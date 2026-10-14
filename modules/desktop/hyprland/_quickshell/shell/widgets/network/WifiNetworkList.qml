pragma ComponentBehavior: Bound

import qs.components
import Quickshell
import Quickshell.Networking
import QtQuick

ScrollableList {
    id: root

    property var networks: []
    property var expandedNetwork: null

    signal networkClicked(WifiNetwork network)
    signal networkForgot(WifiNetwork network)
    signal networkConnectWithPsk(WifiNetwork network, string psk)
    signal expandRequested(var network)

    Repeater {
        // ScriptModel diffs by identity, only added/removed rows rebuild
        model: ScriptModel {
            values: root.networks
        }

        delegate: WifiNetworkDelegate {
            id: delegateItem
            required property WifiNetwork modelData
            required property int index
            width: root.width
            network: modelData
            expanded: root.expandedNetwork === modelData
            showSeparator: index > 0

            // the expandedNetwork edge would measure the old height
            onImplicitHeightChanged: {
                if (expanded)
                    root.ensureVisible(delegateItem);
            }

            onClicked: root.networkClicked(modelData)
            onForgotNetwork: root.networkForgot(modelData)
            onConnectWithPsk: psk => root.networkConnectWithPsk(modelData, psk)
            onExpandRequested: expand => root.expandRequested(expand ? modelData : null)
        }
    }
}
