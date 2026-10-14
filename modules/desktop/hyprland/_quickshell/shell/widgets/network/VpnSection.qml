pragma ComponentBehavior: Bound

import qs.components
import qs.lib
import Quickshell.Io
import QtQuick
import QtQuick.Layouts

// wireguard tunnels via nmcli, quickshell's Networking has no wireguard device type.
// one tunnel up at a time, NM won't down tunnel A when B comes up so we down the others
Item {
    id: root

    property bool polling: false

    // [{name, uuid, device, active}], wireguard only
    property var tunnels: []
    // "" when idle
    property string busyUuid: ""
    // "up" | "down" | "dropscan" | "reconcile" | ""
    property string pendingAction: ""
    property string opError: ""
    // reassigned wholesale, never mutated
    property var detail: ({})

    // other active tunnels still to down after a successful up
    property var _dropQueue: []
    property string _opStderr: ""

    readonly property bool busy: root.busyUuid !== ""
    readonly property var activeTunnel: root.tunnels.find(t => t && t.active) ?? null
    readonly property bool anyActive: root.activeTunnel !== null

    // nmcli output and stderr are parsed
    readonly property var cLocale: ({
            "LC_ALL": "C"
        })

    readonly property var enumerateCmd: ["nmcli", "-t", "-f", "NAME,UUID,TYPE,DEVICE,STATE", "connection", "show"]

    // nmcli -t escapes ':' as '\:' and '\' as '\\' in values, and connection names can
    // contain ':', so split only on unescaped ':'. detail output is not escaped
    function _splitTerse(line: string): var {
        const fields = [];
        let cur = "";
        for (let i = 0; i < line.length; i++) {
            const c = line[i];
            if (c === "\\" && i + 1 < line.length) {
                // kept verbatim, unescaped below
                cur += c + line[i + 1];
                i++;
            } else if (c === ":") {
                fields.push(cur);
                cur = "";
            } else {
                cur += c;
            }
        }
        fields.push(cur);
        // one regex, two sequential replaces would double-unescape \\:
        return fields.map(f => f.replace(/\\(.)/g, "$1"));
    }

    function _parseTunnels(stdout: string): var {
        const out = [];
        for (const line of stdout.split("\n")) {
            if (line === "")
                continue;
            const f = root._splitTerse(line);
            if (f.length < 5)
                continue;
            if (f[2] !== "wireguard") // exact type, not includes("vpn")
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

    // values here are not escaped and can contain ':' (endpoint host:port), split on the first only
    function _parseDetail(stdout: string): var {
        const map = {};
        for (const line of stdout.split("\n")) {
            const idx = line.indexOf(":");
            if (idx < 0)
                continue;
            map[line.slice(0, idx)] = line.slice(idx + 1);
        }
        // one peer is wireguard.peers, several are wireguard.peers[N]
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
            "endpoint": endpoints[0] ?? ""
        };
    }

    // up first, then down the others, so a failed handshake leaves the old tunnel up
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

    // first enumerate run allowed to clear busy, earlier runs hold pre-op state
    property int _reconcileRun: 0

    // the only path back to idle. active state comes from nmcli STATE, never an op's exit code
    function _reconcile(): void {
        root.pendingAction = "reconcile";
        root._reconcileRun = listProc.runId + 1;
        listProc.trigger();
    }

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

    // polling pauses during an op so it can't race the reconcile
    PolledProcess {
        id: listProc
        environment: root.cLocale
        command: root.enumerateCmd
        polling: root.polling && !root.busy
        onFinished: output => {
            const rows = root._parseTunnels(output);
            // a failed poll emits finished(""), don't clear a populated model with it
            if (!(rows.length === 0 && root.tunnels.length > 0 && output === "")) {
                // keep the array when unchanged so the Repeater doesn't rebuild rows every poll
                const same = rows.length === root.tunnels.length && rows.every((r, i) => {
                    const t = root.tunnels[i];
                    return r.uuid === t.uuid && r.name === t.name && r.device === t.device && r.active === t.active;
                });
                if (!same)
                    root.tunnels = rows;
            }
            if (root.pendingAction === "reconcile") {
                if (listProc.runId < root._reconcileRun) {
                    // started before the op finished, enumerate again
                    listProc.trigger();
                } else {
                    root.busyUuid = "";
                    root.pendingAction = "";
                }
            }
            if (root.activeTunnel)
                root._fetchDetail();
        }
    }

    BufferedProcess {
        id: detailProc
        environment: root.cLocale
        onFinished: output => root.detail = root._parseDetail(output)
    }

    BufferedProcess {
        id: dropScanProc
        environment: root.cLocale
        command: root.enumerateCmd
        onFinished: output => {
            root._dropQueue = root._parseTunnels(output).filter(t => t.active && t.uuid !== root.busyUuid).map(t => t.uuid);
            root._pumpDropQueue();
        }
    }

    // Process, not BufferedProcess, which discards the exit code
    Process {
        id: upProc
        environment: root.cLocale
        stderr: SplitParser {
            onRead: data => root._opStderr += data + "\n"
        }
        onExited: (exitCode, exitStatus) => { // qmllint disable signal-handler-parameters
            if (root.pendingAction !== "up") // watchdog already moved on
                return;
            // QProcess.ExitStatus isn't a registered enum: 0 NormalExit, 1 CrashExit
            if (exitCode === 0 && exitStatus === 0) {
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
        stderr: SplitParser {
            onRead: data => root._opStderr += data + "\n"
        }
        onExited: (exitCode, exitStatus) => { // qmllint disable signal-handler-parameters
            // a down failure is non-fatal, the tunnel may already be gone
            if (root._dropQueue.length > 0) {
                root._pumpDropQueue();
                return;
            }
            root._reconcile();
        }
    }

    // FailedToStart and a hung NM emit no exited signal, busy would stick with polling paused
    Timer {
        id: watchdog
        interval: 30000
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

    implicitHeight: visible ? col.implicitHeight : 0
    // stays visible mid-op
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

            SectionLabel {
                text: "VPN"
                Layout.fillWidth: true
            }

            // disconnect only, there's no single connect target
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
                    required property int index

                    Layout.fillWidth: true
                    text: modelData.name
                    active: modelData.active
                    showSeparator: index > 0
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
