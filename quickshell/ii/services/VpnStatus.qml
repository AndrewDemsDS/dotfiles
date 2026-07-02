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
    property var vpnConnections: [] // available NM wireguard/vpn connection names (for the toggle fallback)
    property var activeVpnNames: [] // names of every currently-active vpn/wg/tun connection
    property var vpnProfiles: [] // detailed list for the manager: [{name, uuid, type, autoconnect}]

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

    // ── Auto-VPN ─────────────────────────────────────────────────────────────
    // When enabled, keep the VPN up on untrusted networks and down on trusted
    // (home) ones. The shell becomes the sole controller, so NM's own autoconnect
    // for the managed connection is turned off the first time auto-VPN acts.
    property string _autoTunedTarget: ""
    property string _autoMsg: ""

    function _applyAuto() {
        const opt = Config.options.vpnStatus;
        if (!opt.enable || !opt.autoConnect)
            return;
        const t = root.toggleTarget;
        if (t.length === 0 || root.localIp.length === 0) // no target, or network not known yet
            return;
        // Stop NetworkManager from auto-raising this connection on a home network.
        if (root._autoTunedTarget !== t) {
            root._autoTunedTarget = t;
            Quickshell.execDetached(["nmcli", "connection", "modify", t, "connection.autoconnect", "no"]);
        }
        if (root.trusted && root.vpnUp) {
            root._autoMsg = Translation.tr("Disconnected on a trusted network");
            autoProc.command = ["nmcli", "connection", "down", root.vpnName.length > 0 ? root.vpnName : t];
            autoProc.running = true;
        } else if (!root.trusted && !root.vpnUp) {
            root._autoMsg = Translation.tr("Connected on an untrusted network");
            autoProc.command = ["nmcli", "connection", "up", t];
            autoProc.running = true;
        }
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
                let active = [];
                const lines = text.trim().length > 0 ? text.trim().split("\n") : [];
                for (const line of lines) {
                    const f = line.split(":");
                    const type = f[1] ?? "";
                    const state = f[2] ?? "";
                    if ((type === "wireguard" || type === "vpn" || type === "tun") && state === "activated") {
                        active.push(f[0]);
                        if (!up) {
                            up = true;
                            name = f[0];
                        }
                    }
                }
                root.vpnUp = up;
                root.vpnName = name;
                root.activeVpnNames = active;
            }
        }
    }

    // Enumerate available VPN/WireGuard connection profiles (names for the toggle fallback,
    // plus detailed rows for the manager dialog).
    Process {
        id: listProc
        command: ["nmcli", "-t", "-f", "NAME,UUID,TYPE,AUTOCONNECT", "connection", "show"]
        stdout: StdioCollector {
            onStreamFinished: {
                let conns = [];
                let profiles = [];
                const lines = text.trim().length > 0 ? text.trim().split("\n") : [];
                for (const line of lines) {
                    const f = line.split(":");
                    const type = f[2] ?? "";
                    if (type === "wireguard" || type === "vpn" || type === "tun") {
                        conns.push(f[0]);
                        profiles.push({
                            name: f[0],
                            uuid: f[1] ?? "",
                            type: type,
                            autoconnect: (f[3] ?? "") === "yes"
                        });
                    }
                }
                root.vpnConnections = conns;
                root.vpnProfiles = profiles;
            }
        }
    }

    // ── Profile management (all non-root; user has NM network-control perm) ───
    // A single serialized action process: run a command, then refresh. Failures notify.
    property string _actionLabel: ""
    function _run(cmd, label) {
        if (actionProc.running) // avoid clobbering an in-flight action
            return;
        root._actionLabel = label ?? "";
        actionProc.command = cmd;
        actionProc.running = true;
    }

    // Single-quote a value for embedding in a bash -c command.
    function _sq(s) {
        return "'" + String(s).replace(/'/g, "'\\''") + "'";
    }
    // Connect exclusively: NetworkManager happily runs multiple VPNs at once, so
    // bring down any *other* active vpn/wg/tun first, then bring up the target.
    function connectProfile(name) {
        if (!name || name.length === 0)
            return;
        const downs = (root.activeVpnNames ?? []).filter(n => n !== name).map(n => "nmcli connection down " + root._sq(n));
        const cmd = downs.concat(["nmcli connection up " + root._sq(name)]).join(" ; ");
        root._run(["bash", "-c", cmd], Translation.tr("Connect %1").arg(name));
    }
    function disconnectProfile(name) {
        if (name && name.length > 0)
            root._run(["nmcli", "connection", "down", name], Translation.tr("Disconnect %1").arg(name));
    }
    function deleteProfile(name) {
        if (name && name.length > 0)
            root._run(["nmcli", "connection", "delete", name], Translation.tr("Delete %1").arg(name));
    }
    function setProfileAutoconnect(name, on) {
        if (name && name.length > 0)
            root._run(["nmcli", "connection", "modify", name, "connection.autoconnect", on ? "yes" : "no"], "");
    }
    function renameProfile(name, newName) {
        if (name && name.length > 0 && newName && newName.length > 0 && newName !== name)
            root._run(["nmcli", "connection", "modify", name, "connection.id", newName], Translation.tr("Rename to %1").arg(newName));
    }
    // Import a WireGuard (.conf) or OpenVPN (.ovpn) profile file.
    function importConfig(path) {
        const p = (path ?? "").trim().replace(/^file:\/\//, "").replace(/^~/, FileUtils.trimFileProtocol(Directories.home));
        if (p.length === 0)
            return;
        const lower = p.toLowerCase();
        const kind = (lower.endsWith(".ovpn") || lower.endsWith(".openvpn")) ? "openvpn" : "wireguard";
        root._run(["nmcli", "connection", "import", "type", kind, "file", p], Translation.tr("Import %1").arg(kind));
    }
    // Open the system file picker (kdialog, as the wallpaper picker uses) to choose a
    // profile file, then import it.
    function browseImport() {
        browseProc.command = ["kdialog", "--getopenfilename", FileUtils.trimFileProtocol(Directories.home), "*.conf *.ovpn *.wg|" + Translation.tr("VPN profiles (*.conf, *.ovpn)"), "--title", Translation.tr("Import VPN profile")];
        browseProc.running = true;
    }

    Process {
        id: browseProc
        stdout: StdioCollector {
            onStreamFinished: {
                const p = text.trim();
                if (p.length > 0)
                    root.importConfig(p);
            }
        }
    }

    Process {
        id: actionProc
        onExited: (exitCode, exitStatus) => {
            if (exitCode !== 0 && root._actionLabel.length > 0) {
                Quickshell.execDetached(["notify-send", Translation.tr("VPN"), Translation.tr("Failed: %1").arg(root._actionLabel), "-a", "Shell", "-u", "critical"]);
            } else if (root._actionLabel.length > 0) {
                Quickshell.execDetached(["notify-send", Translation.tr("VPN"), root._actionLabel, "-a", "Shell", "-u", "low"]);
            }
            root._actionLabel = "";
            root.refresh();
        }
    }

    // Flip auto-connect (and auto-disconnect on trusted networks) on/off. Backs the quick toggle.
    function toggleAuto() {
        Config.options.vpnStatus.autoConnect = !Config.options.vpnStatus.autoConnect;
        if (Config.options.vpnStatus.autoConnect)
            root.refresh(); // re-evaluate immediately so it acts on the current network
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

    // Re-evaluate auto-VPN shortly after a refresh settles, debounced so all
    // three probe processes have reported before we decide.
    Timer {
        id: autoTimer
        interval: 1500
        repeat: false
        onTriggered: root._applyAuto()
    }

    Process {
        id: autoProc
        onExited: (exitCode, exitStatus) => {
            if (exitCode === 0) {
                if (root._autoMsg.length > 0)
                    Quickshell.execDetached(["notify-send", Translation.tr("VPN"), root._autoMsg, "-a", "Shell", "-u", "low"]);
                root._autoMsg = "";
                root.refresh();
            } else {
                // Leave the retry to the next poll so a failing action can't tight-loop.
                console.log("[VpnStatus] auto action failed:", root._autoMsg);
                root._autoMsg = "";
            }
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
                if (Config.options.vpnStatus.autoConnect)
                    autoTimer.restart();
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
        function toggleAuto(): void {
            root.toggleAuto();
        }
        function connect(name: string): void {
            root.connectProfile(name);
        }
        function disconnect(name: string): void {
            root.disconnectProfile(name);
        }
        function remove(name: string): void {
            root.deleteProfile(name);
        }
        function importFile(path: string): void {
            root.importConfig(path);
        }
        function profiles(): string {
            return root.vpnProfiles.map(p => `${p.name} [${p.type}]${root.activeVpnNames.indexOf(p.name) !== -1 ? " *active" : ""}${p.autoconnect ? " auto" : ""}`).join("\n");
        }
        function status(): string {
            return `ssid=${root.ssid} vpn=${root.vpnUp ? root.vpnName : "down"} target=${root.toggleTarget} trusted=${root.trusted} auto=${Config.options.vpnStatus.autoConnect} ip=${root.localIp} pub=${root.publicIp}`;
        }
    }
}
