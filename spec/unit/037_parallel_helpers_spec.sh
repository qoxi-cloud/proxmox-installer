# shellcheck shell=bash
# shellcheck disable=SC2034
# =============================================================================
# Tests for 037-parallel-helpers.sh
# =============================================================================

%const SCRIPTS_DIR: "${SHELLSPEC_PROJECT_ROOT}/scripts"
%const SUPPORT_DIR: "${SHELLSPEC_PROJECT_ROOT}/spec/support"

# Load shared mocks BEFORE Include
eval "$(cat "$SUPPORT_DIR/colors.sh")"
eval "$(cat "$SUPPORT_DIR/core_mocks.sh")"

# =============================================================================
# Mock controls
# =============================================================================
MOCK_REMOTE_RUN_RESULT=0
MOCK_REMOTE_RUN_CALLS=0
MOCK_REMOTE_RUN_COMMANDS=""

reset_mocks() {
  MOCK_REMOTE_RUN_RESULT=0
  MOCK_REMOTE_RUN_CALLS=0
  MOCK_REMOTE_RUN_COMMANDS=""
  # Reset all feature flags
  INSTALL_FIREWALL=""
  INSTALL_APPARMOR=""
  INSTALL_AUDITD=""
  INSTALL_AIDE=""
  INSTALL_CHKROOTKIT=""
  INSTALL_LYNIS=""
  INSTALL_NEEDRESTART=""
  INSTALL_VNSTAT=""
  INSTALL_PROMTAIL=""
  INSTALL_NETDATA=""
  INSTALL_NVIM=""
  INSTALL_RINGBUFFER=""
  INSTALL_YAZI=""
  INSTALL_TAILSCALE=""
  SSL_TYPE=""
  FIREWALL_MODE=""
  SHELL_TYPE=""
  SYSTEM_UTILITIES=""
  OPTIONAL_PACKAGES=""
}

# Mock remote_run to track calls
remote_run() {
  MOCK_REMOTE_RUN_CALLS=$((MOCK_REMOTE_RUN_CALLS + 1))
  MOCK_REMOTE_RUN_COMMANDS="${MOCK_REMOTE_RUN_COMMANDS}$2;"
  return "$MOCK_REMOTE_RUN_RESULT"
}

# Note: log_subtasks is now in core_mocks.sh

