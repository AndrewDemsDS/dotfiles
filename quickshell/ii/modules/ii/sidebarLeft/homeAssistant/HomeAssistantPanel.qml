import qs.modules.common
import qs.modules.common.widgets
import qs.services
import QtQuick
import QtQuick.Layouts

/*
 * Home Assistant control panel — a left-sidebar tab (next to Intelligence/Anime).
 * Renders a tile per configured entity (Config.options.homeAssistant.entities);
 * tap toggles lights/switches, activates scenes/scripts. Header shows online/failover.
 */
Item {
    id: root

    property string detailEntity: ""

    // Entities that have sub-controls worth an expand affordance.
    function hasDetail(entityId) {
        const d = entityId.split(".")[0];
        if (d === "climate" || d === "media_player" || d === "fan" || d === "cover" || d === "vacuum")
            return true;
        if (d === "light")
            return HomeAssistant.attr(entityId, "supported_color_modes", []).indexOf("brightness") >= 0 || HomeAssistant.attr(entityId, "brightness", null) !== null;
        return false;
    }

    function iconFor(entityId) {
        const d = entityId.split(".")[0];
        switch (d) {
        case "light":
            return "lightbulb";
        case "switch":
        case "input_boolean":
            return "toggle_on";
        case "scene":
            return "movie";
        case "script":
            return "play_arrow";
        case "fan":
            return "mode_fan";
        case "climate":
            return "thermostat";
        case "cover":
            return "blinds";
        case "lock":
            return HomeAssistant.isOn(entityId) ? "lock_open" : "lock";
        case "media_player":
            return "speaker";
        case "button":
            return "smart_button";
        case "automation":
            return "bolt";
        default:
            return "category";
        }
    }

    readonly property string statusText: !HomeAssistant.configured ? Translation.tr("not configured") : !HomeAssistant.online ? Translation.tr("offline") : HomeAssistant.usingFallback ? Translation.tr("failover") : Translation.tr("online")
    readonly property color statusColor: !HomeAssistant.configured ? Appearance.colors.colSubtext : !HomeAssistant.online ? Appearance.m3colors.m3error : HomeAssistant.usingFallback ? Appearance.colors.colSecondary : Appearance.colors.colPrimary

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 12
        spacing: 10

        RowLayout {
            Layout.fillWidth: true
            spacing: 8
            MaterialSymbol {
                text: "home"
                iconSize: 22
                color: Appearance.colors.colOnLayer1
            }
            StyledText {
                Layout.fillWidth: true
                text: Translation.tr("Home Assistant")
                color: Appearance.colors.colOnLayer1
                font.pixelSize: Appearance.font.pixelSize.normal
            }
            StyledText {
                text: root.statusText
                color: root.statusColor
                font.pixelSize: Appearance.font.pixelSize.smaller
            }
        }

        StyledText {
            Layout.fillWidth: true
            visible: !HomeAssistant.configured || Config.options.homeAssistant.entities.length === 0
            wrapMode: Text.WordWrap
            color: Appearance.colors.colSubtext
            font.pixelSize: Appearance.font.pixelSize.small
            text: !HomeAssistant.configured ? Translation.tr("Set homeAssistant.baseUrl and drop a long-lived token in ~/.config/quickshell/secrets/ha_token, then set homeAssistant.enable.") : Translation.tr("Add entity_ids to homeAssistant.entities (e.g. light.kitchen, scene.movie).")
        }

        Flickable {
            id: flick
            Layout.fillWidth: true
            Layout.fillHeight: true
            contentHeight: tileFlow.implicitHeight
            clip: true
            visible: HomeAssistant.configured && Config.options.homeAssistant.entities.length > 0

            Flow {
                id: tileFlow
                width: flick.width
                spacing: 8

                Repeater {
                    model: Config.options.homeAssistant.entities
                    delegate: Rectangle {
                        id: tile
                        required property string modelData
                        readonly property bool isOn: HomeAssistant.isOn(tile.modelData)
                        readonly property color fg: tile.isOn ? Appearance.colors.colOnPrimaryContainer : Appearance.colors.colOnLayer2
                        readonly property bool expandable: root.hasDetail(tile.modelData)
                        width: (tileFlow.width - tileFlow.spacing) / 2
                        height: 60
                        radius: Appearance.rounding.normal
                        color: tile.isOn ? Appearance.colors.colPrimaryContainer : Appearance.colors.colLayer2

                        RowLayout {
                            anchors.fill: parent
                            anchors.margins: 10
                            spacing: 6
                            MaterialSymbol {
                                text: root.iconFor(tile.modelData)
                                iconSize: 24
                                color: tile.fg
                            }
                            ColumnLayout {
                                Layout.fillWidth: true
                                spacing: 0
                                StyledText {
                                    Layout.fillWidth: true
                                    text: HomeAssistant.friendlyName(tile.modelData)
                                    color: tile.fg
                                    elide: Text.ElideRight
                                    font.pixelSize: Appearance.font.pixelSize.small
                                }
                                StyledText {
                                    Layout.fillWidth: true
                                    text: HomeAssistant.stateOf(tile.modelData)
                                    color: Appearance.colors.colSubtext
                                    elide: Text.ElideRight
                                    font.pixelSize: Appearance.font.pixelSize.smaller
                                }
                            }
                            MaterialSymbol {
                                visible: tile.expandable
                                text: "tune"
                                iconSize: 20
                                color: tile.fg
                                opacity: 0.85
                            }
                        }
                        // Whole tile = quick toggle
                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            onClicked: HomeAssistant.toggleEntity(tile.modelData)
                            onPressAndHold: if (tile.expandable)
                                root.detailEntity = tile.modelData
                        }
                        // Right edge over the tune icon = open controls (on top of the toggle)
                        MouseArea {
                            visible: tile.expandable
                            width: 42
                            anchors {
                                right: parent.right
                                top: parent.top
                                bottom: parent.bottom
                            }
                            cursorShape: Qt.PointingHandCursor
                            onClicked: root.detailEntity = tile.modelData
                        }
                    }
                }
            }
        }
    }

    // Tapping a tile's tune icon opens its control popup (WindowDialog, like Wi-Fi/VPN)
    Loader {
        id: detailLoader
        anchors.fill: parent
        readonly property bool shouldShow: root.detailEntity.length > 0
        active: shouldShow
        onShouldShowChanged: if (shouldShow)
            active = true
        onActiveChanged: if (active) {
            item.show = true;
            item.forceActiveFocus();
        }
        sourceComponent: EntityDetail {
            entityId: root.detailEntity
        }
        Connections {
            target: detailLoader.item
            function onDismiss() {
                detailLoader.item.show = false;
                root.detailEntity = "";
            }
            function onVisibleChanged() {
                if (!detailLoader.item.visible && root.detailEntity.length === 0)
                    detailLoader.active = false;
            }
        }
    }
}
