# MuhOS: the WhiteSur icon theme (macOS-style app, folder and file icons), not
# packaged by Fedora. Installed with upstream's install.sh (default blue
# variant: WhiteSur, WhiteSur-light, WhiteSur-dark). The Apple logo icons
# (start-here, folder-apple) are removed: Apple's logo is a trademark.

%global tag 2026-09-10

Name:           whitesur-icon-theme
Version:        %(echo %{tag} | tr -d -)
Release:        1.muhos1%{?dist}
Summary:        macOS-like icon theme (WhiteSur)
License:        GPL-3.0-only
URL:            https://github.com/vinceliuice/WhiteSur-icon-theme
Source0:        %{url}/archive/refs/tags/%{tag}.tar.gz#/WhiteSur-icon-theme-%{tag}.tar.gz
BuildArch:      noarch

BuildRequires:  bash
BuildRequires:  coreutils
BuildRequires:  findutils
BuildRequires:  sed
Requires:       hicolor-icon-theme
Requires:       adwaita-icon-theme

%description
WhiteSur is a macOS Big Sur and later style icon theme for Linux desktops,
with light and dark panel variants.

%prep
%autosetup -n WhiteSur-icon-theme-%{tag}

%build
# Icons only; nothing to compile.

%install
install -d %{buildroot}%{_datadir}/icons
# install.sh refreshes icon caches when gtk-update-icon-cache is present;
# keep that out of the build root (caches are built in %%post instead).
PATH=$(echo "$PATH" | tr ':' '\n' | grep -v '^$' | paste -sd:) \
    bash ./install.sh -d %{buildroot}%{_datadir}/icons
find %{buildroot}%{_datadir}/icons \( -name 'start-here*' -o -name 'folder-apple*' \) -delete
find %{buildroot}%{_datadir}/icons -name icon-theme.cache -delete

%transfiletriggerin -- %{_datadir}/icons/WhiteSur
gtk-update-icon-cache --force %{_datadir}/icons/WhiteSur %{_datadir}/icons/WhiteSur-light %{_datadir}/icons/WhiteSur-dark &>/dev/null || :

%files
%license COPYING
%doc README.md AUTHORS
%{_datadir}/icons/WhiteSur/
%{_datadir}/icons/WhiteSur-light/
%{_datadir}/icons/WhiteSur-dark/

%changelog
* Tue Nov 24 2026 MuhOS contributors - 20260910-1.muhos1
- First MuhOS package: WhiteSur 2026-09-10 icons, Apple logo icons removed
