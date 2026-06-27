pragma Singleton

import qs.modules.common
import QtQuick
import Quickshell
import Quickshell.Io

/*
 * Class timetable / next-class service. Reads a local weekly schedule file at
 * Config.options.timetable.schedulePath and computes the next upcoming class from now.
 * Two formats are supported by file extension:
 *   .json — array of {title, room, day, start "HH:MM", end "HH:MM"} weekly recurring,
 *           where day is 0=Sun..6=Sat OR "Sun".."Sat" / "Mon".."Sun".
 *   .ics  — VEVENT blocks (SUMMARY, LOCATION, DTSTART) parsed with a basic line walk.
 * All paths come from config (no personal data in-repo).
 */
Singleton {
    id: root

    readonly property string schedulePath: Config.options.timetable.schedulePath

    // Next upcoming class (computed in _recompute).
    property string nextTitle: ""
    property string nextRoom: ""
    property var nextStart: null   // Date, or null
    property int minutesUntil: -1
    property bool ongoing: false
    readonly property bool hasNext: root.nextTitle.length > 0 && root.nextStart !== null

    // Parsed events: weekly = [{title, room, day(0-6), startMin, endMin}],
    // dated (.ics) = [{title, room, startMs, endMs}].
    property var _weekly: []
    property var _dated: []
    property bool _isIcs: false

    readonly property var _dayNames: ({
            "sun": 0,
            "mon": 1,
            "tue": 2,
            "wed": 3,
            "thu": 4,
            "fri": 5,
            "sat": 6
        })

    function _dayIndex(day) {
        if (typeof day === "number")
            return ((day % 7) + 7) % 7;
        const s = String(day).trim().toLowerCase().slice(0, 3);
        return root._dayNames[s] ?? -1;
    }

    function _hhmmToMin(s) {
        const m = String(s).match(/(\d{1,2}):(\d{2})/);
        if (!m)
            return -1;
        return parseInt(m[1]) * 60 + parseInt(m[2]);
    }

    function refresh() {
        if (!Config.options.timetable.enable || root.schedulePath.length === 0) {
            root._clear();
            return;
        }
        readProc.command = ["bash", "-c", `cat "${root.schedulePath.replace(/^~/, "$HOME")}"`];
        readProc.running = true;
    }

    function _clear() {
        root.nextTitle = "";
        root.nextRoom = "";
        root.nextStart = null;
        root.minutesUntil = -1;
        root.ongoing = false;
    }

    function _parse(text) {
        const lower = root.schedulePath.toLowerCase();
        root._isIcs = lower.endsWith(".ics");
        if (root._isIcs)
            root._parseIcs(text);
        else
            root._parseJson(text);
        root._recompute();
    }

    function _parseJson(text) {
        let weekly = [];
        try {
            const arr = JSON.parse(text);
            if (Array.isArray(arr)) {
                for (const e of arr) {
                    const day = root._dayIndex(e.day);
                    const startMin = root._hhmmToMin(e.start ?? "");
                    if (day < 0 || startMin < 0)
                        continue;
                    let endMin = root._hhmmToMin(e.end ?? "");
                    if (endMin < 0)
                        endMin = startMin + 60;
                    weekly.push({
                        "title": String(e.title ?? "Class"),
                        "room": String(e.room ?? ""),
                        "day": day,
                        "startMin": startMin,
                        "endMin": endMin
                    });
                }
            }
        } catch (e) {
            console.log("[Timetable] JSON parse failed:", e);
        }
        root._weekly = weekly;
        root._dated = [];
    }

    function _icsDateToMs(val) {
        // DTSTART forms: 20260625T093000 / 20260625T093000Z / 20260625 (all-day).
        const m = String(val).match(/(\d{4})(\d{2})(\d{2})(?:T(\d{2})(\d{2})(\d{2})?(Z)?)?/);
        if (!m)
            return NaN;
        const y = parseInt(m[1]), mo = parseInt(m[2]) - 1, d = parseInt(m[3]);
        const hh = m[4] ? parseInt(m[4]) : 0;
        const mm = m[5] ? parseInt(m[5]) : 0;
        const ss = m[6] ? parseInt(m[6]) : 0;
        if (m[7] === "Z")
            return Date.UTC(y, mo, d, hh, mm, ss);
        return new Date(y, mo, d, hh, mm, ss).getTime();
    }

    function _parseIcs(text) {
        let dated = [];
        const lines = text.split(/\r?\n/);
        let cur = null;
        for (const raw of lines) {
            const line = raw.trim();
            if (line === "BEGIN:VEVENT") {
                cur = {
                    "title": "",
                    "room": "",
                    "startMs": NaN,
                    "endMs": NaN
                };
            } else if (line === "END:VEVENT") {
                if (cur && cur.title.length > 0 && !isNaN(cur.startMs)) {
                    if (isNaN(cur.endMs))
                        cur.endMs = cur.startMs + 3600000;
                    dated.push(cur);
                }
                cur = null;
            } else if (cur) {
                const ci = line.indexOf(":");
                if (ci < 0)
                    continue;
                const key = line.slice(0, ci).toUpperCase();
                const val = line.slice(ci + 1);
                if (key === "SUMMARY")
                    cur.title = val;
                else if (key === "LOCATION")
                    cur.room = val;
                else if (key.startsWith("DTSTART"))
                    cur.startMs = root._icsDateToMs(val);
                else if (key.startsWith("DTEND"))
                    cur.endMs = root._icsDateToMs(val);
            }
        }
        root._dated = dated;
        root._weekly = [];
    }

    // Find the next upcoming (or currently-ongoing) class relative to now.
    function _recompute() {
        const now = new Date();
        if (root._isIcs)
            root._recomputeDated(now);
        else
            root._recomputeWeekly(now);
    }

    function _recomputeDated(now) {
        const nowMs = now.getTime();
        let best = null;
        for (const e of root._dated) {
            // Skip events already finished.
            if (e.endMs <= nowMs)
                continue;
            if (best === null || e.startMs < best.startMs)
                best = e;
        }
        if (best === null) {
            root._clear();
            return;
        }
        const start = new Date(best.startMs);
        const ongoing = best.startMs <= nowMs && nowMs < best.endMs;
        root._set(best.title, best.room, start, ongoing, nowMs);
    }

    function _recomputeWeekly(now) {
        const nowMin = now.getHours() * 60 + now.getMinutes();
        const nowDay = now.getDay(); // 0=Sun..6=Sat
        let best = null; // {offsetMin, title, room, startMin, day, ongoing}
        for (const e of root._weekly) {
            // Minutes from now until this weekly slot's next occurrence.
            let dayDelta = (e.day - nowDay + 7) % 7;
            let offset = dayDelta * 1440 + (e.startMin - nowMin);
            let ongoing = false;
            if (dayDelta === 0 && e.startMin <= nowMin) {
                if (nowMin < e.endMin) {
                    // currently ongoing — treat as the immediate "next"
                    offset = nowMin - e.startMin <= 0 ? 0 : -(nowMin - e.startMin);
                    ongoing = true;
                } else {
                    // already over today → next week
                    offset += 7 * 1440;
                }
            }
            if (best === null || offset < best.offset)
                best = {
                    "offset": offset,
                    "title": e.title,
                    "room": e.room,
                    "startMin": e.startMin,
                    "day": e.day,
                    "ongoing": ongoing
                };
        }
        if (best === null) {
            root._clear();
            return;
        }
        // Build a concrete Date for the next start.
        const start = new Date(now.getTime());
        let dayDelta = (best.day - nowDay + 7) % 7;
        if (dayDelta === 0 && !best.ongoing && best.startMin <= nowMin)
            dayDelta = 7;
        start.setDate(start.getDate() + dayDelta);
        start.setHours(Math.floor(best.startMin / 60), best.startMin % 60, 0, 0);
        root._set(best.title, best.room, start, best.ongoing, now.getTime());
    }

    function _set(title, room, start, ongoing, nowMs) {
        root.nextTitle = title;
        root.nextRoom = room;
        root.nextStart = start;
        root.ongoing = ongoing;
        root.minutesUntil = ongoing ? 0 : Math.max(0, Math.round((start.getTime() - nowMs) / 60000));
    }

    function countdownText() {
        if (!root.hasNext)
            return "";
        if (root.ongoing)
            return Translation.tr("%1 now").arg(root.nextTitle);
        const m = root.minutesUntil;
        if (m < 60)
            return Translation.tr("%1 in %2m").arg(root.nextTitle).arg(m);
        const h = Math.floor(m / 60);
        const rem = m % 60;
        return rem > 0 ? Translation.tr("%1 in %2h%3m").arg(root.nextTitle).arg(h).arg(rem) : Translation.tr("%1 in %2h").arg(root.nextTitle).arg(h);
    }

    Process {
        id: readProc
        stdout: StdioCollector {
            onStreamFinished: root._parse(text)
        }
        onExited: (code, status) => {
            if (code !== 0)
                root._clear();
        }
    }

    // Re-evaluate periodically so the countdown stays fresh (and re-reads the file).
    Timer {
        interval: Math.max(15, Config.options.timetable.pollSeconds) * 1000
        repeat: true
        running: Config.ready && Config.options.timetable.enable
        triggeredOnStart: true
        onTriggered: root.refresh()
    }

    IpcHandler {
        target: "timetable"
        function refresh(): void {
            root.refresh();
        }
        function status(): string {
            return root.hasNext ? `next="${root.nextTitle}" room="${root.nextRoom}" inMin=${root.minutesUntil} ongoing=${root.ongoing}` : "none";
        }
    }
}
