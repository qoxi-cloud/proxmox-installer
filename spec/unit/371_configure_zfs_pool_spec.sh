# shellcheck shell=bash
# shellcheck disable=SC2034
# =============================================================================
# Tests for 371-configure-zfs-pool.sh
# =============================================================================

%const SCRIPTS_DIR: "${SHELLSPEC_PROJECT_ROOT}/scripts"
%const SUPPORT_DIR: "${SHELLSPEC_PROJECT_ROOT}/spec/support"

# Load shared mocks BEFORE Include
eval "$(cat "$SUPPORT_DIR/configure_mocks.sh")"

# Need ZFS helpers for load_virtio_mapping, map_disks_to_virtio, build_zpool_command
Include "$SCRIPTS_DIR/035-zfs-helpers.sh"

Describe "371-configure-zfs-pool.sh"
  Include "$SCRIPTS_DIR/371-configure-zfs-pool.sh"

  # Cleanup after all tests
  AfterAll 'rm -f /tmp/virtio_map.env'

  # ===========================================================================
  # _config_zfs_pool()
  # ===========================================================================
  Describe "_config_zfs_pool()"

    Describe "when BOOT_DISK is not set (all-ZFS mode)"
      It "skips pool creation and returns success"
        BOOT_DISK=""
        When call _config_zfs_pool
        The status should be success
      End

      It "returns early without loading virtio mapping"
        BOOT_DISK=""
        rm -f /tmp/virtio_map.env
        When call _config_zfs_pool
        The status should be success
      End
    End

    Describe "when BOOT_DISK is set (ext4 boot mode)"
      Describe "with valid virtio mapping"
        It "creates ZFS pool successfully"
          BOOT_DISK="/dev/nvme0n1"
          ZFS_POOL_DISKS=("/dev/sda" "/dev/sdb")
          ZFS_RAID="raid1"
          MOCK_REMOTE_RUN_RESULT=0
          (create_virtio_mapping "/dev/nvme0n1" "/dev/sda" "/dev/sdb") || true
          When call _config_zfs_pool
          The status should be success
        End

        It "fails when remote_run fails"
          BOOT_DISK="/dev/nvme0n1"
          ZFS_POOL_DISKS=("/dev/sda" "/dev/sdb")
          ZFS_RAID="raid1"
          MOCK_REMOTE_RUN_RESULT=1
          (create_virtio_mapping "/dev/nvme0n1" "/dev/sda" "/dev/sdb") || true
          When call _config_zfs_pool
          The status should be failure
        End
      End

      Describe "without virtio mapping file"
        It "fails when virtio mapping is missing"
          BOOT_DISK="/dev/nvme0n1"
          ZFS_POOL_DISKS=("/dev/sda" "/dev/sdb")
          ZFS_RAID="raid1"
          MOCK_REMOTE_RUN_RESULT=0
          rm -f /tmp/virtio_map.env
          When call _config_zfs_pool
          The status should be failure
        End
      End

      Describe "with different RAID types"
        It "handles single disk"
          BOOT_DISK="/dev/nvme0n1"
          ZFS_POOL_DISKS=("/dev/sda")
          ZFS_RAID="single"
          MOCK_REMOTE_RUN_RESULT=0
          (create_virtio_mapping "/dev/nvme0n1" "/dev/sda") || true
          When call _config_zfs_pool
          The status should be success
        End

        It "handles raid1 (mirror)"
          BOOT_DISK="/dev/nvme0n1"
          ZFS_POOL_DISKS=("/dev/sda" "/dev/sdb")
          ZFS_RAID="raid1"
          MOCK_REMOTE_RUN_RESULT=0
          (create_virtio_mapping "/dev/nvme0n1" "/dev/sda" "/dev/sdb") || true
          When call _config_zfs_pool
          The status should be success
        End

        It "handles raidz1"
          BOOT_DISK="/dev/nvme0n1"
          ZFS_POOL_DISKS=("/dev/sda" "/dev/sdb" "/dev/sdc")
          ZFS_RAID="raidz1"
          MOCK_REMOTE_RUN_RESULT=0
          (create_virtio_mapping "/dev/nvme0n1" "/dev/sda" "/dev/sdb" "/dev/sdc") || true
          When call _config_zfs_pool
          The status should be success
        End

        It "handles raid10"
          BOOT_DISK="/dev/nvme0n1"
          ZFS_POOL_DISKS=("/dev/sda" "/dev/sdb" "/dev/sdc" "/dev/sdd")
          ZFS_RAID="raid10"
          MOCK_REMOTE_RUN_RESULT=0
          (create_virtio_mapping "/dev/nvme0n1" "/dev/sda" "/dev/sdb" "/dev/sdc" "/dev/sdd") || true
          When call _config_zfs_pool
          The status should be success
        End

        It "handles raid0 (stripe)"
          BOOT_DISK="/dev/nvme0n1"
          ZFS_POOL_DISKS=("/dev/sda" "/dev/sdb")
          ZFS_RAID="raid0"
          MOCK_REMOTE_RUN_RESULT=0
          (create_virtio_mapping "/dev/nvme0n1" "/dev/sda" "/dev/sdb") || true
          When call _config_zfs_pool
          The status should be success
        End

        It "handles raidz2"
          BOOT_DISK="/dev/nvme0n1"
          ZFS_POOL_DISKS=("/dev/sda" "/dev/sdb" "/dev/sdc" "/dev/sdd")
          ZFS_RAID="raidz2"
          MOCK_REMOTE_RUN_RESULT=0
          (create_virtio_mapping "/dev/nvme0n1" "/dev/sda" "/dev/sdb" "/dev/sdc" "/dev/sdd") || true
          When call _config_zfs_pool
          The status should be success
        End
      End

      Describe "with disk mapping errors"
        It "fails when pool disk not in virtio mapping"
          BOOT_DISK="/dev/nvme0n1"
          ZFS_POOL_DISKS=("/dev/sdz")
          ZFS_RAID="single"
          MOCK_REMOTE_RUN_RESULT=0
          (create_virtio_mapping "/dev/nvme0n1" "/dev/sda") || true
          When call _config_zfs_pool
          The status should be failure
        End
      End

      Describe "with invalid RAID type"
        It "fails with unknown RAID type"
          BOOT_DISK="/dev/nvme0n1"
          ZFS_POOL_DISKS=("/dev/sda" "/dev/sdb")
          ZFS_RAID="unknown_raid"
          MOCK_REMOTE_RUN_RESULT=0
          (create_virtio_mapping "/dev/nvme0n1" "/dev/sda" "/dev/sdb") || true
          When call _config_zfs_pool
          The status should be failure
        End
      End
    End

    Describe "edge cases"
      It "handles empty ZFS_POOL_DISKS array"
        BOOT_DISK="/dev/nvme0n1"
        ZFS_POOL_DISKS=()
        ZFS_RAID="raid1"
        MOCK_REMOTE_RUN_RESULT=0
        (create_virtio_mapping "/dev/nvme0n1") || true
        When call _config_zfs_pool
        The status should be failure
      End

      It "handles nvme pool disks"
        BOOT_DISK="/dev/nvme0n1"
        ZFS_POOL_DISKS=("/dev/nvme1n1" "/dev/nvme2n1")
        ZFS_RAID="raid1"
        MOCK_REMOTE_RUN_RESULT=0
        (create_virtio_mapping "/dev/nvme0n1" "/dev/nvme1n1" "/dev/nvme2n1") || true
        When call _config_zfs_pool
        The status should be success
      End

      It "handles mixed disk types"
        BOOT_DISK="/dev/nvme0n1"
        ZFS_POOL_DISKS=("/dev/sda" "/dev/nvme1n1")
        ZFS_RAID="raid1"
        MOCK_REMOTE_RUN_RESULT=0
        (create_virtio_mapping "/dev/nvme0n1" "/dev/sda" "/dev/nvme1n1") || true
        When call _config_zfs_pool
        The status should be success
      End
    End
  End

  # ===========================================================================
  # configure_zfs_pool() - public wrapper
  # ===========================================================================
  Describe "configure_zfs_pool()"
    It "calls _config_zfs_pool and returns its result"
      BOOT_DISK=""
      When call configure_zfs_pool
      The status should be success
    End

    It "passes through success from _config_zfs_pool"
      BOOT_DISK="/dev/nvme0n1"
      ZFS_POOL_DISKS=("/dev/sda" "/dev/sdb")
      ZFS_RAID="raid1"
      MOCK_REMOTE_RUN_RESULT=0
      (create_virtio_mapping "/dev/nvme0n1" "/dev/sda" "/dev/sdb") || true
      When call configure_zfs_pool
      The status should be success
    End

    It "passes through failure from _config_zfs_pool"
      BOOT_DISK="/dev/nvme0n1"
      ZFS_POOL_DISKS=("/dev/sda" "/dev/sdb")
      ZFS_RAID="raid1"
      MOCK_REMOTE_RUN_RESULT=1
      (create_virtio_mapping "/dev/nvme0n1" "/dev/sda" "/dev/sdb") || true
      When call configure_zfs_pool
      The status should be failure
    End
  End
End
