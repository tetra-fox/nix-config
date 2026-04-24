pragma ComponentBehavior: Bound

import qs.components
import qs.lib
import Quickshell.Io
import Quickshell.Networking
import QtQuick
import QtQuick.Layouts

Item {
    id: root

    readonly property WiredDevice wiredDevice: Networking.devices.values.find(d => d && d.type === DeviceType.Wired) ?? null
    readonly property bool available: wiredDevice !== null
    readonly property string ifname: wiredDevice?.name ?? ""
    readonly property bool hasLink: wiredDevice?.hasLink ?? false
    readonly property bool connected: wiredDevice?.connected ?? false
    readonly property int state: wiredDevice?.state ?? ConnectionState.Unknown
    readonly property bool stateChanging: state === ConnectionState.Connecting || state === ConnectionState.Disconnecting
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
                checked: root.connected || root.state === ConnectionState.Connecting
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
                if (root.state === ConnectionState.Disconnecting)
                    return Theme.colorRed;
                if (root.state === ConnectionState.Connecting)
                    return Theme.colorYellow;
                if (!root.hasLink)
                    return Theme.textInactive;
                return Theme.colorRed;
            }
            badgeText: {
                if (root.state === ConnectionState.Connecting)
                    return "Connecting";
                if (root.state === ConnectionState.Disconnecting)
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
