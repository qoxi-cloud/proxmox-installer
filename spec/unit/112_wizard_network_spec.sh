# shellcheck shell=bash
# shellcheck disable=SC2034,SC2154
# =============================================================================
# Tests for 112-wizard-network.sh
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
# Additional mocks for wizard-network functions
# =============================================================================

# Mock return values
MOCK_WIZ_INPUT_VALUE=""
MOCK_WIZ_INPUT_CANCELLED=false
MOCK_WIZ_CHOOSE_VALUE=""
MOCK_WIZ_CHOOSE_CANCELLED=false

# Sequence-based mock support
MOCK_WIZ_INPUT_SEQUENCE=()
MOCK_WIZ_INPUT_INDEX=0
MOCK_WIZ_CHOOSE_SEQUENCE=()
MOCK_WIZ_CHOOSE_INDEX=0

# Track function calls
MOCK_CALLS=()

reset_network_wizard_mocks() {
  MOCK_WIZ_INPUT_VALUE=""
  MOCK_WIZ_INPUT_CANCELLED=false
  MOCK_WIZ_CHOOSE_VALUE=""
  MOCK_WIZ_CHOOSE_CANCELLED=false
  MOCK_WIZ_INPUT_SEQUENCE=()
  MOCK_WIZ_CHOOSE_SEQUENCE=()
  MOCK_WIZ_CHOOSE_INDEX=0
  MOCK_CALLS=()
  # Reset file-based input index counter
  echo 0 > "$MOCK_INPUT_INDEX_FILE"

  # Reset globals
  INTERFACE_NAME=""
  INTERFACE_COUNT=1
  AVAILABLE_INTERFACES=""
  BRIDGE_MODE=""
  PRIVATE_SUBNET=""
  BRIDGE_MTU=""
  IPV6_MODE=""
  IPV6_ADDRESS=""
  IPV6_GATEWAY=""
  MAIN_IPV6=""
  FIRST_IPV6_CIDR=""
  DEFAULT_IPV6_GATEWAY="fe80::1"
  INSTALL_FIREWALL=""
  FIREWALL_MODE=""
}

# File-based counter for subshell-safe sequence tracking
MOCK_INPUT_INDEX_FILE="/tmp/mock_wiz_input_index.$$"

