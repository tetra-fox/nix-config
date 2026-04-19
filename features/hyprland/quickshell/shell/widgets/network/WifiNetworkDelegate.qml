pragma ComponentBehavior: Bound

import qs.components
import Quickshell.Networking
import QtQuick
import QtQuick.Layouts

// Single row in the wifi network list — signal icon, name, action buttons, password field.
Item {
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

    implicitHeight: item.implicitHeight + (root.expanded ? pskField.implicitHeight + pskActions.implicitHeight + 18 : 0)
    clip: true

    Connections {
        target: root.network
        function onConnectionFailed(reason) {
            root.psk = "";
            if (!root.network.known)
                root.expandToggled();
        }
    }

    SelectableItem {
        id: item
        anchors {
            left: parent.left
            right: parent.right
            top: parent.top
        }
        icon: {
            const secured = root.network.security !== WifiSecurityType.Open && root.network.security !== WifiSecurityType.Unknown; // qmllint disable unresolved-type
            const sig = root.network.signalStrength;
            if (secured)
                return sig >= 0.75 ? icons.wifiLocked : sig >= 0.5 ? icons.wifiSignal3Locked : sig >= 0.3 ? icons.wifiSignal2Locked : sig >= 0.1 ? icons.wifiSignal1Locked : icons.wifiSignal0Locked;
            return sig >= 0.75 ? icons.wifi : sig >= 0.5 ? icons.wifiSignal3 : sig >= 0.3 ? icons.wifiSignal2 : sig >= 0.1 ? icons.wifiSignal1 : icons.wifiSignal0;
        }
        iconSize: theme.fontIconLg
        iconColor: root.network.connected ? theme.colorGreen : theme.textPrimary
        text: root.network.name
        textColor: root.network.connected ? theme.colorGreen : theme.textPrimary
        showSeparator: root.showSeparator
        onSelected: root.clicked()

        InlineButton {
            text: "Forget"
            accentColor: theme.colorRed
            visible: root.network.known && !root.network.connected
            onClicked: root.forgotNetwork()
        }
    }

    Rectangle {
        id: pskField
        anchors {
            left: parent.left
            right: parent.right
            top: item.bottom
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

    RowLayout {
        id: pskActions
        anchors {
            right: parent.right
            top: pskField.bottom
            topMargin: 6
            rightMargin: 6
        }
        visible: root.expanded
        spacing: 6

        InlineButton {
            text: "Cancel"
            onClicked: root.expandToggled()
        }

        InlineButton {
            text: "Connect"
            accentColor: theme.colorGreen
            onClicked: root.connectWithPsk(root.psk)
        }
    }
}
