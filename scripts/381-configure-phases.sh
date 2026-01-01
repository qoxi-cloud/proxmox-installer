# shellcheck shell=bash
# Configuration phases for Proxmox post-install
# Broken out for maintainability and testability

# PHASE 1: Base Configuration (sequential - dependencies)
# Must run first - sets up admin user and base system
_phase_base_configuration() {
  make_templates || {
    log_error "make_templates failed"
    return 1
  }
  configure_admin_user || {
    log_error "configure_admin_user failed"
    return 1
  }
  configure_base_system || {
    log_error "configure_base_system failed"
    return 1
  }
  configure_shell || { log_warn "configure_shell failed"; }
  configure_system_services || { log_warn "configure_system_services failed"; }
}

# PHASE 2: Storage Configuration (sequential - ZFS dependencies)
_phase_storage_configuration() {
  configure_lvm_storage || { log_warn "configure_lvm_storage failed"; }
  configure_zfs_arc || { log_warn "configure_zfs_arc failed"; }
  configure_zfs_pool || {
    log_error "configure_zfs_pool failed"
    return 1
  }
  configure_zfs_cachefile || { log_warn "configure_zfs_cachefile failed"; }
  configure_zfs_scrub || { log_warn "configure_zfs_scrub failed"; }

  # Update initramfs to include ZFS cachefile changes (prevents "cachefile import failed" on boot)
  remote_run "Updating initramfs" "update-initramfs -u -k all" || log_warn "update-initramfs failed"
}

# PHASE 3: Security Configuration (parallel after batch install)
_phase_security_configuration() {
  # Batch install security & optional packages first
  batch_install_packages

  # Tailscale (needs package installed, needed for firewall rules)
  configure_tailscale

  # Firewall next (depends on tailscale for rule generation)
  configure_firewall

  # Parallel security configuration - failures are fatal
  if ! run_parallel_group "Configuring security" "Security features configured" \
    configure_apparmor \
    configure_fail2ban \
    configure_auditd \
    configure_aide \
    configure_chkrootkit \
    configure_lynis \
    configure_needrestart; then
    log_error "Security configuration failed - aborting installation"
    print_error "Security hardening failed. Check $LOG_FILE for details."
    return 1
  fi
}

# PHASE 4: Monitoring & Tools (parallel where possible)
_phase_monitoring_tools() {
  # Special installers (non-apt) - run in background with proper error tracking
  # NOTE: Must call directly (not via $()) to keep process as child of main shell
  local netdata_pid yazi_pid
  start_async_feature "netdata" "INSTALL_NETDATA"
  netdata_pid="$REPLY"
  start_async_feature "yazi" "INSTALL_YAZI"
  yazi_pid="$REPLY"

  # Parallel config for apt-installed tools (packages already installed by batch)
  run_parallel_group "Configuring tools" "Tools configured" \
    configure_promtail \
    configure_vnstat \
    configure_ringbuffer \
    configure_nvim \
    configure_postfix

  # Wait for special installers and check results
  wait_async_feature "netdata" "$netdata_pid"
  wait_async_feature "yazi" "$yazi_pid"
}

# PHASE 5: SSL & API Configuration
_phase_ssl_api() {
  configure_ssl_certificate
  if [[ $INSTALL_API_TOKEN == "yes" ]]; then
    run_with_progress "Creating API token" "API token created" create_api_token
  fi
}

# PHASE 6: Validation & Finalization
_phase_finalization() {
  # Deploy SSH hardening config BEFORE validation (so validation can verify it)
  deploy_ssh_hardening_config || {
    log_error "deploy_ssh_hardening_config failed"
    return 1
  }

  # Validate installation (SSH config file now has hardened settings)
  # Non-fatal: continue even if validation has warnings
  validate_installation || { log_warn "validate_installation reported issues"; }

  # Configure EFI fallback boot path (required for QEMU installs without NVRAM persistence)
  # Must run BEFORE cleanup which unmounts /boot/efi
  configure_efi_fallback_boot || { log_warn "configure_efi_fallback_boot failed"; }

  # Clean up installation logs for fresh first boot
  cleanup_installation_logs || { log_warn "cleanup_installation_logs failed"; }

  # Restart SSH as the LAST operation - after this, password auth is disabled
  restart_ssh_service || { log_warn "restart_ssh_service failed"; }

  # Power off VM - SSH no longer available, use QEMU ACPI shutdown
  finalize_vm || { log_warn "finalize_vm did not complete cleanly"; }
}
