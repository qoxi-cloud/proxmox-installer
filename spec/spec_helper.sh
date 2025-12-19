# shellcheck shell=bash
# =============================================================================
# ShellSpec helper - loaded before all tests
# =============================================================================

# Project paths - use SHELLSPEC_PROJECT_ROOT set by shellspec
SPEC_ROOT="${SHELLSPEC_PROJECT_ROOT:-.}"
SCRIPTS_DIR="$SPEC_ROOT/scripts"
TEMPLATES_DIR="$SPEC_ROOT/templates"
export SPEC_ROOT SCRIPTS_DIR TEMPLATES_DIR

# =============================================================================
# Test isolation - temp directory per test
# =============================================================================
spec_helper_configure() {
  # Create temp base if ShellSpec didn't
  SHELLSPEC_TMPBASE="${SHELLSPEC_TMPBASE:-/tmp/shellspec-$$}"
  mkdir -p "$SHELLSPEC_TMPBASE"
  export SHELLSPEC_TMPBASE
}

spec_helper_cleanup() {
  [[ -d "${SHELLSPEC_TMPBASE:-}" ]] && rm -rf "$SHELLSPEC_TMPBASE"
}

# =============================================================================
# Minimal init - colors and globals without side effects
# =============================================================================
mock_minimal_init() {
  # Colors (from 000-init.sh)
  CLR_RED=$'\033[1;31m'
  CLR_CYAN=$'\033[38;2;0;177;255m'
  CLR_YELLOW=$'\033[1;33m'
  CLR_ORANGE=$'\033[38;5;208m'
  CLR_GRAY=$'\033[38;5;240m'
  CLR_RESET=$'\033[m'
  export CLR_RED CLR_CYAN CLR_YELLOW CLR_ORANGE CLR_GRAY CLR_RESET

  # Required globals
  LOG_FILE="${SHELLSPEC_TMPBASE:-/tmp}/test.log"
  touch "$LOG_FILE"
  export LOG_FILE

  # DNS servers for validation tests
  DNS_SERVERS=("1.1.1.1" "8.8.8.8")
  export DNS_SERVERS
}

# =============================================================================
# Source support files
# =============================================================================
# shellcheck source=spec/support/mocks.sh
. "$SPEC_ROOT/spec/support/mocks.sh"
# shellcheck source=spec/support/fixtures.sh
. "$SPEC_ROOT/spec/support/fixtures.sh"

# =============================================================================
# Test helpers
# =============================================================================

# Source a script with mocked dependencies
source_script() {
  local script="$1"
  mock_minimal_init
  # shellcheck source=/dev/null
  . "$SCRIPTS_DIR/$script"
}

# Source script with logging mocks applied
source_script_with_mocks() {
  local script="$1"
  mock_minimal_init
  apply_logging_mocks
  # shellcheck source=/dev/null
  . "$SCRIPTS_DIR/$script"
}

# Create test file in temp directory
create_test_file() {
  local name="$1"
  local content="${2:-}"
  local file="${SHELLSPEC_TMPBASE}/${name}"
  mkdir -p "$(dirname "$file")"
  echo "$content" >"$file"
  echo "$file"
}

# Assert log contains pattern
assert_logged() {
  local pattern="$1"
  grep -q "$pattern" "$LOG_FILE"
}

# Get log contents
get_log_contents() {
  cat "$LOG_FILE"
}

# Clear log file
clear_log() {
  : >"$LOG_FILE"
}
