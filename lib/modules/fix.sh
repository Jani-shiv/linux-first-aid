#!/usr/bin/env bash
#
# fix.sh - Specific fix commands module
# Part of linux-first-aid toolkit
#
# Copyright (c) 2024 linux-first-aid contributors
# Licensed under the MIT License

set -euo pipefail

source "${LFA_LIB_DIR}/core/common.sh"
source "${LFA_LIB_DIR}/core/logger.sh"
source "${LFA_LIB_DIR}/core/config.sh"

lfa_fix_usage() {
    cat <<'EOF'
Usage: first-aid fix <fix-name> [OPTIONS]

Apply specific fixes for common issues.

FIXES:
    clean-package-cache     Clean package manager cache
    fix-broken-packages     Fix broken package installations
    reset-network           Reset network configuration
    clear-journals          Clear systemd journals
    trim-ssd                TRIM SSD filesystems
    fix-permissions         Fix common permission issues
    rebuild-initramfs       Rebuild initramfs
    update-grub             Update GRUB configuration
    restart-failed-services Restart failed systemd services

OPTIONS:
    --dry-run              Show what would be done without making changes
    --force                Force fix without confirmation
    --max-age DAYS         Maximum age for cache cleaning (default: 30)
    --max-size SIZE        Maximum journal size (default: 500M)
    --paths PATHS          Paths for permission fixes (default: /etc,/usr,/var)
    -h, --help             Show this help

EXAMPLES:
    first-aid fix clean-package-cache --max-age 7
    first-aid fix clear-journals --max-size 1G
    first-aid fix trim-ssd
    first-aid fix fix-permissions --paths /etc,/var
    first-aid fix restart-failed-services
EOF
}

lfa_fix() {
    local fix_name="${1:-}"
    shift || true

    if [[ "$fix_name" == "-h" || "$fix_name" == "--help" || -z "$fix_name" ]]; then
        lfa_fix_usage
        [[ -n "$fix_name" ]] && return 0
        return 2
    fi

    local dry_run=false
    local force=false
    local max_age=30
    local max_size="500M"
    local paths="/etc,/usr,/var"

    while [[ $# -gt 0 ]]; do
        case $1 in
            --dry-run)
                dry_run=true
                shift
                ;;
            --force)
                force=true
                shift
                ;;
            --max-age)
                max_age="$2"
                shift 2
                ;;
            --max-size)
                max_size="$2"
                shift 2
                ;;
            --paths)
                paths="$2"
                shift 2
                ;;
            -h | --help)
                lfa_fix_usage
                return 0
                ;;
            *)
                log_error "Unknown option: $1"
                lfa_fix_usage
                return 2
                ;;
        esac
    done

    export LFA_DRY_RUN="$dry_run"
    export LFA_FORCE="$force"

    case "$fix_name" in
        clean-package-cache)
            lfa_fix_clean_package_cache "$max_age"
            ;;
        fix-broken-packages)
            lfa_fix_broken_packages
            ;;
        reset-network)
            lfa_fix_reset_network
            ;;
        clear-journals)
            lfa_fix_clear_journals "$max_size"
            ;;
        trim-ssd)
            lfa_fix_trim_ssd
            ;;
        fix-permissions)
            lfa_fix_permissions "$paths"
            ;;
        rebuild-initramfs)
            lfa_fix_rebuild_initramfs
            ;;
        update-grub)
            lfa_fix_update_grub
            ;;
        restart-failed-services)
            lfa_fix_restart_failed_services
            ;;
        *)
            log_error "Unknown fix: $fix_name"
            lfa_fix_usage
            return 2
            ;;
    esac
}

lfa_fix_clean_package_cache() {
    local max_age="$1"
    local pm
    pm=$(lfa_get_package_manager)

    log_section "Cleaning Package Cache"
    log_kv "Package Manager" "$pm"
    log_kv "Max Age" "${max_age} days"

    if [[ "${LFA_DRY_RUN:-false}" == "true" ]]; then
        log_info "[DRY RUN] Would clean package cache for $pm"
        return 0
    fi

    case "$pm" in
        apt)
            log_info "Cleaning apt cache older than $max_age days..."
            find /var/cache/apt/archives -name "*.deb" -mtime +"$max_age" -delete 2>/dev/null || true
            apt autoclean
            apt clean
            ;;
        dnf | yum)
            log_info "Cleaning dnf/yum cache..."
            $pm clean all
            ;;
        pacman)
            log_info "Cleaning pacman cache..."
            pacman -Sc --noconfirm
            # Remove uninstalled package cache older than max_age
            find /var/cache/pacman/pkg -name "*.pkg.tar*" -mtime +"$max_age" -delete 2>/dev/null || true
            ;;
        zypper)
            log_info "Cleaning zypper cache..."
            zypper clean -a
            ;;
        apk)
            log_info "Cleaning apk cache..."
            apk cache clean
            ;;
        *)
            log_warn "Cache cleaning not supported for: $pm"
            return 1
            ;;
    esac

    log_success "Package cache cleaned"
}

