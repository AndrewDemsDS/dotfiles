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

        StyledToolTip {
            extraVisibleCondition: pillMouse.containsMouse
            text: {
                let lines = [];
                lines.push(Translation.tr("Network: %1").arg(VpnStatus.ssid.length > 0 ? VpnStatus.ssid : (VpnStatus.iface.length > 0 ? VpnStatus.iface : Translation.tr("unknown"))));
                lines.push(VpnStatus.trusted ? Translation.tr("Trusted") : Translation.tr("Untrusted"));
                lines.push(VpnStatus.vpnUp ? Translation.tr("VPN: %1 (up)").arg(VpnStatus.vpnName) : Translation.tr("VPN: down"));
                if (VpnStatus.localIp.length > 0)
                    lines.push(Translation.tr("Local: %1").arg(VpnStatus.localIp));
                if (VpnStatus.publicIp.length > 0)
                    lines.push(Translation.tr("Public: %1 %2").arg(VpnStatus.publicIp).arg(VpnStatus.geoCity.length > 0 ? `(${VpnStatus.geoCity}, ${VpnStatus.geoCountry})` : ""));
                return lines.join("\n");
            }
        }
    }
}
