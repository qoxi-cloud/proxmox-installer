# shellcheck shell=bash
# shellcheck disable=SC2016,SC2034,SC2154
# =============================================================================
# Tests for 203-iso-download.sh
# =============================================================================
# Note: SC2016 disabled - single quotes in ShellSpec hooks
#       SC2034 disabled - variables used by ShellSpec assertions
#       SC2154 disabled - variables set in mocks

%const SCRIPTS_DIR: "${SHELLSPEC_PROJECT_ROOT}/scripts"
%const SUPPORT_DIR: "${SHELLSPEC_PROJECT_ROOT}/spec/support"

# Load shared mocks
eval "$(cat "$SUPPORT_DIR/core_mocks.sh")"

# =============================================================================
# Mock control - use fixed path to avoid subshell variable issues
# =============================================================================
# Use a fixed path that's unique per test run
MOCK_TEMP_DIR="/tmp/iso_download_spec_$$"

# =============================================================================
# Reset mock state - MUST be called before each test
# =============================================================================
reset_iso_mocks() {
  # Clean up previous run
  rm -rf "$MOCK_TEMP_DIR" 2>/dev/null
  mkdir -p "$MOCK_TEMP_DIR"

  LOG_FILE="$MOCK_TEMP_DIR/test.log"
  touch "$LOG_FILE"

  # Reset tracking files
  echo "0" > "$MOCK_TEMP_DIR/curl_calls"
  echo "0" > "$MOCK_TEMP_DIR/wget_calls"
  echo "0" > "$MOCK_TEMP_DIR/aria2c_calls"
  echo "0" > "$MOCK_TEMP_DIR/sha256sum_calls"
  echo "0" > "$MOCK_TEMP_DIR/stat_calls"
  echo "false" > "$MOCK_TEMP_DIR/curl_fail"
  echo "false" > "$MOCK_TEMP_DIR/wget_fail"
  echo "false" > "$MOCK_TEMP_DIR/aria2c_fail"
  echo "false" > "$MOCK_TEMP_DIR/aria2c_available"
  echo "false" > "$MOCK_TEMP_DIR/wget_available"
  echo "false" > "$MOCK_TEMP_DIR/sha256_fail"
  : > "$MOCK_TEMP_DIR/log_calls"
  : > "$MOCK_TEMP_DIR/print_success_calls"
  : > "$MOCK_TEMP_DIR/print_warning_calls"
  : > "$MOCK_TEMP_DIR/live_log_subtask_calls"
  : > "$MOCK_TEMP_DIR/exit_code"
  : > "$MOCK_TEMP_DIR/curl_args"
  : > "$MOCK_TEMP_DIR/wget_args"
  : > "$MOCK_TEMP_DIR/aria2c_args"

  # Reset caches
  _ISO_LIST_CACHE=""
  _CHECKSUM_CACHE=""

  # Set constants
  PROXMOX_ISO_BASE_URL="https://enterprise.proxmox.com/iso/"
  PROXMOX_CHECKSUM_URL="https://enterprise.proxmox.com/iso/SHA256SUMS"
  DOWNLOAD_RETRY_COUNT=3
  DOWNLOAD_RETRY_DELAY=5

  # Default variables for download_proxmox_iso tests
  PROXMOX_ISO_VERSION=""
}

cleanup_iso_mocks() {
  rm -rf "$MOCK_TEMP_DIR" 2>/dev/null
  rm -f pve.iso /tmp/checksum_result 2>/dev/null
}

# Helper to increment counter in file
_inc_counter() {
  local file="$1"
  local val
  val=$(cat "$file" 2>/dev/null || echo 0)
  echo $((val + 1)) > "$file"
}

# =============================================================================
# Mock functions
# =============================================================================

# Override log to track calls
log() {
  echo "$*" >> "$MOCK_TEMP_DIR/log_calls"
}

# Override print_success to track calls
print_success() {
  echo "$*" >> "$MOCK_TEMP_DIR/print_success_calls"
}

# Override print_warning to track calls
print_warning() {
  echo "$*" >> "$MOCK_TEMP_DIR/print_warning_calls"
}

