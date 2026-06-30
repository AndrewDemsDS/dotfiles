import QtQuick
import qs.modules.common
import qs.modules.common.widgets
import qs.services

QuickToggleButton {
    id: screenShaderButton
    toggled: ScreenShader.active
    buttonIcon: toggled ? "blur_on" : "blur_off"
    onClicked: {
        ScreenShader.toggle()
    }

    StyledToolTip {
        text: Translation.tr("Screen Shader")
    }
}
