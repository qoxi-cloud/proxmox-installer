# shellcheck shell=bash
# shellcheck disable=SC2034
# =============================================================================
# Tests for 311-configure-fail2ban.sh
# =============================================================================

%const SCRIPTS_DIR: "${SHELLSPEC_PROJECT_ROOT}/scripts"
%const SUPPORT_DIR: "${SHELLSPEC_PROJECT_ROOT}/spec/support"

# Load shared mocks
eval "$(cat "$SUPPORT_DIR/configure_mocks.sh")"

# Additional mocks for fail2ban
apply_template_vars() { return 0; }

Describe "311-configure-fail2ban.sh"
  Include "$SCRIPTS_DIR/311-configure-fail2ban.sh"

  # ===========================================================================
  # _config_fail2ban()
  # ===========================================================================
  Describe "_config_fail2ban()"
    It "deploys jail config and filter"
      EMAIL="test@example.com"
      PVE_HOSTNAME="testhost"
      MOCK_REMOTE_COPY_RESULT=0
      MOCK_REMOTE_EXEC_RESULT=0
      When call _config_fail2ban
      The status should be success
    End

    It "fails when remote_copy fails"
      EMAIL="test@example.com"
      PVE_HOSTNAME="testhost"
      MOCK_REMOTE_COPY_RESULT=1
      When call _config_fail2ban
      The status should be failure
    End
  End
End
