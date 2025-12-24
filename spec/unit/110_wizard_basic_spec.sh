# shellcheck shell=bash
# shellcheck disable=SC2034,SC2154
# =============================================================================
# Tests for 110-wizard-basic.sh
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
# Additional mocks for wizard-basic functions
# =============================================================================

# Mock return values
MOCK_WIZ_INPUT_VALUE=""
MOCK_WIZ_INPUT_CANCELLED=false
MOCK_WIZ_CHOOSE_VALUE=""
MOCK_WIZ_CHOOSE_CANCELLED=false
MOCK_WIZ_FILTER_VALUE=""
MOCK_WIZ_FILTER_CANCELLED=false

# Sequence-based mock support
MOCK_WIZ_INPUT_SEQUENCE=()
MOCK_WIZ_INPUT_INDEX=0
MOCK_WIZ_CHOOSE_SEQUENCE=()
MOCK_WIZ_CHOOSE_INDEX=0

# Track function calls
MOCK_CALLS=()

reset_wizard_basic_mocks() {
  MOCK_WIZ_INPUT_VALUE=""
  MOCK_WIZ_INPUT_CANCELLED=false
  MOCK_WIZ_CHOOSE_VALUE=""
  MOCK_WIZ_CHOOSE_CANCELLED=false
  MOCK_WIZ_FILTER_VALUE=""
  MOCK_WIZ_FILTER_CANCELLED=false
  MOCK_WIZ_INPUT_SEQUENCE=()
  MOCK_WIZ_INPUT_INDEX=0
  MOCK_WIZ_CHOOSE_SEQUENCE=()
  MOCK_WIZ_CHOOSE_INDEX=0
  MOCK_CALLS=()

  # Clean up temp files for sequence tracking
  rm -f "${MOCK_CALL_COUNTER_FILE}.input" "${MOCK_CALL_COUNTER_FILE}.choose" "${MOCK_CALL_COUNTER_FILE}.calls" 2>/dev/null || true

  # Reset globals
  PVE_HOSTNAME=""
  DOMAIN_SUFFIX=""
  FQDN=""
  EMAIL=""
  NEW_ROOT_PASSWORD=""
  PASSWORD_GENERATED=""
  TIMEZONE=""
  KEYBOARD=""
  COUNTRY=""
  LOCALE=""
  DEFAULT_PASSWORD_LENGTH=16
}

# Helper to check if a call was made (for assertions)
mock_calls_include() {
  local pattern="$1"
  [[ -f "${MOCK_CALL_COUNTER_FILE}.calls" ]] && grep -q "$pattern" "${MOCK_CALL_COUNTER_FILE}.calls"
}

# Helper to check first call
mock_calls_starts_with() {
  local pattern="$1"
  [[ -f "${MOCK_CALL_COUNTER_FILE}.calls" ]] && head -1 "${MOCK_CALL_COUNTER_FILE}.calls" | grep -q "^$pattern"
}

# Temp file for tracking calls across subshells
MOCK_CALL_COUNTER_FILE="/tmp/mock_call_counter_$$"

