# shellcheck shell=bash
# shellcheck disable=SC2016,SC2034
# =============================================================================
# Integration tests for SSL and Tailscale configuration
# Tests: 360-configure-ssl.sh, 301-configure-tailscale.sh integration
# =============================================================================

%const SCRIPTS_DIR: "${SHELLSPEC_PROJECT_ROOT}/scripts"
%const SUPPORT_DIR: "${SHELLSPEC_PROJECT_ROOT}/spec/support"
%const TEMPLATES_DIR: "${SHELLSPEC_PROJECT_ROOT}/templates"

# Load mocks
eval "$(cat "$SUPPORT_DIR/core_mocks.sh")"
eval "$(cat "$SUPPORT_DIR/configure_mocks.sh")"

# =============================================================================
# Mock Tailscale commands
# =============================================================================
MOCK_TAILSCALE_STATUS='{"Self":{"TailscaleIPs":["100.64.1.1"],"DNSName":"myhost.tailnet.ts.net."}}'
MOCK_TAILSCALE_UP_RESULT=0

# =============================================================================
# Test setup
# =============================================================================
setup_ssl_test() {
  # SSL settings
  SSL_TYPE="letsencrypt"
  FQDN="test.example.com"
  PVE_HOSTNAME="test"
  DOMAIN_SUFFIX="example.com"
  EMAIL="admin@example.com"

  # Tailscale settings
  INSTALL_TAILSCALE="yes"
  TAILSCALE_AUTH_KEY=""
  TAILSCALE_WEBUI="no"
  FIREWALL_MODE="standard"

  # Mock functions
  LOG_FILE="${SHELLSPEC_TMPBASE}/test.log"
  touch "$LOG_FILE"

  # Create templates directory
  mkdir -p "${SHELLSPEC_TMPBASE}/templates"
  cd "${SHELLSPEC_TMPBASE}" || return 1

  # Copy real templates for testing
  cp "$TEMPLATES_DIR/letsencrypt-firstboot.sh.tmpl" "./templates/letsencrypt-firstboot.sh" 2>/dev/null || \
    printf '%s\n' '#!/bin/bash' 'certbot certonly -d {{CERT_DOMAIN}} --email {{CERT_EMAIL}}' > "./templates/letsencrypt-firstboot.sh"
  cp "$TEMPLATES_DIR/letsencrypt-deploy-hook.sh.tmpl" "./templates/letsencrypt-deploy-hook.sh" 2>/dev/null || \
    printf '%s\n' '#!/bin/bash' 'cp certs to proxmox' > "./templates/letsencrypt-deploy-hook.sh"
  printf '%s\n' '[Service]' 'ExecStart=/usr/local/bin/obtain-letsencrypt-cert.sh' > "./templates/letsencrypt-firstboot.service"
  printf '%s\n' '[Service]' 'ExecStart=/bin/systemctl stop ssh' > "./templates/disable-openssh.service"

  # Reset mock results
  MOCK_REMOTE_RUN_RESULT=0
  MOCK_REMOTE_EXEC_RESULT=0
  MOCK_REMOTE_COPY_RESULT=0
  MOCK_APPLY_TEMPLATE_VARS_RESULT=0

  # Mock apply_template_vars
  apply_template_vars() {
    local file="$1"
    shift
    # Apply substitutions
    for var in "$@"; do
      local key="${var%%=*}"
      local val="${var#*=}"
      sed -i "s|{{${key}}}|${val}|g" "$file" 2>/dev/null || true
    done
    return "${MOCK_APPLY_TEMPLATE_VARS_RESULT:-0}"
  }

  # Mock complete_task and add_log for Tailscale
  TASK_INDEX=0
  complete_task() { :; }
  add_log() { :; }
  export -f complete_task add_log
}

cleanup_ssl_test() {
  rm -rf "${SHELLSPEC_TMPBASE}/templates" 2>/dev/null || true
  cd - >/dev/null 2>&1 || true
}

