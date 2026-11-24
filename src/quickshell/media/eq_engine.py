#!/usr/bin/env python3
# SPDX-License-Identifier: AGPL-3.0-or-later
# MuhOS: the music equaliser's engine, on PipeWire's own filter-chain
# (replaces EasyEffects; see bench/results/2026-11-24-vm-eq-easyeffects-vs-filterchain.md).
#
#   eq_engine.py get | restore | apply | enable true|false
#                | set_band N GAIN | preset NAME | set_balance B
#                | set_mono true|false | set_swap true|false
#                | set_dynamics off|balanced|night | reset_audio
#                | test | stop_test
#
# The engine is a small separate PipeWire process (one filter-chain sink)
# that WirePlumber links in as a "smart filter": everything played to the
# default output passes through it, and it follows the default output when
# that changes. It runs only while the equaliser is on and does something
# (a flat EQ with no other effect stops it), and as a systemd user unit
# bound to the graphical session, so it ends with the session.
# Settings change live (pw-cli set-param); only turning dynamics on or off
# restarts it. The state is kept in ~/.local/state/serpantinum/music.

import json
import math
import os
import shutil
import struct
import subprocess
import sys
import time
import wave

HOME = os.path.expanduser("~")
STATE_DIR = os.environ.get("QS_STATE_DIR") or os.path.join(HOME, ".local/state/serpantinum")
RUN_DIR = os.environ.get("QS_RUN_DIR") or os.path.join(os.environ.get("XDG_RUNTIME_DIR") or "/tmp", "serpantinum")
STATE_FILE = os.path.join(STATE_DIR, "music", "eq_state.json")
OLD_STATE_FILE = os.path.join(RUN_DIR, "music", "eq_state.json")   # before MuhOS 0.1.0-0.15
WORK = os.path.join(RUN_DIR, "music")
CONF = os.path.join(WORK, "eq-filter.conf")
STRUCTURE = os.path.join(WORK, "eq-structure")
PID_FILE = os.path.join(WORK, "eq-engine.pid")
TEST_FILE = os.path.join(WORK, "channel_test.wav")
TEST_PID_FILE = os.path.join(WORK, "channel_test.pid")

UNIT = "serpantinum-eq"
NODE = "serpantinum_eq"
FREQS = [32, 63, 125, 250, 500, 1000, 2000, 4000, 8000, 16000]
Q = 1.0
PRESETS = {
    "Flat": [0, 0, 0, 0, 0, 0, 0, 0, 0, 0],
    "Bass": [5, 7, 5, 2, 1, 0, 0, 0, 1, 2],
    "Treble": [-2, -1, 0, 1, 2, 3, 4, 5, 6, 6],
    "Vocal": [-2, -1, 1, 3, 5, 5, 4, 2, 1, 0],
    "Pop": [2, 4, 2, 0, 1, 2, 4, 2, 1, 2],
    "Rock": [5, 4, 2, -1, -2, -1, 2, 4, 5, 6],
    "Jazz": [3, 3, 1, 1, 1, 1, 2, 1, 2, 3],
    "Classic": [0, 1, 2, 2, 2, 2, 1, 2, 3, 4],
}
DEFAULTS = {**{f"b{i}": 0 for i in range(1, 11)}, "preset": "Flat", "pending": False,
            "balance": 0, "mono": False, "swap": False, "dynamics": "off", "enabled": True}

# Dynamics: SWH LADSPA compressor and limiter (Fedora: ladspa-swh-plugins).
LADSPA_DIRS = [d for d in (os.environ.get("LADSPA_PATH") or "/usr/lib64/ladspa:/usr/lib/ladspa").split(":") if d]
COMPRESSOR = "sc4_1882"
LIMITER = "fast_lookahead_limiter_1913"
DYNAMICS = {
    # threshold dB, ratio, attack ms, release ms, makeup dB
    "balanced": (-20.0, 2.8, 14.0, 200.0, 3.0),
    "night": (-28.0, 6.0, 6.0, 320.0, 7.0),
}


def dynamics_available():
    return all(any(os.path.exists(os.path.join(d, f"{p}.so")) for d in LADSPA_DIRS) for p in (COMPRESSOR, LIMITER))


# State ----------------------------------------------------------------------

def load():
    os.makedirs(os.path.dirname(STATE_FILE), exist_ok=True)
    if not os.path.exists(STATE_FILE) and os.path.exists(OLD_STATE_FILE):
        shutil.copyfile(OLD_STATE_FILE, STATE_FILE)
    try:
        with open(STATE_FILE) as f:
            state = json.load(f)
    except (OSError, ValueError):
        state = {}
    return {**DEFAULTS, **{k: v for k, v in state.items() if k in DEFAULTS}}


