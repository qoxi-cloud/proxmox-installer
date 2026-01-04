# shellcheck shell=bash
# Autoinstall ISO creation for Proxmox

# Validate answer.toml format. $1=file_path
validate_answer_toml() {
  local file="$1"

  # Basic field validation
  # Note: Use kebab-case keys (root-password, not root_password)
  local required_fields=("fqdn" "mailto" "timezone" "root-password")
  for field in "${required_fields[@]}"; do
    if ! grep -q "^\s*${field}\s*=" "$file" 2>/dev/null; then
      log_error "Missing required field in answer.toml: $field"
      return 1
    fi
  done

  if ! grep -q "\[global\]" "$file" 2>/dev/null; then
    log_error "Missing [global] section in answer.toml"
    return 1
  fi

  # Validate using Proxmox auto-install assistant if available
  if cmd_exists proxmox-auto-install-assistant; then
    log_info "Validating answer.toml with proxmox-auto-install-assistant"
    if ! proxmox-auto-install-assistant validate-answer "$file" >>"$LOG_FILE" 2>&1; then
      log_error "answer.toml validation failed"
      # Show validation errors in log
      proxmox-auto-install-assistant validate-answer "$file" >>"$LOG_FILE" 2>&1 || true
      return 1
    fi
    log_info "answer.toml validation passed"
  else
    log_warn "proxmox-auto-install-assistant not found, skipping advanced validation"
  fi

  return 0
}

