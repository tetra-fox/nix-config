import qs.components
import QtQuick
import QtQuick.Layouts

// CPU, Memory, Swap, GPU, VRAM, and Disk usage bars.
ColumnLayout {
    id: root

    Theme {
        id: theme
    }

    Icons {
        id: icons
    }

    required property var data

    Layout.fillWidth: true
    spacing: 8

    // CPU
    ColumnLayout {
        Layout.fillWidth: true
        spacing: 4

        UsageBar {
            icon: icons.developerBoard
            label: "CPU" + (root.data.cpuCores > 0 ? " • " + root.data.cpuCores + " cores" : "")
            value: root.data.cpuCores > 0 ? root.data.load1 / root.data.cpuCores : 0
            detail: root.data.load1.toFixed(2) + "  " + root.data.load5.toFixed(2) + "  " + root.data.load15.toFixed(2)
        }

        Text {
            visible: root.data.cpuModel !== ""
            text: root.data.cpuModel + (root.data.cpuFreq > 0 ? " • " + (root.data.cpuFreq / 1000000).toFixed(1) + " GHz" : "") + (root.data.cpuTemp > 0 ? " • " + Math.round(root.data.cpuTemp / 1000) + "°C" : "")
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
        value: root.data.memTotal > 0 ? root.data.memUsed / root.data.memTotal : 0
        detail: root.data.memTotal > 0 ? root.data.formatBytesCompact(root.data.memUsed, root.data.memTotal) : "..."
    }

    // Swap
    UsageBar {
        visible: root.data.swapTotal > 0
        icon: icons.swapHoriz
        label: "Swap"
        value: root.data.swapTotal > 0 ? root.data.swapUsed / root.data.swapTotal : 0
        detail: root.data.formatBytesCompact(root.data.swapUsed, root.data.swapTotal)
    }

    // GPU
    ColumnLayout {
        visible: root.data.gpuPercent >= 0
        Layout.fillWidth: true
        spacing: 4

        UsageBar {
            icon: icons.desktopWindows
            label: "GPU"
            value: root.data.gpuPercent / 100
            detail: root.data.gpuPercent + "%"
        }

        Text {
            visible: root.data.gpuModel !== "" || root.data.gpuTemp > 0
            text: (root.data.gpuModel || "") + (root.data.gpuTemp > 0 ? (root.data.gpuModel !== "" ? " • " : "") + root.data.gpuTemp + "°C" : "")
            color: theme.textInactive
            font.pixelSize: theme.fontXs
            font.family: theme.fontFamily
            elide: Text.ElideRight
            Layout.fillWidth: true
        }
    }

    // VRAM
    UsageBar {
        visible: root.data.vramTotal > 0
        icon: icons.memory
        label: "VRAM"
        value: root.data.vramTotal > 0 ? root.data.vramUsed / root.data.vramTotal : 0
        detail: root.data.formatBytesCompact(root.data.vramUsed, root.data.vramTotal)
    }

    // Disk
    UsageBar {
        icon: icons.hardDrive
        label: "Disk /"
        value: root.data.diskTotal > 0 ? root.data.diskUsed / root.data.diskTotal : 0
        detail: root.data.diskTotal > 0 ? root.data.formatBytesCompact(root.data.diskUsed, root.data.diskTotal) : "..."
    }
}
