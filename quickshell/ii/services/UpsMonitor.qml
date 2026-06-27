pragma Singleton

import qs.modules.common
import qs.services
import QtQuick
import Quickshell
import Quickshell.Io

/*
 * Homelab UPS/battery HUD. Sources from Home Assistant (the BMS is exposed as
 * the configured battery sensors), so no MQTT credentials are needed. Detects "on battery"
 * sign-agnostically (not charging AND drawing current) and notifies on mains loss/restore.
 */
Singleton {
    id: root

    function _num(entity) {
        const v = Number(HomeAssistant.stateOf(entity));
        return isNaN(v) ? 0 : v;
    }

    readonly property int soc: Math.round(_num(Config.options.upsMonitor.batteryEntity))
    readonly property bool charging: HomeAssistant.stateOf(Config.options.upsMonitor.chargingEntity) === "on"
    readonly property real power: _num(Config.options.upsMonitor.powerEntity)
    readonly property real current: _num(Config.options.upsMonitor.currentEntity)
    readonly property real voltage: _num(Config.options.upsMonitor.voltageEntity)
    readonly property real temperature: _num(Config.options.upsMonitor.tempEntity)
    readonly property bool onBattery: !root.charging && Math.abs(root.current) >= Config.options.upsMonitor.dischargeAmps
    readonly property bool valid: Config.options.upsMonitor.enable && HomeAssistant.configured && HomeAssistant.online && Config.options.upsMonitor.batteryEntity.length > 0

    property bool _wasOnBattery: false
    onOnBatteryChanged: {
        if (!root.valid)
            return;
        if (root.onBattery && !root._wasOnBattery)
            Quickshell.execDetached(["notify-send", Translation.tr("On battery"), Translation.tr("Mains lost — homelab on UPS (%1%)").arg(root.soc), "-u", "critical", "-a", "Shell"]);
        else if (!root.onBattery && root._wasOnBattery)
            Quickshell.execDetached(["notify-send", Translation.tr("Mains restored"), Translation.tr("Homelab back on mains power"), "-u", "low", "-a", "Shell"]);
        root._wasOnBattery = root.onBattery;
    }

    readonly property string materialSymbol: {
        if (!root.valid)
            return "battery_unknown";
        if (root.charging)
            return "battery_charging_full";
        const s = root.soc;
        if (s >= 95)
            return "battery_full";
        if (s >= 80)
            return "battery_6_bar";
        if (s >= 65)
            return "battery_5_bar";
        if (s >= 50)
            return "battery_4_bar";
        if (s >= 35)
            return "battery_3_bar";
        if (s >= 20)
            return "battery_2_bar";
        if (s >= 10)
            return "battery_1_bar";
        return "battery_alert";
    }
    readonly property color statusColor: root.onBattery ? (root.soc <= 20 ? Appearance.m3colors.m3error : Appearance.colors.colSecondary) : Appearance.colors.colOnSurfaceVariant

    IpcHandler {
        target: "ups"
        function status(): string {
            return `soc=${root.soc} charging=${root.charging} onBattery=${root.onBattery} power=${root.power} voltage=${root.voltage} valid=${root.valid}`;
        }
    }
}
