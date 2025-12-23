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
    BeforeEach 'MOCK_REMOTE_EXEC_RESULT=0'

    # -------------------------------------------------------------------------
    # Successful configuration
    # -------------------------------------------------------------------------
    Describe "successful configuration"
      It "creates vi/vim/editor alternatives successfully"
        When call _config_nvim
        The status should be success
      End

      It "runs update-alternatives for vi"
        exec_cmd=""
        remote_exec() {
          exec_cmd="$1"
          return 0
        }
        When call _config_nvim
        The status should be success
        The variable exec_cmd should include "update-alternatives --install /usr/bin/vi vi"
      End

      It "runs update-alternatives for vim"
        exec_cmd=""
        remote_exec() {
          exec_cmd="$1"
          return 0
        }
        When call _config_nvim
        The status should be success
        The variable exec_cmd should include "update-alternatives --install /usr/bin/vim vim"
      End

      It "runs update-alternatives for editor"
        exec_cmd=""
        remote_exec() {
          exec_cmd="$1"
          return 0
        }
        When call _config_nvim
        The status should be success
        The variable exec_cmd should include "update-alternatives --install /usr/bin/editor editor"
      End

      It "sets nvim as default for all alternatives"
        exec_cmd=""
        remote_exec() {
          exec_cmd="$1"
          return 0
        }
        When call _config_nvim
        The status should be success
        The variable exec_cmd should include "update-alternatives --set vi /usr/bin/nvim"
        The variable exec_cmd should include "update-alternatives --set vim /usr/bin/nvim"
        The variable exec_cmd should include "update-alternatives --set editor /usr/bin/nvim"
      End

      It "calls parallel_mark_configured on success"
        marked_as=""
        parallel_mark_configured() { marked_as="$1"; }
        When call _config_nvim
        The status should be success
        The variable marked_as should equal "nvim"
      End
    End

    # -------------------------------------------------------------------------
    # Failure handling
    # -------------------------------------------------------------------------
    Describe "failure handling"
      It "fails when remote_exec fails"
        MOCK_REMOTE_EXEC_RESULT=1
        When call _config_nvim
        The status should be failure
      End

      It "logs error when remote_exec fails"
        log_message=""
        log() { log_message="$*"; }
        remote_exec() { return 1; }
        When call _config_nvim
        The status should be failure
        The variable log_message should include "ERROR"
        The variable log_message should include "nvim"
      End

      It "does not mark configured on failure"
        MOCK_REMOTE_EXEC_RESULT=1
        marked_as=""
        parallel_mark_configured() { marked_as="$1"; }
        When call _config_nvim
        The status should be failure
        The variable marked_as should equal ""
      End
    End
  End

  # ===========================================================================
  # configure_nvim() - public wrapper
  # ===========================================================================
  Describe "configure_nvim()"
    BeforeEach 'MOCK_REMOTE_EXEC_RESULT=0'

    # -------------------------------------------------------------------------
    # Skip conditions
    # -------------------------------------------------------------------------
    Describe "skip conditions"
      It "skips when INSTALL_NVIM is not yes"
        INSTALL_NVIM="no"
        config_called=false
        _config_nvim() { config_called=true; return 0; }
        When call configure_nvim
        The status should be success
        The variable config_called should equal false
      End

      It "skips when INSTALL_NVIM is unset"
        unset INSTALL_NVIM
        config_called=false
        _config_nvim() { config_called=true; return 0; }
        When call configure_nvim
        The status should be success
        The variable config_called should equal false
      End

      It "skips when INSTALL_NVIM is empty"
        INSTALL_NVIM=""
        config_called=false
        _config_nvim() { config_called=true; return 0; }
        When call configure_nvim
        The status should be success
        The variable config_called should equal false
      End

      It "skips when INSTALL_NVIM is 'Yes' (case sensitive)"
        INSTALL_NVIM="Yes"
        config_called=false
        _config_nvim() { config_called=true; return 0; }
        When call configure_nvim
        The status should be success
        The variable config_called should equal false
      End
    End

    # -------------------------------------------------------------------------
    # Execution when enabled
    # -------------------------------------------------------------------------
    Describe "execution when enabled"
      It "configures nvim when INSTALL_NVIM is yes"
        INSTALL_NVIM="yes"
        config_called=false
        _config_nvim() { config_called=true; return 0; }
        When call configure_nvim
        The status should be success
        The variable config_called should equal true
      End

      It "configures nvim successfully with real function"
        INSTALL_NVIM="yes"
        When call configure_nvim
        The status should be success
      End
    End

    # -------------------------------------------------------------------------
    # Error propagation
    # -------------------------------------------------------------------------
    Describe "error propagation"
      It "propagates failure from _config_nvim"
        INSTALL_NVIM="yes"
        _config_nvim() { return 1; }
        When call configure_nvim
        The status should be failure
      End

      It "returns success when _config_nvim succeeds"
        INSTALL_NVIM="yes"
        _config_nvim() { return 0; }
        When call configure_nvim
        The status should be success
      End

      It "propagates remote_exec failure"
        INSTALL_NVIM="yes"
        MOCK_REMOTE_EXEC_RESULT=1
        When call configure_nvim
        The status should be failure
      End
    End
  End
End