# Override show_progress to wait synchronously
show_progress() {
  local pid="$1"
  wait "$pid" 2>/dev/null
  return $?
}

# Mock live_log_subtask
live_log_subtask() {
  echo "$*" >> "$MOCK_TEMP_DIR/live_log_subtask_calls"
}

# Mock curl command
curl() {
  _inc_counter "$MOCK_TEMP_DIR/curl_calls"
  echo "$*" >> "$MOCK_TEMP_DIR/curl_args"
  if [[ "$(cat "$MOCK_TEMP_DIR/curl_fail")" == "true" ]]; then
    return 1
  fi
  # Parse args to find output file and handle different modes
  local output_file=""
  local silent=false
  while [[ $# -gt 0 ]]; do
    case "$1" in
      -o)
        output_file="$2"
        shift 2
        ;;
      -s) silent=true; shift ;;
      -C) shift 2 ;;  # Skip -C - (resume)
      -fSL | -f | -S | -L | --retry | --retry-delay | --retry-connrefused) shift ;;
      *) shift ;;
    esac
  done
  if [[ -n "$output_file" ]]; then
    mkdir -p "$(dirname "$output_file")"
    echo "mock iso content" > "$output_file"
  elif [[ "$silent" == "true" ]]; then
    # Simulating prefetch - return ISO list
    echo "proxmox-ve_8.3-1.iso"
    echo "proxmox-ve_9.0-1.iso"
    echo "proxmox-ve_9.1-1.iso"
    echo "proxmox-ve_9.2-1.iso"
  fi
  return 0
}

# Mock wget command
wget() {
  _inc_counter "$MOCK_TEMP_DIR/wget_calls"
  echo "$*" >> "$MOCK_TEMP_DIR/wget_args"
  if [[ "$(cat "$MOCK_TEMP_DIR/wget_fail")" == "true" ]]; then
    return 1
  fi
  # Parse args to find output file
  local output_file=""
  while [[ $# -gt 0 ]]; do
    case "$1" in
      -O)
        output_file="$2"
        shift 2
        ;;
      -q | --tries=* | --continue | --timeout=* | --waitretry=*) shift ;;
      *) shift ;;
    esac
  done
  if [[ -n "$output_file" ]]; then
    mkdir -p "$(dirname "$output_file")"
    echo "mock iso content via wget" > "$output_file"
  fi
  return 0
}

# Mock aria2c command
aria2c() {
  _inc_counter "$MOCK_TEMP_DIR/aria2c_calls"
  echo "$*" >> "$MOCK_TEMP_DIR/aria2c_args"
  if [[ "$(cat "$MOCK_TEMP_DIR/aria2c_fail")" == "true" ]]; then
    return 1
  fi
  # Parse args to find output file
  local output_file=""
  while [[ $# -gt 0 ]]; do
    case "$1" in
      -o)
        output_file="$2"
        shift 2
        ;;
      -x | -s | -k | --max-tries=* | --retry-wait=* | --timeout=* | \
      --connect-timeout=* | --max-connection-per-server=* | \
      --allow-overwrite=* | --auto-file-renaming=* | \
      --console-log-level=* | --summary-interval=* | --checksum=*) shift ;;
      *) shift ;;
    esac
  done
  if [[ -n "$output_file" ]]; then
    mkdir -p "$(dirname "$output_file")"
    echo "mock iso content via aria2c" > "$output_file"
  fi
  return 0
}

# Mock sha256sum
sha256sum() {
  _inc_counter "$MOCK_TEMP_DIR/sha256sum_calls"
  if [[ "$(cat "$MOCK_TEMP_DIR/sha256_fail" 2>/dev/null)" == "true" ]]; then
    echo "wrongchecksum  pve.iso"
  else
    echo "abc123def456  pve.iso"
  fi
  return 0
}

# Mock stat for file size
stat() {
  _inc_counter "$MOCK_TEMP_DIR/stat_calls"
  echo "1073741824"  # 1GB
  return 0
}

