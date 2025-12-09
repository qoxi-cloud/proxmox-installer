# shellcheck shell=bash
# =============================================================================
# Configuration Wizard - Step-by-step configuration using gum
# =============================================================================

# Current wizard step (1-based)
WIZARD_STEP=1
WIZARD_TOTAL_STEPS=1 # Will be updated as we add more steps

# =============================================================================
# Step 1: Basic Settings
# =============================================================================

# Display Step 1: Basic Settings
# Allows user to configure: Hostname, Email, Password, Timezone
_wizard_step_basic() {
  local step_valid=false

  while [[ $step_valid == false ]]; do
    clear
    show_banner
    echo ""

    # Step title in cyan/blue
    gum style --foreground "$HEX_CYAN" --bold "Basic Settings"
    echo ""

    # Show current values
    local pass_display
    pass_display=$([[ $PASSWORD_GENERATED == "yes" ]] && echo "auto-generated" || echo "********")

    echo "  Hostname:    ${PVE_HOSTNAME}.${DOMAIN_SUFFIX}"
    echo "  Email:       ${EMAIL}"
    echo "  Password:    ${pass_display}"
    echo "  Timezone:    ${TIMEZONE}"
    echo ""

    # Action menu
    local action
    action=$(gum choose \
      "Edit Hostname" \
      "Edit Email" \
      "Edit Password" \
      "Edit Timezone" \
      "Continue →" \
      --cursor "› " \
      --cursor.foreground "$HEX_ORANGE" \
      --selected.foreground "$HEX_ORANGE")

    case "$action" in
      "Edit Hostname")
        _wizard_edit_hostname
        ;;
      "Edit Email")
        _wizard_edit_email
        ;;
      "Edit Password")
        _wizard_edit_password
        ;;
      "Edit Timezone")
        _wizard_edit_timezone
        ;;
      "Continue →")
        # Validate before continuing
        if [[ -z $PVE_HOSTNAME ]]; then
          gum style --foreground "$HEX_RED" "Hostname is required!"
          sleep 1
          continue
        fi
        if [[ -z $EMAIL ]] || ! validate_email "$EMAIL"; then
          gum style --foreground "$HEX_RED" "Valid email is required!"
          sleep 1
          continue
        fi
        step_valid=true
        ;;
    esac
  done
}

# Edit hostname (hostname + domain)
_wizard_edit_hostname() {
  echo ""

  # Hostname
  local new_hostname
  new_hostname=$(gum input \
    --placeholder "Enter hostname (e.g., pve, proxmox)" \
    --value "$PVE_HOSTNAME" \
    --prompt "Hostname: " \
    --prompt.foreground "$HEX_ORANGE" \
    --cursor.foreground "$HEX_ORANGE" \
    --width 40)

  if [[ -n $new_hostname ]]; then
    if validate_hostname "$new_hostname"; then
      PVE_HOSTNAME="$new_hostname"
    else
      gum style --foreground "$HEX_RED" "Invalid hostname format"
      sleep 1
      return
    fi
  fi

  # Domain
  local new_domain
  new_domain=$(gum input \
    --placeholder "Enter domain (e.g., local, example.com)" \
    --value "$DOMAIN_SUFFIX" \
    --prompt "Domain: " \
    --prompt.foreground "$HEX_ORANGE" \
    --cursor.foreground "$HEX_ORANGE" \
    --width 40)

  if [[ -n $new_domain ]]; then
    DOMAIN_SUFFIX="$new_domain"
  fi

  FQDN="${PVE_HOSTNAME}.${DOMAIN_SUFFIX}"
}

# Edit email
_wizard_edit_email() {
  echo ""

  local new_email
  new_email=$(gum input \
    --placeholder "Enter email address" \
    --value "$EMAIL" \
    --prompt "Email: " \
    --prompt.foreground "$HEX_ORANGE" \
    --cursor.foreground "$HEX_ORANGE" \
    --width 50)

  if [[ -n $new_email ]]; then
    if validate_email "$new_email"; then
      EMAIL="$new_email"
    else
      gum style --foreground "$HEX_RED" "Invalid email format"
      sleep 1
    fi
  fi
}

# Edit password
_wizard_edit_password() {
  echo ""

  local new_password
  new_password=$(gum input \
    --password \
    --placeholder "Enter password (empty to auto-generate)" \
    --prompt "Password: " \
    --prompt.foreground "$HEX_ORANGE" \
    --cursor.foreground "$HEX_ORANGE" \
    --width 40)

  if [[ -z $new_password ]]; then
    NEW_ROOT_PASSWORD=$(generate_password "$DEFAULT_PASSWORD_LENGTH")
    PASSWORD_GENERATED="yes"
    gum style --foreground "$HEX_GREEN" "Password auto-generated"
    sleep 1
  else
    local password_error
    password_error=$(get_password_error "$new_password")
    if [[ -n $password_error ]]; then
      gum style --foreground "$HEX_RED" "$password_error"
      sleep 2
    else
      NEW_ROOT_PASSWORD="$new_password"
      PASSWORD_GENERATED="no"
    fi
  fi
}

