# shellcheck shell=bash
# shellcheck disable=SC2034
# =============================================================================
# Tests for 342-configure-netdata.sh
# Package installed via batch_install_packages(), this tests config only
# =============================================================================

%const SCRIPTS_DIR: "${SHELLSPEC_PROJECT_ROOT}/scripts"
%const SUPPORT_DIR: "${SHELLSPEC_PROJECT_ROOT}/spec/support"

# Load shared mocks
eval "$(cat "$SUPPORT_DIR/configure_mocks.sh")"

Describe "342-configure-netdata.sh"
  Include "$SCRIPTS_DIR/342-configure-netdata.sh"

  # ===========================================================================
  # _config_netdata()
  # ===========================================================================
  Describe "_config_netdata()"
    BeforeEach 'MOCK_REMOTE_EXEC_RESULT=0; MOCK_REMOTE_COPY_RESULT=0'

    # -------------------------------------------------------------------------
    # Successful configuration
    # -------------------------------------------------------------------------
    Describe "successful configuration"
      It "completes all configuration steps"
        INSTALL_TAILSCALE="no"
        When call _config_netdata
        The status should be success
      End

      It "calls deploy_template with netdata.conf"
        deploy_template_called=false
        deploy_template() {
          if [[ $1 == *"netdata.conf"* ]]; then
            deploy_template_called=true
          fi
          return 0
        }
        INSTALL_TAILSCALE="no"
        When call _config_netdata
        The status should be success
        The variable deploy_template_called should equal true
      End

      It "enables netdata service"
        enable_called=false
        remote_enable_services() {
          if [[ $1 == "netdata" ]]; then
            enable_called=true
          fi
          return 0
        }
        INSTALL_TAILSCALE="no"
        When call _config_netdata
        The status should be success
        The variable enable_called should equal true
      End
    End

    # -------------------------------------------------------------------------
    # Bind address configuration
    # -------------------------------------------------------------------------
    Describe "bind address configuration"
      It "uses localhost only when Tailscale is disabled"
        bind_to_value=""
        deploy_template() {
          # Extract NETDATA_BIND_TO value from args
          for arg in "$@"; do
            if [[ $arg == NETDATA_BIND_TO=* ]]; then
              bind_to_value="${arg#NETDATA_BIND_TO=}"
            fi
          done
          return 0
        }
        INSTALL_TAILSCALE="no"
        When call _config_netdata
        The status should be success
        The variable bind_to_value should equal "127.0.0.1"
      End

      It "uses localhost and Tailscale range when Tailscale is enabled"
        bind_to_value=""
        deploy_template() {
          for arg in "$@"; do
            if [[ $arg == NETDATA_BIND_TO=* ]]; then
              bind_to_value="${arg#NETDATA_BIND_TO=}"
            fi
          done
          return 0
        }
        INSTALL_TAILSCALE="yes"
        When call _config_netdata
        The status should be success
        The variable bind_to_value should equal "127.0.0.1 100.*"
      End
    End

    # -------------------------------------------------------------------------
    # Template deployment paths
    # -------------------------------------------------------------------------
    Describe "template deployment paths"
      It "deploys to /etc/netdata/netdata.conf"
        target_path=""
        deploy_template() {
          target_path="$2"
          return 0
        }
        INSTALL_TAILSCALE="no"
        When call _config_netdata
        The status should be success
        The variable target_path should equal "/etc/netdata/netdata.conf"
      End
    End

    # -------------------------------------------------------------------------
    # Template deployment failures
    # -------------------------------------------------------------------------
    Describe "template deployment failures"
      It "fails when deploy_template fails"
        deploy_template() { return 1; }
        INSTALL_TAILSCALE="no"
        When call _config_netdata
        The status should be failure
      End
    End
  End

  # ===========================================================================
  # configure_netdata()
  # ===========================================================================
  Describe "configure_netdata()"
    BeforeEach 'MOCK_REMOTE_EXEC_RESULT=0; MOCK_REMOTE_COPY_RESULT=0'

    # -------------------------------------------------------------------------
    # Skip conditions
    # -------------------------------------------------------------------------
    Describe "skip conditions"
      It "skips when INSTALL_NETDATA is not yes"
        INSTALL_NETDATA="no"
        config_called=false
        _config_netdata() { config_called=true; return 0; }
        When call configure_netdata
        The status should be success
        The variable config_called should equal false
      End

      It "skips when INSTALL_NETDATA is unset"
        unset INSTALL_NETDATA
        config_called=false
        _config_netdata() { config_called=true; return 0; }
        When call configure_netdata
        The status should be success
        The variable config_called should equal false
      End

      It "skips when INSTALL_NETDATA is empty"
        INSTALL_NETDATA=""
        config_called=false
        _config_netdata() { config_called=true; return 0; }
        When call configure_netdata
        The status should be success
        The variable config_called should equal false
      End
    End

    # -------------------------------------------------------------------------
    # Configuration execution
    # -------------------------------------------------------------------------
    Describe "configuration execution"
      It "configures netdata when INSTALL_NETDATA is yes"
        INSTALL_NETDATA="yes"
        INSTALL_TAILSCALE="no"
        config_called=false
        _config_netdata() { config_called=true; return 0; }
        When call configure_netdata
        The status should be success
        The variable config_called should equal true
      End
    End

    # -------------------------------------------------------------------------
    # Error propagation
    # -------------------------------------------------------------------------
    Describe "error propagation"
      It "propagates failure from _config_netdata"
        INSTALL_NETDATA="yes"
        INSTALL_TAILSCALE="no"
        _config_netdata() { return 1; }
        When call configure_netdata
        The status should be failure
      End

      It "returns success when _config_netdata succeeds"
        INSTALL_NETDATA="yes"
        INSTALL_TAILSCALE="no"
        _config_netdata() { return 0; }
        When call configure_netdata
        The status should be success
      End
    End
  End
End
