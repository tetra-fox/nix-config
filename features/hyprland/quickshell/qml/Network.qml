import Quickshell
import Quickshell.Io
import QtQuick
import QtQuick.Layouts

Item {
    id: root

    Theme { id: theme }

    property var panelWindow

    // ── state ────────────────────────────────────────────────────────────────
    property string ifname:    ""
    property string gateway:   ""
    property string operstate: ""
    property string ip:        ""
    property int    prefix:    0
    property string mac:       ""
    property string ip6:       ""
    property int    mtu:       0
    property int    speed:     -1
    property string dns:       ""
    property real   rxBytes:   0
    property real   txBytes:   0
    property real   rxRate:    -1
    property real   txRate:    -1
    property var    samples:    []   // [{rx, tx}] rolling 5s window
    property real   displayMax: 1    // animated y-axis ceiling
    property real   scrollPhase: 0   // 0→1 each sample interval, drives 60fps repaint

    Behavior on displayMax {
        NumberAnimation { duration: 800; easing.type: Easing.OutCubic }
    }

    onScrollPhaseChanged: if (popup.visible) graph.requestPaint()

    NumberAnimation {
        id: scrollAnim
        target: root; property: "scrollPhase"
        from: 0.0; to: 1.0
        duration: 250
        easing.type: Easing.Linear
    }

    // private — rate-calc bookkeeping
    property real _prevRx: 0
    property real _prevTx: 0
    property real _prevTs: 0

    readonly property bool connected: ifname !== ""

    // ── helpers ───────────────────────────────────────────────────────────────
    function formatBytes(b) {
        if (b >= 1073741824) return (b / 1073741824).toFixed(2) + " GB"
        if (b >= 1048576)    return (b / 1048576).toFixed(2)    + " MB"
        if (b >= 1024)       return (b / 1024).toFixed(1)       + " KB"
        return Math.round(b) + " B"
    }

    function formatRate(bps) {
        if (bps < 0)         return ""
        if (bps >= 1048576)  return (bps / 1048576).toFixed(2)  + " MB/s"
        if (bps >= 1024)     return (bps / 1024).toFixed(1)     + " KB/s"
        return Math.round(bps) + " B/s"
    }

    function prefixToMask(p) {
        if (p <= 0 || p > 32) return "—"
        const m = (-1 << (32 - p)) >>> 0
        return `${(m>>>24)&0xFF}.${(m>>>16)&0xFF}.${(m>>>8)&0xFF}.${m&0xFF}`
    }

    // ── processes ─────────────────────────────────────────────────────────────

    // ip route → ifname + gateway → kicks off everything else
    Process {
        id: routeProc
        property string _buf: ""
        command: ["ip", "-j", "-4", "route", "show", "default"]
        stdout: SplitParser {
            splitMarker: "\n"
            onRead: data => routeProc._buf += data
        }
        onRunningChanged: {
            if (running) { _buf = ""; return }
            try {
                const r = JSON.parse(_buf)?.[0]
                if (r?.dev) {
                    root.ifname  = r.dev
                    root.gateway = r.gateway ?? ""
                    addrProc.running  = true
                    addr6Proc.running = true
                    linkProc.running  = true
                    speedProc.running = true
                    dnsProc.running   = true
                } else {
                    root.ifname = root.gateway = root.ip = root.ip6 = root.mac = root.dns = ""
                    root.prefix = root.mtu = 0
                    root.rxBytes = root.txBytes = 0
                    root.rxRate = root.txRate = -1
                    root.speed = -1
                    root.operstate = ""
                }
            } catch (_) { root.ifname = "" }
        }
    }

    // ip -j -4 addr → IP + prefix
    Process {
        id: addrProc
        property string _buf: ""
        command: ["ip", "-j", "-4", "addr", "show", root.ifname]
        stdout: SplitParser {
            splitMarker: "\n"
            onRead: data => addrProc._buf += data
        }
        onRunningChanged: {
            if (running) { _buf = ""; return }
            try {
                const r = JSON.parse(_buf)?.[0]
                root.ip     = r?.addr_info?.[0]?.local    ?? ""
                root.prefix = r?.addr_info?.[0]?.prefixlen ?? 0
            } catch (_) {}
        }
    }

    // ip -j -6 addr → global ipv6 address
    Process {
        id: addr6Proc
        property string _buf: ""
        command: ["ip", "-j", "-6", "addr", "show", root.ifname]
        stdout: SplitParser {
            splitMarker: "\n"
            onRead: data => addr6Proc._buf += data
        }
        onRunningChanged: {
            if (running) { _buf = ""; return }
            try {
                const addrs  = JSON.parse(_buf)?.[0]?.addr_info ?? []
                const global = addrs.find(a => a.scope === "global")
                root.ip6 = global ? `${global.local}/${global.prefixlen}` : ""
            } catch (_) { root.ip6 = "" }
        }
    }

    // ip -s link → MTU, operstate, rx/tx bytes + rate calc
    Process {
        id: linkProc
        property string _buf: ""
        command: ["ip", "-s", "-j", "link", "show", root.ifname]
        stdout: SplitParser {
            splitMarker: "\n"
            onRead: data => linkProc._buf += data
        }
        onRunningChanged: {
            if (running) { _buf = ""; return }
            try {
                const r   = JSON.parse(_buf)?.[0]
                const now = Date.now()
                const rx  = r?.stats64?.rx?.bytes ?? 0
                const tx  = r?.stats64?.tx?.bytes ?? 0

                if (root._prevTs > 0) {
                    const dt    = (now - root._prevTs) / 1000
                    root.rxRate = (rx - root._prevRx) / dt
                    root.txRate = (tx - root._prevTx) / dt

                    const s = root.samples.slice()
                    s.push({rx: Math.max(0, root.rxRate), tx: Math.max(0, root.txRate)})
                    while (s.length > 20) s.shift()
                    root.samples = s

                    let mx = 1
                    for (const p of s) mx = Math.max(mx, p.rx, p.tx)
                    root.displayMax = mx

                    scrollAnim.restart()
                }

                root._prevTs   = now
                root._prevRx   = rx
                root._prevTx   = tx
                root.rxBytes   = rx
                root.txBytes   = tx
                root.mac       = r?.address   ?? ""
                root.mtu       = r?.mtu       ?? 0
                root.operstate = r?.operstate ?? ""
            } catch (_) {}
        }
    }

    // /sys/class/net/<dev>/speed → link speed in mbps
    Process {
        id: speedProc
        property string _buf: ""
        command: ["cat", "/sys/class/net/" + root.ifname + "/speed"]
        stdout: SplitParser {
            splitMarker: "\n"
            onRead: data => speedProc._buf += data
        }
        onRunningChanged: {
            if (running) { _buf = ""; return }
            const n = parseInt(_buf.trim())
            root.speed = isNaN(n) ? -1 : n
        }
    }

    // resolvectl dns <dev> → dns servers
    Process {
        id: dnsProc
        property string _buf: ""
        command: ["resolvectl", "dns", root.ifname]
        stdout: SplitParser {
            splitMarker: "\n"
            onRead: data => dnsProc._buf += data
        }
        onRunningChanged: {
            if (running) { _buf = ""; return }
            const match = _buf.match(/:\s*(.+)/)
            root.dns = match ? match[1].trim() : ""
        }
    }

    Process { id: launcher; command: ["nm-connection-editor"] }

    Component.onCompleted: routeProc.running = true

    // 30s background poll
    Timer {
        interval: 30000
        running: true
        repeat: true
        onTriggered: if (!routeProc.running) routeProc.running = true
    }

    // 250ms live rate poll — only runs while the popup is open
    Timer {
        interval: 250
        running: popup.visible
        repeat: true
        onTriggered: if (!linkProc.running) linkProc.running = true
    }

    // ── button ───────────────────────────────────────────────────────────────
    implicitWidth:  btn.implicitWidth
    implicitHeight: btn.implicitHeight

    BarButton {
        id: btn
        icon: root.connected ? "󰈀" : "󰤭"
        iconColor: root.connected ? theme.textPrimary : theme.textInactive
        isOpen: popup.visible
        onClicked: _ => { popup.visible = !popup.visible }
    }

    // ── popup ────────────────────────────────────────────────────────────────
    PopupWindow {
        id: popup

        anchor.window: root.panelWindow
        anchor.rect.x: root.panelWindow ? root.panelWindow.width - implicitWidth - theme.pillMargin : 0
        anchor.rect.y: root.panelWindow ? root.panelWindow.implicitHeight : 0

        implicitWidth:  320
        implicitHeight: col.implicitHeight + theme.pillHPad * 2

        grabFocus: true
        visible: false
        color: "transparent"

        onVisibleChanged: {
            if (visible) {
                root._prevTs = 0
                root.samples = []
                if (!linkProc.running) linkProc.running = true
            }
        }

        Rectangle {
            anchors.fill: parent
            radius: theme.radiusLg
            color: theme.panelBg
            border.width: 1
            border.color: theme.panelBorder
            clip: true

            ColumnLayout {
                id: col
                anchors {
                    top: parent.top
                    left: parent.left
                    right: parent.right
                    margins: theme.pillHPad
                }
                spacing: 10

                // ── header ───────────────────────────────────────────────────
                RowLayout {
                    Layout.fillWidth: true
                    spacing: 10

                    Text {
                        text: root.connected ? "󰈀" : "󰤭"
                        color: root.connected ? theme.textPrimary : theme.textInactive
                        font.pixelSize: theme.fontIconLg
                        font.family: theme.fontFamily
                    }
                    Text {
                        text: root.ifname || "No connection"
                        color: theme.textPrimary
                        font.pixelSize: theme.fontMd
                        font.family: theme.fontFamily
                        Layout.fillWidth: true
                    }
                    Rectangle {
                        visible: root.operstate !== ""
                        radius: theme.radiusSm
                        color: root.operstate === "UP" ? "#1a4d2e" : "#4d1a1a"
                        width: stateLabel.implicitWidth + 8
                        height: stateLabel.implicitHeight + 4
                        Text {
                            id: stateLabel
                            anchors.centerIn: parent
                            text: root.operstate
                            color: root.operstate === "UP" ? "#4dba6b" : theme.danger
                            font.pixelSize: theme.fontXs
                            font.family: theme.fontFamily
                        }
                    }
                }

                Rectangle { Layout.fillWidth: true; height: 1; color: theme.separatorBg }

                // ── interface ─────────────────────────────────────────────────
                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 5
                    visible: root.connected

                    RowLayout {
                        Layout.fillWidth: true
                        Text { text: "MAC"; color: theme.textLabel; font.pixelSize: theme.fontSm; font.family: theme.fontFamily; Layout.minimumWidth: 64 }
                        CopyText { text: root.mac || "—"; Layout.fillWidth: true }
                    }
                    RowLayout {
                        Layout.fillWidth: true
                        Text { text: "MTU"; color: theme.textLabel; font.pixelSize: theme.fontSm; font.family: theme.fontFamily; Layout.minimumWidth: 64 }
                        CopyText { text: root.mtu > 0 ? String(root.mtu) : "—"; Layout.fillWidth: true }
                        Text {
                            visible: root.speed > 0
                            text: root.speed > 0 ? root.speed + " Mbps" : ""
                            color: theme.textSecondary
                            font.pixelSize: theme.fontSm
                            font.family: theme.fontFamily
                        }
                    }
                }

                Rectangle { Layout.fillWidth: true; height: 1; color: theme.separatorBg; visible: root.connected }

                // ── ipv4 ─────────────────────────────────────────────────────
                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 5
                    visible: root.connected

                    Text { text: "IPv4"; color: theme.textLabel; font.pixelSize: theme.fontSm; font.family: theme.fontFamily }

                    RowLayout {
                        Layout.fillWidth: true
                        Text { text: "Address"; color: theme.textLabel; font.pixelSize: theme.fontSm; font.family: theme.fontFamily; Layout.minimumWidth: 64 }
                        CopyText { text: root.ip ? root.ip + "/" + root.prefix : "—"; Layout.fillWidth: true; elide: Text.ElideRight }
                    }
                    RowLayout {
                        Layout.fillWidth: true
                        Text { text: "Subnet"; color: theme.textLabel; font.pixelSize: theme.fontSm; font.family: theme.fontFamily; Layout.minimumWidth: 64 }
                        CopyText { text: root.prefix > 0 ? root.prefixToMask(root.prefix) : "—"; Layout.fillWidth: true }
                    }
                    RowLayout {
                        Layout.fillWidth: true
                        Text { text: "Gateway"; color: theme.textLabel; font.pixelSize: theme.fontSm; font.family: theme.fontFamily; Layout.minimumWidth: 64 }
                        CopyText { text: root.gateway || "—"; Layout.fillWidth: true }
                    }
                    RowLayout {
                        Layout.fillWidth: true
                        visible: root.dns !== ""
                        Text { text: "DNS"; color: theme.textLabel; font.pixelSize: theme.fontSm; font.family: theme.fontFamily; Layout.minimumWidth: 64 }
                        CopyText { text: root.dns; Layout.fillWidth: true; elide: Text.ElideRight }
                    }
                }

                // ── ipv6 ─────────────────────────────────────────────────────
                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 5
                    visible: root.ip6 !== ""

                    Rectangle { Layout.fillWidth: true; height: 1; color: theme.separatorBg }

                    Text { text: "IPv6"; color: theme.textLabel; font.pixelSize: theme.fontSm; font.family: theme.fontFamily }

                    RowLayout {
                        Layout.fillWidth: true
                        Text { text: "Address"; color: theme.textLabel; font.pixelSize: theme.fontSm; font.family: theme.fontFamily; Layout.minimumWidth: 64 }
                        CopyText { text: root.ip6; Layout.fillWidth: true; elide: Text.ElideRight }
                    }
                }

                Rectangle { Layout.fillWidth: true; height: 1; color: theme.separatorBg; visible: root.connected }

                // ── traffic ───────────────────────────────────────────────────
                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 5
                    visible: root.connected

                    Text { text: "Traffic"; color: theme.textLabel; font.pixelSize: theme.fontSm; font.family: theme.fontFamily }

                    // ── graph ────────────────────────────────────────────────
                    Rectangle {
                        Layout.fillWidth: true
                        height: 52
                        radius: theme.radiusSm
                        color: Qt.rgba(0, 0, 0, 0.25)
                        clip: true

                        Canvas {
                            id: graph
                            anchors.fill: parent

                            onPaint: {
                                const ctx = getContext("2d")
                                ctx.clearRect(0, 0, width, height)

                                const samples = root.samples
                                const n = samples.length
                                if (n < 2) return

                                const maxSamples = 20
                                const step   = width / (maxSamples - 1)
                                const xOff   = root.scrollPhase * step
                                const pad    = 4
                                const availH = height - pad * 2
                                const maxVal = Math.max(1, root.displayMax)

                                const pts = samples.map((s, i) => ({
                                    x:  width - (n - 1 - i) * step - xOff,
                                    ry: height - pad - (s.rx / maxVal) * availH,
                                    ty: height - pad - (s.tx / maxVal) * availH,
                                }))

                                function fill(yKey, color) {
                                    ctx.beginPath()
                                    ctx.moveTo(pts[0].x, height)
                                    ctx.lineTo(pts[0].x, pts[0][yKey])
                                    for (let i = 1; i < n; i++) {
                                        const cx = (pts[i-1].x + pts[i].x) / 2
                                        ctx.bezierCurveTo(cx, pts[i-1][yKey], cx, pts[i][yKey], pts[i].x, pts[i][yKey])
                                    }
                                    ctx.lineTo(pts[n-1].x, height)
                                    ctx.closePath()
                                    ctx.fillStyle = color
                                    ctx.fill()
                                }

                                function line(yKey, color) {
                                    ctx.beginPath()
                                    ctx.moveTo(pts[0].x, pts[0][yKey])
                                    for (let i = 1; i < n; i++) {
                                        const cx = (pts[i-1].x + pts[i].x) / 2
                                        ctx.bezierCurveTo(cx, pts[i-1][yKey], cx, pts[i][yKey], pts[i].x, pts[i][yKey])
                                    }
                                    ctx.strokeStyle = color
                                    ctx.lineWidth = 1.5
                                    ctx.stroke()
                                }

                                // tx behind rx
                                fill("ty", "rgba(77, 159, 255, 0.12)")
                                line("ty", "#4d9fff")
                                fill("ry", "rgba(255, 27, 164, 0.15)")
                                line("ry", "#ff1ba4")
                            }
                        }
                    }

                    RowLayout {
                        Layout.fillWidth: true

                        // download
                        RowLayout {
                            spacing: 6
                            Text { text: "↓"; color: "#ff1ba4"; font.pixelSize: theme.fontSm; font.family: theme.fontFamily }
                            ColumnLayout {
                                spacing: 1
                                Text { text: root.formatBytes(root.rxBytes); color: theme.textPrimary; font.pixelSize: theme.fontSm; font.family: theme.fontFamily }
                                Text {
                                    visible: root.rxRate >= 0
                                    text: root.rxRate >= 0 ? root.formatRate(root.rxRate) : ""
                                    color: theme.textSecondary
                                    font.pixelSize: theme.fontXs
                                    font.family: theme.fontFamily
                                }
                            }
                        }

                        Item { Layout.fillWidth: true }

                        // upload
                        RowLayout {
                            spacing: 6
                            Text { text: "↑"; color: "#4d9fff"; font.pixelSize: theme.fontSm; font.family: theme.fontFamily }
                            ColumnLayout {
                                spacing: 1
                                Text { text: root.formatBytes(root.txBytes); color: theme.textPrimary; font.pixelSize: theme.fontSm; font.family: theme.fontFamily }
                                Text {
                                    visible: root.txRate >= 0
                                    text: root.txRate >= 0 ? root.formatRate(root.txRate) : ""

                                    color: theme.textSecondary
                                    font.pixelSize: theme.fontXs
                                    font.family: theme.fontFamily
                                }
                            }
                        }
                    }
                }

                Rectangle { Layout.fillWidth: true; height: 1; color: theme.separatorBg }

                // ── more settings ─────────────────────────────────────────────
                PopupItem {
                    Layout.fillWidth: true
                    text: "More settings..."
                    onClicked: { launcher.running = true; popup.visible = false }
                }
            }
        }
    }
}
