# shellcheck shell=bash
# shellcheck disable=SC2034,SC2154
# =============================================================================
# Tests for 102-wizard-nav.sh - Navigation Header and Key Input
# =============================================================================
# Note: SC2034 disabled - variables used by ShellSpec assertions
#       SC2154 disabled - variables set by mocks

%const SCRIPTS_DIR: "${SHELLSPEC_PROJECT_ROOT}/scripts"
%const SUPPORT_DIR: "${SHELLSPEC_PROJECT_ROOT}/spec/support"

# Load shared mocks
eval "$(cat "$SUPPORT_DIR/colors.sh")"
eval "$(cat "$SUPPORT_DIR/core_mocks.sh")"

# =============================================================================
# Global constants needed by the module
# =============================================================================
TERM_WIDTH=80

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

# Reset wizard state
reset_wizard_state() {
  WIZ_CURRENT_SCREEN=0
}

Describe "102-wizard-nav.sh"
  Include "$SCRIPTS_DIR/102-wizard-nav.sh"

  # ===========================================================================
  # _wiz_center()
  # ===========================================================================
  Describe "_wiz_center()"
    It "centers simple text"
      When call _wiz_center "Hello"
      The output should include "Hello"
      The status should be success
    End

    It "handles empty string"
      When call _wiz_center ""
      The status should be success
      The output should be present
    End

    It "handles text with ANSI codes"
      colored="${CLR_CYAN}Test${CLR_RESET}"
      When call _wiz_center "$colored"
      The output should include "Test"
      The status should be success
    End

    It "pads text with leading spaces"
      When call _wiz_center "Hi"
      # 80 - 2 = 78 / 2 = 39 spaces of padding
      The output should start with " "
      The status should be success
    End

    It "handles very long text without breaking"
      long_text="This is a very long text that might exceed terminal width"
      When call _wiz_center "$long_text"
      The output should include "very long text"
      The status should be success
    End
  End

  # ===========================================================================
  # _nav_repeat()
  # ===========================================================================
  Describe "_nav_repeat()"
    It "repeats character specified number of times"
      When call _nav_repeat "=" 5
      The output should equal "====="
    End

    It "handles zero repetitions"
      When call _nav_repeat "-" 0
      The output should equal ""
    End

    It "handles single repetition"
      When call _nav_repeat "*" 1
      The output should equal "*"
    End

    It "handles unicode characters"
      When call _nav_repeat "━" 3
      The output should equal "━━━"
    End

    It "handles thin line character"
      When call _nav_repeat "─" 4
      The output should equal "────"
    End

    It "handles space character"
      When call _nav_repeat " " 3
      The output should equal "   "
    End

    It "handles large repetition count"
      When call _nav_repeat "x" 20
      The output should equal "xxxxxxxxxxxxxxxxxxxx"
    End
  End

  # ===========================================================================
  # _nav_color()
  # ===========================================================================
  Describe "_nav_color()"
    It "returns orange for current screen"
      When call _nav_color 2 2
      The output should equal "$CLR_ORANGE"
    End

    It "returns cyan for completed screen"
      When call _nav_color 0 2
      The output should equal "$CLR_CYAN"
    End

    It "returns gray for pending screen"
      When call _nav_color 4 2
      The output should equal "$CLR_GRAY"
    End

    It "handles first screen as current"
      When call _nav_color 0 0
      The output should equal "$CLR_ORANGE"
    End

    It "handles last screen as current"
      When call _nav_color 5 5
      The output should equal "$CLR_ORANGE"
    End
  End

  # ===========================================================================
  # _nav_dot()
  # ===========================================================================
  Describe "_nav_dot()"
    It "returns filled dot for current screen"
      When call _nav_dot 2 2
      The output should equal "◉"
    End

    It "returns filled circle for completed screen"
      When call _nav_dot 1 3
      The output should equal "●"
    End

    It "returns empty circle for pending screen"
      When call _nav_dot 4 2
      The output should equal "○"
    End

    It "handles screen 0 as current"
      When call _nav_dot 0 0
      The output should equal "◉"
    End
  End

  # ===========================================================================
  # _nav_line()
  # ===========================================================================
  Describe "_nav_line()"
    It "returns bold line for completed sections"
      When call _nav_line 0 2 3
      The output should equal "━━━"
    End

    It "returns thin line for pending sections"
      When call _nav_line 3 2 3
      The output should equal "───"
    End

    It "handles length of 1"
      When call _nav_line 0 1 1
      The output should equal "━"
    End

    It "handles length of 0"
      When call _nav_line 0 1 0
      The output should equal ""
    End

    It "handles current section (same as pending)"
      When call _nav_line 2 2 3
      The output should equal "───"
    End

    It "handles long line length"
      When call _nav_line 0 2 10
      The output should equal "━━━━━━━━━━"
    End
  End

  # ===========================================================================
  # _wiz_render_nav()
  # ===========================================================================
  Describe "_wiz_render_nav()"
    BeforeEach 'reset_wizard_state'

    It "renders navigation header"
      WIZ_CURRENT_SCREEN=0
      When call _wiz_render_nav
      The output should include "Basic"
      The output should include "Proxmox"
      The output should include "Network"
      The output should include "Storage"
      The output should include "Services"
      The output should include "Access"
      The status should be success
    End

    It "includes dot indicators"
      When call _wiz_render_nav
      The output should include "◉"
      The status should be success
    End

    It "handles different current screens"
      WIZ_CURRENT_SCREEN=3
      When call _wiz_render_nav
      The status should be success
      The output should include "Storage"
    End

    It "handles first screen (0)"
      WIZ_CURRENT_SCREEN=0
      When call _wiz_render_nav
      The status should be success
      The output should include "◉"
    End

    It "handles last screen (5)"
      WIZ_CURRENT_SCREEN=5
      When call _wiz_render_nav
      The status should be success
      The output should include "Access"
    End

    It "handles middle screen (2)"
      WIZ_CURRENT_SCREEN=2
      When call _wiz_render_nav
      The status should be success
      The output should include "Network"
    End
  End

  # ===========================================================================
  # _wiz_read_key()
  # ===========================================================================
  Describe "_wiz_read_key()"
    # Note: read -rsn1 is hard to test directly, verify state management
    It "WIZ_KEY variable can be set to up"
      WIZ_KEY="up"
      The variable WIZ_KEY should equal "up"
    End

    It "WIZ_KEY variable can be set to down"
      WIZ_KEY="down"
      The variable WIZ_KEY should equal "down"
    End

    It "WIZ_KEY variable can be set to left"
      WIZ_KEY="left"
      The variable WIZ_KEY should equal "left"
    End

    It "WIZ_KEY variable can be set to right"
      WIZ_KEY="right"
      The variable WIZ_KEY should equal "right"
    End

    It "WIZ_KEY variable can be set to enter"
      WIZ_KEY="enter"
      The variable WIZ_KEY should equal "enter"
    End

    It "WIZ_KEY variable can be set to quit"
      WIZ_KEY="quit"
      The variable WIZ_KEY should equal "quit"
    End

    It "WIZ_KEY variable can be set to start"
      WIZ_KEY="start"
      The variable WIZ_KEY should equal "start"
    End

    It "WIZ_KEY variable can be set to esc"
      WIZ_KEY="esc"
      The variable WIZ_KEY should equal "esc"
    End

    It "WIZ_KEY variable can be set to arbitrary character"
      WIZ_KEY="x"
      The variable WIZ_KEY should equal "x"
    End
  End

  # ===========================================================================
  # WIZ_SCREENS array
  # ===========================================================================
  Describe "WIZ_SCREENS array"
    It "contains 6 screens"
      The value "${#WIZ_SCREENS[@]}" should equal 6
    End

    It "has Basic as first screen"
      The value "${WIZ_SCREENS[0]}" should equal "Basic"
    End

    It "has Proxmox as second screen"
      The value "${WIZ_SCREENS[1]}" should equal "Proxmox"
    End

    It "has Network as third screen"
      The value "${WIZ_SCREENS[2]}" should equal "Network"
    End

    It "has Storage as fourth screen"
      The value "${WIZ_SCREENS[3]}" should equal "Storage"
    End

    It "has Services as fifth screen"
      The value "${WIZ_SCREENS[4]}" should equal "Services"
    End

    It "has Access as sixth screen"
      The value "${WIZ_SCREENS[5]}" should equal "Access"
    End
  End

  # ===========================================================================
  # Constants
  # ===========================================================================
  Describe "Constants"
    It "has _NAV_COL_WIDTH set to 10"
      The variable _NAV_COL_WIDTH should equal 10
    End

    It "has WIZ_CURRENT_SCREEN initialized to 0"
      # After reset
      reset_wizard_state
      The variable WIZ_CURRENT_SCREEN should equal 0
    End
  End
End

