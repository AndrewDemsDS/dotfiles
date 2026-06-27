pragma Singleton

import qs.modules.common
import qs.modules.common.functions
import QtQuick
import Quickshell
import Quickshell.Io

/*
 * Home Assistant control service.
 *   - GET  /api/states                  → poll watched entities
 *   - POST /api/services/<domain>/<svc>  → toggle lights/switches, activate scenes
 * Bearer token is read from an UNTRACKED file (~/.config/quickshell/secrets/ha_token).
 * Falls back to Config.options.homeAssistant.fallbackUrl when the primary is unreachable.
 */
Singleton {
    id: root

    readonly property string secretsPath: `${FileUtils.trimFileProtocol(Directories.config)}/quickshell/secrets/ha_token`
    property string token: ""

    function _strip(u) {
        return u.endsWith("/") ? u.slice(0, -1) : u;
    }
    readonly property string baseUrl: _strip(Config.options.homeAssistant.baseUrl)
    readonly property string fallbackUrl: _strip(Config.options.homeAssistant.fallbackUrl)
    readonly property bool configured: root.baseUrl.length > 0 && root.token.length > 0

    property var states: ({}) // entity_id -> { state, attributes }
    property bool online: false
    property bool usingFallback: false
    property bool loading: false

    readonly property string activeUrl: (root.usingFallback && root.fallbackUrl.length > 0) ? root.fallbackUrl : root.baseUrl

    function stateOf(entityId) {
        return root.states[entityId]?.state ?? "unknown";
    }
    function isOn(entityId) {
        const s = root.stateOf(entityId);
        const d = entityId.split(".")[0];
        if (d === "lock")
            return s === "locked";
        if (d === "climate")
            return s !== "off" && s !== "unknown" && s !== "unavailable";
        if (d === "media_player")
            return s === "playing" || s === "on" || s === "paused";
        if (d === "vacuum")
            return s === "cleaning";
        return s === "on";
    }
    function friendlyName(entityId) {
        return root.states[entityId]?.attributes?.friendly_name ?? entityId;
    }
    function attr(entityId, key, fallback) {
        return root.states[entityId]?.attributes?.[key] ?? fallback;
    }

    // --- Sub-controls (driven by the entity's own HA attributes) ---
    function setBrightnessPct(entityId, pct) {
        root.callServiceData("light", "turn_on", {
            "entity_id": entityId,
            "brightness_pct": Math.round(pct)
        });
    }
    function setClimateTemp(entityId, temp) {
        root.callServiceData("climate", "set_temperature", {
            "entity_id": entityId,
            "temperature": temp
        });
    }
    function setHvacMode(entityId, mode) {
        root.callServiceData("climate", "set_hvac_mode", {
            "entity_id": entityId,
            "hvac_mode": mode
        });
    }
    function setFanMode(entityId, mode) {
        root.callServiceData("climate", "set_fan_mode", {
            "entity_id": entityId,
            "fan_mode": mode
        });
    }
    function mediaCommand(entityId, service) {
        root.callService("media_player", service, entityId);
    }
    function setVolume(entityId, level) {
        root.callServiceData("media_player", "volume_set", {
            "entity_id": entityId,
            "volume_level": level
        });
    }
    function selectSource(entityId, source) {
        root.callServiceData("media_player", "select_source", {
            "entity_id": entityId,
            "source": source
        });
    }
    function vacuumCommand(entityId, service) {
        root.callService("vacuum", service, entityId);
    }

    function refresh() {
        if (!Config.options.homeAssistant.enable)
            return;
        if (root.token.length === 0) {
            tokenProc.running = true;
            return;
        }
        if (root.baseUrl.length === 0)
            return;
        root.loading = true;
        _fetchStates(root.baseUrl, false);
    }

    function _fetchStates(url, isFallback) {
        const xhr = new XMLHttpRequest();
        xhr.open("GET", `${url}/api/states`);
        xhr.setRequestHeader("Authorization", `Bearer ${root.token}`);
        xhr.onreadystatechange = function () {
            if (xhr.readyState !== XMLHttpRequest.DONE)
                return;
            if (xhr.status === 200) {
                root.loading = false;
                try {
                    const arr = JSON.parse(xhr.responseText);
                    let m = {};
                    for (const e of arr)
                        m[e.entity_id] = {
                            "state": e.state,
                            "attributes": e.attributes
                        };
                    root.states = m;
                    root.online = true;
                    root.usingFallback = isFallback;
                } catch (e) {
                    console.log("[HomeAssistant] parse failed:", e);
                }
            } else {
                root._failover(isFallback);
            }
        };
        xhr.onerror = function () {
            root._failover(isFallback);
        };
        xhr.send();
    }

    function _failover(wasFallback) {
        if (!wasFallback && root.fallbackUrl.length > 0) {
            root._fetchStates(root.fallbackUrl, true);
        } else {
            root.loading = false;
            root.online = false;
        }
    }

    // Fire a service call with an arbitrary payload (must include entity_id).
    function callServiceData(domain, service, data) {
        if (!root.configured)
            return;
        const xhr = new XMLHttpRequest();
        xhr.open("POST", `${root.activeUrl}/api/services/${domain}/${service}`);
        xhr.setRequestHeader("Authorization", `Bearer ${root.token}`);
        xhr.setRequestHeader("Content-Type", "application/json");
        xhr.onreadystatechange = function () {
            if (xhr.readyState === XMLHttpRequest.DONE)
                root.refresh();
        };
        xhr.send(JSON.stringify(data));
    }

    // Convenience: service call for a single entity (e.g. light.toggle, scene.turn_on).
    function callService(domain, service, entityId) {
        root.callServiceData(domain, service, {
            "entity_id": entityId
        });
    }

    // Smart toggle by domain: scenes/scripts activate, locks lock/unlock, etc.
    function toggleEntity(entityId) {
        const d = entityId.split(".")[0];
        if (d === "scene" || d === "script")
            root.callService(d, "turn_on", entityId);
        else if (d === "button")
            root.callService(d, "press", entityId);
        else if (d === "lock")
            root.callService(d, root.isOn(entityId) ? "unlock" : "lock", entityId);
        else if (d === "climate")
            root.callService(d, root.isOn(entityId) ? "turn_off" : "turn_on", entityId);
        else if (d === "vacuum")
            root.callService(d, root.isOn(entityId) ? "return_to_base" : "start", entityId);
        else
            root.callService(d, "toggle", entityId);
    }

    // Open the configured Lovelace dashboard in a browser app-window (Brave if present).
    function openDashboard() {
        if (root.baseUrl.length === 0)
            return;
        const url = `${root.baseUrl}/${Config.options.homeAssistant.dashboardPath}`;
        Quickshell.execDetached(["bash", "-c", `B="$(command -v brave || command -v brave-browser)"; if [ -n "$B" ]; then exec "$B" --app="${url}"; else exec xdg-open "${url}"; fi`]);
    }

    Process {
        id: tokenProc
        running: true
        command: ["cat", root.secretsPath]
        stdout: StdioCollector {
            onStreamFinished: {
                root.token = text.trim();
                if (root.token.length > 0)
                    root.refresh();
            }
        }
    }

    Timer {
        interval: Math.max(2, Config.options.homeAssistant.pollSeconds) * 1000
        repeat: true
        running: Config.ready && Config.options.homeAssistant.enable
        triggeredOnStart: true
        onTriggered: root.refresh()
    }

    IpcHandler {
        target: "homeAssistant"
        function refresh(): void {
            root.refresh();
        }
        function status(): string {
            return `configured=${root.configured} online=${root.online} fallback=${root.usingFallback} entities=${Object.keys(root.states).length}`;
        }
        function dashboard(): void {
            root.openDashboard();
        }
        function toggle(entityId: string): void {
            root.toggleEntity(entityId);
        }
    }
}
