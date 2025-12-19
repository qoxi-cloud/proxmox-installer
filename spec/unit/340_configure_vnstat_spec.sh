# shellcheck shell=bash
# shellcheck disable=SC2034
# =============================================================================
# Tests for 340-configure-vnstat.sh
# =============================================================================

%const SCRIPTS_DIR: "${SHELLSPEC_PROJECT_ROOT}/scripts"
%const SUPPORT_DIR: "${SHELLSPEC_PROJECT_ROOT}/spec/support"

# Load shared mocks
eval "$(cat "$SUPPORT_DIR/configure_mocks.sh")"

Describe "340-configure-vnstat.sh"
Include "$SCRIPTS_DIR/340-configure-vnstat.sh"

Describe "_install_vnstat()"
It "calls run_remote successfully"
MOCK_RUN_REMOTE_RESULT=0
When call _install_vnstat
The status should be success
End
End

Describe "_config_vnstat()"
It "configures successfully"
MOCK_DEPLOY_TEMPLATE_RESULT=0
MOCK_REMOTE_EXEC_RESULT=0
INTERFACE_NAME="eth0"
When call _config_vnstat
The status should be success
End
End

Describe "configure_vnstat()"
It "skips when INSTALL_VNSTAT is not yes"
INSTALL_VNSTAT="no"
VNSTAT_INSTALLED=""
When call configure_vnstat
The status should be success
The variable VNSTAT_INSTALLED should equal ""
End

It "installs when INSTALL_VNSTAT is yes"
INSTALL_VNSTAT="yes"
VNSTAT_INSTALLED=""
MOCK_RUN_REMOTE_RESULT=0
MOCK_DEPLOY_TEMPLATE_RESULT=0
MOCK_REMOTE_EXEC_RESULT=0
When call configure_vnstat
The status should be success
The variable VNSTAT_INSTALLED should equal "yes"
End
End
End
