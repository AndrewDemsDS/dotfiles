pragma Singleton

import qs.modules.common
import qs.modules.common.functions
import QtQuick
import Quickshell
import Quickshell.Io

/*
 * Guarded recon launcher. Grabs the primary selection / clipboard as a target host/URL,
 * checks it against an OWNER-defined allowlist (Config.options.reconLauncher.allowlist),
 * and only then lets you launch a read-only recon tool (nuclei / whatweb / ffuf) in a
 * terminal. Never run anything against a host you don't own — the allowlist is the guard.
 * No personal hosts in-repo: the allowlist + tool config live in untracked config.json.
 */
Singleton {
    id: root

    property bool active: false
    property string target: ""

    readonly property var tools: [
        {
            "key": "nuclei",
            "label": "nuclei",
            "icon": "bug_report"
        },
        {
            "key": "whatweb",
            "label": "whatweb",
            "icon": "travel_explore"
        },
        {
            "key": "ffuf",
            "label": "ffuf",
            "icon": "manage_search"
        }
    ]

    // Host portion of the target, stripped of scheme / path / port for matching.
    readonly property string targetHost: {
        let t = root.target.trim();
        if (t.length === 0)
            return "";
        t = t.replace(/^[a-zA-Z][a-zA-Z0-9+.-]*:\/\//, ""); // scheme://
        t = t.split("/")[0]; // drop path
        t = t.split("@").pop(); // drop creds
        t = t.split(":")[0]; // drop port
        return t.trim().toLowerCase();
    }

    // Allowlisted only if the host matches (prefix/substring) an owner-provided entry.
    readonly property bool allowlisted: {
        const host = root.targetHost;
        if (host.length === 0)
            return false;
        const list = Config.options.reconLauncher.allowlist ?? [];
        return list.some(e => {
            const entry = String(e).trim().toLowerCase();
            return entry.length > 0 && (host === entry || host.startsWith(entry) || host.indexOf(entry) !== -1);
        });
    }

    readonly property string terminal: {
        const t = (Config.options.reconLauncher.terminal ?? "").trim();
        return t.length > 0 ? t : "xdg-terminal-exec";
    }

    function open() {
        if (!Config.options.reconLauncher.enable)
            return;
        selProc.running = true;
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

    // Build argv for the chosen tool. Target is user-owned (not a secret) so it is fine on argv;
    // we still avoid shell interpolation by using an argv array, never a shell string.
    function _toolArgs(tool) {
        const t = root.target.trim();
        if (tool === "nuclei")
            return ["nuclei", "-u", t];
        if (tool === "whatweb")
            return ["whatweb", t];
        if (tool === "ffuf") {
            const wl = (Config.options.reconLauncher.wordlist ?? "").trim();
            const url = t.replace(/\/+$/, "") + "/FUZZ";
            const args = ["ffuf", "-u", url];
            if (wl.length > 0)
                return args.concat(["-w", wl]);
            return args;
        }
        return [];
    }

    function run(tool) {
        if (!Config.options.reconLauncher.enable)
            return;
        if (!root.allowlisted) {
            Quickshell.execDetached(["notify-send", Translation.tr("Recon refused"), Translation.tr("%1 is not in your allowlist — only run recon against hosts you own.").arg(root.targetHost.length > 0 ? root.targetHost : Translation.tr("target")), "-u", "critical", "-a", "Shell"]);
            return;
        }
        if (tool === "ffuf" && (Config.options.reconLauncher.wordlist ?? "").trim().length === 0) {
            Quickshell.execDetached(["notify-send", Translation.tr("ffuf needs a wordlist"), Translation.tr("Set reconLauncher.wordlist in settings first."), "-u", "normal", "-a", "Shell"]);
            return;
        }
        const args = root._toolArgs(tool);
        if (args.length === 0)
            return;
        // Launch the tool in a terminal via execDetached([term, "-e", tool, ...args]) — no shell injection.
        Quickshell.execDetached([root.terminal, "-e"].concat(args));
        root.close();
    }

    Process {
        id: selProc
        // Prefer the clipboard (a deliberate copy = the target you want); fall back to the
        // primary selection only when the clipboard is empty. (wl-paste --primary returns
        // stale highlighted text with exit 0, so it can't be the first choice.)
        command: ["bash", "-c", "c=$(wl-paste --no-newline 2>/dev/null); if [ -n \"$(printf %s \"$c\" | tr -d '[:space:]')\" ]; then printf %s \"$c\"; else wl-paste --primary --no-newline 2>/dev/null; fi"]
        stdout: StdioCollector {
            onStreamFinished: {
                // Take the first whitespace-delimited token so a multi-line clipboard still yields a clean target.
                const first = (text ?? "").trim().split(/\s+/)[0] ?? "";
                root.target = first;
                root.active = true;
            }
        }
    }

    IpcHandler {
        target: "reconLauncher"
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
            return `enable=${Config.options.reconLauncher.enable} active=${root.active} target=${root.targetHost} allowlisted=${root.allowlisted}`;
        }
    }
}
