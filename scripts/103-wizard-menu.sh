# shellcheck shell=bash
# =============================================================================
# Configuration Wizard - Menu Rendering and Display Values
# =============================================================================
# Field tracking, display value formatting, and menu rendering

# =============================================================================
# Field tracking
# =============================================================================

# Menu item indices (for mapping selection to edit functions)
# These track which items are selectable fields vs section headers
_WIZ_FIELD_COUNT=0
_WIZ_FIELD_MAP=()

# =============================================================================
# Configuration validation
# =============================================================================

# Check if all required configuration fields are set
# Returns: 0 if complete, 1 if missing fields
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
  [[ -z $BRIDGE_MODE ]] && return 1
  [[ -z $PRIVATE_SUBNET ]] && return 1
  [[ -z $IPV6_MODE ]] && return 1
  [[ -z $ZFS_RAID ]] && return 1
  [[ -z $ZFS_ARC_MODE ]] && return 1
  [[ -z $SHELL_TYPE ]] && return 1
  [[ -z $CPU_GOVERNOR ]] && return 1
  [[ -z $SSH_PUBLIC_KEY ]] && return 1
  [[ ${#ZFS_POOL_DISKS[@]} -eq 0 ]] && return 1
  # SSL required if Tailscale disabled
  [[ $INSTALL_TAILSCALE != "yes" && -z $SSL_TYPE ]] && return 1
  # Stealth firewall requires Tailscale
  [[ $FIREWALL_MODE == "stealth" && $INSTALL_TAILSCALE != "yes" ]] && return 1
  return 0
}

# =============================================================================
# Display value formatters
# =============================================================================

# Builds formatted display values from current configuration state.
# Converts internal values to user-friendly display strings.
# Side effects: Sets _DSP_* global variables for menu rendering
_wiz_build_display_values() {
  # Password
  _DSP_PASS=""
  [[ -n $NEW_ROOT_PASSWORD ]] && _DSP_PASS="********"

  # Hostname
  _DSP_HOSTNAME=""
  [[ -n $PVE_HOSTNAME && -n $DOMAIN_SUFFIX ]] && _DSP_HOSTNAME="${PVE_HOSTNAME}.${DOMAIN_SUFFIX}"

  # IPv6
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

  # Tailscale
  _DSP_TAILSCALE=""
  if [[ -n $INSTALL_TAILSCALE ]]; then
    [[ $INSTALL_TAILSCALE == "yes" ]] && _DSP_TAILSCALE="Enabled + Stealth" || _DSP_TAILSCALE="Disabled"
  fi

  # SSL
  _DSP_SSL=""
  if [[ -n $SSL_TYPE ]]; then
    case "$SSL_TYPE" in
      self-signed) _DSP_SSL="Self-signed" ;;
      letsencrypt) _DSP_SSL="Let's Encrypt" ;;
      *) _DSP_SSL="$SSL_TYPE" ;;
    esac
  fi

  # Repository
  _DSP_REPO=""
  if [[ -n $PVE_REPO_TYPE ]]; then
    case "$PVE_REPO_TYPE" in
      no-subscription) _DSP_REPO="No-subscription (free)" ;;
      enterprise) _DSP_REPO="Enterprise" ;;
      test) _DSP_REPO="Test/Development" ;;
      *) _DSP_REPO="$PVE_REPO_TYPE" ;;
    esac
  fi

  # Bridge mode
  _DSP_BRIDGE=""
  if [[ -n $BRIDGE_MODE ]]; then
    case "$BRIDGE_MODE" in
      external) _DSP_BRIDGE="External bridge" ;;
      internal) _DSP_BRIDGE="Internal NAT" ;;
      both) _DSP_BRIDGE="Both" ;;
      *) _DSP_BRIDGE="$BRIDGE_MODE" ;;
    esac
  fi

  # ZFS mode
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
  fi

  # ZFS ARC
  _DSP_ARC=""
  if [[ -n $ZFS_ARC_MODE ]]; then
    case "$ZFS_ARC_MODE" in
      vm-focused) _DSP_ARC="VM-focused (4GB)" ;;
      balanced) _DSP_ARC="Balanced (25-40%)" ;;
      storage-focused) _DSP_ARC="Storage-focused (50%)" ;;
      *) _DSP_ARC="$ZFS_ARC_MODE" ;;
    esac
  fi

  # Shell
  _DSP_SHELL=""
  if [[ -n $SHELL_TYPE ]]; then
    case "$SHELL_TYPE" in
      zsh) _DSP_SHELL="ZSH" ;;
      bash) _DSP_SHELL="Bash" ;;
      *) _DSP_SHELL="$SHELL_TYPE" ;;
    esac
  fi

  # Power profile
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

  # Security features
  _DSP_SECURITY="none"
  local sec_items=()
  [[ $INSTALL_APPARMOR == "yes" ]] && sec_items+=("apparmor")
  [[ $INSTALL_AUDITD == "yes" ]] && sec_items+=("auditd")
  [[ $INSTALL_AIDE == "yes" ]] && sec_items+=("aide")
  [[ $INSTALL_CHKROOTKIT == "yes" ]] && sec_items+=("chkrootkit")
  [[ $INSTALL_LYNIS == "yes" ]] && sec_items+=("lynis")
  [[ $INSTALL_NEEDRESTART == "yes" ]] && sec_items+=("needrestart")
  [[ ${#sec_items[@]} -gt 0 ]] && _DSP_SECURITY="${sec_items[*]}"

  # Monitoring features
  _DSP_MONITORING="none"
  local mon_items=()
  [[ $INSTALL_VNSTAT == "yes" ]] && mon_items+=("vnstat")
  [[ $INSTALL_NETDATA == "yes" ]] && mon_items+=("netdata")
  [[ $INSTALL_PROMTAIL == "yes" ]] && mon_items+=("promtail")
  [[ ${#mon_items[@]} -gt 0 ]] && _DSP_MONITORING="${mon_items[*]}"

  # Tools
  _DSP_TOOLS="none"
  local tool_items=()
  [[ $INSTALL_YAZI == "yes" ]] && tool_items+=("yazi")
  [[ $INSTALL_NVIM == "yes" ]] && tool_items+=("nvim")
  [[ $INSTALL_RINGBUFFER == "yes" ]] && tool_items+=("ringbuffer")
  [[ ${#tool_items[@]} -gt 0 ]] && _DSP_TOOLS="${tool_items[*]}"

  # API Token
  _DSP_API=""
  if [[ -n $INSTALL_API_TOKEN ]]; then
    case "$INSTALL_API_TOKEN" in
      yes) _DSP_API="Yes (${API_TOKEN_NAME})" ;;
      no) _DSP_API="No" ;;
    esac
  fi

  # SSH Key
  _DSP_SSH=""
  [[ -n $SSH_PUBLIC_KEY ]] && _DSP_SSH="${SSH_PUBLIC_KEY:0:20}..."

  # Admin User
  _DSP_ADMIN_USER=""
  [[ -n $ADMIN_USERNAME ]] && _DSP_ADMIN_USER="$ADMIN_USERNAME"

  # Admin Password
  _DSP_ADMIN_PASS=""
  [[ -n $ADMIN_PASSWORD ]] && _DSP_ADMIN_PASS="********"

  # Firewall
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

  # ISO Version
  _DSP_ISO=""
  [[ -n $PROXMOX_ISO_VERSION ]] && _DSP_ISO=$(get_iso_version "$PROXMOX_ISO_VERSION")

  # MTU
  _DSP_MTU="${BRIDGE_MTU:-9000}"
  [[ $_DSP_MTU == "9000" ]] && _DSP_MTU="9000 (jumbo)"

  # Boot disk
  _DSP_BOOT="All in pool"
  if [[ -n $BOOT_DISK ]]; then
    for i in "${!DRIVES[@]}"; do
      if [[ ${DRIVES[$i]} == "$BOOT_DISK" ]]; then
        _DSP_BOOT="${DRIVE_MODELS[$i]}"
        break
      fi
    done
  fi

  # Pool disks
  _DSP_POOL="${#ZFS_POOL_DISKS[@]} disks"
}

# =============================================================================
# Screen content renderers
# =============================================================================

# Render fields for a specific screen
# Parameters:
#   $1 - screen index (0-5)
#   $2 - current selection within screen
# Uses: _add_field helper, field_idx counter
_wiz_render_screen_content() {
  local screen="$1"
  local selection="$2"

  case $screen in
    0) # Basic
      _add_field "Hostname         " "$(_wiz_fmt "$_DSP_HOSTNAME")" "hostname"
      _add_field "Email            " "$(_wiz_fmt "$EMAIL")" "email"
      _add_field "Password         " "$(_wiz_fmt "$_DSP_PASS")" "password"
      _add_field "Timezone         " "$(_wiz_fmt "$TIMEZONE")" "timezone"
      _add_field "Keyboard         " "$(_wiz_fmt "$KEYBOARD")" "keyboard"
      _add_field "Country          " "$(_wiz_fmt "$COUNTRY")" "country"
      ;;
    1) # Proxmox
      _add_field "Version          " "$(_wiz_fmt "$_DSP_ISO")" "iso_version"
      _add_field "Repository       " "$(_wiz_fmt "$_DSP_REPO")" "repository"
      ;;
    2) # Network
      if [[ ${INTERFACE_COUNT:-1} -gt 1 ]]; then
        _add_field "Interface        " "$(_wiz_fmt "$INTERFACE_NAME")" "interface"
      fi
      _add_field "Bridge mode      " "$(_wiz_fmt "$_DSP_BRIDGE")" "bridge_mode"
      if [[ $BRIDGE_MODE == "internal" || $BRIDGE_MODE == "both" ]]; then
        _add_field "Private subnet   " "$(_wiz_fmt "$PRIVATE_SUBNET")" "private_subnet"
        _add_field "Bridge MTU       " "$(_wiz_fmt "$_DSP_MTU")" "bridge_mtu"
      fi
      _add_field "IPv6             " "$(_wiz_fmt "$_DSP_IPV6")" "ipv6"
      _add_field "Firewall         " "$(_wiz_fmt "$_DSP_FIREWALL")" "firewall"
      ;;
    3) # Storage
      if [[ $DRIVE_COUNT -gt 1 ]]; then
        _add_field "Boot disk        " "$(_wiz_fmt "$_DSP_BOOT")" "boot_disk"
        _add_field "Pool disks       " "$(_wiz_fmt "$_DSP_POOL")" "pool_disks"
      fi
      _add_field "ZFS mode         " "$(_wiz_fmt "$_DSP_ZFS")" "zfs_mode"
      _add_field "ZFS ARC          " "$(_wiz_fmt "$_DSP_ARC")" "zfs_arc"
      ;;
    4) # Services
      _add_field "Tailscale        " "$(_wiz_fmt "$_DSP_TAILSCALE")" "tailscale"
      if [[ $INSTALL_TAILSCALE != "yes" ]]; then
        _add_field "SSL Certificate  " "$(_wiz_fmt "$_DSP_SSL")" "ssl"
      fi
      _add_field "Shell            " "$(_wiz_fmt "$_DSP_SHELL")" "shell"
      _add_field "Power profile    " "$(_wiz_fmt "$_DSP_POWER")" "power_profile"
      _add_field "Security         " "$(_wiz_fmt "$_DSP_SECURITY")" "security"
      _add_field "Monitoring       " "$(_wiz_fmt "$_DSP_MONITORING")" "monitoring"
      _add_field "Tools            " "$(_wiz_fmt "$_DSP_TOOLS")" "tools"
      ;;
    5) # Access
      _add_field "Admin User       " "$(_wiz_fmt "$_DSP_ADMIN_USER")" "admin_username"
      _add_field "Admin Password   " "$(_wiz_fmt "$_DSP_ADMIN_PASS")" "admin_password"
      _add_field "SSH Key          " "$(_wiz_fmt "$_DSP_SSH")" "ssh_key"
      _add_field "API Token        " "$(_wiz_fmt "$_DSP_API")" "api_token"
      ;;
  esac
}

