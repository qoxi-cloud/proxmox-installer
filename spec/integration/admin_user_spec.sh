# shellcheck shell=bash
# shellcheck disable=SC2016,SC2034
# =============================================================================
# Integration tests for admin user creation
# Tests: 302-configure-admin.sh SSH key deployment, sudo, Proxmox role
# Requires: Docker containers running (integration-target)
# =============================================================================

%const SCRIPTS_DIR: "${SHELLSPEC_PROJECT_ROOT}/scripts"
%const SUPPORT_DIR: "${SHELLSPEC_PROJECT_ROOT}/spec/support"

# Load helpers
eval "$(cat "$SUPPORT_DIR/core_mocks.sh")"

# =============================================================================
# Skip checks
# =============================================================================
DOCKER_AVAILABLE=false
TARGET_CONTAINER_READY=false

if command -v docker &>/dev/null && docker info &>/dev/null 2>&1; then
  DOCKER_AVAILABLE=true
  running=$(docker inspect -f '{{.State.Running}}' integration-target 2>/dev/null || echo "false")
  [[ $running == "true" ]] && TARGET_CONTAINER_READY=true
fi

skip_admin_tests() {
  [[ $DOCKER_AVAILABLE != "true" || $TARGET_CONTAINER_READY != "true" ]]
}

# =============================================================================
# Docker-based remote execution
# =============================================================================
setup_docker_remote() {
  remote_exec() {
    docker exec integration-target bash -c "$*"
  }

  remote_copy() {
    docker cp "$1" "integration-target:$2"
  }

  export -f remote_exec remote_copy
}

# =============================================================================
# Test setup
# =============================================================================
setup_admin_test() {
  setup_docker_remote

  # Admin user settings
  ADMIN_USERNAME="testadmin"
  ADMIN_PASSWORD="TestPass123!"
  SSH_PUBLIC_KEY="ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAITestKeyForIntegrationTesting test@host"

  # Mock log function
  LOG_FILE="${SHELLSPEC_TMPBASE}/test.log"
  touch "$LOG_FILE"
  export LOG_FILE

  # Mock run_with_progress - execute function directly
  run_with_progress() {
    local func="$3"
    "$func"
  }
  export -f run_with_progress

  # Mock Proxmox commands (not available in test container)
  docker exec integration-target bash -c '
    # Create mock pveum command
    cat > /usr/local/bin/pveum << "MOCK"
#!/bin/bash
case "$1" in
  user)
    case "$2" in
      list) echo "" ;;
      add) exit 0 ;;
      modify) exit 0 ;;
    esac
    ;;
  acl) exit 0 ;;
esac
MOCK
    chmod +x /usr/local/bin/pveum
  ' 2>/dev/null || true

  # Clean up any existing test user
  docker exec integration-target userdel -rf testadmin 2>/dev/null || true
}

cleanup_admin_test() {
  # Clean up test user
  docker exec integration-target userdel -rf testadmin 2>/dev/null || true
  docker exec integration-target rm -f /etc/sudoers.d/testadmin 2>/dev/null || true
  docker exec integration-target rm -f /usr/local/bin/pveum 2>/dev/null || true
}

