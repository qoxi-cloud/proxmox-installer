# shellcheck shell=bash
# shellcheck disable=SC2034,SC2317
# =============================================================================
# Validation mocks for testing validation functions
# =============================================================================
# Note: SC2034 disabled - variables used by spec files
# Note: SC2317 disabled - unreachable code (mock functions defined for later use)
#
# Usage in spec files:
#   %const SUPPORT_DIR: "${SHELLSPEC_PROJECT_ROOT}/spec/support"
#   eval "$(cat "$SUPPORT_DIR/validation_mocks.sh")"
#   BeforeEach 'reset_validation_mocks'

# =============================================================================
# Mock control variables
# =============================================================================
MOCK_DIG_RESULT=""
MOCK_DIG_FAIL=false
MOCK_SSH_KEYGEN_RESULT=0
MOCK_SSH_KEYGEN_OUTPUT=""
MOCK_DF_AVAILABLE_MB=10000
MOCK_DF_FAIL=false

# =============================================================================
# Reset mock state
# =============================================================================
reset_validation_mocks() {
  MOCK_DIG_RESULT=""
  MOCK_DIG_FAIL=false
  MOCK_SSH_KEYGEN_RESULT=0
  MOCK_SSH_KEYGEN_OUTPUT=""
  MOCK_DF_AVAILABLE_MB=10000
  MOCK_DF_FAIL=false
}

# =============================================================================
# dig mock for DNS resolution testing
# =============================================================================
mock_dig() {
  if [[ "$MOCK_DIG_FAIL" == "true" ]]; then
    return 1
  fi
  if [[ -n "$MOCK_DIG_RESULT" ]]; then
    echo "$MOCK_DIG_RESULT"
    return 0
  fi
  # Default behavior based on domain
  case "$*" in
    *"example.com"*) echo "93.184.216.34" ;;
    *"wrongip.com"*) echo "1.2.3.4" ;;
    *) return 1 ;;
  esac
}

# =============================================================================
# timeout mock - just run the command
# =============================================================================
mock_timeout() {
  shift
  "$@"
}

# =============================================================================
# ssh-keygen mock for key validation
# =============================================================================
mock_ssh_keygen() {
  local key_input=""
  # Read key from stdin when -f - is used
  if [[ "$*" == *"-f -"* ]]; then
    read -r key_input
  fi

  if [[ "$MOCK_SSH_KEYGEN_RESULT" -ne 0 ]]; then
    return "$MOCK_SSH_KEYGEN_RESULT"
  fi

  if [[ -n "$MOCK_SSH_KEYGEN_OUTPUT" ]]; then
    echo "$MOCK_SSH_KEYGEN_OUTPUT"
    return 0
  fi

  # Simulate validation based on key type
  case "$key_input" in
    "ssh-ed25519 "*)
      if [[ "$*" == *"-l"* ]]; then
        echo "256 SHA256:xxx comment (ED25519)"
      fi
      return 0
      ;;
    "ssh-rsa "*)
      if [[ "$*" == *"-l"* ]]; then
        # Check for weak vs strong RSA
        if [[ "$key_input" == *"WEAK"* ]]; then
          echo "1024 SHA256:xxx comment (RSA)"
        else
          echo "4096 SHA256:xxx comment (RSA)"
        fi
      fi
      return 0
      ;;
    "ecdsa-sha2-nistp256 "*)
      if [[ "$*" == *"-l"* ]]; then
        echo "256 SHA256:xxx comment (ECDSA)"
      fi
      return 0
      ;;
    "ecdsa-sha2-nistp384 "*)
      if [[ "$*" == *"-l"* ]]; then
        echo "384 SHA256:xxx comment (ECDSA)"
      fi
      return 0
      ;;
    "invalid"*) return 1 ;;
    *) return 1 ;;
  esac
}

# =============================================================================
# df mock for disk space validation
# =============================================================================
mock_df() {
  if [[ "$MOCK_DF_FAIL" == "true" ]]; then
    return 1
  fi
  echo -e "Filesystem\t1M-blocks\tUsed\tAvailable\n/dev/sda1\t50000\t$((50000 - MOCK_DF_AVAILABLE_MB))\t${MOCK_DF_AVAILABLE_MB}"
}

# =============================================================================
# Apply validation mocks - replaces production functions
# =============================================================================
apply_validation_mocks() {
  dig() { mock_dig "$@"; }
  timeout() { mock_timeout "$@"; }
  ssh-keygen() { mock_ssh_keygen "$@"; }
  df() { mock_df "$@"; }
  export -f dig timeout ssh-keygen df 2>/dev/null || true
}