# Internal: Create answer.toml (silent, for parallel execution)
_make_answer_toml() {
  log_info "Creating answer.toml for autoinstall"
  log_debug "ZFS_RAID=$ZFS_RAID, BOOT_DISK=$BOOT_DISK"
  log_debug "ZFS_POOL_DISKS=(${ZFS_POOL_DISKS[*]})"
  log_debug "USE_EXISTING_POOL=$USE_EXISTING_POOL, EXISTING_POOL_NAME=$EXISTING_POOL_NAME"
  log_debug "EXISTING_POOL_DISKS=(${EXISTING_POOL_DISKS[*]})"

  # Determine which disks to pass to QEMU
  # - For existing pool: pass existing pool disks (needed for zpool import)
  # - For new pool: pass ZFS_POOL_DISKS
  # Note: These disks are passed to QEMU but NOT included in answer.toml disk-list,
  #       so the installer won't format them - only the boot disk gets formatted
  local virtio_pool_disks=()
  if [[ $USE_EXISTING_POOL == "yes" ]]; then
    log_info "Using existing pool mode - existing pool disks will be passed to QEMU for import"
    # Filter to only include disks that actually exist on the host
    # (pool metadata may contain stale virtio device names from previous installations)
    for disk in "${EXISTING_POOL_DISKS[@]}"; do
      if [[ -b $disk ]]; then
        virtio_pool_disks+=("$disk")
      else
        log_warn "Pool disk $disk does not exist on host, skipping"
      fi
    done
  else
    virtio_pool_disks=("${ZFS_POOL_DISKS[@]}")
  fi

  # Create virtio mapping (synchronous for parallel execution)
  log_info "Creating virtio disk mapping"
  create_virtio_mapping "$BOOT_DISK" "${virtio_pool_disks[@]}" || {
    log_error "Failed to create virtio mapping"
    return 1
  }

  # Load mapping into current shell
  load_virtio_mapping || {
    log_error "Failed to load virtio mapping"
    return 1
  }

  # Determine filesystem and disk list based on BOOT_DISK mode:
  # - BOOT_DISK set: ext4 on boot disk only, ZFS pool created post-install
  # - BOOT_DISK empty: ZFS on all disks (existing behavior)
  local FILESYSTEM
  local all_disks=()

  if [[ -n $BOOT_DISK ]]; then
    # Separate boot disk mode: ext4 on boot disk, ZFS pool created/imported later
    FILESYSTEM="ext4"
    all_disks=("$BOOT_DISK")

    if [[ $USE_EXISTING_POOL == "yes" ]]; then
      # Validate existing pool name is set
      if [[ -z $EXISTING_POOL_NAME ]]; then
        log_error "USE_EXISTING_POOL=yes but EXISTING_POOL_NAME is empty"
        return 1
      fi
      log_info "Boot disk mode: ext4 on boot disk, existing pool '$EXISTING_POOL_NAME' will be imported"
    else
      # Pool disks are optional - if empty, local storage uses all boot disk space
      if [[ ${#ZFS_POOL_DISKS[@]} -eq 0 ]]; then
        log_info "Boot disk mode: ext4 on boot disk only, no separate ZFS pool"
      else
        log_info "Boot disk mode: ext4 on boot disk, ZFS 'tank' pool will be created from ${#ZFS_POOL_DISKS[@]} pool disk(s)"
      fi
    fi
  else
    # All-ZFS mode: all disks in ZFS rpool
    FILESYSTEM="zfs"
    all_disks=("${ZFS_POOL_DISKS[@]}")

    log_info "All-ZFS mode: ${#all_disks[@]} disk(s) in ZFS rpool (${ZFS_RAID})"
  fi

  # Build DISK_LIST from all_disks using virtio mapping
  declare -g DISK_LIST
  DISK_LIST=$(map_disks_to_virtio "toml_array" "${all_disks[@]}")
  if [[ -z $DISK_LIST ]]; then
    log_error "Failed to map disks to virtio devices"
    return 1
  fi

  log_debug "FILESYSTEM=$FILESYSTEM, DISK_LIST=$DISK_LIST"

  # Generate answer.toml dynamically based on filesystem type
  # This allows conditional sections (ZFS vs LVM parameters)
  log_info "Generating answer.toml for autoinstall"

  # NOTE: SSH key is NOT added to answer.toml anymore.
  # SSH key is deployed directly to the admin user in 302-configure-admin.sh
  # Root login is disabled for both SSH and Proxmox UI.

  # Escape password for TOML basic string. Reject unsupported control chars first.
  local escaped_password="$NEW_ROOT_PASSWORD" test_pwd="$NEW_ROOT_PASSWORD"
  for c in $'\t' $'\n' $'\r' $'\b' $'\f'; do test_pwd="${test_pwd//$c/}"; done
  # shellcheck disable=SC2076
  [[ "$test_pwd" =~ [[:cntrl:]] ]] && {
    log_error "Password has unsupported control chars"
    return 1
  }

  # CRITICAL: Backslashes must be escaped first to avoid double-escaping other sequences
  escaped_password="${escaped_password//\\/\\\\}"
  escaped_password="${escaped_password//\"/\\\"}"
  escaped_password="${escaped_password//$'\t'/\\t}"
  escaped_password="${escaped_password//$'\n'/\\n}"
  escaped_password="${escaped_password//$'\r'/\\r}"
  escaped_password="${escaped_password//$'\b'/\\b}"
  escaped_password="${escaped_password//$'\f'/\\f}"

  # Generate [global] section
  # IMPORTANT: Use kebab-case for all keys (root-password, reboot-on-error)
  cat >./answer.toml <<EOF
[global]
    keyboard = "$KEYBOARD"
    country = "$COUNTRY"
    fqdn = "$FQDN"
    mailto = "$EMAIL"
    timezone = "$TIMEZONE"
    root-password = "$escaped_password"
    reboot-on-error = false

[network]
    source = "from-dhcp"

[disk-setup]
    filesystem = "$FILESYSTEM"
    disk-list = $DISK_LIST
EOF

  # Add filesystem-specific parameters
  if [[ $FILESYSTEM == "zfs" ]]; then
    # Map ZFS_RAID to answer.toml format
    local zfs_raid_value
    zfs_raid_value=$(map_raid_to_toml "$ZFS_RAID")
    log_info "Using ZFS raid: $zfs_raid_value"

    # Add ZFS parameters
    cat >>./answer.toml <<EOF
    zfs.raid = "$zfs_raid_value"
    zfs.compress = "lz4"
    zfs.checksum = "on"
EOF
  elif [[ $FILESYSTEM == "ext4" ]] || [[ $FILESYSTEM == "xfs" ]]; then
    # Add LVM parameters for ext4/xfs
    # swapsize: 0 = no swap (rely on zswap for memory compression)
    # maxroot: 0 = unlimited root size (use all available space)
    # maxvz: 0 = no separate data LV, no local-lvm storage
    cat >>./answer.toml <<EOF
    lvm.swapsize = 0
    lvm.maxroot = 0
    lvm.maxvz = 0
EOF
  fi

  # Validate the generated file
  if ! validate_answer_toml "./answer.toml"; then
    log_error "answer.toml validation failed"
    return 1
  fi

  log_info "answer.toml created and validated:"
  # Redact password before logging to prevent credential exposure
  sed 's/^\([[:space:]]*root-password[[:space:]]*=[[:space:]]*\).*/\1"[REDACTED]"/' answer.toml >>"$LOG_FILE"
}

# Parallel wrapper for run_parallel_group
_parallel_make_toml() {
  _make_answer_toml || return 1
  parallel_mark_configured "answer.toml created"
}

# Create autoinstall ISO from Proxmox ISO and answer.toml
make_autoinstall_iso() {
  log_info "Creating autoinstall ISO"
  log_info "Input: pve.iso exists: $(test -f pve.iso && echo 'yes' || echo 'no')"
  log_info "Input: answer.toml exists: $(test -f answer.toml && echo 'yes' || echo 'no')"
  log_info "Current directory: $(pwd)"

  # Run ISO creation with full logging
  proxmox-auto-install-assistant prepare-iso pve.iso --fetch-from iso --answer-file answer.toml --output pve-autoinstall.iso >>"$LOG_FILE" 2>&1 &
  show_progress "$!" "Creating autoinstall ISO" "Autoinstall ISO created"
  local exit_code="$?"
  if [[ $exit_code -ne 0 ]]; then
    log_warn "proxmox-auto-install-assistant exited with code $exit_code"
  fi

  # Verify ISO was created
  if [[ ! -f "./pve-autoinstall.iso" ]]; then
    log_error "Autoinstall ISO not found after creation attempt"
    exit 1
  fi

  log_info "Autoinstall ISO created successfully: $(stat -c%s pve-autoinstall.iso 2>/dev/null | awk '{printf "%.1fM", $1/1024/1024}')"

  # Add live log subtasks after completion
  if type live_log_subtask &>/dev/null 2>&1; then
    live_log_subtask "Packed ISO with xorriso"
  fi

  # Remove original ISO to save disk space (only autoinstall ISO is needed)
  log_info "Removing original ISO to save disk space"
  rm -f pve.iso
}
