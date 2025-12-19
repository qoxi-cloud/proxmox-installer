# shellcheck shell=bash
# =============================================================================
# needrestart - Checks which services need restart after library upgrades
# Automatically restarts services when libraries are updated
# =============================================================================

# Installation function for needrestart
_install_needrestart() {
  run_remote "Installing needrestart" '
    export DEBIAN_FRONTEND=noninteractive
    apt-get update -qq
    apt-get install -yqq needrestart
  ' "needrestart installed"
}

# Configuration function for needrestart
_config_needrestart() {
  # Deploy configuration for automatic restarts
  remote_copy "templates/needrestart.conf" "/etc/needrestart/conf.d/50-autorestart.conf" || return 1
}

# Installs and configures needrestart for automatic service restarts.
# Sets up automatic restart mode for unattended operation.
# Side effects: Sets NEEDRESTART_INSTALLED global, installs needrestart package
configure_needrestart() {
  # Skip if needrestart is not requested
  if [[ $INSTALL_NEEDRESTART != "yes" ]]; then
    log "Skipping needrestart (not requested)"
    return 0
  fi

  log "Installing and configuring needrestart"

  # Install and configure using helper (with background progress)
  (
    _install_needrestart || exit 1
    _config_needrestart || exit 1
  ) >/dev/null 2>&1 &
  show_progress $! "Installing needrestart" "needrestart configured"

  local exit_code=$?
  if [[ $exit_code -ne 0 ]]; then
    log "WARNING: needrestart setup failed"
    print_warning "needrestart setup failed - continuing without it"
    return 0 # Non-fatal error
  fi

  # Set flag for summary display
  # shellcheck disable=SC2034
  NEEDRESTART_INSTALLED="yes"
}
