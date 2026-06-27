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
 * Printer manager — an independent, movable Hyprland floating window.
 * Title "Printers" is matched by a hypr window_rule to float+center+size it.
 * Lists CUPS printers (with a "set default" action) and the active job queue
 * (cancel per-job / cancel-all), plus quick actions (open CUPS, settings, print
 * clipboard). All data comes from the Printer service (lpstat at runtime).
 */
Scope {
    id: root

    Loader {
        id: overlayLoader
        active: Printer.dialogOpen

        sourceComponent: FloatingWindow {
            id: winRoot
            title: "Printers"
            color: Appearance.colors.colLayer0
            implicitWidth: 760
            implicitHeight: 640

            visible: Printer.dialogOpen
            onVisibleChanged: {
                if (!visible)
                    Printer.close();
            }

            Rectangle {
                anchors.fill: parent
                color: Appearance.colors.colLayer0
                focus: true
                Keys.onPressed: event => {
                    if (event.key === Qt.Key_Escape)
                        Printer.close();
                }

                ColumnLayout {
                    id: contentColumn
                    anchors.fill: parent
                    anchors.margins: 20
                    spacing: 14

                    // Header
                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 8
                        MaterialSymbol {
                            text: "print"
                            iconSize: 22
                            color: Appearance.colors.colOnLayer0
                        }
                        StyledText {
                            Layout.fillWidth: true
                            text: Translation.tr("Printers")
                            color: Appearance.colors.colOnLayer0
                            font.pixelSize: Appearance.font.pixelSize.normal
                        }
                    }

                    // Printers section
                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 6

                        StyledText {
                            text: Translation.tr("Printers")
                            color: Appearance.colors.colSubtext
                            font.pixelSize: Appearance.font.pixelSize.smaller
                        }

                        Repeater {
                            model: Printer.printers
                            delegate: RowLayout {
                                id: printerRow
                                required property var modelData
                                readonly property bool isDefault: printerRow.modelData.name === Printer.defaultPrinter
                                Layout.fillWidth: true
                                spacing: 8

                                MaterialSymbol {
                                    text: (printerRow.modelData.enabled && printerRow.modelData.state !== "disabled") ? "print" : "print_disabled"
                                    iconSize: Appearance.font.pixelSize.larger
                                    color: (printerRow.modelData.enabled && printerRow.modelData.state !== "disabled") ? Appearance.colors.colOnLayer0 : Appearance.m3colors.m3error
                                }
                                StyledText {
                                    text: printerRow.modelData.name
                                    color: Appearance.colors.colOnLayer0
                                    font.pixelSize: Appearance.font.pixelSize.normal
                                    font.weight: printerRow.isDefault ? Font.Bold : Font.Normal
                                }
                                Rectangle {
                                    visible: printerRow.isDefault
                                    implicitWidth: defaultChipText.implicitWidth + 14
                                    implicitHeight: defaultChipText.implicitHeight + 6
                                    radius: Appearance.rounding.small
                                    color: Appearance.colors.colPrimaryContainer
                                    StyledText {
                                        id: defaultChipText
                                        anchors.centerIn: parent
                                        text: Translation.tr("default")
                                        color: Appearance.colors.colOnPrimaryContainer
                                        font.pixelSize: Appearance.font.pixelSize.smallest
                                    }
                                }
                                StyledText {
                                    text: printerRow.modelData.state
                                    color: Appearance.colors.colSubtext
                                    font.pixelSize: Appearance.font.pixelSize.smaller
                                }
                                Item { Layout.fillWidth: true }
                                RippleButton {
                                    visible: !printerRow.isDefault
                                    buttonText: Translation.tr("Set default")
                                    implicitHeight: 32
                                    releaseAction: () => Printer.setDefault(printerRow.modelData.name)
                                }
                            }
                        }

                        StyledText {
                            visible: Printer.printers.length === 0
                            text: Translation.tr("No printers")
                            color: Appearance.colors.colSubtext
                            font.pixelSize: Appearance.font.pixelSize.smaller
                        }
                    }

                    // Queue section
                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 6

                        RowLayout {
                            Layout.fillWidth: true
                            spacing: 8
                            StyledText {
                                text: Translation.tr("Queue (%1)").arg(Printer.jobCount)
                                color: Appearance.colors.colSubtext
                                font.pixelSize: Appearance.font.pixelSize.smaller
                            }
                            Item { Layout.fillWidth: true }
                            RippleButton {
                                visible: Printer.jobCount > 0
                                buttonText: Translation.tr("Cancel all")
                                implicitHeight: 32
                                releaseAction: () => Printer.cancelAll()
                            }
                        }

                        Repeater {
                            model: Printer.jobs
                            delegate: RowLayout {
                                id: jobRow
                                required property var modelData
                                Layout.fillWidth: true
                                spacing: 8

                                MaterialSymbol {
                                    text: "description"
                                    iconSize: Appearance.font.pixelSize.larger
                                    color: Appearance.colors.colOnLayer0
                                }
                                StyledText {
                                    text: jobRow.modelData.id
                                    color: Appearance.colors.colOnLayer0
                                    font.pixelSize: Appearance.font.pixelSize.small
                                }
                                StyledText {
                                    text: jobRow.modelData.user
                                    color: Appearance.colors.colSubtext
                                    font.pixelSize: Appearance.font.pixelSize.smaller
                                }
                                Item { Layout.fillWidth: true }
                                RippleButtonWithIcon {
                                    materialIcon: "close"
                                    mainText: Translation.tr("Cancel")
                                    releaseAction: () => Printer.cancelJob(jobRow.modelData.id)
                                }
                            }
                        }

                        StyledText {
                            visible: Printer.jobs.length === 0
                            text: Translation.tr("No jobs")
                            color: Appearance.colors.colSubtext
                            font.pixelSize: Appearance.font.pixelSize.smaller
                        }
                    }

                    // Actions
                    Flow {
                        Layout.fillWidth: true
                        spacing: 6

                        RippleButtonWithIcon {
                            materialIcon: "open_in_browser"
                            mainText: Translation.tr("Open CUPS")
                            releaseAction: () => Printer.openQueue()
                        }
                        RippleButtonWithIcon {
                            materialIcon: "settings"
                            mainText: Translation.tr("Printer settings")
                            releaseAction: () => Quickshell.execDetached(["system-config-printer"])
                        }
                        RippleButtonWithIcon {
                            materialIcon: "content_paste"
                            mainText: Translation.tr("Print clipboard")
                            enabled: Printer.defaultPrinter.length > 0
                            releaseAction: () => Printer.printClipboard()
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
