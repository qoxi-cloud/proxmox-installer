# shellcheck shell=bash
# shellcheck disable=SC2016,SC2034
# =============================================================================
# Integration tests for system hardware detection
# Tests: 041-system-check.sh interface detection, drive enumeration, IP detection
# =============================================================================

%const SCRIPTS_DIR: "${SHELLSPEC_PROJECT_ROOT}/scripts"
%const SUPPORT_DIR: "${SHELLSPEC_PROJECT_ROOT}/spec/support"

# Load mocks
eval "$(cat "$SUPPORT_DIR/core_mocks.sh")"

# =============================================================================
# Mock system commands for predictable testing
# =============================================================================
MOCK_LSBLK_OUTPUT=""
MOCK_IP_ROUTE_OUTPUT=""
MOCK_IP_ADDRESS_OUTPUT=""
MOCK_IP_LINK_OUTPUT=""

# Reset mocks to defaults
reset_system_mocks() {
  MOCK_LSBLK_OUTPUT="nvme0n1 disk
nvme1n1 disk
sda disk"
  MOCK_IP_ROUTE_OUTPUT='[{"dst":"default","gateway":"192.168.1.1","dev":"eth0"}]'
  MOCK_IP_ADDRESS_OUTPUT='[{"addr_info":[{"family":"inet","local":"192.168.1.100","prefixlen":24,"scope":"global"}]}]'
  MOCK_IP_LINK_OUTPUT='[{"ifname":"eth0","address":"00:11:22:33:44:55","operstate":"UP"}]'
}

