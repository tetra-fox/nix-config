import qs.components
import qs.dialogs
import Quickshell
import Quickshell.Io
import Quickshell.Hyprland
import QtQuick
import QtQuick.Layouts

// system menu — power button with system info dropdown
Item {
    id: root

    Theme {
        id: theme
    }

    Icons {
        id: icons
    }

    property var panelWindow

    implicitWidth: btn.implicitWidth
    implicitHeight: btn.implicitHeight

    // ── inline components ───────────────────────────────────────────────────

    component InfoRow: RowLayout {
        id: _ir

        Theme {
            id: _irTheme
        }

        property string label: ""
        property string icon: ""
        property string value: ""

        Layout.fillWidth: true
        spacing: 8

        Text {
            visible: _ir.icon !== ""
            text: _ir.icon
            color: _irTheme.textLabel
            font.pixelSize: _irTheme.fontIcon
            font.family: _irTheme.fontIconFamily
            font.variableAxes: _irTheme.fontIconAxes
        }

        Text {
            text: _ir.label
            color: _irTheme.textLabel
            font.pixelSize: _irTheme.fontSm
            font.family: _irTheme.fontFamily
        }

        Item {
            Layout.fillWidth: true
        }

        Text {
            text: _ir.value
            color: _irTheme.textPrimary
            font.pixelSize: _irTheme.fontMd
            font.family: _irTheme.fontFamily
        }
    }

    component UsageBar: ColumnLayout {
        id: _ub

        Theme {
            id: _ubTheme
        }

        property string label: ""
        property string icon: ""
        property real value: 0
        property string detail: ""
        property color barColor: _ub.value > 0.9 ? _ubTheme.danger : _ub.value > 0.7 ? _ubTheme.colorYellow : _ubTheme.accent

        spacing: 3
        Layout.fillWidth: true

        RowLayout {
            Layout.fillWidth: true
            spacing: 8

            Text {
                visible: _ub.icon !== ""
                text: _ub.icon
                color: _ubTheme.textLabel
                font.pixelSize: _ubTheme.fontIcon
                font.family: _ubTheme.fontIconFamily
                font.variableAxes: _ubTheme.fontIconAxes
            }

            Text {
                text: _ub.label
                color: _ubTheme.textLabel
                font.pixelSize: _ubTheme.fontSm
                font.family: _ubTheme.fontFamily
            }

            Item {
                Layout.fillWidth: true
            }

            Text {
                text: _ub.detail
                color: _ubTheme.textSecondary
                font.pixelSize: _ubTheme.fontSm
                font.family: _ubTheme.fontFamily
            }
        }

        Rectangle {
            Layout.fillWidth: true
            height: 4
            radius: 2
            color: _ubTheme.inactiveBg

            Rectangle {
                width: parent.width * Math.min(Math.max(_ub.value, 0), 1)
                height: parent.height
                radius: parent.radius
                color: _ub.barColor

                Behavior on width {
                    NumberAnimation {
                        duration: _ubTheme.animSlow
                        easing.type: Easing.OutQuad
                    }
                }
            }
        }
    }

    // ── data properties ─────────────────────────────────────────────────────

    // static (fetched once per popup open)
    property string sHostname: ""
    property string sKernel: ""
    property string sOs: ""
    property string sCpuModel: ""
    property int sCpuCores: 0
    property string sGpuModel: ""
    property int sUid: 0

    // dynamic (polled every 3s while visible)
    property real dUptime: 0
    property real dLoad1: 0
    property real dLoad5: 0
    property real dLoad15: 0
    property string dProcs: ""
    property real dMemUsed: 0
    property real dMemTotal: 0
    property real dSwapUsed: 0
    property real dSwapTotal: 0
    property int dGpuPercent: -1
    property real dVramUsed: 0
    property real dVramTotal: 0
    property real dDiskUsed: 0
    property real dDiskTotal: 0
    property int dCpuTemp: -1
    property int dCpuFreq: -1

    // derived
    readonly property string user: Quickshell.env("USER") ?? ""
    readonly property string shell: {
        const s = Quickshell.env("SHELL") ?? "";
        return s.substring(s.lastIndexOf("/") + 1);
    }

    // ── formatting helpers ──────────────────────────────────────────────────

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
        return parts.join(" ");
    }

    function formatBytesCompact(used, total) {
        if (total >= 1073741824)
            return (used / 1073741824).toFixed(1) + " / " + (total / 1073741824).toFixed(1) + " GiB";
        if (total >= 1048576)
            return (used / 1048576).toFixed(0) + " / " + (total / 1048576).toFixed(0) + " MiB";
        return (used / 1024).toFixed(0) + " / " + (total / 1024).toFixed(0) + " KiB";
    }

    // ── data fetching — FileView for /proc & sysfs, Process only where needed

    // static file reads
    FileView {
        id: hostnameFile
        path: "/etc/hostname"
        preload: true
        onLoaded: root.sHostname = text().trim()
    }

    // static process — only for things that need commands
    BufferedProcess {
        id: staticProc
        command: ["sh", "-c", "echo \"kernel=$(uname -r)\"; echo \"uid=$(id -u)\"; echo \"cpu_model=$(grep -m1 'model name' /proc/cpuinfo | cut -d: -f2 | xargs)\"; echo \"cpu_cores=$(nproc)\"; echo \"gpu_model=$(lspci 2>/dev/null | grep -Ei 'vga|3d' | head -1 | sed 's/.*\\[//;s/\\].*//')\"; . /etc/os-release 2>/dev/null; echo \"os=$PRETTY_NAME\""]
        onFinished: output => {
            for (const line of output.trim().split("\n")) {
                const eq = line.indexOf("=");
                if (eq < 0)
                    continue;
                const key = line.substring(0, eq);
                const val = line.substring(eq + 1);
                switch (key) {
                case "kernel":
                    root.sKernel = val;
                    break;
                case "uid":
                    root.sUid = parseInt(val) || 0;
                    break;
                case "cpu_model":
                    root.sCpuModel = val;
                    break;
                case "cpu_cores":
                    root.sCpuCores = parseInt(val) || 0;
                    break;
                case "gpu_model":
                    root.sGpuModel = val;
                    break;
                case "os":
                    root.sOs = val;
                    break;
                }
            }
        }
    }

    // polled file reads — reloaded by pollTimer
    FileView {
        id: uptimeFile
        path: "/proc/uptime"
        onLoaded: {
            const s = text().trim().split(" ");
            root.dUptime = parseInt(s[0]) || 0;
        }
    }

    FileView {
        id: loadavgFile
        path: "/proc/loadavg"
        onLoaded: {
            const s = text().trim().split(" ");
            root.dLoad1 = parseFloat(s[0]) || 0;
            root.dLoad5 = parseFloat(s[1]) || 0;
            root.dLoad15 = parseFloat(s[2]) || 0;
            root.dProcs = s[3] ?? "";
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
            root.dMemTotal = mt * 1024;
            root.dMemUsed = (mt - ma) * 1024;
            root.dSwapTotal = st * 1024;
            root.dSwapUsed = (st - sf) * 1024;
        }
    }

    FileView {
        id: tempFile
        path: "/sys/class/thermal/thermal_zone0/temp"
        onLoaded: root.dCpuTemp = parseInt(text().trim()) || -1
    }

    FileView {
        id: freqFile
        path: "/sys/devices/system/cpu/cpu0/cpufreq/scaling_cur_freq"
        onLoaded: root.dCpuFreq = parseInt(text().trim()) || -1
    }

    // polled process — only for gpu (glob paths) and disk (needs df)
    BufferedProcess {
        id: gpuDiskProc
        command: ["sh", "-c", "gpu=$(cat /sys/class/drm/card*/device/gpu_busy_percent 2>/dev/null | head -1); echo gpu=${gpu:--1}; vram_u=0; vram_t=0; for f in /sys/class/drm/card*/device/mem_info_vram_used; do [ -f \"$f\" ] && vram_u=$(cat \"$f\") && break; done; for f in /sys/class/drm/card*/device/mem_info_vram_total; do [ -f \"$f\" ] && vram_t=$(cat \"$f\") && break; done; echo \"vram=$vram_u $vram_t\"; df -B1 / | awk 'NR==2{print \"disk=\"$3\" \"$2}'"]
        onFinished: output => {
            for (const line of output.trim().split("\n")) {
                const eq = line.indexOf("=");
                if (eq < 0)
                    continue;
                const key = line.substring(0, eq);
                const val = line.substring(eq + 1);
                switch (key) {
                case "gpu":
                    root.dGpuPercent = parseInt(val);
                    break;
                case "vram":
                    {
                        const p = val.split(" ");
                        root.dVramUsed = parseFloat(p[0]) || 0;
                        root.dVramTotal = parseFloat(p[1]) || 0;
                        break;
                    }
                case "disk":
                    {
                        const p = val.split(" ");
                        root.dDiskUsed = parseFloat(p[0]) || 0;
                        root.dDiskTotal = parseFloat(p[1]) || 0;
                        break;
                    }
                }
            }
        }
    }

    // ── visibility-driven polling ───────────────────────────────────────────

    function pollAll() {
        uptimeFile.reload();
        loadavgFile.reload();
        meminfoFile.reload();
        tempFile.reload();
        freqFile.reload();
        gpuDiskProc.running = true;
    }

    Connections {
        target: popup
        function onVisibleChanged() {
            if (popup.visible) {
                staticProc.running = true;
                root.pollAll();
            }
        }
    }

    Timer {
        id: pollTimer
        interval: 3000
        repeat: true
        running: popup.visible
        onTriggered: root.pollAll()
    }

    // ── bar button ──────────────────────────────────────────────────────────

    IconButton {
        id: btn
        icon: icons.systemMenu
        isOpen: popup.visible
        onClicked: popup.visible = !popup.visible
    }

    // ── confirm dialog ──────────────────────────────────────────────────────

    function run(cmd) {
        Hyprland.dispatch(cmd);
    }

    function confirm(title, body, actionLabel, cmd, icon) {
        popup.visible = false;
        dialog.title = title;
        dialog.body = body;
        dialog.actionLabel = actionLabel;
        dialog.icon = icon;
        dialog.pendingCmd = cmd;
        dialog.open();
    }

    ConfirmDialog {
        id: dialog
        property string pendingCmd: ""
        onConfirmed: root.run(pendingCmd)
    }

    // ── popup ───────────────────────────────────────────────────────────────

    PopupWindow {
        id: popup
        panelWindow: root.panelWindow

        contentWidth: 320
        contentHeight: col.implicitHeight + theme.pillHPad * 2

        ColumnLayout {
            id: col
            anchors {
                top: parent.top
                left: parent.left
                right: parent.right
                margins: theme.pillHPad
            }
            spacing: 10

            // ── identity ────────────────────────────────────────────────

            Header {
                icon: icons.desktopWindows
                title: root.sHostname || "..."
                subtitle: root.user + " • uid " + root.sUid
                badgeVisible: true
                badgeActive: true
                badgeColor: theme.colorGreen
                badgeText: root.formatUptime(root.dUptime)
            }

            Separator {}

            // ── system info ─────────────────────────────────────────────

            ColumnLayout {
                Layout.fillWidth: true
                spacing: 4

                InfoRow {
                    icon: icons.deployedCode
                    label: "OS"
                    value: root.sOs || "..."
                }

                InfoRow {
                    icon: icons.code
                    label: "Kernel"
                    value: root.sKernel || "..."
                }

                InfoRow {
                    icon: icons.terminal
                    label: "Shell"
                    value: root.shell
                }

                InfoRow {
                    icon: icons.monitoring
                    label: "Processes"
                    value: root.dProcs
                }
            }

            Separator {}

            // ── hardware stats ──────────────────────────────────────────

            ColumnLayout {
                Layout.fillWidth: true
                spacing: 8

                // CPU
                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 2

                    UsageBar {
                        icon: icons.speed
                        label: "CPU" + (root.sCpuCores > 0 ? " • " + root.sCpuCores + " cores" : "")
                        value: root.sCpuCores > 0 ? root.dLoad1 / root.sCpuCores : 0
                        detail: root.dLoad1.toFixed(2) + "  " + root.dLoad5.toFixed(2) + "  " + root.dLoad15.toFixed(2)
                    }

                    Text {
                        visible: root.sCpuModel !== ""
                        text: root.sCpuModel + (root.dCpuFreq > 0 ? " • " + (root.dCpuFreq / 1000000).toFixed(1) + " GHz" : "") + (root.dCpuTemp > 0 ? " • " + Math.round(root.dCpuTemp / 1000) + "°C" : "")
                        color: theme.textInactive
                        font.pixelSize: theme.fontXs
                        font.family: theme.fontFamily
                        elide: Text.ElideRight
                        Layout.fillWidth: true
                    }
                }

                // Memory
                UsageBar {
                    icon: icons.memory
                    label: "Memory"
                    value: root.dMemTotal > 0 ? root.dMemUsed / root.dMemTotal : 0
                    detail: root.dMemTotal > 0 ? root.formatBytesCompact(root.dMemUsed, root.dMemTotal) : "..."
                }

                // Swap
                UsageBar {
                    visible: root.dSwapTotal > 0
                    icon: icons.swapHoriz
                    label: "Swap"
                    value: root.dSwapTotal > 0 ? root.dSwapUsed / root.dSwapTotal : 0
                    detail: root.formatBytesCompact(root.dSwapUsed, root.dSwapTotal)
                }

                // GPU
                ColumnLayout {
                    visible: root.dGpuPercent >= 0
                    Layout.fillWidth: true
                    spacing: 2

                    UsageBar {
                        icon: icons.sportsEsports
                        label: "GPU"
                        value: root.dGpuPercent / 100
                        detail: root.dGpuPercent + "%"
                    }

                    Text {
                        visible: root.sGpuModel !== ""
                        text: root.sGpuModel
                        color: theme.textInactive
                        font.pixelSize: theme.fontXs
                        font.family: theme.fontFamily
                        elide: Text.ElideRight
                        Layout.fillWidth: true
                    }
                }

                // VRAM
                UsageBar {
                    visible: root.dVramTotal > 0
                    icon: icons.memory
                    label: "VRAM"
                    value: root.dVramTotal > 0 ? root.dVramUsed / root.dVramTotal : 0
                    detail: root.formatBytesCompact(root.dVramUsed, root.dVramTotal)
                }

                // Disk
                UsageBar {
                    icon: icons.hardDrive
                    label: "Disk /"
                    value: root.dDiskTotal > 0 ? root.dDiskUsed / root.dDiskTotal : 0
                    detail: root.dDiskTotal > 0 ? root.formatBytesCompact(root.dDiskUsed, root.dDiskTotal) : "..."
                }
            }

            Separator {}

            // ── session actions ──────────────────────────────────────────

            ColumnLayout {
                Layout.fillWidth: true
                spacing: 0

                MenuItem {
                    text: "Lock"
                    icon: icons.lock
                    Layout.fillWidth: true
                    onClicked: {
                        popup.visible = false;
                        Hyprland.dispatch("exec hyprlock");
                    }
                }

                MenuItem {
                    text: "Log out"
                    icon: icons.logout
                    Layout.fillWidth: true
                    onClicked: root.confirm("Log out?", "Are you sure you want to log out?", "Log out", "exec hyprshutdown -p 'uwsm stop'", icons.logout)
                }
            }

            Separator {}

            // ── power actions ───────────────────────────────────────────

            ColumnLayout {
                Layout.fillWidth: true
                spacing: 0

                MenuItem {
                    text: "Reboot"
                    icon: icons.restart
                    Layout.fillWidth: true
                    onClicked: root.confirm("Reboot?", "Are you sure you want to reboot?", "Reboot", "exec hyprshutdown -p 'uwsm stop; systemctl reboot'", icons.restart)
                }

                MenuItem {
                    text: "Shut down"
                    icon: icons.power
                    textColor: theme.danger
                    Layout.fillWidth: true
                    onClicked: root.confirm("Shut down?", "Are you sure you want to shut down?", "Shut down", "exec hyprshutdown -p 'uwsm stop; systemctl poweroff'", icons.power)
                }
            }
        }
    }
}
