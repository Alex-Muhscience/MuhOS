# First VM run: 2026-10-18

Not a benchmark; a first observation. One sample per state, one boot.

## Setup

| | |
|---|---|
| MuhOS | 0.1.0 (main `3b62968`): upstream Serpantinum v2.2.13 plus packaging, no shell changes affecting performance |
| Packages | quickshell 0.3.2-1.muhos1, matugen 4.2.0-1.muhos1, hyprland 0.56.2-3 (COPR lionheartp/Hyprland), gdm 50.3 |
| Guest | Fedora 44 Cloud Base, 4 vCPU (KVM, host CPU), 6 GiB RAM, virtio-vga 1920x1080, software rendering |
| Host | Intel TigerLake-H laptop, Fedora 44 |
| Method | `tests/vm/check <dir> 60`: CPU from /proc/PID/stat over 60 s, memory from /proc/PID/smaps_rollup |

## Results

All 11 session checks passed: GDM autologin into a Wayland session, Hyprland
running, `muhos-session.target` and `muhos-shell.service` active, no shell
restarts, per-user files created, `~/.config/hypr` untouched, daemon files in
`XDG_RUNTIME_DIR`.

| State | quickshell CPU (one core) | quickshell PSS | quickshell RSS | Hyprland PSS |
|---|---:|---:|---:|---:|
| First-launch welcome screen (animated, waiting for a click) | 129% | 668 MiB | 751 MiB | 195 MiB |
| Desktop, idle, after the welcome screen | 0.58% | 488 MiB | 560 MiB | 222 MiB |

## Observations

- The welcome screen keeps full-screen animations running while it waits for
  input; in software rendering that costs more than a full core.
- Idle desktop CPU is low; memory is the larger cost, consistent with
  upstream issues #212 and #378 and with widgets being created and cached
  for the whole session.
- 93 PipeWire "no global ... any more" warnings, all while the welcome screen
  played sounds; none during idle.
- No wallpaper is set: the wallpaper folder is empty because MuhOS does not
  ship wallpapers yet.
- Weather loaded, so the shell made a network request for it; upstream
  derives the location from the public IP by default.

## Next

Repeat with the benchmark protocol from the audit (5 runs, median and range,
fixed settings and wallpaper) before comparing any change against these
numbers.
