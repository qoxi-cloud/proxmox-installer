# shellcheck shell=bash
# QEMU configuration

# Check if UEFI mode. Returns 0=UEFI, 1=BIOS
is_uefi_mode() {
  [[ -d /sys/firmware/efi ]]
}

# Configure QEMU settings. Sets UEFI_OPTS, KVM_OPTS, QEMU_CORES/RAM, DRIVE_ARGS.
setup_qemu_config() {
  log_info "Setting up QEMU configuration"

  # UEFI configuration
  if is_uefi_mode; then
    declare -g UEFI_OPTS="-bios /usr/share/ovmf/OVMF.fd"
    log_info "UEFI mode detected"
  else
    declare -g UEFI_OPTS=""
    log_info "Legacy BIOS mode"
  fi

  # KVM acceleration
  declare -g KVM_OPTS="-enable-kvm"
  declare -g CPU_OPTS="-cpu host"
  log_info "Using KVM acceleration"

  # CPU and RAM configuration
  local available_cores available_ram_mb
  available_cores=$(nproc)
  available_ram_mb=$(free -m | awk '/^Mem:/{print $2}')
  log_info "Available cores: $available_cores, Available RAM: ${available_ram_mb}MB"

  # Use override values if provided, otherwise auto-detect
  if [[ -n $QEMU_CORES_OVERRIDE ]]; then
    declare -g QEMU_CORES="$QEMU_CORES_OVERRIDE"
    log_info "Using user-specified cores: $QEMU_CORES"
  else
    # Use all available cores for QEMU
    declare -g QEMU_CORES="$available_cores"
    [[ $QEMU_CORES -lt $MIN_CPU_CORES ]] && declare -g QEMU_CORES="$MIN_CPU_CORES"
  fi

  if [[ -n $QEMU_RAM_OVERRIDE ]]; then
    declare -g QEMU_RAM="$QEMU_RAM_OVERRIDE"
    log_info "Using user-specified RAM: ${QEMU_RAM}MB"
    # Warn if requested RAM exceeds available
    if [[ $QEMU_RAM -gt $((available_ram_mb - QEMU_MIN_RAM_RESERVE)) ]]; then
      print_warning "Requested QEMU RAM (${QEMU_RAM}MB) may exceed safe limits (available: ${available_ram_mb}MB)"
    fi
  else
    # Use all available RAM minus reserve for host
    declare -g QEMU_RAM="$((available_ram_mb - QEMU_MIN_RAM_RESERVE))"
    [[ $QEMU_RAM -lt $MIN_QEMU_RAM ]] && declare -g QEMU_RAM="$MIN_QEMU_RAM"
  fi

  log_info "QEMU config: $QEMU_CORES vCPUs, ${QEMU_RAM}MB RAM"

  # Load virtio mapping (created by make_answer_toml)
  if ! load_virtio_mapping; then
    log_error "Failed to load virtio mapping"
    return 1
  fi

  # Validate VIRTIO_MAP is not empty before proceeding
  if [[ ${#VIRTIO_MAP[@]} -eq 0 ]]; then
    log_error "VIRTIO_MAP is empty - no disks mapped for QEMU"
    print_error "No disk-to-virtio mappings found. Ensure ZFS pool disks were selected in wizard storage configuration."
    return 1
  fi

  # Build DRIVE_ARGS from virtio mapping in correct order (vda, vdb, vdc, ...)
  # CRITICAL: QEMU assigns virtio devices in order of -drive arguments!
  # We must iterate by virtio name (sorted) to match the mapping.
  declare -g DRIVE_ARGS=""

  # Build reverse map: virtio_device -> physical_disk
  declare -A REVERSE_MAP
  local disk vdev
  for disk in "${!VIRTIO_MAP[@]}"; do
    vdev="${VIRTIO_MAP[$disk]}"
    REVERSE_MAP["$vdev"]="$disk"
  done

  # Iterate virtio devices in sorted order (vda, vdb, vdc, ...)
  local sorted_vdevs
  sorted_vdevs=$(printf '%s\n' "${!REVERSE_MAP[@]}" | sort)

  for vdev in $sorted_vdevs; do
    disk="${REVERSE_MAP[$vdev]}"
    # Validate disk exists before adding to QEMU args
    if [[ ! -b $disk ]]; then
      log_error "Disk $disk does not exist or is not a block device"
      return 1
    fi
    log_info "QEMU drive order: $vdev -> $disk"
    declare -g DRIVE_ARGS="$DRIVE_ARGS -drive file=$disk,format=raw,media=disk,if=virtio"
  done

  if [[ -z $DRIVE_ARGS ]]; then
    log_error "No drive arguments built - QEMU would start without disks"
    return 1
  fi

  log_info "Drive args: $DRIVE_ARGS"
}
