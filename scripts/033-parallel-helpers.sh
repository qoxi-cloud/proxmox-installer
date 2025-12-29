# shellcheck shell=bash
# Parallel execution helpers for faster installation

# Install all base system packages in one batch
install_base_packages() {
  # shellcheck disable=SC2086
  local packages="${SYSTEM_UTILITIES} ${OPTIONAL_PACKAGES} locales chrony unattended-upgrades apt-listchanges linux-cpupower"
  # Add ZSH packages if needed
  [[ ${SHELL_TYPE:-bash} == "zsh" ]] && packages="$packages zsh git"
  log "Installing base packages: $packages"
  remote_run "Installing system packages" "
    set -e
    export DEBIAN_FRONTEND=noninteractive
    # Wait for apt locks (max 5 min)
    waited=0
    while fuser /var/lib/dpkg/lock-frontend /var/lib/apt/lists/lock >/dev/null 2>&1; do
      [ \$waited -ge 300 ] && { echo 'ERROR: Timeout waiting for apt lock' >&2; exit 1; }
      sleep 2; waited=\$((waited + 2))
    done
    apt-get update -qq
    apt-get dist-upgrade -yqq
    apt-get install -yqq $packages
    apt-get autoremove -yqq
    apt-get clean
    set +e
    pveupgrade 2>/dev/null || echo 'pveupgrade check skipped' >&2
    pveam update 2>/dev/null || echo 'pveam update skipped' >&2
  " "System packages installed"
  # Show installed packages as subtasks
  # shellcheck disable=SC2086
  log_subtasks $packages
}

