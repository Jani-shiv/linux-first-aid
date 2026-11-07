Name:           linux-first-aid
Version:        1.0.0
Release:        1%{?dist}
Summary:        Linux troubleshooting toolkit

License:        MIT
URL:            https://github.com/linux-first-aid/linux-first-aid
Source0:        %{name}-%{version}.tar.gz

BuildArch:      noarch
BuildRequires:  bash >= 4.0, coreutils, procps, iproute, systemd, util-linux, findutils, grep, sed, gawk, bc, jq
Requires:       bash >= 4.0, coreutils, procps, iproute, systemd, util-linux, findutils, grep, sed, gawk, bc, jq
Recommends:     smartmontools, lsof, sysstat, iotop, htop, ncurses, openssl, curl

%description
linux-first-aid is a comprehensive Linux troubleshooting toolkit for system
administrators and DevOps engineers. It provides commands to diagnose, repair,
and monitor Linux systems including disk, memory, CPU, network, services,
packages, logs, security, kernel, and boot diagnostics.

%prep
%autosetup

%build
# No build step needed for bash scripts

%install
rm -rf %{buildroot}
mkdir -p %{buildroot}/%{_bindir}
mkdir -p %{buildroot}/%{_datadir}/%{name}/core
mkdir -p %{buildroot}/%{_datadir}/%{name}/modules
mkdir -p %{buildroot}/%{_datadir}/%{name}/utils
mkdir -p %{buildroot}/%{_sysconfdir}/%{name}

install -m 755 bin/first-aid %{buildroot}/%{_bindir}/
install -m 644 lib/core/*.sh %{buildroot}/%{_datadir}/%{name}/core/
install -m 644 lib/modules/*.sh %{buildroot}/%{_datadir}/%{name}/modules/
install -m 644 lib/utils/*.sh %{buildroot}/%{_datadir}/%{name}/utils/
install -m 644 config/config.yaml %{buildroot}/%{_sysconfdir}/%{name}/

%files
%{_bindir}/first-aid
%{_datadir}/%{name}/
%config(noreplace) %{_sysconfdir}/%{name}/config.yaml
%doc README.md LICENSE

%changelog
* Thu Nov 07 2024 linux-first-aid contributors <maintainers@linux-first-aid.io> - 1.0.0-1
- Initial release