# Edit timezone
_wizard_edit_timezone() {
  echo ""

  local tz_options="Europe/Kyiv
Europe/London
Europe/Berlin
America/New_York
America/Los_Angeles
Asia/Tokyo
UTC
Custom..."

  local selected
  selected=$(echo "$tz_options" | gum choose \
    --cursor "› " \
    --cursor.foreground "$HEX_ORANGE" \
    --selected.foreground "$HEX_ORANGE" \
    --header "Select timezone:")

  if [[ $selected == "Custom..." ]]; then
    local custom_tz
    custom_tz=$(gum input \
      --placeholder "Enter timezone (e.g., Europe/Paris)" \
      --value "$TIMEZONE" \
      --prompt "Timezone: " \
      --prompt.foreground "$HEX_ORANGE" \
      --cursor.foreground "$HEX_ORANGE" \
      --width 40)

    if [[ -n $custom_tz ]]; then
      if validate_timezone "$custom_tz"; then
        TIMEZONE="$custom_tz"
      else
        gum style --foreground "$HEX_RED" "Invalid timezone"
        sleep 1
      fi
    fi
  elif [[ -n $selected ]]; then
    TIMEZONE="$selected"
  fi
}

# =============================================================================
# Initialize defaults
# =============================================================================

_init_default_config() {
  # Basic settings
  [[ -z $PVE_HOSTNAME ]] && PVE_HOSTNAME="$DEFAULT_HOSTNAME"
  [[ -z $DOMAIN_SUFFIX ]] && DOMAIN_SUFFIX="$DEFAULT_DOMAIN"
  [[ -z $EMAIL ]] && EMAIL="$DEFAULT_EMAIL"
  [[ -z $TIMEZONE ]] && TIMEZONE="$DEFAULT_TIMEZONE"

  # Password - auto-generate if not set
  if [[ -z $NEW_ROOT_PASSWORD ]]; then
    NEW_ROOT_PASSWORD=$(generate_password "$DEFAULT_PASSWORD_LENGTH")
    PASSWORD_GENERATED="yes"
  fi

  # Network
  [[ -z $BRIDGE_MODE ]] && BRIDGE_MODE="$DEFAULT_BRIDGE_MODE"
  [[ -z $PRIVATE_SUBNET ]] && PRIVATE_SUBNET="$DEFAULT_SUBNET"
  [[ -z $IPV6_MODE ]] && IPV6_MODE="$DEFAULT_IPV6_MODE"
  [[ -z $IPV6_GATEWAY ]] && IPV6_GATEWAY="$DEFAULT_IPV6_GATEWAY"

  # Calculate private network values
  if [[ $BRIDGE_MODE == "internal" || $BRIDGE_MODE == "both" ]]; then
    PRIVATE_CIDR=$(echo "$PRIVATE_SUBNET" | cut -d'/' -f1 | rev | cut -d'.' -f2- | rev)
    PRIVATE_IP="${PRIVATE_CIDR}.1"
    SUBNET_MASK=$(echo "$PRIVATE_SUBNET" | cut -d'/' -f2)
    PRIVATE_IP_CIDR="${PRIVATE_IP}/${SUBNET_MASK}"
  fi

  # Storage - set default based on drive count
  if [[ -z $ZFS_RAID ]]; then
    if [[ ${DRIVE_COUNT:-0} -ge 2 ]]; then
      ZFS_RAID="raid1"
    else
      ZFS_RAID="single"
    fi
  fi

  # Proxmox
  [[ -z $PVE_REPO_TYPE ]] && PVE_REPO_TYPE="$DEFAULT_REPO_TYPE"

  # SSL
  [[ -z $SSL_TYPE ]] && SSL_TYPE="$DEFAULT_SSL_TYPE"

  # Tailscale - default to not installed
  [[ -z $INSTALL_TAILSCALE ]] && INSTALL_TAILSCALE="no"

  # Optional features
  [[ -z $DEFAULT_SHELL ]] && DEFAULT_SHELL="zsh"
  [[ -z $CPU_GOVERNOR ]] && CPU_GOVERNOR="$DEFAULT_CPU_GOVERNOR"
  [[ -z $INSTALL_VNSTAT ]] && INSTALL_VNSTAT="yes"
  [[ -z $INSTALL_UNATTENDED_UPGRADES ]] && INSTALL_UNATTENDED_UPGRADES="yes"
  [[ -z $INSTALL_AUDITD ]] && INSTALL_AUDITD="no"

  # SSH key - try to detect from rescue system
  if [[ -z $SSH_PUBLIC_KEY ]]; then
    SSH_PUBLIC_KEY=$(get_rescue_ssh_key 2>/dev/null || true)
  fi

  # Calculate FQDN
  FQDN="${PVE_HOSTNAME}.${DOMAIN_SUFFIX}"
}

# =============================================================================
# Main wizard entry point
# =============================================================================

show_gum_config_editor() {
  # Initialize network detection first
  detect_network_interface
  collect_network_info

  # Initialize default configuration values
  _init_default_config

  # Run wizard steps
  _wizard_step_basic

  # TODO: Add more steps here
  # _wizard_step_network
  # _wizard_step_storage
  # etc.
}
