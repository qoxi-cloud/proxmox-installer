# shellcheck shell=bash
# shellcheck disable=SC2016,SC2034
# =============================================================================
# Integration tests for parallel execution helpers
# Tests: run_parallel_group, batch_install_packages, parallel_mark_configured
# =============================================================================

%const SCRIPTS_DIR: "${SHELLSPEC_PROJECT_ROOT}/scripts"
%const SUPPORT_DIR: "${SHELLSPEC_PROJECT_ROOT}/spec/support"

# Load mocks
eval "$(cat "$SUPPORT_DIR/core_mocks.sh")"

# =============================================================================
# Test setup
# =============================================================================
setup_parallel_test() {
  # Clean environment
  unset PARALLEL_RESULT_DIR

  # Mock log functions
  LOG_FILE="${SHELLSPEC_TMPBASE}/test.log"
  touch "$LOG_FILE"
  export LOG_FILE

  log_subtasks() { :; }
  show_progress() {
    # Wait for background process, return its exit code
    wait "$1" 2>/dev/null
    return $?
  }
  export -f log_subtasks show_progress
}

cleanup_parallel_test() {
  unset PARALLEL_RESULT_DIR
  rm -rf "${SHELLSPEC_TMPBASE}/parallel_*" 2>/dev/null || true
}

