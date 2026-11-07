#!/usr/bin/env bash
#
# utils.sh - Utility functions
# Part of linux-first-aid toolkit
#
# Copyright (c) 2024 linux-first-aid contributors
# Licensed under the MIT License

set -euo pipefail

lfa_read_file() {
    local file="$1"
    if [[ -f "$file" && -r "$file" ]]; then
        cat "$file"
    else
        return 1
    fi
}

lfa_write_file() {
    local file="$1"
    local content="$2"
    local mode="${3:-644}"

    mkdir -p "$(dirname "$file")"
    echo "$content" >"$file"
    chmod "$mode" "$file"
}

lfa_append_file() {
    local file="$1"
    local content="$2"

    mkdir -p "$(dirname "$file")"
    echo "$content" >>"$file"
}

lfa_backup_file() {
    local file="$1"
    local backup_dir="${2:-$LFA_CACHE_DIR/backups}"
    local timestamp
    timestamp=$(date +%Y%m%d-%H%M%S)

    if [[ -f "$file" ]]; then
        mkdir -p "$backup_dir"
        local backup_file="$backup_dir/$(basename "$file").$timestamp.bak"
        cp "$file" "$backup_file"
        echo "$backup_file"
    fi
}

lfa_restore_file() {
    local file="$1"
    local backup_file="$2"

    if [[ -f "$backup_file" ]]; then
        cp "$backup_file" "$file"
        return 0
    fi
    return 1
}

lfa_diff_files() {
    local file1="$1"
    local file2="$2"

    if lfa_check_command diff; then
        diff -u "$file1" "$file2" || true
    elif lfa_check_command git; then
        git diff --no-index "$file1" "$file2" || true
    else
        log_error "No diff utility available"
        return 1
    fi
}

lfa_find_files() {
    local path="$1"
    local pattern="${2:-*}"
    local max_depth="${3:-}"

    local find_cmd=(find "$path" -name "$pattern")
    if [[ -n "$max_depth" ]]; then
        find_cmd+=(-maxdepth "$max_depth")
    fi
    "${find_cmd[@]}" 2>/dev/null
}

lfa_find_large_files() {
    local path="${1:-/}"
    local size="${2:-100M}"
    local count="${3:-20}"

    find "$path" -type f -size +"$size" -exec ls -lh {} + 2>/dev/null |
        sort -k5 -hr | head -n "$count"
}

lfa_find_old_files() {
    local path="${1:-/}"
    local days="${2:-30}"
    local count="${3:-20}"

    find "$path" -type f -mtime +"$days" -exec ls -lh {} + 2>/dev/null |
        sort -k6,7 | head -n "$count"
}

lfa_get_file_type() {
    local file="$1"
    file -b "$file" 2>/dev/null
}

lfa_is_text_file() {
    local file="$1"
    [[ "$(lfa_get_file_type "$file")" == *text* ]]
}

lfa_get_mime_type() {
    local file="$1"
    file -b --mime-type "$file" 2>/dev/null
}

lfa_exec_safe() {
    local cmd=("$@")
    local timeout="${LFA_CMD_TIMEOUT:-30}"

    if lfa_check_command timeout; then
        timeout "$timeout" "${cmd[@]}"
    else
        "${cmd[@]}"
    fi
}

lfa_pipe_exec() {
    local input="$1"
    shift
    local cmd=("$@")

    echo "$input" | "${cmd[@]}"
}

lfa_json_escape() {
    local string="$1"
    string="${string//\\/\\\\}"
    string="${string//\"/\\\"}"
    string="${string//$'\n'/\\n}"
    string="${string//$'\r'/\\r}"
    string="${string//$'\t'/\\t}"
    echo "$string"
}

lfa_json_parse() {
    local json="$1"
    local key="$2"

    if lfa_check_command jq; then
        echo "$json" | jq -r "$key"
    elif lfa_check_command python3; then
        python3 -c "import sys, json; print(json.load(sys.stdin).get('$key', ''))" <<<"$json"
    else
        log_error "No JSON parser available (jq or python3 required)"
        return 1
    fi
}

lfa_yaml_parse() {
    local yaml="$1"
    local key="$2"

    if lfa_check_command yq; then
        echo "$yaml" | yq -r "$key"
    elif lfa_check_command python3; then
        python3 -c "import sys, yaml; print(yaml.safe_load(sys.stdin).get('$key', ''))" <<<"$yaml"
    else
        log_error "No YAML parser available (yq or python3 required)"
        return 1
    fi
}

lfa_xml_parse() {
    local xml="$1"
    local xpath="$2"

    if lfa_check_command xmllint; then
        echo "$xml" | xmllint --xpath "$xpath" - 2>/dev/null
    else
        log_error "xmllint not available for XML parsing"
        return 1
    fi
}

