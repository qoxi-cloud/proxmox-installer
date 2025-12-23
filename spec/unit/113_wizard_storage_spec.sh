# shellcheck shell=bash
# shellcheck disable=SC2034,SC2154
# =============================================================================
# Tests for 113-wizard-storage.sh
# =============================================================================
# Note: SC2034 disabled - variables used by ShellSpec assertions
#       SC2154 disabled - variables set by mocks

%const SCRIPTS_DIR: "${SHELLSPEC_PROJECT_ROOT}/scripts"
%const SUPPORT_DIR: "${SHELLSPEC_PROJECT_ROOT}/spec/support"

# Load shared mocks
eval "$(cat "$SUPPORT_DIR/colors.sh")"
eval "$(cat "$SUPPORT_DIR/core_mocks.sh")"
eval "$(cat "$SUPPORT_DIR/ui_mocks.sh")"

# =============================================================================
# Storage wizard mocks
# =============================================================================

MOCK_WIZ_CHOOSE_RESULT=""
MOCK_WIZ_CHOOSE_EXIT=0

reset_storage_mocks() {
  MOCK_WIZ_CHOOSE_RESULT=""
  MOCK_WIZ_CHOOSE_EXIT=0
  ZFS_RAID=""
  ZFS_ARC_MODE=""
  ZFS_POOL_DISKS=()
}

# Mock wizard UI functions
_wiz_start_edit() { :; }
_wiz_description() { :; }
_show_input_footer() { :; }

_wiz_choose() {
  if [[ $MOCK_WIZ_CHOOSE_EXIT -ne 0 ]]; then
    return $MOCK_WIZ_CHOOSE_EXIT
  fi
  printf '%s\n' "$MOCK_WIZ_CHOOSE_RESULT"
}

# Global constant from 000-init.sh
WIZ_ZFS_ARC_MODES="VM-focused (4GB fixed)
Balanced (25-40% of RAM)
Storage-focused (50% of RAM)"

