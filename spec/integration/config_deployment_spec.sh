# shellcheck shell=bash
# shellcheck disable=SC2016,SC2034
# =============================================================================
# Integration tests for configuration deployment
# Tests: deploy_template, deploy_systemd_*, remote_copy with variable substitution
# Requires: Docker containers running (integration-target)
# =============================================================================

%const SCRIPTS_DIR: "${SHELLSPEC_PROJECT_ROOT}/scripts"
%const SUPPORT_DIR: "${SHELLSPEC_PROJECT_ROOT}/spec/support"
%const FIXTURES_DIR: "${SHELLSPEC_PROJECT_ROOT}/spec/fixtures/integration"

# Load helpers
eval "$(cat "$SUPPORT_DIR/core_mocks.sh")"

# =============================================================================
# Skip checks - evaluated at file load time
# =============================================================================
DOCKER_AVAILABLE=false
TARGET_CONTAINER_READY=false

if command -v docker &>/dev/null && docker info &>/dev/null 2>&1; then
  DOCKER_AVAILABLE=true
  running=$(docker inspect -f '{{.State.Running}}' integration-target 2>/dev/null || echo "false")
  [[ $running == "true" ]] && TARGET_CONTAINER_READY=true
fi

skip_config_tests() {
  [[ $DOCKER_AVAILABLE != "true" || $TARGET_CONTAINER_READY != "true" ]]
}

# =============================================================================
# Docker-based remote execution (overrides SSH-based for this test)
# =============================================================================
setup_docker_remote() {
  # Override remote_exec to use docker exec instead of SSH
  remote_exec() {
    docker exec integration-target bash -c "$*"
  }

  # Override remote_copy to use docker cp
  remote_copy() {
    local src="$1"
    local dst="$2"
    docker cp "$src" "integration-target:$dst"
  }

  # Export for subshells
  export -f remote_exec remote_copy
}

setup_config_test() {
  setup_docker_remote

  # Set required globals
  EMAIL="admin@example.com"
  PVE_HOSTNAME="testnode"
  ADMIN_USERNAME="admin"
  INTERFACE_NAME="eth0"
  export EMAIL PVE_HOSTNAME ADMIN_USERNAME INTERFACE_NAME

  # Create templates directory
  mkdir -p "${SHELLSPEC_TMPBASE}/templates"

  # Mock log function
  LOG_FILE="${SHELLSPEC_TMPBASE}/test.log"
  touch "$LOG_FILE"
  export LOG_FILE

  # Mock parallel_mark_configured (no-op for tests)
  parallel_mark_configured() { :; }
  export -f parallel_mark_configured
}

cleanup_config_test() {
  # Clean up files from target container
  docker exec integration-target bash -c 'rm -rf /etc/fail2ban/jail.local /etc/systemd/system/test-*.* /tmp/test-* /etc/test-*' 2>/dev/null || true
  rm -rf "${SHELLSPEC_TMPBASE}/templates" 2>/dev/null || true
}

Describe "Config Deployment Integration"
  Skip if "Docker not available or target container not running" skip_config_tests

  Include "$SCRIPTS_DIR/020-templates.sh"
  Include "$SCRIPTS_DIR/038-deploy-helpers.sh"

  BeforeEach 'setup_config_test'
  AfterEach 'cleanup_config_test'

  # ===========================================================================
  # deploy_template()
  # ===========================================================================
  Describe "deploy_template()"
    It "deploys template with variable substitution"
      # Create test template
      cat >"${SHELLSPEC_TMPBASE}/templates/test.conf" <<'EOF'
hostname = {{HOSTNAME}}
email = {{EMAIL}}
EOF

      When call deploy_template "${SHELLSPEC_TMPBASE}/templates/test.conf" "/tmp/test-deployed.conf" \
        "HOSTNAME=$PVE_HOSTNAME" "EMAIL=$EMAIL"
      The status should be success

      # Verify file on remote
      content=$(docker exec integration-target cat /tmp/test-deployed.conf)
      The value "$content" should include "hostname = testnode"
      The value "$content" should include "email = admin@example.com"
    End

    It "deploys template without variables"
      cat >"${SHELLSPEC_TMPBASE}/templates/plain.conf" <<'EOF'
static content
no variables
EOF

      When call deploy_template "${SHELLSPEC_TMPBASE}/templates/plain.conf" "/tmp/test-plain.conf"
      The status should be success

      content=$(docker exec integration-target cat /tmp/test-plain.conf)
      The value "$content" should include "static content"
    End

    It "fails for non-existent template"
      When call deploy_template "/nonexistent/template" "/tmp/dest"
      The status should be failure
      The stderr should include "No such file"
    End

    It "fails when variable substitution leaves unsubstituted placeholders"
      cat >"${SHELLSPEC_TMPBASE}/templates/incomplete.conf" <<'EOF'
