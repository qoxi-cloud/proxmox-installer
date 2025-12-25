# shellcheck shell=bash
# shellcheck disable=SC2016,SC2034
# =============================================================================
# Integration tests for firewall rules generation
# Tests: 310-configure-firewall.sh nftables config for all modes
# =============================================================================

%const SCRIPTS_DIR: "${SHELLSPEC_PROJECT_ROOT}/scripts"
%const SUPPORT_DIR: "${SHELLSPEC_PROJECT_ROOT}/spec/support"

# Load mocks
eval "$(cat "$SUPPORT_DIR/core_mocks.sh")"
eval "$(cat "$SUPPORT_DIR/configure_mocks.sh")"

# =============================================================================
# Test setup
# =============================================================================
setup_firewall_test() {
  # Default settings
  FIREWALL_MODE="standard"
  BRIDGE_MODE="internal"
  INSTALL_FIREWALL="yes"
  INSTALL_TAILSCALE="no"
  PORT_SSH="22"
  PORT_PROXMOX_UI="8006"
  PRIVATE_SUBNET="10.0.0.0/24"

  # Mock functions
  LOG_FILE="${SHELLSPEC_TMPBASE}/test.log"
  touch "$LOG_FILE"

  # Create templates directory for generated config
  mkdir -p "${SHELLSPEC_TMPBASE}/templates"
  cd "${SHELLSPEC_TMPBASE}" || return 1

  # Reset mock results
  MOCK_REMOTE_EXEC_RESULT=0
  MOCK_REMOTE_COPY_RESULT=0
}

cleanup_firewall_test() {
  rm -rf "${SHELLSPEC_TMPBASE}/templates" 2>/dev/null || true
  cd - >/dev/null 2>&1 || true
}

