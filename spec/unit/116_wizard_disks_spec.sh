# shellcheck shell=bash
# shellcheck disable=SC2034,SC2154
# =============================================================================
# Tests for 116-wizard-disks.sh
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
# Disk wizard mocks
# =============================================================================

MOCK_WIZ_CHOOSE_RESULT=""
MOCK_WIZ_CHOOSE_EXIT=0
MOCK_WIZ_CHOOSE_MULTI_RESULT=""
MOCK_WIZ_CHOOSE_MULTI_EXIT=0
MOCK_READ_KEY=""

reset_disk_mocks() {
  MOCK_WIZ_CHOOSE_RESULT=""
  MOCK_WIZ_CHOOSE_EXIT=0
  MOCK_WIZ_CHOOSE_MULTI_RESULT=""
  MOCK_WIZ_CHOOSE_MULTI_EXIT=0
  MOCK_READ_KEY=""

  # Reset globals
  BOOT_DISK=""
  ZFS_RAID=""
  ZFS_POOL_DISKS=()
  DRIVES=()
  DRIVE_NAMES=()
  DRIVE_SIZES=()
  DRIVE_MODELS=()
  DRIVE_COUNT=0
}

setup_test_drives() {
  local count="${1:-2}"
  DRIVES=()
  DRIVE_NAMES=()
  DRIVE_SIZES=()
  DRIVE_MODELS=()

  for i in $(seq 1 "$count"); do
    local idx=$((i - 1))
    DRIVES+=("/dev/nvme${idx}n1")
    DRIVE_NAMES+=("nvme${idx}n1")
    DRIVE_SIZES+=("500GB")
    DRIVE_MODELS+=("Samsung SSD 980")
  done
  DRIVE_COUNT=$count
}

# Mock wizard UI functions
_wiz_start_edit() { :; }
_wiz_description() { :; }
_show_input_footer() { :; }
_wiz_error() { :; }
_wiz_dim() { :; }
_wiz_blank_line() { :; }
show_validation_error() { :; }

_wiz_choose() {
  if [[ $MOCK_WIZ_CHOOSE_EXIT -ne 0 ]]; then
    return $MOCK_WIZ_CHOOSE_EXIT
  fi
  printf '%s\n' "$MOCK_WIZ_CHOOSE_RESULT"
}

_wiz_choose_multi() {
  if [[ $MOCK_WIZ_CHOOSE_MULTI_EXIT -ne 0 ]]; then
    return $MOCK_WIZ_CHOOSE_MULTI_EXIT
  fi
  printf '%s\n' "$MOCK_WIZ_CHOOSE_MULTI_RESULT"
}

# Mock read for key capture
read() {
  if [[ "$1" == "-r" && "$2" == "-n" ]]; then
    REPLY="$MOCK_READ_KEY"
    return 0
  fi
  # shellcheck disable=SC2162
  builtin read "$@"
}

