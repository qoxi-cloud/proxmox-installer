# shellcheck shell=bash
# shellcheck disable=SC2034,SC2154
# =============================================================================
# Tests for 101-wizard-ui.sh - Core UI Primitives
# =============================================================================
# Note: SC2034 disabled - variables used by ShellSpec assertions
#       SC2154 disabled - variables set by mocks

%const SCRIPTS_DIR: "${SHELLSPEC_PROJECT_ROOT}/scripts"
%const SUPPORT_DIR: "${SHELLSPEC_PROJECT_ROOT}/spec/support"

# Load shared mocks
eval "$(cat "$SUPPORT_DIR/colors.sh")"
eval "$(cat "$SUPPORT_DIR/core_mocks.sh")"
eval "$(cat "$SUPPORT_DIR/ui_mocks.sh")"

# =============================================================================
# Global constants needed by the module
# =============================================================================
TERM_WIDTH=80
WIZ_NOTIFY_INDENT="   "

# Hex colors for gum
HEX_RED="#ff0000"
HEX_CYAN="#00b1ff"
HEX_YELLOW="#ffff00"
HEX_ORANGE="#ff8700"
HEX_GRAY="#585858"
HEX_WHITE="#ffffff"
HEX_NONE="7"

# =============================================================================
# Mocks for external dependencies
# =============================================================================

# Mock tput for terminal operations
tput() {
  case "$1" in
    cols) echo "80" ;;
    lines) echo "24" ;;
    cuu) : ;;
    smcup | rmcup | cnorm | civis) : ;;
    *) : ;;
  esac
}

# Mock gum for UI components
MOCK_GUM_OUTPUT=""
MOCK_GUM_RESULT=0
gum() {
  local cmd="$1"
  shift
  case "$cmd" in
    style)
      # Extract the text (last non-flag argument)
      local text=""
      while [[ $# -gt 0 ]]; do
        case "$1" in
          --*) shift ;;
          *) text="$1"; shift ;;
        esac
      done
      echo "$text"
      ;;
    confirm)
      return $MOCK_GUM_RESULT
      ;;
    choose | filter | input)
      echo "$MOCK_GUM_OUTPUT"
      return $MOCK_GUM_RESULT
      ;;
    *)
      return 0
      ;;
  esac
}

# Mock show_banner
show_banner() { echo "=== BANNER ==="; }

# Mock _show_input_footer
_show_input_footer() { echo "[Footer]"; }

# Mock _wiz_center (from 102-wizard-nav.sh)
_wiz_center() {
  local text="$1"
  echo "$text"
}

# Reset wizard state
reset_wizard_state() {
  MOCK_GUM_OUTPUT=""
  MOCK_GUM_RESULT=0
}

