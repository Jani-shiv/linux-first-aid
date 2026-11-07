#!/usr/bin/env bash
#
# monitor.sh - Continuous monitoring module
# Part of linux-first-aid toolkit
#
# Copyright (c) 2024 linux-first-aid contributors
# Licensed under the MIT License

set -euo pipefail

source "${LFA_LIB_DIR}/core/common.sh"
source "${LFA_LIB_DIR}/core/logger.sh"
source "${LFA_LIB_DIR}/core/config.sh"

lfa_monitor_usage() {
    cat <<'EOF'
Usage: first-aid monitor [OPTIONS]

Start continuous system monitoring.

OPTIONS:
    --interval SECONDS      Check interval in seconds (default: 60)
    --alert-threshold LEVEL Alert threshold: info, warn, critical (default: warn)
    --daemon                Run as daemon
    --pid-file FILE         PID file for daemon mode
    --log-file FILE         Log file for daemon mode
    --once                  Run checks once and exit
    --categories LIST       Comma-separated categories to monitor
    -h, --help              Show this help

EXAMPLES:
    first-aid monitor --interval 30 --alert-threshold warn
    first-aid monitor --daemon --pid-file /var/run/first-aid.pid
    first-aid monitor --once --categories disk,memory,cpu
EOF
}

lfa_monitor() {
    local interval=60
    local alert_threshold="warn"
    local daemon=false
    local pid_file="/var/run/first-aid-monitor.pid"
    local log_file="/var/log/first-aid-monitor.log"
    local once=false
    local categories=()

    while [[ $# -gt 0 ]]; do
        case $1 in
            --interval)
                interval="$2"
                shift 2
                ;;
            --alert-threshold)
                alert_threshold="$2"
                shift 2
                ;;
            --daemon)
                daemon=true
                shift
                ;;
            --pid-file)
                pid_file="$2"
                shift 2
                ;;
            --log-file)
                log_file="$2"
                shift 2
                ;;
            --once)
                once=true
                shift
                ;;
            --categories)
                IFS=',' read -ra categories <<<"$2"
                shift 2
                ;;
            -h | --help)
                lfa_monitor_usage
                return 0
                ;;
            *)
                log_error "Unknown option: $1"
                lfa_monitor_usage
                return 2
                ;;
        esac
    done

    if [[ ${#categories[@]} -eq 0 ]]; then
        local config_categories
        config_categories=$(lfa_get_config "diagnose.categories")
        IFS=',' read -ra categories <<<"$config_categories"
    fi

    if [[ "$daemon" == "true" ]]; then
        lfa_monitor_daemon "$interval" "$alert_threshold" "$pid_file" "$log_file" "${categories[@]}"
    else
        lfa_monitor_foreground "$interval" "$alert_threshold" "$once" "${categories[@]}"
    fi
}

lfa_monitor_daemon() {
    local interval="$1"
    local alert_threshold="$2"
    local pid_file="$3"
    local log_file="$4"
    shift 4
    local categories=("$@")

    if [[ -f "$pid_file" ]] && kill -0 "$(cat "$pid_file" 2>/dev/null)" 2>/dev/null; then
        log_error "Monitor already running (PID: $(cat "$pid_file"))"
        return 1
    fi

    log_info "Starting monitor daemon (interval: ${interval}s, threshold: $alert_threshold)"

    (
        exec >>"$log_file" 2>&1
        echo "$$" >"$pid_file"
        trap 'rm -f "$pid_file"; exit 0' EXIT INT TERM

        while true; do
            lfa_monitor_run_checks "$alert_threshold" "${categories[@]}"
            sleep "$interval"
        done
    ) &

    disown
    log_success "Monitor daemon started (PID: $!)"
}

lfa_monitor_foreground() {
    local interval="$1"
    local alert_threshold="$2"
    local once="$3"
    shift 3
    local categories=("$@")

    log_info "Starting monitor (interval: ${interval}s, threshold: $alert_threshold)"
    log_info "Press Ctrl+C to stop"

    trap 'log_info "Monitor stopped"; exit 0' INT TERM

    while true; do
        lfa_monitor_run_checks "$alert_threshold" "${categories[@]}"

        if [[ "$once" == "true" ]]; then
            break
        fi

        sleep "$interval"
    done
}

lfa_monitor_run_checks() {
    local alert_threshold="$1"
    shift
    local categories=("$@")

    local timestamp
    timestamp=$(lfa_timestamp)
    log_info "=== Monitor Check: $timestamp ==="

    for category in "${categories[@]}"; do
        local result
        if lfa_monitor_check_category "$category" "$alert_threshold"; then
            log_debug "$category: OK"
        else
            local level="$?"
            case $level in
                1) log_warn "$category: WARNING" ;;
                2) log_error "$category: CRITICAL" ;;
                *) log_error "$category: UNKNOWN ERROR" ;;
            esac
        fi
    done
}

lfa_monitor_check_category() {
    local category="$1"
    local alert_threshold="$2"

    case "$category" in
        disk)
            lfa_monitor_check_disk "$alert_threshold"
            ;;
        memory)
            lfa_monitor_check_memory "$alert_threshold"
            ;;
        cpu)
            lfa_monitor_check_cpu "$alert_threshold"
            ;;
        network)
            lfa_monitor_check_network "$alert_threshold"
            ;;
        services)
            lfa_monitor_check_services "$alert_threshold"
            ;;
        *)
            log_debug "Monitoring not implemented for: $category"
            return 0
            ;;
    esac
}