needs = {{MISSING_VAR}}
EOF

      # deploy_template fails when apply_template_vars fails (missing var)
      When call deploy_template "${SHELLSPEC_TMPBASE}/templates/incomplete.conf" "/tmp/test-fail.conf" "OTHER_VAR=value"
      The status should be failure
    End
  End

  # ===========================================================================
  # Note: deploy_systemd_service() and deploy_systemd_timer() are tested
  # via unit tests. Integration testing these requires template files
  # without .tmpl extension which is handled by the download pipeline.
  # ===========================================================================

  # ===========================================================================
  # remote_enable_services()
  # ===========================================================================
  Describe "remote_enable_services()"
    It "enables multiple services"
      # Create test services first
      docker exec integration-target bash -c 'cat > /etc/systemd/system/test-svc1.service << EOF
[Unit]
Description=Test 1
[Service]
Type=oneshot
ExecStart=/bin/true
[Install]
WantedBy=multi-user.target
EOF'
      docker exec integration-target bash -c 'cat > /etc/systemd/system/test-svc2.service << EOF
[Unit]
Description=Test 2
[Service]
Type=oneshot
ExecStart=/bin/true
[Install]
WantedBy=multi-user.target
EOF'
      docker exec integration-target systemctl daemon-reload

      When call remote_enable_services "test-svc1" "test-svc2"
      The status should be success

      # Verify services enabled (suppress output)
      docker exec integration-target systemctl is-enabled test-svc1 >/dev/null 2>&1
      The status should be success
      docker exec integration-target systemctl is-enabled test-svc2 >/dev/null 2>&1
      The status should be success
    End

    It "succeeds with empty list"
      When call remote_enable_services
      The status should be success
    End
  End

  # ===========================================================================
  # File permissions and ownership
  # ===========================================================================
  Describe "file deployment permissions"
    It "deploys config files with default permissions"
      cat >"${SHELLSPEC_TMPBASE}/templates/perms-test.conf" <<'EOF'
test content
EOF

      deploy_template "${SHELLSPEC_TMPBASE}/templates/perms-test.conf" "/tmp/perms-test.conf"

      # Verify file exists and is readable
      When call docker exec integration-target cat /tmp/perms-test.conf
      The status should be success
      The output should equal "test content"
    End
  End

  # ===========================================================================
  # deploy_user_config()
  # ===========================================================================
  Describe "deploy_user_config()"
    BeforeEach 'docker exec integration-target useradd -m admin 2>/dev/null || true'
    AfterEach 'docker exec integration-target userdel -r admin 2>/dev/null || true'

    It "deploys config to user home directory"
      cat >"${SHELLSPEC_TMPBASE}/templates/user-config" <<'EOF'
user specific config
EOF

      When call deploy_user_config "${SHELLSPEC_TMPBASE}/templates/user-config" ".config/test/config"
      The status should be success

      # Verify file exists with correct ownership
      docker exec integration-target test -f /home/admin/.config/test/config
      The status should be success

      owner=$(docker exec integration-target stat -c '%U' /home/admin/.config/test/config)
      The value "$owner" should equal "admin"
    End

    It "creates parent directories as needed"
      cat >"${SHELLSPEC_TMPBASE}/templates/deep-config" <<'EOF'
deep config
EOF

      When call deploy_user_config "${SHELLSPEC_TMPBASE}/templates/deep-config" ".config/deep/nested/path/config"
      The status should be success

      docker exec integration-target test -f /home/admin/.config/deep/nested/path/config
      The status should be success
    End
  End

  # ===========================================================================
  # End-to-end config deployment
  # ===========================================================================
  Describe "complete configuration workflow"
    It "deploys multiple configs in sequence"
      # Create templates
      cat >"${SHELLSPEC_TMPBASE}/templates/config1.conf" <<'EOF'
first config for {{HOSTNAME}}
EOF
      cat >"${SHELLSPEC_TMPBASE}/templates/config2.conf" <<'EOF'
second config for {{HOSTNAME}}
EOF

      # Deploy both
      deploy_template "${SHELLSPEC_TMPBASE}/templates/config1.conf" "/etc/test-config1.conf" "HOSTNAME=$PVE_HOSTNAME"
      result1=$?
      deploy_template "${SHELLSPEC_TMPBASE}/templates/config2.conf" "/etc/test-config2.conf" "HOSTNAME=$PVE_HOSTNAME"
      result2=$?

      When call printf '%s %s' "$result1" "$result2"
      The output should equal "0 0"

      # Verify both deployed
      docker exec integration-target cat /etc/test-config1.conf | grep -q "testnode"
      The status should be success
      docker exec integration-target cat /etc/test-config2.conf | grep -q "testnode"
      The status should be success
    End
  End
End

