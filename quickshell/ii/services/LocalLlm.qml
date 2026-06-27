pragma Singleton

import qs.modules.common
import qs.modules.common.functions
import QtQuick
import Quickshell
import Quickshell.Io

/*
 * System-wide local-LLM text actions. Captures the primary selection (wl-paste --primary)
 * and runs an action (Explain / Summarize / Refactor / Rephrase / Translate / Answer) on a
 * LOCAL Ollama instance only — nothing leaves the machine. Triggered via IPC (a keybind).
 */
Singleton {
    id: root

    property bool active: false
    property string selection: ""
    property string action: ""
    property string result: ""
    property bool loading: false
    property var models: []

    readonly property var actions: [
        {
            "key": "explain",
            "label": "Explain",
            "icon": "lightbulb",
            "prompt": "Explain the following clearly and concisely:\n\n%1"
        },
        {
            "key": "summarize",
            "label": "Summarize",
            "icon": "summarize",
            "prompt": "Summarize the following:\n\n%1"
        },
        {
            "key": "refactor",
            "label": "Refactor",
            "icon": "code",
            "prompt": "Improve/refactor the following; return only the result:\n\n%1"
        },
        {
            "key": "rephrase",
            "label": "Rephrase",
            "icon": "edit_note",
            "prompt": "Rephrase the following more clearly; return only the result:\n\n%1"
        },
        {
            "key": "translate",
            "label": "Translate",
            "icon": "translate",
            "prompt": "Translate the following to English; return only the translation:\n\n%1"
        },
        {
            "key": "answer",
            "label": "Answer",
            "icon": "quiz",
            "prompt": "%1"
        }
    ]

    // localhost-only guard
    readonly property string baseUrl: {
        const u = Config.options.localLlm.baseUrl;
        return (u.indexOf("localhost") !== -1 || u.indexOf("127.0.0.1") !== -1) ? u : "http://localhost:11434";
    }
    readonly property string model: Config.options.localLlm.model.length > 0 ? Config.options.localLlm.model : (root.models.length > 0 ? root.models[0] : "")

    function open() {
        if (!Config.options.localLlm.enable)
            return;
        modelsProc.running = true;
        selProc.running = true;
    }
    function close() {
        root.active = false;
        root.result = "";
        root.action = "";
    }
    function toggle() {
        if (root.active)
            root.close();
        else
            root.open();
    }

    function runAction(key) {
        const a = root.actions.find(x => x.key === key);
        if (!a || root.selection.length === 0)
            return;
        root.action = a.label;
        root.result = "";
        root.loading = true;
        const prompt = a.prompt.arg(root.selection);
        const xhr = new XMLHttpRequest();
        xhr.open("POST", `${root.baseUrl}/api/generate`);
        xhr.setRequestHeader("Content-Type", "application/json");
        xhr.onreadystatechange = function () {
            if (xhr.readyState !== XMLHttpRequest.DONE)
                return;
            root.loading = false;
            if (xhr.status === 200) {
                try {
                    root.result = (JSON.parse(xhr.responseText).response ?? "").trim();
                } catch (e) {
                    root.result = Translation.tr("Could not parse the model response.");
                }
            } else {
                root.result = Translation.tr("Ollama request failed (is it running on %1?).").arg(root.baseUrl);
            }
        };
        xhr.send(JSON.stringify({
            "model": root.model,
            "prompt": prompt,
            "stream": false
        }));
    }

    Process {
        id: selProc
        command: ["wl-paste", "--primary", "--no-newline"]
        stdout: StdioCollector {
            onStreamFinished: {
                root.selection = text;
                root.result = "";
                root.action = "";
                root.active = true;
            }
        }
    }

    Process {
        id: modelsProc
        command: ["bash", "-c", `curl -s ${root.baseUrl}/api/tags`]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    root.models = (JSON.parse(text).models ?? []).map(m => m.name);
                } catch (e) {
                    root.models = [];
                }
            }
        }
    }

    IpcHandler {
        target: "localLlm"
        function open(): void {
            root.open();
        }
        function close(): void {
            root.close();
        }
        function toggle(): void {
            root.toggle();
        }
    }
}
