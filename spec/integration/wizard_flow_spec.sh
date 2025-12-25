# shellcheck shell=bash
# shellcheck disable=SC2016,SC2034
# =============================================================================
# Integration tests for wizard flow
# Tests: Full wizard navigation and configuration flow with mocked UI
# =============================================================================

%const SCRIPTS_DIR: "${SHELLSPEC_PROJECT_ROOT}/scripts"
%const SUPPORT_DIR: "${SHELLSPEC_PROJECT_ROOT}/spec/support"

# Load mocks
eval "$(cat "$SUPPORT_DIR/core_mocks.sh")"
eval "$(cat "$SUPPORT_DIR/wizard_mocks.sh")"

# =============================================================================
# Test setup
# =============================================================================
setup_wizard_test() {
  reset_wizard_mocks

  # Initialize wizard state
  WIZ_CURRENT_SCREEN=0
  WIZ_SCREENS=("Basic" "Proxmox" "Network" "Storage" "Services" "Access")
  declare -gA _WIZ_FIELD_MAP
  _WIZ_FIELD_COUNT=0

  # Required globals with empty defaults
  PVE_HOSTNAME=""
  DOMAIN_SUFFIX=""
  EMAIL=""
  NEW_ROOT_PASSWORD=""
  TIMEZONE=""
  KEYBOARD=""
  COUNTRY=""
  PROXMOX_ISO_VERSION=""
  PVE_REPO_TYPE=""
  INTERFACE_NAME=""
  BRIDGE_MODE=""
  PRIVATE_SUBNET=""
  IPV6_MODE=""
  ZFS_RAID=""
  ZFS_ARC_MODE=""
  SHELL_TYPE=""
  CPU_GOVERNOR=""
  SSH_PUBLIC_KEY=""
  SSL_TYPE=""
  INSTALL_TAILSCALE=""
  FIREWALL_MODE=""
  ZFS_POOL_DISKS=()

  # Mock tput commands (not available in test environment)
  tput() { :; }
  export -f tput

  # Mock cursor functions
  _wiz_show_cursor() { :; }
  _wiz_hide_cursor() { :; }
  export -f _wiz_show_cursor _wiz_hide_cursor
}

setup_complete_config() {
  PVE_HOSTNAME="testnode"
  DOMAIN_SUFFIX="example.com"
  EMAIL="admin@example.com"
  NEW_ROOT_PASSWORD="SecurePass123!"
  TIMEZONE="UTC"
  KEYBOARD="us"
  COUNTRY="US"
  PROXMOX_ISO_VERSION="8.3"
  PVE_REPO_TYPE="no-subscription"
  INTERFACE_NAME="eth0"
  BRIDGE_MODE="internal"
  PRIVATE_SUBNET="10.0.0.0/24"
  IPV6_MODE="slaac"
  ZFS_RAID="mirror"
  ZFS_ARC_MODE="auto"
  SHELL_TYPE="zsh"
  CPU_GOVERNOR="performance"
  SSH_PUBLIC_KEY="ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAI... user@host"
  SSL_TYPE="letsencrypt"
  INSTALL_TAILSCALE="no"
  FIREWALL_MODE="standard"
  ZFS_POOL_DISKS=("/dev/sda" "/dev/sdb")
}

# Helper to call _validate_config suppressing stdout (it prints missing fields)
validate_config_quiet() {
  _validate_config >/dev/null 2>&1
}

