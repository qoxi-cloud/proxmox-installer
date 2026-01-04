# shellcheck shell=bash
# Auditd configuration for administrative action logging
# Provides audit trail for security compliance and forensics
# Package installed via batch_install_packages() in 037-parallel-helpers.sh

# Configuration function for auditd
# Deploys audit rules and configures log retention
_config_auditd() {
  deploy_template "templates/auditd-rules" "/etc/audit/rules.d/proxmox.rules" \
    "ADMIN_USERNAME=${ADMIN_USERNAME}" || {
    log_error "Failed to deploy auditd rules"
    return 1
  }

  # Configure auditd log settings (50MB files, 10 max, rotate)
  # Remove other rules FIRST to avoid "failure 1" duplicate warnings during augenrules --load
  # Stop auditd before modifying rules to prevent conflicts
  # shellcheck disable=SC2016
  remote_exec '
    mkdir -p /var/log/audit
    # Create directories that audit rules will watch (rules fail if paths dont exist)
    mkdir -p /etc/ssh/sshd_config.d /root/.ssh /etc/network/interfaces.d
    mkdir -p /etc/modprobe.d /etc/cron.d /etc/cron.daily /etc/cron.hourly
    mkdir -p /etc/cron.monthly /etc/cron.weekly /var/spool/cron/crontabs
    mkdir -p /etc/sudoers.d /etc/pam.d /etc/security /etc/init.d
    mkdir -p /etc/systemd/system /etc/fail2ban
    mkdir -p /home/'"${ADMIN_USERNAME}"'/.ssh
    chmod 700 /root/.ssh /home/'"${ADMIN_USERNAME}"'/.ssh
    # audit-rules.service must start AFTER pve-cluster mounts /etc/pve (FUSE filesystem)
    mkdir -p /etc/systemd/system/audit-rules.service.d
    cat > /etc/systemd/system/audit-rules.service.d/after-pve.conf << "DROPIN"
[Unit]
After=pve-cluster.service
Wants=pve-cluster.service
DROPIN
    # Remove ALL default/conflicting rules before our rules
    find /etc/audit/rules.d -name "*.rules" ! -name "proxmox.rules" -delete 2>/dev/null || true
    rm -f /etc/audit/audit.rules 2>/dev/null || true
    # Configure auditd settings
    sed -i "s/^max_log_file = .*/max_log_file = 50/" /etc/audit/auditd.conf
    sed -i "s/^num_logs = .*/num_logs = 10/" /etc/audit/auditd.conf
    sed -i "s/^max_log_file_action = .*/max_log_file_action = ROTATE/" /etc/audit/auditd.conf
    # Enable auditd for boot (dont start yet)
    systemctl daemon-reload
    systemctl enable auditd
    # Stop auditd, load new rules, then restart
    # auditd requires special handling - use service command for stop/start
    service auditd stop 2>/dev/null || true
    sleep 1
    auditctl -D 2>/dev/null || true
    augenrules --load 2>/dev/null || true
    # Start with retry - audit subsystem may need time to stabilize
    for i in 1 2 3; do
      service auditd start 2>/dev/null && break
      sleep 2
    done
  ' || {
    log_error "Failed to configure auditd"
    return 1
  }
  parallel_mark_configured "auditd"
}

# Public wrapper (generated via factory)
make_feature_wrapper "auditd" "INSTALL_AUDITD"
