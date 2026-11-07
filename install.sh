#!/usr/bin/env bash
#
# install.sh - Installation script for linux-first-aid
# Part of linux-first-aid toolkit
#
# Usage: curl -sSL https://github.com/linux-first-aid/linux-first-aid/releases/latest/download/install.sh | sudo bash

set -euo pipefail

readonly REPO="linux-first-aid/linux-first-aid"
readonly INSTALL_DIR="/usr/local/bin"
readonly LIB_DIR="/usr/share/linux-first-aid"
readonly CONFIG_DIR="/etc/linux-first-aid"

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

log_info() { echo -e "${BLUE}[INFO]${NC} $*"; }
log_success() { echo -e "${GREEN}[SUCCESS]${NC} $*"; }
log_warn() { echo -e "${YELLOW}[WARN]${NC} $*"; }
log_error() { echo -e "${RED}[ERROR]${NC} $*"; }

check_root() {
    if [[ $EUID -ne 0 ]]; then
        log_error "This script must be run as root (use sudo)"
        exit 1
    fi
}

check_dependencies() {
    local deps=("bash" "curl" "tar" "coreutils" "procps" "iproute2" "systemd" "util-linux" "findutils" "grep" "sed" "gawk" "bc")
    local missing=()

    for dep in "${deps[@]}"; do
        if ! command -v "$dep" >/dev/null 2>&1; then
            missing+=("$dep")
        fi
    done

    if [[ ${#missing[@]} -gt 0 ]]; then
        log_warn "Missing dependencies: ${missing[*]}"
        log_info "Attempting to install..."

        if command -v apt-get >/dev/null; then
            apt-get update && apt-get install -y "${missing[@]}"
        elif command -v dnf >/dev/null; then
            dnf install -y "${missing[@]}"
        elif command -v yum >/dev/null; then
            yum install -y "${missing[@]}"
        elif command -v pacman >/dev/null; then
            pacman -S --noconfirm "${missing[@]}"
        elif command -v zypper >/dev/null; then
            zypper install -y "${missing[@]}"
        elif command -v apk >/dev/null; then
            apk add "${missing[@]}"
        else
            log_error "Cannot install dependencies automatically. Please install: ${missing[*]}"
            exit 1
        fi
    fi
}

get_latest_version() {
    curl -sSL "https://api.github.com/repos/${REPO}/releases/latest" | \
        grep '"tag_name":' | sed -E 's/.*"([^"]+)".*/\1/'
}

download_release() {
    local version="$1"
    local url="https://github.com/${REPO}/releases/download/${version}/linux-first-aid-${version}.tar.gz"
    local dest="/tmp/linux-first-aid-${version}.tar.gz"

    log_info "Downloading ${version}..."
    curl -sSL -o "$dest" "$url"
    echo "$dest"
}

install_package() {
    local archive="$1"

    log_info "Installing to ${INSTALL_DIR}..."
    mkdir -p "$INSTALL_DIR" "$LIB_DIR"/{core,modules,utils} "$CONFIG_DIR"

    tar -xzf "$archive" -C /tmp/
    local extract_dir
    extract_dir=$(find /tmp -maxdepth 1 -type d -name "linux-first-aid-*" | head -1)

    cp "$extract_dir/bin/first-aid" "$INSTALL_DIR/"
    chmod 755 "$INSTALL_DIR/first-aid"

    cp -r "$extract_dir/lib/"* "$LIB_DIR/"

    if [[ ! -f "$CONFIG_DIR/config.yaml" ]]; then
        cp "$extract_dir/config/config.yaml" "$CONFIG_DIR/"
        log_info "Installed default configuration to $CONFIG_DIR/config.yaml"
    else
        log_warn "Configuration already exists at $CONFIG_DIR/config.yaml (not overwritten)"
    fi

    rm -rf "$extract_dir" "$archive"
}

verify_installation() {
    if command -v first-aid >/dev/null; then
        local version
        version=$(first-aid --version)
        log_success "Installation verified: $version"
    else
        log_error "Installation failed: first-aid not found in PATH"
        exit 1
    fi
}

main() {
    echo "========================================"
    echo "  linux-first-aid Installer"
    echo "========================================"
    echo ""

    check_root
    check_dependencies

    local version
    version=$(get_latest_version)

    if [[ -z "$version" ]]; then
        log_error "Failed to fetch latest version"
        exit 1
    fi

    log_info "Latest version: $version"

    local archive
    archive=$(download_release "$version")

    install_package "$archive"
    verify_installation

    echo ""
    echo "========================================"
    log_success "Installation complete!"
    echo "========================================"
    echo ""
    echo "Quick start:"
    echo "  sudo first-aid diagnose --full"
    echo "  first-aid check disk"
    echo "  first-aid repair --dry-run"
    echo ""
    echo "Documentation: https://github.com/${REPO}"
    echo ""
}

main "$@"