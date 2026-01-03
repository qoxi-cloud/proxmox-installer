# shellcheck shell=bash
# Configure LVM storage for ext4 boot mode

# Expands LVM root to use all disk space (ext4 boot mode only).
# Removes local-lvm data LV and extends root LV to 100% free.
_config_expand_lvm_root() {
  log_info "Expanding LVM root to use all disk space"

  # shellcheck disable=SC2016
  if ! remote_run "Expanding LVM root filesystem" '
    set -e
    if ! vgs pve &>/dev/null; then
      echo "No pve VG found - not LVM install"
      exit 0
    fi
    if pvesm status local-lvm &>/dev/null; then
      pvesm remove local-lvm || true
      echo "Removed local-lvm storage"
    fi
    if lvs pve/data &>/dev/null; then
      lvremove -f /dev/pve/data
      echo "Removed data LV"
    fi
    free_extents=$(vgs --noheadings -o vg_free_count pve 2>/dev/null | xargs)
    if [[ "$free_extents" -gt 0 ]]; then
      lvextend -l +100%FREE /dev/pve/root
      resize2fs /dev/mapper/pve-root
      echo "Extended root LV to use all disk space"
    else
      echo "No free space in VG - root already uses all space"
    fi
    pvesm set local --content iso,vztmpl,backup,snippets,images,rootdir 2>/dev/null || true
  ' "LVM root filesystem expanded"; then
    log_warn "LVM expansion had issues, continuing"
  fi
  return 0
}

# Public wrapper - expands LVM root to use all disk space.
# Only runs in ext4 boot mode (BOOT_DISK set).
configure_lvm_storage() {
  [[ -z $BOOT_DISK ]] && return 0
  _config_expand_lvm_root
  parallel_mark_configured "LVM root expanded"
}
