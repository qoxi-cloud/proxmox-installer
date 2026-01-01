# shellcheck shell=bash
# Network interface and IP detection

# Detect default network interface. Sets CURRENT_INTERFACE.
_detect_default_interface() {
  if cmd_exists ip && cmd_exists jq; then
    declare -g CURRENT_INTERFACE="$(ip -j route 2>/dev/null | jq -r '.[] | select(.dst == "default") | .dev' | head -n1)"
  elif cmd_exists ip; then
    declare -g CURRENT_INTERFACE="$(ip route | grep default | awk '{print $5}' | head -n1)"
  elif cmd_exists route; then
    declare -g CURRENT_INTERFACE="$(route -n | awk '/^0\.0\.0\.0/ {print $8}' | head -n1)"
  fi

  if [[ -z $CURRENT_INTERFACE ]]; then
    if cmd_exists ip && cmd_exists jq; then
      declare -g CURRENT_INTERFACE="$(ip -j link show 2>/dev/null | jq -r '.[] | select(.ifname != "lo" and .operstate == "UP") | .ifname' | head -n1)"
    elif cmd_exists ip; then
      declare -g CURRENT_INTERFACE="$(ip link show | awk -F': ' '/^[0-9]+:/ && !/lo:/ {print $2; exit}')"
    elif cmd_exists ifconfig; then
      declare -g CURRENT_INTERFACE="$(ifconfig -a | awk '/^[a-z]/ && !/^lo/ {print $1; exit}' | tr -d ':')"
    fi
  fi

  if [[ -z $CURRENT_INTERFACE ]]; then
    declare -g CURRENT_INTERFACE="eth0"
    log_warn "Could not detect network interface, defaulting to eth0"
  fi
}

# Get predictable interface name from udev. Sets PREDICTABLE_NAME, DEFAULT_INTERFACE.
# Prefers MAC-based naming (enx*) for maximum reliability across udev versions.
_detect_predictable_name() {
  declare -g PREDICTABLE_NAME=""

  if [[ -e "/sys/class/net/${CURRENT_INTERFACE}" ]]; then
    local udev_info
    udev_info=$(udevadm info "/sys/class/net/${CURRENT_INTERFACE}" 2>/dev/null)

    # Prefer MAC-based naming (enx*) - most reliable across different udev versions
    # Different kernels/udev can interpret SMBIOS slots differently (enp* vs ens*)
    # but MAC-based names are always consistent
    declare -g PREDICTABLE_NAME="$(printf '%s\n' "$udev_info" | grep "ID_NET_NAME_MAC=" | cut -d'=' -f2)"

    # Fallback to path-based if MAC naming unavailable
    if [[ -z $PREDICTABLE_NAME ]]; then
      declare -g PREDICTABLE_NAME="$(printf '%s\n' "$udev_info" | grep "ID_NET_NAME_PATH=" | cut -d'=' -f2)"
    fi

    if [[ -z $PREDICTABLE_NAME ]]; then
      declare -g PREDICTABLE_NAME="$(printf '%s\n' "$udev_info" | grep "ID_NET_NAME_ONBOARD=" | cut -d'=' -f2)"
    fi

    if [[ -z $PREDICTABLE_NAME ]]; then
      declare -g PREDICTABLE_NAME="$(ip -d link show "$CURRENT_INTERFACE" 2>/dev/null | grep "altname" | awk '{print $2}' | head -1)"
    fi
  fi

  if [[ -n $PREDICTABLE_NAME ]]; then
    declare -g DEFAULT_INTERFACE="$PREDICTABLE_NAME"
  else
    declare -g DEFAULT_INTERFACE="$CURRENT_INTERFACE"
  fi
}

# Get MAC-based predictable name for an interface. Outputs name to stdout.
_get_mac_based_name() {
  local iface="$1"
  local udev_info mac_name

  if [[ -e "/sys/class/net/${iface}" ]]; then
    udev_info=$(udevadm info "/sys/class/net/${iface}" 2>/dev/null)
    mac_name=$(printf '%s\n' "$udev_info" | grep "ID_NET_NAME_MAC=" | cut -d'=' -f2)

    if [[ -n $mac_name ]]; then
      printf '%s' "$mac_name"
      return 0
    fi

    # Fallback to PATH-based if no MAC name
    mac_name=$(printf '%s\n' "$udev_info" | grep "ID_NET_NAME_PATH=" | cut -d'=' -f2)
    if [[ -n $mac_name ]]; then
      printf '%s' "$mac_name"
      return 0
    fi
  fi

  # Return original if no predictable name found
  printf '%s' "$iface"
}