lfa_monitor_check_disk() {
    local alert_threshold="$1"
    local warn_threshold
    warn_threshold=$(lfa_get_config "check.disk.threshold_warn" 80)
    local crit_threshold
    crit_threshold=$(lfa_get_config "check.disk.threshold_crit" 90)

    local max_usage=0
    local max_mount=""

    while read -r line; do
        if [[ "$line" =~ ^/dev/ ]]; then
            local usage mount
            usage=$(echo "$line" | awk '{print $5}' | sed 's/%//')
            mount=$(echo "$line" | awk '{print $6}')
            if [[ "$usage" =~ ^[0-9]+$ ]] && ((usage > max_usage)); then
                max_usage=$usage
                max_mount=$mount
            fi
        fi
    done < <(df -h -x tmpfs -x devtmpfs -x squashfs)

    if ((max_usage >= crit_threshold)); then
        log_error "Disk critical: $max_mount at ${max_usage}%"
        return 2
    elif ((max_usage >= warn_threshold)); then
        log_warn "Disk warning: $max_mount at ${max_usage}%"
        return 1
    fi
    return 0
}

lfa_monitor_check_memory() {
    local alert_threshold="$1"
    local warn_threshold
    warn_threshold=$(lfa_get_config "check.memory.threshold_warn" 80)
    local crit_threshold
    crit_threshold=$(lfa_get_config "check.memory.threshold_crit" 90)

    local mem_info
    mem_info=$(free | grep "^Mem:")
    local total used
    total=$(echo "$mem_info" | awk '{print $2}')
    used=$(echo "$mem_info" | awk '{print $3}')

    local pct=$((used * 100 / total))

    if ((pct >= crit_threshold)); then
        log_error "Memory critical: ${pct}% used"
        return 2
    elif ((pct >= warn_threshold)); then
        log_warn "Memory warning: ${pct}% used"
        return 1
    fi
    return 0
}

lfa_monitor_check_cpu() {
    local alert_threshold="$1"
    local load_warn
    load_warn=$(lfa_get_config "check.cpu.load_warn" 2.0)
    local load_crit
    load_crit=$(lfa_get_config "check.cpu.load_crit" 4.0)

    local load_avg
    load_avg=$(lfa_get_load_average)
    local load_1min
    load_1min=$(echo "$load_avg" | awk '{print $1}')
    local cpu_count
    cpu_count=$(nproc)
    local load_per_cpu
    load_per_cpu=$(echo "scale=2; $load_1min / $cpu_count" | bc 2>/dev/null || echo "0")

    if (($(echo "$load_per_cpu > $load_crit" | bc -l 2>/dev/null || echo 0))); then
        log_error "CPU load critical: $load_per_cpu per CPU"
        return 2
    elif (($(echo "$load_per_cpu > $load_warn" | bc -l 2>/dev/null || echo 0))); then
        log_warn "CPU load warning: $load_per_cpu per CPU"
        return 1
    fi
    return 0
}

lfa_monitor_check_network() {
    local alert_threshold="$1"
    local ping_hosts
    ping_hosts=$(lfa_get_config "check.network.ping_hosts" "8.8.8.8,1.1.1.1")
    local ping_timeout
    ping_timeout=$(lfa_get_config "check.network.ping_timeout" 5)

    IFS=',' read -ra hosts <<<"$ping_hosts"
    local failed=0

    for host in "${hosts[@]}"; do
        if ! lfa_ping_host "$host" 2 "$ping_timeout"; then
            ((failed += 1))
        fi
    done

    if ((failed == ${#hosts[@]})); then
        log_error "Network critical: All ping targets unreachable"
        return 2
    elif ((failed > 0)); then
        log_warn "Network warning: $failed/${#hosts[@]} ping targets unreachable"
        return 1
    fi
    return 0
}

lfa_monitor_check_services() {
    local alert_threshold="$1"
    local critical_services
    critical_services=$(lfa_get_config "check.services.critical_services" "sshd,systemd-resolved,systemd-networkd,cron")

    if ! lfa_is_systemd; then
        return 0
    fi

    local failed=0
    IFS=',' read -ra services <<<"$critical_services"
    for service in "${services[@]}"; do
        local status
        status=$(lfa_service_status "$service" 2>/dev/null || echo "inactive")
        if [[ "$status" != "active" ]]; then
            log_error "Service critical: $service is $status"
            ((failed += 1))
        fi
    done

    if ((failed > 0)); then
        return 2
    fi
    return 0
}

lfa_monitor_stop() {
    local pid_file="${1:-/var/run/first-aid-monitor.pid}"

    if [[ -f "$pid_file" ]]; then
        local pid
        pid=$(cat "$pid_file" 2>/dev/null)
        if [[ -n "$pid" ]] && kill -0 "$pid" 2>/dev/null; then
            kill "$pid"
            log_info "Monitor stopped (PID: $pid)"
            return 0
        fi
    fi
    log_warn "Monitor not running"
    return 1
}

lfa_monitor_status() {
    local pid_file="${1:-/var/run/first-aid-monitor.pid}"

    if [[ -f "$pid_file" ]]; then
        local pid
        pid=$(cat "$pid_file" 2>/dev/null)
        if [[ -n "$pid" ]] && kill -0 "$pid" 2>/dev/null; then
            echo "Monitor running (PID: $pid)"
            return 0
        fi
    fi
    echo "Monitor not running"
    return 1
}
