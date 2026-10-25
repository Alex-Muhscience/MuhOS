# MuhOS: Fedora package. Every bundled asset is listed with its license in ASSETS.md;
# %check fails the build if any is not cleared for redistribution.

%global upstream_version 2.2.13

Name:           muhos
Version:        0.1.0
Release:        0.13%{?dist}
Summary:        Desktop shell for Hyprland on Fedora, based on Serpantinum

# Code, MuhOS sounds and images: AGPL-3.0-or-later.
# Fonts: src/assets/fonts/LICENSES. Sounds: src/assets/sounds/SOURCES.md. Full list: ASSETS.md.
License:        AGPL-3.0-or-later AND OFL-1.1 AND MIT AND Apache-2.0 AND Bitstream-Vera AND CC-BY-3.0 AND CC-BY-4.0 AND CC0-1.0 AND Unlicense AND WTFPL
URL:            https://github.com/Alex-Muhscience/MuhOS
Source0:        %{name}-%{version}.tar.gz

BuildArch:      noarch
BuildRequires:  systemd-rpm-macros
BuildRequires:  python3
BuildRequires:  bash
BuildRequires:  desktop-file-utils

# Versions the upstream base release was tested with (its Nix pin).
# Fedora 44 ships older Quickshell/Matugen and no Hyprland; these come from COPR.
Requires:       quickshell >= 0.3.2
Requires:       matugen >= 4
Requires:       hyprland >= 0.56
# Hyprland's own dialogs (app-not-responding, permission prompts); Hyprland
# warns at login when it is missing. Same COPR as Hyprland.
Requires:       hyprland-guiutils

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
# Default interface font and app icon theme (see muhos-session, muhos-shell).
Requires:       adwaita-sans-fonts
Requires:       adwaita-icon-theme

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
# Asset licenses are installed once, via %%license.
rm -r "$share/src/assets/fonts/LICENSES" "$share/src/assets/sounds/LICENSES"
# Disables upstream's GitHub update check; updates come from the package.
printf 'rpm\n' > "$share/package-managed"
# The shell shows this as its version (upstream's is in NOTICE).
printf '%s\n' %{version} > "$share/version.txt"
# MuhOS names in the UI and command help; upstream's files stay untouched in
# the source, see tools/brand-languages.
python3 -I tools/brand-languages "$share/src/assets/languages"

# Hyprland defaults: upstream config with the MuhOS autostart.
install -d "$share/hypr"
cp -a compositors/hyprland/. "$share/hypr/"
install -m 0644 packaging/fedora/hypr/autostart.lua "$share/hypr/config/autostart.lua"
install -m 0644 packaging/fedora/hypr/muhos.lua "$share/hypr/config/muhos.lua"
echo 'require("config/muhos")' >> "$share/hypr/hyprland.lua"
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
install -Dm 0644 packaging/fedora/muhos-settings.desktop %{buildroot}%{_datadir}/applications/muhos-settings.desktop
install -Dm 0644 packaging/fedora/muhos-sound.desktop %{buildroot}%{_datadir}/applications/muhos-sound.desktop
install -Dm 0644 packaging/fedora/icons/muhos-sound.svg %{buildroot}%{_datadir}/icons/hicolor/scalable/apps/muhos-sound.svg
install -Dm 0644 packaging/fedora/muhos-shell.service %{buildroot}%{_userunitdir}/muhos-shell.service
install -Dm 0644 packaging/fedora/muhos-session.target %{buildroot}%{_userunitdir}/muhos-session.target
install -Dm 0644 packaging/fedora/pam-serpantinum %{buildroot}%{_sysconfdir}/pam.d/serpantinum

%check
bash -n %{buildroot}%{_bindir}/muhos-session
sh -n %{buildroot}%{_libexecdir}/%{name}/muhos-shell
for f in %{buildroot}%{_datadir}/%{name}/bin/*; do bash -n "$f"; done
desktop-file-validate %{buildroot}%{_datadir}/applications/muhos-settings.desktop
desktop-file-validate %{buildroot}%{_datadir}/applications/muhos-sound.desktop
python3 -I tools/asset-inventory --strict

%files
%license LICENSE.md NOTICE ASSETS.md src/assets/fonts/LICENSES
%license src/assets/sounds/SOURCES.md src/assets/sounds/LICENSES
%doc README.md FORK.md CHANGES-FROM-UPSTREAM.md packaging/fedora/README.fedora.md
%{_bindir}/muhos
%{_bindir}/muhosd
%{_bindir}/muhos-session
%{_libexecdir}/%{name}/
%{_datadir}/%{name}/
%{_datadir}/wayland-sessions/muhos.desktop
%{_datadir}/applications/muhos-settings.desktop
%{_datadir}/applications/muhos-sound.desktop
%{_datadir}/icons/hicolor/scalable/apps/muhos-sound.svg
%{_userunitdir}/muhos-shell.service
%{_userunitdir}/muhos-session.target
%config(noreplace) %{_sysconfdir}/pam.d/serpantinum

%changelog
* Sun Oct 25 2026 MuhOS contributors - 0.1.0-0.13
- Sound app entry and icon for the MuhOS sound window; close button on it
- Control centre: arrow beside the volume slider opens the sound window

* Sun Oct 25 2026 MuhOS contributors - 0.1.0-0.12
- macOS-style glass: frosted blur, glass dock with magnification, Spotlight-style
  launcher, notification banners and centre, on-screen indicator, lock screen
- Settings window: close button no longer covers the page's controls
- New users get the MuhOS dock settings at first login

* Mon Oct 19 2026 MuhOS contributors - 0.1.0-0.11
- Hybrid menu bar and control centre; Adwaita icons replace Fluent and Material Symbols
- Blur rules per MuhOS surface (bar island, control centre, welcome screen)

* Mon Oct 19 2026 MuhOS contributors - 0.1.0-0.10
- New MuhOS bar (clean glass, Material Symbols); bar.design "classic" restores the old one

* Mon Oct 19 2026 MuhOS contributors - 0.1.0-0.9
- Fluent app icons and Material Symbols Rounded for the redesign
- Hyprland blurs behind MuhOS panels (muhos-* layer rule)

* Mon Oct 19 2026 MuhOS contributors - 0.1.0-0.8
- MuhOS Settings app entry; settings window gets a close button

* Mon Oct 19 2026 MuhOS contributors - 0.1.0-0.7
- Require hyprland-guiutils (Hyprland warned at login without it)

* Mon Oct 19 2026 MuhOS contributors - 0.1.0-0.6
- Welcome screen: drop a signal that shadowed the window's own

* Mon Oct 19 2026 MuhOS contributors - 0.1.0-0.5
- New lightweight welcome screen
- Adwaita Sans interface font, Papirus icons, native text rendering

* Mon Oct 19 2026 MuhOS contributors - 0.1.0-0.4
- MuhOS branding: logo, names in all languages, attribution, version
- First run ends on the desktop; stored version follows the package

* Sun Oct 18 2026 MuhOS contributors - 0.1.0-0.3
- Looping sounds stop when playback fails instead of respawning pw-play
- Welcome screen pause now engages when the pointer is still

* Sun Oct 18 2026 MuhOS contributors - 0.1.0-0.2
- Default wallpapers; IP geolocation off for new users; no weather fetch for 0,0
- Welcome screen pauses its animations when the pointer is idle

* Sun Oct 18 2026 MuhOS contributors - 0.1.0-0.1
- First test build, based on Serpantinum 2.2.13
