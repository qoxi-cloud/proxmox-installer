# Code Review: Proxmox Installer

**Date:** 2026-01-01
**Reviewed:** 92 scripts across scripts/ directory

---

## Summary

The codebase is well-organized with consistent patterns, clear naming conventions, and thorough error handling. The architecture follows a logical execution flow from initialization through configuration phases. Below are identified patterns, bugs, and improvement opportunities.

---

## Patterns (Positive)

### 1. Consistent Function Naming Prefixes ✓
The codebase maintains excellent naming discipline:
- `_config_*` for private implementation functions
- `configure_*` for public wrapper functions
- `_wiz_*` for wizard UI primitives
- `_edit_*` for field editors
- `validate_*` for validation functions
- `_generate_*` for content generators

### 2. Feature Flag Pattern ✓
Consistent pattern for optional features:
```bash
configure_feature() {
  [[ $INSTALL_FEATURE != "yes" ]] && return 0
  _config_feature
}
```

### 3. Progress Display Pattern ✓
Consistent use of `run_with_progress` for operations:
```bash
run_with_progress "Doing thing" "Thing done" _helper_function
```

### 4. Template Deployment Pattern ✓
Well-established pipeline:
1. Stage template to temp file (preserves original)
2. Apply variable substitution
3. Validate no unsubstituted placeholders remain
4. Copy to destination
5. Clean up temp file

### 5. Error Handling Pattern ✓
Explicit error handling without `set -e`:
```bash
command || {
  log "ERROR: Operation failed"
  return 1
}
```

### 6. Sensitive Data Sanitization ✓
`_sanitize_script_for_log()` in 022-ssh-remote.sh properly masks passwords/secrets before logging.

---

## Potential Bugs

### 1. Race Condition in Parallel Group Progress Polling
**File:** `scripts/033-parallel-helpers.sh:194-200`

```bash
while ((running >= max_jobs)); do
  local completed=0
  for ((j = 0; j < i; j++)); do
    [[ -f "$result_dir/success_$j" || -f "$result_dir/fail_$j" ]] && ((completed++))
  done
  running=$((i - completed)) && ((running >= max_jobs)) && sleep 0.1
done
```

**Issue:** The `&& sleep 0.1` is chained to the assignment, which means sleep is only called if the assignment returns true (it always does). This creates a potential tight loop when `running >= max_jobs`.

**Suggestion:**
```bash
while ((running >= max_jobs)); do
  local completed=0
  for ((j = 0; j < i; j++)); do
    [[ -f "$result_dir/success_$j" || -f "$result_dir/fail_$j" ]] && ((completed++))
  done
  running=$((i - completed))
  ((running >= max_jobs)) && sleep 0.1
done
```

### 2. Unquoted Array Expansion in Package Installation
**File:** `scripts/033-parallel-helpers.sh:22`

```bash
apt-get install -yqq ${packages[*]}
```

**Issue:** Word splitting on package names is intentional here (via SC2206 disable), but if a package name ever contains a space (unlikely but possible), it would break.

**Suggestion:** Use `"${packages[@]}"` for safety, though this is low risk.

### 3. Missing Return Code Check in `_config_nftables`
**File:** `scripts/311-configure-firewall.sh:86-87`

```bash
local config_file="./templates/nftables.conf.generated"
_generate_nftables_conf >"$config_file"
```

**Issue:** If `_generate_nftables_conf` fails (write error, etc.), there's no check before proceeding.

**Suggestion:**
```bash
if ! _generate_nftables_conf >"$config_file"; then
  log "ERROR: Failed to generate nftables config"
  return 1
fi
```

### 4. Potential File Descriptor Leak in Animation Loop
**File:** `scripts/007-banner.sh:151-153`

```bash
exec 3>&1
[[ -c /dev/tty ]] && exec 1>/dev/tty
exec 2>/dev/null
```

**Issue:** FD 3 is opened but never closed in the animation loop. While this is in a subshell (so it will be cleaned up), it's not best practice.

**Suggestion:** Add cleanup or use a more localized redirect.

### 5. Missing Validation of ADMIN_USERNAME Before Use
**File:** `scripts/300-configure-base.sh:61`

```bash
remote_exec "chsh -s /bin/zsh ${ADMIN_USERNAME}" || return 1
```

**Issue:** While `require_admin_username` is called at the start of `_configure_zsh_files`, the check at line 148 in `_config_shell()` comes after the function call pattern makes this implicit but not obvious.

**Note:** This is more of a code clarity issue than a bug since the check exists.

---

## Improvements

### 1. Centralize Color Constants for Live Logs
**Current:** Tree characters use inline color codes:
```bash
"${CLR_ORANGE}├─${CLR_RESET}"
"${CLR_ORANGE}│${CLR_RESET}"
```