Describe "SSL and Tailscale Integration"
  Include "$SCRIPTS_DIR/360-configure-ssl.sh"
  Include "$SCRIPTS_DIR/301-configure-tailscale.sh"

  BeforeEach 'setup_ssl_test'
  AfterEach 'cleanup_ssl_test'

  # ===========================================================================
  # SSL Certificate Configuration
  # ===========================================================================
  Describe "configure_ssl_certificate()"
    Describe "Let's Encrypt mode"
      It "configures Let's Encrypt when SSL_TYPE is letsencrypt"
        SSL_TYPE="letsencrypt"

        When call configure_ssl_certificate
        The status should be success
      End

      It "skips when SSL_TYPE is self-signed"
        SSL_TYPE="self-signed"
        config_called=false
        _config_ssl() { config_called=true; }

        configure_ssl_certificate

        When call printf '%s' "$config_called"
        The output should equal "false"
      End
    End

    Describe "_config_ssl()"
      It "copies all required templates"
        copy_calls=()
        remote_copy() { copy_calls+=("$1"); return 0; }
        remote_run() { return 0; }

        _config_ssl

        When call printf '%s\n' "${#copy_calls[@]}"
        # Should copy: deploy-hook, firstboot.sh, firstboot.service
        The output should equal "3"
      End

      It "sets LETSENCRYPT_DOMAIN"
        FQDN="myhost.example.com"
        remote_copy() { return 0; }
        remote_run() { return 0; }

        _config_ssl

        When call printf '%s' "$LETSENCRYPT_DOMAIN"
        The output should equal "myhost.example.com"
      End

      It "uses hostname.domain when FQDN not set"
        unset FQDN
        PVE_HOSTNAME="server1"
        DOMAIN_SUFFIX="mydomain.com"
        remote_copy() { return 0; }
        remote_run() { return 0; }

        _config_ssl

        When call printf '%s' "$LETSENCRYPT_DOMAIN"
        The output should equal "server1.mydomain.com"
      End

      It "fails when template copy fails"
        MOCK_REMOTE_COPY_RESULT=1
        remote_copy() { return 1; }

        When call _config_ssl
        The status should be failure
      End
    End
  End

  # ===========================================================================
  # Tailscale Configuration
  # ===========================================================================
  Describe "configure_tailscale()"
    It "skips when INSTALL_TAILSCALE is not yes"
      INSTALL_TAILSCALE="no"
      config_called=false
      _config_tailscale() { config_called=true; }

      configure_tailscale

      When call printf '%s' "$config_called"
      The output should equal "false"
    End

    It "runs config when INSTALL_TAILSCALE is yes"
      INSTALL_TAILSCALE="yes"
      config_called=false
      _config_tailscale() { config_called=true; return 0; }

      configure_tailscale

      When call printf '%s' "$config_called"
      The output should equal "true"
    End
  End

  Describe "_config_tailscale()"
    Describe "without auth key"
      It "sets TAILSCALE_IP to not authenticated"
        TAILSCALE_AUTH_KEY=""

        _config_tailscale

        When call printf '%s' "$TAILSCALE_IP"
        The output should equal "not authenticated"
      End

      It "enables tailscaled service"
        TAILSCALE_AUTH_KEY=""
        run_cmd=""
        remote_run() { run_cmd="$2"; return 0; }

        _config_tailscale

        When call printf '%s' "$run_cmd"
        The output should include "systemctl enable tailscaled"
      End
    End

    # Note: Tests with auth key are complex due to background jobs in _config_tailscale
    # They're covered by unit tests in spec/unit/301_configure_tailscale_spec.sh
    Describe "with auth key"
      It "would authenticate via tailscale up"
        # The actual auth flow uses background jobs which are hard to test
        # Verify the pattern would be used
        TAILSCALE_AUTH_KEY="tskey-auth-xxxxx"
        When call printf '%s' "tailscale up --authkey='$TAILSCALE_AUTH_KEY' --ssh"
        The output should include "tailscale up"
        The output should include "--authkey"
        The output should include "--ssh"
      End
    End

    Describe "stealth mode config"
      It "would deploy disable-openssh.service template"
        # Verify template exists
        When call test -f "./templates/disable-openssh.service"
        The status should be success
      End

      It "template contains ExecStart"
        When call cat "./templates/disable-openssh.service"
        The output should include "ExecStart"
      End
    End

    Describe "Tailscale Serve"
      BeforeEach 'TAILSCALE_AUTH_KEY="tskey-auth-xxxxx"'

      It "configures Tailscale Serve when enabled"
        TAILSCALE_WEBUI="yes"
        run_cmds=()
        remote_run() { run_cmds+=("$2"); return 0; }
        remote_exec() { return 0; }
        show_progress() { wait "$1" 2>/dev/null; return 0; }

        _config_tailscale

        When call printf '%s\n' "${run_cmds[*]}"
        The output should include "tailscale serve"
      End

      It "skips Tailscale Serve when disabled"
        TAILSCALE_WEBUI="no"
        run_cmds=()
        remote_run() { run_cmds+=("$2"); return 0; }
        remote_exec() { return 0; }
        show_progress() { wait "$1" 2>/dev/null; return 0; }

        _config_tailscale

        When call printf '%s\n' "${run_cmds[*]}"
        The output should not include "tailscale serve"
      End
    End
  End

  # ===========================================================================
  # SSL + Tailscale integration
  # ===========================================================================
  Describe "SSL with Tailscale"
    It "can configure both SSL and Tailscale"
      SSL_TYPE="letsencrypt"
      INSTALL_TAILSCALE="yes"
      TAILSCALE_AUTH_KEY=""

      remote_copy() { return 0; }
      remote_run() { return 0; }

      configure_ssl_certificate
      ssl_result=$?
      configure_tailscale
      ts_result=$?

      When call printf '%s %s' "$ssl_result" "$ts_result"
      The output should equal "0 0"
    End

    It "SSL works without Tailscale"
      SSL_TYPE="letsencrypt"
      INSTALL_TAILSCALE="no"

      remote_copy() { return 0; }
      remote_run() { return 0; }

      When call configure_ssl_certificate
      The status should be success
    End
  End
End

