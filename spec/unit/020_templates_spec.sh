# shellcheck shell=bash
# =============================================================================
# Tests for 020-templates.sh
# =============================================================================

%const SCRIPTS_DIR: "${SHELLSPEC_PROJECT_ROOT}/scripts"

# Mock log function
log() { :; }

Describe "020-templates.sh"
Include "$SCRIPTS_DIR/020-templates.sh"

Describe "validate_template_vars()"
It "passes template with no variables"
template=$(mktemp)
echo "hostname = pve-server" >"$template"
When call validate_template_vars "$template"
The status should be success
rm -f "$template"
End

It "fails template with unfilled variable"
template=$(mktemp)
echo "hostname = {{HOSTNAME}}" >"$template"
When call validate_template_vars "$template"
The status should be failure
rm -f "$template"
End

It "fails for non-existent file"
When call validate_template_vars "/nonexistent/file.txt"
The status should be failure
End
End

Describe "apply_template_vars()"
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

It "fails for non-existent file"
When call apply_template_vars "/nonexistent/file.txt" "VAR=value"
The status should be failure
End
End
End
