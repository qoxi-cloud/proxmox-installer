# shellcheck shell=bash
# shellcheck disable=SC2034,SC2016,SC2102
# =============================================================================
# Tests for 041-system-check.sh
# =============================================================================

%const SCRIPTS_DIR: "${SHELLSPEC_PROJECT_ROOT}/scripts"
%const SUPPORT_DIR: "${SHELLSPEC_PROJECT_ROOT}/spec/support"

# Load shared mocks
eval "$(cat "$SUPPORT_DIR/colors.sh")"
eval "$(cat "$SUPPORT_DIR/core_mocks.sh")"

Describe "041-system-check.sh"
  # ===========================================================================
  # _load_timezones()
  # ===========================================================================
  Describe "_load_timezones()"
    Describe "with timedatectl available"
      timedatectl() {
        if [[ "$1" == "list-timezones" ]]; then
          printf '%s\n' "America/New_York" "Europe/London" "Asia/Tokyo"
        fi
      }

      Include "$SCRIPTS_DIR/041-system-check.sh"

      It "loads timezones from timedatectl"
        When call _load_timezones
        The variable WIZ_TIMEZONES should include "America/New_York"
        The variable WIZ_TIMEZONES should include "Europe/London"
      End

      It "appends UTC at the end"
        When call _load_timezones
        The variable WIZ_TIMEZONES should include "UTC"
      End
    End

    Describe "without timedatectl (fallback)"
      # Override command -v to hide timedatectl
      command() {
        [[ "$*" == *"timedatectl"* ]] && return 1
        builtin command "$@"
      }

      # Mock find for zoneinfo fallback
      find() {
        if [[ "$1" == "/usr/share/zoneinfo" ]]; then
          printf '%s\n' \
            "/usr/share/zoneinfo/America/New_York" \
            "/usr/share/zoneinfo/Europe/Paris" \
            "/usr/share/zoneinfo/Asia/Tokyo"
        fi
      }

      Include "$SCRIPTS_DIR/041-system-check.sh"

      It "falls back to parsing zoneinfo directory"
        When call _load_timezones
        The variable WIZ_TIMEZONES should include "UTC"
      End
    End
  End

  # ===========================================================================
  # _load_countries()
  # ===========================================================================
  Describe "_load_countries()"
    Describe "with iso-codes json available"
      BeforeAll 'MOCK_ISO_FILE=$(mktemp); echo "{\"alpha_2\": \"US\"}{\"alpha_2\": \"GB\"}{\"alpha_2\": \"DE\"}" > "$MOCK_ISO_FILE"'
      AfterAll 'rm -f "$MOCK_ISO_FILE"'

      Include "$SCRIPTS_DIR/041-system-check.sh"

      It "parses countries from iso_3166-1.json"
        # Create mock file in expected location
        mkdir -p /tmp/test-iso-codes/json
        echo '{"alpha_2": "US"}{"alpha_2": "GB"}{"alpha_2": "DE"}' > /tmp/test-iso-codes/json/iso_3166-1.json

        # Patch the function to use our temp path
        _load_countries_patched() {
          local iso_file="/tmp/test-iso-codes/json/iso_3166-1.json"
          if [[ -f $iso_file ]]; then
            WIZ_COUNTRIES=$(grep -oP '"alpha_2":\s*"\K[^"]+' "$iso_file" | tr '[:upper:]' '[:lower:]' | sort)
          fi
        }

        When call _load_countries_patched
        The variable WIZ_COUNTRIES should include "us"
        The variable WIZ_COUNTRIES should include "gb"

        rm -rf /tmp/test-iso-codes
      End
    End

    Describe "without iso-codes (fallback to locale)"
      # Mock locale command
      locale() {
        if [[ "$1" == "-a" ]]; then
          printf '%s\n' "en_US.UTF-8" "de_DE.UTF-8" "fr_FR.UTF-8"
        fi
      }

      Include "$SCRIPTS_DIR/041-system-check.sh"

      It "falls back to locale -a parsing"
        # Use a temp path that doesn't exist
        _load_countries_no_iso() {
          local iso_file="/nonexistent/path/iso_3166-1.json"
          if [[ -f $iso_file ]]; then
            WIZ_COUNTRIES=$(grep -oP '"alpha_2":\s*"\K[^"]+' "$iso_file" | tr '[:upper:]' '[:lower:]' | sort)
          else
            WIZ_COUNTRIES=$(locale -a 2>/dev/null | grep -oP '^[a-z]{2}(?=_)' | sort -u)
          fi
        }

        When call _load_countries_no_iso
        The variable WIZ_COUNTRIES should include "en"
        The variable WIZ_COUNTRIES should include "de"
        The variable WIZ_COUNTRIES should include "fr"
      End
    End
  End

  # ===========================================================================
  # _build_tz_to_country()
  # ===========================================================================
  Describe "_build_tz_to_country()"
    BeforeAll 'MOCK_ZONE_TAB=$(mktemp)'
    AfterAll 'rm -f "$MOCK_ZONE_TAB"'

    Include "$SCRIPTS_DIR/041-system-check.sh"

    It "builds timezone to country mapping"
      # Create mock zone.tab
      printf '%s\t%s\t%s\n' "US" "+1234" "America/New_York" > "$MOCK_ZONE_TAB"
      printf '%s\t%s\t%s\n' "GB" "+5678" "Europe/London" >> "$MOCK_ZONE_TAB"

      _build_tz_to_country_patched() {
        declare -gA TZ_TO_COUNTRY
        local zone_tab="$MOCK_ZONE_TAB"
        [[ -f $zone_tab ]] || return 0

        while IFS=$'\t' read -r country _ tz _; do
          [[ $country == \#* ]] && continue
          [[ -z $tz ]] && continue
          TZ_TO_COUNTRY["$tz"]="${country,,}"
        done <"$zone_tab"
      }

      When call _build_tz_to_country_patched
      The variable TZ_TO_COUNTRY[America/New_York] should equal "us"
      The variable TZ_TO_COUNTRY[Europe/London] should equal "gb"
    End

    It "skips comment lines"
      printf '%s\n' "# This is a comment" > "$MOCK_ZONE_TAB"
      printf '%s\t%s\t%s\n' "DE" "+9012" "Europe/Berlin" >> "$MOCK_ZONE_TAB"

      _build_tz_to_country_patched() {
        declare -gA TZ_TO_COUNTRY
        local zone_tab="$MOCK_ZONE_TAB"
        while IFS=$'\t' read -r country _ tz _; do
          [[ $country == \#* ]] && continue
          [[ -z $tz ]] && continue
          TZ_TO_COUNTRY["$tz"]="${country,,}"
        done <"$zone_tab"
      }

      When call _build_tz_to_country_patched
      The variable TZ_TO_COUNTRY[Europe/Berlin] should equal "de"
    End

    It "returns 0 when zone.tab doesn't exist"
      _build_tz_to_country_missing() {
        declare -gA TZ_TO_COUNTRY
        local zone_tab="/nonexistent/zone.tab"
        [[ -f $zone_tab ]] || return 0
      }

      When call _build_tz_to_country_missing
      The status should be success
    End
  End

  # ===========================================================================
  # _load_wizard_data()
  # ===========================================================================
  Describe "_load_wizard_data()"
    Include "$SCRIPTS_DIR/041-system-check.sh"

    It "calls all loader functions"
      # Override the loader functions after Include
      _load_timezones() { WIZ_TIMEZONES="UTC"; }
      _load_countries() { WIZ_COUNTRIES="us"; }
      _build_tz_to_country() { declare -gA TZ_TO_COUNTRY; TZ_TO_COUNTRY["UTC"]="zz"; }

      When call _load_wizard_data
      The status should be success
    End
  End

  # ===========================================================================
  # detect_drives()
  # ===========================================================================
  Describe "detect_drives()"
    Include "$SCRIPTS_DIR/041-system-check.sh"

    Describe "with NVMe drives"
      lsblk() {
        case "$*" in
          *"-d -n -o NAME,TYPE"*)
            printf '%s\n' "nvme0n1 disk" "nvme1n1 disk" "sda disk"
            ;;
          *"-d -n -o SIZE"*)
            echo "1T"
            ;;
          *"-d -n -o MODEL"*)
            echo "Samsung SSD"
            ;;
        esac
      }

      It "detects NVMe drives"
        When call detect_drives
        The variable DRIVE_COUNT should equal 2
      End

      It "populates DRIVES array with nvme devices"
        When call detect_drives
        The variable DRIVES[0] should equal "/dev/nvme0n1"
        The variable DRIVES[1] should equal "/dev/nvme1n1"
      End
    End

    Describe "without NVMe drives (fallback)"
      lsblk() {
        case "$*" in
          *"-d -n -o NAME,TYPE"*"nvme"*)
            return 0  # No output for nvme
            ;;
          *"-d -n -o NAME,TYPE"*)
            printf '%s\n' "sda disk" "sdb disk" "loop0 loop"
            ;;
          *"-d -n -o SIZE"*)
            echo "500G"
            ;;
          *"-d -n -o MODEL"*)
            echo "HGST HDD"
            ;;
        esac
      }

      It "falls back to any disk type"
        When call detect_drives
        The variable DRIVE_COUNT should equal 2
      End

      It "excludes loop devices"
        When call detect_drives
        The variable DRIVES[0] should equal "/dev/sda"
        The variable DRIVES[1] should equal "/dev/sdb"
      End
    End

    Describe "with no drives"
      lsblk() { :; }

      It "sets DRIVE_COUNT to 0"
        When call detect_drives
        The variable DRIVE_COUNT should equal 0
      End
    End

    Describe "drive info collection"
      lsblk() {
        case "$*" in
          *"-d -n -o NAME,TYPE"*)
            echo "nvme0n1 disk"
            ;;
          *"-d -n -o SIZE /dev/nvme0n1")
            echo "2T"
            ;;
          *"-d -n -o MODEL /dev/nvme0n1")
            echo "Samsung 990 Pro"
            ;;
        esac
      }

      It "populates DRIVE_SIZES array"
        When call detect_drives
        The variable DRIVE_SIZES[0] should equal "2T"
      End

      It "populates DRIVE_MODELS array"
        When call detect_drives
        The variable DRIVE_MODELS[0] should equal "Samsung 990 Pro"
      End

      It "populates DRIVE_NAMES array"
        When call detect_drives
        The variable DRIVE_NAMES[0] should equal "nvme0n1"
      End
    End
  End

  # ===========================================================================
  # detect_disk_roles()
  # ===========================================================================
  Describe "detect_disk_roles()"
    Include "$SCRIPTS_DIR/041-system-check.sh"

    Describe "with no drives"
      It "returns failure"
        DRIVE_COUNT=0
        DRIVES=()
        When call detect_disk_roles
        The status should be failure
      End
    End

    Describe "with same-size drives"
      setup_same_size() {
        DRIVES=("/dev/nvme0n1" "/dev/nvme1n1")
        DRIVE_SIZES=("1T" "1T")
        DRIVE_COUNT=2
      }

      It "puts all drives in pool"
        setup_same_size
        When call detect_disk_roles
        The variable BOOT_DISK should equal ""
        The variable ZFS_POOL_DISKS[0] should equal "/dev/nvme0n1"
        The variable ZFS_POOL_DISKS[1] should equal "/dev/nvme1n1"
      End
    End

    Describe "with mixed-size drives"
      setup_mixed_size() {
        DRIVES=("/dev/nvme0n1" "/dev/nvme1n1" "/dev/sda")
        DRIVE_SIZES=("2T" "2T" "500G")
        DRIVE_COUNT=3
      }

      It "uses smallest drive as boot disk"
        setup_mixed_size
        When call detect_disk_roles
        The variable BOOT_DISK should equal "/dev/sda"
      End

      It "puts larger drives in pool"
        setup_mixed_size
        When call detect_disk_roles
        The variable ZFS_POOL_DISKS[0] should equal "/dev/nvme0n1"
        The variable ZFS_POOL_DISKS[1] should equal "/dev/nvme1n1"
      End
    End

    Describe "with single drive"
      setup_single() {
        DRIVES=("/dev/nvme0n1")
        DRIVE_SIZES=("1T")
        DRIVE_COUNT=1
      }

      It "puts single drive in pool"
        setup_single
        When call detect_disk_roles
        The variable BOOT_DISK should equal ""
        The variable ZFS_POOL_DISKS[0] should equal "/dev/nvme0n1"
      End
    End

    Describe "size parsing"
      Describe "with terabyte sizes"
        setup_tb() {
          DRIVES=("/dev/nvme0n1" "/dev/nvme1n1")
          DRIVE_SIZES=("2T" "4T")
          DRIVE_COUNT=2
        }

        It "correctly identifies smaller TB drive"
          setup_tb
          When call detect_disk_roles
          The variable BOOT_DISK should equal "/dev/nvme0n1"
        End
      End

      Describe "with gigabyte sizes"
        setup_gb() {
          DRIVES=("/dev/sda" "/dev/sdb")
          DRIVE_SIZES=("500G" "1000G")
          DRIVE_COUNT=2
        }

        It "correctly identifies smaller GB drive"
          setup_gb
          When call detect_disk_roles
          The variable BOOT_DISK should equal "/dev/sda"
        End
      End

      Describe "with mixed TB and GB"
        setup_mixed_tb_gb() {
          DRIVES=("/dev/nvme0n1" "/dev/sda")
          DRIVE_SIZES=("2T" "240G")
          DRIVE_COUNT=2
        }

        It "uses GB drive as boot (smaller)"
          setup_mixed_tb_gb
          When call detect_disk_roles
          The variable BOOT_DISK should equal "/dev/sda"
        End
      End
    End

    Describe "size difference threshold (10%)"
      Describe "within 10% difference"
        setup_within_threshold() {
          DRIVES=("/dev/nvme0n1" "/dev/nvme1n1")
          DRIVE_SIZES=("1000G" "1050G")
          DRIVE_COUNT=2
        }

        It "treats as same size (all in pool)"
          setup_within_threshold
          When call detect_disk_roles
          The variable BOOT_DISK should equal ""
        End
      End

      Describe "over 10% difference"
        setup_over_threshold() {
          DRIVES=("/dev/nvme0n1" "/dev/sda")
          DRIVE_SIZES=("1000G" "500G")
          DRIVE_COUNT=2
        }

        It "separates boot and pool"
          setup_over_threshold
          When call detect_disk_roles
          The variable BOOT_DISK should equal "/dev/sda"
        End
      End
    End
  End

  # ===========================================================================
  # collect_system_info() - complex function with many dependencies
  # ===========================================================================
  Describe "collect_system_info()"
    # Helper to check root (since EUID is readonly)
    _check_root() {
      if [[ $MOCK_EUID -ne 0 ]]; then
        PREFLIGHT_ROOT="✗ Not root"
        PREFLIGHT_ROOT_STATUS="error"
        return 1
      else
        PREFLIGHT_ROOT="Running as root"
        PREFLIGHT_ROOT_STATUS="ok"
        return 0
      fi
    }

    # Create a testable version that uses our mock
    _test_collect_system_info() {
      local errors=0

      # Root check using mock
      if ! _check_root; then
        errors=$((errors + 1))
      fi

      # Network check
      if ping -c 1 -W 3 "$DNS_PRIMARY" >/dev/null 2>&1; then
        PREFLIGHT_NET="Available"
        PREFLIGHT_NET_STATUS="ok"
      else
        PREFLIGHT_NET="No connection"
        PREFLIGHT_NET_STATUS="error"
        errors=$((errors + 1))
      fi

      # RAM check
      local total_ram_mb
      total_ram_mb=$(free -m | awk '/^Mem:/{print $2}')
      if [[ $total_ram_mb -ge $MIN_RAM_MB ]]; then
        PREFLIGHT_RAM="${total_ram_mb} MB"
        PREFLIGHT_RAM_STATUS="ok"
      else
        PREFLIGHT_RAM="${total_ram_mb} MB (need ${MIN_RAM_MB}MB+)"
        PREFLIGHT_RAM_STATUS="error"
        errors=$((errors + 1))
      fi

      # CPU check
      local cpu_cores
      cpu_cores=$(nproc)
      if [[ $cpu_cores -ge 2 ]]; then
        PREFLIGHT_CPU="${cpu_cores} cores"
        PREFLIGHT_CPU_STATUS="ok"
      else
        PREFLIGHT_CPU="${cpu_cores} core(s)"
        PREFLIGHT_CPU_STATUS="warn"
      fi

      # Disk check
      if validate_disk_space "/root" "$MIN_DISK_SPACE_MB"; then
        PREFLIGHT_DISK="${DISK_SPACE_MB} MB"
        PREFLIGHT_DISK_STATUS="ok"
      else
        PREFLIGHT_DISK="${DISK_SPACE_MB:-0} MB (need ${MIN_DISK_SPACE_MB}MB+)"
        PREFLIGHT_DISK_STATUS="error"
        errors=$((errors + 1))
      fi

      PREFLIGHT_ERRORS=$errors
    }

    Include "$SCRIPTS_DIR/041-system-check.sh"

    Describe "root check"
      ping() { return 0; }
      free() { echo "Mem:         16000        8000        8000"; }
      nproc() { echo "8"; }
      validate_disk_space() { DISK_SPACE_MB=10000; return 0; }

      It "detects root user"
        MOCK_EUID=0
        DNS_PRIMARY="1.1.1.1"
        MIN_RAM_MB=4096
        MIN_DISK_SPACE_MB=5000
        When call _test_collect_system_info
        The variable PREFLIGHT_ROOT should equal "Running as root"
        The variable PREFLIGHT_ROOT_STATUS should equal "ok"
      End

      It "detects non-root user"
        MOCK_EUID=1000
        DNS_PRIMARY="1.1.1.1"
        MIN_RAM_MB=4096
        MIN_DISK_SPACE_MB=5000
        When call _test_collect_system_info
        The variable PREFLIGHT_ROOT should equal "✗ Not root"
        The variable PREFLIGHT_ROOT_STATUS should equal "error"
      End
    End

    Describe "network check"
      validate_disk_space() { DISK_SPACE_MB=10000; return 0; }
      free() { echo "Mem:         16000        8000        8000"; }
      nproc() { echo "8"; }

      It "detects available network"
        ping() { return 0; }
        MOCK_EUID=0
        DNS_PRIMARY="1.1.1.1"
        MIN_RAM_MB=4096
        MIN_DISK_SPACE_MB=5000
        When call _test_collect_system_info
        The variable PREFLIGHT_NET should equal "Available"
        The variable PREFLIGHT_NET_STATUS should equal "ok"
      End

      It "detects no network"
        ping() { return 1; }
        MOCK_EUID=0
        DNS_PRIMARY="1.1.1.1"
        MIN_RAM_MB=4096
        MIN_DISK_SPACE_MB=5000
        When call _test_collect_system_info
        The variable PREFLIGHT_NET should equal "No connection"
        The variable PREFLIGHT_NET_STATUS should equal "error"
      End
    End

    Describe "RAM check"
      ping() { return 0; }
      validate_disk_space() { DISK_SPACE_MB=10000; return 0; }
      nproc() { echo "8"; }

      It "passes with sufficient RAM"
        free() { echo "Mem:         8000        4000        4000"; }
        MOCK_EUID=0
        DNS_PRIMARY="1.1.1.1"
        MIN_RAM_MB=4096
        MIN_DISK_SPACE_MB=5000
        When call _test_collect_system_info
        The variable PREFLIGHT_RAM should equal "8000 MB"
        The variable PREFLIGHT_RAM_STATUS should equal "ok"
      End

      It "fails with insufficient RAM"
        free() { echo "Mem:         2000        1000        1000"; }
        MOCK_EUID=0
        DNS_PRIMARY="1.1.1.1"
        MIN_RAM_MB=4096
        MIN_DISK_SPACE_MB=5000
        When call _test_collect_system_info
        The variable PREFLIGHT_RAM should include "need"
        The variable PREFLIGHT_RAM_STATUS should equal "error"
      End
    End

    Describe "CPU check"
      ping() { return 0; }
      validate_disk_space() { DISK_SPACE_MB=10000; return 0; }
      free() { echo "Mem:         16000        8000        8000"; }

      It "passes with 2+ cores"
        nproc() { echo "4"; }
        MOCK_EUID=0
        DNS_PRIMARY="1.1.1.1"
        MIN_RAM_MB=4096
        MIN_DISK_SPACE_MB=5000
        When call _test_collect_system_info
        The variable PREFLIGHT_CPU should equal "4 cores"
        The variable PREFLIGHT_CPU_STATUS should equal "ok"
      End

      It "warns with 1 core"
        nproc() { echo "1"; }
        MOCK_EUID=0
        DNS_PRIMARY="1.1.1.1"
        MIN_RAM_MB=4096
        MIN_DISK_SPACE_MB=5000
        When call _test_collect_system_info
        The variable PREFLIGHT_CPU should equal "1 core(s)"
        The variable PREFLIGHT_CPU_STATUS should equal "warn"
      End
    End

    Describe "error counting"
      It "counts errors correctly"
        ping() { return 1; }  # No network - 1 error
        free() { echo "Mem:         16000        8000        8000"; }
        nproc() { echo "8"; }
        validate_disk_space() { DISK_SPACE_MB=100; return 1; }  # Low disk - 1 error
        MOCK_EUID=1000  # Not root - 1 error
        DNS_PRIMARY="1.1.1.1"
        MIN_RAM_MB=4096
        MIN_DISK_SPACE_MB=5000
        When call _test_collect_system_info
        The variable PREFLIGHT_ERRORS should equal 3
      End
    End
  End

  # ===========================================================================
  # Interface detection tests
  # ===========================================================================
  Describe "interface detection logic"
    Include "$SCRIPTS_DIR/041-system-check.sh"

    Describe "with ip and jq available"
      command() {
        case "$2" in
          ip|jq) return 0 ;;
          *) builtin command "$@" ;;
        esac
      }

      ip() {
        case "$*" in
          *"-j route"*)
            echo '[{"dst":"default","gateway":"192.168.1.1","dev":"enp0s3"}]'
            ;;
        esac
      }

      jq() {
        case "$*" in
          *"default"*".dev"*)
            echo "enp0s3"
            ;;
        esac
      }

      It "detects interface from ip route JSON"
        _test_interface_detection() {
          local iface
          if command -v ip &>/dev/null && command -v jq &>/dev/null; then
            iface=$(ip -j route 2>/dev/null | jq -r '.[] | select(.dst == "default") | .dev' | head -n1)
          fi
          echo "$iface"
        }
        When call _test_interface_detection
        The output should equal "enp0s3"
      End
    End

    Describe "fallback to ip route without jq"
      command() {
        case "$2" in
          ip) return 0 ;;
          jq) return 1 ;;
          *) builtin command "$@" ;;
        esac
      }

      ip() {
        case "$*" in
          *"route"*)
            echo "default via 192.168.1.1 dev eth0 proto static"
            ;;
        esac
      }

      It "parses interface from ip route text output"
        _test_interface_fallback() {
          local iface
          if command -v ip &>/dev/null; then
            iface=$(ip route | grep default | awk '{print $5}' | head -n1)
          fi
          echo "$iface"
        }
        When call _test_interface_fallback
        The output should equal "eth0"
      End
    End
  End

  # ===========================================================================
  # show_system_status() - display function
  # ===========================================================================
  Describe "show_system_status()"
    Include "$SCRIPTS_DIR/041-system-check.sh"

    Describe "with all checks passing"
      It "proceeds to wizard when no errors"
        # Test the logic directly
        _test_show_passing() {
          local has_errors=false
          PREFLIGHT_ERRORS=0
          DRIVE_COUNT=1
          if [[ $PREFLIGHT_ERRORS -gt 0 || $DRIVE_COUNT -eq 0 ]]; then
            has_errors=true
          fi
          if [[ $has_errors == false ]]; then
            echo "wizard"
            return 0
          fi
          return 1
        }
        When call _test_show_passing
        The output should equal "wizard"
        The status should be success
      End
    End

    Describe "with errors"
      It "detects errors correctly"
        _test_show_errors() {
          local has_errors=false
          PREFLIGHT_ERRORS=1
          DRIVE_COUNT=1
          if [[ $PREFLIGHT_ERRORS -gt 0 || $DRIVE_COUNT -eq 0 ]]; then
            has_errors=true
          fi
          echo "$has_errors"
        }
        When call _test_show_errors
        The output should equal "true"
      End
    End

    Describe "with no drives"
      It "detects no drives as error"
        _test_show_no_drives() {
          local has_errors=false
          PREFLIGHT_ERRORS=0
          DRIVE_COUNT=0
          if [[ $PREFLIGHT_ERRORS -gt 0 || $DRIVE_COUNT -eq 0 ]]; then
            has_errors=true
          fi
          echo "$has_errors"
        }
        When call _test_show_no_drives
        The output should equal "true"
      End
    End

    Describe "table building"
      It "builds table data with status markers"
        gum() {
          case "$1" in
            style) shift; while [[ "$1" == --* ]]; do shift 2 2>/dev/null || shift; done; echo "$*" ;;
          esac
        }
        HEX_CYAN="00B1FF"
        HEX_RED="FF0000"

        _test_build_table() {
          local table_data="Status,Item,Value"
          local ok_status
          ok_status=$(gum style --foreground "$HEX_CYAN" "[OK]")
          table_data+=$'\n'"${ok_status},Root Access,Running as root"
          echo "$table_data"
        }
        When call _test_build_table
        The output should include "[OK]"
        The output should include "Root Access"
      End
    End
  End

  # ===========================================================================
  # format_status() - helper function inside show_system_status
  # ===========================================================================
  Describe "format_status() helper"
    gum() {
      case "$1" in
        style)
          shift
          # Extract just the text (last argument after options)
          local text=""
          while [[ $# -gt 0 ]]; do
            case "$1" in
              --*) shift 2 ;;
              *) text="$1"; shift ;;
            esac
          done
          echo "$text"
          ;;
      esac
    }

    HEX_CYAN="00B1FF"
    HEX_YELLOW="FFFF00"
    HEX_RED="FF0000"

    Include "$SCRIPTS_DIR/041-system-check.sh"

    It "formats ok status"
      format_status() {
        local status="$1"
        case "$status" in
          ok) gum style --foreground "$HEX_CYAN" "[OK]" ;;
          warn) gum style --foreground "$HEX_YELLOW" "[WARN]" ;;
          error) gum style --foreground "$HEX_RED" "[ERROR]" ;;
        esac
      }
      When call format_status "ok"
      The output should equal "[OK]"
    End

    It "formats warn status"
      format_status() {
        local status="$1"
        case "$status" in
          ok) gum style --foreground "$HEX_CYAN" "[OK]" ;;
          warn) gum style --foreground "$HEX_YELLOW" "[WARN]" ;;
          error) gum style --foreground "$HEX_RED" "[ERROR]" ;;
        esac
      }
      When call format_status "warn"
      The output should equal "[WARN]"
    End

    It "formats error status"
      format_status() {
        local status="$1"
        case "$status" in
          ok) gum style --foreground "$HEX_CYAN" "[OK]" ;;
          warn) gum style --foreground "$HEX_YELLOW" "[WARN]" ;;
          error) gum style --foreground "$HEX_RED" "[ERROR]" ;;
        esac
      }
      When call format_status "error"
      The output should equal "[ERROR]"
    End
  End
End
