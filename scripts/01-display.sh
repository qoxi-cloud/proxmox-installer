# shellcheck shell=bash
# =============================================================================
# Display utilities
# =============================================================================

# Display a boxed section with title using 'boxes'
# Usage: display_box "title" "content"
display_box() {
    local title="$1"
    local content="$2"
    local box_style="${3:-stone}"

    echo -e "${CLR_BLUE}"
    {
        echo "$title"
        echo ""
        echo "$content"
    } | boxes -d "$box_style" -p a1
    echo -e "${CLR_RESET}"
}

# Display system info table using boxes and column
# Takes associative array-like pairs: "label|value|status"
# status: ok=green, warn=yellow, error=red
display_info_table() {
    local title="$1"
    shift
    local items=("$@")

    local content=""
    for item in "${items[@]}"; do
        local label="${item%%|*}"
        local rest="${item#*|}"
        local value="${rest%%|*}"
        local status="${rest#*|}"

        case "$status" in
            ok)    content+="[OK]     $label: $value"$'\n' ;;
            warn)  content+="[WARN]   $label: $value"$'\n' ;;
            error) content+="[ERROR]  $label: $value"$'\n' ;;
            *)     content+="         $label: $value"$'\n' ;;
        esac
    done

    # Remove trailing newline and display
    content="${content%$'\n'}"

    echo ""
    {
        echo "=== $title ==="
        echo ""
        echo "$content"
    } | boxes -d stone -p a1
    echo ""
}

# Colorize the output of boxes (post-process)
# Adds cyan frame and colors for [OK], [WARN], [ERROR]
colorize_status() {
    local cyan=$'\033[1;36m'
    local green=$'\033[1;32m'
    local yellow=$'\033[1;33m'
    local red=$'\033[1;31m'
    local reset=$'\033[m'

    while IFS= read -r line; do
        # Top/bottom border
        if [[ "$line" =~ ^\+[-+]+\+$ ]]; then
            echo "${cyan}${line}${reset}"
        # Content line with | borders
        elif [[ "$line" =~ ^(\|)(.*)\|$ ]]; then
            local content="${BASH_REMATCH[2]}"
            # Color status markers
            content="${content//\[OK\]/${green}[OK]${reset}}"
            content="${content//\[WARN\]/${yellow}[WARN]${reset}}"
            content="${content//\[ERROR\]/${red}[ERROR]${reset}}"
            echo "${cyan}|${reset}${content}${cyan}|${reset}"
        else
            echo "$line"
        fi
    done
}

# Print success message with checkmark
print_success() {
    echo -e "${CLR_GREEN}✓${CLR_RESET} $1"
}

# Print error message with cross
print_error() {
    echo -e "${CLR_RED}✗${CLR_RESET} $1"
}

# Print warning message
print_warning() {
    echo -e "${CLR_YELLOW}⚠${CLR_RESET} $1"
}

# Print info message
print_info() {
    echo -e "${CLR_CYAN}ℹ${CLR_RESET} $1"
}
