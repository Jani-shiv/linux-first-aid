#!/usr/bin/env bash
#
# test_logger.sh - Unit tests for logger.sh
# Part of linux-first-aid toolkit

set -euo pipefail

LFA_LIB_DIR="${LFA_LIB_DIR:-$(dirname "$0")/../../lib}"
source "${LFA_LIB_DIR}/core/logger.sh"
source "${LFA_LIB_DIR}/utils/utils.sh"

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

test_log_levels() {
    echo "Testing log levels..."
    LFA_LOG_LEVEL=0
    assert_equals "0" "$LFA_LOG_LEVEL"

    LFA_LOG_LEVEL=1
    assert_equals "1" "$LFA_LOG_LEVEL"
}

test_lfa_init_logger() {
    echo "Testing lfa_init_logger..."
    LFA_QUIET=false
    LFA_DEBUG=false
    LFA_NO_COLOR=false
    lfa_init_logger
    assert_equals "1" "$LFA_LOG_LEVEL"
}

test_lfa_set_get_log_level() {
    echo "Testing lfa_set_log_level and lfa_get_log_level..."
    lfa_set_log_level "debug"
    assert_equals "debug" "$(lfa_get_log_level)"

    lfa_set_log_level "info"
    assert_equals "info" "$(lfa_get_log_level)"

    lfa_set_log_level "warn"
    assert_equals "warn" "$(lfa_get_log_level)"

    lfa_set_log_level "error"
    assert_equals "error" "$(lfa_get_log_level)"

    lfa_set_log_level "quiet"
    assert_equals "quiet" "$(lfa_get_log_level)"
}

test_lfa_json_escape() {
    echo "Testing lfa_json_escape..."
    assert_equals 'hello world' "$(lfa_json_escape 'hello world')"
    assert_equals 'hello\"world' "$(lfa_json_escape 'hello"world')"
    assert_equals 'hello\\world' "$(lfa_json_escape 'hello\world')"
    assert_equals 'hello\nworld' "$(lfa_json_escape $'hello\nworld')"
    assert_equals 'hello\tworld' "$(lfa_json_escape $'hello\tworld')"
}

main() {
    echo "Running logger.sh unit tests..."
    echo ""

    test_log_levels
    test_lfa_init_logger
    test_lfa_set_get_log_level
    test_lfa_json_escape

    echo ""
    echo "Results: $TESTS_PASSED passed, $TESTS_FAILED failed"

    if [[ $TESTS_FAILED -gt 0 ]]; then
        exit 1
    fi
}

main "$@"
