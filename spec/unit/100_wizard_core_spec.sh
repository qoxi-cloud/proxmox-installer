# shellcheck shell=bash
# shellcheck disable=SC2034,SC2154
# =============================================================================
# Tests for 100-wizard-core.sh
# =============================================================================
# Note: SC2034 disabled - variables used by ShellSpec assertions
#       SC2154 disabled - variables set by mocks

%const SCRIPTS_DIR: "${SHELLSPEC_PROJECT_ROOT}/scripts"
%const SUPPORT_DIR: "${SHELLSPEC_PROJECT_ROOT}/spec/support"

# Load shared mocks
eval "$(cat "$SUPPORT_DIR/colors.sh")"
eval "$(cat "$SUPPORT_DIR/core_mocks.sh")"
eval "$(cat "$SUPPORT_DIR/ui_mocks.sh")"

# =============================================================================
# Additional UI mocks for wizard functions
# =============================================================================

# Track function calls for assertions
MOCK_RENDER_MENU_CALLS=0
MOCK_READ_KEY_SEQUENCE=()
MOCK_READ_KEY_INDEX=0
MOCK_CONFIRM_RESULT=1
MOCK_CONFIG_COMPLETE=1
MOCK_EDIT_CALLS=()

# Reset mocks between tests
reset_wizard_mocks() {
  MOCK_RENDER_MENU_CALLS=0
  MOCK_READ_KEY_SEQUENCE=()
  MOCK_READ_KEY_INDEX=0
  MOCK_CONFIRM_RESULT=1
  MOCK_CONFIG_COMPLETE=1
  MOCK_EDIT_CALLS=()
  WIZ_CURRENT_SCREEN=0
  _WIZ_FIELD_COUNT=3
  _WIZ_FIELD_MAP=("hostname" "email" "password")
}

# Mock wizard UI functions
_wiz_render_menu() {
  ((MOCK_RENDER_MENU_CALLS++))
}

_wiz_read_key() {
  if [[ $MOCK_READ_KEY_INDEX -lt ${#MOCK_READ_KEY_SEQUENCE[@]} ]]; then
    WIZ_KEY="${MOCK_READ_KEY_SEQUENCE[$MOCK_READ_KEY_INDEX]}"
    ((MOCK_READ_KEY_INDEX++))
  else
    # Default to start to exit the loop
    WIZ_KEY="start"
  fi
}

_wiz_start_edit() { :; }
_wiz_blank_line() { :; }
_wiz_error() { :; }
_wiz_warn() { :; }
_wiz_center() { echo "$1"; }
_wiz_confirm() { return $MOCK_CONFIRM_RESULT; }
_wiz_config_complete() { return $MOCK_CONFIG_COMPLETE; }

# Mock tput commands
tput() {
  case "$1" in
    smcup | rmcup) : ;;
    cuu) : ;;
    cnorm | civis) : ;;
    *) : ;;
  esac
}

# Mock show_banner
show_banner() { :; }

