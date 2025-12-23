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
    BeforeEach 'MOCK_REMOTE_EXEC_RESULT=0; MOCK_REMOTE_COPY_RESULT=0'

    # -------------------------------------------------------------------------
    # Successful configuration
    # -------------------------------------------------------------------------
    Describe "successful configuration"
      It "creates config directory and deploys configuration"
        When call _config_needrestart
        The status should be success
      End

      It "creates /etc/needrestart/conf.d directory"
        mkdir_called=false
        remote_exec() {
          if [[ $1 == *"/etc/needrestart/conf.d"* ]]; then
            mkdir_called=true
          fi
          return 0
        }
        When call _config_needrestart
        The status should be success
        The variable mkdir_called should equal true
      End

      It "copies config to correct path"
        copy_dest=""
        remote_copy() {
          copy_dest="$2"
          return 0
        }
        When call _config_needrestart
        The status should be success
        The variable copy_dest should equal "/etc/needrestart/conf.d/50-autorestart.conf"
      End

      It "uses correct template source"
        copy_src=""
        remote_copy() {
          copy_src="$1"
          return 0
        }
        When call _config_needrestart
        The status should be success
        The variable copy_src should include "needrestart.conf"
      End

      It "calls parallel_mark_configured on success"
        marked_as=""
        parallel_mark_configured() { marked_as="$1"; }
        When call _config_needrestart
        The status should be success
        The variable marked_as should equal "needrestart"
      End
    End

    # -------------------------------------------------------------------------
    # Failure handling
    # -------------------------------------------------------------------------
    Describe "failure handling"
      It "fails when remote_copy fails"
        MOCK_REMOTE_COPY_RESULT=1
        When call _config_needrestart
        The status should be failure
      End

      It "logs error when remote_copy fails"
        log_message=""
        log() { log_message="$*"; }
        remote_copy() { return 1; }
        When call _config_needrestart
        The status should be failure
        The variable log_message should include "ERROR"
        The variable log_message should include "needrestart"
      End

      It "does not mark configured on failure"
        MOCK_REMOTE_COPY_RESULT=1
        marked_as=""
        parallel_mark_configured() { marked_as="$1"; }
        When call _config_needrestart
        The status should be failure
        The variable marked_as should equal ""
      End

      It "continues when mkdir remote_exec fails (no error check)"
        exec_call=0
        remote_exec() {
          exec_call=$((exec_call + 1))
          return 1  # mkdir fails
        }
        MOCK_REMOTE_COPY_RESULT=0
        When call _config_needrestart
        The status should be success
      End
    End
  End

  # ===========================================================================
  # configure_needrestart() - public wrapper
  # ===========================================================================
  Describe "configure_needrestart()"
    BeforeEach 'MOCK_REMOTE_EXEC_RESULT=0; MOCK_REMOTE_COPY_RESULT=0'

    # -------------------------------------------------------------------------
    # Skip conditions
    # -------------------------------------------------------------------------
    Describe "skip conditions"
      It "skips when INSTALL_NEEDRESTART is not yes"
        INSTALL_NEEDRESTART="no"
        config_called=false
        _config_needrestart() { config_called=true; return 0; }
        When call configure_needrestart
        The status should be success
        The variable config_called should equal false
      End

      It "skips when INSTALL_NEEDRESTART is unset"
        unset INSTALL_NEEDRESTART
        config_called=false
        _config_needrestart() { config_called=true; return 0; }
        When call configure_needrestart
        The status should be success
        The variable config_called should equal false
      End

      It "skips when INSTALL_NEEDRESTART is empty"
        INSTALL_NEEDRESTART=""
        config_called=false
        _config_needrestart() { config_called=true; return 0; }
        When call configure_needrestart
        The status should be success
        The variable config_called should equal false
      End

      It "skips when INSTALL_NEEDRESTART is 'Yes' (case sensitive)"
        INSTALL_NEEDRESTART="Yes"
        config_called=false
        _config_needrestart() { config_called=true; return 0; }
        When call configure_needrestart
        The status should be success
        The variable config_called should equal false
      End
    End

    # -------------------------------------------------------------------------
    # Execution when enabled
    # -------------------------------------------------------------------------
    Describe "execution when enabled"
      It "configures needrestart when INSTALL_NEEDRESTART is yes"
        INSTALL_NEEDRESTART="yes"
        config_called=false
        _config_needrestart() { config_called=true; return 0; }
        When call configure_needrestart
        The status should be success
        The variable config_called should equal true
      End

      It "configures needrestart successfully with real function"
        INSTALL_NEEDRESTART="yes"
        When call configure_needrestart
        The status should be success
      End
    End

    # -------------------------------------------------------------------------
    # Error propagation
    # -------------------------------------------------------------------------
    Describe "error propagation"
      It "propagates failure from _config_needrestart"
        INSTALL_NEEDRESTART="yes"
        _config_needrestart() { return 1; }
        When call configure_needrestart
        The status should be failure
      End

      It "returns success when _config_needrestart succeeds"
        INSTALL_NEEDRESTART="yes"
        _config_needrestart() { return 0; }
        When call configure_needrestart
        The status should be success
      End

      It "propagates remote_copy failure"
        INSTALL_NEEDRESTART="yes"
        MOCK_REMOTE_COPY_RESULT=1
        When call configure_needrestart
        The status should be failure
      End
    End
  End
End
