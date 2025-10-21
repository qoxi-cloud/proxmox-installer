# shellcheck shell=bash
# =============================================================================
# Banner display
# Note: cursor cleanup is handled by cleanup_and_error_handler in 00-init.sh
# =============================================================================

# Display main ASCII banner
# Usage: show_banner [--no-info]
# shellcheck disable=SC2120
show_banner() {
    local show_info=true
    [[ "$1" == "--no-info" ]] && show_info=false

    echo -e "${CLR_CYAN}         ____"
    echo -e "        |  _ \\ _ __ _____  ___ __ ___   _____  __"
    echo -e "        | |_) | '__/ _ \\ \\/ / '\`_ \` _ \\ / _ \\ \\/ /"
    echo -e "        |  __/| | | (_) ${CLR_YELLOW}>${CLR_CYAN}  ${CLR_YELLOW}<${CLR_CYAN}| | | | | | (_) ${CLR_YELLOW}>${CLR_CYAN}  ${CLR_YELLOW}<${CLR_CYAN}"
    echo -e "        |_|   |_|  \\___/_/${CLR_YELLOW}\\${CLR_CYAN}_${CLR_YELLOW}\\${CLR_CYAN}_| |_| |_|\\___/_/${CLR_YELLOW}\\${CLR_CYAN}_${CLR_YELLOW}\\${CLR_CYAN}"
    echo -e ""
    echo -e "            Hetzner Automated Installer"
    echo -e "${CLR_RESET}"

    if [[ "$show_info" == true ]]; then
        echo -e "${CLR_YELLOW}Version: ${VERSION}${CLR_RESET}"
        echo -e "${CLR_YELLOW}Log file: ${LOG_FILE}${CLR_RESET}"
        if [[ -n "$CONFIG_FILE" ]]; then
            echo -e "${CLR_YELLOW}Config: ${CONFIG_FILE}${CLR_RESET}"
        fi
        if [[ "$NON_INTERACTIVE" == true ]]; then
            echo -e "${CLR_YELLOW}Mode: Non-interactive${CLR_RESET}"
        fi
        if [[ "$TEST_MODE" == true ]]; then
            echo -e "${CLR_YELLOW}Mode: Test (TCG emulation, no KVM)${CLR_RESET}"
        fi
    fi
    echo ""
}

# =============================================================================
# Show banner on startup
# =============================================================================
clear
show_banner
