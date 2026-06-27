import qs.modules.common
import qs.modules.common.widgets
import qs.services
import QtQuick
import QtQuick.Layouts

/*
 * Sidebar card: NAS free disk + container health (NasHealth service). Turns red and
 * warns when free space is below the media-server guard threshold. Hidden until configured.
 */
Rectangle {
    id: root
    Layout.fillWidth: true
    visible: Config.options.nasGuard.enable
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
                text: NasHealth.belowThreshold ? "storage" : "hard_drive_2"
                iconSize: 24
                color: NasHealth.belowThreshold ? Appearance.m3colors.m3error : Appearance.colors.colOnLayer1
            }
            ColumnLayout {
                Layout.fillWidth: true
                spacing: 0
                StyledText {
                    text: Translation.tr("NAS storage")
                    color: Appearance.colors.colOnLayer1
                    font.pixelSize: Appearance.font.pixelSize.normal
                }
                StyledText {
                    Layout.fillWidth: true
                    text: !NasHealth.configured ? Translation.tr("Set nasGuard host/sensor") : !NasHealth.reachable ? Translation.tr("unreachable") : Translation.tr("%1 free").arg(NasHealth.freeHuman())
                    color: NasHealth.belowThreshold ? Appearance.m3colors.m3error : Appearance.colors.colSubtext
                    font.pixelSize: Appearance.font.pixelSize.smaller
                    elide: Text.ElideRight
                }
            }
        }

        Flow {
            Layout.fillWidth: true
            spacing: 5
            visible: NasHealth.containers.length > 0
            Repeater {
                model: NasHealth.containers
                delegate: Rectangle {
                    required property var modelData
                    readonly property bool ok: modelData.state === "running" && modelData.health !== "unhealthy"
                    width: dot.implicitWidth + 14
                    height: 18
                    radius: 9
                    color: Appearance.colors.colLayer2
                    RowLayout {
                        id: dot
                        anchors.centerIn: parent
                        spacing: 4
                        Rectangle {
                            implicitWidth: 7
                            implicitHeight: 7
                            radius: 4
                            color: parent.parent.ok ? Appearance.colors.colPrimary : Appearance.m3colors.m3error
                        }
                        StyledText {
                            text: parent.parent.modelData.name
                            color: Appearance.colors.colOnLayer2
                            font.pixelSize: Appearance.font.pixelSize.smallest
                        }
                    }
                }
            }
        }
    }
}
