# shellcheck shell=bash
# shellcheck disable=SC2016,SC2034
# =============================================================================
# Tests for 020-templates.sh
# =============================================================================

%const SCRIPTS_DIR: "${SHELLSPEC_PROJECT_ROOT}/scripts"
%const SUPPORT_DIR: "${SHELLSPEC_PROJECT_ROOT}/spec/support"

# Load shared mocks
eval "$(cat "$SUPPORT_DIR/core_mocks.sh")"
eval "$(cat "$SUPPORT_DIR/download_mocks.sh")"

# =============================================================================
# Helper functions for setting up test environment
# =============================================================================
setup_common_vars() {
  MAIN_IPV4="192.168.1.100"
  MAIN_IPV4_GW="192.168.1.1"
  MAIN_IPV6="2001:db8::1"
  FIRST_IPV6_CIDR="2001:db8::/64"
  IPV6_GATEWAY="fe80::1"
  FQDN="host.example.com"
  PVE_HOSTNAME="host"
  INTERFACE_NAME="eth0"
  PRIVATE_IP_CIDR="10.0.0.0/24"
  PRIVATE_SUBNET="10.0.0.0/24"
  BRIDGE_MTU="1500"
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

unset_common_vars() {
  unset MAIN_IPV4 MAIN_IPV4_GW MAIN_IPV6 FIRST_IPV6_CIDR
  unset PVE_HOSTNAME INTERFACE_NAME FQDN PRIVATE_IP_CIDR PRIVATE_SUBNET
  unset DNS_PRIMARY DNS_SECONDARY DNS6_PRIMARY DNS6_SECONDARY
  unset LOCALE KEYBOARD COUNTRY BAT_THEME PORT_SSH PORT_PROXMOX_UI
  unset BRIDGE_MTU IPV6_GATEWAY
}

setup_empty_critical_vars() {
  MAIN_IPV4=""
  MAIN_IPV4_GW=""
  PVE_HOSTNAME=""
  INTERFACE_NAME=""
}

# download_file mock is now in download_mocks.sh

Describe "020-templates.sh"
  Include "$SCRIPTS_DIR/020-templates.sh"

  # ===========================================================================
  # apply_template_vars()
  # ===========================================================================
  Describe "apply_template_vars()"
    Describe "basic substitution"
      It "substitutes single variable"
        template=$(mktemp)
        echo "hostname = {{HOSTNAME}}" >"$template"
        When call apply_template_vars "$template" "HOSTNAME=pve-test"
        The status should be success
        The contents of file "$template" should equal "hostname = pve-test"
        rm -f "$template"
      End

      It "substitutes multiple variables"
        template=$(mktemp)
        echo "host={{HOST}} gw={{GW}}" >"$template"
        When call apply_template_vars "$template" "HOST=server" "GW=192.168.1.1"
        The status should be success
        The contents of file "$template" should equal "host=server gw=192.168.1.1"
        rm -f "$template"
      End

      It "substitutes same variable multiple times"
        template=$(mktemp)
        echo "{{VAR}}-{{VAR}}-{{VAR}}" >"$template"
        When call apply_template_vars "$template" "VAR=x"
        The status should be success
        The contents of file "$template" should equal "x-x-x"
        rm -f "$template"
      End

      It "preserves non-placeholder text"
        template=$(mktemp)
        echo "before {{VAR}} after" >"$template"
        When call apply_template_vars "$template" "VAR=middle"
        The status should be success
        The contents of file "$template" should equal "before middle after"
        rm -f "$template"
      End
    End

    Describe "error handling"
      It "fails for non-existent file"
        When call apply_template_vars "/nonexistent/file.txt" "VAR=value"
        The status should be failure
      End

      It "fails when unmatched placeholders remain"
        template=$(mktemp)
        echo "a={{A}} b={{B}}" >"$template"
        When call apply_template_vars "$template" "A=1"
        The status should be failure
        rm -f "$template"
      End

      It "fails when no substitutions provided but placeholders exist"
        template=$(mktemp)
        echo "{{UNHANDLED}}" >"$template"
        When call apply_template_vars "$template"
        The status should be failure
        rm -f "$template"
      End
    End

    Describe "special character handling"
      It "handles path values with slashes"
        template=$(mktemp)
        echo "path={{PATH}}" >"$template"
        When call apply_template_vars "$template" "PATH=/usr/local/bin"
        The status should be success
        The contents of file "$template" should equal "path=/usr/local/bin"
        rm -f "$template"
      End

      It "escapes ampersand in value"
        template=$(mktemp)
        echo "cmd={{CMD}}" >"$template"
        When call apply_template_vars "$template" "CMD=a & b"
        The status should be success
        The contents of file "$template" should equal "cmd=a & b"
        rm -f "$template"
      End

      It "escapes backslash in value"
        template=$(mktemp)
        echo "path={{PATH}}" >"$template"
        When call apply_template_vars "$template" 'PATH=C:\Users'
        The status should be success
        The contents of file "$template" should equal 'path=C:\Users'
        rm -f "$template"
      End

      It "escapes pipe in value"
        template=$(mktemp)
        echo "cmd={{CMD}}" >"$template"
        When call apply_template_vars "$template" "CMD=a | b"
        The status should be success
        The contents of file "$template" should equal "cmd=a | b"
        rm -f "$template"
      End

      It "handles quotes in value"
        template=$(mktemp)
        echo "msg={{MSG}}" >"$template"
        When call apply_template_vars "$template" 'MSG="hello world"'
        The status should be success
        The contents of file "$template" should equal 'msg="hello world"'
        rm -f "$template"
      End
    End

    Describe "empty and edge cases"
      It "allows empty value substitution"
        template=$(mktemp)
        echo "var={{VAR}}" >"$template"
        When call apply_template_vars "$template" "VAR="
        The status should be success
        The contents of file "$template" should equal "var="
        rm -f "$template"
      End

      It "succeeds with file containing no placeholders"
        template=$(mktemp)
        echo "no placeholders here" >"$template"
        When call apply_template_vars "$template"
        The status should be success
        The contents of file "$template" should equal "no placeholders here"
        rm -f "$template"
      End

      It "handles multiline template"
        template=$(mktemp)
        printf "line1={{A}}\nline2={{B}}\nline3" >"$template"
        When call apply_template_vars "$template" "A=val1" "B=val2"
        The status should be success
        The contents of file "$template" should equal "line1=val1
line2=val2
line3"
        rm -f "$template"
      End

      It "handles variable names with underscores"
        template=$(mktemp)
        echo "{{MY_LONG_VAR_NAME}}" >"$template"
        When call apply_template_vars "$template" "MY_LONG_VAR_NAME=value"
        The status should be success
        The contents of file "$template" should equal "value"
        rm -f "$template"
      End

      It "handles variable names with digits"
        template=$(mktemp)
        echo "ip={{MAIN_IPV4}} dns={{DNS6_PRIMARY}}" >"$template"
        When call apply_template_vars "$template" "MAIN_IPV4=192.168.1.1" "DNS6_PRIMARY=2606:4700::1111"
        The status should be success
        The contents of file "$template" should equal "ip=192.168.1.1 dns=2606:4700::1111"
        rm -f "$template"
      End
    End

    Describe "placeholder detection with digits"
      It "fails when variable with digits remains unsubstituted"
        template=$(mktemp)
        echo "ip={{MAIN_IPV4}} gw={{MAIN_IPV4_GW}}" >"$template"
        When call apply_template_vars "$template" "MAIN_IPV4=192.168.1.1"
        The status should be failure
        rm -f "$template"
      End

      It "detects unsubstituted DNS6_PRIMARY"
        template=$(mktemp)
        echo "dns={{DNS6_PRIMARY}}" >"$template"
        When call apply_template_vars "$template"
        The status should be failure
        rm -f "$template"
      End

      It "detects unsubstituted FIRST_IPV6_CIDR"
        template=$(mktemp)
        echo "cidr={{FIRST_IPV6_CIDR}}" >"$template"
        When call apply_template_vars "$template"
        The status should be failure
        rm -f "$template"
      End

      It "succeeds when all digit-containing variables are substituted"
        template=$(mktemp)
        echo "{{VAR1}} {{VAR2A}} {{A3B4C5}}" >"$template"
        When call apply_template_vars "$template" "VAR1=x" "VAR2A=y" "A3B4C5=z"
        The status should be success
        The contents of file "$template" should equal "x y z"
        rm -f "$template"
      End
    End
  End

  # ===========================================================================
  # apply_common_template_vars()
  # ===========================================================================
  Describe "apply_common_template_vars()"
    Describe "successful substitution"
      BeforeEach 'setup_common_vars'

      It "substitutes all common network variables"
        template=$(mktemp)
        echo "ip={{MAIN_IPV4}} gw={{MAIN_IPV4_GW}} host={{HOSTNAME}}" >"$template"
        When call apply_common_template_vars "$template"
        The status should be success
        The contents of file "$template" should equal "ip=192.168.1.100 gw=192.168.1.1 host=host"
        rm -f "$template"
      End

      It "substitutes IPv6 variables"
        template=$(mktemp)
        echo "ipv6={{MAIN_IPV6}} cidr={{FIRST_IPV6_CIDR}} gw6={{IPV6_GATEWAY}}" >"$template"
        When call apply_common_template_vars "$template"
        The status should be success
        The contents of file "$template" should equal "ipv6=2001:db8::1 cidr=2001:db8::/64 gw6=fe80::1"
        rm -f "$template"
      End

      It "substitutes DNS variables"
        template=$(mktemp)
        echo "dns1={{DNS_PRIMARY}} dns2={{DNS_SECONDARY}}" >"$template"
        When call apply_common_template_vars "$template"
        The status should be success
        The contents of file "$template" should equal "dns1=1.1.1.1 dns2=1.0.0.1"
        rm -f "$template"
      End

      It "substitutes locale and keyboard variables"
        template=$(mktemp)
        echo "locale={{LOCALE}} kb={{KEYBOARD}} country={{COUNTRY}}" >"$template"
        When call apply_common_template_vars "$template"
        The status should be success
        The contents of file "$template" should equal "locale=en_US.UTF-8 kb=us country=US"
        rm -f "$template"
      End

      It "substitutes port variables"
        template=$(mktemp)
        echo "ssh={{PORT_SSH}} ui={{PORT_PROXMOX_UI}}" >"$template"
        When call apply_common_template_vars "$template"
        The status should be success
        The contents of file "$template" should equal "ssh=22 ui=8006"
        rm -f "$template"
      End

      It "substitutes interface and bridge variables"
        template=$(mktemp)
        echo "iface={{INTERFACE_NAME}} mtu={{BRIDGE_MTU}}" >"$template"
        When call apply_common_template_vars "$template"
        The status should be success
        The contents of file "$template" should equal "iface=eth0 mtu=1500"
        rm -f "$template"
      End

      It "substitutes FQDN variable"
        template=$(mktemp)
        echo "fqdn={{FQDN}}" >"$template"
        When call apply_common_template_vars "$template"
        The status should be success
        The contents of file "$template" should equal "fqdn=host.example.com"
        rm -f "$template"
      End

      It "substitutes private network variables"
        template=$(mktemp)
        echo "priv_cidr={{PRIVATE_IP_CIDR}} subnet={{PRIVATE_SUBNET}}" >"$template"
        When call apply_common_template_vars "$template"
        The status should be success
        The contents of file "$template" should equal "priv_cidr=10.0.0.0/24 subnet=10.0.0.0/24"
        rm -f "$template"
      End

      It "substitutes BAT_THEME variable"
        template=$(mktemp)
        echo "theme={{BAT_THEME}}" >"$template"
        When call apply_common_template_vars "$template"
        The status should be success
        The contents of file "$template" should equal "theme=Catppuccin Mocha"
        rm -f "$template"
      End
    End

    Describe "default values"
      BeforeEach 'unset_common_vars'

      It "uses default DNS values when not set"
        template=$(mktemp)
        echo "dns={{DNS_PRIMARY}} dns2={{DNS_SECONDARY}}" >"$template"
        When call apply_common_template_vars "$template"
        The status should be success
        The contents of file "$template" should equal "dns=1.1.1.1 dns2=1.0.0.1"
        rm -f "$template"
      End

      It "uses default IPv6 DNS values when not set"
        template=$(mktemp)
        echo "dns6={{DNS6_PRIMARY}} dns6_2={{DNS6_SECONDARY}}" >"$template"
        When call apply_common_template_vars "$template"
        The status should be success
        The contents of file "$template" should equal "dns6=2606:4700:4700::1111 dns6_2=2606:4700:4700::1001"
        rm -f "$template"
      End

      It "uses default IPv6 gateway when not set"
        template=$(mktemp)
        echo "gw6={{IPV6_GATEWAY}}" >"$template"
        When call apply_common_template_vars "$template"
        The status should be success
        The contents of file "$template" should equal "gw6=fe80::1"
        rm -f "$template"
      End

      It "uses default bridge MTU when not set"
        template=$(mktemp)
        echo "mtu={{BRIDGE_MTU}}" >"$template"
        When call apply_common_template_vars "$template"
        The status should be success
        The contents of file "$template" should equal "mtu=9000"
        rm -f "$template"
      End

      It "uses default locale when not set"
        template=$(mktemp)
        echo "locale={{LOCALE}}" >"$template"
        When call apply_common_template_vars "$template"
        The status should be success
        The contents of file "$template" should equal "locale=en_US.UTF-8"
        rm -f "$template"
      End

      It "uses default keyboard when not set"
        template=$(mktemp)
        echo "kb={{KEYBOARD}}" >"$template"
        When call apply_common_template_vars "$template"
        The status should be success
        The contents of file "$template" should equal "kb=us"
        rm -f "$template"
      End

      It "uses default country when not set"
        template=$(mktemp)
        echo "country={{COUNTRY}}" >"$template"
        When call apply_common_template_vars "$template"
        The status should be success
        The contents of file "$template" should equal "country=US"
        rm -f "$template"
      End

      It "uses default BAT theme when not set"
        template=$(mktemp)
        echo "theme={{BAT_THEME}}" >"$template"
        When call apply_common_template_vars "$template"
        The status should be success
        The contents of file "$template" should equal "theme=Catppuccin Mocha"
        rm -f "$template"
      End

      It "uses default SSH port when not set"
        template=$(mktemp)
        echo "ssh={{PORT_SSH}}" >"$template"
        When call apply_common_template_vars "$template"
        The status should be success
        The contents of file "$template" should equal "ssh=22"
        rm -f "$template"
      End

      It "uses default Proxmox UI port when not set"
        template=$(mktemp)
        echo "ui={{PORT_PROXMOX_UI}}" >"$template"
        When call apply_common_template_vars "$template"
        The status should be success
        The contents of file "$template" should equal "ui=8006"
        rm -f "$template"
      End
    End

    Describe "empty variable handling"
      BeforeEach 'setup_empty_critical_vars'

      It "replaces with empty string when critical vars are empty"
        template=$(mktemp)
        echo "ip={{MAIN_IPV4}} host={{HOSTNAME}}" >"$template"
        When call apply_common_template_vars "$template"
        The status should be success
        The contents of file "$template" should equal "ip= host="
        rm -f "$template"
      End
    End
  End

  # ===========================================================================
  # download_template()
  # ===========================================================================
  Describe "download_template()"
    BeforeEach 'reset_download_mocks; GITHUB_BASE_URL="https://raw.githubusercontent.com/test/repo/main"'

    Describe "successful downloads"
      It "downloads template to specified path"
        tmpfile=$(mktemp)
        rm -f "$tmpfile"
        When call download_template "$tmpfile" "some-config"
        The status should be success
        The file "$tmpfile" should be exist
        rm -f "$tmpfile"
      End

      It "uses basename when remote filename not specified"
        tmpdir=$(mktemp -d)
        tmpfile="$tmpdir/myconfig"
        When call download_template "$tmpfile"
        The status should be success
        The file "$tmpfile" should be exist
        rm -rf "$tmpdir"
      End
    End

    Describe "download failures"
      It "fails when download fails"
        MOCK_DOWNLOAD_FAIL=true
        tmpfile=$(mktemp)
        rm -f "$tmpfile"
        When call download_template "$tmpfile" "some-config"
        The status should be failure
        rm -f "$tmpfile"
      End

      It "fails when downloaded file is empty"
        MOCK_DOWNLOAD_EMPTY=true
        tmpfile=$(mktemp)
        rm -f "$tmpfile"
        When call download_template "$tmpfile" "some-config"
        The status should be failure
        rm -f "$tmpfile"
      End
    End

    Describe "answer.toml validation"
      It "succeeds when answer.toml has [global] section"
        MOCK_DOWNLOAD_CONTENT="[global]
keyboard = us"
        tmpdir=$(mktemp -d)
        tmpfile="$tmpdir/answer.toml"
        When call download_template "$tmpfile" "answer.toml"
        The status should be success
        rm -rf "$tmpdir"
      End

      It "fails when answer.toml missing [global] section"
        MOCK_DOWNLOAD_CONTENT="invalid content"
        tmpdir=$(mktemp -d)
        tmpfile="$tmpdir/answer.toml"
        When call download_template "$tmpfile" "answer.toml"
        The status should be failure
        rm -rf "$tmpdir"
      End
    End

    Describe "sshd_config validation"
      It "succeeds when sshd_config has PasswordAuthentication"
        MOCK_DOWNLOAD_CONTENT="Port 22
PasswordAuthentication no"
        tmpdir=$(mktemp -d)
        tmpfile="$tmpdir/sshd_config"
        When call download_template "$tmpfile" "sshd_config"
        The status should be success
        rm -rf "$tmpdir"
      End

      It "fails when sshd_config missing PasswordAuthentication"
        MOCK_DOWNLOAD_CONTENT="Port 22"
        tmpdir=$(mktemp -d)
        tmpfile="$tmpdir/sshd_config"
        When call download_template "$tmpfile" "sshd_config"
        The status should be failure
        rm -rf "$tmpdir"
      End
    End

    Describe "shell script validation"
      It "succeeds when .sh file has shebang"
        MOCK_DOWNLOAD_CONTENT="#!/bin/bash
echo hello"
        tmpdir=$(mktemp -d)
        tmpfile="$tmpdir/test.sh"
        When call download_template "$tmpfile" "test.sh"
        The status should be success
        rm -rf "$tmpdir"
      End

      It "succeeds when .sh file has shellcheck directive"
        MOCK_DOWNLOAD_CONTENT="# shellcheck shell=bash
echo test"
        tmpdir=$(mktemp -d)
        tmpfile="$tmpdir/test.sh"
        When call download_template "$tmpfile" "test.sh"
        The status should be success
        rm -rf "$tmpdir"
      End

      It "succeeds when .sh file has export statement first"
        MOCK_DOWNLOAD_CONTENT="export PATH=/usr/bin"
        tmpdir=$(mktemp -d)
        tmpfile="$tmpdir/test.sh"
        When call download_template "$tmpfile" "test.sh"
        The status should be success
        rm -rf "$tmpdir"
      End

      It "succeeds when .sh file has bash syntax"
        MOCK_DOWNLOAD_CONTENT="# comment
if true; then echo yes; fi"
        tmpdir=$(mktemp -d)
        tmpfile="$tmpdir/test.sh"
        When call download_template "$tmpfile" "test.sh"
        The status should be success
        rm -rf "$tmpdir"
      End

      It "fails when .sh file has no valid bash content"
        MOCK_DOWNLOAD_CONTENT="random garbage"
        tmpdir=$(mktemp -d)
        tmpfile="$tmpdir/test.sh"
        When call download_template "$tmpfile" "test.sh"
        The status should be failure
        rm -rf "$tmpdir"
      End
    End

    Describe "config file validation"
      It "succeeds when .conf file has sufficient lines"
        MOCK_DOWNLOAD_CONTENT="line1
line2"
        tmpdir=$(mktemp -d)
        tmpfile="$tmpdir/test.conf"
        When call download_template "$tmpfile" "test.conf"
        The status should be success
        rm -rf "$tmpdir"
      End

      It "fails when .conf file is too short"
        MOCK_DOWNLOAD_CONTENT="single"
        tmpdir=$(mktemp -d)
        tmpfile="$tmpdir/test.conf"
        When call download_template "$tmpfile" "test.conf"
        The status should be failure
        rm -rf "$tmpdir"
      End

      It "succeeds when .service file has sufficient lines"
        MOCK_DOWNLOAD_CONTENT="[Unit]
Description=Test"
        tmpdir=$(mktemp -d)
        tmpfile="$tmpdir/test.service"
        When call download_template "$tmpfile" "test.service"
        The status should be success
        rm -rf "$tmpdir"
      End

      It "succeeds when .timer file has sufficient lines"
        MOCK_DOWNLOAD_CONTENT="[Timer]
OnCalendar=daily"
        tmpdir=$(mktemp -d)
        tmpfile="$tmpdir/test.timer"
        When call download_template "$tmpfile" "test.timer"
        The status should be success
        rm -rf "$tmpdir"
      End

      It "succeeds when .sources file has sufficient lines"
        MOCK_DOWNLOAD_CONTENT="Types: deb
URIs: http://example.com"
        tmpdir=$(mktemp -d)
        tmpfile="$tmpdir/test.sources"
        When call download_template "$tmpfile" "test.sources"
        The status should be success
        rm -rf "$tmpdir"
      End
    End

    Describe "files without validation"
      It "succeeds for unknown file types with content"
        tmpdir=$(mktemp -d)
        tmpfile="$tmpdir/test.txt"
        When call download_template "$tmpfile" "test.txt"
        The status should be success
        rm -rf "$tmpdir"
      End
    End
  End
End
