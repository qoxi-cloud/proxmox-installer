# shellcheck shell=bash
# =============================================================================
# Proxmox ISO download and version management
# =============================================================================

# Cache for ISO list (populated by prefetch_proxmox_iso_info)
_ISO_LIST_CACHE=""

# Cache for SHA256SUMS content
_CHECKSUM_CACHE=""

# Prefetches ISO list and checksums.
# Call this early to cache data for later use.
# Side effects: Populates _ISO_LIST_CACHE and _CHECKSUM_CACHE
prefetch_proxmox_iso_info() {
  _ISO_LIST_CACHE=$(curl -s "$PROXMOX_ISO_BASE_URL" 2>/dev/null | grep -oE 'proxmox-ve_[0-9]+\.[0-9]+-[0-9]+\.iso' | sort -uV) || true
  _CHECKSUM_CACHE=$(curl -s "$PROXMOX_CHECKSUM_URL" 2>/dev/null) || true
}

# Returns available Proxmox VE ISO versions (last N versions, v9+ only).
# Parameters:
#   $1 - Number of versions to return (default: 5)
# Returns: ISO filenames via stdout, newest first
get_available_proxmox_isos() {
  local count="${1:-5}"
  # Filter to versions 9+ (matches 9, 10, 11, etc.)
  printf '%s\n' "$_ISO_LIST_CACHE" | grep -E '^proxmox-ve_(9|[1-9][0-9]+)\.' | tail -n "$count" | tac
}

# Constructs full ISO URL from filename.
# Parameters:
#   $1 - ISO filename
# Returns: Full URL via stdout
get_proxmox_iso_url() {
  local iso_filename="$1"
  printf '%s\n' "${PROXMOX_ISO_BASE_URL}${iso_filename}"
}

# Extracts version from ISO filename.
# Parameters:
#   $1 - ISO filename (e.g., "proxmox-ve_8.3-1.iso")
# Returns: Version string (e.g., "8.3-1") via stdout
get_iso_version() {
  local iso_filename="$1"
  printf '%s\n' "$iso_filename" | sed -E 's/proxmox-ve_([0-9]+\.[0-9]+-[0-9]+)\.iso/\1/'
}

# Internal: downloads ISO using curl with retry support.
# Parameters:
#   $1 - URL to download
#   $2 - Output filename
# Returns: Exit code from curl
_download_iso_curl() {
  local url="$1"
  local output="$2"
  local max_retries="${DOWNLOAD_RETRY_COUNT:-3}"
  local retry_delay="${DOWNLOAD_RETRY_DELAY:-5}"

  log "Downloading with curl (single connection, resume-enabled)"
  curl -fSL \
    --retry "$max_retries" \
    --retry-delay "$retry_delay" \
    --retry-connrefused \
    -C - \
    -o "$output" \
    "$url" >>"$LOG_FILE" 2>&1
}

# Internal: downloads ISO using wget with retry support.
# Parameters:
#   $1 - URL to download
#   $2 - Output filename
# Returns: Exit code from wget
_download_iso_wget() {
  local url="$1"
  local output="$2"
  local max_retries="${DOWNLOAD_RETRY_COUNT:-3}"

  log "Downloading with wget (single connection, resume-enabled)"
  wget -q \
    --tries="$max_retries" \
    --continue \
    --timeout=60 \
    --waitretry=5 \
    -O "$output" \
    "$url" >>"$LOG_FILE" 2>&1
}

# Internal: downloads ISO using aria2c with conservative settings.
# Parameters:
#   $1 - URL to download
#   $2 - Output filename
#   $3 - Optional SHA256 checksum for verification
# Returns: Exit code from aria2c
_download_iso_aria2c() {
  local url="$1"
  local output="$2"
  local checksum="$3"
  local max_retries="${DOWNLOAD_RETRY_COUNT:-3}"

  log "Downloading with aria2c (4 connections, with retries)"
  local aria2_args=(
    -x 4  # 4 connections (optimal for Proxmox server)
    -s 4  # 4 splits
    -k 4M # 4MB minimum split size
    --max-tries="$max_retries"
    --retry-wait=5
    --timeout=60
    --connect-timeout=30
    --max-connection-per-server=4
    --allow-overwrite=true
    --auto-file-renaming=false
    -o "$output"
    --console-log-level=error
    --summary-interval=0
  )

  # Add checksum verification if available
  if [[ -n $checksum ]]; then
    aria2_args+=(--checksum=sha-256="$checksum")
    log "aria2c will verify checksum automatically"
  fi

  aria2c "${aria2_args[@]}" "$url" >>"$LOG_FILE" 2>&1
}

