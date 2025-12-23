# shellcheck shell=bash
# shellcheck disable=SC2034
# =============================================================================
# Main script mocks for testing 900-main.sh functions
# =============================================================================
#
# Usage in spec files:
#   %const SUPPORT_DIR: "${SHELLSPEC_PROJECT_ROOT}/spec/support"
#   eval "$(cat "$SUPPORT_DIR/main_mocks.sh")"

# =============================================================================
# Banner and display mocks
# =============================================================================
show_banner() { echo "BANNER"; }
format_wizard_header() { echo "=== $1 ==="; }
_wiz_center() { echo "$1"; }
_wiz_clear() { :; }
_wiz_hide_cursor() { :; }
_wiz_show_cursor() { :; }

# =============================================================================
# Installation flow mocks
# =============================================================================
finish_live_installation() { :; }

# =============================================================================
# Gum mocks for main script
# =============================================================================
gum() {
  local subcommand="$1"
  shift
  case "$subcommand" in
    style)
      # Extract just the text (last argument after options)
      local text=""
      while [[ $# -gt 0 ]]; do
        case "$1" in
          --*) shift 2 2>/dev/null || shift ;;
          *) text="$1"; shift ;;
        esac
      done
      echo "$text"
      ;;
    *) : ;;
  esac
}