Describe "Firewall Rules Integration"
  Include "$SCRIPTS_DIR/310-configure-firewall.sh"

  BeforeEach 'setup_firewall_test'
  AfterEach 'cleanup_firewall_test'

  # ===========================================================================
  # Port rule generation
  # ===========================================================================
  Describe "_generate_port_rules()"
    Describe "standard mode"
      It "allows SSH and Web UI"
        FIREWALL_MODE="standard"
        PORT_SSH="22"
        PORT_PROXMOX_UI="8006"

        When call _generate_port_rules "standard"
        The output should include "tcp dport 22"
        The output should include "tcp dport 8006"
      End

      It "uses custom SSH port"
        PORT_SSH="2222"

        When call _generate_port_rules "standard"
        The output should include "tcp dport 2222"
      End

      It "uses custom Web UI port"
        PORT_PROXMOX_UI="443"

        When call _generate_port_rules "standard"
        The output should include "tcp dport 443"
      End
    End

    Describe "strict mode"
      It "allows only SSH"
        When call _generate_port_rules "strict"
        The output should include "tcp dport 22"
        The output should not include "tcp dport 8006"
      End
    End

    Describe "stealth mode"
      It "blocks all public ports"
        When call _generate_port_rules "stealth"
        The output should include "Stealth mode"
        The output should not include "tcp dport"
      End
    End
  End

  # ===========================================================================
  # Bridge interface rules
  # ===========================================================================
  Describe "_generate_bridge_input_rules()"
    Describe "internal mode"
      It "allows traffic from vmbr0"
        BRIDGE_MODE="internal"

        When call _generate_bridge_input_rules
        The output should include 'iifname "vmbr0" accept'
        The output should not include 'iifname "vmbr1"'
      End
    End

    Describe "external mode"
      It "allows traffic from vmbr1"
        BRIDGE_MODE="external"

        When call _generate_bridge_input_rules
        The output should include 'iifname "vmbr1" accept'
        The output should not include 'iifname "vmbr0"'
      End
    End

    Describe "both mode"
      It "allows traffic from both bridges"
        BRIDGE_MODE="both"

        When call _generate_bridge_input_rules
        The output should include 'iifname "vmbr0" accept'
        The output should include 'iifname "vmbr1" accept'
      End
    End
  End

  # ===========================================================================
  # Forward chain rules
  # ===========================================================================
  Describe "_generate_bridge_forward_rules()"
    Describe "internal mode"
      It "allows forwarding for vmbr0"
        BRIDGE_MODE="internal"

        When call _generate_bridge_forward_rules
        The output should include 'iifname "vmbr0" accept'
        The output should include 'oifname "vmbr0" accept'
      End
    End

    Describe "external mode"
      It "allows forwarding for vmbr1"
        BRIDGE_MODE="external"

        When call _generate_bridge_forward_rules
        The output should include 'iifname "vmbr1" accept'
        The output should include 'oifname "vmbr1" accept'
      End
    End
  End

  # ===========================================================================
  # Tailscale rules
  # ===========================================================================
  Describe "_generate_tailscale_rules()"
    It "adds Tailscale interface when enabled"
      INSTALL_TAILSCALE="yes"

      When call _generate_tailscale_rules
      The output should include 'iifname "tailscale0" accept'
    End

    It "skips Tailscale when disabled"
      INSTALL_TAILSCALE="no"

      When call _generate_tailscale_rules
      The output should include "Tailscale not installed"
      The output should not include 'iifname "tailscale0"'
    End
  End

  # ===========================================================================
  # NAT rules
  # ===========================================================================
  Describe "_generate_nat_rules()"
    Describe "internal mode"
      It "adds masquerade for private subnet"
        BRIDGE_MODE="internal"
        PRIVATE_SUBNET="10.0.0.0/24"

        When call _generate_nat_rules
        The output should include "masquerade"
        The output should include "10.0.0.0/24"
      End

      It "uses custom private subnet"
        BRIDGE_MODE="internal"
        PRIVATE_SUBNET="192.168.100.0/24"

        When call _generate_nat_rules
        The output should include "192.168.100.0/24"
      End
    End

    Describe "external mode"
      It "skips NAT for external mode"
        BRIDGE_MODE="external"

        When call _generate_nat_rules
        The output should include "no NAT needed"
        The output should not include "masquerade"
      End
    End

    Describe "both mode"
      It "adds NAT for both mode"
        BRIDGE_MODE="both"
        PRIVATE_SUBNET="10.0.0.0/24"

        When call _generate_nat_rules
        The output should include "masquerade"
      End
    End
  End

  # ===========================================================================
  # Complete config generation
  # ===========================================================================
  Describe "_generate_nftables_conf()"
    It "generates valid nftables structure"
      FIREWALL_MODE="standard"
      BRIDGE_MODE="internal"

      config=$(_generate_nftables_conf)

      When call printf '%s' "$config"
      The output should include "#!/usr/sbin/nft"
      The output should include "table inet filter"
      The output should include "chain input"
      The output should include "chain forward"
      The output should include "chain output"
      The output should include "table inet nat"
    End

    It "includes flush ruleset"
      config=$(_generate_nftables_conf)

      When call printf '%s' "$config"
      The output should include "flush ruleset"
    End

    It "sets drop policy for input"
      config=$(_generate_nftables_conf)

      When call printf '%s' "$config"
      The output should include "policy drop"
    End

    It "allows established connections"
      config=$(_generate_nftables_conf)

      When call printf '%s' "$config"
      The output should include "ct state established,related accept"
    End

    It "includes ICMP rules"
      config=$(_generate_nftables_conf)

      When call printf '%s' "$config"
      The output should include "icmp type"
      The output should include "icmpv6 type"
    End

    It "includes loopback accept"
      config=$(_generate_nftables_conf)

      When call printf '%s' "$config"
      The output should include 'iifname "lo" accept'
    End
  End

  # ===========================================================================
  # Stealth mode with Tailscale
  # ===========================================================================
  Describe "stealth mode with Tailscale"
    It "allows access only via Tailscale"
      FIREWALL_MODE="stealth"
      INSTALL_TAILSCALE="yes"
      BRIDGE_MODE="internal"

      config=$(_generate_nftables_conf)

      # Should have Tailscale interface
      When call printf '%s' "$config"
      The output should include 'iifname "tailscale0" accept'
      # Should NOT have public ports
      The output should not include "tcp dport 22"
      The output should not include "tcp dport 8006"
    End
  End

  # ===========================================================================
  # Strict mode without Tailscale
  # ===========================================================================
  Describe "strict mode"
    It "blocks Web UI but allows SSH"
      FIREWALL_MODE="strict"
      INSTALL_TAILSCALE="no"

      config=$(_generate_nftables_conf)

      When call printf '%s' "$config"
      The output should include "tcp dport 22"
      The output should not include "tcp dport 8006"
    End

    It "includes Tailscale when enabled"
      FIREWALL_MODE="strict"
      INSTALL_TAILSCALE="yes"

      config=$(_generate_nftables_conf)

      When call printf '%s' "$config"
      The output should include 'iifname "tailscale0" accept'
    End
  End

  # ===========================================================================
  # configure_firewall() wrapper
  # ===========================================================================
  Describe "configure_firewall()"
    It "skips when INSTALL_FIREWALL is not yes"
      INSTALL_FIREWALL="no"
      config_called=false
      _config_nftables() { config_called=true; }

      When call configure_firewall
      The status should be success
      The variable config_called should equal false
    End

    It "runs config when INSTALL_FIREWALL is yes"
      INSTALL_FIREWALL="yes"
      config_called=false
      _config_nftables() { config_called=true; return 0; }
      run_with_progress() { "$3"; }

      configure_firewall

      When call printf '%s' "$config_called"
      The output should equal "true"
    End
  End

  # ===========================================================================
  # IPv6 rules
  # ===========================================================================
  Describe "IPv6 support"
    It "includes ICMPv6 neighbor discovery"
      config=$(_generate_nftables_conf)

      When call printf '%s' "$config"
      The output should include "nd-neighbor-solicit"
      The output should include "nd-neighbor-advert"
      The output should include "nd-router-advert"
    End

    It "uses inet family for dual-stack"
      config=$(_generate_nftables_conf)

      When call printf '%s' "$config"
      The output should include "table inet filter"
      The output should include "table inet nat"
    End
  End
End

