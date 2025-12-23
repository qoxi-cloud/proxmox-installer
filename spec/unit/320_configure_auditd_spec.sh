# shellcheck shell=bash
# shellcheck disable=SC2034
# =============================================================================
# Tests for 320-configure-auditd.sh
# =============================================================================

%const SCRIPTS_DIR: "${SHELLSPEC_PROJECT_ROOT}/scripts"
%const SUPPORT_DIR: "${SHELLSPEC_PROJECT_ROOT}/spec/support"

# Load shared mocks
eval "$(cat "$SUPPORT_DIR/configure_mocks.sh")"

Describe "320-configure-auditd.sh"
  Include "$SCRIPTS_DIR/320-configure-auditd.sh"

  # ===========================================================================
  # _config_auditd()
  # ===========================================================================
  Describe "_config_auditd()"
    BeforeEach 'MOCK_REMOTE_COPY_RESULT=0; MOCK_REMOTE_EXEC_RESULT=0'

    # -------------------------------------------------------------------------
    # Success scenarios
    # -------------------------------------------------------------------------
    Describe "successful configuration"
      It "deploys rules and configures service successfully"
        When call _config_auditd
        The status should be success
      End

      It "creates rules directory via remote_exec"
        mkdir_called=false
        remote_exec() {
          if [[ $1 == *"mkdir -p /etc/audit/rules.d"* ]]; then
            mkdir_called=true
          fi
          return 0
        }
        When call _config_auditd
        The status should be success
        The variable mkdir_called should equal true
      End

      It "deploys auditd-rules to correct path"
        rules_deployed=false
        rules_path=""
        remote_copy() {
          if [[ $1 == *"auditd-rules"* ]]; then
            rules_deployed=true
            rules_path="$2"
          fi
          return 0
        }
        When call _config_auditd
        The status should be success
        The variable rules_deployed should equal true
        The variable rules_path should equal "/etc/audit/rules.d/proxmox.rules"
      End

      It "configures log settings via sed commands"
        sed_configured=false
        remote_exec() {
          if [[ $1 == *"max_log_file = 50"* ]] && [[ $1 == *"num_logs = 10"* ]]; then
            sed_configured=true
          fi
          return 0
        }
        When call _config_auditd
        The status should be success
        The variable sed_configured should equal true
      End

      It "sets max_log_file_action to ROTATE"
        rotate_configured=false
        remote_exec() {
          if [[ $1 == *"max_log_file_action = ROTATE"* ]]; then
            rotate_configured=true
          fi
          return 0
        }
        When call _config_auditd
        The status should be success
        The variable rotate_configured should equal true
      End

      It "creates /var/log/audit directory"
        log_dir_created=false
        remote_exec() {
          if [[ $1 == *"mkdir -p /var/log/audit"* ]]; then
            log_dir_created=true
          fi
          return 0
        }
        When call _config_auditd
        The status should be success
        The variable log_dir_created should equal true
      End

      It "loads augenrules"
        augenrules_called=false
        remote_exec() {
          if [[ $1 == *"augenrules --load"* ]]; then
            augenrules_called=true
          fi
          return 0
        }
        When call _config_auditd
        The status should be success
        The variable augenrules_called should equal true
      End

      It "enables auditd service"
        service_enabled=false
        remote_enable_services() {
          if [[ $1 == "auditd" ]]; then
            service_enabled=true
          fi
          return 0
        }
        When call _config_auditd
        The status should be success
        The variable service_enabled should equal true
      End

      It "marks configuration as complete"
        marked=false
        parallel_mark_configured() {
          if [[ $1 == "auditd" ]]; then
            marked=true
          fi
        }
        When call _config_auditd
        The status should be success
        The variable marked should equal true
      End
    End

    # -------------------------------------------------------------------------
    # Failure scenarios
    # -------------------------------------------------------------------------
    Describe "failure handling"
      It "fails when remote_copy fails for rules deployment"
        MOCK_REMOTE_COPY_RESULT=1
        When call _config_auditd
        The status should be failure
      End

      It "fails when remote_exec for config fails"
        exec_call=0
        remote_exec() {
          exec_call=$((exec_call + 1))
          # First call (mkdir) succeeds, second (sed config) fails
          [[ $exec_call -eq 2 ]] && return 1
          return 0
        }
        When call _config_auditd
        The status should be failure
      End

      It "logs error when remote_copy fails"
        log_called=false
        log_message=""
        log() {
          log_called=true
          log_message="$*"
        }
        MOCK_REMOTE_COPY_RESULT=1
        When call _config_auditd
        The status should be failure
        The variable log_called should equal true
        The variable log_message should include "Failed to deploy auditd rules"
      End

      It "logs error when remote_exec for config fails"
        log_called=false
        log_message=""
        log() {
          log_called=true
          log_message="$*"
        }
        exec_call=0
        remote_exec() {
          exec_call=$((exec_call + 1))
          [[ $exec_call -eq 2 ]] && return 1
          return 0
        }
        When call _config_auditd
        The status should be failure
        The variable log_called should equal true
        The variable log_message should include "Failed to configure auditd"
      End

      It "does not mark configured when remote_copy fails"
        marked=false
        parallel_mark_configured() { marked=true; }
        MOCK_REMOTE_COPY_RESULT=1
        When call _config_auditd
        The status should be failure
        The variable marked should equal false
      End

      It "does not mark configured when remote_exec fails"
        marked=false
        parallel_mark_configured() { marked=true; }
        exec_call=0
        remote_exec() {
          exec_call=$((exec_call + 1))
          [[ $exec_call -eq 2 ]] && return 1
          return 0
        }
        When call _config_auditd
        The status should be failure
        The variable marked should equal false
      End

      It "does not enable service when config fails"
        service_enabled=false
        remote_enable_services() { service_enabled=true; return 0; }
        exec_call=0
        remote_exec() {
          exec_call=$((exec_call + 1))
          [[ $exec_call -eq 2 ]] && return 1
          return 0
        }
        When call _config_auditd
        The status should be failure
        The variable service_enabled should equal false
      End
    End

    # -------------------------------------------------------------------------
    # Execution order
    # -------------------------------------------------------------------------
    Describe "execution order"
      It "runs steps in correct sequence"
        order=""
        remote_exec() {
          if [[ $1 == *"mkdir -p /etc/audit/rules.d"* ]]; then
            order="${order}1-mkdir,"
          elif [[ $1 == *"mkdir -p /var/log/audit"* ]]; then
            order="${order}3-logdir,"
          fi
          return 0
        }
        remote_copy() {
          order="${order}2-copy,"
          return 0
        }
        remote_enable_services() {
          order="${order}4-enable,"
          return 0
        }
        parallel_mark_configured() {
          order="${order}5-mark"
        }
        When call _config_auditd
        The status should be success
        The variable order should equal "1-mkdir,2-copy,3-logdir,4-enable,5-mark"
      End
    End
  End

  # ===========================================================================
  # configure_auditd() - public wrapper
  # ===========================================================================
  Describe "configure_auditd()"
    BeforeEach 'MOCK_REMOTE_COPY_RESULT=0; MOCK_REMOTE_EXEC_RESULT=0'

    # -------------------------------------------------------------------------
    # Skip conditions
    # -------------------------------------------------------------------------
    Describe "skip conditions"
      It "skips when INSTALL_AUDITD is not yes"
        INSTALL_AUDITD="no"
        config_called=false
        _config_auditd() { config_called=true; return 0; }
        When call configure_auditd
        The status should be success
        The variable config_called should equal false
      End

      It "skips when INSTALL_AUDITD is unset"
        unset INSTALL_AUDITD
        config_called=false
        _config_auditd() { config_called=true; return 0; }
        When call configure_auditd
        The status should be success
        The variable config_called should equal false
      End

      It "skips when INSTALL_AUDITD is empty"
        INSTALL_AUDITD=""
        config_called=false
        _config_auditd() { config_called=true; return 0; }
        When call configure_auditd
        The status should be success
        The variable config_called should equal false
      End

      It "skips when INSTALL_AUDITD is 'false'"
        INSTALL_AUDITD="false"
        config_called=false
        _config_auditd() { config_called=true; return 0; }
        When call configure_auditd
        The status should be success
        The variable config_called should equal false
      End

      It "skips when INSTALL_AUDITD is 'NO'"
        INSTALL_AUDITD="NO"
        config_called=false
        _config_auditd() { config_called=true; return 0; }
        When call configure_auditd
        The status should be success
        The variable config_called should equal false
      End
    End

    # -------------------------------------------------------------------------
    # Configuration triggers
    # -------------------------------------------------------------------------
    Describe "when auditd installation is enabled"
      BeforeEach 'INSTALL_AUDITD="yes"'

      It "configures auditd when INSTALL_AUDITD is yes"
        config_called=false
        _config_auditd() { config_called=true; return 0; }
        When call configure_auditd
        The status should be success
        The variable config_called should equal true
      End

      It "propagates success from _config_auditd"
        _config_auditd() { return 0; }
        When call configure_auditd
        The status should be success
      End

      It "propagates failure from _config_auditd"
        _config_auditd() { return 1; }
        When call configure_auditd
        The status should be failure
      End

      It "propagates specific exit codes"
        _config_auditd() { return 42; }
        When call configure_auditd
        The status should equal 42
      End
    End

    # -------------------------------------------------------------------------
    # Integration with real _config_auditd
    # -------------------------------------------------------------------------
    Describe "integration with _config_auditd"
      It "succeeds with real _config_auditd when mocks pass"
        INSTALL_AUDITD="yes"
        When call configure_auditd
        The status should be success
      End

      It "fails with real _config_auditd when remote_copy fails"
        INSTALL_AUDITD="yes"
        MOCK_REMOTE_COPY_RESULT=1
        When call configure_auditd
        The status should be failure
      End
    End
  End
End
