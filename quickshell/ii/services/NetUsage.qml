pragma Singleton

import qs.modules.common
import qs.modules.common.functions
import QtQuick
import Quickshell
import Quickshell.Io

/*
 * Data-usage + bandwidth meter (metered-hotspot friendly). Polls /proc/net/dev for the
 * configured interface, derives instantaneous rx/tx speed, and keeps a MONTHLY byte total
 * that survives reboots (persisted to disk). Counter resets (reboot / iface flap) are
 * handled by adding the smaller-of (current, current-last). All non-root.
 */
Singleton {
    id: root

    readonly property var cfg: Config.options.netUsage

    // Instantaneous speeds (bytes/s)
    property real rxSpeed: 0
    property real txSpeed: 0

    // Monthly accumulators (bytes)
    property string month: "" // "YYYY-MM"
    property double monthRx: 0
    property double monthTx: 0
    property double _lastRx: -1 // last raw counter reading
    property double _lastTx: -1
    property bool _loaded: false

    // The interface actually being metered. With cfg.iface == "auto" (or empty) this tracks the
    // current default-route interface — Wi-Fi (wlan*/wlp*), Ethernet (eth*/en*), USB tethering
    // (usb*/rndis*), or anything else carrying internet traffic. Otherwise it equals cfg.iface.
    property string activeIface: ""
    property string _lastIface: ""

    readonly property double monthRxGiB: root.monthRx / 1073741824
    readonly property double monthTxGiB: root.monthTx / 1073741824
    readonly property double monthTotalGiB: (root.monthRx + root.monthTx) / 1073741824
    readonly property double capGiB: root.cfg.monthlyCapGiB
    readonly property double capPercent: root.capGiB > 0 ? (root.monthTotalGiB / root.capGiB) * 100 : 0
    readonly property bool overWarn: root.capGiB > 0 && root.capPercent >= root.cfg.warnPercent

    function _curMonth() {
        const d = new Date();
        return `${d.getFullYear()}-${String(d.getMonth() + 1).padStart(2, "0")}`;
    }

    // Humanize a byte/s rate, e.g. "1.2 MB/s".
    function humanRate(bytesPerSec) {
        const u = ["B/s", "KB/s", "MB/s", "GB/s"];
        let v = Math.max(0, bytesPerSec);
        let i = 0;
        while (v >= 1024 && i < u.length - 1) {
            v /= 1024;
            i++;
        }
        return `${v < 10 && i > 0 ? v.toFixed(1) : Math.round(v)} ${u[i]}`;
    }

    // Humanize a GiB total, e.g. "3.4 GiB".
    function humanTotal(gib) {
        if (gib >= 100)
            return `${Math.round(gib)} GiB`;
        if (gib >= 1)
            return `${gib.toFixed(1)} GiB`;
        return `${(gib * 1024).toFixed(0)} MiB`;
    }

    function _save() {
        if (!root._loaded)
            return;
        stateFileView.setText(JSON.stringify({
            "month": root.month,
            "rx": root.monthRx,
            "tx": root.monthTx,
            "lastRx": root._lastRx,
            "lastTx": root._lastTx,
            "iface": root._lastIface
        }));
    }

    function _resetMonth(m) {
        root.month = m;
        root.monthRx = 0;
        root.monthTx = 0;
        // keep _lastRx/_lastTx so the next delta is measured from the current counter
    }

    // Point the meter at `name`. If the interface changed (Wi-Fi → Ethernet, USB tether plugged
    // in, etc.) the per-interface byte counters are unrelated, so drop the stale baseline — the
    // next sample re-baselines instead of registering a bogus delta.
    function _setIface(name) {
        if (name !== root._lastIface) {
            root._lastRx = -1;
            root._lastTx = -1;
            root._lastIface = name;
            root._save();
        }
        root.activeIface = name;
    }

    function _ingest(rawRx, rawTx) {
        const m = root._curMonth();
        if (root.month !== m)
            root._resetMonth(m);

        if (root._lastRx >= 0 && root._lastTx >= 0) {
            const interval = Math.max(1, root.cfg.pollSeconds);
            const dRx = rawRx >= root._lastRx ? (rawRx - root._lastRx) : rawRx; // counter reset => add current
            const dTx = rawTx >= root._lastTx ? (rawTx - root._lastTx) : rawTx;
            root.rxSpeed = dRx / interval;
            root.txSpeed = dTx / interval;
            root.monthRx += dRx;
            root.monthTx += dTx;
        }
        root._lastRx = rawRx;
        root._lastTx = rawTx;
        root._save();
    }

    function refresh() {
        if (!root.cfg.enable)
            return;
        const want = (root.cfg.iface || "").trim();
        if (want === "" || want.toLowerCase() === "auto")
            routeProc.running = true; // resolve the default-route iface, then sample it
        else {
            root._setIface(want);
            readProc.running = true;
        }
    }

    // Parse /proc/net/dev for the configured interface. Fields after the colon:
    //   rx_bytes(0) rx_packets rx_errs rx_drop rx_fifo rx_frame rx_compressed rx_multicast
    //   tx_bytes(8) ...
    Process {
        id: readProc
        command: ["cat", "/proc/net/dev"]
        stdout: StdioCollector {
            onStreamFinished: {
                const iface = root.activeIface;
                if (!iface) {
                    root.rxSpeed = 0;
                    root.txSpeed = 0;
                    return;
                }
                for (const line of text.split("\n")) {
                    const idx = line.indexOf(":");
                    if (idx < 0)
                        continue;
                    if (line.slice(0, idx).trim() !== iface)
                        continue;
                    const f = line.slice(idx + 1).trim().split(/\s+/);
                    const rx = Number(f[0]);
                    const tx = Number(f[8]);
                    if (!isNaN(rx) && !isNaN(tx))
                        root._ingest(rx, tx);
                    return;
                }
                // iface not present this tick: no speed sample
                root.rxSpeed = 0;
                root.txSpeed = 0;
            }
        }
    }

    // Auto interface resolution (cfg.iface == "auto"/empty): ask the kernel which device carries
    // traffic to the internet. This is connection-type agnostic — it follows Wi-Fi, Ethernet, USB
    // tethering, WWAN, etc. as they come and go, instead of a hardcoded wlan0. (Same `ip route get`
    // trick VpnStatus uses.) On success it samples that iface; offline => no sample this tick.
    Process {
        id: routeProc
        command: ["ip", "route", "get", "1.1.1.1"]
        stdout: StdioCollector {
            onStreamFinished: {
                const m = text.match(/\bdev (\S+)/);
                if (m) {
                    root._setIface(m[1]);
                    readProc.running = true;
                } else {
                    root.activeIface = "";
                    root.rxSpeed = 0;
                    root.txSpeed = 0;
                }
            }
        }
    }

    Timer {
        interval: Math.max(1, root.cfg.pollSeconds) * 1000
        repeat: true
        running: Config.ready && root.cfg.enable
        triggeredOnStart: true
        onTriggered: root.refresh()
    }

    FileView {
        id: stateFileView
        path: Qt.resolvedUrl(FileUtils.trimFileProtocol(`${Directories.state}/user/netUsage.json`))
        onLoaded: {
            try {
                const o = JSON.parse(stateFileView.text());
                const m = root._curMonth();
                if (o.month === m) {
                    root.month = o.month;
                    root.monthRx = Number(o.rx) || 0;
                    root.monthTx = Number(o.tx) || 0;
                } else {
                    root._resetMonth(m);
                }
                root._lastRx = (o.lastRx !== undefined) ? Number(o.lastRx) : -1;
                root._lastTx = (o.lastTx !== undefined) ? Number(o.lastTx) : -1;
                root._lastIface = (o.iface !== undefined) ? String(o.iface) : "";
            } catch (e) {
                root._resetMonth(root._curMonth());
            }
            root._loaded = true;
        }
        onLoadFailed: error => {
            if (error === FileViewError.FileNotFound) {
                root._resetMonth(root._curMonth());
                root._loaded = true;
                root._save();
            }
        }
    }

    IpcHandler {
        target: "netUsage"
        function refresh(): void {
            root.refresh();
        }
        function status(): string {
            return `iface=${root.cfg.iface} active=${root.activeIface} down=${root.humanRate(root.rxSpeed)} up=${root.humanRate(root.txSpeed)} month=${root.month} total=${root.monthTotalGiB.toFixed(2)}GiB cap=${root.capGiB}GiB pct=${root.capPercent.toFixed(0)} overWarn=${root.overWarn}`;
        }
    }
}
