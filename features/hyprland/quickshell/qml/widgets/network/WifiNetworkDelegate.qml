pragma ComponentBehavior: Bound

import qs.components
import Quickshell.Networking
import QtQuick
import QtQuick.Layouts

// Single row in the wifi network list — signal icon, name, action buttons, password field.
Rectangle {
    id: root

    Theme {
        id: theme
    }
    Icons {
        id: icons
    }

    required property WifiNetwork network
    property bool expanded: false
    property bool showSeparator: false
    property string psk: ""

    signal clicked
    signal forgotNetwork
    signal connectWithPsk(string psk)
    signal expandToggled

    implicitHeight: (root.showSeparator ? sep.height : 0) + rowContent.height + (root.expanded ? pskField.implicitHeight + 12 : 0)
    radius: theme.radiusMd
    color: rowArea.pressed ? theme.pressedBg : rowArea.containsMouse ? theme.hoverBg : "transparent"

    Rectangle {
        id: sep
        anchors {
            top: parent.top
            left: parent.left
            right: parent.right
            leftMargin: 8
            rightMargin: 8
        }
        height: 1
        color: theme.separatorBg
        visible: root.showSeparator
    }
    Behavior on color {
        ColorAnimation {
            duration: theme.animFast
        }
    }
    clip: true

    Connections {
        target: root.network
        function onConnectionFailed(reason) {
            root.psk = "";
            root.expandToggled();
        }
    }

    RowLayout {
        id: rowContent
        anchors {
            left: parent.left
            right: parent.right
            top: root.showSeparator ? sep.bottom : parent.top
            leftMargin: 6
            rightMargin: 6
        }
        height: theme.popupItemHeight
        spacing: 8

        Text {
            readonly property bool secured: root.network.security !== WifiSecurityType.Open && root.network.security !== WifiSecurityType.Unknown
            readonly property real sig: root.network.signalStrength
            text: {
                if (secured)
                    return sig >= 0.75 ? icons.wifiLocked : sig >= 0.5 ? icons.wifiSignal3Locked : sig >= 0.3 ? icons.wifiSignal2Locked : sig >= 0.1 ? icons.wifiSignal1Locked : icons.wifiSignal0Locked;
                return sig >= 0.75 ? icons.wifi : sig >= 0.5 ? icons.wifiSignal3 : sig >= 0.3 ? icons.wifiSignal2 : sig >= 0.1 ? icons.wifiSignal1 : icons.wifiSignal0;
            }
            color: root.network.connected ? theme.colorGreen : theme.textPrimary
            font.pixelSize: theme.fontIconLg
            font.family: theme.fontIconFamily
            font.variableAxes: theme.fontIconAxes
        }

        Text {
            text: root.network.name
            color: root.network.connected ? theme.colorGreen : theme.textPrimary
            font.pixelSize: theme.fontMd
            font.family: theme.fontFamily
            Layout.fillWidth: true
            elide: Text.ElideRight
        }

        // forget saved credentials
        Text {
            text: icons.delete_
            color: forgetArea.pressed ? theme.colorRed : theme.textInactive
            font.pixelSize: theme.fontMd
            font.family: theme.fontIconFamily
            font.variableAxes: theme.fontIconAxes
            visible: rowArea.containsMouse && root.network.known && !root.network.connected

            MouseArea {
                id: forgetArea
                anchors.fill: parent
                cursorShape: Qt.PointingHandCursor
                onClicked: root.forgotNetwork()
            }
        }

        // disconnect icon — only for connected network
        Text {
            text: icons.close
            color: theme.colorRed
            font.pixelSize: theme.fontMd
            font.family: theme.fontIconFamily
            font.variableAxes: theme.fontIconAxes
            visible: root.network.connected && rowArea.containsMouse
        }
    }

    Rectangle {
        id: pskField
        anchors {
            left: parent.left
            right: parent.right
            top: rowContent.bottom
            topMargin: 6
            leftMargin: 6
            rightMargin: 6
        }
        implicitHeight: 24
        visible: root.expanded
        radius: theme.radiusSm
        color: theme.withAlpha(theme.black, 0.3)
        border.width: 1
        border.color: passInput.activeFocus ? theme.accent : theme.panelBorder

        Text {
            anchors {
                fill: parent
                leftMargin: 8
                rightMargin: 8
                topMargin: 4
                bottomMargin: 4
            }
            text: "Password"
            color: theme.textInactive
            font.pixelSize: theme.fontMd
            font.family: theme.fontFamily
            visible: passInput.text.length === 0 && !passInput.activeFocus
        }

        TextInput {
            id: passInput
            onVisibleChanged: if (visible)
                forceActiveFocus()
            anchors {
                fill: parent
                leftMargin: 8
                rightMargin: 8
                topMargin: 4
                bottomMargin: 4
            }
            text: root.psk
            onTextChanged: root.psk = text
            echoMode: TextInput.Password
            color: theme.textPrimary
            font.pixelSize: theme.fontMd
            font.family: theme.fontFamily
            Keys.onReturnPressed: root.connectWithPsk(root.psk)
            Keys.onEscapePressed: root.expandToggled()
        }
    }

    MouseArea {
        id: rowArea
        anchors {
            left: parent.left
            right: parent.right
            top: parent.top
        }
        height: rowContent.height
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: root.clicked()
    }
}
