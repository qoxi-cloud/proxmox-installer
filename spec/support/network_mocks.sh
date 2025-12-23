# shellcheck shell=bash
# shellcheck disable=SC2034
# =============================================================================
# Network mocks for wget and download functions
# =============================================================================
# Note: SC2034 disabled - variables used by spec files
#
# Usage in spec files:
#   %const SUPPORT_DIR: "${SHELLSPEC_PROJECT_ROOT}/spec/support"
#   eval "$(cat "$SUPPORT_DIR/network_mocks.sh")"
#   BeforeEach 'reset_network_mocks'

# =============================================================================
# Mock control variables
# =============================================================================
MOCK_WGET_FAIL=false
MOCK_WGET_EMPTY=false
MOCK_FILE_EMPTY=false
MOCK_WGET_FAIL_COUNT=0
MOCK_WGET_CURRENT_ATTEMPT=0
MOCK_WGET_CALLS=0

# =============================================================================
# Reset mock state
# =============================================================================
reset_network_mocks() {
  MOCK_WGET_FAIL=false
  MOCK_WGET_EMPTY=false
  MOCK_FILE_EMPTY=false
  MOCK_WGET_FAIL_COUNT=0
  MOCK_WGET_CURRENT_ATTEMPT=0
  MOCK_WGET_CALLS=0
}

# =============================================================================
# wget mock with configurable behavior
# =============================================================================
wget() {
  local output_file=""
  while [[ $# -gt 0 ]]; do
    case "$1" in
      -O)
        output_file="$2"
        shift 2
        ;;
      -q) shift ;;
      *) shift ;;
    esac
  done

  MOCK_WGET_CALLS=$((MOCK_WGET_CALLS + 1))
  MOCK_WGET_CURRENT_ATTEMPT=$((MOCK_WGET_CURRENT_ATTEMPT + 1))

  # Fail first N attempts, then succeed
  if [[ "$MOCK_WGET_FAIL_COUNT" -gt 0 ]] && [[ "$MOCK_WGET_CURRENT_ATTEMPT" -le "$MOCK_WGET_FAIL_COUNT" ]]; then
    return 1
  fi

  if [[ "$MOCK_WGET_FAIL" == "true" ]]; then
    return 1
  fi

  if [[ -n "$output_file" ]]; then
    if [[ "$MOCK_WGET_EMPTY" == "true" ]]; then
      : >"$output_file"
    else
      echo "mock file content" >"$output_file"
    fi
  fi
  return 0
}

# =============================================================================
# file command mock
# =============================================================================
file() {
  local filepath="$1"
  if [[ "$MOCK_FILE_EMPTY" == "true" ]]; then
    echo "$filepath: empty"
    return 0
  fi
  if [[ -s "$filepath" ]]; then
    echo "$filepath: ASCII text"
  else
    echo "$filepath: empty"
  fi
}

