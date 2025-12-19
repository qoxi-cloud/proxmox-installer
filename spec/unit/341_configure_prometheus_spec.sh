# shellcheck shell=bash
# shellcheck disable=SC2034
# =============================================================================
# Tests for 341-configure-prometheus.sh
# =============================================================================

%const SCRIPTS_DIR: "${SHELLSPEC_PROJECT_ROOT}/scripts"
%const SUPPORT_DIR: "${SHELLSPEC_PROJECT_ROOT}/spec/support"

# Load shared mocks
eval "$(cat "$SUPPORT_DIR/configure_mocks.sh")"

Describe "341-configure-prometheus.sh"
Include "$SCRIPTS_DIR/341-configure-prometheus.sh"

# ===========================================================================
# _config_prometheus()
# ===========================================================================
Describe "_config_prometheus()"
It "deploys config and metrics collector"
MOCK_REMOTE_COPY_RESULT=0
MOCK_REMOTE_EXEC_RESULT=0
When call _config_prometheus
The status should be success
End

It "fails when remote_exec fails"
MOCK_REMOTE_COPY_RESULT=0
MOCK_REMOTE_EXEC_RESULT=1
When call _config_prometheus
The status should be failure
End
End
End
