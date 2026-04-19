import qs.components
import Quickshell
import Quickshell.Io
import QtQuick

// Data layer for the system menu — fetches static info once and polls dynamic
// metrics while active.
Item {
    id: root
    visible: false

    required property bool active

    // ── static (fetched once per activation) ─────────────────────────────────
    property string hostname: ""
    property string kernel: ""
    property string os: ""
    property string cpuModel: ""
    property int cpuCores: 0
    property string gpuModel: ""
    property int uid: 0

    // ── dynamic (polled every 3 s while active) ──────────────────────────────
    property real uptime: 0
    property real load1: 0
    property real load5: 0
    property real load15: 0
    property string procs: ""
    property real memUsed: 0
    property real memTotal: 0
    property real swapUsed: 0
    property real swapTotal: 0
    property real cpuPercent: 0
    property int gpuPercent: -1
    property real vramUsed: 0
    property real vramTotal: 0
    property real diskUsed: 0
    property real diskTotal: 0
    property var extraDisks: []
    property int cpuTemp: -1
    property int cpuFreq: -1
    property int gpuTemp: -1

    // ── derived ──────────────────────────────────────────────────────────────
    readonly property string user: Quickshell.env("USER") ?? ""
    readonly property string shell: {
        const s = Quickshell.env("SHELL") ?? "";
        return s.substring(s.lastIndexOf("/") + 1);
    }

    // ── formatting helpers ───────────────────────────────────────────────────

    function formatUptime(seconds) {
        const d = Math.floor(seconds / 86400);
        const h = Math.floor((seconds % 86400) / 3600);
        const m = Math.floor((seconds % 3600) / 60);
        let parts = [];
        if (d > 0)
            parts.push(d + "d");
        if (h > 0)
            parts.push(h + "h");
        parts.push(m + "m");
        const s = Math.floor(seconds % 60);
        parts.push(s + "s");
        return parts.join(" ");
    }

    function formatBytesCompact(used, total) {
        if (total >= 1073741824)
            return (used / 1073741824).toFixed(1) + " / " + (total / 1073741824).toFixed(1) + " GiB";
        if (total >= 1048576)
            return (used / 1048576).toFixed(0) + " / " + (total / 1048576).toFixed(0) + " MiB";
        return (used / 1024).toFixed(0) + " / " + (total / 1024).toFixed(0) + " KiB";
    }

    // ── data fetching ────────────────────────────────────────────────────────

    readonly property string _scriptsDir: Qt.resolvedUrl("../../scripts").toString().replace("file://", "")

    BufferedProcess {
        id: staticProc
        command: ["sh", root._scriptsDir + "/static-info.sh"]
        onFinished: output => {
            for (const line of output.trim().split("\n")) {
                const eq = line.indexOf("=");
                if (eq < 0)
                    continue;
                const key = line.substring(0, eq);
                const val = line.substring(eq + 1);
                switch (key) {
                case "hostname":
                    root.hostname = val;
                    break;
                case "kernel":
                    root.kernel = val;
                    break;
                case "uid":
                    root.uid = parseInt(val) || 0;
                    break;
                case "cpu_model":
                    root.cpuModel = val;
                    break;
                case "cpu_cores":
                    root.cpuCores = parseInt(val) || 0;
                    break;
                case "gpu_model":
                    root.gpuModel = val;
                    break;
                case "os":
                    root.os = val;
                    break;
                }
            }
        }
    }

    FileView {
        id: uptimeFile
        path: "/proc/uptime"
        onLoaded: root.uptime = parseInt(text().trim().split(" ")[0]) || 0
    }

    Timer {
        interval: 1000
        repeat: true
        running: root.active
        onTriggered: root.uptime += 1
    }

    FileView {
        id: loadavgFile
        path: "/proc/loadavg"
        onLoaded: {
            const s = text().trim().split(" ");
            root.load1 = parseFloat(s[0]) || 0;
            root.load5 = parseFloat(s[1]) || 0;
            root.load15 = parseFloat(s[2]) || 0;
            root.procs = s[3] ?? "";
        }
    }

    // ── CPU usage from /proc/stat delta ────────────────────────────────────
    property var _prevCpu: null

    FileView {
        id: cpuStatFile
        path: "/proc/stat"
        onLoaded: {
            const line = text().substring(0, text().indexOf("\n"));
            const f = line.split(/\s+/);
            // f[0]="cpu", f[1..]=user nice system idle iowait irq softirq steal
            const idle = (parseInt(f[4]) || 0) + (parseInt(f[5]) || 0);
            const total = f.slice(1, 9).reduce((s, v) => s + (parseInt(v) || 0), 0);
            if (root._prevCpu) {
                const dt = total - root._prevCpu.total;
                const di = idle - root._prevCpu.idle;
                root.cpuPercent = dt > 0 ? (dt - di) / dt : 0;
            }
            root._prevCpu = {
                idle,
                total
            };
        }
    }

    FileView {
        id: meminfoFile
        path: "/proc/meminfo"
        onLoaded: {
            let mt = 0, ma = 0, st = 0, sf = 0;
            for (const line of text().split("\n")) {
                const p = line.split(/\s+/);
                switch (p[0]) {
                case "MemTotal:":
                    mt = parseInt(p[1]) || 0;
                    break;
                case "MemAvailable:":
                    ma = parseInt(p[1]) || 0;
                    break;
                case "SwapTotal:":
                    st = parseInt(p[1]) || 0;
                    break;
                case "SwapFree:":
                    sf = parseInt(p[1]) || 0;
                    break;
                }
            }
            root.memTotal = mt * 1024;
            root.memUsed = (mt - ma) * 1024;
            root.swapTotal = st * 1024;
            root.swapUsed = (st - sf) * 1024;
        }
    }

    BufferedProcess {
        id: hwProc
        command: ["sh", root._scriptsDir + "/poll-hw.sh"]
        onFinished: output => {
            let _extraDisks = [];
            for (const line of output.trim().split("\n")) {
                const eq = line.indexOf("=");
                if (eq < 0)
                    continue;
                const key = line.substring(0, eq);
                const val = line.substring(eq + 1);
                switch (key) {
                case "cputemp":
                    root.cpuTemp = parseInt(val);
                    break;
                case "cpufreq":
                    root.cpuFreq = parseInt(val);
                    break;
                case "gpu":
                    root.gpuPercent = parseInt(val);
                    break;
                case "vram":
                    {
                        const p = val.split(" ");
                        root.vramUsed = parseFloat(p[0]) || 0;
                        root.vramTotal = parseFloat(p[1]) || 0;
                        break;
                    }
                case "gputemp":
                    root.gpuTemp = parseInt(val);
                    break;
                case "disk":
                    {
                        const p = val.split(" ");
                        root.diskUsed = parseFloat(p[0]) || 0;
                        root.diskTotal = parseFloat(p[1]) || 0;
                        break;
                    }
                case "extdisk":
                    {
                        const firstSpace = val.indexOf(" ");
                        const mount = val.substring(0, firstSpace);
                        const rest = val.substring(firstSpace + 1).split(" ");
                        _extraDisks.push({
                            mount: mount,
                            used: parseFloat(rest[0]) || 0,
                            total: parseFloat(rest[1]) || 0
                        });
                        break;
                    }
                }
            }
            root.extraDisks = _extraDisks;
        }
    }

    // ── polling control ──────────────────────────────────────────────────────

    function pollAll() {
        cpuStatFile.reload();
        loadavgFile.reload();
        meminfoFile.reload();
        if (!hwProc.running)
            hwProc.running = true;
    }

    onActiveChanged: {
        if (active) {
            staticProc.running = true;
            uptimeFile.reload();
            pollAll();
        }
    }

    Timer {
        id: pollTimer
        interval: 3000
        repeat: true
        running: root.active
        onTriggered: root.pollAll()
    }
}
