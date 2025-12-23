# shellcheck shell=bash
# shellcheck disable=SC2034
# =============================================================================
# Tests for 302-configure-admin.sh
# =============================================================================

%const SCRIPTS_DIR: "${SHELLSPEC_PROJECT_ROOT}/scripts"
%const SUPPORT_DIR: "${SHELLSPEC_PROJECT_ROOT}/spec/support"

# Load shared mocks
eval "$(cat "$SUPPORT_DIR/configure_mocks.sh")"

Describe "302-configure-admin.sh"
  Include "$SCRIPTS_DIR/302-configure-admin.sh"

  # ===========================================================================
  # _config_admin_user()
  # ===========================================================================
  Describe "_config_admin_user()"
    BeforeEach 'ADMIN_USERNAME="testadmin"; ADMIN_PASSWORD="testpass123"; SSH_PUBLIC_KEY="ssh-ed25519 AAAA... test@example.com"; MOCK_REMOTE_EXEC_RESULT=0'

    # -------------------------------------------------------------------------
    # User creation
    # -------------------------------------------------------------------------
    Describe "user creation"
      It "creates user with useradd successfully"
        When call _config_admin_user
        The status should be success
      End

      It "fails when useradd fails"
        exec_call=0
        remote_exec() {
          exec_call=$((exec_call + 1))
          [[ $exec_call -eq 1 ]] && return 1  # useradd fails
          return 0
        }
        When call _config_admin_user
        The status should be failure
      End
    End

    # -------------------------------------------------------------------------
    # Password setting
    # -------------------------------------------------------------------------
    Describe "password setting"
      It "sets password using chpasswd"
        chpasswd_called=false
        remote_exec() {
          if [[ $1 == *"chpasswd"* ]]; then
            chpasswd_called=true
          fi
          return 0
        }
        When call _config_admin_user
        The status should be success
        The variable chpasswd_called should equal true
      End

      It "fails when chpasswd fails"
        exec_call=0
        remote_exec() {
          exec_call=$((exec_call + 1))
          [[ $exec_call -eq 2 ]] && return 1  # chpasswd fails
          return 0
        }
        When call _config_admin_user
        The status should be failure
      End
    End

    # -------------------------------------------------------------------------
    # SSH directory setup
    # -------------------------------------------------------------------------
    Describe "SSH directory setup"
      It "creates .ssh directory with correct permissions"
        ssh_dir_created=false
        remote_exec() {
          if [[ $1 == *"mkdir -p"* && $1 == *".ssh"* ]]; then
            ssh_dir_created=true
          fi
          return 0
        }
        When call _config_admin_user
        The status should be success
        The variable ssh_dir_created should equal true
      End

      It "fails when mkdir for .ssh fails"
        exec_call=0
        remote_exec() {
          exec_call=$((exec_call + 1))
          [[ $exec_call -eq 3 ]] && return 1  # mkdir .ssh fails
          return 0
        }
        When call _config_admin_user
        The status should be failure
      End
    End

    # -------------------------------------------------------------------------
    # SSH key deployment
    # -------------------------------------------------------------------------
    Describe "SSH key deployment"
      It "deploys SSH key to authorized_keys"
        key_deployed=false
        remote_exec() {
          if [[ $1 == *"authorized_keys"* ]]; then
            key_deployed=true
          fi
          return 0
        }
        When call _config_admin_user
        The status should be success
        The variable key_deployed should equal true
      End

      It "escapes single quotes in SSH key"
        SSH_PUBLIC_KEY="ssh-ed25519 AAAA... user's key"
        key_content=""
        remote_exec() {
          if [[ $1 == *"echo"* && $1 == *"authorized_keys"* ]]; then
            key_content="$1"
          fi
          return 0
        }
        When call _config_admin_user
        The status should be success
        The variable key_content should include "user"
      End

      It "fails when key deployment fails"
        exec_call=0
        remote_exec() {
          exec_call=$((exec_call + 1))
          [[ $exec_call -eq 4 ]] && return 1  # key deployment fails
          return 0
        }
        When call _config_admin_user
        The status should be failure
      End
    End

    # -------------------------------------------------------------------------
    # Permissions and ownership
    # -------------------------------------------------------------------------
    Describe "permissions and ownership"
      It "sets correct permissions on authorized_keys"
        chmod_called=false
        remote_exec() {
          if [[ $1 == *"chmod 600"* && $1 == *"authorized_keys"* ]]; then
            chmod_called=true
          fi
          return 0
        }
        When call _config_admin_user
        The status should be success
        The variable chmod_called should equal true
      End

      It "sets correct ownership on .ssh directory"
        chown_called=false
        remote_exec() {
          if [[ $1 == *"chown -R"* && $1 == *".ssh"* ]]; then
            chown_called=true
          fi
          return 0
        }
        When call _config_admin_user
        The status should be success
        The variable chown_called should equal true
      End

      It "fails when chmod fails"
        exec_call=0
        remote_exec() {
          exec_call=$((exec_call + 1))
          [[ $exec_call -eq 5 ]] && return 1  # chmod 600 fails
          return 0
        }
        When call _config_admin_user
        The status should be failure
      End

      It "fails when chown fails"
        exec_call=0
        remote_exec() {
          exec_call=$((exec_call + 1))
          [[ $exec_call -eq 6 ]] && return 1  # chown fails
          return 0
        }
        When call _config_admin_user
        The status should be failure
      End
    End

    # -------------------------------------------------------------------------
    # Sudo configuration
    # -------------------------------------------------------------------------
    Describe "sudo configuration"
      It "creates sudoers.d file with NOPASSWD rule"
        sudoers_created=false
        remote_exec() {
          if [[ $1 == *"sudoers.d"* && $1 == *"NOPASSWD"* ]]; then
            sudoers_created=true
          fi
          return 0
        }
        When call _config_admin_user
        The status should be success
        The variable sudoers_created should equal true
      End

      It "sets correct permissions on sudoers file"
        sudoers_chmod=false
        remote_exec() {
          if [[ $1 == *"chmod 440"* && $1 == *"sudoers.d"* ]]; then
            sudoers_chmod=true
          fi
          return 0
        }
        When call _config_admin_user
        The status should be success
        The variable sudoers_chmod should equal true
      End

      It "fails when sudoers file creation fails"
        exec_call=0
        remote_exec() {
          exec_call=$((exec_call + 1))
          [[ $exec_call -eq 7 ]] && return 1  # sudoers creation fails
          return 0
        }
        When call _config_admin_user
        The status should be failure
      End

      It "fails when sudoers chmod fails"
        exec_call=0
        remote_exec() {
          exec_call=$((exec_call + 1))
          [[ $exec_call -eq 8 ]] && return 1  # sudoers chmod fails
          return 0
        }
        When call _config_admin_user
        The status should be failure
      End
    End

    # -------------------------------------------------------------------------
    # Proxmox UI access
    # -------------------------------------------------------------------------
    Describe "Proxmox UI access"
      It "checks if PAM user exists before creating"
        user_check_called=false
        remote_exec() {
          if [[ $1 == *"pveum user list"* && $1 == *"grep"* ]]; then
            user_check_called=true
          fi
          return 0
        }
        When call _config_admin_user
        The status should be success
        The variable user_check_called should equal true
      End

      It "grants Administrator role to admin user"
        acl_modified=false
        remote_exec() {
          if [[ $1 == *"pveum acl modify"* && $1 == *"Administrator"* ]]; then
            acl_modified=true
          fi
          return 0
        }
        When call _config_admin_user
        The status should be success
        The variable acl_modified should equal true
      End

      It "disables root@pam user"
        root_disabled=false
        remote_exec() {
          if [[ $1 == *"pveum user modify root@pam"* && $1 == *"-enable 0"* ]]; then
            root_disabled=true
          fi
          return 0
        }
        When call _config_admin_user
        The status should be success
        The variable root_disabled should equal true
      End

      It "continues if pveum acl modify fails (logs warning)"
        log_called=false
        log() { log_called=true; }
        exec_call=0
        remote_exec() {
          exec_call=$((exec_call + 1))
          # pveum acl modify is call 10
          [[ $exec_call -eq 10 ]] && return 1
          return 0
        }
        When call _config_admin_user
        The status should be success
        The variable log_called should equal true
      End

      It "continues if pveum user modify fails (logs warning)"
        log_called=false
        log() { log_called=true; }
        exec_call=0
        remote_exec() {
          exec_call=$((exec_call + 1))
          # pveum user modify is call 11
          [[ $exec_call -eq 11 ]] && return 1
          return 0
        }
        When call _config_admin_user
        The status should be success
        The variable log_called should equal true
      End
    End

    # -------------------------------------------------------------------------
    # Command sequence verification
    # -------------------------------------------------------------------------
    Describe "command sequence"
      It "executes all commands in correct order"
        commands=()
        remote_exec() {
          commands+=("$1")
          return 0
        }
        When call _config_admin_user
        The status should be success
        # Verify key commands are present
        The variable "commands[0]" should include "useradd"
        The variable "commands[1]" should include "chpasswd"
        The variable "commands[2]" should include "mkdir"
        The variable "commands[3]" should include "authorized_keys"
        The variable "commands[4]" should include "chmod 600"
        The variable "commands[5]" should include "chown"
        The variable "commands[6]" should include "sudoers.d"
        The variable "commands[7]" should include "chmod 440"
      End
    End
  End

  # ===========================================================================
  # configure_admin_user() - public wrapper
  # ===========================================================================
  Describe "configure_admin_user()"
    BeforeEach 'ADMIN_USERNAME="testadmin"; ADMIN_PASSWORD="testpass123"; SSH_PUBLIC_KEY="ssh-ed25519 AAAA..."; MOCK_REMOTE_EXEC_RESULT=0'

    It "calls _config_admin_user via run_with_progress"
      config_called=false
      _config_admin_user() { config_called=true; return 0; }
      When call configure_admin_user
      The status should be success
      The variable config_called should equal true
    End

    It "returns success when _config_admin_user succeeds"
      _config_admin_user() { return 0; }
      When call configure_admin_user
      The status should be success
    End

    It "returns failure when _config_admin_user fails"
      _config_admin_user() { return 1; }
      When call configure_admin_user
      The status should be failure
    End

    It "logs admin username on start"
      log_message=""
      log() { log_message="$*"; }
      _config_admin_user() { return 0; }
      When call configure_admin_user
      The status should be success
      The variable log_message should include "testadmin"
    End

    It "logs success message when completed"
      last_log=""
      log() { last_log="$*"; }
      _config_admin_user() { return 0; }
      When call configure_admin_user
      The status should be success
      The variable last_log should include "created successfully"
    End

    It "logs error when failed"
      error_logged=false
      log() { [[ $* == *"ERROR"* ]] && error_logged=true; }
      _config_admin_user() { return 1; }
      When call configure_admin_user
      The status should be failure
      The variable error_logged should equal true
    End
  End
End

