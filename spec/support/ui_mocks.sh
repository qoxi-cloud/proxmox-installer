# shellcheck shell=bash
# =============================================================================
# UI mocks for terminal and gum functions
# =============================================================================
#
# Usage in spec files:
#   %const SUPPORT_DIR: "${SHELLSPEC_PROJECT_ROOT}/spec/support"
#   eval "$(cat "$SUPPORT_DIR/ui_mocks.sh")"

# =============================================================================
# Cursor control mocks
# =============================================================================
_wiz_hide_cursor() { :; }
_wiz_show_cursor() { :; }

# =============================================================================
# Terminal control mocks
# =============================================================================
clear() { :; }

# =============================================================================
# Gum mock - handles spin subcommand
# =============================================================================
gum() {
  local subcommand="$1"
  shift
  if [[ "$subcommand" == "spin" ]]; then
    local cmd_arg=""
    while [[ $# -gt 0 ]]; do
      if [[ "$1" == "--" ]]; then
        shift
        cmd_arg="$*"
        break
      fi
      shift
    done
    eval "$cmd_arg" 2>/dev/null || true
  fi
}

# =============================================================================
# tput mock for terminal operations
# =============================================================================
tput() {
  case "$1" in
    lines) echo "40" ;;
    cols) echo "120" ;;
    smcup|rmcup|civis|cnorm) : ;;
    *) : ;;
  esac
}

# =============================================================================
# Display function mocks
# =============================================================================
show_banner() { :; }
format_wizard_header() { echo "[$1]"; }
_wiz_blank_line() { echo ""; }
_wiz_clear() { :; }

# =============================================================================
# Wizard error mocks with tracking
# =============================================================================
MOCK_WIZ_ERROR_CALLED=false
MOCK_WIZ_ERROR_MESSAGE=""

_wiz_error() {
  MOCK_WIZ_ERROR_CALLED=true
  MOCK_WIZ_ERROR_MESSAGE="$*"
}

reset_wiz_error_mocks() {
  MOCK_WIZ_ERROR_CALLED=false
  MOCK_WIZ_ERROR_MESSAGE=""
}

# =============================================================================
# sleep mock to avoid delays in tests
# =============================================================================
MOCK_SLEEP_CALLED=false
MOCK_SLEEP_DURATION=""

mock_sleep() {
  MOCK_SLEEP_CALLED=true
  MOCK_SLEEP_DURATION="$1"
}

reset_sleep_mocks() {
  MOCK_SLEEP_CALLED=false
  MOCK_SLEEP_DURATION=""
}

