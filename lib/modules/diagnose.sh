#!/usr/bin/env bash
#
# diagnose.sh - System diagnosis module
# Part of linux-first-aid toolkit
#
# Copyright (c) 2024 linux-first-aid contributors
# Licensed under the MIT License

set -euo pipefail

source "${LFA_LIB_DIR}/core/common.sh"
source "${LFA_LIB_DIR}/core/logger.sh"
source "${LFA_LIB_DIR}/core/config.sh"

lfa_diagnose_usage() {
    cat <<'EOF'
Usage: first-aid diagnose [OPTIONS]

Run comprehensive system diagnosis.

OPTIONS:
    --full              Run full diagnosis (default)
    --quick             Run quick diagnosis
    --category CATEGORY Run only specific category
    --list-categories   List available categories
    --timeout SECONDS   Timeout for diagnosis (default: 300)
    --output FILE       Write results to file
    --format FORMAT     Output format: text, json (default: text)
    -h, --help          Show this help

CATEGORIES:
    system      Basic system information
    disk        Disk usage and health
    memory      Memory and swap usage
    cpu         CPU usage and load
    network     Network connectivity and configuration
    services    System services status
    packages    Package manager status
    logs        System logs analysis
    security    Security configuration
    kernel      Kernel parameters and modules
    boot        Boot configuration

EXAMPLES:
    first-aid diagnose --full
    first-aid diagnose --quick
    first-aid diagnose --category disk,memory
    first-aid diagnose --output report.json --format json
EOF
}

lfa_diagnose() {
    local full=true
    local quick=false
    local categories=()
    local timeout=300
    local output=""
    local format="text"
    local list_categories=false

    while [[ $# -gt 0 ]]; do
        case $1 in
            --full)
                full=true
                quick=false
                shift
                ;;
            --quick)
                quick=true
                full=false
                shift
                ;;
            --category)
                IFS=',' read -ra categories <<<"$2"
                shift 2
                ;;
            --list-categories)
                list_categories=true
                shift
                ;;
            --timeout)
                timeout="$2"
                shift 2
                ;;
            --output)
                output="$2"
                shift 2
                ;;
            --format)
                format="$2"
                shift 2
                ;;
            -h | --help)
                lfa_diagnose_usage
                return 0
                ;;
            *)
                log_error "Unknown option: $1"
                lfa_diagnose_usage
                return 2
                ;;
        esac
    done

    if [[ "$list_categories" == "true" ]]; then
        lfa_list_diagnose_categories
        return 0
    fi

    if [[ ${#categories[@]} -eq 0 ]]; then
        local config_categories
        config_categories=$(lfa_get_config "diagnose.categories")
        IFS=',' read -ra categories <<<"$config_categories"
    fi

    log_section "System Diagnosis Starting"
    log_info "Mode: $([ "$quick" == "true" ] && echo "Quick" || echo "Full")"
    log_info "Categories: ${categories[*]}"
    log_info "Timeout: ${timeout}s"

    local start_time
    start_time=$(date +%s)
    local results=()
    local failed_categories=()

    for category in "${categories[@]}"; do
        log_subsection "Diagnosing: $category"
        local cat_start
        cat_start=$(date +%s)

        local result
        if result=$(lfa_run_diagnose_category "$category" "$timeout"); then
            results+=("$category:OK")
            log_success "$category: OK ($(lfa_format_elapsed $(($(date +%s) - cat_start))))"
        else
            results+=("$category:FAILED")
            failed_categories+=("$category")
            log_error "$category: FAILED ($(lfa_format_elapsed $(($(date +%s) - cat_start))))"
        fi
    done

    local total_time
    total_time=$(lfa_format_elapsed $(($(date +%s) - start_time)))

    log_section "Diagnosis Complete"
    log_info "Total time: $total_time"
    log_info "Categories passed: $((${#results[@]} - ${#failed_categories[@]}))/${#results[@]}"

    if [[ ${#failed_categories[@]} -gt 0 ]]; then
        log_warn "Failed categories: ${failed_categories[*]}"
    fi

    if [[ -n "$output" ]]; then
        lfa_write_diagnose_report "$output" "$format" "${results[@]}"
        log_info "Report written to: $output"
    fi

    if [[ ${#failed_categories[@]} -gt 0 ]]; then
        return 3
    fi
    return 0
}

lfa_list_diagnose_categories() {
    echo "Available diagnosis categories:"
    echo "  system      - Basic system information"
    echo "  disk        - Disk usage and health"
    echo "  memory      - Memory and swap usage"
    echo "  cpu         - CPU usage and load"
    echo "  network     - Network connectivity and configuration"
    echo "  services    - System services status"
    echo "  packages    - Package manager status"
    echo "  logs        - System logs analysis"
    echo "  security    - Security configuration"
    echo "  kernel      - Kernel parameters and modules"
    echo "  boot        - Boot configuration"
}

lfa_run_diagnose_category() {
    local category="$1"
    local timeout="$2"

    case "$category" in
        system)
            lfa_diagnose_system "$timeout"
            ;;
        disk)
            lfa_diagnose_disk "$timeout"
            ;;
        memory)
            lfa_diagnose_memory "$timeout"
            ;;
        cpu)
            lfa_diagnose_cpu "$timeout"
            ;;
        network)
            lfa_diagnose_network "$timeout"
            ;;
        services)
            lfa_diagnose_services "$timeout"
            ;;
        packages)
            lfa_diagnose_packages "$timeout"
            ;;
        logs)
            lfa_diagnose_logs "$timeout"
            ;;
        security)
            lfa_diagnose_security "$timeout"
            ;;
        kernel)
            lfa_diagnose_kernel "$timeout"
            ;;
        boot)
            lfa_diagnose_boot "$timeout"
            ;;
        *)
            log_error "Unknown category: $category"
            return 1
            ;;
    esac
}

