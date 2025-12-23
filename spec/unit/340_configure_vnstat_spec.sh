# shellcheck shell=bash
# shellcheck disable=SC2034
# =============================================================================
# Tests for 340-configure-vnstat.sh
# =============================================================================

%const SCRIPTS_DIR: "${SHELLSPEC_PROJECT_ROOT}/scripts"
%const SUPPORT_DIR: "${SHELLSPEC_PROJECT_ROOT}/spec/support"

# Load shared mocks
eval "$(cat "$SUPPORT_DIR/configure_mocks.sh")"

Describe "340-configure-vnstat.sh"
  Include "$SCRIPTS_DIR/340-configure-vnstat.sh"

  # ===========================================================================
  # _config_vnstat()
  # ===========================================================================
  Describe "_config_vnstat()"
    BeforeEach 'MOCK_REMOTE_COPY_RESULT=0; MOCK_REMOTE_EXEC_RESULT=0; INTERFACE_NAME=""'

    # -------------------------------------------------------------------------
    # Interface name handling
    # -------------------------------------------------------------------------
    Describe "interface name handling"
      It "uses INTERFACE_NAME when set"
        INTERFACE_NAME="enp3s0"
        deploy_template_called_with=""
        deploy_template() {
          deploy_template_called_with="$*"
          return 0
        }
        When call _config_vnstat
        The status should be success
        The variable deploy_template_called_with should include "INTERFACE_NAME=enp3s0"
      End

      It "defaults to eth0 when INTERFACE_NAME is empty"
        INTERFACE_NAME=""
        deploy_template_called_with=""
        deploy_template() {
          deploy_template_called_with="$*"
          return 0
        }
        When call _config_vnstat
        The status should be success
        The variable deploy_template_called_with should include "INTERFACE_NAME=eth0"
      End

      It "defaults to eth0 when INTERFACE_NAME is unset"
        unset INTERFACE_NAME
        deploy_template_called_with=""
        deploy_template() {
          deploy_template_called_with="$*"
          return 0
        }
        When call _config_vnstat
        The status should be success
        The variable deploy_template_called_with should include "INTERFACE_NAME=eth0"
      End
    End

    # -------------------------------------------------------------------------
    # Template deployment
    # -------------------------------------------------------------------------
    Describe "template deployment"
      It "deploys vnstat.conf template to /etc/vnstat.conf"
        deploy_template_args=""
        deploy_template() {
          deploy_template_args="$1 $2"
          return 0
        }
        When call _config_vnstat
        The status should be success
        The variable deploy_template_args should equal "templates/vnstat.conf /etc/vnstat.conf"
      End

      It "fails when deploy_template fails"
        MOCK_REMOTE_COPY_RESULT=1
        When call _config_vnstat
        The status should be failure
      End
    End

    # -------------------------------------------------------------------------
    # Remote execution
    # -------------------------------------------------------------------------
    Describe "remote execution"
      It "creates /var/lib/vnstat directory"
        remote_exec_command=""
        remote_exec() {
          remote_exec_command="$1"
          return 0
        }
        When call _config_vnstat
        The status should be success
        The variable remote_exec_command should include "mkdir -p /var/lib/vnstat"
      End

      It "adds main interface to vnstat monitoring"
        INTERFACE_NAME="eno1"
        remote_exec_command=""
        remote_exec() {
          remote_exec_command="$1"
          return 0
        }
        When call _config_vnstat
        The status should be success
        The variable remote_exec_command should include "vnstat --add -i 'eno1'"
      End

      It "adds bridge interfaces vmbr0 and vmbr1 if they exist"
        remote_exec_command=""
        remote_exec() {
          remote_exec_command="$1"
          return 0
        }
        When call _config_vnstat
        The status should be success
        The variable remote_exec_command should include "vmbr0"
        The variable remote_exec_command should include "vmbr1"
      End

      It "enables vnstat service"
        remote_exec_command=""
        remote_exec() {
          remote_exec_command="$1"
          return 0
        }
        When call _config_vnstat
        The status should be success
        The variable remote_exec_command should include "systemctl enable vnstat"
      End

      It "fails when remote_exec fails"
        MOCK_REMOTE_EXEC_RESULT=1
        When call _config_vnstat
        The status should be failure
      End

      It "logs error when remote_exec fails"
        log_message=""
        log() { log_message="$*"; }
        MOCK_REMOTE_EXEC_RESULT=1
        When call _config_vnstat
        The status should be failure
        The variable log_message should include "ERROR"
        The variable log_message should include "vnstat"
      End
    End

    # -------------------------------------------------------------------------
    # Parallel execution marker
    # -------------------------------------------------------------------------
    Describe "parallel execution marker"
      It "calls parallel_mark_configured on success"
        marked_as=""
        parallel_mark_configured() { marked_as="$1"; }
        When call _config_vnstat
        The status should be success
        The variable marked_as should equal "vnstat"
      End

      It "does not call parallel_mark_configured on deploy_template failure"
        MOCK_REMOTE_COPY_RESULT=1
        marked_as=""
        parallel_mark_configured() { marked_as="$1"; }
        When call _config_vnstat
        The status should be failure
        The variable marked_as should equal ""
      End

      It "does not call parallel_mark_configured on remote_exec failure"
        MOCK_REMOTE_EXEC_RESULT=1
        marked_as=""
        parallel_mark_configured() { marked_as="$1"; }
        When call _config_vnstat
        The status should be failure
        The variable marked_as should equal ""
      End
    End

    # -------------------------------------------------------------------------
    # Success case
    # -------------------------------------------------------------------------
    Describe "success case"
      It "deploys config and initializes interfaces"
        INTERFACE_NAME="eth0"
        When call _config_vnstat
        The status should be success
      End
    End
  End

  # ===========================================================================
  # configure_vnstat() - public wrapper
  # ===========================================================================
  Describe "configure_vnstat()"
    BeforeEach 'MOCK_REMOTE_COPY_RESULT=0; MOCK_REMOTE_EXEC_RESULT=0; INTERFACE_NAME="eth0"'

    # -------------------------------------------------------------------------
    # Skip conditions
    # -------------------------------------------------------------------------
    Describe "skip conditions"
      It "skips when INSTALL_VNSTAT is not yes"
        INSTALL_VNSTAT="no"
        config_called=false
        _config_vnstat() { config_called=true; return 0; }
        When call configure_vnstat
        The status should be success
        The variable config_called should equal false
      End

      It "skips when INSTALL_VNSTAT is unset"
        unset INSTALL_VNSTAT
        config_called=false
        _config_vnstat() { config_called=true; return 0; }
        When call configure_vnstat
        The status should be success
        The variable config_called should equal false
      End

      It "skips when INSTALL_VNSTAT is empty"
        INSTALL_VNSTAT=""
        config_called=false
        _config_vnstat() { config_called=true; return 0; }
        When call configure_vnstat
        The status should be success
        The variable config_called should equal false
      End

      It "skips when INSTALL_VNSTAT is YES (case sensitive)"
        INSTALL_VNSTAT="YES"
        config_called=false
        _config_vnstat() { config_called=true; return 0; }
        When call configure_vnstat
        The status should be success
        The variable config_called should equal false
      End
    End

    # -------------------------------------------------------------------------
    # Execution when enabled
    # -------------------------------------------------------------------------
    Describe "execution when enabled"
      It "calls _config_vnstat when INSTALL_VNSTAT is yes"
        INSTALL_VNSTAT="yes"
        config_called=false
        _config_vnstat() { config_called=true; return 0; }
        When call configure_vnstat
        The status should be success
        The variable config_called should equal true
      End

      It "propagates success from _config_vnstat"
        INSTALL_VNSTAT="yes"
        _config_vnstat() { return 0; }
        When call configure_vnstat
        The status should be success
      End

      It "propagates failure from _config_vnstat"
        INSTALL_VNSTAT="yes"
        _config_vnstat() { return 1; }
        When call configure_vnstat
        The status should be failure
      End
    End
  End
End
