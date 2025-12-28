# shellcheck shell=bash
# Auditd configuration for administrative action logging
# Provides audit trail for security compliance and forensics
# Package installed via batch_install_packages() in 037-parallel-helpers.sh

# Configuration function for auditd
# Deploys audit rules and configures log retention
_config_auditd() {
  deploy_template "templates/auditd-rules" "/etc/audit/rules.d/proxmox.rules" || {
    log "ERROR: Failed to deploy auditd rules"
    return 1
  }

  # Configure auditd log settings (50MB files, 10 max, rotate)
  # Remove other rules FIRST to avoid "failure 1" duplicate warnings during augenrules --load
  # Stop auditd before modifying rules to prevent conflicts
  remote_exec '
    mkdir -p /var/log/audit
    # Stop auditd to prevent rule conflicts during cleanup
    systemctl stop auditd 2>/dev/null || true
    # Remove ALL default/conflicting rules before our rules
    find /etc/audit/rules.d -name "*.rules" ! -name "proxmox.rules" -delete 2>/dev/null || true
    rm -f /etc/audit/audit.rules 2>/dev/null || true
    # Configure auditd settings
    sed -i "s/^max_log_file = .*/max_log_file = 50/" /etc/audit/auditd.conf
    sed -i "s/^num_logs = .*/num_logs = 10/" /etc/audit/auditd.conf
    sed -i "s/^max_log_file_action = .*/max_log_file_action = ROTATE/" /etc/audit/auditd.conf
    # Regenerate rules from clean state
    augenrules --load 2>/dev/null || true
  ' || {
    log "ERROR: Failed to configure auditd"
    return 1
  }

  remote_enable_services "auditd"
  parallel_mark_configured "auditd"
}

# Public wrapper (generated via factory)
make_feature_wrapper "auditd" "INSTALL_AUDITD"
