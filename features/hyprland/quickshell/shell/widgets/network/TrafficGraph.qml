import qs.theme
import Quickshell.Io
import QtQuick
import QtQuick.Layouts

Item {
    id: root

    property string ifname: ""
    property bool polling: false

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

    // disabled until first sample so the scale doesn't animate up from zero
    Behavior on displayMax {
        enabled: root._scaleInited
        NumberAnimation {
            duration: 800
            easing.type: Easing.OutQuint
        }
    }

    onScrollPhaseChanged: root.graphRepaintNeeded()

    // animates graph sliding left by one sample width between polls,
    // so new data points appear to scroll in smoothly
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

    // waits for both rx and tx file reads to finish before computing rates
    function _onStatsLoaded() {
        if (--_pendingReloads > 0)
            return;
        _pendingReloads = 0; // clamp

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
            // 21 = maxSamples(20) + 1 extra for scroll interpolation
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
            color: Theme.textLabel
            font.pixelSize: Theme.fontSm
            font.family: Theme.fontFamily
        }

        Rectangle {
            Layout.fillWidth: true
            height: 52
            radius: Theme.radiusSm
            color: Theme.withAlpha(Theme.black, 0.25)
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
                        ctx.strokeStyle = Theme.withAlpha(Theme.white, 0.10);
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

                    fill("ty", Theme.withAlpha(Theme.colorBlue, 0.12));
                    line("ty", Theme.colorBlue);
                    fill("ry", Theme.withAlpha(Theme.colorPink, 0.15));
                    line("ry", Theme.colorPink);
                }
            }
        }

        RowLayout {
            Layout.fillWidth: true

            RowLayout {
                spacing: 6
                Text {
                    text: "↓"
                    color: Theme.colorPink
                    font.pixelSize: Theme.fontSm
                    font.family: Theme.fontFamily
                }
                ColumnLayout {
                    spacing: 1
                    Text {
                        text: root.formatBytes(root.rxBytes)
                        color: Theme.textPrimary
                        font.pixelSize: Theme.fontSm
                        font.family: Theme.fontFamily
                    }
                    Text {
                        visible: root.rxRate >= 0
                        text: root.formatRate(root.rxRate)
                        color: Theme.textSecondary
                        font.pixelSize: Theme.fontXs
                        font.family: Theme.fontFamily
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
                    color: Theme.colorBlue
                    font.pixelSize: Theme.fontSm
                    font.family: Theme.fontFamily
                }
                ColumnLayout {
                    spacing: 1
                    Text {
                        text: root.formatBytes(root.txBytes)
                        color: Theme.textPrimary
                        font.pixelSize: Theme.fontSm
                        font.family: Theme.fontFamily
                    }
                    Text {
                        visible: root.txRate >= 0
                        text: root.formatRate(root.txRate)
                        color: Theme.textSecondary
                        font.pixelSize: Theme.fontXs
                        font.family: Theme.fontFamily
                    }
                }
            }
        }
    }
}