lfa_diagnose_system() {
    local timeout="$1"

    log_kv "Hostname" "$(hostname)"
    log_kv "OS" "$(lfa_get_os_info)"
    log_kv "Kernel" "$(lfa_get_kernel_version)"
    log_kv "Architecture" "$(lfa_get_arch)"
    log_kv "Init System" "$(lfa_get_init_system)"
    log_kv "Container" "$(lfa_is_container && echo "yes" || echo "no")"
    log_kv "Uptime" "$(lfa_format_elapsed $(awk '{print int($1)}' /proc/uptime))"
    log_kv "Load Average" "$(lfa_get_load_average)"
    log_kv "Process Count" "$(lfa_get_process_count)"
    log_kv "Open Files" "$(lfa_get_open_files)"
    log_kv "Network Connections" "$(lfa_get_network_connections)"

    return 0
}

lfa_diagnose_disk() {
    local timeout="$1"
    local warn_threshold
    warn_threshold=$(lfa_get_config "check.disk.threshold_warn" 80)
    local crit_threshold
    crit_threshold=$(lfa_get_config "check.disk.threshold_crit" 90)
    local inode_warn
    inode_warn=$(lfa_get_config "check.disk.threshold_inode_warn" 80)
    local inode_crit
    inode_crit=$(lfa_get_config "check.disk.threshold_inode_crit" 90)

    log_subsection "Disk Usage"
    df -h -x tmpfs -x devtmpfs -x squashfs | while read -r line; do
        log_info "  $line"
    done

    log_subsection "Inode Usage"
    df -hi -x tmpfs -x devtmpfs -x squashfs | while read -r line; do
        log_info "  $line"
    done

    log_subsection "Disk Health (SMART)"
    if lfa_check_command smartctl; then
        for disk in /dev/sd? /dev/nvme?n?; do
            if [[ -b "$disk" ]]; then
                local health
                health=$(smartctl -H "$disk" 2>/dev/null | grep -i "overall\|result" | head -1 || echo "Unknown")
                log_kv "$disk" "$health"
            fi
        done
    else
        log_warn "smartctl not available, skipping SMART checks"
    fi

    log_subsection "Mount Points"
    findmnt -r -o TARGET,SOURCE,FSTYPE,OPTIONS | while read -r line; do
        log_info "  $line"
    done

    return 0
}

