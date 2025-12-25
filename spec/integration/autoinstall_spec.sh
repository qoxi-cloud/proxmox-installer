# shellcheck shell=bash
# shellcheck disable=SC2016,SC2034
# =============================================================================
# Integration tests for autoinstall creation
# Tests: 204-autoinstall.sh answer.toml generation, validation, disk mapping
# =============================================================================

%const SCRIPTS_DIR: "${SHELLSPEC_PROJECT_ROOT}/scripts"
%const SUPPORT_DIR: "${SHELLSPEC_PROJECT_ROOT}/spec/support"

# Load mocks
eval "$(cat "$SUPPORT_DIR/core_mocks.sh")"

# =============================================================================
# Global mocks - must be before Include
# =============================================================================
LOG_FILE="/tmp/shellspec-autoinstall-test.log"
export LOG_FILE

log() { echo "$*" >> "$LOG_FILE" 2>/dev/null || true; }
export -f log

run_with_progress() {
  local func="$3"
  shift 3
  "$func" "$@"
}
export -f run_with_progress

live_log_subtask() { :; }
export -f live_log_subtask

proxmox-auto-install-assistant() {
  case "$1" in
    validate-answer) [[ -f "$2" ]] ;;
  esac
  return 0
}
export -f proxmox-auto-install-assistant

# =============================================================================
# Test setup
# =============================================================================
setup_autoinstall_test() {
  # Required globals
  FQDN="testnode.example.com"
  PVE_HOSTNAME="testnode"
  EMAIL="admin@example.com"
  TIMEZONE="UTC"
  KEYBOARD="us"
  COUNTRY="US"
  NEW_ROOT_PASSWORD="SecurePass123"
  ZFS_RAID="raid1"
  ZFS_POOL_DISKS=("/dev/sda" "/dev/sdb")
  BOOT_DISK=""

  # Change to temp directory
  cd "${SHELLSPEC_TMPBASE}" || return 1

  # Clean up files
  rm -f answer.toml /tmp/virtio_map.env "$LOG_FILE" 2>/dev/null || true
  touch "$LOG_FILE"
}

cleanup_autoinstall_test() {
  rm -f answer.toml pve.iso pve-autoinstall.iso /tmp/virtio_map.env 2>/dev/null || true
  cd - >/dev/null 2>&1 || true
}

Describe "Autoinstall Integration"
  Include "$SCRIPTS_DIR/035-zfs-helpers.sh"
  Include "$SCRIPTS_DIR/204-autoinstall.sh"

  BeforeEach 'setup_autoinstall_test'
  AfterEach 'cleanup_autoinstall_test'

  # ===========================================================================
  # Virtio mapping
  # ===========================================================================
  Describe "virtio disk mapping"
    Describe "_virtio_name_for_index()"
      It "generates vda for index 0"
        When call _virtio_name_for_index 0
        The output should equal "vda"
      End

      It "generates vdz for index 25"
        When call _virtio_name_for_index 25
        The output should equal "vdz"
      End

      It "generates vdaa for index 26"
        When call _virtio_name_for_index 26
        The output should equal "vdaa"
      End

      It "generates vdba for index 52"
        When call _virtio_name_for_index 52
        The output should equal "vdba"
      End
    End

    Describe "create_virtio_mapping()"
      It "maps pool disks without boot disk"
        When call create_virtio_mapping "" "/dev/sda" "/dev/sdb"
        The status should be success
        The file "/tmp/virtio_map.env" should be exist
      End

      It "creates valid mapping file"
        # Use When call for the mapping creation
        When call create_virtio_mapping "" "/dev/sda" "/dev/sdb"
        The file "/tmp/virtio_map.env" should be exist
      End
    End

    Describe "map_disks_to_virtio()"
      BeforeEach 'create_virtio_mapping "" "/dev/sda" "/dev/sdb" >/dev/null 2>&1; load_virtio_mapping'

      It "formats as TOML array"
        When call map_disks_to_virtio "toml_array" "/dev/sda" "/dev/sdb"
        The output should equal '["vda", "vdb"]'
      End

      It "formats as bash array"
        When call map_disks_to_virtio "bash_array" "/dev/sda" "/dev/sdb"
        The output should equal "(/dev/vda /dev/vdb)"
      End

      It "formats as space separated"
        When call map_disks_to_virtio "space_separated" "/dev/sda" "/dev/sdb"
        The output should equal "/dev/vda /dev/vdb"
      End

      It "fails for unknown disk"
        When call map_disks_to_virtio "toml_array" "/dev/unknown"
        The status should be failure
      End
    End
  End

  # ===========================================================================
  # RAID type mapping
  # ===========================================================================
  Describe "map_raid_to_toml()"
    It "maps single to raid0"
      When call map_raid_to_toml "single"
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

    It "maps raid10 to raid10"
      When call map_raid_to_toml "raid10"
      The output should equal "raid10"
    End
  End

  # ===========================================================================
  # build_zpool_command()
  # ===========================================================================
  Describe "build_zpool_command()"
    It "builds mirror command for raid1"
      When call build_zpool_command "tank" "raid1" /dev/vda /dev/vdb
      The output should equal "zpool create -f tank mirror /dev/vda /dev/vdb"
    End

    It "builds raidz command for raidz1"
      When call build_zpool_command "tank" "raidz1" /dev/vda /dev/vdb /dev/vdc
      The output should equal "zpool create -f tank raidz /dev/vda /dev/vdb /dev/vdc"
    End

    It "builds raid10 with mirror pairs"
      When call build_zpool_command "tank" "raid10" /dev/vda /dev/vdb /dev/vdc /dev/vdd
      The output should equal "zpool create -f tank mirror /dev/vda /dev/vdb mirror /dev/vdc /dev/vdd"
    End

    It "fails raid10 with odd disk count"
      When call build_zpool_command "tank" "raid10" /dev/vda /dev/vdb /dev/vdc
      The status should be failure
    End

    It "fails raid10 with less than 4 disks"
      When call build_zpool_command "tank" "raid10" /dev/vda /dev/vdb
      The status should be failure
    End
  End

  # ===========================================================================
  # validate_answer_toml()
  # ===========================================================================
  Describe "validate_answer_toml()"
    It "passes for valid answer.toml"
      cat > answer.toml <<'EOF'
