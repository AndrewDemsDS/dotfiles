import qs.modules.common
import qs.modules.common.widgets
import qs.services
import QtQuick
import QtQuick.Layouts

/*
 * News/RSS reader — a left-sidebar tab. Lists items from Config.options.sidebar.news.feeds,
 * newest first; tap to expand the summary, Open to read in the browser (marks read).
 */
Item {
    id: root

    function relTime(ms) {
        if (!ms)
            return "";
        const s = Math.max(0, (Date.now() - ms) / 1000);
        if (s < 3600)
            return `${Math.round(s / 60)}m`;
        if (s < 86400)
            return `${Math.round(s / 3600)}h`;
        return `${Math.round(s / 86400)}d`;
    }

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 12
        spacing: 8

        RowLayout {
            Layout.fillWidth: true
            spacing: 8
            MaterialSymbol {
                text: "rss_feed"
                iconSize: 22
                color: Appearance.colors.colOnLayer1
            }
            StyledText {
                Layout.fillWidth: true
                text: Translation.tr("News")
                color: Appearance.colors.colOnLayer1
                font.pixelSize: Appearance.font.pixelSize.normal
            }
            StyledText {
                visible: NewsFeeds.unreadCount > 0
                text: NewsFeeds.unreadCount
                color: Appearance.colors.colPrimary
                font.pixelSize: Appearance.font.pixelSize.smaller
            }
            RippleButtonWithIcon {
                materialIcon: "mark_email_read"
                mainText: ""
                releaseAction: () => NewsFeeds.markAllRead()
            }
            RippleButtonWithIcon {
                materialIcon: "refresh"
                mainText: ""
                releaseAction: () => NewsFeeds.refresh()
            }
        }

        StyledText {
            Layout.fillWidth: true
            visible: NewsFeeds.items.length === 0
            wrapMode: Text.WordWrap
            color: Appearance.colors.colSubtext
            font.pixelSize: Appearance.font.pixelSize.small
            text: NewsFeeds.loading ? Translation.tr("Loading feeds…") : Translation.tr("No items. Add feeds in sidebar.news.feeds.")
        }

        ListView {
            Layout.fillWidth: true
            Layout.fillHeight: true
            clip: true
            spacing: 6
            model: NewsFeeds.items

            delegate: Rectangle {
                id: card
                required property var modelData
                readonly property bool read: NewsFeeds.isRead(card.modelData.link)
                width: ListView.view.width
                implicitHeight: itemCol.implicitHeight + 16
                radius: Appearance.rounding.small
                color: Appearance.colors.colLayer2

                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onClicked: NewsFeeds.openArticle(card.modelData.link)
                    onPressAndHold: NewsFeeds.toggleRead(card.modelData.link)
                }

                RowLayout {
                    id: itemCol
                    anchors {
                        left: parent.left
                        right: parent.right
                        top: parent.top
                        margins: 8
                    }
                    spacing: 8

                    Rectangle { // unread dot (space reserved when read for alignment)
                        Layout.alignment: Qt.AlignTop
                        Layout.topMargin: 4
                        implicitWidth: 8
                        implicitHeight: 8
                        radius: 4
                        color: card.read ? "transparent" : Appearance.colors.colPrimary
                    }
                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 2
                        StyledText {
                            Layout.fillWidth: true
                            text: card.modelData.title
                            color: card.read ? Appearance.colors.colSubtext : Appearance.colors.colOnLayer2
                            font.pixelSize: Appearance.font.pixelSize.small
                            font.weight: card.read ? Font.Normal : Font.DemiBold
                            wrapMode: Text.WordWrap
                            maximumLineCount: 2
                            elide: Text.ElideRight
                        }
                        StyledText {
                            text: `${card.modelData.source} · ${root.relTime(card.modelData.date)}`
                            color: Appearance.colors.colSubtext
                            font.pixelSize: Appearance.font.pixelSize.smaller
                        }
                    }
                }
            }
        }
    }
}
