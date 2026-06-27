pragma Singleton

import qs.modules.common
import qs.modules.common.functions
import qs.services
import QtQuick
import Quickshell
import Quickshell.Io

/*
 * Network/VPN awareness service. Sourced entirely from non-root tools:
 *   - nmcli (active connections) for VPN/WireGuard up/down
 *   - ip route for local iface/gateway/IP
 *   - Network.networkName (nmcli) for the current SSID
 *   - a single XHR (on network change only) for public IP + geo
 * Classifies the current network as trusted/untrusted against a config allowlist.
 */
Singleton {
    id: root

    // VPN (nmcli)
    property bool vpnUp: false
    property string vpnName: ""
    property var vpnConnections: [] // available NM wireguard/vpn connection names

    // Which connection the quick-toggle acts on. Configurable, with sensible fallbacks:
    //   config vpnStatus.toggleConnection  →  currently-up VPN  →  first available  →  none
    readonly property string toggleTarget: {
        const cfg = Config.options.vpnStatus.toggleConnection;
        if (cfg && cfg.length > 0)
            return cfg;
        if (root.vpnUp && root.vpnName.length > 0)
            return root.vpnName;
        return root.vpnConnections.length > 0 ? root.vpnConnections[0] : "";
    }

    // Local network (ip route)
    property string iface: ""
    property string gateway: ""
    property string localIp: ""
    property string subnet: "" // first 3 octets, e.g. "192.168.1"

    // SSID — reuse the existing nmcli-backed Network service
    readonly property string ssid: Network.networkName ?? ""

    // Public IP + geo (fetched only on network change)
    property string publicIp: ""
    property string geoCity: ""
    property string geoCountry: ""
    property string _lastGeoKey: ""

    readonly property bool trusted: {
        const opt = Config.options.vpnStatus;
        if (root.ssid.length > 0 && (opt.trustedSsids ?? []).indexOf(root.ssid) !== -1)
            return true;
        if (root.subnet.length > 0 && (opt.trustedSubnets ?? []).some(s => root.localIp.startsWith(s)))
            return true;
        return false;
    }
    // Warn only when on an untrusted network with no VPN protecting it.
    readonly property bool warn: Config.options.vpnStatus.enable && !root.trusted && !root.vpnUp

    readonly property string materialSymbol: root.vpnUp ? "vpn_lock" : root.warn ? "gpp_maybe" : root.trusted ? "verified_user" : "vpn_key_off"

    readonly property color statusColor: root.warn ? Appearance.m3colors.m3error : root.vpnUp ? Appearance.colors.colPrimary : Appearance.colors.colOnSurfaceVariant

    function refresh() {
        if (!Config.options.vpnStatus.enable)
            return;
        vpnProc.running = true;
        routeProc.running = true;
        listProc.running = true;
    }

    // Bring the target VPN connection up or down (nmcli; user has network-control perm).
    function toggle() {
        const t = root.toggleTarget;
        if (t.length === 0) {
            Quickshell.execDetached(["notify-send", Translation.tr("VPN"), Translation.tr("No VPN connection set (configure vpnStatus.toggleConnection)"), "-a", "Shell", "-u", "low"]);
            return;
        }
        toggleProc.command = ["nmcli", "connection", root.vpnUp ? "down" : "up", t];
        toggleProc.running = true;
    }

    function _maybeFetchGeo() {
        if (!Config.options.vpnStatus.geoLookup)
            return;
        const key = `${root.localIp}|${root.gateway}`;
        if (key === root._lastGeoKey || root.localIp.length === 0)
            return;
        root._lastGeoKey = key;
        const xhr = new XMLHttpRequest();
        xhr.open("GET", "https://ipinfo.io/json");
        xhr.onreadystatechange = function () {
            if (xhr.readyState === XMLHttpRequest.DONE && xhr.status === 200) {
                try {
                    const r = JSON.parse(xhr.responseText);
                    root.publicIp = r.ip ?? "";
                    root.geoCity = r.city ?? "";
                    root.geoCountry = r.country ?? "";
                } catch (e) {
                    console.log("[VpnStatus] geo parse failed:", e);
                }
            }
        };
        xhr.send();
    }

    Timer {
        interval: Math.max(5, Config.options.vpnStatus.pollSeconds) * 1000
        repeat: true
        running: Config.ready && Config.options.vpnStatus.enable
        triggeredOnStart: true
        onTriggered: root.refresh()
    }

    // nmcli active connections → VPN/WireGuard up?
    Process {
        id: vpnProc
        command: ["nmcli", "-t", "-f", "NAME,TYPE,STATE", "connection", "show", "--active"]
        stdout: StdioCollector {
            onStreamFinished: {
                let up = false;
                let name = "";
                const lines = text.trim().length > 0 ? text.trim().split("\n") : [];
                for (const line of lines) {
                    const f = line.split(":");
                    const type = f[1] ?? "";
                    const state = f[2] ?? "";
                    if ((type === "wireguard" || type === "vpn" || type === "tun") && state === "activated") {
                        up = true;
                        name = f[0];
                        break;
                    }
                }
                root.vpnUp = up;
                root.vpnName = name;
            }
        }
    }

    // Enumerate available VPN/WireGuard connection profiles (for the toggle fallback).
    Process {
        id: listProc
        command: ["nmcli", "-t", "-f", "NAME,TYPE", "connection", "show"]
        stdout: StdioCollector {
            onStreamFinished: {
                let conns = [];
                const lines = text.trim().length > 0 ? text.trim().split("\n") : [];
                for (const line of lines) {
                    const f = line.split(":");
                    const type = f[1] ?? "";
                    if (type === "wireguard" || type === "vpn" || type === "tun")
                        conns.push(f[0]);
                }
                root.vpnConnections = conns;
            }
        }
    }

    Process {
        id: toggleProc
        onExited: (exitCode, exitStatus) => {
            if (exitCode !== 0) {
                Quickshell.execDetached(["notify-send", Translation.tr("VPN"), Translation.tr("Failed to toggle %1").arg(root.toggleTarget), "-a", "Shell", "-u", "critical"]);
            }
            root.refresh();
        }
    }

    // ip route get → iface / gateway / local IP
    Process {
        id: routeProc
        command: ["ip", "route", "get", "1.1.1.1"]
        stdout: StdioCollector {
            onStreamFinished: {
                const m = text.match(/via (\S+) dev (\S+) src (\S+)/);
                if (m) {
                    root.gateway = m[1];
                    root.iface = m[2];
                    root.localIp = m[3];
                    root.subnet = m[3].split(".").slice(0, 3).join(".");
                } else {
                    root.gateway = "";
                    root.iface = "";
                    root.localIp = "";
                    root.subnet = "";
                }
                root._maybeFetchGeo();
            }
        }
    }

    IpcHandler {
        target: "vpnStatus"
        function refresh(): void {
            root.refresh();
        }
        function toggle(): void {
            root.toggle();
        }
        function status(): string {
            return `ssid=${root.ssid} vpn=${root.vpnUp ? root.vpnName : "down"} target=${root.toggleTarget} trusted=${root.trusted} ip=${root.localIp} pub=${root.publicIp}`;
        }
    }
}
