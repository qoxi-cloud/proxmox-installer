# shellcheck shell=bash
# General utilities
# NOTE: Many functions have been moved to specialized modules:
# - download_file → 011-downloads.sh
# - apply_template_vars, download_template → 020-templates.sh
# - generate_password → 034-password-utils.sh
# - show_progress → 010-display.sh

# Command existence cache for frequently checked commands (jq, ip, etc.)
declare -gA _CMD_CACHE

# Check if command exists with caching. $1=command → 0 if available
cmd_exists() {
  local cmd="$1"
  if [[ -z "${_CMD_CACHE[$cmd]+isset}" ]]; then
    command -v "$cmd" &>/dev/null && _CMD_CACHE[$cmd]=1 || _CMD_CACHE[$cmd]=0
  fi
  [[ "${_CMD_CACHE[$cmd]}" -eq 1 ]]
}

# Get file size in bytes (cross-platform: GNU and BSD stat, wc fallback). $1=file → size
_get_file_size() {
  local file="$1"
  local size
  # Try GNU stat first (-c%s), then BSD stat (-f%z), then wc -c
  size=$(stat -c%s "$file" 2>/dev/null) \
    || size=$(stat -f%z "$file" 2>/dev/null) \
    || size=$(wc -c <"$file" 2>/dev/null | tr -d ' ')
  # Return size or empty (caller must handle)
  [[ -n "$size" && "$size" =~ ^[0-9]+$ ]] && echo "$size"
}

# Securely delete file (shred or dd fallback). $1=file_path
secure_delete_file() {
  local file="$1"

  [[ -z "$file" ]] && return 0
  [[ ! -f "$file" ]] && return 0

  if cmd_exists shred; then
    shred -u -z "$file" 2>/dev/null || rm -f "$file"
  else
    # Fallback: overwrite with zeros before deletion
    local file_size
    file_size=$(_get_file_size "$file")
    if [[ -n "$file_size" ]]; then
      dd if=/dev/zero of="$file" bs=1 count="$file_size" conv=notrunc 2>/dev/null || true
    fi
    rm -f "$file"
  fi

  return 0
}
