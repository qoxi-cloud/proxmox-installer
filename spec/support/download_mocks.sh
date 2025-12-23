# shellcheck shell=bash
# shellcheck disable=SC2034
# =============================================================================
# Download mocks for template download testing
# =============================================================================
#
# Usage in spec files:
#   %const SUPPORT_DIR: "${SHELLSPEC_PROJECT_ROOT}/spec/support"
#   eval "$(cat "$SUPPORT_DIR/download_mocks.sh")"
#   BeforeEach 'reset_download_mocks'

# =============================================================================
# Mock control variables
# =============================================================================
MOCK_DOWNLOAD_FAIL=false
MOCK_DOWNLOAD_EMPTY=false
MOCK_DOWNLOAD_CONTENT=""

# =============================================================================
# Reset mock state
# =============================================================================
reset_download_mocks() {
  MOCK_DOWNLOAD_FAIL=false
  MOCK_DOWNLOAD_EMPTY=false
  MOCK_DOWNLOAD_CONTENT=""
}

# =============================================================================
# download_file mock with configurable behavior
# =============================================================================
download_file() {
  local output_file="$1"
  local url="$2"

  # Check mock control variables
  if [[ "${MOCK_DOWNLOAD_FAIL:-false}" == "true" ]]; then
    return 1
  fi

  if [[ "${MOCK_DOWNLOAD_EMPTY:-false}" == "true" ]]; then
    : >"$output_file"
    return 0
  fi

  # Use custom content if set, otherwise default
  if [[ -n "${MOCK_DOWNLOAD_CONTENT:-}" ]]; then
    echo "$MOCK_DOWNLOAD_CONTENT" >"$output_file"
  else
    echo "mock file content" >"$output_file"
  fi
  return 0
}

