# MuhOS

MuhOS is a desktop shell for the Hyprland compositor on Fedora. It provides
the menu bar, control centre, launcher, dock, notifications, lock screen,
widgets and theming of a complete desktop, built on
[Quickshell](https://quickshell.org/) (Qt 6 / QML).

MuhOS is a Fedora-focused fork of
[Serpantinum](https://github.com/ilyamiro/serpantinum) by Illia Miroshnichenko.
It keeps Serpantinum's features, changes how the shell is packaged, installed
and integrated into the system, and is redesigning its interface.

> **Status: pre-release.** The package builds and passes its install tests,
> and a full GDM login session works in Fedora 44 virtual machines (a
> Workstation install and a headless benchmark image). It has not yet been
> validated on real hardware. The redesign is in progress: the menu bar and
> control centre are new; the dock, launcher, notifications and lock screen
> still use Serpantinum's design. Expect rough edges.

## Goals

In priority order:

1. Reliable installation and session integration on a clearly defined Fedora target.
2. Better UI/UX, polished animations and consistent theming.
3. Useful desktop customization and additional features.
4. Lower resource use and better responsiveness, backed by reproducible benchmarks.
5. Maintainable code and reliable updates.

## Supported platform

| | |
|---|---|
| Distribution | Fedora 44 Workstation, x86_64 |
| Compositor | Hyprland 0.56 |
| Login manager | GDM (kept; MuhOS adds a session entry) |

Other compositors supported upstream (Niri, Sway, Mango) are still in the tree
but untested in MuhOS.

## Design

MuhOS's look ("Hybrid") combines GNOME's structure with a macOS-style
translucent menu bar and glass panels, plus Serpantinum's wallpaper-driven
theming:

- **Menu bar.** Transparent over the wallpaper, laid out like GNOME: the apps
  button and workspace dots on the left, the clock in the middle, network,
  volume and battery on the right. Its text turns dark on light wallpapers
  and light on dark ones, per screen.
- **Clock island.** The clock shows the cover and a small visualizer while
  music plays; click it to expand it into a player. Without music it opens
  the calendar.
- **Control centre.** Click the status icons (or run
  `muhos ipc call muhos controlCentre`, e.g. from a key binding): toggles for
  Wi-Fi, Bluetooth, power mode, night light, dark style and do not disturb,
  volume and brightness sliders, screenshot, settings, lock and a power menu.
- **Icons and colour.** Adwaita icons throughout; the accent colour comes
  from the wallpaper.
- **Glass.** Panels are translucent and Hyprland blurs what is behind them.
  Set `"muhos": { "solidPanels": true }` in the settings for solid panels.

To go back to Serpantinum's bar, set `"bar": { "design": "classic" }`. Side
bars and an auto-hiding bar also use the classic bar for now.

## How MuhOS differs from Serpantinum

- **Installed as an RPM**, not by a `curl | bash` script. There is no
  telemetry and no network update check; updates come from the package.
- **Does not take over your system.** GDM stays your login manager, no
  services are enabled permanently, nothing is written to `/usr/local`, and
  your existing `~/.config/hypr`, kitty, cava and fastfetch configuration is
  never touched.
- **A session you choose at login.** Pick "MuhOS (Hyprland)" on the GDM
  login screen. The shell runs as a systemd user service tied to the session
  and is restarted if it crashes.
- **Configuration that survives updates.** Your Hyprland config lives in
  `~/.config/muhos/hypr/`: a small `hyprland.lua` that loads the packaged
  defaults, plus your own `user.lua`. Package updates improve the defaults
  without overwriting your changes.
- **Its own interface.** The menu bar and control centre are rebuilt (see
  [Design](#design)), and they open popups directly instead of starting a
  helper script and a second Quickshell process for every click.
- **Every bundled asset is cleared for redistribution.** Fonts, sounds and
  images each have a recorded source and license ([ASSETS.md](ASSETS.md));
  material without one was removed or replaced with openly licensed or
  original work.

The full list of changes is in
[CHANGES-FROM-UPSTREAM.md](CHANGES-FROM-UPSTREAM.md).

## Installing

MuhOS needs Quickshell 0.3.2, Matugen 4.2 and Hyprland 0.56, none of which
Fedora 44 ships at those versions. MuhOS builds Quickshell and Matugen itself;
Hyprland comes from a third-party COPR. Packages are not published yet: build
them from this repository as described in
[packaging/fedora/README.fedora.md](packaging/fedora/README.fedora.md), which
also explains exactly what the package installs and how to remove it.

After installing, log out and choose **MuhOS (Hyprland)** on the login screen.

## Building and testing

Everything runs in a Fedora 44 container, so the host stays untouched:

```sh
# RPM
podman run --rm -v "$PWD":/src:Z -w /src registry.fedoraproject.org/fedora:44 bash -c '
  dnf -y install git python3 rpm-build systemd-rpm-macros jq xdg-user-dirs &&
  git config --global --add safe.directory /src &&
  packaging/fedora/build-rpm out &&
  tests/fedora/test-package.sh out/muhos-*.noarch.rpm'

# Checks also run in CI
python3 -I tools/asset-inventory --strict   # every asset licensed and cleared
python3 -I tools/lint-baseline --check      # shellcheck/qmllint counts must not grow
```

`tests/vm/` builds Fedora 44 virtual machines with MuhOS installed, checks the
login session, and runs the benchmarks (5 runs per scenario, medians
reported); see [tests/vm/README.md](tests/vm/README.md). Results are in
[bench/results/](bench/results/). So far, measured in a VM with software
rendering:

| Change | Measured effect (Quickshell, idle) |
|---|---|
| New welcome screen (0.1.0-0.5) | CPU on the first-run screen 130% → 0.5% of a core |
| New bar (0.1.0-0.10) | Desktop CPU 0.52% → 0.07%, memory (PSS) 503 → 473 MiB |

The 0.1.0-0.10 bar also raised Hyprland's memory by about 12 MiB, probably
because of the blur; that has not been isolated yet.

## Repository layout

| Path | Contents |
|---|---|
| `src/quickshell/` | The shell (QML) |
| `src/quickshell/muhos/` | MuhOS's own interface: menu bar, control centre, design tokens |
| `src/scripts/`, `bin/` | Helper scripts and the shell's command-line tools |
| `src/assets/` | Fonts, sounds, shaders, themes, translations |
| `compositors/` | Default compositor configuration (Hyprland is the one MuhOS uses) |
| `packaging/fedora/` | RPM specs, session entry, systemd units |
| `tools/` | Asset inventory, lint baseline, upstream sync, asset build scripts |
| `tests/` | Package tests (`tests/fedora/`) and VM tests and benchmarks (`tests/vm/`) |
| `bench/results/` | Benchmark reports |

## Contributing

MuhOS tracks upstream Serpantinum releases and keeps its own changes small
and clearly labelled, so fixes can flow back upstream. Every commit is
labelled `[general]` (useful upstream), `[fedora]`, `[brand]` or `[fork]`;
[FORK.md](FORK.md) explains the labels, how upstream releases are merged, and
the rules for evidence (no performance claim without a benchmark).

## Credits

- [Serpantinum](https://github.com/ilyamiro/serpantinum) by Illia Miroshnichenko
  and its [contributors](https://github.com/ilyamiro/serpantinum/graphs/contributors):
  the shell MuhOS is built on.
- [Quickshell](https://quickshell.org/), the toolkit the shell runs on.
- The [Adwaita icon theme](https://gitlab.gnome.org/GNOME/adwaita-icon-theme)
  by the GNOME project, used from Fedora's package. The design takes cues
  from GNOME and macOS; MuhOS is not affiliated with either.
- Sounds by [Kenney](https://kenney.nl) (CC0) and Romain Raynal's
  [Open Sounds](https://romainraynal.gumroad.com/) (CC0).
- Fonts and icons from [Nerd Fonts](https://www.nerdfonts.com/) and the font
  projects listed in [ASSETS.md](ASSETS.md).

## License

Copyright (C) 2026 Illia Miroshnichenko (Serpantinum) and MuhOS contributors.

MuhOS is licensed under the GNU Affero General Public License version 3, or
(at your option) any later version; see [LICENSE.md](LICENSE.md) and
[NOTICE](NOTICE). Bundled fonts, sounds and images have their own licenses,
listed in [ASSETS.md](ASSETS.md).
