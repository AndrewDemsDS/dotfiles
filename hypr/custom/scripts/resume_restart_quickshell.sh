#!/usr/bin/env bash
# Quickshell's renderer can freeze after suspend/resume with no recovery
# (end-4/dots-hyprland #2320, #2971) — restart it on wake.
# The qs lock screen dies with the restart, so cover the gap with hyprlock first.

if ! pidof hyprlock >/dev/null; then
    hyprlock &
    sleep 0.5 # let hyprlock grab the session before the qs locker dies
fi

qs kill -c ii
pkill -x qs 2>/dev/null # fallback if the freeze took the IPC socket with it
qs -c ii -d -n
