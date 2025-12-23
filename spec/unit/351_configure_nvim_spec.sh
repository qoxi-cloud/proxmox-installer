# shellcheck shell=bash
# shellcheck disable=SC2034
# =============================================================================
# Tests for 351-configure-nvim.sh
# =============================================================================

%const SCRIPTS_DIR: "${SHELLSPEC_PROJECT_ROOT}/scripts"
%const SUPPORT_DIR: "${SHELLSPEC_PROJECT_ROOT}/spec/support"

# Load shared mocks
eval "$(cat "$SUPPORT_DIR/configure_mocks.sh")"

Describe "351-configure-nvim.sh"
  Include "$SCRIPTS_DIR/351-configure-nvim.sh"

  # ===========================================================================
  # _config_nvim()
  # ===========================================================================
  Describe "_config_nvim()"
    It "creates vi/vim alternatives"
      MOCK_REMOTE_EXEC_RESULT=0
      When call _config_nvim
      The status should be success
    End

    It "fails when remote_exec fails"
      MOCK_REMOTE_EXEC_RESULT=1
      When call _config_nvim
      The status should be failure
    End
  End
End
