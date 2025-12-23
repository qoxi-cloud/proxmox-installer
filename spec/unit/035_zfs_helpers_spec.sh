# shellcheck shell=bash
# =============================================================================
# Tests for 035-zfs-helpers.sh
# =============================================================================

%const SCRIPTS_DIR: "${SHELLSPEC_PROJECT_ROOT}/scripts"
%const SUPPORT_DIR: "${SHELLSPEC_PROJECT_ROOT}/spec/support"

# Load shared mocks (includes silent log)
eval "$(cat "$SUPPORT_DIR/core_mocks.sh")"

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

    It "builds raidz3 command"
      When call build_zpool_command "rpool" "raidz3" /dev/vda /dev/vdb /dev/vdc /dev/vdd /dev/vde
      The output should equal "zpool create -f rpool raidz3 /dev/vda /dev/vdb /dev/vdc /dev/vdd /dev/vde"
    End

    It "builds raid10 with mirror pairs"
      When call build_zpool_command "tank" "raid10" /dev/vda /dev/vdb /dev/vdc /dev/vdd
      The output should equal "zpool create -f tank mirror /dev/vda /dev/vdb mirror /dev/vdc /dev/vdd"
    End

    It "builds raid10 with 6 disks"
      When call build_zpool_command "tank" "raid10" /dev/vda /dev/vdb /dev/vdc /dev/vdd /dev/vde /dev/vdf
      The output should equal "zpool create -f tank mirror /dev/vda /dev/vdb mirror /dev/vdc /dev/vdd mirror /dev/vde /dev/vdf"
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

    It "fails raid10 with less than 4 disks"
      When call build_zpool_command "tank" "raid10" /dev/vda /dev/vdb
      The status should be failure
    End

    It "fails raid10 with odd number of disks"
      When call build_zpool_command "tank" "raid10" /dev/vda /dev/vdb /dev/vdc /dev/vdd /dev/vde
      The status should be failure
    End
  End

  # ===========================================================================
  # create_virtio_mapping()
  # ===========================================================================
  Describe "create_virtio_mapping()"
    AfterEach 'rm -f /tmp/virtio_map.env'

    It "creates mapping file"
      When call create_virtio_mapping "" "/dev/sda" "/dev/sdb"
      The status should be success
      The file "/tmp/virtio_map.env" should be exist
    End

    It "maps pool disks starting from vda when no boot disk"
      (create_virtio_mapping "" "/dev/sda" "/dev/sdb") || true
      When call cat /tmp/virtio_map.env
      The output should include '[/dev/sda]="vda"'
      The output should include '[/dev/sdb]="vdb"'
    End

    It "maps boot disk to vda first"
      (create_virtio_mapping "/dev/nvme0n1" "/dev/sda" "/dev/sdb") || true
      When call cat /tmp/virtio_map.env
      The output should include '[/dev/nvme0n1]="vda"'
      The output should include '[/dev/sda]="vdb"'
      The output should include '[/dev/sdb]="vdc"'
    End

    It "handles single pool disk"
      (create_virtio_mapping "" "/dev/sda") || true
      When call cat /tmp/virtio_map.env
      The output should include '[/dev/sda]="vda"'
    End

    It "handles many pool disks"
      (create_virtio_mapping "" "/dev/sda" "/dev/sdb" "/dev/sdc" "/dev/sdd" "/dev/sde") || true
      When call cat /tmp/virtio_map.env
      The output should include '[/dev/sda]="vda"'
      The output should include '[/dev/sde]="vde"'
    End

    It "handles nvme device names"
      (create_virtio_mapping "/dev/nvme0n1" "/dev/nvme1n1" "/dev/nvme2n1") || true
      When call cat /tmp/virtio_map.env
      The output should include '[/dev/nvme0n1]="vda"'
      The output should include '[/dev/nvme1n1]="vdb"'
      The output should include '[/dev/nvme2n1]="vdc"'
    End

    It "creates declare -gA format"
      (create_virtio_mapping "" "/dev/sda") || true
      When call cat /tmp/virtio_map.env
      The output should include 'declare -gA VIRTIO_MAP'
    End
  End

  # ===========================================================================
  # load_virtio_mapping()
  # ===========================================================================
  Describe "load_virtio_mapping()"
    AfterEach 'rm -f /tmp/virtio_map.env'

    It "loads mapping file successfully"
      (create_virtio_mapping "" "/dev/sda") || true
      When call load_virtio_mapping
      The status should be success
    End

    It "fails loading non-existent mapping"
      rm -f /tmp/virtio_map.env
      When call load_virtio_mapping
      The status should be failure
    End

    It "populates VIRTIO_MAP array"
      (create_virtio_mapping "" "/dev/sda" "/dev/sdb") || true
      load_virtio_mapping
      When call echo "${VIRTIO_MAP[/dev/sda]}"
      The output should equal "vda"
    End

    It "populates multiple entries"
      (create_virtio_mapping "" "/dev/sda" "/dev/sdb" "/dev/sdc") || true
      load_virtio_mapping
      When call echo "${VIRTIO_MAP[/dev/sdb]}"
      The output should equal "vdb"
    End

    It "preserves boot disk mapping"
      (create_virtio_mapping "/dev/nvme0n1" "/dev/sda") || true
      load_virtio_mapping
      When call echo "${VIRTIO_MAP[/dev/nvme0n1]}"
      The output should equal "vda"
    End
  End

  # ===========================================================================
  # map_disks_to_virtio()
  # ===========================================================================
  Describe "map_disks_to_virtio()"
    BeforeEach 'rm -f /tmp/virtio_map.env; (create_virtio_mapping "" "/dev/sda" "/dev/sdb" "/dev/sdc") || true; load_virtio_mapping'
    AfterEach 'rm -f /tmp/virtio_map.env'

    Describe "toml_array format"
      It "formats single disk"
        When call map_disks_to_virtio "toml_array" "/dev/sda"
        The output should equal '["vda"]'
      End

      It "formats two disks"
        When call map_disks_to_virtio "toml_array" "/dev/sda" "/dev/sdb"
        The output should equal '["vda", "vdb"]'
      End

      It "formats three disks"
        When call map_disks_to_virtio "toml_array" "/dev/sda" "/dev/sdb" "/dev/sdc"
        The output should equal '["vda", "vdb", "vdc"]'
      End

      It "outputs short names without /dev/ prefix"
        When call map_disks_to_virtio "toml_array" "/dev/sda"
        The output should not include "/dev/"
      End
    End

    Describe "bash_array format"
      It "formats single disk"
        When call map_disks_to_virtio "bash_array" "/dev/sda"
        The output should equal '(/dev/vda)'
      End

      It "formats multiple disks"
        When call map_disks_to_virtio "bash_array" "/dev/sda" "/dev/sdb"
        The output should equal '(/dev/vda /dev/vdb)'
      End

      It "includes /dev/ prefix"
        When call map_disks_to_virtio "bash_array" "/dev/sda"
        The output should include "/dev/"
      End
    End

    Describe "space_separated format"
      It "formats single disk"
        When call map_disks_to_virtio "space_separated" "/dev/sda"
        The output should equal '/dev/vda'
      End

      It "formats multiple disks"
        When call map_disks_to_virtio "space_separated" "/dev/sda" "/dev/sdb" "/dev/sdc"
        The output should equal '/dev/vda /dev/vdb /dev/vdc'
      End

      It "separates with spaces"
        When call map_disks_to_virtio "space_separated" "/dev/sda" "/dev/sdb"
        The output should include ' '
      End
    End

    Describe "error handling"
      It "fails with no disks"
        When call map_disks_to_virtio "toml_array"
        The status should be failure
      End

      It "fails with unknown format"
        When call map_disks_to_virtio "unknown_format" "/dev/sda"
        The status should be failure
      End

      It "fails when disk not in mapping"
        When call map_disks_to_virtio "toml_array" "/dev/sdz"
        The status should be failure
      End
    End

    Describe "with boot disk in mapping"
      BeforeEach 'rm -f /tmp/virtio_map.env; (create_virtio_mapping "/dev/nvme0n1" "/dev/sda" "/dev/sdb") || true; load_virtio_mapping'

      It "maps boot disk correctly"
        When call map_disks_to_virtio "toml_array" "/dev/nvme0n1"
        The output should equal '["vda"]'
      End

      It "maps pool disks after boot disk"
        When call map_disks_to_virtio "toml_array" "/dev/sda" "/dev/sdb"
        The output should equal '["vdb", "vdc"]'
      End

      It "maps all disks including boot"
        When call map_disks_to_virtio "space_separated" "/dev/nvme0n1" "/dev/sda" "/dev/sdb"
        The output should equal '/dev/vda /dev/vdb /dev/vdc'
      End
    End
  End
End
