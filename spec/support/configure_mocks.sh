# shellcheck shell=bash
# =============================================================================
# Shared mocks for configure script tests
# =============================================================================
# Source this file BEFORE Including the configure script under test

# Mock result controls
MOCK_RUN_REMOTE_RESULT=0
MOCK_REMOTE_EXEC_RESULT=0
MOCK_REMOTE_COPY_RESULT=0
MOCK_DEPLOY_TEMPLATE_RESULT=0

# Mock functions
log() { :; }
print_warning() { :; }
print_error() { :; }
print_info() { :; }
print_success() { :; }

run_remote() {
  # $1 = description, $2 = command, $3 = success message
  return "$MOCK_RUN_REMOTE_RESULT"
}

remote_exec() {
  return "$MOCK_REMOTE_EXEC_RESULT"
}

remote_copy() {
  return "$MOCK_REMOTE_COPY_RESULT"
}

deploy_template() {
  return "$MOCK_DEPLOY_TEMPLATE_RESULT"
}

show_progress() {
  local pid="$1"
  wait "$pid" 2>/dev/null
  return $?
}
