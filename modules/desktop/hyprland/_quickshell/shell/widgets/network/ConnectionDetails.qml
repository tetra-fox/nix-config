import qs.components
import qs.lib
import QtQuick
import QtQuick.Layouts

Item {
    id: root

    property string ifname: ""
    property bool polling: false

    property string ip: ""
    property int prefix: 0
    property string gateway: ""
    property string dns: ""
    property string ip6: ""

    readonly property bool hasIpv4: ip !== ""
    readonly property bool hasIpv6: ip6 !== ""
    readonly property bool hasAny: hasIpv4 || hasIpv6

    // shared poll gate for all four fetchers
    readonly property bool _live: polling && ifname !== ""

    implicitHeight: col.implicitHeight
    visible: root.hasAny

    // immediate refetch for changes the poll gate can't see (interface switch
    // while the popup stays open)
    function fetch() {
        if (root.ifname === "")
            return;
        routeProc.trigger();
        addrProc.trigger();
        addr6Proc.trigger();
        dnsProc.trigger();
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
        // >>> 0 coerces to unsigned 32-bit so high bits don't produce negative
        const m = (-1 << (32 - p)) >>> 0;
        return `${(m >>> 24) & 0xFF}.${(m >>> 16) & 0xFF}.${(m >>> 8) & 0xFF}.${m & 0xFF}`;
    }

    // handlers drop results that land after the interface cleared: a running
    // process keeps its old argv, so its output would repopulate the fields of
    // a dead interface with no poll left to correct them. results from an
    // interface-to-interface switch self-heal on the next 2s poll
    PolledProcess {
        id: routeProc
        polling: root._live
        command: ["ip", "-j", "-4", "route", "show", "default", "dev", root.ifname]
        onFinished: output => {
            if (root.ifname === "")
                return;
            try {
                root.gateway = JSON.parse(output)?.[0]?.gateway ?? "";
            } catch (_) {
                root.gateway = "";
            }
        }
    }

    PolledProcess {
        id: addrProc
        polling: root._live
        command: ["ip", "-j", "-4", "addr", "show", root.ifname]
        onFinished: output => {
            if (root.ifname === "")
                return;
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

    PolledProcess {
        id: addr6Proc
        polling: root._live
        command: ["ip", "-j", "-6", "addr", "show", root.ifname]
        onFinished: output => {
            if (root.ifname === "")
                return;
            try {
                const addrs = JSON.parse(output)?.[0]?.addr_info ?? [];
                const global = addrs.find(a => a.scope === "global");
                root.ip6 = global ? `${global.local}/${global.prefixlen}` : "";
            } catch (_) {
                root.ip6 = "";
            }
        }
    }

    PolledProcess {
        id: dnsProc
        polling: root._live
        command: ["resolvectl", "dns", root.ifname]
        onFinished: output => {
            if (root.ifname === "")
                return;
            const match = output.match(/:\s*(.+)/);
            root.dns = match ? match[1].trim() : "";
        }
    }

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

            SectionLabel {
                text: "IPv4"
            }
            InfoRow {
                label: "Address"
                value: root.ip + "/" + root.prefix
                elide: Text.ElideRight
            }
            InfoRow {
                label: "Subnet"
                value: root.prefixToMask(root.prefix)
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

            SectionLabel {
                text: "IPv6"
            }
            InfoRow {
                label: "Address"
                value: root.ip6
                elide: Text.ElideRight
            }
        }
    }
}
