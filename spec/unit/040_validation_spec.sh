# shellcheck shell=bash
# =============================================================================
# Tests for 040-validation.sh
# =============================================================================

%const SCRIPTS_DIR: "${SHELLSPEC_PROJECT_ROOT}/scripts"

Describe "040-validation.sh"
Include "$SCRIPTS_DIR/040-validation.sh"

# ===========================================================================
# validate_hostname()
# ===========================================================================
Describe "validate_hostname()"
It "accepts valid hostname with letters and numbers"
When call validate_hostname "pve-server-01"
The status should be success
End

It "accepts single character hostname"
When call validate_hostname "a"
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
When call validate_hostname "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa"
The status should be success
End

It "rejects hostname starting with hyphen"
When call validate_hostname "-invalid"
The status should be failure
End

It "rejects hostname ending with hyphen"
When call validate_hostname "invalid-"
The status should be failure
End

It "rejects hostname with underscores"
When call validate_hostname "invalid_hostname"
The status should be failure
End

It "rejects empty hostname"
When call validate_hostname ""
The status should be failure
End

It "rejects hostname over 63 characters"
When call validate_hostname "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa"
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
End

# ===========================================================================
# validate_fqdn()
# ===========================================================================
Describe "validate_fqdn()"
It "accepts valid FQDN"
When call validate_fqdn "server.example.com"
The status should be success
End

It "accepts FQDN with subdomain"
When call validate_fqdn "pve.dc1.example.com"
The status should be success
End

It "accepts two-level FQDN"
When call validate_fqdn "server.com"
The status should be success
End

It "rejects single label (no dots)"
When call validate_fqdn "localhost"
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
When call validate_email "admin@example.com"
The status should be success
End

It "accepts email with subdomain"
When call validate_email "user@mail.example.co.uk"
The status should be success
End

It "accepts email with plus sign"
When call validate_email "user+tag@example.com"
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
When call validate_email "notanemail"
The status should be failure
End

It "rejects email without domain"
When call validate_email "user@"
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
When call validate_email "user @example.com"
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
When call get_password_error "SecurePass123"
The output should equal ""
End

It "returns error for empty password"
When call get_password_error ""
The output should equal "Password cannot be empty!"
End

It "returns error for short password"
When call get_password_error "short"
The output should equal "Password must be at least 8 characters long."
End

It "returns empty for exactly 8 char password"
When call get_password_error "12345678"
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
When call validate_subnet "10.0.0.0/24"
The status should be success
End

It "accepts valid /32 (single host)"
When call validate_subnet "192.168.1.1/32"
The status should be success
End

It "accepts valid /0 (all networks)"
When call validate_subnet "0.0.0.0/0"
The status should be success
End

It "accepts valid /16 subnet"
When call validate_subnet "172.16.0.0/16"
The status should be success
End

It "accepts valid /8 subnet"
When call validate_subnet "10.0.0.0/8"
The status should be success
End

It "rejects prefix over 32"
When call validate_subnet "10.0.0.0/33"
The status should be failure
End

It "rejects octet over 255"
When call validate_subnet "256.0.0.0/24"
The status should be failure
End

It "rejects missing prefix"
When call validate_subnet "10.0.0.0"
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
When call validate_ipv6 "2001:0db8:85a3:0000:0000:8a2e:0370:7334"
The status should be success
End

It "accepts compressed IPv6 with ::"
When call validate_ipv6 "2001:db8::1"
The status should be success
End

It "accepts loopback ::1"
When call validate_ipv6 "::1"
The status should be success
End

It "accepts link-local fe80::1"
When call validate_ipv6 "fe80::1"
The status should be success
End

It "accepts all zeros ::"
When call validate_ipv6 "::"
The status should be success
End

It "rejects multiple :: sequences"
When call validate_ipv6 "2001::db8::1"
The status should be failure
End

It "rejects IPv4 format"
When call validate_ipv6 "192.168.1.1"
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
When call validate_ipv6_cidr "2001:db8::1/64"
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
When call validate_ipv6_cidr "2001:db8::1"
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
End
