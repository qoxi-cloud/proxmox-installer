# shellcheck shell=bash
# Configuration phases for Proxmox post-install
# Broken out for maintainability and testability

# PHASE 1: Base Configuration (sequential then parallel)
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

  # Shell and system services have no inter-dependencies - run in parallel
  # configure_shell: Oh-My-Zsh, plugins (operates on user home directory)
  # configure_system_services: chrony, governors, limits (operates on system configs)
  run_parallel_group "Configuring shell & services" "Shell & services configured" \
    configure_shell \
    configure_system_services
}

# PHASE 2: Storage Configuration (LVM parallel with ZFS arc, then sequential ZFS chain)
_phase_storage_configuration() {
  # LVM and ZFS arc can run in parallel (no dependencies, non-critical)
  # run_parallel_group properly suppresses progress output (>/dev/null) - no wasted calls
  # log_info inside functions still writes to $LOG_FILE
  if [[ -n $BOOT_DISK ]]; then
    # LVM operates on boot partition, arc sets kernel params - no shared resources
    run_parallel_group "Configuring LVM & ZFS memory" "LVM & ZFS memory configured" \
      configure_lvm_storage \
      configure_zfs_arc
  else
    # Subshell catches exit 1 from remote_run, making failure non-fatal
    # Note: remote_run calls exit 1, not return 1, so || pattern needs subshell
    (configure_zfs_arc) || log_warn "configure_zfs_arc failed"
  fi

  # ZFS pool is critical - must succeed for storage to work
  configure_zfs_pool || {
    log_error "configure_zfs_pool failed"
    return 1
  }

  # These depend on pool existing (must run after pool)
  # Subshell catches exit 1 from remote_run, making failures non-fatal
  (configure_zfs_cachefile) || log_warn "configure_zfs_cachefile failed"
  (configure_zfs_scrub) || log_warn "configure_zfs_scrub failed"

  # Update initramfs to include ZFS cachefile changes (prevents "cachefile import failed" on boot)
  (remote_run "Updating initramfs" "update-initramfs -u -k all") || log_warn "update-initramfs failed"
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

# PHASE 5: SSL & API Configuration (parallel - independent operations)
_phase_ssl_api() {
  # SSL certificate and API token creation are independent - run in parallel
  # Failures logged but not fatal (user can configure manually post-install)
  if ! run_parallel_group "Configuring SSL & API" "SSL & API configured" \
    configure_ssl \
    configure_api_token; then
    log_warn "SSL/API configuration had failures - check $LOG_FILE for details"
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
  # Subshell catches exit 1 from remote_run, making failure non-fatal
  (configure_efi_fallback_boot) || log_warn "configure_efi_fallback_boot failed"

  # Clean up installation logs for fresh first boot
  (cleanup_installation_logs) || log_warn "cleanup_installation_logs failed"

  # Restart SSH as the LAST operation - after this, password auth is disabled
  restart_ssh_service || { log_warn "restart_ssh_service failed"; }

  # Power off VM - SSH no longer available, use QEMU ACPI shutdown
  finalize_vm || { log_warn "finalize_vm did not complete cleanly"; }
}
