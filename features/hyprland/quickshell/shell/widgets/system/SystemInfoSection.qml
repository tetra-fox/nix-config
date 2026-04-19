import qs.components
import QtQuick
import QtQuick.Layouts

// Identity header + system info rows (OS, kernel, shell, processes).
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
    spacing: 10

    // inline — distinct from components/InfoRow (this one has an icon)
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
            color: theme.textLabel
            font.pixelSize: theme.fontIcon
            font.family: theme.fontIconFamily
            font.variableAxes: theme.fontIconAxes
        }

        Text {
            text: _ir.label
            color: theme.textLabel
            font.pixelSize: theme.fontSm
            font.family: theme.fontFamily
        }

        Item {
            Layout.fillWidth: true
        }

        Text {
            text: _ir.value
            color: theme.textPrimary
            font.pixelSize: theme.fontMd
            font.family: theme.fontFamily
        }
    }

    Header {
        icon: icons.dns
        title: root.data.hostname || "..."
        subtitle: root.data.user + " • uid " + root.data.uid
        badgeVisible: true
        badgeActive: true
        badgeColor: theme.colorGreen
        badgeText: root.data.formatUptime(root.data.uptime)
    }

    Separator {}

    ColumnLayout {
        Layout.fillWidth: true
        spacing: 4

        SysInfoRow {
            icon: icons.deployedCode
            label: "OS"
            value: root.data.os || "..."
        }

        SysInfoRow {
            icon: icons.code
            label: "Kernel"
            value: root.data.kernel || "..."
        }

        SysInfoRow {
            icon: icons.terminal
            label: "Shell"
            value: root.data.shell
        }

        SysInfoRow {
            icon: icons.monitoring
            label: "Processes"
            value: root.data.procs
        }
    }
}
