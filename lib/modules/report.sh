#!/usr/bin/env bash
#
# report.sh - System health report generation module
# Part of linux-first-aid toolkit
#
# Copyright (c) 2024 linux-first-aid contributors
# Licensed under the MIT License

set -euo pipefail

source "${LFA_LIB_DIR}/core/common.sh"
source "${LFA_LIB_DIR}/core/logger.sh"
source "${LFA_LIB_DIR}/core/config.sh"

lfa_report_usage() {
    cat <<'EOF'
Usage: first-aid report [OPTIONS]

Generate system health report.

OPTIONS:
    --format FORMAT     Output format: text, json, html, markdown (default: text)
    --output FILE       Output file (default: stdout)
    --include-sections  Comma-separated sections to include
    --exclude-sections  Comma-separated sections to exclude
    --template FILE     Custom template file
    -h, --help          Show this help

SECTIONS:
    system      System information
    disk        Disk usage and health
    memory      Memory and swap
    cpu         CPU and load
    network     Network status
    services    Service status
    packages    Package status
    logs        Recent errors
    security    Security status
    kernel      Kernel info
    boot        Boot status

EXAMPLES:
    first-aid report --format html --output report.html
    first-aid report --format json --output report.json
    first-aid report --format markdown --output report.md
    first-aid report --include-sections disk,memory,cpu
EOF
}

lfa_report() {
    local format="text"
    local output=""
    local include_sections=""
    local exclude_sections=""
    local template=""

    while [[ $# -gt 0 ]]; do
        case $1 in
            --format)
                format="$2"
                shift 2
                ;;
            --output)
                output="$2"
                shift 2
                ;;
            --include-sections)
                include_sections="$2"
                shift 2
                ;;
            --exclude-sections)
                exclude_sections="$2"
                shift 2
                ;;
            --template)
                template="$2"
                shift 2
                ;;
            -h | --help)
                lfa_report_usage
                return 0
                ;;
            *)
                log_error "Unknown option: $1"
                lfa_report_usage
                return 2
                ;;
        esac
    done

    if [[ -n "$template" ]]; then
        if [[ ! -f "$template" ]]; then
            log_error "Template file not found: $template"
            return 1
        fi
        log_warn "Custom templates are not supported yet; using the built-in template"
    fi

    local sections=("system" "disk" "memory" "cpu" "network" "services" "packages" "logs" "security" "kernel" "boot")

    if [[ -n "$include_sections" ]]; then
        IFS=',' read -ra sections <<<"$include_sections"
    fi

    if [[ -n "$exclude_sections" ]]; then
        local new_sections=()
        for section in "${sections[@]}"; do
            IFS=',' read -ra excluded <<<"$exclude_sections"
            if ! lfa_in_array "$section" "${excluded[@]}"; then
                new_sections+=("$section")
            fi
        done
        sections=("${new_sections[@]}")
    fi

    log_section "Generating System Health Report"
    log_kv "Format" "$format"
    log_kv "Sections" "${sections[*]}"

    local report_data
    report_data=$(lfa_generate_report_data "${sections[@]}")

    local report_output
    case "$format" in
        json)
            report_output=$(lfa_format_report_json "$report_data")
            ;;
        html)
            report_output=$(lfa_format_report_html "$report_data")
            ;;
        markdown | md)
            report_output=$(lfa_format_report_markdown "$report_data")
            ;;
        text | *)
            report_output=$(lfa_format_report_text "$report_data")
            ;;
    esac

    if [[ -n "$output" ]]; then
        echo "$report_output" >"$output"
        log_success "Report written to: $output"
    else
        echo "$report_output"
    fi
}

lfa_generate_report_data() {
    local sections=("$@")
    local data=()

    for section in "${sections[@]}"; do
        case "$section" in
            system)
                data+=("$section:$(lfa_collect_system_info)")
                ;;
            disk)
                data+=("$section:$(lfa_collect_disk_info)")
                ;;
            memory)
                data+=("$section:$(lfa_collect_memory_info)")
                ;;
            cpu)
                data+=("$section:$(lfa_collect_cpu_info)")
                ;;
            network)
                data+=("$section:$(lfa_collect_network_info)")
                ;;
            services)
                data+=("$section:$(lfa_collect_services_info)")
                ;;
            packages)
                data+=("$section:$(lfa_collect_packages_info)")
                ;;
            logs)
                data+=("$section:$(lfa_collect_logs_info)")
                ;;
            security)
                data+=("$section:$(lfa_collect_security_info)")
                ;;
            kernel)
                data+=("$section:$(lfa_collect_kernel_info)")
                ;;
            boot)
                data+=("$section:$(lfa_collect_boot_info)")
                ;;
        esac
    done

    lfa_join_array "|" "${data[@]}"
}

