# shellcheck shell=bash
# shellcheck disable=SC2034
# =============================================================================
# Tests for 311-configure-fail2ban.sh
# =============================================================================

%const SCRIPTS_DIR: "${SHELLSPEC_PROJECT_ROOT}/scripts"
%const SUPPORT_DIR: "${SHELLSPEC_PROJECT_ROOT}/spec/support"

# Load shared mocks
eval "$(cat "$SUPPORT_DIR/configure_mocks.sh")"

# Additional mocks for fail2ban
apply_template_vars() { return 0; }

Describe "311-configure-fail2ban.sh"
Include "$SCRIPTS_DIR/311-configure-fail2ban.sh"

# ===========================================================================
# _install_fail2ban()
# ===========================================================================
Describe "_install_fail2ban()"
It "calls run_remote successfully"
MOCK_RUN_REMOTE_RESULT=0
When call _install_fail2ban
The status should be success
End
End

# ===========================================================================
# configure_fail2ban()
# ===========================================================================
Describe "configure_fail2ban()"
It "skips when INSTALL_FIREWALL is not yes"
INSTALL_FIREWALL="no"
FAIL2BAN_INSTALLED=""
When call configure_fail2ban
The status should be success
The variable FAIL2BAN_INSTALLED should equal ""
End

It "skips in stealth mode"
INSTALL_FIREWALL="yes"
FIREWALL_MODE="stealth"
FAIL2BAN_INSTALLED=""
When call configure_fail2ban
The status should be success
The variable FAIL2BAN_INSTALLED should equal ""
End

It "installs when firewall enabled and not stealth"
INSTALL_FIREWALL="yes"
FIREWALL_MODE="standard"
FAIL2BAN_INSTALLED=""
MOCK_RUN_REMOTE_RESULT=0
MOCK_REMOTE_COPY_RESULT=0
MOCK_REMOTE_EXEC_RESULT=0
When call configure_fail2ban
The status should be success
The variable FAIL2BAN_INSTALLED should equal "yes"
End

It "installs in strict mode"
INSTALL_FIREWALL="yes"
FIREWALL_MODE="strict"
FAIL2BAN_INSTALLED=""
MOCK_RUN_REMOTE_RESULT=0
MOCK_REMOTE_COPY_RESULT=0
MOCK_REMOTE_EXEC_RESULT=0
When call configure_fail2ban
The status should be success
The variable FAIL2BAN_INSTALLED should equal "yes"
End
End
End
