#!/usr/bin/env bash
# =============================================================================
# Unit tests for main script functions (99-main.sh)
# =============================================================================

set -euo pipefail

# Colors for test output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
NC='\033[0m'

TESTS_RUN=0
TESTS_PASSED=0
TESTS_FAILED=0

# Source required scripts
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

# Extract truncate_middle function from main script
eval "$(sed -n '/^truncate_middle()/,/^}/p' "$SCRIPT_DIR/scripts/99-main.sh")"

# Test helper functions
assert_equals() {
    local description="$1"
    local expected="$2"
    local actual="$3"
    TESTS_RUN=$((TESTS_RUN + 1))
    if [[ "$expected" == "$actual" ]]; then
        echo -e "${GREEN}✓${NC} $description"
        TESTS_PASSED=$((TESTS_PASSED + 1))
    else
        echo -e "${RED}✗${NC} $description (expected: '$expected', got: '$actual')"
        TESTS_FAILED=$((TESTS_FAILED + 1))
    fi
}

# =============================================================================
# truncate_middle tests
# =============================================================================
echo -e "\n${YELLOW}=== Testing truncate_middle ===${NC}"

# Short strings (no truncation needed)
assert_equals "short string unchanged" "hello" "$(truncate_middle "hello" 25)"
assert_equals "exact length unchanged" "1234567890123456789012345" "$(truncate_middle "1234567890123456789012345" 25)"

# Long strings (truncation needed)
result=$(truncate_middle "this-is-a-very-long-hostname-that-needs-truncation" 25)
TESTS_RUN=$((TESTS_RUN + 1))
if [[ ${#result} -le 25 ]] && [[ "$result" == *"..."* ]]; then
    echo -e "${GREEN}✓${NC} long string is truncated with ellipsis"
    TESTS_PASSED=$((TESTS_PASSED + 1))
else
    echo -e "${RED}✗${NC} long string truncation failed (got: '$result')"
    TESTS_FAILED=$((TESTS_FAILED + 1))
fi

# Check ellipsis is in middle
result=$(truncate_middle "abcdefghijklmnopqrstuvwxyz1234567890" 20)
TESTS_RUN=$((TESTS_RUN + 1))
if [[ "$result" =~ ^[a-z]+\.\.\.[0-9]+$ ]]; then
    echo -e "${GREEN}✓${NC} ellipsis is in middle position"
    TESTS_PASSED=$((TESTS_PASSED + 1))
else
    echo -e "${RED}✗${NC} ellipsis position incorrect (got: '$result')"
    TESTS_FAILED=$((TESTS_FAILED + 1))
fi

# Different max lengths
result=$(truncate_middle "abcdefghijklmnopqrstuvwxyz" 10)
assert_equals "truncate to 10 chars" "10" "${#result}"

result=$(truncate_middle "abcdefghijklmnopqrstuvwxyz" 15)
assert_equals "truncate to 15 chars" "15" "${#result}"

# Default max length (25)
result=$(truncate_middle "this-is-a-very-very-very-long-string-indeed")
TESTS_RUN=$((TESTS_RUN + 1))
if [[ ${#result} -le 25 ]]; then
    echo -e "${GREEN}✓${NC} default max length is 25"
    TESTS_PASSED=$((TESTS_PASSED + 1))
else
    echo -e "${RED}✗${NC} default max length should be 25 (got length: ${#result})"
    TESTS_FAILED=$((TESTS_FAILED + 1))
fi

# Empty string
assert_equals "empty string unchanged" "" "$(truncate_middle "" 25)"

# =============================================================================
# Summary
# =============================================================================
echo -e "\n${YELLOW}=== Test Summary ===${NC}"
echo "Tests run: $TESTS_RUN"
echo -e "Passed: ${GREEN}$TESTS_PASSED${NC}"
echo -e "Failed: ${RED}$TESTS_FAILED${NC}"

if [[ $TESTS_FAILED -gt 0 ]]; then
    exit 1
fi
