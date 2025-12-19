# shellcheck shell=bash
# shellcheck disable=SC2034
# =============================================================================
# Tests for 330-configure-ringbuffer.sh
# =============================================================================

%const SCRIPTS_DIR: "${SHELLSPEC_PROJECT_ROOT}/scripts"
%const SUPPORT_DIR: "${SHELLSPEC_PROJECT_ROOT}/spec/support"

# Load shared mocks
eval "$(cat "$SUPPORT_DIR/configure_mocks.sh")"

Describe "330-configure-ringbuffer.sh"
Include "$SCRIPTS_DIR/330-configure-ringbuffer.sh"

# ===========================================================================
# _install_ringbuffer()
# ===========================================================================
Describe "_install_ringbuffer()"
It "calls run_remote successfully"
MOCK_RUN_REMOTE_RESULT=0
When call _install_ringbuffer
The status should be success
End
End

# ===========================================================================
# _config_ringbuffer()
# ===========================================================================
Describe "_config_ringbuffer()"
It "configures successfully"
MOCK_APPLY_TEMPLATE_VARS_RESULT=0
MOCK_REMOTE_COPY_RESULT=0
MOCK_REMOTE_EXEC_RESULT=0
DEFAULT_INTERFACE="eth0"
When call _config_ringbuffer
The status should be success
End
End

# ===========================================================================
# configure_ringbuffer()
# ===========================================================================
Describe "configure_ringbuffer()"
It "skips when INSTALL_RINGBUFFER is not yes"
INSTALL_RINGBUFFER="no"
RINGBUFFER_INSTALLED=""
When call configure_ringbuffer
The status should be success
The variable RINGBUFFER_INSTALLED should equal ""
End

It "installs when INSTALL_RINGBUFFER is yes"
INSTALL_RINGBUFFER="yes"
RINGBUFFER_INSTALLED=""
DEFAULT_INTERFACE="eth0"
MOCK_RUN_REMOTE_RESULT=0
MOCK_APPLY_TEMPLATE_VARS_RESULT=0
MOCK_REMOTE_COPY_RESULT=0
MOCK_REMOTE_EXEC_RESULT=0
When call configure_ringbuffer
The status should be success
The variable RINGBUFFER_INSTALLED should equal "yes"
End
End
End
