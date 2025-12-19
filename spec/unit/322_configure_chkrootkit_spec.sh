# shellcheck shell=bash
# shellcheck disable=SC2034
# =============================================================================
# Tests for 322-configure-chkrootkit.sh
# =============================================================================

%const SCRIPTS_DIR: "${SHELLSPEC_PROJECT_ROOT}/scripts"
%const SUPPORT_DIR: "${SHELLSPEC_PROJECT_ROOT}/spec/support"

# Load shared mocks
eval "$(cat "$SUPPORT_DIR/configure_mocks.sh")"

Describe "322-configure-chkrootkit.sh"
Include "$SCRIPTS_DIR/322-configure-chkrootkit.sh"

# ===========================================================================
# _config_chkrootkit()
# ===========================================================================
Describe "_config_chkrootkit()"
It "deploys timer for weekly scans"
MOCK_REMOTE_COPY_RESULT=0
MOCK_REMOTE_EXEC_RESULT=0
When call _config_chkrootkit
The status should be success
End

It "fails when remote_copy fails"
MOCK_REMOTE_COPY_RESULT=1
When call _config_chkrootkit
The status should be failure
End
End
End
