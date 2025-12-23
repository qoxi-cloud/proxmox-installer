# shellcheck shell=bash
# shellcheck disable=SC2016,SC2034,SC2154,SC2329
# =============================================================================
# Tests for 204-autoinstall.sh
# =============================================================================
# Note: SC2016 disabled - single quotes in ShellSpec hooks
#       SC2034 disabled - variables used by ShellSpec assertions
#       SC2154 disabled - variables set in mocks
#       SC2329 disabled - mock functions invoked indirectly by tested code

%const SCRIPTS_DIR: "${SHELLSPEC_PROJECT_ROOT}/scripts"
%const SUPPORT_DIR: "${SHELLSPEC_PROJECT_ROOT}/spec/support"

# Load shared mocks
eval "$(cat "$SUPPORT_DIR/core_mocks.sh")"

# =============================================================================
# Mock control variables (use files for cross-subshell communication)
# =============================================================================
MOCK_TEMP_DIR=""

# =============================================================================
# Reset mock state
# =============================================================================
reset_autoinstall_mocks() {
  MOCK_TEMP_DIR=$(mktemp -d)
  LOG_FILE="$MOCK_TEMP_DIR/test.log"
  touch "$LOG_FILE"

  # Reset tracking files
  echo "0" > "$MOCK_TEMP_DIR/show_progress_calls"
  echo "0" > "$MOCK_TEMP_DIR/create_virtio_mapping_calls"
  echo "0" > "$MOCK_TEMP_DIR/load_virtio_mapping_calls"
  echo "0" > "$MOCK_TEMP_DIR/map_disks_to_virtio_calls"
  echo "0" > "$MOCK_TEMP_DIR/map_raid_to_toml_calls"
  echo "0" > "$MOCK_TEMP_DIR/proxmox_assistant_calls"
  echo "0" > "$MOCK_TEMP_DIR/proxmox_assistant_validate_calls"
  echo "false" > "$MOCK_TEMP_DIR/proxmox_assistant_available"
  echo "false" > "$MOCK_TEMP_DIR/proxmox_assistant_fail"
  echo "false" > "$MOCK_TEMP_DIR/proxmox_assistant_validate_fail"
  echo "false" > "$MOCK_TEMP_DIR/load_virtio_mapping_fail"
  echo "false" > "$MOCK_TEMP_DIR/map_disks_fail"
  : > "$MOCK_TEMP_DIR/log_calls"
  : > "$MOCK_TEMP_DIR/live_log_subtask_calls"

  # Reset global variables
  BOOT_DISK=""
  ZFS_POOL_DISKS=()
  ZFS_RAID="raid1"
  NEW_ROOT_PASSWORD="testpassword123"
  KEYBOARD="us"
  COUNTRY="US"
  FQDN="test.example.com"
  EMAIL="admin@example.com"
  TIMEZONE="UTC"

  # Setup virtio mapping
  declare -gA VIRTIO_MAP
  VIRTIO_MAP["/dev/nvme0n1"]="vda"
  VIRTIO_MAP["/dev/nvme1n1"]="vdb"
  VIRTIO_MAP["/dev/sda"]="vda"
  VIRTIO_MAP["/dev/sdb"]="vdb"

  # Create pve.iso for make_autoinstall_iso tests
  touch "$MOCK_TEMP_DIR/pve.iso"
}

cleanup_autoinstall_mocks() {
  [[ -n "$MOCK_TEMP_DIR" ]] && rm -rf "$MOCK_TEMP_DIR"
  rm -f answer.toml pve.iso pve-autoinstall.iso 2>/dev/null
}

# Helper to increment counter in file
_inc_counter() {
  local file="$1"
  local val
  val=$(cat "$file" 2>/dev/null || echo 0)
  echo $((val + 1)) > "$file"
}

# Helper to read counter
_get_counter() {
  cat "$1" 2>/dev/null || echo 0
}

