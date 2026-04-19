pragma ComponentBehavior: Bound

import qs.components
import Quickshell.Networking
import QtQuick

// Wifi network list — delegates to ScrollableList for overflow/fade handling.
ScrollableList {
    id: root

    property var networks: []
    property var expandedNetwork: null

    signal networkClicked(WifiNetwork network)
    signal networkForgot(WifiNetwork network)
    signal networkConnectWithPsk(WifiNetwork network, string psk)
    signal expandRequested(var network)

    onExpandedNetworkChanged: {
        if (expandedNetwork)
            scrollTimer.restart();
    }

    Timer {
        id: scrollTimer
        interval: 50
        onTriggered: {
            for (let i = 0; i < repeater.count; i++) {
                const item = repeater.itemAt(i);
                if (item && item.network === root.expandedNetwork) { // qmllint disable missing-property
                    root.ensureVisible(item);
                    break;
                }
            }
        }
    }

    Repeater {
        id: repeater
        model: root.networks

        delegate: WifiNetworkDelegate {
            required property WifiNetwork modelData
            required property int index
            width: root.width
            network: modelData
            expanded: root.expandedNetwork === modelData
            showSeparator: index > 0

            onClicked: root.networkClicked(modelData)
            onForgotNetwork: root.networkForgot(modelData)
            onConnectWithPsk: psk => root.networkConnectWithPsk(modelData, psk)
            onExpandToggled: root.expandRequested(expanded ? null : modelData)
        }
    }
}
