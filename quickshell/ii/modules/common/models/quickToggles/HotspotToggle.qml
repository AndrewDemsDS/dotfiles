import qs.services
import qs.modules.common
import QtQuick

/*
 * Quick toggle for the Wi-Fi hotspot (mirrors VpnToggle). Brings the NM "Hotspot"
 * profile up/down; the menu opens HotspotDialog to configure SSID/password/band + QR.
 */
QuickToggleModel {
    id: root
    name: Translation.tr("Hotspot")
    icon: Hotspot.materialSymbol
    toggled: Hotspot.enabled
    available: Hotspot.iface.length > 0
    hasMenu: true
    mainAction: () => Hotspot.toggle()
    statusText: Hotspot.enabled ? Hotspot.ssid : Translation.tr("Off")
    tooltipText: Hotspot.iface.length > 0
        ? Translation.tr("Hotspot: %1 | Right-click to configure").arg(Hotspot.ssid)
        : Translation.tr("No Wi-Fi device")
}