lfa_fix_broken_packages() {
    local pm
    pm=$(lfa_get_package_manager)

    log_section "Fixing Broken Packages"
    log_kv "Package Manager" "$pm"

    if [[ "${LFA_DRY_RUN:-false}" == "true" ]]; then
        log_info "[DRY RUN] Would fix broken packages for $pm"
        return 0
    fi

    case "$pm" in
        apt)
            log_info "Fixing broken installs..."
            apt --fix-broken install -y
            log_info "Configuring pending packages..."
            dpkg --configure -a
            ;;
        dnf | yum)
            log_info "Checking for broken packages..."
            $pm check || true
            log_info "Reinstalling broken packages..."
            mapfile -t changed_packages < <(rpm -Va 2>/dev/null | awk '$1 ~ /^..5/ {print $NF}' | sort -u)
            if [[ ${#changed_packages[@]} -gt 0 ]]; then
                lfa_exec_safe "$pm" reinstall -y "${changed_packages[@]}"
            fi
            ;;
        pacman)
            log_info "Checking package database..."
            pacman -Dk
            log_info "Refreshing package databases..."
            pacman -Sy
            ;;
        zypper)
            log_info "Verifying packages..."
            zypper verify
            ;;
        apk)
            log_info "Fixing packages..."
            apk fix
            ;;
        *)
            log_warn "Broken package fix not supported for: $pm"
            return 1
            ;;
    esac

    log_success "Broken packages fixed"
}

