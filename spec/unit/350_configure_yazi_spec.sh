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
    BeforeEach 'MOCK_REMOTE_EXEC_RESULT=0'

    It "calls remote_exec successfully"
      When call _install_yazi
      The status should be success
    End

    It "fails when remote_exec fails"
      MOCK_REMOTE_EXEC_RESULT=1
      When call _install_yazi
      The status should be failure
    End
  End

  # ===========================================================================
  # _config_yazi()
  # ===========================================================================
  Describe "_config_yazi()"
    BeforeEach 'MOCK_REMOTE_EXEC_RESULT=0; MOCK_REMOTE_COPY_RESULT=0'

    Describe "successful configuration"
      It "completes all steps successfully"
        When call _config_yazi
        The status should be success
      End

      It "deploys yazi theme to correct path"
        deploy_src=""
        deploy_dest=""
        deploy_user_config() {
          deploy_src="$1"
          deploy_dest="$2"
          return 0
        }
        When call _config_yazi
        The status should be success
        The variable deploy_src should equal "templates/yazi-theme.toml"
        The variable deploy_dest should equal ".config/yazi/theme.toml"
      End
    End

    Describe "failure handling"
      It "fails when _install_yazi fails"
        MOCK_REMOTE_EXEC_RESULT=1
        When call _config_yazi
        The status should be failure
      End

      It "fails when deploy_user_config fails"
        MOCK_REMOTE_COPY_RESULT=1
        When call _config_yazi
        The status should be failure
      End

      It "does not deploy theme when install fails"
        MOCK_REMOTE_EXEC_RESULT=1
        deploy_called=false
        deploy_user_config() { deploy_called=true; return 0; }
        When call _config_yazi
        The status should be failure
        The variable deploy_called should equal false
      End

      It "logs error when deploy_user_config fails"
        MOCK_REMOTE_COPY_RESULT=1
        log_message=""
        log() { log_message="$*"; }
        When call _config_yazi
        The status should be failure
        The variable log_message should include "ERROR"
        The variable log_message should include "yazi theme"
      End
    End
  End

  # ===========================================================================
  # configure_yazi() - public wrapper
  # ===========================================================================
  Describe "configure_yazi()"
    BeforeEach 'MOCK_REMOTE_EXEC_RESULT=0; MOCK_REMOTE_COPY_RESULT=0'

    # -------------------------------------------------------------------------
    # Skip conditions
    # -------------------------------------------------------------------------
    Describe "skip conditions"
      It "skips when INSTALL_YAZI is not yes"
        INSTALL_YAZI="no"
        config_called=false
        _config_yazi() { config_called=true; return 0; }
        When call configure_yazi
        The status should be success
        The variable config_called should equal false
      End

      It "skips when INSTALL_YAZI is unset"
        unset INSTALL_YAZI
        config_called=false
        _config_yazi() { config_called=true; return 0; }
        When call configure_yazi
        The status should be success
        The variable config_called should equal false
      End

      It "skips when INSTALL_YAZI is empty"
        INSTALL_YAZI=""
        config_called=false
        _config_yazi() { config_called=true; return 0; }
        When call configure_yazi
        The status should be success
        The variable config_called should equal false
      End

      It "skips when INSTALL_YAZI is 'Yes' (case sensitive)"
        INSTALL_YAZI="Yes"
        config_called=false
        _config_yazi() { config_called=true; return 0; }
        When call configure_yazi
        The status should be success
        The variable config_called should equal false
      End
    End

    # -------------------------------------------------------------------------
    # Execution when enabled
    # -------------------------------------------------------------------------
    Describe "execution when enabled"
      It "configures yazi when INSTALL_YAZI is yes"
        INSTALL_YAZI="yes"
        config_called=false
        _config_yazi() { config_called=true; return 0; }
        When call configure_yazi
        The status should be success
        The variable config_called should equal true
      End

      It "configures yazi successfully with real function"
        INSTALL_YAZI="yes"
        When call configure_yazi
        The status should be success
      End
    End

    # -------------------------------------------------------------------------
    # Error propagation
    # -------------------------------------------------------------------------
    Describe "error propagation"
      It "propagates failure from _config_yazi"
        INSTALL_YAZI="yes"
        _config_yazi() { return 1; }
        When call configure_yazi
        The status should be failure
      End

      It "returns success when _config_yazi succeeds"
        INSTALL_YAZI="yes"
        _config_yazi() { return 0; }
        When call configure_yazi
        The status should be success
      End

      It "propagates specific exit codes"
        INSTALL_YAZI="yes"
        _config_yazi() { return 42; }
        When call configure_yazi
        The status should equal 42
      End
    End
  End
End
