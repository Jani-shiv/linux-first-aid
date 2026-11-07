#!/usr/bin/env bash
#
# test_integration.sh - Integration tests for linux-first-aid
# Part of linux-first-aid toolkit

set -euo pipefail

# These tests require root and a real system
# Run with: sudo make test-integration

LFA_LIB_DIR="${LFA_LIB_DIR:-$(dirname "$0")/../../lib}"
source "${LFA_LIB_DIR}/core/common.sh"
source "${LFA_LIB_DIR}/core/logger.sh"
source "${LFA_LIB_DIR}/core/config.sh"

TESTS_PASSED=0
TESTS_FAILED=0

assert_equals() {
    local expected="$1"
    local actual="$2"
    local message="${3:-}"

    if [[ "$expected" == "$actual" ]]; then
        echo "  ✓ $message"
        ((TESTS_PASSED += 1))
    else
        echo "  ✗ $message"
        echo "    Expected: $expected"
        echo "    Actual:   $actual"
        ((TESTS_FAILED += 1))
    fi
}

assert_command_succeeds() {
    local cmd="$1"
    local message="${2:-}"

    if eval "$cmd" >/dev/null 2>&1; then
        echo "  ✓ $message"
        ((TESTS_PASSED += 1))
    else
        echo "  ✗ $message"
        echo "    Command failed: $cmd"
        ((TESTS_FAILED += 1))
    fi
}

test_binary_exists() {
    echo "Testing binary exists..."
    assert_command_succeeds "command -v first-aid" "first-aid in PATH"
}

test_help() {
    echo "Testing help output..."
    assert_command_succeeds "first-aid --help" "main help"
    assert_command_succeeds "first-aid diagnose --help" "diagnose help"
    assert_command_succeeds "first-aid check --help" "check help"
    assert_command_succeeds "first-aid repair --help" "repair help"
    assert_command_succeeds "first-aid fix --help" "fix help"
    assert_command_succeeds "first-aid monitor --help" "monitor help"
    assert_command_succeeds "first-aid analyze --help" "analyze help"
    assert_command_succeeds "first-aid report --help" "report help"
    assert_command_succeeds "first-aid config --help" "config help"
}

test_version() {
    echo "Testing version output..."
    assert_command_succeeds "first-aid --version" "version output"
}

test_diagnose_quick() {
    echo "Testing quick diagnosis..."
    assert_command_succeeds "first-aid diagnose --quick" "quick diagnose"
}

test_check_disk() {
    echo "Testing disk check..."
    assert_command_succeeds "first-aid check disk" "disk check"
}

test_check_memory() {
    echo "Testing memory check..."
    assert_command_succeeds "first-aid check memory" "memory check"
}

test_check_cpu() {
    echo "Testing CPU check..."
    assert_command_succeeds "first-aid check cpu" "cpu check"
}

test_check_network() {
    echo "Testing network check..."
    assert_command_succeeds "first-aid check network" "network check"
}

test_config_get_set() {
    echo "Testing config get/set..."
    assert_command_succeeds "first-aid config get general.check_interval" "config get"
    first-aid config set test.integration_test "value" >/dev/null 2>&1
    assert_equals "value" "$(first-aid config get test.integration_test)"
}

test_report_text() {
    echo "Testing text report..."
    assert_command_succeeds "first-aid report --format text" "text report"
}

test_report_json() {
    echo "Testing JSON report..."
    assert_command_succeeds "first-aid report --format json" "json report"
}

test_fix_dry_run() {
    echo "Testing fix dry-run..."
    assert_command_succeeds "first-aid fix clean-package-cache --dry-run" "clean cache dry-run"
    assert_command_succeeds "first-aid fix clear-journals --dry-run" "clear journals dry-run"
    assert_command_succeeds "first-aid fix trim-ssd --dry-run" "trim ssd dry-run"
}

main() {
    echo "Running integration tests..."
    echo ""

    test_binary_exists
    test_help
    test_version
    test_diagnose_quick
    test_check_disk
    test_check_memory
    test_check_cpu
    test_check_network
    test_config_get_set
    test_report_text
    test_report_json
    test_fix_dry_run

    echo ""
    echo "Results: $TESTS_PASSED passed, $TESTS_FAILED failed"

    if [[ $TESTS_FAILED -gt 0 ]]; then
        exit 1
    fi
}

main "$@"
