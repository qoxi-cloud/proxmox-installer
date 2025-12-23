# shellcheck shell=bash
# shellcheck disable=SC2016,SC2034
# =============================================================================
# Tests for 038-deploy-helpers.sh
# =============================================================================

%const SCRIPTS_DIR: "${SHELLSPEC_PROJECT_ROOT}/scripts"
%const SUPPORT_DIR: "${SHELLSPEC_PROJECT_ROOT}/spec/support"

# Load shared mocks
eval "$(cat "$SUPPORT_DIR/core_mocks.sh")"
eval "$(cat "$SUPPORT_DIR/deploy_helper_mocks.sh")"

# Note: deploy mocks (remote_exec, remote_copy, apply_template_vars with tracking)
# are now in deploy_helper_mocks.sh

Describe "038-deploy-helpers.sh"
  Include "$SCRIPTS_DIR/038-deploy-helpers.sh"

  # ===========================================================================
  # deploy_user_config()
  # ===========================================================================
  Describe "deploy_user_config()"
    BeforeEach 'reset_deploy_mocks'

    Describe "successful deployment"
      It "deploys config to user home directory"
        When call deploy_user_config "templates/bat-config" ".config/bat/config"
        The status should be success
      End

      It "creates parent directory when needed"
        When call deploy_user_config "templates/bat-config" ".config/bat/config"
        The status should be success
        The variable "REMOTE_EXEC_CALLS[0]" should include "mkdir -p"
        The variable "REMOTE_EXEC_CALLS[0]" should include ".config/bat"
      End

      It "copies file to correct destination"
        When call deploy_user_config "templates/test.conf" ".config/test/config"
        The status should be success
        The variable "REMOTE_COPY_CALLS[0]" should include "templates/test.conf"
        The variable "REMOTE_COPY_CALLS[0]" should include "/home/testadmin/.config/test/config"
      End

      It "sets correct ownership"
        When call deploy_user_config "templates/bat-config" ".config/bat/config"
        The status should be success
        The variable "REMOTE_EXEC_CALLS[1]" should include "chown testadmin:testadmin"
      End

      It "skips mkdir for files in home root"
        When call deploy_user_config "templates/zshrc" ".zshrc"
        The status should be success
        # Should only have chown call, not mkdir
        The variable "REMOTE_EXEC_CALLS[0]" should include "chown"
        The variable "REMOTE_EXEC_CALLS[0]" should not include "mkdir"
      End
    End

    Describe "failure handling"
      It "fails when mkdir fails"
        MOCK_REMOTE_EXEC_RESULT=1
        When call deploy_user_config "templates/bat-config" ".config/bat/config"
        The status should be failure
      End

      It "fails when remote_copy fails"
        # First call (mkdir) succeeds, second call we test copy
        remote_copy() {
          REMOTE_COPY_CALLS+=("$1 -> $2")
          return 1
        }
        When call deploy_user_config "templates/bat-config" ".config/bat/config"
        The status should be failure
      End

      It "fails when chown fails"
        # Make mkdir succeed but chown fail
        _chown_call_count=0
        remote_exec() {
          REMOTE_EXEC_CALLS+=("$1")
          if [[ "$1" == *"chown"* ]]; then
            return 1
          fi
          return 0
        }
        When call deploy_user_config "templates/bat-config" ".config/bat/config"
        The status should be failure
      End
    End
  End

  # ===========================================================================
  # run_with_progress()
  # ===========================================================================
  Describe "run_with_progress()"
    It "runs command and returns success"
      When call run_with_progress "Processing" "Done" true
      The status should be success
    End

    It "returns failure when command fails"
      When call run_with_progress "Processing" "Done" false
      The status should be failure
    End

    It "passes arguments to command"
      test_cmd() {
        [[ "$1" == "arg1" ]] && [[ "$2" == "arg2" ]]
      }
      When call run_with_progress "Testing" "Complete" test_cmd "arg1" "arg2"
      The status should be success
    End
  End

  # ===========================================================================
  # deploy_systemd_timer()
  # ===========================================================================
  Describe "deploy_systemd_timer()"
    BeforeEach 'reset_deploy_mocks'

    Describe "successful deployment"
      It "deploys both service and timer files"
        When call deploy_systemd_timer "aide-check"
        The status should be success
      End

      It "copies service file to correct location"
        When call deploy_systemd_timer "aide-check"
        The status should be success
        The variable "REMOTE_COPY_CALLS[0]" should include "templates/aide-check.service"
        The variable "REMOTE_COPY_CALLS[0]" should include "/etc/systemd/system/aide-check.service"
      End

      It "copies timer file to correct location"
        When call deploy_systemd_timer "aide-check"
        The status should be success
        The variable "REMOTE_COPY_CALLS[1]" should include "templates/aide-check.timer"
        The variable "REMOTE_COPY_CALLS[1]" should include "/etc/systemd/system/aide-check.timer"
      End

      It "enables timer via systemctl"
        When call deploy_systemd_timer "aide-check"
        The status should be success
        The variable "REMOTE_EXEC_CALLS[0]" should include "systemctl daemon-reload"
        The variable "REMOTE_EXEC_CALLS[0]" should include "systemctl enable aide-check.timer"
      End

      It "uses template directory prefix when provided"
        When call deploy_systemd_timer "myservice" "subdir"
        The status should be success
        The variable "REMOTE_COPY_CALLS[0]" should include "templates/subdir/myservice.service"
      End
    End

    Describe "failure handling"
      It "fails when service file copy fails"
        MOCK_REMOTE_COPY_RESULT=1
        When call deploy_systemd_timer "aide-check"
        The status should be failure
      End

      It "fails when timer file copy fails"
        _copy_count=0
        remote_copy() {
          REMOTE_COPY_CALLS+=("$1 -> $2")
          _copy_count=$((_copy_count + 1))
          # Fail on second copy (timer file)
          [[ $_copy_count -eq 2 ]] && return 1
          return 0
        }
        When call deploy_systemd_timer "aide-check"
        The status should be failure
      End

      It "fails when systemctl enable fails"
        MOCK_REMOTE_EXEC_RESULT=1
        When call deploy_systemd_timer "aide-check"
        The status should be failure
      End
    End
  End

  # ===========================================================================
  # deploy_systemd_service()
  # ===========================================================================
  Describe "deploy_systemd_service()"
    BeforeEach 'reset_deploy_mocks'

    setup_service_template() {
      SERVICE_TEMPLATE=$(mktemp)
      echo "[Unit]
Description={{DESCRIPTION}}
[Service]
ExecStart={{EXEC_START}}" >"$SERVICE_TEMPLATE"
      # Override template path for testing
      mkdir -p "$(dirname "$SERVICE_TEMPLATE")"
    }

    cleanup_service_template() {
      rm -f "$SERVICE_TEMPLATE"
    }

    Describe "successful deployment"
      It "deploys service without template vars"
        # Create a minimal test template
        tmpdir=$(mktemp -d)
        mkdir -p "$tmpdir/templates"
        echo "[Unit]
