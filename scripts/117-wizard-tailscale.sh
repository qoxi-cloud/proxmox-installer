# shellcheck shell=bash
# Configuration Wizard - Tailscale Settings Editors

# Prompts for Tailscale auth key with validation.
# Sets _TAILSCALE_TMP_KEY on success, clears on cancel.
_tailscale_get_auth_key() {
  declare -g _TAILSCALE_TMP_KEY=""
  _wiz_input_validated "_TAILSCALE_TMP_KEY" "validate_tailscale_key" \
    "Invalid key format. Expected: tskey-auth-xxx-xxx" \
    --placeholder "tskey-auth-..." \
    --prompt "Auth Key: "
}

# Prompt for Tailscale Web UI config. Sets TAILSCALE_WEBUI.
_tailscale_configure_webui() {
  _wiz_start_edit
  _wiz_description \
    "  Expose Proxmox Web UI via Tailscale Serve?" \
    "" \
    "  {{cyan:Enabled}}:  Access Web UI at https://<tailscale-hostname>" \
    "  {{cyan:Disabled}}: Web UI only via direct IP" \
    "" \
    "  Uses: tailscale serve --bg --https=443 https://127.0.0.1:443" \
    ""

  _show_input_footer "filter" 3

  _wiz_toggle "TAILSCALE_WEBUI" "Tailscale Web UI:" "no"
}

# Enable Tailscale with auth key. $1=auth_key
_tailscale_enable() {
  local auth_key="$1"

  declare -g INSTALL_TAILSCALE="yes"
  declare -g TAILSCALE_AUTH_KEY="$auth_key"

  _tailscale_configure_webui

  declare -g SSL_TYPE="self-signed"
  if [[ -z $INSTALL_FIREWALL ]]; then
    declare -g INSTALL_FIREWALL="yes"
    declare -g FIREWALL_MODE="stealth"
  fi
}

# Disable Tailscale and clear related settings
_tailscale_disable() {
  declare -g INSTALL_TAILSCALE="no"
  declare -g TAILSCALE_AUTH_KEY=""
  declare -g TAILSCALE_WEBUI=""
  declare -g SSL_TYPE=""
  if [[ -z $INSTALL_FIREWALL ]]; then
    declare -g INSTALL_FIREWALL="yes"
    declare -g FIREWALL_MODE="standard"
  fi
}

# Edit Tailscale VPN configuration
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

  local result
  _wiz_toggle "INSTALL_TAILSCALE" "Tailscale:"
  result=$?

  if [[ $result -eq 1 ]]; then
    return
  elif [[ $result -eq 2 ]]; then
    # Enabled - get auth key
    if _tailscale_get_auth_key && [[ -n $_TAILSCALE_TMP_KEY ]]; then
      _tailscale_enable "$_TAILSCALE_TMP_KEY"
    else
      _tailscale_disable
    fi
  else
    _tailscale_disable
  fi
}
