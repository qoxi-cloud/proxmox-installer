# shellcheck shell=bash
# shellcheck disable=SC2034
# =============================================================================
# Tests for 322-configure-chkrootkit.sh
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

Describe "322-configure-chkrootkit.sh"
Include "$SCRIPTS_DIR/322-configure-chkrootkit.sh"

# ===========================================================================
# _install_chkrootkit()
# ===========================================================================
Describe "_install_chkrootkit()"
It "calls run_remote successfully"
MOCK_RUN_REMOTE_RESULT=0
When call _install_chkrootkit
The status should be success
End
End

# ===========================================================================
# configure_chkrootkit()
# ===========================================================================
Describe "configure_chkrootkit()"
It "skips when INSTALL_CHKROOTKIT is not yes"
INSTALL_CHKROOTKIT="no"
CHKROOTKIT_INSTALLED=""
When call configure_chkrootkit
The status should be success
The variable CHKROOTKIT_INSTALLED should equal ""
End

It "installs when INSTALL_CHKROOTKIT is yes"
INSTALL_CHKROOTKIT="yes"
CHKROOTKIT_INSTALLED=""
MOCK_RUN_REMOTE_RESULT=0
MOCK_DEPLOY_TEMPLATES_RESULT=0
MOCK_REMOTE_EXEC_RESULT=0
When call configure_chkrootkit
The status should be success
The variable CHKROOTKIT_INSTALLED should equal "yes"
End
End
End