lfa_fix_reset_network() {
    log_section "Resetting Network"

    if [[ "${LFA_DRY_RUN:-false}" == "true" ]]; then
        log_info "[DRY RUN] Would restart network services"
        return 0
    fi

    log_info "Restarting NetworkManager..."
    systemctl restart NetworkManager 2>/dev/null || true

    log_info "Restarting systemd-networkd..."
    systemctl restart systemd-networkd 2>/dev/null || true

    log_info "Restarting systemd-resolved..."
    systemctl restart systemd-resolved 2>/dev/null || true

    log_info "Flushing DNS cache..."
    resolvectl flush-caches 2>/dev/null || true

    log_info "Renewing DHCP leases..."
    for iface in /sys/class/net/*; do
        iface=$(basename "$iface")
        if [[ "$iface" != "lo" ]]; then
            dhclient -r "$iface" 2>/dev/null || true
            dhclient "$iface" 2>/dev/null || true
        fi
    done

    log_success "Network reset complete"
}

lfa_fix_clear_journals() {
    local max_size="$1"

    log_section "Clearing Journals"
    log_kv "Max Size" "$max_size"

    if [[ "${LFA_DRY_RUN:-false}" == "true" ]]; then
        log_info "[DRY RUN] Would run: journalctl --vacuum-size=$max_size"
        log_info "[DRY RUN] Would run: journalctl --vacuum-time=30d"
        return 0
    fi

    log_info "Vacuuming journal to $max_size..."
    journalctl --vacuum-size="$max_size" 2>/dev/null || true

    log_info "Vacuuming journal older than 30 days..."
    journalctl --vacuum-time=30d 2>/dev/null || true

    log_success "Journals cleared"
}

lfa_fix_trim_ssd() {
    local enabled
    enabled=$(lfa_get_config "fix.trim_ssd.enabled" true)

    if [[ "$enabled" != "true" ]]; then
        log_warn "SSD TRIM is disabled in configuration"
        return 0
    fi

    log_section "TRIM SSD Filesystems"

    if [[ "${LFA_DRY_RUN:-false}" == "true" ]]; then
        log_info "[DRY RUN] Would run: fstrim -av"
        return 0
    fi

    if lfa_check_command fstrim; then
        log_info "Running fstrim on all mounted filesystems..."
        fstrim -av 2>/dev/null | while read -r line; do
            log_info "  $line"
        done
        log_success "SSD TRIM complete"
    else
        log_warn "fstrim not available"
        return 1
    fi
}

lfa_fix_permissions() {
    local paths="$1"

    log_section "Fixing Permissions"
    log_kv "Paths" "$paths"

    if [[ "${LFA_DRY_RUN:-false}" == "true" ]]; then
        log_info "[DRY RUN] Would fix permissions on: $paths"
        return 0
    fi

    IFS=',' read -ra path_array <<<"$paths"
    for path in "${path_array[@]}"; do
        log_info "Checking: $path"
        local pm
        pm=$(lfa_get_package_manager)

        case "$pm" in
            rpm | dnf | yum)
                rpm --setperms "$path" 2>/dev/null || true
                ;;
            apt)
                dpkg --verify "$path" 2>/dev/null | grep -E '^.{8}M' | head -20 | while read -r line; do
                    log_warn "Permission mismatch: $line"
                done
                ;;
            pacman)
                pacman -Qkk "$path" 2>/dev/null | grep -v "0 altered files" | head -20 | while read -r line; do
                    log_warn "Permission mismatch: $line"
                done
                ;;
        esac
    done

    log_info "Fixing common critical permissions..."
    chmod 644 /etc/passwd /etc/group 2>/dev/null || true
    chmod 600 /etc/shadow /etc/gshadow 2>/dev/null || true
    chmod 600 /etc/ssh/ssh_host_*_key 2>/dev/null || true
    chmod 700 /root 2>/dev/null || true
    chmod 1777 /tmp /var/tmp 2>/dev/null || true
    chmod 755 /etc /usr /var 2>/dev/null || true

    log_success "Permissions fixed"
}

lfa_fix_rebuild_initramfs() {
    log_section "Rebuilding Initramfs"

    local pm
    pm=$(lfa_get_package_manager)

    if [[ "${LFA_DRY_RUN:-false}" == "true" ]]; then
        log_info "[DRY RUN] Would rebuild initramfs for $pm"
        return 0
    fi

    case "$pm" in
        apt)
            update-initramfs -u -k all 2>/dev/null || true
            ;;
        dnf | yum)
            dracut --force 2>/dev/null || true
            ;;
        pacman)
            mkinitcpio -P 2>/dev/null || true
            ;;
        zypper)
            dracut --force 2>/dev/null || true
            ;;
    esac

    log_success "Initramfs rebuilt"
}

lfa_fix_update_grub() {
    log_section "Updating GRUB"

    local pm
    pm=$(lfa_get_package_manager)

    if [[ "${LFA_DRY_RUN:-false}" == "true" ]]; then
        log_info "[DRY RUN] Would update GRUB for $pm"
        return 0
    fi

    case "$pm" in
        apt)
            update-grub 2>/dev/null || grub2-mkconfig -o /boot/grub/grub.cfg 2>/dev/null || true
            ;;
        dnf | yum)
            grub2-mkconfig -o /boot/grub2/grub.cfg 2>/dev/null || true
            ;;
        pacman)
            grub-mkconfig -o /boot/grub/grub.cfg 2>/dev/null || true
            ;;
        zypper)
            grub2-mkconfig -o /boot/grub2/grub.cfg 2>/dev/null || true
            ;;
    esac

    log_success "GRUB updated"
}

lfa_fix_restart_failed_services() {
    log_section "Restarting Failed Services"

    if ! lfa_is_systemd; then
        log_warn "Not using systemd"
        return 0
    fi

    if [[ "${LFA_DRY_RUN:-false}" == "true" ]]; then
        log_info "[DRY RUN] Would restart failed services"
        local failed
        failed=$(lfa_get_failed_services)
        if [[ -n "$failed" ]]; then
            echo "$failed" | while read -r svc; do
                log_info "[DRY RUN] Would restart: $svc"
            done
        fi
        return 0
    fi

    local failed
    failed=$(lfa_get_failed_services)
    if [[ -n "$failed" ]]; then
        echo "$failed" | while read -r svc; do
            log_info "Restarting: $svc"
            systemctl restart "$svc" 2>/dev/null || log_warn "Failed to restart: $svc"
        done
    else
        log_success "No failed services"
    fi

    systemctl daemon-reload 2>/dev/null || true
    log_success "Failed services restarted"
}
