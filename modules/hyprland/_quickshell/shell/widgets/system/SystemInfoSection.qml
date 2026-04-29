pragma ComponentBehavior: Bound

import qs.components
import qs.lib
import QtQuick
import QtQuick.Layouts

ColumnLayout {
    id: root

    required property var sysData

    Layout.fillWidth: true
    spacing: 10

    // not the same as components/InfoRow - this one has an icon
    component SysInfoRow: RowLayout {
        id: _ir

        property string label: ""
        property string icon: ""
        property string value: ""

        Layout.fillWidth: true
        spacing: 8

        Text {
            visible: _ir.icon !== ""
            text: _ir.icon
            color: Theme.textLabel
            font.pixelSize: Theme.fontIcon
            font.family: Theme.fontIconFamily
            font.variableAxes: Theme.fontIconAxes
        }

        Text {
            text: _ir.label
            color: Theme.textLabel
            font.pixelSize: Theme.fontSm
            font.family: Theme.fontFamily
        }

        Item {
            Layout.fillWidth: true
        }

        Text {
            text: _ir.value
            color: Theme.textPrimary
            font.pixelSize: Theme.fontMd
            font.family: Theme.fontFamily
        }
    }

    Header {
        icon: Icons.dns
        title: root.sysData.hostname || "..."
        subtitle: root.sysData.user + " • uid " + root.sysData.uid
        badgeVisible: true
        badgeActive: true
        badgeColor: Theme.colorGreen
        badgeText: root.sysData.formatUptime(root.sysData.uptime)
    }

    Separator {}

    ColumnLayout {
        Layout.fillWidth: true
        spacing: 4

        SysInfoRow {
            icon: Icons.deployedCode
            label: "OS"
            value: root.sysData.os || "..."
        }

        SysInfoRow {
            icon: Icons.code
            label: "Kernel"
            value: root.sysData.kernel || "..."
        }

        SysInfoRow {
            icon: Icons.terminal
            label: "Shell"
            value: root.sysData.shell
        }

        SysInfoRow {
            icon: Icons.monitoring
            label: "Processes"
            value: root.sysData.procs
        }
    }
}