# Mock UI functions with sequence support
# Uses file-based counter because _wiz_input is called inside $() subshells
_wiz_input() {
  # Read current index from file (default 0)
  local current_index=0
  if [[ -f "$MOCK_INPUT_INDEX_FILE" ]]; then
    current_index=$(cat "$MOCK_INPUT_INDEX_FILE")
  fi

  if [[ $MOCK_WIZ_INPUT_CANCELLED == true ]]; then
    echo ""
    return
  fi

  # Use sequence if defined
  if [[ ${#MOCK_WIZ_INPUT_SEQUENCE[@]} -gt 0 ]]; then
    if [[ $current_index -ge ${#MOCK_WIZ_INPUT_SEQUENCE[@]} ]]; then
      # Sequence exhausted - return empty to break loops
      echo ""
      return
    fi
    local val="${MOCK_WIZ_INPUT_SEQUENCE[$current_index]}"
    # Increment and save index to file
    echo $((current_index + 1)) > "$MOCK_INPUT_INDEX_FILE"
    echo "$val"
  else
    echo "$MOCK_WIZ_INPUT_VALUE"
  fi
}

_wiz_choose() {
  MOCK_CALLS+=("_wiz_choose")
  if [[ $MOCK_WIZ_CHOOSE_CANCELLED == true ]]; then
    return 1
  fi
  # Use sequence if defined
  if [[ ${#MOCK_WIZ_CHOOSE_SEQUENCE[@]} -gt 0 ]]; then
    local val="${MOCK_WIZ_CHOOSE_SEQUENCE[$MOCK_WIZ_CHOOSE_INDEX]:-}"
    ((MOCK_WIZ_CHOOSE_INDEX++)) || true
    # Empty string in sequence means return 1 (cancel)
    if [[ -z $val ]]; then
      return 1
    fi
    echo "$val"
  else
    echo "$MOCK_WIZ_CHOOSE_VALUE"
  fi
}

_wiz_start_edit() { MOCK_CALLS+=("_wiz_start_edit"); }
_wiz_description() { :; }
_wiz_blank_line() { :; }
_wiz_input_screen() { :; }
_show_input_footer() { :; }
show_validation_error() { MOCK_CALLS+=("show_validation_error: $1"); }

# Simplified validation mocks - actual validation tested in 040_validation_spec.sh
validate_subnet() {
  local subnet="$1"
  # Accept anything with a slash (basic check)
  [[ $subnet == */* ]]
}

validate_ipv6_cidr() {
  local ipv6_cidr="$1"
  # Accept anything with a colon and slash
  [[ $ipv6_cidr == *:*/* ]]
}

validate_ipv6_gateway() {
  local gateway="$1"
  # Accept empty, "auto", or anything with colon
  [[ -z $gateway || $gateway == "auto" || $gateway == *:* ]]
}

# Wizard option strings (from 000-init.sh)
WIZ_BRIDGE_MODES="Internal NAT
External bridge
Both"

WIZ_BRIDGE_MTU="9000 (jumbo frames)
1500 (standard)"

WIZ_IPV6_MODES="Auto
Manual
Disabled"

WIZ_PRIVATE_SUBNETS="10.0.0.0/24
192.168.1.0/24
172.16.0.0/24
Custom"

WIZ_FIREWALL_MODES="Stealth (Tailscale only)
Strict (SSH only)
Standard (SSH + Web UI)
Disabled"

Describe "112-wizard-network.sh"
  Include "$SCRIPTS_DIR/112-wizard-network.sh"

  # ===========================================================================
  # _edit_interface()
  # ===========================================================================
  Describe "_edit_interface()"
    BeforeEach 'reset_network_wizard_mocks'

    It "sets INTERFACE_NAME when user selects an interface"
      AVAILABLE_INTERFACES="eth0"
      INTERFACE_COUNT=1
      MOCK_WIZ_CHOOSE_VALUE="eth0"
      When call _edit_interface
      The variable INTERFACE_NAME should equal "eth0"
    End

    It "allows selection from multiple interfaces"
      AVAILABLE_INTERFACES="eth0
eno1
enp3s0"
      INTERFACE_COUNT=3
      MOCK_WIZ_CHOOSE_VALUE="eno1"
      When call _edit_interface
      The variable INTERFACE_NAME should equal "eno1"
    End

    It "uses INTERFACE_NAME as default if AVAILABLE_INTERFACES is not set"
      INTERFACE_NAME="default_eth"
      INTERFACE_COUNT=1
      MOCK_WIZ_CHOOSE_VALUE="default_eth"
      When call _edit_interface
      The variable INTERFACE_NAME should equal "default_eth"
    End

    It "returns without changes when cancelled"
      AVAILABLE_INTERFACES="eth0"
      MOCK_WIZ_CHOOSE_CANCELLED=true
      INTERFACE_NAME="original"
      When call _edit_interface
      The variable INTERFACE_NAME should equal "original"
    End

    It "calls _wiz_start_edit before showing chooser"
      AVAILABLE_INTERFACES="eth0"
      MOCK_WIZ_CHOOSE_VALUE="eth0"
      When call _edit_interface
      The value "${MOCK_CALLS[0]}" should equal "_wiz_start_edit"
    End
  End

  # ===========================================================================
  # _edit_bridge_mode()
  # ===========================================================================
  Describe "_edit_bridge_mode()"
    BeforeEach 'reset_network_wizard_mocks'

    It "sets BRIDGE_MODE to internal when 'Internal NAT' selected"
      MOCK_WIZ_CHOOSE_VALUE="Internal NAT"
      When call _edit_bridge_mode
      The variable BRIDGE_MODE should equal "internal"
    End

    It "sets BRIDGE_MODE to external when 'External bridge' selected"
      MOCK_WIZ_CHOOSE_VALUE="External bridge"
      When call _edit_bridge_mode
      The variable BRIDGE_MODE should equal "external"
    End

    It "sets BRIDGE_MODE to both when 'Both' selected"
      MOCK_WIZ_CHOOSE_VALUE="Both"
      When call _edit_bridge_mode
      The variable BRIDGE_MODE should equal "both"
    End

    It "returns without changes when cancelled"
      MOCK_WIZ_CHOOSE_CANCELLED=true
      BRIDGE_MODE="original"
      When call _edit_bridge_mode
      The variable BRIDGE_MODE should equal "original"
    End

    It "calls _wiz_start_edit before showing options"
      MOCK_WIZ_CHOOSE_VALUE="Internal NAT"
      When call _edit_bridge_mode
      The value "${MOCK_CALLS[0]}" should equal "_wiz_start_edit"
    End
  End

  # ===========================================================================
  # _edit_private_subnet()
  # ===========================================================================
  Describe "_edit_private_subnet()"
    BeforeEach 'reset_network_wizard_mocks'

    Describe "preset subnet selection"
      It "sets PRIVATE_SUBNET to 10.0.0.0/24"
        MOCK_WIZ_CHOOSE_VALUE="10.0.0.0/24"
        When call _edit_private_subnet
        The variable PRIVATE_SUBNET should equal "10.0.0.0/24"
      End

      It "sets PRIVATE_SUBNET to 192.168.1.0/24"
        MOCK_WIZ_CHOOSE_VALUE="192.168.1.0/24"
        When call _edit_private_subnet
        The variable PRIVATE_SUBNET should equal "192.168.1.0/24"
      End

      It "sets PRIVATE_SUBNET to 172.16.0.0/24"
        MOCK_WIZ_CHOOSE_VALUE="172.16.0.0/24"
        When call _edit_private_subnet
        The variable PRIVATE_SUBNET should equal "172.16.0.0/24"
      End
    End

    Describe "custom subnet input"
      It "accepts valid custom subnet"
        MOCK_WIZ_CHOOSE_VALUE="Custom"
        MOCK_WIZ_INPUT_VALUE="10.10.10.0/24"
        When call _edit_private_subnet
        The variable PRIVATE_SUBNET should equal "10.10.10.0/24"
      End

      It "returns without changes when custom input is cancelled"
        MOCK_WIZ_CHOOSE_VALUE="Custom"
        MOCK_WIZ_INPUT_VALUE=""
        PRIVATE_SUBNET="original"
        When call _edit_private_subnet
        The variable PRIVATE_SUBNET should equal "original"
      End

      It "accepts different valid subnets"
        MOCK_WIZ_CHOOSE_VALUE="Custom"
        MOCK_WIZ_INPUT_VALUE="192.168.100.0/24"
        When call _edit_private_subnet
        The variable PRIVATE_SUBNET should equal "192.168.100.0/24"
      End
    End

    Describe "cancellation"
      It "returns without changes when chooser cancelled"
        MOCK_WIZ_CHOOSE_CANCELLED=true
        PRIVATE_SUBNET="original"
        When call _edit_private_subnet
        The variable PRIVATE_SUBNET should equal "original"
      End
    End

  End

  # ===========================================================================
  # _edit_bridge_mtu()
  # ===========================================================================
  Describe "_edit_bridge_mtu()"
    BeforeEach 'reset_network_wizard_mocks'

    It "sets BRIDGE_MTU to 9000 for jumbo frames"
      MOCK_WIZ_CHOOSE_VALUE="9000 (jumbo frames)"
      When call _edit_bridge_mtu
      The variable BRIDGE_MTU should equal "9000"
    End

    It "sets BRIDGE_MTU to 1500 for standard"
      MOCK_WIZ_CHOOSE_VALUE="1500 (standard)"
      When call _edit_bridge_mtu
      The variable BRIDGE_MTU should equal "1500"
    End

    It "returns without changes when cancelled"
      MOCK_WIZ_CHOOSE_CANCELLED=true
      BRIDGE_MTU="original"
      When call _edit_bridge_mtu
      The variable BRIDGE_MTU should equal "original"
    End

    It "calls _wiz_start_edit before showing options"
      MOCK_WIZ_CHOOSE_VALUE="9000 (jumbo frames)"
      When call _edit_bridge_mtu
      The value "${MOCK_CALLS[0]}" should equal "_wiz_start_edit"
    End
  End

  # ===========================================================================
  # _edit_ipv6()
  # ===========================================================================
  Describe "_edit_ipv6()"
    BeforeEach 'reset_network_wizard_mocks'

    Describe "auto mode"
      It "sets IPV6_MODE to auto"
        MOCK_WIZ_CHOOSE_VALUE="Auto"
        When call _edit_ipv6
        The variable IPV6_MODE should equal "auto"
      End

      It "uses default gateway when existing gateway is empty"
        MOCK_WIZ_CHOOSE_VALUE="Auto"
        IPV6_GATEWAY=""
        DEFAULT_IPV6_GATEWAY="fe80::1"
        When call _edit_ipv6
        The variable IPV6_GATEWAY should equal "fe80::1"
      End

      It "preserves existing gateway in auto mode"
        MOCK_WIZ_CHOOSE_VALUE="Auto"
        IPV6_GATEWAY="2001:db8::1"
        When call _edit_ipv6
        The variable IPV6_GATEWAY should equal "2001:db8::1"
      End
    End

    Describe "disabled mode"
      It "sets IPV6_MODE to disabled"
        MOCK_WIZ_CHOOSE_VALUE="Disabled"
        When call _edit_ipv6
        The variable IPV6_MODE should equal "disabled"
      End

      It "clears MAIN_IPV6 when disabled"
        MOCK_WIZ_CHOOSE_VALUE="Disabled"
        MAIN_IPV6="2001:db8::1"
        When call _edit_ipv6
        The variable MAIN_IPV6 should equal ""
      End

      It "clears IPV6_GATEWAY when disabled"
        MOCK_WIZ_CHOOSE_VALUE="Disabled"
        IPV6_GATEWAY="fe80::1"
        When call _edit_ipv6
        The variable IPV6_GATEWAY should equal ""
      End

      It "clears FIRST_IPV6_CIDR when disabled"
        MOCK_WIZ_CHOOSE_VALUE="Disabled"
        FIRST_IPV6_CIDR="2001:db8::1/64"
        When call _edit_ipv6
        The variable FIRST_IPV6_CIDR should equal ""
      End

      It "clears IPV6_ADDRESS when disabled"
        MOCK_WIZ_CHOOSE_VALUE="Disabled"
        IPV6_ADDRESS="2001:db8::1/64"
        When call _edit_ipv6
        The variable IPV6_ADDRESS should equal ""
      End
    End

    Describe "manual mode"
      # Each test needs its own setup function to reset state properly
      setup_manual_mode() {
        reset_network_wizard_mocks
        MOCK_WIZ_CHOOSE_VALUE="Manual"
      }

      It "sets IPV6_MODE to manual with valid inputs"
        setup_manual_mode
        MOCK_WIZ_INPUT_SEQUENCE=("2001:db8::1/64" "fe80::1")
        When call _edit_ipv6
        The variable IPV6_MODE should equal "manual"
      End

      It "sets IPV6_ADDRESS from input"
        setup_manual_mode
        MOCK_WIZ_INPUT_SEQUENCE=("2001:db8::1/64" "fe80::1")
        When call _edit_ipv6
        The variable IPV6_ADDRESS should equal "2001:db8::1/64"
      End

      It "sets MAIN_IPV6 without prefix"
        setup_manual_mode
        MOCK_WIZ_INPUT_SEQUENCE=("2001:db8::1/64" "fe80::1")
        When call _edit_ipv6
        The variable MAIN_IPV6 should equal "2001:db8::1"
      End

      It "sets IPV6_GATEWAY from input"
        setup_manual_mode
        MOCK_WIZ_INPUT_SEQUENCE=("2001:db8::1/64" "2001:db8::ffff")
        When call _edit_ipv6
        The variable IPV6_GATEWAY should equal "2001:db8::ffff"
      End

      It "uses default gateway when gateway input is empty"
        setup_manual_mode
        MOCK_WIZ_INPUT_SEQUENCE=("2001:db8::1/64" "")
        DEFAULT_IPV6_GATEWAY="fe80::1"
        When call _edit_ipv6
        The variable IPV6_GATEWAY should equal "fe80::1"
      End

      It "clears IPV6_MODE when address input cancelled"
        setup_manual_mode
        MOCK_WIZ_INPUT_VALUE=""
        IPV6_MODE="previous"
        When call _edit_ipv6
        The variable IPV6_MODE should equal ""
      End
    End

    Describe "cancellation"
      It "returns without changes when chooser cancelled"
        MOCK_WIZ_CHOOSE_CANCELLED=true
        IPV6_MODE="original"
        When call _edit_ipv6
        The variable IPV6_MODE should equal "original"
      End
    End

    It "calls _wiz_start_edit before showing options"
      MOCK_WIZ_CHOOSE_VALUE="Auto"
      When call _edit_ipv6
      The value "${MOCK_CALLS[0]}" should equal "_wiz_start_edit"
    End
  End

  # ===========================================================================
  # _edit_firewall()
  # ===========================================================================
  Describe "_edit_firewall()"
    BeforeEach 'reset_network_wizard_mocks'

    Describe "stealth mode"
      It "sets FIREWALL_MODE to stealth"
        MOCK_WIZ_CHOOSE_VALUE="Stealth (Tailscale only)"
        When call _edit_firewall
        The variable FIREWALL_MODE should equal "stealth"
      End

      It "enables firewall for stealth mode"
        MOCK_WIZ_CHOOSE_VALUE="Stealth (Tailscale only)"
        When call _edit_firewall
        The variable INSTALL_FIREWALL should equal "yes"
      End
    End

    Describe "strict mode"
      It "sets FIREWALL_MODE to strict"
        MOCK_WIZ_CHOOSE_VALUE="Strict (SSH only)"
        When call _edit_firewall
        The variable FIREWALL_MODE should equal "strict"
      End

      It "enables firewall for strict mode"
        MOCK_WIZ_CHOOSE_VALUE="Strict (SSH only)"
        When call _edit_firewall
        The variable INSTALL_FIREWALL should equal "yes"
      End
    End

    Describe "standard mode"
      It "sets FIREWALL_MODE to standard"
        MOCK_WIZ_CHOOSE_VALUE="Standard (SSH + Web UI)"
        When call _edit_firewall
        The variable FIREWALL_MODE should equal "standard"
      End

      It "enables firewall for standard mode"
        MOCK_WIZ_CHOOSE_VALUE="Standard (SSH + Web UI)"
        When call _edit_firewall
        The variable INSTALL_FIREWALL should equal "yes"
      End
    End

    Describe "disabled mode"
      It "clears FIREWALL_MODE when disabled"
        MOCK_WIZ_CHOOSE_VALUE="Disabled"
        FIREWALL_MODE="previous"
        When call _edit_firewall
        The variable FIREWALL_MODE should equal ""
      End

      It "sets INSTALL_FIREWALL to no when disabled"
        MOCK_WIZ_CHOOSE_VALUE="Disabled"
        When call _edit_firewall
        The variable INSTALL_FIREWALL should equal "no"
      End
    End

    Describe "cancellation"
      It "returns without changes when cancelled"
        MOCK_WIZ_CHOOSE_CANCELLED=true
        FIREWALL_MODE="original"
        INSTALL_FIREWALL="yes"
        When call _edit_firewall
        The variable FIREWALL_MODE should equal "original"
        The variable INSTALL_FIREWALL should equal "yes"
      End
    End

    It "calls _wiz_start_edit before showing options"
      MOCK_WIZ_CHOOSE_VALUE="Standard (SSH + Web UI)"
      When call _edit_firewall
      The value "${MOCK_CALLS[0]}" should equal "_wiz_start_edit"
    End
  End

  # ===========================================================================
  # Edge cases and integration
  # ===========================================================================
  Describe "edge cases"
    BeforeEach 'reset_network_wizard_mocks'

    Describe "interface selection with special names"
      It "handles predictable network names"
        AVAILABLE_INTERFACES="enp0s31f6"
        MOCK_WIZ_CHOOSE_VALUE="enp0s31f6"
        When call _edit_interface
        The variable INTERFACE_NAME should equal "enp0s31f6"
      End

      It "handles bonded interfaces"
        AVAILABLE_INTERFACES="bond0"
        MOCK_WIZ_CHOOSE_VALUE="bond0"
        When call _edit_interface
        The variable INTERFACE_NAME should equal "bond0"
      End
    End


    Describe "subnet validation edge cases"
      It "accepts 0.0.0.0/0"
        MOCK_WIZ_CHOOSE_VALUE="Custom"
        MOCK_WIZ_INPUT_VALUE="0.0.0.0/0"
        When call _edit_private_subnet
        The variable PRIVATE_SUBNET should equal "0.0.0.0/0"
      End

      It "accepts maximum prefix /32"
        MOCK_WIZ_CHOOSE_VALUE="Custom"
        MOCK_WIZ_INPUT_VALUE="10.0.0.1/32"
        When call _edit_private_subnet
        The variable PRIVATE_SUBNET should equal "10.0.0.1/32"
      End
    End
  End
End

