# linux-first-aid

[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)
[![ShellCheck](https://img.shields.io/badge/ShellCheck-passing-brightgreen.svg)](https://www.shellcheck.net/)
[![Build Status](https://github.com/linux-first-aid/linux-first-aid/workflows/CI/badge.svg)](https://github.com/linux-first-aid/linux-first-aid/actions)

A comprehensive Linux troubleshooting toolkit for system administrators and DevOps engineers. Diagnose, repair, and monitor Linux systems with a single, powerful CLI tool.

## Features

- **Comprehensive Diagnosis** - Check disk, memory, CPU, network, services, packages, logs, security, kernel, and boot
- **Automated Repair** - Fix broken packages, reset network, clear journals, trim SSDs, fix permissions, and more
- **Continuous Monitoring** - Run health checks at intervals with configurable alerting
- **Log Analysis** - Analyze system logs, performance, startup, crashes, and security events
- **Health Reports** - Generate detailed reports in text, JSON, HTML, or Markdown
- **Multi-Distro Support** - Works on Debian/Ubuntu, RHEL/Fedora, Arch, openSUSE, Alpine, and more
- **Zero Dependencies** - Pure Bash with only standard Linux utilities
- **Configurable** - YAML-based configuration with user and system-level overrides

## Quick Start

```bash
# Install from release
curl -sSL https://github.com/linux-first-aid/linux-first-aid/releases/latest/download/install.sh | sudo bash

# Or install manually
sudo cp bin/first-aid /usr/local/bin/
sudo cp -r lib /usr/share/linux-first-aid/
sudo cp config/config.yaml /etc/linux-first-aid/

# Run full system diagnosis
sudo first-aid diagnose --full

# Quick health check
first-aid check disk --threshold 80,90

# Auto-repair common issues (dry run first)
first-aid repair --dry-run
first-aid repair

# Continuous monitoring
first-aid monitor --interval 30 --alert-threshold warn

# Generate HTML report
first-aid report --format html --output health-report.html
```

## Installation

### Supported Distributions

| Distribution | Package Manager | Status |
|--------------|-----------------|--------|
| Debian/Ubuntu | apt | ✅ Tested |
| RHEL/CentOS/Fedora | dnf/yum | ✅ Tested |
| Arch Linux | pacman | ✅ Tested |
| openSUSE | zypper | ✅ Tested |
| Alpine Linux | apk | ✅ Tested |
| Others | - | 🟡 Should work |

### Requirements

- Bash 4.0+
- Standard Linux utilities (coreutils, procps, iproute2, systemd, etc.)
- Root privileges for most operations

### From Source

```bash
git clone https://github.com/linux-first-aid/linux-first-aid.git
cd linux-first-aid
sudo make install
```

### Package Managers

```bash
# Arch Linux (AUR)
yay -S linux-first-aid

# NixOS
nix-env -iA nixpkgs.linux-first-aid

# Homebrew (Linux)
brew install linux-first-aid
```

## Usage

### Commands Overview

```bash
first-aid [global options] <command> [command options]

Global Options:
  -h, --help          Show help
  -v, --version       Show version
  -c, --config FILE   Use custom config file
  -q, --quiet         Suppress non-error output
  -d, --debug         Enable debug output
  --no-color          Disable colored output
```

### Diagnose

```bash
# Full system diagnosis
first-aid diagnose --full

# Quick diagnosis
first-aid diagnose --quick

# Specific categories
first-aid diagnose --category disk,memory,cpu

# List available categories
first-aid diagnose --list-categories

# Output to file
first-aid diagnose --output report.json --format json
```

### Check

```bash
# Check disk usage
first-aid check disk --threshold 80,90

# Check memory
first-aid check memory --threshold 80,90

# Check CPU load
first-aid check cpu --threshold 2.0,4.0

# Check network
first-aid check network

# Check services
first-aid check services

# Check logs
first-aid check logs --since "1 hour ago" --level error
```

### Repair

```bash
# Dry run (show what would be done)
first-aid repair --dry-run

# Repair specific categories
first-aid repair --category packages,network

# Force repair without confirmation
first-aid repair --force

# Skip backups
first-aid repair --no-backup
```

### Fix (Individual Fixes)

```bash
# Clean package cache
first-aid fix clean-package-cache --max-age 7

# Fix broken packages
first-aid fix fix-broken-packages

# Reset network
first-aid fix reset-network

# Clear journals
first-aid fix clear-journals --max-size 1G

# TRIM SSDs
first-aid fix trim-ssd

# Fix permissions
first-aid fix fix-permissions --paths /etc,/var

# Rebuild initramfs
first-aid fix rebuild-initramfs

# Update GRUB
first-aid fix update-grub

# Restart failed services
first-aid fix restart-failed-services
```

### Monitor

```bash
# Run once
first-aid monitor --once

# Continuous monitoring
first-aid monitor --interval 60 --alert-threshold warn

# Daemon mode
first-aid monitor --daemon --pid-file /var/run/first-aid.pid

# Monitor specific categories
first-aid monitor --categories disk,memory,cpu
```

### Analyze

```bash
# Analyze logs
first-aid analyze logs --since "1 hour ago" --level error --top 100

# Analyze performance
first-aid analyze performance --format json

# Analyze startup
first-aid analyze startup

# Analyze crashes
first-aid analyze crashes

# Analyze security events
first-aid analyze security --since "7 days ago"
```

### Report

```bash
# Text report (default)
first-aid report

# HTML report
first-aid report --format html --output report.html

# JSON report
first-aid report --format json --output report.json

# Markdown report
first-aid report --format markdown --output report.md

# Custom sections
first-aid report --include-sections disk,memory,cpu
```

### Config

```bash
# Get value
first-aid config get check.disk.threshold_warn

# Set value
first-aid config set check.disk.threshold_warn 85

# List all
first-aid config list

# List with prefix
first-aid config list check.disk

# Save to file
first-aid config save ~/.config/linux-first-aid/config.yaml

# Reset to defaults
first-aid config reset
```

## Configuration

Configuration is loaded from (in order of precedence):
1. `/etc/linux-first-aid/config.yaml` (system-wide)
2. `~/.config/linux-first-aid/config.yaml` (user)

```yaml
general:
  check_interval: 300
  alert_threshold: "warn"
  auto_repair: false

diagnose:
  categories: "system,disk,memory,cpu,network,services,packages,logs,security,kernel,boot"
  timeout: 300

check:
  disk:
    threshold_warn: 80
    threshold_crit: 90
  memory:
    threshold_warn: 80
    threshold_crit: 90
  cpu:
    load_warn: 2.0
    load_crit: 4.0

repair:
  dry_run: false
  backup: true
```

## Exit Codes

| Code | Meaning |
|------|---------|
| 0 | Success |
| 1 | General error |
| 2 | Invalid usage |
| 3 | Check failed (issues found) |
| 4 | Repair failed |
| 5 | Permission denied |
| 6 | Configuration error |

## Examples

### Daily Health Check (cron)

```bash
# /etc/cron.daily/first-aid-health
#!/bin/bash
/usr/local/bin/first-aid diagnose --quick --output /var/log/first-aid/daily-$(date +%F).json --format json
```

### Nagios/Icinga Plugin

```bash
#!/bin/bash
# check_first_aid_disk
first-aid check disk --threshold 80,90 --format json | jq -r '.results[] | select(.status=="critical") | .name'
```

### Systemd Service for Monitoring

```ini
# /etc/systemd/system/first-aid-monitor.service
[Unit]
Description=Linux First Aid Monitor
After=network.target

[Service]
Type=simple
ExecStart=/usr/local/bin/first-aid monitor --daemon --interval 60 --alert-threshold warn
Restart=on-failure
User=root

[Install]
WantedBy=multi-user.target
```

## Contributing

1. Fork the repository
2. Create a feature branch (`git checkout -b feature/amazing-feature`)
3. Make your changes
4. Run tests (`make test`)
5. Run linter (`make lint`)
6. Commit your changes (`git commit -m 'Add amazing feature'`)
7. Push to the branch (`git push origin feature/amazing-feature`)
8. Open a Pull Request

### Development Setup

```bash
git clone https://github.com/linux-first-aid/linux-first-aid.git
cd linux-first-aid
make dev-setup
```

### Code Style

- ShellCheck clean (no warnings)
- 4-space indentation
- Functions prefixed with `lfa_`
- Variables prefixed with `LFA_`
- Comprehensive error handling
- Documented with comments

## Testing

```bash
# Run all tests
make test

# Run unit tests only
make test-unit

# Run integration tests (requires root)
sudo make test-integration

# Run specific test
./tests/unit/test_common.sh
```

## Roadmap

- [ ] Plugin system for custom checks/fixes
- [ ] Web dashboard for monitoring
- [ ] Prometheus metrics exporter
- [ ] Ansible collection
- [ ] Kubernetes operator
- [ ] Windows Subsystem for Linux (WSL) support
- [ ] More package manager support (nix, guix, etc.)

## License

MIT License - see [LICENSE](LICENSE) for details.

## Acknowledgments

- Inspired by various system administration tools
- Built with Bash best practices from [Google Shell Style Guide](https://google.github.io/styleguide/shellguide.html)
- Tested with [ShellCheck](https://www.shellcheck.net/)
- CI/CD with GitHub Actions

## Support

- **Documentation**: [docs.linux-first-aid.io](https://docs.linux-first-aid.io)
- **Issues**: [GitHub Issues](https://github.com/linux-first-aid/linux-first-aid/issues)
- **Discussions**: [GitHub Discussions](https://github.com/linux-first-aid/linux-first-aid/discussions)
- **Security**: [Security Policy](SECURITY.md)

---

**Made with ❤️ for Linux system administrators everywhere**