**Suggestion:** Define constants in `000-colors.sh`:
```bash
readonly TREE_BRANCH="${CLR_ORANGE}├─${CLR_RESET}"
readonly TREE_VERT="${CLR_ORANGE}│${CLR_RESET}"
readonly TREE_END="${CLR_ORANGE}└─${CLR_RESET}"
```

### 2. Add Timeout to DNS Resolution Fallback
**File:** `scripts/042-validation-dns.sh:123-128`

The system resolver fallback doesn't have a consistent timeout:
```bash
raw_output=$(timeout "$dns_timeout" dig +short +time=3 +tries=1 A "$fqdn" 2>/dev/null)
```

**Issue:** `+time=3` overrides the outer timeout, potentially causing inconsistent behavior.

**Suggestion:** Remove inner timeouts when using outer `timeout`:
```bash
raw_output=$(timeout "$dns_timeout" dig +short A "$fqdn" 2>/dev/null)
```

### 3. ~~Consider Using `declare -g` for Global Variable Assignments in Functions~~ ✓ FIXED
**Multiple files**

~~When assigning global variables in functions, `declare -g` makes intent explicit:~~
```bash
# Now implemented across all scripts
declare -g DNS_RESOLVED_IP="$resolved_ip"
```
**Status:** Fixed in 36 scripts with ~350 global variable assignments updated to use `declare -g`.

### 4. ~~Add Defensive Check for Empty VIRTIO_MAP~~ ✓ FIXED
**File:** `scripts/031-zfs-helpers.sh:91-96`

~~**Issue:** The check `[[ -z "$vdev" ]]` doesn't distinguish between VIRTIO_MAP not being initialized vs the disk key not existing.~~

```bash
# Now implemented with proper key existence check
if [[ -z "${VIRTIO_MAP[$disk]+isset}" ]]; then
  log "ERROR: VIRTIO_MAP not initialized or disk $disk not mapped"
  return 1
fi
```
**Status:** Fixed with `${VAR+isset}` pattern to properly detect uninitialized array or missing key.

### 5. ~~Consider Early Exit Pattern for Feature Checks~~ ✓ FIXED
**File:** `scripts/381-configure-phases.sh:70-77`

~~**Issue:** Repetitive async feature execution pattern with manual flag checks.~~

```bash
# Now implemented with async feature helpers
netdata_pid=$(start_async_feature "netdata" "INSTALL_NETDATA")
yazi_pid=$(start_async_feature "yazi" "INSTALL_YAZI")
# ... parallel work ...
wait_async_feature "netdata" "$netdata_pid"
wait_async_feature "yazi" "$yazi_pid"
```
**Status:** Fixed with `start_async_feature` and `wait_async_feature` helpers in `034-deploy-helpers.sh`.

### 6. ~~Add Input Validation for CLI Arguments~~ ✓ FIXED
**File:** `scripts/005-cli.sh:49-56`

~~The RAM/cores validation is good but could be more robust:~~
```bash
# Now implemented with digit limits for overflow protection
if ! [[ $2 =~ ^[0-9]{1,6}$ ]] || [[ $2 -lt 2048 ]]; then  # RAM (max 6 digits)
if ! [[ $2 =~ ^[0-9]{1,3}$ ]] || [[ $2 -lt 1 ]]; then    # Cores (max 3 digits)
```
**Status:** Fixed with explicit digit limits to prevent arithmetic overflow on very large inputs.

### 7. ~~Consolidate SSH Options~~ ✓ FIXED
**File:** `scripts/021-ssh.sh:10`

~~**Issue:** SSH options defined as a string with word-splitting on usage.~~

```bash
# Now implemented as array for cleaner manipulation
SSH_OPTS=(
  -o StrictHostKeyChecking=no
  -o UserKnownHostsFile=/dev/null
  -o LogLevel=ERROR
  -o "ConnectTimeout=${SSH_CONNECT_TIMEOUT:-10}"
  # ...
)

# Usage with proper array expansion
ssh "${SSH_OPTS[@]}" root@localhost
```
**Status:** Fixed with array pattern in `021-ssh.sh`. All usages updated to `"${SSH_OPTS[@]}"`.

### 8. ~~Add Documentation for Template Variable Escaping Rules~~ ✓ FIXED
**File:** `scripts/020-templates.sh:34-43`

~~The escaping logic is correct but not documented.~~

```bash
# Now documented with inline comments
# Escape special characters in value for sed replacement
# - \ must be escaped first (before adding more backslashes)
# - & is replaced with matched pattern
# - | is our delimiter
# - newlines need special handling
```
**Status:** Fixed with comprehensive inline comments explaining each escape character and why the order matters.

---

## Code Style Inconsistencies

### 1. ~~Mixed Use of `[[ ]]` vs `[ ]`~~ ✓ FIXED
**Files:** ~~Some scripts mix styles, though `[[ ]]` is preferred.~~

