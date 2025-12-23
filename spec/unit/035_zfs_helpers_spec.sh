# shellcheck shell=bash
# =============================================================================
# Tests for 035-zfs-helpers.sh
# =============================================================================

%const SCRIPTS_DIR: "${SHELLSPEC_PROJECT_ROOT}/scripts"

# Mock log function since it's used by zfs helpers
log() { :; }

Describe "035-zfs-helpers.sh"
  Include "$SCRIPTS_DIR/035-zfs-helpers.sh"

  # ===========================================================================
  # map_raid_to_toml()
  # ===========================================================================
  Describe "map_raid_to_toml()"
    It "maps single to raid0"
      When call map_raid_to_toml "single"
      The output should equal "raid0"
    End

    It "maps raid0 to raid0"
      When call map_raid_to_toml "raid0"
      The output should equal "raid0"
    End

    It "maps raid1 to raid1"
      When call map_raid_to_toml "raid1"
      The output should equal "raid1"
    End

    It "maps raidz1 to raidz-1"
      When call map_raid_to_toml "raidz1"
      The output should equal "raidz-1"
    End

    It "maps raidz2 to raidz-2"
      When call map_raid_to_toml "raidz2"
      The output should equal "raidz-2"
    End

    It "maps raidz3 to raidz-3"
      When call map_raid_to_toml "raidz3"
      The output should equal "raidz-3"
    End

    It "maps raid5 (legacy) to raidz-1"
      When call map_raid_to_toml "raid5"
      The output should equal "raidz-1"
    End

    It "maps raid10 to raid10"
      When call map_raid_to_toml "raid10"
      The output should equal "raid10"
    End

    It "defaults unknown to raid0"
      When call map_raid_to_toml "unknown"
      The output should equal "raid0"
    End

    It "handles empty input"
      When call map_raid_to_toml ""
      The output should equal "raid0"
    End
  End

  # ===========================================================================
  # build_zpool_command()
  # ===========================================================================
  Describe "build_zpool_command()"
    It "builds single disk command"
      When call build_zpool_command "tank" "single" /dev/vda
      The output should equal "zpool create -f tank /dev/vda"
    End

    It "builds raid0 (stripe) command"
      When call build_zpool_command "tank" "raid0" /dev/vda /dev/vdb
      The output should equal "zpool create -f tank /dev/vda /dev/vdb"
    End

    It "builds raid1 (mirror) command"
      When call build_zpool_command "tank" "raid1" /dev/vda /dev/vdb
      The output should equal "zpool create -f tank mirror /dev/vda /dev/vdb"
    End

    It "builds raidz1 command"
      When call build_zpool_command "rpool" "raidz1" /dev/vda /dev/vdb /dev/vdc
      The output should equal "zpool create -f rpool raidz /dev/vda /dev/vdb /dev/vdc"
    End

    It "builds raidz2 command"
      When call build_zpool_command "rpool" "raidz2" /dev/vda /dev/vdb /dev/vdc /dev/vdd
      The output should equal "zpool create -f rpool raidz2 /dev/vda /dev/vdb /dev/vdc /dev/vdd"
    End

    It "builds raid10 with mirror pairs"
      When call build_zpool_command "tank" "raid10" /dev/vda /dev/vdb /dev/vdc /dev/vdd
      The output should equal "zpool create -f tank mirror /dev/vda /dev/vdb mirror /dev/vdc /dev/vdd"
    End

    It "fails with empty pool name"
      When call build_zpool_command "" "raid1" /dev/vda /dev/vdb
      The status should be failure
    End

    It "fails with no vdevs"
      When call build_zpool_command "tank" "raid1"
      The status should be failure
    End

    It "fails with unknown raid type"
      When call build_zpool_command "tank" "invalid" /dev/vda /dev/vdb
      The status should be failure
    End

    It "handles three-disk mirror"
      When call build_zpool_command "tank" "raid1" /dev/vda /dev/vdb /dev/vdc
      The output should equal "zpool create -f tank mirror /dev/vda /dev/vdb /dev/vdc"
    End
  End

  # ===========================================================================
  # create_virtio_mapping() and load_virtio_mapping()
  # ===========================================================================
  Describe "virtio mapping"
    AfterEach 'rm -f /tmp/virtio_map.env'

    It "creates mapping file"
      When call create_virtio_mapping "" "/dev/sda" "/dev/sdb"
      The status should be success
      The file "/tmp/virtio_map.env" should be exist
    End

    It "loads mapping file"
      # Create mapping in a subshell to avoid ((idx++)) exit code issue
      (create_virtio_mapping "" "/dev/sda") || true
      When call load_virtio_mapping
      The status should be success
    End

    It "fails loading non-existent mapping"
      rm -f /tmp/virtio_map.env
      When call load_virtio_mapping
      The status should be failure
    End

    It "maps boot disk correctly"
      When call create_virtio_mapping "/dev/sda" "/dev/sdb"
      The status should be success
    End
  End
End
