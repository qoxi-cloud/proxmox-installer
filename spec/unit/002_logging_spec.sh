# shellcheck shell=bash
# shellcheck disable=SC2016
# =============================================================================
# Tests for 002-logging.sh
# =============================================================================
# Note: SC2016 disabled - ShellSpec hooks use single quotes by design

%const SCRIPTS_DIR: "${SHELLSPEC_PROJECT_ROOT}/scripts"

Describe "002-logging.sh"
# Set up LOG_FILE before including script
BeforeAll 'LOG_FILE="/tmp/test_$$.log"; export LOG_FILE'
AfterAll 'rm -f "$LOG_FILE"'
BeforeEach 'echo -n > "$LOG_FILE"'

Include "$SCRIPTS_DIR/002-logging.sh"

Describe "log()"
It "writes message to LOG_FILE"
When call log "Test message"
The contents of file "$LOG_FILE" should include "Test message"
End

It "includes timestamp"
When call log "Test"
The contents of file "$LOG_FILE" should match pattern '*[0-9][0-9][0-9][0-9]-[0-9][0-9]-[0-9][0-9]*'
End

It "handles multiple arguments"
When call log "First" "Second" "Third"
The contents of file "$LOG_FILE" should include "First Second Third"
End
End

Describe "metrics_start()"
It "sets INSTALL_START_TIME"
When call metrics_start
The variable INSTALL_START_TIME should be defined
End

It "logs installation_started metric"
When call metrics_start
The contents of file "$LOG_FILE" should include "METRIC: installation_started"
End
End

Describe "log_metric()"
BeforeEach 'INSTALL_START_TIME=$(date +%s)'

It "logs step name"
When call log_metric "iso_download"
The contents of file "$LOG_FILE" should include "iso_download_completed"
End

It "includes elapsed time"
When call log_metric "test_step"
The contents of file "$LOG_FILE" should include "elapsed="
End
End

Describe "metrics_finish()"
BeforeEach 'INSTALL_START_TIME=$(date +%s)'

It "logs installation_completed"
When call metrics_finish
The contents of file "$LOG_FILE" should include "installation_completed"
End

It "includes total_time"
When call metrics_finish
The contents of file "$LOG_FILE" should include "total_time="
End
End
End
