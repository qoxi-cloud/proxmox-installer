# shellcheck shell=bash
# =============================================================================
# needrestart - Checks which services need restart after library upgrades
# Automatically restarts services when libraries are updated
# Package installed via batch_install_packages() in 037-parallel-helpers.sh
# =============================================================================

# Configuration function for needrestart
# Deploys configuration for automatic restarts
_config_needrestart() {
  remote_exec 'mkdir -p /etc/needrestart/conf.d'
  remote_copy "templates/needrestart.conf" "/etc/needrestart/conf.d/50-autorestart.conf" || {
    log "ERROR: Failed to deploy needrestart config"
    return 1
  }

  parallel_mark_configured "needrestart"
}

# =============================================================================
# Public wrapper
# =============================================================================

# Public wrapper for needrestart configuration
configure_needrestart() {
  [[ ${INSTALL_NEEDRESTART:-} != "yes" ]] && return 0
  _config_needrestart
}
