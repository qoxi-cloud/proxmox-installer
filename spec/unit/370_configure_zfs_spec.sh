# shellcheck shell=bash
# shellcheck disable=SC2034
# =============================================================================
# Tests for 370-configure-zfs.sh
# =============================================================================

%const SCRIPTS_DIR: "${SHELLSPEC_PROJECT_ROOT}/scripts"
%const SUPPORT_DIR: "${SHELLSPEC_PROJECT_ROOT}/spec/support"

# Load shared mocks
eval "$(cat "$SUPPORT_DIR/configure_mocks.sh")"

Describe "370-configure-zfs.sh"
  Include "$SCRIPTS_DIR/370-configure-zfs.sh"

  # ===========================================================================
  # _config_zfs_arc()
  # ===========================================================================
  Describe "_config_zfs_arc()"
    BeforeEach 'MOCK_REMOTE_RUN_RESULT=0; ZFS_ARC_MODE=""'

    # -------------------------------------------------------------------------
    # ARC mode: vm-focused
    # -------------------------------------------------------------------------
    Describe "vm-focused mode"
      It "sets fixed 4GB ARC limit"
        ZFS_ARC_MODE="vm-focused"
        # free -m output: line 1 is header, line 2 is data (awk 'NR==2 {print $2}')
        free() { printf '%s\n%s\n' "              total        used        free" "Mem:          32768        1000        1000"; }
        remote_run_command=""
        remote_run() {
          remote_run_command="$2"
          return 0
        }
        When call _config_zfs_arc
        The status should be success
        # 4096MB * 1024 * 1024 = 4294967296
        The variable remote_run_command should include "4294967296"
      End

      It "uses 4GB regardless of RAM size"
        ZFS_ARC_MODE="vm-focused"
        # 128GB RAM
        free() { printf '%s\n%s\n' "              total        used        free" "Mem:         131072        1000        1000"; }
        remote_run_command=""
        remote_run() {
          remote_run_command="$2"
          return 0
        }
        When call _config_zfs_arc
        The status should be success
        # Still 4GB = 4294967296
        The variable remote_run_command should include "4294967296"
      End
    End

    # -------------------------------------------------------------------------
    # ARC mode: balanced
    # -------------------------------------------------------------------------
    Describe "balanced mode"
      It "uses 25% of RAM when under 16GB"
        ZFS_ARC_MODE="balanced"
        # 8GB = 8192MB
        free() { printf '%s\n%s\n' "              total        used        free" "Mem:           8192        1000        1000"; }
        remote_run_command=""
        remote_run() {
          remote_run_command="$2"
          return 0
        }
        When call _config_zfs_arc
        The status should be success
        # 8192 * 25 / 100 = 2048MB = 2147483648 bytes
        The variable remote_run_command should include "2147483648"
      End

      It "uses 40% of RAM when between 16GB and 64GB"
        ZFS_ARC_MODE="balanced"
        # 32GB = 32768MB
        free() { printf '%s\n%s\n' "              total        used        free" "Mem:          32768        1000        1000"; }
        remote_run_command=""
        remote_run() {
          remote_run_command="$2"
          return 0
        }
        When call _config_zfs_arc
        The status should be success
        # 32768 * 40 / 100 = 13107MB = 13743685632 bytes
        The variable remote_run_command should include "13743685632"
      End

      It "uses 50% of RAM when over 64GB"
        ZFS_ARC_MODE="balanced"
        # 128GB = 131072MB
        free() { printf '%s\n%s\n' "              total        used        free" "Mem:         131072        1000        1000"; }
        remote_run_command=""
        remote_run() {
          remote_run_command="$2"
          return 0
        }
        When call _config_zfs_arc
        The status should be success
        # 131072 / 2 = 65536MB = 68719476736 bytes
        The variable remote_run_command should include "68719476736"
      End

      It "uses 25% at exactly 16GB boundary"
        ZFS_ARC_MODE="balanced"
        # 16383MB (just under 16GB)
        free() { printf '%s\n%s\n' "              total        used        free" "Mem:          16383        1000        1000"; }
        remote_run_command=""
        remote_run() {
          remote_run_command="$2"
          return 0
        }
        When call _config_zfs_arc
        The status should be success
        # 16383 * 25 / 100 = 4095MB = 4293918720 bytes
        The variable remote_run_command should include "4293918720"
      End

      It "uses 40% at exactly 16GB"
        ZFS_ARC_MODE="balanced"
        # 16384MB (exactly 16GB)
        free() { printf '%s\n%s\n' "              total        used        free" "Mem:          16384        1000        1000"; }
        remote_run_command=""
        remote_run() {
          remote_run_command="$2"
          return 0
        }
        When call _config_zfs_arc
        The status should be success
        # 16384 * 40 / 100 = 6553MB = 6871318528 bytes
        The variable remote_run_command should include "6871318528"
      End
    End

    # -------------------------------------------------------------------------
    # ARC mode: storage-focused
    # -------------------------------------------------------------------------
    Describe "storage-focused mode"
      It "uses 50% of RAM"
        ZFS_ARC_MODE="storage-focused"
        # 64GB = 65536MB
        free() { printf '%s\n%s\n' "              total        used        free" "Mem:          65536        1000        1000"; }
        remote_run_command=""
        remote_run() {
          remote_run_command="$2"
          return 0
        }
        When call _config_zfs_arc
        The status should be success
        # 65536 / 2 = 32768MB = 34359738368 bytes
        The variable remote_run_command should include "34359738368"
      End

      It "uses 50% for small RAM too"
        ZFS_ARC_MODE="storage-focused"
        # 8GB = 8192MB
        free() { printf '%s\n%s\n' "              total        used        free" "Mem:           8192        1000        1000"; }
        remote_run_command=""
        remote_run() {
          remote_run_command="$2"
          return 0
        }
        When call _config_zfs_arc
        The status should be success
        # 8192 / 2 = 4096MB = 4294967296 bytes
        The variable remote_run_command should include "4294967296"
      End
    End

    # -------------------------------------------------------------------------
    # Invalid mode
    # -------------------------------------------------------------------------
    Describe "invalid mode"
      It "fails with invalid ZFS_ARC_MODE"
        ZFS_ARC_MODE="invalid-mode"
        free() { echo "Mem: 32768 1000 1000 0 0 0"; }
        When call _config_zfs_arc
        The status should be failure
      End

      It "logs error for invalid mode"
        ZFS_ARC_MODE="unknown"
        log_message=""
        log() { log_message="$*"; }
        free() { echo "Mem: 32768 1000 1000 0 0 0"; }
        When call _config_zfs_arc
        The status should be failure
        The variable log_message should include "ERROR"
        The variable log_message should include "Invalid ZFS_ARC_MODE"
      End

      It "fails with empty ZFS_ARC_MODE"
        ZFS_ARC_MODE=""
        free() { echo "Mem: 32768 1000 1000 0 0 0"; }
        When call _config_zfs_arc
        The status should be failure
      End
    End

    # -------------------------------------------------------------------------
    # Remote execution
    # -------------------------------------------------------------------------
    Describe "remote execution"
      It "writes to /etc/modprobe.d/zfs.conf"
        ZFS_ARC_MODE="vm-focused"
        free() { echo "Mem: 32768 1000 1000 0 0 0"; }
        remote_run_command=""
        remote_run() {
          remote_run_command="$2"
          return 0
        }
        When call _config_zfs_arc
        The status should be success
        The variable remote_run_command should include "/etc/modprobe.d/zfs.conf"
        The variable remote_run_command should include "options zfs zfs_arc_max="
      End

      It "attempts to apply runtime setting"
        ZFS_ARC_MODE="vm-focused"
        free() { printf '%s\n%s\n' "              total        used        free" "Mem:          32768        1000        1000"; }
        remote_run_command=""
        remote_run() {
          remote_run_command="$2"
          return 0
        }
        When call _config_zfs_arc
        The status should be success
        The variable remote_run_command should include "/sys/module/zfs/parameters/zfs_arc_max"
      End
    End

    # -------------------------------------------------------------------------
    # Logging
    # -------------------------------------------------------------------------
    Describe "logging"
      It "logs initial configuration message"
        ZFS_ARC_MODE="balanced"
        log_messages=()
        log() { log_messages+=("$*"); }
        free() { echo "Mem: 32768 1000 1000 0 0 0"; }
        When call _config_zfs_arc
        The status should be success
        The variable 'log_messages[0]' should include "Configuring ZFS ARC memory allocation"
        The variable 'log_messages[0]' should include "balanced"
      End

      It "logs calculated ARC size"
        ZFS_ARC_MODE="vm-focused"
        log_messages=()
        log() { log_messages+=("$*"); }
        free() { echo "Mem: 32768 1000 1000 0 0 0"; }
        When call _config_zfs_arc
        The status should be success
        The value "${log_messages[*]}" should include "ZFS ARC"
        The value "${log_messages[*]}" should include "4096MB"
      End
    End
  End

  # ===========================================================================
  # _config_zfs_scrub()
  # ===========================================================================
  Describe "_config_zfs_scrub()"
    BeforeEach 'MOCK_REMOTE_COPY_RESULT=0; MOCK_REMOTE_RUN_RESULT=0'

    # -------------------------------------------------------------------------
    # Template deployment
    # -------------------------------------------------------------------------
    Describe "template deployment"
      It "deploys zfs-scrub.service template"
        copy_args=()
        remote_copy() {
          copy_args+=("$1:$2")
          return 0
        }
        When call _config_zfs_scrub
        The status should be success
        The value "${copy_args[*]}" should include "templates/zfs-scrub.service"
        The value "${copy_args[*]}" should include "/etc/systemd/system/zfs-scrub@.service"
      End

      It "deploys zfs-scrub.timer template"
        copy_args=()
        remote_copy() {
          copy_args+=("$1:$2")
          return 0
        }
        When call _config_zfs_scrub
        The status should be success
        The value "${copy_args[*]}" should include "templates/zfs-scrub.timer"
        The value "${copy_args[*]}" should include "/etc/systemd/system/zfs-scrub@.timer"
      End

      It "fails when service template copy fails"
        call_count=0
        remote_copy() {
          call_count=$((call_count + 1))
          if [[ $call_count -eq 1 ]]; then
            return 1
          fi
          return 0
        }
        When call _config_zfs_scrub
        The status should be failure
      End

      It "fails when timer template copy fails"
        call_count=0
        remote_copy() {
          call_count=$((call_count + 1))
          if [[ $call_count -eq 2 ]]; then
            return 1
          fi
          return 0
        }
        When call _config_zfs_scrub
        The status should be failure
      End

      It "logs error when service template fails"
        log_message=""
        log() { log_message="$*"; }
        remote_copy() { return 1; }
        When call _config_zfs_scrub
        The status should be failure
        The variable log_message should include "ERROR"
        The variable log_message should include "ZFS scrub service"
      End
    End

    # -------------------------------------------------------------------------
    # Remote execution
    # -------------------------------------------------------------------------
    Describe "remote execution"
      It "runs systemctl daemon-reload"
        remote_run_command=""
        remote_run() {
          remote_run_command="$2"
          return 0
        }
        When call _config_zfs_scrub
        The status should be success
        The variable remote_run_command should include "systemctl daemon-reload"
      End

      It "enables timer for rpool if it exists"
        remote_run_command=""
        remote_run() {
          remote_run_command="$2"
          return 0
        }
        When call _config_zfs_scrub
        The status should be success
        The variable remote_run_command should include "zpool list rpool"
        The variable remote_run_command should include "zfs-scrub@rpool.timer"
      End

      It "enables timer for tank if it exists"
        remote_run_command=""
        remote_run() {
          remote_run_command="$2"
          return 0
        }
        When call _config_zfs_scrub
        The status should be success
        The variable remote_run_command should include "zpool list tank"
        The variable remote_run_command should include "zfs-scrub@tank.timer"
      End
    End

    # -------------------------------------------------------------------------
    # Logging
    # -------------------------------------------------------------------------
    Describe "logging"
      It "logs initial message"
        log_message=""
        log() { log_message="$*"; }
        When call _config_zfs_scrub
        The status should be success
        The variable log_message should include "ZFS scrub"
      End

      It "logs completion with schedule details"
        log_messages=()
        log() { log_messages+=("$*"); }
        When call _config_zfs_scrub
        The status should be success
        The value "${log_messages[*]}" should include "monthly"
      End
    End

    # -------------------------------------------------------------------------
    # Success case
    # -------------------------------------------------------------------------
    Describe "success case"
      It "completes when all operations succeed"
        When call _config_zfs_scrub
        The status should be success
      End
    End
  End

  # ===========================================================================
  # configure_zfs_arc() - public wrapper
  # ===========================================================================
  Describe "configure_zfs_arc()"
    BeforeEach 'MOCK_REMOTE_RUN_RESULT=0'

    It "calls _config_zfs_arc"
      config_called=false
      _config_zfs_arc() { config_called=true; return 0; }
      When call configure_zfs_arc
      The status should be success
      The variable config_called should equal true
    End

    It "propagates success from _config_zfs_arc"
      _config_zfs_arc() { return 0; }
      When call configure_zfs_arc
      The status should be success
    End

    It "propagates failure from _config_zfs_arc"
      _config_zfs_arc() { return 1; }
      When call configure_zfs_arc
      The status should be failure
    End
  End

  # ===========================================================================
  # configure_zfs_scrub() - public wrapper
  # ===========================================================================
  Describe "configure_zfs_scrub()"
    BeforeEach 'MOCK_REMOTE_COPY_RESULT=0; MOCK_REMOTE_RUN_RESULT=0'

    It "calls _config_zfs_scrub"
      config_called=false
      _config_zfs_scrub() { config_called=true; return 0; }
      When call configure_zfs_scrub
      The status should be success
      The variable config_called should equal true
    End

    It "propagates success from _config_zfs_scrub"
      _config_zfs_scrub() { return 0; }
      When call configure_zfs_scrub
      The status should be success
    End

    It "propagates failure from _config_zfs_scrub"
      _config_zfs_scrub() { return 1; }
      When call configure_zfs_scrub
      The status should be failure
    End
  End
End

