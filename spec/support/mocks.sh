# shellcheck shell=bash
# =============================================================================
# Aggregator for all mock files - load this in spec_helper.sh
# =============================================================================
#
# This file sources all mock modules. Load it with:
#   . "$SPEC_ROOT/spec/support/mocks.sh"
#
# For spec files, use eval "$(cat ...)" to load specific mocks:
#   eval "$(cat "$SUPPORT_DIR/core_mocks.sh")"
#   eval "$(cat "$SUPPORT_DIR/configure_mocks.sh")"

SUPPORT_DIR="${SUPPORT_DIR:-$(dirname "${BASH_SOURCE[0]}")}"

# Fixtures - test data constants (always available)
# shellcheck source=spec/support/fixtures.sh
. "$SUPPORT_DIR/fixtures.sh"

# Core mocks are always available
# shellcheck source=spec/support/core_mocks.sh
. "$SUPPORT_DIR/core_mocks.sh"

# Trackable mocks for advanced testing
# shellcheck source=spec/support/trackable_mocks.sh
. "$SUPPORT_DIR/trackable_mocks.sh"

# JSON parsing mocks (jq)
# shellcheck source=spec/support/json_mocks.sh
. "$SUPPORT_DIR/json_mocks.sh"