Describe "101-wizard-ui.sh"
  Include "$SCRIPTS_DIR/101-wizard-ui.sh"

  # ===========================================================================
  # _wiz_hide_cursor()
  # ===========================================================================
  Describe "_wiz_hide_cursor()"
    It "outputs ANSI hide cursor sequence"
      When call _wiz_hide_cursor
      The output should include "[?25l"
    End
  End

  # ===========================================================================
  # _wiz_show_cursor()
  # ===========================================================================
  Describe "_wiz_show_cursor()"
    It "outputs ANSI show cursor sequence"
      When call _wiz_show_cursor
      The output should include "[?25h"
    End
  End

  # ===========================================================================
  # _wiz_blank_line()
  # ===========================================================================
  Describe "_wiz_blank_line()"
    It "outputs a newline"
      When call _wiz_blank_line
      The output should equal ""
    End
  End

  # ===========================================================================
  # _wiz_error()
  # ===========================================================================
  Describe "_wiz_error()"
    It "outputs error message with cross icon"
      When call _wiz_error "Something failed"
      The output should include "✗"
      The output should include "Something failed"
    End

    It "handles flags before message"
      When call _wiz_error --bold "Critical error"
      The output should include "Critical error"
    End

    It "handles empty message"
      When call _wiz_error ""
      The output should include "✗"
    End
  End

  # ===========================================================================
  # _wiz_warn()
  # ===========================================================================
  Describe "_wiz_warn()"
    It "outputs warning message"
      When call _wiz_warn "Caution advised"
      The output should include "Caution advised"
    End

    It "handles flags before message"
      When call _wiz_warn --bold "Important warning"
      The output should include "Important warning"
    End
  End

  # ===========================================================================
  # _wiz_info()
  # ===========================================================================
  Describe "_wiz_info()"
    It "outputs info message with checkmark"
      When call _wiz_info "Configuration saved"
      The output should include "✓"
      The output should include "Configuration saved"
    End

    It "handles flags before message"
      When call _wiz_info --bold "Success"
      The output should include "Success"
    End
  End

  # ===========================================================================
  # _wiz_dim()
  # ===========================================================================
  Describe "_wiz_dim()"
    It "outputs dimmed message"
      When call _wiz_dim "Hint text"
      The output should include "Hint text"
    End

    It "handles flags before message"
      When call _wiz_dim --italic "Optional info"
      The output should include "Optional info"
    End
  End

  # ===========================================================================
  # _wiz_description()
  # ===========================================================================
  Describe "_wiz_description()"
    It "outputs multiple lines"
      When call _wiz_description "Line 1" "Line 2" "Line 3"
      The output should include "Line 1"
      The output should include "Line 2"
      The output should include "Line 3"
    End

    It "handles empty lines"
      When call _wiz_description "First" "" "Third"
      The output should include "First"
      The output should include "Third"
    End

    It "replaces {{cyan:text}} with color codes"
      When call _wiz_description "Hello {{cyan:world}}"
      The output should include "world"
      The output should include "$CLR_CYAN"
    End

    It "handles no arguments"
      When call _wiz_description
      The output should equal ""
    End
  End

  # ===========================================================================
  # _wiz_confirm()
  # ===========================================================================
  Describe "_wiz_confirm()"
    BeforeEach 'MOCK_GUM_RESULT=0'

    It "returns success when confirmed"
      MOCK_GUM_RESULT=0
      When call _wiz_confirm "Proceed?"
      The status should be success
      The output should be present
    End

    It "returns failure when declined"
      MOCK_GUM_RESULT=1
      When call _wiz_confirm "Proceed?"
      The status should be failure
      The output should be present
    End

    It "outputs footer text"
      When call _wiz_confirm "Continue?"
      The output should include "toggle"
    End
  End

  # ===========================================================================
  # _wiz_choose()
  # ===========================================================================
  Describe "_wiz_choose()"
    It "returns selected option"
      MOCK_GUM_OUTPUT="option2"
      When call _wiz_choose "option1" "option2" "option3"
      The output should equal "option2"
    End

    It "handles single option"
      MOCK_GUM_OUTPUT="only"
      When call _wiz_choose "only"
      The output should equal "only"
    End

    It "returns first option"
      MOCK_GUM_OUTPUT="option1"
      When call _wiz_choose "option1" "option2" "option3"
      The output should equal "option1"
    End

    It "returns last option"
      MOCK_GUM_OUTPUT="option3"
      When call _wiz_choose "option1" "option2" "option3"
      The output should equal "option3"
    End

    It "handles cancellation"
      MOCK_GUM_OUTPUT=""
      MOCK_GUM_RESULT=1
      When call _wiz_choose "opt1" "opt2"
      The status should be failure
      The output should be blank
    End

    It "handles header flag"
      MOCK_GUM_OUTPUT="item1"
      When call _wiz_choose --header "Select one" "item1" "item2"
      The output should equal "item1"
    End
  End

  # ===========================================================================
  # _wiz_choose_multi()
  # ===========================================================================
  Describe "_wiz_choose_multi()"
    It "returns selected options"
      MOCK_GUM_OUTPUT="opt1
