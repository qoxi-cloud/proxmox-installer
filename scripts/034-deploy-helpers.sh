# shellcheck shell=bash
# =============================================================================
# Parallel file operations and feature wrapper factory
# =============================================================================

# Copies multiple files to remote in parallel and waits for all to complete.
# Reduces code duplication for the common pattern of parallel remote_copy calls.
# Parameters:
#   $@ - Pairs of "source:dest" (e.g., "templates/hosts:/etc/hosts")
# Returns: 0 if all copies succeed, 1 if any fail
# Example:
#   run_parallel_copies \
#     "templates/hosts:/etc/hosts" \
#     "templates/resolv.conf:/etc/resolv.conf" \
#     "templates/sysctl.conf:/etc/sysctl.d/99-custom.conf"
run_parallel_copies() {
  local -a pids=()
  local -a pairs=("$@")

  for pair in "${pairs[@]}"; do
    local src="${pair%%:*}"
    local dst="${pair#*:}"
    remote_copy "$src" "$dst" >/dev/null 2>&1 &
    pids+=($!)
  done

  # Wait for all copies and track failures
  local failures=0
  for pid in "${pids[@]}"; do
    if ! wait "$pid"; then
      ((failures++))
    fi
  done

  if [[ $failures -gt 0 ]]; then
    log "ERROR: $failures/${#pairs[@]} parallel copies failed"
    return 1
  fi

  return 0
}

# =============================================================================
# Feature wrapper factory
# =============================================================================

# Creates a configure_* wrapper that checks INSTALL_* flag before calling _config_*.
# Eliminates duplicate wrapper boilerplate across configure scripts.
# Parameters:
#   $1 - Feature name (e.g., "apparmor")
#   $2 - Flag variable name (e.g., "INSTALL_APPARMOR")
# Side effects: Defines configure_<feature>() function globally
# Example:
#   make_feature_wrapper "apparmor" "INSTALL_APPARMOR"
#   # Creates: configure_apparmor() that guards _config_apparmor()
# shellcheck disable=SC2086,SC2154
make_feature_wrapper() {
  local feature="$1"
  local flag_var="$2"
  eval "configure_${feature}() { [[ \${${flag_var}:-} != \"yes\" ]] && return 0; _config_${feature}; }"
}
