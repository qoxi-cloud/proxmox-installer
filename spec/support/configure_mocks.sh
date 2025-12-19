# shellcheck shell=bash
# shellcheck disable=SC2034
# =============================================================================
# Shared mocks for configure script tests
# =============================================================================

# Mock result controls - set these in your tests
MOCK_RUN_REMOTE_RESULT=0
MOCK_REMOTE_EXEC_RESULT=0
MOCK_REMOTE_COPY_RESULT=0
MOCK_DEPLOY_TEMPLATE_RESULT=0
MOCK_DEPLOY_TEMPLATES_RESULT=0

# =============================================================================
# Logging mocks
# =============================================================================
log() { :; }

# =============================================================================
# Display mocks
# =============================================================================
print_warning() { :; }
print_error() { :; }
print_info() { :; }
print_success() { :; }

# =============================================================================
# Remote execution mocks
# =============================================================================
run_remote() {
  return "$MOCK_RUN_REMOTE_RESULT"
}

remote_exec() {
  return "$MOCK_REMOTE_EXEC_RESULT"
}

remote_copy() {
  return "$MOCK_REMOTE_COPY_RESULT"
}

# =============================================================================
# Template mocks
# =============================================================================
deploy_template() {
  return "$MOCK_DEPLOY_TEMPLATE_RESULT"
}

deploy_templates() {
  return "$MOCK_DEPLOY_TEMPLATES_RESULT"
}

# =============================================================================
# Progress mock
# =============================================================================
show_progress() {
  local pid="$1"
  wait "$pid" 2>/dev/null
  return $?
}
