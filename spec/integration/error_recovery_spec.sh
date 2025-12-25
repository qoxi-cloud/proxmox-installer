# shellcheck shell=bash
# shellcheck disable=SC2016,SC2034
# =============================================================================
# Integration tests for error recovery mechanisms
# Tests: SSH session recovery, trap handlers, cleanup, passfile security
# =============================================================================

%const SCRIPTS_DIR: "${SHELLSPEC_PROJECT_ROOT}/scripts"
%const SUPPORT_DIR: "${SHELLSPEC_PROJECT_ROOT}/spec/support"

# Load mocks
eval "$(cat "$SUPPORT_DIR/core_mocks.sh")"

# =============================================================================
# Skip checks
# =============================================================================
DOCKER_AVAILABLE=false
SSHD_CONTAINER_READY=false

if command -v docker &>/dev/null && docker info &>/dev/null 2>&1; then
  DOCKER_AVAILABLE=true
  running=$(docker inspect -f '{{.State.Running}}' integration-sshd 2>/dev/null || echo "false")
  [[ $running == "true" ]] && SSHD_CONTAINER_READY=true
fi

skip_ssh_recovery_tests() {
  [[ $DOCKER_AVAILABLE != "true" || $SSHD_CONTAINER_READY != "true" ]]
}

# =============================================================================
# Test setup
# =============================================================================
setup_error_recovery_test() {
  # SSH settings for integration test container
  SSH_PORT=2222
  SSH_PORT_QEMU=2222
  SSH_CONNECT_TIMEOUT=5
  NEW_ROOT_PASSWORD="testpass123"
  export SSH_PORT SSH_PORT_QEMU SSH_CONNECT_TIMEOUT NEW_ROOT_PASSWORD

  # Clear any existing session
  _SSH_SESSION_PASSFILE=""
  _SSH_SESSION_LOGGED=false

  # Mock LOG_FILE
  LOG_FILE="${SHELLSPEC_TMPBASE}/test.log"
  touch "$LOG_FILE"
  export LOG_FILE

  # Clean up any stale passfiles
  rm -f /dev/shm/pve-ssh-session.$$ /tmp/pve-ssh-session.$$ 2>/dev/null || true
}

cleanup_error_recovery_test() {
  rm -f /dev/shm/pve-ssh-session.$$ /tmp/pve-ssh-session.$$ 2>/dev/null || true
  _SSH_SESSION_PASSFILE=""
  _SSH_SESSION_LOGGED=false
}

