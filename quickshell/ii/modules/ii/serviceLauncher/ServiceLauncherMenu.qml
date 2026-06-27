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
 * Service quick-launcher — an independent, movable Hyprland floating window.
 * Title "Service Launcher" is matched by a hypr window_rule to float+center+size it.
 * Shows a grid of the configured homelab services (ServiceLauncher); clicking one
 * opens it in a browser app-window and closes the window.
 */
Scope {
    id: root

    Loader {
        id: overlayLoader
        active: ServiceLauncher.active

        sourceComponent: FloatingWindow {
            id: winRoot
            title: "Service Launcher"
            color: Appearance.colors.colLayer0
            implicitWidth: 900
            implicitHeight: 650

            visible: ServiceLauncher.active
            onVisibleChanged: {
                if (!visible)
                    ServiceLauncher.close();
            }

            Rectangle {
                anchors.fill: parent
                color: Appearance.colors.colLayer0
                focus: true
                Keys.onPressed: event => {
                    if (event.key === Qt.Key_Escape)
                        ServiceLauncher.close();
                }

                ColumnLayout {
                    anchors.fill: parent
                    anchors.margins: 24
                    spacing: 12

                    RowLayout {
                        Layout.fillWidth: true
                        MaterialSymbol {
                            text: "apps"
                            iconSize: 22
                            color: Appearance.colors.colOnLayer0
                        }
                        StyledText {
                            Layout.fillWidth: true
                            text: Translation.tr("Services")
                            color: Appearance.colors.colOnLayer0
                            font.pixelSize: Appearance.font.pixelSize.normal
                        }
                    }

                    StyledText {
                        Layout.fillWidth: true
                        visible: ServiceLauncher.services.length === 0
                        text: Translation.tr("No services configured — add some in Settings → Custom.")
                        color: Appearance.colors.colSubtext
                        font.pixelSize: Appearance.font.pixelSize.smaller
                        wrapMode: Text.WordWrap
                    }

                    Flickable {
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        visible: ServiceLauncher.services.length > 0
                        clip: true
                        contentHeight: serviceGrid.implicitHeight
                        ScrollBar.vertical: ScrollBar {}

                        GridLayout {
                            id: serviceGrid
                            width: parent.width
                            columns: 4
                            rowSpacing: 8
                            columnSpacing: 8

                            Repeater {
                                model: ServiceLauncher.services
                                delegate: RippleButton {
                                    id: tile
                                    required property var modelData
                                    Layout.fillWidth: true
                                    Layout.preferredHeight: tileCol.implicitHeight + 20
                                    buttonRadius: Appearance.rounding.small
                                    colBackground: Appearance.colors.colLayer1
                                    colBackgroundHover: Appearance.colors.colLayer1Hover
                                    onClicked: ServiceLauncher.launch(tile.modelData.url)

                                    contentItem: ColumnLayout {
                                        id: tileCol
                                        spacing: 4
                                        MaterialSymbol {
                                            Layout.alignment: Qt.AlignHCenter
                                            text: tile.modelData.icon && String(tile.modelData.icon).length > 0 ? tile.modelData.icon : "lan"
                                            iconSize: 26
                                            color: Appearance.colors.colOnLayer1
                                        }
                                        StyledText {
                                            Layout.alignment: Qt.AlignHCenter
                                            Layout.maximumWidth: 140
                                            text: tile.modelData.name ?? tile.modelData.url ?? ""
                                            color: Appearance.colors.colOnLayer1
                                            font.pixelSize: Appearance.font.pixelSize.smaller
                                            horizontalAlignment: Text.AlignHCenter
                                            elide: Text.ElideRight
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
}
