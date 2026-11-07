#!/usr/bin/env bash
#
# analyze.sh - Log and performance analysis module
# Part of linux-first-aid toolkit
#
# Copyright (c) 2024 linux-first-aid contributors
# Licensed under the MIT License

set -euo pipefail

source "${LFA_LIB_DIR}/core/common.sh"
source "${LFA_LIB_DIR}/core/logger.sh"
source "${LFA_LIB_DIR}/core/config.sh"

lfa_analyze_usage() {
    cat <<'EOF'
Usage: first-aid analyze <type> [OPTIONS]

Analyze logs, performance, or configuration.

TYPES:
    logs            Analyze system logs
    performance     Analyze system performance
    startup         Analyze boot/startup performance
    crashes         Analyze crash dumps and coredumps
    security        Analyze security events

OPTIONS:
    --since TIME        Time range (default: 24h)
    --level LEVEL       Log level (default: error)
    --unit UNIT         Systemd unit for log analysis
    --top N             Show top N entries (default: 50)
    --format FORMAT     Output format: text, json (default: text)
    --output FILE       Write results to file
    -h, --help          Show this help

EXAMPLES:
    first-aid analyze logs --since "1 hour ago" --level error
    first-aid analyze logs --unit nginx --top 100
    first-aid analyze performance --format json
    first-aid analyze startup
    first-aid analyze crashes
    first-aid analyze security --since "7 days ago"
EOF
}

lfa_analyze() {
    local analyze_type="${1:-}"
    shift || true

    if [[ "$analyze_type" == "-h" || "$analyze_type" == "--help" || -z "$analyze_type" ]]; then
        lfa_analyze_usage
        [[ -n "$analyze_type" ]] && return 0
        return 2
    fi

    local since="24h"
    local level="error"
    local unit=""
    local top=50
    local format="text"
    local output=""

    while [[ $# -gt 0 ]]; do
        case $1 in
            --since)
                since="$2"
                shift 2
                ;;
            --level)
                level="$2"
                shift 2
                ;;
            --unit)
                unit="$2"
                shift 2
                ;;
            --top)
                top="$2"
                shift 2
                ;;
            --format)
                format="$2"
                shift 2
                ;;
            --output)
                output="$2"
                shift 2
                ;;
            -h | --help)
                lfa_analyze_usage
                return 0
                ;;
            *)
                log_error "Unknown option: $1"
                lfa_analyze_usage
                return 2
                ;;
        esac
    done

    case "$analyze_type" in
        logs)
            lfa_analyze_logs "$since" "$level" "$unit" "$top" "$format" "$output"
            ;;
        performance)
            lfa_analyze_performance "$format" "$output"
            ;;
        startup)
            lfa_analyze_startup "$format" "$output"
            ;;
        crashes)
            lfa_analyze_crashes "$format" "$output"
            ;;
        security)
            lfa_analyze_security "$since" "$format" "$output"
            ;;
        *)
            log_error "Unknown analysis type: $analyze_type"
            lfa_analyze_usage
            return 2
            ;;
    esac
}

lfa_analyze_logs() {
    local since="$1"
    local level="$2"
    local unit="$3"
    local top="$4"
    local format="$5"
    local output="$6"

    log_section "Log Analysis"
    log_kv "Since" "$since"
    log_kv "Level" "$level"
    log_kv "Unit" "${unit:-all}"
    log_kv "Top" "$top"

    local results=()

    if [[ -n "$unit" ]]; then
        log_subsection "Logs for unit: $unit"
        journalctl -u "$unit" -p "$level" --since "$since" --no-pager -n "$top" 2>/dev/null | while read -r line; do
            results+=("log:$line")
        done
    else
        log_subsection "System logs (level: $level, since: $since)"
        journalctl -p "$level" --since "$since" --no-pager -n "$top" 2>/dev/null | while read -r line; do
            results+=("log:$line")
        done
    fi

    log_subsection "Top error sources"
    journalctl -p "$level" --since "$since" --no-pager 2>/dev/null |
        awk '{for(i=1;i<=NF;i++) if($i ~ /^[-_.a-zA-Z0-9]+@/ || $i ~ /^[a-zA-Z0-9_-]+\.[a-zA-Z0-9_-]+/) print $i}' |
        sort | uniq -c | sort -rn | head -10 | while read -r line; do
        results+=("source:$line")
    done

    log_subsection "Kernel errors"
    dmesg -T --level=err,crit,alert,emerg 2>/dev/null | tail -20 | while read -r line; do
        results+=("kernel:$line")
    done

    lfa_output_analysis "logs" "$format" "$output" "${results[@]}"
}

lfa_analyze_performance() {
    local format="$1"
    local output="$2"

    log_section "Performance Analysis"

    local results=()

    log_subsection "CPU"
    local cpu_info
    cpu_info=$(mpstat 1 1 2>/dev/null | tail -1 || echo "mpstat not available")
    results+=("cpu:$cpu_info")

    log_subsection "Memory"
    local mem_info
    mem_info=$(free -h)
    results+=("memory:$mem_info")

    log_subsection "Disk I/O"
    local io_info
    io_info=$(iostat -x 1 1 2>/dev/null | tail -n +4 || echo "iostat not available")
    results+=("disk_io:$io_info")

    log_subsection "Network I/O"
    local net_info
    net_info=$(sar -n DEV 1 1 2>/dev/null | tail -n +4 || echo "sar not available")
    results+=("network_io:$net_info")

    log_subsection "Load Average"
    results+=("load:$(lfa_get_load_average)")

    log_subsection "Top CPU Processes"
    ps aux --sort=-%cpu | head -11 | while read -r line; do
        results+=("top_cpu:$line")
    done

    log_subsection "Top Memory Processes"
    ps aux --sort=-%mem | head -11 | while read -r line; do
        results+=("top_mem:$line")
    done

    lfa_output_analysis "performance" "$format" "$output" "${results[@]}"
}

