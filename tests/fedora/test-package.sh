#!/usr/bin/env bash
# SPDX-License-Identifier: AGPL-3.0-or-later
# MuhOS: install-level tests for the Fedora RPM. Run as root in a disposable
# fedora:44 container:
#
#   tests/fedora/test-package.sh /path/to/muhos-*.noarch.rpm
#
# Runtime dependencies (Quickshell >= 0.3.2, Hyprland) are not in Fedora 44,
# so the package is installed with --nodeps; this tests layout and per-user
# setup, not a running session.

set -euo pipefail

rpm_file="$1"
user=muhostest
fails=0

pass() { printf 'ok    %s\n' "$*"; }
fail() { printf 'FAIL  %s\n' "$*"; fails=$((fails + 1)); }
check() { local desc="$1"; shift; if "$@" >/dev/null 2>&1; then pass "$desc"; else fail "$desc"; fi; }
as_user() { runuser -u "$user" -- env HOME="/home/$user" XDG_CONFIG_HOME= "$@"; }
tree_hash() { (cd "$1" && find . -type f -print0 | sort -z | xargs -0 sha256sum | sha256sum); }

rpm -i --nodeps "$rpm_file"

# Layout
check "muhos command resolves" test -x "$(readlink -f /usr/bin/muhos)"
check "muhosd command resolves" test -x "$(readlink -f /usr/bin/muhosd)"
check "libexec upstream names resolve" test -x "$(readlink -f /usr/libexec/muhos/serpantinumd)"
check "muhos-shell is executable" test -x /usr/libexec/muhos/muhos-shell
check "package-managed marker" test -f /usr/share/muhos/package-managed
check "updater sees package-managed" grep -q 'package-managed' /usr/share/muhos/src/scripts/updater.py
check "MuhOS autostart replaces upstream" grep -q 'muhos-session.target' /usr/share/muhos/hypr/config/autostart.lua
check "upstream autostart does not enable easyeffects" bash -c '! grep -q easyeffects /usr/share/muhos/hypr/config/autostart.lua'
check "session entry for GDM" grep -q '^Exec=/usr/bin/muhos-session$' /usr/share/wayland-sessions/muhos.desktop
check "PAM service uses system-auth" grep -q 'include *system-auth' /etc/pam.d/serpantinum
check "no installer or telemetry shipped" bash -c '! rpm -ql muhos | grep -qE "/install/|telemetry"'
check "nothing installed under /usr/local" bash -c '! rpm -ql muhos | grep -q "^/usr/local"'
check "no non-script executables in datadir" bash -c '! find /usr/share/muhos/src -type f -perm /111 ! -name "*.sh" ! -name "*.py" | grep -q .'
check "font licenses shipped" test -f /usr/share/licenses/muhos/LICENSES/OFL-1.1.txt
check "sound sources shipped" test -f /usr/share/licenses/muhos/SOURCES.md
check "systemd units verify" systemd-analyze verify /usr/lib/systemd/user/muhos-shell.service /usr/lib/systemd/user/muhos-session.target

# Per-user setup must never overwrite existing files.
useradd -m "$user"
home="/home/$user"
as_user mkdir -p "$home/.config/hypr" "$home/.config/kitty"
as_user sh -c "echo 'user hyprland config' > '$home/.config/hypr/hyprland.conf'"
as_user sh -c "echo 'user kitty config' > '$home/.config/kitty/kitty.conf'"
before_other="$(tree_hash "$home/.config/hypr")$(tree_hash "$home/.config/kitty")"

as_user muhos-session --prepare 2>/dev/null
stub="$home/.config/muhos/hypr/hyprland.lua"
settings="$home/.config/serpantinum/settings.json"
check "stub created" test -f "$stub"
check "stub points at packaged defaults" grep -q '"/usr/share/muhos/hypr"' "$stub"
check "settings seeded with wallpaper dir" bash -c "jq -e '.wallpaperDir == \"$home/Pictures/Wallpapers\"' '$settings'"
check "wallpaper dir created" test -d "$home/Pictures/Wallpapers"
check "files owned by the user" bash -c "[ \"\$(stat -c %U '$stub')\" = '$user' ]"
after_other="$(tree_hash "$home/.config/hypr")$(tree_hash "$home/.config/kitty")"
check "existing ~/.config/hypr and kitty untouched" test "$before_other" = "$after_other"

first="$(tree_hash "$home/.config")"
as_user muhos-session --prepare 2>/dev/null
check "second run changes nothing" test "$first" = "$(tree_hash "$home/.config")"

as_user sh -c "echo '-- my edit' >> '$stub'"
as_user sh -c "echo '{\"mine\": true}' > '$settings'"
as_user muhos-session --prepare 2>/dev/null
check "user edits to stub preserved" grep -q -- '-- my edit' "$stub"
check "user settings preserved" grep -q '"mine"' "$settings"

# Removal leaves user data alone.
rpm -e muhos
check "package removed" bash -c '! rpm -q muhos'
check "datadir removed" test ! -e /usr/share/muhos
check "user files kept after removal" test -f "$stub" -a -f "$home/.config/hypr/hyprland.conf"

echo
if [ "$fails" -eq 0 ]; then echo "all checks passed"; else echo "$fails check(s) failed"; exit 1; fi
