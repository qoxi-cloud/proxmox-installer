# shellcheck shell=bash
# shellcheck disable=SC2034,SC2016
# =============================================================================
# Tests for 900-main.sh
# =============================================================================
#
# Note: 900-main.sh has top-level execution code that runs on source.
# We extract only the function definitions (lines 1-145) to test.

%const SCRIPTS_DIR: "${SHELLSPEC_PROJECT_ROOT}/scripts"
%const SUPPORT_DIR: "${SHELLSPEC_PROJECT_ROOT}/spec/support"

# Load shared mocks
eval "$(cat "$SUPPORT_DIR/colors.sh")"
eval "$(cat "$SUPPORT_DIR/configure_mocks.sh")"
eval "$(cat "$SUPPORT_DIR/core_mocks.sh")"
eval "$(cat "$SUPPORT_DIR/main_mocks.sh")"

VERSION="1.0.0"
LOG_FILE="/dev/null"

# Extract only the functions from 900-main.sh (lines 1-145), avoiding main execution
# shellcheck disable=SC1090
eval "$(sed -n '1,145p' "$SCRIPTS_DIR/900-main.sh")"

Describe "900-main.sh"
  # ===========================================================================
  # _render_completion_screen()
  # ===========================================================================
  Describe "_render_completion_screen()"
    setup() {
      PVE_HOSTNAME="testhost"
      DOMAIN_SUFFIX="example.com"
      ADMIN_USERNAME="admin"
      ADMIN_PASSWORD="secret123"
      NEW_ROOT_PASSWORD="root456"
      MAIN_IPV4="192.168.1.100"
      FIREWALL_MODE="standard"
      TAILSCALE_IP=""
      rm -f /tmp/pve-install-api-token.env
    }
    BeforeEach 'setup'

    It "includes hostname in output"
      When call _render_completion_screen
      The output should include "testhost.example.com"
    End

    It "includes admin username in output"
      When call _render_completion_screen
      The output should include "admin"
    End

    It "includes admin password in output"
      When call _render_completion_screen
      The output should include "secret123"
    End

    It "includes root password in output"
      When call _render_completion_screen
      The output should include "root456"
    End

    It "includes Installation Complete header"
      When call _render_completion_screen
      The output should include "Installation Complete"
    End

    It "includes save credentials warning"
      When call _render_completion_screen
      The output should include "SAVE THESE CREDENTIALS"
    End

    Describe "with standard firewall mode"
      BeforeEach 'FIREWALL_MODE="standard"; TAILSCALE_IP=""'

      It "shows SSH access via main IP"
        When call _render_completion_screen
        The output should include "ssh admin@192.168.1.100"
      End

      It "shows Web UI access via main IP"
        When call _render_completion_screen
        The output should include "https://192.168.1.100:8006"
      End
    End

    Describe "with strict firewall mode"
      BeforeEach 'FIREWALL_MODE="strict"; TAILSCALE_IP=""'

      It "shows SSH access via main IP"
        When call _render_completion_screen
        The output should include "ssh admin@192.168.1.100"
      End

      It "shows Web UI as blocked"
        When call _render_completion_screen
        The output should include "blocked"
        The output should include "strict mode"
      End
    End

    Describe "with stealth firewall mode"
      BeforeEach 'FIREWALL_MODE="stealth"; TAILSCALE_IP=""'

      It "shows SSH as blocked"
        When call _render_completion_screen
        The output should include "blocked"
        The output should include "stealth mode"
      End

      It "shows Web UI as blocked"
        When call _render_completion_screen
        The output should include "blocked"
      End
    End

    Describe "with Tailscale enabled"
      BeforeEach 'TAILSCALE_IP="100.64.0.1"'

      It "shows Tailscale SSH in standard mode"
        FIREWALL_MODE="standard"
        When call _render_completion_screen
        The output should include "100.64.0.1"
        The output should include "Tailscale"
      End

      It "shows Tailscale access in strict mode"
        FIREWALL_MODE="strict"
        When call _render_completion_screen
        The output should include "100.64.0.1"
        The output should include "Tailscale"
      End

      It "shows Tailscale access in stealth mode"
        FIREWALL_MODE="stealth"
        When call _render_completion_screen
        The output should include "100.64.0.1"
        The output should include "Tailscale"
      End
    End

    Describe "with pending Tailscale IP"
      BeforeEach 'TAILSCALE_IP="pending"'

      It "does not show Tailscale access"
        FIREWALL_MODE="standard"
        When call _render_completion_screen
        The output should not include "pending"
      End
    End

    Describe "with not authenticated Tailscale IP"
      BeforeEach 'TAILSCALE_IP="not authenticated"'

      It "does not show Tailscale section"
        FIREWALL_MODE="standard"
        When call _render_completion_screen
        The output should not include "not authenticated"
      End
    End

    Describe "with API token"
      setup_api_token() {
        echo 'API_TOKEN_ID="user@pam!token"' > /tmp/pve-install-api-token.env
        echo 'API_TOKEN_VALUE="secret-token-value"' >> /tmp/pve-install-api-token.env
      }
      cleanup_api_token() {
        rm -f /tmp/pve-install-api-token.env
      }
      BeforeEach 'setup_api_token'
      AfterEach 'cleanup_api_token'

      It "shows API token ID"
        When call _render_completion_screen
        The output should include "API Token ID"
        The output should include "user@pam!token"
      End

      It "shows API secret"
        When call _render_completion_screen
        The output should include "API Secret"
        The output should include "secret-token-value"
      End
    End

    Describe "without API token file"
      BeforeEach 'rm -f /tmp/pve-install-api-token.env'

      It "does not show API token section"
        When call _render_completion_screen
        The output should not include "API Token ID"
      End
    End
  End

  # ===========================================================================
  # _completion_screen_input()
  # ===========================================================================
  Describe "_completion_screen_input()"
    # Note: This function has an infinite loop with blocking read.
    # Testing requires complex terminal mocking that ShellSpec doesn't support well.
    # We skip execution tests and verify structure via code inspection.

    It "is defined as a function"
      When call type _completion_screen_input
      The output should include "function"
    End
  End

  # ===========================================================================
  # reboot_to_main_os()
  # ===========================================================================
  Describe "reboot_to_main_os()"
    setup_reboot() {
      # Mock both functions to prevent actual execution
      finish_live_installation() { echo "finish_called"; }
      _completion_screen_input() { echo "input_called"; }
    }
    BeforeEach 'setup_reboot'

    It "calls finish_live_installation"
      When call reboot_to_main_os
      The output should include "finish_called"
    End

    It "calls _completion_screen_input"
      When call reboot_to_main_os
      The output should include "input_called"
    End

    It "calls finish_live_installation before _completion_screen_input"
      When call reboot_to_main_os
      The line 1 of output should include "finish_called"
      The line 2 of output should include "input_called"
    End
  End
End
