# Security Policy

## Supported Versions

We release security updates for the following versions:

| Version | Supported          |
| ------- | ------------------ |
| 1.0.x   | ✅ Yes             |
| < 1.0   | ❌ No              |

## Reporting a Vulnerability

We take security vulnerabilities seriously. If you discover a security issue,
please report it responsibly.

### How to Report

**Do not** create a public GitHub issue for security vulnerabilities.

Instead, please email us at **security@linux-first-aid.io** with:

1. Description of the vulnerability
2. Steps to reproduce
3. Potential impact
4. Any suggested fixes

We will acknowledge receipt within 48 hours and provide a timeline for a fix.

### What to Expect

1. **Acknowledgment** - Within 48 hours
2. **Assessment** - Within 7 days
3. **Fix Development** - Based on severity
4. **Release** - Security patch release
5. **Disclosure** - Coordinated disclosure after fix

## Security Considerations

### Root Privileges

linux-first-aid requires root privileges for most operations. This is by design
as it needs to:

- Read system configuration files
- Manage systemd services
- Access package manager databases
- Read system logs (journalctl)
- Modify network configuration
- Run hardware diagnostics (smartctl)

### Best Practices

When using linux-first-aid:

1. **Audit the code** - Review scripts before running in production
2. **Use --dry-run** - Test repairs before applying
3. **Limit scope** - Run specific checks instead of full diagnosis
4. **Monitor logs** - Check /var/log/first-aid-monitor.log
5. **Keep updated** - Update regularly for security fixes

### Configuration Security

- Configuration files are stored in `/etc/linux-first-aid/` (root only)
- User configs in `~/.config/linux-first-aid/` (user only)
- No secrets stored in configuration
- API keys not used (local-only tool)

### Network Security

- No listening services
- Outbound connections only for:
  - Package manager updates
  - DNS resolution tests
  - HTTP connectivity checks
  - Public IP detection (opt-in)
- No telemetry or data collection

### Supply Chain

- No external dependencies at runtime
- Build-time dependencies: bash, coreutils, standard Linux utilities
- Release artifacts signed with GPG
- Verify downloads with checksums

## Vulnerability Disclosure Timeline

| Severity | Target Fix Time |
| -------- | --------------- |
| Critical | 24 hours        |
| High     | 72 hours        |
| Medium   | 7 days          |
| Low      | 30 days         |

## Security Contacts

- **Security Team**: security@linux-first-aid.io
- **PGP Key**: Available at https://linux-first-aid.io/pgp-key.asc

## Hall of Fame

We recognize security researchers who responsibly disclose vulnerabilities:

*None yet - be the first!*

## Security Updates

Security updates are released as patch versions (e.g., 1.0.1) and announced via:

- GitHub Security Advisories
- Release notes
- Mailing list (security-announce@linux-first-aid.io)