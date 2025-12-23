# shellcheck shell=bash
# shellcheck disable=SC2034,SC2016
# =============================================================================
# Tests for 039-network-helpers.sh
# =============================================================================

%const SCRIPTS_DIR: "${SHELLSPEC_PROJECT_ROOT}/scripts"
%const SUPPORT_DIR: "${SHELLSPEC_PROJECT_ROOT}/spec/support"

# Load shared mocks
eval "$(cat "$SUPPORT_DIR/colors.sh")"
eval "$(cat "$SUPPORT_DIR/core_mocks.sh")"

# Setup default test environment
setup_network_env() {
  INTERFACE_NAME="eth0"
  MAIN_IPV4="192.168.1.100"
  MAIN_IPV4_GW="192.168.1.1"
  MAIN_IPV4_CIDR="192.168.1.100/24"
  MAIN_IPV6=""
  IPV6_MODE="disabled"
  BRIDGE_MODE="internal"
  BRIDGE_MTU="9000"
  PRIVATE_IP_CIDR="10.0.0.1/24"
}

Describe "039-network-helpers.sh"
  Include "$SCRIPTS_DIR/039-network-helpers.sh"

  BeforeEach 'setup_network_env'

  # ===========================================================================
  # _generate_loopback()
  # ===========================================================================
  Describe "_generate_loopback()"
    It "generates loopback configuration"
      When call _generate_loopback
      The output should include "auto lo"
      The output should include "iface lo inet loopback"
      The output should include "iface lo inet6 loopback"
    End
  End

  # ===========================================================================
  # _generate_iface_manual()
  # ===========================================================================
  Describe "_generate_iface_manual()"
    It "generates manual interface configuration"
      INTERFACE_NAME="enp3s0"
      When call _generate_iface_manual
      The output should include "auto enp3s0"
      The output should include "iface enp3s0 inet manual"
    End

    It "includes interface name from variable"
      INTERFACE_NAME="eth1"
      When call _generate_iface_manual
      The output should include "eth1"
    End
  End

  # ===========================================================================
  # _generate_iface_static()
  # ===========================================================================
  Describe "_generate_iface_static()"
    It "generates static IPv4 configuration"
      When call _generate_iface_static
      The output should include "auto eth0"
      The output should include "iface eth0 inet static"
      The output should include "address 192.168.1.100/24"
      The output should include "gateway 192.168.1.1"
    End

    It "adds pointopoint for /32 subnets"
      MAIN_IPV4_CIDR="192.168.1.100/32"
      When call _generate_iface_static
      The output should include "pointopoint 192.168.1.1"
    End

    It "skips pointopoint for larger subnets"
      MAIN_IPV4_CIDR="192.168.1.100/24"
      When call _generate_iface_static
      The output should not include "pointopoint"
    End

    It "includes sysctl setup"
      When call _generate_iface_static
      The output should include "sysctl --system"
    End

    It "adds IPv6 when enabled"
      MAIN_IPV6="2001:db8::1"
      IPV6_MODE="slaac"
      IPV6_CIDR="2001:db8::1/64"
      When call _generate_iface_static
      The output should include "iface eth0 inet6 static"
      The output should include "address 2001:db8::1/64"
    End

    It "uses default IPv6 gateway when not set"
      MAIN_IPV6="2001:db8::1"
      IPV6_MODE="slaac"
      When call _generate_iface_static
      The output should include "gateway fe80::1"
    End

    It "uses custom IPv6 gateway when set"
      MAIN_IPV6="2001:db8::1"
      IPV6_MODE="slaac"
      IPV6_GATEWAY="2001:db8::ffff"
      When call _generate_iface_static
      The output should include "gateway 2001:db8::ffff"
    End

    It "adds on-link route for /128 with non-link-local gateway"
      MAIN_IPV6="2001:db8::1"
      IPV6_MODE="slaac"
      IPV6_CIDR="2001:db8::1/128"
      IPV6_GATEWAY="2001:db8::ffff"
      When call _generate_iface_static
      The output should include "ip -6 route add 2001:db8::ffff/128"
    End
  End

  # ===========================================================================
  # _generate_vmbr0_external()
  # ===========================================================================
  Describe "_generate_vmbr0_external()"
    It "generates external bridge configuration"
      When call _generate_vmbr0_external
      The output should include "auto vmbr0"
      The output should include "iface vmbr0 inet static"
      The output should include "bridge-ports eth0"
      The output should include "bridge-stp off"
    End

    It "uses host IP on bridge"
      When call _generate_vmbr0_external
      The output should include "address 192.168.1.100/24"
      The output should include "gateway 192.168.1.1"
    End

    It "adds pointopoint for /32 subnets"
      MAIN_IPV4_CIDR="10.0.0.1/32"
      When call _generate_vmbr0_external
      The output should include "pointopoint"
    End

    It "adds IPv6 when enabled"
      MAIN_IPV6="2001:db8::1"
      IPV6_MODE="slaac"
      IPV6_CIDR="2001:db8::1/64"
      When call _generate_vmbr0_external
      The output should include "iface vmbr0 inet6 static"
    End
  End

  # ===========================================================================
  # _generate_vmbr0_nat()
  # ===========================================================================
  Describe "_generate_vmbr0_nat()"
    It "generates NAT bridge configuration"
      When call _generate_vmbr0_nat
      The output should include "auto vmbr0"
      The output should include "iface vmbr0 inet static"
      The output should include "address 10.0.0.1/24"
      The output should include "bridge-ports none"
    End

    It "uses configured MTU"
      BRIDGE_MTU="1500"
      When call _generate_vmbr0_nat
      The output should include "mtu 1500"
    End

    It "includes CT zone rules for VM networking"
      When call _generate_vmbr0_nat
      The output should include "iptables -t raw"
      The output should include "CT --zone 1"
    End

    It "adds IPv6 when FIRST_IPV6_CIDR is set"
      FIRST_IPV6_CIDR="fd00::1/64"
      IPV6_MODE="slaac"
      When call _generate_vmbr0_nat
      The output should include "iface vmbr0 inet6 static"
      The output should include "address fd00::1/64"
    End
  End

  # ===========================================================================
  # _generate_vmbr1_nat()
  # ===========================================================================
  Describe "_generate_vmbr1_nat()"
    It "generates secondary NAT bridge configuration"
      When call _generate_vmbr1_nat
      The output should include "auto vmbr1"
      The output should include "iface vmbr1 inet static"
      The output should include "bridge-ports none"
    End

    It "uses same MTU as primary bridge"
      BRIDGE_MTU="9000"
      When call _generate_vmbr1_nat
      The output should include "mtu 9000"
    End
  End

  # ===========================================================================
  # _generate_interfaces_conf()
  # ===========================================================================
  Describe "_generate_interfaces_conf()"
    It "includes header with source directive"
      When call _generate_interfaces_conf
      The output should include "source /etc/network/interfaces.d/*"
    End

    It "includes loopback"
      When call _generate_interfaces_conf
      The output should include "auto lo"
    End

    Describe "with internal mode"
      It "generates host IP on physical interface"
        BRIDGE_MODE="internal"
        When call _generate_interfaces_conf
        The output should include "iface eth0 inet static"
      End

      It "generates NAT bridge"
        BRIDGE_MODE="internal"
        When call _generate_interfaces_conf
        The output should include "bridge-ports none"
      End
    End

    Describe "with external mode"
      It "generates physical interface as manual"
        BRIDGE_MODE="external"
        When call _generate_interfaces_conf
        The output should include "iface eth0 inet manual"
      End

      It "generates host IP on vmbr0 bridge"
        BRIDGE_MODE="external"
        When call _generate_interfaces_conf
        The output should include "bridge-ports eth0"
      End
    End

    Describe "with both mode"
      It "generates physical interface as manual"
        BRIDGE_MODE="both"
        When call _generate_interfaces_conf
        The output should include "iface eth0 inet manual"
      End

      It "generates both vmbr0 and vmbr1"
        BRIDGE_MODE="both"
        When call _generate_interfaces_conf
        The output should include "auto vmbr0"
        The output should include "auto vmbr1"
      End
    End
  End

  # ===========================================================================
  # generate_interfaces_file()
  # ===========================================================================
  Describe "generate_interfaces_file()"
    It "writes configuration to specified file"
      output_file="${SHELLSPEC_TMPBASE}/interfaces"
      When call generate_interfaces_file "$output_file"
      The status should be success
      The file "$output_file" should be exist
    End

    It "writes valid interfaces content"
      output_file="${SHELLSPEC_TMPBASE}/interfaces"
      generate_interfaces_file "$output_file"
      When call cat "$output_file"
      The output should include "auto lo"
    End

    It "uses default path when not specified"
      mkdir -p "${SHELLSPEC_TMPBASE}/templates"
      cd "${SHELLSPEC_TMPBASE}" || return
      When call generate_interfaces_file
      The file "./templates/interfaces" should be exist
      rm -rf "${SHELLSPEC_TMPBASE}/templates"
    End
  End
End

