import qs
import qs.services
import qs.modules.common
import qs.modules.common.widgets
import QtQuick
import QtQuick.Layouts
import Quickshell

/*
 * VPN manager — the menu of the VPN quick toggle. Lists NM VPN/WireGuard profiles
 * with per-profile connect/disconnect, set-as-toggle-default, start-on-login,
 * rename and delete (see VpnProfileItem). Also toggles auto-connect (which also
 * auto-disconnects on trusted networks) and imports .conf/.ovpn profile files.
 */
WindowDialog {
    id: root
    backgroundHeight: 620

    WindowDialogTitle {
        text: Translation.tr("VPN profiles")
    }
    WindowDialogSeparator {}

    ConfigSwitch {
        Layout.fillWidth: true
        buttonIcon: Config.options.vpnStatus.autoConnect ? "auto_mode" : "vpn_key_off"
        text: Translation.tr("Auto VPN off home networks")
        checked: Config.options.vpnStatus.autoConnect
        onCheckedChanged: {
            if (checked !== Config.options.vpnStatus.autoConnect) {
                Config.options.vpnStatus.autoConnect = checked;
                if (checked)
                    VpnStatus.refresh();
            }
        }
    }

    ListView {
        Layout.fillHeight: true
        Layout.fillWidth: true
        Layout.topMargin: -6
        Layout.bottomMargin: -8
        Layout.leftMargin: -Appearance.rounding.large
        Layout.rightMargin: -Appearance.rounding.large
        clip: true
        spacing: 0

        model: ScriptModel {
            values: VpnStatus.vpnProfiles
        }
        delegate: VpnProfileItem {
            width: ListView.view.width
        }

        StyledText { // empty state
            anchors.centerIn: parent
            visible: VpnStatus.vpnProfiles.length === 0
            text: Translation.tr("No VPN profiles.\nImport a .conf or .ovpn below.")
            horizontalAlignment: Text.AlignHCenter
            color: Appearance.colors.colSubtext
            font.pixelSize: Appearance.font.pixelSize.smaller
        }
    }

    WindowDialogSeparator {}

    RowLayout { // Import a WireGuard (.conf) / OpenVPN (.ovpn) file
        Layout.fillWidth: true
        spacing: 6
        MaterialTextField {
            id: importField
            Layout.fillWidth: true
            placeholderText: Translation.tr("Path to .conf / .ovpn to import")
            onAccepted: {
                VpnStatus.importConfig(text);
                text = "";
            }
        }
        DialogButton {
            buttonText: Translation.tr("Browse…")
            onClicked: VpnStatus.browseImport()
        }
        DialogButton {
            buttonText: Translation.tr("Import")
            enabled: importField.text.trim().length > 0
            onClicked: {
                VpnStatus.importConfig(importField.text);
                importField.text = "";
            }
        }
    }

    WindowDialogSeparator {}
    WindowDialogButtonRow {
        DialogButton {
            buttonText: Translation.tr("Details")
            onClicked: {
                Quickshell.execDetached(["bash", "-c", Config.options.apps.network]);
                GlobalStates.sidebarRightOpen = false;
            }
        }
        Item {
            Layout.fillWidth: true
        }
        DialogButton {
            buttonText: Translation.tr("Close")
            onClicked: root.dismiss()
        }
    }
}
