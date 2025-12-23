# shellcheck shell=bash
# shellcheck disable=SC2034,SC2154
# =============================================================================
# Tests for 115-wizard-access.sh
# =============================================================================
# Note: SC2034 disabled - variables used by ShellSpec assertions
#       SC2154 disabled - variables set by mocks

%const SCRIPTS_DIR: "${SHELLSPEC_PROJECT_ROOT}/scripts"
%const SUPPORT_DIR: "${SHELLSPEC_PROJECT_ROOT}/spec/support"

# Load shared mocks
eval "$(cat "$SUPPORT_DIR/colors.sh")"
eval "$(cat "$SUPPORT_DIR/core_mocks.sh")"
eval "$(cat "$SUPPORT_DIR/ui_mocks.sh")"

# =============================================================================
# Mock configuration
# =============================================================================

# Mock return values
MOCK_WIZ_INPUT_VALUE=""
MOCK_WIZ_INPUT_CANCELLED=false
MOCK_WIZ_CHOOSE_VALUE=""
MOCK_WIZ_CHOOSE_CANCELLED=false

# Sequence-based mock support
MOCK_WIZ_INPUT_SEQUENCE=()
MOCK_WIZ_INPUT_INDEX=0
MOCK_WIZ_CHOOSE_SEQUENCE=()
MOCK_WIZ_CHOOSE_INDEX=0

# SSH key mocks
MOCK_RESCUE_SSH_KEY=""
MOCK_VALIDATE_SSH_KEY_RESULT=0

# Temp file for tracking calls across subshells
MOCK_CALL_COUNTER_FILE="/tmp/mock_access_call_counter_$$"

reset_wizard_access_mocks() {
  MOCK_WIZ_INPUT_VALUE=""
  MOCK_WIZ_INPUT_CANCELLED=false
  MOCK_WIZ_CHOOSE_VALUE=""
  MOCK_WIZ_CHOOSE_CANCELLED=false
  MOCK_WIZ_INPUT_SEQUENCE=()
  MOCK_WIZ_INPUT_INDEX=0
  MOCK_WIZ_CHOOSE_SEQUENCE=()
  MOCK_WIZ_CHOOSE_INDEX=0
  MOCK_RESCUE_SSH_KEY=""
  MOCK_VALIDATE_SSH_KEY_RESULT=0

  # Clean up temp files
  rm -f "${MOCK_CALL_COUNTER_FILE}.input" "${MOCK_CALL_COUNTER_FILE}.choose" "${MOCK_CALL_COUNTER_FILE}.calls" 2>/dev/null || true

  # Reset globals
  SSH_PUBLIC_KEY=""
  ADMIN_USERNAME=""
  ADMIN_PASSWORD=""
  INSTALL_API_TOKEN=""
  API_TOKEN_NAME=""
  DEFAULT_PASSWORD_LENGTH=16

  # SSH key parse results
  SSH_KEY_TYPE=""
  SSH_KEY_DATA=""
  SSH_KEY_COMMENT=""
  SSH_KEY_SHORT=""
}

# Helper to check if a call was made
mock_calls_include() {
  local pattern="$1"
  [[ -f "${MOCK_CALL_COUNTER_FILE}.calls" ]] && grep -q "$pattern" "${MOCK_CALL_COUNTER_FILE}.calls"
}

# =============================================================================
# UI mocks with sequence support
# =============================================================================

