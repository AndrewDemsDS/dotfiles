import qs
import qs.modules.common
import qs.modules.common.widgets
import qs.services
import QtQuick
import QtQuick.Layouts

/*
 * One VPN/WireGuard profile row in the manager. Collapsed: name + state, click to
 * connect/disconnect. The "tune" button expands an inline panel (like the wifi
 * password prompt) with: set-as-default-toggle, start-on-login (NM autoconnect),
 * rename, and delete (two-step confirm). All actions go through VpnStatus (nmcli).
 */
DialogListItem {
    id: root
    required property var modelData // {name, uuid, type, autoconnect}
    readonly property string vpnName: modelData?.name ?? ""
    readonly property bool isActive: VpnStatus.activeVpnNames.indexOf(root.vpnName) !== -1
    readonly property bool isDefault: Config.options.vpnStatus.toggleConnection === root.vpnName

    property bool expanded: false
    property bool confirmingDelete: false
    property string editName: root.vpnName

    active: expanded || isActive
    onClicked: {
        if (root.isActive)
            VpnStatus.disconnectProfile(root.vpnName);
        else
            VpnStatus.connectProfile(root.vpnName);
    }

    contentItem: ColumnLayout {
        anchors {
            fill: parent
            topMargin: root.verticalPadding
            bottomMargin: root.verticalPadding
            leftMargin: root.horizontalPadding
            rightMargin: root.horizontalPadding
        }
        spacing: 0

        RowLayout {
            spacing: 10
            MaterialSymbol {
                iconSize: Appearance.font.pixelSize.larger
                text: root.isActive ? "vpn_lock" : "vpn_key"
                color: root.isActive ? Appearance.colors.colPrimary : Appearance.colors.colOnSurfaceVariant
            }
            StyledText {
                Layout.fillWidth: true
                color: Appearance.colors.colOnSurfaceVariant
                elide: Text.ElideRight
                text: root.vpnName
                textFormat: Text.PlainText
            }
            StyledText {
                visible: root.isDefault
                text: Translation.tr("default")
                color: Appearance.colors.colSubtext
                font.pixelSize: Appearance.font.pixelSize.smaller
            }
            StyledText {
                visible: root.isActive
                text: Translation.tr("active")
                color: Appearance.colors.colPrimary
                font.pixelSize: Appearance.font.pixelSize.smaller
            }
            // Expand / collapse the edit panel. Stop the click reaching the row toggle.
            RippleButton {
                implicitWidth: 30
                implicitHeight: 30
                buttonRadius: Appearance.rounding.full
                toggled: root.expanded
                onClicked: root.expanded = !root.expanded
                contentItem: MaterialSymbol {
                    anchors.centerIn: parent
                    text: "tune"
                    iconSize: Appearance.font.pixelSize.larger
                    color: root.expanded ? Appearance.colors.colOnPrimary : Appearance.colors.colOnSurfaceVariant
                }
            }
        }

        ColumnLayout { // Inline edit panel
            id: editPanel
            Layout.topMargin: root.expanded ? 8 : 0
            Layout.fillWidth: true
            visible: root.expanded
            spacing: 6

            Flow {
                Layout.fillWidth: true
                spacing: 6
                RippleButton {
                    buttonText: root.isActive ? Translation.tr("Disconnect") : Translation.tr("Connect")
                    toggled: root.isActive
                    releaseAction: () => root.isActive ? VpnStatus.disconnectProfile(root.vpnName) : VpnStatus.connectProfile(root.vpnName)
                }
                RippleButton {
                    buttonText: root.isDefault ? Translation.tr("Default toggle ✓") : Translation.tr("Set as toggle default")
                    toggled: root.isDefault
                    releaseAction: () => {
                        Config.options.vpnStatus.toggleConnection = root.isDefault ? "" : root.vpnName;
                        VpnStatus.refresh();
                    }
                }
                RippleButton {
                    buttonText: (root.modelData?.autoconnect ?? false) ? Translation.tr("Start on login ✓") : Translation.tr("Start on login")
                    toggled: root.modelData?.autoconnect ?? false
                    releaseAction: () => VpnStatus.setProfileAutoconnect(root.vpnName, !(root.modelData?.autoconnect ?? false))
                }
            }

            RowLayout {
                Layout.fillWidth: true
                spacing: 6
                MaterialTextField {
                    id: renameField
                    Layout.fillWidth: true
                    placeholderText: Translation.tr("Rename profile")
                    text: root.editName
                    onTextChanged: root.editName = text
                    onAccepted: VpnStatus.renameProfile(root.vpnName, root.editName)
                }
                DialogButton {
                    buttonText: Translation.tr("Rename")
                    enabled: root.editName.length > 0 && root.editName !== root.vpnName
                    onClicked: VpnStatus.renameProfile(root.vpnName, root.editName)
                }
            }

            RowLayout { // Delete, two-step
                Layout.fillWidth: true
                Item { Layout.fillWidth: true }
                DialogButton {
                    visible: !root.confirmingDelete
                    buttonText: Translation.tr("Delete")
                    onClicked: root.confirmingDelete = true
                }
                StyledText {
                    visible: root.confirmingDelete
                    Layout.fillWidth: true
                    text: Translation.tr("Delete “%1”?").arg(root.vpnName)
                    color: Appearance.m3colors.m3error
                    font.pixelSize: Appearance.font.pixelSize.smaller
                    elide: Text.ElideRight
                }
                DialogButton {
                    visible: root.confirmingDelete
                    buttonText: Translation.tr("Cancel")
                    onClicked: root.confirmingDelete = false
                }
                DialogButton {
                    visible: root.confirmingDelete
                    buttonText: Translation.tr("Confirm")
                    onClicked: {
                        root.confirmingDelete = false;
                        VpnStatus.deleteProfile(root.vpnName);
                    }
                }
            }
        }

        Item {
            Layout.fillHeight: true
        }
    }
}
