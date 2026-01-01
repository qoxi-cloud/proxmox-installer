# shellcheck shell=bash
# Configuration Wizard - Postfix Mail Settings Editor

# Prompts for SMTP relay configuration. Sets SMTP_RELAY_* variables.
_postfix_configure_relay() {
  _wiz_start_edit

  _wiz_description \
    "  SMTP Relay Configuration:" \
    "" \
    "  Configure external SMTP server for sending mail." \
    "  Common providers: Gmail, Mailgun, SendGrid, AWS SES" \
    ""

  # SMTP Host
  _wiz_input_validated "SMTP_RELAY_HOST" "validate_smtp_host" \
    "Invalid host. Enter hostname, FQDN, or IP address." \
    --placeholder "smtp.example.com" \
    --value "${SMTP_RELAY_HOST:-smtp.gmail.com}" \
    --prompt "SMTP Host: " || return 1

  # SMTP Port
  _wiz_input_validated "SMTP_RELAY_PORT" "validate_smtp_port" \
    "Invalid port. Enter a number between 1 and 65535." \
    --placeholder "587" \
    --value "${SMTP_RELAY_PORT:-587}" \
    --prompt "SMTP Port: " || return 1

  # Username (email format)
  _wiz_input_validated "SMTP_RELAY_USER" "validate_email" \
    "Invalid email format." \
    --placeholder "user@example.com" \
    --value "${SMTP_RELAY_USER}" \
    --prompt "Username: " || return 1

  # Password (non-empty)
  _wiz_input_validated "SMTP_RELAY_PASSWORD" "validate_not_empty" \
    "Password cannot be empty." \
    --password \
    --placeholder "App password or API key" \
    --value "${SMTP_RELAY_PASSWORD}" \
    --prompt "Password: " || return 1

  return 0
}

# Enable Postfix with relay configuration
_postfix_enable() {
  declare -g INSTALL_POSTFIX="yes"
  _postfix_configure_relay || {
    declare -g INSTALL_POSTFIX="no"
    declare -g SMTP_RELAY_HOST=""
    declare -g SMTP_RELAY_PORT=""
    declare -g SMTP_RELAY_USER=""
    declare -g SMTP_RELAY_PASSWORD=""
  }
}

# Disable Postfix and clear settings
_postfix_disable() {
  declare -g INSTALL_POSTFIX="no"
  declare -g SMTP_RELAY_HOST=""
  declare -g SMTP_RELAY_PORT=""
  declare -g SMTP_RELAY_USER=""
  declare -g SMTP_RELAY_PASSWORD=""
}

# Edit Postfix mail configuration
_edit_postfix() {
  _wiz_start_edit

  _wiz_description \
    "  Postfix Mail Relay:" \
    "" \
    "  {{cyan:Enabled}}:  Send mail via external SMTP relay (port 587)" \
    "  {{cyan:Disabled}}: Disable Postfix service completely" \
    "" \
    "  Note: Most hosting providers block port 25." \
    "  Use relay with port 587 for outgoing mail." \
    ""

  _show_input_footer "filter" 3

  local result
  _wiz_toggle "INSTALL_POSTFIX" "Postfix:"
  result=$?

  if [[ $result -eq 1 ]]; then
    return
  elif [[ $result -eq 2 ]]; then
    # Enabled - configure relay
    _postfix_enable
  else
    _postfix_disable
  fi
}
