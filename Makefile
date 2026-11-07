# linux-first-aid Makefile
# Build, test, and install the linux-first-aid toolkit

.PHONY: help install uninstall test test-unit test-integration lint shellcheck format clean dev-setup release

# Variables
PREFIX ?= /usr/local
BINDIR = $(PREFIX)/bin
LIBDIR = $(PREFIX)/share/linux-first-aid
CONFIGDIR = /etc/linux-first-aid
VERSION = $(shell grep -m1 'readonly LFA_VERSION=' bin/first-aid | cut -d'"' -f2)

# Default target
help:
	@echo "linux-first-aid Makefile"
	@echo ""
	@echo "Targets:"
	@echo "  install          Install to system directories"
	@echo "  uninstall        Remove from system directories"
	@echo "  test             Run all tests"
	@echo "  test-unit        Run unit tests only"
	@echo "  test-integration Run integration tests (requires root)"
	@echo "  lint             Run shellcheck on all scripts"
	@echo "  format           Format scripts with shfmt"
	@echo "  clean            Remove build artifacts"
	@echo "  dev-setup        Set up development environment"
	@echo "  release          Create release package"
	@echo ""
	@echo "Variables:"
	@echo "  PREFIX=$(PREFIX)"
	@echo "  VERSION=$(VERSION)"

install:
	@echo "Installing linux-first-aid v$(VERSION) to $(PREFIX)..."
	install -d $(DESTDIR)$(BINDIR)
	install -d $(DESTDIR)$(LIBDIR)/core
	install -d $(DESTDIR)$(LIBDIR)/modules
	install -d $(DESTDIR)$(LIBDIR)/utils
	install -d $(DESTDIR)$(CONFIGDIR)
	install -m 755 bin/first-aid $(DESTDIR)$(BINDIR)/
	install -m 644 lib/core/*.sh $(DESTDIR)$(LIBDIR)/core/
	install -m 644 lib/modules/*.sh $(DESTDIR)$(LIBDIR)/modules/
	install -m 644 lib/utils/*.sh $(DESTDIR)$(LIBDIR)/utils/
	install -m 644 config/config.yaml $(DESTDIR)$(CONFIGDIR)/
	@echo "Installation complete!"

uninstall:
	@echo "Uninstalling linux-first-aid..."
	rm -f $(DESTDIR)$(BINDIR)/first-aid
	rm -rf $(DESTDIR)$(LIBDIR)
	rm -f $(DESTDIR)$(CONFIGDIR)/config.yaml
	@echo "Uninstallation complete!"

test: test-unit test-integration

test-unit:
	@echo "Running unit tests..."
	@for test in tests/unit/*.sh; do \
		if [[ -x "$$test" ]]; then \
			echo "Running $$test..."; \
			"$$test" || exit 1; \
		fi; \
	done
	@echo "Unit tests passed!"

test-integration:
	@echo "Running integration tests (requires root)..."
	@if [[ $$EUID -ne 0 ]]; then \
		echo "Integration tests require root. Run with sudo."; \
		exit 1; \
	fi
	@for test in tests/integration/*.sh; do \
		if [[ -x "$$test" ]]; then \
			echo "Running $$test..."; \
			"$$test" || exit 1; \
		fi; \
	done
	@echo "Integration tests passed!"

lint:
	@echo "Running shellcheck..."
	@shellcheck bin/first-aid
	@shellcheck lib/core/*.sh
	@shellcheck lib/modules/*.sh
	@shellcheck lib/utils/*.sh
	@shellcheck tests/unit/*.sh
	@shellcheck tests/integration/*.sh
	@echo "Linting passed!"

format:
	@echo "Formatting with shfmt..."
	@shfmt -i 4 -ci -w bin/first-aid lib/core/*.sh lib/modules/*.sh lib/utils/*.sh tests/unit/*.sh tests/integration/*.sh
	@echo "Formatting complete!"

clean:
	@echo "Cleaning..."
	@rm -rf build/
	@rm -f *.tar.gz
	@echo "Clean complete!"

dev-setup:
	@echo "Setting up development environment..."
	@command -v shellcheck >/dev/null || (echo "Installing shellcheck..." && apt-get update && apt-get install -y shellcheck)
	@command -v shfmt >/dev/null || (echo "Installing shfmt..." && go install mvdan.cc/sh/v3/cmd/shfmt@latest)
	@command -v bats >/dev/null || (echo "Installing bats..." && apt-get update && apt-get install -y bats)
	@chmod +x tests/unit/*.sh tests/integration/*.sh
	@echo "Development environment ready!"

release: clean
	@echo "Creating release package v$(VERSION)..."
	@mkdir -p build/linux-first-aid-$(VERSION)
	@cp -r bin lib config README.md LICENSE CONTRIBUTING.md Makefile build/linux-first-aid-$(VERSION)/
	@cd build && tar -czf linux-first-aid-$(VERSION).tar.gz linux-first-aid-$(VERSION)
	@echo "Release package: build/linux-first-aid-$(VERSION).tar.gz"

# Install to /usr/local for testing
install-local: PREFIX=/usr/local
install-local: install

# Quick test without integration tests
quick-test: lint test-unit
	@echo "Quick tests passed!"

# Check for common issues
check:
	@echo "Checking for common issues..."
	@grep -r "TODO\|FIXME\|XXX" --include="*.sh" bin/ lib/ tests/ || true
	@echo "Check complete!"