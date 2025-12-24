# shellcheck shell=bash
# =============================================================================
# Tests for 040-validation.sh
# Uses fixtures from spec/support/fixtures.sh
# =============================================================================

%const SCRIPTS_DIR: "${SHELLSPEC_PROJECT_ROOT}/scripts"
%const SUPPORT_DIR: "${SHELLSPEC_PROJECT_ROOT}/spec/support"

# Load fixtures (also loaded by spec_helper.sh)
eval "$(cat "$SUPPORT_DIR/fixtures.sh")"

Describe "040-validation.sh"
  Include "$SCRIPTS_DIR/040-validation.sh"

  # ===========================================================================
  # validate_hostname()
  # ===========================================================================
  Describe "validate_hostname()"
    It "accepts valid hostname with letters and numbers"
      When call validate_hostname "$FIXTURE_VALID_HOSTNAME"
      The status should be success
    End

    It "accepts single character hostname"
      When call validate_hostname "$FIXTURE_VALID_HOSTNAME_SHORT"
      The status should be success
    End

    It "accepts hostname with only letters"
      When call validate_hostname "myserver"
      The status should be success
    End

    It "accepts hostname with hyphens in middle"
      When call validate_hostname "my-server-name"
      The status should be success
    End

    It "accepts 63 character hostname (max length)"
      When call validate_hostname "$FIXTURE_VALID_HOSTNAME_MAX"
      The status should be success
    End

    It "rejects hostname starting with hyphen"
      When call validate_hostname "$FIXTURE_INVALID_HOSTNAME_HYPHEN_START"
      The status should be failure
    End

    It "rejects hostname ending with hyphen"
      When call validate_hostname "$FIXTURE_INVALID_HOSTNAME_HYPHEN_END"
      The status should be failure
    End

    It "rejects hostname with underscores"
      When call validate_hostname "$FIXTURE_INVALID_HOSTNAME_UNDERSCORE"
      The status should be failure
    End

    It "rejects empty hostname"
      When call validate_hostname ""
      The status should be failure
    End

    It "rejects hostname over 63 characters"
      When call validate_hostname "$FIXTURE_INVALID_HOSTNAME_TOO_LONG"
      The status should be failure
    End

    It "rejects hostname with spaces"
      When call validate_hostname "my server"
      The status should be failure
    End

    It "rejects hostname with dots"
      When call validate_hostname "my.server"
      The status should be failure
    End

    It "rejects reserved hostname localhost"
      When call validate_hostname "localhost"
      The status should be failure
    End

    It "rejects localhost in uppercase"
      When call validate_hostname "LOCALHOST"
      The status should be failure
    End

    It "rejects localhost in mixed case"
      When call validate_hostname "LocalHost"
      The status should be failure
    End
  End

  # ===========================================================================
  # validate_admin_username()
  # ===========================================================================
  Describe "validate_admin_username()"
    It "accepts simple username"
      When call validate_admin_username "$FIXTURE_VALID_USERNAME"
      The status should be success
    End

    It "accepts username with numbers"
      When call validate_admin_username "$FIXTURE_VALID_USERNAME_NUMBERS"
      The status should be success
    End

    It "accepts username with underscore"
      When call validate_admin_username "$FIXTURE_VALID_USERNAME_UNDERSCORE"
      The status should be success
    End

    It "accepts username with hyphen"
      When call validate_admin_username "$FIXTURE_VALID_USERNAME_HYPHEN"
      The status should be success
    End

    It "accepts single character username"
      When call validate_admin_username "a"
      The status should be success
    End

    It "accepts max length username (32 chars)"
      When call validate_admin_username "$FIXTURE_VALID_USERNAME_MAX"
      The status should be success
    End

    It "rejects username starting with number"
      When call validate_admin_username "$FIXTURE_INVALID_USERNAME_NUMBER_START"
      The status should be failure
    End

    It "rejects username starting with underscore"
      When call validate_admin_username "_user"
      The status should be failure
    End

    It "rejects username starting with hyphen"
      When call validate_admin_username "-user"
      The status should be failure
    End

    It "rejects uppercase letters"
      When call validate_admin_username "$FIXTURE_INVALID_USERNAME_UPPERCASE"
      The status should be failure
    End

    It "rejects username over 32 characters"
      When call validate_admin_username "$FIXTURE_INVALID_USERNAME_TOO_LONG"
      The status should be failure
    End

    It "rejects empty username"
      When call validate_admin_username ""
      The status should be failure
    End

    It "rejects username with spaces"
      When call validate_admin_username "my user"
      The status should be failure
    End

    It "rejects reserved username root"
      When call validate_admin_username "root"
      The status should be failure
    End

    It "rejects reserved username nobody"
      When call validate_admin_username "nobody"
      The status should be failure
    End

    It "rejects reserved username daemon"
      When call validate_admin_username "daemon"
      The status should be failure
    End

    It "rejects reserved username www-data"
      When call validate_admin_username "www-data"
      The status should be failure
    End

    It "rejects reserved username sshd"
      When call validate_admin_username "sshd"
      The status should be failure
    End

    It "rejects reserved username admin"
      When call validate_admin_username "admin"
      The status should be failure
    End

    It "rejects reserved username administrator"
      When call validate_admin_username "administrator"
      The status should be failure
    End

    It "rejects reserved username guest"
      When call validate_admin_username "guest"
      The status should be failure
    End

    It "rejects reserved username operator"
      When call validate_admin_username "operator"
      The status should be failure
    End
  End

  # ===========================================================================
  # validate_fqdn()
  # ===========================================================================
  Describe "validate_fqdn()"
    It "accepts valid FQDN"
      When call validate_fqdn "$FIXTURE_VALID_FQDN"
      The status should be success
    End

    It "accepts FQDN with subdomain"
      When call validate_fqdn "$FIXTURE_VALID_FQDN_SUBDOMAIN"
      The status should be success
    End

    It "accepts two-level FQDN"
      When call validate_fqdn "server.com"
      The status should be success
    End

    It "rejects single label (no dots)"
      When call validate_fqdn "$FIXTURE_INVALID_FQDN_NO_DOT"
      The status should be failure
    End

    It "rejects empty FQDN"
      When call validate_fqdn ""
      The status should be failure
    End

    It "rejects FQDN starting with dot"
      When call validate_fqdn ".example.com"
      The status should be failure
    End

    It "rejects FQDN ending with dot only"
      When call validate_fqdn "example."
      The status should be failure
    End
  End

  # ===========================================================================
  # validate_email()
  # ===========================================================================
  Describe "validate_email()"
    It "accepts standard email format"
      When call validate_email "$FIXTURE_VALID_EMAIL"
      The status should be success
    End

    It "accepts email with subdomain"
      When call validate_email "$FIXTURE_VALID_EMAIL_SUBDOMAIN"
      The status should be success
    End

    It "accepts email with plus sign"
      When call validate_email "$FIXTURE_VALID_EMAIL_PLUS"
      The status should be success
    End

    It "accepts email with dots in local part"
      When call validate_email "first.last@example.com"
      The status should be success
    End

    It "accepts email with numbers"
      When call validate_email "user123@example123.com"
      The status should be success
    End

    It "rejects email without @"
      When call validate_email "$FIXTURE_INVALID_EMAIL_NO_AT"
      The status should be failure
    End

    It "rejects email without domain"
      When call validate_email "$FIXTURE_INVALID_EMAIL_NO_DOMAIN"
      The status should be failure
    End

    It "rejects email without local part"
      When call validate_email "@example.com"
      The status should be failure
    End

    It "rejects empty email"
      When call validate_email ""
      The status should be failure
    End

    It "rejects email with spaces"
      When call validate_email "$FIXTURE_INVALID_EMAIL_SPACE"
      The status should be failure
    End
  End

  # ===========================================================================
  # is_ascii_printable()
  # ===========================================================================
  Describe "is_ascii_printable()"
    It "accepts ASCII letters"
      When call is_ascii_printable "HelloWorld"
      The status should be success
    End

    It "accepts ASCII numbers"
      When call is_ascii_printable "1234567890"
      The status should be success
    End

    It "accepts ASCII special characters"
      When call is_ascii_printable 'P@ssword!#$%'
      The status should be success
    End

    It "accepts spaces"
      When call is_ascii_printable "hello world"
      The status should be success
    End

    It "rejects Cyrillic characters"
      When call is_ascii_printable "пароль"
      The status should be failure
    End

    It "rejects empty string"
      When call is_ascii_printable ""
      The status should be failure
    End

    It "rejects Chinese characters"
      When call is_ascii_printable "密码"
      The status should be failure
    End
  End

  # ===========================================================================
  # get_password_error()
  # ===========================================================================
  Describe "get_password_error()"
    It "returns empty for valid password"
      When call get_password_error "$FIXTURE_VALID_PASSWORD"
      The output should equal ""
    End

    It "returns error for empty password"
      When call get_password_error "$FIXTURE_INVALID_PASSWORD_EMPTY"
      The output should equal "Password cannot be empty!"
    End

    It "returns error for short password"
      When call get_password_error "$FIXTURE_INVALID_PASSWORD_SHORT"
      The output should equal "Password must be at least 8 characters long."
    End

    It "returns empty for exactly 8 char password"
      When call get_password_error "$FIXTURE_VALID_PASSWORD_MIN"
      The output should equal ""
    End

    It "returns empty for long password"
      When call get_password_error "ThisIsAVeryLongPasswordThatShouldBeValid123!"
      The output should equal ""
    End

    It "returns error for 7 char password"
      When call get_password_error "1234567"
      The output should equal "Password must be at least 8 characters long."
    End
  End

  # ===========================================================================
  # validate_subnet()
  # ===========================================================================
  Describe "validate_subnet()"
    It "accepts valid /24 subnet"
      When call validate_subnet "$FIXTURE_VALID_SUBNET_24"
      The status should be success
    End

    It "accepts valid /32 (single host)"
      When call validate_subnet "$FIXTURE_VALID_SUBNET_32"
      The status should be success
    End

    It "accepts valid /0 (all networks)"
      When call validate_subnet "$FIXTURE_VALID_SUBNET_0"
      The status should be success
    End

    It "accepts valid /16 subnet"
      When call validate_subnet "$FIXTURE_VALID_SUBNET_16"
      The status should be success
    End

    It "accepts valid /8 subnet"
      When call validate_subnet "10.0.0.0/8"
      The status should be success
    End

    It "rejects prefix over 32"
      When call validate_subnet "$FIXTURE_INVALID_SUBNET_PREFIX"
      The status should be failure
    End

    It "rejects octet over 255"
      When call validate_subnet "$FIXTURE_INVALID_SUBNET_OCTET"
      The status should be failure
    End

    It "rejects missing prefix"
      When call validate_subnet "$FIXTURE_INVALID_SUBNET_NO_PREFIX"
      The status should be failure
    End

    It "rejects empty string"
      When call validate_subnet ""
      The status should be failure
    End

    It "rejects negative prefix"
      When call validate_subnet "10.0.0.0/-1"
      The status should be failure
    End

    It "rejects incomplete IP"
      When call validate_subnet "10.0.0/24"
      The status should be failure
    End
  End

  # ===========================================================================
  # validate_ipv6()
  # ===========================================================================
  Describe "validate_ipv6()"
    It "accepts full IPv6 address"
      When call validate_ipv6 "$FIXTURE_VALID_IPV6_FULL"
      The status should be success
    End

    It "accepts compressed IPv6 with ::"
      When call validate_ipv6 "$FIXTURE_VALID_IPV6_COMPRESSED"
      The status should be success
    End

    It "accepts loopback ::1"
      When call validate_ipv6 "$FIXTURE_VALID_IPV6_LOOPBACK"
      The status should be success
    End

    It "accepts link-local fe80::1"
      When call validate_ipv6 "$FIXTURE_VALID_IPV6_LINK_LOCAL"
      The status should be success
    End

    It "accepts all zeros ::"
      When call validate_ipv6 "::"
      The status should be success
    End

    It "rejects multiple :: sequences"
      When call validate_ipv6 "$FIXTURE_INVALID_IPV6_DOUBLE_COLON"
      The status should be failure
    End

    It "rejects IPv4 format"
      When call validate_ipv6 "$FIXTURE_INVALID_IPV6_IPV4"
      The status should be failure
    End

    It "rejects empty string"
      When call validate_ipv6 ""
      The status should be failure
    End

    It "rejects invalid hex characters"
      When call validate_ipv6 "2001:db8::ghij"
      The status should be failure
    End
  End

  # ===========================================================================
  # validate_ipv6_cidr()
  # ===========================================================================
  Describe "validate_ipv6_cidr()"
    It "accepts valid IPv6 with /64"
      When call validate_ipv6_cidr "$FIXTURE_VALID_IPV6_CIDR"
      The status should be success
    End

    It "accepts valid IPv6 with /128"
      When call validate_ipv6_cidr "2001:db8::1/128"
      The status should be success
    End

    It "accepts valid IPv6 with /48"
      When call validate_ipv6_cidr "2001:db8::/48"
      The status should be success
    End

    It "rejects prefix over 128"
      When call validate_ipv6_cidr "2001:db8::1/129"
      The status should be failure
    End

    It "rejects missing prefix"
      When call validate_ipv6_cidr "$FIXTURE_VALID_IPV6_COMPRESSED"
      The status should be failure
    End

    It "rejects empty string"
      When call validate_ipv6_cidr ""
      The status should be failure
    End
  End

  # ===========================================================================
  # validate_ipv6_gateway()
  # ===========================================================================
  Describe "validate_ipv6_gateway()"
    It "accepts empty (no gateway)"
      When call validate_ipv6_gateway ""
      The status should be success
    End

    It "accepts 'auto' keyword"
      When call validate_ipv6_gateway "auto"
      The status should be success
    End

    It "accepts valid IPv6 address"
      When call validate_ipv6_gateway "fe80::1"
      The status should be success
    End

    It "accepts full IPv6 address"
      When call validate_ipv6_gateway "2001:db8::1"
      The status should be success
    End

    It "rejects invalid IPv6"
      When call validate_ipv6_gateway "invalid"
      The status should be failure
    End

    It "rejects IPv4 address"
      When call validate_ipv6_gateway "192.168.1.1"
      The status should be failure
    End
  End

  # ===========================================================================
  # validate_tailscale_key()
  # ===========================================================================
  Describe "validate_tailscale_key()"
    It "accepts valid auth key"
      When call validate_tailscale_key "tskey-auth-kpaPEJ2wwN11CNTRL-UsWiT9N81EjmVTyBKVj5Ej23Pwkp2KUN"
      The status should be success
    End

    It "accepts valid client key"
      When call validate_tailscale_key "tskey-client-abc123DEF-xyz789GHI"
      The status should be success
    End

    It "accepts short key parts"
      When call validate_tailscale_key "tskey-auth-a1-b2"
      The status should be success
    End

    It "rejects missing prefix"
      When call validate_tailscale_key "abc123-def456"
      The status should be failure
    End

    It "rejects invalid prefix"
      When call validate_tailscale_key "tskey-invalid-abc123-def456"
      The status should be failure
    End

    It "rejects missing second part"
      When call validate_tailscale_key "tskey-auth-abc123"
      The status should be failure
    End

    It "rejects empty string"
      When call validate_tailscale_key ""
      The status should be failure
    End

    It "rejects key with special characters"
      When call validate_tailscale_key "tskey-auth-abc@123-def!456"
      The status should be failure
    End

    It "rejects key with spaces"
      When call validate_tailscale_key "tskey-auth-abc 123-def456"
      The status should be failure
    End
  End

  # ===========================================================================
  # validate_dns_resolution()
  # ===========================================================================
  Describe "validate_dns_resolution()"
    # Mock dig to simulate DNS lookups
    dig() {
      case "$*" in
        *"example.com"*)
          echo "93.184.216.34"
          ;;
        *"wrongip.com"*)
          echo "1.2.3.4"
          ;;
        *"noresolution.com"*)
          return 1
          ;;
        *)
          return 1
          ;;
      esac
    }

    # Mock timeout to just run the command
    timeout() { shift; "$@"; }

    # Silence logging
    log() { :; }

    It "returns 0 when FQDN resolves to expected IP"
      When call validate_dns_resolution "example.com" "93.184.216.34"
      The status should equal 0
      The variable DNS_RESOLVED_IP should equal "93.184.216.34"
    End

    It "returns 2 when FQDN resolves to wrong IP"
      When call validate_dns_resolution "wrongip.com" "5.6.7.8"
      The status should equal 2
      The variable DNS_RESOLVED_IP should equal "1.2.3.4"
    End

    It "returns 1 when FQDN cannot be resolved"
      When call validate_dns_resolution "noresolution.com" "1.2.3.4"
      The status should equal 1
      The variable DNS_RESOLVED_IP should equal ""
    End
  End


  # ===========================================================================
  # validate_ssh_key_secure()
  # ===========================================================================
  Describe "validate_ssh_key_secure()"
    # Silence logging
    log() { :; }

    Describe "with mocked ssh-keygen"
      # Mock ssh-keygen for key validation
      ssh-keygen() {
        local key_input=""
        # Read key from stdin when -f - is used
        if [[ "$*" == *"-f -"* ]]; then
          read -r key_input
        fi

        # Simulate validation based on key type
        case "$key_input" in
          "ssh-ed25519 "*)
            if [[ "$*" == *"-l"* ]]; then
              echo "256 SHA256:xxx comment (ED25519)"
            fi
            return 0
            ;;
          "ssh-rsa "*)
            if [[ "$*" == *"-l"* ]]; then
              # Check for weak vs strong RSA
              if [[ "$key_input" == *"WEAK"* ]]; then
                echo "1024 SHA256:xxx comment (RSA)"
              else
                echo "4096 SHA256:xxx comment (RSA)"
              fi
            fi
            return 0
            ;;
          "ecdsa-sha2-nistp256 "*)
            if [[ "$*" == *"-l"* ]]; then
              echo "256 SHA256:xxx comment (ECDSA)"
            fi
            return 0
            ;;
          "ecdsa-sha2-nistp384 "*)
            if [[ "$*" == *"-l"* ]]; then
              echo "384 SHA256:xxx comment (ECDSA)"
            fi
            return 0
            ;;
          "invalid"*)
            return 1
            ;;
          *)
            return 1
            ;;
        esac
      }

      It "accepts ED25519 key"
        When call validate_ssh_key_secure "$FIXTURE_SSH_ED25519"
        The status should be success
      End

      It "accepts strong RSA key (4096 bits)"
        When call validate_ssh_key_secure "$FIXTURE_SSH_RSA_4096"
        The status should be success
      End

      It "rejects weak RSA key (1024 bits)"
        When call validate_ssh_key_secure "$FIXTURE_SSH_RSA_WEAK"
        The status should be failure
      End

      It "accepts ECDSA 256-bit key"
        When call validate_ssh_key_secure "$FIXTURE_SSH_ECDSA_256"
        The status should be success
      End

      It "accepts ECDSA 384-bit key"
        When call validate_ssh_key_secure "$FIXTURE_SSH_ECDSA_384"
        The status should be success
      End

      It "rejects invalid key format"
        When call validate_ssh_key_secure "$FIXTURE_SSH_INVALID"
        The status should be failure
      End

      It "rejects empty key"
        When call validate_ssh_key_secure ""
        The status should be failure
      End
    End
  End

  # ===========================================================================
  # validate_disk_space()
  # ===========================================================================
  Describe "validate_disk_space()"
    # Silence logging
    log() { :; }

    Describe "with sufficient space"
      # Mock df to return 10000 MB available
      df() { echo -e "Filesystem\t1M-blocks\tUsed\tAvailable\n/dev/sda1\t50000\t40000\t10000"; }

      It "returns success when space is sufficient"
        MIN_DISK_SPACE_MB=5000
        When call validate_disk_space "/root"
        The status should be success
        The variable DISK_SPACE_MB should equal "10000"
      End

      It "uses MIN_DISK_SPACE_MB default"
        MIN_DISK_SPACE_MB=1000
        When call validate_disk_space "/root"
        The status should be success
      End
    End

    Describe "with insufficient space"
      # Mock df to return only 500 MB available
      df() { echo -e "Filesystem\t1M-blocks\tUsed\tAvailable\n/dev/sda1\t50000\t49500\t500"; }

      It "returns failure when space is insufficient"
        MIN_DISK_SPACE_MB=5000
        When call validate_disk_space "/root"
        The status should be failure
        The variable DISK_SPACE_MB should equal "500"
      End
    End

    Describe "with custom minimum"
      # Mock df to return 2000 MB available
      df() { echo -e "Filesystem\t1M-blocks\tUsed\tAvailable\n/dev/sda1\t50000\t48000\t2000"; }

      It "accepts custom min_required_mb parameter"
        When call validate_disk_space "/root" 1500
        The status should be success
      End

      It "fails when below custom minimum"
        When call validate_disk_space "/root" 3000
        The status should be failure
      End
    End

    Describe "with df failure"
      # Mock df to fail
      df() { return 1; }

      It "returns failure when df fails"
        When call validate_disk_space "/nonexistent"
        The status should be failure
      End
    End

    Describe "with default path"
      # Mock df to return 5000 MB available
      df() { echo -e "Filesystem\t1M-blocks\tUsed\tAvailable\n/dev/sda1\t50000\t45000\t5000"; }

      It "uses /root as default path"
        MIN_DISK_SPACE_MB=1000
        When call validate_disk_space
        The status should be success
      End
    End
  End

  # ===========================================================================
  # get_password_error() - additional edge cases
  # ===========================================================================
  Describe "get_password_error() - non-ASCII handling"
    It "returns error for Cyrillic password"
      When call get_password_error "$FIXTURE_INVALID_PASSWORD_UNICODE"
      The output should include "invalid characters"
    End

    It "returns error for mixed ASCII and Cyrillic"
      When call get_password_error "password123пароль"
      The output should include "invalid characters"
    End

    It "accepts password with special chars"
      When call get_password_error "$FIXTURE_VALID_PASSWORD_SPECIAL"
      The output should equal ""
    End
  End
End