lfa_collect_system_info() {
    local info=()
    info+=("hostname=$(hostname)")
    info+=("os=$(lfa_get_os_info)")
    info+=("kernel=$(lfa_get_kernel_version)")
    info+=("arch=$(lfa_get_arch)")
    info+=("init=$(lfa_get_init_system)")
    info+=("container=$(lfa_is_container && echo true || echo false)")
    info+=("uptime=$(lfa_format_elapsed "$(awk '{print int($1)}' /proc/uptime)")")
    info+=("load=$(lfa_get_load_average)")
    info+=("processes=$(lfa_get_process_count)")
    lfa_join_array ";" "${info[@]}"
}

lfa_collect_disk_info() {
    local info=()
    while read -r line; do
        if [[ "$line" =~ ^/dev/ ]]; then
            local fs mount usage avail
            fs=$(echo "$line" | awk '{print $1}')
            mount=$(echo "$line" | awk '{print $6}')
            usage=$(echo "$line" | awk '{print $5}')
            avail=$(echo "$line" | awk '{print $4}')
            info+=("$mount:$fs:$usage:$avail")
        fi
    done < <(df -h -x tmpfs -x devtmpfs -x squashfs)
    lfa_join_array "," "${info[@]}"
}

lfa_collect_memory_info() {
    local mem_info
    mem_info=$(free -b | grep "^Mem:")
    local total used free available
    total=$(echo "$mem_info" | awk '{print $2}')
    used=$(echo "$mem_info" | awk '{print $3}')
    free=$(echo "$mem_info" | awk '{print $4}')
    available=$(echo "$mem_info" | awk '{print $7}')
    local pct=$((used * 100 / total))

    local swap_info
    swap_info=$(free -b | grep "^Swap:")
    local swap_total swap_used swap_free
    swap_total=$(echo "$swap_info" | awk '{print $2}')
    swap_used=$(echo "$swap_info" | awk '{print $3}')
    swap_free=$(echo "$swap_info" | awk '{print $4}')
    local swap_pct=0
    if ((swap_total > 0)); then
        swap_pct=$((swap_used * 100 / swap_total))
    fi

    echo "total=$total;used=$used;free=$free;available=$available;pct=$pct;swap_total=$swap_total;swap_used=$swap_used;swap_free=$swap_free;swap_pct=$swap_pct"
}

lfa_collect_cpu_info() {
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

    echo "load_1min=$load_1min;load_5min=$load_5min;load_15min=$load_15min;cpu_count=$cpu_count;load_per_cpu=$load_per_cpu"
}

lfa_collect_network_info() {
    local info=()
    local ping_hosts
    ping_hosts=$(lfa_get_config "check.network.ping_hosts" "8.8.8.8,1.1.1.1")
    local ping_timeout
    ping_timeout=$(lfa_get_config "check.network.ping_timeout" 5)

    IFS=',' read -ra hosts <<<"$ping_hosts"
    for host in "${hosts[@]}"; do
        if lfa_ping_host "$host" 3 "$ping_timeout"; then
            info+=("ping:$host:ok")
        else
            info+=("ping:$host:failed")
        fi
    done

    local interfaces
    interfaces=$(ip -brief address | grep -v "lo" | awk '{print $1":"$2":"$3}')
    echo "ping=$(lfa_join_array "," "${info[@]}");interfaces=$interfaces"
}

lfa_collect_services_info() {
    if ! lfa_is_systemd; then
        echo "init_not_systemd=true"
        return
    fi

    local info=()
    local critical_services
    critical_services=$(lfa_get_config "check.services.critical_services" "sshd,systemd-resolved,systemd-networkd,cron")

    IFS=',' read -ra services <<<"$critical_services"
    for service in "${services[@]}"; do
        local status
        status=$(lfa_service_status "$service" 2>/dev/null || echo "inactive")
        local enabled
        enabled=$(lfa_service_enabled "$service" 2>/dev/null || echo "disabled")
        info+=("$service:$status:$enabled")
    done

    local failed
    failed=$(lfa_get_failed_services)
    if [[ -n "$failed" ]]; then
        info+=("failed=$(echo "$failed" | tr '\n' ',')")
    fi

    echo "$(lfa_join_array ";" "${info[@]}")"
}

