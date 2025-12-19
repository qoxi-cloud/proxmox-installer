# shellcheck shell=bash
# =============================================================================
# Remote execution helpers
# =============================================================================

# Installs packages on remote system via apt with standard error handling.
# Parameters:
#   $@ - Package names to install
# Returns: 0 on success, exits on failure
# Side effects: Updates apt cache, installs packages via run_remote
remote_apt_install() {
  local packages="$*"

  if [[ -z $packages ]]; then
    log "ERROR: No packages specified for installation"
    return 1
  fi

  run_remote "Installing packages: $packages" "
    export DEBIAN_FRONTEND=noninteractive
    apt-get update -qq || exit 1
    apt-get install -yqq $packages || exit 1
  " "Packages installed: $packages"
}