lfa_url_encode() {
    local string="$1"
    local encoded=""
    local i char

    for ((i = 0; i < ${#string}; i++)); do
        char="${string:i:1}"
        case "$char" in
            [a-zA-Z0-9.~_-]) encoded+="$char" ;;
            *)
                printf -v char '%%%02X' "'$char"
                encoded+="$char"
                ;;
        esac
    done
    echo "$encoded"
}

lfa_url_decode() {
    local string="$1"
    local decoded=""
    local i char hex

    for ((i = 0; i < ${#string}; i++)); do
        char="${string:i:1}"
        if [[ "$char" == "%" ]]; then
            hex="${string:i+1:2}"
            printf -v char "\\x$hex"
            decoded+="$char"
            ((i += 2))
        else
            decoded+="$char"
        fi
    done
    echo "$decoded"
}

lfa_base64_encode() {
    local string="$1"
    if lfa_check_command base64; then
        echo -n "$string" | base64 -w 0
    else
        log_error "base64 not available"
        return 1
    fi
}

lfa_base64_decode() {
    local string="$1"
    if lfa_check_command base64; then
        echo -n "$string" | base64 -d
    else
        log_error "base64 not available"
        return 1
    fi
}

lfa_generate_password() {
    local length="${1:-16}"
    local chars='A-Za-z0-9!@#$%^&*()_+-=[]{}|;:,.<>?'
    local password=""

    if lfa_check_command openssl; then
        openssl rand -base64 $((length * 3 / 2)) | tr -d '=+/' | cut -c1-"$length"
    elif lfa_check_command tr; then
        tr -dc "$chars" </dev/urandom | head -c "$length"
    else
        log_error "No random generator available"
        return 1
    fi
}

lfa_is_valid_ip() {
    local ip="$1"
    local regex='^([0-9]{1,3}\.){3}[0-9]{1,3}$'

    if [[ "$ip" =~ $regex ]]; then
        IFS='.' read -ra octets <<<"$ip"
        for octet in "${octets[@]}"; do
            if ((octet > 255)); then
                return 1
            fi
        done
        return 0
    fi
    return 1
}

lfa_is_valid_cidr() {
    local cidr="$1"
    local regex='^([0-9]{1,3}\.){3}[0-9]{1,3}/([0-9]|[12][0-9]|3[012])$'

    if [[ "$cidr" =~ $regex ]]; then
        IFS='.' read -ra octets <<<"${BASH_REMATCH[1]}"
        for octet in "${octets[@]}"; do
            if ((octet > 255)); then
                return 1
            fi
        done
        return 0
    fi
    return 1
}

lfa_is_valid_hostname() {
    local hostname="$1"
    local regex='^([a-zA-Z0-9]([a-zA-Z0-9-]{0,61}[a-zA-Z0-9])?\.)+[a-zA-Z]{2,}$'

    [[ "$hostname" =~ $regex ]]
}

lfa_is_valid_port() {
    local port="$1"
    [[ "$port" =~ ^[0-9]+$ ]] && ((port >= 1 && port <= 65535))
}

lfa_get_random_port() {
    local min="${1:-1024}"
    local max="${2:-65535}"
    echo $((RANDOM % (max - min + 1) + min))
}

lfa_wait_for_port() {
    local host="$1"
    local port="$2"
    local timeout="${3:-30}"
    local interval="${4:-1}"
    local start_time
    start_time=$(date +%s)

    while ! lfa_check_port "$host" "$port"; do
        if (($(date +%s) - start_time > timeout)); then
            return 1
        fi
        sleep "$interval"
    done
    return 0
}

lfa_check_port() {
    local host="$1"
    local port="$2"

    if lfa_check_command nc; then
        nc -z -w 1 "$host" "$port" &>/dev/null
    elif lfa_check_command timeout; then
        timeout 1 bash -c "cat < /dev/null > /dev/tcp/$host/$port" &>/dev/null
    else
        return 1
    fi
}

lfa_get_public_ip() {
    local services=(
        "https://api.ipify.org"
        "https://ifconfig.me/ip"
        "https://icanhazip.com"
        "https://ipecho.net/plain"
    )

    for service in "${services[@]}"; do
        if lfa_check_command curl; then
            local ip
            ip=$(timeout 5 curl -s "$service" 2>/dev/null || true)
            if lfa_is_valid_ip "$ip"; then
                echo "$ip"
                return 0
            fi
        elif lfa_check_command wget; then
            local ip
            ip=$(timeout 5 wget -qO- "$service" 2>/dev/null || true)
            if lfa_is_valid_ip "$ip"; then
                echo "$ip"
                return 0
            fi
        fi
    done
    return 1
}

lfa_ping_host() {
    local host="$1"
    local count="${2:-3}"
    local timeout="${3:-5}"

    if lfa_check_command ping; then
        ping -c "$count" -W "$timeout" "$host" &>/dev/null
    else
        return 1
    fi
}

lfa_traceroute() {
    local host="$1"
    local max_hops="${2:-30}"

    if lfa_check_command traceroute; then
        traceroute -m "$max_hops" "$host"
    elif lfa_check_command tracepath; then
        tracepath -m "$max_hops" "$host"
    else
        log_error "No traceroute utility available"
        return 1
    fi
}

lfa_dns_lookup() {
    local host="$1"
    local type="${2:-A}"
    local server="${3:-}"

    local cmd=(dig +short "$type" "$host")
    if [[ -n "$server" ]]; then
        cmd+=("@$server")
    fi
    "${cmd[@]}" 2>/dev/null
}

lfa_get_certificate_info() {
    local host="$1"
    local port="${2:-443}"

    if lfa_check_command openssl; then
        echo | openssl s_client -connect "$host:$port" -servername "$host" 2>/dev/null |
            openssl x509 -noout -text 2>/dev/null
    else
        log_error "openssl not available"
        return 1
    fi
}

lfa_check_ssl_expiry() {
    local host="$1"
    local port="${2:-443}"
    local warning_days="${3:-30}"

    if lfa_check_command openssl; then
        local expiry_date
        expiry_date=$(echo | openssl s_client -connect "$host:$port" -servername "$host" 2>/dev/null |
            openssl x509 -noout -enddate 2>/dev/null | cut -d= -f2)

        if [[ -n "$expiry_date" ]]; then
            local expiry_epoch
            expiry_epoch=$(date -d "$expiry_date" +%s 2>/dev/null || date -j -f "%b %d %H:%M:%S %Y %Z" "$expiry_date" +%s 2>/dev/null)
            local now_epoch
            now_epoch=$(date +%s)
            local days_left=$(((expiry_epoch - now_epoch) / 86400))

            if ((days_left < 0)); then
                echo "expired"
                return 2
            elif ((days_left <= warning_days)); then
                echo "warning:$days_left"
                return 1
            else
                echo "ok:$days_left"
                return 0
            fi
        fi
    fi
    return 1
}

lfa_get_process_info() {
    local pid="$1"
    if [[ -f "/proc/$pid/status" ]]; then
        cat "/proc/$pid/status"
    else
        return 1
    fi
}

lfa_get_process_cmdline() {
    local pid="$1"
    if [[ -f "/proc/$pid/cmdline" ]]; then
        tr '\0' ' ' <"/proc/$pid/cmdline"
        echo
    else
        return 1
    fi
}

lfa_get_process_env() {
    local pid="$1"
    if [[ -f "/proc/$pid/environ" ]]; then
        tr '\0' '\n' <"/proc/$pid/environ"
    else
        return 1
    fi
}

lfa_get_process_fds() {
    local pid="$1"
    if [[ -d "/proc/$pid/fd" ]]; then
        ls -l "/proc/$pid/fd" 2>/dev/null
    else
        return 1
    fi
}

lfa_kill_process_tree() {
    local pid="$1"
    local signal="${2:-TERM}"

    local children
    children=$(pgrep -P "$pid" 2>/dev/null || true)
    for child in $children; do
        lfa_kill_process_tree "$child" "$signal"
    done
    kill -"$signal" "$pid" 2>/dev/null || true
}

lfa_get_systemd_unit_file() {
    local unit="$1"
    systemctl cat "$unit" 2>/dev/null || true
}

lfa_get_systemd_dropins() {
    local unit="$1"
    systemctl cat "$unit" 2>/dev/null | grep -A 1000 "^# /etc/systemd/" || true
}

lfa_reload_systemd() {
    systemctl daemon-reload 2>/dev/null
}

lfa_enable_service() {
    local service="$1"
    systemctl enable "$service" 2>/dev/null
}

lfa_disable_service() {
    local service="$1"
    systemctl disable "$service" 2>/dev/null
}

lfa_start_service() {
    local service="$1"
    systemctl start "$service" 2>/dev/null
}

lfa_stop_service() {
    local service="$1"
    systemctl stop "$service" 2>/dev/null
}

lfa_restart_service() {
    local service="$1"
    systemctl restart "$service" 2>/dev/null
}

lfa_mask_service() {
    local service="$1"
    systemctl mask "$service" 2>/dev/null
}

lfa_unmask_service() {
    local service="$1"
    systemctl unmask "$service" 2>/dev/null
}

lfa_get_service_logs() {
    local service="$1"
    local lines="${2:-100}"
    local since="${3:-}"

    local cmd=(journalctl -u "$service" -n "$lines" --no-pager)
    if [[ -n "$since" ]]; then
        cmd+=("--since" "$since")
    fi
    "${cmd[@]}" 2>/dev/null
}

lfa_follow_service_logs() {
    local service="$1"
    journalctl -u "$service" -f 2>/dev/null
}

lfa_get_failed_units() {
    systemctl list-units --state=failed --no-legend 2>/dev/null | awk '{print $1}'
}

lfa_get_unit_dependencies() {
    local unit="$1"
    systemctl list-dependencies "$unit" --no-pager 2>/dev/null
}

lfa_get_unit_reverse_dependencies() {
    local unit="$1"
    systemctl list-dependencies --reverse "$unit" --no-pager 2>/dev/null
}
