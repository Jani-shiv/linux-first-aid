#!/usr/bin/env bash
#
# check.sh - Individual health checks module
# Part of linux-first-aid toolkit
#
# Copyright (c) 2024 linux-first-aid contributors
# Licensed under the MIT License

set -euo pipefail

source "${LFA_LIB_DIR}/core/common.sh"
source "${LFA_LIB_DIR}/core/logger.sh"
source "${LFA_LIB_DIR}/core/config.sh"

lfa_check_usage() {
    cat <<'EOF'
Usage: first-aid check <check-name> [OPTIONS]

Run specific health checks.

CHECKS:
    disk        Check disk usage and health
    memory      Check memory and swap usage
    cpu         Check CPU usage and load
    network     Check network connectivity
    services    Check system services status
    packages    Check package manager status
    logs        Check system logs for errors
    security    Check security configuration
    kernel      Check kernel parameters and modules
    boot        Check boot configuration

OPTIONS:
    --threshold WARN,CRIT   Set warning and critical thresholds
    --since TIME           Time range for log checks (default: 24h)
    --level LEVEL          Log level for log checks (default: error)
    --format FORMAT        Output format: text, json (default: text)
    --output FILE          Write results to file
    -h, --help             Show this help

EXAMPLES:
    first-aid check disk --threshold 80,90
    first-aid check memory --threshold 80,90
    first-aid check cpu --threshold 2.0,4.0
    first-aid check network
    first-aid check logs --since "1 hour ago" --level error
    first-aid check security --format json
EOF
}

lfa_check() {
    local check_name="${1:-}"
    shift || true

    if [[ -z "$check_name" ]]; then
        lfa_check_usage
        return 2
    fi

    local threshold=""
    local since="24h"
    local level="error"
    local format="text"
    local output=""

    while [[ $# -gt 0 ]]; do
        case $1 in
            --threshold)
                threshold="$2"
                shift 2
                ;;
            --since)
                since="$2"
                shift 2
                ;;
            --level)
                level="$2"
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
            -h|--help)
                lfa_check_usage
                return 0
                ;;
            *)
                log_error "Unknown option: $1"
                lfa_check_usage
                return 2
                ;;
        esac
    done

    case "$check_name" in
        disk)
            lfa_check_disk "$threshold" "$format" "$output"
            ;;
        memory)
            lfa_check_memory "$threshold" "$format" "$output"
            ;;
        cpu)
            lfa_check_cpu "$threshold" "$format" "$output"
            ;;
        network)
            lfa_check_network "$format" "$output"
            ;;
        services)
            lfa_check_services "$format" "$output"
            ;;
        packages)
            lfa_check_packages "$format" "$output"
            ;;
        logs)
            lfa_check_logs "$since" "$level" "$format" "$output"
            ;;
        security)
            lfa_check_security "$format" "$output"
            ;;
        kernel)
            lfa_check_kernel "$format" "$output"
            ;;
        boot)
            lfa_check_boot "$format" "$output"
            ;;
        *)
            log_error "Unknown check: $check_name"
            lfa_check_usage
            return 2
            ;;
    esac
}

lfa_check_disk() {
    local threshold="$1"
    local format="$2"
    local output="$3"
    local warn_threshold=80
    local crit_threshold=90

    if [[ -n "$threshold" ]]; then
        IFS=',' read -r warn_threshold crit_threshold <<< "$threshold"
    fi

    local results=()
    local max_usage=0
    local max_mount=""

    while read -r line; do
        if [[ "$line" =~ ^/dev/ ]]; then
            local usage mount fs avail
            usage=$(echo "$line" | awk '{print $5}' | sed 's/%//')
            mount=$(echo "$line" | awk '{print $6}')
            fs=$(echo "$line" | awk '{print $1}')
            avail=$(echo "$line" | awk '{print $4}')

            if [[ "$usage" =~ ^[0-9]+$ ]]; then
                local status="ok"
                if (( usage >= crit_threshold )); then
                    status="critical"
                elif (( usage >= warn_threshold ]]; then
                    status="warning"
                fi

                results+=("$mount:$usage:$status:$fs:$avail")
                if (( usage > max_usage )); then
                    max_usage=$usage
                    max_mount=$mount
                fi
            fi
        fi
    done < <(df -h -x tmpfs -x devtmpfs -x squashfs)

    lfa_output_check_results "disk" "$format" "$output" "${results[@]}"

    if (( max_usage >= crit_threshold )); then
        return 2
    elif (( max_usage >= warn_threshold )); then
        return 1
    fi
    return 0
}

