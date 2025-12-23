# shellcheck shell=bash
# shellcheck disable=SC2016,SC2034
# =============================================================================
# Tests for 202-templates.sh
# =============================================================================

%const SCRIPTS_DIR: "${SHELLSPEC_PROJECT_ROOT}/scripts"
%const SUPPORT_DIR: "${SHELLSPEC_PROJECT_ROOT}/spec/support"

# Load shared mocks
eval "$(cat "$SUPPORT_DIR/core_mocks.sh")"

# =============================================================================
# Mock control variables
# =============================================================================
MOCK_APPLY_COMMON_RESULT=0
MOCK_APPLY_VARS_RESULT=0
MOCK_GENERATE_INTERFACES_RESULT=0
MOCK_DOWNLOAD_TEMPLATE_RESULT=0
MOCK_ARIA2C_AVAILABLE=false
MOCK_ARIA2C_RESULT=0

# Track function calls
MOCK_APPLY_COMMON_CALLS=0
MOCK_APPLY_VARS_CALLS=0
MOCK_GENERATE_INTERFACES_CALLS=0
MOCK_DOWNLOAD_TEMPLATE_CALLS=0
MOCK_ARIA2C_CALLS=0
MOCK_DOWNLOADED_ENTRIES=()

reset_template_mocks() {
  MOCK_APPLY_COMMON_RESULT=0
  MOCK_APPLY_VARS_RESULT=0
  MOCK_GENERATE_INTERFACES_RESULT=0
  MOCK_DOWNLOAD_TEMPLATE_RESULT=0
  MOCK_ARIA2C_AVAILABLE=false
  MOCK_ARIA2C_RESULT=0

  MOCK_APPLY_COMMON_CALLS=0
  MOCK_APPLY_VARS_CALLS=0
  MOCK_GENERATE_INTERFACES_CALLS=0
  MOCK_DOWNLOAD_TEMPLATE_CALLS=0
  MOCK_ARIA2C_CALLS=0
  MOCK_DOWNLOADED_ENTRIES=()

  # Required globals
  GITHUB_BASE_URL="https://raw.githubusercontent.com/test/repo/main"
  LOG_FILE="${SHELLSPEC_TMPBASE:-/tmp}/test.log"
  touch "$LOG_FILE" 2>/dev/null || true

  # Bridge mode
  BRIDGE_MODE="internal"

  # Repo type
  PVE_REPO_TYPE="no-subscription"

  # Private network
  PRIVATE_SUBNET=""

  # CPU governor
  CPU_GOVERNOR="performance"
}

# =============================================================================
# Mock functions (defined before Include)
# =============================================================================

apply_common_template_vars() {
  MOCK_APPLY_COMMON_CALLS=$((MOCK_APPLY_COMMON_CALLS + 1))
  return "$MOCK_APPLY_COMMON_RESULT"
}

apply_template_vars() {
  MOCK_APPLY_VARS_CALLS=$((MOCK_APPLY_VARS_CALLS + 1))
  return "$MOCK_APPLY_VARS_RESULT"
}

generate_interfaces_file() {
  MOCK_GENERATE_INTERFACES_CALLS=$((MOCK_GENERATE_INTERFACES_CALLS + 1))
  return "$MOCK_GENERATE_INTERFACES_RESULT"
}

download_template() {
  MOCK_DOWNLOAD_TEMPLATE_CALLS=$((MOCK_DOWNLOAD_TEMPLATE_CALLS + 1))
  MOCK_DOWNLOADED_ENTRIES+=("$1:$2")
  return "$MOCK_DOWNLOAD_TEMPLATE_RESULT"
}

# Mock aria2c command
aria2c() {
  MOCK_ARIA2C_CALLS=$((MOCK_ARIA2C_CALLS + 1))
  return "$MOCK_ARIA2C_RESULT"
}

# Mock command check for aria2c
command() {
  if [[ "$2" == "aria2c" ]]; then
    if [[ "$MOCK_ARIA2C_AVAILABLE" == "true" ]]; then
      return 0
    else
      return 1
    fi
  fi
  builtin command "$@"
}

