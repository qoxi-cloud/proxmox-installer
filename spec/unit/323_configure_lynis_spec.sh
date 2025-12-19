# shellcheck shell=bash
# shellcheck disable=SC2034
# =============================================================================
# Tests for 323-configure-lynis.sh
# =============================================================================

%const SCRIPTS_DIR: "${SHELLSPEC_PROJECT_ROOT}/scripts"
%const SUPPORT_DIR: "${SHELLSPEC_PROJECT_ROOT}/spec/support"

# Load shared mocks
eval "$(cat "$SUPPORT_DIR/configure_mocks.sh")"

Describe "323-configure-lynis.sh"
Include "$SCRIPTS_DIR/323-configure-lynis.sh"

# ===========================================================================
# _config_lynis()
# ===========================================================================
Describe "_config_lynis()"
It "deploys timer for weekly scans"
MOCK_REMOTE_COPY_RESULT=0
MOCK_REMOTE_EXEC_RESULT=0
When call _config_lynis
The status should be success
End

It "fails when remote_copy fails"
MOCK_REMOTE_COPY_RESULT=1
When call _config_lynis
The status should be failure
End
End
End
