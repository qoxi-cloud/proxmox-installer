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

  _show_input_footer

  # SMTP Host
  local host
  host=$(_wiz_input \
    --placeholder "smtp.example.com" \
    --value "${SMTP_RELAY_HOST:-smtp.gmail.com}" \
    --prompt "SMTP Host: ")
  [[ -z $host ]] && return 1
  SMTP_RELAY_HOST="$host"

  # SMTP Port
  local port
  port=$(_wiz_input \
    --placeholder "587" \
    --value "${SMTP_RELAY_PORT:-587}" \
    --prompt "SMTP Port: ")
  [[ -z $port ]] && return 1
  SMTP_RELAY_PORT="$port"

  # Username
  local user
  user=$(_wiz_input \
    --placeholder "user@example.com" \
    --value "${SMTP_RELAY_USER}" \
    --prompt "Username: ")
  [[ -z $user ]] && return 1
  SMTP_RELAY_USER="$user"

  # Password
  local pass
  pass=$(_wiz_input \
    --password \
    --placeholder "App password or API key" \
    --value "${SMTP_RELAY_PASSWORD}" \
    --prompt "Password: ")
  [[ -z $pass ]] && return 1
  SMTP_RELAY_PASSWORD="$pass"

  return 0
}

# Enable Postfix with relay configuration
_postfix_enable() {
  INSTALL_POSTFIX="yes"
  _postfix_configure_relay || {
    INSTALL_POSTFIX="no"
    SMTP_RELAY_HOST=""
    SMTP_RELAY_PORT=""
    SMTP_RELAY_USER=""
    SMTP_RELAY_PASSWORD=""
  }
}

# Disable Postfix and clear settings
_postfix_disable() {
  INSTALL_POSTFIX="no"
  SMTP_RELAY_HOST=""
  SMTP_RELAY_PORT=""
  SMTP_RELAY_USER=""
  SMTP_RELAY_PASSWORD=""
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
