import qs.modules.common
import qs.modules.common.widgets
import qs.services
import QtQuick
import QtQuick.Layouts

/*
 * Sidebar card: service health board (ServiceHealth service). One row per configured
 * service with a colored dot — green when reachable, red when down. Hidden until enabled
 * and at least one service is configured.
 */
Rectangle {
    id: root
    Layout.fillWidth: true
    visible: Config.options.serviceHealth.enable && ServiceHealth.hasData
    implicitHeight: visible ? contentCol.implicitHeight + 20 : 0
    radius: Appearance.rounding.normal
    color: Appearance.colors.colLayer1
    clip: true

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
                text: ServiceHealth.allUp ? "check_circle" : "error"
                iconSize: 24
                color: ServiceHealth.allUp ? Appearance.colors.colOnLayer1 : Appearance.m3colors.m3error
            }
            ColumnLayout {
                Layout.fillWidth: true
                spacing: 0
                StyledText {
                    text: Translation.tr("Services")
                    color: Appearance.colors.colOnLayer1
                    font.pixelSize: Appearance.font.pixelSize.normal
                }
                StyledText {
                    Layout.fillWidth: true
                    text: Translation.tr("%1/%2 up").arg(ServiceHealth.upCount).arg(ServiceHealth.total)
                    color: ServiceHealth.allUp ? Appearance.colors.colSubtext : Appearance.m3colors.m3error
                    font.pixelSize: Appearance.font.pixelSize.smaller
                    elide: Text.ElideRight
                }
            }
        }

        ColumnLayout {
            Layout.fillWidth: true
            spacing: 4
            Repeater {
                model: ServiceHealth.model
                delegate: RowLayout {
                    required property var modelData
                    Layout.fillWidth: true
                    spacing: 8
                    Rectangle {
                        implicitWidth: 9
                        implicitHeight: 9
                        radius: 5
                        color: parent.modelData.up ? Appearance.colors.colPrimary : Appearance.m3colors.m3error
                    }
                    StyledText {
                        Layout.fillWidth: true
                        text: parent.modelData.name
                        color: Appearance.colors.colOnLayer1
                        font.pixelSize: Appearance.font.pixelSize.smaller
                        elide: Text.ElideRight
                    }
                    StyledText {
                        text: parent.modelData.up ? Translation.tr("up") : (parent.modelData.lastStatus > 0 ? `${parent.modelData.lastStatus}` : Translation.tr("down"))
                        color: parent.modelData.up ? Appearance.colors.colSubtext : Appearance.m3colors.m3error
                        font.pixelSize: Appearance.font.pixelSize.smallest
                    }
                }
            }
        }
    }
}
