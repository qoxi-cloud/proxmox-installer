# shellcheck shell=bash
# DNS validation functions

# Extract IPv4 address from text. Returns first valid IPv4 found.
_extract_ipv4() {
  grep -oE '([0-9]{1,3}\.){3}[0-9]{1,3}' | head -1
}

# Parse dig output for A record. Handles CNAME chains and various formats.
_parse_dig_output() {
  local output="$1"
  local ip=""
  # Primary: dig +short returns IPs directly (may have CNAMEs first)
  ip=$(printf '%s\n' "$output" | grep -E '^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$' | head -1)
  # Fallback: extract any IPv4 from output
  [[ -z $ip ]] && ip=$(printf '%s\n' "$output" | _extract_ipv4)
  printf '%s' "$ip"
}

# Parse host output for A record. Handles different locales and formats.
_parse_host_output() {
  local output="$1"
  local ip=""
  # Primary: "hostname has address x.x.x.x"
  ip=$(printf '%s\n' "$output" | grep -i "has address" | head -1 | awk '{print $NF}')
  # Fallback: "hostname A x.x.x.x" or similar
  [[ -z $ip ]] && ip=$(printf '%s\n' "$output" | grep -iE '(^|\s)A\s' | head -1 | _extract_ipv4)
  # Last resort: any IPv4 after the first line (skip server info)
  [[ -z $ip ]] && ip=$(printf '%s\n' "$output" | tail -n +2 | _extract_ipv4)
  printf '%s' "$ip"
}

# Parse nslookup output for A record. Handles BSD/GNU/busybox variations.
_parse_nslookup_output() {
  local output="$1"
  local ip=""
  # Skip the server info section, look for Address without port (#)
  ip=$(printf '%s\n' "$output" | awk '/^Address:/ && !/#/ {print $2; exit}')
  # Fallback: look for "Address: x.x.x.x" without port anywhere
  [[ -z $ip ]] && ip=$(printf '%s\n' "$output" | grep -E '^Address:\s*[0-9]' | grep -v '#' | head -1 | awk '{print $2}')
  # Fallback: "Name:...Address:" pattern (some nslookup versions)
  [[ -z $ip ]] && ip=$(printf '%s\n' "$output" | awk '/^Name:/{found=1} found && /^Address:/{print $2; exit}')
  # Last resort: any IPv4 after "Non-authoritative" or "Name:" line
  [[ -z $ip ]] && ip=$(printf '%s\n' "$output" | sed -n '/Non-authoritative\|^Name:/,$p' | _extract_ipv4)
  printf '%s' "$ip"
}

# Parse getent ahosts output. Handles different formats.
_parse_getent_output() {
  local output="$1"
  local ip=""
  # Primary: "x.x.x.x STREAM hostname"
  ip=$(printf '%s\n' "$output" | grep -i 'STREAM' | head -1 | awk '{print $1}')
  # Fallback: first IPv4 in output
  [[ -z $ip ]] && ip=$(printf '%s\n' "$output" | _extract_ipv4)
  printf '%s' "$ip"
}

# Validate FQDN resolves to IP. $1=fqdn, $2=expected_ip. Sets DNS_RESOLVED_IP.
validate_dns_resolution() {
  local fqdn="$1"
  local expected_ip="$2"
  local resolved_ip=""
  local dns_timeout="${DNS_LOOKUP_TIMEOUT:-5}" # Default 5 second timeout
  local retry_delay="${DNS_RETRY_DELAY:-10}"   # Default 10 second delay between retries
  local max_attempts=3

  # Determine which DNS tool to use (check once, not in loop)
  local dns_tool=""
  if cmd_exists dig; then
    dns_tool="dig"
  elif cmd_exists host; then
    dns_tool="host"
  elif cmd_exists nslookup; then
    dns_tool="nslookup"
  fi

  # If no DNS tool available, log warning and return no resolution
  if [[ -z $dns_tool ]]; then
    log "WARNING: No DNS lookup tool available (dig, host, or nslookup)"
    DNS_RESOLVED_IP=""
    return 1
  fi

  # Retry loop for DNS resolution
  for ((attempt = 1; attempt <= max_attempts; attempt++)); do
    resolved_ip=""

    # Try each public DNS server until we get a result (use global DNS_SERVERS)
    local raw_output=""
    for dns_server in "${DNS_SERVERS[@]}"; do
      case "$dns_tool" in
        dig)
          # Use outer timeout only to avoid conflicting timeout values
          raw_output=$(timeout "$dns_timeout" dig +short +tries=1 A "$fqdn" "@${dns_server}" 2>/dev/null)
          resolved_ip=$(_parse_dig_output "$raw_output")
          ;;
        host)
          # Use outer timeout only to avoid conflicting timeout values
          raw_output=$(timeout "$dns_timeout" host -t A "$fqdn" "$dns_server" 2>/dev/null)
          resolved_ip=$(_parse_host_output "$raw_output")
          ;;
        nslookup)
          # Use outer timeout only to avoid conflicting timeout values
          raw_output=$(timeout "$dns_timeout" nslookup "$fqdn" "$dns_server" 2>/dev/null)
          resolved_ip=$(_parse_nslookup_output "$raw_output")
          ;;
      esac

      if [[ -n $resolved_ip ]]; then
        break
      fi
    done

    # Fallback to system resolver if public DNS fails
    if [[ -z $resolved_ip ]]; then
      case "$dns_tool" in
        dig)
          raw_output=$(timeout "$dns_timeout" dig +short +tries=1 A "$fqdn" 2>/dev/null)
          resolved_ip=$(_parse_dig_output "$raw_output")
          ;;
        *)
          if cmd_exists getent; then
            raw_output=$(timeout "$dns_timeout" getent ahosts "$fqdn" 2>/dev/null)
            resolved_ip=$(_parse_getent_output "$raw_output")
          fi
          ;;
      esac
    fi

    # If we got a result, process it
    if [[ -n $resolved_ip ]]; then
      DNS_RESOLVED_IP="$resolved_ip"
      if [[ $resolved_ip == "$expected_ip" ]]; then
        return 0 # Match
      else
        return 2 # Wrong IP
      fi
    fi

    # No resolution on this attempt
    if [[ $attempt -lt $max_attempts ]]; then
      log "WARN: DNS lookup for $fqdn failed (attempt $attempt/$max_attempts), retrying in ${retry_delay}s..."
      sleep "$retry_delay"
    fi
  done

  # All attempts failed
  log "ERROR: Failed to resolve $fqdn after $max_attempts attempts"
  DNS_RESOLVED_IP=""
  return 1 # No resolution
}