# Get available interfaces. Sets AVAILABLE_INTERFACES, INTERFACE_NAME, etc.
# Converts all interface names to MAC-based predictable names for reliability.
_detect_available_interfaces() {
  declare -g AVAILABLE_ALTNAMES=$(ip -d link show | grep -v "lo:" | grep -E '(^[0-9]+:|altname)' | awk '/^[0-9]+:/ {interface=$2; gsub(/:/, "", interface); printf "%s", interface} /altname/ {printf ", %s", $2} END {print ""}' | sed 's/, $//')

  # Get raw interface names first
  local raw_interfaces
  if cmd_exists ip && cmd_exists jq; then
    raw_interfaces=$(ip -j link show 2>/dev/null | jq -r '.[] | select(.ifname != "lo") | .ifname' | sort)
  elif cmd_exists ip; then
    raw_interfaces=$(ip link show | awk -F': ' '/^[0-9]+:/ && !/lo:/ {print $2}' | sort)
  else
    raw_interfaces="$CURRENT_INTERFACE"
  fi

  # Convert each interface to MAC-based name
  declare -g AVAILABLE_INTERFACES=""
  local iface mac_name
  while IFS= read -r iface; do
    [[ -z $iface ]] && continue
    mac_name=$(_get_mac_based_name "$iface")
    if [[ -n $AVAILABLE_INTERFACES ]]; then
      declare -g AVAILABLE_INTERFACES="${AVAILABLE_INTERFACES}"$'\n'"${mac_name}"
    else
      declare -g AVAILABLE_INTERFACES="${mac_name}"
    fi
  done <<<"$raw_interfaces"

  declare -g INTERFACE_COUNT="$(printf '%s\n' "$AVAILABLE_INTERFACES" | wc -l)"

  if [[ -z $INTERFACE_NAME ]]; then
    declare -g INTERFACE_NAME="$DEFAULT_INTERFACE"
  fi
}

# IP address detection

