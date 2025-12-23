# shellcheck shell=bash
# shellcheck disable=SC2034
# =============================================================================
# Tests for 350-configure-yazi.sh
# =============================================================================

%const SCRIPTS_DIR: "${SHELLSPEC_PROJECT_ROOT}/scripts"
%const SUPPORT_DIR: "${SHELLSPEC_PROJECT_ROOT}/spec/support"

# Load shared mocks
eval "$(cat "$SUPPORT_DIR/configure_mocks.sh")"

Describe "350-configure-yazi.sh"
  Include "$SCRIPTS_DIR/350-configure-yazi.sh"

  # ===========================================================================
  # _install_yazi()
  # ===========================================================================
  Describe "_install_yazi()"
    It "calls remote_run successfully"
      MOCK_REMOTE_RUN_RESULT=0
      When call _install_yazi
      The status should be success
    End
  End

  # ===========================================================================
  # _config_yazi()
  # ===========================================================================
  Describe "_config_yazi()"
    It "configures successfully"
      MOCK_REMOTE_EXEC_RESULT=0
      MOCK_REMOTE_COPY_RESULT=0
      When call _config_yazi
      The status should be success
    End
  End

  # ===========================================================================
  # configure_yazi()
  # ===========================================================================
  Describe "configure_yazi()"
    It "skips when INSTALL_YAZI is not yes"
      INSTALL_YAZI="no"
      When call configure_yazi
      The status should be success
    End

    It "installs when INSTALL_YAZI is yes"
      INSTALL_YAZI="yes"
      MOCK_REMOTE_RUN_RESULT=0
      MOCK_REMOTE_EXEC_RESULT=0
      MOCK_REMOTE_COPY_RESULT=0
      When call configure_yazi
      The status should be success
    End
  End
End
