# shellcheck shell=bash
# shellcheck disable=SC2034
# =============================================================================
# Tests for 320-configure-auditd.sh
# =============================================================================

%const SCRIPTS_DIR: "${SHELLSPEC_PROJECT_ROOT}/scripts"
%const SUPPORT_DIR: "${SHELLSPEC_PROJECT_ROOT}/spec/support"

# Load shared mocks
eval "$(cat "$SUPPORT_DIR/configure_mocks.sh")"

Describe "320-configure-auditd.sh"
  Include "$SCRIPTS_DIR/320-configure-auditd.sh"

  # ===========================================================================
  # _config_auditd()
  # ===========================================================================
  Describe "_config_auditd()"
    It "deploys rules and configures service"
      MOCK_REMOTE_COPY_RESULT=0
      MOCK_REMOTE_EXEC_RESULT=0
      When call _config_auditd
      The status should be success
    End

    It "fails when remote_copy fails"
      MOCK_REMOTE_COPY_RESULT=1
      When call _config_auditd
      The status should be failure
    End
  End
End