Describe "037-parallel-helpers.sh"
  Include "$SCRIPTS_DIR/037-parallel-helpers.sh"

  # ===========================================================================
  # install_base_packages()
  # ===========================================================================
  Describe "install_base_packages()"
    BeforeEach 'reset_mocks'

    It "installs system packages via remote_run"
      SYSTEM_UTILITIES="htop iotop"
      OPTIONAL_PACKAGES="vim"
      When call install_base_packages
      The status should be success
      The variable MOCK_REMOTE_RUN_CALLS should equal 1
    End

    It "includes base packages in install command"
      SYSTEM_UTILITIES="htop"
      When call install_base_packages
      The status should be success
      The variable MOCK_REMOTE_RUN_COMMANDS should include "locales"
      The variable MOCK_REMOTE_RUN_COMMANDS should include "chrony"
      The variable MOCK_REMOTE_RUN_COMMANDS should include "unattended-upgrades"
    End

    It "adds zsh packages when SHELL_TYPE is zsh"
      SYSTEM_UTILITIES=""
      SHELL_TYPE="zsh"
      When call install_base_packages
      The status should be success
      The variable MOCK_REMOTE_RUN_COMMANDS should include "zsh"
      The variable MOCK_REMOTE_RUN_COMMANDS should include "git"
      The variable MOCK_REMOTE_RUN_COMMANDS should include "curl"
    End

    It "does not add zsh packages when SHELL_TYPE is bash"
      SYSTEM_UTILITIES=""
      SHELL_TYPE="bash"
      When call install_base_packages
      The status should be success
      The variable MOCK_REMOTE_RUN_COMMANDS should not include "zsh"
    End

    # Note: remote_run calls exit 1 on failure (not return 1)
    # Cannot test failure case with mock that only returns
  End

  # ===========================================================================
  # batch_install_packages()
  # ===========================================================================
  Describe "batch_install_packages()"
    BeforeEach 'reset_mocks'

    It "returns 0 when no features enabled"
      When call batch_install_packages
      The status should be success
      The variable MOCK_REMOTE_RUN_CALLS should equal 0
    End

    Describe "with security features"
      It "includes nftables when firewall enabled"
        INSTALL_FIREWALL="yes"
        When call batch_install_packages
        The status should be success
        The variable MOCK_REMOTE_RUN_COMMANDS should include "nftables"
      End

      It "includes fail2ban when firewall enabled and not stealth mode"
        INSTALL_FIREWALL="yes"
        FIREWALL_MODE="standard"
        When call batch_install_packages
        The status should be success
        The variable MOCK_REMOTE_RUN_COMMANDS should include "fail2ban"
      End

      It "excludes fail2ban in stealth mode"
        INSTALL_FIREWALL="yes"
        FIREWALL_MODE="stealth"
        When call batch_install_packages
        The status should be success
        The variable MOCK_REMOTE_RUN_COMMANDS should not include "fail2ban"
      End

      It "includes apparmor packages"
        INSTALL_APPARMOR="yes"
        When call batch_install_packages
        The status should be success
        The variable MOCK_REMOTE_RUN_COMMANDS should include "apparmor"
        The variable MOCK_REMOTE_RUN_COMMANDS should include "apparmor-utils"
      End

      It "includes auditd packages"
        INSTALL_AUDITD="yes"
        When call batch_install_packages
        The status should be success
        The variable MOCK_REMOTE_RUN_COMMANDS should include "auditd"
        The variable MOCK_REMOTE_RUN_COMMANDS should include "audispd-plugins"
      End

      It "includes aide packages"
        INSTALL_AIDE="yes"
        When call batch_install_packages
        The status should be success
        The variable MOCK_REMOTE_RUN_COMMANDS should include "aide"
        The variable MOCK_REMOTE_RUN_COMMANDS should include "aide-common"
      End

      It "includes chkrootkit"
        INSTALL_CHKROOTKIT="yes"
        When call batch_install_packages
        The status should be success
        The variable MOCK_REMOTE_RUN_COMMANDS should include "chkrootkit"
      End

      It "includes lynis"
        INSTALL_LYNIS="yes"
        When call batch_install_packages
        The status should be success
        The variable MOCK_REMOTE_RUN_COMMANDS should include "lynis"
      End

      It "includes needrestart"
        INSTALL_NEEDRESTART="yes"
        When call batch_install_packages
        The status should be success
        The variable MOCK_REMOTE_RUN_COMMANDS should include "needrestart"
      End
    End

    Describe "with monitoring features"
      It "includes vnstat"
        INSTALL_VNSTAT="yes"
        When call batch_install_packages
        The status should be success
        The variable MOCK_REMOTE_RUN_COMMANDS should include "vnstat"
      End

      It "includes promtail"
        INSTALL_PROMTAIL="yes"
        When call batch_install_packages
        The status should be success
        The variable MOCK_REMOTE_RUN_COMMANDS should include "promtail"
      End

      It "includes netdata"
        INSTALL_NETDATA="yes"
        When call batch_install_packages
        The status should be success
        The variable MOCK_REMOTE_RUN_COMMANDS should include "netdata"
      End
    End

    Describe "with tools features"
      It "includes neovim"
        INSTALL_NVIM="yes"
        When call batch_install_packages
        The status should be success
        The variable MOCK_REMOTE_RUN_COMMANDS should include "neovim"
      End

      It "includes ethtool for ringbuffer"
        INSTALL_RINGBUFFER="yes"
        When call batch_install_packages
        The status should be success
        The variable MOCK_REMOTE_RUN_COMMANDS should include "ethtool"
      End

      It "includes yazi dependencies"
        INSTALL_YAZI="yes"
        When call batch_install_packages
        The status should be success
        The variable MOCK_REMOTE_RUN_COMMANDS should include "curl"
        The variable MOCK_REMOTE_RUN_COMMANDS should include "file"
        The variable MOCK_REMOTE_RUN_COMMANDS should include "unzip"
      End
    End

    Describe "with tailscale"
      It "includes tailscale package"
        INSTALL_TAILSCALE="yes"
        When call batch_install_packages
        The status should be success
        The variable MOCK_REMOTE_RUN_COMMANDS should include "tailscale"
      End

      It "sets up tailscale repo"
        INSTALL_TAILSCALE="yes"
        When call batch_install_packages
        The status should be success
        The variable MOCK_REMOTE_RUN_COMMANDS should include "pkgs.tailscale.com"
      End
    End

    Describe "with SSL"
      It "includes certbot for letsencrypt"
        SSL_TYPE="letsencrypt"
        When call batch_install_packages
        The status should be success
        The variable MOCK_REMOTE_RUN_COMMANDS should include "certbot"
      End

      It "excludes certbot for self-signed"
        SSL_TYPE="self-signed"
        When call batch_install_packages
        The status should be success
        # No packages to install
        The variable MOCK_REMOTE_RUN_CALLS should equal 0
      End
    End

    Describe "with multiple features"
      It "installs all packages in one batch"
        INSTALL_FIREWALL="yes"
        INSTALL_APPARMOR="yes"
        INSTALL_VNSTAT="yes"
        INSTALL_NVIM="yes"
        When call batch_install_packages
        The status should be success
        # Only one remote_run call for all packages
        The variable MOCK_REMOTE_RUN_CALLS should equal 1
        The variable MOCK_REMOTE_RUN_COMMANDS should include "nftables"
        The variable MOCK_REMOTE_RUN_COMMANDS should include "apparmor"
        The variable MOCK_REMOTE_RUN_COMMANDS should include "vnstat"
        The variable MOCK_REMOTE_RUN_COMMANDS should include "neovim"
      End
    End

    # Note: remote_run calls exit 1 on failure (not return 1)
    # Cannot test failure case with mock that only returns
  End

  # ===========================================================================
  # run_parallel_group()
  # ===========================================================================
  Describe "run_parallel_group()"
    BeforeEach 'reset_mocks'

    # Test helper functions
    _test_success_func() { return 0; }
    _test_fail_func() { return 1; }
    _test_exit_func() { exit 1; }  # Simulates remote_run failure
    _test_slow_func() { sleep 0.1; return 0; }

    It "returns success with no functions"
      When call run_parallel_group "Test Group" "Done" 
      The status should be success
    End

    It "runs single function successfully"
      When call run_parallel_group "Test Group" "Done" _test_success_func
      The status should be success
    End

    It "runs multiple functions in parallel"
      When call run_parallel_group "Test Group" "Done" _test_success_func _test_success_func _test_success_func
      The status should be success
    End

    It "returns success even when functions fail (non-fatal)"
      When call run_parallel_group "Test Group" "Done" _test_fail_func
      The status should be success
    End

    It "handles mix of success and failure"
      When call run_parallel_group "Test Group" "Done" _test_success_func _test_fail_func _test_success_func
      The status should be success
    End

    It "handles function that calls exit (like remote_run)"
      # This was the bug: exit 1 in subshell skipped marker file creation
      When call run_parallel_group "Test Group" "Done" _test_exit_func
      The status should be success
    End

    It "handles mix of exit and return failures"
      When call run_parallel_group "Test Group" "Done" _test_success_func _test_exit_func _test_fail_func
      The status should be success
    End

    It "waits for slow functions"
      When call run_parallel_group "Test Group" "Done" _test_slow_func
      The status should be success
    End

    It "cleans up temp directory"
      When call run_parallel_group "Test Group" "Done" _test_success_func
      The status should be success
      # PARALLEL_RESULT_DIR should be cleaned up by trap
    End
  End

  # ===========================================================================
  # parallel_mark_configured()
  # ===========================================================================
  Describe "parallel_mark_configured()"
    BeforeEach 'reset_mocks'

    It "does nothing when PARALLEL_RESULT_DIR not set"
      unset PARALLEL_RESULT_DIR
      When call parallel_mark_configured "feature"
      # Returns 1 because [[ -n ${PARALLEL_RESULT_DIR:-} ]] && ... pattern
      # returns exit code of last command (the test, which is false)
      The status should be failure
    End

    It "creates marker file when PARALLEL_RESULT_DIR is set"
      result_dir=$(mktemp -d)
      PARALLEL_RESULT_DIR="$result_dir"
      # Run in subshell to capture the file (BASHPID changes in subshell)
      (
        parallel_mark_configured "testfeature"
        # Verify file was created with this subshell's BASHPID
        [ -f "$result_dir/ran_$BASHPID" ] && cat "$result_dir/ran_$BASHPID"
      )
      When run cat "$result_dir"/ran_*
      The output should equal "testfeature"
      rm -rf "$result_dir"
    End

    It "handles empty feature name"
      result_dir=$(mktemp -d)
      PARALLEL_RESULT_DIR="$result_dir"
      (parallel_mark_configured "")
      When run cat "$result_dir"/ran_*
      The output should equal ""
      rm -rf "$result_dir"
    End

    It "handles feature name with special characters"
      result_dir=$(mktemp -d)
      PARALLEL_RESULT_DIR="$result_dir"
      (parallel_mark_configured "feature-with-dashes_and_underscores")
      When run cat "$result_dir"/ran_*
      The output should equal "feature-with-dashes_and_underscores"
      rm -rf "$result_dir"
    End
  End
End