def save(state):
    state = {k: state[k] for k in DEFAULTS}
    state["dynamicsAvailable"] = dynamics_available()
    state["active"] = needs_engine(state)
    tmp = f"{STATE_FILE}.tmp.{os.getpid()}"
    with open(tmp, "w") as f:
        json.dump(state, f)
    os.replace(tmp, STATE_FILE)


def gains(state):
    return [max(-12.0, min(12.0, float(state[f"b{i}"]))) for i in range(1, 11)]


def dynamics_mode(state):
    mode = state.get("dynamics", "off")
    return mode if mode in DYNAMICS and dynamics_available() else "off"


def needs_engine(state):
    if not state.get("enabled", True):
        return False
    return (any(g != 0 for g in gains(state)) or float(state["balance"]) != 0
            or state["mono"] or state["swap"] or dynamics_mode(state) != "off")


# Filter graph ---------------------------------------------------------------

def mixer_gains(state):
    """Left/right output mixes of the left/right inputs: swap, mono, balance."""
    ll, lr, rl, rr = (0.0, 1.0, 1.0, 0.0) if state["swap"] else (1.0, 0.0, 0.0, 1.0)
    if state["mono"]:
        ll = lr = rl = rr = 0.5
    b = max(-1.0, min(1.0, float(state["balance"])))
    left, right = 1.0 - max(0.0, b), 1.0 + min(0.0, b)
    return {"mixL:Gain 1": ll * left, "mixL:Gain 2": lr * left,
            "mixR:Gain 1": rl * right, "mixR:Gain 2": rr * right}


def params(state):
    p = mixer_gains(state)
    for i, g in enumerate(gains(state)):
        p[f"eqL{i}:Gain"] = g
        p[f"eqR{i}:Gain"] = g
    return p


def spa(value):
    if isinstance(value, bool):
        return "true" if value else "false"
    if isinstance(value, (int, float)):
        return f"{float(value):.6f}"
    return json.dumps(value)


def graph(state):
    p = params(state)
    nodes = ['{ type = builtin label = copy name = inL }', '{ type = builtin label = copy name = inR }']
    for side in "LR":
        nodes.append(f'{{ type = builtin label = mixer name = mix{side} control = {{ "Gain 1" = {spa(p[f"mix{side}:Gain 1"])} "Gain 2" = {spa(p[f"mix{side}:Gain 2"])} }} }}')
        for i, f in enumerate(FREQS):
            nodes.append(f'{{ type = builtin label = bq_peaking name = eq{side}{i} control = {{ "Freq" = {f}.0 "Q" = {Q} "Gain" = {spa(p[f"eq{side}{i}:Gain"])} }} }}')
    links = ['{ output = "inL:Out" input = "mixL:In 1" }', '{ output = "inR:Out" input = "mixL:In 2" }',
             '{ output = "inL:Out" input = "mixR:In 1" }', '{ output = "inR:Out" input = "mixR:In 2" }']
    for side in "LR":
        links.append(f'{{ output = "mix{side}:Out" input = "eq{side}0:In" }}')
        links += [f'{{ output = "eq{side}{i}:Out" input = "eq{side}{i + 1}:In" }}' for i in range(len(FREQS) - 1)]
    outputs = ['"eqL9:Out"', '"eqR9:Out"']
    mode = dynamics_mode(state)
    if mode != "off":
        threshold, ratio, attack, release, makeup = DYNAMICS[mode]
        nodes.append(f'{{ type = ladspa plugin = {COMPRESSOR} label = sc4 name = comp control = {{ "RMS/peak" = 0.0 "Attack time (ms)" = {attack} "Release time (ms)" = {release} "Threshold level (dB)" = {threshold} "Ratio (1:n)" = {ratio} "Knee radius (dB)" = 6.0 "Makeup gain (dB)" = {makeup} }} }}')
        nodes.append(f'{{ type = ladspa plugin = {LIMITER} label = fastLookaheadLimiter name = limit control = {{ "Input gain (dB)" = 0.0 "Limit (dB)" = -1.0 "Release time (s)" = 0.08 }} }}')
        links += ['{ output = "eqL9:Out" input = "comp:Left input" }', '{ output = "eqR9:Out" input = "comp:Right input" }',
                  '{ output = "comp:Left output" input = "limit:Input 1" }', '{ output = "comp:Right output" input = "limit:Input 2" }']
        outputs = ['"limit:Output 1"', '"limit:Output 2"']
    nl = "\n          "
    return f"""# Generated by eq_engine.py; rewritten on every change.
context.properties = {{ log.level = 2 }}
context.spa-libs = {{ audio.convert.* = audioconvert/libspa-audioconvert support.* = support/libspa-support }}
context.modules = [
  {{ name = libpipewire-module-rt flags = [ ifexists nofail ] }}
  {{ name = libpipewire-module-protocol-native }}
  {{ name = libpipewire-module-client-node }}
  {{ name = libpipewire-module-adapter }}
  {{ name = libpipewire-module-filter-chain
    args = {{
      node.description = "Equaliser"
      media.name = "Equaliser"
      filter.graph = {{
        nodes = [
          {nl.join(nodes)}
        ]
        links = [
          {nl.join(links)}
        ]
        inputs = [ "inL:In" "inR:In" ]
        outputs = [ {" ".join(outputs)} ]
      }}
      audio.channels = 2
      audio.position = [ FL FR ]
      capture.props = {{
        node.name = "{NODE}"
        media.class = Audio/Sink
        filter.smart = true
        filter.smart.name = "{NODE}"
      }}
      playback.props = {{
        node.name = "{NODE}.output"
        node.passive = true
      }}
    }}
  }}
]
"""


