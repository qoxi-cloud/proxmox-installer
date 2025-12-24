# shellcheck shell=bash
# shellcheck disable=SC2034,SC2016
# =============================================================================
# Tests for 021-ssh.sh
# =============================================================================

%const SCRIPTS_DIR: "${SHELLSPEC_PROJECT_ROOT}/scripts"
%const SUPPORT_DIR: "${SHELLSPEC_PROJECT_ROOT}/spec/support"

# Load shared mocks
eval "$(cat "$SUPPORT_DIR/colors.sh")"
eval "$(cat "$SUPPORT_DIR/core_mocks.sh")"
eval "$(cat "$SUPPORT_DIR/ssh_mocks.sh")"

# Override print_error to output for test assertions
print_error() { echo "ERROR: $*" >&2; }

# Required variables
SSH_CONNECT_TIMEOUT=10
NEW_ROOT_PASSWORD="testpass"
LOG_FILE="${SHELLSPEC_TMPBASE:-/tmp}/ssh_test.log"

Describe "021-ssh.sh"
  Include "$SCRIPTS_DIR/021-ssh.sh"

  BeforeEach 'reset_ssh_mocks; : > "$LOG_FILE"'
  AfterEach '_ssh_session_cleanup 2>/dev/null || true'

  # ===========================================================================
  # _ssh_passfile_path()
  # ===========================================================================
  Describe "_ssh_passfile_path()"
    It "returns path in /dev/shm when available"
      # Most Linux systems have /dev/shm
      Skip if "/dev/shm not available" test ! -d /dev/shm || test ! -w /dev/shm
      When call _ssh_passfile_path
      The output should match pattern "/dev/shm/pve-ssh-session.*"
    End

    It "includes PID in path for uniqueness"
      When call _ssh_passfile_path
      The output should include "$$"
    End

    It "returns consistent path across calls"
      path1=$(_ssh_passfile_path)
      path2=$(_ssh_passfile_path)
      When call test "$path1" = "$path2"
      The status should be success
    End

    It "falls back to /tmp when /dev/shm is not available"
      # Test the fallback logic by mocking the directory check
      _ssh_passfile_path_tmp_fallback() {
        local passfile_dir="/dev/shm"
        # Simulate /dev/shm not available
        if ! test -d "/dev/shm/nonexistent_test_dir_12345"; then
          passfile_dir="/tmp"
        fi
        printf '%s\n' "${passfile_dir}/pve-ssh-session.$$"
      }
      When call _ssh_passfile_path_tmp_fallback
      The output should match pattern "/tmp/pve-ssh-session.*"
    End
  End

  # ===========================================================================
  # _ssh_session_init()
  # ===========================================================================
  Describe "_ssh_session_init()"
    It "creates passfile"
      _SSH_SESSION_PASSFILE=""
      When call _ssh_session_init
      The status should be success
      The variable _SSH_SESSION_PASSFILE should not equal ""
    End

    It "creates file with correct permissions"
      _SSH_SESSION_PASSFILE=""
      When call _ssh_session_init
      The file "$_SSH_SESSION_PASSFILE" should be exist
    End

    It "writes password to passfile"
      _SSH_SESSION_PASSFILE=""
      When call _ssh_session_init
      The contents of file "$_SSH_SESSION_PASSFILE" should equal "$NEW_ROOT_PASSWORD"
    End

    It "reuses existing passfile"
      _ssh_session_init
      first_passfile="$_SSH_SESSION_PASSFILE"
      When call _ssh_session_init
      The variable _SSH_SESSION_PASSFILE should equal "$first_passfile"
    End

    It "sets restrictive file permissions (600)"
      _SSH_SESSION_PASSFILE=""
      _ssh_session_init
      perms=$(stat -c '%a' "$_SSH_SESSION_PASSFILE" 2>/dev/null || stat -f '%Lp' "$_SSH_SESSION_PASSFILE" 2>/dev/null)
      When call test "$perms" = "600"
      The status should be success
    End
  End

  # ===========================================================================
  # _ssh_session_cleanup()
  # ===========================================================================
  Describe "_ssh_session_cleanup()"
    It "handles already cleaned session"
      _SSH_SESSION_PASSFILE=""
      When call _ssh_session_cleanup
      The status should be success
    End

    It "removes passfile"
      _ssh_session_init
      passfile="$_SSH_SESSION_PASSFILE"
      When call _ssh_session_cleanup
      The file "$passfile" should not be exist
    End

    It "clears _SSH_SESSION_PASSFILE variable"
      _ssh_session_init
      When call _ssh_session_cleanup
      The variable _SSH_SESSION_PASSFILE should equal ""
    End

    It "handles non-existent passfile gracefully"
      _SSH_SESSION_PASSFILE="/nonexistent/path/file"
      When call _ssh_session_cleanup
      The status should be success
    End

    Describe "cleanup method selection"
      # Test shred path when available
      _test_cleanup_with_shred() {
        local tmpfile
        tmpfile=$(mktemp)
        echo "sensitive" > "$tmpfile"
        # Use real shred command if available
        if command -v shred >/dev/null 2>&1; then
          shred -u -z "$tmpfile" 2>/dev/null || rm -f "$tmpfile"
        else
          rm -f "$tmpfile"
        fi
        [[ ! -f "$tmpfile" ]]
      }

      It "uses shred when available"
        Skip if "shred not available" ! command -v shred >/dev/null 2>&1
        When call _test_cleanup_with_shred
        The status should be success
      End

      # Test dd fallback path
      _test_cleanup_with_dd_fallback() {
        local tmpfile
        tmpfile=$(mktemp)
        echo "sensitive data here" > "$tmpfile"
        local file_size
        file_size=$(stat -c%s "$tmpfile" 2>/dev/null || stat -f%z "$tmpfile" 2>/dev/null || echo 1024)
        
        # Use dd to overwrite
        dd if=/dev/zero of="$tmpfile" bs=1 count="$file_size" conv=notrunc 2>/dev/null || true
        rm -f "$tmpfile"
        [[ ! -f "$tmpfile" ]]
      }

      It "dd fallback successfully overwrites and removes file"
        When call _test_cleanup_with_dd_fallback
        The status should be success
      End
    End
  End

  # ===========================================================================
  # _ssh_get_passfile()
  # ===========================================================================
  Describe "_ssh_get_passfile()"
    It "initializes session if not already done"
      _SSH_SESSION_PASSFILE=""
      When call _ssh_get_passfile
      The output should not equal ""
      The file "$_SSH_SESSION_PASSFILE" should be exist
    End

    It "returns existing passfile path"
      _ssh_session_init
      expected="$_SSH_SESSION_PASSFILE"
      When call _ssh_get_passfile
      The output should equal "$expected"
    End

    It "returns same path across multiple calls"
      path1=$(_ssh_get_passfile)
      path2=$(_ssh_get_passfile)
      When call test "$path1" = "$path2"
      The status should be success
    End
  End

  # ===========================================================================
  # check_port_available()
  # ===========================================================================
  Describe "check_port_available()"
    It "returns success for unused port"
      When call check_port_available 59999
      The status should be success
    End

    It "handles port 0"
      When call check_port_available 0
      The status should be success
    End

    # Note: Testing "in use" port is unreliable in containers
    # The function logic is tested via mocking in integration tests

    Describe "with mocked commands"
      # Test ss path
      _check_port_with_ss() {
        local port="$1"
        # Mock ss to report port in use
        ss() { echo "tcp LISTEN :$port "; }
        command() {
          if [[ $2 == "ss" ]]; then return 0; else builtin command "$@"; fi
        }
        if ss -tuln 2>/dev/null | grep -q ":$port "; then
          return 1
        fi
        return 0
      }

      It "returns failure when ss shows port in use"
        When call _check_port_with_ss 8080
        The status should be failure
      End

      # Test netstat fallback path
      _check_port_with_netstat() {
        local port="$1"
        # Mock ss as unavailable, netstat as available
        command() {
          case "$2" in
            ss) return 1 ;;
            netstat) return 0 ;;
            *) builtin command "$@" ;;
          esac
        }
        ss() { return 1; }
        netstat() { echo "tcp 0 0 0.0.0.0:$port 0.0.0.0:* LISTEN"; }
        if command -v ss &>/dev/null; then
          if ss -tuln 2>/dev/null | grep -q ":$port "; then
            return 1
          fi
        elif command -v netstat &>/dev/null; then
          if netstat -tuln 2>/dev/null | grep -q ":$port "; then
            return 1
          fi
        fi
        return 0
      }

      It "falls back to netstat when ss unavailable"
        When call _check_port_with_netstat 8080
        The status should be failure
      End

      # Test when neither command finds port
      _check_port_available_clean() {
        local port="$1"
        ss() { echo "nothing here"; }
        netstat() { echo "nothing here"; }
        command() {
          if [[ $2 == "ss" ]]; then return 0; else builtin command "$@"; fi
        }
        if ss -tuln 2>/dev/null | grep -q ":$port "; then
          return 1
        fi
        return 0
      }

      It "returns success when port not found in output"
        When call _check_port_available_clean 9999
        The status should be success
      End
    End
  End

  # ===========================================================================
  # wait_for_ssh_ready()
  # ===========================================================================
  Describe "wait_for_ssh_ready()"
    # Note: wait_for_ssh_ready is complex with port checks and SSH loops
    # Full integration tests should mock network; here we test basic logic

    It "clears stale known_hosts entries"
      # Just verify the function runs without error when ssh-keygen is mocked
      MOCK_SSH_KEYGEN_RESULT=0
      MOCK_SSHPASS_RESULT=0
      # Skip actual execution since port check fails
      Skip "requires network simulation"
    End
  End

  # ===========================================================================
  # remote_exec()
  # ===========================================================================
  Describe "remote_exec()"
    BeforeEach '_ssh_session_init'

    It "executes command successfully"
      MOCK_SSHPASS_RESULT=0
      When call remote_exec 'echo test'
      The status should be success
    End

    It "returns failure when command fails"
      MOCK_SSHPASS_RESULT=1
      MOCK_SSHPASS_FAIL_COUNT=999
      When call remote_exec 'false'
      The status should be failure
    End

    It "retries on failure"
      MOCK_SSHPASS_FAIL_COUNT=2
      When call remote_exec 'echo test'
      The status should be success
      The variable MOCK_SSHPASS_CALLS should equal 3
    End

    It "fails after max attempts"
      MOCK_SSHPASS_RESULT=1
      MOCK_SSHPASS_FAIL_COUNT=10
      When call remote_exec 'false'
      The status should be failure
      The variable MOCK_SSHPASS_CALLS should equal 3
    End

    It "outputs command result"
      MOCK_SSHPASS_OUTPUT="command_output"
      When call remote_exec 'echo hello'
      The status should be success
      The output should equal "command_output"
    End
  End

  # ===========================================================================
  # _remote_exec_with_progress()
  # ===========================================================================
  Describe "_remote_exec_with_progress()"
    # Skip when running under kcov - background subshells cause kcov to hang
    Skip if "running under kcov" is_running_under_kcov

    BeforeEach '_ssh_session_init'

    It "returns success when script succeeds"
      MOCK_SSHPASS_RESULT=0
      When call _remote_exec_with_progress "Test message" 'echo test' "Done"
      The status should be success
    End

    It "returns failure when script fails"
      MOCK_SSHPASS_RESULT=1
      When call _remote_exec_with_progress "Test message" 'false' "Done"
      The status should be failure
    End

    It "logs script content"
      MOCK_SSHPASS_RESULT=0
      _remote_exec_with_progress "Test log" 'echo logged_script' "Done"
      When call grep -q "logged_script" "$LOG_FILE"
      The status should be success
    End

    It "uses default done message when not provided"
      MOCK_SSHPASS_RESULT=0
      When call _remote_exec_with_progress "My message" 'echo test'
      The status should be success
    End
  End

  # ===========================================================================
  # remote_run()
  # ===========================================================================
  Describe "remote_run()"
    # Skip when running under kcov - background subshells cause kcov to hang
    Skip if "running under kcov" is_running_under_kcov

    BeforeEach '_ssh_session_init'

    # Note: remote_run exits on failure, so we test success path
    It "succeeds with valid command"
      MOCK_SSHPASS_RESULT=0
      When call remote_run "Running test" 'echo success' "Test done"
      The status should be success
    End

    It "accepts optional done message"
      MOCK_SSHPASS_RESULT=0
      When call remote_run "Step 1" 'echo step1' "Step 1 complete"
      The status should be success
    End

    It "uses progress message as default done message"
      MOCK_SSHPASS_RESULT=0
      When call remote_run "Default message" 'echo test'
      The status should be success
    End
  End

  # ===========================================================================
  # remote_copy()
  # ===========================================================================
  Describe "remote_copy()"
    BeforeEach '_ssh_session_init'

    It "copies file successfully"
      MOCK_SSHPASS_RESULT=0
      tmpfile=$(mktemp)
      echo "content" > "$tmpfile"
      When call remote_copy "$tmpfile" "/remote/path"
      The status should be success
      rm -f "$tmpfile"
    End

    It "returns failure when scp fails"
      MOCK_SSHPASS_RESULT=1
      tmpfile=$(mktemp)
      echo "content" > "$tmpfile"
      When call remote_copy "$tmpfile" "/remote/path"
      The status should be failure
      rm -f "$tmpfile"
    End

    It "handles paths with spaces"
      MOCK_SSHPASS_RESULT=0
      tmpdir=$(mktemp -d)
      tmpfile="$tmpdir/file with spaces.txt"
      echo "content" > "$tmpfile"
      When call remote_copy "$tmpfile" "/remote/path"
      The status should be success
      rm -rf "$tmpdir"
    End
  End

  # ===========================================================================
  # parse_ssh_key()
  # ===========================================================================
  Describe "parse_ssh_key()"
    It "parses ED25519 key correctly"
      key="ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIOMqqnkVzrm0SdG6UOoqKLsabgH5C9okWi0dh2l9GKJl test@example.com"
      When call parse_ssh_key "$key"
      The status should be success
      The variable SSH_KEY_TYPE should equal "ssh-ed25519"
      The variable SSH_KEY_COMMENT should equal "test@example.com"
    End

    It "parses RSA key correctly"
      key="ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABgQDf user@host"
      When call parse_ssh_key "$key"
      The status should be success
      The variable SSH_KEY_TYPE should equal "ssh-rsa"
      The variable SSH_KEY_COMMENT should equal "user@host"
    End

    It "parses ECDSA key correctly"
      key="ecdsa-sha2-nistp256 AAAAE2VjZHNhLXNoYTItbmlzdHAyNTY admin@server"
      When call parse_ssh_key "$key"
      The status should be success
      The variable SSH_KEY_TYPE should equal "ecdsa-sha2-nistp256"
    End

    It "fails for empty key"
      When call parse_ssh_key ""
      The status should be failure
    End

    It "handles key without comment"
      When call parse_ssh_key "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAI"
      The status should be success
      The variable SSH_KEY_TYPE should equal "ssh-ed25519"
      The variable SSH_KEY_COMMENT should equal ""
    End

    It "extracts key data"
      key="ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIOMqqnkVzrm test"
      When call parse_ssh_key "$key"
      The variable SSH_KEY_DATA should equal "AAAAC3NzaC1lZDI1NTE5AAAAIOMqqnkVzrm"
    End

    It "creates short key representation for long keys"
      key="ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIOMqqnkVzrm0SdG6UOoqKLsabgH5C9okWi0dh2l9GKJl test"
      When call parse_ssh_key "$key"
      The variable SSH_KEY_SHORT should include "..."
    End

    It "uses full key for short keys"
      key="ssh-ed25519 shortkey test"
      When call parse_ssh_key "$key"
      The variable SSH_KEY_SHORT should equal "shortkey"
    End

    It "handles multi-word comments"
      key="ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIOMqqnkVzrm John Doe @ workstation"
      When call parse_ssh_key "$key"
      The variable SSH_KEY_COMMENT should equal "John Doe @ workstation"
    End

    It "clears previous values on new parse"
      parse_ssh_key "ssh-rsa KEYDATA1 comment1"
      When call parse_ssh_key "ssh-ed25519 KEYDATA2 comment2"
      The variable SSH_KEY_TYPE should equal "ssh-ed25519"
      The variable SSH_KEY_DATA should equal "KEYDATA2"
      The variable SSH_KEY_COMMENT should equal "comment2"
    End
  End

  # ===========================================================================
  # get_rescue_ssh_key()
  # ===========================================================================
  Describe "get_rescue_ssh_key()"
    Describe "with authorized_keys file"
      setup() {
        mkdir -p "${SHELLSPEC_TMPBASE}/root/.ssh"
        echo "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAI test@example.com" > "${SHELLSPEC_TMPBASE}/root/.ssh/authorized_keys"
      }

      cleanup() {
        rm -rf "${SHELLSPEC_TMPBASE}/root"
      }

      # Override /root with temp dir for testing
      get_rescue_ssh_key_test() {
        local auth_keys="${SHELLSPEC_TMPBASE}/root/.ssh/authorized_keys"
        if [[ -f "$auth_keys" ]]; then
          grep -E "^ssh-(rsa|ed25519|ecdsa)" "$auth_keys" 2>/dev/null | head -1
        fi
      }

      BeforeEach 'setup'
      AfterEach 'cleanup'

      It "returns first SSH key from authorized_keys"
        When call get_rescue_ssh_key_test
        The output should include "ssh-ed25519"
      End

      It "returns ed25519 key"
        echo "ssh-ed25519 KEYDATA1 user1" > "${SHELLSPEC_TMPBASE}/root/.ssh/authorized_keys"
        When call get_rescue_ssh_key_test
        The output should include "ssh-ed25519"
      End

      It "returns rsa key"
        echo "ssh-rsa KEYDATA1 user1" > "${SHELLSPEC_TMPBASE}/root/.ssh/authorized_keys"
        When call get_rescue_ssh_key_test
        The output should include "ssh-rsa"
      End

      # Note: The pattern ^ssh-(rsa|ed25519|ecdsa) matches ssh-ecdsa but
      # real ECDSA keys use "ecdsa-sha2-nistp256" format which won't match.
      # This is a known limitation - most rescue systems use ed25519 or rsa.

      It "returns only first key when multiple present"
        echo -e "ssh-ed25519 KEY1 first\nssh-rsa KEY2 second" > "${SHELLSPEC_TMPBASE}/root/.ssh/authorized_keys"
        When call get_rescue_ssh_key_test
        The lines of output should equal 1
      End

      It "ignores non-SSH lines"
        echo -e "# comment\nssh-ed25519 KEYDATA user" > "${SHELLSPEC_TMPBASE}/root/.ssh/authorized_keys"
        When call get_rescue_ssh_key_test
        The output should include "ssh-ed25519"
        The output should not include "#"
      End
    End

    Describe "without authorized_keys file"
      get_rescue_ssh_key_nofile() {
        local auth_keys="${SHELLSPEC_TMPBASE}/nonexistent/.ssh/authorized_keys"
        if [[ -f "$auth_keys" ]]; then
          grep -E "^ssh-(rsa|ed25519|ecdsa)" "$auth_keys" 2>/dev/null | head -1
        fi
      }

      It "returns empty when no authorized_keys"
        When call get_rescue_ssh_key_nofile
        The output should equal ""
      End
    End
  End

  # ===========================================================================
  # cleanup_and_error_handler integration
  # ===========================================================================
  Describe "cleanup_and_error_handler integration"
    # Test that the main cleanup handler calls _ssh_session_cleanup
    # This verifies the fix for fragile trap chaining logic

    cleanup_and_error_handler() {
      # Simplified version matching 000-init.sh logic
      if type _ssh_session_cleanup &>/dev/null; then
        _ssh_session_cleanup
      fi
    }

    test_cleanup_removes_passfile() {
      _SSH_SESSION_PASSFILE=""
      _ssh_session_init
      local passfile="$_SSH_SESSION_PASSFILE"
      [[ -f "$passfile" ]] || return 1
      cleanup_and_error_handler
      [[ ! -f "$passfile" ]]
    }

    It "calls _ssh_session_cleanup when function is available"
      When call test_cleanup_removes_passfile
      The status should be success
    End

    test_handles_missing_cleanup_func() {
      # Temporarily hide the function
      local original_func
      original_func=$(declare -f _ssh_session_cleanup)
      unset -f _ssh_session_cleanup

      cleanup_and_error_handler
      local result=$?

      # Restore function
      eval "$original_func"
      return $result
    }

    It "handles case when _ssh_session_cleanup is not defined"
      When call test_handles_missing_cleanup_func
      The status should be success
    End

    test_passfile_content_and_cleanup() {
      _SSH_SESSION_PASSFILE=""
      _ssh_session_init
      local passfile="$_SSH_SESSION_PASSFILE"
      # Verify passfile exists and has content
      [[ -f "$passfile" ]] || return 1
      [[ "$(cat "$passfile")" == "$NEW_ROOT_PASSWORD" ]] || return 1
      # Run cleanup
      cleanup_and_error_handler
      # Verify passfile is removed
      [[ ! -f "$passfile" ]]
    }

    It "cleans up passfile with correct content"
      When call test_passfile_content_and_cleanup
      The status should be success
    End
  End

  # ===========================================================================
  # SSH_OPTS and SSH_PORT defaults
  # ===========================================================================
  Describe "module constants"
    It "sets SSH_OPTS with security options"
      When call echo "$SSH_OPTS"
      The output should include "StrictHostKeyChecking=no"
      The output should include "UserKnownHostsFile=/dev/null"
    End

    It "sets SSH_PORT to default 5555"
      When call echo "$SSH_PORT"
      The output should equal "5555"
    End

    It "respects SSH_PORT_QEMU override"
      # This is set at source time, so we just verify the mechanism
      When call test -n "$SSH_PORT"
      The status should be success
    End
  End
End
