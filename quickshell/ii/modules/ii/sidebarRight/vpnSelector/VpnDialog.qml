import qs
import qs.services
import qs.modules.common
import qs.modules.common.widgets
import QtQuick
import QtQuick.Layouts
import Quickshell

/*
 * VPN picker — long-press/menu of the VPN quick toggle. Lists available NM VPN/WireGuard
 * connections; selecting one sets it as the default the toggle controls
 * (Config.options.vpnStatus.toggleConnection, persisted). "Automatic" clears the override.
 */
WindowDialog {
    id: root
    backgroundHeight: 480

    WindowDialogTitle {
        text: Translation.tr("Choose VPN")
    }
    WindowDialogSeparator {}

    ListView {
        Layout.fillHeight: true
        Layout.fillWidth: true
        Layout.topMargin: -15
        Layout.bottomMargin: -16
        Layout.leftMargin: -Appearance.rounding.large
        Layout.rightMargin: -Appearance.rounding.large
        clip: true
        spacing: 0

        model: ScriptModel {
            values: [""].concat(VpnStatus.vpnConnections)
        }
        delegate: DialogListItem {
            required property string modelData
            readonly property bool isAuto: modelData.length === 0
            readonly property bool selected: Config.options.vpnStatus.toggleConnection === modelData
            readonly property bool isActive: !isAuto && VpnStatus.vpnUp && VpnStatus.vpnName === modelData
            width: ListView.view.width
            onClicked: {
                Config.options.vpnStatus.toggleConnection = modelData;
                VpnStatus.refresh();
            }
            contentItem: RowLayout {
                spacing: 12
                MaterialSymbol {
                    text: selected ? "radio_button_checked" : "radio_button_unchecked"
                    iconSize: Appearance.font.pixelSize.larger
                    color: selected ? Appearance.colors.colPrimary : Appearance.colors.colOnSurfaceVariant
                }
                MaterialSymbol {
                    text: isAuto ? "auto_mode" : (isActive ? "vpn_lock" : "vpn_key")
                    iconSize: Appearance.font.pixelSize.larger
                    color: Appearance.colors.colOnSurfaceVariant
                }
                StyledText {
                    Layout.fillWidth: true
                    text: isAuto ? Translation.tr("Automatic (current or first)") : modelData
                    color: Appearance.colors.colOnSurfaceVariant
                }
                StyledText {
                    visible: isActive
                    text: Translation.tr("active")
                    color: Appearance.colors.colPrimary
                    font.pixelSize: Appearance.font.pixelSize.smaller
                }
            }
        }
    }

    WindowDialogSeparator {}
    WindowDialogButtonRow {
        DialogButton {
            buttonText: Translation.tr("Close")
            onClicked: root.dismiss()
        }
    }
}
