import qs
import qs.services
import qs.modules.common
import qs.modules.common.widgets
import qs.modules.common.functions
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import Quickshell.Io

/*
 * Homelab "glance": one keybind (Super+Alt+G) → a summary window composed from
 * existing singletons (UpsMonitor, NasHealth, NewsFeeds, Weather). No new service —
 * each row guards on the singleton's own availability props and is hidden when not
 * configured. An independent, movable Hyprland floating window (not a modal overlay);
 * title "Homelab Glance" is matched by a hypr window_rule to float+center+size it.
 */
Scope {
    id: root

    property bool isOpen: false
    function open() {
        root.isOpen = true;
    }
    function close() {
        root.isOpen = false;
    }
    function toggle() {
        root.isOpen = !root.isOpen;
    }

    IpcHandler {
        target: "homelabGlance"
        function open(): void {
            root.open();
        }
        function close(): void {
            root.close();
        }
        function toggle(): void {
            root.toggle();
        }
        function status(): string {
            return `open=${root.isOpen}`;
        }
    }

    Loader {
        id: overlayLoader
        active: root.isOpen

        sourceComponent: FloatingWindow {
            id: winRoot
            title: "Homelab Glance"
            color: Appearance.colors.colLayer0
            implicitWidth: 760
            implicitHeight: 800

            visible: root.isOpen
            onVisibleChanged: {
                if (!visible)
                    root.close();
            }

            Rectangle {
                anchors.fill: parent
                color: Appearance.colors.colLayer0
                focus: true
                Keys.onPressed: event => {
                    if (event.key === Qt.Key_Escape)
                        root.close();
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
                            text: "dns"
                            iconSize: 22
                            color: Appearance.colors.colOnLayer0
                        }
                        StyledText {
                            Layout.fillWidth: true
                            text: Translation.tr("Homelab glance")
                            color: Appearance.colors.colOnLayer0
                            font.pixelSize: Appearance.font.pixelSize.normal
                        }
                    }

                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 8

                        // ── UPS / battery ───────────────────────────────
                        RowLayout {
                            Layout.fillWidth: true
                            spacing: 10
                            visible: UpsMonitor.valid
                            MaterialSymbol {
                                text: UpsMonitor.materialSymbol
                                iconSize: 20
                                color: UpsMonitor.statusColor
                            }
                            StyledText {
                                Layout.fillWidth: true
                                text: Translation.tr("UPS")
                                color: Appearance.colors.colOnLayer0
                                font.pixelSize: Appearance.font.pixelSize.normal
                            }
                            StyledText {
                                text: `${UpsMonitor.soc}%  ·  ${UpsMonitor.onBattery ? Translation.tr("on battery") : (UpsMonitor.charging ? Translation.tr("charging") : Translation.tr("on mains"))}`
                                color: UpsMonitor.statusColor
                                font.pixelSize: Appearance.font.pixelSize.smaller
                            }
                        }

                        // ── NAS storage ─────────────────────────────────
                        RowLayout {
                            Layout.fillWidth: true
                            spacing: 10
                            visible: NasHealth.configured
                            MaterialSymbol {
                                text: NasHealth.belowThreshold ? "storage" : "hard_drive_2"
                                iconSize: 20
                                color: NasHealth.belowThreshold ? Appearance.m3colors.m3error : Appearance.colors.colOnLayer0
                            }
                            StyledText {
                                Layout.fillWidth: true
                                text: Translation.tr("NAS")
                                color: Appearance.colors.colOnLayer0
                                font.pixelSize: Appearance.font.pixelSize.normal
                            }
                            StyledText {
                                text: !NasHealth.reachable ? Translation.tr("unreachable") : Translation.tr("%1 free").arg(NasHealth.freeHuman())
                                color: NasHealth.belowThreshold ? Appearance.m3colors.m3error : Appearance.colors.colSubtext
                                font.pixelSize: Appearance.font.pixelSize.smaller
                            }
                        }

                        // ── NAS containers ──────────────────────────────
                        RowLayout {
                            Layout.fillWidth: true
                            spacing: 10
                            visible: NasHealth.configured && NasHealth.containers.length > 0
                            property int upCount: {
                                let n = 0;
                                for (const c of NasHealth.containers)
                                    if (c.state === "running" && c.health !== "unhealthy")
                                        n++;
                                return n;
                            }
                            MaterialSymbol {
                                text: "deployed_code"
                                iconSize: 20
                                color: parent.upCount < NasHealth.containers.length ? Appearance.m3colors.m3error : Appearance.colors.colOnLayer0
                            }
                            StyledText {
                                Layout.fillWidth: true
                                text: Translation.tr("Containers")
                                color: Appearance.colors.colOnLayer0
                                font.pixelSize: Appearance.font.pixelSize.normal
                            }
                            StyledText {
                                text: `${parent.upCount}/${NasHealth.containers.length} ${Translation.tr("up")}`
                                color: parent.upCount < NasHealth.containers.length ? Appearance.m3colors.m3error : Appearance.colors.colSubtext
                                font.pixelSize: Appearance.font.pixelSize.smaller
                            }
                        }

                        // ── News unread ─────────────────────────────────
                        RowLayout {
                            Layout.fillWidth: true
                            spacing: 10
                            visible: Config.options.sidebar.news.enable
                            MaterialSymbol {
                                text: "rss_feed"
                                iconSize: 20
                                color: Appearance.colors.colOnLayer0
                            }
                            StyledText {
                                Layout.fillWidth: true
                                text: Translation.tr("News")
                                color: Appearance.colors.colOnLayer0
                                font.pixelSize: Appearance.font.pixelSize.normal
                            }
                            StyledText {
                                text: NewsFeeds.unreadCount > 0 ? Translation.tr("%1 unread").arg(NewsFeeds.unreadCount) : Translation.tr("all read")
                                color: NewsFeeds.unreadCount > 0 ? Appearance.colors.colPrimary : Appearance.colors.colSubtext
                                font.pixelSize: Appearance.font.pixelSize.smaller
                            }
                        }

                        // ── Weather ─────────────────────────────────────
                        RowLayout {
                            Layout.fillWidth: true
                            spacing: 10
                            visible: Config.options.bar.weather.enable && String(Weather.data.temp).length > 0
                            MaterialSymbol {
                                text: "device_thermostat"
                                iconSize: 20
                                color: Appearance.colors.colOnLayer0
                            }
                            StyledText {
                                Layout.fillWidth: true
                                text: Weather.data.city ? String(Weather.data.city) : Translation.tr("Weather")
                                color: Appearance.colors.colOnLayer0
                                font.pixelSize: Appearance.font.pixelSize.normal
                                elide: Text.ElideRight
                            }
                            StyledText {
                                text: String(Weather.data.temp)
                                color: Appearance.colors.colSubtext
                                font.pixelSize: Appearance.font.pixelSize.smaller
                            }
                        }

                        StyledText {
                            Layout.fillWidth: true
                            visible: !UpsMonitor.valid && !NasHealth.configured && !Config.options.sidebar.news.enable && !Config.options.bar.weather.enable
                            text: Translation.tr("Nothing to show — configure UPS / NAS / News / Weather.")
                            color: Appearance.colors.colSubtext
                            font.pixelSize: Appearance.font.pixelSize.smaller
                            wrapMode: Text.WordWrap
                        }
                    }

                    Item {
                        Layout.fillHeight: true
                    }
                }
            }
        }
    }
}
