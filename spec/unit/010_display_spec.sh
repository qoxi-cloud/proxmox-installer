# shellcheck shell=bash
# shellcheck disable=SC2034
# =============================================================================
# Tests for 010-display.sh
# =============================================================================

%const SCRIPTS_DIR: "${SHELLSPEC_PROJECT_ROOT}/scripts"
%const SUPPORT_DIR: "${SHELLSPEC_PROJECT_ROOT}/spec/support"

# Load shared mocks
eval "$(cat "$SUPPORT_DIR/colors.sh")"
eval "$(cat "$SUPPORT_DIR/ui_mocks.sh")"

# Required globals for format_wizard_header
BANNER_WIDTH=51
_BANNER_PAD=""

# Shared mocks include add_log

Describe "010-display.sh"
  Include "$SCRIPTS_DIR/010-display.sh"

  # ===========================================================================
  # print_success()
  # ===========================================================================
  Describe "print_success()"
    It "prints message with checkmark"
      When call print_success "Operation completed"
      The output should include "✓"
      The output should include "Operation completed"
    End

    It "prints label and value when two args"
      When call print_success "Status:" "OK"
      The output should include "Status:"
      The output should include "OK"
    End

    It "includes cyan color for value"
      When call print_success "Label" "value"
      The output should include "$CLR_CYAN"
      The output should include "value"
    End

    It "handles empty message"
      When call print_success ""
      The status should be success
      The output should be present
    End

    It "handles message with special characters"
      When call print_success "Disk: /dev/sda1"
      The output should include "/dev/sda1"
    End
  End

  # ===========================================================================
  # print_error()
  # ===========================================================================
  Describe "print_error()"
    It "prints error message with cross mark"
      When call print_error "Something failed"
      The output should include "✗"
      The output should include "Something failed"
    End

    It "includes red color"
      When call print_error "Error occurred"
      The output should include "$CLR_RED"
    End

    It "prints message with colon"
      When call print_error "Error: File not found"
      The output should include "Error: File not found"
    End

    It "handles empty message"
      When call print_error ""
      The status should be success
      The output should include "✗"
    End
  End

  # ===========================================================================
  # print_warning()
  # ===========================================================================
  Describe "print_warning()"
    It "prints warning message with warning icon"
      When call print_warning "Caution advised"
      The output should include "⚠️"
      The output should include "Caution advised"
    End

    It "includes yellow color"
      When call print_warning "Warning"
      The output should include "$CLR_YELLOW"
    End

    It "prints message with value when two args (not nested)"
      When call print_warning "Disk usage:" "90%"
      The output should include "Disk usage:"
      The output should include "90%"
      The output should include "$CLR_CYAN"
    End

    It "prints indented when nested is true"
      When call print_warning "Sub-warning" "true"
      The output should include "  "
      The output should include "Sub-warning"
    End

    It "handles special characters"
      When call print_warning "Warning: disk 90% full!"
      The output should include "disk 90% full"
    End

    It "handles empty message"
      When call print_warning ""
      The status should be success
      The output should include "⚠️"
    End
  End

  # ===========================================================================
  # print_info()
  # ===========================================================================
  Describe "print_info()"
    It "prints info message with info symbol"
      When call print_info "For your information"
      The output should include "ℹ"
      The output should include "For your information"
    End

    It "includes cyan color"
      When call print_info "Info message"
      The output should include "$CLR_CYAN"
    End

    It "prints message with colon"
      When call print_info "Version: 1.0.0"
      The output should include "Version: 1.0.0"
    End

    It "handles empty message"
      When call print_info ""
      The status should be success
      The output should include "ℹ"
    End
  End

  # ===========================================================================
  # print_section()
  # ===========================================================================
  Describe "print_section()"
    It "prints section header"
      When call print_section "Configuration"
      The output should include "Configuration"
    End

    It "includes cyan color"
      When call print_section "Network Setup"
      The output should include "$CLR_CYAN"
      The output should include "$CLR_RESET"
    End

    It "handles empty header"
      When call print_section ""
      The status should be success
      The output should be present
    End

    It "handles special characters in header"
      When call print_section "Step 1/5: Network"
      The output should include "Step 1/5: Network"
    End
  End

  # ===========================================================================
  # show_progress()
  # ===========================================================================
  Describe "show_progress()"
    # Skip when running under kcov - background subshells cause kcov to hang
    Skip if "running under kcov" is_running_under_kcov

    It "returns success for successful background process"
      (sleep 0.01; exit 0) &
      pid=$!
      When call show_progress "$pid" "Testing" "Done"
      The status should be success
      The output should include "✓"
      The output should include "Done"
    End

    It "returns failure for failed background process"
      (sleep 0.01; exit 1) &
      pid=$!
      When call show_progress "$pid" "Testing"
      The status should be failure
      The output should include "✗"
      The output should include "Testing"
    End

    It "shows done message on success"
      (exit 0) &
      pid=$!
      When call show_progress "$pid" "Processing" "Completed successfully"
      The status should be success
      The output should include "Completed successfully"
    End

    It "shows original message on failure"
      (exit 1) &
      pid=$!
      When call show_progress "$pid" "Installation"
      The status should be failure
      The output should include "Installation"
    End

    It "suppresses output with --silent flag"
      (exit 0) &
      pid=$!
      When call show_progress "$pid" "Silent task" "--silent"
      The status should be success
      The output should be blank
    End

    It "suppresses output with --silent as fourth arg"
      (exit 0) &
      pid=$!
      When call show_progress "$pid" "Task" "Done message" "--silent"
      The status should be success
      The output should be blank
    End
  End

  # ===========================================================================
  # format_wizard_header()
  # ===========================================================================
  Describe "format_wizard_header()"
    It "prints title"
      When call format_wizard_header "Network"
      The output should include "Network"
    End

    It "includes orange color for title"
      When call format_wizard_header "Storage"
      The output should include "$CLR_ORANGE"
    End

    It "includes line characters"
      When call format_wizard_header "Basic"
      The output should include "━"
      The output should include "─"
    End

    It "includes dot marker"
      When call format_wizard_header "Services"
      The output should include "●"
    End

    It "handles empty title"
      When call format_wizard_header ""
      The status should be success
      The output should include "●"
    End

    It "handles long title"
      When call format_wizard_header "Very Long Title That Might Overflow"
      The status should be success
      The output should include "Very Long Title"
    End

    It "includes reset color at end"
      When call format_wizard_header "Access"
      The output should include "$CLR_RESET"
    End

    It "includes gray color for right line"
      When call format_wizard_header "Proxmox"
      The output should include "$CLR_GRAY"
    End

    It "includes cyan color for left line"
      When call format_wizard_header "Settings"
      The output should include "$CLR_CYAN"
    End
  End
End