lfa_diagnose_memory() {
    local timeout="$1"
    local warn_threshold
    warn_threshold=$(lfa_get_config "check.memory.threshold_warn" 80)
    local crit_threshold
    crit_threshold=$(lfa_get_config "check.memory.threshold_crit" 90)
    local swap_warn
    swap_warn=$(lfa_get_config "check.memory.swap_warn" 50)
    local swap_crit
    swap_crit=$(lfa_get_config "check.memory.swap_crit" 80)

    log_subsection "Memory Usage"
    free -h | while read -r line; do
        log_info "  $line"
    done

    log_subsection "Memory Details"
    grep -E '^(MemTotal|MemFree|MemAvailable|Buffers|Cached|SwapTotal|SwapFree|Shmem|SReclaimable):' /proc/meminfo | while read -r line; do
        log_kv "$(echo "$line" | awk '{print $1}')" "$(echo "$line" | awk '{print $2, $3}')"
    done

    log_subsection "Swap Usage"
    local swap_used_pct=0
    if grep -q "SwapTotal:" /proc/meminfo; then
        local swap_total swap_free
        swap_total=$(grep "SwapTotal:" /proc/meminfo | awk '{print $2}')
        swap_free=$(grep "SwapFree:" /proc/meminfo | awk '{print $2}')
        if ((swap_total > 0)); then
            swap_used_pct=$(((swap_total - swap_free) * 100 / swap_total))
        fi
    fi
    log_kv "Swap Used" "${swap_used_pct}%"

    if ((swap_used_pct >= swap_crit)); then
        log_error "Critical: Swap usage at ${swap_used_pct}%"
        return 1
    elif ((swap_used_pct >= swap_warn)); then
        log_warn "Warning: Swap usage at ${swap_used_pct}%"
    fi

    return 0
}

lfa_diagnose_cpu() {
    local timeout="$1"
    local warn_threshold
    warn_threshold=$(lfa_get_config "check.cpu.threshold_warn" 80)
    local crit_threshold
    crit_threshold=$(lfa_get_config "check.cpu.threshold_crit" 95)
    local load_warn
    load_warn=$(lfa_get_config "check.cpu.load_warn" 2.0)
    local load_crit
    load_crit=$(lfa_get_config "check.cpu.load_crit" 4.0)

    log_subsection "CPU Information"
    lscpu | grep -E '^(CPU\(s\):|Thread|Core|Socket|Model name|CPU MHz|CPU max MHz|CPU min MHz|BogoMIPS|Virtualization|Hypervisor|Flags:)' | while read -r line; do
        log_kv "$(echo "$line" | cut -d: -f1)" "$(echo "$line" | cut -d: -f2- | sed 's/^ *//')"
    done

    log_subsection "Current Load"
    local load_avg
    load_avg=$(lfa_get_load_average)
    log_kv "Load Average" "$load_avg"

    local load_1min
    load_1min=$(echo "$load_avg" | awk '{print $1}')
    local cpu_count
    cpu_count=$(nproc)

    local load_per_cpu
    load_per_cpu=$(echo "scale=2; $load_1min / $cpu_count" | bc 2>/dev/null || echo "0")

    log_kv "Load per CPU" "$load_per_cpu"

    if (($(echo "$load_per_cpu > $load_crit" | bc -l 2>/dev/null || echo 0))); then
        log_error "Critical: Load per CPU ($load_per_cpu) exceeds critical threshold ($load_crit)"
        return 1
    elif (($(echo "$load_per_cpu > $load_warn" | bc -l 2>/dev/null || echo 0))); then
        log_warn "Warning: Load per CPU ($load_per_cpu) exceeds warning threshold ($load_warn)"
    fi

    log_subsection "CPU Usage (top 10 processes)"
    ps aux --sort=-%cpu | head -11 | while read -r line; do
        log_info "  $line"
    done

    log_subsection "CPU Frequency"
    if [[ -d /sys/devices/system/cpu/cpu0/cpufreq ]]; then
        for cpu in /sys/devices/system/cpu/cpu*/cpufreq; do
            if [[ -f "$cpu/scaling_cur_freq" ]]; then
                local cur_freq max_freq governor
                cur_freq=$(cat "$cpu/scaling_cur_freq" 2>/dev/null || echo "N/A")
                max_freq=$(cat "$cpu/scaling_max_freq" 2>/dev/null || echo "N/A")
                governor=$(cat "$cpu/scaling_governor" 2>/dev/null || echo "N/A")
                local cpu_num
                cpu_num=$(basename "$(dirname "$cpu")")
                log_kv "$cpu_num" "cur=${cur_freq}KHz max=${max_freq}KHz gov=$governor"
            fi
        done
    fi

    return 0
}

