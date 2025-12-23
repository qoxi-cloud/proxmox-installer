# shellcheck shell=bash
# shellcheck disable=SC2034,SC2016
# =============================================================================
# Tests for 003-banner.sh
# =============================================================================
# Note: SC2034 disabled - variables used by ShellSpec assertions
# Note: SC2016 disabled - single quotes in ShellSpec hooks

%const SCRIPTS_DIR: "${SHELLSPEC_PROJECT_ROOT}/scripts"
%const SUPPORT_DIR: "${SHELLSPEC_PROJECT_ROOT}/spec/support"

# Load shared mocks
eval "$(cat "$SUPPORT_DIR/colors.sh")"
eval "$(cat "$SUPPORT_DIR/ui_mocks.sh")"

# Set up terminal constants
TERM_WIDTH=80
BANNER_WIDTH=51
VERSION="2"

Describe "003-banner.sh"
  Include "$SCRIPTS_DIR/003-banner.sh"

  # ===========================================================================
  # Constants
  # ===========================================================================
  Describe "Constants"
    It "defines BANNER_LETTER_COUNT as 7"
      The variable BANNER_LETTER_COUNT should equal 7
    End

    It "defines BANNER_HEIGHT as 9"
      The variable BANNER_HEIGHT should equal 9
    End

    It "defines _BANNER_PAD_SIZE based on terminal width"
      The variable _BANNER_PAD_SIZE should be defined
    End

    It "defines _BANNER_PAD as spaces"
      The variable _BANNER_PAD should be defined
    End
  End

  # ===========================================================================
  # show_banner()
  # ===========================================================================
  Describe "show_banner()"
    It "outputs banner lines"
      When call show_banner
      The output should be present
      The status should be success
    End

    It "includes Proxmox ASCII art"
      When call show_banner
      The output should include "|  __ \\"
    End

    It "includes the tagline with version"
      When call show_banner
      The output should include "Qoxi"
      The output should include "Automated Installer"
    End

    It "includes color codes"
      When call show_banner
      The output should include "$CLR_GRAY"
    End
  End

  # ===========================================================================
  # _show_banner_frame()
  # ===========================================================================
  Describe "_show_banner_frame()"
    It "outputs banner frame"
      When call _show_banner_frame 0
      The output should be present
      The status should be success
    End

    It "accepts letter index -1 (no highlight)"
      When call _show_banner_frame -1
      The output should be present
      The status should be success
    End

    It "accepts letter index 0 (highlight P)"
      When call _show_banner_frame 0
      The output should be present
      The output should include "_____"
    End

    It "accepts letter index 1 (highlight r)"
      When call _show_banner_frame 1
      The output should be present
      The output should include "_ __"
    End

    It "accepts letter index 2 (highlight o)"
      When call _show_banner_frame 2
      The output should be present
      The output should include "___"
    End

    It "accepts letter index 3 (highlight x)"
      When call _show_banner_frame 3
      The output should be present
      The output should include "__  __"
    End

    It "accepts letter index 4 (highlight m)"
      When call _show_banner_frame 4
      The output should be present
      The output should include "_ __ ___"
    End

    It "accepts letter index 5 (highlight second o)"
      When call _show_banner_frame 5
      The output should be present
      The output should include "___"
    End

    It "accepts letter index 6 (highlight second x)"
      When call _show_banner_frame 6
      The output should be present
      The output should include "__  __"
    End

    It "includes clear screen escape sequence"
      When call _show_banner_frame 0
      # \033[H\033[J is cursor home + clear screen
      The output should include $'\033[H\033[J'
    End

    It "includes tagline with version"
      When call _show_banner_frame 3
      The output should include "Qoxi"
      The output should include "Automated Installer"
    End

    It "defaults to -1 when no argument provided"
      When call _show_banner_frame
      The output should be present
      The status should be success
    End
  End

  # ===========================================================================
  # show_banner_animated_start()
  # ===========================================================================
  Describe "show_banner_animated_start()"
    AfterEach 'show_banner_animated_stop 2>/dev/null; BANNER_ANIMATION_PID=""'

    It "has BANNER_ANIMATION_PID initially empty"
      The variable BANNER_ANIMATION_PID should equal ""
    End

    It "returns early when stdout is not a terminal"
      # Pipe to cat breaks -t 1 test
      result=$(show_banner_animated_start 2>&1 | cat)
      When call echo "$result"
      The output should be blank
    End
  End

  # ===========================================================================
  # show_banner_animated_stop()
  # ===========================================================================
  Describe "show_banner_animated_stop()"
    It "handles empty BANNER_ANIMATION_PID gracefully"
      BANNER_ANIMATION_PID=""
      When call show_banner_animated_stop
      The status should be success
      The output should be present
    End

    It "clears BANNER_ANIMATION_PID"
      BANNER_ANIMATION_PID="12345"
      When call show_banner_animated_stop
      The variable BANNER_ANIMATION_PID should equal ""
      The output should be present
    End

    It "handles invalid PID gracefully"
      BANNER_ANIMATION_PID="99999999"
      When call show_banner_animated_stop
      The status should be success
      The variable BANNER_ANIMATION_PID should equal ""
      The output should be present
    End

    It "shows static banner after stopping"
      BANNER_ANIMATION_PID=""
      When call show_banner_animated_stop
      The output should include "Qoxi"
      The output should include "Automated Installer"
    End
  End
End