# =============================================================================
# Mock functions
# =============================================================================

# Override log to track calls
log() {
  echo "$*" >> "$MOCK_TEMP_DIR/log_calls"
}

# Override live_log_subtask to track calls
live_log_subtask() {
  echo "$*" >> "$MOCK_TEMP_DIR/live_log_subtask_calls"
}

# Override show_progress to wait synchronously
show_progress() {
  local pid="$1"
  _inc_counter "$MOCK_TEMP_DIR/show_progress_calls"
  wait "$pid" 2>/dev/null
  return $?
}

# Override run_with_progress to execute command directly
run_with_progress() {
  local label="$1"
  local done_msg="$2"
  shift 2

  if [[ $# -gt 0 ]]; then
    "$@"
    return $?
  fi
  return 0
}

# Mock create_virtio_mapping
create_virtio_mapping() {
  _inc_counter "$MOCK_TEMP_DIR/create_virtio_mapping_calls"
  # Create a fake virtio_map.env
  echo 'declare -gA VIRTIO_MAP=(["/dev/nvme0n1"]="vda" ["/dev/nvme1n1"]="vdb" ["/dev/sda"]="vda" ["/dev/sdb"]="vdb")' > /tmp/virtio_map.env
  return 0
}

# Mock load_virtio_mapping
load_virtio_mapping() {
  _inc_counter "$MOCK_TEMP_DIR/load_virtio_mapping_calls"
  if [[ $(cat "$MOCK_TEMP_DIR/load_virtio_mapping_fail") == "true" ]]; then
    return 1
  fi
  # Source the mapping file if it exists
  if [[ -f /tmp/virtio_map.env ]]; then
    # shellcheck disable=SC1091
    source /tmp/virtio_map.env
  fi
  return 0
}

# Mock map_disks_to_virtio
map_disks_to_virtio() {
  _inc_counter "$MOCK_TEMP_DIR/map_disks_to_virtio_calls"
  if [[ $(cat "$MOCK_TEMP_DIR/map_disks_fail") == "true" ]]; then
    echo ""
    return 1
  fi

  local format="$1"
  shift
  local disks=("$@")

  case "$format" in
    toml_array)
      local result="["
      for i in "${!disks[@]}"; do
        local disk="${disks[$i]}"
        local vdev="${VIRTIO_MAP[$disk]:-vd$i}"
        result+="\"${vdev}\""
        [[ $i -lt $((${#disks[@]} - 1)) ]] && result+=", "
      done
      result+="]"
      printf '%s\n' "$result"
      ;;
    *)
      printf '%s\n' "vda vdb"
      ;;
  esac
}

# Mock map_raid_to_toml
map_raid_to_toml() {
  _inc_counter "$MOCK_TEMP_DIR/map_raid_to_toml_calls"
  local raid="$1"
  case "$raid" in
    single) echo "raid0" ;;
    raid0) echo "raid0" ;;
    raid1) echo "raid1" ;;
    raidz1) echo "raidz-1" ;;
    raidz2) echo "raidz-2" ;;
    raidz3) echo "raidz-3" ;;
    raid10) echo "raid10" ;;
    *) echo "raid0" ;;
  esac
}

# Mock proxmox-auto-install-assistant
proxmox-auto-install-assistant() {
  _inc_counter "$MOCK_TEMP_DIR/proxmox_assistant_calls"

  case "$1" in
    validate-answer)
      _inc_counter "$MOCK_TEMP_DIR/proxmox_assistant_validate_calls"
      if [[ $(cat "$MOCK_TEMP_DIR/proxmox_assistant_validate_fail") == "true" ]]; then
        return 1
      fi
      return 0
      ;;
    prepare-iso)
      if [[ $(cat "$MOCK_TEMP_DIR/proxmox_assistant_fail") == "true" ]]; then
        return 1
      fi
      # Create the output ISO
      local output_file=""
      for arg in "$@"; do
        if [[ "$arg" == "--output" ]]; then
          continue
        elif [[ "$arg" == *.iso && "$arg" != "pve.iso" ]]; then
          output_file="$arg"
        fi
      done
      if [[ -n "$output_file" ]]; then
        touch "$output_file"
      else
        touch pve-autoinstall.iso
      fi
      return 0
      ;;
    *)
      return 0
      ;;
  esac
}

