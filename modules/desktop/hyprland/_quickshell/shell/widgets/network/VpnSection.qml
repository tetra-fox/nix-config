pragma ComponentBehavior: Bound

import qs.components
import qs.lib
import Quickshell.Io
import QtQuick
import QtQuick.Layouts

// wireguard tunnels via nmcli (quickshell's Networking service does not model
// wireguard - DeviceType is only None/Wifi/Wired). radio-exclusive: one tunnel up
// at a time. NetworkManager will NOT auto-down tunnel A when you up B (two wg ifaces
// can coexist), so exclusivity is enforced by explicitly downing the others.
Item {
    id: root

    // set from Network.qml, gated on popup.visible
    property bool polling: false

    // [{name, uuid, device, active}] from the last enumerate, wireguard only
    property var tunnels: []
    // uuid of the in-flight up/down target; "" means idle
    property string busyUuid: ""
    // which op is in flight, drives the badge: "up" | "down" | "dropscan" | "reconcile" | ""
    property string pendingAction: ""
    // last failure text (stderr of a failed op), cleared on the next user action
    property string opError: ""
    // detail of the active tunnel for the accordion, reassigned wholesale (never mutated)
    property var detail: ({})

    // uuids still to be downed after a successful up, to enforce radio exclusivity
    property var _dropQueue: []
    // accumulated stderr of the in-flight toggle, so multi-line nmcli/polkit errors survive
    property string _opStderr: ""

    readonly property bool busy: root.busyUuid !== ""
    readonly property var activeTunnel: root.tunnels.find(t => t && t.active) ?? null
    readonly property bool anyActive: root.activeTunnel !== null

    // every nmcli invocation parses output or stderr, so force the C locale
    readonly property var cLocale: ({
            "LC_ALL": "C"
        })

    // -- parsers --

    // nmcli -t (terse) escapes the field separator ':' as '\:' and a literal backslash
    // as '\\' inside field VALUES (nmcli -e defaults to yes). a raw split on ':' is wrong
    // because connection names can legally contain a colon. walk char by char, treat '\'
    // as escaping the next char, split only on an UNESCAPED ':', then resolve escapes.
    // this applies ONLY to the enumerate command; detail values are not terse-escaped.
    function _splitTerse(line: string): var {
        const fields = [];
        let cur = "";
        for (let i = 0; i < line.length; i++) {
            const c = line[i];
            if (c === "\\" && i + 1 < line.length) {
                // keep the pair verbatim so the unescape pass below resolves it
                cur += c + line[i + 1];
                i++;
            } else if (c === ":") {
                fields.push(cur);
                cur = "";
            } else {
                cur += c;
            }
        }
        fields.push(cur); // trailing field, "" when the line ends in ':'
        // one sweep: \X -> X turns \: into : and \\ into \ . two sequential replaces
        // would double-unescape \\: , so keep it a single regex
        return fields.map(f => f.replace(/\\(.)/g, "$1"));
    }

    function _parseTunnels(stdout: string): var {
        const out = [];
        for (const line of stdout.split("\n")) {
            if (line === "")
                continue;
            const f = root._splitTerse(line);
            if (f.length < 5) // truncated line, skip rather than read undefined
                continue;
            if (f[2] !== "wireguard") // exact type; do not loosen to includes("vpn")
                continue;
            out.push({
                "name": f[0],
                "uuid": f[1],
                "device": f[3] // "" when inactive
                ,
                "active": f[4] === "activated"
            });
        }
        return out;
    }

    // 'nmcli -t connection show <uuid>' emits key:value where value is everything after
    // the FIRST colon and is NOT terse-escaped (endpoint host:port keeps its colon), so
    // split on the first colon only; never run this through _splitTerse.
    function _parseDetail(stdout: string): var {
        const map = {};
        for (const line of stdout.split("\n")) {
            const idx = line.indexOf(":");
            if (idx < 0)
                continue;
            map[line.slice(0, idx)] = line.slice(idx + 1);
        }
        // peers is unindexed for a single peer (wireguard.peers) and indexed for
        // multiple (wireguard.peers[1]...). collect each peer's endpoint; a roaming
        // peer may have none. \S+ stops at whitespace so an ipv6 [addr]:port survives.
        const endpoints = [];
        for (const k in map) {
            if (k === "wireguard.peers" || /^wireguard\.peers\[\d+\]$/.test(k)) {
                const m = map[k].match(/endpoint=(\S+)/);
                if (m)
                    endpoints.push(m[1]);
            }
        }
        return {
            "ifname": map["connection.interface-name"] ?? "",
            "address": map["IP4.ADDRESS[1]"] ?? "",
            "endpoint": endpoints[0] ?? "",
            "peerCount": endpoints.length
        };
    }

    // -- state machine --

    // up-first then down-others: a failed handshake leaves the old tunnel up so the user
    // keeps connectivity; the brief two-up window is closed by the drop step
    function connect(uuid: string): void {
        if (root.busy || root.activeTunnel?.uuid === uuid)
            return;
        root.opError = "";
        root._opStderr = "";
        root.busyUuid = uuid;
        root.pendingAction = "up";
        upProc.command = ["nmcli", "connection", "up", "uuid", uuid];
        upProc.running = true;
    }

    function disconnect(uuid: string): void {
        if (root.busy)
            return;
        root.opError = "";
        root._opStderr = "";
        root.busyUuid = uuid;
        root.pendingAction = "down";
        downProc.command = ["nmcli", "connection", "down", "uuid", uuid];
        downProc.running = true;
    }

    // re-enumerate is the only path back to idle; active-ness is set ONLY from STATE here,
    // never optimistically from an op's exit code
    function _reconcile(): void {
        root.pendingAction = "reconcile";
        if (!listProc.running)
            listProc.running = true;
    }

    // down each remaining uuid from a fresh enumerate, then reconcile
    function _pumpDropQueue(): void {
        if (root._dropQueue.length === 0) {
            root._reconcile();
            return;
        }
        const rest = root._dropQueue.slice();
        const next = rest.shift();
        root._dropQueue = rest;
        root.pendingAction = "down";
        downProc.command = ["nmcli", "connection", "down", "uuid", next];
        downProc.running = true;
    }

    function _fetchDetail(): void {
        if (!root.activeTunnel)
            return;
        detailProc.command = ["nmcli", "-t", "connection", "show", root.activeTunnel.uuid];
        if (!detailProc.running)
            detailProc.running = true;
    }

    onActiveTunnelChanged: {
        if (root.activeTunnel)
            root._fetchDetail();
        else
            root.detail = ({});
    }

    onPollingChanged: if (root.polling && !listProc.running)
        listProc.running = true

    // enumerate (read): drives the model and the return to idle
    BufferedProcess {
        id: listProc
        environment: root.cLocale
        command: ["nmcli", "-t", "-f", "NAME,UUID,TYPE,DEVICE,STATE", "connection", "show"]
        onFinished: output => {
            const rows = root._parseTunnels(output);
            // a failed/empty poll emits finished("") (BufferedProcess fires off
            // runningChanged); don't clobber a populated model with that
            if (!(rows.length === 0 && root.tunnels.length > 0 && output === ""))
                root.tunnels = rows;
            if (root.pendingAction === "reconcile") {
                root.busyUuid = "";
                root.pendingAction = "";
            }
            if (root.activeTunnel)
                root._fetchDetail();
        }
    }

    // active-tunnel detail (read): feeds the accordion
    BufferedProcess {
        id: detailProc
        environment: root.cLocale
        onFinished: output => root.detail = root._parseDetail(output)
    }

    // fresh enumerate after a successful up, to compute which tunnels to drop
    BufferedProcess {
        id: dropScanProc
        environment: root.cLocale
        command: ["nmcli", "-t", "-f", "NAME,UUID,TYPE,DEVICE,STATE", "connection", "show"]
        onFinished: output => {
            root._dropQueue = root._parseTunnels(output).filter(t => t.active && t.uuid !== root.busyUuid).map(t => t.uuid);
            root._pumpDropQueue();
        }
    }

    // toggles use a tracked Process for the exit code; BufferedProcess discards it.
    // stderr is accumulated so multi-line nmcli/polkit errors survive for opError.
    Process {
        id: upProc
        environment: root.cLocale
        stdout: SplitParser {}
        stderr: SplitParser {
            onRead: data => root._opStderr += data + "\n"
        }
        onExited: (exitCode, exitStatus) => { // qmllint disable signal-handler-parameters
            if (root.pendingAction !== "up") // a watchdog kill already moved on
                return;
            // QProcess.ExitStatus isn't registered as a quickshell enum, so compare the
            // raw int: 0 == NormalExit, 1 == CrashExit (our watchdog SIGTERM lands here)
            if (exitCode === 0 && exitStatus === 0) {
                // success: drop the other active tunnels computed from fresh truth
                root.pendingAction = "dropscan";
                dropScanProc.running = true;
            } else {
                root.opError = root._opStderr.trim() || "Failed to connect";
                root._reconcile();
            }
        }
    }

    Process {
        id: downProc
        environment: root.cLocale
        stdout: SplitParser {}
        stderr: SplitParser {
            onRead: data => root._opStderr += data + "\n"
        }
        onExited: (exitCode, exitStatus) => { // qmllint disable signal-handler-parameters
            // a down failure is non-fatal (tunnel may already be gone); reconcile to truth.
            // while draining the drop queue keep pumping it
            if (root._dropQueue.length > 0) {
                root._pumpDropQueue();
                return;
            }
            root._reconcile();
        }
    }

    // FailedToStart (nmcli missing) and a hung NM D-Bus emit no exited signal, so busyUuid
    // would stick forever and the poll is suppressed while busy. this is the only guard.
    Timer {
        id: watchdog
        interval: 30000 // up legitimately takes seconds on handshake
        running: root.busy
        onTriggered: {
            if (upProc.running)
                upProc.running = false; // SIGTERM
            if (downProc.running)
                downProc.running = false;
            root.opError = "nmcli timed out or failed to launch";
            root._dropQueue = [];
            root._reconcile();
        }
    }

    // periodic poll, suppressed during an op so it can't race the reconcile
    Timer {
        interval: 2000
        running: root.polling && !root.busy
        repeat: true
        onTriggered: if (!listProc.running)
            listProc.running = true
    }

    implicitHeight: visible ? col.implicitHeight : 0
    // collapse out when there are no tunnels; keep visible mid-op so it doesn't vanish
    visible: root.tunnels.length > 0 || root.busy

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
                text: "VPN"
                color: Theme.textLabel
                font.pixelSize: Theme.fontSm
                font.family: Theme.fontFamily
                Layout.fillWidth: true
            }

            // disconnect-only: radio has no single unambiguous connect target
            ToggleSwitch {
                checked: root.anyActive || root.busy
                onToggled: if (root.activeTunnel)
                    root.disconnect(root.activeTunnel.uuid)
            }
        }

        Header {
            icon: {
                if (root.opError !== "")
                    return Icons.vpnKeyAlert;
                if (root.anyActive)
                    return Icons.vpnKey;
                return Icons.vpnKeyOff;
            }
            iconColor: root.anyActive ? Theme.textPrimary : Theme.textInactive
            title: root.activeTunnel ? root.activeTunnel.name : "VPN"
            subtitle: root.activeTunnel ? (root.detail.endpoint ?? "") : ""
            badgeVisible: true
            badgeActive: root.anyActive
            badgePulsing: root.busy
            badgeColor: {
                if (root.opError !== "")
                    return Theme.colorRed;
                if (root.busy)
                    return Theme.colorYellow;
                if (root.anyActive)
                    return Theme.colorGreen;
                return Theme.colorRed;
            }
            badgeText: {
                if (root.pendingAction === "up")
                    return "Connecting";
                if (root.pendingAction === "down")
                    return "Disconnecting";
                if (root.opError !== "")
                    return "Failed";
                if (root.anyActive)
                    return "Connected";
                return "Disconnected";
            }
        }

        ColumnLayout {
            Layout.fillWidth: true
            Layout.topMargin: 3
            spacing: 0

            Repeater {
                model: root.tunnels

                SelectableItem {
                    required property var modelData
                    // under ComponentBehavior: Bound, index is not auto-injected; declare it
                    required property int index

                    Layout.fillWidth: true
                    text: modelData.name
                    active: modelData.active
                    showSeparator: index > 0
                    // spinner on the row whose op is in flight, else checkmark when active
                    icon: (root.busy && root.busyUuid === modelData.uuid) ? Icons.progressActivity : Icons.check
                    onSelected: {
                        if (root.busy)
                            return;
                        if (modelData.active)
                            root.disconnect(modelData.uuid);
                        else
                            root.connect(modelData.uuid);
                    }
                }
            }
        }

        Text {
            Layout.fillWidth: true
            Layout.topMargin: 3
            text: root.opError
            color: Theme.danger
            font.pixelSize: Theme.fontSm
            font.family: Theme.fontFamily
            wrapMode: Text.WordWrap
            visible: root.opError !== ""
        }

        Accordion {
            Layout.fillWidth: true
            Layout.topMargin: 3
            label: "Details"
            visible: root.activeTunnel !== null

            ColumnLayout {
                width: parent.width
                spacing: 5

                InfoRow {
                    label: "Endpoint"
                    value: root.detail.endpoint || "-"
                    elide: Text.ElideRight
                }
                InfoRow {
                    label: "Address"
                    value: root.detail.address || "-"
                    elide: Text.ElideRight
                }
                InfoRow {
                    label: "Interface"
                    value: root.detail.ifname || "-"
                }
            }
        }
    }
}
