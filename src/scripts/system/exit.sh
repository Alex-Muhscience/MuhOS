#!/usr/bin/env bash

# MuhOS: when the shell runs as a systemd user service, this script is part of
# that service, so stopping graphical-session.target below would kill it
# before it tells the compositor to exit: the session stayed on a black
# screen with only a cursor. Re-run outside the service first.
if [ -z "${SERPANTINUM_EXIT_DETACHED:-}" ] && [ -n "${INVOCATION_ID:-}" ] && command -v systemd-run &>/dev/null; then
    exec systemd-run --user --scope --quiet --setenv=SERPANTINUM_EXIT_DETACHED=1 \
        --setenv=HYPRLAND_INSTANCE_SIGNATURE="${HYPRLAND_INSTANCE_SIGNATURE:-}" \
        --setenv=XDG_RUNTIME_DIR="${XDG_RUNTIME_DIR:-}" bash "$0" "$@"
fi

rm -f "${XDG_RUNTIME_DIR:-/tmp}/serpantinumd.lock" "${XDG_RUNTIME_DIR:-/tmp}/serpantinumd.pid" 2>/dev/null

if command -v systemctl &>/dev/null; then
    systemctl --user stop graphical-session.target 2>/dev/null
    systemctl --user stop graphical-session-pre.target 2>/dev/null
fi

if command -v dinitctl &>/dev/null; then
    dinitctl --user stop graphical-session 2>/dev/null
fi

sleep 0.2

if [ -n "$HYPRLAND_INSTANCE_SIGNATURE" ] || pgrep -x Hyprland &>/dev/null; then
    hyprctl dispatch 'hl.dsp.exit()' 2>/dev/null || \
    pkill -SIGTERM -x Hyprland 2>/dev/null
elif [ -n "$NIRI_SOCKET" ] || pgrep -x niri &>/dev/null; then
    niri msg action quit --skip-confirmation 2>/dev/null || \
    niri msg action quit 2>/dev/null || \
    pkill -SIGTERM -x niri 2>/dev/null
elif [ -n "$SWAYSOCK" ] || pgrep -x sway &>/dev/null; then
    swaymsg exit 2>/dev/null || \
    pkill -SIGTERM -x sway 2>/dev/null
elif [ -n "$MANGO_INSTANCE_SIGNATURE" ] || pgrep -x mango &>/dev/null; then
    mmsg dispatch quit 2>/dev/null || \
    pkill -SIGTERM -x mango 2>/dev/null
elif [ -n "$WAYFIRE_SOCKET" ] || pgrep -x wayfire &>/dev/null; then
    wayfire-msg -c exit 2>/dev/null || \
    pkill -SIGTERM -x wayfire 2>/dev/null
elif [ -n "$RIVER_SOCKET" ] || pgrep -x river &>/dev/null; then
    riverctl exit 2>/dev/null || \
    pkill -SIGTERM -x river 2>/dev/null
else
    if command -v loginctl &>/dev/null; then
        loginctl terminate-session "${XDG_SESSION_ID:-self}" 2>/dev/null || \
        loginctl terminate-user "$USER" 2>/dev/null
    fi
fi
