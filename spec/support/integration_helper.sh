# shellcheck shell=bash
# =============================================================================
# Integration test helper - shared setup for integration tests
# =============================================================================

# Source docker helper
# shellcheck source=spec/support/docker_helper.sh
. "$SPEC_ROOT/spec/support/docker_helper.sh"

# =============================================================================
# Integration test globals
# =============================================================================

# Override SSH settings for integration tests
INTEGRATION_MODE=true
export INTEGRATION_MODE

# =============================================================================
# Setup/teardown hooks
# =============================================================================

# Call in BeforeAll to start containers
integration_setup() {
  # Skip if already running
  if containers_running; then
    return 0
  fi

  if ! start_integration_containers; then
    echo "ERROR: Failed to start integration containers" >&2
    return 1
  fi

  if ! wait_for_sshd 30; then
    echo "ERROR: SSHD container not ready" >&2
    stop_integration_containers
    return 1
  fi
}

# Call in AfterAll to stop containers
integration_teardown() {
  stop_integration_containers
}

# =============================================================================
# Remote function overrides for integration tests
# =============================================================================

# Override remote_exec to use integration container
# Use when testing code that calls remote_exec
setup_integration_remote_exec() {
  # Save original if exists
  if type remote_exec &>/dev/null; then
    eval "_original_remote_exec() $(declare -f remote_exec | tail -n +2)"
  fi

  remote_exec() {
    integration_ssh_exec "$@"
  }
  export -f remote_exec
}

# Override remote_copy to use integration container
setup_integration_remote_copy() {
  if type remote_copy &>/dev/null; then
    eval "_original_remote_copy() $(declare -f remote_copy | tail -n +2)"
  fi

  remote_copy() {
    integration_ssh_copy "$@"
  }
  export -f remote_copy
}

# Restore original remote functions
restore_remote_functions() {
  if type _original_remote_exec &>/dev/null; then
    eval "remote_exec() $(declare -f _original_remote_exec | tail -n +2)"
    unset -f _original_remote_exec
  fi
  if type _original_remote_copy &>/dev/null; then
    eval "remote_copy() $(declare -f _original_remote_copy | tail -n +2)"
    unset -f _original_remote_copy
  fi
}

# =============================================================================
# Test assertion helpers
# =============================================================================

# Assert remote command succeeds
assert_remote_success() {
  local cmd="$1"
  local msg="${2:-Command should succeed}"
  if ! integration_ssh_exec "$cmd"; then
    echo "FAIL: $msg - command failed: $cmd" >&2
    return 1
  fi
}

# Assert remote file contains pattern
assert_remote_contains() {
  local file="$1"
  local pattern="$2"
  local msg="${3:-File should contain pattern}"

  local content
  content=$(integration_ssh_exec "cat '$file'" 2>/dev/null)
  if ! echo "$content" | grep -q "$pattern"; then
    echo "FAIL: $msg" >&2
    echo "  File: $file" >&2
    echo "  Pattern: $pattern" >&2
    return 1
  fi
}

# Assert file was deployed with correct permissions
assert_remote_perms() {
  local file="$1"
  local expected_perms="$2"
  local msg="${3:-File should have correct permissions}"

  local actual_perms
  actual_perms=$(integration_ssh_exec "stat -c '%a' '$file'" 2>/dev/null)
  if [[ $actual_perms != "$expected_perms" ]]; then
    echo "FAIL: $msg" >&2
    echo "  Expected: $expected_perms" >&2
    echo "  Actual: $actual_perms" >&2
    return 1
  fi
}

