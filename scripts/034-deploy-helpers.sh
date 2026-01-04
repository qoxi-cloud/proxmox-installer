# shellcheck shell=bash
# Parallel file operations and deployment helpers

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

# Deploy template with variable substitution. $1=template, $2=dest, $@=VAR=value
# For .service files: validates ExecStart exists and verifies remote copy
deploy_template() {
  local template="$1"
  local dest="$2"
  shift 2
  local staged
  local is_service=false
  [[ $dest == *.service ]] && is_service=true

  # Stage template to temp location to preserve original
  staged=$(mktemp) || {
    log_error "Failed to create temp file for $template"
    return 1
  }
  register_temp_file "$staged"
  cp "$template" "$staged" || {
    log_error "Failed to stage template $template"
    rm -f "$staged"
    return 1
  }

  # Apply template vars (also validates no unsubstituted placeholders remain)
  apply_template_vars "$staged" "$@" || {
    log_error "Template substitution failed for $template"
    rm -f "$staged"
    return 1
  }

  # For .service files, verify ExecStart exists after substitution
  if [[ $is_service == true ]] && ! grep -q "ExecStart=" "$staged" 2>/dev/null; then
    log_error "Service file $dest missing ExecStart after template substitution"
    rm -f "$staged"
    return 1
  fi

  # Create parent directory on remote if needed
  local dest_dir
  dest_dir=$(dirname "$dest")
  remote_exec "mkdir -p '$dest_dir'" || {
    log_error "Failed to create directory $dest_dir"
    rm -f "$staged"
    return 1
  }

  remote_copy "$staged" "$dest" || {
    log_error "Failed to deploy $template to $dest"
    rm -f "$staged"
    return 1
  }
  rm -f "$staged"

  # Set proper permissions for systemd files (fixes "world-inaccessible" warning)
  if [[ $dest == /etc/systemd/* || $dest == *.service || $dest == *.timer ]]; then
    remote_exec "chmod 644 '$dest'" || {
      log_error "Failed to set permissions on $dest"
      return 1
    }
  fi

  # For .service files, verify remote copy wasn't corrupted
  if [[ $is_service == true ]]; then
    remote_exec "grep -q 'ExecStart=' '$dest'" || {
      log_error "Remote service file $dest appears corrupted (missing ExecStart)"
      return 1
    }
  fi
}
