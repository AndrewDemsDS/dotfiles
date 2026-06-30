import qs
import qs.services
import qs.modules.common
import qs.modules.common.functions
import qs.modules.common.widgets
import QtQuick
import QtQuick.Layouts
import Quickshell

/*
 * Hotspot configuration + QR. Edits the NM "Hotspot" profile (SSID / password / band)
 * via Hotspot.applyConfig, toggles it on/off, and renders a Wi-Fi QR a phone can scan
 * to join. Source of truth is the profile, so fields seed from Hotspot on open.
 */
WindowDialog {
    id: root
    backgroundWidth: 380
    backgroundHeight: 640

    // Local edit buffer, seeded from the live profile.
    property string fSsid: Hotspot.ssid
    property string fPassword: Hotspot.password
    property string fBand: Hotspot.band

    readonly property bool dirty: fSsid !== Hotspot.ssid || fPassword !== Hotspot.password || fBand !== Hotspot.band
    readonly property bool passwordValid: fPassword.length >= 8

    Component.onCompleted: {
        Hotspot.refresh();
        Hotspot.regenerateQr();
    }
    // Re-seed if the profile changes underneath us (e.g. first read completes after open).
    Connections {
        target: Hotspot
        function onSsidChanged() { if (!root.dirty) root.fSsid = Hotspot.ssid; }
        function onPasswordChanged() { if (!root.dirty) root.fPassword = Hotspot.password; }
        function onBandChanged() { if (!root.dirty) root.fBand = Hotspot.band; }
    }

    WindowDialogTitle {
        text: Translation.tr("Hotspot")
    }
    WindowDialogSeparator {}

    // Status + on/off
    RowLayout {
        Layout.fillWidth: true
        spacing: 10
        MaterialSymbol {
            iconSize: Appearance.font.pixelSize.huge
            text: Hotspot.materialSymbol
            color: Hotspot.enabled ? Appearance.colors.colPrimary : Appearance.colors.colOnSurfaceVariant
        }
        ColumnLayout {
            Layout.fillWidth: true
            spacing: 0
            StyledText {
                text: Hotspot.enabled ? Translation.tr("On") : Translation.tr("Off")
                color: Appearance.colors.colOnSurface
            }
            StyledText {
                Layout.fillWidth: true
                elide: Text.ElideRight
                text: Hotspot.iface.length > 0
                    ? Translation.tr("Device: %1").arg(Hotspot.iface)
                    : Translation.tr("No Wi-Fi device")
                color: Appearance.colors.colOnSurfaceVariant
                font.pixelSize: Appearance.font.pixelSize.smaller
            }
        }
        DialogButton {
            buttonText: Hotspot.enabled ? Translation.tr("Stop") : Translation.tr("Start")
            enabled: !Hotspot.busy && Hotspot.iface.length > 0 && (Hotspot.enabled || (Hotspot.profileExists && Hotspot.passwordValid))
            onClicked: Hotspot.toggle()
        }
    }

    // SSID
    MaterialTextField {
        Layout.fillWidth: true
        placeholderText: Translation.tr("Network name (SSID)")
        text: root.fSsid
        onTextChanged: root.fSsid = text
    }

    // Password (masked by default; the eye toggles reveal)
    RowLayout {
        Layout.fillWidth: true
        spacing: 4
        MaterialTextField {
            id: passwordField
            Layout.fillWidth: true
            property bool revealed: false
            placeholderText: Translation.tr("Password (8+ characters)")
            text: root.fPassword
            onTextChanged: root.fPassword = text
            echoMode: revealed ? TextInput.Normal : TextInput.Password
            inputMethodHints: Qt.ImhSensitiveData
        }
        IconToolbarButton {
            Layout.preferredHeight: passwordField.implicitHeight
            Layout.preferredWidth: Layout.preferredHeight
            text: passwordField.revealed ? "visibility_off" : "visibility"
            toggled: passwordField.revealed
            onClicked: passwordField.revealed = !passwordField.revealed
            StyledToolTip {
                text: passwordField.revealed ? Translation.tr("Hide password") : Translation.tr("Show password")
            }
        }
    }
    StyledText {
        visible: !root.passwordValid
        text: Translation.tr("Password must be at least 8 characters.")
        color: Appearance.m3colors.m3error
        font.pixelSize: Appearance.font.pixelSize.smaller
    }

    // Band selector
    RowLayout {
        Layout.fillWidth: true
        spacing: 6
        StyledText {
            text: Translation.tr("Band")
            color: Appearance.colors.colOnSurfaceVariant
        }
        Item { Layout.fillWidth: true }
        DialogButton {
            buttonText: Translation.tr("2.4 GHz")
            colBackground: root.fBand === "bg" ? Appearance.colors.colPrimaryContainer : ColorUtils.transparentize(Appearance.colors.colLayer3)
            colText: root.fBand === "bg" ? Appearance.m3colors.m3onPrimaryContainer : Appearance.colors.colPrimary
            onClicked: root.fBand = "bg"
        }
        DialogButton {
            buttonText: Translation.tr("5 GHz")
            colBackground: root.fBand === "a" ? Appearance.colors.colPrimaryContainer : ColorUtils.transparentize(Appearance.colors.colLayer3)
            colText: root.fBand === "a" ? Appearance.m3colors.m3onPrimaryContainer : Appearance.colors.colPrimary
            onClicked: root.fBand = "a"
        }
    }

    // QR code — scan with a phone camera to join
    Rectangle {
        Layout.alignment: Qt.AlignHCenter
        Layout.topMargin: 4
        implicitWidth: 220
        implicitHeight: 220
        radius: Appearance.rounding.normal
        color: "white"
        visible: Hotspot.profileExists && root.passwordValid && !root.dirty

        Image {
            anchors.centerIn: parent
            width: 200
            height: 200
            cache: false
            smooth: false
            fillMode: Image.PreserveAspectFit
            source: Hotspot.qrPath.length > 0 ? `file://${Hotspot.qrPath}?v=${Hotspot.qrGeneration}` : ""
            sourceSize.width: 400
            sourceSize.height: 400
        }
    }
    StyledText {
        Layout.alignment: Qt.AlignHCenter
        visible: Hotspot.profileExists && root.passwordValid && !root.dirty
        text: Translation.tr("Scan to join")
        color: Appearance.colors.colOnSurfaceVariant
        font.pixelSize: Appearance.font.pixelSize.smaller
    }
    StyledText {
        Layout.alignment: Qt.AlignHCenter
        Layout.fillWidth: true
        horizontalAlignment: Text.AlignHCenter
        wrapMode: Text.WordWrap
        visible: root.dirty
        text: Translation.tr("Apply changes to update the QR code.")
        color: Appearance.colors.colOnSurfaceVariant
        font.pixelSize: Appearance.font.pixelSize.smaller
    }

    Item { Layout.fillHeight: true }

    WindowDialogSeparator {}
    WindowDialogButtonRow {
        DialogButton {
            buttonText: Translation.tr("Apply")
            enabled: root.dirty && root.passwordValid && root.fSsid.length > 0 && !Hotspot.busy
            onClicked: Hotspot.applyConfig(root.fSsid, root.fPassword, root.fBand)
        }
        Item { Layout.fillWidth: true }
        DialogButton {
            buttonText: Translation.tr("Close")
            onClicked: root.dismiss()
        }
    }
}
