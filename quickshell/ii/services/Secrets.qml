pragma Singleton

import qs.modules.common
import qs.modules.common.functions
import QtQuick
import Quickshell
import Quickshell.Io

/*
 * Secrets surfacing — pick a saved secret, copy it to the clipboard, auto-clear.
 *
 * Security model: the plaintext NEVER enters QML/JS. Listing yields entry NAMES only
 * (file names for `pass`, which are not secret). Copying happens entirely inside the
 * shelled pipe — `pass show -c` (pass owns copy + clear) or `<showCommand> | wl-copy`
 * for a custom backend, with a Timer running `wl-copy --clear` after clearSeconds.
 * Values are never shown in the UI and never logged.
 *
 * Backends (Config.options.secrets.backend):
 *   "pass"    — the standard password-store (needs `pass` + gpg). Optional store override.
 *   "command" — generic: listCommand prints names; showCommand gets $SECRET_NAME on the
 *               environment and prints the secret to stdout (piped straight to wl-copy).
 * Disabled by default — set a backend up first.
 */
Singleton {
    id: root

    property bool active: false
    property bool loading: false
    property bool backendAvailable: false
    property var entries: [] // entry names only — never values
    property int clearRemaining: 0 // seconds left before the clipboard auto-clears
    property string _pendingName: ""

    readonly property string backend: (Config.options.secrets.backend ?? "pass").trim()
    readonly property int clearSeconds: {
        const n = Config.options.secrets.clearSeconds ?? 45;
        return n > 0 ? n : 45;
    }
    readonly property string store: (Config.options.secrets.store ?? "").trim()

    function open() {
        if (!Config.options.secrets.enable)
            return;
        root.active = true;
        root.refresh();
    }
    function close() {
        root.active = false;
    }
    function toggle() {
        if (root.active)
            root.close();
        else
            root.open();
    }

    function refresh() {
        if (!Config.options.secrets.enable)
            return;
        root.loading = true;
        listProc.running = false;
        listProc.running = true;
    }

    // Environment shared by list/copy: store dir + pass's own clip timeout, plus extras.
    function _env(extra) {
        const e = {
            "LANG": "C",
            "LC_ALL": "C",
            "PASSWORD_STORE_CLIP_TIME": String(root.clearSeconds)
        };
        if (root.store.length > 0)
            e["PASSWORD_STORE_DIR"] = root.store;
        for (const k in extra)
            e[k] = extra[k];
        return e;
    }

    // Copy a secret to the clipboard entirely inside the shell pipe (plaintext never enters QML).
    function copy(name) {
        if (!Config.options.secrets.enable || !name || name.length === 0)
            return;
        let cmd;
        if (root.backend === "pass") {
            // pass copies the first line and clears after PASSWORD_STORE_CLIP_TIME by itself.
            cmd = ["bash", "-c", 'pass show -c -- "$SECRET_NAME"'];
        } else {
            const show = (Config.options.secrets.showCommand ?? "").trim();
            if (show.length === 0) {
                Quickshell.execDetached(["notify-send", Translation.tr("Secrets"), Translation.tr("Set a show command in settings first."), "-a", "Shell", "-u", "low"]);
                return;
            }
            cmd = ["bash", "-c", `${show} | wl-copy`];
        }
        root._pendingName = name;
        copyProc.exec({
            "command": cmd,
            "environment": root._env({
                "SECRET_NAME": name
            })
        });
    }

    function clearNow() {
        clearTimer.stop();
        root.clearRemaining = 0;
        Quickshell.execDetached(["wl-copy", "--clear"]);
    }

    // Backend availability + entry listing (names only).
    Process {
        id: listProc
        environment: root._env({})
        command: {
            if (root.backend === "pass") {
                return ["bash", "-c", 'd="${PASSWORD_STORE_DIR:-$HOME/.password-store}"; command -v pass >/dev/null 2>&1 || exit 3; [ -d "$d" ] || exit 4; find "$d" -name "*.gpg" -type f 2>/dev/null | sed -e "s|^$d/||" -e "s|\\.gpg$||" | sort'];
            }
            const list = (Config.options.secrets.listCommand ?? "").trim();
            if (list.length === 0)
                return ["bash", "-c", "exit 5"];
            return ["bash", "-c", list];
        }
        stdout: StdioCollector {
            onStreamFinished: {
                const names = text.trim().length > 0 ? text.trim().split("\n").map(s => s.trim()).filter(s => s.length > 0) : [];
                root.entries = names;
                root.backendAvailable = true;
                root.loading = false;
            }
        }
        onExited: (code, status) => {
            if (code !== 0) {
                root.entries = [];
                root.backendAvailable = false;
                root.loading = false;
            }
        }
    }

    Process {
        id: copyProc
        onExited: (code, status) => {
            if (code !== 0) {
                Quickshell.execDetached(["notify-send", Translation.tr("Secrets"), Translation.tr("Could not copy %1").arg(root._pendingName), "-a", "Shell", "-u", "critical"]);
                return;
            }
            // Arm the countdown. For "command" backend WE clear at 0; for "pass", pass clears
            // itself but we still show the countdown and clear as a harmless backstop.
            root.clearRemaining = root.clearSeconds;
            clearTimer.restart();
            Quickshell.execDetached(["notify-send", Translation.tr("Secrets"), Translation.tr("Copied %1 — clears in %2s").arg(root._pendingName).arg(root.clearSeconds), "-a", "Shell", "-u", "low"]);
            root.close();
        }
    }

    Timer {
        id: clearTimer
        interval: 1000
        repeat: true
        onTriggered: {
            root.clearRemaining = root.clearRemaining - 1;
            if (root.clearRemaining <= 0) {
                clearTimer.stop();
                Quickshell.execDetached(["wl-copy", "--clear"]);
            }
        }
    }

    IpcHandler {
        target: "secrets"
        function open(): void {
            root.open();
        }
        function close(): void {
            root.close();
        }
        function toggle(): void {
            root.toggle();
        }
        function status(): string {
            return `enable=${Config.options.secrets.enable} backend=${root.backend} active=${root.active} entries=${root.entries.length} available=${root.backendAvailable}`;
        }
    }
}
