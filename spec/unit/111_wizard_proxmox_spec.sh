# shellcheck shell=bash
# shellcheck disable=SC2034,SC2154
# =============================================================================
# Tests for 111-wizard-proxmox.sh
# =============================================================================
# Note: SC2034 disabled - variables used by ShellSpec assertions
#       SC2154 disabled - variables set by mocks

%const SCRIPTS_DIR: "${SHELLSPEC_PROJECT_ROOT}/scripts"
%const SUPPORT_DIR: "${SHELLSPEC_PROJECT_ROOT}/spec/support"

# Load shared mocks
eval "$(cat "$SUPPORT_DIR/colors.sh")"
eval "$(cat "$SUPPORT_DIR/core_mocks.sh")"
eval "$(cat "$SUPPORT_DIR/ui_mocks.sh")"

# =============================================================================
# Wizard UI mocks
# =============================================================================

# Track function calls for assertions
MOCK_WIZ_CHOOSE_RESULT=""
MOCK_WIZ_CHOOSE_EXIT=0
MOCK_WIZ_INPUT_RESULT=""
MOCK_WIZ_INPUT_EXIT=0
MOCK_ISO_LIST=""

# Reset mocks between tests
reset_proxmox_mocks() {
  MOCK_WIZ_CHOOSE_RESULT=""
  MOCK_WIZ_CHOOSE_EXIT=0
  MOCK_WIZ_INPUT_RESULT=""
  MOCK_WIZ_INPUT_EXIT=0
  MOCK_ISO_LIST=""
  PROXMOX_ISO_VERSION=""
  PVE_REPO_TYPE=""
  PVE_SUBSCRIPTION_KEY=""
}

# Mock wizard UI functions
_wiz_start_edit() { :; }
_wiz_description() { :; }
_wiz_blank_line() { :; }
_wiz_error() { :; }
_wiz_input_screen() { :; }
_show_input_footer() { :; }

_wiz_choose() {
  if [[ $MOCK_WIZ_CHOOSE_EXIT -ne 0 ]]; then
    return $MOCK_WIZ_CHOOSE_EXIT
  fi
  printf '%s\n' "$MOCK_WIZ_CHOOSE_RESULT"
}

_wiz_input() {
  if [[ $MOCK_WIZ_INPUT_EXIT -ne 0 ]]; then
    return $MOCK_WIZ_INPUT_EXIT
  fi
  printf '%s\n' "$MOCK_WIZ_INPUT_RESULT"
}

# Mock external dependency
get_available_proxmox_isos() {
  printf '%s\n' "$MOCK_ISO_LIST"
}

# Global constant from 000-init.sh
WIZ_REPO_TYPES="No-subscription (free)
Enterprise
Test/Development"

Describe "111-wizard-proxmox.sh"
  Include "$SCRIPTS_DIR/111-wizard-proxmox.sh"

  # ===========================================================================
  # _edit_iso_version()
  # ===========================================================================
  Describe "_edit_iso_version()"
    BeforeEach 'reset_proxmox_mocks'

    It "sets PROXMOX_ISO_VERSION when user selects a version"
      MOCK_ISO_LIST="proxmox-ve_9.0-1.iso
proxmox-ve_9.1-1.iso
proxmox-ve_9.2-1.iso"
      MOCK_WIZ_CHOOSE_RESULT="proxmox-ve_9.1-1.iso"
      When call _edit_iso_version
      The status should be success
      The variable PROXMOX_ISO_VERSION should equal "proxmox-ve_9.1-1.iso"
    End

    It "sets latest version when user selects it"
      MOCK_ISO_LIST="proxmox-ve_9.0-1.iso
