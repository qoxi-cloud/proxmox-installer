# shellcheck shell=bash
# =============================================================================
# Tests for 034-password-utils.sh
# =============================================================================

# Set up paths before Include
%const SCRIPTS_DIR: "${SHELLSPEC_PROJECT_ROOT}/scripts"

Describe "034-password-utils.sh"
  Include "$SCRIPTS_DIR/034-password-utils.sh"

  # ===========================================================================
  # generate_password()
  # Note: macOS has issues with tr and /dev/urandom (illegal byte sequence)
  # These tests pass on Linux (CI environment)
  # ===========================================================================
  Describe "generate_password()"
    # Skip on macOS due to tr illegal byte sequence issue
    Skip if "macOS tr compatibility issue" test "$(uname)" = "Darwin"

    It "generates default 16 character password"
      When call generate_password
      The length of output should equal 16
    End

    It "generates password of custom length 8"
      When call generate_password 8
      The length of output should equal 8
    End

    It "generates password of custom length 32"
      When call generate_password 32
      The length of output should equal 32
    End

    It "generates unique passwords"
      password1=$(generate_password 16)
      password2=$(generate_password 16)
      The value "$password1" should not equal "$password2"
    End

    It "contains only valid characters"
      password=$(generate_password 50)
      When call bash -c "[[ '$password' =~ ^[A-Za-z0-9!@#\$%^\&*]+$ ]]"
      The status should be success
    End

    It "generates minimum length 1"
      When call generate_password 1
      The length of output should equal 1
    End

    It "handles large length"
      When call generate_password 100
      The length of output should equal 100
    End

    It "generates non-empty password with default args"
      When call generate_password
      The output should not be blank
    End

    It "returns zero length for zero input"
      When call generate_password 0
      The output should be blank
    End

    It "output contains no newlines or spaces"
      password=$(generate_password 50)
      When call bash -c "[[ '$password' != *$'\n'* && '$password' != *' '* ]]"
      The status should be success
    End

    It "generates different passwords on successive calls"
      passwords=""
      for _ in {1..5}; do
        passwords="$passwords$(generate_password 16)"$'\n'
      done
      unique=$(printf '%s' "$passwords" | grep -c .)
      distinct=$(printf '%s' "$passwords" | sort -u | grep -c .)
      The value "$distinct" should equal "$unique"
    End
  End
End
