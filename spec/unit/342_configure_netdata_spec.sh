# shellcheck shell=bash
# shellcheck disable=SC2034
# =============================================================================
# Tests for 342-configure-netdata.sh
# =============================================================================

%const SCRIPTS_DIR: "${SHELLSPEC_PROJECT_ROOT}/scripts"
%const SUPPORT_DIR: "${SHELLSPEC_PROJECT_ROOT}/spec/support"

# Load shared mocks
eval "$(cat "$SUPPORT_DIR/configure_mocks.sh")"

Describe "342-configure-netdata.sh"
Include "$SCRIPTS_DIR/342-configure-netdata.sh"

# ===========================================================================
# _install_netdata()
# ===========================================================================
Describe "_install_netdata()"
It "calls run_remote successfully"
MOCK_RUN_REMOTE_RESULT=0
When call _install_netdata
The status should be success
End
End

# ===========================================================================
# configure_netdata()
# ===========================================================================
Describe "configure_netdata()"
It "skips when INSTALL_NETDATA is not yes"
INSTALL_NETDATA="no"
When call configure_netdata
The status should be success
End

It "installs when INSTALL_NETDATA is yes"
INSTALL_NETDATA="yes"
INSTALL_TAILSCALE="no"
MAIN_IPV4="1.2.3.4"
MOCK_RUN_REMOTE_RESULT=0
MOCK_APPLY_TEMPLATE_VARS_RESULT=0
MOCK_REMOTE_COPY_RESULT=0
MOCK_REMOTE_EXEC_RESULT=0
When call configure_netdata
The status should be success
End
End
End
