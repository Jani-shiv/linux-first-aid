# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Added
- Initial project structure
- Core library modules (common, logger, config, utils)
- Diagnosis modules (system, disk, memory, CPU, network, services, packages, logs, security, kernel, boot)
- Repair modules (packages, network, logs, permissions, services, kernel, boot)
- Individual fix commands (clean-package-cache, fix-broken-packages, reset-network, clear-journals, trim-ssd, fix-permissions, rebuild-initramfs, update-grub, restart-failed-services)
- Monitoring daemon with configurable intervals and alerts
- Log analysis (logs, performance, startup, crashes, security)
- Report generation (text, JSON, HTML, Markdown)
- Configuration management (get, set, list, reset, save, show, path)
- Multi-distro package manager support (apt, dnf/yum, pacman, zypper, apk)
- Comprehensive test suite (unit and integration)
- CI/CD pipeline with GitHub Actions
- Docker support
- Packaging for Debian, RPM, and Arch

### Changed
- N/A

### Deprecated
- N/A

### Removed
- N/A

### Fixed
- N/A

### Security
- N/A

## [1.0.0] - 2026-11-07

### Added
- Initial release of linux-first-aid
- Complete Linux troubleshooting toolkit
- All core functionality as listed above

---

## Release Notes Template

### [X.Y.Z] - YYYY-MM-DD

#### Added
- New features

#### Changed
- Changes in existing functionality

#### Deprecated
- Soon-to-be removed features

#### Removed
- Removed features

#### Fixed
- Bug fixes

#### Security
- Security fixes