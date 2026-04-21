import qs.components
import qs.theme
import Quickshell.Io
import QtQuick
import QtQuick.Layouts

Item {
    id: root

    readonly property bool connected: ifname !== "" && operstate === "UP" && ip !== ""
    readonly property string ifname: _ifname
    property bool polling: false

    property string _ifname: ""
    property string operstate: ""
    property string ip: ""
    property string mac: ""
    property int mtu: 0
    property int speed: -1
    property string duplex: ""

    // find first physical non-wireless interface
    BufferedProcess {
        id: ifaceProc
        command: ["sh", "-c", "for d in /sys/class/net/*/device; do i=$(basename $(dirname $d)); [ ! -d /sys/class/net/$i/wireless ] && echo $i; done"]
        onFinished: output => {
            const name = output.trim().split("\n")[0] ?? "";
            if (name !== "" && name !== root.ifname) {
                root._ifname = name;
                root._fetchDetails();
            } else if (name === "") {
                root._ifname = "";
                root._clearDetails();
            }
        }
    }

    function _clearDetails() {
        root.ip = root.mac = root.duplex = "";
        root.mtu = 0;
        root.speed = -1;
        root.operstate = "";
    }

    function _fetchDetails() {
        if (!addrProc.running)
            addrProc.running = true;
        if (!linkProc.running)
            linkProc.running = true;
        speedFile.reload();
        duplexFile.reload();
    }

    BufferedProcess {
        id: addrProc
        command: ["ip", "-j", "-4", "addr", "show", root.ifname]
        onFinished: output => {
            try {
                root.ip = JSON.parse(output)?.[0]?.addr_info?.[0]?.local ?? "";
            } catch (_) {
                root.ip = "";
            }
        }
    }

    BufferedProcess {
        id: linkProc
        command: ["ip", "-j", "link", "show", root.ifname]
        onFinished: output => {
            try {
                const r = JSON.parse(output)?.[0];
                root.mac = r?.address ?? "";
                root.mtu = r?.mtu ?? 0;
                const newState = r?.operstate ?? "";
                if (newState !== root.operstate) {
                    root.operstate = newState;
                    // re-fetch addr/speed/duplex since they change with link state
                    root._fetchDetails();
                }
            } catch (_) {}
        }
    }

    FileView {
        id: speedFile
        path: root.ifname !== "" ? "/sys/class/net/" + root.ifname + "/speed" : ""
        onLoaded: {
            const n = parseInt(text().trim());
            root.speed = isNaN(n) ? -1 : n;
        }
    }

    FileView {
        id: duplexFile
        path: root.ifname !== "" ? "/sys/class/net/" + root.ifname + "/duplex" : ""
        onLoaded: root.duplex = text().trim()
    }

    BufferedProcess {
        id: toggleUpProc
        command: ["nmcli", "device", "connect", root.ifname]
        onFinished: root._fetchDetails()
    }

    BufferedProcess {
        id: toggleDownProc
        command: ["nmcli", "device", "disconnect", root.ifname]
        onFinished: root._fetchDetails()
    }

    Component.onCompleted: ifaceProc.running = true

    // hotplug re-scan
    Timer {
        interval: 5000
        running: root.polling
        repeat: true
        onTriggered: if (!ifaceProc.running)
            ifaceProc.running = true
    }

    Timer {
        interval: 2000
        running: root.polling && root.ifname !== ""
        repeat: true
        onTriggered: {
            if (!linkProc.running)
                linkProc.running = true;
            if (!addrProc.running)
                addrProc.running = true;
        }
    }

    implicitHeight: col.implicitHeight

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
            visible: root.ifname !== ""

            Text {
                text: "Ethernet"
                color: Theme.textLabel
                font.pixelSize: Theme.fontSm
                font.family: Theme.fontFamily
                Layout.fillWidth: true
            }

            ToggleSwitch {
                checked: root.connected
                onToggled: {
                    if (root.connected)
                        toggleDownProc.running = true;
                    else
                        toggleUpProc.running = true;
                }
            }
        }

        Header {
            icon: root.connected ? Icons.settingsEthernet : Icons.cable
            iconColor: root.connected ? Theme.textPrimary : Theme.textInactive
            title: root.ifname || "No connection"
            badgeVisible: root.ifname !== ""
            badgeActive: root.connected
            badgeText: {
                if (!root.connected)
                    return "Disconnected";
                if (root.speed <= 0)
                    return "Connected";
                let duplex;
                if (root.duplex === "full")
                    duplex = " FDX";
                else if (root.duplex === "half")
                    duplex = " HDX";
                else
                    duplex = "";
                return root.speed + " Mbps" + duplex;
            }
        }

        ColumnLayout {
            Layout.fillWidth: true
            spacing: 5
            visible: root.connected

            InfoRow {
                label: "MAC"
                value: root.mac || "-"
            }
            InfoRow {
                label: "MTU"
                value: root.mtu > 0 ? String(root.mtu) : "-"
            }
        }
    }
}