[global]
    fqdn = "test.example.com"
    mailto = "admin@test.com"
    timezone = "UTC"
    root-password = "password123"

[disk-setup]
    filesystem = "zfs"
EOF

      When call validate_answer_toml "./answer.toml"
      The status should be success
    End

    It "fails when fqdn is missing"
      cat > answer.toml <<'EOF'
[global]
    mailto = "admin@test.com"
    timezone = "UTC"
    root-password = "password123"
EOF

      When call validate_answer_toml "./answer.toml"
      The status should be failure
    End

    It "fails when [global] section is missing"
      cat > answer.toml <<'EOF'
fqdn = "test.example.com"
mailto = "admin@test.com"
EOF

      When call validate_answer_toml "./answer.toml"
      The status should be failure
    End
  End

  # ===========================================================================
  # make_answer_toml()
  # ===========================================================================
  Describe "make_answer_toml()"
    Describe "ZFS mode (all disks)"
      It "creates valid answer.toml for ZFS raid1"
        ZFS_RAID="raid1"
        ZFS_POOL_DISKS=("/dev/sda" "/dev/sdb")
        BOOT_DISK=""

        When call make_answer_toml
        The status should be success
        The file "answer.toml" should be exist
      End

      It "generates correct ZFS configuration"
        ZFS_RAID="raid1"
        ZFS_POOL_DISKS=("/dev/sda" "/dev/sdb")
        BOOT_DISK=""

        # Create and verify in one call
        generate_and_check() {
          make_answer_toml >/dev/null 2>&1
          cat answer.toml
        }

        When call generate_and_check
        The output should include 'filesystem = "zfs"'
        The output should include 'zfs.raid = "raid1"'
        The output should include '["vda", "vdb"]'
      End
    End

    Describe "separate boot disk mode (ext4)"
      It "creates valid answer.toml for ext4 boot disk"
        BOOT_DISK="/dev/nvme2n1"
        ZFS_POOL_DISKS=("/dev/sda" "/dev/sdb")

        When call make_answer_toml
        The status should be success
        The file "answer.toml" should be exist
      End

      It "generates correct ext4 configuration"
        BOOT_DISK="/dev/nvme2n1"
        ZFS_POOL_DISKS=("/dev/sda" "/dev/sdb")

        generate_and_check() {
          make_answer_toml >/dev/null 2>&1
          cat answer.toml
        }

        When call generate_and_check
        The output should include 'filesystem = "ext4"'
        The output should include '["vda"]'
        The output should include 'lvm.swapsize = 0'
      End
    End

    Describe "required fields"
      It "includes all required fields"
        ZFS_POOL_DISKS=("/dev/sda" "/dev/sdb")
        BOOT_DISK=""

        generate_and_check() {
          make_answer_toml >/dev/null 2>&1
          cat answer.toml
        }

        When call generate_and_check
        The output should include 'fqdn = "testnode.example.com"'
        The output should include 'mailto = "admin@example.com"'
        The output should include 'timezone = "UTC"'
        The output should include 'keyboard = "us"'
      End
    End
  End
End