# Mock UI functions with sequence support (uses temp file for subshell persistence)
_wiz_input() {
  # Track call for assertions
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

_wiz_filter() {
  MOCK_CALLS+=("_wiz_filter")
  if [[ $MOCK_WIZ_FILTER_CANCELLED == true ]]; then
    return 1
  fi
  echo "$MOCK_WIZ_FILTER_VALUE"
}

_wiz_start_edit() {
  MOCK_CALLS+=("_wiz_start_edit")
  echo "_wiz_start_edit" >> "${MOCK_CALL_COUNTER_FILE}.calls" 2>/dev/null || true
}
_wiz_blank_line() { :; }
_wiz_warn() { :; }
_wiz_error() { :; }
_show_input_footer() { :; }
show_validation_error() {
  MOCK_CALLS+=("show_validation_error: $1")
  echo "show_validation_error: $1" >> "${MOCK_CALL_COUNTER_FILE}.calls" 2>/dev/null || true
}
generate_password() { echo "generated_password_123"; }

# Include validation functions (needed for actual validation logic)
validate_hostname() {
  local hostname="$1"
  [[ ${hostname,,} == "localhost" ]] && return 1
  [[ $hostname =~ ^[a-zA-Z0-9]([a-zA-Z0-9-]{0,61}[a-zA-Z0-9])?$ ]]
}

validate_email() {
  local email="$1"
  [[ $email =~ ^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$ ]]
}

get_password_error() {
  local password="$1"
  if [[ -z $password ]]; then
    printf '%s\n' "Password cannot be empty!"
  elif [[ ${#password} -lt 8 ]]; then
    printf '%s\n' "Password must be at least 8 characters long."
  fi
}

# Wizard option strings
WIZ_PASSWORD_OPTIONS="Generate password
Manual entry"
WIZ_TIMEZONES="UTC
America/New_York
Europe/London"
WIZ_KEYBOARD_LAYOUTS="us
de
fr"
WIZ_COUNTRIES="us
de
ua"

# Timezone to country mapping
declare -A TZ_TO_COUNTRY
TZ_TO_COUNTRY["America/New_York"]="us"
TZ_TO_COUNTRY["Europe/London"]="gb"
TZ_TO_COUNTRY["Europe/Berlin"]="de"
TZ_TO_COUNTRY["Europe/Kiev"]="ua"

Describe "110-wizard-basic.sh"
  Include "$SCRIPTS_DIR/110-wizard-basic.sh"

  # ===========================================================================
  # _country_to_locale()
  # ===========================================================================
  Describe "_country_to_locale()"
    It "returns en_US.UTF-8 for us"
      When call _country_to_locale "us"
      The output should equal "en_US.UTF-8"
    End

    It "returns en_GB.UTF-8 for gb"
      When call _country_to_locale "gb"
      The output should equal "en_GB.UTF-8"
    End

    It "returns de_DE.UTF-8 for de"
      When call _country_to_locale "de"
      The output should equal "de_DE.UTF-8"
    End

    It "returns uk_UA.UTF-8 for ua"
      When call _country_to_locale "ua"
      The output should equal "uk_UA.UTF-8"
    End

    It "returns ru_RU.UTF-8 for ru"
      When call _country_to_locale "ru"
      The output should equal "ru_RU.UTF-8"
    End

    It "returns fr_FR.UTF-8 for fr"
      When call _country_to_locale "fr"
      The output should equal "fr_FR.UTF-8"
    End

    It "handles uppercase country codes"
      When call _country_to_locale "US"
      The output should equal "en_US.UTF-8"
    End

    It "returns default en_US.UTF-8 for unknown country"
      When call _country_to_locale "xyz"
      The output should equal "en_US.UTF-8"
    End

    It "returns default en_US.UTF-8 for empty input"
      When call _country_to_locale ""
      The output should equal "en_US.UTF-8"
    End

    It "returns es_ES.UTF-8 for es"
      When call _country_to_locale "es"
      The output should equal "es_ES.UTF-8"
    End

    It "returns pt_BR.UTF-8 for br"
      When call _country_to_locale "br"
      The output should equal "pt_BR.UTF-8"
    End

    It "returns ja_JP.UTF-8 for jp"
      When call _country_to_locale "jp"
      The output should equal "ja_JP.UTF-8"
    End

    It "returns zh_CN.UTF-8 for cn"
      When call _country_to_locale "cn"
      The output should equal "zh_CN.UTF-8"
    End

    It "returns ko_KR.UTF-8 for kr"
      When call _country_to_locale "kr"
      The output should equal "ko_KR.UTF-8"
    End

    It "returns pl_PL.UTF-8 for pl"
      When call _country_to_locale "pl"
      The output should equal "pl_PL.UTF-8"
    End

    It "returns cs_CZ.UTF-8 for cz"
      When call _country_to_locale "cz"
      The output should equal "cs_CZ.UTF-8"
    End

    It "returns tr_TR.UTF-8 for tr"
      When call _country_to_locale "tr"
      The output should equal "tr_TR.UTF-8"
    End

    It "returns nl_NL.UTF-8 for nl"
      When call _country_to_locale "nl"
      The output should equal "nl_NL.UTF-8"
    End

    It "returns sv_SE.UTF-8 for se"
      When call _country_to_locale "se"
      The output should equal "sv_SE.UTF-8"
    End

    It "returns nb_NO.UTF-8 for no"
      When call _country_to_locale "no"
      The output should equal "nb_NO.UTF-8"
    End

    It "returns da_DK.UTF-8 for dk"
      When call _country_to_locale "dk"
      The output should equal "da_DK.UTF-8"
    End

    It "returns fi_FI.UTF-8 for fi"
      When call _country_to_locale "fi"
      The output should equal "fi_FI.UTF-8"
    End
  End

  # ===========================================================================
  # _update_locale_from_country()
  # ===========================================================================
  Describe "_update_locale_from_country()"
    BeforeEach 'reset_wizard_basic_mocks'

    It "sets LOCALE based on COUNTRY"
      COUNTRY="de"
      When call _update_locale_from_country
      The variable LOCALE should equal "de_DE.UTF-8"
    End

    It "sets LOCALE to uk_UA.UTF-8 for Ukraine"
      COUNTRY="ua"
      When call _update_locale_from_country
      The variable LOCALE should equal "uk_UA.UTF-8"
    End

    It "sets LOCALE to default when COUNTRY is empty"
      COUNTRY=""
      When call _update_locale_from_country
      The variable LOCALE should equal "en_US.UTF-8"
    End

    It "handles uppercase COUNTRY"
      COUNTRY="FR"
      When call _update_locale_from_country
      The variable LOCALE should equal "fr_FR.UTF-8"
    End
  End

  # ===========================================================================
  # _edit_hostname()
  # ===========================================================================
  Describe "_edit_hostname()"
    BeforeEach 'reset_wizard_basic_mocks'

    Describe "with valid hostname and domain"
      It "sets PVE_HOSTNAME, DOMAIN_SUFFIX and FQDN"
        MOCK_WIZ_INPUT_SEQUENCE=("myhost" "example.com")
        When call _edit_hostname
        The variable PVE_HOSTNAME should equal "myhost"
        The variable DOMAIN_SUFFIX should equal "example.com"
        The variable FQDN should equal "myhost.example.com"
      End
    End

    Describe "when hostname is cancelled"
      It "returns without changing values"
        MOCK_WIZ_INPUT_CANCELLED=true
        PVE_HOSTNAME="original"
        When call _edit_hostname
        The variable PVE_HOSTNAME should equal "original"
      End
    End

    Describe "when domain is cancelled"
      It "returns without changing domain"
        # First call returns hostname, second returns empty (cancel)
        MOCK_WIZ_INPUT_SEQUENCE=("myhost" "")
        DOMAIN_SUFFIX="original.com"
        When call _edit_hostname
        The variable PVE_HOSTNAME should equal "myhost"
        The variable DOMAIN_SUFFIX should equal "original.com"
      End
    End

    Describe "with invalid hostname"
      It "shows validation error for invalid hostname"
        # First call invalid, second empty to exit
        MOCK_WIZ_INPUT_SEQUENCE=("-invalid" "")
        When call _edit_hostname
        Assert mock_calls_include "show_validation_error"
      End

      It "shows validation error for localhost"
        MOCK_WIZ_INPUT_SEQUENCE=("localhost" "")
        When call _edit_hostname
        Assert mock_calls_include "show_validation_error"
      End
    End
  End

  # ===========================================================================
  # _edit_email()
  # ===========================================================================
  Describe "_edit_email()"
    BeforeEach 'reset_wizard_basic_mocks'

    It "sets EMAIL with valid input"
      MOCK_WIZ_INPUT_VALUE="admin@example.com"
      When call _edit_email
      The variable EMAIL should equal "admin@example.com"
    End

    It "returns without changes when cancelled"
      MOCK_WIZ_INPUT_CANCELLED=true
      EMAIL="original@test.com"
      When call _edit_email
      The variable EMAIL should equal "original@test.com"
    End

    Describe "with invalid email"
      It "shows validation error for invalid format"
        MOCK_WIZ_INPUT_SEQUENCE=("not-an-email" "")
        When call _edit_email
        Assert mock_calls_include "show_validation_error"
      End

      It "shows validation error for email without domain"
        MOCK_WIZ_INPUT_SEQUENCE=("test@" "")
        When call _edit_email
        Assert mock_calls_include "show_validation_error"
      End
    End

    Describe "with retry after invalid input"
      It "accepts valid email after invalid attempt"
        MOCK_WIZ_INPUT_SEQUENCE=("invalid" "valid@example.com")
        When call _edit_email
        The variable EMAIL should equal "valid@example.com"
      End
    End
  End

  # ===========================================================================
  # _edit_password()
  # ===========================================================================
  Describe "_edit_password()"
    BeforeEach 'reset_wizard_basic_mocks'

    Describe "generate password option"
      It "generates password when 'Generate password' selected"
        MOCK_WIZ_CHOOSE_VALUE="Generate password"
        When call _edit_password </dev/null
        The variable NEW_ROOT_PASSWORD should equal "generated_password_123"
        The variable PASSWORD_GENERATED should equal "yes"
        The output should include "Generated password"
      End
    End

    Describe "manual entry option"
      It "sets password when valid manual entry"
        MOCK_WIZ_CHOOSE_VALUE="Manual entry"
        MOCK_WIZ_INPUT_VALUE="ValidPass123!"
        When call _edit_password
        The variable NEW_ROOT_PASSWORD should equal "ValidPass123!"
        The variable PASSWORD_GENERATED should equal "no"
      End

      It "shows error for empty password and exits on cancel"
        # First choose Manual entry, then cancelled on retry
        MOCK_WIZ_CHOOSE_SEQUENCE=("Manual entry" "")
        MOCK_WIZ_INPUT_VALUE=""
        When call _edit_password
        The variable NEW_ROOT_PASSWORD should be blank
      End

      It "shows error for short password"
        # Manual entry twice, then cancel
        MOCK_WIZ_CHOOSE_SEQUENCE=("Manual entry" "Manual entry" "")
        # First short, then empty to continue loop
        MOCK_WIZ_INPUT_SEQUENCE=("short" "")
        When call _edit_password
        Assert mock_calls_include "show_validation_error"
      End
    End

    Describe "when cancelled"
      It "returns without changes when choose cancelled"
        MOCK_WIZ_CHOOSE_CANCELLED=true
        NEW_ROOT_PASSWORD="original"
        When call _edit_password
        The variable NEW_ROOT_PASSWORD should equal "original"
      End
    End
  End

  # ===========================================================================
  # _edit_timezone()
  # ===========================================================================
  Describe "_edit_timezone()"
    BeforeEach 'reset_wizard_basic_mocks'

    It "sets TIMEZONE when selected"
      MOCK_WIZ_FILTER_VALUE="America/New_York"
      When call _edit_timezone
      The variable TIMEZONE should equal "America/New_York"
    End

    It "updates COUNTRY when timezone has mapping"
      MOCK_WIZ_FILTER_VALUE="America/New_York"
      When call _edit_timezone
      The variable COUNTRY should equal "us"
    End

    It "updates LOCALE when timezone has mapping"
      MOCK_WIZ_FILTER_VALUE="Europe/Berlin"
      TZ_TO_COUNTRY["Europe/Berlin"]="de"
      When call _edit_timezone
      The variable LOCALE should equal "de_DE.UTF-8"
    End

    It "does not update COUNTRY when timezone has no mapping"
      MOCK_WIZ_FILTER_VALUE="UTC"
      COUNTRY="original"
      When call _edit_timezone
      The variable TIMEZONE should equal "UTC"
      The variable COUNTRY should equal "original"
    End

    It "returns without changes when cancelled"
      MOCK_WIZ_FILTER_CANCELLED=true
      TIMEZONE="original"
      When call _edit_timezone
      The variable TIMEZONE should equal "original"
    End
  End

  # ===========================================================================
  # _edit_keyboard()
  # ===========================================================================
  Describe "_edit_keyboard()"
    BeforeEach 'reset_wizard_basic_mocks'

    It "sets KEYBOARD when selected"
      MOCK_WIZ_FILTER_VALUE="de"
      When call _edit_keyboard
      The variable KEYBOARD should equal "de"
    End

    It "sets KEYBOARD to us layout"
      MOCK_WIZ_FILTER_VALUE="us"
      When call _edit_keyboard
      The variable KEYBOARD should equal "us"
    End

    It "returns without changes when cancelled"
      MOCK_WIZ_FILTER_CANCELLED=true
      KEYBOARD="original"
      When call _edit_keyboard
      The variable KEYBOARD should equal "original"
    End

    It "calls _wiz_start_edit before showing filter"
      MOCK_WIZ_FILTER_VALUE="us"
      When call _edit_keyboard
      Assert mock_calls_starts_with "_wiz_start_edit"
    End
  End

  # ===========================================================================
  # _edit_country()
  # ===========================================================================
  Describe "_edit_country()"
    BeforeEach 'reset_wizard_basic_mocks'

    It "sets COUNTRY when selected"
      MOCK_WIZ_FILTER_VALUE="de"
      When call _edit_country
      The variable COUNTRY should equal "de"
    End

    It "updates LOCALE when country selected"
      MOCK_WIZ_FILTER_VALUE="ua"
      When call _edit_country
      The variable COUNTRY should equal "ua"
      The variable LOCALE should equal "uk_UA.UTF-8"
    End

    It "sets LOCALE for US"
      MOCK_WIZ_FILTER_VALUE="us"
      When call _edit_country
      The variable LOCALE should equal "en_US.UTF-8"
    End

    It "returns without changes when cancelled"
      MOCK_WIZ_FILTER_CANCELLED=true
      COUNTRY="original"
      LOCALE="original_locale"
      When call _edit_country
      The variable COUNTRY should equal "original"
      The variable LOCALE should equal "original_locale"
    End

    It "calls _wiz_start_edit before showing filter"
      MOCK_WIZ_FILTER_VALUE="us"
      When call _edit_country
      Assert mock_calls_starts_with "_wiz_start_edit"
    End
  End

  # ===========================================================================
  # Edge cases and integration
  # ===========================================================================
  Describe "edge cases"
    BeforeEach 'reset_wizard_basic_mocks'

    Describe "_country_to_locale special regions"
      It "returns de_AT.UTF-8 for Austria"
        When call _country_to_locale "at"
        The output should equal "de_AT.UTF-8"
      End

      It "returns fr_BE.UTF-8 for Belgium"
        When call _country_to_locale "be"
        The output should equal "fr_BE.UTF-8"
      End

      It "returns zh_TW.UTF-8 for Taiwan"
        When call _country_to_locale "tw"
        The output should equal "zh_TW.UTF-8"
      End

      It "returns ar_EG.UTF-8 for Egypt"
        When call _country_to_locale "eg"
        The output should equal "ar_EG.UTF-8"
      End

      It "returns fa_IR.UTF-8 for Iran"
        When call _country_to_locale "ir"
        The output should equal "fa_IR.UTF-8"
      End

      It "returns it_IT.UTF-8 for Italy"
        When call _country_to_locale "it"
        The output should equal "it_IT.UTF-8"
      End

      It "returns sk_SK.UTF-8 for Slovakia"
        When call _country_to_locale "sk"
        The output should equal "sk_SK.UTF-8"
      End

      It "returns hu_HU.UTF-8 for Hungary"
        When call _country_to_locale "hu"
        The output should equal "hu_HU.UTF-8"
      End

      It "returns ro_RO.UTF-8 for Romania"
        When call _country_to_locale "ro"
        The output should equal "ro_RO.UTF-8"
      End

      It "returns bg_BG.UTF-8 for Bulgaria"
        When call _country_to_locale "bg"
        The output should equal "bg_BG.UTF-8"
      End

      It "returns hr_HR.UTF-8 for Croatia"
        When call _country_to_locale "hr"
        The output should equal "hr_HR.UTF-8"
      End

      It "returns sr_RS.UTF-8 for Serbia"
        When call _country_to_locale "rs"
        The output should equal "sr_RS.UTF-8"
      End

      It "returns sl_SI.UTF-8 for Slovenia"
        When call _country_to_locale "si"
        The output should equal "sl_SI.UTF-8"
      End

      It "returns et_EE.UTF-8 for Estonia"
        When call _country_to_locale "ee"
        The output should equal "et_EE.UTF-8"
      End

      It "returns lv_LV.UTF-8 for Latvia"
        When call _country_to_locale "lv"
        The output should equal "lv_LV.UTF-8"
      End

      It "returns lt_LT.UTF-8 for Lithuania"
        When call _country_to_locale "lt"
        The output should equal "lt_LT.UTF-8"
      End

      It "returns el_GR.UTF-8 for Greece"
        When call _country_to_locale "gr"
        The output should equal "el_GR.UTF-8"
      End

      It "returns he_IL.UTF-8 for Israel"
        When call _country_to_locale "il"
        The output should equal "he_IL.UTF-8"
      End

      It "returns hi_IN.UTF-8 for India"
        When call _country_to_locale "in"
        The output should equal "hi_IN.UTF-8"
      End

      It "returns th_TH.UTF-8 for Thailand"
        When call _country_to_locale "th"
        The output should equal "th_TH.UTF-8"
      End

      It "returns vi_VN.UTF-8 for Vietnam"
        When call _country_to_locale "vn"
        The output should equal "vi_VN.UTF-8"
      End

      It "returns id_ID.UTF-8 for Indonesia"
        When call _country_to_locale "id"
        The output should equal "id_ID.UTF-8"
      End

      It "returns ms_MY.UTF-8 for Malaysia"
        When call _country_to_locale "my"
        The output should equal "ms_MY.UTF-8"
      End

      It "returns en_PH.UTF-8 for Philippines"
        When call _country_to_locale "ph"
        The output should equal "en_PH.UTF-8"
      End

      It "returns en_SG.UTF-8 for Singapore"
        When call _country_to_locale "sg"
        The output should equal "en_SG.UTF-8"
      End

      It "returns en_ZA.UTF-8 for South Africa"
        When call _country_to_locale "za"
        The output should equal "en_ZA.UTF-8"
      End

      It "returns ar_SA.UTF-8 for Saudi Arabia"
        When call _country_to_locale "sa"
        The output should equal "ar_SA.UTF-8"
      End

      It "returns ar_AE.UTF-8 for UAE"
        When call _country_to_locale "ae"
        The output should equal "ar_AE.UTF-8"
      End
    End

    Describe "country/locale chain"
      It "updates both COUNTRY and LOCALE when timezone selected"
        MOCK_WIZ_FILTER_VALUE="Europe/London"
        TZ_TO_COUNTRY["Europe/London"]="gb"
        When call _edit_timezone
        The variable COUNTRY should equal "gb"
        The variable LOCALE should equal "en_GB.UTF-8"
      End
    End
  End
End

