import qs.components
import qs.widgets.network
import qs.lib
import Quickshell.Hyprland
import QtQuick
import QtQuick.Layouts

Item {
    id: root

    property var panelWindow

    implicitWidth: btn.implicitWidth
    implicitHeight: btn.implicitHeight

    readonly property string activeIfname: wired.connected ? wired.ifname : (wifi.activeNetwork ? wifi.ifname : "")
    readonly property bool anyConnected: activeIfname !== ""

    IconButton {
        id: btn
        icon: wired.connected ? Icons.settingsEthernet : wifi.activeNetwork ? Icons.wifi : Icons.wifiOff
        iconColor: (wired.connected || wifi.activeNetwork) ? Theme.textPrimary : Theme.textInactive
        isOpen: popup.visible
        onClicked: _ => popup.visible = !popup.visible
    }

    PopupWindow {
        id: popup
        panelWindow: root.panelWindow
        anchorItem: btn

        contentWidth: 320
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
                polling: popup.visible
            }

            Separator {}

            WifiSection {
                id: wifi
                Layout.fillWidth: true
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
                    Hyprland.dispatch("exec app2unit -- nm-connection-editor");
                    popup.visible = false;
                }
            }
        }
    }
}
