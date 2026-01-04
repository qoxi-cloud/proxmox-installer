# shellcheck shell=bash
# Drive detection and role assignment

# Detect available drives. Sets DRIVES, DRIVE_COUNT, DRIVE_NAMES/SIZES/MODELS.
detect_drives() {
  # Find all NVMe drives (excluding partitions)
  mapfile -t DRIVES < <(lsblk -d -n -o NAME,TYPE | grep nvme | grep disk | awk '{print "/dev/"$1}' | sort)
  declare -g DRIVE_COUNT="${#DRIVES[@]}"

  # Fall back to any available disk if no NVMe found (for budget servers)
  if [[ $DRIVE_COUNT -eq 0 ]]; then
    # Find any disk (sda, vda, etc.) excluding loop devices
    mapfile -t DRIVES < <(lsblk -d -n -o NAME,TYPE | grep disk | grep -v loop | awk '{print "/dev/"$1}' | sort)
    declare -g DRIVE_COUNT="${#DRIVES[@]}"
  fi

  # Collect drive info
  declare -g -a DRIVE_NAMES=()
  declare -g -a DRIVE_SIZES=()
  declare -g -a DRIVE_MODELS=()

  for drive in "${DRIVES[@]}"; do
    local name size model
    name="$(basename "$drive")"
    size="$(lsblk -d -n -o SIZE "$drive" | xargs)"
    model="$(lsblk -d -n -o MODEL "$drive" 2>/dev/null | xargs || echo "Disk")"
    DRIVE_NAMES+=("$name")
    DRIVE_SIZES+=("$size")
    DRIVE_MODELS+=("$model")
  done
}

# Initialize disk roles without auto-selection. User must manually select.
# Sets BOOT_DISK="", ZFS_POOL_DISKS=().
detect_disk_roles() {
  [[ $DRIVE_COUNT -eq 0 ]] && return 1

  # Initialize empty - user must select manually in wizard
  declare -g BOOT_DISK=""
  declare -g -a ZFS_POOL_DISKS=()

  log_info "Disk roles initialized (user selection required)"
  log_info "Available drives: ${DRIVES[*]}"
}

# Existing ZFS pool detection

# Detect existing ZFS pools → stdout "name|status|disks" per line
detect_existing_pools() {
  # Check if zpool command exists
  if ! cmd_exists zpool; then
    log_warn "zpool not found - ZFS not installed in rescue"
    return 0
  fi

  local pools=()

  # Get importable pools - try multiple methods
  # Method 1: scan all devices explicitly (catches more pools)
  local import_output
  import_output=$(zpool import -d /dev 2>&1) || true

  # Fallback: try without -d flag
  if [[ -z "$import_output" ]] || [[ $import_output == *"no pools available"* ]]; then
    import_output=$(zpool import 2>&1) || true
  fi

  log_debug "zpool import output: ${import_output:-(empty)}"

  # Check if output contains pool info (not just "no pools available")
  if [[ -z "$import_output" ]] || [[ $import_output == *"no pools available"* ]]; then
    log_debug "No importable pools found"
    return 0
  fi

  # Parse zpool import output
  # Format:
  #   pool: tankname
  #      id: 12345
  #   state: ONLINE
  #  action: The pool can be imported...
  #  config:
  #      tankname    ONLINE
  #        mirror-0  ONLINE
  #          nvme0n1 ONLINE
  #          nvme1n1 ONLINE

  local current_pool=""
  local current_state=""
  local current_disks=""
  local in_config=false

  while IFS= read -r line; do
    # Pool name
    if [[ $line =~ ^[[:space:]]*pool:[[:space:]]*(.+)$ ]]; then
      # Save previous pool if exists
      if [[ -n $current_pool ]]; then
        pools+=("${current_pool}|${current_state}|${current_disks}")
      fi
      current_pool="${BASH_REMATCH[1]}"
      current_state=""
      current_disks=""
      in_config=false
    # State
    elif [[ $line =~ ^[[:space:]]*state:[[:space:]]*(.+)$ ]]; then
      current_state="${BASH_REMATCH[1]}"
    # Config section start
    elif [[ $line =~ ^[[:space:]]*config: ]]; then
      in_config=true
    # Disk entries - match common disk patterns
    elif [[ $in_config == true ]]; then
      # Match: nvme0n1, sda, vda, xvda, hda, etc (with partition suffix optional)
      if [[ $line =~ ^[[:space:]]+(nvme[0-9]+n[0-9]+|[shxv]d[a-z]+)[p0-9]*[[:space:]] ]]; then
        local disk="${BASH_REMATCH[1]}"
        if [[ -n $current_disks ]]; then
          current_disks="${current_disks},/dev/${disk}"
        else
          current_disks="/dev/${disk}"
        fi
      fi
    fi
  done <<<"$import_output"

  # Save last pool
  if [[ -n $current_pool ]]; then
    pools+=("${current_pool}|${current_state}|${current_disks}")
  fi

  # Output pools
  for pool in "${pools[@]}"; do
    printf '%s\n' "$pool"
  done
}

# Get disks in pool. $1=pool_name → comma-separated disk paths
get_pool_disks() {
  local pool_name="$1"

  for line in "${DETECTED_POOLS[@]}"; do
    local name="${line%%|*}"
    if [[ $name == "$pool_name" ]]; then
      local rest="${line#*|}"
      printf '%s\n' "${rest#*|}"
      return 0
    fi
  done

  return 1
}

# Stores detected pools for wizard use
# Format: DETECTED_POOLS[0]="name|status|disks"
DETECTED_POOLS=()
