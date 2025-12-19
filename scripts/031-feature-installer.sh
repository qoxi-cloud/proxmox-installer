# shellcheck shell=bash
# =============================================================================
# Optional feature installation helpers
# =============================================================================

# Universal optional feature installer with standardized error handling.
# Parameters:
#   $1 - Feature name (for display)
#   $2 - Install variable name (e.g., "USE_FAIL2BAN")
#   $3 - Installation function name
#   $4 - Configuration function name
#   $5 - Optional: installed variable name (e.g., "FAIL2BAN_INSTALLED")
# Returns: 0 on success or skip, exits on fatal error
# Side effects: Calls provided functions, updates installed variable if provided
install_optional_feature() {
  local feature_name="$1"
  local install_var="$2"
  local install_func="$3"
  local config_func="$4"
  local installed_var="${5:-}"

  # Check if feature should be installed
  if [[ ${!install_var} != "yes" ]]; then
    log "Skipping $feature_name (not requested)"
    return 0
  fi

  # Run installation function
  if ! "$install_func"; then
    log "ERROR: $feature_name installation failed"
    print_error "$feature_name installation failed"
    return 1
  fi

  # Run configuration function (non-fatal on failure)
  if ! "$config_func"; then
    log "WARNING: $feature_name configuration failed"
    print_warning "$feature_name configuration failed - continuing without it"
    return 0 # Non-fatal error for config
  fi

  # Mark as installed if variable name provided
  if [[ -n $installed_var ]]; then
    declare -g "$installed_var=yes"
    log "$feature_name installed and configured successfully"
  fi

  return 0
}

# Enhanced optional feature installer with progress display.
# Runs installation and configuration in background with progress indicator.
# Parameters:
#   $1 - Feature name (for display)
#   $2 - Install variable name (e.g., "INSTALL_FEATURE")
#   $3 - Installation function name (must use || exit 1 pattern)
#   $4 - Configuration function name (must use || exit 1 pattern)
#   $5 - Installed variable name (e.g., "FEATURE_INSTALLED")
#   $6 - Optional: Progress message (default: "Installing $feature_name")
#   $7 - Optional: Success message (default: "$feature_name configured")
# Returns: 0 on success or skip, 0 on non-fatal error (with warning)
# Side effects: Updates installed variable on success
install_optional_feature_with_progress() {
  local feature_name="$1"
  local install_var="$2"
  local install_func="$3"
  local config_func="$4"
  local installed_var="$5"
  local progress_msg="${6:-Installing $feature_name}"
  local success_msg="${7:-$feature_name configured}"

  # Check if feature should be installed
  if [[ ${!install_var} != "yes" ]]; then
    log "Skipping $feature_name (not requested)"
    return 0
  fi

  log "Installing and configuring $feature_name"

  # Run installation and configuration in background with progress
  (
    "$install_func" || exit 1
    "$config_func" || exit 1
  ) >/dev/null 2>&1 &
  show_progress $! "$progress_msg" "$success_msg"

  local exit_code=$?
  if [[ $exit_code -ne 0 ]]; then
    log "WARNING: $feature_name setup failed"
    print_warning "$feature_name setup failed - continuing without it"
    return 0 # Non-fatal error
  fi

  # Mark as installed
  # shellcheck disable=SC2034
  declare -g "$installed_var=yes"
  return 0
}
