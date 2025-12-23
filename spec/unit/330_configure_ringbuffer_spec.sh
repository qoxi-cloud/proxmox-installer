# shellcheck shell=bash
# shellcheck disable=SC2034
# =============================================================================
# Tests for 330-configure-ringbuffer.sh
# =============================================================================

%const SCRIPTS_DIR: "${SHELLSPEC_PROJECT_ROOT}/scripts"
%const SUPPORT_DIR: "${SHELLSPEC_PROJECT_ROOT}/spec/support"

# Load shared mocks
eval "$(cat "$SUPPORT_DIR/configure_mocks.sh")"

# Additional mocks
apply_template_vars() { return 0; }

Describe "330-configure-ringbuffer.sh"
  Include "$SCRIPTS_DIR/330-configure-ringbuffer.sh"

  # ===========================================================================
  # _config_ringbuffer()
  # ===========================================================================
  Describe "_config_ringbuffer()"
    It "deploys systemd service"
      DEFAULT_INTERFACE="eth0"
      MOCK_REMOTE_COPY_RESULT=0
      MOCK_REMOTE_EXEC_RESULT=0
      When call _config_ringbuffer
      The status should be success
    End

    It "fails when remote_copy fails"
      DEFAULT_INTERFACE="eth0"
      MOCK_REMOTE_COPY_RESULT=1
      When call _config_ringbuffer
      The status should be failure
    End
  End
End
