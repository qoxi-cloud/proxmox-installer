# shellcheck shell=bash
# =============================================================================
# chkrootkit - Rootkit detection scanner
# Weekly scheduled scans with logging
# Package installed via batch_install_packages() in 037-parallel-helpers.sh
# =============================================================================

# Configuration function for chkrootkit
# Sets up weekly scans via systemd timer with logging
_config_chkrootkit() {
  # Deploy systemd timer for weekly scans
  deploy_systemd_timer "chkrootkit-scan" || return 1

  # Ensure log directory exists
  remote_exec 'mkdir -p /var/log/chkrootkit' || {
    log "ERROR: Failed to configure chkrootkit"
    return 1
  }

  parallel_mark_configured "chkrootkit"
}

# =============================================================================
# Public wrapper
# =============================================================================

# Public wrapper for chkrootkit configuration
configure_chkrootkit() {
  [[ ${INSTALL_CHKROOTKIT:-} != "yes" ]] && return 0
  _config_chkrootkit
}
