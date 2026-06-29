import QtQuick
import QtQuick.Layouts
import qs.services
import qs.modules.common
import qs.modules.common.widgets

/*
 * Bar pill for the homelab UPS (distinct from the laptop battery). Shows SoC + a
 * battery icon coloured by state; amber/red when on battery. Hover for details.
 */
Loader {
    id: root
    active: Config.options.upsMonitor.enable && UpsMonitor.valid
    visible: active

    sourceComponent: Item {
        implicitWidth: pillRow.implicitWidth
        implicitHeight: pillRow.implicitHeight

        RowLayout {
            id: pillRow
            anchors.centerIn: parent
            spacing: 1
            MaterialSymbol {
                text: UpsMonitor.materialSymbol
                iconSize: Appearance.font.pixelSize.larger
                color: UpsMonitor.statusColor
            }
            StyledText {
                text: `${UpsMonitor.soc}%`
                color: UpsMonitor.statusColor
                font.pixelSize: Appearance.font.pixelSize.small
            }
        }

    }
}
