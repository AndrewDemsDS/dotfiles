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

        MouseArea {
            id: pillMouse
            anchors.fill: parent
            hoverEnabled: true
        }

        StyledToolTip {
            extraVisibleCondition: pillMouse.containsMouse
            text: {
                let lines = [Translation.tr("Homelab UPS")];
                lines.push(UpsMonitor.onBattery ? Translation.tr("On battery") : (UpsMonitor.charging ? Translation.tr("Charging") : Translation.tr("On mains")));
                lines.push(`${UpsMonitor.soc}%  ·  ${UpsMonitor.voltage.toFixed(2)} V`);
                if (UpsMonitor.power !== 0)
                    lines.push(Translation.tr("Load: %1 W").arg(UpsMonitor.power.toFixed(0)));
                if (UpsMonitor.temperature !== 0)
                    lines.push(`${UpsMonitor.temperature.toFixed(0)}°C`);
                return lines.join("\n");
            }
        }
    }
}
