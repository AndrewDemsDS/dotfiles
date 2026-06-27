pragma Singleton

import qs.modules.common
import qs.modules.common.functions
import qs.services
import QtQuick
import Quickshell
import Quickshell.Io

/*
 * Live mini-graph service. Every pollSeconds it samples each configured Home Assistant
 * sensor (via the existing HomeAssistant singleton — no re-auth) into a fixed-length ring
 * buffer, exposing a model the sidebar sparkline card renders. History persists to disk
 * so the graph survives a shell reload. Entities come from
 * Config.options.sensorSparkline.entities [{name, entity, unit}].
 */
Singleton {
    id: root

    readonly property var cfg: Config.options.sensorSparkline
    readonly property int samples: Math.max(2, root.cfg.samples)

    // entity_id -> [numbers] (ring buffer, newest last)
    property var buffers: ({})

    // Exposed model: [{name, unit, entity, current, min, max, series:[numbers]}]
    property var model: []

    function _seriesStats(series) {
        let lo = Infinity, hi = -Infinity;
        for (const v of series) {
            if (v < lo)
                lo = v;
            if (v > hi)
                hi = v;
        }
        if (!isFinite(lo)) {
            lo = 0;
            hi = 0;
        }
        return {
            "min": lo,
            "max": hi
        };
    }

    function _rebuildModel() {
        let out = [];
        for (const e of (root.cfg.entities ?? [])) {
            const entity = e.entity ?? "";
            if (entity.length === 0)
                continue;
            const series = root.buffers[entity] ?? [];
            const stats = root._seriesStats(series);
            out.push({
                "name": e.name && e.name.length > 0 ? e.name : entity,
                "unit": e.unit ?? "",
                "entity": entity,
                "current": series.length > 0 ? series[series.length - 1] : NaN,
                "min": stats.min,
                "max": stats.max,
                "series": series
            });
        }
        root.model = out;
    }

    function refresh() {
        if (!root.cfg.enable)
            return;
        let bufs = Object.assign({}, root.buffers);
        // Drop buffers for entities that are no longer configured.
        const wanted = {};
        for (const e of (root.cfg.entities ?? [])) {
            const entity = e.entity ?? "";
            if (entity.length === 0)
                continue;
            wanted[entity] = true;
            const v = Number(HomeAssistant.stateOf(entity));
            let series = (bufs[entity] ?? []).slice();
            if (!isNaN(v)) {
                series.push(v);
                while (series.length > root.samples)
                    series.shift();
            }
            bufs[entity] = series;
        }
        for (const key of Object.keys(bufs))
            if (!wanted[key])
                delete bufs[key];
        root.buffers = bufs;
        root._rebuildModel();
        historyFileView.setText(JSON.stringify(bufs));
    }

    Timer {
        interval: Math.max(2, root.cfg.pollSeconds) * 1000
        repeat: true
        running: Config.ready && root.cfg.enable
        triggeredOnStart: true
        onTriggered: root.refresh()
    }

    FileView {
        id: historyFileView
        path: Qt.resolvedUrl(FileUtils.trimFileProtocol(`${Directories.state}/user/sensorSparkline.json`))
        onLoaded: {
            try {
                const m = JSON.parse(historyFileView.text());
                if (m && typeof m === "object") {
                    root.buffers = m;
                    root._rebuildModel();
                }
            } catch (e) {}
        }
        onLoadFailed: error => {
            if (error === FileViewError.FileNotFound)
                historyFileView.setText("{}");
        }
    }

    IpcHandler {
        target: "sensorSparkline"
        function refresh(): void {
            root.refresh();
        }
        function status(): string {
            return `enable=${root.cfg.enable} sensors=${root.model.length} samples=${root.samples}`;
        }
    }
}
