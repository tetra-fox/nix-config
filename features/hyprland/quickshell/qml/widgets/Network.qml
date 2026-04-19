import qs.components
import qs.widgets.network
import QtQuick
import QtQuick.Layouts

Item {
    id: root

    Theme {
        id: theme
    }
    Icons {
        id: icons
    }

    property var panelWindow

    implicitWidth: btn.implicitWidth
    implicitHeight: btn.implicitHeight

    // ── active interface ──────────────────────────────────────────────────────
    readonly property string activeIfname: wired.connected ? wired.ifname : (wifi.activeNetwork ? wifi.ifname : "")
    readonly property bool anyConnected: activeIfname !== ""

    // ── bar button ────────────────────────────────────────────────────────────
    IconButton {
        id: btn
        icon: wired.connected ? icons.settingsEthernet : wifi.activeNetwork ? icons.wifi : icons.wifiOff
        iconColor: (wired.connected || wifi.activeNetwork) ? theme.textPrimary : theme.textInactive
        isOpen: popup.visible
        onClicked: _ => popup.visible = !popup.visible
    }

    // ── popup ─────────────────────────────────────────────────────────────────
    PopupWindow {
        id: popup
        panelWindow: root.panelWindow

        contentWidth: 320
        contentHeight: col.implicitHeight + theme.pillHPad * 2

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
                margins: theme.pillHPad
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
                    launcher.running = true;
                    popup.visible = false;
                }
            }
        }
    }

    BufferedProcess {
        id: launcher
        command: ["nm-connection-editor"]
    }
}
