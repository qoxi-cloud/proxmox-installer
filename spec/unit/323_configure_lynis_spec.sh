# shellcheck shell=bash
# shellcheck disable=SC2034
# =============================================================================
# Tests for 323-configure-lynis.sh
# =============================================================================

%const SCRIPTS_DIR: "${SHELLSPEC_PROJECT_ROOT}/scripts"
%const SUPPORT_DIR: "${SHELLSPEC_PROJECT_ROOT}/spec/support"

# Load shared mocks
eval "$(cat "$SUPPORT_DIR/configure_mocks.sh")"

# Additional mock for install_optional_feature_with_progress
install_optional_feature_with_progress() {
  local name="$1"
  local install_var="$2"
  local install_func="$3"
  local config_func="$4"
  local installed_var="$5"

  local install_value
  install_value="${!install_var:-}"

  if [[ "${install_value,,}" != "yes" ]]; then
    return 0
  fi

  "$install_func" || return 1
  "$config_func" || return 1

  if [[ -n "$installed_var" ]]; then
    eval "$installed_var=yes"
  fi
  return 0
}

Describe "323-configure-lynis.sh"
Include "$SCRIPTS_DIR/323-configure-lynis.sh"

# ===========================================================================
# _install_lynis()
# ===========================================================================
Describe "_install_lynis()"
It "calls run_remote successfully"
MOCK_RUN_REMOTE_RESULT=0
When call _install_lynis
The status should be success
End
End

# ===========================================================================
# configure_lynis()
# ===========================================================================
Describe "configure_lynis()"
It "skips when INSTALL_LYNIS is not yes"
INSTALL_LYNIS="no"
LYNIS_INSTALLED=""
When call configure_lynis
The status should be success
The variable LYNIS_INSTALLED should equal ""
End

It "installs when INSTALL_LYNIS is yes"
INSTALL_LYNIS="yes"
LYNIS_INSTALLED=""
MOCK_RUN_REMOTE_RESULT=0
MOCK_REMOTE_COPY_RESULT=0
MOCK_REMOTE_EXEC_RESULT=0
When call configure_lynis
The status should be success
The variable LYNIS_INSTALLED should equal "yes"
End
End
End
