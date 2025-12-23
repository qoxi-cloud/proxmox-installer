# shellcheck shell=bash
# shellcheck disable=SC2016,SC2034,SC2154
# =============================================================================
# Tests for 200-packages.sh
# =============================================================================
# Note: SC2016 disabled - single quotes in ShellSpec hooks
#       SC2034 disabled - variables used by ShellSpec assertions
#       SC2154 disabled - variables set in mocks

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
reset_packages_mocks() {
  # Create temp directory for file operations and tracking
  MOCK_TEMP_DIR=$(mktemp -d)
  mkdir -p "$MOCK_TEMP_DIR/etc/apt/sources.list.d"
  mkdir -p "$MOCK_TEMP_DIR/etc/apt/trusted.gpg.d"
  LOG_FILE="$MOCK_TEMP_DIR/test.log"
  touch "$LOG_FILE"

  # Reset tracking files
  echo "0" > "$MOCK_TEMP_DIR/curl_calls"
  echo "0" > "$MOCK_TEMP_DIR/apt_clean_calls"
  echo "0" > "$MOCK_TEMP_DIR/apt_update_calls"
  echo "0" > "$MOCK_TEMP_DIR/apt_install_calls"
  echo "false" > "$MOCK_TEMP_DIR/curl_fail"
  echo "false" > "$MOCK_TEMP_DIR/apt_update_fail"
  echo "false" > "$MOCK_TEMP_DIR/apt_install_fail"
  : > "$MOCK_TEMP_DIR/log_calls"
  : > "$MOCK_TEMP_DIR/print_error_calls"
  : > "$MOCK_TEMP_DIR/live_log_subtask_calls"
  : > "$MOCK_TEMP_DIR/exit_code"
}

cleanup_packages_mocks() {
  [[ -n "$MOCK_TEMP_DIR" ]] && rm -rf "$MOCK_TEMP_DIR"
}

# =============================================================================
# Mock functions (use file-based state for subshell persistence)
# =============================================================================

# Override log to track calls
log() {
  echo "$*" >> "$MOCK_TEMP_DIR/log_calls"
}

# Override print_error to track calls
print_error() {
  echo "$*" >> "$MOCK_TEMP_DIR/print_error_calls"
}

# Override show_progress to wait synchronously
show_progress() {
  local pid="$1"
  wait "$pid" 2>/dev/null
  return $?
}

# Mock curl command
curl() {
  local val
  val=$(cat "$MOCK_TEMP_DIR/curl_calls" 2>/dev/null || echo 0)
  echo $((val + 1)) > "$MOCK_TEMP_DIR/curl_calls"
  if [[ "$(cat "$MOCK_TEMP_DIR/curl_fail")" == "true" ]]; then
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
      -fsSL | -f | -s | -S | -L) shift ;;
      *) shift ;;
    esac
  done
  if [[ -n "$output_file" ]]; then
    mkdir -p "$(dirname "$output_file")"
    echo "mock gpg key content" > "$output_file"
  fi
  return 0
}

# Mock apt command
apt() {
  local subcommand="$1"
  local val
  shift
  case "$subcommand" in
    clean)
      val=$(cat "$MOCK_TEMP_DIR/apt_clean_calls" 2>/dev/null || echo 0)
      echo $((val + 1)) > "$MOCK_TEMP_DIR/apt_clean_calls"
      return 0
      ;;
    update)
      val=$(cat "$MOCK_TEMP_DIR/apt_update_calls" 2>/dev/null || echo 0)
      echo $((val + 1)) > "$MOCK_TEMP_DIR/apt_update_calls"
      [[ "$(cat "$MOCK_TEMP_DIR/apt_update_fail")" == "true" ]] && return 1
      return 0
      ;;
    install)
      val=$(cat "$MOCK_TEMP_DIR/apt_install_calls" 2>/dev/null || echo 0)
      echo $((val + 1)) > "$MOCK_TEMP_DIR/apt_install_calls"
      [[ "$(cat "$MOCK_TEMP_DIR/apt_install_fail")" == "true" ]] && return 1
      return 0
      ;;
    *)
      return 0
      ;;
  esac
}