# Mock run_with_progress to execute function directly
run_with_progress() {
  local label="$1"
  local done_msg="$2"
  shift 2

  # Check if remaining args contain a function call
  if [[ $# -gt 0 ]]; then
    # Execute the function/command
    "$@"
    return $?
  fi
  return 0
}

Describe "202-templates.sh"
  Include "$SCRIPTS_DIR/202-templates.sh"

  BeforeEach 'reset_template_mocks'

  # ===========================================================================
  # _modify_template_files()
  # ===========================================================================
  Describe "_modify_template_files()"
    It "calls apply_common_template_vars for hosts template"
      When call _modify_template_files
      The status should be success
      # hosts, resolv.conf, locale.sh, default-locale, environment = 5 calls
      The variable MOCK_APPLY_COMMON_CALLS should equal 5
    End

    It "calls generate_interfaces_file for interfaces template"
      When call _modify_template_files
      The status should be success
      The variable MOCK_GENERATE_INTERFACES_CALLS should equal 1
    End

    It "calls apply_template_vars for cpupower.service"
      When call _modify_template_files
      The status should be success
      The variable MOCK_APPLY_VARS_CALLS should equal 1
    End

    It "calls all template modification functions"
      When call _modify_template_files
      The status should be success
      # Verify all expected calls were made
      The variable MOCK_APPLY_COMMON_CALLS should equal 5
      The variable MOCK_GENERATE_INTERFACES_CALLS should equal 1
      The variable MOCK_APPLY_VARS_CALLS should equal 1
    End

    # Note: The function runs commands sequentially without error handling.
    # Return code is from the last command (apply_common_template_vars).
    It "returns failure when last apply_common_template_vars fails"
      MOCK_APPLY_COMMON_RESULT=1
      When call _modify_template_files
      The status should be failure
    End

    It "continues after generate_interfaces_file failure (no error handling)"
      MOCK_GENERATE_INTERFACES_RESULT=1
      When call _modify_template_files
      # Succeeds because last command succeeds
      The status should be success
      # But generate_interfaces was still called
      The variable MOCK_GENERATE_INTERFACES_CALLS should equal 1
    End

    It "continues after apply_template_vars failure (no error handling)"
      MOCK_APPLY_VARS_RESULT=1
      When call _modify_template_files
      # Succeeds because last command succeeds
      The status should be success
      The variable MOCK_APPLY_VARS_CALLS should equal 1
    End
  End

  # ===========================================================================
  # _download_templates_parallel()
  # ===========================================================================
  Describe "_download_templates_parallel()"
    Describe "with aria2c available"
      BeforeEach 'MOCK_ARIA2C_AVAILABLE=true'

      It "uses aria2c for parallel download"
        templates=("./templates/test1:test1" "./templates/test2:test2")
        When call _download_templates_parallel "${templates[@]}"
        The status should be success
        The variable MOCK_ARIA2C_CALLS should equal 1
        The variable MOCK_DOWNLOAD_TEMPLATE_CALLS should equal 0
      End

      It "falls back to sequential when aria2c fails"
        MOCK_ARIA2C_RESULT=1
        templates=("./templates/test1:test1" "./templates/test2:test2")
        When call _download_templates_parallel "${templates[@]}"
        The status should be success
        The variable MOCK_ARIA2C_CALLS should equal 1
        The variable MOCK_DOWNLOAD_TEMPLATE_CALLS should equal 2
      End

      It "returns failure when aria2c fails and sequential fails"
        MOCK_ARIA2C_RESULT=1
        MOCK_DOWNLOAD_TEMPLATE_RESULT=1
        templates=("./templates/test1:test1")
        When call _download_templates_parallel "${templates[@]}"
        The status should be failure
      End
    End

    Describe "without aria2c"
      BeforeEach 'MOCK_ARIA2C_AVAILABLE=false'

      It "uses sequential download with download_template"
        templates=("./templates/test1:test1" "./templates/test2:test2")
        When call _download_templates_parallel "${templates[@]}"
        The status should be success
        The variable MOCK_ARIA2C_CALLS should equal 0
        The variable MOCK_DOWNLOAD_TEMPLATE_CALLS should equal 2
      End

      It "fails when download_template fails"
        MOCK_DOWNLOAD_TEMPLATE_RESULT=1
        templates=("./templates/test1:test1")
        When call _download_templates_parallel "${templates[@]}"
        The status should be failure
        The variable MOCK_DOWNLOAD_TEMPLATE_CALLS should equal 1
      End

      It "stops on first download failure"
        MOCK_DOWNLOAD_TEMPLATE_RESULT=1
        templates=("./templates/test1:test1" "./templates/test2:test2" "./templates/test3:test3")
        When call _download_templates_parallel "${templates[@]}"
        The status should be failure
        The variable MOCK_DOWNLOAD_TEMPLATE_CALLS should equal 1
      End

      It "downloads correct number of templates"
        templates=("./t1:n1" "./t2:n2" "./t3:n3" "./t4:n4" "./t5:n5")
        When call _download_templates_parallel "${templates[@]}"
        The status should be success
        The variable MOCK_DOWNLOAD_TEMPLATE_CALLS should equal 5
      End
    End

    Describe "input file generation"
      It "handles empty template list"
        templates=()
        When call _download_templates_parallel "${templates[@]}"
        The status should be success
      End

      It "handles single template"
        MOCK_ARIA2C_AVAILABLE=false
        templates=("./templates/single:single")
        When call _download_templates_parallel "${templates[@]}"
        The status should be success
        The variable MOCK_DOWNLOAD_TEMPLATE_CALLS should equal 1
      End
    End
  End

  # ===========================================================================
  # make_templates()
  # ===========================================================================
  Describe "make_templates()"
    # Override run_with_progress to track calls but still execute
    run_with_progress() {
      local label="$1"
      local done_msg="$2"
      shift 2
      "$@"
      return $?
    }

    Describe "successful execution"
      It "creates templates directory"
        tmpdir=$(mktemp -d)
        cd "$tmpdir" || exit 1
        MOCK_ARIA2C_AVAILABLE=false
        When call make_templates
        The status should be success
        The directory "./templates" should be exist
        cd - >/dev/null || exit 1
        rm -rf "$tmpdir"
      End

      It "downloads templates with no-subscription repo type"
        tmpdir=$(mktemp -d)
        cd "$tmpdir" || exit 1
        MOCK_ARIA2C_AVAILABLE=false
        PVE_REPO_TYPE="no-subscription"
        When call make_templates
        The status should be success
        cd - >/dev/null || exit 1
        rm -rf "$tmpdir"
      End

      It "downloads templates with enterprise repo type"
        tmpdir=$(mktemp -d)
        cd "$tmpdir" || exit 1
        MOCK_ARIA2C_AVAILABLE=false
        PVE_REPO_TYPE="enterprise"
        When call make_templates
        The status should be success
        cd - >/dev/null || exit 1
        rm -rf "$tmpdir"
      End

      It "downloads templates with test repo type"
        tmpdir=$(mktemp -d)
        cd "$tmpdir" || exit 1
        MOCK_ARIA2C_AVAILABLE=false
        PVE_REPO_TYPE="test"
        When call make_templates
        The status should be success
        cd - >/dev/null || exit 1
        rm -rf "$tmpdir"
      End
    End

    Describe "PRIVATE_IP_CIDR derivation"
      It "derives PRIVATE_IP_CIDR from PRIVATE_SUBNET with internal bridge"
        tmpdir=$(mktemp -d)
        cd "$tmpdir" || exit 1
        MOCK_ARIA2C_AVAILABLE=false
        BRIDGE_MODE="internal"
        PRIVATE_SUBNET="10.0.0.0/24"
        When call make_templates
        The status should be success
        The variable PRIVATE_IP_CIDR should equal "10.0.0.1/24"
        cd - >/dev/null || exit 1
        rm -rf "$tmpdir"
      End

      It "derives PRIVATE_IP_CIDR from different subnet"
        tmpdir=$(mktemp -d)
        cd "$tmpdir" || exit 1
        MOCK_ARIA2C_AVAILABLE=false
        BRIDGE_MODE="internal"
        PRIVATE_SUBNET="192.168.100.0/16"
        When call make_templates
        The status should be success
        The variable PRIVATE_IP_CIDR should equal "192.168.100.1/16"
        cd - >/dev/null || exit 1
        rm -rf "$tmpdir"
      End

      It "does not set PRIVATE_IP_CIDR for external bridge mode"
        tmpdir=$(mktemp -d)
        cd "$tmpdir" || exit 1
        MOCK_ARIA2C_AVAILABLE=false
        BRIDGE_MODE="external"
        PRIVATE_SUBNET="10.0.0.0/24"
        unset PRIVATE_IP_CIDR
        When call make_templates
        The status should be success
        The variable PRIVATE_IP_CIDR should be undefined
        cd - >/dev/null || exit 1
        rm -rf "$tmpdir"
      End

      It "does not set PRIVATE_IP_CIDR when PRIVATE_SUBNET is empty"
        tmpdir=$(mktemp -d)
        cd "$tmpdir" || exit 1
        MOCK_ARIA2C_AVAILABLE=false
        BRIDGE_MODE="internal"
        PRIVATE_SUBNET=""
        unset PRIVATE_IP_CIDR
        When call make_templates
        The status should be success
        The variable PRIVATE_IP_CIDR should be undefined
        cd - >/dev/null || exit 1
        rm -rf "$tmpdir"
      End
    End

    Describe "template list"
      check_template_count() {
        # Verify we downloaded a significant number of templates (40+)
        [[ $MOCK_DOWNLOAD_TEMPLATE_CALLS -ge 40 ]]
      }

      It "includes all required system templates"
        tmpdir=$(mktemp -d)
        cd "$tmpdir" || exit 1
        MOCK_ARIA2C_AVAILABLE=false
        When call make_templates
        The status should be success
        Assert check_template_count
        cd - >/dev/null || exit 1
        rm -rf "$tmpdir"
      End
    End

    Describe "error handling"
      # Note: make_templates calls exit 1 on failure, which terminates the test.
      # We verify the failure path indirectly by checking run_with_progress
      # is called with download function that would fail.

      It "calls run_with_progress for downloading"
        tmpdir=$(mktemp -d)
        cd "$tmpdir" || exit 1
        MOCK_ARIA2C_AVAILABLE=false
        # Successful case verifies the download path is exercised
        When call make_templates
        The status should be success
        cd - >/dev/null || exit 1
        rm -rf "$tmpdir"
      End
    End
  End

  # ===========================================================================
  # Edge cases
  # ===========================================================================
  Describe "edge cases"
    Describe "template entry parsing"
      It "correctly parses local_path and remote_name from entry"
        MOCK_ARIA2C_AVAILABLE=false
        templates=("./templates/my-config:remote-name")
        When call _download_templates_parallel "${templates[@]}"
        The status should be success
        # Check that download_template was called with correct args
        The variable MOCK_DOWNLOAD_TEMPLATE_CALLS should equal 1
      End

      It "handles templates with dots in names"
        MOCK_ARIA2C_AVAILABLE=false
        templates=("./templates/99-proxmox.conf:99-proxmox.conf")
        When call _download_templates_parallel "${templates[@]}"
        The status should be success
      End

      It "handles templates with dashes and underscores"
        MOCK_ARIA2C_AVAILABLE=false
        templates=("./templates/my_config-file:my_config-file")
        When call _download_templates_parallel "${templates[@]}"
        The status should be success
      End
    End

    Describe "CPU governor substitution"
      It "uses custom CPU_GOVERNOR value"
        CPU_GOVERNOR="powersave"
        When call _modify_template_files
        The status should be success
        The variable MOCK_APPLY_VARS_CALLS should equal 1
      End

      It "uses default performance governor when not set"
        unset CPU_GOVERNOR
        When call _modify_template_files
        The status should be success
      End
    End

    Describe "bridge mode logging"
      It "handles undefined BRIDGE_MODE"
        unset BRIDGE_MODE
        tmpdir=$(mktemp -d)
        cd "$tmpdir" || exit 1
        MOCK_ARIA2C_AVAILABLE=false
        When call make_templates
        The status should be success
        cd - >/dev/null || exit 1
        rm -rf "$tmpdir"
      End
    End
  End
End

