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
 * Local-LLM text-action overlay — an independent, movable Hyprland floating window.
 * Title "Text Actions" is matched by a hypr window_rule to float+center+size it.
 * Runs the chosen action on a local Ollama (LocalLlm service).
 */
Scope {
    id: root

    Loader {
        id: overlayLoader
        active: LocalLlm.active

        sourceComponent: FloatingWindow {
            id: winRoot
            title: "Text Actions"
            color: Appearance.colors.colLayer0
            implicitWidth: 880
            implicitHeight: 620

            visible: LocalLlm.active
            onVisibleChanged: {
                if (!visible)
                    LocalLlm.close();
            }

            Rectangle {
                anchors.fill: parent
                color: Appearance.colors.colLayer0
                focus: true
                Keys.onPressed: event => {
                    if (event.key === Qt.Key_Escape)
                        LocalLlm.close();
                }

                ColumnLayout {
                    id: contentColumn
                    anchors.fill: parent
                    anchors.margins: 20
                    spacing: 12

                    RowLayout {
                        Layout.fillWidth: true
                        MaterialSymbol {
                            text: "neurology"
                            iconSize: 22
                            color: Appearance.colors.colOnLayer0
                        }
                        StyledText {
                            Layout.fillWidth: true
                            text: Translation.tr("Text actions") + (LocalLlm.model.length > 0 ? ` · ${LocalLlm.model}` : "")
                            color: Appearance.colors.colOnLayer0
                            font.pixelSize: Appearance.font.pixelSize.normal
                        }
                    }

                    StyledText {
                        Layout.fillWidth: true
                        text: LocalLlm.selection.length > 0 ? LocalLlm.selection : Translation.tr("No text selected — select something first, then trigger this.")
                        color: Appearance.colors.colSubtext
                        font.pixelSize: Appearance.font.pixelSize.smaller
                        wrapMode: Text.WordWrap
                        maximumLineCount: 3
                        elide: Text.ElideRight
                    }

                    Flow {
                        Layout.fillWidth: true
                        spacing: 6
                        Repeater {
                            model: LocalLlm.actions
                            delegate: RippleButtonWithIcon {
                                required property var modelData
                                materialIcon: modelData.icon
                                mainText: modelData.label
                                toggled: LocalLlm.action === modelData.label
                                enabled: LocalLlm.selection.length > 0 && !LocalLlm.loading
                                releaseAction: () => LocalLlm.runAction(modelData.key)
                            }
                        }
                    }

                    StyledText {
                        visible: LocalLlm.loading
                        text: Translation.tr("Thinking…")
                        color: Appearance.colors.colSubtext
                    }

                    Flickable {
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        visible: LocalLlm.result.length > 0
                        clip: true
                        contentHeight: resultText.implicitHeight
                        ScrollBar.vertical: ScrollBar {}
                        StyledText {
                            id: resultText
                            width: parent.width
                            text: LocalLlm.result
                            textFormat: Text.MarkdownText
                            wrapMode: Text.WordWrap
                            color: Appearance.colors.colOnLayer0
                            font.pixelSize: Appearance.font.pixelSize.normal
                            onLinkActivated: link => Qt.openUrlExternally(link)
                        }
                    }

                    RowLayout {
                        Layout.fillWidth: true
                        DialogButton {
                            visible: LocalLlm.result.length > 0
                            buttonText: Translation.tr("Copy")
                            onClicked: {
                                Quickshell.execDetached(["wl-copy", LocalLlm.result]);
                                LocalLlm.close();
                            }
                        }
                        Item {
                            Layout.fillWidth: true
                        }
                    }

                    Item {
                        Layout.fillWidth: true
                        Layout.fillHeight: LocalLlm.result.length === 0
                    }
                }
            }
        }
    }
}
