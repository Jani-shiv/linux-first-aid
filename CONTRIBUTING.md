# Contributing to linux-first-aid

Thank you for your interest in contributing! This document provides guidelines for contributing to the project.

## Code of Conduct

By participating in this project, you agree to abide by our [Code of Conduct](CODE_OF_CONDUCT.md).

## How to Contribute

### Reporting Bugs

1. Check if the bug has already been reported in [Issues](https://github.com/linux-first-aid/linux-first-aid/issues)
2. If not, create a new issue with:
   - Clear title and description
   - Steps to reproduce
   - Expected vs actual behavior
   - System information (OS, version, etc.)
   - Relevant logs or output

### Suggesting Features

1. Check existing [Issues](https://github.com/linux-first-aid/linux-first-aid/issues) and [Discussions](https://github.com/linux-first-aid/linux-first-aid/discussions)
2. Create a feature request with:
   - Clear use case
   - Proposed solution
   - Alternatives considered
   - Any relevant examples

### Pull Requests

1. Fork the repository
2. Create a feature branch from `main`
3. Make your changes
4. Ensure all tests pass
5. Run the linter
6. Update documentation if needed
7. Submit a PR with a clear description

## Development Setup

```bash
# Clone your fork
git clone https://github.com/YOUR_USERNAME/linux-first-aid.git
cd linux-first-aid

# Install development dependencies
make dev-setup

# Run tests
make test

# Run linter
make lint
```

## Code Standards

### Shell Script Style

- Follow [Google Shell Style Guide](https://google.github.io/styleguide/shellguide.html)
- Use ShellCheck: `shellcheck script.sh`
- Indentation: 4 spaces (no tabs)
- Line length: Max 100 characters
- Function naming: `lfa_<module>_<function>`
- Variable naming: `LFA_<MODULE>_<VARIABLE>` for globals, lowercase for locals
- Always use `set -euo pipefail` at top of scripts
- Quote all variables: `"$VAR"` not `$VAR`

### File Organization

```
bin/                 # Executable entry points
lib/
  core/              # Core utilities (common, logger, config)
  modules/           # Command modules (diagnose, repair, etc.)
  utils/             # Utility functions
tests/
  unit/              # Unit tests
  integration/       # Integration tests
config/              # Default configuration
docs/                # Documentation
packaging/           # Distribution packaging
.github/workflows/   # CI/CD
```

### Function Template

```bash
#!/usr/bin/env bash
#
# module.sh - Brief description
# Part of linux-first-aid toolkit
#
# Copyright (c) 2024 linux-first-aid contributors
# Licensed under the MIT License

set -euo pipefail

source "${LFA_LIB_DIR}/core/common.sh"
source "${LFA_LIB_DIR}/core/logger.sh"

# Public function with usage
lfa_module_command() {
    local arg1="${1:-}"
    # Implementation
}

# Private helper function
_lfa_module_helper() {
    # Implementation
}
```

### Error Handling

- Use `log_error` for errors, `log_warn` for warnings, `log_info` for info
- Return appropriate exit codes (see README)
- Use `lfa_confirm` for destructive operations
- Support `--dry-run` for repair/fix commands

### Testing

- Write unit tests for all public functions
- Test edge cases and error conditions
- Mock external commands where possible
- Integration tests should be safe to run on test systems

## Adding New Checks/Fixes

### New Check

1. Add function to `lib/modules/check.sh`
2. Follow naming: `lfa_check_<name>`
3. Accept standard parameters: threshold, format, output
4. Return appropriate exit codes
5. Add to `lfa_check` dispatch
6. Update documentation

### New Fix

1. Add function to `lib/modules/fix.sh`
2. Follow naming: `lfa_fix_<name>`
3. Support `--dry-run` and `--force`
4. Create backups when modifying files
5. Add to `lfa_fix` dispatch
6. Update documentation

### New Diagnosis Category

1. Add function to `lib/modules/diagnose.sh`
2. Follow naming: `lfa_diagnose_<category>`
3. Accept timeout parameter
4. Return 0 on success, 1 on failure
5. Add to `lfa_run_diagnose_category` dispatch
6. Update config defaults

## Documentation

- Update README.md for user-facing changes
- Update command help text (`lfa_<command>_usage`)
- Add examples for new features
- Keep CHANGELOG.md updated

## Release Process

1. Update version in `bin/first-aid`
2. Update CHANGELOG.md
3. Create release tag: `git tag v1.0.0`
4. Push tag: `git push origin v1.0.0`
5. GitHub Actions builds and publishes release

## Getting Help

- Join discussions on [GitHub Discussions](https://github.com/linux-first-aid/linux-first-aid/discussions)
- Ask questions in issues
- Check existing documentation

## Recognition

Contributors will be recognized in:
- CONTRIBUTORS.md
- Release notes
- Project README

Thank you for contributing to linux-first-aid!