# Mock all _edit_* functions - track calls
_edit_hostname() { MOCK_EDIT_CALLS+=("hostname"); }
_edit_email() { MOCK_EDIT_CALLS+=("email"); }
_edit_password() { MOCK_EDIT_CALLS+=("password"); }
_edit_timezone() { MOCK_EDIT_CALLS+=("timezone"); }
_edit_keyboard() { MOCK_EDIT_CALLS+=("keyboard"); }
_edit_country() { MOCK_EDIT_CALLS+=("country"); }
_edit_iso_version() { MOCK_EDIT_CALLS+=("iso_version"); }
_edit_repository() { MOCK_EDIT_CALLS+=("repository"); }
_edit_interface() { MOCK_EDIT_CALLS+=("interface"); }
_edit_bridge_mode() { MOCK_EDIT_CALLS+=("bridge_mode"); }
_edit_private_subnet() { MOCK_EDIT_CALLS+=("private_subnet"); }
_edit_bridge_mtu() { MOCK_EDIT_CALLS+=("bridge_mtu"); }
_edit_ipv6() { MOCK_EDIT_CALLS+=("ipv6"); }
_edit_firewall() { MOCK_EDIT_CALLS+=("firewall"); }
_edit_boot_disk() { MOCK_EDIT_CALLS+=("boot_disk"); }
_edit_pool_disks() { MOCK_EDIT_CALLS+=("pool_disks"); }
_edit_zfs_mode() { MOCK_EDIT_CALLS+=("zfs_mode"); }
_edit_zfs_arc() { MOCK_EDIT_CALLS+=("zfs_arc"); }
_edit_tailscale() { MOCK_EDIT_CALLS+=("tailscale"); }
_edit_ssl() { MOCK_EDIT_CALLS+=("ssl"); }
_edit_shell() { MOCK_EDIT_CALLS+=("shell"); }
_edit_power_profile() { MOCK_EDIT_CALLS+=("power_profile"); }
_edit_features_security() { MOCK_EDIT_CALLS+=("security"); }
_edit_features_monitoring() { MOCK_EDIT_CALLS+=("monitoring"); }
_edit_features_tools() { MOCK_EDIT_CALLS+=("tools"); }
_edit_api_token() { MOCK_EDIT_CALLS+=("api_token"); }
_edit_admin_username() { MOCK_EDIT_CALLS+=("admin_username"); }
_edit_admin_password() { MOCK_EDIT_CALLS+=("admin_password"); }
_edit_ssh_key() { MOCK_EDIT_CALLS+=("ssh_key"); }

# Screen definitions
WIZ_SCREENS=("Basic" "Proxmox" "Network" "Storage" "Services" "Access")

