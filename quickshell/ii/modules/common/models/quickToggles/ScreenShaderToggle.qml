import QtQuick
import qs.services
import qs.modules.common
import qs.modules.common.functions
import qs.modules.common.widgets

QuickToggleModel {
    name: Translation.tr("Screen Shader")
    statusText: toggled ? Translation.tr("On") : Translation.tr("Off")
    tooltipText: Translation.tr("Screen Shader")
    icon: toggled ? "blur_on" : "blur_off"
    available: Config.options.light.shader.enable
    toggled: ScreenShader.active

    mainAction: () => {
        ScreenShader.toggle()
    }
}
