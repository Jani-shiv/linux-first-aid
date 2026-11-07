#!/usr/bin/env bash
#
# config.sh - Configuration management
# Part of linux-first-aid toolkit
#
# Copyright (c) 2024 linux-first-aid contributors
# Licensed under the MIT License

set -euo pipefail

readonly LFA_DEFAULT_CONFIG_DIR="/etc/linux-first-aid"
readonly LFA_USER_CONFIG_DIR="${XDG_CONFIG_HOME:-$HOME/.config}/linux-first-aid"
readonly LFA_DEFAULT_CONFIG_FILE="config.yaml"
readonly LFA_CONFIG_FILE="${LFA_CONFIG_FILE:-$LFA_DEFAULT_CONFIG_DIR/$LFA_DEFAULT_CONFIG_FILE}"

declare -A LFA_CONFIG=()

lfa_load_config() {
    local config_file="${LFA_CONFIG_FILE:-$LFA_DEFAULT_CONFIG_DIR/$LFA_DEFAULT_CONFIG_FILE}"
    local user_config_file="$LFA_USER_CONFIG_DIR/$LFA_DEFAULT_CONFIG_FILE"

    LFA_CONFIG=()

    if [[ -f "$config_file" ]]; then
        lfa_parse_config "$config_file"
    fi

    if [[ -f "$user_config_file" ]]; then
        lfa_parse_config "$user_config_file"
    fi

    lfa_set_defaults
}

lfa_parse_config() {
    local file="$1"
    local key=""
    local in_array=false
    local array_key=""

    while IFS= read -r line; do
        line="${line%%#*}"
        line="${line%% *}"
        line="${line## }"
        [[ -z "$line" ]] && continue

        if [[ "$line" =~ ^[[:space:]]*-[[:space:]]*(.+)$ ]]; then
            if [[ "$in_array" == "true" ]]; then
                local value="${BASH_REMATCH[1]}"
                value="${value%\"}"
                value="${value#\"}"
                LFA_CONFIG["${array_key}[]"]+="${value} "
            fi
            continue
        fi

        if [[ "$line" =~ ^([a-zA-Z_][a-zA-Z0-9_]*):[[:space:]]*(.*)$ ]]; then
            key="${BASH_REMATCH[1]}"
            local value="${BASH_REMATCH[2]}"
            value="${value%\"}"
            value="${value#\"}"

            if [[ -z "$value" || "$value" == "[]" ]]; then
                in_array=true
                array_key="$key"
                LFA_CONFIG["${key}[]"]=""
            else
                in_array=false
                LFA_CONFIG["$key"]="$value"
            fi
        fi
    done < "$file"
}

lfa_set_defaults() {
    local defaults=(
        "general.check_interval:300"
        "general.alert_threshold:warn"
        "general.auto_repair:false"
        "general.verbose:false"
        "general.color:auto"
        "diagnose.categories:system,disk,memory,cpu,network,services,packages,logs,security,kernel,boot"
        "diagnose.full_scan:true"
        "diagnose.quick_scan:false"
        "diagnose.timeout:300"
        "repair.dry_run:false"
        "repair.force:false"
        "repair.backup:true"
        "repair.categories:packages,network,logs,permissions"
        "monitor.interval:60"
        "monitor.alert_threshold:warn"
        "monitor.daemon:false"
        "monitor.pid_file:/var/run/first-aid-monitor.pid"
        "monitor.log_file:/var/log/first-aid-monitor.log"
        "check.disk.threshold_warn:80"
        "check.disk.threshold_crit:90"
        "check.disk.threshold_inode_warn:80"
        "check.disk.threshold_inode_crit:90"
        "check.memory.threshold_warn:80"
        "check.memory.threshold_crit:90"
        "check.memory.swap_warn:50"
        "check.memory.swap_crit:80"
        "check.cpu.threshold_warn:80"
        "check.cpu.threshold_crit:95"
        "check.cpu.load_warn:2.0"
        "check.cpu.load_crit:4.0"
        "check.network.ping_hosts:8.8.8.8,1.1.1.1"
        "check.network.ping_timeout:5"
        "check.network.dns_servers:8.8.8.8,1.1.1.1"
        "check.network.check_dns:true"
        "check.network.check_http:true"
        "check.services.critical_services:sshd,systemd-resolved,systemd-networkd,cron"
        "check.services.check_enabled:true"
        "check.packages.check_updates:true"
        "check.packages.check_broken:true"
        "check.packages.check_orphans:true"
        "check.logs.since:24h"
        "check.logs.level:error"
        "check.logs.max_entries:1000"
        "check.security.check_firewall:true"
        "check.security.check_ssh_config:true"
        "check.security.check_sudoers:true"
        "check.security.check_world_writable:true"
        "check.security.check_suid:true"
        "check.kernel.check_params:true"
        "check.kernel.check_modules:true"
        "check.kernel.check_dmesg:true"
        "check.boot.check_grub:true"
        "check.boot.check_initramfs:true"
        "check.boot.check_fstab:true"
        "fix.clean_package_cache.max_age:30"
        "fix.clear_journals.max_size:500M"
        "fix.trim_ssd.enabled:true"
        "fix.fix_permissions.paths:/etc,/usr,/var"
        "report.format:text"
        "report.output:-"
        "report.include_timestamp:true"
        "report.include_hostname:true"
    )

    for entry in "${defaults[@]}"; do
        local key="${entry%%:*}"
        local value="${entry#*:}"
        if [[ -z "${LFA_CONFIG[$key]:-}" ]]; then
            LFA_CONFIG["$key"]="$value"
        fi
    done
}