lfa_diagnose_network() {
    local timeout="$1"
    local ping_hosts
    ping_hosts=$(lfa_get_config "check.network.ping_hosts" "8.8.8.8,1.1.1.1")
    local ping_timeout
    ping_timeout=$(lfa_get_config "check.network.ping_timeout" 5)
    local dns_servers
    dns_servers=$(lfa_get_config "check.network.dns_servers" "8.8.8.8,1.1.1.1")
    local check_dns
    check_dns=$(lfa_get_config "check.network.check_dns" true)
    local check_http
    check_http=$(lfa_get_config "check.network.check_http" true)

    log_subsection "Network Interfaces"
    ip -brief address | while read -r line; do
        log_info "  $line"
    done

    log_subsection "Routing Table"
    ip route | head -20 | while read -r line; do
        log_info "  $line"
    done

    log_subsection "DNS Configuration"
    if [[ -f /etc/resolv.conf ]]; then
        cat /etc/resolv.conf | while read -r line; do
            log_info "  $line"
        done
    fi

    log_subsection "Connectivity Tests"
    IFS=',' read -ra hosts <<<"$ping_hosts"
    for host in "${hosts[@]}"; do
        if lfa_ping_host "$host" 3 "$ping_timeout"; then
            log_success "Ping $host: OK"
        else
            log_error "Ping $host: FAILED"
        fi
    done

    if [[ "$check_dns" == "true" ]]; then
        log_subsection "DNS Resolution"
        IFS=',' read -ra dns <<<"$dns_servers"
        for server in "${dns[@]}"; do
            if lfa_dns_lookup "google.com" A "$server" &>/dev/null; then
                log_success "DNS $server: OK"
            else
                log_error "DNS $server: FAILED"
            fi
        done
    fi

    if [[ "$check_http" == "true" ]]; then
        log_subsection "HTTP Connectivity"
        if lfa_check_command curl; then
            if timeout 10 curl -s -o /dev/null -w "%{http_code}" "http://httpbin.org/get" | grep -q "200"; then
                log_success "HTTP: OK"
            else
                log_warn "HTTP: FAILED or non-200 response"
            fi
        fi
    fi

    log_subsection "Listening Ports"
    lfa_get_listening_ports | while read -r line; do
        log_info "  $line"
    done

    log_subsection "Network Connections Summary"
    ss -s | while read -r line; do
        log_info "  $line"
    done

    return 0
}

