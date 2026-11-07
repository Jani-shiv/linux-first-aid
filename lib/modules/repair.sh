#!/usr/bin/env bash
#
# repair.sh - Automatic repair module
# Part of linux-first-aid toolkit
#
# Copyright (c) 2024 linux-first-aid contributors
# Licensed under the MIT License

set -euo pipefail

source "${LFA_LIB_DIR}/core/common.sh"
source "${LFA_LIB_DIR}/core/logger.sh"
source "${LFA_LIB_DIR}/core/config.sh"

lfa_repair_usage() {
    cat <<'EOF'
Usage: first-aid repair [OPTIONS]

Attempt automatic repairs for common issues.

OPTIONS:
    --dry-run           Show what would be done without making changes
    --category CATEGORY Repair only specific category (comma-separated)
    --list-categories   List available repair categories
    --force             Force repairs without confirmation
    --backup            Create backups before repairs (default: true)
    --no-backup         Skip backup creation
    -h, --help          Show this help

CATEGORIES:
    packages       Fix broken packages, clean cache
    network        Reset network configuration
    logs           Clear old journals and logs
    permissions    Fix common permission issues
    services       Restart failed services
    kernel         Reload kernel modules
    boot           Regenerate boot configuration

EXAMPLES:
    first-aid repair --dry-run
    first-aid repair --category packages,network
    first-aid repair --force --no-backup
EOF
}

lfa_repair() {
    local dry_run=false
    local categories=()
    local force=false
    local backup=true
    local list_categories=false

    while [[ $# -gt 0 ]]; do
        case $1 in
            --dry-run)
                dry_run=true
                shift
                ;;
            --category)
                IFS=',' read -ra categories <<< "$2"
                shift 2
                ;;
            --list-categories)
                list_categories=true
                shift
                ;;
            --force)
                force=true
                shift
                ;;
            --backup)
                backup=true
                shift
                ;;
            --no-backup)
                backup=false
                shift
                ;;
            -h|--help)
                lfa_repair_usage
                return 0
                ;;
            *)
                log_error "Unknown option: $1"
                lfa_repair_usage
                return 2
                ;;
        esac
    done

    if [[ "$list_categories" == "true" ]]; then
        lfa_list_repair_categories
        return 0
    fi

    if [[ ${#categories[@]} -eq 0 ]]; then
        local config_categories
        config_categories=$(lfa_get_config "repair.categories")
        IFS=',' read -ra categories <<< "$config_categories"
    fi

    export LFA_DRY_RUN="$dry_run"
    export LFA_FORCE="$force"
    export LFA_BACKUP="$backup"

    log_section "System Repair Starting"
    log_info "Mode: $([ "$dry_run" == "true" ] && echo "DRY RUN" || echo "LIVE")"
    log_info "Categories: ${categories[*]}"
    log_info "Force: $force"
    log_info "Backup: $backup"

    if [[ "$dry_run" == "true" ]]; then
        log_warn "DRY RUN MODE - No changes will be made"
    fi

    if ! lfa_confirm "Proceed with repairs?" "n"; then
        log_info "Repair cancelled by user"
        return 0
    fi

    local failed_categories=()

    for category in "${categories[@]}"; do
        log_subsection "Repairing: $category"
        if ! lfa_run_repair_category "$category"; then
            failed_categories+=("$category")
            log_error "Failed to repair: $category"
        else
            log_success "Repaired: $category"
        fi
    done

    log_section "Repair Complete"
    if [[ ${#failed_categories[@]} -gt 0 ]]; then
        log_error "Failed categories: ${failed_categories[*]}"
        return 4
    else
        log_success "All repairs completed successfully"
        return 0
    fi
}

lfa_list_repair_categories() {
    echo "Available repair categories:"
    echo "  packages       - Fix broken packages, clean cache"
    echo "  network        - Reset network configuration"
    echo "  logs           - Clear old journals and logs"
    echo "  permissions    - Fix common permission issues"
    echo "  services       - Restart failed services"
    echo "  kernel         - Reload kernel modules"
    echo "  boot           - Regenerate boot configuration"
}

lfa_run_repair_category() {
    local category="$1"

    case "$category" in
        packages)
            lfa_repair_packages
            ;;
        network)
            lfa_repair_network
            ;;
        logs)
            lfa_repair_logs
            ;;
        permissions)
            lfa_repair_permissions
            ;;
        services)
            lfa_repair_services
            ;;
        kernel)
            lfa_repair_kernel
            ;;
        boot)
            lfa_repair_boot
            ;;
        *)
            log_error "Unknown repair category: $category"
            return 1
            ;;
    esac
}

lfa_repair_packages() {
    local pm
    pm=$(lfa_get_package_manager)

    case "$pm" in
        apt)
            lfa_repair_apt
            ;;
        dnf|yum)
            lfa_repair_dnf
            ;;
        pacman)
            lfa_repair_pacman
            ;;
        zypper)
            lfa_repair_zypper
            ;;
        apk)
            lfa_repair_apk
            ;;
        *)
            log_warn "Package repair not supported for: $pm"
            return 1
            ;;
    esac
}