# Engine process -------------------------------------------------------------

def run(*cmd, **kw):
    return subprocess.run(cmd, stdout=subprocess.PIPE, stderr=subprocess.DEVNULL, text=True, **kw)


def have_systemd():
    return shutil.which("systemd-run") and run("systemctl", "--user", "show-environment").returncode == 0


def engine_running():
    if have_systemd():
        return run("systemctl", "--user", "is-active", "--quiet", UNIT).returncode == 0
    try:
        with open(PID_FILE) as f:
            os.kill(int(f.read()), 0)
        return True
    except (OSError, ValueError):
        return False


def stop_engine():
    if have_systemd():
        run("systemctl", "--user", "stop", UNIT)
    try:
        with open(PID_FILE) as f:
            os.kill(int(f.read()), 15)
    except (OSError, ValueError):
        pass
    for path in (PID_FILE, STRUCTURE):
        try:
            os.remove(path)
        except OSError:
            pass


def owner_unit():
    """The systemd user service this script runs in (the shell's, when the
    shell calls it), so the engine can stop together with it."""
    try:
        with open("/proc/self/cgroup") as f:
            path = f.read().strip().split("::")[-1]
    except OSError:
        return None
    for part in reversed(path.split("/")):
        if part.endswith(".service") and not part.startswith("user@"):
            return part
    return None


def start_engine(state):
    with open(CONF, "w") as f:
        f.write(graph(state))
    if have_systemd():
        # End with the shell, however it ends (at logout it exits on its own
        # when the compositor goes, which PartOf= would miss), or, when
        # started from elsewhere, with the graphical session.
        owner = owner_unit()
        bind = ["-p", f"BindsTo={owner}", "-p", f"After={owner}"] if owner else \
               ["-p", "PartOf=graphical-session.target", "-p", "After=graphical-session.target"]
        run("systemctl", "--user", "reset-failed", UNIT)
        run("systemd-run", "--user", "--quiet", "--collect", f"--unit={UNIT}",
            "--description=Equaliser (PipeWire filter-chain)", *bind,
            "pipewire", "-c", CONF)
    else:
        proc = subprocess.Popen(["pipewire", "-c", CONF], stdout=subprocess.DEVNULL,
                                stderr=subprocess.DEVNULL, start_new_session=True)
        with open(PID_FILE, "w") as f:
            f.write(str(proc.pid))
    with open(STRUCTURE, "w") as f:
        f.write(dynamics_mode(state))


def node_id():
    out = run("pw-dump").stdout
    try:
        for obj in json.loads(out or "[]"):
            props = (obj.get("info") or {}).get("props") or {}
            if props.get("node.name") == NODE:
                return obj["id"]
    except ValueError:
        pass
    return None


def set_live(state):
    nid = node_id()
    if nid is None:
        return False
    items = " ".join(f'"{k}" {spa(v)}' for k, v in params(state).items())
    return run("pw-cli", "set-param", str(nid), "Props", f"{{ params = [ {items} ] }}").returncode == 0