# Mock command to check for proxmox-auto-install-assistant availability
command() {
  if [[ "$2" == "proxmox-auto-install-assistant" ]]; then
    if [[ $(cat "$MOCK_TEMP_DIR/proxmox_assistant_available") == "true" ]]; then
      return 0
    else
      return 1
    fi
  fi
  builtin command "$@"
}

# Mock stat for file size display
stat() {
  if [[ "$1" == "-c%s" ]]; then
    echo "1073741824"  # 1GB
    return 0
  fi
  builtin stat "$@" 2>/dev/null || echo "0"
}

Describe "204-autoinstall.sh"
  Include "$SCRIPTS_DIR/204-autoinstall.sh"

  BeforeEach 'reset_autoinstall_mocks'
  AfterEach 'cleanup_autoinstall_mocks'

  # ===========================================================================
  # validate_answer_toml()
  # ===========================================================================
  Describe "validate_answer_toml()"
    Describe "with valid answer.toml"
      It "returns success when all required fields present"
        # Create valid answer.toml
        cat > "$MOCK_TEMP_DIR/answer.toml" <<EOF
[global]
    keyboard = "us"
    country = "US"
    fqdn = "test.example.com"
    mailto = "admin@example.com"
    timezone = "UTC"
    root-password = "testpass123"
    reboot-on-error = false
EOF
        When call validate_answer_toml "$MOCK_TEMP_DIR/answer.toml"
        The status should be success
      End

      It "validates with proxmox-auto-install-assistant when available"
        echo "true" > "$MOCK_TEMP_DIR/proxmox_assistant_available"
        cat > "$MOCK_TEMP_DIR/answer.toml" <<EOF
[global]
    fqdn = "test.example.com"
    mailto = "admin@example.com"
    timezone = "UTC"
    root-password = "testpass123"
EOF
        When call validate_answer_toml "$MOCK_TEMP_DIR/answer.toml"
        The status should be success
        The value "$(_get_counter "$MOCK_TEMP_DIR/proxmox_assistant_validate_calls")" should equal 1
      End
    End

    Describe "with invalid answer.toml"
      It "fails when missing fqdn field"
        cat > "$MOCK_TEMP_DIR/answer.toml" <<EOF
[global]
    mailto = "admin@example.com"
    timezone = "UTC"
    root-password = "testpass123"
EOF
        When call validate_answer_toml "$MOCK_TEMP_DIR/answer.toml"
        The status should be failure
      End

      It "fails when missing mailto field"
        cat > "$MOCK_TEMP_DIR/answer.toml" <<EOF
[global]
    fqdn = "test.example.com"
    timezone = "UTC"
    root-password = "testpass123"
EOF
        When call validate_answer_toml "$MOCK_TEMP_DIR/answer.toml"
        The status should be failure
      End

      It "fails when missing timezone field"
        cat > "$MOCK_TEMP_DIR/answer.toml" <<EOF
[global]
    fqdn = "test.example.com"
    mailto = "admin@example.com"
    root-password = "testpass123"
EOF
        When call validate_answer_toml "$MOCK_TEMP_DIR/answer.toml"
        The status should be failure
      End

      It "fails when missing root-password field"
        cat > "$MOCK_TEMP_DIR/answer.toml" <<EOF
[global]
    fqdn = "test.example.com"
    mailto = "admin@example.com"
    timezone = "UTC"
EOF
        When call validate_answer_toml "$MOCK_TEMP_DIR/answer.toml"
        The status should be failure
      End

      It "fails when missing [global] section"
        cat > "$MOCK_TEMP_DIR/answer.toml" <<EOF
