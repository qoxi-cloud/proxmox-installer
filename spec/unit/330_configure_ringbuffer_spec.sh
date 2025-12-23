# shellcheck shell=bash
# shellcheck disable=SC2034
# =============================================================================
# Tests for 330-configure-ringbuffer.sh
# =============================================================================

%const SCRIPTS_DIR: "${SHELLSPEC_PROJECT_ROOT}/scripts"
%const SUPPORT_DIR: "${SHELLSPEC_PROJECT_ROOT}/spec/support"

# Load shared mocks
eval "$(cat "$SUPPORT_DIR/configure_mocks.sh")"

Describe "330-configure-ringbuffer.sh"
  Include "$SCRIPTS_DIR/330-configure-ringbuffer.sh"

  # ===========================================================================
  # _config_ringbuffer()
  # ===========================================================================
  Describe "_config_ringbuffer()"
    BeforeEach 'MOCK_REMOTE_COPY_RESULT=0; DEFAULT_INTERFACE=""'

    # -------------------------------------------------------------------------
    # Successful configuration
    # -------------------------------------------------------------------------
    Describe "successful configuration"
      It "deploys systemd service successfully"
        When call _config_ringbuffer
        The status should be success
      End

      It "calls deploy_systemd_service with network-ringbuffer"
        service_name=""
        deploy_systemd_service() {
          service_name="$1"
          return 0
        }
        When call _config_ringbuffer
        The status should be success
        The variable service_name should equal "network-ringbuffer"
      End

      It "calls parallel_mark_configured on success"
        marked_as=""
        parallel_mark_configured() { marked_as="$1"; }
        When call _config_ringbuffer
        The status should be success
        The variable marked_as should equal "ringbuffer"
      End
    End

    # -------------------------------------------------------------------------
    # Interface name handling
    # -------------------------------------------------------------------------
    Describe "interface name handling"
      It "uses DEFAULT_INTERFACE when set"
        DEFAULT_INTERFACE="eno1"
        captured_vars=""
        deploy_systemd_service() {
          captured_vars="$2"
          return 0
        }
        When call _config_ringbuffer
        The status should be success
        The variable captured_vars should equal "RINGBUFFER_INTERFACE=eno1"
      End

      It "uses eth0 as fallback when DEFAULT_INTERFACE is unset"
        unset DEFAULT_INTERFACE
        captured_vars=""
        deploy_systemd_service() {
          captured_vars="$2"
          return 0
        }
        When call _config_ringbuffer
        The status should be success
        The variable captured_vars should equal "RINGBUFFER_INTERFACE=eth0"
      End

      It "uses eth0 as fallback when DEFAULT_INTERFACE is empty"
        DEFAULT_INTERFACE=""
        captured_vars=""
        deploy_systemd_service() {
          captured_vars="$2"
          return 0
        }
        When call _config_ringbuffer
        The status should be success
        The variable captured_vars should equal "RINGBUFFER_INTERFACE=eth0"
      End

      It "handles interface names with numbers"
        DEFAULT_INTERFACE="enp3s0f1"
        captured_vars=""
        deploy_systemd_service() {
          captured_vars="$2"
          return 0
        }
        When call _config_ringbuffer
        The status should be success
        The variable captured_vars should equal "RINGBUFFER_INTERFACE=enp3s0f1"
      End
    End

    # -------------------------------------------------------------------------
    # Failure handling
    # -------------------------------------------------------------------------
    Describe "failure handling"
      It "fails when deploy_systemd_service fails"
        MOCK_REMOTE_COPY_RESULT=1
        When call _config_ringbuffer
        The status should be failure
      End

      It "does not mark configured on failure"
        MOCK_REMOTE_COPY_RESULT=1
        marked_as=""
        parallel_mark_configured() { marked_as="$1"; }
        When call _config_ringbuffer
        The status should be failure
        The variable marked_as should equal ""
      End
    End
  End

  # ===========================================================================
  # configure_ringbuffer() - public wrapper
  # ===========================================================================
  Describe "configure_ringbuffer()"
    BeforeEach 'MOCK_REMOTE_COPY_RESULT=0; DEFAULT_INTERFACE=""'

    # -------------------------------------------------------------------------
    # Skip conditions
    # -------------------------------------------------------------------------
    Describe "skip conditions"
      It "skips when INSTALL_RINGBUFFER is not yes"
        INSTALL_RINGBUFFER="no"
        config_called=false
        _config_ringbuffer() { config_called=true; return 0; }
        When call configure_ringbuffer
        The status should be success
        The variable config_called should equal false
      End

      It "skips when INSTALL_RINGBUFFER is unset"
        unset INSTALL_RINGBUFFER
        config_called=false
        _config_ringbuffer() { config_called=true; return 0; }
        When call configure_ringbuffer
        The status should be success
        The variable config_called should equal false
      End

      It "skips when INSTALL_RINGBUFFER is empty"
        INSTALL_RINGBUFFER=""
        config_called=false
        _config_ringbuffer() { config_called=true; return 0; }
        When call configure_ringbuffer
        The status should be success
        The variable config_called should equal false
      End

      It "skips when INSTALL_RINGBUFFER is 'Yes' (case sensitive)"
        INSTALL_RINGBUFFER="Yes"
        config_called=false
        _config_ringbuffer() { config_called=true; return 0; }
        When call configure_ringbuffer
        The status should be success
        The variable config_called should equal false
      End
    End

    # -------------------------------------------------------------------------
    # Execution when enabled
    # -------------------------------------------------------------------------
    Describe "execution when enabled"
      It "configures ringbuffer when INSTALL_RINGBUFFER is yes"
        INSTALL_RINGBUFFER="yes"
        config_called=false
        _config_ringbuffer() { config_called=true; return 0; }
        When call configure_ringbuffer
        The status should be success
        The variable config_called should equal true
      End

      It "configures ringbuffer successfully with real function"
        INSTALL_RINGBUFFER="yes"
        When call configure_ringbuffer
        The status should be success
      End
    End

    # -------------------------------------------------------------------------
    # Error propagation
    # -------------------------------------------------------------------------
    Describe "error propagation"
      It "propagates failure from _config_ringbuffer"
        INSTALL_RINGBUFFER="yes"
        MOCK_REMOTE_COPY_RESULT=1
        When call configure_ringbuffer
        The status should be failure
      End

      It "returns success when _config_ringbuffer succeeds"
        INSTALL_RINGBUFFER="yes"
        _config_ringbuffer() { return 0; }
        When call configure_ringbuffer
        The status should be success
      End
    End
  End
End
