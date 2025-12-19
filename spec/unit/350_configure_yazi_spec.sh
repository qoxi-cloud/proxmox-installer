# shellcheck shell=bash
# shellcheck disable=SC2034
# =============================================================================
# Tests for 350-configure-yazi.sh
# =============================================================================

%const SCRIPTS_DIR: "${SHELLSPEC_PROJECT_ROOT}/scripts"
%const SUPPORT_DIR: "${SHELLSPEC_PROJECT_ROOT}/spec/support"

# Load shared mocks
eval "$(cat "$SUPPORT_DIR/configure_mocks.sh")"

Describe "350-configure-yazi.sh"
Include "$SCRIPTS_DIR/350-configure-yazi.sh"

Describe "_install_yazi()"
It "calls run_remote successfully"
MOCK_RUN_REMOTE_RESULT=0
When call _install_yazi
The status should be success
End
End

Describe "_config_yazi()"
It "configures successfully"
MOCK_REMOTE_EXEC_RESULT=0
MOCK_REMOTE_COPY_RESULT=0
When call _config_yazi
The status should be success
End
End

Describe "configure_yazi()"
It "skips when INSTALL_YAZI is not yes"
INSTALL_YAZI="no"
YAZI_INSTALLED=""
When call configure_yazi
The status should be success
The variable YAZI_INSTALLED should equal ""
End

It "installs when INSTALL_YAZI is yes"
INSTALL_YAZI="yes"
YAZI_INSTALLED=""
MOCK_RUN_REMOTE_RESULT=0
MOCK_REMOTE_EXEC_RESULT=0
MOCK_REMOTE_COPY_RESULT=0
When call configure_yazi
The status should be success
The variable YAZI_INSTALLED should equal "yes"
End
End
End