Describe "100-wizard-core.sh"
  Include "$SCRIPTS_DIR/100-wizard-core.sh"

  # ===========================================================================
  # _show_input_footer()
  # ===========================================================================
  Describe "_show_input_footer()"
    BeforeEach 'reset_wizard_mocks'

    It "outputs footer for input type (default)"
      When call _show_input_footer
      The status should be success
      The output should include "Enter"
      The output should include "confirm"
    End

    It "outputs footer for filter type"
      When call _show_input_footer "filter"
      The status should be success
      The output should include "navigate"
      The output should include "select"
    End

    It "outputs footer for checkbox type"
      When call _show_input_footer "checkbox"
      The status should be success
      The output should include "toggle"
      The output should include "Space"
    End

    It "accepts component lines parameter"
      When call _show_input_footer "input" 3
      The status should be success
      The output should include "confirm"
    End

    It "defaults to 1 component line"
      When call _show_input_footer "filter"
      The status should be success
      The output should include "navigate"
    End
  End

  # ===========================================================================
  # _wizard_main()
  # ===========================================================================
  Describe "_wizard_main()"
    BeforeEach 'reset_wizard_mocks'

    Describe "navigation"
      It "returns 0 when user presses start key"
        MOCK_READ_KEY_SEQUENCE=("start")
        When call _wizard_main
        The status should be success
      End

      It "renders menu on each loop iteration"
        MOCK_READ_KEY_SEQUENCE=("down" "start")
        When call _wizard_main
        The status should be success
        The variable MOCK_RENDER_MENU_CALLS should equal 2
      End

      It "moves selection down on down arrow"
        MOCK_READ_KEY_SEQUENCE=("down" "start")
        When call _wizard_main
        The status should be success
      End

      It "moves selection up on up arrow"
        MOCK_READ_KEY_SEQUENCE=("down" "down" "up" "start")
        When call _wizard_main
        The status should be success
      End

      It "does not go below zero on up at start"
        MOCK_READ_KEY_SEQUENCE=("up" "start")
        When call _wizard_main
        The status should be success
      End

      It "does not exceed field count on down"
        _WIZ_FIELD_COUNT=2
        MOCK_READ_KEY_SEQUENCE=("down" "down" "down" "start")
        When call _wizard_main
        The status should be success
      End
    End

    Describe "screen navigation"
      It "moves to next screen on right arrow"
        MOCK_READ_KEY_SEQUENCE=("right" "start")
        When call _wizard_main
        The status should be success
        The variable WIZ_CURRENT_SCREEN should equal 1
      End

      It "moves to previous screen on left arrow"
        WIZ_CURRENT_SCREEN=2
        MOCK_READ_KEY_SEQUENCE=("left" "start")
        When call _wizard_main
        The status should be success
        The variable WIZ_CURRENT_SCREEN should equal 1
      End

      It "does not go below screen 0 on left"
        WIZ_CURRENT_SCREEN=0
        MOCK_READ_KEY_SEQUENCE=("left" "start")
        When call _wizard_main
        The status should be success
        The variable WIZ_CURRENT_SCREEN should equal 0
      End

      It "does not exceed max screen on right"
        WIZ_CURRENT_SCREEN=5
        MOCK_READ_KEY_SEQUENCE=("right" "start")
        When call _wizard_main
        The status should be success
        The variable WIZ_CURRENT_SCREEN should equal 5
      End

      It "resets selection to 0 when changing screens"
        MOCK_READ_KEY_SEQUENCE=("down" "down" "right" "start")
        When call _wizard_main
        The status should be success
      End
    End

    Describe "field editing"
      It "calls edit function on enter"
        _WIZ_FIELD_MAP=("hostname" "email" "password")
        MOCK_READ_KEY_SEQUENCE=("enter" "start")
        When call _wizard_main
        The status should be success
        The value "${MOCK_EDIT_CALLS[0]}" should equal "hostname"
      End

      It "calls correct edit function based on selection"
        _WIZ_FIELD_MAP=("hostname" "email" "password")
        MOCK_READ_KEY_SEQUENCE=("down" "enter" "start")
        When call _wizard_main
        The status should be success
        The value "${MOCK_EDIT_CALLS[0]}" should equal "email"
      End
    End

    Describe "quit handling"
      It "shows confirmation on quit key"
        MOCK_CONFIRM_RESULT=1  # Return false (don't quit)
        MOCK_READ_KEY_SEQUENCE=("quit" "start")
        When call _wizard_main
        The status should be success
      End

      It "shows confirmation on esc key"
        MOCK_CONFIRM_RESULT=1  # Return false (don't quit)
        MOCK_READ_KEY_SEQUENCE=("esc" "start")
        When call _wizard_main
        The status should be success
      End
    End
  End

  # ===========================================================================
  # _validate_config()
  # ===========================================================================
  Describe "_validate_config()"
    BeforeEach 'reset_wizard_mocks'

    Describe "when configuration is complete"
      It "returns 0 when all fields are set"
        MOCK_CONFIG_COMPLETE=0
        When call _validate_config
        The status should be success
      End
    End

    Describe "when configuration is incomplete"
      # Set minimal config state for testing
      setup_incomplete_config() {
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
        ZFS_POOL_DISKS=()
        INSTALL_TAILSCALE="no"
        SSL_TYPE=""
        FIREWALL_MODE=""
        MOCK_CONFIRM_RESULT=0  # User confirms to return
      }

      BeforeEach 'setup_incomplete_config'

      It "returns 1 when hostname is missing"
        When call _validate_config
        The status should be failure
        The output should include "Hostname"
      End

      It "returns 1 when email is missing"
        PVE_HOSTNAME="test"
        DOMAIN_SUFFIX="example.com"
        When call _validate_config
        The status should be failure
        The output should include "Email"
      End

      It "returns 1 when SSH key is missing"
        PVE_HOSTNAME="test"
        DOMAIN_SUFFIX="example.com"
        EMAIL="test@example.com"
        NEW_ROOT_PASSWORD="password123"
        TIMEZONE="UTC"
        KEYBOARD="us"
        COUNTRY="US"
        PROXMOX_ISO_VERSION="8.3-1"
        PVE_REPO_TYPE="no-subscription"
        INTERFACE_NAME="eth0"
        BRIDGE_MODE="external"
        PRIVATE_SUBNET="10.0.0.0/24"
        IPV6_MODE="disabled"
        ZFS_RAID="single"
        ZFS_ARC_MODE="balanced"
        SHELL_TYPE="zsh"
        CPU_GOVERNOR="performance"
        ZFS_POOL_DISKS=("/dev/sda")
        When call _validate_config
        The status should be failure
        The output should include "SSH Key"
      End
    End

    Describe "SSL validation"
      setup_config_without_ssl() {
        MOCK_CONFIG_COMPLETE=1
        PVE_HOSTNAME=""
        INSTALL_TAILSCALE="no"
        SSL_TYPE=""
        MOCK_CONFIRM_RESULT=0
      }

      BeforeEach 'setup_config_without_ssl'

      It "returns 1 when Tailscale disabled and SSL not configured"
        When call _validate_config
        The status should be failure
        The output should include "SSL Certificate"
      End
    End

    Describe "Stealth firewall validation"
      setup_stealth_without_tailscale() {
        MOCK_CONFIG_COMPLETE=1
        PVE_HOSTNAME=""
        FIREWALL_MODE="stealth"
        INSTALL_TAILSCALE="no"
        MOCK_CONFIRM_RESULT=0
      }

      BeforeEach 'setup_stealth_without_tailscale'

      It "returns 1 when stealth firewall without Tailscale"
        When call _validate_config
        The status should be failure
        The output should include "Tailscale"
      End
    End
  End

  # ===========================================================================
  # show_gum_config_editor()
  # ===========================================================================
  Describe "show_gum_config_editor()"
    BeforeEach 'reset_wizard_mocks'

    # Mock _wizard_main to return immediately
    _wizard_main() { return 0; }
    _validate_config() { return 0; }

    It "enters alternate screen buffer"
      When call show_gum_config_editor
      The status should be success
    End

    It "returns when configuration is complete"
      When call show_gum_config_editor
      The status should be success
    End

    Describe "with validation loop"
      setup_validation_loop() {
        LOOP_COUNT=0
      }

      BeforeEach 'setup_validation_loop'

      It "loops until configuration is valid"
        # Override to fail first, then succeed
        _wizard_main() { return 0; }
        _validate_config() {
          ((LOOP_COUNT++))
          [[ $LOOP_COUNT -ge 2 ]] && return 0
          return 1
        }
        When call show_gum_config_editor
        The status should be success
        The variable LOOP_COUNT should equal 2
      End
    End
  End

  # ===========================================================================
  # Field editing dispatch
  # ===========================================================================
  Describe "field editing dispatch"
    BeforeEach 'reset_wizard_mocks'

    It "dispatches to _edit_timezone for timezone field"
      _WIZ_FIELD_MAP=("timezone")
      MOCK_READ_KEY_SEQUENCE=("enter" "start")
      When call _wizard_main
      The value "${MOCK_EDIT_CALLS[0]}" should equal "timezone"
    End

    It "dispatches to _edit_keyboard for keyboard field"
      _WIZ_FIELD_MAP=("keyboard")
      MOCK_READ_KEY_SEQUENCE=("enter" "start")
      When call _wizard_main
      The value "${MOCK_EDIT_CALLS[0]}" should equal "keyboard"
    End

    It "dispatches to _edit_country for country field"
      _WIZ_FIELD_MAP=("country")
      MOCK_READ_KEY_SEQUENCE=("enter" "start")
      When call _wizard_main
      The value "${MOCK_EDIT_CALLS[0]}" should equal "country"
    End

    It "dispatches to _edit_iso_version for iso_version field"
      _WIZ_FIELD_MAP=("iso_version")
      MOCK_READ_KEY_SEQUENCE=("enter" "start")
      When call _wizard_main
      The value "${MOCK_EDIT_CALLS[0]}" should equal "iso_version"
    End

    It "dispatches to _edit_repository for repository field"
      _WIZ_FIELD_MAP=("repository")
      MOCK_READ_KEY_SEQUENCE=("enter" "start")
      When call _wizard_main
      The value "${MOCK_EDIT_CALLS[0]}" should equal "repository"
    End

    It "dispatches to _edit_interface for interface field"
      _WIZ_FIELD_MAP=("interface")
      MOCK_READ_KEY_SEQUENCE=("enter" "start")
      When call _wizard_main
      The value "${MOCK_EDIT_CALLS[0]}" should equal "interface"
    End

    It "dispatches to _edit_bridge_mode for bridge_mode field"
      _WIZ_FIELD_MAP=("bridge_mode")
      MOCK_READ_KEY_SEQUENCE=("enter" "start")
      When call _wizard_main
      The value "${MOCK_EDIT_CALLS[0]}" should equal "bridge_mode"
    End

    It "dispatches to _edit_private_subnet for private_subnet field"
      _WIZ_FIELD_MAP=("private_subnet")
      MOCK_READ_KEY_SEQUENCE=("enter" "start")
      When call _wizard_main
      The value "${MOCK_EDIT_CALLS[0]}" should equal "private_subnet"
    End

    It "dispatches to _edit_bridge_mtu for bridge_mtu field"
      _WIZ_FIELD_MAP=("bridge_mtu")
      MOCK_READ_KEY_SEQUENCE=("enter" "start")
      When call _wizard_main
      The value "${MOCK_EDIT_CALLS[0]}" should equal "bridge_mtu"
    End

    It "dispatches to _edit_ipv6 for ipv6 field"
      _WIZ_FIELD_MAP=("ipv6")
      MOCK_READ_KEY_SEQUENCE=("enter" "start")
      When call _wizard_main
      The value "${MOCK_EDIT_CALLS[0]}" should equal "ipv6"
    End

    It "dispatches to _edit_firewall for firewall field"
      _WIZ_FIELD_MAP=("firewall")
      MOCK_READ_KEY_SEQUENCE=("enter" "start")
      When call _wizard_main
      The value "${MOCK_EDIT_CALLS[0]}" should equal "firewall"
    End

    It "dispatches to _edit_boot_disk for boot_disk field"
      _WIZ_FIELD_MAP=("boot_disk")
      MOCK_READ_KEY_SEQUENCE=("enter" "start")
      When call _wizard_main
      The value "${MOCK_EDIT_CALLS[0]}" should equal "boot_disk"
    End

    It "dispatches to _edit_pool_disks for pool_disks field"
      _WIZ_FIELD_MAP=("pool_disks")
      MOCK_READ_KEY_SEQUENCE=("enter" "start")
      When call _wizard_main
      The value "${MOCK_EDIT_CALLS[0]}" should equal "pool_disks"
    End

    It "dispatches to _edit_zfs_mode for zfs_mode field"
      _WIZ_FIELD_MAP=("zfs_mode")
      MOCK_READ_KEY_SEQUENCE=("enter" "start")
      When call _wizard_main
      The value "${MOCK_EDIT_CALLS[0]}" should equal "zfs_mode"
    End

    It "dispatches to _edit_zfs_arc for zfs_arc field"
      _WIZ_FIELD_MAP=("zfs_arc")
      MOCK_READ_KEY_SEQUENCE=("enter" "start")
      When call _wizard_main
      The value "${MOCK_EDIT_CALLS[0]}" should equal "zfs_arc"
    End

    It "dispatches to _edit_tailscale for tailscale field"
      _WIZ_FIELD_MAP=("tailscale")
      MOCK_READ_KEY_SEQUENCE=("enter" "start")
      When call _wizard_main
      The value "${MOCK_EDIT_CALLS[0]}" should equal "tailscale"
    End

    It "dispatches to _edit_ssl for ssl field"
      _WIZ_FIELD_MAP=("ssl")
      MOCK_READ_KEY_SEQUENCE=("enter" "start")
      When call _wizard_main
      The value "${MOCK_EDIT_CALLS[0]}" should equal "ssl"
    End

    It "dispatches to _edit_shell for shell field"
      _WIZ_FIELD_MAP=("shell")
      MOCK_READ_KEY_SEQUENCE=("enter" "start")
      When call _wizard_main
      The value "${MOCK_EDIT_CALLS[0]}" should equal "shell"
    End

    It "dispatches to _edit_power_profile for power_profile field"
      _WIZ_FIELD_MAP=("power_profile")
      MOCK_READ_KEY_SEQUENCE=("enter" "start")
      When call _wizard_main
      The value "${MOCK_EDIT_CALLS[0]}" should equal "power_profile"
    End

    It "dispatches to _edit_features_security for security field"
      _WIZ_FIELD_MAP=("security")
      MOCK_READ_KEY_SEQUENCE=("enter" "start")
      When call _wizard_main
      The value "${MOCK_EDIT_CALLS[0]}" should equal "security"
    End

    It "dispatches to _edit_features_monitoring for monitoring field"
      _WIZ_FIELD_MAP=("monitoring")
      MOCK_READ_KEY_SEQUENCE=("enter" "start")
      When call _wizard_main
      The value "${MOCK_EDIT_CALLS[0]}" should equal "monitoring"
    End

    It "dispatches to _edit_features_tools for tools field"
      _WIZ_FIELD_MAP=("tools")
      MOCK_READ_KEY_SEQUENCE=("enter" "start")
      When call _wizard_main
      The value "${MOCK_EDIT_CALLS[0]}" should equal "tools"
    End

    It "dispatches to _edit_api_token for api_token field"
      _WIZ_FIELD_MAP=("api_token")
      MOCK_READ_KEY_SEQUENCE=("enter" "start")
      When call _wizard_main
      The value "${MOCK_EDIT_CALLS[0]}" should equal "api_token"
    End

    It "dispatches to _edit_admin_username for admin_username field"
      _WIZ_FIELD_MAP=("admin_username")
      MOCK_READ_KEY_SEQUENCE=("enter" "start")
      When call _wizard_main
      The value "${MOCK_EDIT_CALLS[0]}" should equal "admin_username"
    End

    It "dispatches to _edit_admin_password for admin_password field"
      _WIZ_FIELD_MAP=("admin_password")
      MOCK_READ_KEY_SEQUENCE=("enter" "start")
      When call _wizard_main
      The value "${MOCK_EDIT_CALLS[0]}" should equal "admin_password"
    End

    It "dispatches to _edit_ssh_key for ssh_key field"
      _WIZ_FIELD_MAP=("ssh_key")
      MOCK_READ_KEY_SEQUENCE=("enter" "start")
      When call _wizard_main
      The value "${MOCK_EDIT_CALLS[0]}" should equal "ssh_key"
    End
  End

  # ===========================================================================
  # Edge cases and boundary conditions
  # ===========================================================================
  Describe "edge cases"
    BeforeEach 'reset_wizard_mocks'

    It "handles rapid navigation across all screens"
      WIZ_CURRENT_SCREEN=0
      MOCK_READ_KEY_SEQUENCE=("right" "right" "right" "right" "right" "start")
      When call _wizard_main
      The status should be success
      The variable WIZ_CURRENT_SCREEN should equal 5
    End

    It "handles rapid navigation back to first screen"
      WIZ_CURRENT_SCREEN=5
      MOCK_READ_KEY_SEQUENCE=("left" "left" "left" "left" "left" "start")
      When call _wizard_main
      The status should be success
      The variable WIZ_CURRENT_SCREEN should equal 0
    End

    It "handles multiple field selections"
      _WIZ_FIELD_MAP=("hostname" "email" "password")
      MOCK_READ_KEY_SEQUENCE=("enter" "down" "enter" "down" "enter" "start")
      When call _wizard_main
      The status should be success
      The value "${#MOCK_EDIT_CALLS[@]}" should equal 3
    End

    It "handles empty field map gracefully"
      _WIZ_FIELD_MAP=()
      _WIZ_FIELD_COUNT=0
      MOCK_READ_KEY_SEQUENCE=("start")
      When call _wizard_main
      The status should be success
    End
  End
End

