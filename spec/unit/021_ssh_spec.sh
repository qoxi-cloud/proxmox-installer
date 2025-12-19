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

Describe "parse_ssh_key()"
It "parses ED25519 key correctly"
key="ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIOMqqnkVzrm0SdG6UOoqKLsabgH5C9okWi0dh2l9GKJl test@example.com"
When call parse_ssh_key "$key"
The status should be success
The variable SSH_KEY_TYPE should equal "ssh-ed25519"
The variable SSH_KEY_COMMENT should equal "test@example.com"
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
End

Describe "check_port_available()"
It "returns success for unused port"
When call check_port_available 59999
The status should be success
End
End

Describe "_ssh_session_init()"
AfterEach '_ssh_session_cleanup 2>/dev/null || true'

It "creates passfile"
_SSH_SESSION_PASSFILE=""
When call _ssh_session_init
The status should be success
The variable _SSH_SESSION_PASSFILE should not equal ""
End
End

Describe "_ssh_session_cleanup()"
It "handles already cleaned session"
_SSH_SESSION_PASSFILE=""
When call _ssh_session_cleanup
The status should be success
End
End
End
