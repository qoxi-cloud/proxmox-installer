# shellcheck shell=bash
# Proxmox ISO download and version management

# Cache for ISO list (populated by prefetch_proxmox_iso_info)
_ISO_LIST_CACHE=""

# Cache for SHA256SUMS content
_CHECKSUM_CACHE=""

# Prefetch ISO list and checksums to cache
prefetch_proxmox_iso_info() {
  declare -g _ISO_LIST_CACHE
  declare -g _CHECKSUM_CACHE
  _ISO_LIST_CACHE="$(curl -s "$PROXMOX_ISO_BASE_URL" 2>/dev/null | grep -oE 'proxmox-ve_[0-9]+\.[0-9]+-[0-9]+\.iso' | sort -uV)" || true
  _CHECKSUM_CACHE="$(curl -s "$PROXMOX_CHECKSUM_URL" 2>/dev/null)" || true
}

# Get available Proxmox ISOs (v9+). $1=count (default 5) → stdout
get_available_proxmox_isos() {
  local count="${1:-5}"
  # Filter to versions 9+ (matches 9, 10, 11, etc.)
  printf '%s\n' "$_ISO_LIST_CACHE" | grep -E '^proxmox-ve_(9|[1-9][0-9]+)\.' | tail -n "$count" | tac
}

# Get full ISO URL. $1=filename → stdout
get_proxmox_iso_url() {
  local iso_filename="$1"
  printf '%s\n' "${PROXMOX_ISO_BASE_URL}${iso_filename}"
}

# Extract version from ISO filename. $1=filename → stdout
get_iso_version() {
  local iso_filename="$1"
  printf '%s\n' "$iso_filename" | sed -E 's/proxmox-ve_([0-9]+\.[0-9]+-[0-9]+)\.iso/\1/'
}

# Internal: Download and verify ISO (silent, for parallel execution)
_download_iso() {
  log_info "Starting Proxmox ISO download"

  if [[ -f "pve.iso" ]]; then
    log_info "Proxmox ISO already exists, skipping download"
    return 0
  fi

  if [[ -z $PROXMOX_ISO_VERSION ]]; then
    log_error "PROXMOX_ISO_VERSION not set"
    return 1
  fi

  log_info "Using selected ISO: $PROXMOX_ISO_VERSION"
  declare -g PROXMOX_ISO_URL
  PROXMOX_ISO_URL="$(get_proxmox_iso_url "$PROXMOX_ISO_VERSION")"
  log_info "Found ISO URL: $PROXMOX_ISO_URL"

  declare -g ISO_FILENAME
  ISO_FILENAME="$(basename "$PROXMOX_ISO_URL")"

  # Get checksum from cache (populated by prefetch_proxmox_iso_info)
  local expected_checksum=""
  if [[ -n $_CHECKSUM_CACHE ]]; then
    expected_checksum="$(printf '%s\n' "$_CHECKSUM_CACHE" | grep "$ISO_FILENAME" | awk '{print $1}')"
  fi
  log_info "Expected checksum: ${expected_checksum:-not available}"

  # Download with fallback chain: aria2c → curl → wget
  log_info "Downloading ISO: $ISO_FILENAME"
  local method_file=""
  method_file=$(mktemp) || {
    log_error "mktemp failed for method_file"
    return 1
  }
  register_temp_file "$method_file"

  _download_iso_with_fallback "$PROXMOX_ISO_URL" "pve.iso" "$expected_checksum" "$method_file"
  local exit_code="$?"
  declare -g DOWNLOAD_METHOD
  DOWNLOAD_METHOD="$(cat "$method_file" 2>/dev/null)"
  rm -f "$method_file"

  if [[ $exit_code -ne 0 ]] || [[ ! -s "pve.iso" ]]; then
    log_error "All download methods failed for Proxmox ISO"
    rm -f pve.iso
    return 1
  fi

  log_info "Download successful via $DOWNLOAD_METHOD"

  local iso_size
  iso_size="$(stat -c%s pve.iso 2>/dev/null)" || iso_size=0
  log_info "ISO file size: $(printf '%s\n' "$iso_size" | awk '{printf "%.1fG", $1/1024/1024/1024}')"

  # Verify checksum (if not already verified by aria2c)
  if [[ -n $expected_checksum ]]; then
    if [[ $DOWNLOAD_METHOD == "aria2c" ]]; then
      log_info "Checksum already verified by aria2c"
    else
      log_info "Verifying ISO checksum"
      local actual_checksum
      actual_checksum=$(sha256sum pve.iso | awk '{print $1}')
      if [[ $actual_checksum != "$expected_checksum" ]]; then
        log_error "Checksum mismatch! Expected: $expected_checksum, Got: $actual_checksum"
        rm -f pve.iso
        return 1
      fi
      log_info "Checksum verification passed"
    fi
  else
    log_warn "Could not find checksum for $ISO_FILENAME"
  fi

  # Clean up /tmp to free memory (rescue system uses tmpfs)
  log_info "Cleaning up temporary files in /tmp"
  rm -rf /tmp/tmp.* /tmp/pve-* 2>/dev/null || true
  log_info "Temporary files cleaned"
}

# Parallel wrapper for run_parallel_group
_parallel_download_iso() {
  _download_iso || return 1
  parallel_mark_configured "ISO downloaded"
}
