# shellcheck shell=bash
# shellcheck disable=SC2034
# =============================================================================
# Tests for 340-configure-vnstat.sh
# =============================================================================

%const SCRIPTS_DIR: "${SHELLSPEC_PROJECT_ROOT}/scripts"
%const SUPPORT_DIR: "${SHELLSPEC_PROJECT_ROOT}/spec/support"

# Load shared mocks
eval "$(cat "$SUPPORT_DIR/configure_mocks.sh")"

# Additional mocks
apply_template_vars() { return 0; }

Describe "340-configure-vnstat.sh"
Include "$SCRIPTS_DIR/340-configure-vnstat.sh"

# ===========================================================================
# _config_vnstat()
# ===========================================================================
Describe "_config_vnstat()"
It "deploys config and initializes interfaces"
INTERFACE_NAME="eth0"
MOCK_REMOTE_COPY_RESULT=0
MOCK_REMOTE_EXEC_RESULT=0
When call _config_vnstat
The status should be success
End

It "fails when remote_copy fails"
INTERFACE_NAME="eth0"
MOCK_REMOTE_COPY_RESULT=1
When call _config_vnstat
The status should be failure
End
End
End
