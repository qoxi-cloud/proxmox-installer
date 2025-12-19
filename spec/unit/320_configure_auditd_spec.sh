# shellcheck shell=bash
# shellcheck disable=SC2034
# =============================================================================
# Tests for 320-configure-auditd.sh
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

Describe "320-configure-auditd.sh"
Include "$SCRIPTS_DIR/320-configure-auditd.sh"

# ===========================================================================
# _install_auditd()
# ===========================================================================
Describe "_install_auditd()"
It "calls run_remote successfully"
MOCK_RUN_REMOTE_RESULT=0
When call _install_auditd
The status should be success
End
End

# ===========================================================================
# _config_auditd()
# ===========================================================================
Describe "_config_auditd()"
It "configures successfully"
MOCK_REMOTE_COPY_RESULT=0
MOCK_REMOTE_EXEC_RESULT=0
When call _config_auditd
The status should be success
End
End

# ===========================================================================
# configure_auditd()
# ===========================================================================
Describe "configure_auditd()"
It "skips when INSTALL_AUDITD is not yes"
INSTALL_AUDITD="no"
AUDITD_INSTALLED=""
When call configure_auditd
The status should be success
The variable AUDITD_INSTALLED should equal ""
End

It "installs when INSTALL_AUDITD is yes"
INSTALL_AUDITD="yes"
AUDITD_INSTALLED=""
MOCK_RUN_REMOTE_RESULT=0
MOCK_REMOTE_COPY_RESULT=0
MOCK_REMOTE_EXEC_RESULT=0
When call configure_auditd
The status should be success
The variable AUDITD_INSTALLED should equal "yes"
End
End
End
