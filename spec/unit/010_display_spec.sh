# shellcheck shell=bash
# =============================================================================
# Tests for 010-display.sh
# =============================================================================

%const SCRIPTS_DIR: "${SHELLSPEC_PROJECT_ROOT}/scripts"

# Set up colors before including script
CLR_RED=$'\033[1;31m'
CLR_CYAN=$'\033[38;2;0;177;255m'
CLR_YELLOW=$'\033[1;33m'
CLR_RESET=$'\033[m'

Describe "010-display.sh"
Include "$SCRIPTS_DIR/010-display.sh"

Describe "print_success()"
It "prints message"
When call print_success "Operation completed"
The output should include "Operation completed"
End

It "prints label and value when two args"
When call print_success "Status:" "OK"
The output should include "Status:"
The output should include "OK"
End
End

Describe "print_error()"
It "prints error message"
When call print_error "Something failed"
The output should include "Something failed"
End
End

Describe "print_warning()"
It "prints warning message"
When call print_warning "Caution advised"
The output should include "Caution advised"
End
End

Describe "print_info()"
It "prints info message"
When call print_info "For your information"
The output should include "For your information"
End
End
End
