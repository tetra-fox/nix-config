import qs.components
import qs.widgets.network
import qs.lib
import Quickshell
import QtQuick
import QtQuick.Layouts

Item {
    id: root

    property var panelWindow

    implicitWidth: btn.implicitWidth
    implicitHeight: btn.implicitHeight

    // a live wg tunnel owns the default route, so the detail/traffic blocks follow it.
    // device is the enumerate DEVICE column, available without a detail round-trip
    readonly property string activeIfname: vpn.anyActive ? vpn.activeTunnel.device : wired.connected ? wired.ifname : (wifi.activeNetwork ? wifi.ifname : "")
    readonly property bool anyConnected: activeIfname !== ""

    IconButton {
        id: btn
        // vpn takes icon priority when up (most security-relevant state), tinted to read as secured
        icon: vpn.anyActive ? Icons.vpnKey : wired.connected ? Icons.settingsEthernet : wifi.activeNetwork ? Icons.wifi : Icons.wifiOff
        iconColor: vpn.anyActive ? Theme.colorGreen : (wired.connected || wifi.activeNetwork) ? Theme.textPrimary : Theme.textInactive
        isOpen: popup.visible
        onClicked: _ => popup.visible = !popup.visible
    }

    PopupWindow {
        id: popup
        panelWindow: root.panelWindow
        anchorItem: btn

        contentWidth: Theme.popupWidth
        contentHeight: col.implicitHeight + Theme.pillHPad * 2

        onVisibleChanged: {
            if (visible) {
                traffic.reset();
                connDetails.fetch();
                wifi.scannerEnabled = true;
            } else {
                wifi.scannerEnabled = false;
            }
        }

        ColumnLayout {
            id: col
            anchors {
                top: parent.top
                left: parent.left
                right: parent.right
                margins: Theme.pillHPad
            }
            spacing: 10

            WiredSection {
                id: wired
                Layout.fillWidth: true
            }

            Separator {}

            WifiSection {
                id: wifi
                Layout.fillWidth: true
            }

            Separator {
                visible: vpn.visible
            }

            VpnSection {
                id: vpn
                Layout.fillWidth: true
                polling: popup.visible
            }

            Separator {
                visible: connDetails.visible
            }

            ConnectionDetails {
                id: connDetails
                Layout.fillWidth: true
                ifname: root.activeIfname
                polling: popup.visible && root.anyConnected
            }

            Separator {
                visible: traffic.visible
            }

            TrafficGraph {
                id: traffic
                Layout.fillWidth: true
                ifname: root.activeIfname
                polling: popup.visible && root.anyConnected
            }

            Separator {}

            MenuItem {
                Layout.fillWidth: true
                text: "More settings..."
                onClicked: {
                    Quickshell.execDetached(["app2unit", "--", "nm-connection-editor"]);
                    popup.visible = false;
                }
            }
        }
    }
}
