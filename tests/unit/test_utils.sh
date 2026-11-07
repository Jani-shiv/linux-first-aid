#!/usr/bin/env bash
#
# test_utils.sh - Unit tests for utils.sh
# Part of linux-first-aid toolkit

set -euo pipefail

LFA_LIB_DIR="${LFA_LIB_DIR:-$(dirname "$0")/../../lib}"
source "${LFA_LIB_DIR}/utils/utils.sh"

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

test_lfa_json_escape() {
    echo "Testing lfa_json_escape..."
    assert_equals 'hello world' "$(lfa_json_escape 'hello world')"
    assert_equals 'hello\"world' "$(lfa_json_escape 'hello"world')"
    assert_equals 'hello\\world' "$(lfa_json_escape 'hello\world')"
}

test_lfa_url_encode_decode() {
    echo "Testing lfa_url_encode/decode..."
    local encoded
    encoded=$(lfa_url_encode "hello world!")
    assert_equals "hello%20world%21" "$encoded"

    local decoded
    decoded=$(lfa_url_decode "$encoded")
    assert_equals "hello world!" "$decoded"
}

test_lfa_base64_encode_decode() {
    echo "Testing lfa_base64_encode/decode..."
    local encoded
    encoded=$(lfa_base64_encode "hello world")
    assert_equals "aGVsbG8gd29ybGQ=" "$encoded"

    local decoded
    decoded=$(lfa_base64_decode "$encoded")
    assert_equals "hello world" "$decoded"
}

test_lfa_is_valid_ip() {
    echo "Testing lfa_is_valid_ip..."
    assert_command_succeeds "lfa_is_valid_ip 192.168.1.1" "valid IPv4"
    assert_command_succeeds "lfa_is_valid_ip 10.0.0.1" "valid IPv4"
    assert_command_fails "lfa_is_valid_ip 256.1.1.1" "invalid IPv4"
    assert_command_fails "lfa_is_valid_ip not.an.ip" "invalid format"
}

test_lfa_is_valid_cidr() {
    echo "Testing lfa_is_valid_cidr..."
    assert_command_succeeds "lfa_is_valid_cidr 192.168.1.0/24" "valid CIDR"
    assert_command_succeeds "lfa_is_valid_cidr 10.0.0.0/8" "valid CIDR"
    assert_command_fails "lfa_is_valid_cidr 192.168.1.0/33" "invalid prefix"
    assert_command_fails "lfa_is_valid_cidr not.a.cidr" "invalid format"
}

test_lfa_is_valid_hostname() {
    echo "Testing lfa_is_valid_hostname..."
    assert_command_succeeds "lfa_is_valid_hostname example.com" "valid hostname"
    assert_command_succeeds "lfa_is_valid_hostname sub.domain.example.com" "valid subdomain"
    assert_command_fails "lfa_is_valid_hostname -invalid.com" "invalid start"
    assert_command_fails "lfa_is_valid_hostname invalid-.com" "invalid end"
}

test_lfa_is_valid_port() {
    echo "Testing lfa_is_valid_port..."
    assert_command_succeeds "lfa_is_valid_port 80" "valid port"
    assert_command_succeeds "lfa_is_valid_port 65535" "max port"
    assert_command_fails "lfa_is_valid_port 0" "zero port"
    assert_command_fails "lfa_is_valid_port 65536" "overflow port"
    assert_command_fails "lfa_is_valid_port abc" "non-numeric"
}

test_lfa_json_parse() {
    echo "Testing lfa_json_parse..."
    if command -v jq >/dev/null; then
        local json='{"name":"test","value":123}'
        assert_equals "test" "$(lfa_json_parse "$json" ".name")"
        assert_equals "123" "$(lfa_json_parse "$json" ".value")"
    else
        echo "  ⊘ Skipped (jq not available)"
    fi
}

test_lfa_read_write_file() {
    echo "Testing lfa_read_file/lfa_write_file..."
    local test_file="/tmp/lfa_test_$$"
    local content="test content"

    lfa_write_file "$test_file" "$content"
    assert_equals "$content" "$(lfa_read_file "$test_file")"
    rm -f "$test_file"
}

test_lfa_backup_restore_file() {
    echo "Testing lfa_backup_file/lfa_restore_file..."
    local test_file="/tmp/lfa_test_$$"
    local backup_dir="/tmp/lfa_backup_$$"
    local content="original"
    local new_content="modified"

    echo "$content" > "$test_file"
    local backup
    backup=$(lfa_backup_file "$test_file" "$backup_dir")
    assert_command_succeeds "test -f $backup" "backup created"

    echo "$new_content" > "$test_file"
    lfa_restore_file "$test_file" "$backup"
    assert_equals "$content" "$(cat "$test_file")"

    rm -f "$test_file"
    rm -rf "$backup_dir"
}

main() {
    echo "Running utils.sh unit tests..."
    echo ""

    test_lfa_json_escape
    test_lfa_url_encode_decode
    test_lfa_base64_encode_decode
    test_lfa_is_valid_ip
    test_lfa_is_valid_cidr
    test_lfa_is_valid_hostname
    test_lfa_is_valid_port
    test_lfa_json_parse
    test_lfa_read_write_file
    test_lfa_backup_restore_file

    echo ""
    echo "Results: $TESTS_PASSED passed, $TESTS_FAILED failed"

    if [[ $TESTS_FAILED -gt 0 ]]; then
        exit 1
    fi
}

main "$@"