# Mock exit to capture exit codes
exit() {
  echo "$1" > "$MOCK_TEMP_DIR/exit_code"
  return "${1:-0}"
}

# Mock live_log_subtask
live_log_subtask() {
  echo "$*" >> "$MOCK_TEMP_DIR/live_log_subtask_calls"
}

# =============================================================================
# Test version of prepare_packages using temp paths
# =============================================================================
# shellcheck disable=SC2317
_test_prepare_packages() {
  log "Starting package preparation"

  log "Adding Proxmox repository"
  printf '%s\n' "deb http://download.proxmox.com/debian/pve bookworm pve-no-subscription" >"$MOCK_TEMP_DIR/etc/apt/sources.list.d/pve.list"

  log "Downloading Proxmox GPG key"
  curl -fsSL -o "$MOCK_TEMP_DIR/etc/apt/trusted.gpg.d/proxmox-release-bookworm.gpg" https://enterprise.proxmox.com/debian/proxmox-release-bookworm.gpg >>"$LOG_FILE" 2>&1 &
  show_progress $! "Adding Proxmox repository" "Proxmox repository added"
  wait $!
  local exit_code=$?
  if [[ $exit_code -ne 0 ]]; then
    log "ERROR: Failed to download Proxmox GPG key"
    print_error "Cannot reach Proxmox repository"
    exit 1
    return 1
  fi
  log "Proxmox GPG key downloaded successfully"

  if type live_log_subtask &>/dev/null 2>&1; then
    live_log_subtask "Configuring APT sources"
  fi

  log "Updating package lists"
  apt clean >>"$LOG_FILE" 2>&1
  apt update >>"$LOG_FILE" 2>&1 &
  show_progress $! "Updating package lists" "Package lists updated"
  wait $!
  exit_code=$?
  if [[ $exit_code -ne 0 ]]; then
    log "ERROR: Failed to update package lists"
    exit 1
    return 1
  fi
  log "Package lists updated successfully"

  if type live_log_subtask &>/dev/null 2>&1; then
    live_log_subtask "Downloading package lists"
  fi

  log "Installing required packages: proxmox-auto-install-assistant xorriso ovmf wget sshpass"
  apt install -yq proxmox-auto-install-assistant xorriso ovmf wget sshpass >>"$LOG_FILE" 2>&1 &
  show_progress $! "Installing required packages" "Required packages installed"
  wait $!
  exit_code=$?
  if [[ $exit_code -ne 0 ]]; then
    log "ERROR: Failed to install required packages"
    exit 1
    return 1
  fi
  log "Required packages installed successfully"

  if type live_log_subtask &>/dev/null 2>&1; then
    live_log_subtask "Installing proxmox-auto-install-assistant"
    live_log_subtask "Installing xorriso and ovmf"
  fi
}