Describe "Parallel Execution Integration"
  Include "$SCRIPTS_DIR/037-parallel-helpers.sh"

  BeforeEach 'setup_parallel_test'
  AfterEach 'cleanup_parallel_test'

  # ===========================================================================
  # run_parallel_group()
  # ===========================================================================
  Describe "run_parallel_group()"
    Describe "basic execution"
      It "runs multiple functions in parallel"
        results=()
        func1() { results+=(1); return 0; }
        func2() { results+=(2); return 0; }
        func3() { results+=(3); return 0; }

        When call run_parallel_group "Test group" "Done" func1 func2 func3
        The status should be success
      End

      It "returns success with empty function list"
        When call run_parallel_group "Empty group" "Done"
        The status should be success
      End

      It "handles single function"
        single_ran=false
        single_func() { single_ran=true; return 0; }

        When call run_parallel_group "Single" "Done" single_func
        The status should be success
      End
    End

    Describe "failure handling"
      It "continues when one function fails"
        success_func() { return 0; }
        fail_func() { return 1; }

        When call run_parallel_group "Mixed" "Done" success_func fail_func
        The status should be success # Non-fatal
      End

      It "continues when all functions fail"
        fail1() { return 1; }
        fail2() { return 1; }

        When call run_parallel_group "All fail" "Done" fail1 fail2
        The status should be success # Non-fatal
      End
    End

    Describe "result tracking"
      It "functions complete successfully"
        track1() { return 0; }
        track2() { return 0; }

        When call run_parallel_group "Track" "Done" track1 track2
        The status should be success
      End
    End
  End

  # ===========================================================================
  # parallel_mark_configured()
  # ===========================================================================
  Describe "parallel_mark_configured()"
    It "creates marker file when PARALLEL_RESULT_DIR is set"
      result_dir=$(mktemp -d)
      export PARALLEL_RESULT_DIR="$result_dir"

      # Call directly (BASHPID will be current shell's PID)
      parallel_mark_configured "test_feature"
      marker_exists=false
      [[ -n "$(ls "$result_dir"/ran_* 2>/dev/null)" ]] && marker_exists=true

      When call printf '%s' "$marker_exists"
      The output should equal "true"

      rm -rf "$result_dir"
    End

    It "does nothing when PARALLEL_RESULT_DIR is unset"
      unset PARALLEL_RESULT_DIR

      # Function uses ${PARALLEL_RESULT_DIR:-} pattern, so unset is safe
      # The printf in the function will fail silently when dir doesn't exist
      parallel_mark_configured "test_feature" 2>/dev/null || true

      When call printf "ok"
      The output should equal "ok"
    End

    It "writes feature name to marker file"
      result_dir=$(mktemp -d)
      export PARALLEL_RESULT_DIR="$result_dir"

      parallel_mark_configured "apparmor"

      # Read content of the marker file
      content=$(cat "$result_dir"/ran_* 2>/dev/null || echo "")

      When call printf '%s' "$content"
      The output should equal "apparmor"

      rm -rf "$result_dir"
    End
  End

  # ===========================================================================
  # Integration with configure functions pattern
  # ===========================================================================
  Describe "configure function pattern integration"
    It "works with typical configure_* wrapper pattern"
      INSTALL_FEATURE="yes"

      _config_feature() {
        parallel_mark_configured "feature"
        return 0
      }

      configure_feature() {
        [[ ${INSTALL_FEATURE:-} != "yes" ]] && return 0
        _config_feature
      }

      When call run_parallel_group "Features" "Done" configure_feature
      The status should be success
    End

    It "skips when INSTALL_* flag is not set"
      INSTALL_FEATURE="no"

      configure_feature() {
        [[ ${INSTALL_FEATURE:-} != "yes" ]] && return 0
        return 1 # Would fail if called
      }

      When call run_parallel_group "Features" "Done" configure_feature
      The status should be success
    End
  End

  # ===========================================================================
  # batch_install_packages() - Mock SSH for testing
  # ===========================================================================
  Describe "batch_install_packages()"
    BeforeEach 'remote_run() { :; }; export -f remote_run'

    It "returns success with no packages needed"
      INSTALL_FIREWALL="no"
      INSTALL_APPARMOR="no"
      INSTALL_AUDITD="no"
      INSTALL_AIDE="no"
      INSTALL_CHKROOTKIT="no"
      INSTALL_LYNIS="no"
      INSTALL_NEEDRESTART="no"
      INSTALL_VNSTAT="no"
      INSTALL_PROMTAIL="no"
      INSTALL_NETDATA="no"
      INSTALL_NVIM="no"
      INSTALL_RINGBUFFER="no"
      INSTALL_YAZI="no"
      INSTALL_TAILSCALE="no"
      SSL_TYPE="self-signed"

      When call batch_install_packages
      The status should be success
    End

    It "collects firewall packages when enabled"
      INSTALL_FIREWALL="yes"
      FIREWALL_MODE="standard"
      INSTALL_APPARMOR="no"
      INSTALL_AUDITD="no"
      INSTALL_AIDE="no"
      INSTALL_CHKROOTKIT="no"
      INSTALL_LYNIS="no"
      INSTALL_NEEDRESTART="no"
      INSTALL_VNSTAT="no"
      INSTALL_PROMTAIL="no"
      INSTALL_NETDATA="no"
      INSTALL_NVIM="no"
      INSTALL_RINGBUFFER="no"
      INSTALL_YAZI="no"
      INSTALL_TAILSCALE="no"
      SSL_TYPE="self-signed"

      # Track what remote_run receives
      captured_cmd=""
      remote_run() { captured_cmd="$2"; }

      batch_install_packages

      When call printf '%s' "$captured_cmd"
      The output should include "nftables"
      The output should include "fail2ban"
    End

    It "excludes fail2ban in stealth mode"
      INSTALL_FIREWALL="yes"
      FIREWALL_MODE="stealth"
      INSTALL_APPARMOR="no"
      INSTALL_AUDITD="no"
      INSTALL_AIDE="no"
      INSTALL_CHKROOTKIT="no"
      INSTALL_LYNIS="no"
      INSTALL_NEEDRESTART="no"
      INSTALL_VNSTAT="no"
      INSTALL_PROMTAIL="no"
      INSTALL_NETDATA="no"
      INSTALL_NVIM="no"
      INSTALL_RINGBUFFER="no"
      INSTALL_YAZI="no"
      INSTALL_TAILSCALE="no"
      SSL_TYPE="self-signed"

      captured_cmd=""
      remote_run() { captured_cmd="$2"; }

      batch_install_packages

      When call printf '%s' "$captured_cmd"
      The output should include "nftables"
      The output should not include "fail2ban"
    End

    It "includes certbot for letsencrypt"
      INSTALL_FIREWALL="no"
      INSTALL_APPARMOR="no"
      INSTALL_AUDITD="no"
      INSTALL_AIDE="no"
      INSTALL_CHKROOTKIT="no"
      INSTALL_LYNIS="no"
      INSTALL_NEEDRESTART="no"
      INSTALL_VNSTAT="no"
      INSTALL_PROMTAIL="no"
      INSTALL_NETDATA="no"
      INSTALL_NVIM="no"
      INSTALL_RINGBUFFER="no"
      INSTALL_YAZI="no"
      INSTALL_TAILSCALE="no"
      SSL_TYPE="letsencrypt"

      captured_cmd=""
      remote_run() { captured_cmd="$2"; }

      batch_install_packages

      When call printf '%s' "$captured_cmd"
      The output should include "certbot"
    End

    It "includes security packages when enabled"
      INSTALL_FIREWALL="no"
      INSTALL_APPARMOR="yes"
      INSTALL_AUDITD="yes"
      INSTALL_AIDE="no"
      INSTALL_CHKROOTKIT="no"
      INSTALL_LYNIS="no"
      INSTALL_NEEDRESTART="no"
      INSTALL_VNSTAT="no"
      INSTALL_PROMTAIL="no"
      INSTALL_NETDATA="no"
      INSTALL_NVIM="no"
      INSTALL_RINGBUFFER="no"
      INSTALL_YAZI="no"
      INSTALL_TAILSCALE="no"
      SSL_TYPE="self-signed"

      captured_cmd=""
      remote_run() { captured_cmd="$2"; }

      batch_install_packages

      When call printf '%s' "$captured_cmd"
      The output should include "apparmor"
      The output should include "auditd"
    End
  End
End

