#!/usr/bin/env bash
# =============================================================================
# Gum Demo Script - Showcase gum features with project colors
# =============================================================================

set -euo pipefail

# Project colors (from 00-init.sh)
# CLR_RED='#ff0000' (bold red)
# CLR_CYAN='#00b1ff' (RGB: 0, 177, 255)
# CLR_YELLOW='#ffff00' (bold yellow)
# CLR_ORANGE - ANSI 256 color 208 = #ff8700
# CLR_GRAY - ANSI 256 color 240 = #585858
# CLR_HETZNER - ANSI 256 color 160 = #d70000

# Hex colors for gum
COLOR_RED="#ff0000"
COLOR_CYAN="#00b1ff"
COLOR_YELLOW="#ffff00"
COLOR_ORANGE="#ff8700"
COLOR_GRAY="#585858"
COLOR_HETZNER="#d70000"
COLOR_GREEN="#00ff00"
COLOR_WHITE="#ffffff"
COLOR_MUTED="#585858"
COLOR_ACCENT="#ff8700"

# Check if gum is installed
if ! command -v gum &>/dev/null; then
  echo "Error: gum is not installed"
  echo "Install with: brew install gum (macOS) or see https://github.com/charmbracelet/gum"
  exit 1
fi

clear

# =============================================================================
# 1. Styled Text (gum style)
# =============================================================================
echo ""
gum style \
  --foreground "$COLOR_ORANGE" \
  --border-foreground "$COLOR_GRAY" \
  --border double \
  --align center \
  --width 60 \
  --margin "1 2" \
  --padding "1 2" \
  "Proxmox Installer" \
  "Gum Features Demo"

# =============================================================================
# 2. Spinner (gum spin)
# =============================================================================
echo ""
gum style --foreground "$COLOR_CYAN" "1. SPINNER DEMO"
echo ""

gum spin --spinner dot --title "Loading with dot spinner..." -- sleep 1
gum spin --spinner line --title "Loading with line spinner..." --title.foreground "$COLOR_ORANGE" -- sleep 1
gum spin --spinner minidot --title "Loading with minidot spinner..." --title.foreground "$COLOR_CYAN" -- sleep 1
gum spin --spinner jump --title "Loading with jump spinner..." --title.foreground "$COLOR_YELLOW" -- sleep 1
gum spin --spinner pulse --title "Loading with pulse spinner..." --title.foreground "$COLOR_HETZNER" -- sleep 1
gum spin --spinner points --title "Loading with points spinner..." --title.foreground "$COLOR_GREEN" -- sleep 1
gum spin --spinner globe --title "Loading with globe spinner..." --title.foreground "$COLOR_ORANGE" -- sleep 1
gum spin --spinner moon --title "Loading with moon spinner..." --title.foreground "$COLOR_CYAN" -- sleep 1
gum spin --spinner monkey --title "Loading with monkey spinner..." -- sleep 1
gum spin --spinner meter --title "Loading with meter spinner..." --title.foreground "$COLOR_ORANGE" -- sleep 1
gum spin --spinner hamburger --title "Loading with hamburger spinner..." -- sleep 1

echo ""
gum style --foreground "$COLOR_GREEN" "✓ Spinner demo complete"

# =============================================================================
# 3. Confirm Dialog (gum confirm)
# =============================================================================
echo ""
gum style --foreground "$COLOR_CYAN" "2. CONFIRM DIALOG DEMO"
echo ""

if gum confirm "Do you want to continue with the demo?" \
  --affirmative "Yes, continue" \
  --negative "No, skip" \
  --prompt.foreground "$COLOR_ORANGE" \
  --selected.background "$COLOR_ORANGE" \
  --unselected.foreground "$COLOR_GRAY"; then
  gum style --foreground "$COLOR_GREEN" "✓ You confirmed!"
else
  gum style --foreground "$COLOR_YELLOW" "○ You declined"
fi

# =============================================================================
# 4. Choose (Single Select) (gum choose)
# =============================================================================
echo ""
gum style --foreground "$COLOR_CYAN" "3. SINGLE SELECT DEMO (gum choose)"
echo ""

