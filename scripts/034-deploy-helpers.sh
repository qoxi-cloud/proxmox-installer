# shellcheck shell=bash
# Parallel file operations and feature wrapper factory

# Guard for functions that require ADMIN_USERNAME. $1=context (optional)
require_admin_username() {
  if [[ -z ${ADMIN_USERNAME:-} ]]; then
    log_error "ADMIN_USERNAME is empty${1:+, cannot $1}"
    return 1
  fi
}

# Copy multiple files to remote with error aggregation. $@="src:dst" pairs
# Note: Copies are serialized due to ControlMaster socket locking
run_batch_copies() {
  local -a pids=()
  local -a pairs=("$@")

  for pair in "${pairs[@]}"; do
    local src="${pair%%:*}"
    local dst="${pair#*:}"
    remote_copy "$src" "$dst" &
    pids+=("$!")
  done

  # Wait for all copies and track failures
  local failures=0
  for pid in "${pids[@]}"; do
    if ! wait "$pid"; then
      ((failures++))
    fi
  done

  if [[ $failures -gt 0 ]]; then
    log_error "$failures/${#pairs[@]} parallel copies failed"
    return 1
  fi

  return 0
}

# Timer with log directory helper

# Deploy systemd timer and create log dir. $1=timer_name, $2=log_dir
deploy_timer_with_logdir() {
  local timer_name="$1"
  local log_dir="$2"

  deploy_systemd_timer "$timer_name" || return 1

  remote_exec "mkdir -p '$log_dir'" || {
    log_error "Failed to create $log_dir"
    return 1
  }
}

# Feature wrapper factory

# Create configure_* wrapper checking INSTALL_* flag. $1=feature, $2=flag_var
# shellcheck disable=SC2086,SC2154
make_feature_wrapper() {
  local feature="$1"
  local flag_var="$2"
  eval "configure_${feature}() { [[ \${${flag_var}:-} != \"yes\" ]] && return 0; _config_${feature}; }"
}

# Create configure_* wrapper checking VAR==value. $1=feature, $2=var, $3=expected
# shellcheck disable=SC2086,SC2154
make_condition_wrapper() {
  local feature="$1"
  local var_name="$2"
  local expected_value="$3"
  eval "configure_${feature}() { [[ \${${var_name}:-} != \"${expected_value}\" ]] && return 0; _config_${feature}; }"
}

# Async feature execution helpers

# Start async feature if flag is set. $1=feature, $2=flag_var. Sets REPLY to PID.
# IMPORTANT: Do NOT call via $(). Call directly to keep process as child of main shell.
start_async_feature() {
  local feature="$1"
  local flag_var="$2"
  local flag_value="${!flag_var:-}"

  REPLY=""
  [[ $flag_value != "yes" ]] && return 0

  "configure_${feature}" >>"$LOG_FILE" 2>&1 &
  REPLY="$!"
}

# Wait for async feature and log result. $1=feature, $2=pid
wait_async_feature() {
  local feature="$1"
  local pid="$2"

  [[ -z $pid ]] && return 0

  if ! wait "$pid" 2>/dev/null; then
    log_error "configure_${feature} failed (exit code: $?)"
    return 1
  fi
  return 0
}
