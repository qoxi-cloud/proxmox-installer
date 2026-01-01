# shellcheck shell=bash
# Configure ZFS ARC memory allocation

# Private implementation - configures ZFS ARC memory
_config_zfs_arc() {
  log_info "Configuring ZFS ARC memory allocation (mode: $ZFS_ARC_MODE)"

  # Calculate ARC size locally (we know RAM from rescue system)
  local total_ram_mb
  total_ram_mb=$(free -m | awk 'NR==2 {print $2}')

  # Validate numeric before arithmetic
  if [[ ! $total_ram_mb =~ ^[0-9]+$ ]] || [[ $total_ram_mb -eq 0 ]]; then
    log_error "Failed to detect RAM size (got: '$total_ram_mb')"
    return 1
  fi

  local arc_max_mb
  case "$ZFS_ARC_MODE" in
    vm-focused)
      # Fixed 4GB for servers where VMs are primary workload
      arc_max_mb=4096
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
      ;;
    storage-focused)
      # Use 50% of RAM (ZFS default behavior)
      arc_max_mb=$((total_ram_mb / 2))
      ;;
    *)
      log_error "Invalid ZFS_ARC_MODE: $ZFS_ARC_MODE"
      return 1
      ;;
  esac

  local arc_max_bytes=$((arc_max_mb * 1024 * 1024))

  log_info "ZFS ARC: ${arc_max_mb}MB (Total RAM: ${total_ram_mb}MB, Mode: $ZFS_ARC_MODE)"

  # Set ZFS ARC limit in modprobe config (persistent) and apply to running kernel
  remote_run "Configuring ZFS ARC memory" "
    echo 'options zfs zfs_arc_max=$arc_max_bytes' >/etc/modprobe.d/zfs.conf
    if [[ -f /sys/module/zfs/parameters/zfs_arc_max ]]; then
      echo '$arc_max_bytes' >/sys/module/zfs/parameters/zfs_arc_max 2>/dev/null || true
    fi
  "

  log_info "ZFS ARC memory limit configured: ${arc_max_mb}MB"
}

# Fix ZFS cachefile import issues during boot

# Private implementation - fixes cachefile import failures
_config_zfs_cachefile() {
  log_info "Configuring ZFS cachefile import fixes"

  # 1. Create systemd drop-in to ensure devices are ready before import
  remote_run "Creating systemd drop-in for zfs-import-cache.service" "
    mkdir -p /etc/systemd/system/zfs-import-cache.service.d
  " || return 1

  deploy_template "templates/zfs-import-cache.service.d-override.conf" \
    "/etc/systemd/system/zfs-import-cache.service.d/override.conf" || return 1

  # 2. Install initramfs hook to include cachefile in initramfs
  deploy_template "templates/zfs-cachefile-initramfs-hook" \
    "/etc/initramfs-tools/hooks/zfs-cachefile" || return 1

  remote_exec "chmod +x /etc/initramfs-tools/hooks/zfs-cachefile" || {
    log_error "Failed to make initramfs hook executable"
    return 1
  }

  # 3. Regenerate cachefile for all existing pools
  remote_run "Regenerating ZFS cachefile" "
    rm -f /etc/zfs/zpool.cache
    for pool in \$(zpool list -H -o name 2>/dev/null); do
      zpool set cachefile=/etc/zfs/zpool.cache \"\$pool\"
    done
  " "ZFS cachefile regenerated"

  log_info "ZFS cachefile import fixes configured"
}

# Configure ZFS scrub scheduling

# Private implementation - configures ZFS scrub timers
_config_zfs_scrub() {
  log_info "Configuring ZFS scrub schedule"

  # Deploy systemd service and timer templates
  remote_copy "templates/zfs-scrub.service" "/etc/systemd/system/zfs-scrub@.service" || {
    log_error "Failed to deploy ZFS scrub service"
    return 1
  }
  remote_copy "templates/zfs-scrub.timer" "/etc/systemd/system/zfs-scrub@.timer" || {
    log_error "Failed to deploy ZFS scrub timer"
    return 1
  }

  # Determine data pool name: existing pool name or "tank"
  local data_pool="tank"
  if [[ $USE_EXISTING_POOL == "yes" && -n $EXISTING_POOL_NAME ]]; then
    data_pool="$EXISTING_POOL_NAME"
  fi

  log_info "Enabling scrub timers for pools: rpool (if exists), $data_pool"

  # Enable scrub timers for all detected pools
  remote_run "Enabling ZFS scrub timers" "
    systemctl daemon-reload
    for pool in \$(zpool list -H -o name 2>/dev/null); do
      systemctl enable --now zfs-scrub@\$pool.timer 2>/dev/null || true
    done
  "

  log_info "ZFS scrub schedule configured (monthly, 1st Sunday at 2:00 AM)"
}

# Public wrappers

# Public wrapper for ZFS ARC configuration
configure_zfs_arc() {
  _config_zfs_arc
}

# Public wrapper for ZFS cachefile import fixes
configure_zfs_cachefile() {
  _config_zfs_cachefile
}

# Public wrapper for ZFS scrub scheduling
configure_zfs_scrub() {
  _config_zfs_scrub
}
