# shellcheck shell=bash
# shellcheck disable=SC2034
# =============================================================================
# Tests for 312-configure-apparmor.sh
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

Describe "312-configure-apparmor.sh"
Include "$SCRIPTS_DIR/312-configure-apparmor.sh"

# ===========================================================================
# _install_apparmor()
# ===========================================================================
Describe "_install_apparmor()"
It "calls run_remote successfully"
MOCK_RUN_REMOTE_RESULT=0
When call _install_apparmor
The status should be success
End
End

# ===========================================================================
# configure_apparmor()
# ===========================================================================
Describe "configure_apparmor()"
It "skips when INSTALL_APPARMOR is not yes"
INSTALL_APPARMOR="no"
APPARMOR_INSTALLED=""
When call configure_apparmor
The status should be success
The variable APPARMOR_INSTALLED should equal ""
End

It "installs when INSTALL_APPARMOR is yes"
INSTALL_APPARMOR="yes"
APPARMOR_INSTALLED=""
MOCK_RUN_REMOTE_RESULT=0
MOCK_REMOTE_COPY_RESULT=0
MOCK_REMOTE_EXEC_RESULT=0
When call configure_apparmor
The status should be success
The variable APPARMOR_INSTALLED should equal "yes"
End
End
End
