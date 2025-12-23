# shellcheck shell=bash
# shellcheck disable=SC2034
# =============================================================================
# Tests for 322-configure-chkrootkit.sh
# =============================================================================

%const SCRIPTS_DIR: "${SHELLSPEC_PROJECT_ROOT}/scripts"
%const SUPPORT_DIR: "${SHELLSPEC_PROJECT_ROOT}/spec/support"

# Load shared mocks
eval "$(cat "$SUPPORT_DIR/configure_mocks.sh")"

Describe "322-configure-chkrootkit.sh"
  Include "$SCRIPTS_DIR/322-configure-chkrootkit.sh"

  # ===========================================================================
  # _config_chkrootkit()
  # ===========================================================================
  Describe "_config_chkrootkit()"
    BeforeEach 'MOCK_REMOTE_EXEC_RESULT=0; MOCK_REMOTE_COPY_RESULT=0'

    # -------------------------------------------------------------------------
    # Successful configuration
    # -------------------------------------------------------------------------
    Describe "successful configuration"
      It "configures chkrootkit successfully"
        When call _config_chkrootkit
        The status should be success
      End

      It "calls deploy_systemd_timer with chkrootkit-scan"
        timer_name=""
        deploy_systemd_timer() {
          timer_name="$1"
          return 0
        }
        When call _config_chkrootkit
        The status should be success
        The variable timer_name should equal "chkrootkit-scan"
      End

      It "creates /var/log/chkrootkit directory"
        mkdir_called=false
        deploy_systemd_timer() { return 0; }
        remote_exec() {
          if [[ $1 == *"/var/log/chkrootkit"* ]]; then
            mkdir_called=true
          fi
          return 0
        }
        When call _config_chkrootkit
        The status should be success
        The variable mkdir_called should equal true
      End

      It "calls parallel_mark_configured on success"
        marked_as=""
        parallel_mark_configured() { marked_as="$1"; }
        When call _config_chkrootkit
        The status should be success
        The variable marked_as should equal "chkrootkit"
      End
    End

    # -------------------------------------------------------------------------
    # Failure handling
    # -------------------------------------------------------------------------
    Describe "failure handling"
      It "fails when deploy_systemd_timer fails"
        MOCK_REMOTE_COPY_RESULT=1
        When call _config_chkrootkit
        The status should be failure
      End

      It "fails when remote_exec (mkdir) fails"
        deploy_systemd_timer() { return 0; }
        remote_exec() { return 1; }
        When call _config_chkrootkit
        The status should be failure
      End

      It "logs error when mkdir fails"
        log_message=""
        log() { log_message="$*"; }
        deploy_systemd_timer() { return 0; }
        remote_exec() { return 1; }
        When call _config_chkrootkit
        The status should be failure
        The variable log_message should include "ERROR"
        The variable log_message should include "chkrootkit"
      End

      It "does not call remote_exec when timer deployment fails"
        MOCK_REMOTE_COPY_RESULT=1
        exec_called=false
        remote_exec() {
          exec_called=true
          return 0
        }
        When call _config_chkrootkit
        The status should be failure
        The variable exec_called should equal false
      End

      It "does not call parallel_mark_configured on timer failure"
        MOCK_REMOTE_COPY_RESULT=1
        marked_as=""
        parallel_mark_configured() { marked_as="$1"; }
        When call _config_chkrootkit
        The status should be failure
        The variable marked_as should equal ""
      End

      It "does not call parallel_mark_configured on mkdir failure"
        deploy_systemd_timer() { return 0; }
        remote_exec() { return 1; }
        marked_as=""
        parallel_mark_configured() { marked_as="$1"; }
        When call _config_chkrootkit
        The status should be failure
        The variable marked_as should equal ""
      End
    End
  End

  # ===========================================================================
  # configure_chkrootkit() - public wrapper
  # ===========================================================================
  Describe "configure_chkrootkit()"
    BeforeEach 'MOCK_REMOTE_EXEC_RESULT=0; MOCK_REMOTE_COPY_RESULT=0'

    # -------------------------------------------------------------------------
    # Skip conditions
    # -------------------------------------------------------------------------
    Describe "skip conditions"
      It "skips when INSTALL_CHKROOTKIT is not yes"
        INSTALL_CHKROOTKIT="no"
        config_called=false
        _config_chkrootkit() { config_called=true; return 0; }
        When call configure_chkrootkit
        The status should be success
        The variable config_called should equal false
      End

      It "skips when INSTALL_CHKROOTKIT is unset"
        unset INSTALL_CHKROOTKIT
        config_called=false
        _config_chkrootkit() { config_called=true; return 0; }
        When call configure_chkrootkit
        The status should be success
        The variable config_called should equal false
      End

      It "skips when INSTALL_CHKROOTKIT is empty"
        INSTALL_CHKROOTKIT=""
        config_called=false
        _config_chkrootkit() { config_called=true; return 0; }
        When call configure_chkrootkit
        The status should be success
        The variable config_called should equal false
      End

      It "skips when INSTALL_CHKROOTKIT is 'Yes' (case sensitive)"
        INSTALL_CHKROOTKIT="Yes"
        config_called=false
        _config_chkrootkit() { config_called=true; return 0; }
        When call configure_chkrootkit
        The status should be success
        The variable config_called should equal false
      End
    End

    # -------------------------------------------------------------------------
    # Execution when enabled
    # -------------------------------------------------------------------------
    Describe "execution when enabled"
      It "configures chkrootkit when INSTALL_CHKROOTKIT is yes"
        INSTALL_CHKROOTKIT="yes"
        config_called=false
        _config_chkrootkit() { config_called=true; return 0; }
        When call configure_chkrootkit
        The status should be success
        The variable config_called should equal true
      End

      It "configures chkrootkit successfully with real function"
        INSTALL_CHKROOTKIT="yes"
        When call configure_chkrootkit
        The status should be success
      End
    End

    # -------------------------------------------------------------------------
    # Error propagation
    # -------------------------------------------------------------------------
    Describe "error propagation"
      It "propagates failure from _config_chkrootkit when timer fails"
        INSTALL_CHKROOTKIT="yes"
        MOCK_REMOTE_COPY_RESULT=1
        When call configure_chkrootkit
        The status should be failure
      End

      It "propagates failure from _config_chkrootkit when mkdir fails"
        INSTALL_CHKROOTKIT="yes"
        deploy_systemd_timer() { return 0; }
        remote_exec() { return 1; }
        When call configure_chkrootkit
        The status should be failure
      End

      It "returns success when _config_chkrootkit succeeds"
        INSTALL_CHKROOTKIT="yes"
        _config_chkrootkit() { return 0; }
        When call configure_chkrootkit
        The status should be success
      End
    End
  End
End
