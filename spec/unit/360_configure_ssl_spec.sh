# shellcheck shell=bash
# shellcheck disable=SC2034
# =============================================================================
# Tests for 360-configure-ssl.sh
# =============================================================================

%const SCRIPTS_DIR: "${SHELLSPEC_PROJECT_ROOT}/scripts"
%const SUPPORT_DIR: "${SHELLSPEC_PROJECT_ROOT}/spec/support"

# Load shared mocks
eval "$(cat "$SUPPORT_DIR/configure_mocks.sh")"

# Template directory for mock files
MOCK_TEMPLATE_DIR=""

setup_mock_templates() {
  MOCK_TEMPLATE_DIR=$(mktemp -d)
  mkdir -p "$MOCK_TEMPLATE_DIR/templates"
  echo "#!/bin/bash" > "$MOCK_TEMPLATE_DIR/templates/letsencrypt-firstboot.sh"
  echo "deploy hook" > "$MOCK_TEMPLATE_DIR/templates/letsencrypt-deploy-hook.sh"
  echo "[Unit]" > "$MOCK_TEMPLATE_DIR/templates/letsencrypt-firstboot.service"
  # Also create in working directory for relative path access
  mkdir -p ./templates 2>/dev/null || true
  echo "#!/bin/bash" > ./templates/letsencrypt-firstboot.sh
  echo "deploy hook" > ./templates/letsencrypt-deploy-hook.sh
  echo "[Unit]" > ./templates/letsencrypt-firstboot.service
}

cleanup_mock_templates() {
  rm -rf "$MOCK_TEMPLATE_DIR" 2>/dev/null || true
  rm -f ./templates/letsencrypt-firstboot.sh 2>/dev/null || true
  rm -f ./templates/letsencrypt-deploy-hook.sh 2>/dev/null || true
  rm -f ./templates/letsencrypt-firstboot.service 2>/dev/null || true
}

