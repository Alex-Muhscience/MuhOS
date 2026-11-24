# Equaliser engines: EasyEffects vs PipeWire filter-chain

Date: 2026-11-24. Script: `tests/vm/eq-bench`. Question: what does the music
equaliser's engine cost, and would PipeWire's own filter-chain be cheaper?

## Setup

- Fedora 44 Workstation VM (`tests/vm/workstation`, 4 vCPUs, 8 GiB, KVM),
  logged in to a MuhOS 0.1.0-0.14 session, real PipeWire sink
  ("Built-in Audio Analog Stereo", QEMU HDA). PipeWire 1.6.2.
- Same 10-band EQ for both engines: 32, 63, 125, 250, 500 Hz, 1, 2, 4, 8,
  16 kHz with gains +4 +3 +1 -1 -2 0 +2 +3 +4 +2 dB, Q 1.0.
- Same audio: a 60 s, 48 kHz stereo test signal (partials 55 Hz-12 kHz plus
  light noise), played with `pw-play` into the engine's sink.
- **easyeffects**: EasyEffects 8.2.8 from Fedora, started and configured by
  MuhOS's own `src/quickshell/media/equalizer.sh` (`set_band`, `apply`), as
  the music window does. Measured process: `easyeffects`.
- **filterchain**: a separate `pipewire` process loading
  `libpipewire-module-filter-chain` with ten built-in `bq_peaking` filters.
  Measured process: that `pipewire` process.
- Memory: PSS from `/proc/<pid>/smaps_rollup`, sampled every 2 s during
  playback, median per run. CPU: utime+stime of the process over the
  playback, as a share of one core. 3 runs each.

Checked before trusting the numbers: the filter-chain's sink fed the
hardware sink (`pw-link -l`: pw-play → muhos_eq_bench → muhos_eq_bench.output
→ alsa_output…analog-stereo), and its node reported all ten Freq/Gain values
as configured.

## Results

| Engine | Run | PSS (MiB) | CPU (% of one core) |
|---|---|---:|---:|
| EasyEffects | 1 | 121.1 | 2.15 |
| EasyEffects | 2 | 119.8 | 2.25 |
| EasyEffects | 3 | 119.5 | 2.25 |
| filter-chain | 1 | 4.7 | 1.22 |
| filter-chain | 2 | 4.7 | 1.25 |
| filter-chain | 3 | 4.7 | 1.30 |

Medians: EasyEffects 119.8 MiB, 2.25 %; filter-chain 4.7 MiB, 1.25 %.

## Findings

- For the same 10-band EQ on the same audio, the filter-chain process used
  about 115 MiB less memory (4.7 vs 119.8 MiB PSS, about 1/25) and about
  1 percentage point less CPU (1.25 vs 2.25 % of one core).
- EasyEffects is not installed by default with MuhOS (it is only
  Recommended); installing it in this VM pulled in 78 packages. PipeWire is
  already on every Fedora system.

## Limits

- One VM, software audio device, one EQ setting; no real hardware.
- The filter-chain ran as its own process; loaded into the session's main
  PipeWire instead, its cost would show up there rather than separately.
- Only the EQ was compared. The music window's other options (balance, mono,
  channel swap, and "dynamics", which uses a compressor and limiter) were
  not part of the run.
