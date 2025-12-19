# shellcheck shell=bash
# shellcheck disable=SC2034
# =============================================================================
# Tests for 321-configure-aide.sh
# =============================================================================

%const SCRIPTS_DIR: "${SHELLSPEC_PROJECT_ROOT}/scripts"
%const SUPPORT_DIR: "${SHELLSPEC_PROJECT_ROOT}/spec/support"

# Load shared mocks
eval "$(cat "$SUPPORT_DIR/configure_mocks.sh")"

Describe "321-configure-aide.sh"
Include "$SCRIPTS_DIR/321-configure-aide.sh"

# ===========================================================================
# _config_aide()
# ===========================================================================
Describe "_config_aide()"
It "deploys timer and initializes database"
MOCK_REMOTE_COPY_RESULT=0
MOCK_REMOTE_EXEC_RESULT=0
When call _config_aide
The status should be success
End

It "fails when remote_copy fails"
MOCK_REMOTE_COPY_RESULT=1
When call _config_aide
The status should be failure
End
End
End
