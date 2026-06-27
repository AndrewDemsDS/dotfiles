pragma Singleton

import qs.modules.common
import qs.services
import QtQuick
import Quickshell
import Quickshell.Io

/*
 * CUPS printer integration. Polls `lpstat` for the default destination, printer
 * states and the active job queue, and exposes actions (cancel, set-default, print
 * clipboard, open the CUPS web UI). No printer names/hosts are hardcoded — everything
 * is discovered from lpstat at runtime, so this stays publication-safe.
 */
Singleton {
    id: root

    property string defaultPrinter: ""
    property var printers: []  // [{name, state, enabled}]
    property var jobs: []      // [{id, printer, user, when}]
    readonly property int jobCount: root.jobs.length
    readonly property bool hasError: {
        for (const p of root.printers) {
            if (!p.enabled || p.state === "disabled")
                return true;
        }
        if (root.defaultPrinter.length > 0) {
            for (const p of root.printers) {
                if (p.name === root.defaultPrinter && (!p.enabled || p.state === "disabled"))
                    return true;
            }
        }
        return false;
    }

    property bool dialogOpen: false

    function open() {
        if (!Config.options.printer.enable)
            return;
        root.dialogOpen = true;
        root.refresh();
    }
    function close() {
        root.dialogOpen = false;
    }
    function toggle() {
        if (root.dialogOpen)
            root.close();
        else
            root.open();
    }

    function refresh() {
        proc.running = true;
    }

    function cancelJob(id) {
        if (!id || id.length === 0)
            return;
        Quickshell.execDetached(["cancel", id]);
        root.refresh();
    }
    function cancelAll() {
        Quickshell.execDetached(["cancel", "-a"]);
        root.refresh();
    }
    function setDefault(name) {
        if (!name || name.length === 0)
            return;
        Quickshell.execDetached(["lpoptions", "-d", name]);
        root.refresh();
    }
    function printClipboard() {
        if (root.defaultPrinter.length === 0)
            return;
        Quickshell.execDetached(["bash", "-c", `wl-paste --no-newline | lp ${root.defaultPrinter.length > 0 ? "-d " + root.defaultPrinter : ""}`]);
    }
    function openQueue() {
        const cmd = Config.options.printer.queueCommand;
        if (cmd && cmd.length > 0) {
            Quickshell.execDetached(cmd.split(" "));
            return;
        }
        const url = "http://localhost:631/jobs/";
        Quickshell.execDetached(["bash", "-c", `B="$(command -v brave || command -v brave-browser)"; if [ -n "$B" ]; then exec "$B" --app="${url}"; else exec xdg-open "${url}"; fi`]);
    }

    Process {
        id: proc
        command: ["bash", "-c", "echo @@DEFAULT; lpstat -d 2>/dev/null; echo @@PRINTERS; lpstat -p 2>/dev/null; echo @@JOBS; lpstat -o 2>/dev/null"]
        stdout: StdioCollector {
            onStreamFinished: {
                let section = "";
                let def = "";
                const printers = [];
                const jobs = [];
                for (const raw of text.split("\n")) {
                    const line = raw.replace(/\r$/, "");
                    if (line.startsWith("@@DEFAULT")) {
                        section = "default";
                        continue;
                    } else if (line.startsWith("@@PRINTERS")) {
                        section = "printers";
                        continue;
                    } else if (line.startsWith("@@JOBS")) {
                        section = "jobs";
                        continue;
                    }
                    if (line.trim().length === 0)
                        continue;

                    if (section === "default") {
                        const i = line.indexOf("destination:");
                        if (i >= 0)
                            def = line.slice(i + "destination:".length).trim();
                        // "no system default destination" → leave def empty
                    } else if (section === "printers") {
                        // "printer <name> is idle.  enabled since ..."
                        // "printer <name> disabled since ..."
                        const m = line.match(/^printer\s+(\S+)\s+(is\s+(\S+?)\.?|disabled)/);
                        if (m) {
                            const name = m[1];
                            let state = "idle";
                            let enabled = true;
                            if (m[2].startsWith("disabled") || / disabled /.test(line)) {
                                state = "disabled";
                                enabled = false;
                            } else if (m[3]) {
                                state = m[3].replace(/\.$/, "");
                            }
                            printers.push({
                                "name": name,
                                "state": state,
                                "enabled": enabled
                            });
                        }
                    } else if (section === "jobs") {
                        // "<printer>-<n>  user  size  date"
                        const f = line.trim().split(/\s+/);
                        const id = f[0] ?? "";
                        if (id.length === 0)
                            continue;
                        const dash = id.lastIndexOf("-");
                        const printer = dash > 0 ? id.slice(0, dash) : id;
                        jobs.push({
                            "id": id,
                            "printer": printer,
                            "user": f[1] ?? "",
                            "when": f.slice(3).join(" ")
                        });
                    }
                }
                root.defaultPrinter = def;
                root.printers = printers;
                root.jobs = jobs;
            }
        }
    }

    Timer {
        interval: Math.max(5, Config.options.printer.pollSeconds) * 1000
        repeat: true
        triggeredOnStart: true
        running: Config.ready && Config.options.printer.enable
        onTriggered: root.refresh()
    }

    IpcHandler {
        target: "printer"
        function status(): string {
            return `default=${root.defaultPrinter} printers=${root.printers.length} jobs=${root.jobCount} error=${root.hasError}`;
        }
        function open(): void {
            root.open();
        }
        function close(): void {
            root.close();
        }
        function toggle(): void {
            root.toggle();
        }
        function cancelAll(): void {
            root.cancelAll();
        }
        function refresh(): void {
            root.refresh();
        }
    }
}
