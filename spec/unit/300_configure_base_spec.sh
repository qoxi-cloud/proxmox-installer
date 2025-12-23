# shellcheck shell=bash
# shellcheck disable=SC2034
# =============================================================================
# Tests for 300-configure-base.sh
# =============================================================================

%const SCRIPTS_DIR: "${SHELLSPEC_PROJECT_ROOT}/scripts"
%const SUPPORT_DIR: "${SHELLSPEC_PROJECT_ROOT}/spec/support"

# Load shared mocks
eval "$(cat "$SUPPORT_DIR/configure_mocks.sh")"

Describe "300-configure-base.sh"
  Include "$SCRIPTS_DIR/300-configure-base.sh"

  # ===========================================================================
  # _copy_config_files()
  # ===========================================================================
  Describe "_copy_config_files()"
    It "copies all config files successfully"
      MOCK_REMOTE_COPY_RESULT=0
      When call _copy_config_files
      The status should be success
    End

    It "fails when any remote_copy fails"
      # All background jobs will fail
      MOCK_REMOTE_COPY_RESULT=1
      When call _copy_config_files
      The status should be failure
    End
  End

  # ===========================================================================
  # _apply_basic_settings()
  # ===========================================================================
  Describe "_apply_basic_settings()"
    BeforeEach 'PVE_HOSTNAME="testhost"'

    It "applies settings successfully"
      MOCK_REMOTE_EXEC_RESULT=0
      When call _apply_basic_settings
      The status should be success
    End

    It "fails when sources.list backup fails"
      remote_exec() {
        [[ $1 == *"sources.list"* ]] && return 1
        return 0
      }
      When call _apply_basic_settings
      The status should be failure
    End

    It "fails when hostname set fails"
      remote_exec() {
        [[ $1 == *"hostname"* ]] && return 1
        return 0
      }
      When call _apply_basic_settings
      The status should be failure
    End

    It "continues when rpcbind disable fails (non-critical)"
      # First two succeed, third fails
      call_count=0
      remote_exec() {
        call_count=$((call_count + 1))
        [[ $call_count -eq 3 ]] && return 1
        return 0
      }
      When call _apply_basic_settings
      The status should be success
    End
  End

  # ===========================================================================
  # _install_locale_files()
  # ===========================================================================
  Describe "_install_locale_files()"
    It "installs locale files successfully"
      MOCK_REMOTE_COPY_RESULT=0
      MOCK_REMOTE_EXEC_RESULT=0
      When call _install_locale_files
      The status should be success
    End

    It "fails when locale.sh copy fails"
      copy_call=0
      remote_copy() {
        copy_call=$((copy_call + 1))
        [[ $copy_call -eq 1 ]] && return 1
        return 0
      }
      When call _install_locale_files
      The status should be failure
    End

    It "fails when chmod fails"
      MOCK_REMOTE_COPY_RESULT=0
      MOCK_REMOTE_EXEC_RESULT=1
      When call _install_locale_files
      The status should be failure
    End

    It "fails when default-locale copy fails"
      copy_call=0
      exec_call=0
      remote_copy() {
        copy_call=$((copy_call + 1))
        [[ $copy_call -eq 2 ]] && return 1
        return 0
      }
      remote_exec() { exec_call=$((exec_call + 1)); return 0; }
      When call _install_locale_files
      The status should be failure
    End

    It "fails when environment copy fails"
      copy_call=0
      remote_copy() {
        copy_call=$((copy_call + 1))
        [[ $copy_call -eq 3 ]] && return 1
        return 0
      }
      remote_exec() { return 0; }
      When call _install_locale_files
      The status should be failure
    End
  End

  # ===========================================================================
  # _configure_fastfetch()
  # ===========================================================================
  Describe "_configure_fastfetch()"
    It "configures fastfetch successfully"
      MOCK_REMOTE_COPY_RESULT=0
      MOCK_REMOTE_EXEC_RESULT=0
      When call _configure_fastfetch
      The status should be success
    End

    It "fails when copy fails"
      MOCK_REMOTE_COPY_RESULT=1
      When call _configure_fastfetch
      The status should be failure
    End

    It "fails when chmod fails"
      copy_call=0
      exec_call=0
      remote_copy() { return 0; }
      remote_exec() {
        exec_call=$((exec_call + 1))
        [[ $exec_call -eq 1 ]] && return 1
        return 0
      }
      When call _configure_fastfetch
      The status should be failure
    End

    It "fails when bash.bashrc update fails"
      exec_call=0
      remote_copy() { return 0; }
      remote_exec() {
        exec_call=$((exec_call + 1))
        [[ $exec_call -eq 2 ]] && return 1
        return 0
      }
      When call _configure_fastfetch
      The status should be failure
    End
  End

  # ===========================================================================
  # _configure_bat()
  # ===========================================================================
  Describe "_configure_bat()"
    It "configures bat successfully"
      MOCK_REMOTE_EXEC_RESULT=0
      MOCK_REMOTE_COPY_RESULT=0
      When call _configure_bat
      The status should be success
    End

    It "fails when symlink creation fails"
      MOCK_REMOTE_EXEC_RESULT=1
      When call _configure_bat
      The status should be failure
    End

    It "fails when deploy_user_config fails"
      remote_exec() { return 0; }
      MOCK_REMOTE_COPY_RESULT=1
      When call _configure_bat
      The status should be failure
    End
  End

  # ===========================================================================
  # _configure_zsh_files()
  # ===========================================================================
  Describe "_configure_zsh_files()"
    BeforeEach 'ADMIN_USERNAME="testadmin"'

    It "configures zsh files successfully"
      MOCK_REMOTE_COPY_RESULT=0
      MOCK_REMOTE_EXEC_RESULT=0
      When call _configure_zsh_files
      The status should be success
    End

    It "fails when zshrc deploy fails"
      MOCK_REMOTE_COPY_RESULT=1
      When call _configure_zsh_files
      The status should be failure
    End

    It "fails when p10k.zsh deploy fails"
      copy_call=0
      deploy_user_config() {
        copy_call=$((copy_call + 1))
        [[ $copy_call -eq 2 ]] && return 1
        return 0
      }
      When call _configure_zsh_files
      The status should be failure
    End

    It "fails when chsh fails"
      MOCK_REMOTE_COPY_RESULT=0
      MOCK_REMOTE_EXEC_RESULT=1
      When call _configure_zsh_files
      The status should be failure
    End
  End

  # ===========================================================================
  # _configure_chrony()
  # ===========================================================================
  Describe "_configure_chrony()"
    It "configures chrony successfully"
      MOCK_REMOTE_EXEC_RESULT=0
      MOCK_REMOTE_COPY_RESULT=0
      When call _configure_chrony
      The status should be success
    End

    It "continues when stop fails (not critical)"
      exec_call=0
      remote_exec() {
        exec_call=$((exec_call + 1))
        [[ $exec_call -eq 1 ]] && return 1  # stop fails
        return 0
      }
      MOCK_REMOTE_COPY_RESULT=0
      When call _configure_chrony
      The status should be success
    End

    It "fails when config copy fails"
      MOCK_REMOTE_COPY_RESULT=1
      When call _configure_chrony
      The status should be failure
    End

    It "fails when enable fails"
      MOCK_REMOTE_COPY_RESULT=0
      exec_call=0
      remote_exec() {
        exec_call=$((exec_call + 1))
        [[ $exec_call -eq 2 ]] && return 1  # enable fails
        return 0
      }
      When call _configure_chrony
      The status should be failure
    End
  End

  # ===========================================================================
  # _configure_unattended_upgrades()
  # ===========================================================================
  Describe "_configure_unattended_upgrades()"
    It "configures unattended-upgrades successfully"
      MOCK_REMOTE_COPY_RESULT=0
      MOCK_REMOTE_EXEC_RESULT=0
      When call _configure_unattended_upgrades
      The status should be success
    End

    It "fails when 50unattended-upgrades copy fails"
      MOCK_REMOTE_COPY_RESULT=1
      When call _configure_unattended_upgrades
      The status should be failure
    End

    It "fails when 20auto-upgrades copy fails"
      copy_call=0
      remote_copy() {
        copy_call=$((copy_call + 1))
        [[ $copy_call -eq 2 ]] && return 1
        return 0
      }
      When call _configure_unattended_upgrades
      The status should be failure
    End

    It "fails when enable fails"
      MOCK_REMOTE_COPY_RESULT=0
      MOCK_REMOTE_EXEC_RESULT=1
      When call _configure_unattended_upgrades
      The status should be failure
    End
  End

  # ===========================================================================
  # _configure_cpu_governor()
  # ===========================================================================
  Describe "_configure_cpu_governor()"
    It "configures with default governor (performance)"
      unset CPU_GOVERNOR
      MOCK_REMOTE_COPY_RESULT=0
      MOCK_REMOTE_EXEC_RESULT=0
      When call _configure_cpu_governor
      The status should be success
    End

    It "configures with custom governor"
      CPU_GOVERNOR="powersave"
      MOCK_REMOTE_COPY_RESULT=0
      MOCK_REMOTE_EXEC_RESULT=0
      When call _configure_cpu_governor
      The status should be success
    End

    It "fails when service file copy fails"
      MOCK_REMOTE_COPY_RESULT=1
      When call _configure_cpu_governor
      The status should be failure
    End

    It "fails when daemon-reload/enable fails"
      MOCK_REMOTE_COPY_RESULT=0
      MOCK_REMOTE_EXEC_RESULT=1
      When call _configure_cpu_governor
      The status should be failure
    End
  End

  # ===========================================================================
  # _configure_io_scheduler()
  # ===========================================================================
  Describe "_configure_io_scheduler()"
    It "configures io scheduler successfully"
      MOCK_REMOTE_COPY_RESULT=0
      MOCK_REMOTE_EXEC_RESULT=0
      When call _configure_io_scheduler
      The status should be success
    End

    It "fails when udev rules copy fails"
      MOCK_REMOTE_COPY_RESULT=1
      When call _configure_io_scheduler
      The status should be failure
    End

    It "fails when udevadm reload fails"
      MOCK_REMOTE_COPY_RESULT=0
      MOCK_REMOTE_EXEC_RESULT=1
      When call _configure_io_scheduler
      The status should be failure
    End
  End

  # ===========================================================================
  # _remove_subscription_notice()
  # ===========================================================================
  Describe "_remove_subscription_notice()"
    It "removes subscription notice successfully"
      MOCK_REMOTE_COPY_RESULT=0
      MOCK_REMOTE_EXEC_RESULT=0
      When call _remove_subscription_notice
      The status should be success
    End

    It "fails when script copy fails"
      MOCK_REMOTE_COPY_RESULT=1
      When call _remove_subscription_notice
      The status should be failure
    End

    It "fails when script execution fails"
      MOCK_REMOTE_COPY_RESULT=0
      MOCK_REMOTE_EXEC_RESULT=1
      When call _remove_subscription_notice
      The status should be failure
    End
  End

  # ===========================================================================
  # _config_base_system()
  # ===========================================================================
  Describe "_config_base_system()"
    BeforeEach 'PVE_HOSTNAME="testhost"; PVE_REPO_TYPE="no-subscription"; LOCALE="en_US.UTF-8"; MOCK_REMOTE_COPY_RESULT=0; MOCK_REMOTE_EXEC_RESULT=0; MOCK_REMOTE_RUN_RESULT=0'

    It "configures base system with no-subscription repo"
      PVE_REPO_TYPE="no-subscription"
      When call _config_base_system
      The status should be success
    End

    It "configures base system with enterprise repo"
      PVE_REPO_TYPE="enterprise"
      PVE_SUBSCRIPTION_KEY=""
      When call _config_base_system
      The status should be success
    End

    It "configures enterprise repo with subscription key"
      PVE_REPO_TYPE="enterprise"
      PVE_SUBSCRIPTION_KEY="pve2s-xxxxxx"
      When call _config_base_system
      The status should be success
    End

    It "defaults to no-subscription when PVE_REPO_TYPE unset"
      unset PVE_REPO_TYPE
      When call _config_base_system
      The status should be success
    End
  End

  # ===========================================================================
  # _config_shell()
  # ===========================================================================
  Describe "_config_shell()"
    BeforeEach 'ADMIN_USERNAME="testadmin"; MOCK_REMOTE_COPY_RESULT=0; MOCK_REMOTE_EXEC_RESULT=0; MOCK_REMOTE_RUN_RESULT=0'

    It "configures zsh when SHELL_TYPE is zsh"
      SHELL_TYPE="zsh"
      When call _config_shell
      The status should be success
    End

    It "skips zsh installation when SHELL_TYPE is bash"
      SHELL_TYPE="bash"
      When call _config_shell
      The status should be success
    End

    It "skips zsh installation when SHELL_TYPE is unset"
      unset SHELL_TYPE
      When call _config_shell
      The status should be success
    End
  End

  # ===========================================================================
  # _config_system_services()
  # ===========================================================================
  Describe "_config_system_services()"
    BeforeEach 'CPU_GOVERNOR="performance"; PVE_REPO_TYPE="no-subscription"; MOCK_REMOTE_COPY_RESULT=0; MOCK_REMOTE_EXEC_RESULT=0; MOCK_REMOTE_RUN_RESULT=0'

    It "configures system services successfully"
      When call _config_system_services
      The status should be success
    End

    It "removes subscription notice for no-subscription"
      PVE_REPO_TYPE="no-subscription"
      When call _config_system_services
      The status should be success
    End

    It "removes subscription notice for test repo"
      PVE_REPO_TYPE="test"
      When call _config_system_services
      The status should be success
    End

    It "skips subscription notice removal for enterprise"
      PVE_REPO_TYPE="enterprise"
      When call _config_system_services
      The status should be success
    End

    It "uses default CPU governor when unset"
      unset CPU_GOVERNOR
      When call _config_system_services
      The status should be success
    End
  End

  # ===========================================================================
  # configure_base_system() - public wrapper
  # ===========================================================================
  Describe "configure_base_system()"
    BeforeEach 'PVE_HOSTNAME="testhost"; PVE_REPO_TYPE="no-subscription"; LOCALE="en_US.UTF-8"; MOCK_REMOTE_COPY_RESULT=0; MOCK_REMOTE_EXEC_RESULT=0; MOCK_REMOTE_RUN_RESULT=0'

    It "calls _config_base_system"
      When call configure_base_system
      The status should be success
    End
  End

  # ===========================================================================
  # configure_shell() - public wrapper
  # ===========================================================================
  Describe "configure_shell()"
    BeforeEach 'ADMIN_USERNAME="testadmin"; SHELL_TYPE="bash"; MOCK_REMOTE_COPY_RESULT=0; MOCK_REMOTE_EXEC_RESULT=0'

    It "calls _config_shell"
      When call configure_shell
      The status should be success
    End
  End

  # ===========================================================================
  # configure_system_services() - public wrapper
  # ===========================================================================
  Describe "configure_system_services()"
    BeforeEach 'CPU_GOVERNOR="performance"; PVE_REPO_TYPE="no-subscription"; MOCK_REMOTE_COPY_RESULT=0; MOCK_REMOTE_EXEC_RESULT=0; MOCK_REMOTE_RUN_RESULT=0'

    It "calls _config_system_services"
      When call configure_system_services
      The status should be success
    End
  End
End

