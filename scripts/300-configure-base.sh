# shellcheck shell=bash
# Base system configuration via SSH

# Copy config files to remote (hosts, interfaces, sysctl, sources, resolv, journald, pveproxy)
_copy_config_files() {
  # Create journald config directory if it doesn't exist
  remote_exec "mkdir -p /etc/systemd/journald.conf.d" || return 1

  run_batch_copies \
    "templates/hosts:/etc/hosts" \
    "templates/interfaces:/etc/network/interfaces" \
    "templates/99-proxmox.conf:/etc/sysctl.d/99-proxmox.conf" \
    "templates/debian.sources:/etc/apt/sources.list.d/debian.sources" \
    "templates/proxmox.sources:/etc/apt/sources.list.d/proxmox.sources" \
    "templates/resolv.conf:/etc/resolv.conf" \
    "templates/journald.conf:/etc/systemd/journald.conf.d/00-proxmox.conf"
}

# Apply basic system settings (backup sources, set hostname, disable unused services)
_apply_basic_settings() {
  remote_exec "[ -f /etc/apt/sources.list ] && mv /etc/apt/sources.list /etc/apt/sources.list.bak" || return 1
  remote_exec "echo '$PVE_HOSTNAME' > /etc/hostname" || return 1
  # Disable NFS-related services (not needed on typical Proxmox install)
  # rpcbind: NFS RPC portmapper
  # nfs-blkmap: pNFS block layout mapper (causes "open pipe file failed" errors)
  remote_exec "systemctl disable --now rpcbind rpcbind.socket nfs-blkmap.service 2>/dev/null" || {
    log_warn "Failed to disable rpcbind/nfs-blkmap"
  }
  # Mask nfs-blkmap to prevent it from starting on boot
  remote_exec "systemctl mask nfs-blkmap.service 2>/dev/null" || true
}

# Main base system configuration implementation
_config_base_system() {
  # Copy template files to VM (parallel for better performance)
  run_with_progress "Copying configuration files" "Configuration files copied" _copy_config_files

  # Apply sysctl settings to running kernel
  run_with_progress "Applying sysctl settings" "Sysctl settings applied" remote_exec "sysctl --system"

  # Basic system configuration
  run_with_progress "Applying basic system settings" "Basic system settings applied" _apply_basic_settings

  # Configure Proxmox repository
  log_debug "configure_base_system: PVE_REPO_TYPE=${PVE_REPO_TYPE:-no-subscription}"
  if [[ ${PVE_REPO_TYPE:-no-subscription} == "enterprise" ]]; then
    log_info "configure_base_system: configuring enterprise repository"
    # Enterprise: disable default no-subscription repo (template already has enterprise)
    # shellcheck disable=SC2016 # Single quotes intentional - executed on remote system
    remote_run "Configuring enterprise repository" '
            for repo_file in /etc/apt/sources.list.d/*.list /etc/apt/sources.list.d/*.sources; do
                [[ -f "$repo_file" ]] || continue
                if grep -q "pve-no-subscription\|pvetest" "$repo_file" 2>/dev/null; then
                    mv "$repo_file" "${repo_file}.disabled"
                fi
            done
        ' "Enterprise repository configured"

    # Register subscription key if provided
    if [[ -n $PVE_SUBSCRIPTION_KEY ]]; then
      log_info "configure_base_system: registering subscription key"
      remote_run "Registering subscription key" \
        "pvesubscription set '${PVE_SUBSCRIPTION_KEY}' 2>/dev/null || true" \
        "Subscription key registered"
    fi
  else
    # No-subscription or test: disable enterprise repo
    log_info "configure_base_system: configuring ${PVE_REPO_TYPE:-no-subscription} repository"
    # shellcheck disable=SC2016 # Single quotes intentional - executed on remote system
    remote_run "Configuring ${PVE_REPO_TYPE:-no-subscription} repository" '
            for repo_file in /etc/apt/sources.list.d/*.list /etc/apt/sources.list.d/*.sources; do
                [[ -f "$repo_file" ]] || continue
                if grep -q "enterprise.proxmox.com" "$repo_file" 2>/dev/null; then
                    mv "$repo_file" "${repo_file}.disabled"
                fi
            done

            if [[ -f /etc/apt/sources.list ]] && grep -q "enterprise.proxmox.com" /etc/apt/sources.list 2>/dev/null; then
                sed -i "s|^deb.*enterprise.proxmox.com|# &|g" /etc/apt/sources.list
            fi
        ' "Repository configured"
  fi

  # Install all base system packages in one batch (includes dist-upgrade)
  install_base_packages

  # Configure UTF-8 locales using template files
  # Generate the user's selected locale plus common fallbacks
  # Note: locales package already installed via install_base_packages()
  local locale_name="${LOCALE%%.UTF-8}" # Remove .UTF-8 suffix for sed pattern
  # Enable user's selected locale + en_US as fallback (many tools expect it)
  remote_run "Configuring UTF-8 locales" "
        set -e
        sed -i 's/# ${locale_name}.UTF-8/${locale_name}.UTF-8/' /etc/locale.gen
        sed -i 's/# en_US.UTF-8/en_US.UTF-8/' /etc/locale.gen
        locale-gen
        update-locale LANG=${LOCALE} LC_ALL=${LOCALE}
    " "UTF-8 locales configured"

  # Copy locale template files
  run_with_progress "Installing locale configuration files" "Locale files installed" _install_locale_files

  # Configure fastfetch to run on shell login
  run_with_progress "Configuring fastfetch" "Fastfetch configured" _configure_fastfetch

  # Configure bat with Visual Studio Dark+ theme
  # Note: Debian packages bat as 'batcat', create symlink for 'bat' command
  run_with_progress "Configuring bat" "Bat configured" _configure_bat
}

# Configure base system via SSH into QEMU VM
configure_base_system() {
  _config_base_system
}