# Detect IPv4 address and gateway. Sets MAIN_IPV4, MAIN_IPV4_CIDR, MAIN_IPV4_GW.
_detect_ipv4() {
  local max_attempts="${SSH_RETRY_ATTEMPTS:-3}"
  local attempt=0

  while [[ $attempt -lt $max_attempts ]]; do
    attempt="$((attempt + 1))"

    if cmd_exists ip && cmd_exists jq; then
      declare -g MAIN_IPV4_CIDR="$(ip -j address show "$CURRENT_INTERFACE" 2>/dev/null | jq -r '.[0].addr_info[] | select(.family == "inet" and .scope == "global") | "\(.local)/\(.prefixlen)"' | head -n1)"
      declare -g MAIN_IPV4="${MAIN_IPV4_CIDR%/*}"
      declare -g MAIN_IPV4_GW="$(ip -j route 2>/dev/null | jq -r '.[] | select(.dst == "default") | .gateway' | head -n1)"
      [[ -n $MAIN_IPV4 ]] && [[ -n $MAIN_IPV4_GW ]] && return 0
    elif cmd_exists ip; then
      declare -g MAIN_IPV4_CIDR="$(ip address show "$CURRENT_INTERFACE" 2>/dev/null | grep global | grep "inet " | awk '{print $2}' | head -n1)"
      declare -g MAIN_IPV4="${MAIN_IPV4_CIDR%/*}"
      declare -g MAIN_IPV4_GW="$(ip route 2>/dev/null | grep default | awk '{print $3}' | head -n1)"
      [[ -n $MAIN_IPV4 ]] && [[ -n $MAIN_IPV4_GW ]] && return 0
    elif cmd_exists ifconfig; then
      declare -g MAIN_IPV4="$(ifconfig "$CURRENT_INTERFACE" 2>/dev/null | awk '/inet / {print $2}' | sed 's/addr://')"
      local netmask
      netmask=$(ifconfig "$CURRENT_INTERFACE" 2>/dev/null | awk '/inet / {print $4}' | sed 's/Mask://')
      if [[ -n $MAIN_IPV4 ]] && [[ -n $netmask ]]; then
        case "$netmask" in
          255.255.255.0) declare -g MAIN_IPV4_CIDR="${MAIN_IPV4}/24" ;;
          255.255.255.128) declare -g MAIN_IPV4_CIDR="${MAIN_IPV4}/25" ;;
          255.255.255.192) declare -g MAIN_IPV4_CIDR="${MAIN_IPV4}/26" ;;
          255.255.255.224) declare -g MAIN_IPV4_CIDR="${MAIN_IPV4}/27" ;;
          255.255.255.240) declare -g MAIN_IPV4_CIDR="${MAIN_IPV4}/28" ;;
          255.255.255.248) declare -g MAIN_IPV4_CIDR="${MAIN_IPV4}/29" ;;
          255.255.255.252) declare -g MAIN_IPV4_CIDR="${MAIN_IPV4}/30" ;;
          255.255.0.0) declare -g MAIN_IPV4_CIDR="${MAIN_IPV4}/16" ;;
          *) declare -g MAIN_IPV4_CIDR="${MAIN_IPV4}/24" ;;
        esac
      fi
      if cmd_exists route; then
        declare -g MAIN_IPV4_GW="$(route -n 2>/dev/null | awk '/^0\.0\.0\.0/ {print $2}' | head -n1)"
      fi
      [[ -n $MAIN_IPV4 ]] && [[ -n $MAIN_IPV4_GW ]] && return 0
    fi

    if [[ $attempt -lt $max_attempts ]]; then
      log_info "Network info attempt $attempt failed, retrying in ${RETRY_DELAY_SECONDS:-2} seconds..."
      sleep "${RETRY_DELAY_SECONDS:-2}"
    fi
  done

  # All attempts failed
  log_error "IPv4 detection failed after $max_attempts attempts"
  return 1
}

# Detect MAC and IPv6 info. Sets MAC_ADDRESS, IPV6_*, MAIN_IPV6.
_detect_ipv6_and_mac() {
  if cmd_exists ip && cmd_exists jq; then
    declare -g MAC_ADDRESS="$(ip -j link show "$CURRENT_INTERFACE" 2>/dev/null | jq -r '.[0].address // empty')"
    declare -g IPV6_CIDR="$(ip -j address show "$CURRENT_INTERFACE" 2>/dev/null | jq -r '.[0].addr_info[] | select(.family == "inet6" and .scope == "global") | "\(.local)/\(.prefixlen)"' | head -n1)"
  elif cmd_exists ip; then
    declare -g MAC_ADDRESS="$(ip link show "$CURRENT_INTERFACE" 2>/dev/null | awk '/ether/ {print $2}')"
    declare -g IPV6_CIDR="$(ip address show "$CURRENT_INTERFACE" 2>/dev/null | grep global | grep "inet6 " | awk '{print $2}' | head -n1)"
  elif cmd_exists ifconfig; then
    declare -g MAC_ADDRESS="$(ifconfig "$CURRENT_INTERFACE" 2>/dev/null | awk '/ether/ {print $2}')"
    declare -g IPV6_CIDR="$(ifconfig "$CURRENT_INTERFACE" 2>/dev/null | awk '/inet6/ && /global/ {print $2}')"
  fi
  declare -g MAIN_IPV6="${IPV6_CIDR%/*}"

  if [[ -n $IPV6_CIDR ]]; then
    local ipv6_prefix
    ipv6_prefix=$(printf '%s' "$MAIN_IPV6" | cut -d':' -f1-4)
    declare -g FIRST_IPV6_CIDR="${ipv6_prefix}:1::1/80"
  else
    declare -g FIRST_IPV6_CIDR=""
  fi

  if [[ -n $MAIN_IPV6 ]]; then
    if cmd_exists ip; then
      declare -g IPV6_GATEWAY="$(ip -6 route 2>/dev/null | grep default | awk '{print $3}' | head -n1)"
    fi
  fi
}
