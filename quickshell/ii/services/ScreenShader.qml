pragma Singleton
pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Io

import qs.modules.common
import qs.modules.common.models.hyprland

/*
 * Applies a GLSL screen shader via decoration:screen_shader, the same path the
 * anti-flashbang shader uses. HyprlandConfig.setMany writes the override to the
 * Lua config, so the shader survives Hyprland reloads and reboots; resetMany
 * removes it. State is read back reactively from `hyprctl getoption`.
 *
 * Only one screen_shader can be active at a time, so this and the anti-flashbang
 * toggle are mutually exclusive (last write wins). No printer/host names here, so
 * it stays publication-safe.
 */
Singleton {
    id: root

    readonly property string defaultShaderPath: Quickshell.shellPath("services/screenShader/bluelight.glsl")
    // Empty config path falls back to the bundled blue-light shader.
    readonly property string shaderPath: Config.options.light.shader.path.length > 0 ? Config.options.light.shader.path : root.defaultShaderPath
    readonly property bool active: confOpt.value === root.shaderPath

    function apply() {
        if (!Config.options.light.shader.enable)
            return;
        HyprlandConfig.setMany({
            "decoration:screen_shader": root.shaderPath
        });
    }
    function clear() {
        HyprlandConfig.resetMany(["decoration:screen_shader"]);
    }
    function toggle() {
        if (root.active)
            root.clear();
        else
            root.apply();
    }

    // Honour the master switch: turning the feature off clears our active shader.
    Connections {
        target: Config.options.light.shader
        function onEnableChanged() {
            if (!Config.options.light.shader.enable && root.active)
                root.clear();
        }
    }

    HyprlandConfigOption {
        id: confOpt
        key: "decoration:screen_shader"
    }

    IpcHandler {
        target: "screenShader"
        function status(): string {
            return `enabled=${Config.options.light.shader.enable} active=${root.active} path=${root.shaderPath}`;
        }
        function toggle(): void {
            root.toggle();
        }
        function apply(): void {
            root.apply();
        }
        function clear(): void {
            root.clear();
        }
    }
}
