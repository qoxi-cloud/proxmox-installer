# shellcheck shell=bash
# shellcheck disable=SC2016,SC2034
# =============================================================================
# Integration tests for template pipeline
# Tests: 020-templates.sh using real project templates
# =============================================================================

%const SCRIPTS_DIR: "${SHELLSPEC_PROJECT_ROOT}/scripts"
%const SUPPORT_DIR: "${SHELLSPEC_PROJECT_ROOT}/spec/support"
%const TEMPLATES_DIR: "${SHELLSPEC_PROJECT_ROOT}/templates"

# Load core mocks
eval "$(cat "$SUPPORT_DIR/core_mocks.sh")"

# =============================================================================
# Test setup
# =============================================================================
setup_template_test_vars() {
  MAIN_IPV4="192.168.1.100"
  MAIN_IPV4_GW="192.168.1.1"
  MAIN_IPV6="2001:db8::1"
  FIRST_IPV6_CIDR="2001:db8::/64"
  IPV6_GATEWAY="fe80::1"
  FQDN="test.example.com"
  PVE_HOSTNAME="test"
  INTERFACE_NAME="eth0"
  PRIVATE_IP_CIDR="10.0.0.1/24"
  PRIVATE_SUBNET="10.0.0.0/24"
  BRIDGE_MTU="9000"
  DNS_PRIMARY="1.1.1.1"
  DNS_SECONDARY="1.0.0.1"
  DNS6_PRIMARY="2606:4700:4700::1111"
  DNS6_SECONDARY="2606:4700:4700::1001"
  LOCALE="en_US.UTF-8"
  KEYBOARD="us"
  COUNTRY="US"
  BAT_THEME="Catppuccin Mocha"
  PORT_SSH="22"
  PORT_PROXMOX_UI="8006"
}

cleanup_template_test() {
  rm -rf "${SHELLSPEC_TMPBASE:-/tmp}/templates" 2>/dev/null || true
}

