# shellcheck shell=bash
# shellcheck disable=SC2034
# =============================================================================
# Tests for 323-configure-lynis.sh
# =============================================================================

%const SCRIPTS_DIR: "${SHELLSPEC_PROJECT_ROOT}/scripts"
%const SUPPORT_DIR: "${SHELLSPEC_PROJECT_ROOT}/spec/support"

# Load shared mocks
eval "$(cat "$SUPPORT_DIR/configure_mocks.sh")"

Describe "323-configure-lynis.sh"
  Include "$SCRIPTS_DIR/323-configure-lynis.sh"

  # ===========================================================================
  # _config_lynis()
  # ===========================================================================
  Describe "_config_lynis()"
    BeforeEach 'MOCK_REMOTE_COPY_RESULT=0; MOCK_REMOTE_EXEC_RESULT=0'

    # -------------------------------------------------------------------------
    # Successful configuration
    # -------------------------------------------------------------------------
    Describe "successful configuration"
      It "deploys timer and creates log directory"
        When call _config_lynis
        The status should be success
      End

      It "calls deploy_systemd_timer with lynis-audit"
        timer_name=""
        deploy_systemd_timer() {
          timer_name="$1"
          return 0
        }
        When call _config_lynis
        The status should be success
        The variable timer_name should equal "lynis-audit"
      End

      It "creates /var/log/lynis directory"
        mkdir_called=false
        deploy_systemd_timer() { return 0; }
        remote_exec() {
          if [[ $1 == *"/var/log/lynis"* ]]; then
            mkdir_called=true
          fi
          return 0
        }
        When call _config_lynis
        The status should be success
        The variable mkdir_called should equal true
      End

      It "calls parallel_mark_configured on success"
        marked_as=""
        parallel_mark_configured() { marked_as="$1"; }
        When call _config_lynis
        The status should be success
        The variable marked_as should equal "lynis"
      End
    End

    # -------------------------------------------------------------------------
    # Failure handling
    # -------------------------------------------------------------------------
    Describe "failure handling"
      It "fails when deploy_systemd_timer fails"
        MOCK_REMOTE_COPY_RESULT=1
        When call _config_lynis
        The status should be failure
      End

      It "fails when mkdir for log directory fails"
        deploy_systemd_timer() { return 0; }
        MOCK_REMOTE_EXEC_RESULT=1
        When call _config_lynis
        The status should be failure
      End

      It "logs error when mkdir fails"
        log_message=""
        log() { log_message="$*"; }
        deploy_systemd_timer() { return 0; }
        remote_exec() { return 1; }
        When call _config_lynis
        The status should be failure
        The variable log_message should include "ERROR"
        The variable log_message should include "Lynis"
      End

      It "does not call remote_exec when timer deployment fails"
        MOCK_REMOTE_COPY_RESULT=1
        exec_called=false
        remote_exec() {
          exec_called=true
          return 0
        }
        When call _config_lynis
        The status should be failure
        The variable exec_called should equal false
      End

      It "does not mark configured on timer failure"
        MOCK_REMOTE_COPY_RESULT=1
        marked_as=""
        parallel_mark_configured() { marked_as="$1"; }
        When call _config_lynis
        The status should be failure
        The variable marked_as should equal ""
      End

      It "does not mark configured on mkdir failure"
        deploy_systemd_timer() { return 0; }
        remote_exec() { return 1; }
        marked_as=""
        parallel_mark_configured() { marked_as="$1"; }
        When call _config_lynis
        The status should be failure
        The variable marked_as should equal ""
      End
    End
  End

  # ===========================================================================
  # configure_lynis() - public wrapper
  # ===========================================================================
  Describe "configure_lynis()"
    BeforeEach 'MOCK_REMOTE_COPY_RESULT=0; MOCK_REMOTE_EXEC_RESULT=0'

    # -------------------------------------------------------------------------
    # Skip conditions
    # -------------------------------------------------------------------------
    Describe "skip conditions"
      It "skips when INSTALL_LYNIS is not yes"
        INSTALL_LYNIS="no"
        config_called=false
        _config_lynis() { config_called=true; return 0; }
        When call configure_lynis
        The status should be success
        The variable config_called should equal false
      End

      It "skips when INSTALL_LYNIS is unset"
        unset INSTALL_LYNIS
        config_called=false
        _config_lynis() { config_called=true; return 0; }
        When call configure_lynis
        The status should be success
        The variable config_called should equal false
      End

      It "skips when INSTALL_LYNIS is empty"
        INSTALL_LYNIS=""
        config_called=false
        _config_lynis() { config_called=true; return 0; }
        When call configure_lynis
        The status should be success
        The variable config_called should equal false
      End

      It "skips when INSTALL_LYNIS is 'Yes' (case sensitive)"
        INSTALL_LYNIS="Yes"
        config_called=false
        _config_lynis() { config_called=true; return 0; }
        When call configure_lynis
        The status should be success
        The variable config_called should equal false
      End
    End

    # -------------------------------------------------------------------------
    # Execution when enabled
    # -------------------------------------------------------------------------
    Describe "execution when enabled"
      It "configures lynis when INSTALL_LYNIS is yes"
        INSTALL_LYNIS="yes"
        config_called=false
        _config_lynis() { config_called=true; return 0; }
        When call configure_lynis
        The status should be success
        The variable config_called should equal true
      End

      It "configures lynis successfully with real function"
        INSTALL_LYNIS="yes"
        When call configure_lynis
        The status should be success
      End
    End

    # -------------------------------------------------------------------------
    # Error propagation
    # -------------------------------------------------------------------------
    Describe "error propagation"
      It "propagates failure from _config_lynis"
        INSTALL_LYNIS="yes"
        _config_lynis() { return 1; }
        When call configure_lynis
        The status should be failure
      End

      It "returns success when _config_lynis succeeds"
        INSTALL_LYNIS="yes"
        _config_lynis() { return 0; }
        When call configure_lynis
        The status should be success
      End

      It "propagates timer deployment failure"
        INSTALL_LYNIS="yes"
        MOCK_REMOTE_COPY_RESULT=1
        When call configure_lynis
        The status should be failure
      End

      It "propagates mkdir failure"
        INSTALL_LYNIS="yes"
        deploy_systemd_timer() { return 0; }
        MOCK_REMOTE_EXEC_RESULT=1
        When call configure_lynis
        The status should be failure
      End
    End
  End
End
