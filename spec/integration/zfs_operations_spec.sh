# shellcheck shell=bash
# shellcheck disable=SC2016,SC2034
# =============================================================================
# Integration tests for ZFS pool operations
# Tests: 371-configure-zfs-pool.sh, 035-zfs-helpers.sh complete flow
# =============================================================================

%const SCRIPTS_DIR: "${SHELLSPEC_PROJECT_ROOT}/scripts"
%const SUPPORT_DIR: "${SHELLSPEC_PROJECT_ROOT}/spec/support"

# Load mocks
eval "$(cat "$SUPPORT_DIR/core_mocks.sh")"
eval "$(cat "$SUPPORT_DIR/configure_mocks.sh")"

# =============================================================================
# Test setup
# =============================================================================
setup_zfs_test() {
  # Required globals
  BOOT_DISK=""
  ZFS_POOL_DISKS=("/dev/sda" "/dev/sdb")
  ZFS_RAID="raid1"

  # Mock functions
  LOG_FILE="${SHELLSPEC_TMPBASE}/test.log"
  touch "$LOG_FILE"

  # Create mock virtio mapping
  rm -f /tmp/virtio_map.env

  # Reset mock results
  MOCK_REMOTE_RUN_RESULT=0
  MOCK_REMOTE_EXEC_RESULT=0
  CAPTURED_POOL_CMD=""
}

cleanup_zfs_test() {
  rm -f /tmp/virtio_map.env 2>/dev/null || true
}

