# shellcheck shell=bash
# Configuration Wizard - Display Value Formatters

# Display mapping table (internal value → display text)
declare -gA _DSP_MAP=(
  # Repository types
  ["repo:no-subscription"]="No-subscription (free)"
  ["repo:enterprise"]="Enterprise"
  ["repo:test"]="Test/Development"

  # IPv6 modes
  ["ipv6:auto"]="Auto"
  ["ipv6:manual"]="Manual"
  ["ipv6:disabled"]="Disabled"

  # Bridge modes
  ["bridge:external"]="External bridge"
  ["bridge:internal"]="Internal NAT"
  ["bridge:both"]="Both"

  # Firewall modes
  ["firewall:stealth"]="Stealth (Tailscale only)"
  ["firewall:strict"]="Strict (SSH only)"
  ["firewall:standard"]="Standard (SSH + Web UI)"

  # ZFS RAID
  ["zfs:single"]="Single disk"
  ["zfs:raid0"]="RAID-0 (striped)"
  ["zfs:raid1"]="RAID-1 (mirror)"
  ["zfs:raidz1"]="RAID-Z1 (parity)"
  ["zfs:raidz2"]="RAID-Z2 (double parity)"
  ["zfs:raidz3"]="RAID-Z3 (triple parity)"
  ["zfs:raid10"]="RAID-10 (striped mirrors)"

  # ZFS ARC
  ["arc:vm-focused"]="VM-focused (4GB)"
  ["arc:balanced"]="Balanced (25-40%)"
  ["arc:storage-focused"]="Storage-focused (50%)"

  # SSL types
  ["ssl:self-signed"]="Self-signed"
  ["ssl:letsencrypt"]="Let's Encrypt"

  # Shell types
  ["shell:zsh"]="ZSH"
  ["shell:bash"]="Bash"

  # CPU governors
  ["power:performance"]="Performance"
  ["power:ondemand"]="Balanced"
  ["power:powersave"]="Balanced"
  ["power:schedutil"]="Adaptive"
  ["power:conservative"]="Conservative"
)

# Configuration validation

