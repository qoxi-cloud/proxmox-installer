# shellcheck shell=bash
# =============================================================================
# Display utilities
# =============================================================================

# Prints success message with checkmark.
# Parameters:
#   $1 - Label or full message
#   $2 - Optional value (highlighted in cyan)
print_success() {
  local msg
  if [[ $# -eq 2 ]]; then
    msg="${CLR_CYAN}✓${CLR_RESET} $1 ${CLR_CYAN}$2${CLR_RESET}"
  else
    msg="${CLR_CYAN}✓${CLR_RESET} $1"
  fi

  if [[ ${LIVE_LOGS_ACTIVE:-false} == true ]]; then
    add_log "${CLR_GRAY}├─${CLR_RESET} $msg"
  else
    echo -e "$msg"
  fi
}

# Prints error message with red cross icon.
# Parameters:
#   $1 - Error message to display
print_error() {
  local msg="${CLR_RED}✗${CLR_RESET} $1"

  if [[ ${LIVE_LOGS_ACTIVE:-false} == true ]]; then
    add_log "${CLR_GRAY}├─${CLR_RESET} $msg"
  else
    echo -e "$msg"
  fi
}

# Prints warning message with yellow warning icon.
# Parameters:
#   $1 - Warning message or label
#   $2 - Optional: "true" for nested indent, or value to highlight in cyan
print_warning() {
  local message="$1"
  local second="${2:-false}"
  local indent=""
  local msg

  # Check if second argument is a value (not "true" for nested)
  if [[ $# -eq 2 && $second != "true" ]]; then
    # Two-argument format: label and value
    msg="${CLR_YELLOW}⚠️${CLR_RESET} $message ${CLR_CYAN}$second${CLR_RESET}"
  else
    # Original format: message with optional nested indent
    if [[ $second == "true" ]]; then
      indent="  "
    fi
    msg="${indent}${CLR_YELLOW}⚠️${CLR_RESET} $message"
  fi

  if [[ ${LIVE_LOGS_ACTIVE:-false} == true ]]; then
    add_log "${CLR_GRAY}├─${CLR_RESET} $msg"
  else
    echo -e "$msg"
  fi
}

# Prints informational message with cyan info symbol.
# Parameters:
#   $1 - Informational message to display
print_info() {
  local msg="${CLR_CYAN}ℹ${CLR_RESET} $1"

  if [[ ${LIVE_LOGS_ACTIVE:-false} == true ]]; then
    add_log "${CLR_GRAY}├─${CLR_RESET} $msg"
  else
    echo -e "$msg"
  fi
}

# Prints section header in cyan bold.
# Parameters:
#   $1 - Section header text
print_section() {
  echo "${CLR_CYAN}${CLR_BOLD}$1${CLR_RESET}"
}

# =============================================================================
# Progress indicators
# =============================================================================

# Shows progress indicator with gum spinner while process runs.
# Parameters:
#   $1 - PID of process to wait for
#   $2 - Progress message
#   $3 - Optional done message or "--silent" to clear line on success
#   $4 - Optional "--silent" flag
# Returns: Exit code of the waited process
show_progress() {
  local pid=$1
  local message="${2:-Processing}"
  local done_message="${3:-$message}"
  local silent=false
  [[ ${3:-} == "--silent" || ${4:-} == "--silent" ]] && silent=true
  [[ ${3:-} == "--silent" ]] && done_message="$message"

  # Use gum spin to wait for the process
  gum spin --spinner meter --spinner.foreground "#ff8700" --title "$message" -- bash -c "
    while kill -0 $pid 2>/dev/null; do
      sleep 0.2
    done
  "

  # Get exit code from the original process
  wait "$pid" 2>/dev/null
  local exit_code=$?

  if [[ $exit_code -eq 0 ]]; then
    if [[ $silent != true ]]; then
      printf "${CLR_CYAN}✓${CLR_RESET} %s\n" "$done_message"
    fi
  else
    printf "${CLR_RED}✗${CLR_RESET} %s\n" "$message"
  fi

  return $exit_code
}
