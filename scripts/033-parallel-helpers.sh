# shellcheck shell=bash
# Parallel execution framework for faster installation

# Internal: run single task in parallel group. $1=result_dir, $2=idx, $3=func
_run_parallel_task() {
  local result_dir="$1"
  local idx="$2"
  local func="$3"

  # Default to failure marker on ANY exit (handles remote_run's exit 1)
  # shellcheck disable=SC2064
  trap "touch '$result_dir/fail_$idx' 2>/dev/null" EXIT

  if "$func" >/dev/null 2>&1; then
    # Write success marker BEFORE clearing trap to avoid race condition
    # If touch fails, trap still fires and marks as failed
    if touch "$result_dir/success_$idx" 2>/dev/null; then
      trap - EXIT # Only clear trap after success marker is confirmed written
    fi
  fi
}

# Run config functions in parallel with concurrency limit. $1=name, $2=done_msg, $@=functions
run_parallel_group() {
  local group_name="$1"
  local done_msg="$2"
  shift 2
  local funcs=("$@")

  if [[ ${#funcs[@]} -eq 0 ]]; then
    log_info "No functions to run in parallel group: $group_name"
    return 0
  fi

  # Max concurrent jobs (prevents fork bombs, default 8)
  local max_jobs="${PARALLEL_MAX_JOBS:-8}"
  log_info "Running parallel group '$group_name' with functions: ${funcs[*]} (max $max_jobs concurrent)"

  # Track results via temp files (avoid subshell variable issues)
  local result_dir
  result_dir=$(mktemp -d) || {
    log_error "Failed to create temp dir for parallel group '$group_name'"
    return 1
  }
  register_temp_file "$result_dir"
  export PARALLEL_RESULT_DIR="$result_dir"

  # Start functions in background with concurrency limit
  # Use trap to ensure marker created even if function calls exit 1 (like remote_run)
  # NOTE: Each subshell gets its own copy of variables at fork time.
  local i=0
  local running=0
  local pids=()
  for func in "${funcs[@]}"; do
    _run_parallel_task "$result_dir" "$i" "$func" &
    pids+=("$!")
    ((i++))
    ((running++))

    # Poll for job completion (wait -n requires bash 4.3+, we support 4.0+)
    while ((running >= max_jobs)); do
      local completed=0
      for ((j = 0; j < i; j++)); do
        [[ -f "$result_dir/success_$j" || -f "$result_dir/fail_$j" ]] && ((completed++))
      done
      running="$((i - completed))"
      ((running >= max_jobs)) && sleep 0.1
    done
  done

  local count="$i"

  # Wait for all with single progress
  (
    while true; do
      local done_count=0
      for ((j = 0; j < count; j++)); do
        [[ -f "$result_dir/success_$j" || -f "$result_dir/fail_$j" ]] && ((done_count++))
      done
      [[ $done_count -eq $count ]] && break
      sleep "${PROGRESS_POLL_INTERVAL:-0.2}"
    done
  ) &
  show_progress "$!" "$group_name" "$done_msg"

  # Collect configured features for display
  local configured=()
  for f in "$result_dir"/ran_*; do
    [[ -f "$f" ]] && configured+=("$(cat "$f")")
  done

  # Show configured features as subtasks (one per line)
  for item in "${configured[@]}"; do
    add_subtask_log "$item"
  done

  # Check for failures
  local failures=0
  for ((j = 0; j < count; j++)); do
    [[ -f "$result_dir/fail_$j" ]] && ((failures++))
  done

  # Cleanup before return (not using RETURN trap - it overwrites exit status)
  rm -rf "$result_dir"
  unset PARALLEL_RESULT_DIR

  if [[ $failures -gt 0 ]]; then
    log_error "$failures/$count functions failed in group '$group_name'"
    return $failures
  fi

  return 0
}

# Mark feature as configured in parallel group. $1=feature name
# Safe to call outside parallel groups - becomes a no-op
parallel_mark_configured() {
  local feature="$1"
  # Only write if directory exists (protects against stale PARALLEL_RESULT_DIR)
  [[ -n ${PARALLEL_RESULT_DIR:-} && -d $PARALLEL_RESULT_DIR ]] \
    && printf '%s' "$feature" >"$PARALLEL_RESULT_DIR/ran_$BASHPID"
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

  wait "$pid" 2>/dev/null
  local exit_code=$?

  if [[ $exit_code -ne 0 ]]; then
    log_error "configure_${feature} failed (exit code: $exit_code)"
    return 1
  fi
  return 0
}
