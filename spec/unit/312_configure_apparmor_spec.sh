# shellcheck shell=bash
# shellcheck disable=SC2034
# =============================================================================
# Tests for 312-configure-apparmor.sh
# =============================================================================

%const SCRIPTS_DIR: "${SHELLSPEC_PROJECT_ROOT}/scripts"
%const SUPPORT_DIR: "${SHELLSPEC_PROJECT_ROOT}/spec/support"

# Load shared mocks
eval "$(cat "$SUPPORT_DIR/configure_mocks.sh")"

Describe "312-configure-apparmor.sh"
  Include "$SCRIPTS_DIR/312-configure-apparmor.sh"

  # ===========================================================================
  # _config_apparmor()
  # ===========================================================================
  Describe "_config_apparmor()"
    It "configures grub and enables service"
      MOCK_REMOTE_EXEC_RESULT=0
      MOCK_REMOTE_COPY_RESULT=0
      When call _config_apparmor
      The status should be success
    End

    It "fails when remote_exec fails"
      MOCK_REMOTE_EXEC_RESULT=1
      When call _config_apparmor
      The status should be failure
    End
  End
End
