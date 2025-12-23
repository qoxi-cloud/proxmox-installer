# shellcheck shell=bash
# shellcheck disable=SC2034
# =============================================================================
# Wizard mocks for testing wizard screen functions
# =============================================================================
#
# Usage in spec files:
#   %const SUPPORT_DIR: "${SHELLSPEC_PROJECT_ROOT}/spec/support"
#   eval "$(cat "$SUPPORT_DIR/wizard_mocks.sh")"
#   BeforeEach 'reset_wizard_mocks'

# =============================================================================
# Mock control variables
# =============================================================================
MOCK_WIZ_INPUT_SEQUENCE=()
MOCK_WIZ_INPUT_INDEX=0
MOCK_WIZ_CHOOSE_VALUE=""
MOCK_WIZ_CHOOSE_MULTI_VALUES=()
MOCK_WIZ_FILTER_VALUE=""
MOCK_WIZ_READ_KEY=""
MOCK_CONFIRM_RESULT=0
MOCK_CONFIG_COMPLETE=0
MOCK_GUM_RESULT=0
MOCK_CALLS=()
MOCK_EDIT_CALLS=()

# =============================================================================
# Reset mock state
# =============================================================================
reset_wizard_mocks() {
  MOCK_WIZ_INPUT_SEQUENCE=()
  MOCK_WIZ_INPUT_INDEX=0
  MOCK_WIZ_CHOOSE_VALUE=""
  MOCK_WIZ_CHOOSE_MULTI_VALUES=()
  MOCK_WIZ_FILTER_VALUE=""
  MOCK_WIZ_READ_KEY=""
  MOCK_CONFIRM_RESULT=0
  MOCK_CONFIG_COMPLETE=0
  MOCK_GUM_RESULT=0
  MOCK_CALLS=()
  MOCK_EDIT_CALLS=()
  # Reset counter files
  rm -f /tmp/test_wizard_input_counter 2>/dev/null
}

# =============================================================================
# Helper functions
# =============================================================================
mock_calls_include() {
  local pattern="$1"
  for call in "${MOCK_CALLS[@]}"; do
    [[ "$call" == *"$pattern"* ]] && return 0
  done
  return 1
}

mock_calls_starts_with() {
  local pattern="$1"
  [[ ${#MOCK_CALLS[@]} -gt 0 && "${MOCK_CALLS[0]}" == *"$pattern"* ]]
}

# =============================================================================
# Wizard UI function mocks
# =============================================================================
_wiz_start_edit() { MOCK_CALLS+=("_wiz_start_edit"); }
_wiz_description() { :; }
_wiz_blank_line() { :; }
_wiz_input_screen() { :; }
_wiz_error() { :; }
_wiz_warn() { :; }
_wiz_info() { :; }
_wiz_dim() { :; }
_show_input_footer() { :; }
show_validation_error() { MOCK_CALLS+=("show_validation_error: $1"); }
register_temp_file() { :; }

# =============================================================================
# _wiz_input mock with sequence support
# Uses file-based counter for subshell compatibility
# =============================================================================
_wiz_input() {
  MOCK_CALLS+=("_wiz_input: $1")
  
  local counter_file="/tmp/test_wizard_input_counter"
  local idx=0
  
  # Read and increment counter
  if [[ -f "$counter_file" ]]; then
    idx=$(cat "$counter_file")
  fi
  echo $((idx + 1)) > "$counter_file"
  
  # Return value from sequence or empty
  if [[ $idx -lt ${#MOCK_WIZ_INPUT_SEQUENCE[@]} ]]; then
    echo "${MOCK_WIZ_INPUT_SEQUENCE[$idx]}"
  else
    echo ""
  fi
}

# =============================================================================
# _wiz_choose mock
# =============================================================================
_wiz_choose() {
  MOCK_CALLS+=("_wiz_choose: $1")
  echo "$MOCK_WIZ_CHOOSE_VALUE"
}

# =============================================================================
# _wiz_choose_multi mock
# =============================================================================
_wiz_choose_multi() {
  MOCK_CALLS+=("_wiz_choose_multi: $1")
  printf '%s\n' "${MOCK_WIZ_CHOOSE_MULTI_VALUES[@]}"
}

# =============================================================================
# _wiz_filter mock
# =============================================================================
_wiz_filter() {
  MOCK_CALLS+=("_wiz_filter: $1")
  echo "$MOCK_WIZ_FILTER_VALUE"
}

# =============================================================================
# _wiz_read_key mock
# =============================================================================
_wiz_read_key() {
  echo "$MOCK_WIZ_READ_KEY"
}

# =============================================================================
# _wiz_render_menu mock
# =============================================================================
_wiz_render_menu() {
  MOCK_CALLS+=("_wiz_render_menu")
}

# =============================================================================
# _wiz_confirm mock
# =============================================================================
_wiz_confirm() {
  MOCK_CALLS+=("_wiz_confirm: $*")
  return $MOCK_CONFIRM_RESULT
}

# =============================================================================
# _wiz_config_complete mock
# =============================================================================
_wiz_config_complete() {
  return $MOCK_CONFIG_COMPLETE
}

# =============================================================================
# _wiz_center mock
# =============================================================================
_wiz_center() {
  echo "$1"
}

# =============================================================================
# _wiz_fmt mock
# =============================================================================
_wiz_fmt() {
  echo "$*"
}

# =============================================================================
# generate_password mock
# =============================================================================
generate_password() {
  echo "generated_password_123"
}

# =============================================================================
# Mock edit functions - track calls
# =============================================================================
_edit_hostname() { MOCK_EDIT_CALLS+=("hostname"); }
_edit_email() { MOCK_EDIT_CALLS+=("email"); }
_edit_password() { MOCK_EDIT_CALLS+=("password"); }
_edit_timezone() { MOCK_EDIT_CALLS+=("timezone"); }
_edit_keyboard() { MOCK_EDIT_CALLS+=("keyboard"); }
_edit_country() { MOCK_EDIT_CALLS+=("country"); }
_edit_iso_version() { MOCK_EDIT_CALLS+=("iso_version"); }
_edit_interface() { MOCK_EDIT_CALLS+=("interface"); }
_edit_ipv4() { MOCK_EDIT_CALLS+=("ipv4"); }
_edit_ipv6() { MOCK_EDIT_CALLS+=("ipv6"); }
_edit_boot_disk() { MOCK_EDIT_CALLS+=("boot_disk"); }
_edit_pool_disks() { MOCK_EDIT_CALLS+=("pool_disks"); }
_edit_zfs_raid() { MOCK_EDIT_CALLS+=("zfs_raid"); }

