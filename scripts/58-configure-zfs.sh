#!/bin/bash
# shellcheck shell=bash
# =============================================================================
# Configure ZFS ARC memory allocation
# =============================================================================

configure_zfs_arc() {
  log "INFO: Configuring ZFS ARC memory allocation (mode: $ZFS_ARC_MODE)"

  local total_ram_mb
  total_ram_mb=$(free -m | awk 'NR==2 {print $2}')

  local arc_max_mb

  case "$ZFS_ARC_MODE" in
    vm-focused)
      # Fixed 4GB for servers where VMs are primary workload
      arc_max_mb=4096
      log "INFO: ZFS ARC mode: VM-focused - setting fixed 4GB limit"
      ;;
    balanced)
      # Conservative ARC sizing based on RAM:
      # < 16GB: 25% of RAM
      # 16-64GB: 40% of RAM
      # > 64GB: 50% of RAM
      if [[ $total_ram_mb -lt 16384 ]]; then
        arc_max_mb=$((total_ram_mb * 25 / 100))
      elif [[ $total_ram_mb -lt 65536 ]]; then
        arc_max_mb=$((total_ram_mb * 40 / 100))
      else
        arc_max_mb=$((total_ram_mb / 2))
      fi
      log "INFO: ZFS ARC mode: Balanced - calculated ${arc_max_mb}MB (Total RAM: ${total_ram_mb}MB)"
      ;;
    storage-focused)
      # Use 50% of RAM (ZFS default behavior)
      arc_max_mb=$((total_ram_mb / 2))
      log "INFO: ZFS ARC mode: Storage-focused - using 50% of RAM (${arc_max_mb}MB)"
      ;;
    *)
      log "ERROR: Invalid ZFS_ARC_MODE: $ZFS_ARC_MODE"
      return 1
      ;;
  esac

  local arc_max_bytes=$((arc_max_mb * 1024 * 1024))

  # Set ZFS ARC limit in modprobe config (persistent across reboots)
  echo "options zfs zfs_arc_max=${arc_max_bytes}" >/target/etc/modprobe.d/zfs.conf

  # Apply limit to currently running kernel module (if ZFS loaded)
  if [[ -f /target/sys/module/zfs/parameters/zfs_arc_max ]]; then
    echo "${arc_max_bytes}" >/target/sys/module/zfs/parameters/zfs_arc_max 2>/dev/null || true
  fi

  log "INFO: ZFS ARC configured: ${arc_max_mb}MB (Total RAM: ${total_ram_mb}MB)"
  print_success "ZFS ARC memory limit configured"
}

# Run configuration
configure_zfs_arc
