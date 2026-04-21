pragma ComponentBehavior: Bound

import qs.components
import qs.theme
import Quickshell.Networking
import QtQuick
import QtQuick.Layouts

Item {
    id: root

    required property WifiNetwork network
    property bool expanded: false
    property bool showSeparator: false
    property string psk: ""

    signal clicked
    signal forgotNetwork
    signal connectWithPsk(string psk)
    signal expandToggled

    // 18 = topMargin*3 (6px gap above pskField + 6px gap above pskActions + 6px bottom pad)
    implicitHeight: item.implicitHeight + (root.expanded ? pskField.implicitHeight + pskActions.implicitHeight + 18 : 0)
    clip: true

    Connections {
        target: root.network
        function onConnectionFailed(reason) {
            root.psk = "";
            // collapse psk prompt for unknown networks so user can retry fresh
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
                return sig >= 0.75 ? Icons.wifiLocked : sig >= 0.5 ? Icons.wifiSignal3Locked : sig >= 0.3 ? Icons.wifiSignal2Locked : sig >= 0.1 ? Icons.wifiSignal1Locked : Icons.wifiSignal0Locked;
            return sig >= 0.75 ? Icons.wifi : sig >= 0.5 ? Icons.wifiSignal3 : sig >= 0.3 ? Icons.wifiSignal2 : sig >= 0.1 ? Icons.wifiSignal1 : Icons.wifiSignal0;
        }
        iconSize: Theme.fontIconLg
        iconColor: root.network.connected ? Theme.colorGreen : Theme.textPrimary
        text: root.network.name
        textColor: root.network.connected ? Theme.colorGreen : Theme.textPrimary
        showSeparator: root.showSeparator
        onSelected: root.clicked()

        InlineButton {
            text: "Forget"
            accentColor: Theme.colorRed
            visible: root.network.known && !root.network.connected
            onClicked: root.forgotNetwork()
        }
    }

    InputField {
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
        radius: Theme.radiusSm
        color: Theme.withAlpha(Theme.black, 0.3)
        placeholderText: "Password"
        password: true
        text: root.psk

        onTextChanged: root.psk = text
        onAccepted: root.connectWithPsk(root.psk)
        onVisibleChanged: if (visible)
            forceActiveFocus()

        Keys.onEscapePressed: root.expandToggled()
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
            accentColor: Theme.colorGreen
            onClicked: root.connectWithPsk(root.psk)
        }
    }
}