# Collect and install all feature packages in one batch
batch_install_packages() {
  local packages=()
  # Security packages
  [[ $INSTALL_FIREWALL == "yes" ]] && packages+=(nftables)
  if [[ $INSTALL_FIREWALL == "yes" && ${FIREWALL_MODE:-standard} != "stealth" ]]; then
    packages+=(fail2ban)
  fi
  [[ $INSTALL_APPARMOR == "yes" ]] && packages+=(apparmor apparmor-utils)
  [[ $INSTALL_AUDITD == "yes" ]] && packages+=(auditd audispd-plugins)
  [[ $INSTALL_AIDE == "yes" ]] && packages+=(aide aide-common)
  [[ $INSTALL_CHKROOTKIT == "yes" ]] && packages+=(chkrootkit binutils)
  [[ $INSTALL_LYNIS == "yes" ]] && packages+=(lynis)
  [[ $INSTALL_NEEDRESTART == "yes" ]] && packages+=(needrestart)
  # Monitoring packages
  [[ $INSTALL_VNSTAT == "yes" ]] && packages+=(vnstat)
  [[ $INSTALL_PROMTAIL == "yes" ]] && packages+=(promtail)
  [[ $INSTALL_NETDATA == "yes" ]] && packages+=(netdata)
  # Tools packages
  [[ $INSTALL_NVIM == "yes" ]] && packages+=(neovim)
  [[ $INSTALL_RINGBUFFER == "yes" ]] && packages+=(ethtool)
  [[ $INSTALL_YAZI == "yes" ]] && packages+=(yazi ffmpeg 7zip jq poppler-utils fd-find ripgrep fzf zoxide imagemagick)
  # Tailscale (needs custom repo)
  [[ $INSTALL_TAILSCALE == "yes" ]] && packages+=(tailscale)
  # SSL packages
  [[ ${SSL_TYPE:-self-signed} == "letsencrypt" ]] && packages+=(certbot)
  if [[ ${#packages[@]} -eq 0 ]]; then
    log "No optional packages to install"
    return 0
  fi

  log "Batch installing packages: ${packages[*]}"

  # Build repo setup commands for packages needing custom repos
  # Detect Debian codename dynamically to support future releases (trixie, etc.)
  # shellcheck disable=SC2016
  local repo_setup='
    DEBIAN_CODENAME=$(grep -oP "VERSION_CODENAME=\K\w+" /etc/os-release 2>/dev/null || echo "bookworm")
  '

  if [[ $INSTALL_TAILSCALE == "yes" ]]; then
    # shellcheck disable=SC2016
    repo_setup+='
      curl -fsSL "https://pkgs.tailscale.com/stable/debian/${DEBIAN_CODENAME}.noarmor.gpg" | tee /usr/share/keyrings/tailscale-archive-keyring.gpg >/dev/null
      curl -fsSL "https://pkgs.tailscale.com/stable/debian/${DEBIAN_CODENAME}.tailscale-keyring.list" | tee /etc/apt/sources.list.d/tailscale.list
    '
  fi

  if [[ $INSTALL_NETDATA == "yes" ]]; then
    # shellcheck disable=SC2016
    repo_setup+='
      curl -fsSL https://repo.netdata.cloud/netdatabot.gpg.key | gpg --dearmor -o /usr/share/keyrings/netdata-archive-keyring.gpg
      echo "deb [signed-by=/usr/share/keyrings/netdata-archive-keyring.gpg] https://repo.netdata.cloud/repos/stable/debian/ ${DEBIAN_CODENAME}/" > /etc/apt/sources.list.d/netdata.list
    '
  fi

  if [[ $INSTALL_PROMTAIL == "yes" ]]; then
    repo_setup+='
      curl -fsSL https://apt.grafana.com/gpg.key | gpg --dearmor -o /usr/share/keyrings/grafana-archive-keyring.gpg
      echo "deb [signed-by=/usr/share/keyrings/grafana-archive-keyring.gpg] https://apt.grafana.com stable main" > /etc/apt/sources.list.d/grafana.list
    '
  fi

  if [[ $INSTALL_YAZI == "yes" ]]; then
    # shellcheck disable=SC2016
    repo_setup+='
      curl -fsSL https://debian.griffo.io/EA0F721D231FDD3A0A17B9AC7808B4DD62C41256.asc | gpg --dearmor --yes -o /etc/apt/trusted.gpg.d/debian.griffo.io.gpg
      echo "deb https://debian.griffo.io/apt ${DEBIAN_CODENAME} main" > /etc/apt/sources.list.d/debian.griffo.io.list
    '
  fi

  # Use remote_run for reliable execution (pipes script to bash -s, better for long scripts)
  # remote_run exits on failure, so no need for error handling here
  # shellcheck disable=SC2086,SC2016
  remote_run "Installing packages (${#packages[@]})" '
      set -e
      export DEBIAN_FRONTEND=noninteractive
      # Wait for apt locks (max 5 min)
      waited=0
      while fuser /var/lib/dpkg/lock-frontend /var/lib/apt/lists/lock >/dev/null 2>&1; do
        [ $waited -ge 300 ] && { echo "ERROR: Timeout waiting for apt lock" >&2; exit 1; }
        sleep 2; waited=$((waited + 2))
      done
      '"$repo_setup"'
      apt-get update -qq
      apt-get install -yqq '"${packages[*]}"'
    ' "Packages installed"

  # Show installed packages as subtasks
  log_subtasks "${packages[@]}"

  return 0
}

# Internal: run single task in parallel group. $1=result_dir, $2=idx, $3=func
_run_parallel_task() {
  local result_dir="$1"
  local idx="$2"
  local func="$3"

  # Override show_progress to silent waiter to prevent TUI race conditions.
  # Each subshell has its own copy of LOG_LINES array and live_show_progress
  # writes to /dev/tty (bypassing >/dev/null). Multiple subshells racing to
  # redraw causes flickering and corruption. Parent handles group progress.
  # shellcheck disable=SC2317
  show_progress() {
    wait "$1" 2>/dev/null
    return $?
  }

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
    log "No functions to run in parallel group: $group_name"
    return 0
  fi

  # Max concurrent jobs (prevents fork bombs, default 8)
  local max_jobs="${PARALLEL_MAX_JOBS:-8}"
  log "Running parallel group '$group_name' with functions: ${funcs[*]} (max $max_jobs concurrent)"

  # Track results via temp files (avoid subshell variable issues)
  local result_dir
  result_dir=$(mktemp -d) || {
    log "ERROR: Failed to create temp dir for parallel group '$group_name'"
    return 1
  }
  export PARALLEL_RESULT_DIR="$result_dir"

  # Start functions in background with concurrency limit
  # Use trap to ensure marker created even if function calls exit 1 (like remote_run)
  # NOTE: Each subshell gets its own copy of variables at fork time.
  local i=0
  local running=0
  local pids=()
  for func in "${funcs[@]}"; do
    _run_parallel_task "$result_dir" "$i" "$func" &
    pids+=($!)
    ((i++))
    ((running++))

    # Poll for job completion (wait -n requires bash 4.3+, we support 4.0+)
    while ((running >= max_jobs)); do
      local completed=0
      for ((j = 0; j < i; j++)); do
        [[ -f "$result_dir/success_$j" || -f "$result_dir/fail_$j" ]] && ((completed++))
      done
      running=$((i - completed)) && ((running >= max_jobs)) && sleep 0.1
    done
  done

  local count=$i

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
  show_progress $! "$group_name" "$done_msg"

  # Collect configured features for display
  local configured=()
  for f in "$result_dir"/ran_*; do
    [[ -f "$f" ]] && configured+=("$(cat "$f")")
  done

  # Show configured features as subtasks
  if [[ ${#configured[@]} -gt 0 ]]; then
    log_subtasks "${configured[@]}"
  fi

  # Check for failures
  local failures=0
  for ((j = 0; j < count; j++)); do
    [[ -f "$result_dir/fail_$j" ]] && ((failures++))
  done

  # Cleanup before return (not using RETURN trap - it overwrites exit status)
  rm -rf "$result_dir"

  if [[ $failures -gt 0 ]]; then
    log "ERROR: $failures/$count functions failed in group '$group_name'"
    return $failures
  fi

  return 0
}

# Mark feature as configured in parallel group. $1=feature name
parallel_mark_configured() {
  local feature="$1"
  [[ -n ${PARALLEL_RESULT_DIR:-} ]] && printf '%s' "$feature" >"$PARALLEL_RESULT_DIR/ran_$BASHPID"
}