CHOICE=$(gum choose \
  --cursor.foreground "$COLOR_ORANGE" \
  --selected.foreground "$COLOR_ORANGE" \
  --header "Select installation type:" \
  --header.foreground "$COLOR_GRAY" \
  "Standard Installation" \
  "Advanced Installation" \
  "Minimal Installation" \
  "Custom Installation")

gum style --foreground "$COLOR_GREEN" "✓ Selected: $CHOICE"

# =============================================================================
# 5. Choose (Multi Select) (gum choose --no-limit)
# =============================================================================
echo ""
gum style --foreground "$COLOR_CYAN" "4. MULTI SELECT DEMO (gum choose --no-limit)"
echo ""

PACKAGES=$(gum choose --no-limit \
  --cursor.foreground "$COLOR_ORANGE" \
  --selected.foreground "$COLOR_GREEN" \
  --header "Select packages to install:" \
  --header.foreground "$COLOR_GRAY" \
  "Tailscale VPN" \
  "Fail2Ban" \
  "Auditd" \
  "ZSH + Oh-My-ZSH" \
  "Fastfetch")

echo ""
gum style --foreground "$COLOR_GREEN" "✓ Selected packages:"
echo "$PACKAGES" | while read -r pkg; do
  gum style --foreground "$COLOR_WHITE" "  • $pkg"
done

# =============================================================================
# 6. Input (gum input)
# =============================================================================
echo ""
gum style --foreground "$COLOR_CYAN" "5. TEXT INPUT DEMO (gum input)"
echo ""

HOSTNAME=$(gum input \
  --placeholder "Enter hostname (e.g., pve01)" \
  --prompt "> " \
  --prompt.foreground "$COLOR_ORANGE" \
  --cursor.foreground "$COLOR_ORANGE" \
  --width 40 \
  --value "pve01")

gum style --foreground "$COLOR_GREEN" "✓ Hostname: $HOSTNAME"

# Password input
echo ""
PASSWORD=$(gum input \
  --password \
  --placeholder "Enter password" \
  --prompt "Password: " \
  --prompt.foreground "$COLOR_ORANGE" \
  --cursor.foreground "$COLOR_ORANGE" \
  --width 40)

gum style --foreground "$COLOR_GREEN" "✓ Password entered (${#PASSWORD} characters)"

# =============================================================================
# 7. Write (Multi-line input) (gum write)
# =============================================================================
echo ""
gum style --foreground "$COLOR_CYAN" "6. MULTI-LINE INPUT DEMO (gum write)"
echo ""
gum style --foreground "$COLOR_GRAY" "Press Ctrl+D or Esc to finish"
echo ""

NOTES=$(gum write \
  --placeholder "Enter installation notes..." \
  --char-limit 500 \
  --width 60 \
  --height 5 \
  --header "Installation Notes" \
  --header.foreground "$COLOR_ORANGE" \
  --cursor.foreground "$COLOR_ORANGE")

echo ""
if [[ -n "$NOTES" ]]; then
  gum style --foreground "$COLOR_GREEN" "✓ Notes saved"
else
  gum style --foreground "$COLOR_YELLOW" "○ No notes entered"
fi

# =============================================================================
# 8. Filter (Fuzzy search) (gum filter)
# =============================================================================
echo ""
gum style --foreground "$COLOR_CYAN" "7. FUZZY FILTER DEMO (gum filter)"
echo ""

TIMEZONES="Europe/Kyiv
Europe/London
Europe/Berlin
Europe/Paris
Europe/Moscow
America/New_York
America/Los_Angeles
America/Chicago
Asia/Tokyo
Asia/Shanghai
Australia/Sydney
Pacific/Auckland"

TIMEZONE=$(echo "$TIMEZONES" | gum filter \
  --placeholder "Search timezone..." \
  --prompt "> " \
  --prompt.foreground "$COLOR_ORANGE" \
  --indicator.foreground "$COLOR_ORANGE" \
  --match.foreground "$COLOR_GREEN" \
  --header "Select timezone:" \
  --header.foreground "$COLOR_GRAY" \
  --height 10)

gum style --foreground "$COLOR_GREEN" "✓ Selected: $TIMEZONE"

# =============================================================================
# 9. File Browser (gum file)
# =============================================================================
echo ""
gum style --foreground "$COLOR_CYAN" "8. FILE BROWSER DEMO (gum file)"
echo ""
gum style --foreground "$COLOR_GRAY" "Navigate with arrows, Enter to select, Esc to cancel"
echo ""

