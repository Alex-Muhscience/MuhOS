# MuhOS: Fedora package. Test builds only until `tools/asset-inventory --strict`
# passes; see ASSETS.md for the assets that still block a public release.

%global upstream_version 2.2.13

Name:           muhos
Version:        0.1.0
Release:        0.1%{?dist}
Summary:        Desktop shell for Hyprland on Fedora, based on Serpantinum

# Code: AGPL-3.0-or-later (upstream Serpantinum and MuhOS changes).
# Bundled fonts: see ASSETS.md and src/assets/fonts/LICENSES.
# Bundled sounds and images: provenance still unknown (ASSETS.md); test builds only.
License:        AGPL-3.0-or-later AND OFL-1.1 AND MIT AND Apache-2.0 AND Bitstream-Vera AND CC-BY-3.0 AND WTFPL
# TODO: MuhOS project URL once hosting is decided.
URL:            https://github.com/ilyamiro/serpantinum
Source0:        %{name}-%{version}.tar.gz

BuildArch:      noarch
BuildRequires:  systemd-rpm-macros
BuildRequires:  python3
BuildRequires:  bash

# Versions the upstream base release was tested with (its Nix pin).
# Fedora 44 ships older Quickshell/Matugen and no Hyprland; these come from COPR.
Requires:       quickshell >= 0.3.2
Requires:       matugen >= 4
Requires:       hyprland >= 0.56

Requires:       qt6-qtdeclarative
Requires:       qt6-qtwayland
Requires:       qt6-qtmultimedia
Requires:       qt6-qt5compat
Requires:       qt6-qtwebsockets
Requires:       qt6-qtsvg
Requires:       python3
Requires:       python3-websockets
Requires:       python3-jeepney
Requires:       bash
Requires:       bc
Requires:       coreutils
Requires:       file
Requires:       findutils
Requires:       fontconfig
Requires:       jq
Requires:       procps-ng
Requires:       psmisc
Requires:       socat
Requires:       util-linux
Requires:       inotify-tools
Requires:       xdg-user-dirs
Requires:       wl-clipboard
Requires:       cliphist
Requires:       grim
Requires:       slurp
Requires:       playerctl
Requires:       brightnessctl
Requires:       pamixer
Requires:       pipewire-utils
Requires:       wireplumber
Requires:       /usr/bin/notify-send
Requires:       NetworkManager
Requires:       bluez
Requires:       lm_sensors
Requires:       ImageMagick
Requires:       (ffmpeg-free or ffmpeg)
Requires:       systemd

# Features degrade without these; the split is provisional until VM testing.
Recommends:     xdg-desktop-portal-hyprland
Recommends:     xdg-desktop-portal-gtk
Recommends:     adwaita-icon-theme
Recommends:     adw-gtk3-theme
Recommends:     qt6ct
Recommends:     kitty
Recommends:     nautilus
Recommends:     pavucontrol
Recommends:     power-profiles-daemon
Recommends:     wf-recorder
Recommends:     zbar
Recommends:     ddcutil
Recommends:     acpi
Recommends:     iw
Recommends:     fd-find
Recommends:     ripgrep
Recommends:     wmctrl
Recommends:     cava
Recommends:     fastfetch
Recommends:     easyeffects
Recommends:     calf
Recommends:     lsp-plugins-lv2
# Not in Fedora; optional features (screenshot editor, recorder, night light).
Suggests:       satty
Suggests:       gpu-screen-recorder
Suggests:       wl-gammarelay-rs

%description
MuhOS is a Fedora-focused desktop shell for the Hyprland compositor, built on
Quickshell. It is a modified version of Serpantinum %{upstream_version} by
Illia Miroshnichenko. MuhOS adds a login session entry, runs the shell as a
systemd user service, and never modifies existing compositor configuration.

%prep
%autosetup

%build
# Nothing to build: QML, shell and Python are installed as-is.

%install
share=%{buildroot}%{_datadir}/%{name}
install -d "$share"
cp -a bin src version.txt "$share/"
# Executable bits: only on scripts, whatever the tarball says.
find "$share" -type f -exec chmod 0644 {} +
find "$share/src" -type f \( -name '*.sh' -o -name '*.py' \) -exec chmod 0755 {} +
chmod 0755 "$share"/bin/*
# Disables upstream's GitHub update check; updates come from the package.
printf 'rpm\n' > "$share/package-managed"

# Hyprland defaults: upstream config with the MuhOS autostart.
install -d "$share/hypr"
cp -a compositors/hyprland/. "$share/hypr/"
install -m 0644 packaging/fedora/hypr/autostart.lua "$share/hypr/config/autostart.lua"
install -Dm 0644 packaging/fedora/hypr/hyprland.lua "$share/skel/hyprland.lua"
install -Dm 0644 config/serpantinum/settings.json "$share/defaults/settings.json"

# Upstream command names, used internally by the shell and keybinds.
install -d %{buildroot}%{_libexecdir}/%{name}
ln -s ../../share/%{name}/bin/serpantinum  %{buildroot}%{_libexecdir}/%{name}/serpantinum
ln -s ../../share/%{name}/bin/serpantinumd %{buildroot}%{_libexecdir}/%{name}/serpantinumd
install -m 0755 packaging/fedora/muhos-shell %{buildroot}%{_libexecdir}/%{name}/muhos-shell

# Public MuhOS commands.
install -d %{buildroot}%{_bindir}
ln -s ../share/%{name}/bin/serpantinum  %{buildroot}%{_bindir}/muhos
ln -s ../share/%{name}/bin/serpantinumd %{buildroot}%{_bindir}/muhosd
install -m 0755 packaging/fedora/muhos-session %{buildroot}%{_bindir}/muhos-session

install -Dm 0644 packaging/fedora/muhos.desktop %{buildroot}%{_datadir}/wayland-sessions/muhos.desktop
install -Dm 0644 packaging/fedora/muhos-shell.service %{buildroot}%{_userunitdir}/muhos-shell.service
install -Dm 0644 packaging/fedora/muhos-session.target %{buildroot}%{_userunitdir}/muhos-session.target
install -Dm 0644 packaging/fedora/pam-serpantinum %{buildroot}%{_sysconfdir}/pam.d/serpantinum

%check
bash -n %{buildroot}%{_bindir}/muhos-session
sh -n %{buildroot}%{_libexecdir}/%{name}/muhos-shell
for f in %{buildroot}%{_datadir}/%{name}/bin/*; do bash -n "$f"; done
python3 -I tools/asset-inventory --check

%files
%license LICENSE.md NOTICE ASSETS.md src/assets/fonts/LICENSES
%doc README.md FORK.md CHANGES-FROM-UPSTREAM.md packaging/fedora/README.fedora.md
%{_bindir}/muhos
%{_bindir}/muhosd
%{_bindir}/muhos-session
%{_libexecdir}/%{name}/
%{_datadir}/%{name}/
%{_datadir}/wayland-sessions/muhos.desktop
%{_userunitdir}/muhos-shell.service
%{_userunitdir}/muhos-session.target
%config(noreplace) %{_sysconfdir}/pam.d/serpantinum

%changelog
* Sun Oct 18 2026 MuhOS contributors - 0.1.0-0.1
- First test build, based on Serpantinum 2.2.13
