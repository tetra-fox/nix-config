import qs.components
import QtQuick
import QtQuick.Layouts

// Shared connection details — IPv4/IPv6 address, subnet, gateway, DNS.
// Polls the active interface for details while visible.
Item {
    id: root

    Theme {
        id: theme
    }

    property string ifname: ""
    property bool polling: false

    // ── state ─────────────────────────────────────────────────────────────────
    property string ip: ""
    property int prefix: 0
    property string gateway: ""
    property string dns: ""
    property string ip6: ""

    readonly property bool hasIpv4: ip !== ""
    readonly property bool hasIpv6: ip6 !== ""
    readonly property bool hasAny: hasIpv4 || hasIpv6

    implicitHeight: col.implicitHeight
    visible: root.hasAny

    function fetch() {
        if (root.ifname === "")
            return;
        if (!routeProc.running)
            routeProc.running = true;
        if (!addrProc.running)
            addrProc.running = true;
        if (!addr6Proc.running)
            addr6Proc.running = true;
        if (!dnsProc.running)
            dnsProc.running = true;
    }

    function clear() {
        root.ip = root.gateway = root.dns = root.ip6 = "";
        root.prefix = 0;
    }

    onIfnameChanged: {
        if (ifname === "")
            clear();
        else
            fetch();
    }

    function prefixToMask(p) {
        if (p <= 0 || p > 32)
            return "-";
        const m = (-1 << (32 - p)) >>> 0;
        return `${(m >>> 24) & 0xFF}.${(m >>> 16) & 0xFF}.${(m >>> 8) & 0xFF}.${m & 0xFF}`;
    }

    // ── processes ─────────────────────────────────────────────────────────────
    BufferedProcess {
        id: routeProc
        command: ["ip", "-j", "-4", "route", "show", "default", "dev", root.ifname]
        onFinished: output => {
            try {
                root.gateway = JSON.parse(output)?.[0]?.gateway ?? "";
            } catch (_) {
                root.gateway = "";
            }
        }
    }

    BufferedProcess {
        id: addrProc
        command: ["ip", "-j", "-4", "addr", "show", root.ifname]
        onFinished: output => {
            try {
                const r = JSON.parse(output)?.[0];
                root.ip = r?.addr_info?.[0]?.local ?? "";
                root.prefix = r?.addr_info?.[0]?.prefixlen ?? 0;
            } catch (_) {
                root.ip = "";
                root.prefix = 0;
            }
        }
    }

    BufferedProcess {
        id: addr6Proc
        command: ["ip", "-j", "-6", "addr", "show", root.ifname]
        onFinished: output => {
            try {
                const addrs = JSON.parse(output)?.[0]?.addr_info ?? [];
                const global = addrs.find(a => a.scope === "global");
                root.ip6 = global ? `${global.local}/${global.prefixlen}` : "";
            } catch (_) {
                root.ip6 = "";
            }
        }
    }

    BufferedProcess {
        id: dnsProc
        command: ["resolvectl", "dns", root.ifname]
        onFinished: output => {
            const match = output.match(/:\s*(.+)/);
            root.dns = match ? match[1].trim() : "";
        }
    }

    Timer {
        interval: 2000
        running: root.polling && root.ifname !== ""
        repeat: true
        onTriggered: root.fetch()
    }

    // ── UI ────────────────────────────────────────────────────────────────────
    ColumnLayout {
        id: col
        anchors {
            top: parent.top
            left: parent.left
            right: parent.right
        }
        spacing: 10

        ColumnLayout {
            Layout.fillWidth: true
            spacing: 5
            visible: root.hasIpv4

            Text {
                text: "IPv4"
                color: theme.textLabel
                font.pixelSize: theme.fontSm
                font.family: theme.fontFamily
            }
            InfoRow {
                label: "Address"
                value: root.ip + "/" + root.prefix
                elide: Text.ElideRight
            }
            InfoRow {
                label: "Subnet"
                value: root.prefix > 0 ? root.prefixToMask(root.prefix) : "-"
            }
            InfoRow {
                label: "Gateway"
                value: root.gateway || "-"
            }
            InfoRow {
                label: "DNS"
                value: root.dns
                elide: Text.ElideRight
                visible: root.dns !== ""
            }
        }

        Separator {
            visible: root.hasIpv4 && root.hasIpv6
        }

        ColumnLayout {
            Layout.fillWidth: true
            spacing: 5
            visible: root.hasIpv6

            Text {
                text: "IPv6"
                color: theme.textLabel
                font.pixelSize: theme.fontSm
                font.family: theme.fontFamily
            }
            InfoRow {
                label: "Address"
                value: root.ip6
                elide: Text.ElideRight
            }
        }
    }
}