Describe "Admin User Integration"
  Skip if "Docker not available or target container not running" skip_admin_tests

  Include "$SCRIPTS_DIR/302-configure-admin.sh"

  BeforeEach 'setup_admin_test'
  AfterEach 'cleanup_admin_test'

  # ===========================================================================
  # User creation
  # ===========================================================================
  Describe "_config_admin_user()"
    It "creates user with home directory"
      When call _config_admin_user
      The status should be success

      # Verify user exists
      docker exec integration-target id testadmin >/dev/null 2>&1
      The status should be success
    End

    It "creates user home directory"
      _config_admin_user

      When call docker exec integration-target test -d /home/testadmin
      The status should be success
    End

    It "adds user to sudo group"
      _config_admin_user

      groups=$(docker exec integration-target groups testadmin 2>/dev/null)
      When call printf '%s' "$groups"
      The output should include "sudo"
    End
  End

  # ===========================================================================
  # SSH key deployment
  # ===========================================================================
  Describe "SSH key deployment"
    It "creates .ssh directory"
      _config_admin_user

      When call docker exec integration-target test -d /home/testadmin/.ssh
      The status should be success
    End

    It "sets correct permissions on .ssh directory"
      _config_admin_user

      perms=$(docker exec integration-target stat -c '%a' /home/testadmin/.ssh)
      When call printf '%s' "$perms"
      The output should equal "700"
    End

    It "creates authorized_keys file"
      _config_admin_user

      When call docker exec integration-target test -f /home/testadmin/.ssh/authorized_keys
      The status should be success
    End

    It "deploys SSH public key"
      _config_admin_user

      content=$(docker exec integration-target cat /home/testadmin/.ssh/authorized_keys)
      When call printf '%s' "$content"
      The output should include "ssh-ed25519"
      The output should include "test@host"
    End

    It "sets correct permissions on authorized_keys"
      _config_admin_user

      perms=$(docker exec integration-target stat -c '%a' /home/testadmin/.ssh/authorized_keys)
      When call printf '%s' "$perms"
      The output should equal "600"
    End

    It "sets correct ownership"
      _config_admin_user

      owner=$(docker exec integration-target stat -c '%U' /home/testadmin/.ssh/authorized_keys)
      When call printf '%s' "$owner"
      The output should equal "testadmin"
    End
  End

  # ===========================================================================
  # Sudo configuration
  # ===========================================================================
  Describe "sudo configuration"
    It "creates sudoers.d file"
      _config_admin_user

      When call docker exec integration-target test -f /etc/sudoers.d/testadmin
      The status should be success
    End

    It "grants NOPASSWD sudo"
      _config_admin_user

      content=$(docker exec integration-target cat /etc/sudoers.d/testadmin)
      When call printf '%s' "$content"
      The output should include "NOPASSWD:ALL"
    End

    It "sets correct permissions on sudoers file"
      _config_admin_user

      perms=$(docker exec integration-target stat -c '%a' /etc/sudoers.d/testadmin)
      When call printf '%s' "$perms"
      The output should equal "440"
    End
  End

  # ===========================================================================
  # Special characters in SSH key
  # ===========================================================================
  Describe "SSH key with special characters"
    It "handles key with spaces in comment"
      SSH_PUBLIC_KEY="ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAITestKey user with spaces@host"

      _config_admin_user

      content=$(docker exec integration-target cat /home/testadmin/.ssh/authorized_keys)
      When call printf '%s' "$content"
      The output should include "user with spaces@host"
    End

    It "handles RSA key"
      SSH_PUBLIC_KEY="ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABgQC12345longrsakeydatahere user@host"

      _config_admin_user

      content=$(docker exec integration-target cat /home/testadmin/.ssh/authorized_keys)
      When call printf '%s' "$content"
      The output should include "ssh-rsa"
    End
  End

  # ===========================================================================
  # configure_admin_user() wrapper
  # ===========================================================================
  Describe "configure_admin_user()"
    It "calls _config_admin_user"
      When call configure_admin_user
      The status should be success

      # Verify user was created
      docker exec integration-target id testadmin >/dev/null 2>&1
      The status should be success
    End

    It "returns success on completion"
      When call configure_admin_user
      The status should be success
    End
  End

  # ===========================================================================
  # Password setting
  # ===========================================================================
  Describe "password configuration"
    It "sets user password"
      _config_admin_user

      # Verify password is set (shadow entry exists)
      shadow=$(docker exec integration-target grep testadmin /etc/shadow)
      When call printf '%s' "$shadow"
      The output should include "testadmin"
      # Password hash should not be empty (* or !)
      The output should not include "testadmin:*"
      The output should not include "testadmin:!"
    End
  End
End