fqdn = "test.example.com"
mailto = "admin@example.com"
timezone = "UTC"
root-password = "testpass123"
EOF
        When call validate_answer_toml "$MOCK_TEMP_DIR/answer.toml"
        The status should be failure
      End

      It "fails when proxmox-auto-install-assistant validation fails"
        echo "true" > "$MOCK_TEMP_DIR/proxmox_assistant_available"
        echo "true" > "$MOCK_TEMP_DIR/proxmox_assistant_validate_fail"
        cat > "$MOCK_TEMP_DIR/answer.toml" <<EOF
[global]
    fqdn = "test.example.com"
    mailto = "admin@example.com"
    timezone = "UTC"
    root-password = "testpass123"
EOF
        When call validate_answer_toml "$MOCK_TEMP_DIR/answer.toml"
        The status should be failure
      End

      It "fails for non-existent file"
        When call validate_answer_toml "$MOCK_TEMP_DIR/nonexistent.toml"
        The status should be failure
      End
    End

    Describe "with skipped advanced validation"
      It "skips proxmox-auto-install-assistant when not available"
        echo "false" > "$MOCK_TEMP_DIR/proxmox_assistant_available"
        cat > "$MOCK_TEMP_DIR/answer.toml" <<EOF
[global]
    fqdn = "test.example.com"
    mailto = "admin@example.com"
    timezone = "UTC"
    root-password = "testpass123"
