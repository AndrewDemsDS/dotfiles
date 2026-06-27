import qs.modules.common
import qs.modules.common.widgets
import qs.services
import QtQuick
import QtQuick.Layouts

/*
 * Sidebar card: upcoming deadlines (Deadlines service). Lists each entry sorted by due
 * date, coloured by urgency (overdue = error, soon = primary, otherwise subtext). Hidden
 * when disabled or when no deadlines are configured.
 */
Rectangle {
    id: root
    Layout.fillWidth: true
    visible: Config.options.deadlines.enable && Deadlines.hasData
    implicitHeight: visible ? contentCol.implicitHeight + 20 : 0
    radius: Appearance.rounding.normal
    color: Appearance.colors.colLayer1
    clip: true

    function urgencyColor(entry) {
        if (entry.overdue)
            return Appearance.m3colors.m3error;
        if (entry.soon)
            return Appearance.colors.colPrimary;
        return Appearance.colors.colSubtext;
    }

    function dueLabel(entry) {
        if (entry.overdue)
            return entry.daysLeft === -1 ? Translation.tr("1 day overdue") : Translation.tr("%1 days overdue").arg(-entry.daysLeft);
        if (entry.daysLeft === 0)
            return Translation.tr("Due today");
        if (entry.daysLeft === 1)
            return Translation.tr("Tomorrow");
        return Translation.tr("in %1 days").arg(entry.daysLeft);
    }

    ColumnLayout {
        id: contentCol
        anchors {
            left: parent.left
            right: parent.right
            verticalCenter: parent.verticalCenter
            leftMargin: 12
            rightMargin: 12
        }
        spacing: 6

        RowLayout {
            Layout.fillWidth: true
            spacing: 10
            MaterialSymbol {
                text: Deadlines.soonCount > 0 ? "event_busy" : "event_available"
                iconSize: 24
                color: Deadlines.soonCount > 0 ? Appearance.m3colors.m3error : Appearance.colors.colOnLayer1
            }
            ColumnLayout {
                Layout.fillWidth: true
                spacing: 0
                StyledText {
                    text: Translation.tr("Deadlines")
                    color: Appearance.colors.colOnLayer1
                    font.pixelSize: Appearance.font.pixelSize.normal
                }
                StyledText {
                    Layout.fillWidth: true
                    text: Deadlines.soonCount > 0 ? Translation.tr("%1 due soon").arg(Deadlines.soonCount) : Translation.tr("%1 tracked").arg(Deadlines.entries.length)
                    color: Deadlines.soonCount > 0 ? Appearance.m3colors.m3error : Appearance.colors.colSubtext
                    font.pixelSize: Appearance.font.pixelSize.smaller
                    elide: Text.ElideRight
                }
            }
        }

        ColumnLayout {
            Layout.fillWidth: true
            spacing: 4
            Repeater {
                model: Deadlines.entries
                delegate: RowLayout {
                    required property var modelData
                    Layout.fillWidth: true
                    spacing: 8
                    Rectangle {
                        implicitWidth: 7
                        implicitHeight: 7
                        radius: 4
                        Layout.alignment: Qt.AlignVCenter
                        color: root.urgencyColor(modelData)
                    }
                    StyledText {
                        Layout.fillWidth: true
                        text: modelData.name
                        color: Appearance.colors.colOnLayer1
                        font.pixelSize: Appearance.font.pixelSize.small
                        elide: Text.ElideRight
                    }
                    StyledText {
                        text: root.dueLabel(modelData)
                        color: root.urgencyColor(modelData)
                        font.pixelSize: Appearance.font.pixelSize.smaller
                    }
                }
            }
        }
    }
}