Describe "ZFS Operations Integration"
  Include "$SCRIPTS_DIR/035-zfs-helpers.sh"
  Include "$SCRIPTS_DIR/371-configure-zfs-pool.sh"

  BeforeEach 'setup_zfs_test'
  AfterEach 'cleanup_zfs_test'

  # ===========================================================================
  # Complete virtio mapping flow
  # ===========================================================================
  Describe "complete virtio mapping roundtrip"
    It "creates and loads mapping correctly"
      # Create mapping
      create_virtio_mapping "" "/dev/sda" "/dev/sdb"

      # Load mapping
      load_virtio_mapping
      result=$?

      # Verify mapping
      sda_vdev="${VIRTIO_MAP[/dev/sda]}"
      sdb_vdev="${VIRTIO_MAP[/dev/sdb]}"

      When call printf '%s %s %s' "$result" "$sda_vdev" "$sdb_vdev"
      The output should equal "0 vda vdb"
    End

    It "handles boot disk + pool disks"
      # Create mapping with boot disk
      create_virtio_mapping "/dev/nvme0n1" "/dev/sda" "/dev/sdb"
      load_virtio_mapping

      # Boot disk should be vda
      boot_vdev="${VIRTIO_MAP[/dev/nvme0n1]}"
      # Pool disks should be vdb, vdc
      sda_vdev="${VIRTIO_MAP[/dev/sda]}"
      sdb_vdev="${VIRTIO_MAP[/dev/sdb]}"

      When call printf '%s %s %s' "$boot_vdev" "$sda_vdev" "$sdb_vdev"
      The output should equal "vda vdb vdc"
    End

    It "persists mapping across function calls"
      # Create in one call
      create_virtio_mapping "" "/dev/sda" "/dev/sdb" "/dev/sdc"

      # Load in another call (simulating subshell)
      load_virtio_mapping

      When call map_disks_to_virtio "space_separated" "/dev/sda" "/dev/sdb" "/dev/sdc"
      The output should equal "/dev/vda /dev/vdb /dev/vdc"
    End
  End

  # ===========================================================================
  # Pool command generation for different RAID types
  # ===========================================================================
  Describe "pool command generation"
    BeforeEach 'create_virtio_mapping "" "/dev/sda" "/dev/sdb" "/dev/sdc" "/dev/sdd"; load_virtio_mapping'

    Describe "raid1 (mirror)"
      It "builds correct mirror command"
        When call build_zpool_command "tank" "raid1" /dev/vda /dev/vdb
        The output should equal "zpool create -f tank mirror /dev/vda /dev/vdb"
      End
    End

    Describe "raidz1"
      It "builds correct raidz command"
        When call build_zpool_command "tank" "raidz1" /dev/vda /dev/vdb /dev/vdc
        The output should equal "zpool create -f tank raidz /dev/vda /dev/vdb /dev/vdc"
      End
    End

    Describe "raidz2"
      It "builds correct raidz2 command"
        When call build_zpool_command "tank" "raidz2" /dev/vda /dev/vdb /dev/vdc /dev/vdd
        The output should equal "zpool create -f tank raidz2 /dev/vda /dev/vdb /dev/vdc /dev/vdd"
      End
    End

    Describe "raid10"
      It "builds correct striped mirror command"
        When call build_zpool_command "tank" "raid10" /dev/vda /dev/vdb /dev/vdc /dev/vdd
        The output should equal "zpool create -f tank mirror /dev/vda /dev/vdb mirror /dev/vdc /dev/vdd"
      End

      It "handles 6 disks"
        create_virtio_mapping "" "/dev/sda" "/dev/sdb" "/dev/sdc" "/dev/sdd" "/dev/sde" "/dev/sdf"
        load_virtio_mapping

        When call build_zpool_command "tank" "raid10" /dev/vda /dev/vdb /dev/vdc /dev/vdd /dev/vde /dev/vdf
        The output should equal "zpool create -f tank mirror /dev/vda /dev/vdb mirror /dev/vdc /dev/vdd mirror /dev/vde /dev/vdf"
      End
    End

    Describe "single"
      It "builds single disk command"
        When call build_zpool_command "tank" "single" /dev/vda
        The output should equal "zpool create -f tank /dev/vda"
      End
    End

    Describe "raid0 (stripe)"
      It "builds stripe command"
        When call build_zpool_command "tank" "raid0" /dev/vda /dev/vdb
        The output should equal "zpool create -f tank /dev/vda /dev/vdb"
      End
    End
  End

  # ===========================================================================
  # configure_zfs_pool() behavior
  # ===========================================================================
  Describe "configure_zfs_pool()"
    Describe "all-ZFS mode (BOOT_DISK empty)"
      It "skips pool creation when BOOT_DISK is empty"
        BOOT_DISK=""

        When call configure_zfs_pool
        The status should be success
      End

      It "does not call remote_run when BOOT_DISK is empty"
        BOOT_DISK=""
        remote_run_called=false
        remote_run() { remote_run_called=true; }

        configure_zfs_pool

        When call printf '%s' "$remote_run_called"
        The output should equal "false"
      End
    End

    Describe "separate boot disk mode"
      BeforeEach 'create_virtio_mapping "/dev/nvme0n1" "/dev/sda" "/dev/sdb"'

      It "creates pool when BOOT_DISK is set"
        BOOT_DISK="/dev/nvme0n1"
        ZFS_POOL_DISKS=("/dev/sda" "/dev/sdb")
        ZFS_RAID="raid1"

        When call configure_zfs_pool
        The status should be success
      End

      It "uses correct vdev names from mapping"
        BOOT_DISK="/dev/nvme0n1"
        ZFS_POOL_DISKS=("/dev/sda" "/dev/sdb")
        ZFS_RAID="raid1"

        load_virtio_mapping
        vdevs=$(map_disks_to_virtio "space_separated" "${ZFS_POOL_DISKS[@]}")

        # Pool disks should be vdb, vdc (boot is vda)
        When call printf '%s' "$vdevs"
        The output should equal "/dev/vdb /dev/vdc"
      End
    End

    Describe "failure handling"
      BeforeEach 'create_virtio_mapping "/dev/nvme0n1" "/dev/sda" "/dev/sdb"'

      It "fails when virtio mapping not found"
        BOOT_DISK="/dev/nvme0n1"
        ZFS_POOL_DISKS=("/dev/sda" "/dev/sdb")
        rm -f /tmp/virtio_map.env

        When call _config_zfs_pool
        The status should be failure
      End

      It "fails when remote_run fails"
        BOOT_DISK="/dev/nvme0n1"
        ZFS_POOL_DISKS=("/dev/sda" "/dev/sdb")
        MOCK_REMOTE_RUN_RESULT=1
        # Override remote_run to fail
        remote_run() { return 1; }

        When call _config_zfs_pool
        The status should be failure
      End
    End
  End

  # ===========================================================================
  # Edge cases
  # ===========================================================================
  Describe "edge cases"
    Describe "many disks (>26)"
      setup_many_disks() {
        local disks=()
        for i in {0..27}; do
          disks+=("/dev/sd$(printf '%c' $((97 + i % 26)))")
        done
        create_virtio_mapping "" "${disks[@]}"
        load_virtio_mapping
        # 27th disk (index 26) should be vdaa
        printf '%s' "${VIRTIO_MAP[${disks[26]}]}"
      }

      It "handles 27th disk correctly (vdaa)"
        When call setup_many_disks
        The output should equal "vdaa"
      End
    End

    Describe "disk deduplication"
      It "prevents duplicate mapping when boot disk is in pool disks"
        # Boot disk is also first pool disk
        create_virtio_mapping "/dev/sda" "/dev/sda" "/dev/sdb"
        load_virtio_mapping

        # sda should only be mapped once
        sda_vdev="${VIRTIO_MAP[/dev/sda]}"
        sdb_vdev="${VIRTIO_MAP[/dev/sdb]}"

        When call printf '%s %s' "$sda_vdev" "$sdb_vdev"
        The output should equal "vda vdb"
      End
    End
  End

  # ===========================================================================
  # Integration with answer.toml format
  # ===========================================================================
  Describe "TOML format integration"
    BeforeEach 'create_virtio_mapping "" "/dev/nvme0n1" "/dev/nvme1n1"; load_virtio_mapping'

    It "generates correct TOML array for answer.toml"
      When call map_disks_to_virtio "toml_array" "/dev/nvme0n1" "/dev/nvme1n1"
      The output should equal '["vda", "vdb"]'
    End

    It "uses short names without /dev/ prefix"
      result=$(map_disks_to_virtio "toml_array" "/dev/nvme0n1")
      When call printf '%s' "$result"
      The output should include '"vda"'
      The output should not include '"/dev/vda"'
    End
  End
End

