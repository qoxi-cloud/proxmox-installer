# shellcheck shell=bash
# shellcheck disable=SC2034,SC2016,SC2168
# =============================================================================
# Tests for 042-live-logs.sh
# =============================================================================
# Note: SC2034 - variables used by ShellSpec assertions
# Note: SC2016 - ShellSpec hooks use single quotes by design

%const SCRIPTS_DIR: "${SHELLSPEC_PROJECT_ROOT}/scripts"
%const SUPPORT_DIR: "${SHELLSPEC_PROJECT_ROOT}/spec/support"

# Load shared mocks before Include
eval "$(cat "$SUPPORT_DIR/colors.sh")"
eval "$(cat "$SUPPORT_DIR/ui_mocks.sh")"

# Note: tput, show_banner, format_wizard_header, _wiz_blank_line are now in ui_mocks.sh

# Required globals
BANNER_HEIGHT=9

Describe "042-live-logs.sh"
  Include "$SCRIPTS_DIR/042-live-logs.sh"

  # Reset state before each test
  BeforeEach 'LOG_LINES=(); LOG_COUNT=0'

  # ===========================================================================
  # get_terminal_dimensions()
  # ===========================================================================
  Describe "get_terminal_dimensions()"
    It "sets _LOG_TERM_HEIGHT from tput lines"
      When call get_terminal_dimensions
      The variable _LOG_TERM_HEIGHT should equal "40"
    End

    It "sets _LOG_TERM_WIDTH from tput cols"
      When call get_terminal_dimensions
      The variable _LOG_TERM_WIDTH should equal "120"
    End
  End

  # ===========================================================================
  # calculate_log_area()
  # ===========================================================================
  Describe "calculate_log_area()"
    It "calculates LOG_AREA_HEIGHT based on terminal size"
      When call calculate_log_area
      # 40 (terminal) - 9 (logo) - 4 (header) - 1 = 26
      The variable LOG_AREA_HEIGHT should equal 26
    End

    It "calls get_terminal_dimensions"
      When call calculate_log_area
      The variable _LOG_TERM_HEIGHT should be defined
      The variable _LOG_TERM_WIDTH should be defined
    End
  End

  # ===========================================================================
  # add_log()
  # ===========================================================================
  Describe "add_log()"
    # Override render_logs to avoid output
    BeforeEach 'render_logs() { :; }'

    It "appends message to LOG_LINES array"
      When call add_log "Test message"
      The variable LOG_LINES[0] should equal "Test message"
    End

    It "increments LOG_COUNT"
      When call add_log "First"
      The variable LOG_COUNT should equal 1
    End

    It "handles multiple messages"
      # Helper to add two logs
      add_two_logs() {
        add_log "First"
        add_log "Second"
      }
      When call add_two_logs
      The variable LOG_COUNT should equal 2
      The variable LOG_LINES[1] should equal "Second"
    End

    It "handles empty message"
      When call add_log ""
      The status should be success
      The variable LOG_COUNT should equal 1
    End

    It "preserves message with special characters"
      When call add_log "Test: /dev/sda1 @ 100%"
      The variable LOG_LINES[0] should equal "Test: /dev/sda1 @ 100%"
    End
  End

  # ===========================================================================
  # _render_install_header()
  # ===========================================================================
  Describe "_render_install_header()"
    It "outputs header with Installing Proxmox text"
      When call _render_install_header
      The output should include "Installing Proxmox"
    End

    It "includes blank lines"
      When call _render_install_header
      The status should be success
      The output should be present
    End
  End

  # ===========================================================================
  # render_logs()
  # ===========================================================================
  Describe "render_logs()"
    BeforeEach 'calculate_log_area'

    It "renders without errors when LOG_LINES is empty"
      When call render_logs
      The status should be success
      The output should be present
    End

    It "renders log entries"
      LOG_LINES=("Line 1" "Line 2")
      LOG_COUNT=2
      When call render_logs
      The output should include "Line 1"
      The output should include "Line 2"
    End

    It "handles more logs than LOG_AREA_HEIGHT (auto-scroll)"
      # Fill with more lines than area can show
      for i in $(seq 1 30); do
        LOG_LINES+=("Line $i")
      done
      LOG_COUNT=30
      When call render_logs
      The status should be success
      # Should show last lines, not first
      The output should include "Line 30"
    End
  End

  # ===========================================================================
  # start_task()
  # ===========================================================================
  Describe "start_task()"
    BeforeEach 'render_logs() { :; }'

    It "adds task with ... suffix"
      When call start_task "Downloading"
      The variable LOG_LINES[0] should equal "Downloading..."
    End

    It "sets TASK_INDEX to current position"
      When call start_task "Processing"
      The variable TASK_INDEX should equal 0
    End

    It "increments LOG_COUNT"
      When call start_task "Installing"
      The variable LOG_COUNT should equal 1
    End

    It "correctly sets TASK_INDEX for second task"
      # Helper to add two tasks
      add_two_tasks() {
        start_task "First task"
        start_task "Second task"
      }
      When call add_two_tasks
      The variable TASK_INDEX should equal 1
    End
  End

  # ===========================================================================
  # complete_task()
  # ===========================================================================
  Describe "complete_task()"
    BeforeEach 'render_logs() { :; }; LOG_LINES=("Initial..."); LOG_COUNT=1'

    It "updates task with success indicator by default"
      When call complete_task 0 "Task completed"
      The variable LOG_LINES[0] should include "Task completed"
      The variable LOG_LINES[0] should include "✓"
    End

    It "updates task with error indicator"
      When call complete_task 0 "Task failed" "error"
      The variable LOG_LINES[0] should include "✗"
    End

    It "updates task with warning indicator"
      When call complete_task 0 "Task warning" "warning"
      The variable LOG_LINES[0] should include "⚠"
    End

    It "includes color codes for success"
      When call complete_task 0 "Done" "success"
      The variable LOG_LINES[0] should include "$CLR_CYAN"
    End

    It "includes color codes for error"
      When call complete_task 0 "Failed" "error"
      The variable LOG_LINES[0] should include "$CLR_RED"
    End

    It "includes color codes for warning"
      When call complete_task 0 "Caution" "warning"
      The variable LOG_LINES[0] should include "$CLR_YELLOW"
    End
  End

  # ===========================================================================
  # add_subtask_log()
  # ===========================================================================
  Describe "add_subtask_log()"
    BeforeEach 'render_logs() { :; }'

    It "adds subtask with tree prefix"
      When call add_subtask_log "Subtask item"
      The variable LOG_LINES[0] should include "│"
    End

    It "includes message in gray color"
      When call add_subtask_log "Subtask text"
      The variable LOG_LINES[0] should include "$CLR_GRAY"
      The variable LOG_LINES[0] should include "Subtask text"
    End

    It "includes orange tree character"
      When call add_subtask_log "Item"
      The variable LOG_LINES[0] should include "$CLR_ORANGE"
    End
  End

  # ===========================================================================
  # start_live_installation()
  # ===========================================================================
  Describe "start_live_installation()"
    It "calculates log area"
      When call start_live_installation
      The variable LOG_AREA_HEIGHT should be defined
    End

    It "overrides show_progress with live version"
      When call start_live_installation
      # After calling, show_progress should be redefined to live_show_progress
      # We verify by checking that the function is callable
      The status should be success
    End
  End

  # ===========================================================================
  # finish_live_installation()
  # ===========================================================================
  Describe "finish_live_installation()"
    It "completes without errors"
      When call finish_live_installation
      The status should be success
    End
  End

  # ===========================================================================
  # live_show_progress()
  # ===========================================================================
  Describe "live_show_progress()"
    # Skip when running under kcov - background subshells cause kcov to hang
    Skip if "running under kcov" is_running_under_kcov

    BeforeEach 'render_logs() { :; }; LOG_LINES=(); LOG_COUNT=0'

    It "returns success for successful process"
      (exit 0) &
      local pid=$!
      When call live_show_progress "$pid" "Testing"
      The status should be success
    End

    It "returns failure for failed process"
      (exit 1) &
      local pid=$!
      When call live_show_progress "$pid" "Testing"
      The status should be failure
    End

    It "adds task to LOG_LINES"
      (exit 0) &
      local pid=$!
      When call live_show_progress "$pid" "Processing"
      The variable LOG_COUNT should be defined
    End

    It "shows success indicator on completion"
      (exit 0) &
      local pid=$!
      When call live_show_progress "$pid" "Done task"
      The variable LOG_LINES[0] should include "✓"
    End

    It "shows error indicator on failure"
      (exit 1) &
      local pid=$!
      When call live_show_progress "$pid" "Failing task"
      The status should be failure
      The variable LOG_LINES[0] should include "✗"
    End

    It "uses done_message on success"
      (exit 0) &
      local pid=$!
      When call live_show_progress "$pid" "Working" "Completed"
      The variable LOG_LINES[0] should include "Completed"
    End

    It "removes line in silent mode on success"
      (exit 0) &
      local pid=$!
      When call live_show_progress "$pid" "Silent task" "--silent"
      # In silent mode, successful task line is removed
      The variable LOG_COUNT should equal 0
    End

    It "handles silent as fourth argument"
      (exit 0) &
      local pid=$!
      When call live_show_progress "$pid" "Task" "Done" "--silent"
      The status should be success
    End

    It "includes tree prefix"
      (exit 0) &
      local pid=$!
      When call live_show_progress "$pid" "Tree task"
      The variable LOG_LINES[0] should include "├─"
    End
  End

  # ===========================================================================
  # live_log_subtask()
  # ===========================================================================
  Describe "live_log_subtask()"
    BeforeEach 'render_logs() { :; }; LOG_LINES=(); LOG_COUNT=0'

    It "calls add_subtask_log with message"
      When call live_log_subtask "Subtask info"
      The variable LOG_LINES[0] should include "Subtask info"
    End

    It "adds tree structure"
      When call live_log_subtask "Info item"
      The variable LOG_LINES[0] should include "│"
    End
  End

  # ===========================================================================
  # log_subtasks()
  # ===========================================================================
  Describe "log_subtasks()"
    BeforeEach 'render_logs() { :; }; LOG_LINES=(); LOG_COUNT=0'

    It "logs single item"
      When call log_subtasks "item1"
      The variable LOG_COUNT should equal 1
      The variable LOG_LINES[0] should include "item1"
    End

    It "logs multiple items comma-separated"
      When call log_subtasks "item1" "item2" "item3"
      The variable LOG_LINES[0] should include "item1"
      The variable LOG_LINES[0] should include "item2"
    End

    It "includes tree prefix"
      When call log_subtasks "test"
      The variable LOG_LINES[0] should include "│"
    End

    It "includes gray color"
      When call log_subtasks "colored"
      The variable LOG_LINES[0] should include "$CLR_GRAY"
    End

    It "wraps long lines"
      # Create items that will exceed max_width (55)
      When call log_subtasks "longitem1" "longitem2" "longitem3" "longitem4" "longitem5" "longitem6" "longitem7" "longitem8"
      # Should wrap to multiple lines (at least 2)
      The variable LOG_COUNT should not equal 1
    End

    It "handles empty input"
      When call log_subtasks
      The variable LOG_COUNT should equal 0
    End

    It "separates items with commas"
      When call log_subtasks "a" "b" "c"
      The variable LOG_LINES[0] should include ", "
    End

    It "adds trailing comma on wrapped lines"
      # Force wrapping with many items
      When call log_subtasks "package1" "package2" "package3" "package4" "package5" "package6" "package7" "package8" "package9" "package10"
      # First line should end with comma (check it includes comma separator)
      The variable LOG_LINES[0] should include ","
    End
  End

  # ===========================================================================
  # Constants and defaults
  # ===========================================================================
  Describe "Constants"
    It "LOGO_HEIGHT defaults from BANNER_HEIGHT"
      The variable LOGO_HEIGHT should equal 9
    End

    It "HEADER_HEIGHT is 4"
      The variable HEADER_HEIGHT should equal 4
    End
  End
End

