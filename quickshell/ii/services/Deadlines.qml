pragma Singleton

import qs.modules.common
import qs.modules.common.functions
import qs.services
import QtQuick
import Quickshell
import Quickshell.Io

/*
 * Deadline tracker. Reads a list of {name, due "YYYY-MM-DD" or ISO} from
 * Config.options.deadlines.items, computes daysLeft/overdue/soon for each, sorts by
 * due date, and exposes the next/soonest. Polls hourly to refresh and nags once per day
 * (notify-send) when something is soon or overdue (last-nagged date persisted to disk).
 *
 * Optional focus DND: while a Pomodoro focus lap is running (TimerService), drive the
 * existing notifications Do-Not-Disturb flag (Notifications.silent) so a focus session
 * silences popups; released when focus ends. No personal data lives in this file.
 */
Singleton {
    id: root

    readonly property var cfg: Config.options.deadlines
    property var entries: [] // [{name, due, ms, daysLeft, overdue, soon}]
    property string lastNagged: ""

    readonly property var next: root.entries.length > 0 ? root.entries[0] : null
    readonly property string nextName: root.next ? root.next.name : ""
    readonly property int nextDaysLeft: root.next ? root.next.daysLeft : 0
    readonly property int soonCount: {
        let n = 0;
        for (const e of root.entries)
            if (e.soon || e.overdue)
                n++;
        return n;
    }
    readonly property bool hasData: root.entries.length > 0

    function _todayStr() {
        return new Date().toISOString().slice(0, 10);
    }

    // Midnight-aligned day count so "due today" reads 0 regardless of time of day.
    function _daysBetween(dueMs) {
        const now = new Date();
        const todayMid = new Date(now.getFullYear(), now.getMonth(), now.getDate()).getTime();
        const due = new Date(dueMs);
        const dueMid = new Date(due.getFullYear(), due.getMonth(), due.getDate()).getTime();
        return Math.round((dueMid - todayMid) / 86400000);
    }

    function refresh() {
        if (!root.cfg.enable)
            return;
        const items = root.cfg.items ?? [];
        const soonDays = root.cfg.soonDays;
        let out = [];
        for (const it of items) {
            if (!it || !it.due)
                continue;
            const ms = Date.parse(it.due);
            if (isNaN(ms))
                continue;
            const daysLeft = root._daysBetween(ms);
            out.push({
                "name": (it.name && it.name.length > 0) ? it.name : Translation.tr("(unnamed)"),
                "due": it.due,
                "ms": ms,
                "daysLeft": daysLeft,
                "overdue": daysLeft < 0,
                "soon": daysLeft >= 0 && daysLeft <= soonDays
            });
        }
        out.sort((a, b) => a.ms - b.ms);
        root.entries = out;
        root._maybeNag();
    }

    function _maybeNag() {
        if (root.soonCount <= 0)
            return;
        const today = root._todayStr();
        if (root.lastNagged === today)
            return;
        let urgent = [];
        for (const e of root.entries) {
            if (e.overdue)
                urgent.push(Translation.tr("%1 — overdue").arg(e.name));
            else if (e.soon)
                urgent.push(e.daysLeft === 0 ? Translation.tr("%1 — due today").arg(e.name) : Translation.tr("%1 — in %2d").arg(e.name).arg(e.daysLeft));
        }
        if (urgent.length === 0)
            return;
        Quickshell.execDetached(["notify-send", Translation.tr("Upcoming deadlines"), urgent.join("\n"), "-u", "normal", "-a", "Shell"]);
        root.lastNagged = today;
        stateFileView.setText(JSON.stringify({
            "lastNagged": today
        }));
    }

    // --- Focus DND: silence notifications during a Pomodoro focus lap ---
    property bool _dndForcedByUs: false
    function _applyFocusDnd() {
        if (!root.cfg.enable || !root.cfg.dndOnFocus)
            return;
        const focusing = TimerService.pomodoroRunning && !TimerService.pomodoroBreak;
        if (focusing && !Notifications.silent) {
            Notifications.silent = true;
            root._dndForcedByUs = true;
        } else if (!focusing && root._dndForcedByUs) {
            Notifications.silent = false;
            root._dndForcedByUs = false;
        }
    }

    Connections {
        target: TimerService
        function onPomodoroRunningChanged() {
            root._applyFocusDnd();
        }
        function onPomodoroBreakChanged() {
            root._applyFocusDnd();
        }
    }

    Timer {
        interval: 3600000 // hourly
        repeat: true
        running: Config.ready && Config.options.deadlines.enable
        triggeredOnStart: true
        onTriggered: root.refresh()
    }

    // Recompute when the configured list changes (live editing in Settings).
    Connections {
        target: Config.options.deadlines
        function onItemsChanged() {
            root.refresh();
        }
        function onSoonDaysChanged() {
            root.refresh();
        }
    }

    FileView {
        id: stateFileView
        path: Qt.resolvedUrl(FileUtils.trimFileProtocol(`${Directories.state}/user/deadlines.json`))
        onLoaded: {
            try {
                const o = JSON.parse(stateFileView.text());
                root.lastNagged = o.lastNagged ?? "";
            } catch (e) {}
        }
        onLoadFailed: error => {
            if (error === FileViewError.FileNotFound)
                stateFileView.setText("{}");
        }
    }

    IpcHandler {
        target: "deadlines"
        function refresh(): void {
            root.refresh();
        }
        function status(): string {
            return `enabled=${root.cfg.enable} count=${root.entries.length} soon=${root.soonCount} next=${root.nextName} nextDays=${root.nextDaysLeft} dnd=${Notifications.silent}`;
        }
    }
}
