import qs
import qs.modules.common
import qs.modules.common.widgets
import qs.services
import QtQuick
import QtQuick.Layouts
import Quickshell

/*
 * Per-entity control popup (WindowDialog, like the Wi-Fi/VPN dialogs). Sub-controls are
 * derived from the entity's own HA attributes (hvac_modes, fan_modes, source_list, ...).
 */
WindowDialog {
    id: root
    required property string entityId
    readonly property string domain: entityId.split(".")[0]
    backgroundWidth: Math.min(340, root.width - 24)

    function num(key, fallback) {
        return Number(HomeAssistant.attr(root.entityId, key, fallback));
    }

    WindowDialogTitle {
        text: HomeAssistant.friendlyName(root.entityId)
    }

    // State + on/off toggle
    RowLayout {
        Layout.fillWidth: true
        spacing: 8
        StyledText {
            Layout.fillWidth: true
            text: HomeAssistant.stateOf(root.entityId)
            color: Appearance.colors.colSubtext
        }
        RippleButtonWithIcon {
            visible: ["scene", "script", "button"].indexOf(root.domain) === -1
            materialIcon: HomeAssistant.isOn(root.entityId) ? "toggle_on" : "toggle_off"
            mainText: HomeAssistant.isOn(root.entityId) ? Translation.tr("On") : Translation.tr("Off")
            releaseAction: () => HomeAssistant.toggleEntity(root.entityId)
        }
    }

    // LIGHT — brightness
    ColumnLayout {
        Layout.fillWidth: true
        spacing: 4
        visible: root.domain === "light" && (HomeAssistant.attr(root.entityId, "supported_color_modes", []).indexOf("brightness") >= 0 || HomeAssistant.attr(root.entityId, "brightness", null) !== null)
        StyledText {
            text: Translation.tr("Brightness")
            color: Appearance.colors.colOnLayer1
        }
        StyledSlider {
            id: brightnessSlider
            Layout.fillWidth: true
            property real liveVal: root.num("brightness", 0) / 255
            onLiveValChanged: if (!pressed)
                value = liveVal
            Component.onCompleted: value = liveVal
            onPressedChanged: if (!pressed)
                HomeAssistant.setBrightnessPct(root.entityId, value * 100)
        }
    }

    // CLIMATE — target temp, hvac mode, fan mode
    ColumnLayout {
        Layout.fillWidth: true
        spacing: 8
        visible: root.domain === "climate"
        StyledText {
            text: Translation.tr("Current: %1°").arg(HomeAssistant.attr(root.entityId, "current_temperature", "–"))
            color: Appearance.colors.colSubtext
        }
        RowLayout {
            Layout.fillWidth: true
            spacing: 8
            StyledText {
                Layout.fillWidth: true
                text: Translation.tr("Target")
                color: Appearance.colors.colOnLayer1
            }
            RippleButtonWithIcon {
                materialIcon: "remove"
                mainText: ""
                releaseAction: () => HomeAssistant.setClimateTemp(root.entityId, Math.max(root.num("min_temp", 16), root.num("temperature", 20) - root.num("target_temp_step", 1)))
            }
            StyledText {
                text: `${HomeAssistant.attr(root.entityId, "temperature", "–")}°`
                color: Appearance.colors.colOnLayer1
                font.pixelSize: Appearance.font.pixelSize.normal
            }
            RippleButtonWithIcon {
                materialIcon: "add"
                mainText: ""
                releaseAction: () => HomeAssistant.setClimateTemp(root.entityId, Math.min(root.num("max_temp", 32), root.num("temperature", 20) + root.num("target_temp_step", 1)))
            }
        }
        StyledText {
            text: Translation.tr("Mode")
            color: Appearance.colors.colOnLayer1
        }
        Flow {
            Layout.fillWidth: true
            spacing: 6
            Repeater {
                model: HomeAssistant.attr(root.entityId, "hvac_modes", [])
                delegate: RippleButton {
                    required property string modelData
                    buttonText: modelData
                    toggled: HomeAssistant.stateOf(root.entityId) === modelData
                    releaseAction: () => HomeAssistant.setHvacMode(root.entityId, modelData)
                }
            }
        }
        StyledText {
            text: Translation.tr("Fan")
            color: Appearance.colors.colOnLayer1
        }
        Flow {
            Layout.fillWidth: true
            spacing: 6
            Repeater {
                model: HomeAssistant.attr(root.entityId, "fan_modes", [])
                delegate: RippleButton {
                    required property string modelData
                    buttonText: modelData
                    toggled: HomeAssistant.attr(root.entityId, "fan_mode", "") === modelData
                    releaseAction: () => HomeAssistant.setFanMode(root.entityId, modelData)
                }
            }
        }
    }

    // MEDIA PLAYER — transport, volume, source
    ColumnLayout {
        Layout.fillWidth: true
        spacing: 8
        visible: root.domain === "media_player"
        RowLayout {
            Layout.fillWidth: true
            spacing: 6
            RippleButtonWithIcon {
                materialIcon: "skip_previous"
                mainText: ""
                releaseAction: () => HomeAssistant.mediaCommand(root.entityId, "media_previous_track")
            }
            RippleButtonWithIcon {
                materialIcon: HomeAssistant.stateOf(root.entityId) === "playing" ? "pause" : "play_arrow"
                mainText: ""
                releaseAction: () => HomeAssistant.mediaCommand(root.entityId, "media_play_pause")
            }
            RippleButtonWithIcon {
                materialIcon: "skip_next"
                mainText: ""
                releaseAction: () => HomeAssistant.mediaCommand(root.entityId, "media_next_track")
            }
        }
        StyledText {
            text: Translation.tr("Volume")
            color: Appearance.colors.colOnLayer1
        }
        StyledSlider {
            id: volumeSlider
            Layout.fillWidth: true
            property real liveVal: root.num("volume_level", 0)
            onLiveValChanged: if (!pressed)
                value = liveVal
            Component.onCompleted: value = liveVal
            onPressedChanged: if (!pressed)
                HomeAssistant.setVolume(root.entityId, value)
        }
        Flow {
            Layout.fillWidth: true
            spacing: 6
            Repeater {
                model: HomeAssistant.attr(root.entityId, "source_list", [])
                delegate: RippleButton {
                    required property string modelData
                    buttonText: modelData
                    toggled: HomeAssistant.attr(root.entityId, "source", "") === modelData
                    releaseAction: () => HomeAssistant.selectSource(root.entityId, modelData)
                }
            }
        }
    }

    // VACUUM
    RowLayout {
        Layout.fillWidth: true
        spacing: 6
        visible: root.domain === "vacuum"
        RippleButtonWithIcon {
            materialIcon: "play_arrow"
            mainText: Translation.tr("Start")
            releaseAction: () => HomeAssistant.vacuumCommand(root.entityId, "start")
        }
        RippleButtonWithIcon {
            materialIcon: "home"
            mainText: Translation.tr("Dock")
            releaseAction: () => HomeAssistant.vacuumCommand(root.entityId, "return_to_base")
        }
        RippleButtonWithIcon {
            materialIcon: "stop"
            mainText: Translation.tr("Stop")
            releaseAction: () => HomeAssistant.vacuumCommand(root.entityId, "stop")
        }
    }

    WindowDialogButtonRow {
        DialogButton {
            buttonText: Translation.tr("Close")
            onClicked: root.dismiss()
        }
    }
}
