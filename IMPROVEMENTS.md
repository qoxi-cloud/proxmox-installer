# Project Improvements - Remaining Items

**Last Updated:** 2025-12-18

---

## Remaining Enhancements

### 1. SSH Post-Quantum Key Exchange (Optional)
**File:** `templates/sshd_config.tmpl`
**Status:** Current config is already secure (SSH keys only)

**Enhancement - Add post-quantum ready algorithms (OpenSSH 8.5+):**
```bash
KexAlgorithms sntrup761x25519-sha512@openssh.com,curve25519-sha256,curve25519-sha256@libssh.org,diffie-hellman-group16-sha512,diffie-hellman-group18-sha512
```

**Note:** Optional future-proofing, not critical for security

---

### 2. Unattended Upgrades Auto-Reboot (Make Configurable)
**File:** `templates/50unattended-upgrades.tmpl`
**Current:** `Automatic-Reboot "false"` (hardcoded)

**Enhancement - Add wizard option:**
```bash
# In wizard:
AUTO_REBOOT="${AUTO_REBOOT:-false}"

# In template:
Unattended-Upgrade::Automatic-Reboot "{{AUTO_REBOOT}}";
Unattended-Upgrade::Automatic-Reboot-Time "04:00";
Unattended-Upgrade::Automatic-Reboot-WithUsers "false";
Unattended-Upgrade::Mail "root";
Unattended-Upgrade::MailReport "only-on-error";
```

---

### 3. Structured Logging (JSON) - Nice-to-Have
**File:** `scripts/02-logging.sh`
**Enhancement:** Machine-readable logs for parsing/monitoring

```bash
log_json() {
  local level="$1"
  local message="$2"

  [[ "${LOG_FORMAT}" != "json" ]] && return

  jq -n \
    --arg ts "$(date -u +%Y-%m-%dT%H:%M:%SZ)" \
    --arg lvl "$level" \
    --arg msg "$message" \
    '{timestamp: $ts, level: $lvl, message: $msg}' \
    >> "${LOG_FILE}.json" 2>/dev/null || true
}
```

---

## Completed Items (Removed from this list)

- ✅ Kernel Security Parameters (unprivileged_userns_clone, unprivileged_bpf, etc.)
- ✅ Security Packages (aide, chkrootkit, sysstat, nethogs, ethtool)
- ✅ SSH Key Validation (validate_ssh_key_secure with key type/bits check)
- ✅ Network Performance Tuning (TCP buffers, VPN optimizations)
- ✅ DNS Resolution Retry (3-attempt retry with delay)
- ✅ Template Variable Validation (validate_template_vars)
- ✅ Fail2Ban Recidive Jail (2-week ban for repeat offenders)
- ✅ ZFS ARC Configuration (vm-focused/balanced/storage-focused)
- ✅ Configurable Bridge MTU
- ✅ IPv6 Router Advertisement Support
- ✅ Installation Metrics Collection
- ✅ Disk Space Validation
- ✅ AppArmor Configuration
