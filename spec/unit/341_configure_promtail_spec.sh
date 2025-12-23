# shellcheck shell=bash
# shellcheck disable=SC2034
# =============================================================================
# Tests for 341-configure-promtail.sh
# Package installed via batch_install_packages(), this tests config only
# =============================================================================

%const SCRIPTS_DIR: "${SHELLSPEC_PROJECT_ROOT}/scripts"
%const SUPPORT_DIR: "${SHELLSPEC_PROJECT_ROOT}/spec/support"

# Load shared mocks
eval "$(cat "$SUPPORT_DIR/configure_mocks.sh")"

Describe "341-configure-promtail.sh"
  Include "$SCRIPTS_DIR/341-configure-promtail.sh"

  # ===========================================================================
  # _config_promtail()
  # ===========================================================================
  Describe "_config_promtail()"
    BeforeEach 'MOCK_REMOTE_EXEC_RESULT=0; MOCK_REMOTE_COPY_RESULT=0; PVE_HOSTNAME="testhost"'

    # -------------------------------------------------------------------------
    # Successful configuration
    # -------------------------------------------------------------------------
    Describe "successful configuration"
      It "completes all configuration steps"
        When call _config_promtail
        The status should be success
      End

      It "calls deploy_template with promtail.yml"
        deploy_template_called_yml=false
        deploy_template() {
          if [[ $1 == *"promtail.yml"* ]]; then
            deploy_template_called_yml=true
          fi
          return 0
        }
        When call _config_promtail
        The status should be success
        The variable deploy_template_called_yml should equal true
      End

      It "calls deploy_template with promtail.service"
        deploy_template_called_service=false
        deploy_template() {
          if [[ $1 == *"promtail.service"* ]]; then
            deploy_template_called_service=true
          fi
          return 0
        }
        When call _config_promtail
        The status should be success
        The variable deploy_template_called_service should equal true
      End

      It "passes HOSTNAME variable to template"
        hostname_passed=""
        deploy_template() {
          if [[ $1 == *"promtail.yml"* ]]; then
            hostname_passed="$3"
          fi
          return 0
        }
        PVE_HOSTNAME="myproxmox"
        When call _config_promtail
        The status should be success
        The variable hostname_passed should equal "HOSTNAME=myproxmox"
      End

      It "enables promtail service"
        enable_called=false
        remote_enable_services() {
          if [[ $1 == "promtail" ]]; then
            enable_called=true
          fi
          return 0
        }
        When call _config_promtail
        The status should be success
        The variable enable_called should equal true
      End

      It "marks promtail as configured"
        mark_called=false
        parallel_mark_configured() {
          if [[ $1 == "promtail" ]]; then
            mark_called=true
          fi
        }
        When call _config_promtail
        The status should be success
        The variable mark_called should equal true
      End
    End

    # -------------------------------------------------------------------------
    # Directory creation
    # -------------------------------------------------------------------------
    Describe "directory creation"
      It "creates /etc/promtail directory"
        mkdir_called=false
        remote_exec() {
          if [[ $1 == *"/etc/promtail"* ]]; then
            mkdir_called=true
          fi
          return 0
        }
        When call _config_promtail
        The status should be success
        The variable mkdir_called should equal true
      End

      It "creates /var/lib/promtail directory"
        mkdir_called=false
        remote_exec() {
          if [[ $1 == *"/var/lib/promtail"* ]]; then
            mkdir_called=true
          fi
          return 0
        }
        When call _config_promtail
        The status should be success
        The variable mkdir_called should equal true
      End

      It "fails when config directory creation fails"
        call_count=0
        remote_exec() {
          call_count=$((call_count + 1))
          if [[ $call_count -eq 1 ]]; then
            return 1
          fi
          return 0
        }
        When call _config_promtail
        The status should be failure
      End
    End

    # -------------------------------------------------------------------------
    # Template deployment failures
    # -------------------------------------------------------------------------
    Describe "template deployment failures"
      It "fails when promtail.yml deployment fails"
        deploy_template() {
          if [[ $1 == *"promtail.yml"* ]]; then
            return 1
          fi
          return 0
        }
        When call _config_promtail
        The status should be failure
      End

      It "fails when promtail.service deployment fails"
        deploy_template() {
          if [[ $1 == *"promtail.service"* ]]; then
            return 1
          fi
          return 0
        }
        When call _config_promtail
        The status should be failure
      End
    End
  End

  # ===========================================================================
  # configure_promtail()
  # ===========================================================================
  Describe "configure_promtail()"
    BeforeEach 'MOCK_REMOTE_EXEC_RESULT=0; MOCK_REMOTE_COPY_RESULT=0; PVE_HOSTNAME="testhost"'

    # -------------------------------------------------------------------------
    # Skip conditions
    # -------------------------------------------------------------------------
    Describe "skip conditions"
      It "skips when INSTALL_PROMTAIL is not yes"
        INSTALL_PROMTAIL="no"
        config_called=false
        _config_promtail() { config_called=true; return 0; }
        When call configure_promtail
        The status should be success
        The variable config_called should equal false
      End

      It "skips when INSTALL_PROMTAIL is unset"
        unset INSTALL_PROMTAIL
        config_called=false
        _config_promtail() { config_called=true; return 0; }
        When call configure_promtail
        The status should be success
        The variable config_called should equal false
      End

      It "skips when INSTALL_PROMTAIL is empty"
        INSTALL_PROMTAIL=""
        config_called=false
        _config_promtail() { config_called=true; return 0; }
        When call configure_promtail
        The status should be success
        The variable config_called should equal false
      End
    End

    # -------------------------------------------------------------------------
    # Configuration execution
    # -------------------------------------------------------------------------
    Describe "configuration execution"
      It "configures promtail when INSTALL_PROMTAIL is yes"
        INSTALL_PROMTAIL="yes"
        config_called=false
        _config_promtail() { config_called=true; return 0; }
        When call configure_promtail
        The status should be success
        The variable config_called should equal true
      End
    End

    # -------------------------------------------------------------------------
    # Error propagation
    # -------------------------------------------------------------------------
    Describe "error propagation"
      It "propagates failure from _config_promtail"
        INSTALL_PROMTAIL="yes"
        _config_promtail() { return 1; }
        When call configure_promtail
        The status should be failure
      End

      It "returns success when _config_promtail succeeds"
        INSTALL_PROMTAIL="yes"
        _config_promtail() { return 0; }
        When call configure_promtail
        The status should be success
      End
    End
  End
End
