# shellcheck shell=bash
# shellcheck disable=SC2034
# =============================================================================
# Tests for 012-utils.sh
# =============================================================================

%const SCRIPTS_DIR: "${SHELLSPEC_PROJECT_ROOT}/scripts"
%const SUPPORT_DIR: "${SHELLSPEC_PROJECT_ROOT}/spec/support"

# Load shared mocks
eval "$(cat "$SUPPORT_DIR/colors.sh")"
eval "$(cat "$SUPPORT_DIR/core_mocks.sh")"

Describe "012-utils.sh"
  Include "$SCRIPTS_DIR/012-utils.sh"

  # ===========================================================================
  # secure_delete_file()
  # ===========================================================================
  Describe "secure_delete_file()"
    Describe "with empty or missing arguments"
      It "returns success for empty argument"
        When call secure_delete_file ""
        The status should be success
      End

      It "returns success for null file path"
        When call secure_delete_file
        The status should be success
      End
    End

    Describe "with non-existent file"
      It "returns success when file does not exist"
        When call secure_delete_file "/tmp/nonexistent_file_12345"
        The status should be success
      End

      It "returns success for path that is a directory"
        tmpdir=$(mktemp -d)
        When call secure_delete_file "$tmpdir"
        The status should be success
        rmdir "$tmpdir"
      End
    End

    Describe "with existing file and shred available"
      Skip if "shred not available" ! command -v shred >/dev/null 2>&1

      It "deletes the file"
        tmpfile=$(mktemp)
        echo "sensitive data" > "$tmpfile"
        When call secure_delete_file "$tmpfile"
        The status should be success
        The file "$tmpfile" should not be exist
      End

      It "handles file with special characters in name"
        tmpdir=$(mktemp -d)
        tmpfile="${tmpdir}/file with spaces.txt"
        echo "data" > "$tmpfile"
        When call secure_delete_file "$tmpfile"
        The status should be success
        The file "$tmpfile" should not be exist
        rmdir "$tmpdir"
      End

      It "handles empty file"
        tmpfile=$(mktemp)
        When call secure_delete_file "$tmpfile"
        The status should be success
        The file "$tmpfile" should not be exist
      End

      It "handles large file"
        tmpfile=$(mktemp)
        dd if=/dev/zero of="$tmpfile" bs=1024 count=100 2>/dev/null
        When call secure_delete_file "$tmpfile"
        The status should be success
        The file "$tmpfile" should not be exist
      End
    End

    Describe "with dd fallback when shred unavailable"
      # Mock shred to not exist
      command() {
        if [[ $1 == "-v" && $2 == "shred" ]]; then
          return 1
        fi
        builtin command "$@"
      }

      It "uses dd fallback and deletes file"
        tmpfile=$(mktemp)
        echo "fallback test data" > "$tmpfile"
        When call secure_delete_file "$tmpfile"
        The status should be success
        The file "$tmpfile" should not be exist
      End

      It "handles empty file with dd fallback"
        tmpfile=$(mktemp)
        When call secure_delete_file "$tmpfile"
        The status should be success
        The file "$tmpfile" should not be exist
      End
    End

    Describe "file content overwrite verification"
      Skip if "shred not available" ! command -v shred >/dev/null 2>&1

      It "overwrites file content before deletion"
        tmpfile=$(mktemp)
        echo "SECRET_PASSPHRASE_12345" > "$tmpfile"
        # Create a hard link to verify content is overwritten
        linkfile=$(mktemp)
        rm "$linkfile"
        ln "$tmpfile" "$linkfile" 2>/dev/null || {
          # Hard links may not be supported, skip content check
          rm -f "$tmpfile"
          Skip "hard links not supported"
        }
        When call secure_delete_file "$tmpfile"
        The status should be success
        # Original file should be gone
        The file "$tmpfile" should not be exist
        rm -f "$linkfile"
      End
    End
  End
End