lfa_diagnose_services() {
    local timeout="$1"
    local critical_services
    critical_services=$(lfa_get_config "check.services.critical_services" "sshd,systemd-resolved,systemd-networkd,cron")
    local check_enabled
    check_enabled=$(lfa_get_config "check.services.check_enabled" true)

    if ! lfa_is_systemd; then
        log_warn "Not using systemd, limited service diagnostics"
        return 0
    fi

    log_subsection "Critical Services"
    IFS=',' read -ra services <<<"$critical_services"
    for service in "${services[@]}"; do
        local status
        status=$(lfa_service_status "$service" 2>/dev/null || echo "inactive")
        local enabled
        enabled=$(lfa_service_enabled "$service" 2>/dev/null || echo "disabled")

        if [[ "$status" == "active" ]]; then
            log_success "$service: $status ($enabled)"
        else
            log_error "$service: $status ($enabled)"
        fi
    done

    log_subsection "Failed Services"
    local failed
    failed=$(lfa_get_failed_services)
    if [[ -n "$failed" ]]; then
        echo "$failed" | while read -r svc; do
            log_error "Failed: $svc"
        done
    else
        log_success "No failed services"
    fi

    log_subsection "Service Summary"
    systemctl list-units --type=service --no-legend | awk '{print $1, $2, $3, $4}' | while read -r line; do
        log_info "  $line"
    done | head -30

    return 0
}

lfa_diagnose_packages() {
    local timeout="$1"
    local check_updates
    check_updates=$(lfa_get_config "check.packages.check_updates" true)
    local check_broken
    check_broken=$(lfa_get_config "check.packages.check_broken" true)
    local check_orphans
    check_orphans=$(lfa_get_config "check.packages.check_orphans" true)

    local pm
    pm=$(lfa_get_package_manager)
    log_kv "Package Manager" "$pm"

    case "$pm" in
        apt)
            log_subsection "APT Package Status"
            if [[ "$check_updates" == "true" ]]; then
                log_info "Checking for updates..."
                apt update 2>/dev/null | tail -5 | while read -r line; do
                    log_info "  $line"
                done
                local upgradable
                upgradable=$(apt list --upgradable 2>/dev/null | tail -n +2 | wc -l)
                log_kv "Upgradable packages" "$upgradable"
            fi

            if [[ "$check_broken" == "true" ]]; then
                local broken
                broken=$(dpkg -l | grep -c '^ii' || true)
                log_kv "Installed packages" "$broken"
                broken=$(dpkg -l | grep -c '^rc' || true)
                log_kv "Config files remaining" "$broken"
            fi
            ;;

        dnf | yum)
            log_subsection "DNF/YUM Package Status"
            if [[ "$check_updates" == "true" ]]; then
                log_info "Checking for updates..."
                $pm check-update 2>/dev/null | tail -10 | while read -r line; do
                    log_info "  $line"
                done
            fi
            ;;

        pacman)
            log_subsection "Pacman Package Status"
            if [[ "$check_updates" == "true" ]]; then
                log_info "Checking for updates..."
                pacman -Qu 2>/dev/null | while read -r line; do
                    log_info "  $line"
                done
            fi
            if [[ "$check_orphans" == "true" ]]; then
                local orphans
                orphans=$(pacman -Qdtq 2>/dev/null | wc -l)
                log_kv "Orphan packages" "$orphans"
            fi
            ;;

        zypper)
            log_subsection "Zypper Package Status"
            if [[ "$check_updates" == "true" ]]; then
                zypper list-updates 2>/dev/null | tail -10 | while read -r line; do
                    log_info "  $line"
                done
            fi
            ;;

        apk)
            log_subsection "APK Package Status"
            if [[ "$check_updates" == "true" ]]; then
                apk version -l '<' 2>/dev/null | while read -r line; do
                    log_info "  $line"
                done
            fi
            ;;

        *)
            log_warn "Unknown package manager: $pm"
            ;;
    esac

    return 0
}

