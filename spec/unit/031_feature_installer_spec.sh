# shellcheck shell=bash
# =============================================================================
# Tests for 031-feature-installer.sh
# =============================================================================

%const SCRIPTS_DIR: "${SHELLSPEC_PROJECT_ROOT}/scripts"

# Mocks
log() { :; }
print_error() { echo "ERROR: $*" >&2; }
print_warning() { echo "WARNING: $*"; }
show_progress() {
  wait "$1" 2>/dev/null
  return $?
}

# Test functions
test_install_success() { return 0; }
test_install_fail() { return 1; }
test_config_success() { return 0; }
test_config_fail() { return 1; }

Describe "031-feature-installer.sh"
Include "$SCRIPTS_DIR/031-feature-installer.sh"

Describe "install_optional_feature()"
It "skips when install var is not 'yes'"
INSTALL_TEST="no"
When call install_optional_feature "Test Feature" "INSTALL_TEST" "test_install_success" "test_config_success"
The status should be success
End

It "skips when install var is empty"
INSTALL_TEST=""
When call install_optional_feature "Test Feature" "INSTALL_TEST" "test_install_success" "test_config_success"
The status should be success
End

It "runs install and config when enabled"
INSTALL_TEST="yes"
When call install_optional_feature "Test Feature" "INSTALL_TEST" "test_install_success" "test_config_success" "TEST_INSTALLED"
The status should be success
The variable TEST_INSTALLED should equal "yes"
End

It "fails when install function fails"
INSTALL_TEST="yes"
When call install_optional_feature "Test Feature" "INSTALL_TEST" "test_install_fail" "test_config_success"
The status should be failure
The stderr should include "installation failed"
End

It "continues when config fails (non-fatal)"
INSTALL_TEST="yes"
When call install_optional_feature "Test Feature" "INSTALL_TEST" "test_install_success" "test_config_fail"
The status should be success
The output should include "configuration failed"
End
End
End