# Mock command -v for tool availability
command() {
  if [[ "$1" == "-v" ]]; then
    case "$2" in
      aria2c)
        [[ "$(cat "$MOCK_TEMP_DIR/aria2c_available" 2>/dev/null)" == "true" ]] && return 0 || return 1
        ;;
      wget)
        [[ "$(cat "$MOCK_TEMP_DIR/wget_available" 2>/dev/null)" == "true" ]] && return 0 || return 1
        ;;
      *)
        return 0
        ;;
    esac
  fi
  builtin command "$@"
}

# Mock exit to capture exit codes
exit() {
  echo "$1" > "$MOCK_TEMP_DIR/exit_code"
  return "${1:-0}"
}

# =============================================================================
# Setup functions for various test scenarios (defined at top level)
# =============================================================================

setup_iso_cache() {
  _ISO_LIST_CACHE="proxmox-ve_8.3-1.iso
proxmox-ve_9.0-1.iso
proxmox-ve_9.1-1.iso
proxmox-ve_9.2-1.iso
proxmox-ve_9.3-1.iso"
}

setup_v10_cache() {
  _ISO_LIST_CACHE="proxmox-ve_9.9-1.iso
proxmox-ve_10.0-1.iso
proxmox-ve_10.1-1.iso"
}

setup_empty_cache() {
  _ISO_LIST_CACHE=""
}

setup_curl_fail() {
  echo "true" > "$MOCK_TEMP_DIR/curl_fail"
}

setup_wget_fail() {
  echo "true" > "$MOCK_TEMP_DIR/wget_fail"
}

setup_aria2c_fail() {
  echo "true" > "$MOCK_TEMP_DIR/aria2c_fail"
}

setup_aria2c_available() {
  echo "true" > "$MOCK_TEMP_DIR/aria2c_available"
}

setup_wget_available() {
  echo "true" > "$MOCK_TEMP_DIR/wget_available"
}

setup_aria2c_fail_with_available() {
  echo "true" > "$MOCK_TEMP_DIR/aria2c_available"
  echo "true" > "$MOCK_TEMP_DIR/aria2c_fail"
}

setup_curl_fail_wget_available() {
  echo "true" > "$MOCK_TEMP_DIR/curl_fail"
  echo "true" > "$MOCK_TEMP_DIR/wget_available"
}

setup_all_fail() {
  echo "true" > "$MOCK_TEMP_DIR/aria2c_available"
  echo "true" > "$MOCK_TEMP_DIR/aria2c_fail"
  echo "true" > "$MOCK_TEMP_DIR/curl_fail"
  echo "true" > "$MOCK_TEMP_DIR/wget_available"
  echo "true" > "$MOCK_TEMP_DIR/wget_fail"
}

# Setup for download_proxmox_iso tests
setup_download_vars() {
  PROXMOX_ISO_VERSION="proxmox-ve_9.1-1.iso"
  _CHECKSUM_CACHE="abc123def456 proxmox-ve_9.1-1.iso"
}

setup_existing_iso() {
  PROXMOX_ISO_VERSION="proxmox-ve_9.1-1.iso"
  _CHECKSUM_CACHE="abc123def456 proxmox-ve_9.1-1.iso"
  echo "existing" > pve.iso
}

setup_no_version() {
  PROXMOX_ISO_VERSION=""
  _CHECKSUM_CACHE=""
}

setup_aria2c_download() {
  PROXMOX_ISO_VERSION="proxmox-ve_9.1-1.iso"
  _CHECKSUM_CACHE="abc123def456 proxmox-ve_9.1-1.iso"
  echo "true" > "$MOCK_TEMP_DIR/aria2c_available"
}

setup_checksum_mismatch() {
  PROXMOX_ISO_VERSION="proxmox-ve_9.1-1.iso"
  _CHECKSUM_CACHE="abc123def456 proxmox-ve_9.1-1.iso"
  echo "true" > "$MOCK_TEMP_DIR/sha256_fail"
}

setup_no_checksum() {
  PROXMOX_ISO_VERSION="proxmox-ve_9.1-1.iso"
  _CHECKSUM_CACHE=""
}

