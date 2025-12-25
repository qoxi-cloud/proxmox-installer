# shellcheck shell=bash
# =============================================================================
# Configuration Wizard - Display Value Formatters
# =============================================================================
# Formats configuration values for display in wizard menu

# =============================================================================
# Display value formatters (grouped by screen)
# =============================================================================

# Formats Basic screen values: hostname, password
_dsp_basic() {
  _DSP_PASS=""
  [[ -n $NEW_ROOT_PASSWORD ]] && _DSP_PASS="********"

  _DSP_HOSTNAME=""
  [[ -n $PVE_HOSTNAME && -n $DOMAIN_SUFFIX ]] && _DSP_HOSTNAME="${PVE_HOSTNAME}.${DOMAIN_SUFFIX}"
}

# Formats Proxmox screen values: repository, ISO version
_dsp_proxmox() {
  _DSP_REPO=""
  if [[ -n $PVE_REPO_TYPE ]]; then
    case "$PVE_REPO_TYPE" in
      no-subscription) _DSP_REPO="No-subscription (free)" ;;
      enterprise) _DSP_REPO="Enterprise" ;;
      test) _DSP_REPO="Test/Development" ;;
      *) _DSP_REPO="$PVE_REPO_TYPE" ;;
    esac
  fi

  _DSP_ISO=""
  [[ -n $PROXMOX_ISO_VERSION ]] && _DSP_ISO=$(get_iso_version "$PROXMOX_ISO_VERSION")
}

# Formats Network screen values: IPv6, bridge, firewall, MTU
_dsp_network() {
  _DSP_IPV6=""
  if [[ -n $IPV6_MODE ]]; then
    case "$IPV6_MODE" in
      auto) _DSP_IPV6="Auto" ;;
      manual)
        _DSP_IPV6="Manual"
        [[ -n $MAIN_IPV6 ]] && _DSP_IPV6+=" (${MAIN_IPV6}, gw: ${IPV6_GATEWAY})"
        ;;
      disabled) _DSP_IPV6="Disabled" ;;
      *) _DSP_IPV6="$IPV6_MODE" ;;
    esac
  fi

  _DSP_BRIDGE=""
  if [[ -n $BRIDGE_MODE ]]; then
    case "$BRIDGE_MODE" in
      external) _DSP_BRIDGE="External bridge" ;;
      internal) _DSP_BRIDGE="Internal NAT" ;;
      both) _DSP_BRIDGE="Both" ;;
      *) _DSP_BRIDGE="$BRIDGE_MODE" ;;
    esac
  fi

  _DSP_FIREWALL=""
  if [[ -n $INSTALL_FIREWALL ]]; then
    if [[ $INSTALL_FIREWALL == "yes" ]]; then
      case "$FIREWALL_MODE" in
        stealth) _DSP_FIREWALL="Stealth (Tailscale only)" ;;
        strict) _DSP_FIREWALL="Strict (SSH only)" ;;
        standard) _DSP_FIREWALL="Standard (SSH + Web UI)" ;;
        *) _DSP_FIREWALL="$FIREWALL_MODE" ;;
      esac
    else
      _DSP_FIREWALL="Disabled"
    fi
  fi

  _DSP_MTU="${BRIDGE_MTU:-9000}"
  [[ $_DSP_MTU == "9000" ]] && _DSP_MTU="9000 (jumbo)"
}

# Formats Storage screen values: ZFS mode, ARC, boot/pool disks, existing pool
_dsp_storage() {
  # Existing pool mode
  _DSP_EXISTING_POOL=""
  if [[ $USE_EXISTING_POOL == "yes" && -n $EXISTING_POOL_NAME ]]; then
    _DSP_EXISTING_POOL="Use: ${EXISTING_POOL_NAME} (${#EXISTING_POOL_DISKS[@]} disks)"
  else
    _DSP_EXISTING_POOL="Create new"
  fi

  _DSP_ZFS=""
  if [[ -n $ZFS_RAID ]]; then
    case "$ZFS_RAID" in
      single) _DSP_ZFS="Single disk" ;;
      raid0) _DSP_ZFS="RAID-0 (striped)" ;;
      raid1) _DSP_ZFS="RAID-1 (mirror)" ;;
      raidz1) _DSP_ZFS="RAID-Z1 (parity)" ;;
      raidz2) _DSP_ZFS="RAID-Z2 (double parity)" ;;
      raid10) _DSP_ZFS="RAID-10 (striped mirrors)" ;;
      *) _DSP_ZFS="$ZFS_RAID" ;;
    esac
  elif [[ $USE_EXISTING_POOL == "yes" ]]; then
    _DSP_ZFS="(preserved)"
  fi

  _DSP_ARC=""
  if [[ -n $ZFS_ARC_MODE ]]; then
    case "$ZFS_ARC_MODE" in
      vm-focused) _DSP_ARC="VM-focused (4GB)" ;;
      balanced) _DSP_ARC="Balanced (25-40%)" ;;
      storage-focused) _DSP_ARC="Storage-focused (50%)" ;;
      *) _DSP_ARC="$ZFS_ARC_MODE" ;;
    esac
  fi

  _DSP_BOOT="All in pool"
  if [[ -n $BOOT_DISK ]]; then
    for i in "${!DRIVES[@]}"; do
      if [[ ${DRIVES[$i]} == "$BOOT_DISK" ]]; then
        _DSP_BOOT="${DRIVE_MODELS[$i]}"
        break
      fi
    done
  fi

  if [[ $USE_EXISTING_POOL == "yes" ]]; then
    _DSP_POOL="(existing pool)"
  else
    _DSP_POOL="${#ZFS_POOL_DISKS[@]} disks"
  fi
}

