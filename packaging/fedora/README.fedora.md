# MuhOS on Fedora

Target: Fedora 44 and 45 Workstation, x86_64, Hyprland. GDM stays your login manager.

> Every bundled font, sound and image is listed with its source and license in
> `ASSETS.md`; the package build fails if any is not cleared for
> redistribution (`tools/asset-inventory --strict`).

## What the package installs

| Path | Purpose |
|---|---|
| `/usr/share/muhos/` | Shell (upstream `bin/`, `src/`), Hyprland defaults in `hypr/`, templates |
| `/usr/bin/muhos`, `/usr/bin/muhosd` | Shell command line and daemon |
| `/usr/bin/muhos-session` | Session entry point started by GDM |
| `/usr/libexec/muhos/` | Upstream command names used internally (`serpantinum`, `serpantinumd`) |
| `/usr/share/wayland-sessions/muhos.desktop` | "MuhOS (Hyprland)" entry on the GDM login screen |
| `/usr/lib/systemd/user/muhos-shell.service` | Runs the shell; restarts it if it crashes |
| `/usr/lib/systemd/user/muhos-session.target` | Bound to the graphical session; pulls in the shell |
| `/etc/pam.d/serpantinum` | Lock screen authentication (`system-auth`) |
| `/etc/dconf/profile/muhos`, `/etc/dconf/db/muhos.d/` | MuhOS-only GNOME/GTK settings: WhiteSur theme and icons, Inter, window buttons on the left |

It does **not** replace GDM, enable any service, write to `/usr/local`, or
touch `~/.config/hypr`, kitty, cava or fastfetch configuration.

## What happens at first login

`muhos-session` creates, only if missing:

- `~/.config/muhos/hypr/hyprland.lua`: a stub that loads the packaged defaults
  from `/usr/share/muhos/hypr`, then `user.lua` beside it if present. Put your
  changes in `user.lua`; package updates keep improving the defaults
  underneath.
- `~/.config/serpantinum/settings.json`: seeded from the upstream template,
  with the wallpaper folder set to `~/Pictures/Wallpapers` (created if needed)
  and automatic IP geolocation off: your public IP is not sent to a
  geolocation service in the background, and the weather stays offline until
  you set a location in Settings > General > Location (enter coordinates, or
  press the detect button for a one-time lookup). To look it up automatically
  instead, set `general.ipGeolocation` to `true` in that file.
- `~/Pictures/Wallpapers`: the MuhOS default wallpapers are copied in during
  this first setup, only if the folder has no images, so the first launch
  has one to apply.

It also sets two variables for this session only. `DCONF_PROFILE=muhos`
makes apps read and write their GNOME/GTK settings in
`~/.config/dconf/muhos`, on top of the MuhOS defaults, instead of your
GNOME settings. In light mode `GTK_THEME` gives libadwaita apps WhiteSur;
in dark mode it is left unset and apps use libadwaita's own dark style,
because WhiteSur's dark variant does not render GNOME 50 apps correctly.
When the session ends, both are cleared from
the systemd user manager, so a GNOME session started afterwards is
unaffected.

Then it starts Hyprland with that config. Hyprland's autostart imports the
session environment into systemd and starts `muhos-session.target`, which
starts `muhos-shell.service`.

## Dependencies outside Fedora

Upstream 2.2.13 was tested with Quickshell 0.3.2 and Matugen 4.2.0 (its Nix
pin). Fedora 44 and 45 have Quickshell 0.2.1 and Matugen 3.1.0, and no Hyprland.

| Package | Version | Source |
|---|---|---|
| Quickshell | 0.3.2 | MuhOS: `packaging/fedora/quickshell/quickshell.spec` (Fedora's spec, updated) |
| Matugen | 4.2.0 | MuhOS: `packaging/fedora/matugen/matugen.spec` (vendored crates) |
| WhiteSur GTK theme | 2026-09-10 | MuhOS: `packaging/fedora/whitesur/whitesur-gtk-theme.spec` (upstream's prebuilt Light/Dark, GTK parts only) |
| WhiteSur icon theme | 2026-09-10 | MuhOS: `packaging/fedora/whitesur/whitesur-icon-theme.spec` (Apple logo icons removed) |
| hyprland-guiutils | 0.2.2 | Same COPR as Hyprland: its dialogs (app not responding, permissions) |
| Hyprland | 0.56 or newer (tested with 0.57.2) | Third-party COPR [`lionheartp/Hyprland`](https://copr.fedorainfracloud.org/coprs/lionheartp/Hyprland/) (fork of solopasha/hyprland); fallback [`mineiro/hyprland`](https://copr.fedorainfracloud.org/coprs/mineiro/hyprland/) |

Until the MuhOS COPR exists, the Quickshell and Matugen source RPMs are
attached to GitHub releases. For testing:

```sh
sudo dnf copr enable lionheartp/Hyprland
sudo dnf install ./quickshell-*.rpm ./matugen-*.rpm ./whitesur-*.noarch.rpm ./muhos-*.noarch.rpm
```

## Building

```sh
podman run --rm -v "$PWD":/src:Z -w /src registry.fedoraproject.org/fedora:44 bash -c '
  dnf -y install rpm-build systemd-rpm-macros git python3 &&
  git config --global --add safe.directory /src &&
  packaging/fedora/build-rpm'
```

## Removing

```sh
sudo dnf remove muhos
rm -r ~/.config/muhos      # optional: your MuhOS Hyprland config
```

`~/.config/serpantinum` and `~/.local/state/serpantinum` hold shell settings
and state; remove them too for a clean slate.

## Troubleshooting

```sh
journalctl --user -u muhos-shell -b      # shell logs
systemctl --user status muhos-session.target
Hyprland --verify-config -c ~/.config/muhos/hypr/hyprland.lua
```
