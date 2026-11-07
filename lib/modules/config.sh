#!/usr/bin/env bash
#
# config.sh - Configuration management CLI module
# Part of linux-first-aid toolkit
#
# Copyright (c) 2024 linux-first-aid contributors
# Licensed under the MIT License

set -euo pipefail

source "${LFA_LIB_DIR}/core/common.sh"
source "${LFA_LIB_DIR}/core/logger.sh"
source "${LFA_LIB_DIR}/core/config.sh"

lfa_config_usage() {
    cat <<'EOF'
Usage: first-aid config <command> [OPTIONS]

Manage configuration.

COMMANDS:
    get <key>           Get configuration value
    set <key> <value>   Set configuration value
    list [prefix]       List all configuration (optionally filtered by prefix)
    reset               Reset to defaults
    save [file]         Save current configuration to file
    show                Show effective configuration
    path                Show configuration file path

OPTIONS:
    -h, --help          Show this help

EXAMPLES:
    first-aid config get diagnose.categories
    first-aid config set check.disk.threshold_warn 85
    first-aid config list check.disk
    first-aid config save ~/.config/linux-first-aid/config.yaml
    first-aid config reset
EOF
}

lfa_config_cmd() {
    local subcmd="${1:-}"
    shift || true

    if [[ "$subcmd" == "-h" || "$subcmd" == "--help" || -z "$subcmd" ]]; then
        lfa_config_usage
        [[ -n "$subcmd" ]] && return 0
        return 2
    fi

    case "$subcmd" in
        get)
            lfa_config_get "$@"
            ;;
        set)
            lfa_config_set "$@"
            ;;
        list)
            lfa_config_list "$@"
            ;;
        reset)
            lfa_config_reset
            ;;
        save)
            lfa_config_save "$@"
            ;;
        show)
            lfa_config_show
            ;;
        path)
            lfa_config_path
            ;;
        -h | --help)
            lfa_config_usage
            return 0
            ;;
        *)
            log_error "Unknown config command: $subcmd"
            lfa_config_usage
            return 2
            ;;
    esac
}

lfa_config_get() {
    local key="${1:-}"

    if [[ -z "$key" ]]; then
        log_error "Key required"
        return 2
    fi

    local value
    value=$(lfa_get_config "$key")

    if [[ -z "$value" ]]; then
        log_warn "Key not found: $key"
        return 1
    fi

    echo "$value"
}

lfa_config_set() {
    local key="${1:-}"
    local value="${2:-}"

    if [[ -z "$key" || -z "$value" ]]; then
        log_error "Key and value required"
        return 2
    fi

    lfa_set_config "$key" "$value"
    log_success "Set $key = $value"
}

lfa_config_list() {
    local prefix="${1:-}"

    lfa_list_config "$prefix"
}

lfa_config_reset() {
    if ! lfa_confirm "Reset all configuration to defaults?" "n"; then
        log_info "Reset cancelled"
        return 0
    fi

    lfa_reset_config
    log_success "Configuration reset to defaults"
}

lfa_config_save() {
    local file="${1:-}"

    if [[ -z "$file" ]]; then
        file="$LFA_USER_CONFIG_DIR/$LFA_DEFAULT_CONFIG_FILE"
    fi

    lfa_save_config "$file"
}

lfa_config_show() {
    log_section "Effective Configuration"

    local config_file
    config_file=$(lfa_get_config_path 2>/dev/null || echo "none")
    log_kv "Config File" "$config_file"

    log_subsection "All Settings"
    lfa_list_config
}

lfa_config_path() {
    local path
    path=$(lfa_get_config_path)

    if [[ -n "$path" ]]; then
        echo "$path"
    else
        log_warn "No configuration file found"
        return 1
    fi
}

lfa_config_init() {
    local config_dir="${1:-$LFA_USER_CONFIG_DIR}"
    local config_file="$config_dir/$LFA_DEFAULT_CONFIG_FILE"

    if [[ -f "$config_file" ]]; then
        log_warn "Configuration already exists: $config_file"
        if ! lfa_confirm "Overwrite?" "n"; then
            return 0
        fi
    fi

    mkdir -p "$config_dir"
    lfa_save_config "$config_file"
    log_success "Configuration initialized at: $config_file"
}
