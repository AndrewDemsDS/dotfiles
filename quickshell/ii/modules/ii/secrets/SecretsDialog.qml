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
 * Secrets picker — an independent, movable Hyprland floating window (title "Secrets",
 * matched by a window_rule to float+center+size). Shows entry NAMES only; selecting one
 * copies its value to the clipboard inside the shelled pipe (Secrets service) and the
 * clipboard auto-clears. Values are never displayed here.
 */
Scope {
    id: root

    Loader {
        id: overlayLoader
        active: Secrets.active

        sourceComponent: FloatingWindow {
            id: winRoot
            title: "Secrets"
            color: Appearance.colors.colLayer0
            implicitWidth: 480
            implicitHeight: 560

            visible: Secrets.active
            onVisibleChanged: {
                if (!visible)
                    Secrets.close();
            }

            property string query: ""
            readonly property var filtered: {
                const q = winRoot.query.trim().toLowerCase();
                const all = Secrets.entries;
                if (q.length === 0)
                    return all;
                return all.filter(n => String(n).toLowerCase().indexOf(q) !== -1);
            }

            Rectangle {
                anchors.fill: parent
                color: Appearance.colors.colLayer0
                Component.onCompleted: search.forceActiveFocus()

                ColumnLayout {
                    anchors.fill: parent
                    anchors.margins: 16
                    spacing: 10

                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 8
                        MaterialSymbol {
                            text: "key"
                            iconSize: 22
                            color: Appearance.colors.colOnLayer0
                        }
                        StyledText {
                            Layout.fillWidth: true
                            text: Translation.tr("Secrets")
                            color: Appearance.colors.colOnLayer0
                            font.pixelSize: Appearance.font.pixelSize.normal
                        }
                        StyledText {
                            visible: Secrets.clearRemaining > 0
                            text: Translation.tr("clears in %1s").arg(Secrets.clearRemaining)
                            color: Appearance.colors.colPrimary
                            font.pixelSize: Appearance.font.pixelSize.smaller
                        }
                    }

                    MaterialTextField {
                        id: search
                        Layout.fillWidth: true
                        placeholderText: Translation.tr("Search secrets…")
                        onTextChanged: winRoot.query = text
                        Keys.onPressed: event => {
                            if (event.key === Qt.Key_Escape) {
                                Secrets.close();
                                event.accepted = true;
                            } else if (event.key === Qt.Key_Down) {
                                list.incrementCurrentIndex();
                                event.accepted = true;
                            } else if (event.key === Qt.Key_Up) {
                                list.decrementCurrentIndex();
                                event.accepted = true;
                            } else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
                                if (list.currentItem)
                                    Secrets.copy(list.currentItem.entryName);
                                event.accepted = true;
                            }
                        }
                    }

                    StyledText {
                        Layout.fillWidth: true
                        visible: !Secrets.backendAvailable && !Secrets.loading
                        wrapMode: Text.WordWrap
                        text: Translation.tr("No secrets backend. Install `pass` and create a store, or set a command backend in Settings → Custom.")
                        color: Appearance.colors.colSubtext
                        font.pixelSize: Appearance.font.pixelSize.smaller
                    }

                    ListView {
                        id: list
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        clip: true
                        spacing: 2
                        model: winRoot.filtered
                        currentIndex: 0

                        delegate: RippleButton {
                            id: entryButton
                            required property var modelData
                            required property int index
                            readonly property string entryName: String(modelData)
                            readonly property bool current: ListView.isCurrentItem
                            width: ListView.view.width
                            implicitHeight: 40
                            buttonRadius: Appearance.rounding.small
                            toggled: current
                            releaseAction: () => Secrets.copy(entryButton.entryName)
                            onHoveredChanged: if (hovered) list.currentIndex = index

                            contentItem: RowLayout {
                                anchors.fill: parent
                                anchors.leftMargin: 10
                                anchors.rightMargin: 10
                                spacing: 8
                                MaterialSymbol {
                                    text: "vpn_key"
                                    iconSize: 18
                                    color: entryButton.toggled ? Appearance.colors.colOnPrimary : Appearance.colors.colOnSurfaceVariant
                                }
                                StyledText {
                                    Layout.fillWidth: true
                                    text: entryButton.entryName
                                    color: entryButton.toggled ? Appearance.colors.colOnPrimary : Appearance.colors.colOnLayer0
                                    elide: Text.ElideRight
                                    font.pixelSize: Appearance.font.pixelSize.smaller
                                }
                                MaterialSymbol {
                                    text: "content_copy"
                                    iconSize: 16
                                    color: entryButton.toggled ? Appearance.colors.colOnPrimary : Appearance.colors.colSubtext
                                }
                            }
                        }
                    }

                    StyledText {
                        Layout.fillWidth: true
                        text: Translation.tr("Enter copies to the clipboard, then it auto-clears. Values are never shown.")
                        color: Appearance.colors.colSubtext
                        font.pixelSize: Appearance.font.pixelSize.smallest
                        wrapMode: Text.WordWrap
                    }
                }
            }
        }
    }
}