lfa_collect_packages_info() {
    local pm
    pm=$(lfa_get_package_manager)
    local info=("pm=$pm")

    case "$pm" in
        apt)
            local upgradable
            upgradable=$(apt list --upgradable 2>/dev/null | tail -n +2 | wc -l)
            info+=("upgradable=$upgradable")
            ;;
        dnf | yum)
            local updates
            updates=$($pm check-update 2>/dev/null | grep -c "^[^.]" || true)
            info+=("updates=$updates")
            ;;
        pacman)
            local updates
            updates=$(pacman -Qu 2>/dev/null | wc -l)
            info+=("updates=$updates")
            local orphans
            orphans=$(pacman -Qdtq 2>/dev/null | wc -l)
            info+=("orphans=$orphans")
            ;;
    esac

    echo "$(lfa_join_array ";" "${info[@]}")"
}

lfa_collect_logs_info() {
    local since
    since=$(lfa_get_config "check.logs.since" "24h")
    local level
    level=$(lfa_get_config "check.logs.level" "error")

    local error_count
    error_count=$(journalctl -p "$level" --since "$since" --no-pager 2>/dev/null | wc -l)

    local failed_units
    failed_units=$(journalctl -p err -b --no-pager 2>/dev/null | grep -c "Failed" || true)

    echo "error_count=$error_count;failed_units=$failed_units;since=$since;level=$level"
}

lfa_collect_security_info() {
    local info=()

    if lfa_check_command ufw; then
        local ufw_status
        ufw_status=$(ufw status | head -1 | awk '{print $2}')
        info+=("ufw=$ufw_status")
    elif lfa_check_command firewall-cmd; then
        local fw_status
        fw_status=$(firewall-cmd --state 2>/dev/null || echo "unknown")
        info+=("firewalld=$fw_status")
    fi

    if [[ -f /etc/ssh/sshd_config ]]; then
        local root_login
        root_login=$(grep -i "^PermitRootLogin" /etc/ssh/sshd_config | awk '{print $2}' || echo "yes")
        info+=("ssh_root_login=$root_login")
    fi

    local world_writable
    world_writable=$(find / -xdev -type f -perm -0002 ! -perm -1000 2>/dev/null | wc -l)
    info+=("world_writable=$world_writable")

    echo "$(lfa_join_array ";" "${info[@]}")"
}

lfa_collect_kernel_info() {
    local info=()
    info+=("version=$(lfa_get_kernel_version)")
    info+=("modules=$(lsmod | wc -l)")
    info+=("dmesg_errors=$(dmesg --level=err 2>/dev/null | wc -l)")
    echo "$(lfa_join_array ";" "${info[@]}")"
}

lfa_collect_boot_info() {
    local info=()

    if lfa_is_systemd; then
        local boot_time
        boot_time=$(systemd-analyze 2>/dev/null | grep "Startup finished" | sed 's/.*in //' || echo "unknown")
        info+=("boot_time=$boot_time")
    fi

    if [[ -f /etc/fstab ]]; then
        local fstab_entries
        fstab_entries=$(grep -v '^#' /etc/fstab | grep -c -v '^$' || echo 0)
        info+=("fstab_entries=$fstab_entries")
    fi

    echo "$(lfa_join_array ";" "${info[@]}")"
}

lfa_format_report_text() {
    local data="$1"
    local output=""

    output+="========================================\n"
    output+="  Linux First Aid - System Health Report\n"
    output+="========================================\n"
    output+="Generated: $(lfa_timestamp)\n"
    output+="Hostname: $(hostname)\n"
    output+="\n"

    IFS='|' read -ra sections <<<"$data"
    for section_data in "${sections[@]}"; do
        IFS=':' read -r section content <<<"$section_data"
        output+="--- ${section^^} ---\n"
        output+=$(lfa_format_section_text "$section" "$content")
        output+="\n"
    done

    echo -e "$output"
}

