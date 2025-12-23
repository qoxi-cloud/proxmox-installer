# shellcheck shell=bash
# shellcheck disable=SC2034
# =============================================================================
# Tests for 310-configure-firewall.sh
# =============================================================================

%const SCRIPTS_DIR: "${SHELLSPEC_PROJECT_ROOT}/scripts"
%const SUPPORT_DIR: "${SHELLSPEC_PROJECT_ROOT}/spec/support"

# Load shared mocks
eval "$(cat "$SUPPORT_DIR/configure_mocks.sh")"

Describe "310-configure-firewall.sh"
  Include "$SCRIPTS_DIR/310-configure-firewall.sh"

  # ===========================================================================
  # _generate_port_rules()
  # ===========================================================================
  Describe "_generate_port_rules()"
    BeforeEach 'PORT_SSH=22; PORT_PROXMOX_UI=8006'

    Describe "stealth mode"
      It "outputs stealth comment only"
        When call _generate_port_rules "stealth"
        The output should include "Stealth mode"
        The output should include "all public ports blocked"
        The output should not include "tcp dport"
      End
    End

    Describe "strict mode"
      It "allows only SSH"
        When call _generate_port_rules "strict"
        The output should include "tcp dport 22"
        The output should not include "8006"
      End

      It "uses custom SSH port"
        PORT_SSH=2222
        When call _generate_port_rules "strict"
        The output should include "tcp dport 2222"
      End
    End

    Describe "standard mode"
      It "allows SSH and Web UI"
        When call _generate_port_rules "standard"
        The output should include "tcp dport 22"
        The output should include "tcp dport 8006"
      End

      It "uses custom ports"
        PORT_SSH=2222
        PORT_PROXMOX_UI=443
        When call _generate_port_rules "standard"
        The output should include "tcp dport 2222"
        The output should include "tcp dport 443"
      End
    End

    Describe "default mode"
      It "defaults to standard when mode not specified"
        When call _generate_port_rules
        The output should include "tcp dport 22"
        The output should include "tcp dport 8006"
      End

      It "defaults to standard for unknown mode"
        When call _generate_port_rules "unknown"
        The output should include "tcp dport 22"
        The output should include "tcp dport 8006"
      End
    End
  End

  # ===========================================================================
  # _generate_bridge_input_rules()
  # ===========================================================================
  Describe "_generate_bridge_input_rules()"
    Describe "internal mode"
      BeforeEach 'BRIDGE_MODE="internal"'

      It "allows vmbr0 only"
        When call _generate_bridge_input_rules
        The output should include 'iifname "vmbr0" accept'
        The output should not include "vmbr1"
      End
    End

    Describe "external mode"
      BeforeEach 'BRIDGE_MODE="external"'

      It "allows vmbr1 only"
        When call _generate_bridge_input_rules
        The output should include 'iifname "vmbr1" accept'
        The output should not include "vmbr0"
      End
    End

    Describe "both mode"
      BeforeEach 'BRIDGE_MODE="both"'

      It "allows both bridges"
        When call _generate_bridge_input_rules
        The output should include 'iifname "vmbr0" accept'
        The output should include 'iifname "vmbr1" accept'
      End
    End

    Describe "default mode"
      It "defaults to internal when unset"
        unset BRIDGE_MODE
        When call _generate_bridge_input_rules
        The output should include 'iifname "vmbr0" accept'
        The output should not include "vmbr1"
      End
    End
  End

  # ===========================================================================
  # _generate_bridge_forward_rules()
  # ===========================================================================
  Describe "_generate_bridge_forward_rules()"
    Describe "internal mode"
      BeforeEach 'BRIDGE_MODE="internal"'

      It "forwards vmbr0 traffic"
        When call _generate_bridge_forward_rules
        The output should include 'iifname "vmbr0" accept'
        The output should include 'oifname "vmbr0" accept'
        The output should not include "vmbr1"
      End
    End

    Describe "external mode"
      BeforeEach 'BRIDGE_MODE="external"'

      It "forwards vmbr1 traffic"
        When call _generate_bridge_forward_rules
        The output should include 'iifname "vmbr1" accept'
        The output should include 'oifname "vmbr1" accept'
        The output should not include "vmbr0"
      End
    End

    Describe "both mode"
      BeforeEach 'BRIDGE_MODE="both"'

      It "forwards both bridges"
        When call _generate_bridge_forward_rules
        The output should include 'iifname "vmbr0" accept'
        The output should include 'oifname "vmbr0" accept'
        The output should include 'iifname "vmbr1" accept'
        The output should include 'oifname "vmbr1" accept'
      End
    End

    Describe "default mode"
      It "defaults to internal when unset"
        unset BRIDGE_MODE
        When call _generate_bridge_forward_rules
        The output should include 'iifname "vmbr0" accept'
        The output should not include "vmbr1"
      End
    End
  End

  # ===========================================================================
  # _generate_tailscale_rules()
  # ===========================================================================
  Describe "_generate_tailscale_rules()"
    It "includes tailscale0 when INSTALL_TAILSCALE is yes"
      INSTALL_TAILSCALE="yes"
      When call _generate_tailscale_rules
      The output should include 'iifname "tailscale0" accept'
    End

    It "outputs comment when INSTALL_TAILSCALE is no"
      INSTALL_TAILSCALE="no"
      When call _generate_tailscale_rules
      The output should include "Tailscale not installed"
      The output should not include "tailscale0"
    End

    It "outputs comment when INSTALL_TAILSCALE is unset"
      unset INSTALL_TAILSCALE
      When call _generate_tailscale_rules
      The output should include "Tailscale not installed"
    End

    It "outputs comment when INSTALL_TAILSCALE is empty"
      INSTALL_TAILSCALE=""
      When call _generate_tailscale_rules
      The output should include "Tailscale not installed"
    End
  End

  # ===========================================================================
  # _generate_nat_rules()
  # ===========================================================================
  Describe "_generate_nat_rules()"
    BeforeEach 'PRIVATE_SUBNET="10.0.0.0/24"'

    Describe "internal mode"
      BeforeEach 'BRIDGE_MODE="internal"'

      It "generates masquerade rule"
        When call _generate_nat_rules
        The output should include "masquerade"
        The output should include "10.0.0.0/24"
      End

      It "uses custom subnet"
        PRIVATE_SUBNET="192.168.100.0/24"
        When call _generate_nat_rules
        The output should include "192.168.100.0/24"
      End
    End

    Describe "external mode"
      BeforeEach 'BRIDGE_MODE="external"'

      It "outputs no NAT comment"
        When call _generate_nat_rules
        The output should include "no NAT needed"
        The output should not include "masquerade"
      End
    End

    Describe "both mode"
      BeforeEach 'BRIDGE_MODE="both"'

      It "generates masquerade rule"
        When call _generate_nat_rules
        The output should include "masquerade"
        The output should include "10.0.0.0/24"
      End
    End

    Describe "default mode"
      It "defaults to internal with masquerade"
        unset BRIDGE_MODE
        When call _generate_nat_rules
        The output should include "masquerade"
      End
    End
  End

  # ===========================================================================
  # _generate_nftables_conf()
  # ===========================================================================
  Describe "_generate_nftables_conf()"
    BeforeEach 'BRIDGE_MODE="internal"; FIREWALL_MODE="standard"; INSTALL_TAILSCALE="no"; PRIVATE_SUBNET="10.0.0.0/24"; PORT_SSH=22; PORT_PROXMOX_UI=8006'

    It "includes nft shebang"
      When call _generate_nftables_conf
      The output should include "#!/usr/sbin/nft -f"
    End

    It "includes flush ruleset"
      When call _generate_nftables_conf
      The output should include "flush ruleset"
    End

    It "includes inet filter table"
      When call _generate_nftables_conf
      The output should include "table inet filter"
    End

    It "includes input chain with drop policy"
      When call _generate_nftables_conf
      The output should include "chain input"
      The output should include "policy drop"
    End

    It "includes forward chain"
      When call _generate_nftables_conf
      The output should include "chain forward"
    End

    It "includes output chain"
      When call _generate_nftables_conf
      The output should include "chain output"
    End

    It "includes established/related accept"
      When call _generate_nftables_conf
      The output should include "ct state established,related accept"
    End

    It "includes loopback accept"
      When call _generate_nftables_conf
      The output should include 'iifname "lo" accept'
    End

    It "includes ICMP rate limiting"
      When call _generate_nftables_conf
      The output should include "icmp type"
      The output should include "limit rate 10/second"
    End

    It "includes ICMPv6 rules"
      When call _generate_nftables_conf
      The output should include "icmpv6 type"
    End

    It "includes NAT table"
      When call _generate_nftables_conf
      The output should include "table inet nat"
      The output should include "chain postrouting"
    End

    It "includes mode comments in header"
      FIREWALL_MODE="strict"
      BRIDGE_MODE="both"
      When call _generate_nftables_conf
      The output should include "Firewall mode: strict"
      The output should include "Bridge mode: both"
    End

    Describe "with stealth mode"
      BeforeEach 'FIREWALL_MODE="stealth"'

      It "includes stealth port rules"
        When call _generate_nftables_conf
        The output should include "Stealth mode"
      End
    End

    Describe "with tailscale enabled"
      BeforeEach 'INSTALL_TAILSCALE="yes"'

      It "includes tailscale interface rules"
        When call _generate_nftables_conf
        The output should include 'iifname "tailscale0" accept'
      End
    End
  End

  # ===========================================================================
  # _config_nftables()
  # ===========================================================================
  Describe "_config_nftables()"
    BeforeEach 'BRIDGE_MODE="internal"; FIREWALL_MODE="standard"; INSTALL_TAILSCALE="no"; PRIVATE_SUBNET="10.0.0.0/24"; PORT_SSH=22; PORT_PROXMOX_UI=8006; MOCK_REMOTE_EXEC_RESULT=0; MOCK_REMOTE_COPY_RESULT=0'
    AfterEach 'rm -f ./templates/nftables.conf.generated'

    It "succeeds with valid configuration"
      When call _config_nftables
      The status should be success
    End

    It "sets iptables-nft alternatives"
      alternatives_set=false
      remote_exec() {
        if [[ $1 == *"update-alternatives"* ]]; then
          alternatives_set=true
        fi
        return 0
      }
      remote_copy() { return 0; }
      When call _config_nftables
      The status should be success
      The variable alternatives_set should equal true
    End

    It "generates config file"
      remote_exec() { return 0; }
      remote_copy() { return 0; }
      When call _config_nftables
      The status should be success
      # File should be cleaned up after success
    End

    It "copies config to remote"
      copy_called=false
      copy_dest=""
      remote_exec() { return 0; }
      remote_copy() {
        if [[ $2 == "/etc/nftables.conf" ]]; then
          copy_called=true
          copy_dest="$2"
        fi
        return 0
      }
      When call _config_nftables
      The status should be success
      The variable copy_called should equal true
      The variable copy_dest should equal "/etc/nftables.conf"
    End

    It "validates nftables syntax"
      validation_called=false
      remote_exec() {
        if [[ $1 == *"nft -c"* ]]; then
          validation_called=true
        fi
        return 0
      }
      remote_copy() { return 0; }
      When call _config_nftables
      The status should be success
      The variable validation_called should equal true
    End

    It "enables nftables service"
      service_enabled=false
      remote_exec() {
        if [[ $1 == *"systemctl enable nftables"* ]]; then
          service_enabled=true
        fi
        return 0
      }
      remote_copy() { return 0; }
      When call _config_nftables
      The status should be success
      The variable service_enabled should equal true
    End

    It "continues when alternatives fail"
      call_count=0
      remote_exec() {
        call_count=$((call_count + 1))
        [[ $1 == *"update-alternatives"* ]] && return 1
        return 0
      }
      remote_copy() { return 0; }
      When call _config_nftables
      The status should be success
    End

    It "fails when remote_copy fails"
      remote_copy() { return 1; }
      When call _config_nftables
      The status should be failure
    End

    It "fails when syntax validation fails"
      remote_copy() { return 0; }
      remote_exec() {
        [[ $1 == *"nft -c"* ]] && return 1
        return 0
      }
      When call _config_nftables
      The status should be failure
    End

    It "fails when enable service fails"
      remote_copy() { return 0; }
      remote_exec() {
        [[ $1 == *"systemctl enable"* ]] && return 1
        return 0
      }
      When call _config_nftables
      The status should be failure
    End

    It "cleans up temp file on success"
      remote_exec() { return 0; }
      remote_copy() { return 0; }
      When call _config_nftables
      The status should be success
      The file "./templates/nftables.conf.generated" should not be exist
    End

    It "cleans up temp file on failure"
      remote_copy() { return 1; }
      When call _config_nftables
      The status should be failure
      The file "./templates/nftables.conf.generated" should not be exist
    End
  End

  # ===========================================================================
  # configure_firewall() - public wrapper
  # ===========================================================================
  Describe "configure_firewall()"
    BeforeEach 'BRIDGE_MODE="internal"; FIREWALL_MODE="standard"; INSTALL_TAILSCALE="no"; PRIVATE_SUBNET="10.0.0.0/24"; PORT_SSH=22; PORT_PROXMOX_UI=8006; MOCK_REMOTE_EXEC_RESULT=0; MOCK_REMOTE_COPY_RESULT=0'
    AfterEach 'rm -f ./templates/nftables.conf.generated'

    It "skips when INSTALL_FIREWALL is not yes"
      INSTALL_FIREWALL="no"
      When call configure_firewall
      The status should be success
    End

    It "skips when INSTALL_FIREWALL is unset"
      unset INSTALL_FIREWALL
      When call configure_firewall
      The status should be success
    End

    It "skips when INSTALL_FIREWALL is empty"
      INSTALL_FIREWALL=""
      When call configure_firewall
      The status should be success
    End

    It "configures firewall when INSTALL_FIREWALL is yes"
      INSTALL_FIREWALL="yes"
      config_called=false
      _config_nftables() { config_called=true; return 0; }
      When call configure_firewall
      The status should be success
      The variable config_called should equal true
    End

    It "returns success even when _config_nftables fails"
      INSTALL_FIREWALL="yes"
      _config_nftables() { return 1; }
      When call configure_firewall
      The status should be success
    End

    Describe "mode display"
      BeforeEach 'INSTALL_FIREWALL="yes"'

      It "displays stealth mode correctly"
        FIREWALL_MODE="stealth"
        run_with_progress() {
          [[ $2 == *"stealth (Tailscale only)"* ]] && return 0
          return 1
        }
        When call configure_firewall
        The status should be success
      End

      It "displays strict mode correctly"
        FIREWALL_MODE="strict"
        run_with_progress() {
          [[ $2 == *"strict (SSH only)"* ]] && return 0
          return 1
        }
        When call configure_firewall
        The status should be success
      End

      It "displays standard mode correctly"
        FIREWALL_MODE="standard"
        run_with_progress() {
          [[ $2 == *"standard (SSH + Web UI)"* ]] && return 0
          return 1
        }
        When call configure_firewall
        The status should be success
      End
    End
  End
End

