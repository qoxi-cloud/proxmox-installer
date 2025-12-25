# shellcheck shell=bash
# shellcheck disable=SC2016,SC2034
# =============================================================================
# Integration tests for ISO download pipeline
# Tests: 203-iso-download.sh fallback chain, checksum verification, retries
# =============================================================================

%const SCRIPTS_DIR: "${SHELLSPEC_PROJECT_ROOT}/scripts"
%const SUPPORT_DIR: "${SHELLSPEC_PROJECT_ROOT}/spec/support"

# Load mocks
eval "$(cat "$SUPPORT_DIR/core_mocks.sh")"

# =============================================================================
# Mock control variables for download tools
# =============================================================================
MOCK_ARIA2C_AVAILABLE=true
MOCK_ARIA2C_FAIL=false
MOCK_CURL_FAIL=false
MOCK_WGET_FAIL=false
MOCK_CHECKSUM_MATCH=true
MOCK_DOWNLOAD_METHOD=""
MOCK_DOWNLOAD_CALLS=()

# =============================================================================
# Reset mocks
# =============================================================================
reset_download_mocks() {
  MOCK_ARIA2C_AVAILABLE=true
  MOCK_ARIA2C_FAIL=false
  MOCK_CURL_FAIL=false
  MOCK_WGET_FAIL=false
  MOCK_CHECKSUM_MATCH=true
  MOCK_DOWNLOAD_METHOD=""
  MOCK_DOWNLOAD_CALLS=()
}

# =============================================================================
# Tool availability mocks
# =============================================================================
# Override command -v to control tool availability
_original_command() { command "$@"; }

# Mock aria2c
aria2c() {
  MOCK_DOWNLOAD_CALLS+=("aria2c")
  local output=""
  local checksum_arg=""

  while [[ $# -gt 0 ]]; do
    case "$1" in
      -o) output="$2"; shift 2 ;;
      --checksum=*) checksum_arg="$1"; shift ;;
      *) shift ;;
    esac
  done

  if [[ $MOCK_ARIA2C_FAIL == "true" ]]; then
    return 1
  fi

  if [[ -n $output ]]; then
    echo "mock iso content" >"$output"
  fi
  return 0
}

# Mock curl for downloads
curl() {
  local output=""
  local url=""
  local silent=false

  while [[ $# -gt 0 ]]; do
    case "$1" in
      -o) output="$2"; shift 2 ;;
      -s) silent=true; shift ;;
      -fSL|--retry-connrefused|-C) shift ;;
      --retry-delay*) shift ;;
      --retry*) shift ;;
      https*) url="$1"; shift ;;
      http*) url="$1"; shift ;;
      *) shift ;;
    esac
  done

  # Handle ISO list fetch (for prefetch)
  if [[ $url == *"iso/"* ]] && [[ -z $output ]]; then
    echo 'proxmox-ve_8.2-1.iso'
    echo 'proxmox-ve_8.3-1.iso'
    echo 'proxmox-ve_9.0-1.iso'
    echo 'proxmox-ve_9.1-1.iso'
    return 0
  fi

  # Handle checksum fetch
  if [[ $url == *"SHA256SUMS"* ]]; then
    echo "abc123def456 proxmox-ve_9.1-1.iso"
    return 0
  fi

  MOCK_DOWNLOAD_CALLS+=("curl")

  if [[ $MOCK_CURL_FAIL == "true" ]]; then
    return 1
  fi

  if [[ -n $output ]]; then
    echo "mock iso content" >"$output"
  fi
  return 0
}

# Mock wget
wget() {
  MOCK_DOWNLOAD_CALLS+=("wget")
  local output=""

  while [[ $# -gt 0 ]]; do
    case "$1" in
      -O) output="$2"; shift 2 ;;
      -q|--tries=*|--continue|--timeout=*|--waitretry=*) shift ;;
      *) shift ;;
    esac
  done

  if [[ $MOCK_WGET_FAIL == "true" ]]; then
    return 1
  fi

  if [[ -n $output ]]; then
    echo "mock iso content" >"$output"
  fi
  return 0
}

# Mock sha256sum
sha256sum() {
  local file="$1"
  if [[ $MOCK_CHECKSUM_MATCH == "true" ]]; then
    echo "abc123def456  $file"
  else
    echo "wrongchecksum  $file"
  fi
}

# =============================================================================
# Test setup
# =============================================================================
setup_download_test() {
  reset_download_mocks

  # Set required globals
  PROXMOX_ISO_BASE_URL="https://enterprise.proxmox.com/iso/"
  PROXMOX_CHECKSUM_URL="https://enterprise.proxmox.com/iso/SHA256SUMS"
  PROXMOX_ISO_VERSION="proxmox-ve_9.1-1.iso"
  LOG_FILE="${SHELLSPEC_TMPBASE}/test.log"
  touch "$LOG_FILE"

  # Mock live_log_subtask
  live_log_subtask() { :; }
  export -f live_log_subtask

  # Clean up any previous test files
  rm -f pve.iso pve-autoinstall.iso 2>/dev/null || true

  # Change to temp directory for file operations
  cd "${SHELLSPEC_TMPBASE}" || return 1
}

cleanup_download_test() {
  rm -f pve.iso pve-autoinstall.iso answer.toml 2>/dev/null || true
  cd - >/dev/null 2>&1 || true
}