lfa_analyze_startup() {
    local format="$1"
    local output="$2"

    log_section "Startup Analysis"

    local results=()

    if lfa_is_systemd; then
        log_subsection "Boot Time"
        systemd-analyze 2>/dev/null | while read -r line; do
            results+=("boot_time:$line")
        done

        log_subsection "Service Startup Times"
        systemd-analyze blame 2>/dev/null | head -20 | while read -r line; do
            results+=("service_time:$line")
        done

        log_subsection "Critical Chain"
        systemd-analyze critical-chain 2>/dev/null | while read -r line; do
            results+=("critical_chain:$line")
        done

        log_subsection "Unit Files State"
        systemctl list-unit-files --state=enabled --no-legend 2>/dev/null | head -20 | while read -r line; do
            results+=("enabled_unit:$line")
        done
    else
        log_warn "Startup analysis requires systemd"
        results+=("error:startup analysis requires systemd")
    fi

    lfa_output_analysis "startup" "$format" "$output" "${results[@]}"
}

lfa_analyze_crashes() {
    local format="$1"
    local output="$2"

    log_section "Crash Analysis"

    local results=()

    log_subsection "Coredumps"
    if lfa_check_command coredumpctl; then
        coredumpctl list 2>/dev/null | tail -20 | while read -r line; do
            results+=("coredump:$line")
        done

        log_subsection "Recent Coredump Details"
        coredumpctl list --no-pager 2>/dev/null | head -5 | awk '{print $1}' | while read -r pid; do
            if [[ -n "$pid" && "$pid" =~ ^[0-9]+$ ]]; then
                coredumpctl info "$pid" 2>/dev/null | while read -r line; do
                    results+=("coredump_info:$line")
                done
            fi
        done
    else
        results+=("coredump:coredumpctl not available")
    fi

    log_subsection "Kernel Panics (dmesg)"
    dmesg -T --level=crit,alert,emerg 2>/dev/null | tail -20 | while read -r line; do
        results+=("kernel_panic:$line")
    done

    log_subsection "Application Crashes (journal)"
    journalctl -p crit,alert,emerg --since "7 days ago" --no-pager 2>/dev/null |
        grep -i "crash\|segfault\|abort\|core dumped" | head -20 | while read -r line; do
        results+=("app_crash:$line")
    done

    lfa_output_analysis "crashes" "$format" "$output" "${results[@]}"
}

lfa_analyze_security() {
    local since="$1"
    local format="$2"
    local output="$3"

    log_section "Security Analysis"
    log_kv "Since" "$since"

    local results=()

    log_subsection "Failed Logins"
    lastb -s "$since" 2>/dev/null | head -20 | while read -r line; do
        results+=("failed_login:$line")
    done

    log_subsection "Successful Logins"
    last -s "$since" 2>/dev/null | head -20 | while read -r line; do
        results+=("success_login:$line")
    done

    log_subsection "Sudo Usage"
    journalctl -u sudo --since "$since" --no-pager 2>/dev/null | head -20 | while read -r line; do
        results+=("sudo:$line")
    done

    log_subsection "SSH Authentication Failures"
    journalctl -u sshd --since "$since" --no-pager 2>/dev/null |
        grep -i "failed\|invalid\|error" | head -20 | while read -r line; do
        results+=("ssh_fail:$line")
    done

    log_subsection "Firewall Blocks"
    if lfa_check_command ufw; then
        ufw status verbose 2>/dev/null | grep -i "block\|deny" | head -20 | while read -r line; do
            results+=("fw_block:$line")
        done
    fi

    log_subsection "Setuid/Setgid Files"
    find / -xdev -type f \( -perm -4000 -o -perm -2000 \) 2>/dev/null | head -30 | while read -r line; do
        results+=("suid:$line")
    done

    log_subsection "World-Writable Directories"
    find / -xdev -type d -perm -0002 ! -perm -1000 2>/dev/null | head -30 | while read -r line; do
        results+=("world_writable:$line")
    done

    lfa_output_analysis "security" "$format" "$output" "${results[@]}"
}

lfa_output_analysis() {
    local type="$1"
    local format="$2"
    local output="$3"
    shift 3
    local results=("$@")

    case "$format" in
        json)
            local json="{"
            json+='"type":"'$type'",'
            json+='"timestamp":"'$(lfa_timestamp_iso)'",'
            json+='"hostname":"'$(hostname)'",'
            json+='"results":['
            local first=true
            for result in "${results[@]}"; do
                IFS=':' read -r category content <<<"$result"
                if [[ "$first" == "true" ]]; then
                    first=false
                else
                    json+=","
                fi
                json+='{"category":"'$category'","content":"'$(lfa_json_escape "$content")'"}'
            done
            json+="]}"
            echo "$json"
            ;;
        text | *)
            echo "=== $type analysis ==="
            echo "Timestamp: $(lfa_timestamp)"
            echo "Hostname: $(hostname)"
            echo ""
            for result in "${results[@]}"; do
                IFS=':' read -r category content <<<"$result"
                echo "[$category] $content"
            done
            ;;
    esac

    if [[ -n "$output" ]]; then
        lfa_output_analysis "$type" "$format" "" "${results[@]}" >"$output"
    fi
}
