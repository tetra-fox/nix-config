import qs.components
import Quickshell.Io
import QtQuick
import QtQuick.Layouts

// Live traffic graph with rx/tx rates for an interface.
// Set ifname and polling to activate.
Item {
    id: root

    Theme {
        id: theme
    }

    property string ifname: ""
    property bool polling: false

    // ── state ─────────────────────────────────────────────────────────────────
    property real rxBytes: 0
    property real txBytes: 0
    property real rxRate: -1
    property real txRate: -1
    property var samples: []
    property real displayMax: 1
    property real scrollPhase: 0
    property bool _scaleInited: false
    property real _prevRx: 0
    property real _prevTx: 0
    property real _prevTs: 0

    signal graphRepaintNeeded

    readonly property bool hasData: ifname !== ""

    implicitHeight: col.implicitHeight
    visible: root.hasData

    Behavior on displayMax {
        enabled: root._scaleInited
        NumberAnimation {
            duration: 800
            easing.type: Easing.OutQuint
        }
    }

    onScrollPhaseChanged: root.graphRepaintNeeded()

    NumberAnimation {
        id: scrollAnim
        target: root
        property: "scrollPhase"
        from: 0.0
        to: 1.0
        duration: 250
        easing.type: Easing.Linear
    }

    function reset() {
        root._prevTs = 0;
        root.samples = [];
        root.displayMax = 1;
        root._scaleInited = false;
    }

    function formatBytes(b) {
        if (b >= 1073741824)
            return (b / 1073741824).toFixed(2) + " GB";
        if (b >= 1048576)
            return (b / 1048576).toFixed(2) + " MB";
        if (b >= 1024)
            return (b / 1024).toFixed(1) + " KB";
        return Math.round(b) + " B";
    }

    function formatRate(bps) {
        if (bps < 0)
            return "";
        if (bps >= 1048576)
            return (bps / 1048576).toFixed(2) + " MB/s";
        if (bps >= 1024)
            return (bps / 1024).toFixed(1) + " KB/s";
        return Math.round(bps) + " B/s";
    }

    onIfnameChanged: reset()

    // ── sysfs reads ─────────────────────────────────────────────────────────
    property int _pendingReloads: 0

    FileView {
        id: rxFile
        path: root.ifname !== "" ? "/sys/class/net/" + root.ifname + "/statistics/rx_bytes" : ""
        onLoaded: root._onStatsLoaded()
    }

    FileView {
        id: txFile
        path: root.ifname !== "" ? "/sys/class/net/" + root.ifname + "/statistics/tx_bytes" : ""
        onLoaded: root._onStatsLoaded()
    }

    function _onStatsLoaded() {
        if (--_pendingReloads > 0)
            return;
        _pendingReloads = 0; // clamp in case of spurious loads

        const now = Date.now();
        const rx = parseInt(rxFile.text()) || 0;
        const tx = parseInt(txFile.text()) || 0;

        if (root._prevTs > 0) {
            const dt = (now - root._prevTs) / 1000;
            root.rxRate = (rx - root._prevRx) / dt;
            root.txRate = (tx - root._prevTx) / dt;

            const s = root.samples.slice();
            s.push({
                rx: Math.max(0, root.rxRate),
                tx: Math.max(0, root.txRate)
            });
            while (s.length > 21)
                s.shift();
            root.samples = s;

            let mx = 1;
            for (const p of s)
                mx = Math.max(mx, p.rx, p.tx);
            root.displayMax = mx;
            if (!root._scaleInited)
                root._scaleInited = true;
            scrollAnim.restart();
        }

        root._prevTs = now;
        root._prevRx = rx;
        root._prevTx = tx;
        root.rxBytes = rx;
        root.txBytes = tx;
    }

    Timer {
        interval: 250
        running: root.polling && root.ifname !== ""
        repeat: true
        onTriggered: {
            root._pendingReloads = 2;
            rxFile.reload();
            txFile.reload();
        }
    }

    // ── UI ────────────────────────────────────────────────────────────────────
    ColumnLayout {
        id: col
        anchors {
            top: parent.top
            left: parent.left
            right: parent.right
        }
        spacing: 5

        Text {
            text: "Traffic"
            color: theme.textLabel
            font.pixelSize: theme.fontSm
            font.family: theme.fontFamily
        }

        Rectangle {
            Layout.fillWidth: true
            height: 52
            radius: theme.radiusSm
            color: theme.withAlpha(theme.black, 0.25)
            clip: true

            Canvas {
                id: graph
                anchors.fill: parent

                Connections {
                    target: root
                    function onGraphRepaintNeeded() {
                        graph.requestPaint();
                    }
                }

                onPaint: {
                    const ctx = getContext("2d");
                    ctx.clearRect(0, 0, width, height);

                    const samples = root.samples;
                    const n = samples.length;
                    const pad = 4;
                    if (n < 2) {
                        ctx.beginPath();
                        ctx.moveTo(0, height - pad);
                        ctx.lineTo(width, height - pad);
                        ctx.strokeStyle = theme.withAlpha(theme.white, 0.10);
                        ctx.lineWidth = 1;
                        ctx.stroke();
                        return;
                    }

                    const maxSamples = 20;
                    const step = width / (maxSamples - 1);
                    const availH = height - pad * 2;
                    const maxVal = Math.max(1, root.displayMax);

                    const pts = samples.map((s, i) => ({
                                x: (n <= maxSamples) ? (i * step) : (i * step - root.scrollPhase * step),
                                ry: height - pad - (s.rx / maxVal) * availH,
                                ty: height - pad - (s.tx / maxVal) * availH
                            }));

                    function fill(yKey, color) {
                        ctx.beginPath();
                        ctx.moveTo(pts[0].x, height);
                        ctx.lineTo(pts[0].x, pts[0][yKey]);
                        for (let i = 1; i < n; i++) {
                            const cx = (pts[i - 1].x + pts[i].x) / 2;
                            ctx.bezierCurveTo(cx, pts[i - 1][yKey], cx, pts[i][yKey], pts[i].x, pts[i][yKey]);
                        }
                        ctx.lineTo(pts[n - 1].x, height);
                        ctx.closePath();
                        ctx.fillStyle = color;
                        ctx.fill();
                    }

                    function line(yKey, color) {
                        ctx.beginPath();
                        ctx.moveTo(pts[0].x, pts[0][yKey]);
                        for (let i = 1; i < n; i++) {
                            const cx = (pts[i - 1].x + pts[i].x) / 2;
                            ctx.bezierCurveTo(cx, pts[i - 1][yKey], cx, pts[i][yKey], pts[i].x, pts[i][yKey]);
                        }
                        ctx.strokeStyle = color;
                        ctx.lineWidth = 1.5;
                        ctx.stroke();
                    }

                    fill("ty", theme.withAlpha(theme.colorBlue, 0.12));
                    line("ty", theme.colorBlue);
                    fill("ry", theme.withAlpha(theme.colorPink, 0.15));
                    line("ry", theme.colorPink);
                }
            }
        }

        RowLayout {
            Layout.fillWidth: true

            RowLayout {
                spacing: 6
                Text {
                    text: "↓"
                    color: theme.colorPink
                    font.pixelSize: theme.fontSm
                    font.family: theme.fontFamily
                }
                ColumnLayout {
                    spacing: 1
                    Text {
                        text: root.formatBytes(root.rxBytes)
                        color: theme.textPrimary
                        font.pixelSize: theme.fontSm
                        font.family: theme.fontFamily
                    }
                    Text {
                        visible: root.rxRate >= 0
                        text: root.rxRate >= 0 ? root.formatRate(root.rxRate) : ""
                        color: theme.textSecondary
                        font.pixelSize: theme.fontXs
                        font.family: theme.fontFamily
                    }
                }
            }

            Item {
                Layout.fillWidth: true
            }

            RowLayout {
                spacing: 6
                Text {
                    text: "↑"
                    color: theme.colorBlue
                    font.pixelSize: theme.fontSm
                    font.family: theme.fontFamily
                }
                ColumnLayout {
                    spacing: 1
                    Text {
                        text: root.formatBytes(root.txBytes)
                        color: theme.textPrimary
                        font.pixelSize: theme.fontSm
                        font.family: theme.fontFamily
                    }
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
}
