import qs.modules.common
import qs.modules.common.widgets
import qs.services
import QtQuick
import QtQuick.Layouts

/*
 * Compact sidebar card that appears only when the dotfiles repo has drifted from git.
 * Shows the change count and a one-click "Commit & push". Backed by DotfilesDrift service.
 */
Rectangle {
    id: root
    Layout.fillWidth: true
    visible: DotfilesDrift.dirty || DotfilesDrift.pushing
    implicitHeight: visible ? contentRow.implicitHeight + 20 : 0
    radius: Appearance.rounding.normal
    color: Appearance.colors.colLayer1
    clip: true

    RowLayout {
        id: contentRow
        anchors {
            left: parent.left
            right: parent.right
            verticalCenter: parent.verticalCenter
            leftMargin: 12
            rightMargin: 12
        }
        spacing: 10

        MaterialSymbol {
            text: DotfilesDrift.pushing ? "cloud_upload" : "commit"
            iconSize: 26
            color: Appearance.colors.colOnLayer1
        }

        ColumnLayout {
            Layout.fillWidth: true
            spacing: 0

            StyledText {
                text: Translation.tr("Dotfiles drift")
                color: Appearance.colors.colOnLayer1
                font.pixelSize: Appearance.font.pixelSize.normal
            }

            StyledText {
                Layout.fillWidth: true
                text: DotfilesDrift.pushing
                    ? Translation.tr("Committing & pushing…")
                    : Translation.tr("%1 uncommitted change(s)").arg(DotfilesDrift.changedCount)
                color: Appearance.colors.colSubtext
                font.pixelSize: Appearance.font.pixelSize.smaller
                elide: Text.ElideRight
            }
        }

        RippleButtonWithIcon {
            materialIcon: "upload"
            mainText: Translation.tr("Commit & push")
            enabled: DotfilesDrift.dirty && !DotfilesDrift.pushing
            releaseAction: () => DotfilesDrift.commitAndPush()
        }
    }
}
