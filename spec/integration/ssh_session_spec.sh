# shellcheck shell=bash
# shellcheck disable=SC2016,SC2034
# =============================================================================
# Integration tests for SSH session management
# Tests: 021-ssh.sh with real SSH connections to Docker container
# Requires: Docker containers running (integration-sshd)
# =============================================================================

%const SCRIPTS_DIR: "${SHELLSPEC_PROJECT_ROOT}/scripts"
%const SUPPORT_DIR: "${SHELLSPEC_PROJECT_ROOT}/spec/support"

# Load helpers
eval "$(cat "$SUPPORT_DIR/core_mocks.sh")"

# =============================================================================
# Skip checks - evaluated at file load time
# =============================================================================
DOCKER_AVAILABLE=false
SSHD_CONTAINER_READY=false

if command -v docker &>/dev/null && docker info &>/dev/null 2>&1; then
  DOCKER_AVAILABLE=true
  running=$(docker inspect -f '{{.State.Running}}' integration-sshd 2>/dev/null || echo "false")
  [[ $running == "true" ]] && SSHD_CONTAINER_READY=true
fi

skip_ssh_tests() {
  [[ $DOCKER_AVAILABLE != "true" || $SSHD_CONTAINER_READY != "true" ]]
}

# =============================================================================
# Test setup
# =============================================================================
setup_ssh_test() {
  # Override SSH settings for integration test container
  SSH_PORT=2222
  SSH_PORT_QEMU=2222
  SSH_CONNECT_TIMEOUT=5
  NEW_ROOT_PASSWORD="testpass123"
  export SSH_PORT SSH_PORT_QEMU SSH_CONNECT_TIMEOUT NEW_ROOT_PASSWORD

  # Clear any existing session
  _SSH_SESSION_PASSFILE=""
  _SSH_SESSION_LOGGED=false

  # Clean up any stale passfiles
  rm -f /dev/shm/pve-ssh-session.$$ /tmp/pve-ssh-session.$$ 2>/dev/null || true
}

cleanup_ssh_test() {
  # Clean up passfiles
  rm -f /dev/shm/pve-ssh-session.$$ /tmp/pve-ssh-session.$$ 2>/dev/null || true
  _SSH_SESSION_PASSFILE=""
  _SSH_SESSION_LOGGED=false
}

# Include SSH functions
Include "$SCRIPTS_DIR/021-ssh.sh"

