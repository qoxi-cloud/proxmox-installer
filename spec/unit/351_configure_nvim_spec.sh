# shellcheck shell=bash
# shellcheck disable=SC2034
# =============================================================================
# Tests for 351-configure-nvim.sh
# =============================================================================

%const SCRIPTS_DIR: "${SHELLSPEC_PROJECT_ROOT}/scripts"
%const SUPPORT_DIR: "${SHELLSPEC_PROJECT_ROOT}/spec/support"

# Load shared mocks
eval "$(cat "$SUPPORT_DIR/configure_mocks.sh")"

Describe "351-configure-nvim.sh"
Include "$SCRIPTS_DIR/351-configure-nvim.sh"

Describe "_install_nvim()"
It "calls run_remote successfully"
MOCK_RUN_REMOTE_RESULT=0
When call _install_nvim
The status should be success
End
End

Describe "_config_nvim()"
It "configures alternatives successfully"
MOCK_REMOTE_EXEC_RESULT=0
When call _config_nvim
The status should be success
End
End

Describe "configure_nvim()"
It "skips when INSTALL_NVIM is not yes"
INSTALL_NVIM="no"
NVIM_INSTALLED=""
When call configure_nvim
The status should be success
The variable NVIM_INSTALLED should equal ""
End

It "installs when INSTALL_NVIM is yes"
INSTALL_NVIM="yes"
NVIM_INSTALLED=""
MOCK_RUN_REMOTE_RESULT=0
MOCK_REMOTE_EXEC_RESULT=0
When call configure_nvim
The status should be success
The variable NVIM_INSTALLED should equal "yes"
End
End
End
