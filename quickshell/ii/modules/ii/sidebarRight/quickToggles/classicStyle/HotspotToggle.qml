import qs.services
import qs.modules.common
import qs.modules.common.widgets
import qs
import QtQuick
import Quickshell

QuickToggleButton {
    id: root
    toggled: Hotspot.enabled
    buttonIcon: Hotspot.materialSymbol
    onClicked: Hotspot.toggle()
    StyledToolTip {
        text: Translation.tr("Hotspot: %1 | Right-click to configure").arg(Hotspot.ssid)
    }
}