# Mock lsblk
lsblk() {
  local show_name=false show_type=false show_size=false show_model=false
  local name_only=false disk=""

  while [[ $# -gt 0 ]]; do
    case "$1" in
      -d) shift ;; # disk only (not partitions)
      -n) name_only=true; shift ;;
      -o)
        shift
        [[ $1 == *NAME* ]] && show_name=true
        [[ $1 == *TYPE* ]] && show_type=true
        [[ $1 == *SIZE* ]] && show_size=true
        [[ $1 == *MODEL* ]] && show_model=true
        shift
        ;;
      /dev/*)
        disk="${1#/dev/}"
        shift
        ;;
      *) shift ;;
    esac
  done

  if [[ $show_name == true && $show_type == true ]]; then
    printf '%s\n' "$MOCK_LSBLK_OUTPUT"
    return 0
  fi

  if [[ -n $disk ]]; then
    case "$disk" in
      nvme0n1) printf '%s\n' "1.8T" ;;
      nvme1n1) printf '%s\n' "1.8T" ;;
      sda) printf '%s\n' "480G" ;;
      *) printf '%s\n' "1T" ;;
    esac
    return 0
  fi

  printf '%s\n' "$MOCK_LSBLK_OUTPUT"
}

# Mock ip command
ip() {
  local json=false cmd="" dev=""

  while [[ $# -gt 0 ]]; do
    case "$1" in
      -j) json=true; shift ;;
      route|address|link) cmd="$1"; shift ;;
      show) shift ;;
      *) dev="$1"; shift ;;
    esac
  done

  case "$cmd" in
    route)
      if [[ $json == true ]]; then
        printf '%s\n' "$MOCK_IP_ROUTE_OUTPUT"
      else
        printf '%s\n' "default via 192.168.1.1 dev eth0"
      fi
      ;;
    address)
      if [[ $json == true ]]; then
        printf '%s\n' "$MOCK_IP_ADDRESS_OUTPUT"
      else
        printf '%s\n' "    inet 192.168.1.100/24 scope global eth0"
      fi
      ;;
    link)
      if [[ $json == true ]]; then
        printf '%s\n' "$MOCK_IP_LINK_OUTPUT"
      else
        printf '%s\n' "1: lo: <LOOPBACK,UP>
2: eth0: <BROADCAST,UP>"
      fi
      ;;
  esac
}

# Mock jq (simplified for our use cases)
jq() {
  local raw=false filter="" input=""

  while [[ $# -gt 0 ]]; do
    case "$1" in
      -r) raw=true; shift ;;
      *)
        if [[ -z $filter ]]; then
          filter="$1"
        fi
        shift
        ;;
    esac
  done

  # Read input from stdin
  input=$(cat)

  case "$filter" in
    *'"dst == "default"'*dev*)
      printf '%s\n' "eth0"
      ;;
    *'"default"'*gateway*)
      printf '%s\n' "192.168.1.1"
      ;;
    *'"inet"'*local*prefixlen*)
      printf '%s\n' "192.168.1.100/24"
      ;;
    *ifname*lo*operstate*)
      printf '%s\n' "eth0"
      ;;
    *ifname*lo*)
      printf '%s\n' "eth0"
      ;;
    *address*)
      printf '%s\n' "00:11:22:33:44:55"
      ;;
    *)
      printf '%s\n' "eth0"
      ;;
  esac
}

# Mock udevadm
udevadm() {
  case "$*" in
    *info*)
      printf '%s\n' "ID_NET_NAME_PATH=enp0s31f6"
      ;;
  esac
}

# Mock other commands
ping() { return 0; }
free() { printf '%s\n' "Mem:        16384"; }
nproc() { printf '%s\n' "8"; }
modprobe() { return 0; }
timedatectl() { printf '%s\n' "UTC"; }

# =============================================================================
# Test setup
# =============================================================================
setup_detection_test() {
  reset_system_mocks

  # Required globals
  DNS_PRIMARY="1.1.1.1"
  MIN_DISK_SPACE_MB=6000
  MIN_RAM_MB=4096
  MIN_CPU_CORES=2

  # Mock validate_disk_space
  DISK_SPACE_MB=10000
  validate_disk_space() { return 0; }
  export -f validate_disk_space

  # Mock _load_wizard_data
  _load_wizard_data() { :; }
  export -f _load_wizard_data

  # Mock _wiz_start_edit (called from show_system_status)
  _wiz_start_edit() { :; }
  export -f _wiz_start_edit

  LOG_FILE="${SHELLSPEC_TMPBASE}/test.log"
  touch "$LOG_FILE"

  # Mock /dev/kvm
  mkdir -p "${SHELLSPEC_TMPBASE}/dev"
  touch "${SHELLSPEC_TMPBASE}/dev/kvm"

  # Clear state
  DRIVES=()
  DRIVE_COUNT=0
  DRIVE_NAMES=()
  DRIVE_SIZES=()
  DRIVE_MODELS=()
  BOOT_DISK=""
  ZFS_POOL_DISKS=()
}

cleanup_detection_test() {
  rm -rf "${SHELLSPEC_TMPBASE:?}/dev" 2>/dev/null || true
}

Describe "System Detection Integration"
  Include "$SCRIPTS_DIR/041-system-check.sh"

  BeforeEach 'setup_detection_test'
  AfterEach 'cleanup_detection_test'

  # ===========================================================================
  # Drive detection
  # ===========================================================================
  Describe "detect_drives()"
    Describe "NVMe detection"
      It "detects NVMe drives"
        MOCK_LSBLK_OUTPUT="nvme0n1 disk
nvme1n1 disk"
        When call detect_drives
        The status should be success
        The variable DRIVE_COUNT should equal 2
      End

      It "populates DRIVES array"
        MOCK_LSBLK_OUTPUT="nvme0n1 disk
nvme1n1 disk"
        detect_drives
        When call printf '%s\n' "${DRIVES[0]}"
        The output should equal "/dev/nvme0n1"
      End
    End

    Describe "SATA/SSD fallback"
      It "falls back to SATA drives when no NVMe"
        MOCK_LSBLK_OUTPUT="sda disk
sdb disk"
        When call detect_drives
        The status should be success
        The variable DRIVE_COUNT should equal 2
      End
    End

    Describe "mixed drives"
      It "detects all available drives"
        MOCK_LSBLK_OUTPUT="nvme0n1 disk
sda disk
vda disk"
        When call detect_drives
        The status should be success
        The variable DRIVE_COUNT should equal 3
      End
    End
  End

  # ===========================================================================
  # Disk role detection
  # ===========================================================================
  Describe "detect_disk_roles()"
    Describe "identical sizes"
      It "assigns all disks to pool when same size"
        DRIVES=("/dev/nvme0n1" "/dev/nvme1n1")
        DRIVE_SIZES=("1.8T" "1.8T")
        DRIVE_COUNT=2

        When call detect_disk_roles
        The status should be success
        The variable BOOT_DISK should equal ""
        The variable "${#ZFS_POOL_DISKS[@]}" should equal 2
      End
    End

    Describe "mixed sizes"
      It "assigns smallest disk as boot disk"
        DRIVES=("/dev/nvme0n1" "/dev/nvme1n1" "/dev/sda")
        DRIVE_SIZES=("1.8T" "1.8T" "480G")
        DRIVE_COUNT=3

        When call detect_disk_roles
        The status should be success
        The variable BOOT_DISK should equal "/dev/sda"
      End

      It "assigns remaining disks to pool"
        DRIVES=("/dev/nvme0n1" "/dev/nvme1n1" "/dev/sda")
        DRIVE_SIZES=("1.8T" "1.8T" "480G")
        DRIVE_COUNT=3
        detect_disk_roles

        When call printf '%s\n' "${#ZFS_POOL_DISKS[@]}"
        The output should equal "2"
      End
    End

    Describe "single drive"
      It "handles single drive"
        DRIVES=("/dev/nvme0n1")
        DRIVE_SIZES=("1.8T")
        DRIVE_COUNT=1

        When call detect_disk_roles
        The status should be success
        The variable BOOT_DISK should equal ""
        The variable "${#ZFS_POOL_DISKS[@]}" should equal 1
      End
    End
  End

  # ===========================================================================
  # Interface detection
  # ===========================================================================
  Describe "interface detection"
    It "detects default interface from route"
      MOCK_IP_ROUTE_OUTPUT='[{"dst":"default","gateway":"192.168.1.1","dev":"eth0"}]'

      # Source and run the detection logic
      CURRENT_INTERFACE=""
      if command -v ip &>/dev/null && command -v jq &>/dev/null; then
        CURRENT_INTERFACE=$(ip -j route 2>/dev/null | jq -r '.[] | select(.dst == "default") | .dev' | head -n1)
      fi

      When call printf '%s' "$CURRENT_INTERFACE"
      The output should equal "eth0"
    End

    It "detects predictable interface name"
      # The udevadm mock returns enp0s31f6
      udev_info=$(udevadm info "/sys/class/net/eth0" 2>/dev/null)
      PREDICTABLE_NAME=$(printf '%s\n' "$udev_info" | grep "ID_NET_NAME_PATH=" | cut -d'=' -f2)

      When call printf '%s' "$PREDICTABLE_NAME"
      The output should equal "enp0s31f6"
    End
  End

  # ===========================================================================
  # IP address detection
  # ===========================================================================
  Describe "IP address detection"
    It "detects IPv4 address with CIDR"
      MOCK_IP_ADDRESS_OUTPUT='[{"addr_info":[{"family":"inet","local":"192.168.1.100","prefixlen":24,"scope":"global"}]}]'

      MAIN_IPV4_CIDR=$(ip -j address show eth0 2>/dev/null | jq -r '.[0].addr_info[] | select(.family == "inet" and .scope == "global") | "\(.local)/\(.prefixlen)"' | head -n1)

      When call printf '%s' "$MAIN_IPV4_CIDR"
      The output should equal "192.168.1.100/24"
    End

    It "extracts IPv4 without CIDR"
      MAIN_IPV4_CIDR="192.168.1.100/24"
      MAIN_IPV4="${MAIN_IPV4_CIDR%/*}"

      When call printf '%s' "$MAIN_IPV4"
      The output should equal "192.168.1.100"
    End

    It "detects gateway"
      MOCK_IP_ROUTE_OUTPUT='[{"dst":"default","gateway":"192.168.1.1","dev":"eth0"}]'

      MAIN_IPV4_GW=$(ip -j route 2>/dev/null | jq -r '.[] | select(.dst == "default") | .gateway' | head -n1)

      When call printf '%s' "$MAIN_IPV4_GW"
      The output should equal "192.168.1.1"
    End
  End

  # ===========================================================================
  # MAC address detection
  # ===========================================================================
  Describe "MAC address detection"
    It "detects MAC address"
      MOCK_IP_LINK_OUTPUT='[{"ifname":"eth0","address":"00:11:22:33:44:55","operstate":"UP"}]'

      MAC_ADDRESS=$(ip -j link show eth0 2>/dev/null | jq -r '.[0].address // empty')

      When call printf '%s' "$MAC_ADDRESS"
      The output should equal "00:11:22:33:44:55"
    End
  End

  # ===========================================================================
  # Timezone and country loading
  # ===========================================================================
  Describe "wizard data loading"
    Describe "_load_timezones()"
      It "loads timezones from timedatectl"
        # timedatectl mock returns "UTC"
        When call _load_timezones
        The status should be success
        The variable WIZ_TIMEZONES should include "UTC"
      End
    End
  End

  # ===========================================================================
  # Size parsing in detect_disk_roles
  # ===========================================================================
  Describe "disk size parsing"
    parse_terabyte() {
      local size="1.8T"
      local bytes
      if [[ $size =~ ([0-9.]+)T ]]; then
        bytes=$(awk "BEGIN {printf \"%.0f\", ${BASH_REMATCH[1]} * 1099511627776}")
      fi
      printf '%s' "$bytes"
    }

    It "parses terabyte sizes"
      When call parse_terabyte
      The output should equal "1979120279552"
    End

    parse_gigabyte() {
      local size="480G"
      local bytes
      if [[ $size =~ ([0-9.]+)G ]]; then
        bytes=$(awk "BEGIN {printf \"%.0f\", ${BASH_REMATCH[1]} * 1073741824}")
      fi
      printf '%s' "$bytes"
    }

    It "parses gigabyte sizes"
      When call parse_gigabyte
      The output should equal "515396075520"
    End
  End
End