lfa_get_config() {
    local key="$1"
    local default="${2:-}"
    echo "${LFA_CONFIG[$key]:-$default}"
}

lfa_get_config_array() {
    local key="$1"
    local value="${LFA_CONFIG["${key}[]"]:-}"
    if [[ -n "$value" ]]; then
        echo "$value" | tr ' ' '\n' | grep -v '^$'
    fi
}

lfa_set_config() {
    local key="$1"
    local value="$2"
    LFA_CONFIG["$key"]="$value"
}

lfa_set_config_array() {
    local key="$1"
    shift
    LFA_CONFIG["${key}[]"]="$*"
}

lfa_list_config() {
    local prefix="${1:-}"
    for key in "${!LFA_CONFIG[@]}"; do
        if [[ -z "$prefix" || "$key" == "$prefix"* ]]; then
            if [[ "$key" == *\[\] ]]; then
                local array_key="${key%\[\]}"
                local values="${LFA_CONFIG[$key]}"
                echo "$array_key: [$values]"
            else
                echo "$key: ${LFA_CONFIG[$key]}"
            fi
        fi
    done | sort
}

lfa_save_config() {
    local file="${1:-$LFA_USER_CONFIG_DIR/$LFA_DEFAULT_CONFIG_FILE}"
    mkdir -p "$(dirname "$file")"

    {
        echo "# linux-first-aid configuration"
        echo "# Generated on $(lfa_timestamp_iso)"
        echo ""

        local current_section=""
        for key in $(printf '%s\n' "${!LFA_CONFIG[@]}" | sort); do
            local section="${key%%.*}"
            if [[ "$section" != "$current_section" ]]; then
                current_section="$section"
                echo "# $section"
            fi

            if [[ "$key" == *\[\] ]]; then
                local array_key="${key%\[\]}"
                local values="${LFA_CONFIG[$key]}"
                echo "$array_key:"
                for v in $values; do
                    [[ -n "$v" ]] && echo "  - \"$v\""
                done
            else
                local value="${LFA_CONFIG[$key]}"
                if [[ "$value" =~ ^[0-9]+$ ]] || [[ "$value" == "true" ]] || [[ "$value" == "false" ]]; then
                    echo "$key: $value"
                else
                    echo "$key: \"$value\""
                fi
            fi
        done
    } > "$file"

    log_info "Configuration saved to $file"
}

lfa_reset_config() {
    LFA_CONFIG=()
    lfa_set_defaults
}

lfa_config_exists() {
    [[ -f "${LFA_CONFIG_FILE:-$LFA_DEFAULT_CONFIG_DIR/$LFA_DEFAULT_CONFIG_FILE}" ]] || [[ -f "$LFA_USER_CONFIG_DIR/$LFA_DEFAULT_CONFIG_FILE" ]]
}

lfa_get_config_path() {
    if [[ -f "${LFA_CONFIG_FILE:-}" ]]; then
        echo "$LFA_CONFIG_FILE"
    elif [[ -f "$LFA_DEFAULT_CONFIG_DIR/$LFA_DEFAULT_CONFIG_FILE" ]]; then
        echo "$LFA_DEFAULT_CONFIG_DIR/$LFA_DEFAULT_CONFIG_FILE"
    elif [[ -f "$LFA_USER_CONFIG_DIR/$LFA_DEFAULT_CONFIG_FILE" ]]; then
        echo "$LFA_USER_CONFIG_DIR/$LFA_DEFAULT_CONFIG_FILE"
    else
        return 1
    fi
}