lfa_check_memory() {
    local threshold="$1"
    local format="$2"
    local output="$3"
    local warn_threshold=80
    local crit_threshold=90

    if [[ -n "$threshold" ]]; then
        IFS=',' read -r warn_threshold crit_threshold <<< "$threshold"
    fi

    local mem_info
    mem_info=$(free -b | grep "^Mem:")
    local total used free available
    total=$(echo "$mem_info" | awk '{print $2}')
    used=$(echo "$mem_info" | awk '{print $3}')
    free=$(echo "$mem_info" | awk '{print $4}')
    available=$(echo "$mem_info" | awk '{print $7}')

    local pct=$(( used * 100 / total ))
    local avail_pct=$(( available * 100 / total ))

    local swap_info
    swap_info=$(free -b | grep "^Swap:")
    local swap_total swap_used swap_free
    swap_total=$(echo "$swap_info" | awk '{print $2}')
    swap_used=$(echo "$swap_info" | awk '{print $3}')
    swap_free=$(echo "$swap_info" | awk '{print $4}')

    local swap_pct=0
    if (( swap_total > 0 )); then
        swap_pct=$(( swap_used * 100 / swap_total ))
    fi

    local status="ok"
    if (( pct >= crit_threshold )); then
        status="critical"
    elif (( pct >= warn_threshold )); then
        status="warning"
    fi

    local results=("memory:$pct:$status:$used:$total:$available")
    if (( swap_total > 0 )); then
        results+=("swap:$swap_pct:$status:$swap_used:$swap_total:$swap_free")
    fi

    lfa_output_check_results "memory" "$format" "$output" "${results[@]}"

    if (( pct >= crit_threshold )); then
        return 2
    elif (( pct >= warn_threshold )); then
        return 1
    fi
    return 0
}

lfa_check_cpu() {
    local threshold="$1"
    local format="$2"
    local output="$3"
    local load_warn=2.0
    local load_crit=4.0

    if [[ -n "$threshold" ]]; then
        IFS=',' read -r load_warn load_crit <<< "$threshold"
    fi

    local load_avg
    load_avg=$(lfa_get_load_average)
    local load_1min load_5min load_15min
    load_1min=$(echo "$load_avg" | awk '{print $1}')
    load_5min=$(echo "$load_avg" | awk '{print $2}')
    load_15min=$(echo "$load_avg" | awk '{print $3}')

    local cpu_count
    cpu_count=$(nproc)
    local load_per_cpu
    load_per_cpu=$(echo "scale=2; $load_1min / $cpu_count" | bc 2>/dev/null || echo "0")

    local status="ok"
    if (( $(echo "$load_per_cpu > $load_crit" | bc -l 2>/dev/null || echo 0) )); then
        status="critical"
    elif (( $(echo "$load_per_cpu > $load_warn" | bc -l 2>/dev/null || echo 0) )); then
        status="warning"
    fi

    local results=("cpu:$load_per_cpu:$status:$load_1min:$load_5min:$load_15min:$cpu_count")

    lfa_output_check_results "cpu" "$format" "$output" "${results[@]}"

    if (( $(echo "$load_per_cpu > $load_crit" | bc -l 2>/dev/null || echo 0) )); then
        return 2
    elif (( $(echo "$load_per_cpu > $load_warn" | bc -l 2>/dev/null || echo 0) )); then
        return 1
    fi
    return 0
}

