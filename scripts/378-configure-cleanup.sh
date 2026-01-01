# shellcheck shell=bash
# Installation Cleanup
# Clears logs and syncs filesystems before shutdown

# Clears system logs from installation process for clean first boot.
# Removes journal logs, auth logs, and other installation artifacts.
cleanup_installation_logs() {
  remote_run "Cleaning up installation logs" '
    # Clear systemd journal (installation messages)
    journalctl --rotate 2>/dev/null || true
    journalctl --vacuum-time=1s 2>/dev/null || true

    # Clear traditional log files
    : > /var/log/syslog 2>/dev/null || true
    : > /var/log/messages 2>/dev/null || true
    : > /var/log/auth.log 2>/dev/null || true
    : > /var/log/kern.log 2>/dev/null || true
    : > /var/log/daemon.log 2>/dev/null || true
    : > /var/log/debug 2>/dev/null || true

    # Clear apt logs
    : > /var/log/apt/history.log 2>/dev/null || true
    : > /var/log/apt/term.log 2>/dev/null || true
    rm -f /var/log/apt/*.gz 2>/dev/null || true

    # Clear dpkg log
    : > /var/log/dpkg.log 2>/dev/null || true

    # Remove rotated logs
    find /var/log -name "*.gz" -delete 2>/dev/null || true
    find /var/log -name "*.[0-9]" -delete 2>/dev/null || true
    find /var/log -name "*.old" -delete 2>/dev/null || true

    # Clear lastlog and wtmp (login history)
    : > /var/log/lastlog 2>/dev/null || true
    : > /var/log/wtmp 2>/dev/null || true
    : > /var/log/btmp 2>/dev/null || true

    # Clear machine-id and regenerate on first boot (optional - makes system unique)
    # Commented out - may cause issues with some services
    # : > /etc/machine-id

    # Sync filesystems to ensure all data is written before shutdown
    # ZFS requires explicit zpool sync to commit all transactions (critical for data integrity)
    sync
    if command -v zpool &>/dev/null; then
      zpool sync 2>/dev/null || true
    fi
    umount /boot/efi 2>/dev/null || true
    sync
    # Final ZFS sync after EFI unmount
    if command -v zpool &>/dev/null; then
      zpool sync 2>/dev/null || true
    fi
  ' "Installation logs cleaned"
}
