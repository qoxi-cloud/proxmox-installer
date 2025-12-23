# shellcheck shell=bash
# shellcheck disable=SC2016,SC2034
# =============================================================================
# Tests for 011-downloads.sh
# =============================================================================

%const SCRIPTS_DIR: "${SHELLSPEC_PROJECT_ROOT}/scripts"
%const SUPPORT_DIR: "${SHELLSPEC_PROJECT_ROOT}/spec/support"

# Load shared mocks
eval "$(cat "$SUPPORT_DIR/core_mocks.sh")"
eval "$(cat "$SUPPORT_DIR/network_mocks.sh")"

Describe "011-downloads.sh"
  Include "$SCRIPTS_DIR/011-downloads.sh"

  # Reset mock state before each test
  BeforeEach 'reset_network_mocks'

  # ===========================================================================
  # download_file()
  # ===========================================================================
  Describe "download_file()"
    Describe "successful downloads"
      It "downloads file successfully on first attempt"
        DOWNLOAD_RETRY_COUNT=1
        DOWNLOAD_RETRY_DELAY=0
        tmpfile=$(mktemp)
        When call download_file "$tmpfile" "http://example.com/file.txt"
        The status should be success
        The contents of file "$tmpfile" should include "mock"
        The variable MOCK_WGET_CALLS should equal 1
        rm -f "$tmpfile"
      End

      It "succeeds after retry when first attempt fails"
        MOCK_WGET_FAIL_COUNT=1
        DOWNLOAD_RETRY_COUNT=3
        DOWNLOAD_RETRY_DELAY=0
        tmpfile=$(mktemp)
        When call download_file "$tmpfile" "http://example.com/file.txt"
        The status should be success
        The variable MOCK_WGET_CALLS should equal 2
        rm -f "$tmpfile"
      End

      It "succeeds on last retry attempt"
        MOCK_WGET_FAIL_COUNT=2
        DOWNLOAD_RETRY_COUNT=3
        DOWNLOAD_RETRY_DELAY=0
        tmpfile=$(mktemp)
        When call download_file "$tmpfile" "http://example.com/file.txt"
        The status should be success
        The variable MOCK_WGET_CALLS should equal 3
        rm -f "$tmpfile"
      End
    End

    Describe "wget failures"
      It "returns failure when wget fails after all retries"
        MOCK_WGET_FAIL=true
        DOWNLOAD_RETRY_COUNT=2
        DOWNLOAD_RETRY_DELAY=0
        tmpfile=$(mktemp)
        When call download_file "$tmpfile" "http://example.com/file.txt"
        The status should be failure
        The variable MOCK_WGET_CALLS should equal 2
        rm -f "$tmpfile"
      End

      It "exhausts all retry attempts before failing"
        MOCK_WGET_FAIL=true
        DOWNLOAD_RETRY_COUNT=5
        DOWNLOAD_RETRY_DELAY=0
        tmpfile=$(mktemp)
        When call download_file "$tmpfile" "http://example.com/file.txt"
        The status should be failure
        The variable MOCK_WGET_CALLS should equal 5
        rm -f "$tmpfile"
      End
    End

    Describe "empty file handling"
      It "retries when downloaded file is empty"
        MOCK_WGET_EMPTY=true
        DOWNLOAD_RETRY_COUNT=2
        DOWNLOAD_RETRY_DELAY=0
        tmpfile=$(mktemp)
        When call download_file "$tmpfile" "http://example.com/file.txt"
        The status should be failure
        The variable MOCK_WGET_CALLS should equal 2
        rm -f "$tmpfile"
      End

      It "retries when file command reports empty"
        MOCK_FILE_EMPTY=true
        DOWNLOAD_RETRY_COUNT=2
        DOWNLOAD_RETRY_DELAY=0
        tmpfile=$(mktemp)
        When call download_file "$tmpfile" "http://example.com/file.txt"
        The status should be failure
        rm -f "$tmpfile"
      End
    End

    Describe "retry configuration"
      It "uses default retry count when not set"
        unset DOWNLOAD_RETRY_COUNT
        MOCK_WGET_FAIL=true
        DOWNLOAD_RETRY_DELAY=0
        tmpfile=$(mktemp)
        When call download_file "$tmpfile" "http://example.com/file.txt"
        The status should be failure
        The variable MOCK_WGET_CALLS should equal 3
        rm -f "$tmpfile"
      End

      It "handles custom retry count of 1"
        DOWNLOAD_RETRY_COUNT=1
        DOWNLOAD_RETRY_DELAY=0
        MOCK_WGET_FAIL=true
        tmpfile=$(mktemp)
        When call download_file "$tmpfile" "http://example.com/file.txt"
        The status should be failure
        The variable MOCK_WGET_CALLS should equal 1
        rm -f "$tmpfile"
      End

      It "handles large custom retry count"
        DOWNLOAD_RETRY_COUNT=10
        DOWNLOAD_RETRY_DELAY=0
        tmpfile=$(mktemp)
        When call download_file "$tmpfile" "http://example.com/file.txt"
        The status should be success
        rm -f "$tmpfile"
      End
    End

    Describe "edge cases"
      It "handles URL with special characters"
        DOWNLOAD_RETRY_COUNT=1
        DOWNLOAD_RETRY_DELAY=0
        tmpfile=$(mktemp)
        When call download_file "$tmpfile" "http://example.com/path?query=1&foo=bar"
        The status should be success
        rm -f "$tmpfile"
      End

      It "handles output path with spaces"
        DOWNLOAD_RETRY_COUNT=1
        DOWNLOAD_RETRY_DELAY=0
        tmpdir=$(mktemp -d)
        tmpfile="$tmpdir/file with spaces.txt"
        When call download_file "$tmpfile" "http://example.com/file.txt"
        The status should be success
        The file "$tmpfile" should be exist
        rm -rf "$tmpdir"
      End
    End
  End
End
