# shellcheck shell=bash
# =============================================================================
# SSH helper functions - Remote execution
# =============================================================================
#
# Function selection guide:
#
# remote_exec()      - Low-level SSH execution with retry. Use for:
#                      - Single commands that may not need progress display
#                      - Commands within subshells that already show progress
#                      - Quick status checks or simple configurations
#                      - Returns exit code (doesn't exit on failure)
#
# remote_run()       - Primary function for configuration scripts. Use for:
#                      - All major installation/configuration steps
#                      - Commands that should show progress to user
#                      - Operations where failure should abort installation
#                      - Automatically exits on failure (no manual error handling)
#
# remote_copy()      - SCP file transfer. Use for:
#                      - Deploying config files and templates
#                      - Returns exit code (check manually or use || return 1)
#
# deploy_template()  - High-level helper (in 038-deploy-helpers.sh). Use for:
#                      - Templates with variable substitution + remote copy
#
# run_with_progress() - Background command with progress. Use for:
#                      - Local or remote operations needing progress display
#                      - Wraps any command (not just SSH)
#
# =============================================================================

# Default timeout for remote commands (seconds)
# Can be overridden per-call or via SSH_COMMAND_TIMEOUT environment variable
readonly SSH_DEFAULT_TIMEOUT=300

# Sanitizes script content for logging by masking sensitive values.
# Replaces passwords and secrets with [REDACTED] to prevent leaks in log files.
# Parameters:
#   $1 - Script content to sanitize
# Returns: Sanitized script via stdout
_sanitize_script_for_log() {
  local script="$1"

  # Mask common password patterns (variable assignments and chpasswd)
  # Pattern: PASSWORD=something, PASSWORD="quoted", PASSWORD='quoted'
  # Handle unquoted, single-quoted, and double-quoted values
  script=$(printf '%s\n' "$script" | sed -E 's/(PASSWORD|password|PASSWD|passwd|SECRET|secret|TOKEN|token|KEY|key)=('"'"'[^'"'"']*'"'"'|"[^"]*"|[^[:space:]'"'"'";]+)/\1=[REDACTED]/g')

  # Pattern: echo "user:password" | chpasswd
  script=$(printf '%s\n' "$script" | sed -E 's/(echo[[:space:]]+['\''"]?[^:]+:)[^|'\''"]*/\1[REDACTED]/g')

  # Pattern: --authkey='...' or --authkey="..." or --authkey=...
  # Handle unquoted, single-quoted, and double-quoted values
  script=$(printf '%s\n' "$script" | sed -E 's/(--authkey=)('"'"'[^'"'"']*'"'"'|"[^"]*"|[^[:space:]'"'"'";]+)/\1[REDACTED]/g')

  printf '%s\n' "$script"
}

# Executes command on remote VM via SSH with retry logic and timeout.
# Use when you need return code handling or within subshells with own progress.
# Parameters:
#   $* - Command to execute remotely
# Environment:
#   SSH_COMMAND_TIMEOUT - Override default timeout (seconds, default: 300)
# Returns: Exit code from remote command (124 on timeout)
remote_exec() {
  local passfile
  passfile=$(_ssh_get_passfile)

  local cmd_timeout="${SSH_COMMAND_TIMEOUT:-$SSH_DEFAULT_TIMEOUT}"
  local max_attempts="${SSH_RETRY_ATTEMPTS:-3}"
  local attempt=0

  while [[ $attempt -lt $max_attempts ]]; do
    attempt=$((attempt + 1))

    # shellcheck disable=SC2086
    if timeout "$cmd_timeout" sshpass -f "$passfile" ssh -p "$SSH_PORT" $SSH_OPTS root@localhost "$@"; then
      return 0
    fi

    local exit_code=$?
    if [[ $exit_code -eq 124 ]]; then
      log "ERROR: SSH command timed out after ${cmd_timeout}s: $*"
      return 124
    fi

    if [[ $attempt -lt $max_attempts ]]; then
      log "SSH attempt $attempt failed, retrying in ${RETRY_DELAY_SECONDS:-2} seconds..."
      sleep "${RETRY_DELAY_SECONDS:-2}"
    fi
  done

  log "ERROR: SSH command failed after $max_attempts attempts: $*"
  return 1
}

