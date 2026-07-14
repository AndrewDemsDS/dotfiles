#!/usr/bin/env bash
# Quickshell's renderer can freeze after suspend/resume with no recovery
# (end-4/dots-hyprland #2320, #2971) — restart it on wake.
# The qs lock screen dies with the restart, so cover the gap with hyprlock first.

if ! pidof hyprlock >/dev/null; then
    hyprlock &
    sleep 0.5 # let hyprlock grab the session before the qs locker dies
fi

qs kill -c ii 2>/dev/null
pkill -x qs 2>/dev/null # fallback if the freeze took the IPC socket with it

# Wait for the old instance to actually die before relaunching. pkill returns
# before the process exits, and a frozen instance can outlive its SIGTERM — if
# its runtime lock is still held when the new shell starts, --no-duplicate makes
# the relaunch abort and we end up with NO shell (renderer-freeze resume bug).
for _ in $(seq 1 20); do
    pgrep -x qs >/dev/null || break
    sleep 0.1
done
pkill -9 -x qs 2>/dev/null # force-kill a frozen holdout that ignored SIGTERM

qs -c ii -d # no -n: the old instance is gone, nothing to duplicate
