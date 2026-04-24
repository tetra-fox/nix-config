pragma ComponentBehavior: Bound

import qs.components
import qs.lib
import Quickshell.Networking
import QtQuick
import QtQuick.Layouts

Item {
    id: root

    readonly property WifiDevice wifiDevice: Networking.devices.values.find(d => d && d.type === DeviceType.Wifi) ?? null
    readonly property bool available: wifiDevice !== null
    readonly property string ifname: root.wifiDevice?.name ?? ""
    readonly property WifiNetwork activeNetwork: root.wifiDevice?.networks.values.find(n => n && n.connected) ?? null
    readonly property WifiNetwork connectingNetwork: root.wifiDevice?.networks.values.find(n => n && n.state === ConnectionState.Connecting) ?? null
    readonly property WifiNetwork disconnectingNetwork: root.wifiDevice?.networks.values.find(n => n && n.state === ConnectionState.Disconnecting) ?? null

    property bool scannerEnabled: false
    onScannerEnabledChanged: {
        if (!scannerEnabled)
            root.showAllNetworks = false;
        if (scannerEnabled && activeNetwork && !iwLinkProc.running)
            iwLinkProc.running = true;
    }

    // only run hw scans when actually needed: browsing networks or not connected
    Binding {
        when: root.wifiDevice !== null
        target: root.wifiDevice
        property: "scannerEnabled"
        value: root.scannerEnabled && (root.showAllNetworks || !root.activeNetwork)
    }

    property alias showAllNetworks: moreNetworks.expanded

    property int iwSignal: 0
    property int iwFreq: 0
    property string iwTxBitrate: ""

    onActiveNetworkChanged: {
        if (!activeNetwork) {
            root.iwSignal = 0;
            root.iwFreq = 0;
            root.iwTxBitrate = "";
        } else if (scannerEnabled && !iwLinkProc.running) {
            iwLinkProc.running = true;
        }
    }

    function formatFreq(mhz) {
        if (mhz <= 0)
            return "-";
        let band;
        if (mhz >= 5925)
            band = "6 GHz";
        else if (mhz >= 5000)
            band = "5 GHz";
        else if (mhz >= 2400)
            band = "2.4 GHz";
        else
            band = "";
        return band ? mhz + " MHz (" + band + ")" : mhz + " MHz";
    }

    function securityText(sec) {
        switch (sec) {
        case WifiSecurityType.Sae:
            return "WPA3";
        case WifiSecurityType.Wpa3SuiteB192:
            return "WPA3 Suite B";
        case WifiSecurityType.Wpa2Psk:
            return "WPA2";
        case WifiSecurityType.Wpa2Eap:
            return "WPA2 Enterprise";
        case WifiSecurityType.WpaPsk:
            return "WPA";
        case WifiSecurityType.WpaEap:
            return "WPA Enterprise";
        case WifiSecurityType.StaticWep:
        case WifiSecurityType.DynamicWep:
            return "WEP";
        case WifiSecurityType.Leap:
            return "LEAP";
        case WifiSecurityType.Owe:
            return "OWE";
        case WifiSecurityType.Open:
            return "Open";
        default:
            return "";
        }
    }

    BufferedProcess {
        id: iwLinkProc
        command: ["iw", "dev", root.ifname, "link"]
        onFinished: output => {
            const freqMatch = output.match(/freq:\s*(\d+)/);
            root.iwFreq = freqMatch ? parseInt(freqMatch[1]) : 0;
            const sigMatch = output.match(/signal:\s*(-?\d+)/);
            root.iwSignal = sigMatch ? parseInt(sigMatch[1]) : 0;
            const txMatch = output.match(/tx bitrate:\s*([\d.]+\s*\S+)/);
            root.iwTxBitrate = txMatch ? txMatch[1].replace("MBit/s", "Mbps") : "";
        }
    }

    Timer {
        interval: 2000
        running: root.scannerEnabled && root.activeNetwork !== null
        repeat: true
        onTriggered: if (!iwLinkProc.running)
            iwLinkProc.running = true
    }

    property var sortedNetworks: []
    property var expandedNetwork: null
    readonly property var otherNetworks: root.sortedNetworks.filter(n => n && !n.connected)

    function refreshNetworks() {
        // skip re-sort while psk prompt is open to avoid yanking it away mid-type
        if (root.expandedNetwork !== null)
            return;
        const nets = root.wifiDevice?.networks.values ?? [];
        // filter out dangling entries that can appear mid-AP-removal before the sequence updates
        root.sortedNetworks = nets.slice().filter(n => n && (n.connected || n.signalStrength > 0)).sort((a, b) => {
            if (a.connected !== b.connected)
                return a.connected ? -1 : 1;
            return b.signalStrength - a.signalStrength;
        });
    }

    function handleNetworkClicked(network) {
        if (network.connected) {
            network.disconnect();
        } else if (network.known) {
            network.connect();
        } else {
            const open = network.security === WifiSecurityType.Open || network.security === WifiSecurityType.Unknown;
            if (open) {
                network.connect();
            } else {
                root.expandedNetwork = root.expandedNetwork === network ? null : network;
            }
        }
    }

    function handleConnectWithPsk(network, psk) {
        network.connectWithPsk(psk);
        root.expandedNetwork = null;
        root.refreshNetworks();
    }

    function handleExpandToggled(network) {
        root.expandedNetwork = network;
        root.refreshNetworks();
    }

    Connections {
        target: root.wifiDevice?.networks ?? null
        function onCountChanged() {
            root.refreshNetworks();
        }
    }

    Timer {
        interval: 3000
        running: root.scannerEnabled && root.expandedNetwork === null
        repeat: true
        onTriggered: root.refreshNetworks()
    }

    onAvailableChanged: refreshNetworks()
    Component.onCompleted: refreshNetworks()

    implicitHeight: visible ? col.implicitHeight : 0
    visible: root.available

    ColumnLayout {
        id: col
        anchors {
            top: parent.top
            left: parent.left
            right: parent.right
        }
        spacing: 5

        RowLayout {
            Layout.fillWidth: true

            Text {
                text: "WiFi"
                color: Theme.textLabel
                font.pixelSize: Theme.fontSm
                font.family: Theme.fontFamily
                Layout.fillWidth: true
            }

            ToggleSwitch {
                checked: Networking.wifiEnabled
                onToggled: Networking.wifiEnabled = !Networking.wifiEnabled
            }
        }

        Header {
            icon: {
                if (!Networking.wifiEnabled)
                    return Icons.wifiOff;
                if (root.activeNetwork)
                    return Icons.wifi;
                return scanFrames[scanIndex];
            }
            iconColor: root.activeNetwork ? Theme.textPrimary : Theme.textInactive
            title: {
                if (root.activeNetwork)
                    return root.activeNetwork.name;
                if (root.connectingNetwork)
                    return root.connectingNetwork.name;
                return root.ifname;
            }
            subtitle: (root.activeNetwork || root.connectingNetwork) ? root.ifname : ""
            badgeVisible: root.activeNetwork !== null || root.connectingNetwork !== null || root.disconnectingNetwork !== null || (Networking.wifiEnabled && root.available)
            badgeActive: root.activeNetwork !== null
            badgePulsing: (root.connectingNetwork !== null || root.disconnectingNetwork !== null) && root.activeNetwork === null
            badgeColor: {
                if (root.activeNetwork)
                    return Theme.colorGreen;
                if (root.disconnectingNetwork)
                    return Theme.colorRed;
                if (root.connectingNetwork)
                    return Theme.colorYellow;
                return Theme.colorRed;
            }
            badgeText: {
                if (root.activeNetwork)
                    return "Connected";
                if (root.disconnectingNetwork)
                    return "Disconnecting";
                if (root.connectingNetwork)
                    return "Connecting";
                if (Networking.wifiEnabled)
                    return "Disconnected";
                return "";
            }

            property var scanFrames: [Icons.wifiSignal0, Icons.wifiSignal1, Icons.wifiSignal2, Icons.wifiSignal3, Icons.wifi, Icons.wifiSignal3, Icons.wifiSignal2, Icons.wifiSignal1]
            property int scanIndex: 0

            Timer {
                running: Networking.wifiEnabled && !root.activeNetwork
                interval: 400
                repeat: true
                onRunningChanged: if (!running)
                    parent.scanIndex = 0
                onTriggered: parent.scanIndex = (parent.scanIndex + 1) % parent.scanFrames.length
            }
        }

        RowLayout {
            Layout.fillWidth: true
            visible: root.activeNetwork !== null
            spacing: 8

            InlineButton {
                text: "Disconnect"
                onClicked: root.activeNetwork.disconnect()
            }

            InlineButton {
                text: "Forget"
                accentColor: Theme.colorRed
                onClicked: {
                    const net = root.activeNetwork;
                    if (!net)
                        return;
                    net.disconnect();
                    net.forget();
                }
            }

            Item {
                Layout.fillWidth: true
            }
        }

        ColumnLayout {
            Layout.fillWidth: true
            spacing: 5
            visible: root.activeNetwork !== null

            InfoRow {
                label: "MAC"
                value: (root.wifiDevice?.address ?? "-").toLowerCase() // qmllint disable missing-property
            }
            InfoRow {
                label: "Security"
                value: root.activeNetwork ? root.securityText(root.activeNetwork.security) : "" // qmllint disable unresolved-type
                visible: value !== ""
            }
            InfoRow {
                label: "Signal"
                value: root.iwSignal !== 0 ? root.iwSignal + " dBm" : "-"
            }
            InfoRow {
                label: "Frequency"
                value: root.formatFreq(root.iwFreq)
            }
            InfoRow {
                label: "TX Rate"
                value: root.iwTxBitrate || "-"
            }
        }

        // flat list when disconnected, accordion when connected
        ConfiguredNetworkList {
            Layout.fillWidth: true
            visible: !root.activeNetwork
        }

        Accordion {
            id: moreNetworks
            visible: root.activeNetwork !== null
            label: "More networks"
            loading: root.wifiDevice?.scannerEnabled ?? false

            ConfiguredNetworkList {
                width: parent.width
            }
        }
    }

    component ConfiguredNetworkList: WifiNetworkList {
        networks: root.otherNetworks
        expandedNetwork: root.expandedNetwork
        onNetworkClicked: network => root.handleNetworkClicked(network)
        onNetworkForgot: network => network.forget()
        onNetworkConnectWithPsk: (network, psk) => root.handleConnectWithPsk(network, psk)
        onExpandRequested: network => root.handleExpandToggled(network)
    }
}
