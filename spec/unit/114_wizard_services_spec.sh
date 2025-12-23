# shellcheck shell=bash
# shellcheck disable=SC2034,SC2154
# =============================================================================
# Tests for 114-wizard-services.sh
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
# Additional mocks for wizard-services functions
# =============================================================================

# Mock return values
MOCK_WIZ_INPUT_VALUE=""
MOCK_WIZ_INPUT_CANCELLED=false
MOCK_WIZ_CHOOSE_VALUE=""
MOCK_WIZ_CHOOSE_CANCELLED=false
MOCK_WIZ_CHOOSE_MULTI_VALUE=""
MOCK_WIZ_CHOOSE_MULTI_CANCELLED=false

# Sequence-based mock support
MOCK_WIZ_INPUT_SEQUENCE=()
MOCK_WIZ_INPUT_INDEX=0
MOCK_WIZ_CHOOSE_SEQUENCE=()
MOCK_WIZ_CHOOSE_INDEX=0

# Track function calls
MOCK_CALLS=()

# Temp file for tracking calls across subshells
MOCK_CALL_COUNTER_FILE="/tmp/mock_call_counter_$$"

reset_wizard_services_mocks() {
  MOCK_WIZ_INPUT_VALUE=""
  MOCK_WIZ_INPUT_CANCELLED=false
  MOCK_WIZ_CHOOSE_VALUE=""
  MOCK_WIZ_CHOOSE_CANCELLED=false
  MOCK_WIZ_CHOOSE_MULTI_VALUE=""
  MOCK_WIZ_CHOOSE_MULTI_CANCELLED=false
  MOCK_WIZ_INPUT_SEQUENCE=()
  MOCK_WIZ_INPUT_INDEX=0
  MOCK_WIZ_CHOOSE_SEQUENCE=()
  MOCK_WIZ_CHOOSE_INDEX=0
  MOCK_CALLS=()

  # Clean up temp files for sequence tracking
  rm -f "${MOCK_CALL_COUNTER_FILE}.input" "${MOCK_CALL_COUNTER_FILE}.choose" "${MOCK_CALL_COUNTER_FILE}.calls" 2>/dev/null || true

  # Reset globals
  INSTALL_TAILSCALE=""
  TAILSCALE_AUTH_KEY=""
  TAILSCALE_WEBUI=""
  SSL_TYPE=""
  FIREWALL_MODE=""
  INSTALL_FIREWALL=""
  SHELL_TYPE=""
  CPU_GOVERNOR=""
  FQDN=""
  MAIN_IPV4=""
  DNS_RESOLVED_IP=""

  # Reset security feature flags
  INSTALL_APPARMOR=""
  INSTALL_AUDITD=""
  INSTALL_AIDE=""
  INSTALL_CHKROOTKIT=""
  INSTALL_LYNIS=""
  INSTALL_NEEDRESTART=""

  # Reset monitoring feature flags
  INSTALL_VNSTAT=""
  INSTALL_NETDATA=""
  INSTALL_PROMTAIL=""

  # Reset tools feature flags
  INSTALL_YAZI=""
  INSTALL_NVIM=""
  INSTALL_RINGBUFFER=""
}

# Helper to check if a call was made
mock_calls_include() {
  local pattern="$1"
  [[ -f "${MOCK_CALL_COUNTER_FILE}.calls" ]] && grep -q "$pattern" "${MOCK_CALL_COUNTER_FILE}.calls"
}

