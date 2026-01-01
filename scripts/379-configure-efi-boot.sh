# shellcheck shell=bash
# EFI Fallback Bootloader Configuration

# Configures EFI fallback boot path for systems without NVRAM boot entries.
# Copies the installed bootloader to /EFI/BOOT/BOOTX64.EFI (UEFI default).
# This is required when installing via QEMU without persistent NVRAM.
configure_efi_fallback_boot() {
  # Only needed for UEFI systems
  if ! remote_exec 'test -d /sys/firmware/efi' 2>/dev/null; then
    log "INFO: Legacy BIOS mode - skipping EFI fallback configuration"
    return 0
  fi

  # shellcheck disable=SC2016 # Variables expand on remote, not locally
  remote_run "Configuring EFI fallback boot" '
    # Ensure EFI partition is mounted
    if ! mountpoint -q /boot/efi 2>/dev/null; then
      mount /boot/efi || exit 1
    fi

    # Create fallback directory if needed
    mkdir -p /boot/efi/EFI/BOOT

    # Find and copy the bootloader to fallback path
    # Priority: systemd-boot (ZFS) > GRUB (ext4/LVM) > shim (secure boot)
    local bootloader=""
    if [[ -f /boot/efi/EFI/systemd/systemd-bootx64.efi ]]; then
      bootloader="/boot/efi/EFI/systemd/systemd-bootx64.efi"
    elif [[ -f /boot/efi/EFI/proxmox/grubx64.efi ]]; then
      bootloader="/boot/efi/EFI/proxmox/grubx64.efi"
    elif [[ -f /boot/efi/EFI/debian/grubx64.efi ]]; then
      bootloader="/boot/efi/EFI/debian/grubx64.efi"
    fi

    if [[ -z $bootloader ]]; then
      echo "WARNING: No bootloader found to copy to fallback path"
      exit 0
    fi

    # Copy to fallback path (overwrite if exists)
    cp -f "$bootloader" /boot/efi/EFI/BOOT/BOOTX64.EFI
    echo "Copied $bootloader to /EFI/BOOT/BOOTX64.EFI"
  ' "EFI fallback boot configured"
}
