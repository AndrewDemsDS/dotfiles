pragma Singleton

import qs.modules.common
import qs.services
import QtQuick
import Quickshell
import Quickshell.Io

/*
 * NAS / media-server guard. Polls free disk space (via SSH `df`, or a Home Assistant
 * sensor) and container health (via SSH `docker ps`). Warns before a media server's
 * low-disk crash threshold. All hosts/keys come from config (no personal data in-repo).
 */
Singleton {
    id: root

    readonly property var cfg: Config.options.nasGuard
    property double freeBytes: -1
    property var containers: [] // [{name, state, health}]
    property bool reachable: false
    readonly property double guardBytes: root.cfg.guardGiB * 1073741824
    readonly property bool belowThreshold: root.freeBytes >= 0 && root.freeBytes < root.guardBytes
    readonly property bool usingHa: root.cfg.freeSpaceEntity.length > 0
    readonly property bool usingSsh: !root.usingHa && root.cfg.sshHost.length > 0
    readonly property bool configured: root.cfg.enable && (root.usingHa || root.usingSsh)

    function freeHuman() {
        if (root.freeBytes < 0)
            return "–";
        const gib = root.freeBytes / 1073741824;
        return gib >= 100 ? `${Math.round(gib)} GiB` : `${gib.toFixed(1)} GiB`;
    }

    function _ssh(remoteCmd) {
        const c = root.cfg;
        const key = c.sshKey.length > 0 ? `-i ${c.sshKey} ` : "";
        return ["bash", "-c", `ssh -o BatchMode=yes -o ConnectTimeout=6 -p ${c.sshPort} ${key}${c.sshUser}@${c.sshHost} '${remoteCmd}'`];
    }

    function refresh() {
        if (!root.configured)
            return;
        if (root.usingHa) {
            const v = Number(HomeAssistant.stateOf(root.cfg.freeSpaceEntity));
            // HA sensor assumed to report GiB; convert to bytes
            root.freeBytes = isNaN(v) ? -1 : v * 1073741824;
            root.reachable = !isNaN(v);
            root._checkWarn();
        } else if (root.usingSsh) {
            freeProc.command = root._ssh(`df -B1 --output=avail ${root.cfg.dfMount} | tail -1`);
            freeProc.running = true;
            if (root.cfg.showContainers) {
                containersProc.command = root._ssh("docker ps --format '{{.Names}}\\t{{.State}}\\t{{.Status}}'");
                containersProc.running = true;
            }
        }
    }

    property bool _warned: false
    function _checkWarn() {
        if (root.belowThreshold && !root._warned) {
            Quickshell.execDetached(["notify-send", Translation.tr("NAS low on disk"), Translation.tr("Only %1 free — media server may misbehave").arg(root.freeHuman()), "-u", "critical", "-a", "Shell"]);
            root._warned = true;
        } else if (!root.belowThreshold && root.freeBytes >= root.guardBytes * 1.1) {
            root._warned = false; // hysteresis
        }
    }

    Process {
        id: freeProc
        stdout: StdioCollector {
            onStreamFinished: {
                const n = parseInt(text.trim());
                root.freeBytes = isNaN(n) ? -1 : n;
                root.reachable = !isNaN(n);
                root._checkWarn();
            }
        }
        onExited: (code, status) => {
            if (code !== 0) {
                root.reachable = false;
                root.freeBytes = -1;
            }
        }
    }

    Process {
        id: containersProc
        stdout: StdioCollector {
            onStreamFinished: {
                let out = [];
                for (const line of (text.trim().length > 0 ? text.trim().split("\n") : [])) {
                    const f = line.split("\t");
                    const status = f[2] ?? "";
                    const health = status.includes("(unhealthy)") ? "unhealthy" : (status.includes("(healthy)") ? "healthy" : "");
                    out.push({
                        "name": f[0] ?? "",
                        "state": f[1] ?? "",
                        "health": health
                    });
                }
                root.containers = out;
            }
        }
    }

    Timer {
        interval: Math.max(15, root.cfg.pollSeconds) * 1000
        repeat: true
        running: Config.ready && root.cfg.enable
        triggeredOnStart: true
        onTriggered: root.refresh()
    }

    IpcHandler {
        target: "nas"
        function refresh(): void {
            root.refresh();
        }
        function status(): string {
            return `configured=${root.configured} reachable=${root.reachable} free=${root.freeHuman()} below=${root.belowThreshold} containers=${root.containers.length}`;
        }
    }
}
