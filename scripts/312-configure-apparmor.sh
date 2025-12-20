# shellcheck shell=bash
# =============================================================================
# AppArmor configuration for Proxmox VE
# Provides mandatory access control (MAC) for LXC containers and system services
# Package installed via batch_install_packages() in 037-parallel-helpers.sh
# =============================================================================

# Configuration function for AppArmor
# Configures GRUB for kernel parameters and enables service
_config_apparmor() {
  # Create directory and copy GRUB config (always - it's idempotent)
  remote_exec 'mkdir -p /etc/default/grub.d'
  remote_copy "templates/apparmor-grub.cfg" "/etc/default/grub.d/apparmor.cfg"

  # Configure AppArmor
  # shellcheck disable=SC2016 # Single quotes intentional - executed on remote system
  remote_exec '
    # Update GRUB with AppArmor kernel parameters
    update-grub 2>/dev/null || true

    # Enable AppArmor to start on boot (will activate after reboot)
    systemctl enable apparmor.service
  ' || {
    log "ERROR: Failed to configure AppArmor"
    return 1
  }
}