Description=Test" >"$tmpdir/templates/test.service"
        cd "$tmpdir" || return 1

        When call deploy_systemd_service "test"
        The status should be success

        cd - >/dev/null || return 1
        rm -rf "$tmpdir"
      End

      It "applies template vars when provided"
        tmpdir=$(mktemp -d)
        mkdir -p "$tmpdir/templates"
        echo "[Unit]
Description={{DESC}}" >"$tmpdir/templates/vartest.service"
        cd "$tmpdir" || return 1

        When call deploy_systemd_service "vartest" "DESC=My Service"
        The status should be success
        # Check that apply_template_vars was called
        The variable "APPLY_TEMPLATE_CALLS[0]" should include "DESC=My Service"

        cd - >/dev/null || return 1
        rm -rf "$tmpdir"
      End

      It "enables service after deployment"
        tmpdir=$(mktemp -d)
        mkdir -p "$tmpdir/templates"
        echo "[Unit]" >"$tmpdir/templates/myservice.service"
        cd "$tmpdir" || return 1

        When call deploy_systemd_service "myservice"
        The status should be success
        The variable "REMOTE_EXEC_CALLS[0]" should include "systemctl daemon-reload"
        The variable "REMOTE_EXEC_CALLS[0]" should include "systemctl enable myservice.service"

        cd - >/dev/null || return 1
        rm -rf "$tmpdir"
      End
    End

    Describe "failure handling"
      It "fails when template file doesn't exist"
        tmpdir=$(mktemp -d)
        mkdir -p "$tmpdir/templates"
        cd "$tmpdir" || return 1

        When call deploy_systemd_service "nonexistent"
        The status should be failure
        The stderr should include "cannot stat"

        cd - >/dev/null || return 1
        rm -rf "$tmpdir"
      End

      It "fails when template substitution fails"
        tmpdir=$(mktemp -d)
        mkdir -p "$tmpdir/templates"
        echo "[Unit]" >"$tmpdir/templates/failsub.service"
        cd "$tmpdir" || return 1
        MOCK_APPLY_TEMPLATE_RESULT=1

        When call deploy_systemd_service "failsub" "VAR=value"
        The status should be failure

        cd - >/dev/null || return 1
        rm -rf "$tmpdir"
      End

      It "fails when remote_copy fails"
        tmpdir=$(mktemp -d)
        mkdir -p "$tmpdir/templates"
        echo "[Unit]" >"$tmpdir/templates/copyfail.service"
        cd "$tmpdir" || return 1
        MOCK_REMOTE_COPY_RESULT=1

        When call deploy_systemd_service "copyfail"
        The status should be failure

        cd - >/dev/null || return 1
        rm -rf "$tmpdir"
      End

      It "fails when systemctl enable fails"
        tmpdir=$(mktemp -d)
        mkdir -p "$tmpdir/templates"
        echo "[Unit]" >"$tmpdir/templates/enablefail.service"
        cd "$tmpdir" || return 1
        MOCK_REMOTE_EXEC_RESULT=1

        When call deploy_systemd_service "enablefail"
        The status should be failure

        cd - >/dev/null || return 1
        rm -rf "$tmpdir"
      End
    End
  End

  # ===========================================================================
  # remote_enable_services()
  # ===========================================================================
  Describe "remote_enable_services()"
    BeforeEach 'reset_deploy_mocks'

    Describe "successful operation"
      It "returns success with no services"
        When call remote_enable_services
        The status should be success
      End

      It "enables single service"
        When call remote_enable_services "nginx"
        The status should be success
        The variable "REMOTE_EXEC_CALLS[0]" should equal "systemctl enable nginx"
      End

      It "enables multiple services in single call"
        When call remote_enable_services "nginx" "apache2" "mysql"
        The status should be success
        The variable "REMOTE_EXEC_CALLS[0]" should include "nginx"
        The variable "REMOTE_EXEC_CALLS[0]" should include "apache2"
        The variable "REMOTE_EXEC_CALLS[0]" should include "mysql"
      End
    End

    Describe "failure handling"
      It "fails when remote_exec fails"
        MOCK_REMOTE_EXEC_RESULT=1
        When call remote_enable_services "nginx"
        The status should be failure
      End
    End
  End

  # ===========================================================================
  # deploy_template()
  # ===========================================================================
  Describe "deploy_template()"
    BeforeEach 'reset_deploy_mocks'

    Describe "successful deployment"
      It "deploys template without vars"
        tmpdir=$(mktemp -d)
        echo "static content" >"$tmpdir/test.tmpl"

        When call deploy_template "$tmpdir/test.tmpl" "/etc/test.conf"
        The status should be success
        The variable "REMOTE_COPY_CALLS[0]" should include "/etc/test.conf"

        rm -rf "$tmpdir"
      End

      It "applies template vars and deploys"
        tmpdir=$(mktemp -d)
        echo "{{VAR1}} {{VAR2}}" >"$tmpdir/vars.tmpl"

        When call deploy_template "$tmpdir/vars.tmpl" "/etc/vars.conf" "VAR1=hello" "VAR2=world"
        The status should be success
        The variable "APPLY_TEMPLATE_CALLS[0]" should include "VAR1=hello"
        The variable "APPLY_TEMPLATE_CALLS[0]" should include "VAR2=world"

        rm -rf "$tmpdir"
      End

      It "preserves original template file"
        tmpdir=$(mktemp -d)
        echo "original content" >"$tmpdir/preserve.tmpl"

        When call deploy_template "$tmpdir/preserve.tmpl" "/etc/preserve.conf" "VAR=changed"
        The status should be success
        The contents of file "$tmpdir/preserve.tmpl" should equal "original content"

        rm -rf "$tmpdir"
      End
    End

    Describe "failure handling"
      It "fails when template doesn't exist"
        When call deploy_template "/nonexistent/template.tmpl" "/etc/test.conf"
        The status should be failure
        The stderr should include "cannot stat"
      End

      It "fails when template substitution fails"
        tmpdir=$(mktemp -d)
        echo "{{VAR}}" >"$tmpdir/subfail.tmpl"
        MOCK_APPLY_TEMPLATE_RESULT=1

        When call deploy_template "$tmpdir/subfail.tmpl" "/etc/subfail.conf" "VAR=value"
        The status should be failure

        rm -rf "$tmpdir"
      End

      It "fails when remote_copy fails"
        tmpdir=$(mktemp -d)
        echo "content" >"$tmpdir/copyfail.tmpl"
        MOCK_REMOTE_COPY_RESULT=1

        When call deploy_template "$tmpdir/copyfail.tmpl" "/etc/copyfail.conf"
        The status should be failure

        rm -rf "$tmpdir"
      End

      It "cleans up staged file on failure and preserves original"
        tmpdir=$(mktemp -d)
        echo "original content" >"$tmpdir/cleanup.tmpl"
        MOCK_REMOTE_COPY_RESULT=1

        When call deploy_template "$tmpdir/cleanup.tmpl" "/etc/cleanup.conf"
        The status should be failure
        # Original file should still exist with original content
        The file "$tmpdir/cleanup.tmpl" should be exist
        The contents of file "$tmpdir/cleanup.tmpl" should equal "original content"

        rm -rf "$tmpdir"
      End
    End
  End
End
