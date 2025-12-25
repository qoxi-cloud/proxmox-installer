# shellcheck shell=bash
# =============================================================================
# Drive detection and role assignment
# =============================================================================

# Detects available drives (NVMe preferred, fallback to any disk).
# Excludes loop devices and partitions.
# Side effects: Sets DRIVES, DRIVE_COUNT, DRIVE_NAMES, DRIVE_SIZES, DRIVE_MODELS globals
detect_drives() {
  # Find all NVMe drives (excluding partitions)
  mapfile -t DRIVES < <(lsblk -d -n -o NAME,TYPE | grep nvme | grep disk | awk '{print "/dev/"$1}' | sort)
  DRIVE_COUNT=${#DRIVES[@]}

  # Fall back to any available disk if no NVMe found (for budget servers)
  if [[ $DRIVE_COUNT -eq 0 ]]; then
    # Find any disk (sda, vda, etc.) excluding loop devices
    mapfile -t DRIVES < <(lsblk -d -n -o NAME,TYPE | grep disk | grep -v loop | awk '{print "/dev/"$1}' | sort)
    DRIVE_COUNT=${#DRIVES[@]}
  fi

  # Collect drive info
  DRIVE_NAMES=()
  DRIVE_SIZES=()
  DRIVE_MODELS=()

  for drive in "${DRIVES[@]}"; do
    local name size model
    name=$(basename "$drive")
    size=$(lsblk -d -n -o SIZE "$drive" | xargs)
    model=$(lsblk -d -n -o MODEL "$drive" 2>/dev/null | xargs || echo "Disk")
    DRIVE_NAMES+=("$name")
    DRIVE_SIZES+=("$size")
    DRIVE_MODELS+=("$model")
  done
}

# Smart disk allocation based on size differences.
# If mixed sizes: smallest → boot, rest → pool
# If identical: all → pool (legacy behavior)
# Side effects: Sets BOOT_DISK, ZFS_POOL_DISKS
detect_disk_roles() {
  [[ $DRIVE_COUNT -eq 0 ]] && return 1

  # Parse sizes to bytes for comparison
  local size_bytes=()
  for size in "${DRIVE_SIZES[@]}"; do
    local bytes
    if [[ $size =~ ([0-9.]+)T ]]; then
      bytes=$(awk "BEGIN {printf \"%.0f\", ${BASH_REMATCH[1]} * 1099511627776}")
    elif [[ $size =~ ([0-9.]+)G ]]; then
      bytes=$(awk "BEGIN {printf \"%.0f\", ${BASH_REMATCH[1]} * 1073741824}")
    else
      bytes=0
    fi
    size_bytes+=("$bytes")
  done

  # Find min/max sizes
  local min_size=${size_bytes[0]}
  local max_size=${size_bytes[0]}
  for size in "${size_bytes[@]}"; do
    [[ $size -lt $min_size ]] && min_size=$size
    [[ $size -gt $max_size ]] && max_size=$size
  done

  # Check if sizes differ by >10%
  local size_diff=$((max_size - min_size))
  local threshold=$((min_size / 10))

  if [[ $size_diff -le $threshold ]]; then
    # All same size → all in pool
    log "All disks same size, using all for ZFS pool"
    BOOT_DISK=""
    ZFS_POOL_DISKS=("${DRIVES[@]}")
  else
    # Mixed sizes → smallest = boot, rest = pool
    log "Mixed disk sizes, using smallest for boot"
    local smallest_idx=0
    for i in "${!size_bytes[@]}"; do
      [[ ${size_bytes[$i]} -lt ${size_bytes[$smallest_idx]} ]] && smallest_idx=$i
    done

    BOOT_DISK="${DRIVES[$smallest_idx]}"
    ZFS_POOL_DISKS=()
    for i in "${!DRIVES[@]}"; do
      [[ $i -ne $smallest_idx ]] && ZFS_POOL_DISKS+=("${DRIVES[$i]}")
    done
  fi

  log "Boot disk: ${BOOT_DISK:-all in pool}"
  log "Pool disks: ${ZFS_POOL_DISKS[*]}"
}