lfa_check_network() {
    local format="$1"
    local output="$2"

    local results=()
    local ping_hosts
    ping_hosts=$(lfa_get_config "check.network.ping_hosts" "8.8.8.8,1.1.1.1")
    local ping_timeout
    ping_timeout=$(lfa_get_config "check.network.ping_timeout" 5)

    IFS=',' read -ra hosts <<< "$ping_hosts"
    for host in "${hosts[@]}"; do
        if lfa_ping_host "$host" 3 "$ping_timeout"; then
            results+=("ping:$host:ok")
        else
            results+=("ping:$host:failed")
        fi
    done

    if lfa_check_command dig; then
        local dns_servers
        dns_servers=$(lfa_get_config "check.network.dns_servers" "8.8.8.8,1.1.1.1")
        IFS=',' read -ra dns <<< "$dns_servers"
        for server in "${dns[@]}"; do
            if lfa_dns_lookup "google.com" A "$server" &>/dev/null; then
                results+=("dns:$server:ok")
            else
                results+=("dns:$server:failed")
            fi
        done
    fi

    lfa_output_check_results "network" "$format" "$output" "${results[@]}"

    local failed=0
    for r in "${results[@]}"; do
        if [[ "$r" == *:failed ]]; then
            ((failed++))
        fi
    done

    if (( failed == ${#results[@]} )); then
        return 2
    elif (( failed > 0 )); then
        return 1
    fi
    return 0
}

lfa_check_services() {
    local format="$1"
    local output="$2"

    if ! lfa_is_systemd; then
        log_warn "Not using systemd, limited service checks"
        return 0
    fi

    local results=()
    local critical_services
    critical_services=$(lfa_get_config "check.services.critical_services" "sshd,systemd-resolved,systemd-networkd,cron")

    IFS=',' read -ra services <<< "$critical_services"
    for service in "${services[@]}"; do
        local status
        status=$(lfa_service_status "$service" 2>/dev/null || echo "inactive")
        local enabled
        enabled=$(lfa_service_enabled "$service" 2>/dev/null || echo "disabled")
        results+=("service:$service:$status:$enabled")
    done

    local failed_services
    failed_services=$(lfa_get_failed_services)
    if [[ -n "$failed_services" ]]; then
        echo "$failed_services" | while read -r svc; do
            results+=("service:$svc:failed:enabled")
        done
    fi

    lfa_output_check_results "services" "$format" "$output" "${results[@]}"

    local failed=0
    for r in "${results[@]}"; do
        if [[ "$r" == *:failed:* ]] || [[ "$r" == *:inactive:* ]]; then
            ((failed++))
        fi
    done

    if (( failed > 0 )); then
        return 2
    fi
    return 0
}

lfa_check_packages() {
    local format="$1"
    local output="$2"

    local results=()
    local pm
    pm=$(lfa_get_package_manager)

    case "$pm" in
        apt)
            local upgradable
            upgradable=$(apt list --upgradable 2>/dev/null | tail -n +2 | wc -l)
            results+=("packages:upgradable:$upgradable")
            local broken
            broken=$(dpkg -l | grep -c '^rc' || true)
            results+=("packages:config_remaining:$broken")
            ;;
        dnf|yum)
            local updates
            updates=$($pm check-update 2>/dev/null | grep -c "^[^.]" || true)
            results+=("packages:updates:$updates")
            ;;
        pacman)
            local updates
            updates=$(pacman -Qu 2>/dev/null | wc -l)
            results+=("packages:updates:$updates")
            local orphans
            orphans=$(pacman -Qdtq 2>/dev/null | wc -l)
            results+=("packages:orphans:$orphans")
            ;;
        zypper)
            local updates
            updates=$(zypper list-updates 2>/dev/null | grep -c "^v" || true)
            results+=("packages:updates:$updates")
            ;;
    esac

    lfa_output_check_results "packages" "$format" "$output" "${results[@]}"
    return 0
}

lfa_check_logs() {
    local since="$1"
    local level="$2"
    local format="$3"
    local output="$4"

    local results=()
    local error_count
    error_count=$(journalctl -p "$level" --since "$since" --no-pager 2>/dev/null | wc -l)
    results+=("logs:errors:$error_count:$since:$level")

    local failed_units
    failed_units=$(journalctl -p err -b --no-pager 2>/dev/null | grep -c "Failed" || true)
    results+=("logs:failed_units:$failed_units")

    lfa_output_check_results "logs" "$format" "$output" "${results[@]}"

    if (( error_count > 100 )); then
        return 2
    elif (( error_count > 10 )); then
        return 1
    fi
    return 0
}

