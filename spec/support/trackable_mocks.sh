# shellcheck shell=bash
# shellcheck disable=SC2329
# =============================================================================
# Trackable mock functions for advanced testing
# =============================================================================
# Use these mocks when you need to verify that functions were called
# with specific arguments or a specific number of times.
#
# For simple silent mocks, use:
#   - colors.sh (color constants)
#   - core_mocks.sh (log, print_*, show_progress)
#   - ui_mocks.sh (gum, cursor, clear)
#   - network_mocks.sh (wget, download)
#   - configure_mocks.sh (remote_*, deploy_*, apply_template_vars)
#
# Usage:
#   %const SUPPORT_DIR: "${SHELLSPEC_PROJECT_ROOT}/spec/support"
#   eval "$(cat "$SUPPORT_DIR/trackable_mocks.sh")"
#   BeforeEach 'reset_mocks'

# =============================================================================
# Mock call tracking
# =============================================================================
MOCK_CALLS=""
MOCK_CALL_COUNT=0

reset_mocks() {
  MOCK_CALLS=""
  MOCK_CALL_COUNT=0
}

record_mock_call() {
  local func_name="$1"
  shift
  MOCK_CALLS="${MOCK_CALLS}${func_name};"
  MOCK_CALL_COUNT=$((MOCK_CALL_COUNT + 1))
}

mock_was_called() {
  local func_name="$1"
  [[ "$MOCK_CALLS" == *"${func_name};"* ]]
}

# =============================================================================
# Trackable logging mock
# =============================================================================
mock_log() {
  echo "[TEST $(date '+%H:%M:%S')] $*" >>"${LOG_FILE:-/tmp/test.log}"
  record_mock_call "log" "$@"
}

# =============================================================================
# Trackable display mocks
# =============================================================================
mock_print_success() {
  record_mock_call "print_success" "$@"
  echo "SUCCESS: $*"
}

mock_print_error() {
  record_mock_call "print_error" "$@"
  echo "ERROR: $*" >&2
}

mock_print_warning() {
  record_mock_call "print_warning" "$@"
  echo "WARNING: $*"
}

mock_print_info() {
  record_mock_call "print_info" "$@"
  echo "INFO: $*"
}

mock_show_progress() {
  local pid="$1"
  record_mock_call "show_progress" "$@"
  wait "$pid" 2>/dev/null
  return $?
}

# =============================================================================
# Trackable remote execution mocks
# =============================================================================
MOCK_REMOTE_EXEC_RETURN=0
MOCK_REMOTE_EXEC_OUTPUT=""

mock_remote_exec() {
  record_mock_call "remote_exec" "$@"
  [[ -n "$MOCK_REMOTE_EXEC_OUTPUT" ]] && echo "$MOCK_REMOTE_EXEC_OUTPUT"
  return "$MOCK_REMOTE_EXEC_RETURN"
}

mock_remote_copy() {
  record_mock_call "remote_copy" "$@"
  local src="$1"
  local dst="$2"
  if [[ -f "$src" ]]; then
    cp "$src" "${SHELLSPEC_TMPBASE}/$(basename "$dst")"
  fi
  return 0
}

# =============================================================================
# Trackable download mock
# =============================================================================
MOCK_DOWNLOAD_RETURN=0
MOCK_DOWNLOAD_CONTENT="mock content"

mock_download_file() {
  local dest="$1"
  record_mock_call "download_file" "$@"
  echo "$MOCK_DOWNLOAD_CONTENT" >"$dest"
  return "$MOCK_DOWNLOAD_RETURN"
}

# =============================================================================
# Apply trackable mocks - replaces production functions
# =============================================================================
apply_logging_mocks() {
  log() { mock_log "$@"; }
  export -f log
}

apply_display_mocks() {
  print_success() { mock_print_success "$@"; }
  print_error() { mock_print_error "$@"; }
  print_warning() { mock_print_warning "$@"; }
  print_info() { mock_print_info "$@"; }
  show_progress() { mock_show_progress "$@"; }
  export -f print_success print_error print_warning print_info show_progress
}

apply_remote_mocks() {
  remote_exec() { mock_remote_exec "$@"; }
  remote_copy() { mock_remote_copy "$@"; }
  export -f remote_exec remote_copy
}

apply_download_mocks() {
  download_file() { mock_download_file "$@"; }
  export -f download_file
}

apply_all_mocks() {
  apply_logging_mocks
  apply_display_mocks
  apply_remote_mocks
  apply_download_mocks
}
