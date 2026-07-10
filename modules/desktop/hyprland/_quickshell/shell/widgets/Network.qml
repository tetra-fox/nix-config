import qs.components
import qs.widgets.network
import qs.lib
import Quickshell
import QtQuick
import QtQuick.Layouts

BarPopupButton {
    id: root

    // a live wg tunnel owns the default route, so the detail/traffic blocks follow it.
    // device is the enumerate DEVICE column, available without a detail round-trip
    readonly property string activeIfname: vpn.anyActive ? vpn.activeTunnel.device : wired.connected ? wired.ifname : (wifi.activeNetwork ? wifi.ifname : "")
    readonly property bool anyConnected: activeIfname !== ""

    // vpn takes icon priority when up (most security-relevant state), tinted to read as secured
    icon: vpn.anyActive ? Icons.vpnKey : wired.connected ? Icons.settingsEthernet : wifi.activeNetwork ? Icons.wifi : Icons.wifiOff
    iconColor: vpn.anyActive ? Theme.colorGreen : (wired.connected || wifi.activeNetwork) ? Theme.textPrimary : Theme.textInactive

    onPopupVisibleChanged: {
        if (popupVisible)
            traffic.reset();
    }

    WiredSection {
        id: wired
        Layout.fillWidth: true
    }

    Separator {}

    WifiSection {
        id: wifi
        Layout.fillWidth: true
        scannerEnabled: root.popupVisible
    }

    Separator {
        visible: vpn.visible
    }

    VpnSection {
        id: vpn
        Layout.fillWidth: true
        polling: root.popupVisible
    }

    Separator {
        visible: connDetails.visible
    }

    ConnectionDetails {
        id: connDetails
        Layout.fillWidth: true
        ifname: root.activeIfname
        polling: root.popupVisible && root.anyConnected
    }

    Separator {
        visible: traffic.visible
    }

    TrafficGraph {
        id: traffic
        Layout.fillWidth: true
        ifname: root.activeIfname
        polling: root.popupVisible && root.anyConnected
    }

    Separator {}

    MenuItem {
        Layout.fillWidth: true
        text: "More settings..."
        onClicked: {
            Quickshell.execDetached(["app2unit", "--", "nm-connection-editor"]);
            root.popupVisible = false;
        }
    }
}