Describe "Template Pipeline Integration"
  Include "$SCRIPTS_DIR/020-templates.sh"

  BeforeAll 'setup_template_test_vars'
  AfterEach 'cleanup_template_test'

  # ===========================================================================
  # Real template substitution tests
  # ===========================================================================
  Describe "apply_common_template_vars() with real templates"
    Describe "hosts.tmpl"
      It "substitutes all variables in hosts template"
        tmpdir="${SHELLSPEC_TMPBASE}/templates"
        mkdir -p "$tmpdir"
        cp "$TEMPLATES_DIR/hosts.tmpl" "$tmpdir/hosts"

        When call apply_common_template_vars "$tmpdir/hosts"
        The status should be success
        The contents of file "$tmpdir/hosts" should include "192.168.1.100"
        The contents of file "$tmpdir/hosts" should include "test.example.com"
        The contents of file "$tmpdir/hosts" should include "2001:db8::1"
      End
    End

    Describe "resolv.conf.tmpl"
      It "substitutes DNS settings"
        tmpdir="${SHELLSPEC_TMPBASE}/templates"
        mkdir -p "$tmpdir"
        cp "$TEMPLATES_DIR/resolv.conf.tmpl" "$tmpdir/resolv.conf"

        When call apply_common_template_vars "$tmpdir/resolv.conf"
        The status should be success
        The contents of file "$tmpdir/resolv.conf" should include "nameserver 1.1.1.1"
        The contents of file "$tmpdir/resolv.conf" should include "nameserver 1.0.0.1"
        The contents of file "$tmpdir/resolv.conf" should include "2606:4700:4700::1111"
      End
    End

    Describe "sshd_config.tmpl"
      It "substitutes ADMIN_USERNAME in sshd_config"
        tmpdir="${SHELLSPEC_TMPBASE}/templates"
        mkdir -p "$tmpdir"
        cp "$TEMPLATES_DIR/sshd_config.tmpl" "$tmpdir/sshd_config"
        ADMIN_USERNAME="testadmin"

        When call apply_template_vars "$tmpdir/sshd_config" "ADMIN_USERNAME=$ADMIN_USERNAME"
        The status should be success
        The contents of file "$tmpdir/sshd_config" should include "AllowUsers testadmin"
      End
    End

    Describe "locale templates"
      It "substitutes locale in environment template"
        tmpdir="${SHELLSPEC_TMPBASE}/templates"
        mkdir -p "$tmpdir"
        cp "$TEMPLATES_DIR/environment.tmpl" "$tmpdir/environment"

        When call apply_common_template_vars "$tmpdir/environment"
        The status should be success
        The contents of file "$tmpdir/environment" should include "en_US.UTF-8"
      End

      It "substitutes locale in default-locale template"
        tmpdir="${SHELLSPEC_TMPBASE}/templates"
        mkdir -p "$tmpdir"
        cp "$TEMPLATES_DIR/default-locale.tmpl" "$tmpdir/default-locale"

        When call apply_common_template_vars "$tmpdir/default-locale"
        The status should be success
        The contents of file "$tmpdir/default-locale" should include "en_US.UTF-8"
      End
    End
  End

  # ===========================================================================
  # apply_template_vars() with real templates
  # ===========================================================================
  Describe "apply_template_vars() with specific variables"
    Describe "cpupower.service.tmpl"
      It "substitutes CPU_GOVERNOR variable"
        tmpdir="${SHELLSPEC_TMPBASE}/templates"
        mkdir -p "$tmpdir"
        cp "$TEMPLATES_DIR/cpupower.service.tmpl" "$tmpdir/cpupower.service"

        When call apply_template_vars "$tmpdir/cpupower.service" "CPU_GOVERNOR=performance"
        The status should be success
        The contents of file "$tmpdir/cpupower.service" should include "performance"
      End
    End

    Describe "promtail.yml.tmpl"
      It "substitutes HOSTNAME"
        tmpdir="${SHELLSPEC_TMPBASE}/templates"
        mkdir -p "$tmpdir"
        cp "$TEMPLATES_DIR/promtail.yml.tmpl" "$tmpdir/promtail.yml"

        When call apply_template_vars "$tmpdir/promtail.yml" "HOSTNAME=proxmox"
        The status should be success
        The contents of file "$tmpdir/promtail.yml" should include "proxmox"
      End
    End

    Describe "vnstat.conf.tmpl"
      It "substitutes INTERFACE_NAME"
        tmpdir="${SHELLSPEC_TMPBASE}/templates"
        mkdir -p "$tmpdir"
        cp "$TEMPLATES_DIR/vnstat.conf.tmpl" "$tmpdir/vnstat.conf"

        When call apply_template_vars "$tmpdir/vnstat.conf" "INTERFACE_NAME=enp0s3"
        The status should be success
        The contents of file "$tmpdir/vnstat.conf" should include "enp0s3"
      End
    End
  End

  # ===========================================================================
  # Batch processing (simulates _modify_template_files)
  # ===========================================================================
  Describe "batch template processing"
    It "processes multiple templates without cross-contamination"
      tmpdir="${SHELLSPEC_TMPBASE}/templates"
      mkdir -p "$tmpdir"

      cp "$TEMPLATES_DIR/hosts.tmpl" "$tmpdir/hosts"
      cp "$TEMPLATES_DIR/resolv.conf.tmpl" "$tmpdir/resolv.conf"

      apply_common_template_vars "$tmpdir/hosts"
      first_status=$?

      apply_common_template_vars "$tmpdir/resolv.conf"
      second_status=$?

      When call printf '%s %s' "$first_status" "$second_status"
      The output should equal "0 0"

      # Verify both files are correctly processed
      The contents of file "$tmpdir/hosts" should include "192.168.1.100"
      The contents of file "$tmpdir/resolv.conf" should include "nameserver 1.1.1.1"
    End
  End

  # ===========================================================================
  # Error handling
  # ===========================================================================
  Describe "error handling"
    It "fails gracefully with missing template file"
      When call apply_template_vars "/nonexistent/path/template" "VAR=value"
      The status should be failure
    End

    It "fails when required variables are missing"
      tmpdir="${SHELLSPEC_TMPBASE}/templates"
      mkdir -p "$tmpdir"
      # Create a template with unknown variable
      echo "{{UNKNOWN_VAR}}" >"$tmpdir/incomplete"

      When call apply_template_vars "$tmpdir/incomplete"
      The status should be failure
    End

    It "handles templates with special regex characters in content"
      tmpdir="${SHELLSPEC_TMPBASE}/templates"
      mkdir -p "$tmpdir"
      # Content with regex special chars that shouldn't be interpreted
      echo 'nftables rule: ip saddr {{MAIN_IPV4}}/32 accept' >"$tmpdir/nftables"

      When call apply_template_vars "$tmpdir/nftables" "MAIN_IPV4=10.0.0.1"
      The status should be success
      The contents of file "$tmpdir/nftables" should equal "nftables rule: ip saddr 10.0.0.1/32 accept"
    End
  End

  # ===========================================================================
  # Systemd templates
  # ===========================================================================
  Describe "systemd templates"
    It "processes aide-check.service correctly"
      tmpdir="${SHELLSPEC_TMPBASE}/templates"
      mkdir -p "$tmpdir"
      cp "$TEMPLATES_DIR/aide-check.service.tmpl" "$tmpdir/aide-check.service"

      # This template should have no variables
      When call cat "$tmpdir/aide-check.service"
      The output should include "[Service]"
    End

    It "processes zfs-scrub.timer correctly"
      tmpdir="${SHELLSPEC_TMPBASE}/templates"
      mkdir -p "$tmpdir"
      cp "$TEMPLATES_DIR/zfs-scrub.timer.tmpl" "$tmpdir/zfs-scrub.timer"

      When call cat "$tmpdir/zfs-scrub.timer"
      The output should include "[Timer]"
    End
  End

  # ===========================================================================
  # Template structure validation
  # ===========================================================================
  Describe "template structure validation"
    It "hosts.tmpl has required placeholders"
      When call cat "$TEMPLATES_DIR/hosts.tmpl"
      The output should include "{{MAIN_IPV4}}"
      The output should include "{{FQDN}}"
      The output should include "{{HOSTNAME}}"
    End

    It "sshd_config.tmpl has PasswordAuthentication setting"
      When call cat "$TEMPLATES_DIR/sshd_config.tmpl"
      The output should include "PasswordAuthentication"
    End

    It "promtail.yml.tmpl has HOSTNAME placeholder"
      When call cat "$TEMPLATES_DIR/promtail.yml.tmpl"
      The output should include "{{HOSTNAME}}"
    End
  End
End