# Internal: Executes remote script with progress indicator.
# Don't use directly - use remote_run() instead which handles errors.
# Parameters:
#   $1 - Progress message
#   $2 - Script content to execute
#   $3 - Done message (optional, defaults to $1)
# Returns: Exit code from remote script
_remote_exec_with_progress() {
  local message="$1"
  local script="$2"
  local done_message="${3:-$message}"

  log "_remote_exec_with_progress: $message"
  log "--- Script start (sanitized) ---"
  # Sanitize script before logging to prevent password leaks
  _sanitize_script_for_log "$script" >>"$LOG_FILE"
  log "--- Script end ---"

  local passfile
  passfile=$(_ssh_get_passfile)

  local output_file
  output_file=$(mktemp)
  register_temp_file "$output_file"

  local cmd_timeout="${SSH_COMMAND_TIMEOUT:-$SSH_DEFAULT_TIMEOUT}"

  # shellcheck disable=SC2086
  printf '%s\n' "$script" | timeout "$cmd_timeout" sshpass -f "$passfile" ssh -p "$SSH_PORT" $SSH_OPTS root@localhost 'bash -s' >"$output_file" 2>&1 &
  local pid=$!
  show_progress $pid "$message" "$done_message"
  local exit_code=$?

  # Check output for critical errors (exclude package names like liberror-perl)
  # Use word boundaries and exclude common false positives from apt output
  if grep -iE '\b(error|failed|cannot|unable|fatal)\b' "$output_file" 2>/dev/null \
    | grep -qivE '(lib.*error|error-perl|\.deb|Unpacking|Setting up|Selecting)'; then
    log "WARNING: Potential errors in remote command output:"
    grep -iE '\b(error|failed|cannot|unable|fatal)\b' "$output_file" 2>/dev/null \
      | grep -ivE '(lib.*error|error-perl|\.deb|Unpacking|Setting up|Selecting)' >>"$LOG_FILE" || true
  fi

  cat "$output_file" >>"$LOG_FILE"
  rm -f "$output_file"

  if [[ $exit_code -ne 0 ]]; then
    log "_remote_exec_with_progress: FAILED with exit code $exit_code"
  else
    log "_remote_exec_with_progress: completed successfully"
  fi

  return $exit_code
}

# Executes remote script with progress, exits on failure.
# PRIMARY function for all configuration scripts - use this by default.
# Shows progress spinner to user and logs output for debugging.
# Parameters:
#   $1 - Progress message (shown while running)
#   $2 - Script content to execute (can be multi-line heredoc)
#   $3 - Done message (optional, defaults to $1)
# Side effects: Exits with code 1 on failure (no need to check return)
# Example:
#   remote_run "Installing packages" 'apt-get install -y foo' "Packages installed"
remote_run() {
  local message="$1"
  local script="$2"
  local done_message="${3:-$message}"

  if ! _remote_exec_with_progress "$message" "$script" "$done_message"; then
    log "ERROR: $message failed"
    exit 1
  fi
}

# Copies file to remote VM via SCP.
# Use for deploying config files. For templates with vars, use deploy_template().
# Parameters:
#   $1 - Source file path (local)
#   $2 - Destination path (remote)
# Returns: 0 on success, 1 on failure (check manually: || return 1)
# Example:
#   remote_copy "templates/foo.conf" "/etc/foo.conf" || return 1
remote_copy() {
  local src="$1"
  local dst="$2"

  local passfile
  passfile=$(_ssh_get_passfile)

  # shellcheck disable=SC2086
  if ! sshpass -f "$passfile" scp -P "$SSH_PORT" $SSH_OPTS "$src" "root@localhost:$dst"; then
    log "ERROR: Failed to copy $src to $dst"
    return 1
  fi
}
