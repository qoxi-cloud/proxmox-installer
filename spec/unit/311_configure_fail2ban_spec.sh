# shellcheck shell=bash
# shellcheck disable=SC2034
# =============================================================================
# Tests for 311-configure-fail2ban.sh
# =============================================================================

%const SCRIPTS_DIR: "${SHELLSPEC_PROJECT_ROOT}/scripts"
%const SUPPORT_DIR: "${SHELLSPEC_PROJECT_ROOT}/spec/support"

# Load shared mocks
eval "$(cat "$SUPPORT_DIR/configure_mocks.sh")"

Describe "311-configure-fail2ban.sh"
  Include "$SCRIPTS_DIR/311-configure-fail2ban.sh"

  # ===========================================================================
  # _config_fail2ban()
  # ===========================================================================
  Describe "_config_fail2ban()"
    BeforeEach 'EMAIL="test@example.com"; PVE_HOSTNAME="testhost"; MOCK_REMOTE_COPY_RESULT=0; MOCK_REMOTE_EXEC_RESULT=0'

    # -------------------------------------------------------------------------
    # Successful deployment
    # -------------------------------------------------------------------------
    Describe "successful deployment"
      It "deploys jail config and filter successfully"
        When call _config_fail2ban
        The status should be success
      End

      It "passes EMAIL to deploy_template"
        deploy_template_args=""
        deploy_template() {
          deploy_template_args="$*"
          return 0
        }
        remote_copy() { return 0; }
        remote_enable_services() { return 0; }
        EMAIL="admin@myserver.com"
        When call _config_fail2ban
        The status should be success
        The variable deploy_template_args should include "EMAIL=admin@myserver.com"
      End

      It "passes HOSTNAME to deploy_template"
        deploy_template_args=""
        deploy_template() {
          deploy_template_args="$*"
          return 0
        }
        remote_copy() { return 0; }
        remote_enable_services() { return 0; }
        PVE_HOSTNAME="myproxmox"
        When call _config_fail2ban
        The status should be success
        The variable deploy_template_args should include "HOSTNAME=myproxmox"
      End

      It "deploys to /etc/fail2ban/jail.local"
        deploy_target=""
        deploy_template() {
          deploy_target="$2"
          return 0
        }
        remote_copy() { return 0; }
        remote_enable_services() { return 0; }
        When call _config_fail2ban
        The status should be success
        The variable deploy_target should equal "/etc/fail2ban/jail.local"
      End

      It "deploys proxmox filter to correct path"
        filter_target=""
        deploy_template() { return 0; }
        remote_copy() {
          filter_target="$2"
          return 0
        }
        remote_enable_services() { return 0; }
        When call _config_fail2ban
        The status should be success
        The variable filter_target should equal "/etc/fail2ban/filter.d/proxmox.conf"
      End

      It "uses correct template source for filter"
        filter_source=""
        deploy_template() { return 0; }
        remote_copy() {
          filter_source="$1"
          return 0
        }
        remote_enable_services() { return 0; }
        When call _config_fail2ban
        The status should be success
        The variable filter_source should include "fail2ban-proxmox.conf"
      End
    End

    # -------------------------------------------------------------------------
    # Service enablement
    # -------------------------------------------------------------------------
    Describe "service enablement"
      It "calls remote_enable_services for fail2ban"
        enabled_service=""
        deploy_template() { return 0; }
        remote_copy() { return 0; }
        remote_enable_services() {
          enabled_service="$1"
          return 0
        }
        When call _config_fail2ban
        The status should be success
        The variable enabled_service should equal "fail2ban"
      End

      It "calls parallel_mark_configured with fail2ban"
        marked_feature=""
        deploy_template() { return 0; }
        remote_copy() { return 0; }
        remote_enable_services() { return 0; }
        parallel_mark_configured() { marked_feature="$1"; }
        When call _config_fail2ban
        The status should be success
        The variable marked_feature should equal "fail2ban"
      End
    End

    # -------------------------------------------------------------------------
    # Error handling - deploy_template failure
    # -------------------------------------------------------------------------
    Describe "deploy_template failure"
      It "fails when deploy_template fails"
        MOCK_REMOTE_COPY_RESULT=1
        When call _config_fail2ban
        The status should be failure
      End

      It "does not call remote_copy when deploy_template fails"
        deploy_template() { return 1; }
        remote_copy_called=false
        remote_copy() {
          remote_copy_called=true
          return 0
        }
        When call _config_fail2ban
        The status should be failure
        The variable remote_copy_called should equal false
      End

      It "does not enable service when deploy_template fails"
        deploy_template() { return 1; }
        enable_called=false
        remote_enable_services() {
          enable_called=true
          return 0
        }
        When call _config_fail2ban
        The status should be failure
        The variable enable_called should equal false
      End
    End

    # -------------------------------------------------------------------------
    # Error handling - remote_copy failure
    # -------------------------------------------------------------------------
    Describe "remote_copy failure"
      It "fails when remote_copy for filter fails"
        deploy_template() { return 0; }
        remote_copy() { return 1; }
        When call _config_fail2ban
        The status should be failure
      End

      It "logs error when remote_copy fails"
        deploy_template() { return 0; }
        remote_copy() { return 1; }
        log_message=""
        log() { log_message="$*"; }
        When call _config_fail2ban
        The status should be failure
        The variable log_message should include "ERROR"
        The variable log_message should include "fail2ban filter"
      End

      It "does not enable service when remote_copy fails"
        deploy_template() { return 0; }
        remote_copy() { return 1; }
        enable_called=false
        remote_enable_services() {
          enable_called=true
          return 0
        }
        When call _config_fail2ban
        The status should be failure
        The variable enable_called should equal false
      End

      It "does not mark configured when remote_copy fails"
        deploy_template() { return 0; }
        remote_copy() { return 1; }
        mark_called=false
        parallel_mark_configured() { mark_called=true; }
        When call _config_fail2ban
        The status should be failure
        The variable mark_called should equal false
      End
    End

    # -------------------------------------------------------------------------
    # Edge cases
    # -------------------------------------------------------------------------
    Describe "edge cases"
      It "handles empty EMAIL"
        EMAIL=""
        When call _config_fail2ban
        The status should be success
      End

      It "handles empty PVE_HOSTNAME"
        PVE_HOSTNAME=""
        When call _config_fail2ban
        The status should be success
      End

      It "handles special characters in EMAIL"
        EMAIL="test+admin@sub.example.com"
        deploy_template_args=""
        deploy_template() {
          deploy_template_args="$*"
          return 0
        }
        remote_copy() { return 0; }
        remote_enable_services() { return 0; }
        When call _config_fail2ban
        The status should be success
        The variable deploy_template_args should include "EMAIL=test+admin@sub.example.com"
      End
    End
  End

  # ===========================================================================
  # configure_fail2ban() - public wrapper
  # ===========================================================================
  Describe "configure_fail2ban()"
    BeforeEach 'EMAIL="test@example.com"; PVE_HOSTNAME="testhost"; MOCK_REMOTE_COPY_RESULT=0; MOCK_REMOTE_EXEC_RESULT=0'

    # -------------------------------------------------------------------------
    # Skip conditions - INSTALL_FIREWALL
    # -------------------------------------------------------------------------
    Describe "skip when firewall not enabled"
      It "skips when INSTALL_FIREWALL is not yes"
        INSTALL_FIREWALL="no"
        FIREWALL_MODE="standard"
        config_called=false
        _config_fail2ban() { config_called=true; return 0; }
        When call configure_fail2ban
        The status should be success
        The variable config_called should equal false
      End

      It "skips when INSTALL_FIREWALL is unset"
        unset INSTALL_FIREWALL
        FIREWALL_MODE="standard"
        config_called=false
        _config_fail2ban() { config_called=true; return 0; }
        When call configure_fail2ban
        The status should be success
        The variable config_called should equal false
      End

      It "skips when INSTALL_FIREWALL is empty"
        INSTALL_FIREWALL=""
        FIREWALL_MODE="standard"
        config_called=false
        _config_fail2ban() { config_called=true; return 0; }
        When call configure_fail2ban
        The status should be success
        The variable config_called should equal false
      End

      It "skips when INSTALL_FIREWALL is 'Yes' (case sensitive)"
        INSTALL_FIREWALL="Yes"
        FIREWALL_MODE="standard"
        config_called=false
        _config_fail2ban() { config_called=true; return 0; }
        When call configure_fail2ban
        The status should be success
        The variable config_called should equal false
      End
    End

    # -------------------------------------------------------------------------
    # Skip conditions - stealth mode
    # -------------------------------------------------------------------------
    Describe "skip in stealth mode"
      It "skips when FIREWALL_MODE is stealth"
        INSTALL_FIREWALL="yes"
        FIREWALL_MODE="stealth"
        config_called=false
        _config_fail2ban() { config_called=true; return 0; }
        When call configure_fail2ban
        The status should be success
        The variable config_called should equal false
      End

      It "skips when FIREWALL_MODE is stealth (case as-is)"
        INSTALL_FIREWALL="yes"
        FIREWALL_MODE="stealth"
        config_called=false
        _config_fail2ban() { config_called=true; return 0; }
        When call configure_fail2ban
        The status should be success
        The variable config_called should equal false
      End
    End

    # -------------------------------------------------------------------------
    # Active conditions
    # -------------------------------------------------------------------------
    Describe "configures when enabled"
      It "configures fail2ban when firewall enabled and not stealth"
        INSTALL_FIREWALL="yes"
        FIREWALL_MODE="standard"
        When call configure_fail2ban
        The status should be success
      End

      It "calls _config_fail2ban when conditions met"
        INSTALL_FIREWALL="yes"
        FIREWALL_MODE="standard"
        config_called=false
        _config_fail2ban() { config_called=true; return 0; }
        When call configure_fail2ban
        The status should be success
        The variable config_called should equal true
      End

      It "configures fail2ban when FIREWALL_MODE is unset (defaults to standard)"
        INSTALL_FIREWALL="yes"
        unset FIREWALL_MODE
        config_called=false
        _config_fail2ban() { config_called=true; return 0; }
        When call configure_fail2ban
        The status should be success
        The variable config_called should equal true
      End

      It "configures fail2ban when FIREWALL_MODE is empty (defaults to standard)"
        INSTALL_FIREWALL="yes"
        FIREWALL_MODE=""
        config_called=false
        _config_fail2ban() { config_called=true; return 0; }
        When call configure_fail2ban
        The status should be success
        The variable config_called should equal true
      End

      It "configures fail2ban when FIREWALL_MODE is 'hardened'"
        INSTALL_FIREWALL="yes"
        FIREWALL_MODE="hardened"
        config_called=false
        _config_fail2ban() { config_called=true; return 0; }
        When call configure_fail2ban
        The status should be success
        The variable config_called should equal true
      End

      It "configures fail2ban when FIREWALL_MODE is 'paranoid'"
        INSTALL_FIREWALL="yes"
        FIREWALL_MODE="paranoid"
        config_called=false
        _config_fail2ban() { config_called=true; return 0; }
        When call configure_fail2ban
        The status should be success
        The variable config_called should equal true
      End
    End

    # -------------------------------------------------------------------------
    # Error propagation
    # -------------------------------------------------------------------------
    Describe "error propagation"
      It "propagates failure from _config_fail2ban"
        INSTALL_FIREWALL="yes"
        FIREWALL_MODE="standard"
        MOCK_REMOTE_COPY_RESULT=1
        When call configure_fail2ban
        The status should be failure
      End

      It "returns failure when _config_fail2ban returns 1"
        INSTALL_FIREWALL="yes"
        FIREWALL_MODE="standard"
        _config_fail2ban() { return 1; }
        When call configure_fail2ban
        The status should be failure
      End

      It "returns success when _config_fail2ban returns 0"
        INSTALL_FIREWALL="yes"
        FIREWALL_MODE="standard"
        _config_fail2ban() { return 0; }
        When call configure_fail2ban
        The status should be success
      End
    End

    # -------------------------------------------------------------------------
    # Combined conditions
    # -------------------------------------------------------------------------
    Describe "combined conditions"
      It "skips when both conditions fail (no firewall, stealth mode)"
        INSTALL_FIREWALL="no"
        FIREWALL_MODE="stealth"
        config_called=false
        _config_fail2ban() { config_called=true; return 0; }
        When call configure_fail2ban
        The status should be success
        The variable config_called should equal false
      End

      It "skips when INSTALL_FIREWALL=yes but mode is stealth"
        INSTALL_FIREWALL="yes"
        FIREWALL_MODE="stealth"
        config_called=false
        _config_fail2ban() { config_called=true; return 0; }
        When call configure_fail2ban
        The status should be success
        The variable config_called should equal false
      End

      It "skips when INSTALL_FIREWALL=no but mode is standard"
        INSTALL_FIREWALL="no"
        FIREWALL_MODE="standard"
        config_called=false
        _config_fail2ban() { config_called=true; return 0; }
        When call configure_fail2ban
        The status should be success
        The variable config_called should equal false
      End
    End
  End
End