Describe "113-wizard-storage.sh"
  Include "$SCRIPTS_DIR/113-wizard-storage.sh"

  # ===========================================================================
  # _edit_zfs_mode()
  # ===========================================================================
  Describe "_edit_zfs_mode()"
    BeforeEach 'reset_storage_mocks'

    Describe "with single disk"
      It "sets ZFS_RAID to single when only one disk"
        ZFS_POOL_DISKS=("/dev/sda")
        MOCK_WIZ_CHOOSE_RESULT="Single disk"
        When call _edit_zfs_mode
        The status should be success
        The variable ZFS_RAID should equal "single"
      End
    End

    Describe "with 2 disks"
      It "sets ZFS_RAID to raid0 for striped"
        ZFS_POOL_DISKS=("/dev/sda" "/dev/sdb")
        MOCK_WIZ_CHOOSE_RESULT="RAID-0 (striped)"
        When call _edit_zfs_mode
        The status should be success
        The variable ZFS_RAID should equal "raid0"
      End

      It "sets ZFS_RAID to raid1 for mirror"
        ZFS_POOL_DISKS=("/dev/sda" "/dev/sdb")
        MOCK_WIZ_CHOOSE_RESULT="RAID-1 (mirror)"
        When call _edit_zfs_mode
        The status should be success
        The variable ZFS_RAID should equal "raid1"
      End
    End

    Describe "with 3 disks"
      It "sets ZFS_RAID to raidz1 for parity"
        ZFS_POOL_DISKS=("/dev/sda" "/dev/sdb" "/dev/sdc")
        MOCK_WIZ_CHOOSE_RESULT="RAID-Z1 (parity)"
        When call _edit_zfs_mode
        The status should be success
        The variable ZFS_RAID should equal "raidz1"
      End

      It "allows raid0 with 3 disks"
        ZFS_POOL_DISKS=("/dev/sda" "/dev/sdb" "/dev/sdc")
        MOCK_WIZ_CHOOSE_RESULT="RAID-0 (striped)"
        When call _edit_zfs_mode
        The status should be success
        The variable ZFS_RAID should equal "raid0"
      End

      It "allows raid1 with 3 disks"
        ZFS_POOL_DISKS=("/dev/sda" "/dev/sdb" "/dev/sdc")
        MOCK_WIZ_CHOOSE_RESULT="RAID-1 (mirror)"
        When call _edit_zfs_mode
        The status should be success
        The variable ZFS_RAID should equal "raid1"
      End
    End

    Describe "with 4 disks"
      It "sets ZFS_RAID to raidz2 for double parity"
        ZFS_POOL_DISKS=("/dev/sda" "/dev/sdb" "/dev/sdc" "/dev/sdd")
        MOCK_WIZ_CHOOSE_RESULT="RAID-Z2 (double parity)"
        When call _edit_zfs_mode
        The status should be success
        The variable ZFS_RAID should equal "raidz2"
      End

      It "sets ZFS_RAID to raid10 for striped mirrors"
        ZFS_POOL_DISKS=("/dev/sda" "/dev/sdb" "/dev/sdc" "/dev/sdd")
        MOCK_WIZ_CHOOSE_RESULT="RAID-10 (striped mirrors)"
        When call _edit_zfs_mode
        The status should be success
        The variable ZFS_RAID should equal "raid10"
      End

      It "allows raidz1 with 4 disks"
        ZFS_POOL_DISKS=("/dev/sda" "/dev/sdb" "/dev/sdc" "/dev/sdd")
        MOCK_WIZ_CHOOSE_RESULT="RAID-Z1 (parity)"
        When call _edit_zfs_mode
        The status should be success
        The variable ZFS_RAID should equal "raidz1"
      End
    End

    Describe "with 5+ disks"
      It "sets ZFS_RAID to raidz3 for triple parity"
        ZFS_POOL_DISKS=("/dev/sda" "/dev/sdb" "/dev/sdc" "/dev/sdd" "/dev/sde")
        MOCK_WIZ_CHOOSE_RESULT="RAID-Z3 (triple parity)"
        When call _edit_zfs_mode
        The status should be success
        The variable ZFS_RAID should equal "raidz3"
      End

      It "allows raid10 with 6 disks"
        ZFS_POOL_DISKS=("/dev/sda" "/dev/sdb" "/dev/sdc" "/dev/sdd" "/dev/sde" "/dev/sdf")
        MOCK_WIZ_CHOOSE_RESULT="RAID-10 (striped mirrors)"
        When call _edit_zfs_mode
        The status should be success
        The variable ZFS_RAID should equal "raid10"
      End

      It "allows raidz2 with 5 disks"
        ZFS_POOL_DISKS=("/dev/sda" "/dev/sdb" "/dev/sdc" "/dev/sdd" "/dev/sde")
        MOCK_WIZ_CHOOSE_RESULT="RAID-Z2 (double parity)"
        When call _edit_zfs_mode
        The status should be success
        The variable ZFS_RAID should equal "raidz2"
      End
    End

    Describe "user cancellation"
      It "does not update ZFS_RAID when user cancels"
        ZFS_POOL_DISKS=("/dev/sda" "/dev/sdb")
        ZFS_RAID="raid1"
        MOCK_WIZ_CHOOSE_EXIT=1
        When call _edit_zfs_mode
        The status should be success
        The variable ZFS_RAID should equal "raid1"
      End

      It "preserves existing RAID value on cancel"
        ZFS_POOL_DISKS=("/dev/sda" "/dev/sdb" "/dev/sdc")
        ZFS_RAID="raidz1"
        MOCK_WIZ_CHOOSE_EXIT=1
        When call _edit_zfs_mode
        The status should be success
        The variable ZFS_RAID should equal "raidz1"
      End
    End

    Describe "empty pool disks"
      It "handles empty pool disks array"
        ZFS_POOL_DISKS=()
        MOCK_WIZ_CHOOSE_EXIT=1
        When call _edit_zfs_mode
        The status should be success
        The variable ZFS_RAID should equal ""
      End
    End
  End

  # ===========================================================================
  # _edit_zfs_arc()
  # ===========================================================================
  Describe "_edit_zfs_arc()"
    BeforeEach 'reset_storage_mocks'

    Describe "ARC mode selection"
      It "sets ZFS_ARC_MODE to vm-focused"
        MOCK_WIZ_CHOOSE_RESULT="VM-focused (4GB fixed)"
        When call _edit_zfs_arc
        The status should be success
        The variable ZFS_ARC_MODE should equal "vm-focused"
      End

      It "sets ZFS_ARC_MODE to balanced"
        MOCK_WIZ_CHOOSE_RESULT="Balanced (25-40% of RAM)"
        When call _edit_zfs_arc
        The status should be success
        The variable ZFS_ARC_MODE should equal "balanced"
      End

      It "sets ZFS_ARC_MODE to storage-focused"
        MOCK_WIZ_CHOOSE_RESULT="Storage-focused (50% of RAM)"
        When call _edit_zfs_arc
        The status should be success
        The variable ZFS_ARC_MODE should equal "storage-focused"
      End
    End

    Describe "user cancellation"
      It "does not update ZFS_ARC_MODE when user cancels"
        ZFS_ARC_MODE="balanced"
        MOCK_WIZ_CHOOSE_EXIT=1
        When call _edit_zfs_arc
        The status should be success
        The variable ZFS_ARC_MODE should equal "balanced"
      End

      It "preserves existing ARC mode on cancel"
        ZFS_ARC_MODE="vm-focused"
        MOCK_WIZ_CHOOSE_EXIT=1
        When call _edit_zfs_arc
        The status should be success
        The variable ZFS_ARC_MODE should equal "vm-focused"
      End
    End

    Describe "initial state"
      It "handles empty initial ZFS_ARC_MODE"
        ZFS_ARC_MODE=""
        MOCK_WIZ_CHOOSE_RESULT="Balanced (25-40% of RAM)"
        When call _edit_zfs_arc
        The status should be success
        The variable ZFS_ARC_MODE should equal "balanced"
      End
    End
  End
End

