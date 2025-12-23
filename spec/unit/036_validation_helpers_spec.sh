# shellcheck shell=bash
# shellcheck disable=SC2034
# =============================================================================
# Tests for 036-validation-helpers.sh
# =============================================================================

%const SCRIPTS_DIR: "${SHELLSPEC_PROJECT_ROOT}/scripts"
%const SUPPORT_DIR: "${SHELLSPEC_PROJECT_ROOT}/spec/support"

# Load shared mocks
eval "$(cat "$SUPPORT_DIR/colors.sh")"
eval "$(cat "$SUPPORT_DIR/ui_mocks.sh")"

# Override sleep with trackable version
sleep() { mock_sleep "$@"; }

# Reset mocks between tests (combines UI and sleep mock resets)
reset_validation_helper_mocks() {
  reset_wiz_error_mocks
  reset_sleep_mocks
}

Describe "036-validation-helpers.sh"
  Include "$SCRIPTS_DIR/036-validation-helpers.sh"

  # ===========================================================================
  # show_validation_error()
  # ===========================================================================
  Describe "show_validation_error()"
    BeforeEach 'reset_validation_helper_mocks'

    It "hides cursor before displaying error"
      # _wiz_hide_cursor is mocked to no-op in ui_mocks.sh
      When call show_validation_error "Test error"
      The status should be success
    End

    It "displays error message via _wiz_error"
      When call show_validation_error "Invalid hostname"
      The variable MOCK_WIZ_ERROR_CALLED should equal true
      The variable MOCK_WIZ_ERROR_MESSAGE should equal "Invalid hostname"
    End

    It "pauses for 3 seconds after displaying error"
      When call show_validation_error "Test error"
      The variable MOCK_SLEEP_CALLED should equal true
      The variable MOCK_SLEEP_DURATION should equal 3
    End

    It "handles empty message"
      When call show_validation_error ""
      The status should be success
      The variable MOCK_WIZ_ERROR_CALLED should equal true
      The variable MOCK_WIZ_ERROR_MESSAGE should equal ""
    End

    It "handles message with special characters"
      When call show_validation_error "Error: /dev/sda1 not found!"
      The variable MOCK_WIZ_ERROR_MESSAGE should equal "Error: /dev/sda1 not found!"
    End

    It "handles message with quotes"
      When call show_validation_error 'Value "test" is invalid'
      The variable MOCK_WIZ_ERROR_MESSAGE should equal 'Value "test" is invalid'
    End

    It "handles multiword message correctly"
      When call show_validation_error "Multiple word error message here"
      The variable MOCK_WIZ_ERROR_MESSAGE should equal "Multiple word error message here"
    End
  End
End