lfa_format_section_text() {
    local section="$1"
    local content="$2"
    local output=""

    case "$section" in
        system)
            IFS=';' read -ra items <<<"$content"
            for item in "${items[@]}"; do
                IFS='=' read -r key value <<<"$item"
                output+="  $(echo "$key" | sed 's/_/ /g' | sed 's/\b\(.\)/\u\1/g'): $value\n"
            done
            ;;
        disk)
            IFS=',' read -ra items <<<"$content"
            output+="  Filesystem          Mount Point     Usage  Available\n"
            for item in "${items[@]}"; do
                IFS=':' read -r mount fs usage avail <<<"$item"
                output+="  $(printf "%-18s %-15s %-6s %s\n" "$fs" "$mount" "$usage" "$avail")"
            done
            ;;
        memory)
            IFS=';' read -ra items <<<"$content"
            for item in "${items[@]}"; do
                IFS='=' read -r key value <<<"$item"
                case "$key" in
                    total | used | free | available | swap_total | swap_used | swap_free)
                        value=$(lfa_human_readable "$value")
                        ;;
                esac
                output+="  $(echo "$key" | sed 's/_/ /g' | sed 's/\b\(.\)/\u\1/g'): $value\n"
            done
            ;;
        cpu)
            IFS=';' read -ra items <<<"$content"
            for item in "${items[@]}"; do
                IFS='=' read -r key value <<<"$item"
                output+="  $(echo "$key" | sed 's/_/ /g' | sed 's/\b\(.\)/\u\1/g'): $value\n"
            done
            ;;
        network)
            IFS=';' read -ra items <<<"$content"
            for item in "${items[@]}"; do
                IFS='=' read -r key value <<<"$item"
                if [[ "$key" == "ping" ]]; then
                    output+="  Ping Tests:\n"
                    IFS=',' read -ra pings <<<"$value"
                    for ping in "${pings[@]}"; do
                        IFS=':' read -r _ host status <<<"$ping"
                        output+="    $host: $status\n"
                    done
                else
                    output+="  Interfaces:\n"
                    IFS=',' read -ra ifaces <<<"$value"
                    for iface in "${ifaces[@]}"; do
                        IFS=':' read -r name state ip <<<"$iface"
                        output+="    $name: $state $ip\n"
                    done
                fi
            done
            ;;
        services)
            if [[ "$content" == "init_not_systemd=true" ]]; then
                output+="  Not using systemd\n"
            else
                IFS=';' read -ra items <<<"$content"
                for item in "${items[@]}"; do
                    IFS=':' read -r name status enabled <<<"$item"
                    if [[ "$name" == "failed" ]]; then
                        output+="  Failed Services: $status\n"
                    else
                        output+="  $name: $status ($enabled)\n"
                    fi
                done
            fi
            ;;
        packages)
            IFS=';' read -ra items <<<"$content"
            for item in "${items[@]}"; do
                IFS='=' read -r key value <<<"$item"
                output+="  $(echo "$key" | sed 's/_/ /g' | sed 's/\b\(.\)/\u\1/g'): $value\n"
            done
            ;;
        logs)
            IFS=';' read -ra items <<<"$content"
            for item in "${items[@]}"; do
                IFS='=' read -r key value <<<"$item"
                output+="  $(echo "$key" | sed 's/_/ /g' | sed 's/\b\(.\)/\u\1/g'): $value\n"
            done
            ;;
        security)
            IFS=';' read -ra items <<<"$content"
            for item in "${items[@]}"; do
                IFS='=' read -r key value <<<"$item"
                output+="  $(echo "$key" | sed 's/_/ /g' | sed 's/\b\(.\)/\u\1/g'): $value\n"
            done
            ;;
        kernel)
            IFS=';' read -ra items <<<"$content"
            for item in "${items[@]}"; do
                IFS='=' read -r key value <<<"$item"
                output+="  $(echo "$key" | sed 's/_/ /g' | sed 's/\b\(.\)/\u\1/g'): $value\n"
            done
            ;;
        boot)
            IFS=';' read -ra items <<<"$content"
            for item in "${items[@]}"; do
                IFS='=' read -r key value <<<"$item"
                output+="  $(echo "$key" | sed 's/_/ /g' | sed 's/\b\(.\)/\u\1/g'): $value\n"
            done
            ;;
    esac

    echo -e "$output"
}

