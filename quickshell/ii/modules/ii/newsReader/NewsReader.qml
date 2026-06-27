import qs
import qs.services
import qs.modules.common
import qs.modules.common.widgets
import qs.modules.common.functions
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell

/*
 * Article reader — an independent, movable Hyprland floating window (not a modal overlay).
 * Title "Article Reader …" is matched by a hypr window_rule to float+center+size it.
 * Content extracted by trafilatura (scripts/news/read-article.sh) → Markdown text + images.
 */
Scope {
    id: root

    Loader {
        id: readerLoader
        active: NewsFeeds.articleUrl.length > 0

        sourceComponent: FloatingWindow {
            id: readerRoot
            title: "Article Reader"
            color: Appearance.colors.colLayer0
            implicitWidth: 1100
            implicitHeight: 1250

            visible: NewsFeeds.articleUrl.length > 0
            onVisibleChanged: {
                if (!visible) {
                    NewsFeeds.closeArticle();
                    GlobalStates.sidebarLeftOpen = true; // return to the News tab
                }
            }

            Rectangle {
                anchors.fill: parent
                color: Appearance.colors.colLayer0
                focus: true
                Keys.onPressed: event => {
                    if (event.key === Qt.Key_Escape)
                        NewsFeeds.closeArticle();
                }

                ColumnLayout {
                    anchors.fill: parent
                    anchors.margins: 24
                    spacing: 14

                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 10
                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: 3
                            StyledText {
                                Layout.fillWidth: true
                                text: NewsFeeds.article?.title ?? (NewsFeeds.articleLoading ? Translation.tr("Loading…") : "")
                                color: Appearance.colors.colOnLayer0
                                font.pixelSize: Appearance.font.pixelSize.title ?? Appearance.font.pixelSize.larger
                                font.weight: Font.DemiBold
                                wrapMode: Text.WordWrap
                            }
                            StyledText {
                                visible: text.length > 0
                                text: {
                                    const a = NewsFeeds.article;
                                    if (!a)
                                        return "";
                                    let parts = [];
                                    if (a.sitename)
                                        parts.push(a.sitename);
                                    if (a.author)
                                        parts.push(a.author);
                                    if (a.date)
                                        parts.push(a.date);
                                    return parts.join(" · ");
                                }
                                color: Appearance.colors.colSubtext
                                font.pixelSize: Appearance.font.pixelSize.small
                            }
                        }
                        RippleButtonWithIcon {
                            materialIcon: "open_in_new"
                            mainText: Translation.tr("Browser")
                            releaseAction: () => Qt.openUrlExternally(NewsFeeds.articleUrl)
                        }
                    }

                    StyledText {
                        Layout.fillWidth: true
                        visible: NewsFeeds.articleLoading || (NewsFeeds.article && NewsFeeds.article.error)
                        text: NewsFeeds.articleLoading ? Translation.tr("Fetching article…") : (NewsFeeds.article?.error ?? "")
                        color: Appearance.colors.colSubtext
                        wrapMode: Text.WordWrap
                    }

                    Flickable {
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        clip: true
                        contentHeight: bodyCol.implicitHeight
                        ScrollBar.vertical: ScrollBar {}

                        ColumnLayout {
                            id: bodyCol
                            width: parent.width
                            spacing: 14

                            Repeater {
                                model: NewsFeeds.article?.blocks ?? []
                                delegate: Item {
                                    id: block
                                    required property var modelData
                                    Layout.fillWidth: true
                                    Layout.maximumWidth: 760 // readable measure even in a wide window
                                    Layout.alignment: Qt.AlignHCenter
                                    implicitHeight: block.modelData.type === "image" ? img.height : txt.implicitHeight

                                    Image {
                                        id: img
                                        visible: block.modelData.type === "image"
                                        width: parent.width
                                        source: block.modelData.type === "image" ? block.modelData.url : ""
                                        fillMode: Image.PreserveAspectFit
                                        asynchronous: true
                                        height: (sourceSize.width > 0) ? width * sourceSize.height / sourceSize.width : 0
                                    }
                                    StyledText {
                                        id: txt
                                        visible: block.modelData.type === "text"
                                        width: parent.width
                                        text: block.modelData.type === "text" ? (block.modelData.md ?? "") : ""
                                        textFormat: Text.MarkdownText
                                        wrapMode: Text.WordWrap
                                        color: Appearance.colors.colOnLayer0
                                        font.pixelSize: Appearance.font.pixelSize.normal
                                        onLinkActivated: link => Qt.openUrlExternally(link)
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}
