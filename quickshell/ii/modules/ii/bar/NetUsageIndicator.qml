import QtQuick
import QtQuick.Layouts
import qs.services
import qs.modules.common
import qs.modules.common.widgets

/*
 * Bar pill: live down/up bandwidth + the running monthly data total. Goes to the error
 * colour when the monthly cap is breached past the warn threshold (metered-hotspot guard).
 * Sourced from /proc/net/dev via the NetUsage service (no root, no external calls).
 */
Loader {
    id: root
    active: Config.options.netUsage.enable
    visible: active

    sourceComponent: Item {
        id: pill
        implicitWidth: pillRow.implicitWidth
        implicitHeight: pillRow.implicitHeight

        readonly property color baseColor: NetUsage.overWarn ? Appearance.m3colors.m3error : Appearance.colors.colOnSurfaceVariant

        RowLayout {
            id: pillRow
            anchors.centerIn: parent
            spacing: 1

            MaterialSymbol {
                text: "arrow_downward"
                iconSize: Appearance.font.pixelSize.normal
                color: pill.baseColor
            }
            StyledText {
                text: NetUsage.humanRate(NetUsage.rxSpeed)
                color: pill.baseColor
                font.pixelSize: Appearance.font.pixelSize.small
            }
            MaterialSymbol {
                text: "arrow_upward"
                iconSize: Appearance.font.pixelSize.normal
                color: pill.baseColor
                Layout.leftMargin: 4
            }
            StyledText {
                text: NetUsage.humanRate(NetUsage.txSpeed)
                color: pill.baseColor
                font.pixelSize: Appearance.font.pixelSize.small
            }
            StyledText {
                text: NetUsage.humanTotal(NetUsage.monthTotalGiB)
                color: NetUsage.overWarn ? Appearance.m3colors.m3error : Appearance.colors.colPrimary
                font.pixelSize: Appearance.font.pixelSize.small
                Layout.leftMargin: 5
            }
        }

        MouseArea {
            id: pillMouse
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: NetUsage.refresh()
        }

        StyledToolTip {
            extraVisibleCondition: pillMouse.containsMouse
            text: {
                let lines = [Translation.tr("Network usage (%1)").arg(NetUsage.activeIface || NetUsage.cfg.iface)];
                lines.push(Translation.tr("Down: %1   Up: %2").arg(NetUsage.humanRate(NetUsage.rxSpeed)).arg(NetUsage.humanRate(NetUsage.txSpeed)));
                lines.push(Translation.tr("This month: %1 ↓ / %2 ↑").arg(NetUsage.humanTotal(NetUsage.monthRxGiB)).arg(NetUsage.humanTotal(NetUsage.monthTxGiB)));
                lines.push(Translation.tr("Total: %1").arg(NetUsage.humanTotal(NetUsage.monthTotalGiB)));
                if (NetUsage.capGiB > 0)
                    lines.push(Translation.tr("Cap: %1 GiB (%2%)").arg(NetUsage.capGiB.toFixed(0)).arg(NetUsage.capPercent.toFixed(0)));
                return lines.join("\n");
            }
        }
    }
}