lfa_repair_apt() {
    if [[ "${LFA_DRY_RUN:-false}" == "true" ]]; then
        log_info "[DRY RUN] Would run: apt --fix-broken install"
        log_info "[DRY RUN] Would run: apt autoremove -y"
        log_info "[DRY RUN] Would run: apt autoclean"
        log_info "[DRY RUN] Would run: dpkg --configure -a"
        return 0
    fi

    log_info "Fixing broken packages..."
    lfa_exec_safe apt --fix-broken install -y

    log_info "Configuring pending packages..."
    lfa_exec_safe dpkg --configure -a

    log_info "Removing unused packages..."
    lfa_exec_safe apt autoremove -y

    log_info "Cleaning package cache..."
    lfa_exec_safe apt autoclean

    log_info "Updating package lists..."
    lfa_exec_safe apt update
}

lfa_repair_dnf() {
    if [[ "${LFA_DRY_RUN:-false}" == "true" ]]; then
        log_info "[DRY RUN] Would run: dnf check"
        log_info "[DRY RUN] Would run: dnf autoremove -y"
        log_info "[DRY RUN] Would run: dnf clean all"
        return 0
    fi

    log_info "Checking for problems..."
    lfa_exec_safe dnf check || true

    log_info "Removing unused packages..."
    lfa_exec_safe dnf autoremove -y

    log_info "Cleaning package cache..."
    lfa_exec_safe dnf clean all
}

lfa_repair_pacman() {
    if [[ "${LFA_DRY_RUN:-false}" == "true" ]]; then
        log_info "[DRY RUN] Would run: pacman -Dk"
        log_info "[DRY RUN] Would run: pacman -Rns \$(pacman -Qdtq)"
        log_info "[DRY RUN] Would run: pacman -Sc"
        return 0
    fi

    log_info "Checking package database..."
    lfa_exec_safe pacman -Dk

    log_info "Removing orphan packages..."
    local orphans
    orphans=$(pacman -Qdtq 2>/dev/null || true)
    if [[ -n "$orphans" ]]; then
        lfa_exec_safe pacman -Rns $orphans
    fi

    log_info "Cleaning package cache..."
    lfa_exec_safe pacman -Sc --noconfirm
}

lfa_repair_zypper() {
    if [[ "${LFA_DRY_RUN:-false}" == "true" ]]; then
        log_info "[DRY RUN] Would run: zypper verify"
        log_info "[DRY RUN] Would run: zypper clean -a"
        return 0
    fi

    log_info "Verifying packages..."
    lfa_exec_safe zypper verify

    log_info "Cleaning package cache..."
    lfa_exec_safe zypper clean -a
}

lfa_repair_apk() {
    if [[ "${LFA_DRY_RUN:-false}" == "true" ]]; then
        log_info "[DRY RUN] Would run: apk fix"
        log_info "[DRY RUN] Would run: apk cache clean"
        return 0
    fi

    log_info "Fixing packages..."
    lfa_exec_safe apk fix

    log_info "Cleaning package cache..."
    lfa_exec_safe apk cache clean
}

