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
      # Try fstab first, then find EFI partition directly
      if ! mount /boot/efi 2>/dev/null; then
        # Find EFI System Partition by type GUID
        efi_part=$(lsblk -no PATH,PARTTYPE 2>/dev/null \
          | grep -i "c12a7328-f81f-11d2-ba4b-00a0c93ec93b" \
          | head -1 | awk "{print \$1}")

        if [[ -z $efi_part ]]; then
          # Fallback: find vfat partition on first disk
          efi_part=$(lsblk -no PATH,FSTYPE 2>/dev/null \
            | grep -E "vfat$" | head -1 | awk "{print \$1}")
        fi

        if [[ -n $efi_part ]]; then
          mkdir -p /boot/efi
          mount -t vfat "$efi_part" /boot/efi || exit 1
        else
          echo "WARNING: No EFI partition found - skipping fallback boot setup"
          exit 0
        fi
      fi
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