# Formats Services screen values: Tailscale, SSL, shell, power, features
_dsp_services() {
  _DSP_TAILSCALE=""
  if [[ -n $INSTALL_TAILSCALE ]]; then
    [[ $INSTALL_TAILSCALE == "yes" ]] && _DSP_TAILSCALE="Enabled + Stealth" || _DSP_TAILSCALE="Disabled"
  fi

  _DSP_SSL=""
  if [[ -n $SSL_TYPE ]]; then
    case "$SSL_TYPE" in
      self-signed) _DSP_SSL="Self-signed" ;;
      letsencrypt) _DSP_SSL="Let's Encrypt" ;;
      *) _DSP_SSL="$SSL_TYPE" ;;
    esac
  fi

  _DSP_SHELL=""
  if [[ -n $SHELL_TYPE ]]; then
    case "$SHELL_TYPE" in
      zsh) _DSP_SHELL="ZSH" ;;
      bash) _DSP_SHELL="Bash" ;;
      *) _DSP_SHELL="$SHELL_TYPE" ;;
    esac
  fi

  _DSP_POWER=""
  if [[ -n $CPU_GOVERNOR ]]; then
    case "$CPU_GOVERNOR" in
      performance) _DSP_POWER="Performance" ;;
      ondemand | powersave) _DSP_POWER="Balanced" ;;
      schedutil) _DSP_POWER="Adaptive" ;;
      conservative) _DSP_POWER="Conservative" ;;
      *) _DSP_POWER="$CPU_GOVERNOR" ;;
    esac
  fi

  # Feature lists
  _DSP_SECURITY="none"
  local sec_items=()
  [[ $INSTALL_APPARMOR == "yes" ]] && sec_items+=("apparmor")
  [[ $INSTALL_AUDITD == "yes" ]] && sec_items+=("auditd")
  [[ $INSTALL_AIDE == "yes" ]] && sec_items+=("aide")
  [[ $INSTALL_CHKROOTKIT == "yes" ]] && sec_items+=("chkrootkit")
  [[ $INSTALL_LYNIS == "yes" ]] && sec_items+=("lynis")
  [[ $INSTALL_NEEDRESTART == "yes" ]] && sec_items+=("needrestart")
  [[ ${#sec_items[@]} -gt 0 ]] && _DSP_SECURITY="${sec_items[*]}"

  _DSP_MONITORING="none"
  local mon_items=()
  [[ $INSTALL_VNSTAT == "yes" ]] && mon_items+=("vnstat")
  [[ $INSTALL_NETDATA == "yes" ]] && mon_items+=("netdata")
  [[ $INSTALL_PROMTAIL == "yes" ]] && mon_items+=("promtail")
  [[ ${#mon_items[@]} -gt 0 ]] && _DSP_MONITORING="${mon_items[*]}"

  _DSP_TOOLS="none"
  local tool_items=()
  [[ $INSTALL_YAZI == "yes" ]] && tool_items+=("yazi")
  [[ $INSTALL_NVIM == "yes" ]] && tool_items+=("nvim")
  [[ $INSTALL_RINGBUFFER == "yes" ]] && tool_items+=("ringbuffer")
  [[ ${#tool_items[@]} -gt 0 ]] && _DSP_TOOLS="${tool_items[*]}"
}

# Formats Access screen values: admin user, SSH key, API token
_dsp_access() {
  _DSP_ADMIN_USER=""
  [[ -n $ADMIN_USERNAME ]] && _DSP_ADMIN_USER="$ADMIN_USERNAME"

  _DSP_ADMIN_PASS=""
  [[ -n $ADMIN_PASSWORD ]] && _DSP_ADMIN_PASS="********"

  _DSP_SSH=""
  [[ -n $SSH_PUBLIC_KEY ]] && _DSP_SSH="${SSH_PUBLIC_KEY:0:20}..."

  _DSP_API=""
  if [[ -n $INSTALL_API_TOKEN ]]; then
    case "$INSTALL_API_TOKEN" in
      yes) _DSP_API="Yes (${API_TOKEN_NAME})" ;;
      no) _DSP_API="No" ;;
    esac
  fi
}

# Builds formatted display values from current configuration state.
# Calls individual formatters for each screen category.
# Side effects: Sets _DSP_* global variables for menu rendering
_wiz_build_display_values() {
  _dsp_basic
  _dsp_proxmox
  _dsp_network
  _dsp_storage
  _dsp_services
  _dsp_access
}
