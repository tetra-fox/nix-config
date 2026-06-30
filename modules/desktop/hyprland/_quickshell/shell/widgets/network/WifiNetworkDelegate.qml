pragma ComponentBehavior: Bound

import qs.components
import qs.lib
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
            if (!root.network?.known)
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
            // guard against transient null: delegate briefly outlives its WifiNetwork during AP removal
            if (!root.network)
                return Icons.wifiSignal0;
            const secured = root.network.security !== WifiSecurityType.Open && root.network.security !== WifiSecurityType.Unknown; // qmllint disable unresolved-type
            const sig = root.network.signalStrength;
            const lock = secured ? "Locked" : "";
            if (sig >= 0.75)
                return Icons[`wifi${lock}`];
            if (sig >= 0.5)
                return Icons[`wifiSignal3${lock}`];
            if (sig >= 0.3)
                return Icons[`wifiSignal2${lock}`];
            if (sig >= 0.1)
                return Icons[`wifiSignal1${lock}`];
            return Icons[`wifiSignal0${lock}`];
        }
        iconSize: Theme.fontIconLg
        iconColor: root.network?.connected ? Theme.colorGreen : Theme.textPrimary
        text: root.network?.name ?? ""
        textColor: root.network?.connected ? Theme.colorGreen : Theme.textPrimary
        showSeparator: root.showSeparator
        onSelected: root.clicked()

        InlineButton {
            text: "Forget"
            accentColor: Theme.colorRed
            visible: (root.network?.known ?? false) && !root.network?.connected
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
