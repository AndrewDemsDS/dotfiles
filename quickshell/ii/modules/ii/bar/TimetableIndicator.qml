import QtQuick
import QtQuick.Layouts
import qs.services
import qs.modules.common
import qs.modules.common.widgets

/*
 * Bar pill: shows the next upcoming class + a countdown.
 *   "Math in 25m" while waiting, "Math now" while a class is ongoing.
 * Hover for the room + start time. Click to re-read the schedule file.
 */
Loader {
    id: root
    active: Config.options.timetable.enable && Timetable.hasNext
    visible: active

    sourceComponent: Item {
        implicitWidth: pillRow.implicitWidth
        implicitHeight: pillRow.implicitHeight

        RowLayout {
            id: pillRow
            anchors.centerIn: parent
            spacing: 3

            MaterialSymbol {
                text: Timetable.ongoing ? "school" : "event_upcoming"
                iconSize: Appearance.font.pixelSize.larger
                color: Timetable.ongoing ? Appearance.colors.colPrimary : Appearance.colors.colOnSurfaceVariant
            }

            StyledText {
                text: Timetable.countdownText()
                color: Timetable.ongoing ? Appearance.colors.colPrimary : Appearance.colors.colOnSurfaceVariant
                font.pixelSize: Appearance.font.pixelSize.small
                elide: Text.ElideRight
                Layout.maximumWidth: 140
            }
        }

        MouseArea {
            id: pillMouse
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: Timetable.refresh()
        }

        StyledToolTip {
            extraVisibleCondition: pillMouse.containsMouse
            text: {
                let lines = [Timetable.nextTitle];
                if (Timetable.nextRoom.length > 0)
                    lines.push(Translation.tr("Room: %1").arg(Timetable.nextRoom));
                if (Timetable.nextStart) {
                    const t = Qt.formatDateTime(Timetable.nextStart, "ddd HH:mm");
                    lines.push(Timetable.ongoing ? Translation.tr("Ongoing (started %1)").arg(t) : Translation.tr("Starts %1").arg(t));
                }
                if (!Timetable.ongoing && Timetable.minutesUntil >= 0)
                    lines.push(Translation.tr("In %1 min").arg(Timetable.minutesUntil));
                return lines.join("\n");
            }
        }
    }
}