lfa_format_report_json() {
    local data="$1"
    local json="{"
    json+='"generated":"'$(lfa_timestamp_iso)'",'
    json+='"hostname":"'$(hostname)'",'
    json+='"sections":{'

    IFS='|' read -ra sections <<<"$data"
    local first=true
    for section_data in "${sections[@]}"; do
        IFS=':' read -r section content <<<"$section_data"
        if [[ "$first" == "true" ]]; then
            first=false
        else
            json+=","
        fi
        json+='"'$section'":'$content
    done

    json+="}}"
    echo "$json"
}

lfa_format_report_html() {
    local data="$1"
    local html="<!DOCTYPE html>
<html>
<head>
    <title>Linux First Aid - System Health Report</title>
    <style>
        body { font-family: monospace; margin: 20px; background: #1e1e1e; color: #d4d4d4; }
        h1 { color: #4ec9b0; border-bottom: 1px solid #333; padding-bottom: 10px; }
        h2 { color: #dcdcaa; border-bottom: 1px solid #333; padding-bottom: 5px; }
        .section { margin-bottom: 20px; }
        .key { color: #9cdcfe; }
        .value { color: #ce9178; }
        .ok { color: #4ec9b0; }
        .warn { color: #dcdcaa; }
        .crit { color: #f44747; }
        table { border-collapse: collapse; width: 100%; }
        th, td { border: 1px solid #333; padding: 8px; text-align: left; }
        th { background: #2d2d2d; }
        tr:nth-child(even) { background: #252526; }
        .timestamp { color: #6a9955; font-size: 0.9em; }
    </style>
</head>
<body>
    <h1>Linux First Aid - System Health Report</h1>
    <p class=\"timestamp\">Generated: $(lfa_timestamp) | Hostname: $(hostname)</p>"

    IFS='|' read -ra sections <<<"$data"
    for section_data in "${sections[@]}"; do
        IFS=':' read -r section content <<<"$section_data"
        html+="<div class=\"section\"><h2>${section^^}</h2>"
        html+=$(lfa_format_section_html "$section" "$content")
        html+="</div>"
    done

    html+="</body></html>"
    echo "$html"
}

lfa_format_section_html() {
    local section="$1"
    local content="$2"
    local html=""

    case "$section" in
        system | memory | cpu | packages | logs | security | kernel | boot)
            html+="<table><tr><th>Property</th><th>Value</th></tr>"
            IFS=';' read -ra items <<<"$content"
            for item in "${items[@]}"; do
                IFS='=' read -r key value <<<"$item"
                local display_key
                display_key=$(echo "$key" | sed 's/_/ /g' | sed 's/\b\(.\)/\u\1/g')
                if [[ "$key" =~ ^(total|used|free|available|swap_total|swap_used|swap_free)$ ]]; then
                    value=$(lfa_human_readable "$value")
                fi
                html+="<tr><td class=\"key\">$display_key</td><td class=\"value\">$value</td></tr>"
            done
            html+="</table>"
            ;;
        disk)
            html+="<table><tr><th>Filesystem</th><th>Mount Point</th><th>Usage</th><th>Available</th></tr>"
            IFS=',' read -ra items <<<"$content"
            for item in "${items[@]}"; do
                IFS=':' read -r mount fs usage avail <<<"$item"
                local usage_class="ok"
                local usage_num
                usage_num=$(echo "$usage" | sed 's/%//')
                if ((usage_num >= 90)); then
                    usage_class="crit"
                elif ((usage_num >= 80)); then
                    usage_class="warn"
                fi
                html+="<tr><td>$fs</td><td>$mount</td><td class=\"$usage_class\">$usage</td><td>$avail</td></tr>"
            done
            html+="</table>"
            ;;
        network)
            IFS=';' read -ra items <<<"$content"
            for item in "${items[@]}"; do
                IFS='=' read -r key value <<<"$item"
                if [[ "$key" == "ping" ]]; then
                    html+="<h3>Ping Tests</h3><table><tr><th>Host</th><th>Status</th></tr>"
                    IFS=',' read -ra pings <<<"$value"
                    for ping in "${pings[@]}"; do
                        IFS=':' read -r _ host status <<<"$ping"
                        local status_class="ok"
                        [[ "$status" == "failed" ]] && status_class="crit"
                        html+="<tr><td>$host</td><td class=\"$status_class\">$status</td></tr>"
                    done
                    html+="</table>"
                else
                    html+="<h3>Interfaces</h3><table><tr><th>Name</th><th>State</th><th>IP</th></tr>"
                    IFS=',' read -ra ifaces <<<"$value"
                    for iface in "${ifaces[@]}"; do
                        IFS=':' read -r name state ip <<<"$iface"
                        html+="<tr><td>$name</td><td>$state</td><td>$ip</td></tr>"
                    done
                    html+="</table>"
                fi
            done
            ;;
        services)
            if [[ "$content" == "init_not_systemd=true" ]]; then
                html+="<p>Not using systemd</p>"
            else
                html+="<table><tr><th>Service</th><th>Status</th><th>Enabled</th></tr>"
                IFS=';' read -ra items <<<"$content"
                for item in "${items[@]}"; do
                    IFS=':' read -r name status enabled <<<"$item"
                    if [[ "$name" == "failed" ]]; then
                        html+="<tr><td colspan=\"3\" class=\"crit\">Failed: $status</td></tr>"
                    else
                        local status_class="ok"
                        [[ "$status" != "active" ]] && status_class="crit"
                        html+="<tr><td>$name</td><td class=\"$status_class\">$status</td><td>$enabled</td></tr>"
                    fi
                done
                html+="</table>"
            fi
            ;;
    esac

    echo "$html"
}

lfa_format_report_markdown() {
    local data="$1"
    local md="# Linux First Aid - System Health Report

Generated: $(lfa_timestamp)  
Hostname: $(hostname)

"

    IFS='|' read -ra sections <<<"$data"
    for section_data in "${sections[@]}"; do
        IFS=':' read -r section content <<<"$section_data"
        md+="## ${section^^}\n\n"
        md+=$(lfa_format_section_markdown "$section" "$content")
        md+="\n"
    done

    echo "$md"
}

lfa_format_section_markdown() {
    local section="$1"
    local content="$2"
    local md=""

    case "$section" in
        system | memory | cpu | packages | logs | security | kernel | boot)
            md+="| Property | Value |\n|----------|-------|\n"
            IFS=';' read -ra items <<<"$content"
            for item in "${items[@]}"; do
                IFS='=' read -r key value <<<"$item"
                local display_key
                display_key=$(echo "$key" | sed 's/_/ /g' | sed 's/\b\(.\)/\u\1/g')
                if [[ "$key" =~ ^(total|used|free|available|swap_total|swap_used|swap_free)$ ]]; then
                    value=$(lfa_human_readable "$value")
                fi
                md+="| $display_key | $value |\n"
            done
            ;;
        disk)
            md+="| Filesystem | Mount Point | Usage | Available |\n|------------|-------------|-------|-----------|\n"
            IFS=',' read -ra items <<<"$content"
            for item in "${items[@]}"; do
                IFS=':' read -r mount fs usage avail <<<"$item"
                md+="| $fs | $mount | $usage | $avail |\n"
            done
            ;;
        network)
            IFS=';' read -ra items <<<"$content"
            for item in "${items[@]}"; do
                IFS='=' read -r key value <<<"$item"
                if [[ "$key" == "ping" ]]; then
                    md+="### Ping Tests\n\n| Host | Status |\n|------|--------|\n"
                    IFS=',' read -ra pings <<<"$value"
                    for ping in "${pings[@]}"; do
                        IFS=':' read -r _ host status <<<"$ping"
                        md+="| $host | $status |\n"
                    done
                else
                    md+="### Interfaces\n\n| Name | State | IP |\n|------|-------|----|\n"
                    IFS=',' read -ra ifaces <<<"$value"
                    for iface in "${ifaces[@]}"; do
                        IFS=':' read -r name state ip <<<"$iface"
                        md+="| $name | $state | $ip |\n"
                    done
                fi
            done
            ;;
        services)
            if [[ "$content" == "init_not_systemd=true" ]]; then
                md+="Not using systemd\n"
            else
                md+="| Service | Status | Enabled |\n|---------|--------|---------|\n"
                IFS=';' read -ra items <<<"$content"
                for item in "${items[@]}"; do
                    IFS=':' read -r name status enabled <<<"$item"
                    if [[ "$name" == "failed" ]]; then
                        md+="| **Failed** | $status | - |\n"
                    else
                        md+="| $name | $status | $enabled |\n"
                    fi
                done
            fi
            ;;
    esac

    echo "$md"
}