# Mock UI functions with sequence support
_wiz_input() {
  echo "_wiz_input" >> "${MOCK_CALL_COUNTER_FILE}.calls" 2>/dev/null || true

  if [[ $MOCK_WIZ_INPUT_CANCELLED == true ]]; then
    echo ""
    return
  fi
  # Use sequence if defined
  if [[ ${#MOCK_WIZ_INPUT_SEQUENCE[@]} -gt 0 ]]; then
    local idx=0
    [[ -f "${MOCK_CALL_COUNTER_FILE}.input" ]] && idx=$(cat "${MOCK_CALL_COUNTER_FILE}.input")
    local val="${MOCK_WIZ_INPUT_SEQUENCE[$idx]:-}"
    echo $((idx + 1)) > "${MOCK_CALL_COUNTER_FILE}.input"
    echo "$val"
  else
    echo "$MOCK_WIZ_INPUT_VALUE"
  fi
}

_wiz_choose() {
  echo "_wiz_choose" >> "${MOCK_CALL_COUNTER_FILE}.calls" 2>/dev/null || true

  if [[ $MOCK_WIZ_CHOOSE_CANCELLED == true ]]; then
    return 1
  fi
  # Use sequence if defined
  if [[ ${#MOCK_WIZ_CHOOSE_SEQUENCE[@]} -gt 0 ]]; then
    local idx=0
    [[ -f "${MOCK_CALL_COUNTER_FILE}.choose" ]] && idx=$(cat "${MOCK_CALL_COUNTER_FILE}.choose")
    local val="${MOCK_WIZ_CHOOSE_SEQUENCE[$idx]:-}"
    echo $((idx + 1)) > "${MOCK_CALL_COUNTER_FILE}.choose"
    # Empty string in sequence means return 1 (cancel)
    if [[ -z $val ]]; then
      return 1
    fi
    echo "$val"
  else
    echo "$MOCK_WIZ_CHOOSE_VALUE"
  fi
}

_wiz_choose_multi() {
  echo "_wiz_choose_multi" >> "${MOCK_CALL_COUNTER_FILE}.calls" 2>/dev/null || true

  if [[ $MOCK_WIZ_CHOOSE_MULTI_CANCELLED == true ]]; then
    return 1
  fi
  echo "$MOCK_WIZ_CHOOSE_MULTI_VALUE"
}

_wiz_start_edit() {
  MOCK_CALLS+=("_wiz_start_edit")
  echo "_wiz_start_edit" >> "${MOCK_CALL_COUNTER_FILE}.calls" 2>/dev/null || true
}
_wiz_blank_line() { :; }
_wiz_warn() { :; }
_wiz_error() { :; }
_wiz_info() { :; }
_wiz_dim() { :; }
_wiz_description() { :; }
_show_input_footer() { :; }
show_validation_error() {
  MOCK_CALLS+=("show_validation_error: $1")
  echo "show_validation_error: $1" >> "${MOCK_CALL_COUNTER_FILE}.calls" 2>/dev/null || true
}
register_temp_file() { :; }

# Validation function mocks
validate_tailscale_key() {
  local key="$1"
  [[ -z $key ]] && return 1
  [[ $key =~ ^tskey-(auth|client)-[a-zA-Z0-9]+-[a-zA-Z0-9]+$ ]]
}

validate_fqdn() {
  local fqdn="$1"
  [[ $fqdn =~ ^[a-zA-Z0-9]([a-zA-Z0-9-]{0,61}[a-zA-Z0-9])?(\.[a-zA-Z0-9]([a-zA-Z0-9-]{0,61}[a-zA-Z0-9])?)+$ ]]
}

# Mock DNS validation - default success
MOCK_DNS_RESULT=0
validate_dns_resolution() {
  DNS_RESOLVED_IP="$MAIN_IPV4"
  return "$MOCK_DNS_RESULT"
}

# Wizard option strings
WIZ_TOGGLE_OPTIONS="Enabled
Disabled"

WIZ_SSL_TYPES="Self-signed
Let's Encrypt"

WIZ_SHELL_OPTIONS="ZSH
Bash"

WIZ_FEATURES_SECURITY="apparmor
auditd
aide
chkrootkit
lynis
needrestart"

WIZ_FEATURES_MONITORING="vnstat
netdata
promtail"

WIZ_FEATURES_TOOLS="yazi
nvim
ringbuffer"

Describe "114-wizard-services.sh"
  Include "$SCRIPTS_DIR/114-wizard-services.sh"

  # ===========================================================================
  # _edit_tailscale()
  # ===========================================================================
  Describe "_edit_tailscale()"
    BeforeEach 'reset_wizard_services_mocks'

    Describe "when Enabled is selected"
      It "sets INSTALL_TAILSCALE=yes with valid auth key"
        MOCK_WIZ_CHOOSE_SEQUENCE=("Enabled" "Enabled")
        MOCK_WIZ_INPUT_VALUE="tskey-auth-abc123-def456"
        When call _edit_tailscale
        The variable INSTALL_TAILSCALE should equal "yes"
        The variable TAILSCALE_AUTH_KEY should equal "tskey-auth-abc123-def456"
      End

      It "sets SSL_TYPE to self-signed when Tailscale enabled"
        MOCK_WIZ_CHOOSE_SEQUENCE=("Enabled" "Enabled")
        MOCK_WIZ_INPUT_VALUE="tskey-auth-abc123-def456"
        When call _edit_tailscale
        The variable SSL_TYPE should equal "self-signed"
      End

      It "suggests stealth firewall mode when Tailscale enabled"
        MOCK_WIZ_CHOOSE_SEQUENCE=("Enabled" "Enabled")
        MOCK_WIZ_INPUT_VALUE="tskey-auth-abc123-def456"
        When call _edit_tailscale
        The variable INSTALL_FIREWALL should equal "yes"
        The variable FIREWALL_MODE should equal "stealth"
      End

      It "sets TAILSCALE_WEBUI=yes when Tailscale Serve enabled"
        MOCK_WIZ_CHOOSE_SEQUENCE=("Enabled" "Enabled")
        MOCK_WIZ_INPUT_VALUE="tskey-auth-abc123-def456"
        When call _edit_tailscale
        The variable TAILSCALE_WEBUI should equal "yes"
      End

      It "sets TAILSCALE_WEBUI=no when Tailscale Serve disabled"
        MOCK_WIZ_CHOOSE_SEQUENCE=("Enabled" "Disabled")
        MOCK_WIZ_INPUT_VALUE="tskey-auth-abc123-def456"
        When call _edit_tailscale
        The variable TAILSCALE_WEBUI should equal "no"
      End

      It "shows validation error for invalid auth key format"
        MOCK_WIZ_CHOOSE_VALUE="Enabled"
        MOCK_WIZ_INPUT_SEQUENCE=("invalid-key" "")
        When call _edit_tailscale
        Assert mock_calls_include "show_validation_error"
      End

      It "disables Tailscale when auth key is cancelled"
        MOCK_WIZ_CHOOSE_VALUE="Enabled"
        MOCK_WIZ_INPUT_VALUE=""
        When call _edit_tailscale
        The variable INSTALL_TAILSCALE should equal "no"
        The variable TAILSCALE_AUTH_KEY should be blank
      End

      It "accepts tskey-client format"
        MOCK_WIZ_CHOOSE_SEQUENCE=("Enabled" "Disabled")
        MOCK_WIZ_INPUT_VALUE="tskey-client-xyz789-abc123"
        When call _edit_tailscale
        The variable INSTALL_TAILSCALE should equal "yes"
        The variable TAILSCALE_AUTH_KEY should equal "tskey-client-xyz789-abc123"
      End
    End

    Describe "when Disabled is selected"
      It "sets INSTALL_TAILSCALE=no"
        MOCK_WIZ_CHOOSE_VALUE="Disabled"
        When call _edit_tailscale
        The variable INSTALL_TAILSCALE should equal "no"
      End

      It "clears TAILSCALE_AUTH_KEY"
        MOCK_WIZ_CHOOSE_VALUE="Disabled"
        TAILSCALE_AUTH_KEY="old-key"
        When call _edit_tailscale
        The variable TAILSCALE_AUTH_KEY should be blank
      End

      It "clears SSL_TYPE to allow user choice"
        MOCK_WIZ_CHOOSE_VALUE="Disabled"
        SSL_TYPE="letsencrypt"
        When call _edit_tailscale
        The variable SSL_TYPE should be blank
      End

      It "suggests standard firewall mode"
        MOCK_WIZ_CHOOSE_VALUE="Disabled"
        When call _edit_tailscale
        The variable INSTALL_FIREWALL should equal "yes"
        The variable FIREWALL_MODE should equal "standard"
      End
    End

    Describe "when cancelled"
      It "returns without changes"
        MOCK_WIZ_CHOOSE_CANCELLED=true
        INSTALL_TAILSCALE="original"
        When call _edit_tailscale
        The variable INSTALL_TAILSCALE should equal "original"
      End
    End
  End

  # ===========================================================================
  # _edit_ssl()
  # ===========================================================================
  Describe "_edit_ssl()"
    BeforeEach 'reset_wizard_services_mocks'

    Describe "Self-signed selection"
      It "sets SSL_TYPE to self-signed"
        MOCK_WIZ_CHOOSE_VALUE="Self-signed"
        When call _edit_ssl
        The variable SSL_TYPE should equal "self-signed"
      End
    End

    Describe "Let's Encrypt selection"
      It "sets SSL_TYPE to letsencrypt with valid FQDN and DNS"
        FQDN="pve.example.com"
        MAIN_IPV4="1.2.3.4"
        MOCK_DNS_RESULT=0
        MOCK_WIZ_CHOOSE_VALUE="Let's Encrypt"
        When call _edit_ssl
        The variable SSL_TYPE should equal "letsencrypt"
        # Allow stdout from progress animation
        The output should be present
      End

      It "falls back to self-signed when FQDN is empty"
        FQDN=""
        MOCK_WIZ_CHOOSE_VALUE="Let's Encrypt"
        When call _edit_ssl
        The variable SSL_TYPE should equal "self-signed"
      End

      It "falls back to self-signed for .local domain"
        FQDN="pve.local"
        MOCK_WIZ_CHOOSE_VALUE="Let's Encrypt"
        When call _edit_ssl
        The variable SSL_TYPE should equal "self-signed"
      End

      It "falls back to self-signed for invalid FQDN"
        FQDN="invalid"
        MOCK_WIZ_CHOOSE_VALUE="Let's Encrypt"
        When call _edit_ssl
        The variable SSL_TYPE should equal "self-signed"
      End

      It "falls back to self-signed when DNS resolution fails"
        FQDN="pve.example.com"
        MAIN_IPV4="1.2.3.4"
        MOCK_DNS_RESULT=1
        MOCK_WIZ_CHOOSE_VALUE="Let's Encrypt"
        When call _edit_ssl
        The variable SSL_TYPE should equal "self-signed"
        # Allow stdout from progress animation
        The output should be present
      End

      It "falls back to self-signed when DNS resolves to wrong IP"
        FQDN="pve.example.com"
        MAIN_IPV4="1.2.3.4"
        MOCK_DNS_RESULT=2
        MOCK_WIZ_CHOOSE_VALUE="Let's Encrypt"
        When call _edit_ssl
        The variable SSL_TYPE should equal "self-signed"
        # Allow stdout from progress animation
        The output should be present
      End
    End

    Describe "when cancelled"
      It "returns without changes"
        MOCK_WIZ_CHOOSE_CANCELLED=true
        SSL_TYPE="original"
        When call _edit_ssl
        The variable SSL_TYPE should equal "original"
      End
    End
  End

  # ===========================================================================
  # _edit_shell()
  # ===========================================================================
  Describe "_edit_shell()"
    BeforeEach 'reset_wizard_services_mocks'

    It "sets SHELL_TYPE to zsh when ZSH selected"
      MOCK_WIZ_CHOOSE_VALUE="ZSH"
      When call _edit_shell
      The variable SHELL_TYPE should equal "zsh"
    End

    It "sets SHELL_TYPE to bash when Bash selected"
      MOCK_WIZ_CHOOSE_VALUE="Bash"
      When call _edit_shell
      The variable SHELL_TYPE should equal "bash"
    End

    It "returns without changes when cancelled"
      MOCK_WIZ_CHOOSE_CANCELLED=true
      SHELL_TYPE="original"
      When call _edit_shell
      The variable SHELL_TYPE should equal "original"
    End

    It "calls _wiz_start_edit first"
      MOCK_WIZ_CHOOSE_VALUE="ZSH"
      When call _edit_shell
      Assert mock_calls_include "_wiz_start_edit"
    End
  End

  # ===========================================================================
  # _edit_power_profile()
  # ===========================================================================
  Describe "_edit_power_profile()"
    BeforeEach 'reset_wizard_services_mocks'

    It "sets CPU_GOVERNOR to performance when Performance selected"
      MOCK_WIZ_CHOOSE_VALUE="Performance"
      When call _edit_power_profile
      The variable CPU_GOVERNOR should equal "performance"
    End

    It "sets CPU_GOVERNOR to ondemand when Balanced selected (ondemand available)"
      MOCK_WIZ_CHOOSE_VALUE="Balanced"
      When call _edit_power_profile
      # Falls back to powersave if ondemand not in avail_governors
      The variable CPU_GOVERNOR should equal "powersave"
    End

    It "sets CPU_GOVERNOR to schedutil when Adaptive selected"
      MOCK_WIZ_CHOOSE_VALUE="Adaptive"
      When call _edit_power_profile
      The variable CPU_GOVERNOR should equal "schedutil"
    End

    It "sets CPU_GOVERNOR to conservative when Conservative selected"
      MOCK_WIZ_CHOOSE_VALUE="Conservative"
      When call _edit_power_profile
      The variable CPU_GOVERNOR should equal "conservative"
    End

    It "returns without changes when cancelled"
      MOCK_WIZ_CHOOSE_CANCELLED=true
      CPU_GOVERNOR="original"
      When call _edit_power_profile
      The variable CPU_GOVERNOR should equal "original"
    End
  End

  # ===========================================================================
  # _edit_features_security()
  # ===========================================================================
  Describe "_edit_features_security()"
    BeforeEach 'reset_wizard_services_mocks'

    It "enables all security features when all selected"
      MOCK_WIZ_CHOOSE_MULTI_VALUE="apparmor auditd aide chkrootkit lynis needrestart"
      When call _edit_features_security
      The variable INSTALL_APPARMOR should equal "yes"
      The variable INSTALL_AUDITD should equal "yes"
      The variable INSTALL_AIDE should equal "yes"
      The variable INSTALL_CHKROOTKIT should equal "yes"
      The variable INSTALL_LYNIS should equal "yes"
      The variable INSTALL_NEEDRESTART should equal "yes"
    End

    It "enables only apparmor when only apparmor selected"
      MOCK_WIZ_CHOOSE_MULTI_VALUE="apparmor"
      When call _edit_features_security
      The variable INSTALL_APPARMOR should equal "yes"
      The variable INSTALL_AUDITD should equal "no"
      The variable INSTALL_AIDE should equal "no"
      The variable INSTALL_CHKROOTKIT should equal "no"
      The variable INSTALL_LYNIS should equal "no"
      The variable INSTALL_NEEDRESTART should equal "no"
    End

    It "disables all features when none selected"
      MOCK_WIZ_CHOOSE_MULTI_VALUE=""
      When call _edit_features_security
      The variable INSTALL_APPARMOR should equal "no"
      The variable INSTALL_AUDITD should equal "no"
      The variable INSTALL_AIDE should equal "no"
      The variable INSTALL_CHKROOTKIT should equal "no"
      The variable INSTALL_LYNIS should equal "no"
      The variable INSTALL_NEEDRESTART should equal "no"
    End

    It "enables auditd and lynis only when those selected"
      MOCK_WIZ_CHOOSE_MULTI_VALUE="auditd lynis"
      When call _edit_features_security
      The variable INSTALL_APPARMOR should equal "no"
      The variable INSTALL_AUDITD should equal "yes"
      The variable INSTALL_AIDE should equal "no"
      The variable INSTALL_CHKROOTKIT should equal "no"
      The variable INSTALL_LYNIS should equal "yes"
      The variable INSTALL_NEEDRESTART should equal "no"
    End

    It "returns without changes when cancelled"
      MOCK_WIZ_CHOOSE_MULTI_CANCELLED=true
      INSTALL_APPARMOR="original"
      When call _edit_features_security
      The variable INSTALL_APPARMOR should equal "original"
    End
  End

  # ===========================================================================
  # _edit_features_monitoring()
  # ===========================================================================
  Describe "_edit_features_monitoring()"
    BeforeEach 'reset_wizard_services_mocks'

    It "enables all monitoring features when all selected"
      MOCK_WIZ_CHOOSE_MULTI_VALUE="vnstat netdata promtail"
      When call _edit_features_monitoring
      The variable INSTALL_VNSTAT should equal "yes"
      The variable INSTALL_NETDATA should equal "yes"
      The variable INSTALL_PROMTAIL should equal "yes"
    End

    It "enables only vnstat when only vnstat selected"
      MOCK_WIZ_CHOOSE_MULTI_VALUE="vnstat"
      When call _edit_features_monitoring
      The variable INSTALL_VNSTAT should equal "yes"
      The variable INSTALL_NETDATA should equal "no"
      The variable INSTALL_PROMTAIL should equal "no"
    End

    It "enables netdata and promtail when those selected"
      MOCK_WIZ_CHOOSE_MULTI_VALUE="netdata promtail"
      When call _edit_features_monitoring
      The variable INSTALL_VNSTAT should equal "no"
      The variable INSTALL_NETDATA should equal "yes"
      The variable INSTALL_PROMTAIL should equal "yes"
    End

    It "disables all features when none selected"
      MOCK_WIZ_CHOOSE_MULTI_VALUE=""
      When call _edit_features_monitoring
      The variable INSTALL_VNSTAT should equal "no"
      The variable INSTALL_NETDATA should equal "no"
      The variable INSTALL_PROMTAIL should equal "no"
    End

    It "returns without changes when cancelled"
      MOCK_WIZ_CHOOSE_MULTI_CANCELLED=true
      INSTALL_VNSTAT="original"
      When call _edit_features_monitoring
      The variable INSTALL_VNSTAT should equal "original"
    End
  End

  # ===========================================================================
  # _edit_features_tools()
  # ===========================================================================
  Describe "_edit_features_tools()"
    BeforeEach 'reset_wizard_services_mocks'

    It "enables all tools when all selected"
      MOCK_WIZ_CHOOSE_MULTI_VALUE="yazi nvim ringbuffer"
      When call _edit_features_tools
      The variable INSTALL_YAZI should equal "yes"
      The variable INSTALL_NVIM should equal "yes"
      The variable INSTALL_RINGBUFFER should equal "yes"
    End

    It "enables only yazi when only yazi selected"
      MOCK_WIZ_CHOOSE_MULTI_VALUE="yazi"
      When call _edit_features_tools
      The variable INSTALL_YAZI should equal "yes"
      The variable INSTALL_NVIM should equal "no"
      The variable INSTALL_RINGBUFFER should equal "no"
    End

    It "enables nvim and ringbuffer when those selected"
      MOCK_WIZ_CHOOSE_MULTI_VALUE="nvim ringbuffer"
      When call _edit_features_tools
      The variable INSTALL_YAZI should equal "no"
      The variable INSTALL_NVIM should equal "yes"
      The variable INSTALL_RINGBUFFER should equal "yes"
    End

    It "disables all tools when none selected"
      MOCK_WIZ_CHOOSE_MULTI_VALUE=""
      When call _edit_features_tools
      The variable INSTALL_YAZI should equal "no"
      The variable INSTALL_NVIM should equal "no"
      The variable INSTALL_RINGBUFFER should equal "no"
    End

    It "returns without changes when cancelled"
      MOCK_WIZ_CHOOSE_MULTI_CANCELLED=true
      INSTALL_YAZI="original"
      When call _edit_features_tools
      The variable INSTALL_YAZI should equal "original"
    End
  End

  # ===========================================================================
  # Edge cases
  # ===========================================================================
  Describe "edge cases"
    BeforeEach 'reset_wizard_services_mocks'

    Describe "firewall mode preservation"
      It "does not override existing INSTALL_FIREWALL when Tailscale enabled"
        INSTALL_FIREWALL="yes"
        FIREWALL_MODE="strict"
        MOCK_WIZ_CHOOSE_SEQUENCE=("Enabled" "Disabled")
        MOCK_WIZ_INPUT_VALUE="tskey-auth-abc123-def456"
        When call _edit_tailscale
        The variable INSTALL_FIREWALL should equal "yes"
        The variable FIREWALL_MODE should equal "strict"
      End

      It "does not override existing INSTALL_FIREWALL when Tailscale disabled"
        INSTALL_FIREWALL="yes"
        FIREWALL_MODE="strict"
        MOCK_WIZ_CHOOSE_VALUE="Disabled"
        When call _edit_tailscale
        The variable INSTALL_FIREWALL should equal "yes"
        The variable FIREWALL_MODE should equal "strict"
      End
    End

    Describe "auth key validation retry"
      It "retries after invalid key then accepts valid key"
        MOCK_WIZ_CHOOSE_SEQUENCE=("Enabled" "Disabled")
        MOCK_WIZ_INPUT_SEQUENCE=("bad-key" "tskey-auth-abc123-def456")
        When call _edit_tailscale
        The variable INSTALL_TAILSCALE should equal "yes"
        The variable TAILSCALE_AUTH_KEY should equal "tskey-auth-abc123-def456"
      End
    End
  End
End

