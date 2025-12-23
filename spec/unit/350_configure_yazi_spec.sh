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
    BeforeEach 'MOCK_REMOTE_RUN_RESULT=0'

    It "calls remote_run successfully"
      When call _install_yazi
      The status should be success
    End

    It "fails when remote_run fails"
      MOCK_REMOTE_RUN_RESULT=1
      When call _install_yazi
      The status should be failure
    End

    It "passes correct arguments to remote_run"
      remote_run_label=""
      remote_run() {
        remote_run_label="$1"
        return 0
      }
      When call _install_yazi
      The status should be success
      The variable remote_run_label should equal "Installing yazi"
    End
  End

  # ===========================================================================
  # _config_yazi()
  # ===========================================================================
  Describe "_config_yazi()"
    BeforeEach 'MOCK_REMOTE_COPY_RESULT=0'

    It "configures successfully"
      When call _config_yazi
      The status should be success
    End

    It "fails when deploy_user_config fails"
      MOCK_REMOTE_COPY_RESULT=1
      When call _config_yazi
      The status should be failure
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

  # ===========================================================================
  # _install_and_config_yazi()
  # ===========================================================================
  Describe "_install_and_config_yazi()"
    BeforeEach 'MOCK_REMOTE_RUN_RESULT=0; MOCK_REMOTE_COPY_RESULT=0'

    It "succeeds when both install and config succeed"
      When call _install_and_config_yazi
      The status should be success
    End

    It "fails when _install_yazi fails"
      MOCK_REMOTE_RUN_RESULT=1
      When call _install_and_config_yazi
      The status should be failure
    End

    It "fails when _config_yazi fails"
      MOCK_REMOTE_COPY_RESULT=1
      When call _install_and_config_yazi
      The status should be failure
    End

    It "does not call _config_yazi when _install_yazi fails"
      MOCK_REMOTE_RUN_RESULT=1
      config_called=""
      # Override _config_yazi to track if it's called
      _config_yazi() { config_called="yes"; return 0; }
      When call _install_and_config_yazi
      The status should be failure
      The variable config_called should equal ""
    End

    It "calls _config_yazi after successful install"
      config_called=""
      _config_yazi() { config_called="yes"; return 0; }
      When call _install_and_config_yazi
      The status should be success
      The variable config_called should equal "yes"
    End
  End

  # ===========================================================================
  # configure_yazi()
  # ===========================================================================
  Describe "configure_yazi()"
    BeforeEach 'MOCK_REMOTE_RUN_RESULT=0; MOCK_REMOTE_COPY_RESULT=0'

    It "skips when INSTALL_YAZI is not yes"
      INSTALL_YAZI="no"
      When call configure_yazi
      The status should be success
    End

    It "skips when INSTALL_YAZI is unset"
      unset INSTALL_YAZI
      When call configure_yazi
      The status should be success
    End

    It "skips when INSTALL_YAZI is empty"
      INSTALL_YAZI=""
      When call configure_yazi
      The status should be success
    End

    It "installs when INSTALL_YAZI is yes"
      INSTALL_YAZI="yes"
      When call configure_yazi
      The status should be success
    End

    It "calls run_with_progress with correct arguments"
      INSTALL_YAZI="yes"
      progress_label=""
      progress_msg=""
      progress_func=""
      run_with_progress() {
        progress_label="$1"
        progress_msg="$2"
        progress_func="$3"
        return 0
      }
      When call configure_yazi
      The status should be success
      The variable progress_label should equal "Installing yazi"
      The variable progress_msg should equal "Yazi configured"
      The variable progress_func should equal "_install_and_config_yazi"
    End

    It "returns success even when run_with_progress fails (non-fatal)"
      INSTALL_YAZI="yes"
      run_with_progress() { return 1; }
      When call configure_yazi
      The status should be success
    End

    It "logs warning when setup fails"
      INSTALL_YAZI="yes"
      logged_msg=""
      log() { logged_msg="$*"; }
      run_with_progress() { return 1; }
      When call configure_yazi
      The status should be success
      The variable logged_msg should include "Yazi setup failed"
    End
  End
End
