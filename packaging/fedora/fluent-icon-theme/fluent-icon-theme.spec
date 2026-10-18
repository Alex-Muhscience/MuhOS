# MuhOS: Fluent icon theme (Windows 11 Fluent design style) by vinceliuice,
# used by the MuhOS shell for app icons. Not packaged in Fedora 44.

%global tag 2026-07-27

Name:           fluent-icon-theme
Version:        %(echo %{tag} | tr -d -)
Release:        1.muhos1%{?dist}
Summary:        Fluent design icon theme for Linux desktops
License:        GPL-3.0-only
URL:            https://github.com/vinceliuice/Fluent-icon-theme
Source0:        %{url}/archive/refs/tags/%{tag}.tar.gz#/Fluent-icon-theme-%{tag}.tar.gz

BuildArch:      noarch
BuildRequires:  bash
BuildRequires:  coreutils
BuildRequires:  fdupes
BuildRequires:  findutils
BuildRequires:  sed
Requires:       hicolor-icon-theme

%description
A colorful icon theme following Microsoft's Fluent design language, with
standard, dark and light variants (Fluent, Fluent-dark, Fluent-light).

%prep
%autosetup -n Fluent-icon-theme-%{tag}

%build

%install
mkdir -p %{buildroot}%{_datadir}/icons
# Standard colour only; the installer also creates the -dark and -light variants.
bash ./install.sh -d %{buildroot}%{_datadir}/icons standard
# The installer may build icon caches; they belong to the target system.
find %{buildroot}%{_datadir}/icons -name icon-theme.cache -delete
# The variants repeat many identical files; hardlink them.
%fdupes %{buildroot}%{_datadir}/icons

%check
for v in Fluent Fluent-dark Fluent-light; do
    test -f %{buildroot}%{_datadir}/icons/$v/index.theme
done

%transfiletriggerin -- %{_datadir}/icons/Fluent
gtk-update-icon-cache --force %{_datadir}/icons/Fluent &>/dev/null || :

%files
%license COPYING
%doc README.md AUTHORS
%{_datadir}/icons/Fluent
%{_datadir}/icons/Fluent-dark
%{_datadir}/icons/Fluent-light
# Shared icon sets the variants link into.
%{_datadir}/icons/.Fluent*-base

%changelog
* Mon Oct 19 2026 MuhOS contributors - 20260727-1.muhos1
- Initial package for MuhOS