Describe "200-packages.sh"
  Include "$SCRIPTS_DIR/200-packages.sh"

  BeforeEach 'reset_packages_mocks'
  AfterEach 'cleanup_packages_mocks'

  # ===========================================================================
  # prepare_packages()
  # ===========================================================================
  Describe "prepare_packages()"

    Describe "successful execution"
      It "completes all steps and calls curl"
        When call _test_prepare_packages
        The status should be success
        The contents of file "$MOCK_TEMP_DIR/curl_calls" should equal 1
      End

      It "calls apt clean"
        When call _test_prepare_packages
        The status should be success
        The contents of file "$MOCK_TEMP_DIR/apt_clean_calls" should equal 1
      End

      It "calls apt update"
        When call _test_prepare_packages
        The status should be success
        The contents of file "$MOCK_TEMP_DIR/apt_update_calls" should equal 1
      End

      It "calls apt install"
        When call _test_prepare_packages
        The status should be success
        The contents of file "$MOCK_TEMP_DIR/apt_install_calls" should equal 1
      End

      It "logs start message"
        When call _test_prepare_packages
        The status should be success
        The contents of file "$MOCK_TEMP_DIR/log_calls" should include "Starting package preparation"
      End

      It "logs repository addition"
        When call _test_prepare_packages
        The status should be success
        The contents of file "$MOCK_TEMP_DIR/log_calls" should include "Adding Proxmox repository"
      End

      It "logs GPG key download"
        When call _test_prepare_packages
        The status should be success
        The contents of file "$MOCK_TEMP_DIR/log_calls" should include "Downloading Proxmox GPG key"
      End

      It "logs GPG key success"
        When call _test_prepare_packages
        The status should be success
        The contents of file "$MOCK_TEMP_DIR/log_calls" should include "Proxmox GPG key downloaded successfully"
      End

      It "logs package list update"
        When call _test_prepare_packages
        The status should be success
        The contents of file "$MOCK_TEMP_DIR/log_calls" should include "Updating package lists"
      End

      It "logs package list update success"
        When call _test_prepare_packages
        The status should be success
        The contents of file "$MOCK_TEMP_DIR/log_calls" should include "Package lists updated successfully"
      End

      It "logs package installation"
        When call _test_prepare_packages
        The status should be success
        The contents of file "$MOCK_TEMP_DIR/log_calls" should include "Installing required packages: proxmox-auto-install-assistant xorriso ovmf wget sshpass"
      End

      It "logs package installation success"
        When call _test_prepare_packages
        The status should be success
        The contents of file "$MOCK_TEMP_DIR/log_calls" should include "Required packages installed successfully"
      End

      It "calls live_log_subtask for APT sources"
        When call _test_prepare_packages
        The status should be success
        The contents of file "$MOCK_TEMP_DIR/live_log_subtask_calls" should include "Configuring APT sources"
      End

      It "calls live_log_subtask for downloading package lists"
        When call _test_prepare_packages
        The status should be success
        The contents of file "$MOCK_TEMP_DIR/live_log_subtask_calls" should include "Downloading package lists"
      End

      It "calls live_log_subtask for installing packages"
        When call _test_prepare_packages
        The status should be success
        The contents of file "$MOCK_TEMP_DIR/live_log_subtask_calls" should include "Installing proxmox-auto-install-assistant"
      End

      It "calls live_log_subtask for xorriso and ovmf"
        When call _test_prepare_packages
        The status should be success
        The contents of file "$MOCK_TEMP_DIR/live_log_subtask_calls" should include "Installing xorriso and ovmf"
      End

      It "writes Proxmox repository to sources list"
        When call _test_prepare_packages
        The status should be success
        The file "$MOCK_TEMP_DIR/etc/apt/sources.list.d/pve.list" should be exist
        The contents of file "$MOCK_TEMP_DIR/etc/apt/sources.list.d/pve.list" should include "download.proxmox.com"
      End

      It "writes correct repository line"
        When call _test_prepare_packages
        The status should be success
        The contents of file "$MOCK_TEMP_DIR/etc/apt/sources.list.d/pve.list" should equal "deb http://download.proxmox.com/debian/pve bookworm pve-no-subscription"
      End

      It "downloads GPG key to correct location"
        When call _test_prepare_packages
        The status should be success
        The file "$MOCK_TEMP_DIR/etc/apt/trusted.gpg.d/proxmox-release-bookworm.gpg" should be exist
      End
    End

    Describe "curl failures"
      BeforeEach 'echo "true" > "$MOCK_TEMP_DIR/curl_fail"'

      It "returns failure when curl fails"
        When call _test_prepare_packages
        The status should be failure
      End

      It "logs error when curl fails"
        When call _test_prepare_packages
        The status should be failure
        The contents of file "$MOCK_TEMP_DIR/log_calls" should include "ERROR: Failed to download Proxmox GPG key"
      End

      It "calls print_error when curl fails"
        When call _test_prepare_packages
        The status should be failure
        The contents of file "$MOCK_TEMP_DIR/print_error_calls" should include "Cannot reach Proxmox repository"
      End

      It "does not proceed to apt update when curl fails"
        When call _test_prepare_packages
        The status should be failure
        The contents of file "$MOCK_TEMP_DIR/apt_update_calls" should equal 0
      End

      It "does not proceed to apt install when curl fails"
        When call _test_prepare_packages
        The status should be failure
        The contents of file "$MOCK_TEMP_DIR/apt_install_calls" should equal 0
      End

      It "sets exit code to 1 when curl fails"
        When call _test_prepare_packages
        The status should be failure
        The contents of file "$MOCK_TEMP_DIR/exit_code" should equal 1
      End
    End

    Describe "apt update failures"
      BeforeEach 'echo "true" > "$MOCK_TEMP_DIR/apt_update_fail"'

      It "returns failure when apt update fails"
        When call _test_prepare_packages
        The status should be failure
      End

      It "logs error when apt update fails"
        When call _test_prepare_packages
        The status should be failure
        The contents of file "$MOCK_TEMP_DIR/log_calls" should include "ERROR: Failed to update package lists"
      End

      It "does not proceed to apt install when apt update fails"
        When call _test_prepare_packages
        The status should be failure
        The contents of file "$MOCK_TEMP_DIR/apt_install_calls" should equal 0
      End

      It "still calls apt clean before update"
        When call _test_prepare_packages
        The status should be failure
        The contents of file "$MOCK_TEMP_DIR/apt_clean_calls" should equal 1
      End

      It "still calls curl before update"
        When call _test_prepare_packages
        The status should be failure
        The contents of file "$MOCK_TEMP_DIR/curl_calls" should equal 1
      End

      It "sets exit code to 1 when apt update fails"
        When call _test_prepare_packages
        The status should be failure
        The contents of file "$MOCK_TEMP_DIR/exit_code" should equal 1
      End
    End

    Describe "apt install failures"
      BeforeEach 'echo "true" > "$MOCK_TEMP_DIR/apt_install_fail"'

      It "returns failure when apt install fails"
        When call _test_prepare_packages
        The status should be failure
      End

      It "logs error when apt install fails"
        When call _test_prepare_packages
        The status should be failure
        The contents of file "$MOCK_TEMP_DIR/log_calls" should include "ERROR: Failed to install required packages"
      End

      It "completes apt update before install failure"
        When call _test_prepare_packages
        The status should be failure
        The contents of file "$MOCK_TEMP_DIR/apt_update_calls" should equal 1
      End

      It "completes apt clean before install failure"
        When call _test_prepare_packages
        The status should be failure
        The contents of file "$MOCK_TEMP_DIR/apt_clean_calls" should equal 1
      End

      It "completes curl before install failure"
        When call _test_prepare_packages
        The status should be failure
        The contents of file "$MOCK_TEMP_DIR/curl_calls" should equal 1
      End

      It "sets exit code to 1 when apt install fails"
        When call _test_prepare_packages
        The status should be failure
        The contents of file "$MOCK_TEMP_DIR/exit_code" should equal 1
      End
    End

    Describe "execution order verification"
      It "calls all commands in correct order on success"
        When call _test_prepare_packages
        The status should be success
        The contents of file "$MOCK_TEMP_DIR/curl_calls" should equal 1
        The contents of file "$MOCK_TEMP_DIR/apt_clean_calls" should equal 1
        The contents of file "$MOCK_TEMP_DIR/apt_update_calls" should equal 1
        The contents of file "$MOCK_TEMP_DIR/apt_install_calls" should equal 1
      End
    End
  End
End
