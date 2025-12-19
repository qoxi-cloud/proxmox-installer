# shellcheck shell=bash
# shellcheck disable=SC2034
# =============================================================================
# Tests for 324-configure-needrestart.sh
# =============================================================================

%const SCRIPTS_DIR: "${SHELLSPEC_PROJECT_ROOT}/scripts"
%const SUPPORT_DIR: "${SHELLSPEC_PROJECT_ROOT}/spec/support"

# Load shared mocks
eval "$(cat "$SUPPORT_DIR/configure_mocks.sh")"

Describe "324-configure-needrestart.sh"
Include "$SCRIPTS_DIR/324-configure-needrestart.sh"

# ===========================================================================
# _install_needrestart()
# ===========================================================================
Describe "_install_needrestart()"
It "calls run_remote successfully"
MOCK_RUN_REMOTE_RESULT=0
When call _install_needrestart
The status should be success
End

It "fails when run_remote fails"
MOCK_RUN_REMOTE_RESULT=1
When call _install_needrestart
The status should be failure
End
End

# ===========================================================================
# _config_needrestart()
# ===========================================================================
Describe "_config_needrestart()"
It "deploys template successfully"
MOCK_DEPLOY_TEMPLATE_RESULT=0
When call _config_needrestart
The status should be success
End

It "fails when deploy_template fails"
MOCK_DEPLOY_TEMPLATE_RESULT=1
When call _config_needrestart
The status should be failure
End
End

# ===========================================================================
# configure_needrestart()
# ===========================================================================
Describe "configure_needrestart()"
It "skips when INSTALL_NEEDRESTART is not yes"
INSTALL_NEEDRESTART="no"
NEEDRESTART_INSTALLED=""
When call configure_needrestart
The status should be success
The variable NEEDRESTART_INSTALLED should equal ""
End

It "skips when INSTALL_NEEDRESTART is empty"
INSTALL_NEEDRESTART=""
NEEDRESTART_INSTALLED=""
When call configure_needrestart
The status should be success
The variable NEEDRESTART_INSTALLED should equal ""
End

It "installs when INSTALL_NEEDRESTART is yes"
INSTALL_NEEDRESTART="yes"
NEEDRESTART_INSTALLED=""
MOCK_RUN_REMOTE_RESULT=0
MOCK_DEPLOY_TEMPLATE_RESULT=0
When call configure_needrestart
The status should be success
The variable NEEDRESTART_INSTALLED should equal "yes"
End
End
End