setup_download_failures() {
  PROXMOX_ISO_VERSION="proxmox-ve_9.1-1.iso"
  _CHECKSUM_CACHE="abc123def456 proxmox-ve_9.1-1.iso"
  echo "true" > "$MOCK_TEMP_DIR/curl_fail"
  echo "true" > "$MOCK_TEMP_DIR/wget_available"
  echo "true" > "$MOCK_TEMP_DIR/wget_fail"
}

Describe "203-iso-download.sh"
  Include "$SCRIPTS_DIR/203-iso-download.sh"

  BeforeEach 'reset_iso_mocks'
  AfterEach 'cleanup_iso_mocks'

  # ===========================================================================
  # prefetch_proxmox_iso_info()
  # ===========================================================================
  Describe "prefetch_proxmox_iso_info()"

    It "fetches ISO list and populates cache"
      When call prefetch_proxmox_iso_info
      The status should be success
      The variable _ISO_LIST_CACHE should not be blank
    End

    It "fetches checksums and populates cache"
      When call prefetch_proxmox_iso_info
      The status should be success
      The variable _CHECKSUM_CACHE should not be blank
    End

    It "calls curl twice for ISO list and checksums"
      When call prefetch_proxmox_iso_info
      The status should be success
      The contents of file "$MOCK_TEMP_DIR/curl_calls" should equal 2
    End

    It "handles curl failures gracefully"
      echo "true" > "$MOCK_TEMP_DIR/curl_fail"
      When call prefetch_proxmox_iso_info
      The status should be success
      The variable _ISO_LIST_CACHE should be blank
    End
  End

  # ===========================================================================
  # get_available_proxmox_isos()
  # ===========================================================================
  Describe "get_available_proxmox_isos()"

    BeforeEach 'setup_iso_cache'

    It "returns ISO filenames"
      When call get_available_proxmox_isos
      The status should be success
      The output should include "proxmox-ve_9"
    End

    It "filters to v9+ only"
      When call get_available_proxmox_isos 10
      The status should be success
      The output should not include "proxmox-ve_8"
    End

    It "returns newest first"
      When call get_available_proxmox_isos 2
      The status should be success
      The line 1 of output should equal "proxmox-ve_9.3-1.iso"
      The line 2 of output should equal "proxmox-ve_9.2-1.iso"
    End

    It "limits to requested count"
      When call get_available_proxmox_isos 2
      The status should be success
      The lines of output should equal 2
    End

    It "defaults to 5 versions"
      When call get_available_proxmox_isos
      The status should be success
      The lines of output should equal 4
    End

    Describe "with v10+ versions"
      BeforeEach 'setup_v10_cache'

      It "includes v10+ versions"
        When call get_available_proxmox_isos 5
        The status should be success
        The output should include "proxmox-ve_10"
      End
    End

    Describe "with empty cache"
      BeforeEach 'setup_empty_cache'

      It "returns empty output"
        When call get_available_proxmox_isos
        The status should be success
        The output should be blank
      End
    End
  End

  # ===========================================================================
  # get_proxmox_iso_url()
  # ===========================================================================
  Describe "get_proxmox_iso_url()"

    It "constructs full URL from filename"
      When call get_proxmox_iso_url "proxmox-ve_9.1-1.iso"
      The status should be success
      The output should equal "https://enterprise.proxmox.com/iso/proxmox-ve_9.1-1.iso"
    End

    It "works with different versions"
      When call get_proxmox_iso_url "proxmox-ve_8.3-1.iso"
      The status should be success
      The output should equal "https://enterprise.proxmox.com/iso/proxmox-ve_8.3-1.iso"
    End

    It "preserves filename exactly"
      When call get_proxmox_iso_url "proxmox-ve_10.0-2.iso"
      The status should be success
      The output should end with "/proxmox-ve_10.0-2.iso"
    End
  End

  # ===========================================================================
  # get_iso_version()
  # ===========================================================================
  Describe "get_iso_version()"

    It "extracts version from standard filename"
      When call get_iso_version "proxmox-ve_9.1-1.iso"
      The status should be success
      The output should equal "9.1-1"
    End

    It "extracts version with single digit patch"
      When call get_iso_version "proxmox-ve_8.3-1.iso"
      The status should be success
      The output should equal "8.3-1"
    End

    It "extracts version with double digit patch"
      When call get_iso_version "proxmox-ve_10.0-12.iso"
      The status should be success
      The output should equal "10.0-12"
    End

    It "handles two digit major version"
      When call get_iso_version "proxmox-ve_10.1-1.iso"
      The status should be success
      The output should equal "10.1-1"
    End
  End

  # ===========================================================================
  # _download_iso_curl()
  # ===========================================================================
  Describe "_download_iso_curl()"

    It "downloads file successfully"
      When call _download_iso_curl "http://example.com/test.iso" "$MOCK_TEMP_DIR/test.iso"
      The status should be success
      The file "$MOCK_TEMP_DIR/test.iso" should be exist
    End

    It "uses correct curl options"
      When call _download_iso_curl "http://example.com/test.iso" "$MOCK_TEMP_DIR/test.iso"
      The status should be success
      The contents of file "$MOCK_TEMP_DIR/curl_args" should include "-fSL"
      The contents of file "$MOCK_TEMP_DIR/curl_args" should include "--retry"
      The contents of file "$MOCK_TEMP_DIR/curl_args" should include "-C -"
    End

    It "logs download method"
      When call _download_iso_curl "http://example.com/test.iso" "$MOCK_TEMP_DIR/test.iso"
      The status should be success
      The contents of file "$MOCK_TEMP_DIR/log_calls" should include "curl"
    End

    It "uses retry settings"
      DOWNLOAD_RETRY_COUNT=5
      DOWNLOAD_RETRY_DELAY=10
      When call _download_iso_curl "http://example.com/test.iso" "$MOCK_TEMP_DIR/test.iso"
      The status should be success
      The contents of file "$MOCK_TEMP_DIR/curl_args" should include "--retry 5"
      The contents of file "$MOCK_TEMP_DIR/curl_args" should include "--retry-delay 10"
    End

    Describe "when curl fails"
      BeforeEach 'setup_curl_fail'

      It "returns failure"
        When call _download_iso_curl "http://example.com/test.iso" "$MOCK_TEMP_DIR/test.iso"
        The status should be failure
      End
    End
  End

  # ===========================================================================
  # _download_iso_wget()
  # ===========================================================================
  Describe "_download_iso_wget()"

    It "downloads file successfully"
      When call _download_iso_wget "http://example.com/test.iso" "$MOCK_TEMP_DIR/test.iso"
      The status should be success
      The file "$MOCK_TEMP_DIR/test.iso" should be exist
    End

    It "logs download method"
      When call _download_iso_wget "http://example.com/test.iso" "$MOCK_TEMP_DIR/test.iso"
      The status should be success
      The contents of file "$MOCK_TEMP_DIR/log_calls" should include "wget"
    End

    It "uses correct wget options"
      When call _download_iso_wget "http://example.com/test.iso" "$MOCK_TEMP_DIR/test.iso"
      The status should be success
      The contents of file "$MOCK_TEMP_DIR/wget_args" should include "-q"
      The contents of file "$MOCK_TEMP_DIR/wget_args" should include "--continue"
      The contents of file "$MOCK_TEMP_DIR/wget_args" should include "--tries="
    End

    Describe "when wget fails"
      BeforeEach 'setup_wget_fail'

      It "returns failure"
        When call _download_iso_wget "http://example.com/test.iso" "$MOCK_TEMP_DIR/test.iso"
        The status should be failure
      End
    End
  End

  # ===========================================================================
  # _download_iso_aria2c()
  # ===========================================================================
  Describe "_download_iso_aria2c()"

    It "downloads file successfully"
      When call _download_iso_aria2c "http://example.com/test.iso" "$MOCK_TEMP_DIR/test.iso" ""
      The status should be success
      The file "$MOCK_TEMP_DIR/test.iso" should be exist
    End

    It "logs download method"
      When call _download_iso_aria2c "http://example.com/test.iso" "$MOCK_TEMP_DIR/test.iso" ""
      The status should be success
      The contents of file "$MOCK_TEMP_DIR/log_calls" should include "aria2c"
    End

    It "uses parallel connections"
      When call _download_iso_aria2c "http://example.com/test.iso" "$MOCK_TEMP_DIR/test.iso" ""
      The status should be success
      The contents of file "$MOCK_TEMP_DIR/aria2c_args" should include "-x 4"
      The contents of file "$MOCK_TEMP_DIR/aria2c_args" should include "-s 4"
    End

    It "adds checksum verification when provided"
      When call _download_iso_aria2c "http://example.com/test.iso" "$MOCK_TEMP_DIR/test.iso" "abc123def456"
      The status should be success
      The contents of file "$MOCK_TEMP_DIR/aria2c_args" should include "--checksum=sha-256=abc123def456"
    End

    It "logs checksum auto-verification"
      When call _download_iso_aria2c "http://example.com/test.iso" "$MOCK_TEMP_DIR/test.iso" "abc123"
      The status should be success
      The contents of file "$MOCK_TEMP_DIR/log_calls" should include "verify checksum"
    End

    It "skips checksum arg when not provided"
      When call _download_iso_aria2c "http://example.com/test.iso" "$MOCK_TEMP_DIR/test.iso" ""
      The status should be success
      The contents of file "$MOCK_TEMP_DIR/aria2c_args" should not include "--checksum"
    End

    Describe "when aria2c fails"
      BeforeEach 'setup_aria2c_fail'

      It "returns failure"
        When call _download_iso_aria2c "http://example.com/test.iso" "$MOCK_TEMP_DIR/test.iso" ""
        The status should be failure
      End
    End
  End

  # ===========================================================================
  # _download_iso_with_fallback()
  # ===========================================================================
  Describe "_download_iso_with_fallback()"

    Describe "with aria2c available"
      BeforeEach 'setup_aria2c_available'

      It "tries aria2c first"
        When call _download_iso_with_fallback "http://example.com/test.iso" "$MOCK_TEMP_DIR/test.iso" "" ""
        The status should be success
        The contents of file "$MOCK_TEMP_DIR/aria2c_calls" should equal 1
      End

      It "writes method to file when provided"
        When call _download_iso_with_fallback "http://example.com/test.iso" "$MOCK_TEMP_DIR/test.iso" "" "$MOCK_TEMP_DIR/method"
        The status should be success
        The contents of file "$MOCK_TEMP_DIR/method" should equal "aria2c"
      End

      Describe "when aria2c fails"
        BeforeEach 'setup_aria2c_fail_with_available'

        It "falls back to curl"
          When call _download_iso_with_fallback "http://example.com/test.iso" "$MOCK_TEMP_DIR/test.iso" "" "$MOCK_TEMP_DIR/method"
          The status should be success
          The contents of file "$MOCK_TEMP_DIR/curl_calls" should equal 1
          The contents of file "$MOCK_TEMP_DIR/method" should equal "curl"
        End

        It "logs fallback attempt"
          When call _download_iso_with_fallback "http://example.com/test.iso" "$MOCK_TEMP_DIR/test.iso" "" ""
          The status should be success
          The contents of file "$MOCK_TEMP_DIR/log_calls" should include "failed"
        End
      End
    End

    Describe "without aria2c available"

      It "tries curl directly"
        When call _download_iso_with_fallback "http://example.com/test.iso" "$MOCK_TEMP_DIR/test.iso" "" "$MOCK_TEMP_DIR/method"
        The status should be success
        The contents of file "$MOCK_TEMP_DIR/curl_calls" should equal 1
        The contents of file "$MOCK_TEMP_DIR/method" should equal "curl"
      End

      It "skips aria2c"
        When call _download_iso_with_fallback "http://example.com/test.iso" "$MOCK_TEMP_DIR/test.iso" "" ""
        The status should be success
        The contents of file "$MOCK_TEMP_DIR/aria2c_calls" should equal 0
      End
    End

    Describe "when curl fails and wget available"
      BeforeEach 'setup_curl_fail_wget_available'

      It "falls back to wget"
        When call _download_iso_with_fallback "http://example.com/test.iso" "$MOCK_TEMP_DIR/test.iso" "" "$MOCK_TEMP_DIR/method"
        The status should be success
        The contents of file "$MOCK_TEMP_DIR/wget_calls" should equal 1
        The contents of file "$MOCK_TEMP_DIR/method" should equal "wget"
      End
    End

    Describe "when all methods fail"
      BeforeEach 'setup_all_fail'

      It "returns failure"
        When call _download_iso_with_fallback "http://example.com/test.iso" "$MOCK_TEMP_DIR/test.iso" "" ""
        The status should be failure
      End

      It "logs final failure"
        When call _download_iso_with_fallback "http://example.com/test.iso" "$MOCK_TEMP_DIR/test.iso" "" ""
        The status should be failure
        The contents of file "$MOCK_TEMP_DIR/log_calls" should include "All download methods failed"
      End

      It "tries all available methods"
        When call _download_iso_with_fallback "http://example.com/test.iso" "$MOCK_TEMP_DIR/test.iso" "" ""
        The status should be failure
        The contents of file "$MOCK_TEMP_DIR/aria2c_calls" should equal 1
        The contents of file "$MOCK_TEMP_DIR/curl_calls" should equal 1
        The contents of file "$MOCK_TEMP_DIR/wget_calls" should equal 1
      End
    End

    Describe "checksum handling"
      BeforeEach 'setup_aria2c_available'

      It "passes checksum to aria2c"
        When call _download_iso_with_fallback "http://example.com/test.iso" "$MOCK_TEMP_DIR/test.iso" "abc123checksum" ""
        The status should be success
        The contents of file "$MOCK_TEMP_DIR/aria2c_args" should include "abc123checksum"
      End
    End
  End

  # ===========================================================================
  # download_proxmox_iso()
  # ===========================================================================
  Describe "download_proxmox_iso()"

    Describe "when ISO already exists"
      BeforeEach 'setup_existing_iso'

      It "skips download"
        When call download_proxmox_iso
        The status should be success
        The contents of file "$MOCK_TEMP_DIR/curl_calls" should equal 0
      End

      It "logs skip message"
        When call download_proxmox_iso
        The status should be success
        The contents of file "$MOCK_TEMP_DIR/log_calls" should include "already exists"
      End

      It "calls print_success for skip"
        When call download_proxmox_iso
        The status should be success
        The contents of file "$MOCK_TEMP_DIR/print_success_calls" should include "already exists"
      End
    End

    Describe "when PROXMOX_ISO_VERSION not set"
      BeforeEach 'setup_no_version'

      It "exits with error"
        When call download_proxmox_iso
        The contents of file "$MOCK_TEMP_DIR/exit_code" should equal 1
      End

      It "logs error"
        When call download_proxmox_iso
        The contents of file "$MOCK_TEMP_DIR/log_calls" should include "PROXMOX_ISO_VERSION not set"
      End
    End

    Describe "successful download"
      BeforeEach 'setup_download_vars'

      It "logs start message"
        When call download_proxmox_iso
        The contents of file "$MOCK_TEMP_DIR/log_calls" should include "Starting Proxmox ISO download"
      End

      It "logs selected ISO"
        When call download_proxmox_iso
        The contents of file "$MOCK_TEMP_DIR/log_calls" should include "Using selected ISO: proxmox-ve_9.1-1.iso"
      End

      It "constructs correct URL"
        When call download_proxmox_iso
        The contents of file "$MOCK_TEMP_DIR/log_calls" should include "Found ISO URL:"
      End

      It "logs expected checksum"
        When call download_proxmox_iso
        The contents of file "$MOCK_TEMP_DIR/log_calls" should include "Expected checksum: abc123def456"
      End

      It "creates pve.iso file"
        When call download_proxmox_iso
        The file "pve.iso" should be exist
      End

      It "logs successful download method"
        When call download_proxmox_iso
        The contents of file "$MOCK_TEMP_DIR/log_calls" should include "Download successful via"
      End

      It "logs file size"
        When call download_proxmox_iso
        The contents of file "$MOCK_TEMP_DIR/log_calls" should include "ISO file size:"
      End
    End

    Describe "checksum verification"

      Describe "with curl download"
        BeforeEach 'setup_download_vars'

        It "performs manual checksum verification"
          When call download_proxmox_iso
          The status should be success
          The contents of file "$MOCK_TEMP_DIR/sha256sum_calls" should equal 1
        End

        It "logs verification"
          When call download_proxmox_iso
          The contents of file "$MOCK_TEMP_DIR/log_calls" should include "Verifying ISO checksum"
        End

        It "logs verification passed"
          When call download_proxmox_iso
          The contents of file "$MOCK_TEMP_DIR/log_calls" should include "Checksum verification passed"
        End
      End

      Describe "with aria2c download"
        BeforeEach 'setup_aria2c_download'

        It "skips manual checksum verification"
          When call download_proxmox_iso
          The status should be success
          The contents of file "$MOCK_TEMP_DIR/log_calls" should include "already verified by aria2c"
        End
      End

      Describe "when checksum mismatch"
        BeforeEach 'setup_checksum_mismatch'

        It "exits with error"
          When call download_proxmox_iso
          The contents of file "$MOCK_TEMP_DIR/exit_code" should equal 1
        End

        It "logs mismatch error"
          When call download_proxmox_iso
          The contents of file "$MOCK_TEMP_DIR/log_calls" should include "Checksum mismatch"
        End

        It "removes corrupt file"
          When call download_proxmox_iso
          The file "pve.iso" should not be exist
        End
      End

      Describe "when no checksum available"
        BeforeEach 'setup_no_checksum'

        It "warns about missing checksum"
          When call download_proxmox_iso
          The contents of file "$MOCK_TEMP_DIR/log_calls" should include "Could not find checksum"
        End

        It "still succeeds without checksum"
          When call download_proxmox_iso
          The status should be success
        End

        It "calls print_warning"
          When call download_proxmox_iso
          The contents of file "$MOCK_TEMP_DIR/print_warning_calls" should include "Could not find checksum"
        End
      End
    End

    Describe "download failures"
      BeforeEach 'setup_download_failures'

      It "exits with error when all methods fail"
        When call download_proxmox_iso
        The contents of file "$MOCK_TEMP_DIR/exit_code" should equal 1
      End

      It "logs error"
        When call download_proxmox_iso
        The contents of file "$MOCK_TEMP_DIR/log_calls" should include "All download methods failed"
      End

      It "cleans up partial file"
        When call download_proxmox_iso
        The file "pve.iso" should not be exist
      End
    End

    Describe "cleanup"
      BeforeEach 'setup_download_vars'

      It "logs cleanup of temp files"
        When call download_proxmox_iso
        The contents of file "$MOCK_TEMP_DIR/log_calls" should include "Cleaning up temporary files"
      End

      It "logs cleanup complete"
        When call download_proxmox_iso
        The contents of file "$MOCK_TEMP_DIR/log_calls" should include "Temporary files cleaned"
      End
    End

    Describe "live logging"

      Describe "with aria2c verified checksum"
        BeforeEach 'setup_aria2c_download'

        It "logs aria2c verification to live log"
          When call download_proxmox_iso
          The contents of file "$MOCK_TEMP_DIR/live_log_subtask_calls" should include "verified by aria2c"
        End
      End

      Describe "with manual checksum"
        BeforeEach 'setup_download_vars'

        It "logs OK to live log on success"
          When call download_proxmox_iso
          The contents of file "$MOCK_TEMP_DIR/live_log_subtask_calls" should include "SHA256: OK"
        End
      End

      Describe "on checksum failure"
        BeforeEach 'setup_checksum_mismatch'

        It "logs FAILED to live log"
          When call download_proxmox_iso
          The contents of file "$MOCK_TEMP_DIR/live_log_subtask_calls" should include "SHA256: FAILED"
        End
      End
    End
  End
End