Describe "116-wizard-disks.sh"
  Include "$SCRIPTS_DIR/116-wizard-disks.sh"

  # ===========================================================================
  # _update_zfs_mode_options()
  # ===========================================================================
  Describe "_update_zfs_mode_options()"
    BeforeEach 'reset_disk_mocks'

    # Note: "keeps" tests return status 1 (bash case statement quirk - returns
    # exit status of last [[ ]] test which is 1 when condition not met)

    Describe "single disk mode"
      It "keeps single mode with 1 disk"
        ZFS_POOL_DISKS=("/dev/nvme0n1")
        ZFS_RAID="single"
        When call _update_zfs_mode_options
        The status should be failure
        The variable ZFS_RAID should equal "single"
      End

      It "clears single mode with 2+ disks"
        ZFS_POOL_DISKS=("/dev/nvme0n1" "/dev/nvme1n1")
        ZFS_RAID="single"
        When call _update_zfs_mode_options
        The variable ZFS_RAID should equal ""
      End
    End

    Describe "raid0/raid1 modes"
      It "keeps raid0 with 2 disks"
        ZFS_POOL_DISKS=("/dev/nvme0n1" "/dev/nvme1n1")
        ZFS_RAID="raid0"
        When call _update_zfs_mode_options
        The status should be failure
        The variable ZFS_RAID should equal "raid0"
      End

      It "keeps raid1 with 2 disks"
        ZFS_POOL_DISKS=("/dev/nvme0n1" "/dev/nvme1n1")
        ZFS_RAID="raid1"
        When call _update_zfs_mode_options
        The status should be failure
        The variable ZFS_RAID should equal "raid1"
      End

      It "clears raid0 with 1 disk"
        ZFS_POOL_DISKS=("/dev/nvme0n1")
        ZFS_RAID="raid0"
        When call _update_zfs_mode_options
        The variable ZFS_RAID should equal ""
      End

      It "clears raid1 with 1 disk"
        ZFS_POOL_DISKS=("/dev/nvme0n1")
        ZFS_RAID="raid1"
        When call _update_zfs_mode_options
        The variable ZFS_RAID should equal ""
      End
    End

    Describe "raid5/raidz1 modes"
      It "keeps raidz1 with 3 disks"
        ZFS_POOL_DISKS=("/dev/nvme0n1" "/dev/nvme1n1" "/dev/nvme2n1")
        ZFS_RAID="raidz1"
        When call _update_zfs_mode_options
        The status should be failure
        The variable ZFS_RAID should equal "raidz1"
      End

      It "keeps raid5 with 3 disks"
        ZFS_POOL_DISKS=("/dev/nvme0n1" "/dev/nvme1n1" "/dev/nvme2n1")
        ZFS_RAID="raid5"
        When call _update_zfs_mode_options
        The status should be failure
        The variable ZFS_RAID should equal "raid5"
      End

      It "clears raidz1 with 2 disks"
        ZFS_POOL_DISKS=("/dev/nvme0n1" "/dev/nvme1n1")
        ZFS_RAID="raidz1"
        When call _update_zfs_mode_options
        The variable ZFS_RAID should equal ""
      End
    End

    Describe "raid10/raidz2 modes"
      It "keeps raid10 with 4 disks"
        ZFS_POOL_DISKS=("/dev/nvme0n1" "/dev/nvme1n1" "/dev/nvme2n1" "/dev/nvme3n1")
        ZFS_RAID="raid10"
        When call _update_zfs_mode_options
        The status should be failure
        The variable ZFS_RAID should equal "raid10"
      End

      It "keeps raidz2 with 4 disks"
        ZFS_POOL_DISKS=("/dev/nvme0n1" "/dev/nvme1n1" "/dev/nvme2n1" "/dev/nvme3n1")
        ZFS_RAID="raidz2"
        When call _update_zfs_mode_options
        The status should be failure
        The variable ZFS_RAID should equal "raidz2"
      End

      It "clears raid10 with 3 disks"
        ZFS_POOL_DISKS=("/dev/nvme0n1" "/dev/nvme1n1" "/dev/nvme2n1")
        ZFS_RAID="raid10"
        When call _update_zfs_mode_options
        The variable ZFS_RAID should equal ""
      End

      It "clears raidz2 with 3 disks"
        ZFS_POOL_DISKS=("/dev/nvme0n1" "/dev/nvme1n1" "/dev/nvme2n1")
        ZFS_RAID="raidz2"
        When call _update_zfs_mode_options
        The variable ZFS_RAID should equal ""
      End
    End

    Describe "raidz3 mode"
      It "keeps raidz3 with 5 disks"
        ZFS_POOL_DISKS=("/dev/nvme0n1" "/dev/nvme1n1" "/dev/nvme2n1" "/dev/nvme3n1" "/dev/nvme4n1")
        ZFS_RAID="raidz3"
        When call _update_zfs_mode_options
        The status should be failure
        The variable ZFS_RAID should equal "raidz3"
      End

      It "clears raidz3 with 4 disks"
        ZFS_POOL_DISKS=("/dev/nvme0n1" "/dev/nvme1n1" "/dev/nvme2n1" "/dev/nvme3n1")
        ZFS_RAID="raidz3"
        When call _update_zfs_mode_options
        The variable ZFS_RAID should equal ""
      End
    End

    Describe "empty pool"
      It "handles empty pool disks"
        ZFS_POOL_DISKS=()
        ZFS_RAID="raid1"
        When call _update_zfs_mode_options
        The variable ZFS_RAID should equal ""
      End
    End
  End

  # ===========================================================================
  # _rebuild_pool_disks()
  # ===========================================================================
  Describe "_rebuild_pool_disks()"
    BeforeEach 'reset_disk_mocks'

    Describe "without boot disk"
      It "includes all drives in pool"
        setup_test_drives 3
        BOOT_DISK=""
        When call _rebuild_pool_disks
        The status should be success
        The variable "ZFS_POOL_DISKS[0]" should equal "/dev/nvme0n1"
        The variable "ZFS_POOL_DISKS[1]" should equal "/dev/nvme1n1"
        The variable "ZFS_POOL_DISKS[2]" should equal "/dev/nvme2n1"
      End

      It "handles single drive"
        setup_test_drives 1
        BOOT_DISK=""
        When call _rebuild_pool_disks
        The status should be success
        The variable "ZFS_POOL_DISKS[0]" should equal "/dev/nvme0n1"
      End
    End

    Describe "with boot disk"
      It "excludes boot disk from pool"
        setup_test_drives 3
        BOOT_DISK="/dev/nvme0n1"
        When call _rebuild_pool_disks
        The status should be success
        The variable "ZFS_POOL_DISKS[0]" should equal "/dev/nvme1n1"
        The variable "ZFS_POOL_DISKS[1]" should equal "/dev/nvme2n1"
      End

      It "excludes middle disk when selected as boot"
        setup_test_drives 3
        BOOT_DISK="/dev/nvme1n1"
        When call _rebuild_pool_disks
        The status should be success
        The variable "ZFS_POOL_DISKS[0]" should equal "/dev/nvme0n1"
        The variable "ZFS_POOL_DISKS[1]" should equal "/dev/nvme2n1"
      End

      It "leaves empty pool when boot is only disk"
        setup_test_drives 1
        BOOT_DISK="/dev/nvme0n1"
        When call _rebuild_pool_disks
        The status should be success
        The value "${#ZFS_POOL_DISKS[@]}" should equal 0
      End
    End

    Describe "ZFS mode update"
      It "clears incompatible raid mode after rebuild"
        setup_test_drives 2
        BOOT_DISK="/dev/nvme0n1"
        ZFS_RAID="raid1"
        When call _rebuild_pool_disks
        The variable ZFS_RAID should equal ""
      End

      It "keeps compatible raid mode after rebuild"
        setup_test_drives 3
        BOOT_DISK="/dev/nvme0n1"
        ZFS_RAID="raid1"
        When call _rebuild_pool_disks
        The status should be failure
        The variable ZFS_RAID should equal "raid1"
      End
    End
  End

  # ===========================================================================
  # _edit_boot_disk()
  # ===========================================================================
  Describe "_edit_boot_disk()"
    BeforeEach 'reset_disk_mocks'

    Describe "selecting 'None'"
      It "clears BOOT_DISK when selecting 'None'"
        setup_test_drives 2
        BOOT_DISK="/dev/nvme0n1"
        MOCK_WIZ_CHOOSE_RESULT="None (all in pool)"
        When call _edit_boot_disk
        The status should be success
        The variable BOOT_DISK should equal ""
      End

      It "rebuilds pool disks to include all drives"
        setup_test_drives 2
        BOOT_DISK="/dev/nvme0n1"
        ZFS_POOL_DISKS=("/dev/nvme1n1")
        MOCK_WIZ_CHOOSE_RESULT="None (all in pool)"
        When call _edit_boot_disk
        The status should be success
        The value "${#ZFS_POOL_DISKS[@]}" should equal 2
      End
    End

    Describe "selecting a disk"
      It "sets BOOT_DISK to selected disk"
        setup_test_drives 3
        MOCK_WIZ_CHOOSE_RESULT="nvme0n1 - 500GB  Samsung SSD 980"
        When call _edit_boot_disk
        The status should be success
        The variable BOOT_DISK should equal "/dev/nvme0n1"
      End

      It "excludes selected disk from pool"
        setup_test_drives 3
        MOCK_WIZ_CHOOSE_RESULT="nvme1n1 - 500GB  Samsung SSD 980"
        When call _edit_boot_disk
        The status should be success
        The variable "ZFS_POOL_DISKS[0]" should equal "/dev/nvme0n1"
        The variable "ZFS_POOL_DISKS[1]" should equal "/dev/nvme2n1"
      End
    End

    Describe "validation - empty pool after selection"
      It "restores previous boot disk if pool becomes empty"
        setup_test_drives 1
        BOOT_DISK=""
        ZFS_POOL_DISKS=("/dev/nvme0n1")
        MOCK_WIZ_CHOOSE_RESULT="nvme0n1 - 500GB  Samsung SSD 980"
        MOCK_READ_KEY="x"
        When call _edit_boot_disk
        The status should be success
        The variable BOOT_DISK should equal ""
      End

      It "keeps pool intact when boot selection fails validation"
        setup_test_drives 1
        BOOT_DISK=""
        ZFS_POOL_DISKS=("/dev/nvme0n1")
        MOCK_WIZ_CHOOSE_RESULT="nvme0n1 - 500GB  Samsung SSD 980"
        MOCK_READ_KEY="x"
        When call _edit_boot_disk
        The status should be success
        The value "${#ZFS_POOL_DISKS[@]}" should equal 1
      End
    End

    Describe "user cancellation"
      It "does not update BOOT_DISK when user cancels"
        setup_test_drives 2
        BOOT_DISK="/dev/nvme0n1"
        MOCK_WIZ_CHOOSE_EXIT=1
        When call _edit_boot_disk
        The status should be success
        The variable BOOT_DISK should equal "/dev/nvme0n1"
      End

      It "handles empty selection result"
        setup_test_drives 2
        BOOT_DISK="/dev/nvme0n1"
        MOCK_WIZ_CHOOSE_RESULT=""
        When call _edit_boot_disk
        The status should be success
        The variable BOOT_DISK should equal "/dev/nvme0n1"
      End
    End
  End

  # ===========================================================================
  # _edit_pool_disks()
  # ===========================================================================
  Describe "_edit_pool_disks()"
    BeforeEach 'reset_disk_mocks'

    Describe "disk selection"
      It "updates pool with selected disks"
        setup_test_drives 3
        MOCK_WIZ_CHOOSE_MULTI_RESULT="nvme0n1 - 500GB  Samsung SSD 980
