import qs.components
import QtQuick
import QtQuick.Layouts

// Wired network state + UI section for the network popup.
// Exposes connected/ifname for the parent bar button.
// IP/gateway/DNS details are shown in the shared connection details section.
Item {
    id: root

    Theme {
        id: theme
    }
    Icons {
        id: icons
    }

    // ── public (read by parent) ──────────────────────────────────────────────
    readonly property bool connected: ifname !== "" && operstate === "UP" && ip !== ""
    readonly property string ifname: _ifname
    property bool polling: false

    // ── internal state (set by processes, do not write externally) ─────────
    property string _ifname: ""
    property string operstate: ""
    property string ip: ""
    property string mac: ""
    property int mtu: 0
    property int speed: -1
    property string duplex: ""

    // ── processes ─────────────────────────────────────────────────────────────

    // Discover the wired interface: physical devices (have /sys/.../device)
    // that aren't wireless (no /sys/.../wireless). Runs once + on slow poll.
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
        addrProc.running = true;
        linkProc.running = true;
        speedProc.running = true;
        duplexProc.running = true;
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
                    root._fetchDetails();
                }
            } catch (_) {}
        }
    }

    BufferedProcess {
        id: speedProc
        command: ["cat", "/sys/class/net/" + root.ifname + "/speed"]
        onFinished: output => {
            const n = parseInt(output.trim());
            root.speed = isNaN(n) ? -1 : n;
        }
    }

    BufferedProcess {
        id: duplexProc
        command: ["cat", "/sys/class/net/" + root.ifname + "/duplex"]
        onFinished: output => root.duplex = output.trim()
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

    // Re-discover wired interface periodically (handles hotplug, etc.)
    Timer {
        interval: 5000
        running: root.polling
        repeat: true
        onTriggered: if (!ifaceProc.running)
            ifaceProc.running = true
    }

    // Poll for state changes (catches cable unplug, external nmcli, etc.)
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

    // ── UI ────────────────────────────────────────────────────────────────────
    implicitHeight: col.implicitHeight

    ColumnLayout {
        id: col
        anchors {
            top: parent.top
            left: parent.left
            right: parent.right
        }
        spacing: 5

        // toggle row
        RowLayout {
            Layout.fillWidth: true
            visible: root.ifname !== ""

            Text {
                text: "Ethernet"
                color: theme.textLabel
                font.pixelSize: theme.fontSm
                font.family: theme.fontFamily
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
            icon: root.connected ? icons.settingsEthernet : icons.cable
            iconColor: root.connected ? theme.textPrimary : theme.textInactive
            title: root.ifname || "No connection"
            badgeVisible: root.ifname !== ""
            badgeActive: root.connected
            badgeText: {
                if (!root.connected)
                    return "Disconnected";
                if (root.speed <= 0)
                    return "Connected";
                const duplex = root.duplex === "full" ? " FDX" : root.duplex === "half" ? " HDX" : "";
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
