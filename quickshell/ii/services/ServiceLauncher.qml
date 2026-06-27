pragma Singleton

import qs.modules.common
import QtQuick
import Quickshell
import Quickshell.Io

/*
 * Service quick-launcher. Holds a configurable list of homelab services
 * ({name, url, icon}) and opens any of them in a browser app-window (Brave if
 * present, falling back to xdg-open). The overlay (ServiceLauncherMenu) shows
 * itself while root.active is true; toggle it via IPC (a keybind).
 * No personal data in-repo — the service list lives in Config (config.json).
 */
Singleton {
    id: root

    property bool active: false

    readonly property var services: Config.options.serviceLauncher.services ?? []

    function open() {
        if (!Config.options.serviceLauncher.enable)
            return;
        root.active = true;
    }
    function close() {
        root.active = false;
    }
    function toggle() {
        if (root.active)
            root.close();
        else
            root.open();
    }

    // Open a service URL in a browser app-window (Brave if present, else xdg-open).
    function launch(url) {
        if (!url || url.length === 0)
            return;
        Quickshell.execDetached(["bash", "-c", `B="$(command -v brave || command -v brave-browser)"; if [ -n "$B" ]; then exec "$B" --app="${url}"; else exec xdg-open "${url}"; fi`]);
        root.close();
    }

    IpcHandler {
        target: "serviceLauncher"
        function open(): void {
            root.open();
        }
        function close(): void {
            root.close();
        }
        function toggle(): void {
            root.toggle();
        }
        function status(): string {
            return `enabled=${Config.options.serviceLauncher.enable} active=${root.active} services=${root.services.length}`;
        }
    }
}