def apply(state):
    if not needs_engine(state):
        stop_engine()
        return
    try:
        with open(STRUCTURE) as f:
            structure = f.read()
    except OSError:
        structure = None
    if engine_running() and structure == dynamics_mode(state) and set_live(state):
        with open(CONF, "w") as f:      # keep the file in step for the next start
            f.write(graph(state))
        return
    stop_engine()
    start_engine(state)


# Speaker test -----------------------------------------------------------------

def stop_test():
    try:
        with open(TEST_PID_FILE) as f:
            os.kill(int(f.read()), 15)
    except (OSError, ValueError):
        pass
    try:
        os.remove(TEST_PID_FILE)
    except OSError:
        pass


def play_test():
    """Left tone, right tone, both: plays to the default output (and so
    through the equaliser, balance, mono and swap)."""
    stop_test()
    if not (os.path.exists(TEST_FILE) and os.path.getsize(TEST_FILE) > 0):
        rate = 48000
        segments = [(0.75, 660, 0), (0.18, 0, 0), (0.75, 0, 880), (0.18, 0, 0), (1.0, 770, 770)]
        with wave.open(TEST_FILE, "wb") as out:
            out.setnchannels(2)
            out.setsampwidth(2)
            out.setframerate(rate)
            frames = bytearray()
            for duration, left_hz, right_hz in segments:
                n = int(duration * rate)
                for i in range(n):
                    fade = min(1.0, i / (rate * 0.015), (n - i) / (rate * 0.015))
                    def sample(freq):
                        return int(9000 * fade * math.sin(2 * math.pi * freq * i / rate)) if freq else 0
                    frames += struct.pack("<hh", sample(left_hz), sample(right_hz))
            out.writeframesraw(frames)
    proc = subprocess.Popen(["pw-play", "-P", '{"application.name":"Speaker test","media.role":"music"}', TEST_FILE],
                            stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL, start_new_session=True)
    with open(TEST_PID_FILE, "w") as f:
        f.write(str(proc.pid))


# Commands -------------------------------------------------------------------

def number(text, low, high):
    value = float(text)
    if not math.isfinite(value):
        raise ValueError(text)
    return max(low, min(high, value))


def boolean(text):
    if text not in ("true", "false"):
        raise ValueError(text)
    return text == "true"


def main(argv):
    os.makedirs(WORK, exist_ok=True)
    cmd, args = (argv[0] if argv else "get"), argv[1:]
    state = load()

    if cmd == "get":
        save(state)
        with open(STATE_FILE) as f:
            sys.stdout.write(f.read() + "\n")
        return 0
    if cmd in ("restore", "apply"):
        state["pending"] = False
    elif cmd == "enable":
        state["enabled"] = boolean(args[0])
    elif cmd == "set_band":
        band = int(args[0])
        if not 1 <= band <= 10:
            raise ValueError(band)
        state[f"b{band}"] = round(number(args[1], -12, 12), 1)
        state["preset"] = "Custom"
        state["pending"] = True     # applied by "apply" (the music window's Save)
    elif cmd == "set_band_live":
        band = int(args[0])
        if not 1 <= band <= 10:
            raise ValueError(band)
        state[f"b{band}"] = round(number(args[1], -12, 12), 1)
        state["preset"] = "Custom"
        state["pending"] = False
    elif cmd == "preset":
        if args[0] not in PRESETS:
            raise ValueError(args[0])
        for i, g in enumerate(PRESETS[args[0]], 1):
            state[f"b{i}"] = g
        state["preset"] = args[0]
        state["pending"] = False
    elif cmd == "set_balance":
        state["balance"] = round(number(args[0], -1, 1), 2)
    elif cmd in ("set_mono", "set_swap"):
        state[cmd[4:]] = boolean(args[0])
    elif cmd == "set_dynamics":
        if args[0] not in ("off", "balanced", "night"):
            raise ValueError(args[0])
        state["dynamics"] = args[0]
    elif cmd == "reset_audio":
        state.update(balance=0, mono=False, swap=False, dynamics="off")
        stop_test()
    elif cmd == "test":
        play_test()
        return 0
    elif cmd == "stop_test":
        stop_test()
        return 0
    else:
        print("usage: eq_engine.py get|restore|apply|enable|set_band|set_band_live|preset|set_balance|"
              "set_mono|set_swap|set_dynamics|reset_audio|test|stop_test [args]", file=sys.stderr)
        return 2

    save(state)
    if not state["pending"]:
        apply(state)
    return 0


if __name__ == "__main__":
    try:
        sys.exit(main(sys.argv[1:]))
    except (ValueError, IndexError):
        sys.exit(1)