opt3"
      When call _wiz_choose_multi "opt1" "opt2" "opt3"
      The output should include "opt1"
    End

    It "returns multiple selected options"
      MOCK_GUM_OUTPUT="opt1
opt2
opt3"
      When call _wiz_choose_multi "opt1" "opt2" "opt3"
      The output should include "opt1"
      The output should include "opt2"
      The output should include "opt3"
    End

    It "returns empty when nothing selected"
      MOCK_GUM_OUTPUT=""
      When call _wiz_choose_multi "opt1" "opt2"
      The output should equal ""
    End
  End

  # ===========================================================================
  # _wiz_input()
  # ===========================================================================
  Describe "_wiz_input()"
    It "returns user input"
      MOCK_GUM_OUTPUT="user input"
      When call _wiz_input --placeholder "Type here"
      The output should equal "user input"
    End

    It "returns empty when user enters nothing"
      MOCK_GUM_OUTPUT=""
      When call _wiz_input --placeholder "Enter value"
      The output should equal ""
    End

    It "handles input with special characters"
      MOCK_GUM_OUTPUT="test@example.com"
      When call _wiz_input --placeholder "Email"
      The output should equal "test@example.com"
    End

    It "handles cancellation (empty result)"
      MOCK_GUM_OUTPUT=""
      MOCK_GUM_RESULT=1
      When call _wiz_input --value "default"
      The status should be failure
      The output should be blank
    End
  End

  # ===========================================================================
  # _wiz_filter()
  # ===========================================================================
  Describe "_wiz_filter()"
    It "returns selected item from filter"
      MOCK_GUM_OUTPUT="filtered-item"
      When call _wiz_filter
      The output should equal "filtered-item"
    End

    It "returns empty when cancelled"
      MOCK_GUM_OUTPUT=""
      MOCK_GUM_RESULT=1
      When call _wiz_filter
      The status should be failure
      The output should be blank
    End

    It "handles timezone-like values"
      MOCK_GUM_OUTPUT="America/New_York"
      When call _wiz_filter
      The output should equal "America/New_York"
    End
  End

  # ===========================================================================
  # _wiz_clear()
  # ===========================================================================
  Describe "_wiz_clear()"
    It "outputs ANSI clear sequence"
      When call _wiz_clear
      The output should include "[H"
      The output should include "[J"
    End
  End

  # ===========================================================================
  # _wiz_start_edit()
  # ===========================================================================
  Describe "_wiz_start_edit()"
    It "clears screen and shows banner"
      When call _wiz_start_edit
      The output should include "BANNER"
    End
  End

  # ===========================================================================
  # _wiz_input_screen()
  # ===========================================================================
  Describe "_wiz_input_screen()"
    It "shows banner and footer"
      When call _wiz_input_screen
      The output should include "BANNER"
      The output should include "Footer"
    End

    It "shows description lines when provided"
      When call _wiz_input_screen "Description line 1" "Description line 2"
      The output should include "Description line 1"
      The output should include "Description line 2"
    End

    It "handles no description lines"
      When call _wiz_input_screen
      The status should be success
      The output should include "Footer"
    End
  End

  # ===========================================================================
  # _wiz_fmt()
  # ===========================================================================
  Describe "_wiz_fmt()"
    It "returns value when present"
      When call _wiz_fmt "test-value"
      The output should equal "test-value"
    End

    It "returns placeholder when value is empty"
      When call _wiz_fmt ""
      The output should include "→ set value"
    End

    It "uses custom placeholder when provided"
      When call _wiz_fmt "" "→ configure"
      The output should include "→ configure"
    End

    It "includes gray color for placeholder"
      When call _wiz_fmt ""
      The output should include "$CLR_GRAY"
    End
  End

  # ===========================================================================
  # WIZ_NOTIFY_INDENT constant
  # ===========================================================================
  Describe "WIZ_NOTIFY_INDENT constant"
    It "has WIZ_NOTIFY_INDENT set"
      The variable WIZ_NOTIFY_INDENT should be defined
    End
  End
End
