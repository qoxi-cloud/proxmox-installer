# shellcheck shell=bash
# shellcheck disable=SC2034
# =============================================================================
# Tests for 324-configure-needrestart.sh
# =============================================================================

%const SCRIPTS_DIR: "${SHELLSPEC_PROJECT_ROOT}/scripts"
%const SUPPORT_DIR: "${SHELLSPEC_PROJECT_ROOT}/spec/support"

# Load shared mocks
eval "$(cat "$SUPPORT_DIR/configure_mocks.sh")"

Describe "324-configure-needrestart.sh"
  Include "$SCRIPTS_DIR/324-configure-needrestart.sh"

  # ===========================================================================
  # _config_needrestart()
  # ===========================================================================
  Describe "_config_needrestart()"
    It "deploys configuration"
      MOCK_REMOTE_COPY_RESULT=0
      When call _config_needrestart
      The status should be success
    End

    It "fails when remote_copy fails"
      MOCK_REMOTE_COPY_RESULT=1
      When call _config_needrestart
      The status should be failure
    End
  End
End