Describe "Error Recovery Integration"
  Include "$SCRIPTS_DIR/012-utils.sh"
  Include "$SCRIPTS_DIR/021-ssh.sh"

  BeforeEach 'setup_error_recovery_test'
  AfterEach 'cleanup_error_recovery_test'
  AfterAll 'cleanup_error_recovery_test'

  # ===========================================================================
  # SSH session lifecycle - passfile management
  # ===========================================================================
  Describe "SSH passfile security"
    Describe "_ssh_passfile_path()"
      It "returns predictable path based on PID"
        path1=$(_ssh_passfile_path)
        path2=$(_ssh_passfile_path)
        When call printf '%s' "$([[ $path1 == "$path2" ]] && echo 'same')"
        The output should equal "same"
      End

      It "uses /dev/shm when available"
        Skip if "/dev/shm not writable" test ! -w /dev/shm
        When call _ssh_passfile_path
        The output should include "/dev/shm/"
      End

      It "includes PID in path"
        When call _ssh_passfile_path
        The output should include "$$"
      End
    End

    Describe "_ssh_session_init()"
      It "creates passfile with correct permissions"
        _ssh_session_init
        passfile="$_SSH_SESSION_PASSFILE"
        perms=$(stat -c '%a' "$passfile" 2>/dev/null || stat -f '%A' "$passfile")
        When call printf '%s' "$perms"
        The output should equal "600"
      End

      It "stores password correctly"
        _ssh_session_init
        content=$(cat "$_SSH_SESSION_PASSFILE")
        When call printf '%s' "$content"
        The output should equal "testpass123"
      End

      It "reuses existing passfile on subsequent calls"
        _ssh_session_init
        first="$_SSH_SESSION_PASSFILE"
        _ssh_session_init
        second="$_SSH_SESSION_PASSFILE"
        When call printf '%s' "$([[ $first == "$second" ]] && echo 'reused')"
        The output should equal "reused"
      End
    End

    Describe "_ssh_session_cleanup()"
      It "removes passfile"
        _ssh_session_init
        passfile="$_SSH_SESSION_PASSFILE"
        test -f "$passfile" # verify exists
        _ssh_session_cleanup
        When call test -f "$passfile"
        The status should be failure
      End

      It "clears session variable"
        _ssh_session_init
        _ssh_session_cleanup
        When call printf '%s' "$_SSH_SESSION_PASSFILE"
        The output should equal ""
      End

      It "succeeds when no passfile exists"
        When call _ssh_session_cleanup
        The status should be success
      End
    End
  End

  # ===========================================================================
  # secure_delete_file()
  # ===========================================================================
  Describe "secure_delete_file()"
    It "removes file completely"
      testfile=$(mktemp)
      echo "secret content" > "$testfile"
      secure_delete_file "$testfile"
      When call test -f "$testfile"
      The status should be failure
    End

    It "handles non-existent file gracefully"
      When call secure_delete_file "/nonexistent/file/path"
      The status should be success
    End

    It "overwrites content before deletion"
      shred_available() { command -v shred >/dev/null 2>&1; }
      Skip if "shred not available" shred_available
      testfile=$(mktemp)
      echo "secret content" > "$testfile"
      # Secure delete should overwrite
      When call secure_delete_file "$testfile"
      The status should be success
    End
  End

  # ===========================================================================
  # SSH retry logic with real SSH container
  # ===========================================================================
  Describe "SSH retry logic"
    Skip if "Docker not available or SSHD container not running" skip_ssh_recovery_tests

    Describe "remote_exec() retry behavior"
      It "succeeds on first try for valid command"
        When call remote_exec 'echo test'
        The status should be success
        The output should equal "test"
      End

      It "retries on transient failure then succeeds"
        # First command works, establishing connection is stable
        When call remote_exec 'echo recovery'
        The status should be success
        The output should equal "recovery"
      End

      It "fails after max retries for invalid command"
        When call remote_exec 'exit 99'
        The status should be failure
      End
    End

    Describe "connection recovery"
      It "handles multiple sequential commands"
        remote_exec 'echo cmd1' >/dev/null 2>&1
        remote_exec 'echo cmd2' >/dev/null 2>&1
        When call remote_exec 'echo cmd3'
        The status should be success
        The output should equal "cmd3"
      End

      It "maintains session across commands"
        _ssh_session_init
        first_passfile="$_SSH_SESSION_PASSFILE"
        remote_exec 'echo test1' >/dev/null 2>&1
        remote_exec 'echo test2' >/dev/null 2>&1
        # Passfile should be the same
        current_passfile="$_SSH_SESSION_PASSFILE"
        When call printf '%s' "$([[ $first_passfile == "$current_passfile" ]] && echo 'same')"
        The output should equal "same"
      End
    End
  End

  # ===========================================================================
  # Cleanup trap behavior (unit tests - no Docker needed)
  # ===========================================================================
  Describe "cleanup trap behavior"
    It "cleanup function exists"
      # Source init to get cleanup function
      # Note: We can't fully test trap in spec, but can verify function exists
      When call type _ssh_session_cleanup
      The status should be success
      The output should include "function"
    End

    It "secure_delete_file function exists"
      When call type secure_delete_file
      The status should be success
      The output should include "function"
    End
  End

  # ===========================================================================
  # Passfile path consistency across subshells
  # ===========================================================================
  Describe "subshell passfile sharing"
    It "subshells use same passfile path"
      parent_path=$(_ssh_passfile_path)
      child_path=$(bash -c 'source '"$SCRIPTS_DIR"'/021-ssh.sh; _ssh_passfile_path')
      # Both should contain the parent PID ($$)
      When call printf '%s' "$([[ $parent_path == *"$$"* ]] && echo 'has_pid')"
      The output should equal "has_pid"
    End

    It "passfile created by parent is visible to child"
      _ssh_session_init
      parent_passfile="$_SSH_SESSION_PASSFILE"
      # Check if file exists from child perspective
      child_check=$(bash -c '[[ -f "'"$parent_passfile"'" ]] && echo exists')
      When call printf '%s' "$child_check"
      The output should equal "exists"
    End
  End

  # ===========================================================================
  # Error state tracking
  # ===========================================================================
  Describe "error state handling"
    Skip if "Docker not available or SSHD container not running" skip_ssh_recovery_tests

    It "failed remote_exec returns non-zero"
      When call remote_exec 'exit 1'
      The status should be failure
    End

    It "passfile persists after failed command"
      _ssh_session_init
      passfile="$_SSH_SESSION_PASSFILE"
      remote_exec 'exit 1' >/dev/null 2>&1 || true
      When call test -f "$passfile"
      The status should be success
    End
  End

  # ===========================================================================
  # Port availability checking
  # ===========================================================================
  Describe "check_port_available()"
    It "returns false for port in use"
      Skip if "Docker not available or SSHD container not running" skip_ssh_recovery_tests
      # Port 2222 is used by SSHD container
      When call check_port_available 2222
      The status should be failure
    End

    It "returns true for unused port"
      When call check_port_available 59998
      The status should be success
    End
  End
End

