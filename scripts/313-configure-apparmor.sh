# shellcheck shell=bash
# AppArmor configuration for Proxmox VE
# Provides mandatory access control (MAC) for LXC containers and system services
# Package installed via batch_install_packages() in 037-parallel-helpers.sh

# Configuration function for AppArmor
# Configures GRUB for kernel parameters and enables service
_config_apparmor() {
  # Copy GRUB config (deploy_template creates parent dirs automatically)
  deploy_template "templates/apparmor-grub.cfg" "/etc/default/grub.d/apparmor.cfg"

  # Update boot config and enable AppArmor service (activates after reboot)
  log "INFO: Updating boot configuration and enabling AppArmor"
  remote_exec '
    proxmox-boot-tool refresh
    systemctl enable --now apparmor.service
  ' >>"$LOG_FILE" 2>&1 || {
    log "ERROR: Failed to configure AppArmor"
    return 1
  }

  parallel_mark_configured "apparmor"
}

# Public wrapper (generated via factory)
make_feature_wrapper "apparmor" "INSTALL_APPARMOR"
