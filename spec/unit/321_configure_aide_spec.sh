# shellcheck shell=bash
# shellcheck disable=SC2034
# =============================================================================
# Tests for 321-configure-aide.sh
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

Describe "321-configure-aide.sh"
Include "$SCRIPTS_DIR/321-configure-aide.sh"

# ===========================================================================
# _install_aide()
# ===========================================================================
Describe "_install_aide()"
It "calls run_remote successfully"
MOCK_RUN_REMOTE_RESULT=0
When call _install_aide
The status should be success
End
End

# ===========================================================================
# configure_aide()
# ===========================================================================
Describe "configure_aide()"
It "skips when INSTALL_AIDE is not yes"
INSTALL_AIDE="no"
AIDE_INSTALLED=""
When call configure_aide
The status should be success
The variable AIDE_INSTALLED should equal ""
End

It "installs when INSTALL_AIDE is yes"
INSTALL_AIDE="yes"
AIDE_INSTALLED=""
MOCK_RUN_REMOTE_RESULT=0
MOCK_REMOTE_COPY_RESULT=0
MOCK_REMOTE_EXEC_RESULT=0
When call configure_aide
The status should be success
The variable AIDE_INSTALLED should equal "yes"
End
End
End
