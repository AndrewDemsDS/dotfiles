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
 * Guarded recon launcher — an independent, movable Hyprland floating window.
 * Title "Recon Launcher" is matched by a hypr window_rule to float+center+size it.
 * Shows the clipboard target + an allowlisted/NOT-allowlisted badge; tool buttons are
 * disabled unless the target host is on the owner allowlist (ReconLauncher).
 */
Scope {
    id: root

    Loader {
        id: overlayLoader
        active: ReconLauncher.active

        sourceComponent: FloatingWindow {
            id: winRoot
            title: "Recon Launcher"
            color: Appearance.colors.colLayer0
            implicitWidth: 820
            implicitHeight: 600

            visible: ReconLauncher.active
            onVisibleChanged: {
                if (!visible)
                    ReconLauncher.close();
            }

            Rectangle {
                anchors.fill: parent
                color: Appearance.colors.colLayer0
                focus: true
                Keys.onPressed: event => {
                    if (event.key === Qt.Key_Escape)
                        ReconLauncher.close();
                }

                ColumnLayout {
                    id: contentColumn
                    anchors.fill: parent
                    anchors.margins: 20
                    spacing: 12

                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 8
                        MaterialSymbol {
                            text: "security"
                            iconSize: 22
                            color: Appearance.colors.colOnLayer0
                        }
                        StyledText {
                            Layout.fillWidth: true
                            text: Translation.tr("Recon launcher")
                            color: Appearance.colors.colOnLayer0
                            font.pixelSize: Appearance.font.pixelSize.normal
                        }
                    }

                    // Target + allowlist badge
                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 8

                        StyledText {
                            Layout.fillWidth: true
                            text: ReconLauncher.target.length > 0 ? ReconLauncher.target : Translation.tr("Clipboard empty — copy/select a target first.")
                            color: Appearance.colors.colSubtext
                            font.pixelSize: Appearance.font.pixelSize.smaller
                            wrapMode: Text.WrapAnywhere
                            maximumLineCount: 2
                            elide: Text.ElideRight
                        }

                        Rectangle {
                            id: badge
                            readonly property bool ok: ReconLauncher.allowlisted
                            implicitWidth: badgeRow.implicitWidth + 16
                            implicitHeight: badgeRow.implicitHeight + 8
                            radius: Appearance.rounding.small
                            color: badge.ok ? Appearance.colors.colPrimaryContainer : Appearance.m3colors.m3errorContainer
                            RowLayout {
                                id: badgeRow
                                anchors.centerIn: parent
                                spacing: 4
                                MaterialSymbol {
                                    text: badge.ok ? "verified" : "block"
                                    iconSize: Appearance.font.pixelSize.large
                                    color: badge.ok ? Appearance.colors.colOnPrimaryContainer : Appearance.m3colors.m3onErrorContainer
                                }
                                StyledText {
                                    text: badge.ok ? Translation.tr("Allowlisted") : Translation.tr("Not allowlisted")
                                    color: badge.ok ? Appearance.colors.colOnPrimaryContainer : Appearance.m3colors.m3onErrorContainer
                                    font.pixelSize: Appearance.font.pixelSize.smaller
                                }
                            }
                        }
                    }

                    StyledText {
                        Layout.fillWidth: true
                        visible: !ReconLauncher.allowlisted && ReconLauncher.target.length > 0
                        text: Translation.tr("Host %1 isn't on your owner allowlist. Add it in Settings → Custom to run recon.").arg(ReconLauncher.targetHost.length > 0 ? ReconLauncher.targetHost : Translation.tr("(none)"))
                        color: Appearance.m3colors.m3error
                        font.pixelSize: Appearance.font.pixelSize.smallest
                        wrapMode: Text.WordWrap
                    }

                    // Tool buttons — disabled when not allowlisted
                    Flow {
                        Layout.fillWidth: true
                        spacing: 6
                        Repeater {
                            model: ReconLauncher.tools
                            delegate: RippleButtonWithIcon {
                                required property var modelData
                                materialIcon: modelData.icon
                                mainText: modelData.label
                                enabled: ReconLauncher.allowlisted
                                releaseAction: () => ReconLauncher.run(modelData.key)
                            }
                        }
                    }

                    Item {
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                    }
                }
            }
        }
    }
}
