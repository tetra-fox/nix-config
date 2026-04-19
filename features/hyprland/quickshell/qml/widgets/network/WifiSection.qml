pragma ComponentBehavior: Bound

import qs.components
import Quickshell.Networking
import QtQuick
import QtQuick.Layouts

// WiFi management UI section for the network popup.
Item {
    id: root

    Theme {
        id: theme
    }
    Icons {
        id: icons
    }

    // ── wifi device ───────────────────────────────────────────────────────────
    readonly property WifiDevice wifiDevice: Networking.devices.values.find(d => d.type === DeviceType.Wifi) ?? null
    readonly property bool available: wifiDevice !== null
    readonly property string ifname: root.wifiDevice?.name ?? ""
    readonly property WifiNetwork activeNetwork: root.wifiDevice?.networks.values.find(n => n.connected) ?? null
    readonly property WifiNetwork connectingNetwork: root.wifiDevice?.networks.values.find(n => n.state === ConnectionState.Connecting) ?? null
    readonly property WifiNetwork disconnectingNetwork: root.wifiDevice?.networks.values.find(n => n.state === ConnectionState.Disconnecting) ?? null

    property bool scannerEnabled: false
    onScannerEnabledChanged: {
        if (!scannerEnabled)
            root.showAllNetworks = false;
        if (scannerEnabled && activeNetwork && !iwLinkProc.running)
            iwLinkProc.running = true;
    }

    Binding {
        when: root.wifiDevice !== null
        target: root.wifiDevice
        property: "scannerEnabled"
        value: root.scannerEnabled && (root.showAllNetworks || !root.activeNetwork)
    }

    // keep showAllNetworks in sync with the accordion
    property alias showAllNetworks: moreNetworks.expanded

    // ── iw link state ─────────────────────────────────────────────────────────
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
        const band = mhz >= 5925 ? "6 GHz" : mhz >= 5000 ? "5 GHz" : mhz >= 2400 ? "2.4 GHz" : "";
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

    // ── network list state ────────────────────────────────────────────────────
    property var sortedNetworks: []
    property var expandedNetwork: null
    readonly property var otherNetworks: root.sortedNetworks.filter(n => !n.connected)

    function refreshNetworks() {
        if (root.expandedNetwork !== null)
            return;
        const nets = root.wifiDevice?.networks.values ?? [];
        root.sortedNetworks = nets.slice().filter(n => n.connected || n.signalStrength > 0).sort((a, b) => {
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

    // ── UI ────────────────────────────────────────────────────────────────────
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

        // toggle row
        RowLayout {
            Layout.fillWidth: true

            Text {
                text: "WiFi"
                color: theme.textLabel
                font.pixelSize: theme.fontSm
                font.family: theme.fontFamily
                Layout.fillWidth: true
            }

            ToggleSwitch {
                checked: Networking.wifiEnabled
                onToggled: Networking.wifiEnabled = !Networking.wifiEnabled
            }
        }

        // header row
        Header {
            icon: {
                if (!Networking.wifiEnabled)
                    return icons.wifiOff;
                if (root.activeNetwork)
                    return icons.wifi;
                return scanFrames[scanIndex];
            }
            iconColor: root.activeNetwork ? theme.textPrimary : theme.textInactive
            title: root.activeNetwork ? root.activeNetwork.name : root.connectingNetwork ? root.connectingNetwork.name : root.ifname
            subtitle: (root.activeNetwork || root.connectingNetwork) ? root.ifname : ""
            badgeVisible: root.activeNetwork !== null || root.connectingNetwork !== null || root.disconnectingNetwork !== null || (Networking.wifiEnabled && root.available)
            badgeActive: root.activeNetwork !== null
            badgePulsing: (root.connectingNetwork !== null || root.disconnectingNetwork !== null) && root.activeNetwork === null
            badgeColor: {
                if (root.activeNetwork)
                    return theme.colorGreen;
                if (root.disconnectingNetwork)
                    return theme.colorRed;
                if (root.connectingNetwork)
                    return theme.colorYellow;
                return theme.colorRed;
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

            property var scanFrames: [icons.wifiSignal0, icons.wifiSignal1, icons.wifiSignal2, icons.wifiSignal3, icons.wifi, icons.wifiSignal3, icons.wifiSignal2, icons.wifiSignal1]
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

        // action buttons — visible when connected
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
                accentColor: theme.colorRed
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

        // details — visible when connected
        ColumnLayout {
            Layout.fillWidth: true
            spacing: 5
            visible: root.activeNetwork !== null

            InfoRow {
                label: "MAC"
                value: (root.wifiDevice?.address ?? "-").toLowerCase()
            }
            InfoRow {
                label: "Security"
                value: root.activeNetwork ? root.securityText(root.activeNetwork.security) : ""
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

        // other networks — inside accordion when connected, flat list when not
        WifiNetworkList {
            Layout.fillWidth: true
            visible: !root.activeNetwork
            networks: root.otherNetworks
            expandedNetwork: root.expandedNetwork
            onNetworkClicked: network => root.handleNetworkClicked(network)
            onNetworkForgot: network => network.forget()
            onNetworkConnectWithPsk: (network, psk) => root.handleConnectWithPsk(network, psk)
            onExpandRequested: network => root.handleExpandToggled(network)
        }

        // other networks accordion (when connected)
        Accordion {
            id: moreNetworks
            visible: root.activeNetwork !== null
            label: "More networks"
            loading: root.wifiDevice?.scannerEnabled ?? false

            WifiNetworkList {
                width: parent.width
                networks: root.otherNetworks
                expandedNetwork: root.expandedNetwork
                onNetworkClicked: network => root.handleNetworkClicked(network)
                onNetworkForgot: network => network.forget()
                onNetworkConnectWithPsk: (network, psk) => root.handleConnectWithPsk(network, psk)
                onExpandRequested: network => root.handleExpandToggled(network)
            }
        }
    }
}
