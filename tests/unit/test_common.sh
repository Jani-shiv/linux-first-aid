#!/usr/bin/env bash
#
# test_common.sh - Unit tests for common.sh
# Part of linux-first-aid toolkit

set -euo pipefail

# Source the library
LFA_LIB_DIR="${LFA_LIB_DIR:-$(dirname "$0")/../../lib}"
source "${LFA_LIB_DIR}/core/common.sh"

# Test framework
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

assert_not_equals() {
    local expected="$1"
    local actual="$2"
    local message="${3:-}"

    if [[ "$expected" != "$actual" ]]; then
        echo "  ✓ $message"
        ((TESTS_PASSED++))
    else
        echo "  ✗ $message"
        echo "    Expected not: $expected"
        echo "    Actual:       $actual"
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

assert_command_succeeds() {
    local cmd="$1"
    local message="${2:-}"

    if eval "$cmd" >/dev/null 2>&1; then
        echo "  ✓ $message"
        ((TESTS_PASSED++))
    else
        echo "  ✗ $message"
        echo "    Command failed: $cmd"
        ((TESTS_FAILED++))
    fi
}

assert_command_fails() {
    local cmd="$1"
    local message="${2:-}"

    if ! eval "$cmd" >/dev/null 2>&1; then
        echo "  ✓ $message"
        ((TESTS_PASSED++))
    else
        echo "  ✗ $message"
        echo "    Command succeeded (expected failure): $cmd"
        ((TESTS_FAILED++))
    fi
}

# Tests
test_lfa_human_readable() {
    echo "Testing lfa_human_readable..."
    assert_equals "1024B" "$(lfa_human_readable 1024)"
    assert_equals "1K" "$(lfa_human_readable 1024)"
    assert_equals "1M" "$(lfa_human_readable 1048576)"
    assert_equals "1G" "$(lfa_human_readable 1073741824)"
    assert_equals "1T" "$(lfa_human_readable 1099511627776)"
}

test_lfa_parse_size() {
    echo "Testing lfa_parse_size..."
    assert_equals "1024" "$(lfa_parse_size "1K")"
    assert_equals "1048576" "$(lfa_parse_size "1M")"
    assert_equals "1073741824" "$(lfa_parse_size "1G")"
    assert_equals "100" "$(lfa_parse_size "100")"
}

test_lfa_timestamp() {
    echo "Testing lfa_timestamp..."
    local ts
    ts=$(lfa_timestamp)
    assert_contains "$ts" "$(date +%Y-%m-%d)"
    assert_contains "$ts" ":"
}

test_lfa_format_elapsed() {
    echo "Testing lfa_format_elapsed..."
    assert_equals "0s" "$(lfa_format_elapsed 0)"
    assert_equals "30s" "$(lfa_format_elapsed 30)"
    assert_equals "1m 30s" "$(lfa_format_elapsed 90)"
    assert_equals "1h 1m 1s" "$(lfa_format_elapsed 3661)"
    assert_equals "1d 1h 1m 1s" "$(lfa_format_elapsed 90061)"
}

test_lfa_in_array() {
    echo "Testing lfa_in_array..."
    local arr=("apple" "banana" "cherry")
    assert_command_succeeds "lfa_in_array apple ${arr[*]}" "apple in array"
    assert_command_fails "lfa_in_array durian ${arr[*]}" "durian not in array"
}

test_lfa_unique_array() {
    echo "Testing lfa_unique_array..."
    local result
    result=$(lfa_unique_array "a" "b" "a" "c" "b")
    assert_equals "a b c" "$result"
}

test_lfa_join_array() {
    echo "Testing lfa_join_array..."
    assert_equals "a,b,c" "$(lfa_join_array "," "a" "b" "c")"
    assert_equals "a b c" "$(lfa_join_array " " "a" "b" "c")"
}

test_lfa_split_string() {
    echo "Testing lfa_split_string..."
    local result
    result=$(lfa_split_string "a,b,c" ",")
    assert_equals "a b c" "$result"
}

test_lfa_get_os_info() {
    echo "Testing lfa_get_os_info..."
    local info
    info=$(lfa_get_os_info)
    assert_contains "$info" "ID="
    assert_contains "$info" "VERSION_ID="
    assert_contains "$info" "PRETTY_NAME="
}

test_lfa_get_package_manager() {
    echo "Testing lfa_get_package_manager..."
    local pm
    pm=$(lfa_get_package_manager)
    assert_not_equals "unknown" "$pm"
}

test_lfa_is_systemd() {
    echo "Testing lfa_is_systemd..."
    if [[ -d /run/systemd/system ]]; then
        assert_command_succeeds "lfa_is_systemd" "systemd detected"
    else
        assert_command_fails "lfa_is_systemd" "systemd not detected"
    fi
}

test_lfa_generate_id() {
    echo "Testing lfa_generate_id..."
    local id1 id2
    id1=$(lfa_generate_id "test")
    id2=$(lfa_generate_id "test")
    assert_contains "$id1" "test-"
    assert_not_equals "$id1" "$id2"
}

# Run all tests
main() {
    echo "Running common.sh unit tests..."
    echo ""

    test_lfa_human_readable
    test_lfa_parse_size
    test_lfa_timestamp
    test_lfa_format_elapsed
    test_lfa_in_array
    test_lfa_unique_array
    test_lfa_join_array
    test_lfa_split_string
    test_lfa_get_os_info
    test_lfa_get_package_manager
    test_lfa_is_systemd
    test_lfa_generate_id

    echo ""
    echo "Results: $TESTS_PASSED passed, $TESTS_FAILED failed"

    if [[ $TESTS_FAILED -gt 0 ]]; then
        exit 1
    fi
}

main "$@"