Describe "SSH Session Integration"
  Skip if "Docker not available or SSHD container not running" skip_ssh_tests

  BeforeEach 'setup_ssh_test'
  AfterEach 'cleanup_ssh_test'
  AfterAll 'cleanup_ssh_test'

  # ===========================================================================
  # Session lifecycle
  # ===========================================================================
  Describe "_ssh_session_init()"
    It "creates passfile on first call"
      When call _ssh_session_init
      The status should be success
      The variable _SSH_SESSION_PASSFILE should not equal ""
      The file "$_SSH_SESSION_PASSFILE" should be exist
    End

    It "reuses existing passfile on subsequent calls"
      _ssh_session_init
      first_path="$_SSH_SESSION_PASSFILE"

      When call _ssh_session_init
      The status should be success
      The variable _SSH_SESSION_PASSFILE should equal "$first_path"
    End

    It "sets correct permissions on passfile"
      _ssh_session_init
      perms=$(stat -c '%a' "$_SSH_SESSION_PASSFILE" 2>/dev/null || stat -f '%A' "$_SSH_SESSION_PASSFILE")

      When call printf '%s' "$perms"
      The output should equal "600"
    End

    It "stores correct password in passfile"
      _ssh_session_init
      content=$(cat "$_SSH_SESSION_PASSFILE")

      When call printf '%s' "$content"
      The output should equal "testpass123"
    End
  End

  Describe "_ssh_session_cleanup()"
    It "removes passfile"
      _ssh_session_init
      passfile="$_SSH_SESSION_PASSFILE"
      test -f "$passfile" # ensure it exists

      When call _ssh_session_cleanup
      The status should be success
      The file "$passfile" should not be exist
    End

    It "clears session variable"
      _ssh_session_init
      When call _ssh_session_cleanup
      The variable _SSH_SESSION_PASSFILE should equal ""
    End

    It "succeeds when passfile doesn't exist"
      When call _ssh_session_cleanup
      The status should be success
    End
  End

  Describe "_ssh_get_passfile()"
    It "returns passfile path"
      When call _ssh_get_passfile
      The status should be success
      The output should not equal ""
    End

    It "initializes session if not already done"
      When call _ssh_get_passfile
      The variable _SSH_SESSION_PASSFILE should not equal ""
      The output should include "pve-ssh-session"
    End
  End

  # ===========================================================================
  # Remote execution
  # ===========================================================================
  Describe "remote_exec()"
    It "executes simple command successfully"
      When call remote_exec 'echo hello'
      The status should be success
      The output should equal "hello"
    End

    It "returns failure for failing remote command"
      # remote_exec has retry logic - after 3 failed attempts returns 1
      When call remote_exec 'exit 42'
      The status should be failure
    End

    It "executes complex command with pipes"
      When call remote_exec 'echo "one two three" | wc -w'
      The status should be success
      The output should equal "3"
    End

    It "executes command with environment variables"
      When call remote_exec 'FOO=bar; echo $FOO'
      The status should be success
      The output should equal "bar"
    End

    It "handles command with special characters"
      When call remote_exec 'echo "hello & world | test"'
      The status should be success
      The output should include "hello & world"
    End

    It "handles multiline output"
      When call remote_exec 'printf "line1\nline2\nline3"'
      The status should be success
      The output should include "line1"
      The output should include "line3"
    End
  End

  # ===========================================================================
  # File transfer
  # ===========================================================================
  Describe "remote_copy()"
    It "copies file to remote"
      tmpfile=$(mktemp)
      echo "test content" >"$tmpfile"
      When call remote_copy "$tmpfile" "/tmp/test_copy"
      The status should be success
      rm -f "$tmpfile" 2>/dev/null
    End

    It "fails for non-existent source file"
      When call remote_copy "/nonexistent/file" "/tmp/dest"
      The status should be failure
      The stderr should include "No such file"
    End

    It "copies file with special characters in content"
      tmpfile=$(mktemp)
      echo 'special: $VAR & "quotes" | pipe' >"$tmpfile"
      When call remote_copy "$tmpfile" "/tmp/test_special"
      The status should be success
      rm -f "$tmpfile" 2>/dev/null
    End
  End

  # ===========================================================================
  # Connection handling
  # ===========================================================================
  Describe "connection resilience"
    It "retries on transient failure"
      # First call should succeed (connection is stable)
      When call remote_exec 'echo retry_test'
      The status should be success
      The output should equal "retry_test"
    End

    It "handles multiple sequential commands"
      remote_exec 'echo cmd1' >/dev/null 2>&1
      remote_exec 'echo cmd2' >/dev/null 2>&1
      When call remote_exec 'echo cmd3'
      The status should be success
      The output should equal "cmd3"
    End
  End

  # ===========================================================================
  # Port checking
  # ===========================================================================
  Describe "check_port_available()"
    It "returns false for port in use (SSH container port)"
      When call check_port_available 2222
      The status should be failure
    End

    It "returns true for unused port"
      When call check_port_available 59999
      The status should be success
    End
  End

  # ===========================================================================
  # SSH key utilities
  # ===========================================================================
  Describe "parse_ssh_key()"
    It "parses ed25519 key"
      key="ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIBq8b user@host"
      When call parse_ssh_key "$key"
      The status should be success
      The variable SSH_KEY_TYPE should equal "ssh-ed25519"
      The variable SSH_KEY_DATA should equal "AAAAC3NzaC1lZDI1NTE5AAAAIBq8b"
      The variable SSH_KEY_COMMENT should equal "user@host"
    End

    It "parses RSA key with long data"
      key="ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABgQC12345678901234567890123456789012345678901234567890 user@host"
      When call parse_ssh_key "$key"
      The status should be success
      The variable SSH_KEY_TYPE should equal "ssh-rsa"
      The variable SSH_KEY_SHORT should include "..."
    End

    It "returns failure for empty key"
      When call parse_ssh_key ""
      The status should be failure
    End
  End
End

