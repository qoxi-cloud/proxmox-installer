# shellcheck shell=bash
# shellcheck disable=SC2034
# =============================================================================
# Tests for 361-configure-api-token.sh
# =============================================================================

%const SCRIPTS_DIR: "${SHELLSPEC_PROJECT_ROOT}/scripts"
%const SUPPORT_DIR: "${SHELLSPEC_PROJECT_ROOT}/spec/support"

# Load shared mocks
eval "$(cat "$SUPPORT_DIR/configure_mocks.sh")"
eval "$(cat "$SUPPORT_DIR/json_mocks.sh")"

Describe "361-configure-api-token.sh"
  Include "$SCRIPTS_DIR/361-configure-api-token.sh"

  # ===========================================================================
  # create_api_token()
  # ===========================================================================
  Describe "create_api_token()"
    BeforeEach 'INSTALL_API_TOKEN="yes"; ADMIN_USERNAME="testadmin"; API_TOKEN_NAME="automation"; API_TOKEN_VALUE=""; API_TOKEN_ID=""'
    AfterEach 'rm -f /tmp/pve-install-api-token.env'

    # -------------------------------------------------------------------------
    # Feature flag check
    # -------------------------------------------------------------------------
    Describe "feature flag check"
      It "returns early when INSTALL_API_TOKEN is not 'yes'"
        INSTALL_API_TOKEN="no"
        remote_exec() { echo "should not be called"; return 1; }
        When call create_api_token
        The status should be success
      End

      It "returns early when INSTALL_API_TOKEN is empty"
        INSTALL_API_TOKEN=""
        remote_exec() { echo "should not be called"; return 1; }
        When call create_api_token
        The status should be success
      End

      It "proceeds when INSTALL_API_TOKEN is 'yes'"
        remote_exec() {
          if [[ $1 == *"token list"* ]]; then
            echo ""
            return 0
          fi
          if [[ $1 == *"token add"* ]]; then
            echo '{"value":"test-token-value"}'
            return 0
          fi
          return 0
        }
        When call create_api_token
        The status should be success
      End
    End

    # -------------------------------------------------------------------------
    # Logging
    # -------------------------------------------------------------------------
    Describe "logging"
      It "logs token creation start"
        log_message=""
        log() { log_message="$*"; }
        remote_exec() {
          if [[ $1 == *"token list"* ]]; then echo ""; return 0; fi
          if [[ $1 == *"token add"* ]]; then echo '{"value":"abc123"}'; return 0; fi
          return 0
        }
        When call create_api_token
        The status should be success
        The variable log_message should include "testadmin"
        The variable log_message should include "automation"
      End
    End

    # -------------------------------------------------------------------------
    # Token existence check
    # -------------------------------------------------------------------------
    Describe "token existence check"
      It "checks if token already exists"
        remote_exec() {
          if [[ $1 == *"token list"* ]]; then
            echo "list_checked" >&2
            echo ""
            return 0
          fi
          if [[ $1 == *"token add"* ]]; then echo '{"value":"abc123"}'; return 0; fi
          return 0
        }
        When call create_api_token
        The status should be success
        The stderr should include "list_checked"
      End

      It "removes existing token before creating new one"
        token_removed=false
        remote_exec() {
          if [[ $1 == *"token list"* ]]; then
            echo "exists"
            return 0
          fi
          if [[ $1 == *"token remove"* ]]; then
            token_removed=true
            return 0
          fi
          if [[ $1 == *"token add"* ]]; then echo '{"value":"abc123"}'; return 0; fi
          return 0
        }
        When call create_api_token
        The status should be success
        The variable token_removed should equal true
      End

      It "skips removal when token does not exist"
        token_removed=false
        remote_exec() {
          if [[ $1 == *"token list"* ]]; then
            echo ""
            return 0
          fi
          if [[ $1 == *"token remove"* ]]; then
            token_removed=true
            return 0
          fi
          if [[ $1 == *"token add"* ]]; then echo '{"value":"abc123"}'; return 0; fi
          return 0
        }
        When call create_api_token
        The status should be success
        The variable token_removed should equal false
      End

      It "fails when token removal fails"
        remote_exec() {
          if [[ $1 == *"token list"* ]]; then
            echo "exists"
            return 0
          fi
          if [[ $1 == *"token remove"* ]]; then
            return 1
          fi
          return 0
        }
        When call create_api_token
        The status should be failure
      End
    End

    # -------------------------------------------------------------------------
    # Token creation
    # -------------------------------------------------------------------------
    Describe "token creation"
      It "creates token with correct parameters"
        remote_exec() {
          if [[ $1 == *"token list"* ]]; then echo ""; return 0; fi
          if [[ $1 == *"token add"* ]]; then
            echo "CMD:$1" >&2
            echo '{"value":"test-token"}'
            return 0
          fi
          return 0
        }
        When call create_api_token
        The status should be success
        The stderr should include "testadmin@pam"
        The stderr should include "automation"
        The stderr should include "--privsep 0"
        The stderr should include "--expire 0"
        The stderr should include "--output-format json"
      End

      It "fails when pveum returns empty output"
        remote_exec() {
          if [[ $1 == *"token list"* ]]; then echo ""; return 0; fi
          if [[ $1 == *"token add"* ]]; then
            echo ""
            return 0
          fi
          return 0
        }
        When call create_api_token
        The status should be failure
      End
    End

    # -------------------------------------------------------------------------
    # Output filtering
    # -------------------------------------------------------------------------
    Describe "output filtering"
      It "filters perl locale warnings from output"
        remote_exec() {
          if [[ $1 == *"token list"* ]]; then echo ""; return 0; fi
          if [[ $1 == *"token add"* ]]; then
            printf 'perl: warning: Setting locale failed.\nperl: warning: Falling back to "C".\n{"value":"filtered-token"}\n'
            return 0
          fi
          return 0
        }
        When call create_api_token
        The status should be success
        The variable API_TOKEN_VALUE should equal "filtered-token"
      End

      It "filters generic warnings from output"
        remote_exec() {
          if [[ $1 == *"token list"* ]]; then echo ""; return 0; fi
          if [[ $1 == *"token add"* ]]; then
            printf 'warning: some warning message\n{"value":"clean-token"}\n'
            return 0
          fi
          return 0
        }
        When call create_api_token
        The status should be success
        The variable API_TOKEN_VALUE should equal "clean-token"
      End
    End

    # -------------------------------------------------------------------------
    # JSON parsing
    # -------------------------------------------------------------------------
    Describe "JSON parsing"
      It "parses valid JSON output"
        remote_exec() {
          if [[ $1 == *"token list"* ]]; then echo ""; return 0; fi
          if [[ $1 == *"token add"* ]]; then
            echo '{"value":"parsed-token-value"}'
            return 0
          fi
          return 0
        }
        When call create_api_token
        The status should be success
        The variable API_TOKEN_VALUE should equal "parsed-token-value"
      End

      It "fails when JSON has no value field"
        remote_exec() {
          if [[ $1 == *"token list"* ]]; then echo ""; return 0; fi
          if [[ $1 == *"token add"* ]]; then
            echo '{"error":"no token"}'
            return 0
          fi
          return 0
        }
        When call create_api_token
        The status should be failure
      End

      It "fails when output is invalid JSON"
        remote_exec() {
          if [[ $1 == *"token list"* ]]; then echo ""; return 0; fi
          if [[ $1 == *"token add"* ]]; then
            echo 'not valid json at all'
            return 0
          fi
          return 0
        }
        When call create_api_token
        The status should be failure
      End

      It "handles complex token values"
        remote_exec() {
          if [[ $1 == *"token list"* ]]; then echo ""; return 0; fi
          if [[ $1 == *"token add"* ]]; then
            echo '{"value":"abc123def456ghi789jkl"}'
            return 0
          fi
          return 0
        }
        When call create_api_token
        The status should be success
        The variable API_TOKEN_VALUE should equal "abc123def456ghi789jkl"
      End
    End

    # -------------------------------------------------------------------------
    # Global variable setting
    # -------------------------------------------------------------------------
    Describe "global variable setting"
      It "sets API_TOKEN_VALUE from parsed output"
        remote_exec() {
          if [[ $1 == *"token list"* ]]; then echo ""; return 0; fi
          if [[ $1 == *"token add"* ]]; then
            echo '{"value":"my-token-value"}'
            return 0
          fi
          return 0
        }
        When call create_api_token
        The status should be success
        The variable API_TOKEN_VALUE should equal "my-token-value"
      End

      It "sets API_TOKEN_ID correctly"
        remote_exec() {
          if [[ $1 == *"token list"* ]]; then echo ""; return 0; fi
          if [[ $1 == *"token add"* ]]; then
            echo '{"value":"secret-value"}'
            return 0
          fi
          return 0
        }
        When call create_api_token
        The status should be success
        The variable API_TOKEN_ID should equal "testadmin@pam!automation"
      End

      It "uses ADMIN_USERNAME in token ID"
        ADMIN_USERNAME="customuser"
        remote_exec() {
          if [[ $1 == *"token list"* ]]; then echo ""; return 0; fi
          if [[ $1 == *"token add"* ]]; then
            echo '{"value":"token123"}'
            return 0
          fi
          return 0
        }
        When call create_api_token
        The status should be success
        The variable API_TOKEN_ID should equal "customuser@pam!automation"
      End

      It "uses API_TOKEN_NAME in token ID"
        API_TOKEN_NAME="mytoken"
        remote_exec() {
          if [[ $1 == *"token list"* ]]; then echo ""; return 0; fi
          if [[ $1 == *"token add"* ]]; then
            echo '{"value":"token456"}'
            return 0
          fi
          return 0
        }
        When call create_api_token
        The status should be success
        The variable API_TOKEN_ID should equal "testadmin@pam!mytoken"
      End
    End

    # -------------------------------------------------------------------------
    # Temp file creation
    # -------------------------------------------------------------------------
    Describe "temp file creation"
      It "creates temp file with token info"
        remote_exec() {
          if [[ $1 == *"token list"* ]]; then echo ""; return 0; fi
          if [[ $1 == *"token add"* ]]; then
            echo '{"value":"temp-file-token"}'
            return 0
          fi
          return 0
        }
        When call create_api_token
        The status should be success
        The file "/tmp/pve-install-api-token.env" should be exist
      End

      It "writes correct token value to temp file"
        remote_exec() {
          if [[ $1 == *"token list"* ]]; then echo ""; return 0; fi
          if [[ $1 == *"token add"* ]]; then
            echo '{"value":"file-token-value"}'
            return 0
          fi
          return 0
        }
        When call create_api_token
        The status should be success
        The contents of file "/tmp/pve-install-api-token.env" should include "API_TOKEN_VALUE=file-token-value"
      End

      It "writes correct token ID to temp file"
        remote_exec() {
          if [[ $1 == *"token list"* ]]; then echo ""; return 0; fi
          if [[ $1 == *"token add"* ]]; then
            echo '{"value":"id-token"}'
            return 0
          fi
          return 0
        }
        When call create_api_token
        The status should be success
        The contents of file "/tmp/pve-install-api-token.env" should include "API_TOKEN_ID=testadmin@pam!automation"
      End

      It "writes API_TOKEN_NAME to temp file"
        remote_exec() {
          if [[ $1 == *"token list"* ]]; then echo ""; return 0; fi
          if [[ $1 == *"token add"* ]]; then
            echo '{"value":"name-token"}'
            return 0
          fi
          return 0
        }
        When call create_api_token
        The status should be success
        The contents of file "/tmp/pve-install-api-token.env" should include "API_TOKEN_NAME=automation"
      End
    End

    # -------------------------------------------------------------------------
    # Return values
    # -------------------------------------------------------------------------
    Describe "return values"
      It "returns 0 on success"
        remote_exec() {
          if [[ $1 == *"token list"* ]]; then echo ""; return 0; fi
          if [[ $1 == *"token add"* ]]; then
            echo '{"value":"success-token"}'
            return 0
          fi
          return 0
        }
        When call create_api_token
        The status should be success
      End

      It "returns 1 when token value extraction fails"
        remote_exec() {
          if [[ $1 == *"token list"* ]]; then echo ""; return 0; fi
          if [[ $1 == *"token add"* ]]; then
            echo '{"other":"field"}'
            return 0
          fi
          return 0
        }
        When call create_api_token
        The status should be failure
      End
    End

    # -------------------------------------------------------------------------
    # Error logging
    # -------------------------------------------------------------------------
    Describe "error logging"
      It "logs error when token removal fails"
        error_logged=false
        log() { [[ $* == *"ERROR"* ]] && error_logged=true; }
        remote_exec() {
          if [[ $1 == *"token list"* ]]; then echo "exists"; return 0; fi
          if [[ $1 == *"token remove"* ]]; then return 1; fi
          return 0
        }
        When call create_api_token
        The status should be failure
        The variable error_logged should equal true
      End

      It "logs error when output is empty"
        error_logged=false
        log() { [[ $* == *"ERROR"* ]] && error_logged=true; }
        remote_exec() {
          if [[ $1 == *"token list"* ]]; then echo ""; return 0; fi
          if [[ $1 == *"token add"* ]]; then echo ""; return 0; fi
          return 0
        }
        When call create_api_token
        The status should be failure
        The variable error_logged should equal true
      End

      It "logs error when token value extraction fails"
        error_logged=false
        log() { [[ $* == *"ERROR"* ]] && error_logged=true; }
        remote_exec() {
          if [[ $1 == *"token list"* ]]; then echo ""; return 0; fi
          if [[ $1 == *"token add"* ]]; then echo '{"no":"value"}'; return 0; fi
          return 0
        }
        When call create_api_token
        The status should be failure
        The variable error_logged should equal true
      End

      It "logs debug output when extraction fails"
        debug_logged=false
        log() { [[ $* == *"DEBUG"* ]] && debug_logged=true; }
        remote_exec() {
          if [[ $1 == *"token list"* ]]; then echo ""; return 0; fi
          if [[ $1 == *"token add"* ]]; then echo '{"wrong":"output"}'; return 0; fi
          return 0
        }
        When call create_api_token
        The status should be failure
        The variable debug_logged should equal true
      End

      It "logs success message on completion"
        success_logged=false
        log() { [[ $* == *"INFO"* && $* == *"successfully"* ]] && success_logged=true; }
        remote_exec() {
          if [[ $1 == *"token list"* ]]; then echo ""; return 0; fi
          if [[ $1 == *"token add"* ]]; then echo '{"value":"log-token"}'; return 0; fi
          return 0
        }
        When call create_api_token
        The status should be success
        The variable success_logged should equal true
      End

      It "logs warning when removing existing token"
        warning_logged=false
        log() { [[ $* == *"WARNING"* ]] && warning_logged=true; }
        remote_exec() {
          if [[ $1 == *"token list"* ]]; then echo "exists"; return 0; fi
          if [[ $1 == *"token remove"* ]]; then return 0; fi
          if [[ $1 == *"token add"* ]]; then echo '{"value":"new-token"}'; return 0; fi
          return 0
        }
        When call create_api_token
        The status should be success
        The variable warning_logged should equal true
      End
    End

    # -------------------------------------------------------------------------
    # Edge cases
    # -------------------------------------------------------------------------
    Describe "edge cases"
      It "handles token name with special characters"
        API_TOKEN_NAME="my-api-token"
        remote_exec() {
          if [[ $1 == *"token list"* ]]; then echo ""; return 0; fi
          if [[ $1 == *"token add"* ]]; then
            echo '{"value":"special-token"}'
            return 0
          fi
          return 0
        }
        When call create_api_token
        The status should be success
        The variable API_TOKEN_ID should equal "testadmin@pam!my-api-token"
      End

      It "handles username with special characters"
        ADMIN_USERNAME="test-admin"
        remote_exec() {
          if [[ $1 == *"token list"* ]]; then echo ""; return 0; fi
          if [[ $1 == *"token add"* ]]; then
            echo '{"value":"user-token"}'
            return 0
          fi
          return 0
        }
        When call create_api_token
        The status should be success
        The variable API_TOKEN_ID should equal "test-admin@pam!automation"
      End

      It "handles JSON with extra whitespace"
        remote_exec() {
          if [[ $1 == *"token list"* ]]; then echo ""; return 0; fi
          if [[ $1 == *"token add"* ]]; then
            echo '  { "value" : "whitespace-token" }  '
            return 0
          fi
          return 0
        }
        When call create_api_token
        The status should be success
        The variable API_TOKEN_VALUE should equal "whitespace-token"
      End

      It "handles multiline pveum output with JSON at end"
        remote_exec() {
          if [[ $1 == *"token list"* ]]; then echo ""; return 0; fi
          if [[ $1 == *"token add"* ]]; then
            printf 'some debug info\nmore info\n{"value":"multiline-token"}\n'
            return 0
          fi
          return 0
        }
        When call create_api_token
        The status should be success
        The variable API_TOKEN_VALUE should equal "multiline-token"
      End
    End
  End
End