lfa_diagnose_logs() {
    local timeout="$1"
    local since
    since=$(lfa_get_config "check.logs.since" "24h")
    local level
    level=$(lfa_get_config "check.logs.level" "error")
    local max_entries
    max_entries=$(lfa_get_config "check.logs.max_entries" 1000)

    log_subsection "Journal Errors (since $since)"
    journalctl -p "$level" --since "$since" --no-pager -n "$max_entries" 2>/dev/null | while read -r line; do
        log_info "  $line"
    done

    log_subsection "Kernel Messages (dmesg)"
    dmesg -T --level=err,crit,alert,emerg 2>/dev/null | tail -20 | while read -r line; do
        log_info "  $line"
    done

    log_subsection "Failed Units"
    journalctl -p err -b --no-pager -n 50 2>/dev/null | while read -r line; do
        log_info "  $line"
    done

    return 0
}

lfa_diagnose_security() {
    local timeout="$1"
    local check_firewall
    check_firewall=$(lfa_get_config "check.security.check_firewall" true)
    local check_ssh
    check_ssh=$(lfa_get_config "check.security.check_ssh_config" true)
    local check_sudoers
    check_sudoers=$(lfa_get_config "check.security.check_sudoers" true)
    local check_world_writable
    check_world_writable=$(lfa_get_config "check.security.check_world_writable" true)
    local check_suid
    check_suid=$(lfa_get_config "check.security.check_suid" true)

    log_subsection "Firewall Status"
    if [[ "$check_firewall" == "true" ]]; then
        if lfa_check_command ufw; then
            ufw status verbose | while read -r line; do
                log_info "  $line"
            done
        elif lfa_check_command firewall-cmd; then
            firewall-cmd --list-all | while read -r line; do
                log_info "  $line"
            done
        elif lfa_check_command iptables; then
            iptables -L -n -v | head -20 | while read -r line; do
                log_info "  $line"
            done
        else
            log_warn "No firewall utility detected"
        fi
    fi

    if [[ "$check_ssh" == "true" ]]; then
        log_subsection "SSH Configuration"
        if [[ -f /etc/ssh/sshd_config ]]; then
            grep -E '^(PermitRootLogin|PasswordAuthentication|PubkeyAuthentication|PermitEmptyPasswords|X11Forwarding|MaxAuthTries|ClientAliveInterval|ClientAliveCountMax|Protocol|Port|AllowUsers|DenyUsers|AllowGroups|DenyGroups)' /etc/ssh/sshd_config | while read -r line; do
                log_kv "$(echo "$line" | cut -d' ' -f1)" "$(echo "$line" | cut -d' ' -f2-)"
            done
        fi
    fi

    if [[ "$check_sudoers" == "true" ]]; then
        log_subsection "Sudoers Configuration"
        if [[ -f /etc/sudoers ]]; then
            visudo -c 2>&1 | while read -r line; do
                log_info "  $line"
            done
        fi
    fi

    if [[ "$check_world_writable" == "true" ]]; then
        log_subsection "World-Writable Files (sample)"
        find / -xdev -type f -perm -0002 ! -perm -1000 2>/dev/null | head -20 | while read -r line; do
            log_warn "World-writable: $line"
        done
    fi

    if [[ "$check_suid" == "true" ]]; then
        log_subsection "SUID/SGID Files (sample)"
        find / -xdev -type f \( -perm -4000 -o -perm -2000 \) 2>/dev/null | head -20 | while read -r line; do
            log_info "SUID/SGID: $line"
        done
    fi

    log_subsection "Login Failures (last 24h)"
    lastb -s -24h 2>/dev/null | head -10 | while read -r line; do
        log_warn "  $line"
    done

    return 0
}

