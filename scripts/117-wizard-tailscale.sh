# shellcheck shell=bash
# =============================================================================
# Configuration Wizard - Tailscale Settings Editors
# =============================================================================

# Prompts for Tailscale auth key with validation.
# Returns: auth key via stdout, empty if cancelled
_tailscale_get_auth_key() {
  local auth_key=""

  while true; do
    _wiz_start_edit
    _show_input_footer

    auth_key=$(
      _wiz_input \
        --placeholder "tskey-auth-..." \
        --prompt "Auth Key: "
    )

    [[ -z $auth_key ]] && return

    if validate_tailscale_key "$auth_key"; then
      printf '%s' "$auth_key"
      return 0
    fi

    show_validation_error "Invalid key format. Expected: tskey-auth-xxx-xxx"
  done
}

# Prompts for Tailscale Web UI (Serve) configuration.
# Side effects: Sets TAILSCALE_WEBUI global
_tailscale_configure_webui() {
  _wiz_start_edit
  _wiz_description \
    "  Expose Proxmox Web UI via Tailscale Serve?" \
    "" \
    "  {{cyan:Enabled}}:  Access Web UI at https://<tailscale-hostname>" \
    "  {{cyan:Disabled}}: Web UI only via direct IP" \
    "" \
    "  Uses: tailscale serve --bg --https=443 https://127.0.0.1:8006" \
    ""

  _show_input_footer "filter" 3

  local webui_selected
  if webui_selected=$(printf '%s\n' "$WIZ_TOGGLE_OPTIONS" | _wiz_choose --header="Tailscale Web UI:"); then
    case "$webui_selected" in
      Enabled) TAILSCALE_WEBUI="yes" ;;
      Disabled) TAILSCALE_WEBUI="no" ;;
    esac
  else
    TAILSCALE_WEBUI="no"
  fi
}

# Enables Tailscale with auth key and configures related settings.
# Parameters: $1 - auth key
# Side effects: Sets INSTALL_TAILSCALE, TAILSCALE_AUTH_KEY, SSL_TYPE, FIREWALL_MODE
_tailscale_enable() {
  local auth_key="$1"

  INSTALL_TAILSCALE="yes"
  TAILSCALE_AUTH_KEY="$auth_key"

  _tailscale_configure_webui

  SSL_TYPE="self-signed"
  if [[ -z $INSTALL_FIREWALL ]]; then
    INSTALL_FIREWALL="yes"
    FIREWALL_MODE="stealth"
  fi
}

# Disables Tailscale and clears related settings.
# Side effects: Clears INSTALL_TAILSCALE, TAILSCALE_AUTH_KEY, TAILSCALE_WEBUI, SSL_TYPE
_tailscale_disable() {
  INSTALL_TAILSCALE="no"
  TAILSCALE_AUTH_KEY=""
  TAILSCALE_WEBUI=""
  SSL_TYPE=""
  if [[ -z $INSTALL_FIREWALL ]]; then
    INSTALL_FIREWALL="yes"
    FIREWALL_MODE="standard"
  fi
}

# Edits Tailscale VPN configuration.
# Prompts for auth key if enabled, validates key format.
# Updates INSTALL_TAILSCALE, TAILSCALE_AUTH_KEY, SSL_TYPE, FIREWALL_MODE globals.
_edit_tailscale() {
  _wiz_start_edit

  _wiz_description \
    "  Tailscale VPN with stealth mode:" \
    "" \
    "  {{cyan:Enabled}}:  Access via Tailscale only (blocks public SSH)" \
    "  {{cyan:Disabled}}: Standard access via public IP" \
    "" \
    "  Stealth mode blocks ALL incoming traffic on public IP." \
    ""

  _show_input_footer "filter" 3

  local selected
  if ! selected=$(printf '%s\n' "$WIZ_TOGGLE_OPTIONS" | _wiz_choose --header="Tailscale:"); then
    return
  fi

  case "$selected" in
    Enabled)
      local auth_key
      auth_key=$(_tailscale_get_auth_key)
      if [[ -n $auth_key ]]; then
        _tailscale_enable "$auth_key"
      else
        _tailscale_disable
      fi
      ;;
    Disabled)
      _tailscale_disable
      ;;
  esac
}