if FILE=$(gum file \
  --cursor.foreground "$COLOR_ORANGE" \
  --symlink.foreground "$COLOR_CYAN" \
  --directory.foreground "$COLOR_ORANGE" \
  --file.foreground "$COLOR_WHITE" \
  --permissions.foreground "$COLOR_GRAY" \
  --selected.foreground "$COLOR_GREEN" \
  --height 10 \
  /tmp 2>/dev/null); then
  gum style --foreground "$COLOR_GREEN" "✓ Selected: $FILE"
else
  gum style --foreground "$COLOR_YELLOW" "○ No file selected"
fi

# =============================================================================
# 10. Table (gum table)
# =============================================================================
echo ""
gum style --foreground "$COLOR_CYAN" "9. TABLE DEMO (gum table)"
echo ""

echo "Check,Item,Status
[OK],Root Access,Running as root
[OK],Internet,Available
[OK],Disk Space,15000 MB
[OK],RAM,32768 MB
[OK],CPU,8 cores
[OK],KVM,Available" | gum table \
  --border.foreground "$COLOR_GRAY" \
  --cell.foreground "$COLOR_WHITE" \
  --header.foreground "$COLOR_ORANGE"

# =============================================================================
# 11. Format (Markdown/Code rendering) (gum format)
# =============================================================================
echo ""
gum style --foreground "$COLOR_CYAN" "10. FORMAT DEMO (gum format)"
echo ""

gum format << 'EOF'
# Installation Summary

**Hostname:** pve01.example.com
**IP Address:** 192.168.1.100

## Installed Packages
- Proxmox VE 8.3
- Tailscale VPN
- ZSH with Oh-My-ZSH

## Next Steps
1. Access web UI at `https://192.168.1.100:8006`
2. Login with root credentials
3. Configure storage pools

```bash
# Check Proxmox status
systemctl status pvedaemon
```
EOF

# =============================================================================
# 12. Join (Combine strings) (gum join)
# =============================================================================
echo ""
gum style --foreground "$COLOR_CYAN" "11. JOIN DEMO (gum join)"
echo ""

LEFT=$(gum style \
  --foreground "$COLOR_ORANGE" \
  --border-foreground "$COLOR_GRAY" \
  --border rounded \
  --padding "1 2" \
  "Left Panel" \
  "Content here")

RIGHT=$(gum style \
  --foreground "$COLOR_CYAN" \
  --border-foreground "$COLOR_GRAY" \
  --border rounded \
  --padding "1 2" \
  "Right Panel" \
  "More content")

gum join --horizontal "$LEFT" "$RIGHT"

# =============================================================================
# 13. Pager (gum pager)
# =============================================================================
echo ""
gum style --foreground "$COLOR_CYAN" "12. PAGER DEMO (gum pager)"
echo ""
gum style --foreground "$COLOR_GRAY" "Press q to exit pager"
echo ""

cat << 'EOF' | gum pager --soft-wrap --border rounded --border-foreground "#585858"
# Proxmox Installation Log

This is a demo of the gum pager feature. In a real scenario, this would show
installation logs or configuration details.

== System Information ==
Hostname: pve01.example.com
IP: 192.168.1.100
RAM: 32GB
CPU: 8 cores

== Installation Steps ==
1. Download Proxmox ISO
2. Verify checksum
3. Create autoinstall ISO
4. Boot QEMU with ISO
5. Wait for installation
6. Configure via SSH
7. Reboot to installed system

== Configuration Applied ==
- ZFS RAID mirror on nvme0n1, nvme1n1
- Network bridge vmbr0 configured
- SSL certificate installed
- SSH hardening applied

== Post-Installation ==
- Tailscale connected
- Fail2Ban configured
- Auditd enabled
EOF

# =============================================================================
# Summary
# =============================================================================
echo ""
gum style \
  --foreground "$COLOR_GREEN" \
  --border-foreground "$COLOR_ORANGE" \
  --border double \
  --align center \
  --width 60 \
  --margin "1 2" \
  --padding "1 2" \
  "Demo Complete!" \
  "" \
  "All gum features demonstrated successfully"

echo ""
