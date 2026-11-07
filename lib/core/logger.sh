#!/usr/bin/env bash
#
# logger.sh - Logging utilities
# Part of linux-first-aid toolkit
#
# Copyright (c) 2024 linux-first-aid contributors
# Licensed under the MIT License

set -euo pipefail

LOG_LEVEL_DEBUG=0
LOG_LEVEL_INFO=1
LOG_LEVEL_WARN=2
LOG_LEVEL_ERROR=3
LOG_LEVEL_QUIET=4

LFA_LOG_LEVEL="${LFA_LOG_LEVEL:-$LOG_LEVEL_INFO}"
LFA_LOG_FILE="${LFA_LOG_FILE:-}"
LFA_LOG_JSON="${LFA_LOG_JSON:-false}"
LFA_NO_COLOR="${LFA_NO_COLOR:-false}"

COLOR_RESET='\033[0m'
COLOR_RED='\033[0;31m'
COLOR_GREEN='\033[0;32m'
COLOR_YELLOW='\033[1;33m'
COLOR_BLUE='\033[0;34m'
COLOR_MAGENTA='\033[0;35m'
COLOR_CYAN='\033[0;36m'
COLOR_BOLD='\033[1m'

lfa_init_logger() {
    local log_level="${LFA_LOG_LEVEL:-info}"
    local log_file="${LFA_LOG_FILE:-}"
    local quiet="${LFA_QUIET:-false}"
    local debug="${LFA_DEBUG:-false}"
    local no_color="${LFA_NO_COLOR:-false}"

    if [[ "$debug" == "true" ]]; then
        LFA_LOG_LEVEL=$LOG_LEVEL_DEBUG
    elif [[ "$quiet" == "true" ]]; then
        LFA_LOG_LEVEL=$LOG_LEVEL_QUIET
    else
        case "${log_level,,}" in
            debug) LFA_LOG_LEVEL=$LOG_LEVEL_DEBUG ;;
            info) LFA_LOG_LEVEL=$LOG_LEVEL_INFO ;;
            warn) LFA_LOG_LEVEL=$LOG_LEVEL_WARN ;;
            error) LFA_LOG_LEVEL=$LOG_LEVEL_ERROR ;;
            quiet) LFA_LOG_LEVEL=$LOG_LEVEL_QUIET ;;
            *) LFA_LOG_LEVEL=$LOG_LEVEL_INFO ;;
        esac
    fi

    if [[ "$no_color" == "true" ]] || ! [[ -t 1 ]]; then
        COLOR_RESET=''
        COLOR_RED=''
        COLOR_GREEN=''
        COLOR_YELLOW=''
        COLOR_BLUE=''
        COLOR_MAGENTA=''
        COLOR_CYAN=''
        COLOR_BOLD=''
    fi

    if [[ -n "$log_file" ]]; then
        mkdir -p "$(dirname "$log_file")"
        touch "$log_file"
    fi
}

_lfa_log() {
    local level="$1"
    local level_name="$2"
    local color="$3"
    local message="$4"
    local timestamp
    timestamp=$(lfa_timestamp_iso)

    if [[ $level -lt $LFA_LOG_LEVEL ]]; then
        return 0
    fi

    local formatted_message
    if [[ "$LFA_LOG_JSON" == "true" ]]; then
        formatted_message=$(jq -n \
            --arg ts "$timestamp" \
            --arg level "$level_name" \
            --arg msg "$message" \
            '{timestamp: $ts, level: $level, message: $msg}')
    else
        formatted_message="[${timestamp}] [${level_name}] ${message}"
    fi

    if [[ -n "$LFA_LOG_FILE" ]]; then
        echo "$formatted_message" >>"$LFA_LOG_FILE"
    fi

    if [[ $level -ge $LOG_LEVEL_WARN ]]; then
        echo -e "${color}${formatted_message}${COLOR_RESET}" >&2
    else
        echo -e "${color}${formatted_message}${COLOR_RESET}"
    fi
}

log_debug() {
    _lfa_log $LOG_LEVEL_DEBUG "DEBUG" "$COLOR_BLUE" "$*"
}

log_info() {
    _lfa_log $LOG_LEVEL_INFO "INFO" "$COLOR_GREEN" "$*"
}

log_warn() {
    _lfa_log $LOG_LEVEL_WARN "WARN" "$COLOR_YELLOW" "$*"
}

log_error() {
    _lfa_log $LOG_LEVEL_ERROR "ERROR" "$COLOR_RED" "$*"
}

log_fatal() {
    _lfa_log $LOG_LEVEL_ERROR "FATAL" "$COLOR_RED$COLOR_BOLD" "$*"
    exit 1
}

log_success() {
    _lfa_log $LOG_LEVEL_INFO "SUCCESS" "$COLOR_GREEN$COLOR_BOLD" "$*"
}

