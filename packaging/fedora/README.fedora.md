# MuhOS on Fedora

Target: Fedora 44 Workstation, x86_64, Hyprland. GDM stays your login manager.

> **Test builds only.** Bundled sounds and some images have unknown
> provenance (see `ASSETS.md`). Do not publish RPMs until
> `tools/asset-inventory --strict` passes.

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

It does **not** replace GDM, enable any service, write to `/usr/local`, or
touch `~/.config/hypr`, kitty, cava or fastfetch configuration.

## What happens at first login

`muhos-session` creates, only if missing:

- `~/.config/muhos/hypr/hyprland.lua`: a stub that loads the packaged defaults
  from `/usr/share/muhos/hypr`, then `user.lua` beside it if present. Put your
  changes in `user.lua`; package updates keep improving the defaults
  underneath.
- `~/.config/serpantinum/settings.json`: seeded from the upstream template,
  with the wallpaper folder set to `~/Pictures/Wallpapers` (created if needed).

Then it starts Hyprland with that config. Hyprland's autostart imports the
session environment into systemd and starts `muhos-session.target`, which
starts `muhos-shell.service`.

## Dependencies outside Fedora

Upstream 2.2.13 was tested with Quickshell 0.3.2 and Matugen 4.2.0 (its Nix
pin). Fedora 44 has Quickshell 0.2.1 and Matugen 3.1.0, and no Hyprland. The
MuhOS COPR is expected to provide Quickshell and Matugen; Hyprland comes from
a third-party COPR until decided otherwise.

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
