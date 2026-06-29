import QtQuick
import QtQuick.Layouts
import qs.services
import qs.modules.common
import qs.modules.common.widgets

/*
 * Bar pill: shows current network trust + VPN state at a glance.
 *   vpn up      → vpn_lock (primary)
 *   untrusted   → gpp_maybe (error) + "Unsafe" label
 *   trusted     → verified_user
 *   otherwise   → vpn_key_off
 * Hover for SSID / VPN / local + public IP. Click to refresh.
 */
Loader {
    id: root
    active: Config.options.vpnStatus.enable
    visible: active

    sourceComponent: Item {
        implicitWidth: pillRow.implicitWidth
        implicitHeight: pillRow.implicitHeight

        RowLayout {
            id: pillRow
            anchors.centerIn: parent
            spacing: 3

            MaterialSymbol {
                text: VpnStatus.materialSymbol
                iconSize: Appearance.font.pixelSize.larger
                color: VpnStatus.statusColor
            }

            StyledText {
                visible: VpnStatus.warn || VpnStatus.vpnUp
                text: VpnStatus.vpnUp ? VpnStatus.vpnName : Translation.tr("Unsafe")
                color: VpnStatus.statusColor
                font.pixelSize: Appearance.font.pixelSize.small
                elide: Text.ElideRight
                Layout.maximumWidth: 90
            }
        }

        MouseArea {
            id: pillMouse
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: VpnStatus.refresh()
        }
    }
}