nvme2n1 - 500GB  Samsung SSD 980"
        When call _edit_pool_disks
        The status should be success
        The variable "ZFS_POOL_DISKS[0]" should equal "/dev/nvme0n1"
        The variable "ZFS_POOL_DISKS[1]" should equal "/dev/nvme2n1"
      End

      It "selects single disk"
        setup_test_drives 3
        MOCK_WIZ_CHOOSE_MULTI_RESULT="nvme1n1 - 500GB  Samsung SSD 980"
        When call _edit_pool_disks
        The status should be success
        The value "${#ZFS_POOL_DISKS[@]}" should equal 1
        The variable "ZFS_POOL_DISKS[0]" should equal "/dev/nvme1n1"
      End

      It "selects all disks"
        setup_test_drives 4
        MOCK_WIZ_CHOOSE_MULTI_RESULT="nvme0n1 - 500GB  Samsung SSD 980
nvme1n1 - 500GB  Samsung SSD 980
nvme2n1 - 500GB  Samsung SSD 980
nvme3n1 - 500GB  Samsung SSD 980"
        When call _edit_pool_disks
        The status should be success
        The value "${#ZFS_POOL_DISKS[@]}" should equal 4
      End
    End

    Describe "with boot disk set"
      It "excludes boot disk from available options"
        setup_test_drives 3
        BOOT_DISK="/dev/nvme0n1"
        MOCK_WIZ_CHOOSE_MULTI_RESULT="nvme1n1 - 500GB  Samsung SSD 980
