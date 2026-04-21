pragma ComponentBehavior: Bound

import qs.components
import qs.theme
import QtQuick
import QtQuick.Layouts

ColumnLayout {
    id: root

    required property var sysData

    Layout.fillWidth: true
    spacing: 8

    ColumnLayout {
        Layout.fillWidth: true
        spacing: 4

        UsageBar {
            icon: Icons.developerBoard
            label: "CPU" + (root.sysData.cpuCores > 0 ? " • " + root.sysData.cpuCores + " cores" : "")
            value: root.sysData.cpuPercent
            detail: Math.round(root.sysData.cpuPercent * 100) + "%"
        }

        Text {
            visible: root.sysData.cpuModel !== ""
            text: {
                let t = root.sysData.cpuModel;
                if (root.sysData.cpuFreq > 0)
                    t += " • " + (root.sysData.cpuFreq / 1000000).toFixed(1) + " GHz";
                if (root.sysData.cpuTemp > 0)
                    t += " • " + Math.round(root.sysData.cpuTemp / 1000) + "°C";
                return t;
            }
            color: Theme.textInactive
            font.pixelSize: Theme.fontXs
            font.family: Theme.fontFamily
            elide: Text.ElideRight
            Layout.fillWidth: true
        }
    }

    UsageBar {
        icon: Icons.memory
        label: "Memory"
        value: root.sysData.memTotal > 0 ? root.sysData.memUsed / root.sysData.memTotal : 0
        detail: root.sysData.memTotal > 0 ? root.sysData.formatBytesCompact(root.sysData.memUsed, root.sysData.memTotal) : "..."
    }

    UsageBar {
        visible: root.sysData.swapTotal > 0
        icon: Icons.swapHoriz
        label: "Swap"
        value: root.sysData.swapTotal > 0 ? root.sysData.swapUsed / root.sysData.swapTotal : 0
        detail: root.sysData.formatBytesCompact(root.sysData.swapUsed, root.sysData.swapTotal)
    }

    ColumnLayout {
        visible: root.sysData.gpuPercent >= 0
        Layout.fillWidth: true
        spacing: 4

        UsageBar {
            icon: Icons.desktopWindows
            label: "GPU"
            value: root.sysData.gpuPercent / 100
            detail: root.sysData.gpuPercent + "%"
        }

        Text {
            visible: root.sysData.gpuModel !== "" || root.sysData.gpuTemp > 0
            text: {
                let t = root.sysData.gpuModel || "";
                if (root.sysData.gpuTemp > 0) {
                    if (t !== "") t += " • ";
                    t += root.sysData.gpuTemp + "°C";
                }
                return t;
            }
            color: Theme.textInactive
            font.pixelSize: Theme.fontXs
            font.family: Theme.fontFamily
            elide: Text.ElideRight
            Layout.fillWidth: true
        }
    }

    UsageBar {
        visible: root.sysData.vramTotal > 0
        icon: Icons.memory
        label: "VRAM"
        value: root.sysData.vramTotal > 0 ? root.sysData.vramUsed / root.sysData.vramTotal : 0
        detail: root.sysData.formatBytesCompact(root.sysData.vramUsed, root.sysData.vramTotal)
    }

    UsageBar {
        icon: Icons.hardDrive
        label: "Disk /"
        value: root.sysData.diskTotal > 0 ? root.sysData.diskUsed / root.sysData.diskTotal : 0
        detail: root.sysData.diskTotal > 0 ? root.sysData.formatBytesCompact(root.sysData.diskUsed, root.sysData.diskTotal) : "..."
    }

    Accordion {
        visible: root.sysData.extraDisks.length > 0
        label: "Other filesystems"

        ScrollableList {
            width: parent.width
            maxItems: 4
            spacing: 8

            Repeater {
                model: root.sysData.extraDisks

                UsageBar {
                    required property var modelData
                    width: parent.width
                    icon: Icons.hardDrive
                    label: "Disk " + modelData.mount
                    value: modelData.total > 0 ? modelData.used / modelData.total : 0
                    detail: modelData.total > 0 ? root.sysData.formatBytesCompact(modelData.used, modelData.total) : "..."
                }
            }
        }
    }
}