proxmox-ve_9.1-1.iso
proxmox-ve_9.2-1.iso"
      MOCK_WIZ_CHOOSE_RESULT="proxmox-ve_9.2-1.iso"
      When call _edit_iso_version
      The status should be success
      The variable PROXMOX_ISO_VERSION should equal "proxmox-ve_9.2-1.iso"
    End

    It "returns early if ISO list is empty"
      MOCK_ISO_LIST=""
      When call _edit_iso_version
      The status should be success
      The variable PROXMOX_ISO_VERSION should equal ""
    End

    It "does not update version when user cancels"
      MOCK_ISO_LIST="proxmox-ve_9.0-1.iso
proxmox-ve_9.1-1.iso"
      MOCK_WIZ_CHOOSE_EXIT=1
      PROXMOX_ISO_VERSION="proxmox-ve_8.0-1.iso"
      When call _edit_iso_version
      The status should be success
      The variable PROXMOX_ISO_VERSION should equal "proxmox-ve_8.0-1.iso"
    End
  End

  # ===========================================================================
  # _edit_repository()
  # ===========================================================================
  Describe "_edit_repository()"
    BeforeEach 'reset_proxmox_mocks'

    Describe "repository selection"
      It "sets no-subscription repo type"
        MOCK_WIZ_CHOOSE_RESULT="No-subscription (free)"
        When call _edit_repository
        The status should be success
        The variable PVE_REPO_TYPE should equal "no-subscription"
        The variable PVE_SUBSCRIPTION_KEY should equal ""
      End

      It "sets test repo type"
        MOCK_WIZ_CHOOSE_RESULT="Test/Development"
        When call _edit_repository
        The status should be success
        The variable PVE_REPO_TYPE should equal "test"
        The variable PVE_SUBSCRIPTION_KEY should equal ""
      End

      It "does not update repo type when user cancels"
        MOCK_WIZ_CHOOSE_EXIT=1
        PVE_REPO_TYPE="no-subscription"
        When call _edit_repository
        The status should be success
        The variable PVE_REPO_TYPE should equal "no-subscription"
      End
    End

    Describe "enterprise repo with subscription key"
      It "sets enterprise repo and prompts for subscription key"
        MOCK_WIZ_CHOOSE_RESULT="Enterprise"
        MOCK_WIZ_INPUT_RESULT="pve2c-abcd1234"
        When call _edit_repository
        The status should be success
        The variable PVE_REPO_TYPE should equal "enterprise"
        The variable PVE_SUBSCRIPTION_KEY should equal "pve2c-abcd1234"
      End

      It "accepts empty subscription key for enterprise"
        MOCK_WIZ_CHOOSE_RESULT="Enterprise"
        MOCK_WIZ_INPUT_RESULT=""
        When call _edit_repository
        The status should be success
        The variable PVE_REPO_TYPE should equal "enterprise"
        The variable PVE_SUBSCRIPTION_KEY should equal ""
      End

      It "preserves existing subscription key as default"
        PVE_SUBSCRIPTION_KEY="pve2c-existing"
        MOCK_WIZ_CHOOSE_RESULT="Enterprise"
        MOCK_WIZ_INPUT_RESULT="pve2c-existing"
        When call _edit_repository
        The status should be success
        The variable PVE_SUBSCRIPTION_KEY should equal "pve2c-existing"
      End
    End

    Describe "clearing subscription key"
      It "clears subscription key when switching from enterprise to no-subscription"
        PVE_REPO_TYPE="enterprise"
        PVE_SUBSCRIPTION_KEY="pve2c-oldkey"
        MOCK_WIZ_CHOOSE_RESULT="No-subscription (free)"
        When call _edit_repository
        The status should be success
        The variable PVE_REPO_TYPE should equal "no-subscription"
        The variable PVE_SUBSCRIPTION_KEY should equal ""
      End

      It "clears subscription key when switching from enterprise to test"
        PVE_REPO_TYPE="enterprise"
        PVE_SUBSCRIPTION_KEY="pve2c-oldkey"
        MOCK_WIZ_CHOOSE_RESULT="Test/Development"
        When call _edit_repository
        The status should be success
        The variable PVE_REPO_TYPE should equal "test"
        The variable PVE_SUBSCRIPTION_KEY should equal ""
      End
    End
  End
End