Describe "Wizard Flow Integration"
  Include "$SCRIPTS_DIR/100-wizard-core.sh"

  BeforeEach 'setup_wizard_test'

  # ===========================================================================
  # Configuration validation
  # ===========================================================================
  Describe "_validate_config()"
    Describe "with complete configuration"
      BeforeEach 'setup_complete_config; MOCK_CONFIG_COMPLETE=0'

      It "returns success when all required fields are set"
        When call _validate_config
        The status should be success
      End
    End

    Describe "with incomplete configuration"
      It "fails when hostname is missing"
        setup_complete_config
        PVE_HOSTNAME=""
        MOCK_CONFIG_COMPLETE=1

        When call validate_config_quiet
        The status should be failure
      End

      It "fails when password is missing"
        setup_complete_config
        NEW_ROOT_PASSWORD=""
        MOCK_CONFIG_COMPLETE=1

        When call validate_config_quiet
        The status should be failure
      End

      It "fails when SSH key is missing"
        setup_complete_config
        SSH_PUBLIC_KEY=""
        MOCK_CONFIG_COMPLETE=1

        When call validate_config_quiet
        The status should be failure
      End

      It "fails when pool disks are missing"
        setup_complete_config
        ZFS_POOL_DISKS=()
        MOCK_CONFIG_COMPLETE=1

        When call validate_config_quiet
        The status should be failure
      End

      It "fails when SSL is missing without Tailscale"
        setup_complete_config
        SSL_TYPE=""
        INSTALL_TAILSCALE="no"
        MOCK_CONFIG_COMPLETE=1

        When call validate_config_quiet
        The status should be failure
      End

      It "requires Tailscale for stealth firewall mode"
        setup_complete_config
        FIREWALL_MODE="stealth"
        INSTALL_TAILSCALE="no"
        MOCK_CONFIG_COMPLETE=1

        When call validate_config_quiet
        The status should be failure
      End
    End

    Describe "SSL requirements based on Tailscale"
      It "requires SSL when Tailscale is disabled"
        setup_complete_config
        SSL_TYPE=""
        INSTALL_TAILSCALE="no"
        MOCK_CONFIG_COMPLETE=1

        When call validate_config_quiet
        The status should be failure
      End

      It "does not require SSL when Tailscale is enabled"
        setup_complete_config
        SSL_TYPE=""
        INSTALL_TAILSCALE="yes"
        MOCK_CONFIG_COMPLETE=0

        When call _validate_config
        The status should be success
      End
    End

    Describe "private subnet requirements based on bridge mode"
      It "requires private subnet for internal bridge mode"
        setup_complete_config
        BRIDGE_MODE="internal"
        PRIVATE_SUBNET=""
        MOCK_CONFIG_COMPLETE=1

        When call validate_config_quiet
        The status should be failure
      End

      It "does not require private subnet for external bridge mode"
        setup_complete_config
        BRIDGE_MODE="external"
        PRIVATE_SUBNET=""
        MOCK_CONFIG_COMPLETE=0

        When call _validate_config
        The status should be success
      End
    End
  End

  # ===========================================================================
  # Wizard main loop navigation
  # ===========================================================================
  Describe "_wizard_main() navigation"
    BeforeEach 'setup_wizard_test'

    It "starts on first screen"
      _wiz_read_key() { WIZ_KEY="start"; }

      When call _wizard_main
      The variable WIZ_CURRENT_SCREEN should equal 0
    End

    It "navigates to next screen on right key"
      # Mock read_key to return 'right' then 'start'
      call_count=0
      _wiz_read_key() {
        call_count=$((call_count + 1))
        if [[ $call_count -eq 1 ]]; then
          WIZ_KEY="right"
        else
          WIZ_KEY="start"
        fi
      }

      When call _wizard_main
      The variable WIZ_CURRENT_SCREEN should equal 1
    End

    It "navigates to previous screen on left key"
      WIZ_CURRENT_SCREEN=2

      call_count=0
      _wiz_read_key() {
        call_count=$((call_count + 1))
        if [[ $call_count -eq 1 ]]; then
          WIZ_KEY="left"
        else
          WIZ_KEY="start"
        fi
      }

      When call _wizard_main
      The variable WIZ_CURRENT_SCREEN should equal 1
    End

    It "does not go before first screen"
      WIZ_CURRENT_SCREEN=0

      call_count=0
      _wiz_read_key() {
        call_count=$((call_count + 1))
        if [[ $call_count -eq 1 ]]; then
          WIZ_KEY="left"
        else
          WIZ_KEY="start"
        fi
      }

      When call _wizard_main
      The variable WIZ_CURRENT_SCREEN should equal 0
    End

    It "does not go past last screen"
      WIZ_CURRENT_SCREEN=5

      call_count=0
      _wiz_read_key() {
        call_count=$((call_count + 1))
        if [[ $call_count -eq 1 ]]; then
          WIZ_KEY="right"
        else
          WIZ_KEY="start"
        fi
      }

      When call _wizard_main
      The variable WIZ_CURRENT_SCREEN should equal 5
    End

    It "returns 0 when user presses start"
      _wiz_read_key() { WIZ_KEY="start"; }

      When call _wizard_main
      The status should be success
    End
  End

  # ===========================================================================
  # Field editing dispatch
  # ===========================================================================
  Describe "field editing"
    BeforeEach 'setup_wizard_test; MOCK_EDIT_CALLS=()'

    It "dispatches to hostname editor"
      _WIZ_FIELD_MAP[0]="hostname"
      _WIZ_FIELD_COUNT=1

      call_count=0
      _wiz_read_key() {
        call_count=$((call_count + 1))
        if [[ $call_count -eq 1 ]]; then
          WIZ_KEY="enter"
        else
          WIZ_KEY="start"
        fi
      }

      When call _wizard_main
      The value "${MOCK_EDIT_CALLS[*]}" should include "hostname"
    End

    It "dispatches to email editor"
      _WIZ_FIELD_MAP[0]="email"
      _WIZ_FIELD_COUNT=1

      call_count=0
      _wiz_read_key() {
        call_count=$((call_count + 1))
        if [[ $call_count -eq 1 ]]; then
          WIZ_KEY="enter"
        else
          WIZ_KEY="start"
        fi
      }

      When call _wizard_main
      The value "${MOCK_EDIT_CALLS[*]}" should include "email"
    End

    It "dispatches to password editor"
      _WIZ_FIELD_MAP[0]="password"
      _WIZ_FIELD_COUNT=1

      call_count=0
      _wiz_read_key() {
        call_count=$((call_count + 1))
        if [[ $call_count -eq 1 ]]; then
          WIZ_KEY="enter"
        else
          WIZ_KEY="start"
        fi
      }

      When call _wizard_main
      The value "${MOCK_EDIT_CALLS[*]}" should include "password"
    End
  End

  # ===========================================================================
  # Selection movement
  # ===========================================================================
  Describe "selection movement"
    BeforeEach 'setup_wizard_test; _WIZ_FIELD_COUNT=5'

    It "moves selection down"
      final_selection=0
      _wiz_render_menu() { final_selection=$1; }

      call_count=0
      _wiz_read_key() {
        call_count=$((call_count + 1))
        if [[ $call_count -le 2 ]]; then
          WIZ_KEY="down"
        else
          WIZ_KEY="start"
        fi
      }

      When call _wizard_main
      # After 2 'down' presses, selection should be 2
      The variable final_selection should equal 2
    End

    It "moves selection up"
      final_selection=0
      _wiz_render_menu() { final_selection=$1; }

      call_count=0
      _wiz_read_key() {
        call_count=$((call_count + 1))
        case $call_count in
          1|2) WIZ_KEY="down" ;;
          3) WIZ_KEY="up" ;;
          *) WIZ_KEY="start" ;;
        esac
      }

      When call _wizard_main
      # 2 down + 1 up = 1
      The variable final_selection should equal 1
    End

    It "does not go below 0"
      final_selection=0
      _wiz_render_menu() { final_selection=$1; }

      call_count=0
      _wiz_read_key() {
        call_count=$((call_count + 1))
        if [[ $call_count -eq 1 ]]; then
          WIZ_KEY="up"
        else
          WIZ_KEY="start"
        fi
      }

      When call _wizard_main
      The variable final_selection should equal 0
    End

    It "does not exceed field count"
      final_selection=0
      _wiz_render_menu() { final_selection=$1; }

      call_count=0
      _wiz_read_key() {
        call_count=$((call_count + 1))
        if [[ $call_count -le 10 ]]; then
          WIZ_KEY="down"
        else
          WIZ_KEY="start"
        fi
      }

      When call _wizard_main
      # Should stop at _WIZ_FIELD_COUNT - 1 = 4
      The variable final_selection should equal 4
    End
  End

  # ===========================================================================
  # Quit confirmation
  # ===========================================================================
  Describe "quit handling"
    It "shows confirmation on quit key"
      MOCK_CONFIRM_RESULT=1 # User says "no" to quit

      call_count=0
      _wiz_read_key() {
        call_count=$((call_count + 1))
        if [[ $call_count -eq 1 ]]; then
          WIZ_KEY="quit"
        else
          WIZ_KEY="start"
        fi
      }

      When call _wizard_main
      The status should be success
      # Confirm was called
      The value "${MOCK_CALLS[*]}" should include "_wiz_confirm"
    End

    It "shows confirmation on esc key"
      MOCK_CONFIRM_RESULT=1

      call_count=0
      _wiz_read_key() {
        call_count=$((call_count + 1))
        if [[ $call_count -eq 1 ]]; then
          WIZ_KEY="esc"
        else
          WIZ_KEY="start"
        fi
      }

      When call _wizard_main
      The value "${MOCK_CALLS[*]}" should include "_wiz_confirm"
    End
  End
End

