# shellcheck shell=bash
# =============================================================================
# Auditd configuration for administrative action logging
# Provides audit trail for security compliance and forensics
# =============================================================================

# Installation function for auditd
_install_auditd() {
  run_remote "Installing auditd" '
    export DEBIAN_FRONTEND=noninteractive
    apt-get update -qq
    apt-get install -yqq auditd audispd-plugins
  ' "Auditd installed"
}

# Configuration function for auditd
_config_auditd() {
  # Copy rules to VM
  remote_copy "templates/auditd-rules" "/etc/audit/rules.d/proxmox.rules" || exit 1

  # Configure auditd for persistent logging
  remote_exec '
    # Ensure log directory exists
    mkdir -p /var/log/audit

    # Configure auditd.conf for better log retention
    sed -i "s/^max_log_file = .*/max_log_file = 50/" /etc/audit/auditd.conf 2>/dev/null || true
    sed -i "s/^num_logs = .*/num_logs = 10/" /etc/audit/auditd.conf 2>/dev/null || true
    sed -i "s/^max_log_file_action = .*/max_log_file_action = ROTATE/" /etc/audit/auditd.conf 2>/dev/null || true

    # Load new rules
    augenrules --load 2>/dev/null || true

    # Enable auditd to start on boot (will activate after reboot)
    systemctl enable auditd
  ' || exit 1
}

# Installs and configures auditd for system audit logging.
# Deploys custom audit rules for Proxmox administrative actions.
# Configures log rotation and persistence settings.
# Side effects: Sets AUDITD_INSTALLED global, installs auditd package
configure_auditd() {
  install_optional_feature_with_progress \
    "Auditd" \
    "INSTALL_AUDITD" \
    "_install_auditd" \
    "_config_auditd" \
    "AUDITD_INSTALLED" \
    "Installing and configuring auditd" \
    "Auditd configured"
}
