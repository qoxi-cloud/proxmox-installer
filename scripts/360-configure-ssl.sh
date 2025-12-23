# shellcheck shell=bash
# =============================================================================
# SSL certificate configuration via SSH
# =============================================================================

# Private implementation - configures SSL certificates
# Called by configure_ssl_certificate() public wrapper
_config_ssl() {
  log "_config_ssl: SSL_TYPE=$SSL_TYPE"

  # Build FQDN if not set
  local cert_domain="${FQDN:-$PVE_HOSTNAME.$DOMAIN_SUFFIX}"
  log "configure_ssl_certificate: domain=$cert_domain, email=$EMAIL"

  # Stage template to preserve original, apply substitutions to staged copy
  local staged
  staged=$(mktemp) || {
    log "ERROR: Failed to create temp file for letsencrypt-firstboot.sh"
    return 1
  }
  cp "./templates/letsencrypt-firstboot.sh" "$staged" || {
    log "ERROR: Failed to stage letsencrypt-firstboot.sh"
    rm -f "$staged"
    return 1
  }

  if ! apply_template_vars "$staged" \
    "CERT_DOMAIN=${cert_domain}" \
    "CERT_EMAIL=${EMAIL}"; then
    log "ERROR: Failed to apply template variables to letsencrypt-firstboot.sh"
    rm -f "$staged"
    return 1
  fi

  # Copy Let's Encrypt templates to VM
  if ! remote_copy "./templates/letsencrypt-deploy-hook.sh" "/tmp/letsencrypt-deploy-hook.sh"; then
    log "ERROR: Failed to copy letsencrypt-deploy-hook.sh"
    rm -f "$staged"
    return 1
  fi
  if ! remote_copy "$staged" "/tmp/letsencrypt-firstboot.sh"; then
    log "ERROR: Failed to copy letsencrypt-firstboot.sh"
    rm -f "$staged"
    return 1
  fi
  rm -f "$staged"
  if ! remote_copy "./templates/letsencrypt-firstboot.service" "/tmp/letsencrypt-firstboot.service"; then
    log "ERROR: Failed to copy letsencrypt-firstboot.service"
    return 1
  fi

  # Install deploy hook, first-boot script, and systemd service
  remote_run "Configuring Let's Encrypt templates" '
        set -e
        mkdir -p /etc/letsencrypt/renewal-hooks/deploy
        mv /tmp/letsencrypt-deploy-hook.sh /etc/letsencrypt/renewal-hooks/deploy/proxmox.sh
        chmod +x /etc/letsencrypt/renewal-hooks/deploy/proxmox.sh
        mv /tmp/letsencrypt-firstboot.sh /usr/local/bin/obtain-letsencrypt-cert.sh
        chmod +x /usr/local/bin/obtain-letsencrypt-cert.sh
        mv /tmp/letsencrypt-firstboot.service /etc/systemd/system/letsencrypt-firstboot.service
        systemctl daemon-reload
        systemctl enable letsencrypt-firstboot.service
    ' "First-boot certificate service configured"

  # Store the domain for summary
  LETSENCRYPT_DOMAIN="$cert_domain"
  LETSENCRYPT_FIRSTBOOT=true
}

# =============================================================================
# Public wrapper
# =============================================================================

# Configures SSL certificates for Proxmox Web UI.
# For Let's Encrypt, sets up first-boot certificate acquisition.
# Certbot package installed via batch_install_packages() in 037-parallel-helpers.sh
# Side effects: Configures systemd service for cert renewal
configure_ssl_certificate() {
  # Skip if not using Let's Encrypt
  if [[ $SSL_TYPE != "letsencrypt" ]]; then
    log "configure_ssl_certificate: skipping (self-signed)"
    return 0
  fi
  _config_ssl
}
