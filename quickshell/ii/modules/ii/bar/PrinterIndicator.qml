import QtQuick
import QtQuick.Layouts
import qs.services
import qs.modules.common
import qs.modules.common.widgets

/*
 * Bar pill for CUPS printers. Hidden when idle (unless showWhenIdle); shows the
 * active job count and turns error-coloured when a printer is disabled. Hover for
 * details; click to open the printer dialog.
 */
Loader {
    id: root
    active: Config.options.printer.enable && (Config.options.printer.showWhenIdle || Printer.jobCount > 0 || Printer.hasError)
    visible: active

    sourceComponent: Item {
        implicitWidth: pillRow.implicitWidth
        implicitHeight: pillRow.implicitHeight

        RowLayout {
            id: pillRow
            anchors.centerIn: parent
            spacing: 2

            MaterialSymbol {
                text: "print"
                iconSize: Appearance.font.pixelSize.larger
                color: Printer.hasError ? Appearance.m3colors.m3error : (Printer.jobCount > 0 ? Appearance.colors.colPrimary : Appearance.colors.colOnLayer1)
            }
            StyledText {
                visible: Printer.jobCount > 0
                text: `${Printer.jobCount}`
                color: Printer.hasError ? Appearance.m3colors.m3error : (Printer.jobCount > 0 ? Appearance.colors.colPrimary : Appearance.colors.colOnLayer1)
                font.pixelSize: Appearance.font.pixelSize.small
            }
        }

        MouseArea {
            id: pillMouse
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: Printer.toggle()
        }

        StyledToolTip {
            extraVisibleCondition: pillMouse.containsMouse
            text: {
                let lines = [];
                lines.push(Translation.tr("Default: %1").arg(Printer.defaultPrinter.length > 0 ? Printer.defaultPrinter : Translation.tr("none")));
                lines.push(Translation.tr("Jobs: %1").arg(Printer.jobCount));
                let disabled = [];
                for (const p of Printer.printers) {
                    if (!p.enabled || p.state === "disabled")
                        disabled.push(p.name);
                }
                if (disabled.length > 0)
                    lines.push(Translation.tr("Disabled: %1").arg(disabled.join(", ")));
                return lines.join("\n");
            }
        }
    }
}
