# shellcheck shell=bash
# shellcheck disable=SC2034
# =============================================================================
# Tests for 312-configure-apparmor.sh
# =============================================================================

%const SCRIPTS_DIR: "${SHELLSPEC_PROJECT_ROOT}/scripts"
%const SUPPORT_DIR: "${SHELLSPEC_PROJECT_ROOT}/spec/support"

# Load shared mocks
eval "$(cat "$SUPPORT_DIR/configure_mocks.sh")"

Describe "312-configure-apparmor.sh"
  Include "$SCRIPTS_DIR/312-configure-apparmor.sh"

  # ===========================================================================
  # _config_apparmor()
  # ===========================================================================
  Describe "_config_apparmor()"
    BeforeEach 'MOCK_REMOTE_EXEC_RESULT=0; MOCK_REMOTE_COPY_RESULT=0'

    # -------------------------------------------------------------------------
    # Successful configuration
    # -------------------------------------------------------------------------
    Describe "successful configuration"
      It "configures AppArmor successfully"
        When call _config_apparmor
        The status should be success
      End

      It "creates grub.d directory"
        mkdir_called=false
        remote_exec() {
          if [[ $1 == *"mkdir -p /etc/default/grub.d"* ]]; then
            mkdir_called=true
          fi
          return 0
        }
        When call _config_apparmor
        The status should be success
        The variable mkdir_called should equal true
      End

      It "copies apparmor-grub.cfg to correct path"
        copy_dest=""
        remote_copy() {
          copy_dest="$2"
          return 0
        }
        When call _config_apparmor
        The status should be success
        The variable copy_dest should equal "/etc/default/grub.d/apparmor.cfg"
      End

      It "uses correct template source"
        copy_src=""
        remote_copy() {
          copy_src="$1"
          return 0
        }
        When call _config_apparmor
        The status should be success
        The variable copy_src should include "apparmor-grub.cfg"
      End

      It "runs update-grub"
        update_grub_called=false
        exec_call=0
        remote_exec() {
          exec_call=$((exec_call + 1))
          if [[ $exec_call -eq 2 ]] && [[ $1 == *"update-grub"* ]]; then
            update_grub_called=true
          fi
          return 0
        }
        When call _config_apparmor
        The status should be success
        The variable update_grub_called should equal true
      End

      It "enables apparmor service"
        service_enabled=false
        exec_call=0
        remote_exec() {
          exec_call=$((exec_call + 1))
          if [[ $exec_call -eq 2 ]] && [[ $1 == *"systemctl enable apparmor"* ]]; then
            service_enabled=true
          fi
          return 0
        }
        When call _config_apparmor
        The status should be success
        The variable service_enabled should equal true
      End

      It "calls parallel_mark_configured on success"
        marked_as=""
        parallel_mark_configured() { marked_as="$1"; }
        When call _config_apparmor
        The status should be success
        The variable marked_as should equal "apparmor"
      End
    End

    # -------------------------------------------------------------------------
    # Failure handling
    # -------------------------------------------------------------------------
    Describe "failure handling"
      It "continues when mkdir remote_exec fails (non-critical)"
        exec_call=0
        remote_exec() {
          exec_call=$((exec_call + 1))
          if [[ $exec_call -eq 1 ]]; then
            return 1  # mkdir fails
          fi
          return 0
        }
        When call _config_apparmor
        The status should be success
      End

      It "continues when remote_copy fails (no error handling on this step)"
        MOCK_REMOTE_COPY_RESULT=1
        When call _config_apparmor
        The status should be success
      End

      It "fails when update-grub remote_exec fails"
        exec_call=0
        remote_exec() {
          exec_call=$((exec_call + 1))
          if [[ $exec_call -eq 1 ]]; then
            return 0  # mkdir succeeds
          fi
          return 1  # update-grub fails
        }
        When call _config_apparmor
        The status should be failure
      End

      It "logs error when update-grub fails"
        log_message=""
        log() { log_message="$*"; }
        exec_call=0
        remote_exec() {
          exec_call=$((exec_call + 1))
          [[ $exec_call -eq 1 ]] && return 0
          return 1
        }
        When call _config_apparmor
        The status should be failure
        The variable log_message should include "ERROR"
        The variable log_message should include "AppArmor"
      End

      It "does not mark configured on failure"
        marked_as=""
        parallel_mark_configured() { marked_as="$1"; }
        exec_call=0
        remote_exec() {
          exec_call=$((exec_call + 1))
          [[ $exec_call -eq 1 ]] && return 0
          return 1
        }
        When call _config_apparmor
        The status should be failure
        The variable marked_as should equal ""
      End
    End
  End

  # ===========================================================================
  # configure_apparmor() - public wrapper
  # ===========================================================================
  Describe "configure_apparmor()"
    BeforeEach 'MOCK_REMOTE_EXEC_RESULT=0; MOCK_REMOTE_COPY_RESULT=0'

    # -------------------------------------------------------------------------
    # Skip conditions
    # -------------------------------------------------------------------------
    Describe "skip conditions"
      It "skips when INSTALL_APPARMOR is not yes"
        INSTALL_APPARMOR="no"
        config_called=false
        _config_apparmor() { config_called=true; return 0; }
        When call configure_apparmor
        The status should be success
        The variable config_called should equal false
      End

      It "skips when INSTALL_APPARMOR is unset"
        unset INSTALL_APPARMOR
        config_called=false
        _config_apparmor() { config_called=true; return 0; }
        When call configure_apparmor
        The status should be success
        The variable config_called should equal false
      End

      It "skips when INSTALL_APPARMOR is empty"
        INSTALL_APPARMOR=""
        config_called=false
        _config_apparmor() { config_called=true; return 0; }
        When call configure_apparmor
        The status should be success
        The variable config_called should equal false
      End

      It "skips when INSTALL_APPARMOR is 'Yes' (case sensitive)"
        INSTALL_APPARMOR="Yes"
        config_called=false
        _config_apparmor() { config_called=true; return 0; }
        When call configure_apparmor
        The status should be success
        The variable config_called should equal false
      End

      It "skips when INSTALL_APPARMOR is 'YES'"
        INSTALL_APPARMOR="YES"
        config_called=false
        _config_apparmor() { config_called=true; return 0; }
        When call configure_apparmor
        The status should be success
        The variable config_called should equal false
      End
    End

    # -------------------------------------------------------------------------
    # Execution when enabled
    # -------------------------------------------------------------------------
    Describe "execution when enabled"
      It "configures apparmor when INSTALL_APPARMOR is yes"
        INSTALL_APPARMOR="yes"
        config_called=false
        _config_apparmor() { config_called=true; return 0; }
        When call configure_apparmor
        The status should be success
        The variable config_called should equal true
      End

      It "configures apparmor successfully with real function"
        INSTALL_APPARMOR="yes"
        When call configure_apparmor
        The status should be success
      End
    End

    # -------------------------------------------------------------------------
    # Error propagation
    # -------------------------------------------------------------------------
    Describe "error propagation"
      It "propagates failure from _config_apparmor"
        INSTALL_APPARMOR="yes"
        _config_apparmor() { return 1; }
        When call configure_apparmor
        The status should be failure
      End

      It "returns success when _config_apparmor succeeds"
        INSTALL_APPARMOR="yes"
        _config_apparmor() { return 0; }
        When call configure_apparmor
        The status should be success
      End

      It "propagates specific exit codes"
        INSTALL_APPARMOR="yes"
        _config_apparmor() { return 42; }
        When call configure_apparmor
        The status should equal 42
      End
    End
  End
End
