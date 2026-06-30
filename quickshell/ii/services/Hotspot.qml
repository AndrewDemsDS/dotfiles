pragma Singleton
pragma ComponentBehavior: Bound

import qs.modules.common
import qs.modules.common.functions
import QtQuick
import Quickshell
import Quickshell.Io

/*
 * Wi-Fi hotspot (AP-mode) service, driven entirely by nmcli (user has network-control perm).
 *
 * Source of truth is a persistent NetworkManager connection profile named "Hotspot"
 * (802-11-wireless.mode=ap, ipv4.method=shared). The profile survives reboots, so its
 * stored ssid / psk / band ARE the configuration — we read them back rather than keep a
 * second copy. Config.options.hotspot only seeds the first-ever profile.
 *
 * Single-radio cards can't be a station and an AP at once, so bringing the hotspot up
 * drops the current Wi-Fi client connection; NM restores it when the hotspot goes down.
 */
Singleton {
    id: root

    readonly property string profileName: "Hotspot"

    property string iface: ""           // wifi device, e.g. "wlan0"
    property bool profileExists: false  // the NM "Hotspot" profile is defined
    property bool enabled: false        // the hotspot is currently up
    property bool busy: toggleProc.running || applyProc.running

    // Configuration (mirrored from the NM profile once it exists)
    property string ssid: Config.options.hotspot?.ssid ?? "ii-hotspot"
    property string password: ""
    property string band: Config.options.hotspot?.band ?? "bg" // "bg" => 2.4GHz, "a" => 5GHz

    readonly property bool passwordValid: root.password.length >= 8
    readonly property string materialSymbol: root.enabled ? "wifi_tethering" : "wifi_tethering_off"

    // Connected clients, read from NetworkManager's dnsmasq leases (world-readable, gives
    // hostname + IP + MAC). Polled only while the hotspot is up. [{ host, ip, mac }]
    property var clients: []
    readonly property int clientCount: root.clients.length

    // ── Wi-Fi QR payload (Android/iOS camera join) ──────────────────────────
    // WIFI:T:WPA;S:<ssid>;P:<pass>;H:false;;  — backslash-escape \ ; , : "
    function _qrEscape(s) {
        return String(s).replace(/([\\;,:"])/g, "\\$1");
    }
    readonly property string qrPayload: `WIFI:T:WPA;S:${_qrEscape(root.ssid)};P:${_qrEscape(root.password)};H:false;;`
    readonly property string qrPath: FileUtils.trimFileProtocol(`${Directories.cache}/hotspot/qr.png`)
    property int qrGeneration: 0 // bump to bust the Image cache after regenerating

    // ── State refresh ───────────────────────────────────────────────────────
    function refresh() {
        ifaceProc.running = true;
        readProc.running = true;
        stateProc.running = true;
    }

    Component.onCompleted: refresh()

    // ── Control ─────────────────────────────────────────────────────────────
    function toggle() {
        if (root.enabled) {
            toggleProc.command = ["nmcli", "connection", "down", root.profileName];
        } else {
            if (!root.profileExists || !root.passwordValid) {
                Quickshell.execDetached(["notify-send", Translation.tr("Hotspot"), Translation.tr("Set a network name and an 8+ character password first."), "-a", "Shell", "-u", "low"]);
                return;
            }
            toggleProc.command = ["nmcli", "connection", "up", root.profileName];
        }
        toggleProc.running = true;
    }

    // Create or update the Hotspot profile, then bring it up if it was already running.
    function applyConfig(ssid, password, band) {
        if (String(password).length < 8) {
            Quickshell.execDetached(["notify-send", Translation.tr("Hotspot"), Translation.tr("Password must be at least 8 characters."), "-a", "Shell", "-u", "low"]);
            return;
        }
        if (root.iface.length === 0) {
            Quickshell.execDetached(["notify-send", Translation.tr("Hotspot"), Translation.tr("No Wi-Fi device found."), "-a", "Shell", "-u", "critical"]);
            return;
        }
        root.ssid = ssid;
        root.password = password;
        root.band = band;
        const wasEnabled = root.enabled;
        // Recreate the profile from scratch so stale settings can't linger.
        const cmd = 'nmcli connection delete "$NAME" 2>/dev/null;'
            + ' nmcli connection add type wifi ifname "$IFACE" con-name "$NAME" autoconnect no ssid "$SSID"'
            + ' 802-11-wireless.mode ap 802-11-wireless.band "$BAND" ipv4.method shared'
            + ' wifi-sec.key-mgmt wpa-psk wifi-sec.psk "$PSK"'
            + (wasEnabled ? ' && nmcli connection up "$NAME"' : '');
        applyProc.exec({
            "environment": {
                "NAME": root.profileName,
                "IFACE": root.iface,
                "SSID": ssid,
                "BAND": band,
                "PSK": password
            },
            "command": ["bash", "-c", cmd]
        });
    }

    // ── QR generation ───────────────────────────────────────────────────────
    function regenerateQr() {
        qrProc.exec({
            "environment": { "PAYLOAD": root.qrPayload, "OUT": root.qrPath },
            "command": ["bash", "-c", 'mkdir -p "$(dirname "$OUT")" && qrencode -t PNG -o "$OUT" -s 10 -m 2 -l M "$PAYLOAD"']
        });
    }

    onQrPayloadChanged: regenerateQr()

    // ── Processes ───────────────────────────────────────────────────────────
    Process {
        id: ifaceProc
        command: ["bash", "-c", "nmcli -t -f DEVICE,TYPE device | awk -F: '$2==\"wifi\"{print $1; exit}'"]
        stdout: StdioCollector {
            onStreamFinished: root.iface = text.trim()
        }
    }

    // Read stored ssid / band / psk from the profile (psk needs -s to be shown).
    Process {
        id: readProc
        command: ["nmcli", "-s", "-g", "802-11-wireless.ssid,802-11-wireless.band,802-11-wireless-security.psk", "connection", "show", root.profileName]
        stdout: StdioCollector {
            onStreamFinished: {
                const lines = text.split("\n");
                if (text.trim().length === 0) { // no such profile
                    root.profileExists = false;
                    return;
                }
                root.profileExists = true;
                if (lines[0] !== undefined && lines[0].length > 0) root.ssid = lines[0];
                if (lines[1] !== undefined && lines[1].length > 0) root.band = lines[1];
                if (lines[2] !== undefined) root.password = lines[2];
            }
        }
    }

    Process {
        id: stateProc
        command: ["nmcli", "-t", "-f", "GENERAL.STATE", "connection", "show", root.profileName]
        stdout: StdioCollector {
            onStreamFinished: root.enabled = text.includes("activated")
        }
    }

    Process {
        id: toggleProc
        onExited: (code, status) => {
            if (code !== 0)
                Quickshell.execDetached(["notify-send", Translation.tr("Hotspot"), Translation.tr("Could not toggle the hotspot."), "-a", "Shell", "-u", "critical"]);
            root.refresh();
        }
    }

    Process {
        id: applyProc
        onExited: (code, status) => {
            if (code !== 0)
                Quickshell.execDetached(["notify-send", Translation.tr("Hotspot"), Translation.tr("Failed to apply hotspot settings."), "-a", "Shell", "-u", "critical"]);
            root.refresh();
        }
    }

    Process {
        id: qrProc
        onExited: (code, status) => {
            if (code === 0)
                root.qrGeneration++;
        }
    }

    // Track NM events so the toggle/state stays live while the dialog is open.
    Process {
        id: monitor
        running: true
        command: ["nmcli", "monitor"]
        stdout: SplitParser {
            onRead: line => {
                if (line.includes(root.profileName) || line.includes("connectivity"))
                    root.refresh();
            }
        }
    }

    // ── Connected clients ────────────────────────────────────────────────────
    // Poll the dnsmasq leases ONLY while the hotspot is up; clear the list when it goes down.
    onEnabledChanged: {
        if (!root.enabled)
            root.clients = [];
        else
            clientsProc.running = true;
    }

    Timer {
        running: root.enabled
        interval: 5000
        repeat: true
        triggeredOnStart: true
        onTriggered: clientsProc.running = true
    }

    Process {
        id: clientsProc
        command: ["bash", "-c", `f="/var/lib/NetworkManager/dnsmasq-${root.iface}.leases"; [ -r "$f" ] && cat "$f" || true`]
        stdout: StdioCollector {
            onStreamFinished: {
                // dnsmasq lease line: "<expiry> <mac> <ip> <hostname> <client-id>". hostname is "*" if unknown.
                const out = [];
                const lines = text.trim().length > 0 ? text.trim().split("\n") : [];
                for (const line of lines) {
                    const f = line.trim().split(/\s+/);
                    if (f.length < 3)
                        continue;
                    const host = (f[3] && f[3] !== "*") ? f[3] : "";
                    out.push({ mac: f[1], ip: f[2], host: host });
                }
                root.clients = out;
            }
        }
    }
}
