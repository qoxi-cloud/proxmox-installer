# shellcheck shell=bash
# shellcheck disable=SC2034
# =============================================================================
# Core mocks for logging and display functions
# =============================================================================
# Note: SC2034 disabled - variables used by spec files
#
# Usage in spec files:
#   %const SUPPORT_DIR: "${SHELLSPEC_PROJECT_ROOT}/spec/support"
#   eval "$(cat "$SUPPORT_DIR/core_mocks.sh")"

# =============================================================================
# kcov detection - use inline test in Skip conditions
# =============================================================================
# Usage: Skip if "running under kcov" test -n "${KCOV_BASH_XTRACEFD:-}"
# Note: Functions defined here are not available at parse time for Skip conditions.
#       Use the inline test command directly in spec files.

# =============================================================================
# Silent logging mock
# =============================================================================
log() { :; }

# =============================================================================
# Silent display mocks
# =============================================================================
print_success() { :; }
print_error() { :; }
print_warning() { :; }
print_info() { :; }

# =============================================================================
# Progress mock - waits for process without spinner
# =============================================================================
show_progress() {
  local pid="$1"
  wait "$pid" 2>/dev/null
  return $?
}

# =============================================================================
# Live logs mocks - silent by default
# =============================================================================
add_log() { :; }
start_task() { TASK_INDEX="${TASK_INDEX:-0}"; }
complete_task() { :; }
log_subtasks() { :; }

# =============================================================================
# Package installation mock
# =============================================================================
install_base_packages() { return 0; }
batch_install_packages() { return 0; }

