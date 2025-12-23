# shellcheck shell=bash
# shellcheck disable=SC2034,SC2317
# =============================================================================
# System check mocks for testing system detection functions
# =============================================================================
# Note: SC2034 disabled - variables used by spec files
# Note: SC2317 disabled - unreachable code (mock functions defined for later use)
#
# Usage in spec files:
#   %const SUPPORT_DIR: "${SHELLSPEC_PROJECT_ROOT}/spec/support"
#   eval "$(cat "$SUPPORT_DIR/system_check_mocks.sh")"
#   BeforeEach 'reset_system_check_mocks'

# =============================================================================
# Mock control variables
# =============================================================================
MOCK_LSBLK_DISKS=()
MOCK_LSBLK_SIZES=()
MOCK_LSBLK_MODELS=()
MOCK_NPROC=4
MOCK_FREE_MB=16000
MOCK_PING_RESULT=0
MOCK_EUID=0

# =============================================================================
# Reset mock state
# =============================================================================
reset_system_check_mocks() {
  MOCK_LSBLK_DISKS=()
  MOCK_LSBLK_SIZES=()
  MOCK_LSBLK_MODELS=()
  MOCK_NPROC=4
  MOCK_FREE_MB=16000
  MOCK_PING_RESULT=0
  MOCK_EUID=0
}

# =============================================================================
# lsblk mock for disk detection
# =============================================================================
mock_lsblk() {
  case "$*" in
    *"-d -n -o NAME,TYPE"*"nvme"*)
      # NVMe-specific query
      for i in "${!MOCK_LSBLK_DISKS[@]}"; do
        if [[ "${MOCK_LSBLK_DISKS[$i]}" == *"nvme"* ]]; then
          local name="${MOCK_LSBLK_DISKS[$i]#/dev/}"
          echo "$name disk"
        fi
      done
      ;;
    *"-d -n -o NAME,TYPE"*)
      # All disks query
      for i in "${!MOCK_LSBLK_DISKS[@]}"; do
        local name="${MOCK_LSBLK_DISKS[$i]#/dev/}"
        echo "$name disk"
      done
      ;;
    *"-d -n -o SIZE"*)
      # Extract device from args
      local dev=""
      for arg in "$@"; do
        if [[ "$arg" == /dev/* ]]; then
          dev="$arg"
          break
        fi
      done
      for i in "${!MOCK_LSBLK_DISKS[@]}"; do
        if [[ "${MOCK_LSBLK_DISKS[$i]}" == "$dev" ]]; then
          echo "${MOCK_LSBLK_SIZES[$i]:-1T}"
          return
        fi
      done
      echo "1T"
      ;;
    *"-d -n -o MODEL"*)
      # Extract device from args
      local dev=""
      for arg in "$@"; do
        if [[ "$arg" == /dev/* ]]; then
          dev="$arg"
          break
        fi
      done
      for i in "${!MOCK_LSBLK_DISKS[@]}"; do
        if [[ "${MOCK_LSBLK_DISKS[$i]}" == "$dev" ]]; then
          echo "${MOCK_LSBLK_MODELS[$i]:-Unknown}"
          return
        fi
      done
      echo "Unknown"
      ;;
  esac
}

# =============================================================================
# nproc mock for CPU core count
# =============================================================================
mock_nproc() {
  echo "$MOCK_NPROC"
}

# =============================================================================
# free mock for RAM detection
# =============================================================================
mock_free() {
  echo "Mem:         ${MOCK_FREE_MB}        $((MOCK_FREE_MB / 2))        $((MOCK_FREE_MB / 2))"
}

# =============================================================================
# ping mock for network detection
# =============================================================================
mock_ping() {
  return "$MOCK_PING_RESULT"
}

# =============================================================================
# timedatectl mock for timezone loading
# =============================================================================
MOCK_TIMEZONES="America/New_York
Europe/London
Asia/Tokyo
UTC"

mock_timedatectl() {
  if [[ "$1" == "list-timezones" ]]; then
    echo "$MOCK_TIMEZONES"
  fi
}

# =============================================================================
# locale mock for country loading fallback
# =============================================================================
MOCK_LOCALES="en_US.UTF-8
de_DE.UTF-8
fr_FR.UTF-8"

mock_locale() {
  if [[ "$1" == "-a" ]]; then
    echo "$MOCK_LOCALES"
  fi
}

# =============================================================================
# Apply system check mocks - replaces production functions
# =============================================================================
apply_system_check_mocks() {
  lsblk() { mock_lsblk "$@"; }
  nproc() { mock_nproc "$@"; }
  free() { mock_free "$@"; }
  ping() { mock_ping "$@"; }
  timedatectl() { mock_timedatectl "$@"; }
  locale() { mock_locale "$@"; }
  export -f lsblk nproc free ping timedatectl locale 2>/dev/null || true
}

# =============================================================================
# Helper: Setup mock disks
# =============================================================================
setup_mock_disks() {
  local count="${1:-2}"
  MOCK_LSBLK_DISKS=()
  MOCK_LSBLK_SIZES=()
  MOCK_LSBLK_MODELS=()
  for ((i = 0; i < count; i++)); do
    MOCK_LSBLK_DISKS+=("/dev/nvme${i}n1")
    MOCK_LSBLK_SIZES+=("1T")
    MOCK_LSBLK_MODELS+=("Samsung SSD $i")
  done
}