# Render the main menu with current selection highlighted
# Parameters:
#   $1 - Current selection index (0-based, only counts selectable fields)
_wiz_render_menu() {
  local selection="$1"
  local output=""
  local banner_output

  # Capture banner output
  banner_output=$(show_banner)

  # Build display values
  _wiz_build_display_values

  # Start output with banner + navigation header
  output+="${banner_output}\n\n$(_wiz_render_nav)\n\n"

  # Reset field map
  _WIZ_FIELD_MAP=()
  local field_idx=0

  # Helper to add field (used by _wiz_render_screen_content)
  _add_field() {
    local label="$1"
    local value="$2"
    local field_name="$3"
    _WIZ_FIELD_MAP+=("$field_name")
    if [[ $field_idx -eq $selection ]]; then
      output+="${CLR_ORANGE}›${CLR_RESET} ${CLR_GRAY}${label}${CLR_RESET}${value}\n"
    else
      output+="  ${CLR_GRAY}${label}${CLR_RESET}${value}\n"
    fi
    ((field_idx++))
  }

  # Render current screen content
  _wiz_render_screen_content "$WIZ_CURRENT_SCREEN" "$selection"

  # Store total field count for this screen
  _WIZ_FIELD_COUNT=$field_idx

  output+="\n"

  # Footer with navigation hints (centered)
  # Left/right/start hints: orange when active, gray when inactive
  local left_clr right_clr start_clr
  left_clr=$([[ $WIZ_CURRENT_SCREEN -gt 0 ]] && echo "$CLR_ORANGE" || echo "$CLR_GRAY")
  right_clr=$([[ $WIZ_CURRENT_SCREEN -lt $((${#WIZ_SCREENS[@]} - 1)) ]] && echo "$CLR_ORANGE" || echo "$CLR_GRAY")
  start_clr=$(_wiz_config_complete && echo "$CLR_ORANGE" || echo "$CLR_GRAY")

  local nav_hint=""
  nav_hint+="[${left_clr}←${CLR_GRAY}] prev  "
  nav_hint+="[${CLR_ORANGE}↑↓${CLR_GRAY}] navigate  [${CLR_ORANGE}Enter${CLR_GRAY}] edit  "
  nav_hint+="[${right_clr}→${CLR_GRAY}] next  "
  nav_hint+="[${start_clr}S${CLR_GRAY}] start  [${CLR_ORANGE}Q${CLR_GRAY}] quit"

  output+="$(_wiz_center "${CLR_GRAY}${nav_hint}${CLR_RESET}")"

  # Clear screen and output everything atomically
  _wiz_clear
  printf '%b' "$output"
}