Describe "ISO Download Integration"
  Include "$SCRIPTS_DIR/203-iso-download.sh"

  BeforeEach 'setup_download_test'
  AfterEach 'cleanup_download_test'

  # ===========================================================================
  # prefetch_proxmox_iso_info()
  # ===========================================================================
  Describe "prefetch_proxmox_iso_info()"
    It "populates ISO list cache"
      When call prefetch_proxmox_iso_info
      The status should be success
      The variable _ISO_LIST_CACHE should not equal ""
    End

    It "populates checksum cache"
      When call prefetch_proxmox_iso_info
      The status should be success
      The variable _CHECKSUM_CACHE should not equal ""
    End
  End

  # ===========================================================================
  # get_available_proxmox_isos()
  # ===========================================================================
  Describe "get_available_proxmox_isos()"
    BeforeEach 'prefetch_proxmox_iso_info'

    It "returns available ISO versions"
      When call get_available_proxmox_isos 3
      The status should be success
      The output should include "proxmox-ve_9"
    End

    It "filters to v9+ only"
      When call get_available_proxmox_isos 10
      The status should be success
      The output should not include "proxmox-ve_8"
    End
  End

  # ===========================================================================
  # get_iso_version()
  # ===========================================================================
  Describe "get_iso_version()"
    It "extracts version from ISO filename"
      When call get_iso_version "proxmox-ve_8.3-1.iso"
      The output should equal "8.3-1"
    End

    It "handles version 9.x"
      When call get_iso_version "proxmox-ve_9.1-1.iso"
      The output should equal "9.1-1"
    End
  End

  # ===========================================================================
  # _download_iso_with_fallback()
  # ===========================================================================
  Describe "_download_iso_with_fallback()"
    Describe "primary method (aria2c)"
      It "uses aria2c when available"
        method_file=$(mktemp)
        When call _download_iso_with_fallback "http://example.com/test.iso" "test.iso" "" "$method_file"
        The status should be success
        The file "test.iso" should be exist
        The contents of file "$method_file" should equal "aria2c"
        rm -f "$method_file" test.iso
      End

      It "creates output file with content"
        When call _download_iso_with_fallback "http://example.com/test.iso" "test.iso" "" ""
        The status should be success
        The file "test.iso" should be exist
        rm -f test.iso
      End
    End

    Describe "fallback chain"
      It "falls back to curl when aria2c fails"
        MOCK_ARIA2C_FAIL=true
        method_file=$(mktemp)

        When call _download_iso_with_fallback "http://example.com/test.iso" "test.iso" "" "$method_file"
        The status should be success
        The contents of file "$method_file" should equal "curl"
        rm -f "$method_file" test.iso
      End

      It "falls back to wget when both aria2c and curl fail"
        MOCK_ARIA2C_FAIL=true
        MOCK_CURL_FAIL=true
        method_file=$(mktemp)

        When call _download_iso_with_fallback "http://example.com/test.iso" "test.iso" "" "$method_file"
        The status should be success
        The contents of file "$method_file" should equal "wget"
        rm -f "$method_file" test.iso
      End

      It "fails when all methods fail"
        MOCK_ARIA2C_FAIL=true
        MOCK_CURL_FAIL=true
        MOCK_WGET_FAIL=true

        When call _download_iso_with_fallback "http://example.com/test.iso" "test.iso" "" ""
        The status should be failure
      End
    End

    Describe "download tracking"
      It "records all attempted methods"
        MOCK_ARIA2C_FAIL=true
        MOCK_CURL_FAIL=true

        _download_iso_with_fallback "http://example.com/test.iso" "test.iso" "" ""
        When call printf '%s\n' "${MOCK_DOWNLOAD_CALLS[*]}"
        The output should include "aria2c"
        The output should include "curl"
        The output should include "wget"
        rm -f test.iso
      End
    End
  End

  # ===========================================================================
  # Checksum verification
  # ===========================================================================
  Describe "checksum verification"
    It "validates matching checksum"
      MOCK_CHECKSUM_MATCH=true
      echo "test content" > test.iso

      result=$(sha256sum test.iso | awk '{print $1}')
      When call printf '%s' "$result"
      The output should equal "abc123def456"
      rm -f test.iso
    End

    It "detects mismatched checksum"
      MOCK_CHECKSUM_MATCH=false
      echo "test content" > test.iso

      result=$(sha256sum test.iso | awk '{print $1}')
      When call printf '%s' "$result"
      The output should equal "wrongchecksum"
      rm -f test.iso
    End
  End

  # ===========================================================================
  # download_proxmox_iso() - main entry point
  # ===========================================================================
  Describe "download_proxmox_iso()"
    BeforeEach 'prefetch_proxmox_iso_info'

    It "downloads ISO successfully"
      When call download_proxmox_iso
      The status should be success
      The file "pve.iso" should be exist
    End

    It "skips download when ISO exists"
      echo "existing iso" > pve.iso

      When call download_proxmox_iso
      The status should be success
      # Should not overwrite
      The contents of file "pve.iso" should equal "existing iso"
    End

    It "fails when PROXMOX_ISO_VERSION not set"
      unset PROXMOX_ISO_VERSION

      When run download_proxmox_iso
      The status should be failure
    End
  End
End