log_section() {
    local message="$1"
    local line="========================================"
    if [[ "$LFA_LOG_JSON" != "true" ]]; then
        echo -e "\n${COLOR_BOLD}${COLOR_CYAN}${line}${COLOR_RESET}"
        echo -e "${COLOR_BOLD}${COLOR_CYAN} ${message}${COLOR_RESET}"
        echo -e "${COLOR_BOLD}${COLOR_CYAN}${line}${COLOR_RESET}\n"
    else
        _lfa_log $LOG_LEVEL_INFO "SECTION" "$COLOR_CYAN" "$message"
    fi
}

log_subsection() {
    local message="$1"
    if [[ "$LFA_LOG_JSON" != "true" ]]; then
        echo -e "${COLOR_BOLD}${COLOR_MAGENTA}--- ${message} ---${COLOR_RESET}"
    else
        _lfa_log $LOG_LEVEL_INFO "SUBSECTION" "$COLOR_MAGENTA" "$message"
    fi
}

log_kv() {
    local key="$1"
    local value="$2"
    if [[ "$LFA_LOG_JSON" != "true" ]]; then
        printf "  ${COLOR_BOLD}%-30s${COLOR_RESET} %s\n" "$key:" "$value"
    else
        _lfa_log $LOG_LEVEL_INFO "KV" "" "$key=$value"
    fi
}

log_progress() {
    local current="$1"
    local total="$2"
    local message="${3:-Processing}"
    local percent=$((current * 100 / total))
    local bar_length=30
    local filled=$((percent * bar_length / 100))
    local empty=$((bar_length - filled))

    if [[ "$LFA_LOG_JSON" != "true" ]] && [[ "${LFA_QUIET:-false}" != "true" ]]; then
        printf "\r${COLOR_CYAN}%s:${COLOR_RESET} [" "$message"
        printf "%${filled}s" | tr ' ' '='
        printf "%${empty}s" | tr ' ' '-'
        printf "] %3d%%" "$percent"
        if [[ $current -eq $total ]]; then
            echo
        fi
    fi
}

log_spinner_start() {
    local message="${1:-Working}"
    LFA_SPINNER_PID=$$
    LFA_SPINNER_MESSAGE="$message"
    if [[ "$LFA_LOG_JSON" != "true" ]] && [[ "${LFA_QUIET:-false}" != "true" ]] && [[ "${LFA_NO_COLOR:-false}" != "true" ]]; then
        (
            local spin='⠋⠙⠹⠸⠼⠴⠦⠧⠇⠏'
            local i=0
            tput civis 2>/dev/null || true
            while kill -0 "$LFA_SPINNER_PID" 2>/dev/null; do
                printf "\r${COLOR_CYAN}%s${COLOR_RESET} %s" "${spin:i++%${#spin}:1}" "$LFA_SPINNER_MESSAGE"
                sleep 0.1
            done
            tput cnorm 2>/dev/null || true
        ) &
        LFA_SPINNER_BG_PID=$!
    fi
}

log_spinner_stop() {
    if [[ -n "${LFA_SPINNER_BG_PID:-}" ]]; then
        kill "$LFA_SPINNER_BG_PID" 2>/dev/null || true
        wait "$LFA_SPINNER_BG_PID" 2>/dev/null || true
        unset LFA_SPINNER_BG_PID
        if [[ "$LFA_LOG_JSON" != "true" ]] && [[ "${LFA_QUIET:-false}" != "true" ]] && [[ "${LFA_NO_COLOR:-false}" != "true" ]]; then
            printf "\r%*s\r" $((${#LFA_SPINNER_MESSAGE} + 10)) ""
        fi
    fi
}

lfa_set_log_level() {
    local level="$1"
    case "${level,,}" in
        debug) LFA_LOG_LEVEL=$LOG_LEVEL_DEBUG ;;
        info) LFA_LOG_LEVEL=$LOG_LEVEL_INFO ;;
        warn) LFA_LOG_LEVEL=$LOG_LEVEL_WARN ;;
        error) LFA_LOG_LEVEL=$LOG_LEVEL_ERROR ;;
        quiet) LFA_LOG_LEVEL=$LOG_LEVEL_QUIET ;;
        *) return 1 ;;
    esac
}

lfa_get_log_level() {
    case $LFA_LOG_LEVEL in
        "$LOG_LEVEL_DEBUG") echo "debug" ;;
        "$LOG_LEVEL_INFO") echo "info" ;;
        "$LOG_LEVEL_WARN") echo "warn" ;;
        "$LOG_LEVEL_ERROR") echo "error" ;;
        "$LOG_LEVEL_QUIET") echo "quiet" ;;
        *) echo "info" ;;
    esac
}
