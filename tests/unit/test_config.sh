#!/usr/bin/env bash
#
# test_config.sh - Unit tests for config.sh
# Part of linux-first-aid toolkit

set -euo pipefail

LFA_LIB_DIR="${LFA_LIB_DIR:-$(dirname "$0")/../../lib}"
source "${LFA_LIB_DIR}/core/config.sh"

TESTS_PASSED=0
TESTS_FAILED=0

assert_equals() {
    local expected="$1"
    local actual="$2"
    local message="${3:-}"

    if [[ "$expected" == "$actual" ]]; then
        echo "  ✓ $message"
        ((TESTS_PASSED++))
    else
        echo "  ✗ $message"
        echo "    Expected: $expected"
        echo "    Actual:   $actual"
        ((TESTS_FAILED++))
    fi
}

assert_contains() {
    local haystack="$1"
    local needle="$2"
    local message="${3:-}"

    if [[ "$haystack" == *"$needle"* ]]; then
        echo "  ✓ $message"
        ((TESTS_PASSED++))
    else
        echo "  ✗ $message"
        echo "    Haystack: $haystack"
        echo "    Needle:   $needle"
        ((TESTS_FAILED++))
    fi
}

test_lfa_load_config_defaults() {
    echo "Testing lfa_load_config with defaults..."
    LFA_CONFIG_FILE="/nonexistent"
    lfa_load_config
    assert_equals "300" "${LFA_CONFIG[general.check_interval]}"
    assert_equals "warn" "${LFA_CONFIG[general.alert_threshold]}"
}

test_lfa_get_config() {
    echo "Testing lfa_get_config..."
    LFA_CONFIG[test.key]="test_value"
    assert_equals "test_value" "$(lfa_get_config "test.key")"
    assert_equals "default" "$(lfa_get_config "nonexistent" "default")"
}

test_lfa_set_config() {
    echo "Testing lfa_set_config..."
    lfa_set_config "new.key" "new_value"
    assert_equals "new_value" "${LFA_CONFIG[new.key]}"
}

test_lfa_list_config() {
    echo "Testing lfa_list_config..."
    LFA_CONFIG[test.a]="1"
    LFA_CONFIG[test.b]="2"
    local output
    output=$(lfa_list_config "test.")
    assert_contains "$output" "test.a: 1"
    assert_contains "$output" "test.b: 2"
}

test_lfa_reset_config() {
    echo "Testing lfa_reset_config..."
    LFA_CONFIG[custom.key]="custom"
    lfa_reset_config
    assert_equals "" "${LFA_CONFIG[custom.key]:-}"
    assert_equals "300" "${LFA_CONFIG[general.check_interval]}"
}

main() {
    echo "Running config.sh unit tests..."
    echo ""

    test_lfa_load_config_defaults
    test_lfa_get_config
    test_lfa_set_config
    test_lfa_list_config
    test_lfa_reset_config

    echo ""
    echo "Results: $TESTS_PASSED passed, $TESTS_FAILED failed"

    if [[ $TESTS_FAILED -gt 0 ]]; then
        exit 1
    fi
}

main "$@"