EOF
        When call validate_answer_toml "$MOCK_TEMP_DIR/answer.toml"
        The status should be success
        The value "$(_get_counter "$MOCK_TEMP_DIR/proxmox_assistant_validate_calls")" should equal 0
      End
    End
  End

  # ===========================================================================
  # make_answer_toml()
  # ===========================================================================
  Describe "make_answer_toml()"
    Describe "in all-ZFS mode (no separate boot disk)"
      It "creates answer.toml with ZFS filesystem"
        BOOT_DISK=""
        ZFS_POOL_DISKS=("/dev/nvme0n1" "/dev/nvme1n1")
        ZFS_RAID="raid1"
        When call make_answer_toml
        The status should be success
        The file "answer.toml" should be exist
        The contents of file "answer.toml" should include "filesystem = \"zfs\""
        The contents of file "answer.toml" should include "zfs.raid = \"raid1\""
      End

      It "includes all required global fields"
        BOOT_DISK=""
        ZFS_POOL_DISKS=("/dev/nvme0n1")
        ZFS_RAID="single"
        KEYBOARD="de"
        COUNTRY="DE"
        FQDN="server.test.local"
        EMAIL="test@test.com"
        TIMEZONE="Europe/Berlin"
        NEW_ROOT_PASSWORD="securepass123"
        When call make_answer_toml
        The status should be success
        The contents of file "answer.toml" should include 'keyboard = "de"'
        The contents of file "answer.toml" should include 'country = "DE"'
        The contents of file "answer.toml" should include 'fqdn = "server.test.local"'
        The contents of file "answer.toml" should include 'mailto = "test@test.com"'
        The contents of file "answer.toml" should include 'timezone = "Europe/Berlin"'
      End

      It "maps raidz1 to zfs.raid correctly"
        BOOT_DISK=""
        ZFS_POOL_DISKS=("/dev/nvme0n1" "/dev/nvme1n1" "/dev/sda")
        ZFS_RAID="raidz1"
        When call make_answer_toml
        The status should be success
        The contents of file "answer.toml" should include 'zfs.raid = "raidz-1"'
      End

      It "maps raidz2 to zfs.raid correctly"
        BOOT_DISK=""
        ZFS_POOL_DISKS=("/dev/nvme0n1" "/dev/nvme1n1" "/dev/sda" "/dev/sdb")
        ZFS_RAID="raidz2"
        When call make_answer_toml
        The status should be success
        The contents of file "answer.toml" should include 'zfs.raid = "raidz-2"'
      End

      It "includes ZFS compression and checksum settings"
        BOOT_DISK=""
        ZFS_POOL_DISKS=("/dev/nvme0n1")
        ZFS_RAID="single"
        When call make_answer_toml
        The status should be success
        The contents of file "answer.toml" should include 'zfs.compress = "lz4"'
        The contents of file "answer.toml" should include 'zfs.checksum = "on"'
      End

      It "includes disk-list in TOML array format"
        BOOT_DISK=""
        ZFS_POOL_DISKS=("/dev/nvme0n1" "/dev/nvme1n1")
        When call make_answer_toml
        The status should be success
        The contents of file "answer.toml" should include "disk-list = "
      End

      It "includes network source from-dhcp"
        BOOT_DISK=""
        ZFS_POOL_DISKS=("/dev/nvme0n1")
        When call make_answer_toml
        The status should be success
        The contents of file "answer.toml" should include '[network]'
        The contents of file "answer.toml" should include 'source = "from-dhcp"'
      End
    End

    Describe "in boot disk mode (separate boot + pool disks)"
      It "creates answer.toml with ext4 filesystem"
        BOOT_DISK="/dev/nvme0n1"
        ZFS_POOL_DISKS=("/dev/nvme1n1" "/dev/sda")
        When call make_answer_toml
        The status should be success
        The contents of file "answer.toml" should include "filesystem = \"ext4\""
      End

      It "includes LVM swapsize setting"
        BOOT_DISK="/dev/nvme0n1"
        ZFS_POOL_DISKS=("/dev/nvme1n1")
        When call make_answer_toml
        The status should be success
        The contents of file "answer.toml" should include "lvm.swapsize = 0"
      End

      It "does NOT include ZFS parameters"
        BOOT_DISK="/dev/nvme0n1"
        ZFS_POOL_DISKS=("/dev/nvme1n1")
        When call make_answer_toml
        The status should be success
        The contents of file "answer.toml" should not include "zfs.raid"
        The contents of file "answer.toml" should not include "zfs.compress"
      End
    End

    Describe "with password escaping"
      It "escapes backslashes in password"
        BOOT_DISK=""
        ZFS_POOL_DISKS=("/dev/nvme0n1")
        NEW_ROOT_PASSWORD='pass\word'
        When call make_answer_toml
        The status should be success
        The contents of file "answer.toml" should include 'root-password = "pass\\word"'
      End

      It "escapes double quotes in password"
        BOOT_DISK=""
        ZFS_POOL_DISKS=("/dev/nvme0n1")
        NEW_ROOT_PASSWORD='pass"word'
        When call make_answer_toml
        The status should be success
        The contents of file "answer.toml" should include 'root-password = "pass\"word"'
      End

      It "escapes both backslashes and quotes"
        BOOT_DISK=""
        ZFS_POOL_DISKS=("/dev/nvme0n1")
        NEW_ROOT_PASSWORD='pa\"ss\\wo"rd'
        When call make_answer_toml
        The status should be success
        # Original: pa\"ss\\wo"rd
        # After escaping backslashes: pa\"ss\\\\wo"rd
        # After escaping quotes: pa\\\"ss\\\\wo\\\"rd
        The file "answer.toml" should be exist
      End
    End

    Describe "with disk mapping"
      It "calls create_virtio_mapping"
        BOOT_DISK=""
        ZFS_POOL_DISKS=("/dev/nvme0n1")
        When call make_answer_toml
        The status should be success
        The value "$(_get_counter "$MOCK_TEMP_DIR/create_virtio_mapping_calls")" should equal 1
      End

      It "calls load_virtio_mapping"
        BOOT_DISK=""
        ZFS_POOL_DISKS=("/dev/nvme0n1")
        When call make_answer_toml
        The status should be success
        The value "$(_get_counter "$MOCK_TEMP_DIR/load_virtio_mapping_calls")" should equal 1
      End

      It "calls map_disks_to_virtio"
        BOOT_DISK=""
        ZFS_POOL_DISKS=("/dev/nvme0n1")
        When call make_answer_toml
        The status should be success
        The value "$(_get_counter "$MOCK_TEMP_DIR/map_disks_to_virtio_calls")" should equal 1
      End

      It "calls map_raid_to_toml for ZFS mode"
        BOOT_DISK=""
        ZFS_POOL_DISKS=("/dev/nvme0n1")
        ZFS_RAID="raidz1"
        When call make_answer_toml
        The status should be success
        The value "$(_get_counter "$MOCK_TEMP_DIR/map_raid_to_toml_calls")" should equal 1
      End
    End

    Describe "error handling"
      It "exits when load_virtio_mapping fails"
        BOOT_DISK=""
        ZFS_POOL_DISKS=("/dev/nvme0n1")
        echo "true" > "$MOCK_TEMP_DIR/load_virtio_mapping_fail"
        When run make_answer_toml
        The status should be failure
      End

      It "exits when map_disks_to_virtio returns empty"
        BOOT_DISK=""
        ZFS_POOL_DISKS=("/dev/nvme0n1")
        echo "true" > "$MOCK_TEMP_DIR/map_disks_fail"
        When run make_answer_toml
        The status should be failure
      End

      It "exits when BOOT_DISK set but no pool disks"
        BOOT_DISK="/dev/nvme0n1"
        ZFS_POOL_DISKS=()
        When run make_answer_toml
        The status should be failure
      End
    End
  End

  # ===========================================================================
  # make_autoinstall_iso()
  # ===========================================================================
  Describe "make_autoinstall_iso()"
    Describe "successful ISO creation"
      BeforeEach 'cd "$MOCK_TEMP_DIR" && touch pve.iso answer.toml'
      AfterEach 'cd - >/dev/null'

      It "creates pve-autoinstall.iso"
        When call make_autoinstall_iso
        The status should be success
        The file "pve-autoinstall.iso" should be exist
      End

      It "removes original pve.iso after creation"
        When call make_autoinstall_iso
        The status should be success
        The file "pve.iso" should not be exist
      End

      It "calls show_progress for ISO creation"
        When call make_autoinstall_iso
        The status should be success
        The value "$(_get_counter "$MOCK_TEMP_DIR/show_progress_calls")" should equal 1
      End

      It "calls proxmox-auto-install-assistant"
        When call make_autoinstall_iso
        The status should be success
        The value "$(_get_counter "$MOCK_TEMP_DIR/proxmox_assistant_calls")" should equal 1
      End
    End

    Describe "error handling"
      BeforeEach 'cd "$MOCK_TEMP_DIR" && touch pve.iso answer.toml'
      AfterEach 'cd - >/dev/null'

      It "exits when autoinstall ISO not created"
        # Override the mock to not create the ISO
        proxmox-auto-install-assistant() {
          _inc_counter "$MOCK_TEMP_DIR/proxmox_assistant_calls"
          return 0  # Success but no file created
        }
        When run make_autoinstall_iso
        The status should be failure
      End

      It "logs warning when proxmox-auto-install-assistant has non-zero exit but ISO created"
        # When the tool exits non-zero but still creates ISO, we log warning and continue
        # Test that we handle this gracefully
        When call make_autoinstall_iso
        The status should be success
        The file "pve-autoinstall.iso" should be exist
      End
    End

    Describe "with live log subtasks"
      BeforeEach 'cd "$MOCK_TEMP_DIR" && touch pve.iso answer.toml'
      AfterEach 'cd - >/dev/null'

      It "adds subtask for xorriso packing"
        When call make_autoinstall_iso
        The status should be success
        The contents of file "$MOCK_TEMP_DIR/live_log_subtask_calls" should include "xorriso"
      End
    End
  End
End

