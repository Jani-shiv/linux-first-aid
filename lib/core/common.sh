#!/usr/bin/env bash
#
# common.sh - Common utilities and shared functions
# Part of linux-first-aid toolkit
#
# Copyright (c) 2024 linux-first-aid contributors
# Licensed under the MIT License

set -euo pipefail

readonly LFA_LIB_DIR="${LFA_LIB_DIR:-/usr/share/linux-first-aid/lib}"
readonly LFA_CONFIG_DIR="${LFA_CONFIG_DIR:-/etc/linux-first-aid}"
readonly LFA_DATA_DIR="${LFA_DATA_DIR:-/var/lib/linux-first-aid}"
readonly LFA_CACHE_DIR="${LFA_CACHE_DIR:-/var/cache/linux-first-aid}"
readonly LFA_LOG_DIR="${LFA_LOG_DIR:-/var/log/linux-first-aid}"

readonly LFA_TEMP_DIR="$(mktemp -d -t lfa.XXXXXX)"
readonly LFA_PID_FILE="${LFA_TEMP_DIR}/lfa.pid"

trap 'lfa_cleanup' EXIT INT TERM

lfa_cleanup() {
    local exit_code=$?
    if [[ -d "$LFA_TEMP_DIR" ]]; then
        rm -rf "$LFA_TEMP_DIR"
    fi
    exit $exit_code
}

lfa_require_root() {
    if [[ $EUID -ne 0 ]]; then
        log_error "This operation requires root privileges. Run with sudo."
        return 1
    fi
}

lfa_check_command() {
    local cmd="$1"
    if ! command -v "$cmd" &>/dev/null; then
        log_debug "Command not found: $cmd"
        return 1
    fi
    return 0
}

lfa_get_os_info() {
    if [[ -f /etc/os-release ]]; then
        # shellcheck source=/dev/null
        source /etc/os-release
        echo "ID=${ID:-unknown} VERSION_ID=${VERSION_ID:-unknown} PRETTY_NAME=${PRETTY_NAME:-unknown}"
    else
        echo "ID=unknown VERSION_ID=unknown PRETTY_NAME=unknown"
    fi
}

lfa_get_kernel_version() {
    uname -r
}

lfa_get_arch() {
    uname -m
}

lfa_is_systemd() {
    [[ -d /run/systemd/system ]] || [[ "$(ps --no-headers -o comm 1)" == "systemd" ]]
}

lfa_is_container() {
    [[ -f /.dockerenv ]] || grep -qE 'container|lxc|docker' /proc/1/cgroup 2>/dev/null
}

lfa_get_package_manager() {
    if lfa_check_command apt; then
        echo "apt"
    elif lfa_check_command dnf; then
        echo "dnf"
    elif lfa_check_command yum; then
        echo "yum"
    elif lfa_check_command pacman; then
        echo "pacman"
    elif lfa_check_command zypper; then
        echo "zypper"
    elif lfa_check_command apk; then
        echo "apk"
    else
        echo "unknown"
    fi
}

lfa_get_init_system() {
    if lfa_is_systemd; then
        echo "systemd"
    elif [[ -f /sbin/openrc-run ]] || [[ -f /usr/sbin/openrc-run ]]; then
        echo "openrc"
    elif [[ -f /sbin/runit-init ]]; then
        echo "runit"
    elif [[ -f /sbin/s6-svscan ]]; then
        echo "s6"
    else
        echo "sysvinit"
    fi
}

lfa_human_readable() {
    local bytes="$1"
    local units=("B" "K" "M" "G" "T" "P")
    local i=0
    local value="$bytes"

    while [[ $value -ge 1024 && $i -lt ${#units[@]} ]]; do
        value=$((value / 1024))
        ((i++))
    done
    echo "${value}${units[$i]}"
}

lfa_parse_size() {
    local size="$1"
    local num="${size%[KMGTPE]*}"
    local unit="${size##*[0-9]}"

    case "${unit^^}" in
        K) echo $((num * 1024)) ;;
        M) echo $((num * 1024 * 1024)) ;;
        G) echo $((num * 1024 * 1024 * 1024)) ;;
        T) echo $((num * 1024 * 1024 * 1024 * 1024)) ;;
        P) echo $((num * 1024 * 1024 * 1024 * 1024 * 1024)) ;;
        E) echo $((num * 1024 * 1024 * 1024 * 1024 * 1024 * 1024)) ;;
        *) echo "$num" ;;
    esac
}

lfa_timestamp() {
    date '+%Y-%m-%d %H:%M:%S'
}

lfa_timestamp_iso() {
    date -u '+%Y-%m-%dT%H:%M:%SZ'
}

lfa_elapsed() {
    local start="$1"
    local end="${2:-$(date +%s)}"
    echo $((end - start))
}

