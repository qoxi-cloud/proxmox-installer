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
# _install_prometheus()
# ===========================================================================
Describe "_install_prometheus()"
It "calls run_remote successfully"
MOCK_RUN_REMOTE_RESULT=0
When call _install_prometheus
The status should be success
End
End

# ===========================================================================
# _config_prometheus()
# ===========================================================================
Describe "_config_prometheus()"
It "configures successfully"
MOCK_REMOTE_EXEC_RESULT=0
MOCK_REMOTE_COPY_RESULT=0
When call _config_prometheus
The status should be success
End
End

# ===========================================================================
# configure_prometheus()
# ===========================================================================
Describe "configure_prometheus()"
It "skips when INSTALL_PROMETHEUS is not yes"
INSTALL_PROMETHEUS="no"
PROMETHEUS_INSTALLED=""
When call configure_prometheus
The status should be success
The variable PROMETHEUS_INSTALLED should equal ""
End

It "installs when INSTALL_PROMETHEUS is yes"
INSTALL_PROMETHEUS="yes"
PROMETHEUS_INSTALLED=""
INSTALL_TAILSCALE="no"
MAIN_IPV4="1.2.3.4"
MOCK_RUN_REMOTE_RESULT=0
MOCK_REMOTE_EXEC_RESULT=0
MOCK_REMOTE_COPY_RESULT=0
When call configure_prometheus
The status should be success
The variable PROMETHEUS_INSTALLED should equal "yes"
End
End
End