# Check if all required config fields set. Returns 0=complete, 1=missing
_wiz_config_complete() {
  [[ -z $PVE_HOSTNAME ]] && return 1
  [[ -z $DOMAIN_SUFFIX ]] && return 1
  [[ -z $EMAIL ]] && return 1
  [[ -z $NEW_ROOT_PASSWORD ]] && return 1
  [[ -z $ADMIN_USERNAME ]] && return 1
  [[ -z $ADMIN_PASSWORD ]] && return 1
  [[ -z $TIMEZONE ]] && return 1
  [[ -z $KEYBOARD ]] && return 1
  [[ -z $COUNTRY ]] && return 1
  [[ -z $PROXMOX_ISO_VERSION ]] && return 1
  [[ -z $PVE_REPO_TYPE ]] && return 1
  [[ -z $INTERFACE_NAME ]] && return 1
  [[ -z $MAIN_IPV4 ]] && return 1
  [[ -z $MAIN_IPV4_GW ]] && return 1
  [[ -z $BRIDGE_MODE ]] && return 1
  [[ $BRIDGE_MODE != "external" && -z $PRIVATE_SUBNET ]] && return 1
  [[ -z $IPV6_MODE ]] && return 1
  # ZFS validation: require raid/disks only when NOT using existing pool
  if [[ $USE_EXISTING_POOL == "yes" ]]; then
    [[ -z $EXISTING_POOL_NAME ]] && return 1
  else
    [[ -z $ZFS_RAID ]] && return 1
    [[ ${#ZFS_POOL_DISKS[@]} -eq 0 ]] && return 1
  fi
  [[ -z $ZFS_ARC_MODE ]] && return 1
  [[ -z $SHELL_TYPE ]] && return 1
  [[ -z $CPU_GOVERNOR ]] && return 1
  [[ -z $SSH_PUBLIC_KEY ]] && return 1
  # SSL required if Tailscale disabled
  [[ $INSTALL_TAILSCALE != "yes" && -z $SSL_TYPE ]] && return 1
  # Stealth firewall requires Tailscale
  [[ $FIREWALL_MODE == "stealth" && $INSTALL_TAILSCALE != "yes" ]] && return 1
  # Postfix requires SMTP relay settings when enabled
  if [[ $INSTALL_POSTFIX == "yes" ]]; then
    [[ -z $SMTP_RELAY_HOST || -z $SMTP_RELAY_USER || -z $SMTP_RELAY_PASSWORD ]] && return 1
  fi
  return 0
}

# Display value formatters

# Lookup display value. $1=category, $2=internal_value → display_text
_dsp_lookup() {
  local key="$1:$2"
  echo "${_DSP_MAP[$key]:-$2}"
}

# Escape backslashes for safe printf %b display. $1=value
_dsp_escape() {
  printf '%s' "${1//\\/\\\\}"
}

# Formats Basic screen values: hostname, password
_dsp_basic() {
  declare -g _DSP_PASS=""
  [[ -n $NEW_ROOT_PASSWORD ]] && declare -g _DSP_PASS="********"

  declare -g _DSP_HOSTNAME=""
  if [[ -n $PVE_HOSTNAME && -n $DOMAIN_SUFFIX ]]; then
    # Escape user values to prevent printf %b interpretation
    declare -g _DSP_HOSTNAME="$(_dsp_escape "$PVE_HOSTNAME").$(_dsp_escape "$DOMAIN_SUFFIX")"
  fi
}

# Formats Proxmox screen values: repository, ISO version
_dsp_proxmox() {
  declare -g _DSP_REPO=""
  [[ -n $PVE_REPO_TYPE ]] && declare -g _DSP_REPO=$(_dsp_lookup "repo" "$PVE_REPO_TYPE")

  declare -g _DSP_ISO=""
  [[ -n $PROXMOX_ISO_VERSION ]] && declare -g _DSP_ISO=$(get_iso_version "$PROXMOX_ISO_VERSION")
}

# Formats Network screen values: IPv6, bridge, firewall, MTU
_dsp_network() {
  declare -g _DSP_IPV6=""
  if [[ -n $IPV6_MODE ]]; then
    declare -g _DSP_IPV6=$(_dsp_lookup "ipv6" "$IPV6_MODE")
    # Special case: manual mode shows address details
    if [[ $IPV6_MODE == "manual" && -n $MAIN_IPV6 ]]; then
      _DSP_IPV6+=" ($(_dsp_escape "$MAIN_IPV6"), gw: $(_dsp_escape "$IPV6_GATEWAY"))"
    fi
  fi

  declare -g _DSP_BRIDGE=""
  [[ -n $BRIDGE_MODE ]] && declare -g _DSP_BRIDGE=$(_dsp_lookup "bridge" "$BRIDGE_MODE")

  declare -g _DSP_FIREWALL=""
  if [[ -n $INSTALL_FIREWALL ]]; then
    if [[ $INSTALL_FIREWALL == "yes" ]]; then
      declare -g _DSP_FIREWALL=$(_dsp_lookup "firewall" "$FIREWALL_MODE")
    else
      declare -g _DSP_FIREWALL="Disabled"
    fi
  fi

  declare -g _DSP_MTU="${BRIDGE_MTU:-9000}"
  [[ $_DSP_MTU == "9000" ]] && declare -g _DSP_MTU="9000 (jumbo)"
}

# Formats Storage screen values: ZFS mode, ARC, boot/pool disks, existing pool
_dsp_storage() {
  # Existing pool mode
  declare -g _DSP_EXISTING_POOL=""
  if [[ $USE_EXISTING_POOL == "yes" && -n $EXISTING_POOL_NAME ]]; then
    declare -g _DSP_EXISTING_POOL="Use: $(_dsp_escape "$EXISTING_POOL_NAME") (${#EXISTING_POOL_DISKS[@]} disks)"
  else
    declare -g _DSP_EXISTING_POOL="Create new"
  fi

  declare -g _DSP_ZFS=""
  if [[ -n $ZFS_RAID ]]; then
    declare -g _DSP_ZFS=$(_dsp_lookup "zfs" "$ZFS_RAID")
  elif [[ $USE_EXISTING_POOL == "yes" ]]; then
    declare -g _DSP_ZFS="(preserved)"
  fi

  declare -g _DSP_ARC=""
  [[ -n $ZFS_ARC_MODE ]] && declare -g _DSP_ARC=$(_dsp_lookup "arc" "$ZFS_ARC_MODE")

  declare -g _DSP_BOOT="All in pool"
  if [[ -n $BOOT_DISK ]]; then
    for i in "${!DRIVES[@]}"; do
      if [[ ${DRIVES[$i]} == "$BOOT_DISK" ]]; then
        declare -g _DSP_BOOT="${DRIVE_MODELS[$i]}"
        break
      fi
    done
  fi

  if [[ $USE_EXISTING_POOL == "yes" ]]; then
    declare -g _DSP_POOL="(existing pool)"
  else
    declare -g _DSP_POOL="${#ZFS_POOL_DISKS[@]} disks"
  fi

  # Wipe disks option
  declare -g _DSP_WIPE=""
  if [[ $WIPE_DISKS == "yes" ]]; then
    declare -g _DSP_WIPE="Yes (full wipe)"
  else
    declare -g _DSP_WIPE="No (keep existing)"
  fi
}

# Formats Services screen values: Tailscale, SSL, shell, power, features
_dsp_services() {
  declare -g _DSP_TAILSCALE=""
  if [[ -n $INSTALL_TAILSCALE ]]; then
    if [[ $INSTALL_TAILSCALE == "yes" ]]; then
      declare -g _DSP_TAILSCALE="Enabled + Stealth"
    else
      declare -g _DSP_TAILSCALE="Disabled"
    fi
  fi

  declare -g _DSP_SSL=""
  [[ -n $SSL_TYPE ]] && declare -g _DSP_SSL=$(_dsp_lookup "ssl" "$SSL_TYPE")

  declare -g _DSP_POSTFIX=""
  if [[ -n $INSTALL_POSTFIX ]]; then
    if [[ $INSTALL_POSTFIX == "yes" && -n $SMTP_RELAY_HOST ]]; then
      declare -g _DSP_POSTFIX="Relay: $(_dsp_escape "$SMTP_RELAY_HOST"):$(_dsp_escape "${SMTP_RELAY_PORT:-587}")"
    elif [[ $INSTALL_POSTFIX == "yes" ]]; then
      declare -g _DSP_POSTFIX="Enabled (no relay)"
    else
      declare -g _DSP_POSTFIX="Disabled"
    fi
  fi

  declare -g _DSP_SHELL=""
  [[ -n $SHELL_TYPE ]] && declare -g _DSP_SHELL=$(_dsp_lookup "shell" "$SHELL_TYPE")

  declare -g _DSP_POWER=""
  [[ -n $CPU_GOVERNOR ]] && declare -g _DSP_POWER=$(_dsp_lookup "power" "$CPU_GOVERNOR")

  # Feature lists
  declare -g _DSP_SECURITY="none"
  local sec_items=()
  [[ $INSTALL_APPARMOR == "yes" ]] && sec_items+=("apparmor")
  [[ $INSTALL_AUDITD == "yes" ]] && sec_items+=("auditd")
  [[ $INSTALL_AIDE == "yes" ]] && sec_items+=("aide")
  [[ $INSTALL_CHKROOTKIT == "yes" ]] && sec_items+=("chkrootkit")
  [[ $INSTALL_LYNIS == "yes" ]] && sec_items+=("lynis")
  [[ $INSTALL_NEEDRESTART == "yes" ]] && sec_items+=("needrestart")
  [[ ${#sec_items[@]} -gt 0 ]] && declare -g _DSP_SECURITY="${sec_items[*]}"

  declare -g _DSP_MONITORING="none"
  local mon_items=()
  [[ $INSTALL_VNSTAT == "yes" ]] && mon_items+=("vnstat")
  [[ $INSTALL_NETDATA == "yes" ]] && mon_items+=("netdata")
  [[ $INSTALL_PROMTAIL == "yes" ]] && mon_items+=("promtail")
  [[ ${#mon_items[@]} -gt 0 ]] && declare -g _DSP_MONITORING="${mon_items[*]}"

  declare -g _DSP_TOOLS="none"
  local tool_items=()
  [[ $INSTALL_YAZI == "yes" ]] && tool_items+=("yazi")
  [[ $INSTALL_NVIM == "yes" ]] && tool_items+=("nvim")
  [[ $INSTALL_RINGBUFFER == "yes" ]] && tool_items+=("ringbuffer")
  [[ ${#tool_items[@]} -gt 0 ]] && declare -g _DSP_TOOLS="${tool_items[*]}"
}

# Formats Access screen values: admin user, SSH key, API token
_dsp_access() {
  declare -g _DSP_ADMIN_USER=""
  [[ -n $ADMIN_USERNAME ]] && declare -g _DSP_ADMIN_USER="$(_dsp_escape "$ADMIN_USERNAME")"

  declare -g _DSP_ADMIN_PASS=""
  [[ -n $ADMIN_PASSWORD ]] && declare -g _DSP_ADMIN_PASS="********"

  declare -g _DSP_SSH=""
  [[ -n $SSH_PUBLIC_KEY ]] && declare -g _DSP_SSH="$(_dsp_escape "${SSH_PUBLIC_KEY:0:20}")..."

  declare -g _DSP_API=""
  if [[ -n $INSTALL_API_TOKEN ]]; then
    case "$INSTALL_API_TOKEN" in
      yes) declare -g _DSP_API="Yes ($(_dsp_escape "$API_TOKEN_NAME"))" ;;
      no) declare -g _DSP_API="No" ;;
    esac
  fi
}

# Build _DSP_* display values from current config state
_wiz_build_display_values() {
  _dsp_basic
  _dsp_proxmox
  _dsp_network
  _dsp_storage
  _dsp_services
  _dsp_access
}