lfa_check_security() {
    local format="$1"
    local output="$2"

    local results=()

    if lfa_check_command ufw; then
        local ufw_status
        ufw_status=$(ufw status | head -1 | awk '{print $2}')
        results+=("security:ufw:$ufw_status")
    elif lfa_check_command firewall-cmd; then
        local fw_status
        fw_status=$(firewall-cmd --state 2>/dev/null || echo "unknown")
        results+=("security:firewalld:$fw_status")
    fi

    if [[ -f /etc/ssh/sshd_config ]]; then
        local root_login
        root_login=$(grep -i "^PermitRootLogin" /etc/ssh/sshd_config | awk '{print $2}' || echo "yes")
        results+=("security:ssh_root_login:$root_login")

        local password_auth
        password_auth=$(grep -i "^PasswordAuthentication" /etc/ssh/sshd_config | awk '{print $2}' || echo "yes")
        results+=("security:ssh_password_auth:$password_auth")
    fi

    local world_writable
    world_writable=$(find / -xdev -type f -perm -0002 ! -perm -1000 2>/dev/null | wc -l)
    results+=("security:world_writable:$world_writable")

    lfa_output_check_results "security" "$format" "$output" "${results[@]}"
    return 0
}

lfa_check_kernel() {
    local format="$1"
    local output="$2"

    local results=()

    local kernel_version
    kernel_version=$(lfa_get_kernel_version)
    results+=("kernel:version:$kernel_version")

    local modules_count
    modules_count=$(lsmod | wc -l)
    results+=("kernel:modules:$((modules_count - 1))")

    local dmesg_errors
    dmesg_errors=$(dmesg --level=err 2>/dev/null | wc -l)
    results+=("kernel:dmesg_errors:$dmesg_errors")

    lfa_output_check_results "kernel" "$format" "$output" "${results[@]}"
    return 0
}

lfa_check_boot() {
    local format="$1"
    local output="$2"

    local results=()

    if lfa_is_systemd; then
        local boot_time
        boot_time=$(systemd-analyze 2>/dev/null | grep "Startup finished" | sed 's/.*in //' || echo "unknown")
        results+=("boot:time:$boot_time")
    fi

    if [[ -f /etc/fstab ]]; then
        local fstab_entries
        fstab_entries=$(grep -v '^#' /etc/fstab | grep -c -v '^$' || echo 0)
        results+=("boot:fstab_entries:$fstab_entries")
    fi

    lfa_output_check_results "boot" "$format" "$output" "${results[@]}"
    return 0
}

lfa_output_check_results() {
    local check_name="$1"
    local format="$2"
    local output="$3"
    shift 3
    local results=("$@")

    case "$format" in
        json)
            local json="{"
            json+='"check":"'$check_name'",'
            json+='"timestamp":"'$(lfa_timestamp_iso)'",'
            json+='"results":['
            local first=true
            for result in "${results[@]}"; do
                IFS=':' read -ra parts <<< "$result"
                local name="${parts[0]}"
                local value="${parts[1]}"
                local status="${parts[2]}"
                local extra="${parts[*]:3}"

                if [[ "$first" == "true" ]]; then
                    first=false
                else
                    json+=","
                fi
                json+='{"name":"'$name'","value":"'$value'","status":"'$status'","extra":"'$extra'"}'
            done
            json+="]}"
            echo "$json"
            ;;
        text|*)
            echo "=== $check_name check ==="
            for result in "${results[@]}"; do
                IFS=':' read -ra parts <<< "$result"
                local name="${parts[0]}"
                local value="${parts[1]}"
                local status="${parts[2]}"
                local extra="${parts[*]:3}"

                printf "  %-20s %-10s %s\n" "$name:" "[$status]" "$value"
                if [[ -n "$extra" ]]; then
                    echo "    $extra"
                fi
            done
            ;;
    esac

    if [[ -n "$output" ]]; then
        lfa_output_check_results "$check_name" "$format" "" "${results[@]}" > "$output"
    fi
}