lfa_repair_network() {
    log_subsection "Network Repair"

    if [[ "${LFA_DRY_RUN:-false}" == "true" ]]; then
        log_info "[DRY RUN] Would restart NetworkManager"
        log_info "[DRY RUN] Would restart systemd-networkd"
        log_info "[DRY RUN] Would restart systemd-resolved"
        log_info "[DRY RUN] Would flush DNS cache"
        return 0
    fi

    if lfa_check_command systemctl; then
        log_info "Restarting NetworkManager..."
        systemctl restart NetworkManager 2>/dev/null || true

        log_info "Restarting systemd-networkd..."
        systemctl restart systemd-networkd 2>/dev/null || true

        log_info "Restarting systemd-resolved..."
        systemctl restart systemd-resolved 2>/dev/null || true
    fi

    log_info "Flushing DNS cache..."
    if lfa_check_command resolvectl; then
        resolvectl flush-caches 2>/dev/null || true
    fi

    log_info "Renewing DHCP leases..."
    for iface in /sys/class/net/*; do
        iface=$(basename "$iface")
        if [[ "$iface" != "lo" ]]; then
            dhclient -r "$iface" 2>/dev/null || true
            dhclient "$iface" 2>/dev/null || true
        fi
    done
}

lfa_repair_logs() {
    log_subsection "Log Cleanup"

    local max_size
    max_size=$(lfa_get_config "fix.clear_journals.max_size" "500M")

    if [[ "${LFA_DRY_RUN:-false}" == "true" ]]; then
        log_info "[DRY RUN] Would run: journalctl --vacuum-size=$max_size"
        log_info "[DRY RUN] Would run: journalctl --vacuum-time=30d"
        return 0
    fi

    log_info "Vacuuming journal to ${max_size}..."
    journalctl --vacuum-size="$max_size" 2>/dev/null || true

    log_info "Vacuuming journal older than 30 days..."
    journalctl --vacuum-time=30d 2>/dev/null || true

    log_info "Cleaning old rotated logs..."
    find /var/log -name "*.gz" -o -name "*.[0-9]" -o -name "*.old" | head -20 | while read -r file; do
        if [[ -f "$file" ]]; then
            log_info "Removing: $file"
            rm -f "$file"
        fi
    done
}

lfa_repair_permissions() {
    log_subsection "Permission Repair"

    local paths
    paths=$(lfa_get_config "fix.fix_permissions.paths" "/etc,/usr,/var")

    if [[ "${LFA_DRY_RUN:-false}" == "true" ]]; then
        log_info "[DRY RUN] Would fix permissions on: $paths"
        log_info "[DRY RUN] Would run: rpm --setperms (if RPM-based)"
        log_info "[DRY RUN] Would run: dpkg --verify (if DEB-based)"
        return 0
    fi

    IFS=',' read -ra path_array <<< "$paths"
    for path in "${path_array[@]}"; do
        log_info "Checking permissions on: $path"
        local pm
        pm=$(lfa_get_package_manager)

        case "$pm" in
            apt)
                dpkg --verify 2>/dev/null | grep -E '^.{8}c' | head -20 | while read -r line; do
                    log_warn "Permission mismatch: $line"
                done
                ;;
            rpm|dnf|yum)
                rpm --verify 2>/dev/null | grep -E '^.{8}M' | head -20 | while read -r line; do
                    log_warn "Permission mismatch: $line"
                done
                rpm --setperms 2>/dev/null || true
                ;;
            pacman)
                pacman -Qkk 2>/dev/null | grep -v "0 altered files" | head -20 | while read -r line; do
                    log_warn "Permission mismatch: $line"
                done
                ;;
        esac
    done

    log_info "Fixing common permission issues..."
    chmod 644 /etc/passwd /etc/group /etc/shadow /etc/gshadow 2>/dev/null || true
    chmod 600 /etc/ssh/ssh_host_*_key 2>/dev/null || true
    chmod 700 /root 2>/dev/null || true
    chmod 1777 /tmp /var/tmp 2>/dev/null || true
}

lfa_repair_services() {
    log_subsection "Service Repair"

    if ! lfa_is_systemd; then
        log_warn "Not using systemd, skipping service repair"
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

    log_info "Restarting failed services..."
    local failed
    failed=$(lfa_get_failed_services)
    if [[ -n "$failed" ]]; then
        echo "$failed" | while read -r svc; do
            log_info "Restarting: $svc"
            systemctl restart "$svc" 2>/dev/null || log_warn "Failed to restart: $svc"
        done
    else
        log_success "No failed services to restart"
    fi

    log_info "Reloading systemd..."
    systemctl daemon-reload 2>/dev/null || true
}

lfa_repair_kernel() {
    log_subsection "Kernel Module Repair"

    if [[ "${LFA_DRY_RUN:-false}" == "true" ]]; then
        log_info "[DRY RUN] Would run: depmod -a"
        log_info "[DRY RUN] Would reload failed modules"
        return 0
    fi

    log_info "Updating module dependencies..."
    depmod -a 2>/dev/null || true

    log_info "Checking for failed modules..."
    dmesg -T --level=err 2>/dev/null | grep -i "module\|driver" | head -10 | while read -r line; do
        log_warn "Kernel issue: $line"
    done
}

lfa_repair_boot() {
    log_subsection "Boot Configuration Repair"

    local pm
    pm=$(lfa_get_package_manager)

    if [[ "${LFA_DRY_RUN:-false}" == "true" ]]; then
        log_info "[DRY RUN] Would regenerate GRUB config"
        log_info "[DRY RUN] Would regenerate initramfs"
        return 0
    fi

    case "$pm" in
        apt)
            log_info "Updating GRUB..."
            update-grub 2>/dev/null || grub2-mkconfig -o /boot/grub/grub.cfg 2>/dev/null || true

            log_info "Updating initramfs..."
            update-initramfs -u -k all 2>/dev/null || true
            ;;
        dnf|yum)
            log_info "Regenerating GRUB..."
            grub2-mkconfig -o /boot/grub2/grub.cfg 2>/dev/null || true

            log_info "Regenerating initramfs..."
            dracut --force 2>/dev/null || true
            ;;
        pacman)
            log_info "Regenerating GRUB..."
            grub-mkconfig -o /boot/grub/grub.cfg 2>/dev/null || true

            log_info "Regenerating initramfs..."
            mkinitcpio -P 2>/dev/null || true
            ;;
    esac
}