nvme2n1 - 500GB  Samsung SSD 980"
        When call _edit_pool_disks
        The status should be success
        The value "${#ZFS_POOL_DISKS[@]}" should equal 2
      End
    End

    Describe "user cancellation"
      It "keeps existing selection when user cancels (ESC)"
        setup_test_drives 3
        ZFS_POOL_DISKS=("/dev/nvme0n1" "/dev/nvme1n1")
        MOCK_WIZ_CHOOSE_MULTI_EXIT=1
        When call _edit_pool_disks
        The status should be success
        The variable "ZFS_POOL_DISKS[0]" should equal "/dev/nvme0n1"
        The variable "ZFS_POOL_DISKS[1]" should equal "/dev/nvme1n1"
      End

      It "treats empty selection with existing pool as cancel"
        setup_test_drives 3
        ZFS_POOL_DISKS=("/dev/nvme0n1" "/dev/nvme2n1")
        MOCK_WIZ_CHOOSE_MULTI_RESULT=""
        When call _edit_pool_disks
        The status should be success
        The variable "ZFS_POOL_DISKS[0]" should equal "/dev/nvme0n1"
        The variable "ZFS_POOL_DISKS[1]" should equal "/dev/nvme2n1"
      End
    End

    Describe "ZFS mode update"
      It "clears incompatible raid mode after selection"
        setup_test_drives 4
        ZFS_RAID="raid10"
        MOCK_WIZ_CHOOSE_MULTI_RESULT="nvme0n1 - 500GB  Samsung SSD 980
nvme1n1 - 500GB  Samsung SSD 980"
        When call _edit_pool_disks
        The status should be success
        The variable ZFS_RAID should equal ""
      End

      It "keeps compatible raid mode after selection"
        setup_test_drives 4
        ZFS_RAID="raid1"
        MOCK_WIZ_CHOOSE_MULTI_RESULT="nvme0n1 - 500GB  Samsung SSD 980
nvme1n1 - 500GB  Samsung SSD 980
nvme2n1 - 500GB  Samsung SSD 980"
        When call _edit_pool_disks
        The status should be success
        The variable ZFS_RAID should equal "raid1"
      End
    End
  End
End