```bash
# All scripts now use [[ ]] consistently
while [[ "$retry_count" -lt "$max_retries" ]]; do
  if [[ -s "$output_file" ]]; then
```
**Status:** Fixed in `011-downloads.sh`, `300-configure-base.sh`, and `372-configure-lvm.sh`.

### 2. ~~Inconsistent Log Message Prefixes~~ ✓ FIXED
~~**Observed patterns:**~~
- ~~`log "INFO: message"`~~
- ~~`log "ERROR: message"`~~
- ~~`log "WARNING: message"`~~
- ~~`log "WARN: message"` (scripts/042-validation-dns.sh:143)~~
- `log "message"` (no prefix)

**Status:** Added typed log helper functions in `006-logging.sh`:
```bash
log_info "message"   # → INFO: message
log_error "message"  # → ERROR: message
log_warn "message"   # → WARNING: message
log_debug "message"  # → DEBUG: message
```
Migrated all 247 log calls across 50+ files to use typed helpers. This prevents typos and ensures consistent prefixes.

### 3. Variable Quoting Style
Most code correctly quotes variables, but some places have unnecessary quotes:
```bash
local file_size="$(_get_file_size "$file")"  # Quotes not needed for local
```

Not a bug, but inconsistent with the "always quote" style.

---

## Security Observations

### 1. Good: Secure File Deletion ✓
`secure_delete_file()` properly uses shred with fallback to dd overwrite.

### 2. Good: Password Sanitization in Logs ✓
`_sanitize_script_for_log()` covers common password patterns.

### 3. Good: File Validation Before Source ✓
Defensive checks before sourcing temp files:
```bash
if grep -qvE '^declare -' "$SYSTEM_INFO_CACHE"; then
  log "ERROR: SYSTEM_INFO_CACHE contains invalid content, skipping import"
else
  source "$SYSTEM_INFO_CACHE"
fi
```

### 4. Consideration: API Token File Permissions
**File:** `scripts/003-init.sh:168`

```bash
_TEMP_API_TOKEN_FILE="/tmp/pve-install-api-token.$$.env"
```

**Observation:** File is created with default umask. While registered for cleanup, consider explicit `chmod 600` at creation.

---

## Performance Observations

### 1. Good: Batch Package Installation ✓
`batch_install_packages()` collects all packages before running apt-get once.

### 2. Good: Parallel Configuration Groups ✓
`run_parallel_group()` with concurrency limit prevents fork bombs.

### 3. Suggestion: Cache Command Existence Checks
**File:** `scripts/012-utils.sh:10`

```bash
cmd_exists() { command -v "$1" &>/dev/null; }
```

For frequently checked commands (jq, ip), consider caching results:
```bash
declare -A _CMD_CACHE
cmd_exists() {
  local cmd="$1"
  if [[ -z "${_CMD_CACHE[$cmd]+isset}" ]]; then
    command -v "$cmd" &>/dev/null && _CMD_CACHE[$cmd]=1 || _CMD_CACHE[$cmd]=0
  fi
  [[ ${_CMD_CACHE[$cmd]} -eq 1 ]]
}
```

---

## Documentation Gaps

### 1. Missing: Error Code Documentation
Functions return various codes (0, 1, 2) but this isn't always documented.

**Example:** `validate_dns_resolution` returns:
- 0 = match
- 1 = no resolution
- 2 = wrong IP

This should be in a comment.

### 2. Missing: Template Variable Reference
While CLAUDE.md lists common variables, a complete reference with which templates use which variables would be helpful.

---

## Summary Statistics

| Category | Count | Fixed |
|----------|-------|-------|
| Potential Bugs | 5 | 0 |
| Improvement Suggestions | 8 | 6 |
| Style Inconsistencies | 3 | 2 |
| Security Notes | 4 | 0 |
| Performance Notes | 3 | 0 |

**Overall Assessment:** The codebase is high quality with consistent patterns and good security practices. The identified issues are mostly minor improvements rather than critical bugs.

**Recent Fixes:**
- Improvement #3: Added `declare -g` for explicit global variable assignments in 36 scripts (~350 assignments)
- Improvement #4: Added defensive check for VIRTIO_MAP using `${VAR+isset}` pattern
- Improvement #5: Added `start_async_feature` and `wait_async_feature` helpers for async feature execution
- Improvement #6: Added digit limits to CLI argument validation (`{1,6}` for RAM, `{1,3}` for cores) to prevent arithmetic overflow
- Improvement #7: Converted SSH_OPTS from string to array for cleaner manipulation and proper expansion
- Improvement #8: Added inline documentation for template variable escaping rules in `020-templates.sh`
- Style #1: Standardized on `[[ ]]` test syntax in `011-downloads.sh`, `300-configure-base.sh`, and `372-configure-lvm.sh`
- Style #2: Added typed log helpers (`log_info`, `log_error`, `log_warn`, `log_debug`) and migrated 247 log calls