lfa_diagnose_kernel() {
    local timeout="$1"
    local check_params
    check_params=$(lfa_get_config "check.kernel.check_params" true)
    local check_modules
    check_modules=$(lfa_get_config "check.kernel.check_modules" true)
    local check_dmesg
    check_dmesg=$(lfa_get_config "check.kernel.check_dmesg" true)

    if [[ "$check_params" == "true" ]]; then
        log_subsection "Kernel Parameters"
        sysctl -a 2>/dev/null | grep -E '(net.ipv4|net.ipv6|vm.|kernel.|fs.)' | head -30 | while read -r line; do
            log_kv "$(echo "$line" | cut -d= -f1)" "$(echo "$line" | cut -d= -f2- | sed 's/^ *//')"
        done
    fi

    if [[ "$check_modules" == "true" ]]; then
        log_subsection "Loaded Kernel Modules"
        lsmod | head -30 | while read -r line; do
            log_info "  $line"
        done
    fi

    if [[ "$check_dmesg" == "true" ]]; then
        log_subsection "Recent Kernel Messages (errors/warnings)"
        dmesg -T --level=err,warn 2>/dev/null | tail -20 | while read -r line; do
            log_info "  $line"
        done
    fi

    return 0
}

lfa_diagnose_boot() {
    local timeout="$1"
    local check_grub
    check_grub=$(lfa_get_config "check.boot.check_grub" true)
    local check_initramfs
    check_initramfs=$(lfa_get_config "check.boot.check_initramfs" true)
    local check_fstab
    check_fstab=$(lfa_get_config "check.boot.check_fstab" true)

    if [[ "$check_grub" == "true" ]]; then
        log_subsection "GRUB Configuration"
        if [[ -f /boot/grub/grub.cfg ]]; then
            grep -E '^(menuentry|set timeout|set default|linux|initrd)' /boot/grub/grub.cfg | head -20 | while read -r line; do
                log_info "  $line"
            done
        elif [[ -f /boot/grub2/grub.cfg ]]; then
            grep -E '^(menuentry|set timeout|set default|linux|initrd)' /boot/grub2/grub.cfg | head -20 | while read -r line; do
                log_info "  $line"
            done
        fi
    fi

    if [[ "$check_initramfs" == "true" ]]; then
        log_subsection "Initramfs Images"
        ls -lh /boot/initramfs-* /boot/initrd-* 2>/dev/null | while read -r line; do
            log_info "  $line"
        done
    fi

    if [[ "$check_fstab" == "true" ]]; then
        log_subsection "FSTAB"
        if [[ -f /etc/fstab ]]; then
            cat /etc/fstab | grep -v '^#' | while read -r line; do
                log_info "  $line"
            done
        fi
    fi

    log_subsection "Boot Time Analysis"
    if lfa_is_systemd; then
        systemd-analyze 2>/dev/null | while read -r line; do
            log_info "  $line"
        done
        systemd-analyze blame 2>/dev/null | head -10 | while read -r line; do
            log_info "  $line"
        done
    fi

    return 0
}

lfa_write_diagnose_report() {
    local output="$1"
    local format="$2"
    shift 2
    local results=("$@")

    case "$format" in
        json)
            {
                echo "{"
                echo '  "timestamp": "'$(lfa_timestamp_iso)'",'
                echo '  "hostname": "'$(hostname)'",'
                echo '  "results": {'
                local first=true
                for result in "${results[@]}"; do
                    local category="${result%%:*}"
                    local status="${result#*:}"
                    if [[ "$first" == "true" ]]; then
                        first=false
                    else
                        echo ","
                    fi
                    echo -n "    \"$category\": \"$status\""
                done
                echo ""
                echo "  }"
                echo "}"
            } >"$output"
            ;;
        text | *)
            {
                echo "linux-first-aid Diagnosis Report"
                echo "Generated: $(lfa_timestamp)"
                echo "Hostname: $(hostname)"
                echo ""
                echo "Results:"
                for result in "${results[@]}"; do
                    local category="${result%%:*}"
                    local status="${result#*:}"
                    printf "  %-15s %s\n" "$category:" "$status"
                done
            } >"$output"
            ;;
    esac
}
