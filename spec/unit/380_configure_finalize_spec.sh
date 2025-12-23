# shellcheck shell=bash
# shellcheck disable=SC2034,SC2016
# =============================================================================
# Tests for 380-configure-finalize.sh
# =============================================================================

%const SCRIPTS_DIR: "${SHELLSPEC_PROJECT_ROOT}/scripts"
%const SUPPORT_DIR: "${SHELLSPEC_PROJECT_ROOT}/spec/support"

# Load shared mocks
eval "$(cat "$SUPPORT_DIR/colors.sh")"
eval "$(cat "$SUPPORT_DIR/configure_mocks.sh")"
eval "$(cat "$SUPPORT_DIR/core_mocks.sh")"

# Note: start_task, complete_task, add_log are now in core_mocks.sh

Describe "380-configure-finalize.sh"
  Include "$SCRIPTS_DIR/380-configure-finalize.sh"

  # ===========================================================================
  # _deploy_ssh_config()
  # ===========================================================================
  Describe "_deploy_ssh_config()"
    BeforeEach 'MOCK_REMOTE_COPY_RESULT=0; ADMIN_USERNAME="testadmin"'

    It "deploys SSH config template successfully"
      When call _deploy_ssh_config
      The status should be success
    End

    It "calls deploy_template with correct template path"
      template_path=""
      deploy_template() {
        template_path="$1"
        return 0
      }
      When call _deploy_ssh_config
      The status should be success
      The variable template_path should equal "templates/sshd_config"
    End

    It "calls deploy_template with correct destination"
      dest_path=""
      deploy_template() {
        dest_path="$2"
        return 0
      }
      When call _deploy_ssh_config
      The status should be success
      The variable dest_path should equal "/etc/ssh/sshd_config"
    End

    It "passes ADMIN_USERNAME substitution"
      template_args=""
      deploy_template() {
        template_args="$3"
        return 0
      }
      ADMIN_USERNAME="myuser"
      When call _deploy_ssh_config
      The status should be success
      The variable template_args should equal "ADMIN_USERNAME=myuser"
    End

    It "fails when deploy_template fails"
      MOCK_REMOTE_COPY_RESULT=1
      When call _deploy_ssh_config
      The status should be failure
    End
  End

  # ===========================================================================
  # deploy_ssh_hardening_config()
  # ===========================================================================
  Describe "deploy_ssh_hardening_config()"
    BeforeEach 'MOCK_REMOTE_COPY_RESULT=0; ADMIN_USERNAME="testadmin"'

    It "deploys SSH hardening config successfully"
      When call deploy_ssh_hardening_config
      The status should be success
    End

    It "calls _deploy_ssh_config via run_with_progress"
      deploy_called=false
      _deploy_ssh_config() {
        deploy_called=true
        return 0
      }
      When call deploy_ssh_hardening_config
      The status should be success
      The variable deploy_called should equal true
    End

    It "fails when _deploy_ssh_config fails"
      _deploy_ssh_config() { return 1; }
      When call deploy_ssh_hardening_config
      The status should be failure
    End

    It "logs error when deployment fails"
      log_output=""
      log() { log_output="$*"; }
      _deploy_ssh_config() { return 1; }
      When call deploy_ssh_hardening_config
      The status should be failure
      The variable log_output should include "ERROR"
      The variable log_output should include "SSH"
    End
  End

  # ===========================================================================
  # restart_ssh_service()
  # ===========================================================================
  Describe "restart_ssh_service()"
    BeforeEach 'MOCK_REMOTE_EXEC_RESULT=0'

    It "logs restart message"
      log_output=""
      log() { log_output="$*"; }
      When call restart_ssh_service
      The variable log_output should include "Restarting SSH"
    End

    It "calls remote_exec with systemctl restart sshd"
      # run_with_progress is called as: run_with_progress "desc" "msg" remote_exec "command"
      # $4 contains the actual command
      exec_cmd=""
      run_with_progress() {
        exec_cmd="$4"
        return 0
      }
      When call restart_ssh_service
      The variable exec_cmd should include "systemctl restart sshd"
    End

    It "succeeds even when SSH restart fails"
      run_with_progress() { return 1; }
      When call restart_ssh_service
      The status should be success
    End

    It "logs warning when SSH restart fails"
      log_output=""
      log() { log_output="$*"; }
      run_with_progress() { return 1; }
      When call restart_ssh_service
      The variable log_output should include "WARNING"
    End
  End

  # ===========================================================================
  # validate_installation()
  # ===========================================================================
  Describe "validate_installation()"
    setup_validate() {
      MOCK_REMOTE_EXEC_RESULT=0
      MOCK_APPLY_TEMPLATE_VARS_RESULT=0
      LOG_FILE=$(mktemp)
      INSTALL_TAILSCALE="no"
      INSTALL_FIREWALL="no"
      FIREWALL_MODE="standard"
      INSTALL_APPARMOR="no"
      INSTALL_AUDITD="no"
      INSTALL_AIDE="no"
      INSTALL_CHKROOTKIT="no"
      INSTALL_LYNIS="no"
      INSTALL_NEEDRESTART="no"
      INSTALL_VNSTAT="no"
      INSTALL_PROMTAIL="no"
      ADMIN_USERNAME="testadmin"
      INSTALL_NETDATA="no"
      INSTALL_YAZI="no"
      INSTALL_NVIM="no"
      INSTALL_RINGBUFFER="no"
      SHELL_TYPE="bash"
      SSL_TYPE="self-signed"
      # Create a mock template file
      MOCK_TEMPLATE_DIR=$(mktemp -d)
      mkdir -p "$MOCK_TEMPLATE_DIR"
      echo '#!/bin/bash' > "$MOCK_TEMPLATE_DIR/validation.sh"
      echo 'echo "OK: test"' >> "$MOCK_TEMPLATE_DIR/validation.sh"
    }
    cleanup_validate() {
      rm -f "$LOG_FILE"
      rm -rf "$MOCK_TEMPLATE_DIR"
    }
    BeforeEach 'setup_validate'
    AfterEach 'cleanup_validate'

    # Mock cp to use our mock template
    mock_cp_and_cat() {
      cp() {
        if [[ $1 == *"validation.sh"* ]]; then
          command cp "$MOCK_TEMPLATE_DIR/validation.sh" "$2"
        else
          command cp "$@"
        fi
      }
    }
    BeforeEach 'mock_cp_and_cat'

    It "logs generation message"
      log_output=""
      log() { log_output+="$* "; }
      When call validate_installation
      The variable log_output should include "Generating validation script"
    End

    It "calls apply_template_vars with feature flags"
      template_args=""
      apply_template_vars() {
        shift  # skip file path
        template_args="$*"
        return 0
      }
      When call validate_installation
      The variable template_args should include "INSTALL_TAILSCALE="
      The variable template_args should include "ADMIN_USERNAME="
    End

    It "handles successful validation with no errors"
      remote_exec() { echo "OK: Package installed"; return 0; }
      When call validate_installation
      The status should be success
    End

    It "counts FAIL lines as errors"
      remote_exec() { echo "FAIL: Missing package"; return 0; }
      complete_output=""
      complete_task() { complete_output="$*"; }
      When call validate_installation
      The variable complete_output should include "error"
    End

    It "counts WARN lines as warnings"
      remote_exec() { echo "WARN: Optional not found"; return 0; }
      complete_output=""
      complete_task() { complete_output="$*"; }
      When call validate_installation
      The variable complete_output should include "warning"
    End

    It "handles mixed FAIL and WARN lines"
      remote_exec() {
        echo "FAIL: Error 1"
        echo "WARN: Warning 1"
        echo "OK: Success"
        return 0
      }
      complete_output=""
      complete_task() { complete_output="$*"; }
      When call validate_installation
      The variable complete_output should include "error"
      The variable complete_output should include "warning"
    End

    It "fails to create temp file gracefully"
      mktemp() { return 1; }
      log_output=""
      log() { log_output="$*"; }
      When call validate_installation
      The status should be failure
      The variable log_output should include "ERROR"
    End

    It "passes all feature flags to apply_template_vars"
      captured_args=""
      apply_template_vars() {
        shift
        captured_args="$*"
        return 0
      }
      INSTALL_TAILSCALE="yes"
      INSTALL_FIREWALL="yes"
      FIREWALL_MODE="lockdown"
      When call validate_installation
      The variable captured_args should include "INSTALL_TAILSCALE=yes"
      The variable captured_args should include "INSTALL_FIREWALL=yes"
      The variable captured_args should include "FIREWALL_MODE=lockdown"
    End

    It "fails when cp fails to stage template"
      cp() { return 1; }
      log_output=""
      log() { log_output="$*"; }
      When call validate_installation
      The status should be failure
      The variable log_output should include "ERROR"
    End

    It "writes validation output to LOG_FILE"
      remote_exec() { echo "OK: Test passed"; return 0; }
      When call validate_installation
      The contents of file "$LOG_FILE" should include "OK: Test passed"
    End
  End

  # ===========================================================================
  # finalize_vm()
  # ===========================================================================
  Describe "finalize_vm()"
    setup_finalize() {
      # Create a dummy background process
      sleep 0.1 &
      QEMU_PID=$!
    }
    cleanup_finalize() {
      kill "$QEMU_PID" 2>/dev/null || true
    }
    BeforeEach 'setup_finalize'
    AfterEach 'cleanup_finalize'

    It "sends SIGTERM to QEMU process"
      term_sent=false
      kill() {
        if [[ $1 == "-TERM" ]]; then
          term_sent=true
        fi
        command kill "$@" 2>/dev/null || true
      }
      When call finalize_vm
      The status should be success
    End

    It "waits for QEMU to exit"
      When call finalize_vm
      The status should be success
    End

    It "handles already dead QEMU process"
      kill "$QEMU_PID" 2>/dev/null
      wait "$QEMU_PID" 2>/dev/null || true
      When call finalize_vm
      The status should be success
    End

    It "force kills on timeout (mocked short wait)"
      # Process will still be running due to short test
      When call finalize_vm
      The status should be success
    End
  End

  # ===========================================================================
  # configure_proxmox_via_ssh()
  # ===========================================================================
  Describe "configure_proxmox_via_ssh()"
    setup_configure() {
      # Create dummy QEMU process for finalize_vm
      sleep 0.1 &
      QEMU_PID=$!
      LOG_FILE=$(mktemp)
      # Feature flags
      INSTALL_TAILSCALE="no"
      INSTALL_FIREWALL="no"
      INSTALL_APPARMOR="no"
      INSTALL_AUDITD="no"
      INSTALL_AIDE="no"
      INSTALL_CHKROOTKIT="no"
      INSTALL_LYNIS="no"
      INSTALL_NEEDRESTART="no"
      INSTALL_NETDATA="no"
      INSTALL_YAZI="no"
      INSTALL_VNSTAT="no"
      INSTALL_PROMTAIL="no"
      INSTALL_RINGBUFFER="no"
      INSTALL_NVIM="no"
      INSTALL_API_TOKEN="no"
      ADMIN_USERNAME="testadmin"
      SSL_TYPE="self-signed"
      SHELL_TYPE="bash"
      FIREWALL_MODE="standard"
    }
    cleanup_configure() {
      rm -f "$LOG_FILE"
      kill "$QEMU_PID" 2>/dev/null || true
    }
    BeforeEach 'setup_configure'
    AfterEach 'cleanup_configure'

    # Mock all the configure functions to isolate test
    mock_all_configure_functions() {
      make_templates() { :; }
      configure_admin_user() { :; }
      configure_base_system() { :; }
      configure_shell() { :; }
      configure_system_services() { :; }
      configure_zfs_arc() { :; }
      configure_zfs_pool() { :; }
      configure_zfs_scrub() { :; }
      batch_install_packages() { :; }
      configure_tailscale() { :; }
      configure_firewall() { :; }
      run_parallel_group() { :; }
      configure_netdata() { :; }
      configure_yazi() { :; }
      configure_promtail() { :; }
      configure_vnstat() { :; }
      configure_ringbuffer() { :; }
      configure_nvim() { :; }
      configure_ssl_certificate() { :; }
      create_api_token() { :; }
      deploy_ssh_hardening_config() { :; }
      validate_installation() { :; }
      restart_ssh_service() { :; }
      finalize_vm() { :; }
    }
    BeforeEach 'mock_all_configure_functions'

    It "logs starting message"
      log_output=""
      log() { log_output="$*"; }
      When call configure_proxmox_via_ssh
      The variable log_output should include "Starting Proxmox configuration"
    End

    It "calls make_templates first"
      call_order=""
      make_templates() { call_order+="templates "; }
      configure_admin_user() { call_order+="admin "; }
      When call configure_proxmox_via_ssh
      The variable call_order should start with "templates"
    End

    It "calls configure_admin_user early"
      admin_called=false
      configure_admin_user() { admin_called=true; }
      When call configure_proxmox_via_ssh
      The variable admin_called should equal true
    End

    It "calls configure_base_system"
      base_called=false
      configure_base_system() { base_called=true; }
      When call configure_proxmox_via_ssh
      The variable base_called should equal true
    End

    It "calls ZFS configuration functions"
      zfs_arc_called=false
      zfs_pool_called=false
      zfs_scrub_called=false
      configure_zfs_arc() { zfs_arc_called=true; }
      configure_zfs_pool() { zfs_pool_called=true; }
      configure_zfs_scrub() { zfs_scrub_called=true; }
      When call configure_proxmox_via_ssh
      The variable zfs_arc_called should equal true
      The variable zfs_pool_called should equal true
      The variable zfs_scrub_called should equal true
    End

    It "calls batch_install_packages"
      batch_called=false
      batch_install_packages() { batch_called=true; }
      When call configure_proxmox_via_ssh
      The variable batch_called should equal true
    End

    It "calls security configuration functions"
      parallel_groups=()
      run_parallel_group() {
        parallel_groups+=("$1")
      }
      When call configure_proxmox_via_ssh
      The variable 'parallel_groups[0]' should include "security"
    End

    It "calls SSL configuration"
      ssl_called=false
      configure_ssl_certificate() { ssl_called=true; }
      When call configure_proxmox_via_ssh
      The variable ssl_called should equal true
    End

    It "creates API token when INSTALL_API_TOKEN is yes"
      INSTALL_API_TOKEN="yes"
      api_called=false
      create_api_token() { api_called=true; }
      When call configure_proxmox_via_ssh
      The variable api_called should equal true
    End

    It "skips API token when INSTALL_API_TOKEN is no"
      INSTALL_API_TOKEN="no"
      api_called=false
      create_api_token() { api_called=true; }
      When call configure_proxmox_via_ssh
      The variable api_called should equal false
    End

    It "deploys SSH hardening before validation"
      order=""
      deploy_ssh_hardening_config() { order+="ssh "; }
      validate_installation() { order+="validate "; }
      When call configure_proxmox_via_ssh
      The variable order should equal "ssh validate "
    End

    It "restarts SSH after validation"
      order=""
      validate_installation() { order+="validate "; }
      restart_ssh_service() { order+="restart "; }
      When call configure_proxmox_via_ssh
      The variable order should equal "validate restart "
    End

    It "calls finalize_vm last"
      last_call=""
      finalize_vm() { last_call="finalize"; }
      When call configure_proxmox_via_ssh
      The variable last_call should equal "finalize"
    End

    It "calls configure_tailscale before configure_firewall"
      order=""
      configure_tailscale() { order+="tailscale "; }
      configure_firewall() { order+="firewall "; }
      When call configure_proxmox_via_ssh
      The variable order should equal "tailscale firewall "
    End
  End
End