_wiz_input() {
  echo "_wiz_input" >> "${MOCK_CALL_COUNTER_FILE}.calls" 2>/dev/null || true

  if [[ $MOCK_WIZ_INPUT_CANCELLED == true ]]; then
    echo ""
    return
  fi
  # Use sequence if defined
  if [[ ${#MOCK_WIZ_INPUT_SEQUENCE[@]} -gt 0 ]]; then
    local idx=0
    [[ -f "${MOCK_CALL_COUNTER_FILE}.input" ]] && idx=$(cat "${MOCK_CALL_COUNTER_FILE}.input")
    local val="${MOCK_WIZ_INPUT_SEQUENCE[$idx]:-}"
    echo $((idx + 1)) > "${MOCK_CALL_COUNTER_FILE}.input"
    echo "$val"
  else
    echo "$MOCK_WIZ_INPUT_VALUE"
  fi
}

_wiz_choose() {
  echo "_wiz_choose" >> "${MOCK_CALL_COUNTER_FILE}.calls" 2>/dev/null || true

  if [[ $MOCK_WIZ_CHOOSE_CANCELLED == true ]]; then
    return 1
  fi
  # Use sequence if defined
  if [[ ${#MOCK_WIZ_CHOOSE_SEQUENCE[@]} -gt 0 ]]; then
    local idx=0
    [[ -f "${MOCK_CALL_COUNTER_FILE}.choose" ]] && idx=$(cat "${MOCK_CALL_COUNTER_FILE}.choose")
    local val="${MOCK_WIZ_CHOOSE_SEQUENCE[$idx]:-}"
    echo $((idx + 1)) > "${MOCK_CALL_COUNTER_FILE}.choose"
    # Empty string in sequence means return 1 (cancel)
    if [[ -z $val ]]; then
      return 1
    fi
    echo "$val"
  else
    echo "$MOCK_WIZ_CHOOSE_VALUE"
  fi
}

# =============================================================================
# Additional UI mocks
# =============================================================================

_wiz_start_edit() {
  echo "_wiz_start_edit" >> "${MOCK_CALL_COUNTER_FILE}.calls" 2>/dev/null || true
}
_wiz_blank_line() { :; }
_wiz_warn() {
  echo "WARN: $*" >> "${MOCK_CALL_COUNTER_FILE}.calls" 2>/dev/null || true
}
_wiz_error() { :; }
_wiz_description() { :; }
_wiz_input_screen() { :; }
_wiz_dim() { :; }
_show_input_footer() { :; }
show_validation_error() {
  echo "show_validation_error: $1" >> "${MOCK_CALL_COUNTER_FILE}.calls" 2>/dev/null || true
}

# =============================================================================
# SSH-related mocks
# =============================================================================

get_rescue_ssh_key() {
  echo "$MOCK_RESCUE_SSH_KEY"
}

parse_ssh_key() {
  local key="$1"
  [[ -z $key ]] && return 1

  SSH_KEY_TYPE=$(printf '%s\n' "$key" | awk '{print $1}')
  SSH_KEY_DATA=$(printf '%s\n' "$key" | awk '{print $2}')
  SSH_KEY_COMMENT=$(printf '%s\n' "$key" | awk '{$1=""; $2=""; print}' | sed 's/^ *//')

  if [[ ${#SSH_KEY_DATA} -gt 35 ]]; then
    SSH_KEY_SHORT="${SSH_KEY_DATA:0:20}...${SSH_KEY_DATA: -10}"
  else
    SSH_KEY_SHORT="$SSH_KEY_DATA"
  fi
}

validate_ssh_key_secure() {
  return "$MOCK_VALIDATE_SSH_KEY_RESULT"
}

# =============================================================================
# Validation mocks
# =============================================================================

validate_admin_username() {
  local username="$1"
  # Must be lowercase alphanumeric, start with letter
  [[ ! $username =~ ^[a-z][a-z0-9_-]{0,31}$ ]] && return 1
  # Block reserved names
  case "$username" in
    root | admin | administrator | operator | guest | nobody | daemon) return 1 ;;
    *) return 0 ;;
  esac
}

get_password_error() {
  local password="$1"
  if [[ -z $password ]]; then
    printf '%s\n' "Password cannot be empty!"
  elif [[ ${#password} -lt 8 ]]; then
    printf '%s\n' "Password must be at least 8 characters long."
  fi
}

generate_password() {
  echo "generated_password_123"
}

# =============================================================================
# Constants
# =============================================================================

WIZ_SSH_KEY_OPTIONS="Use detected key
Enter different key"

WIZ_PASSWORD_OPTIONS="Generate password
Manual entry"

WIZ_TOGGLE_OPTIONS="Enabled
Disabled"

DEFAULT_PASSWORD_LENGTH=16

# =============================================================================
# Tests
# =============================================================================

Describe "115-wizard-access.sh"
  Include "$SCRIPTS_DIR/115-wizard-access.sh"

  # ===========================================================================
  # _edit_ssh_key()
  # ===========================================================================
  Describe "_edit_ssh_key()"
    BeforeEach 'reset_wizard_access_mocks'

    Describe "with detected SSH key"
      BeforeEach 'MOCK_RESCUE_SSH_KEY="ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAITest1234567890abcdefghij user@host"'

      It "sets SSH_PUBLIC_KEY when 'Use detected key' selected"
        MOCK_WIZ_CHOOSE_VALUE="Use detected key"
        When call _edit_ssh_key
        The variable SSH_PUBLIC_KEY should equal "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAITest1234567890abcdefghij user@host"
        The output should include "ssh-ed25519"
      End

      It "prompts for manual entry when 'Enter different key' selected"
        MOCK_WIZ_CHOOSE_SEQUENCE=("Enter different key" "")
        MOCK_WIZ_INPUT_VALUE=""
        When call _edit_ssh_key
        The output should include "ssh-ed25519"
        Assert mock_calls_include "_wiz_input"
      End

      It "accepts valid manually entered key after choosing 'Enter different key'"
        MOCK_WIZ_CHOOSE_VALUE="Enter different key"
        MOCK_WIZ_INPUT_VALUE="ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABgQC... manual@key"
        MOCK_VALIDATE_SSH_KEY_RESULT=0
        When call _edit_ssh_key
        The variable SSH_PUBLIC_KEY should equal "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABgQC... manual@key"
        The output should include "ssh-ed25519"
      End

      It "returns to menu when invalid key entered with detected key available"
        MOCK_WIZ_CHOOSE_SEQUENCE=("Enter different key" "Use detected key")
        MOCK_WIZ_INPUT_VALUE="invalid-key"
        MOCK_VALIDATE_SSH_KEY_RESULT=1
        When call _edit_ssh_key
        The output should include "ssh-ed25519"
        Assert mock_calls_include "show_validation_error"
        The variable SSH_PUBLIC_KEY should equal "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAITest1234567890abcdefghij user@host"
      End

      It "returns without changes when cancelled on menu"
        MOCK_WIZ_CHOOSE_CANCELLED=true
        SSH_PUBLIC_KEY="original"
        When call _edit_ssh_key
        The output should include "ssh-ed25519"
        The variable SSH_PUBLIC_KEY should equal "original"
      End
    End

    Describe "without detected SSH key"
      BeforeEach 'MOCK_RESCUE_SSH_KEY=""'

      It "prompts for manual entry directly"
        MOCK_WIZ_INPUT_VALUE="ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIManual test@key"
        MOCK_VALIDATE_SSH_KEY_RESULT=0
        When call _edit_ssh_key
        The variable SSH_PUBLIC_KEY should equal "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIManual test@key"
      End

      It "returns without changes when input cancelled"
        MOCK_WIZ_INPUT_CANCELLED=true
        SSH_PUBLIC_KEY="original"
        When call _edit_ssh_key
        # Returns 1 when cancelled with no detected key (last conditional exit status)
        The status should equal 1
        The variable SSH_PUBLIC_KEY should equal "original"
      End

      It "shows validation error for invalid key"
        MOCK_WIZ_INPUT_SEQUENCE=("invalid-key" "")
        MOCK_VALIDATE_SSH_KEY_RESULT=1
        When call _edit_ssh_key
        # Returns 1 when cancelled after validation error (last conditional exit status)
        The status should equal 1
        Assert mock_calls_include "show_validation_error"
      End

      It "accepts key after retry"
        MOCK_WIZ_INPUT_SEQUENCE=("invalid-key" "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIValid key@host")
        # First call fails, second succeeds
        validate_ssh_key_secure() {
          local idx=0
          [[ -f "${MOCK_CALL_COUNTER_FILE}.validate" ]] && idx=$(cat "${MOCK_CALL_COUNTER_FILE}.validate")
          echo $((idx + 1)) > "${MOCK_CALL_COUNTER_FILE}.validate"
          [[ $idx -eq 0 ]] && return 1
          return 0
        }
        When call _edit_ssh_key
        The variable SSH_PUBLIC_KEY should equal "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIValid key@host"
      End
    End
  End

  # ===========================================================================
  # _edit_admin_username()
  # ===========================================================================
  Describe "_edit_admin_username()"
    BeforeEach 'reset_wizard_access_mocks'

    It "sets ADMIN_USERNAME with valid input"
      MOCK_WIZ_INPUT_VALUE="sysadmin"
      When call _edit_admin_username
      The variable ADMIN_USERNAME should equal "sysadmin"
    End

    It "accepts username with numbers"
      MOCK_WIZ_INPUT_VALUE="admin01"
      When call _edit_admin_username
      The variable ADMIN_USERNAME should equal "admin01"
    End

    It "accepts username with underscore"
      MOCK_WIZ_INPUT_VALUE="sys_admin"
      When call _edit_admin_username
      The variable ADMIN_USERNAME should equal "sys_admin"
    End

    It "accepts username with hyphen"
      MOCK_WIZ_INPUT_VALUE="sys-admin"
      When call _edit_admin_username
      The variable ADMIN_USERNAME should equal "sys-admin"
    End

    It "returns without changes when cancelled"
      MOCK_WIZ_INPUT_CANCELLED=true
      ADMIN_USERNAME="original"
      When call _edit_admin_username
      The variable ADMIN_USERNAME should equal "original"
    End

    Describe "with invalid username"
      It "shows error for 'root'"
        MOCK_WIZ_INPUT_SEQUENCE=("root" "")
        When call _edit_admin_username
        Assert mock_calls_include "show_validation_error"
      End

      It "shows error for 'admin'"
        MOCK_WIZ_INPUT_SEQUENCE=("admin" "")
        When call _edit_admin_username
        Assert mock_calls_include "show_validation_error"
      End

      It "shows error for username starting with number"
        MOCK_WIZ_INPUT_SEQUENCE=("1user" "")
        When call _edit_admin_username
        Assert mock_calls_include "show_validation_error"
      End

      It "shows error for uppercase username"
        MOCK_WIZ_INPUT_SEQUENCE=("Admin" "")
        When call _edit_admin_username
        Assert mock_calls_include "show_validation_error"
      End

      It "shows error for username with special characters"
        MOCK_WIZ_INPUT_SEQUENCE=("user@name" "")
        When call _edit_admin_username
        Assert mock_calls_include "show_validation_error"
      End
    End

    Describe "with retry after invalid input"
      It "accepts valid username after invalid attempt"
        MOCK_WIZ_INPUT_SEQUENCE=("root" "validuser")
        When call _edit_admin_username
        The variable ADMIN_USERNAME should equal "validuser"
      End
    End
  End

  # ===========================================================================
  # _edit_admin_password()
  # ===========================================================================
  Describe "_edit_admin_password()"
    BeforeEach 'reset_wizard_access_mocks'

    Describe "generate password option"
      It "generates password when selected"
        MOCK_WIZ_CHOOSE_VALUE="Generate password"
        When call _edit_admin_password </dev/null
        The variable ADMIN_PASSWORD should equal "generated_password_123"
        The output should include "Generated admin password"
      End

      It "shows warning to save password"
        MOCK_WIZ_CHOOSE_VALUE="Generate password"
        When call _edit_admin_password </dev/null
        The output should include "Generated admin password"
        Assert mock_calls_include "WARN: Please save this password"
      End
    End

    Describe "manual entry option"
      It "sets password when valid"
        MOCK_WIZ_CHOOSE_VALUE="Manual entry"
        MOCK_WIZ_INPUT_VALUE="ValidPass123!"
        When call _edit_admin_password
        The variable ADMIN_PASSWORD should equal "ValidPass123!"
      End

      It "returns to menu when password empty"
        MOCK_WIZ_CHOOSE_SEQUENCE=("Manual entry" "")
        MOCK_WIZ_INPUT_VALUE=""
        When call _edit_admin_password
        The variable ADMIN_PASSWORD should be blank
      End

      It "shows error for short password"
        MOCK_WIZ_CHOOSE_SEQUENCE=("Manual entry" "Manual entry" "")
        MOCK_WIZ_INPUT_SEQUENCE=("short" "")
        When call _edit_admin_password
        Assert mock_calls_include "show_validation_error"
      End

      It "accepts valid password after invalid attempt"
        MOCK_WIZ_CHOOSE_SEQUENCE=("Manual entry" "Manual entry")
        MOCK_WIZ_INPUT_SEQUENCE=("short" "ValidPassword123")
        When call _edit_admin_password
        The variable ADMIN_PASSWORD should equal "ValidPassword123"
      End
    End

    Describe "when cancelled"
      It "returns without changes"
        MOCK_WIZ_CHOOSE_CANCELLED=true
        ADMIN_PASSWORD="original"
        When call _edit_admin_password
        The variable ADMIN_PASSWORD should equal "original"
      End
    End
  End

  # ===========================================================================
  # _edit_api_token()
  # ===========================================================================
  Describe "_edit_api_token()"
    BeforeEach 'reset_wizard_access_mocks'

    Describe "when enabled"
      It "sets INSTALL_API_TOKEN to yes with default name"
        MOCK_WIZ_CHOOSE_VALUE="Enabled"
        MOCK_WIZ_INPUT_VALUE=""
        When call _edit_api_token
        The variable INSTALL_API_TOKEN should equal "yes"
        The variable API_TOKEN_NAME should equal "automation"
      End

      It "sets custom token name when provided"
        MOCK_WIZ_CHOOSE_VALUE="Enabled"
        MOCK_WIZ_INPUT_VALUE="terraform"
        When call _edit_api_token
        The variable INSTALL_API_TOKEN should equal "yes"
        The variable API_TOKEN_NAME should equal "terraform"
      End

      It "accepts token name with hyphens"
        MOCK_WIZ_CHOOSE_VALUE="Enabled"
        MOCK_WIZ_INPUT_VALUE="my-token"
        When call _edit_api_token
        The variable API_TOKEN_NAME should equal "my-token"
      End

      It "accepts token name with underscores"
        MOCK_WIZ_CHOOSE_VALUE="Enabled"
        MOCK_WIZ_INPUT_VALUE="my_token"
        When call _edit_api_token
        The variable API_TOKEN_NAME should equal "my_token"
      End

      It "falls back to default for invalid token name"
        MOCK_WIZ_CHOOSE_VALUE="Enabled"
        MOCK_WIZ_INPUT_VALUE="invalid@name!"
        When call _edit_api_token
        The variable API_TOKEN_NAME should equal "automation"
      End

      It "preserves existing token name in input"
        API_TOKEN_NAME="existing"
        MOCK_WIZ_CHOOSE_VALUE="Enabled"
        MOCK_WIZ_INPUT_VALUE="existing"
        When call _edit_api_token
        The variable API_TOKEN_NAME should equal "existing"
      End
    End

    Describe "when disabled"
      It "sets INSTALL_API_TOKEN to no"
        MOCK_WIZ_CHOOSE_VALUE="Disabled"
        When call _edit_api_token
        The variable INSTALL_API_TOKEN should equal "no"
      End

      It "does not prompt for token name"
        MOCK_WIZ_CHOOSE_VALUE="Disabled"
        When call _edit_api_token
        The variable API_TOKEN_NAME should be blank
      End
    End

    Describe "when cancelled"
      It "returns without changes"
        MOCK_WIZ_CHOOSE_CANCELLED=true
        INSTALL_API_TOKEN="original"
        When call _edit_api_token
        The variable INSTALL_API_TOKEN should equal "original"
      End
    End
  End
End

