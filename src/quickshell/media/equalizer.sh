#!/usr/bin/env bash
# The music equaliser: same commands as before (get, set_band, apply, preset,
# set_balance, set_mono, set_swap, set_dynamics, reset_audio, test,
# stop_test). MuhOS: the engine is PipeWire's filter-chain instead of
# EasyEffects; it lives in eq_engine.py.

source "$(dirname "${BASH_SOURCE[0]}")/../../scripts/caching.sh"
qs_ensure_cache "music"

exec python3 -I "$(dirname "${BASH_SOURCE[0]}")/eq_engine.py" "$@"
