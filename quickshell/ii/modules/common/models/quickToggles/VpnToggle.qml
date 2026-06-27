import qs.services
import qs.modules.common
import QtQuick

/*
 * Quick toggle for the configured VPN connection (mirrors CloudflareWarpToggle).
 * Target is VpnStatus.toggleTarget (config vpnStatus.toggleConnection, else auto).
 */
QuickToggleModel {
    id: root
    name: Translation.tr("VPN")
    icon: VpnStatus.vpnUp ? "vpn_lock" : "vpn_key"
    toggled: VpnStatus.vpnUp
    available: VpnStatus.toggleTarget.length > 0
    hasMenu: true
    mainAction: () => VpnStatus.toggle()
    tooltipText: VpnStatus.toggleTarget.length > 0 ? Translation.tr("VPN: %1").arg(VpnStatus.toggleTarget) : Translation.tr("No VPN configured")
}
