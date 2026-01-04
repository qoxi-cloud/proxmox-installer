# shellcheck shell=bash
# Main orchestrator - installation flow

# Main execution flow
log_info "==================== Qoxi Automated Installer v${VERSION} ===================="
log_debug "QEMU_RAM_OVERRIDE=$QEMU_RAM_OVERRIDE QEMU_CORES_OVERRIDE=$QEMU_CORES_OVERRIDE"
log_debug "PVE_REPO_TYPE=${PVE_REPO_TYPE:-no-subscription} SSL_TYPE=${SSL_TYPE:-self-signed}"

metrics_start
log_info "Step: collect_system_info"
show_banner_animated_start 0.1

# Create temporary file for sharing variables between processes
SYSTEM_INFO_CACHE=$(mktemp) || {
  log_error "Failed to create temp file"
  exit 1
}
register_temp_file "$SYSTEM_INFO_CACHE"

# Run system checks and prefetch Proxmox ISO info in background job
{
  collect_system_info
  log_info "Step: prefetch_proxmox_iso_info"
  prefetch_proxmox_iso_info

  # Export system/network/ISO variables to temp file (atomic write to prevent partial data)
  declare -p | grep -E "^declare -[^ ]* (PREFLIGHT_|DRIVE_|INTERFACE_|CURRENT_INTERFACE|PREDICTABLE_NAME|DEFAULT_INTERFACE|AVAILABLE_|MAC_ADDRESS|MAIN_IPV|IPV6_|FIRST_IPV6_|_ISO_|_CHECKSUM_|WIZ_TIMEZONES|WIZ_COUNTRIES|TZ_TO_COUNTRY|DETECTED_POOLS)" >"${SYSTEM_INFO_CACHE}.tmp" \
    && mv "${SYSTEM_INFO_CACHE}.tmp" "$SYSTEM_INFO_CACHE"
} >/dev/null 2>&1 &

# Wait for background tasks to complete
wait "$!"

# Reset command caches (new packages installed in subshell)
cmd_cache_clear

# Verify required packages are available
_missing_cmds=()
for _cmd in gum jq aria2c curl; do
  command -v "$_cmd" &>/dev/null || _missing_cmds+=("$_cmd")
done
if [[ ${#_missing_cmds[@]} -gt 0 ]]; then
  log_error "Required packages not installed: ${_missing_cmds[*]}"
  print_error "Required packages not installed: ${_missing_cmds[*]}"
  exit 1
fi
unset _missing_cmds _cmd

# Stop animation and show static banner with system info
show_banner_animated_stop

# Import variables from background job
if [[ -s $SYSTEM_INFO_CACHE ]]; then
  # Validate file contains only declare statements (defense in depth)
  if grep -qvE '^declare -' "$SYSTEM_INFO_CACHE"; then
    log_error "SYSTEM_INFO_CACHE contains invalid content, skipping import"
  else
    # shellcheck disable=SC1090
    source "$SYSTEM_INFO_CACHE"
  fi
  rm -f "$SYSTEM_INFO_CACHE"
fi

log_info "Step: show_system_status"
show_system_status
log_metric "system_info"

# Show interactive configuration editor (replaces get_system_inputs)
log_info "Step: show_gum_config_editor"
show_gum_config_editor
log_metric "config_wizard"

# Start live installation display
start_live_installation

log_info "Step: prepare_packages"
prepare_packages
log_metric "packages"

# Download ISO and generate TOML in parallel (no shared resources)
log_info "Step: prepare_iso_and_toml (parallel)"
if ! run_parallel_group "Preparing ISO & TOML" "ISO & TOML ready" \
  _parallel_download_iso \
  _parallel_make_toml; then
  log_error "ISO/TOML preparation failed - check $LOG_FILE for details"
  exit 1
fi
log_metric "iso_download"

log_info "Step: make_autoinstall_iso"
make_autoinstall_iso
log_metric "autoinstall_prep"

log_info "Step: wipe_installation_disks"
run_with_progress "Wiping disks" "Disks wiped" wipe_installation_disks
log_metric "disk_wipe"

log_info "Step: install_proxmox"
install_proxmox
log_metric "proxmox_install"

log_info "Step: boot_proxmox_with_port_forwarding"
boot_proxmox_with_port_forwarding || {
  log_error "Failed to boot Proxmox with port forwarding"
  exit 1
}
log_metric "qemu_boot"

log_info "Step: configure_proxmox_via_ssh"
configure_proxmox_via_ssh || {
  log_error "configure_proxmox_via_ssh failed"
  exit 1
}
log_metric "system_config"

# Log final metrics
metrics_finish

# Mark installation as completed (disables error handler message)
INSTALL_COMPLETED=true

# Reboot to the main OS
log_info "Step: reboot_to_main_os"
reboot_to_main_os
