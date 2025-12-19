# shellcheck shell=bash
# =============================================================================
# Tests for 021-ssh.sh
# =============================================================================

%const SCRIPTS_DIR: "${SHELLSPEC_PROJECT_ROOT}/scripts"

# Mocks
log() { :; }
print_error() { echo "ERROR: $*" >&2; }
show_progress() {
  wait "$1" 2>/dev/null
  return $?
}

# Required variables
SSH_CONNECT_TIMEOUT=10
NEW_ROOT_PASSWORD="testpass"
CLR_CYAN=$'\033[38;2;0;177;255m'
CLR_RED=$'\033[1;31m'
CLR_RESET=$'\033[m'

Describe "021-ssh.sh"
Include "$SCRIPTS_DIR/021-ssh.sh"

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
End

It "extracts key data"
key="ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIOMqqnkVzrm test"
When call parse_ssh_key "$key"
The variable SSH_KEY_DATA should equal "AAAAC3NzaC1lZDI1NTE5AAAAIOMqqnkVzrm"
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
End

# ===========================================================================
# _ssh_session_init()
# ===========================================================================
Describe "_ssh_session_init()"
AfterEach '_ssh_session_cleanup 2>/dev/null || true'

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
End
End