Describe "360-configure-ssl.sh"
  Include "$SCRIPTS_DIR/360-configure-ssl.sh"

  # ===========================================================================
  # _config_ssl()
  # ===========================================================================
  Describe "_config_ssl()"
    BeforeAll 'setup_mock_templates'
    AfterAll 'cleanup_mock_templates'
    BeforeEach 'MOCK_REMOTE_RUN_RESULT=0; MOCK_REMOTE_COPY_RESULT=0; MOCK_APPLY_TEMPLATE_VARS_RESULT=0; FQDN=""; PVE_HOSTNAME="testhost"; DOMAIN_SUFFIX="example.com"; EMAIL="admin@example.com"; LETSENCRYPT_DOMAIN=""; LETSENCRYPT_FIRSTBOOT=""'

    # -------------------------------------------------------------------------
    # Successful deployment
    # -------------------------------------------------------------------------
    Describe "successful deployment"
      It "configures SSL successfully"
        When call _config_ssl
        The status should be success
      End

      It "sets LETSENCRYPT_DOMAIN from PVE_HOSTNAME.DOMAIN_SUFFIX"
        PVE_HOSTNAME="myserver"
        DOMAIN_SUFFIX="mydomain.com"
        When call _config_ssl
        The status should be success
        The variable LETSENCRYPT_DOMAIN should equal "myserver.mydomain.com"
      End

      It "uses FQDN if set"
        FQDN="custom.host.org"
        When call _config_ssl
        The status should be success
        The variable LETSENCRYPT_DOMAIN should equal "custom.host.org"
      End

      It "sets LETSENCRYPT_FIRSTBOOT to true on success"
        When call _config_ssl
        The status should be success
        The variable LETSENCRYPT_FIRSTBOOT should equal true
      End
    End

    # -------------------------------------------------------------------------
    # Template staging
    # -------------------------------------------------------------------------
    Describe "template staging"
      It "stages template with correct domain"
        apply_template_args=""
        apply_template_vars() {
          apply_template_args="$*"
          return 0
        }
        PVE_HOSTNAME="myprox"
        DOMAIN_SUFFIX="local.net"
        When call _config_ssl
        The status should be success
        The variable apply_template_args should include "CERT_DOMAIN=myprox.local.net"
      End

      It "stages template with correct email"
        apply_template_args=""
        apply_template_vars() {
          apply_template_args="$*"
          return 0
        }
        EMAIL="ssl@test.com"
        When call _config_ssl
        The status should be success
        The variable apply_template_args should include "CERT_EMAIL=ssl@test.com"
      End

      It "uses FQDN in template when set"
        apply_template_args=""
        apply_template_vars() {
          apply_template_args="$*"
          return 0
        }
        FQDN="override.domain.org"
        When call _config_ssl
        The status should be success
        The variable apply_template_args should include "CERT_DOMAIN=override.domain.org"
      End
    End

    # -------------------------------------------------------------------------
    # Remote copy operations
    # -------------------------------------------------------------------------
    Describe "remote copy operations"
      It "copies deploy hook to correct path"
        copy_targets=""
        remote_copy() {
          copy_targets="$copy_targets $2"
          return 0
        }
        When call _config_ssl
        The status should be success
        The variable copy_targets should include "/tmp/letsencrypt-deploy-hook.sh"
      End

      It "copies firstboot script to correct path"
        copy_targets=""
        remote_copy() {
          copy_targets="$copy_targets $2"
          return 0
        }
        When call _config_ssl
        The status should be success
        The variable copy_targets should include "/tmp/letsencrypt-firstboot.sh"
      End

      It "copies service file to correct path"
        copy_targets=""
        remote_copy() {
          copy_targets="$copy_targets $2"
          return 0
        }
        When call _config_ssl
        The status should be success
        The variable copy_targets should include "/tmp/letsencrypt-firstboot.service"
      End
    End

    # -------------------------------------------------------------------------
    # Error handling - mktemp/staging failures
    # -------------------------------------------------------------------------
    Describe "temp file creation failure"
      It "fails when mktemp fails"
        mktemp() { return 1; }
        When call _config_ssl
        The status should be failure
      End

      It "logs error when mktemp fails"
        mktemp() { return 1; }
        log_message=""
        log() { log_message="$log_message $*"; }
        When call _config_ssl
        The status should be failure
        The variable log_message should include "ERROR"
      End
    End

    Describe "template staging failure"
      It "fails when cp fails to stage template"
        mktemp() { echo "/tmp/mock_staged"; }
        cp() { return 1; }
        When call _config_ssl
        The status should be failure
      End

      It "logs error when cp fails"
        mktemp() { echo "/tmp/mock_staged"; }
        cp() { return 1; }
        log_message=""
        log() { log_message="$log_message $*"; }
        When call _config_ssl
        The status should be failure
        The variable log_message should include "ERROR"
        The variable log_message should include "stage"
      End
    End

    # -------------------------------------------------------------------------
    # Error handling - apply_template_vars failure
    # -------------------------------------------------------------------------
    Describe "apply_template_vars failure"
      It "fails when apply_template_vars fails"
        MOCK_APPLY_TEMPLATE_VARS_RESULT=1
        When call _config_ssl
        The status should be failure
      End

      It "logs error when apply_template_vars fails"
        apply_template_vars() { return 1; }
        log_message=""
        log() { log_message="$log_message $*"; }
        When call _config_ssl
        The status should be failure
        The variable log_message should include "ERROR"
        The variable log_message should include "template variables"
      End

      It "does not call remote_copy when apply_template_vars fails"
        apply_template_vars() { return 1; }
        copy_called=false
        remote_copy() {
          copy_called=true
          return 0
        }
        When call _config_ssl
        The status should be failure
        The variable copy_called should equal false
      End

      It "does not set LETSENCRYPT_DOMAIN when apply_template_vars fails"
        LETSENCRYPT_DOMAIN="should_be_unset"
        apply_template_vars() { return 1; }
        When call _config_ssl
        The status should be failure
        The variable LETSENCRYPT_DOMAIN should equal "should_be_unset"
      End
    End

    # -------------------------------------------------------------------------
    # Error handling - remote_copy failures
    # -------------------------------------------------------------------------
    Describe "remote_copy failure for deploy hook"
      It "fails when deploy hook copy fails"
        remote_copy_call=0
        remote_copy() {
          remote_copy_call=$((remote_copy_call + 1))
          # First call is deploy hook
          if [[ $remote_copy_call -eq 1 ]]; then
            return 1
          fi
          return 0
        }
        When call _config_ssl
        The status should be failure
      End

      It "logs error when deploy hook copy fails"
        remote_copy() {
          if [[ $1 == *"deploy-hook"* ]]; then
            return 1
          fi
          return 0
        }
        log_message=""
        log() { log_message="$log_message $*"; }
        When call _config_ssl
        The status should be failure
        The variable log_message should include "ERROR"
        The variable log_message should include "letsencrypt-deploy-hook.sh"
      End
    End

    Describe "remote_copy failure for firstboot script"
      It "fails when firstboot script copy fails"
        remote_copy_call=0
        remote_copy() {
          remote_copy_call=$((remote_copy_call + 1))
          # Second call is firstboot script
          if [[ $remote_copy_call -eq 2 ]]; then
            return 1
          fi
          return 0
        }
        When call _config_ssl
        The status should be failure
      End

      It "logs error when firstboot script copy fails"
        remote_copy() {
          if [[ $1 == *"firstboot.sh"* || $2 == *"firstboot.sh"* ]]; then
            return 1
          fi
          return 0
        }
        log_message=""
        log() { log_message="$log_message $*"; }
        When call _config_ssl
        The status should be failure
        The variable log_message should include "ERROR"
        The variable log_message should include "letsencrypt-firstboot.sh"
      End
    End

    Describe "remote_copy failure for service file"
      It "fails when service file copy fails"
        remote_copy_call=0
        remote_copy() {
          remote_copy_call=$((remote_copy_call + 1))
          # Third call is service file
          if [[ $remote_copy_call -eq 3 ]]; then
            return 1
          fi
          return 0
        }
        When call _config_ssl
        The status should be failure
      End

      It "logs error when service file copy fails"
        remote_copy() {
          if [[ $1 == *"firstboot.service"* || $2 == *"firstboot.service"* ]]; then
            return 1
          fi
          return 0
        }
        log_message=""
        log() { log_message="$log_message $*"; }
        When call _config_ssl
        The status should be failure
        The variable log_message should include "ERROR"
        The variable log_message should include "letsencrypt-firstboot.service"
      End
    End

    # -------------------------------------------------------------------------
    # remote_run
    # -------------------------------------------------------------------------
    Describe "remote_run for systemd configuration"
      It "calls remote_run for template installation"
        run_description=""
        remote_run() {
          run_description="$1"
          return 0
        }
        When call _config_ssl
        The status should be success
        The variable run_description should include "Let's Encrypt"
      End

      It "still sets variables even if remote_run fails (no error check)"
        # Note: The script doesn't check remote_run exit status
        # This tests actual behavior - variables are set regardless
        remote_run() { return 1; }
        PVE_HOSTNAME="failtest"
        DOMAIN_SUFFIX="fail.com"
        When call _config_ssl
        The status should be success
        The variable LETSENCRYPT_DOMAIN should equal "failtest.fail.com"
        The variable LETSENCRYPT_FIRSTBOOT should equal true
      End
    End

    # -------------------------------------------------------------------------
    # Edge cases
    # -------------------------------------------------------------------------
    Describe "edge cases"
      It "handles empty EMAIL"
        EMAIL=""
        When call _config_ssl
        The status should be success
      End

      It "handles empty PVE_HOSTNAME with FQDN set"
        PVE_HOSTNAME=""
        FQDN="backup.domain.org"
        When call _config_ssl
        The status should be success
        The variable LETSENCRYPT_DOMAIN should equal "backup.domain.org"
      End

      It "handles empty DOMAIN_SUFFIX with FQDN set"
        DOMAIN_SUFFIX=""
        FQDN="explicit.fqdn.com"
        When call _config_ssl
        The status should be success
        The variable LETSENCRYPT_DOMAIN should equal "explicit.fqdn.com"
      End

      It "handles special characters in EMAIL"
        EMAIL="admin+ssl@sub.example.com"
        apply_template_args=""
        apply_template_vars() {
          apply_template_args="$*"
          return 0
        }
        When call _config_ssl
        The status should be success
        The variable apply_template_args should include "CERT_EMAIL=admin+ssl@sub.example.com"
      End
    End
  End

  # ===========================================================================
  # configure_ssl_certificate() - public wrapper
  # ===========================================================================
  Describe "configure_ssl_certificate()"
    BeforeAll 'setup_mock_templates'
    AfterAll 'cleanup_mock_templates'
    BeforeEach 'MOCK_REMOTE_RUN_RESULT=0; MOCK_REMOTE_COPY_RESULT=0; MOCK_APPLY_TEMPLATE_VARS_RESULT=0; SSL_TYPE=""; FQDN=""; PVE_HOSTNAME="testhost"; DOMAIN_SUFFIX="example.com"; EMAIL="admin@example.com"'

    # -------------------------------------------------------------------------
    # Skip conditions
    # -------------------------------------------------------------------------
    Describe "skip when not letsencrypt"
      It "skips when SSL_TYPE is self-signed"
        SSL_TYPE="self-signed"
        config_called=false
        _config_ssl() { config_called=true; return 0; }
        When call configure_ssl_certificate
        The status should be success
        The variable config_called should equal false
      End

      It "skips when SSL_TYPE is empty"
        SSL_TYPE=""
        config_called=false
        _config_ssl() { config_called=true; return 0; }
        When call configure_ssl_certificate
        The status should be success
        The variable config_called should equal false
      End

      It "skips when SSL_TYPE is unset"
        unset SSL_TYPE
        config_called=false
        _config_ssl() { config_called=true; return 0; }
        When call configure_ssl_certificate
        The status should be success
        The variable config_called should equal false
      End

      It "skips when SSL_TYPE is 'Letsencrypt' (case sensitive)"
        SSL_TYPE="Letsencrypt"
        config_called=false
        _config_ssl() { config_called=true; return 0; }
        When call configure_ssl_certificate
        The status should be success
        The variable config_called should equal false
      End

      It "skips when SSL_TYPE is some other value"
        SSL_TYPE="custom-ca"
        config_called=false
        _config_ssl() { config_called=true; return 0; }
        When call configure_ssl_certificate
        The status should be success
        The variable config_called should equal false
      End
    End

    # -------------------------------------------------------------------------
    # Active conditions
    # -------------------------------------------------------------------------
    Describe "configures when letsencrypt enabled"
      It "calls _config_ssl when SSL_TYPE is letsencrypt"
        SSL_TYPE="letsencrypt"
        config_called=false
        _config_ssl() { config_called=true; return 0; }
        When call configure_ssl_certificate
        The status should be success
        The variable config_called should equal true
      End

      It "configures SSL successfully when letsencrypt"
        SSL_TYPE="letsencrypt"
        When call configure_ssl_certificate
        The status should be success
      End

      It "logs skip message when not letsencrypt"
        SSL_TYPE="self-signed"
        log_message=""
        log() { log_message="$*"; }
        When call configure_ssl_certificate
        The status should be success
        The variable log_message should include "self-signed"
      End
    End

    # -------------------------------------------------------------------------
    # Error propagation
    # -------------------------------------------------------------------------
    Describe "error propagation"
      It "propagates failure from _config_ssl"
        SSL_TYPE="letsencrypt"
        _config_ssl() { return 1; }
        When call configure_ssl_certificate
        The status should be failure
      End

      It "returns success when _config_ssl returns 0"
        SSL_TYPE="letsencrypt"
        _config_ssl() { return 0; }
        When call configure_ssl_certificate
        The status should be success
      End

      It "propagates remote_copy failure through _config_ssl"
        SSL_TYPE="letsencrypt"
        MOCK_REMOTE_COPY_RESULT=1
        When call configure_ssl_certificate
        The status should be failure
      End

      It "propagates apply_template_vars failure through _config_ssl"
        SSL_TYPE="letsencrypt"
        MOCK_APPLY_TEMPLATE_VARS_RESULT=1
        When call configure_ssl_certificate
        The status should be failure
      End
    End
  End
End

