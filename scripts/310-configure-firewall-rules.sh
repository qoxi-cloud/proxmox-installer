# shellcheck shell=bash
# nftables Firewall rule generators
# Returns nftables rule text via stdout

# Generates port accept rules based on firewall mode
# Note: pveproxy listens on 8006 (hardcoded), DNAT redirects 443→8006
_generate_port_rules() {
  local mode="${1:-standard}"
  local ssh="${PORT_SSH:-22}"

  case "$mode" in
    stealth)
      cat <<'EOF'
        # Stealth mode: all public ports blocked
        # Access only via Tailscale VPN or VM bridges
EOF
      ;;
    strict)
      cat <<EOF
        # SSH access (port $ssh)
        tcp dport $ssh ct state new accept
EOF
      ;;
    standard | *)
      cat <<EOF
        # SSH access (port $ssh)
        tcp dport $ssh ct state new accept

        # Proxmox Web UI (port 8006, after DNAT from 443)
        tcp dport 8006 ct state new accept
EOF
      ;;
  esac

  # Add port 80 for Let's Encrypt HTTP challenge (initial + renewals)
  if [[ $SSL_TYPE == "letsencrypt" && $mode != "stealth" ]]; then
    cat <<'EOF'

        # HTTP for Let's Encrypt ACME challenge
        tcp dport 80 ct state new accept
EOF
  fi
}

# Generates bridge interface rules for input chain
_generate_bridge_input_rules() {
  local mode="${BRIDGE_MODE:-internal}"

  case "$mode" in
    internal)
      cat <<'EOF'
        # Allow traffic from vmbr0 (private NAT network)
        iifname "vmbr0" accept
EOF
      ;;
    external)
      cat <<'EOF'
        # Allow traffic from vmbr1 (external bridge)
        iifname "vmbr1" accept
EOF
      ;;
    both)
      cat <<'EOF'
        # Allow traffic from vmbr0 (private NAT network)
        iifname "vmbr0" accept

        # Allow traffic from vmbr1 (public IPs)
        iifname "vmbr1" accept
EOF
      ;;
  esac
}

# Generates bridge interface rules for forward chain
_generate_bridge_forward_rules() {
  local mode="${BRIDGE_MODE:-internal}"

  case "$mode" in
    internal)
      cat <<'EOF'
        # Allow forwarding for vmbr0 (private NAT network)
        iifname "vmbr0" accept
        oifname "vmbr0" accept
EOF
      ;;
    external)
      cat <<'EOF'
        # Allow forwarding for vmbr1 (external bridge)
        iifname "vmbr1" accept
        oifname "vmbr1" accept
EOF
      ;;
    both)
      cat <<'EOF'
        # Allow forwarding for vmbr0 (private NAT network)
        iifname "vmbr0" accept
        oifname "vmbr0" accept

        # Allow forwarding for vmbr1 (public IPs)
        iifname "vmbr1" accept
        oifname "vmbr1" accept
EOF
      ;;
  esac
}

# Generates Tailscale interface rules if enabled
_generate_tailscale_rules() {
  if [[ $INSTALL_TAILSCALE == "yes" ]]; then
    cat <<'EOF'
        # Allow Tailscale VPN interface (traffic already on tunnel)
        iifname "tailscale0" accept

        # Allow incoming WireGuard UDP for direct peer connections
        # Required for NAT hole-punching and peer-to-peer connectivity
        udp dport 41641 accept
EOF
  else
    echo "        # Tailscale not installed"
  fi
}

# Generates NAT masquerade rules for private subnet
_generate_nat_rules() {
  local mode="${BRIDGE_MODE:-internal}"
  local subnet="${PRIVATE_SUBNET:-10.0.0.0/24}"

  case "$mode" in
    internal | both)
      cat <<EOF
        # Masquerade traffic from private subnet to internet
        oifname != "lo" ip saddr $subnet masquerade
EOF
      ;;
    external)
      echo "        # External mode: no NAT needed (VMs have public IPs)"
      ;;
  esac
}

# Generates DNAT prerouting rules for port redirection
# pveproxy is hardcoded to listen on 8006, redirect 443→8006 for convenience
_generate_prerouting_rules() {
  local mode="${1:-standard}"
  local webui="${PORT_PROXMOX_UI:-443}"

  case "$mode" in
    stealth)
      echo "        # Stealth mode: no public port redirects"
      ;;
    strict)
      echo "        # Strict mode: no web UI redirect"
      ;;
    standard | *)
      cat <<EOF
        # Redirect HTTPS (port $webui) to pveproxy (port 8006)
        tcp dport $webui redirect to :8006
EOF
      ;;
  esac
}
