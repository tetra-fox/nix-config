pragma ComponentBehavior: Bound

import qs.components
import qs.lib
import Quickshell.Io
import Quickshell.Networking
import QtQuick
import QtQuick.Layouts

Item {
    id: root

    // multiple wired NICs enumerate in PCI order, not link order; prefer the one with carrier
    readonly property var _wiredDevices: Networking.devices.values.filter(d => d && d.type === DeviceType.Wired)
    readonly property WiredDevice wiredDevice: _wiredDevices.find(d => d.connected) ?? _wiredDevices.find(d => d.hasLink) ?? _wiredDevices[0] ?? null
    readonly property bool available: wiredDevice !== null
    readonly property string ifname: wiredDevice?.name ?? ""
    readonly property bool hasLink: wiredDevice?.hasLink ?? false
    readonly property bool connected: wiredDevice?.connected ?? false
    readonly property int connState: wiredDevice?.state ?? ConnectionState.Unknown
    readonly property bool stateChanging: connState === ConnectionState.Connecting || connState === ConnectionState.Disconnecting
    readonly property int linkSpeed: wiredDevice?.linkSpeed ?? 0
    readonly property string mac: (wiredDevice?.address ?? "").toLowerCase() // qmllint disable missing-property
    readonly property Network network: wiredDevice?.network ?? null // qmllint disable unresolved-type

    // mtu and duplex aren't exposed by quickshell; fetch from sysfs on link change
    property int mtu: 0
    property string duplex: ""

    function refreshSysfs() {
        if (ifname === "") {
            root.mtu = 0;
            root.duplex = "";
            return;
        }
        mtuFile.reload();
        duplexFile.reload();
    }

    onIfnameChanged: refreshSysfs()
    onHasLinkChanged: refreshSysfs()
    onConnectedChanged: refreshSysfs()

    FileView {
        id: mtuFile
        path: root.ifname !== "" ? "/sys/class/net/" + root.ifname + "/mtu" : ""
        onLoaded: {
            const n = parseInt(text().trim());
            root.mtu = isNaN(n) ? 0 : n;
        }
    }

    FileView {
        id: duplexFile
        path: root.ifname !== "" ? "/sys/class/net/" + root.ifname + "/duplex" : ""
        onLoaded: root.duplex = text().trim()
    }

    implicitHeight: visible ? col.implicitHeight : 0
    visible: root.available

    ColumnLayout {
        id: col
        anchors {
            top: parent.top
            left: parent.left
            right: parent.right
        }
        spacing: 5

        RowLayout {
            Layout.fillWidth: true

            Text {
                text: "Ethernet"
                color: Theme.textLabel
                font.pixelSize: Theme.fontSm
                font.family: Theme.fontFamily
                Layout.fillWidth: true
            }

            ToggleSwitch {
                checked: root.connected || root.connState === ConnectionState.Connecting
                onToggled: {
                    if (root.connected || root.stateChanging)
                        root.wiredDevice.disconnect();
                    else
                        root.network?.connect();
                }
            }
        }

        Header {
            icon: root.connected ? Icons.settingsEthernet : Icons.cable
            iconColor: root.connected ? Theme.textPrimary : Theme.textInactive
            title: {
                if (root.connected && root.network)
                    return root.network.name || root.ifname;
                return root.ifname || "Ethernet";
            }
            subtitle: (root.connected && root.network && root.network.name !== root.ifname) ? root.ifname : ""
            badgeVisible: true
            badgeActive: root.connected
            badgePulsing: root.stateChanging
            badgeColor: {
                if (root.connected)
                    return Theme.colorGreen;
                if (root.connState === ConnectionState.Disconnecting)
                    return Theme.colorRed;
                if (root.connState === ConnectionState.Connecting)
                    return Theme.colorYellow;
                if (!root.hasLink)
                    return Theme.textInactive;
                return Theme.colorRed;
            }
            badgeText: {
                if (root.connState === ConnectionState.Connecting)
                    return "Connecting";
                if (root.connState === ConnectionState.Disconnecting)
                    return "Disconnecting";
                if (root.connected) {
                    if (root.linkSpeed <= 0)
                        return "Connected";
                    let dup;
                    if (root.duplex === "full")
                        dup = " FDX";
                    else if (root.duplex === "half")
                        dup = " HDX";
                    else
                        dup = "";
                    return root.linkSpeed + " Mbps" + dup;
                }
                if (!root.hasLink)
                    return "No cable";
                return "Disconnected";
            }
        }

        ColumnLayout {
            Layout.fillWidth: true
            spacing: 5
            visible: root.hasLink

            InfoRow {
                label: "MAC"
                value: root.mac || "-"
            }
            InfoRow {
                label: "MTU"
                value: root.mtu > 0 ? String(root.mtu) : "-"
                visible: root.connected
            }
        }
    }
}
