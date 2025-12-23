# shellcheck shell=bash
# shellcheck disable=SC2034
# =============================================================================
# Tests for 321-configure-aide.sh
# =============================================================================

%const SCRIPTS_DIR: "${SHELLSPEC_PROJECT_ROOT}/scripts"
%const SUPPORT_DIR: "${SHELLSPEC_PROJECT_ROOT}/spec/support"

# Load shared mocks
eval "$(cat "$SUPPORT_DIR/configure_mocks.sh")"

Describe "321-configure-aide.sh"
  Include "$SCRIPTS_DIR/321-configure-aide.sh"

  # ===========================================================================
  # _config_aide()
  # ===========================================================================
  Describe "_config_aide()"
    BeforeEach 'MOCK_REMOTE_COPY_RESULT=0; MOCK_REMOTE_EXEC_RESULT=0'

    # -------------------------------------------------------------------------
    # Successful deployment
    # -------------------------------------------------------------------------
    Describe "successful deployment"
      It "deploys timer and initializes database"
        When call _config_aide
        The status should be success
      End

      It "calls deploy_systemd_timer with aide-check"
        timer_name=""
        deploy_systemd_timer() {
          timer_name="$1"
          return 0
        }
        When call _config_aide
        The status should be success
        The variable timer_name should equal "aide-check"
      End

      It "runs aideinit command via remote_exec"
        exec_cmd=""
        deploy_systemd_timer() { return 0; }
        remote_exec() {
          exec_cmd="$1"
          return 0
        }
        When call _config_aide
        The status should be success
        The variable exec_cmd should include "aideinit"
      End

      It "moves aide.db.new to aide.db"
        exec_cmd=""
        deploy_systemd_timer() { return 0; }
        remote_exec() {
          exec_cmd="$1"
          return 0
        }
        When call _config_aide
        The status should be success
        The variable exec_cmd should include "aide.db.new"
        The variable exec_cmd should include "aide.db"
      End

      It "calls parallel_mark_configured with aide"
        marked=""
        deploy_systemd_timer() { return 0; }
        parallel_mark_configured() { marked="$1"; }
        When call _config_aide
        The status should be success
        The variable marked should equal "aide"
      End
    End

    # -------------------------------------------------------------------------
    # Error handling - deploy_systemd_timer failure
    # -------------------------------------------------------------------------
    Describe "deploy_systemd_timer failure"
      It "fails when deploy_systemd_timer fails"
        MOCK_REMOTE_COPY_RESULT=1
        When call _config_aide
        The status should be failure
      End

      It "does not call remote_exec when deploy_systemd_timer fails"
        deploy_systemd_timer() { return 1; }
        exec_called=false
        remote_exec() {
          exec_called=true
          return 0
        }
        When call _config_aide
        The status should be failure
        The variable exec_called should equal false
      End

      It "does not mark configured when deploy_systemd_timer fails"
        deploy_systemd_timer() { return 1; }
        mark_called=false
        parallel_mark_configured() { mark_called=true; }
        When call _config_aide
        The status should be failure
        The variable mark_called should equal false
      End
    End

    # -------------------------------------------------------------------------
    # Error handling - remote_exec failure
    # -------------------------------------------------------------------------
    Describe "remote_exec failure"
      It "fails when remote_exec (aideinit) fails"
        deploy_systemd_timer() { return 0; }
        MOCK_REMOTE_EXEC_RESULT=1
        When call _config_aide
        The status should be failure
      End

      It "logs error when remote_exec fails"
        deploy_systemd_timer() { return 0; }
        log_message=""
        log() { log_message="$*"; }
        remote_exec() { return 1; }
        When call _config_aide
        The status should be failure
        The variable log_message should include "ERROR"
        The variable log_message should include "AIDE"
      End

      It "does not mark configured when remote_exec fails"
        deploy_systemd_timer() { return 0; }
        remote_exec() { return 1; }
        mark_called=false
        parallel_mark_configured() { mark_called=true; }
        When call _config_aide
        The status should be failure
        The variable mark_called should equal false
      End
    End
  End

  # ===========================================================================
  # configure_aide() - public wrapper
  # ===========================================================================
  Describe "configure_aide()"
    BeforeEach 'MOCK_REMOTE_COPY_RESULT=0; MOCK_REMOTE_EXEC_RESULT=0'

    # -------------------------------------------------------------------------
    # Skip conditions
    # -------------------------------------------------------------------------
    Describe "skip conditions"
      It "skips when INSTALL_AIDE is not yes"
        INSTALL_AIDE="no"
        config_called=false
        _config_aide() { config_called=true; return 0; }
        When call configure_aide
        The status should be success
        The variable config_called should equal false
      End

      It "skips when INSTALL_AIDE is unset"
        unset INSTALL_AIDE
        config_called=false
        _config_aide() { config_called=true; return 0; }
        When call configure_aide
        The status should be success
        The variable config_called should equal false
      End

      It "skips when INSTALL_AIDE is empty"
        INSTALL_AIDE=""
        config_called=false
        _config_aide() { config_called=true; return 0; }
        When call configure_aide
        The status should be success
        The variable config_called should equal false
      End

      It "skips when INSTALL_AIDE is 'Yes' (case sensitive)"
        INSTALL_AIDE="Yes"
        config_called=false
        _config_aide() { config_called=true; return 0; }
        When call configure_aide
        The status should be success
        The variable config_called should equal false
      End

      It "skips when INSTALL_AIDE is 'YES'"
        INSTALL_AIDE="YES"
        config_called=false
        _config_aide() { config_called=true; return 0; }
        When call configure_aide
        The status should be success
        The variable config_called should equal false
      End
    End

    # -------------------------------------------------------------------------
    # Active conditions
    # -------------------------------------------------------------------------
    Describe "configures when enabled"
      It "configures aide when INSTALL_AIDE is yes"
        INSTALL_AIDE="yes"
        When call configure_aide
        The status should be success
      End

      It "calls _config_aide when INSTALL_AIDE is yes"
        INSTALL_AIDE="yes"
        config_called=false
        _config_aide() { config_called=true; return 0; }
        When call configure_aide
        The status should be success
        The variable config_called should equal true
      End
    End

    # -------------------------------------------------------------------------
    # Error propagation
    # -------------------------------------------------------------------------
    Describe "error propagation"
      It "propagates failure from _config_aide"
        INSTALL_AIDE="yes"
        _config_aide() { return 1; }
        When call configure_aide
        The status should be failure
      End

      It "returns success when _config_aide succeeds"
        INSTALL_AIDE="yes"
        _config_aide() { return 0; }
        When call configure_aide
        The status should be success
      End

      It "propagates failure when deploy fails"
        INSTALL_AIDE="yes"
        MOCK_REMOTE_COPY_RESULT=1
        When call configure_aide
        The status should be failure
      End

      It "propagates failure when remote_exec fails"
        INSTALL_AIDE="yes"
        deploy_systemd_timer() { return 0; }
        MOCK_REMOTE_EXEC_RESULT=1
        When call configure_aide
        The status should be failure
      End
    End
  End
End
