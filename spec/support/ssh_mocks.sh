# shellcheck shell=bash
# shellcheck disable=SC2034
# =============================================================================
# SSH mocks for testing SSH-related functions
# =============================================================================
#
# Usage in spec files:
#   %const SUPPORT_DIR: "${SHELLSPEC_PROJECT_ROOT}/spec/support"
#   eval "$(cat "$SUPPORT_DIR/ssh_mocks.sh")"
#   BeforeEach 'reset_ssh_mocks'

# =============================================================================
# Mock control variables
# =============================================================================
MOCK_SSHPASS_RESULT=0
MOCK_SSHPASS_CALLS=0
MOCK_SSHPASS_FAIL_COUNT=0
MOCK_SSHPASS_CURRENT_ATTEMPT=0
MOCK_SSHPASS_OUTPUT=""
MOCK_SSH_KEYGEN_RESULT=0
MOCK_PORT_OPEN=true

# =============================================================================
# Reset mock state
# =============================================================================
reset_ssh_mocks() {
  MOCK_SSHPASS_RESULT=0
  MOCK_SSHPASS_CALLS=0
  MOCK_SSHPASS_FAIL_COUNT=0
  MOCK_SSHPASS_CURRENT_ATTEMPT=0
  MOCK_SSHPASS_OUTPUT=""
  MOCK_SSH_KEYGEN_RESULT=0
  MOCK_PORT_OPEN=true
  _SSH_SESSION_PASSFILE=""
  _SSH_SESSION_LOGGED=false
}

# =============================================================================
# sshpass mock with configurable behavior
# =============================================================================
sshpass() {
  MOCK_SSHPASS_CALLS=$((MOCK_SSHPASS_CALLS + 1))
  MOCK_SSHPASS_CURRENT_ATTEMPT=$((MOCK_SSHPASS_CURRENT_ATTEMPT + 1))

  # Fail first N attempts, then succeed
  if [[ "$MOCK_SSHPASS_FAIL_COUNT" -gt 0 ]] && [[ "$MOCK_SSHPASS_CURRENT_ATTEMPT" -le "$MOCK_SSHPASS_FAIL_COUNT" ]]; then
    return 1
  fi

  if [[ "$MOCK_SSHPASS_RESULT" -ne 0 ]]; then
    return "$MOCK_SSHPASS_RESULT"
  fi

  # Output mock data if configured
  if [[ -n "$MOCK_SSHPASS_OUTPUT" ]]; then
    echo "$MOCK_SSHPASS_OUTPUT"
  fi

  return 0
}

# =============================================================================
# ssh-keygen mock
# =============================================================================
ssh-keygen() {
  return "$MOCK_SSH_KEYGEN_RESULT"
}

# =============================================================================
# Port check mock - override bash's /dev/tcp check behavior
# Note: Can't actually mock /dev/tcp, tests use MOCK_PORT_OPEN to control flow
# =============================================================================


