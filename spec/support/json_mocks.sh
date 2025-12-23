# shellcheck shell=bash
# =============================================================================
# JSON parsing mocks (jq)
# =============================================================================
#
# Usage in spec files:
#   %const SUPPORT_DIR: "${SHELLSPEC_PROJECT_ROOT}/spec/support"
#   eval "$(cat "$SUPPORT_DIR/json_mocks.sh")"

# =============================================================================
# jq mock - simple JSON value extraction
# Handles common patterns like: jq -r '.value // empty'
# =============================================================================
jq() {
  local input
  input=$(cat)
  
  # Parse args to find the query
  local query=""
  local raw=false
  while [[ $# -gt 0 ]]; do
    case "$1" in
      -r) raw=true; shift ;;
      .*) query="$1"; shift ;;
      *) shift ;;
    esac
  done
  
  # Handle common query patterns
  case "$query" in
    ".value"*|*"value"*)
      # Extract value from {"value":"..."} using sed
      echo "$input" | sed -n 's/.*"value"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p'
      ;;
    ".error"*|*"error"*)
      echo "$input" | sed -n 's/.*"error"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p'
      ;;
    *)
      # Default: return empty for unknown queries
      echo ""
      ;;
  esac
}

