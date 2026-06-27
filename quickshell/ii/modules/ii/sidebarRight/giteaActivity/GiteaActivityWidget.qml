import qs.modules.common
import qs.modules.common.widgets
import qs.services
import QtQuick
import QtQuick.Layouts

/*
 * Sidebar card: recent Gitea activity (GiteaActivity service). Lists the latest actions
 * (repo + verb + relative time). Hidden until configured; degrades gracefully when the
 * token is missing/unauthorized or the feed is empty.
 */
Rectangle {
    id: root
    Layout.fillWidth: true
    visible: Config.options.giteaActivity.enable
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
                text: "forum"
                iconSize: 24
                color: GiteaActivity.unauthorized ? Appearance.m3colors.m3error : Appearance.colors.colOnLayer1
            }
            ColumnLayout {
                Layout.fillWidth: true
                spacing: 0
                StyledText {
                    text: Translation.tr("Gitea activity")
                    color: Appearance.colors.colOnLayer1
                    font.pixelSize: Appearance.font.pixelSize.normal
                }
                StyledText {
                    Layout.fillWidth: true
                    text: !GiteaActivity.configured ? Translation.tr("Set giteaActivity base/user + token") : GiteaActivity.unauthorized ? Translation.tr("unauthorized") : !GiteaActivity.online ? Translation.tr("unreachable") : GiteaActivity.count === 0 ? Translation.tr("no recent activity") : Translation.tr("%1 recent").arg(GiteaActivity.count)
                    color: GiteaActivity.unauthorized ? Appearance.m3colors.m3error : Appearance.colors.colSubtext
                    font.pixelSize: Appearance.font.pixelSize.smaller
                    elide: Text.ElideRight
                }
            }
        }

        ColumnLayout {
            Layout.fillWidth: true
            spacing: 3
            visible: GiteaActivity.feed.length > 0
            Repeater {
                model: GiteaActivity.feed
                delegate: RowLayout {
                    required property var modelData
                    Layout.fillWidth: true
                    spacing: 6
                    Rectangle {
                        implicitWidth: 6
                        implicitHeight: 6
                        radius: 3
                        Layout.alignment: Qt.AlignVCenter
                        color: Appearance.colors.colPrimary
                    }
                    StyledText {
                        Layout.fillWidth: true
                        text: `${parent.modelData.act} ${parent.modelData.repo}`.trim()
                        color: Appearance.colors.colOnLayer1
                        font.pixelSize: Appearance.font.pixelSize.smaller
                        elide: Text.ElideRight
                    }
                    StyledText {
                        text: GiteaActivity.relativeTime(parent.modelData.created)
                        color: Appearance.colors.colSubtext
                        font.pixelSize: Appearance.font.pixelSize.smallest
                    }
                }
            }
        }
    }
}