lfa_format_elapsed() {
    local seconds="$1"
    local days=$((seconds / 86400))
    local hours=$(((seconds % 86400) / 3600))
    local minutes=$(((seconds % 3600) / 60))
    local secs=$((seconds % 60))

    local parts=()
    [[ $days -gt 0 ]] && parts+=("${days}d")
    [[ $hours -gt 0 ]] && parts+=("${hours}h")
    [[ $minutes -gt 0 ]] && parts+=("${minutes}m")
    [[ $secs -gt 0 || ${#parts[@]} -eq 0 ]] && parts+=("${secs}s")

    echo "${parts[*]}"
}

lfa_spinner() {
    local pid="$1"
    local message="${2:-Working...}"
    local spin='⠋⠙⠹⠸⠼⠴⠦⠧⠇⠏'
    local i=0

    if [[ "${LFA_QUIET:-false}" == "true" ]] || [[ "${LFA_NO_COLOR:-false}" == "true" ]]; then
        wait "$pid"
        return
    fi

    tput civis 2>/dev/null || true
    while kill -0 "$pid" 2>/dev/null; do
        printf "\r%s %s" "${spin:i++%${#spin}:1}" "$message"
        sleep 0.1
    done
    printf "\r%s\n" "$message"
    tput cnorm 2>/dev/null || true
    wait "$pid"
}

lfa_run_with_timeout() {
    local timeout="$1"
    shift
    local cmd=("$@")

    timeout "$timeout" "${cmd[@]}"
}

lfa_confirm() {
    local prompt="${1:-Are you sure?}"
    local default="${2:-n}"

    if [[ "${LFA_QUIET:-false}" == "true" ]] || [[ "${LFA_FORCE:-false}" == "true" ]]; then
        return 0
    fi

    local yn
    if [[ "$default" == "y" ]]; then
        read -rp "$prompt [Y/n]: " yn
        yn=${yn:-y}
    else
        read -rp "$prompt [y/N]: " yn
        yn=${yn:-n}
    fi

    [[ "${yn,,}" == "y" ]]
}

lfa_join_array() {
    local delimiter="$1"
    shift
    local arr=("$@")
    local IFS="$delimiter"
    echo "${arr[*]}"
}

lfa_split_string() {
    local string="$1"
    local delimiter="${2:- }"
    local IFS="$delimiter"
    read -ra arr <<< "$string"
    echo "${arr[@]}"
}

lfa_in_array() {
    local needle="$1"
    shift
    local haystack=("$@")

    for item in "${haystack[@]}"; do
        if [[ "$item" == "$needle" ]]; then
            return 0
        fi
    done
    return 1
}

lfa_unique_array() {
    local arr=("$@")
    local seen=()
    local result=()

    for item in "${arr[@]}"; do
        if ! lfa_in_array "$item" "${seen[@]}"; then
            seen+=("$item")
            result+=("$item")
        fi
    done
    echo "${result[@]}"
}

lfa_retry() {
    local max_attempts="${1:-3}"
    local delay="${2:-2}"
    local cmd=("${@:3}")
    local attempt=1

    while [[ $attempt -le $max_attempts ]]; do
        if "${cmd[@]}"; then
            return 0
        fi
        log_warn "Attempt $attempt/$max_attempts failed. Retrying in ${delay}s..."
        sleep "$delay"
        ((attempt++))
    done

    log_error "All $max_attempts attempts failed"
    return 1
}

lfa_hash_file() {
    local file="$1"
    local algo="${2:-sha256}"

    if lfa_check_command "${algo}sum"; then
        "${algo}sum" "$file" | awk '{print $1}'
    elif lfa_check_command "openssl"; then
        openssl dgst -"$algo" "$file" | awk '{print $2}'
    else
        log_error "No hash utility available"
        return 1
    fi
}

lfa_generate_id() {
    local prefix="${1:-lfa}"
    echo "${prefix}-$(date +%s)-$$-$RANDOM"
}

lfa_lock() {
    local lock_file="$1"
    local timeout="${2:-30}"
    local start_time=$(date +%s)

    while ! mkdir "$lock_file" 2>/dev/null; do
        if (( $(date +%s) - start_time > timeout )); then
            log_error "Lock timeout: $lock_file"
            return 1
        fi
        sleep 0.1
    done
    echo $$ > "$lock_file/pid"
    return 0
}

lfa_unlock() {
    local lock_file="$1"
    rm -rf "$lock_file"
}

lfa_is_mounted() {
    local mount_point="$1"
    mountpoint -q "$mount_point"
}

lfa_get_mount_info() {
    local mount_point="$1"
    findmnt -n -o SOURCE,FSTYPE,SIZE,USED,AVAIL,USE% "$mount_point" 2>/dev/null
}

lfa_get_disk_usage() {
    local path="${1:-/}"
    df -h "$path" | tail -1
}

lfa_get_memory_info() {
    free -h
}

lfa_get_cpu_info() {
    lscpu
}

lfa_get_load_average() {
    cat /proc/loadavg
}

lfa_get_uptime() {
    cat /proc/uptime
}

lfa_get_process_count() {
    ps aux --no-headers | wc -l
}

lfa_get_open_files() {
    lsof 2>/dev/null | wc -l
}

lfa_get_network_connections() {
    ss -tun 2>/dev/null | tail -n +2 | wc -l
}

lfa_get_listening_ports() {
    ss -tuln 2>/dev/null | tail -n +2
}

lfa_get_failed_services() {
    if lfa_is_systemd; then
        systemctl list-units --state=failed --no-legend 2>/dev/null | awk '{print $1}'
    else
        return 1
    fi
}

lfa_get_enabled_services() {
    if lfa_is_systemd; then
        systemctl list-unit-files --state=enabled --no-legend 2>/dev/null | awk '{print $1}'
    else
        return 1
    fi
}

lfa_service_status() {
    local service="$1"
    if lfa_is_systemd; then
        systemctl is-active "$service" 2>/dev/null
    else
        service "$service" status 2>/dev/null
    fi
}

lfa_service_enabled() {
    local service="$1"
    if lfa_is_systemd; then
        systemctl is-enabled "$service" 2>/dev/null
    else
        return 1
    fi
}