# Internal: downloads ISO with fallback chain (aria2c → curl → wget).
# Tries aria2c first (fastest with parallel connections), then falls back to others.
# Parameters:
#   $1 - URL to download
#   $2 - Output filename
#   $3 - Optional SHA256 checksum
#   $4 - Optional file to write download method (for background job communication)
# Returns: 0 on success, 1 on all failures
_download_iso_with_fallback() {
  local url="$1"
  local output="$2"
  local checksum="$3"
  local method_file="${4:-}"

  # Try aria2c first (fastest - uses parallel connections)
  if command -v aria2c &>/dev/null; then
    log "Trying aria2c (parallel download)..."
    if _download_iso_aria2c "$url" "$output" "$checksum" && [[ -s "$output" ]]; then
      [[ -n $method_file ]] && printf '%s\n' "aria2c" >"$method_file"
      return 0
    fi
    log "aria2c failed, trying fallback..."
    rm -f "$output" 2>/dev/null
  fi

  # Fallback to curl
  log "Trying curl..."
  if _download_iso_curl "$url" "$output" && [[ -s "$output" ]]; then
    [[ -n $method_file ]] && printf '%s\n' "curl" >"$method_file"
    return 0
  fi
  log "curl failed, trying fallback..."
  rm -f "$output" 2>/dev/null

  # Fallback to wget
  if command -v wget &>/dev/null; then
    log "Trying wget..."
    if _download_iso_wget "$url" "$output" && [[ -s "$output" ]]; then
      [[ -n $method_file ]] && printf '%s\n' "wget" >"$method_file"
      return 0
    fi
    rm -f "$output" 2>/dev/null
  fi

  log "All download methods failed"
  return 1
}

# Downloads Proxmox ISO with fallback chain and checksum verification.
# Requires PROXMOX_ISO_VERSION to be set (user selects version in wizard).
# Tries aria2c first (parallel connections), then curl, then wget as fallback.
# Side effects: Creates pve.iso file, exits on failure
download_proxmox_iso() {
  log "Starting Proxmox ISO download"

  if [[ -f "pve.iso" ]]; then
    log "Proxmox ISO already exists, skipping download"
    print_success "Proxmox ISO:" "already exists, skipping download"
    return 0
  fi

  if [[ -z $PROXMOX_ISO_VERSION ]]; then
    log "ERROR: PROXMOX_ISO_VERSION not set"
    exit 1
  fi

  log "Using selected ISO: $PROXMOX_ISO_VERSION"
  PROXMOX_ISO_URL=$(get_proxmox_iso_url "$PROXMOX_ISO_VERSION")
  log "Found ISO URL: $PROXMOX_ISO_URL"

  ISO_FILENAME=$(basename "$PROXMOX_ISO_URL")

  # Get checksum from cache (populated by prefetch_proxmox_iso_info)
  local expected_checksum=""
  if [[ -n $_CHECKSUM_CACHE ]]; then
    expected_checksum=$(printf '%s\n' "$_CHECKSUM_CACHE" | grep "$ISO_FILENAME" | awk '{print $1}')
  fi
  log "Expected checksum: ${expected_checksum:-not available}"

  # Download with fallback chain: aria2c → curl → wget
  log "Downloading ISO: $ISO_FILENAME"
  local method_file
  method_file=$(mktemp)

  _download_iso_with_fallback "$PROXMOX_ISO_URL" "pve.iso" "$expected_checksum" "$method_file" &
  show_progress $! "Downloading $ISO_FILENAME" "$ISO_FILENAME downloaded"
  wait $!
  local exit_code=$?
  DOWNLOAD_METHOD=$(cat "$method_file" 2>/dev/null)
  rm -f "$method_file"

  if [[ $exit_code -ne 0 ]] || [[ ! -s "pve.iso" ]]; then
    log "ERROR: All download methods failed for Proxmox ISO"
    rm -f pve.iso
    exit 1
  fi

  log "Download successful via $DOWNLOAD_METHOD"

  local iso_size
  iso_size=$(stat -c%s pve.iso 2>/dev/null) || iso_size=0
  log "ISO file size: $(printf '%s\n' "$iso_size" | awk '{printf "%.1fG", $1/1024/1024/1024}')"

  # Verify checksum (if not already verified by aria2c)
  if [[ -n $expected_checksum ]]; then
    # Skip manual verification if aria2c already validated
    if [[ $DOWNLOAD_METHOD == "aria2c" ]]; then
      log "Checksum already verified by aria2c"
      # Add live log for aria2c auto-verification
      if type live_log_subtask &>/dev/null 2>&1; then
        live_log_subtask "SHA256: OK (verified by aria2c)"
      fi
    else
      log "Verifying ISO checksum"
      local actual_checksum
      (actual_checksum=$(sha256sum pve.iso | awk '{print $1}') && printf '%s\n' "$actual_checksum" >/tmp/checksum_result) &
      local checksum_pid=$!
      if type show_progress &>/dev/null 2>&1; then
        show_progress $checksum_pid "Verifying checksum" "Checksum verified"
      else
        wait $checksum_pid
      fi
      actual_checksum=$(cat /tmp/checksum_result 2>/dev/null)
      rm -f /tmp/checksum_result
      if [[ $actual_checksum != "$expected_checksum" ]]; then
        log "ERROR: Checksum mismatch! Expected: $expected_checksum, Got: $actual_checksum"
        if type live_log_subtask &>/dev/null 2>&1; then
          live_log_subtask "SHA256: FAILED"
        fi
        rm -f pve.iso
        exit 1
      fi
      log "Checksum verification passed"
      if type live_log_subtask &>/dev/null 2>&1; then
        live_log_subtask "SHA256: OK"
      fi
    fi
  else
    log "WARNING: Could not find checksum for $ISO_FILENAME"
    print_warning "Could not find checksum for $ISO_FILENAME"
  fi

  # Clean up /tmp to free memory (rescue system uses tmpfs)
  log "Cleaning up temporary files in /tmp"
  rm -rf /tmp/tmp.* /tmp/pve-* /tmp/checksum_result 2>/dev/null || true
  log "Temporary files cleaned"
}
