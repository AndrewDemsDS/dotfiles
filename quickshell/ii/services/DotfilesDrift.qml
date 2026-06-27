pragma Singleton

import qs.modules.common
import qs.modules.common.functions
import qs.services
import QtQuick
import Quickshell
import Quickshell.Io

/*
 * Dotfiles drift service.
 * Watches whether the tracked dotfiles repo (default ~/.config) has uncommitted or
 * untracked changes, and can commit + push them in one action. Pure-local git; no secrets.
 */
Singleton {
    id: root

    // Repo to watch. Empty config value => default to ~/.config (the repo root).
    readonly property string repoPath: {
        const cfg = Config.options.dotfilesDrift.repoPath;
        return (cfg && cfg.length > 0) ? cfg : FileUtils.trimFileProtocol(Directories.config);
    }

    property int changedCount: 0
    property var changedFiles: []
    readonly property bool dirty: changedCount > 0
    property alias checking: statusProc.running
    property bool pushing: false
    property double dirtySince: 0   // epoch ms when it first went dirty (0 = clean)
    property bool nagged: false

    function refresh() {
        if (!Config.options.dotfilesDrift.enable)
            return;
        statusProc.running = true;
    }

    function commitAndPush() {
        if (root.pushing || !root.dirty)
            return;
        root.pushing = true;
        commitProc.running = true;
    }

    function _maybeNag() {
        if (root.nagged || root.dirtySince === 0)
            return;
        const hours = (Date.now() - root.dirtySince) / 3600000;
        if (hours >= Config.options.dotfilesDrift.nagAfterHours) {
            Quickshell.execDetached(["notify-send",
                Translation.tr("Dotfiles drift"),
                Translation.tr("%1 uncommitted change(s) in your config").arg(root.changedCount),
                "-a", "Shell", "-u", "low", "--hint=int:transient:1"]);
            root.nagged = true;
        }
    }

    Timer {
        interval: Math.max(1, Config.options.dotfilesDrift.checkInterval) * 60 * 1000
        repeat: true
        running: Config.ready && Config.options.dotfilesDrift.enable
        triggeredOnStart: true
        onTriggered: root.refresh()
    }

    // `git status --porcelain=v1 -z` → NUL-terminated records (safe for spaces/renames).
    Process {
        id: statusProc
        command: ["git", "-C", root.repoPath, "status", "--porcelain=v1", "-z", "-uall"]
        stdout: StdioCollector {
            onStreamFinished: {
                const parts = text.split("\0").filter(s => s.length > 0);
                let files = [];
                for (let i = 0; i < parts.length; i++) {
                    const xy = parts[i].substring(0, 2);
                    files.push(parts[i].substring(3));
                    if (xy[0] === 'R' || xy[0] === 'C')
                        i++; // a rename/copy entry is followed by its source path
                }
                root.changedFiles = files;
                root.changedCount = files.length;
                if (root.changedCount > 0) {
                    if (root.dirtySince === 0)
                        root.dirtySince = Date.now();
                    root._maybeNag();
                } else {
                    root.dirtySince = 0;
                    root.nagged = false;
                }
            }
        }
    }

    // Allow a Hyprland keybind / CLI to trigger checks and commits:
    //   qs -c ii ipc call dotfilesDrift refresh|commit|status
    IpcHandler {
        target: "dotfilesDrift"
        function refresh(): void {
            root.refresh();
        }
        function commit(): void {
            root.commitAndPush();
        }
        function status(): string {
            return root.dirty ? `${root.changedCount} changed` : "clean";
        }
    }

    // Commit everything and push to the configured remote.
    Process {
        id: commitProc
        command: ["bash", "-c",
            `git -C "${root.repoPath}" add -A `
            + `&& git -C "${root.repoPath}" commit -m "live tweak from $(hostname) @ $(date -Iseconds)" `
            + `&& git -C "${root.repoPath}" push`]
        onExited: (exitCode, exitStatus) => {
            root.pushing = false;
            if (exitCode !== 0) {
                Quickshell.execDetached(["notify-send",
                    Translation.tr("Dotfiles drift"),
                    Translation.tr("Commit/push failed — check the repo manually."),
                    "-a", "Shell", "-u", "critical"]);
            }
            root.refresh();
        }
    }
}
