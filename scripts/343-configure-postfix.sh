# shellcheck shell=bash
# Postfix mail relay configuration

# Private implementation - configures Postfix SMTP relay
_config_postfix_relay() {
  local relay_host="${SMTP_RELAY_HOST}"
  local relay_port="${SMTP_RELAY_PORT:-587}"
  local relay_user="${SMTP_RELAY_USER}"
  local relay_pass="${SMTP_RELAY_PASSWORD}"

  # Deploy main.cf configuration
  deploy_template "templates/postfix-main.cf" "/etc/postfix/main.cf" \
    "SMTP_RELAY_HOST=${relay_host}" \
    "SMTP_RELAY_PORT=${relay_port}" \
    "HOSTNAME=${PVE_HOSTNAME}" \
    "DOMAIN_SUFFIX=${DOMAIN_SUFFIX}" || return 1

  # Create SASL password file (use temp file + copy to handle special chars safely)
  local tmp_passwd
  tmp_passwd=$(mktemp) || return 1
  printf '[%s]:%s %s:%s\n' "$relay_host" "$relay_port" "$relay_user" "$relay_pass" >"$tmp_passwd"

  remote_copy "$tmp_passwd" "/etc/postfix/sasl_passwd" || {
    rm -f "$tmp_passwd"
    return 1
  }
  rm -f "$tmp_passwd"

  # Secure password file and generate hash (set umask to prevent any readable window)
  remote_exec '
    umask 077
    chmod 600 /etc/postfix/sasl_passwd
    chown root:root /etc/postfix/sasl_passwd
    postmap /etc/postfix/sasl_passwd
    chmod 600 /etc/postfix/sasl_passwd.db
    chown root:root /etc/postfix/sasl_passwd.db
  ' || return 1

  # Restart Postfix (no progress - called from parallel group)
  remote_exec 'systemctl restart postfix' || return 1

  parallel_mark_configured "postfix"
}

# Private implementation - disables Postfix service
_config_postfix_disable() {
  remote_exec 'systemctl stop postfix 2>/dev/null; systemctl disable postfix 2>/dev/null' || true
  log_info "Postfix disabled"
  parallel_mark_configured "postfix disabled"
}

# Public wrapper - configures or disables Postfix based on INSTALL_POSTFIX
configure_postfix() {
  if [[ $INSTALL_POSTFIX == "yes" ]]; then
    if [[ -n $SMTP_RELAY_HOST && -n $SMTP_RELAY_USER && -n $SMTP_RELAY_PASSWORD ]]; then
      _config_postfix_relay || return 1
    else
      log_warn "Postfix enabled but SMTP relay not configured, skipping"
    fi
  elif [[ $INSTALL_POSTFIX == "no" ]]; then
    _config_postfix_disable
  fi
  # If INSTALL_POSTFIX is empty, leave Postfix as default (no changes)
}
