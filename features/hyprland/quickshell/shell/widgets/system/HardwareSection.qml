pragma ComponentBehavior: Bound

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

    required property var sysData

    Layout.fillWidth: true
    spacing: 8

    // CPU
    ColumnLayout {
        Layout.fillWidth: true
        spacing: 4

        UsageBar {
            icon: icons.developerBoard
            label: "CPU" + (root.sysData.cpuCores > 0 ? " • " + root.sysData.cpuCores + " cores" : "")
            value: root.sysData.cpuPercent
            detail: Math.round(root.sysData.cpuPercent * 100) + "%"
        }

        Text {
            visible: root.sysData.cpuModel !== ""
            text: root.sysData.cpuModel + (root.sysData.cpuFreq > 0 ? " • " + (root.sysData.cpuFreq / 1000000).toFixed(1) + " GHz" : "") + (root.sysData.cpuTemp > 0 ? " • " + Math.round(root.sysData.cpuTemp / 1000) + "°C" : "")
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
        value: root.sysData.memTotal > 0 ? root.sysData.memUsed / root.sysData.memTotal : 0
        detail: root.sysData.memTotal > 0 ? root.sysData.formatBytesCompact(root.sysData.memUsed, root.sysData.memTotal) : "..."
    }

    // Swap
    UsageBar {
        visible: root.sysData.swapTotal > 0
        icon: icons.swapHoriz
        label: "Swap"
        value: root.sysData.swapTotal > 0 ? root.sysData.swapUsed / root.sysData.swapTotal : 0
        detail: root.sysData.formatBytesCompact(root.sysData.swapUsed, root.sysData.swapTotal)
    }

    // GPU
    ColumnLayout {
        visible: root.sysData.gpuPercent >= 0
        Layout.fillWidth: true
        spacing: 4

        UsageBar {
            icon: icons.desktopWindows
            label: "GPU"
            value: root.sysData.gpuPercent / 100
            detail: root.sysData.gpuPercent + "%"
        }

        Text {
            visible: root.sysData.gpuModel !== "" || root.sysData.gpuTemp > 0
            text: (root.sysData.gpuModel || "") + (root.sysData.gpuTemp > 0 ? (root.sysData.gpuModel !== "" ? " • " : "") + root.sysData.gpuTemp + "°C" : "")
            color: theme.textInactive
            font.pixelSize: theme.fontXs
            font.family: theme.fontFamily
            elide: Text.ElideRight
            Layout.fillWidth: true
        }
    }

    // VRAM
    UsageBar {
        visible: root.sysData.vramTotal > 0
        icon: icons.memory
        label: "VRAM"
        value: root.sysData.vramTotal > 0 ? root.sysData.vramUsed / root.sysData.vramTotal : 0
        detail: root.sysData.formatBytesCompact(root.sysData.vramUsed, root.sysData.vramTotal)
    }

    // Disk
    UsageBar {
        icon: icons.hardDrive
        label: "Disk /"
        value: root.sysData.diskTotal > 0 ? root.sysData.diskUsed / root.sysData.diskTotal : 0
        detail: root.sysData.diskTotal > 0 ? root.sysData.formatBytesCompact(root.sysData.diskUsed, root.sysData.diskTotal) : "..."
    }

    Accordion {
        visible: root.sysData.extraDisks.length > 0
        label: "Other disks"

        ScrollableList {
            width: parent.width
            maxItems: 4

            Repeater {
                model: root.sysData.extraDisks

                UsageBar {
                    required property var modelData
                    width: parent.width
                    icon: icons.hardDrive
                    label: "Disk " + modelData.mount
                    value: modelData.total > 0 ? modelData.used / modelData.total : 0
                    detail: modelData.total > 0 ? root.sysData.formatBytesCompact(modelData.used, modelData.total) : "..."
                }
            }
        }
    }
}
