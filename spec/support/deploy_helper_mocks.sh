# shellcheck shell=bash
# shellcheck disable=SC2034
# =============================================================================
# Deploy helper mocks with call tracking for testing deployment functions
# =============================================================================
#
# Usage in spec files:
#   %const SUPPORT_DIR: "${SHELLSPEC_PROJECT_ROOT}/spec/support"
#   eval "$(cat "$SUPPORT_DIR/deploy_helper_mocks.sh")"
#   BeforeEach 'reset_deploy_mocks'

# =============================================================================
# Mock control variables
# =============================================================================
MOCK_REMOTE_EXEC_RESULT=0
MOCK_REMOTE_COPY_RESULT=0
MOCK_APPLY_TEMPLATE_RESULT=0
REMOTE_EXEC_CALLS=()
REMOTE_COPY_CALLS=()
APPLY_TEMPLATE_CALLS=()

# =============================================================================
# Reset mock state
# =============================================================================
reset_deploy_mocks() {
  MOCK_REMOTE_EXEC_RESULT=0
  MOCK_REMOTE_COPY_RESULT=0
  MOCK_APPLY_TEMPLATE_RESULT=0
  REMOTE_EXEC_CALLS=()
  REMOTE_COPY_CALLS=()
  APPLY_TEMPLATE_CALLS=()
  ADMIN_USERNAME="${ADMIN_USERNAME:-testadmin}"
}

# =============================================================================
# remote_exec mock with call tracking
# =============================================================================
remote_exec() {
  REMOTE_EXEC_CALLS+=("$1")
  return "$MOCK_REMOTE_EXEC_RESULT"
}

# =============================================================================
# remote_copy mock with call tracking
# =============================================================================
remote_copy() {
  REMOTE_COPY_CALLS+=("$1 -> $2")
  return "$MOCK_REMOTE_COPY_RESULT"
}

# =============================================================================
# apply_template_vars mock with call tracking
# =============================================================================
apply_template_vars() {
  local file="$1"
  shift
  APPLY_TEMPLATE_CALLS+=("$file: $*")
  return "$MOCK_APPLY_TEMPLATE_RESULT"
}

# =============================================================================
# Helpers to check mock calls
# =============================================================================
remote_exec_was_called_with() {
  local pattern="$1"
  for call in "${REMOTE_EXEC_CALLS[@]}"; do
    if [[ "$call" == *"$pattern"* ]]; then
      return 0
    fi
  done
  return 1
}

remote_copy_was_called_with() {
  local pattern="$1"
  for call in "${REMOTE_COPY_CALLS[@]}"; do
    if [[ "$call" == *"$pattern"* ]]; then
      return 0
    fi
  done
  return 1
}

