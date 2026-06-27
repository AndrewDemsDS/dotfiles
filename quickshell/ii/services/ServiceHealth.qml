pragma Singleton

import qs.modules.common
import qs.services
import QtQuick
import Quickshell
import Quickshell.Io

/*
 * Service health board. For each configured service {name, url} it does a lightweight
 * XHR GET (HEAD-like, short timeout) and marks it up when a response comes back with a
 * non-server-error status. Exposes a model [{name, url, up, lastStatus}] plus up/total
 * counts. Services + an optional Uptime-Kuma URL come from config (no personal data in-repo).
 */
Singleton {
    id: root

    readonly property var cfg: Config.options.serviceHealth
    property var model: [] // [{name, url, up, lastStatus}]
    property bool checking: false

    readonly property int total: root.model.length
    readonly property int upCount: {
        let n = 0;
        for (const s of root.model)
            if (s.up)
                n++;
        return n;
    }
    readonly property bool allUp: root.total > 0 && root.upCount === root.total
    readonly property bool hasData: root.total > 0

    function _normalize() {
        // Seed the model from config so rows render before the first probe completes.
        const services = root.cfg.services ?? [];
        let next = [];
        for (const s of services) {
            const url = (s.url ?? "").toString().trim();
            if (url.length === 0)
                continue;
            const name = (s.name ?? "").toString().trim();
            const prev = root.model.find(m => m.url === url);
            next.push({
                "name": name.length > 0 ? name : url,
                "url": url,
                "up": prev ? prev.up : false,
                "lastStatus": prev ? prev.lastStatus : -1
            });
        }
        root.model = next;
    }

    function _setResult(url, up, status) {
        let next = [];
        for (const m of root.model) {
            if (m.url === url)
                next.push({
                    "name": m.name,
                    "url": m.url,
                    "up": up,
                    "lastStatus": status
                });
            else
                next.push(m);
        }
        root.model = next; // new array => bindings update
    }

    function refresh() {
        if (!root.cfg.enable)
            return;
        root._normalize();
        if (root.model.length === 0)
            return;
        root.checking = true;
        for (const s of root.model)
            root._probe(s.url);
    }

    function _probe(url) {
        const xhr = new XMLHttpRequest();
        let settled = false;
        const done = function (up, status) {
            if (settled)
                return;
            settled = true;
            root._setResult(url, up, status);
            root.checking = false;
        };
        try {
            xhr.open("GET", url);
            xhr.timeout = 5000;
            xhr.onreadystatechange = function () {
                if (xhr.readyState !== XMLHttpRequest.DONE)
                    return;
                // status 0 = network/TLS error or blocked; >=500 = server error.
                const status = xhr.status;
                done(status > 0 && status < 500, status);
            };
            xhr.ontimeout = function () {
                done(false, 0);
            };
            xhr.onerror = function () {
                done(false, 0);
            };
            xhr.send();
        } catch (e) {
            done(false, 0);
        }
    }

    Timer {
        interval: Math.max(10, root.cfg.pollSeconds) * 1000
        repeat: true
        running: Config.ready && Config.options.serviceHealth.enable
        triggeredOnStart: true
        onTriggered: root.refresh()
    }

    IpcHandler {
        target: "serviceHealth"
        function refresh(): void {
            root.refresh();
        }
        function status(): string {
            let parts = [];
            for (const s of root.model)
                parts.push(`${s.name}=${s.up ? "up" : "down"}(${s.lastStatus})`);
            return `up=${root.upCount}/${root.total} kuma=${root.cfg.kumaUrl} ${parts.join(" ")}`;
        }
    }
}
