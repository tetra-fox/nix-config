import QtQuick

// Material Symbols Rounded codepoint aliases.
// https://github.com/google/material-design-icons/blob/master/variablefont/MaterialSymbolsRounded%5BFILL%2CGRAD%2Copsz%2Cwght%5D.codepoints
// Usage: Icons { id: icons } then icons.wifi, icons.volumeUp, etc.
QtObject {

    // ── network ─────────────────────────────────────────────────────────────
    readonly property string wifi: "\uF065"
    readonly property string wifiOff: "\uE1DA"
    readonly property string wifiSignal0: "\uF0B0"
    readonly property string wifiSignal1: "\uEBE4"
    readonly property string wifiSignal2: "\uEBD6"
    readonly property string wifiSignal3: "\uEBE1"
    readonly property string wifiSignal0Locked: "\uF532"
    readonly property string wifiSignal1Locked: "\uF58F"
    readonly property string wifiSignal2Locked: "\uF58E"
    readonly property string wifiSignal3Locked: "\uF58D"
    readonly property string wifiLocked: "\uE1E1"
    readonly property string settingsEthernet: "\uE8BE"
    readonly property string cable: "\uEFE6"

    // ── bluetooth ────────────────────────────────────────────────────────────
    readonly property string bluetooth: "\uE1A7"
    readonly property string bluetoothConnected: "\uE1A8"
    readonly property string bluetoothDisabled: "\uE1A9"
    readonly property string bluetoothSearching: "\uE1AA"

    // ── audio ────────────────────────────────────────────────────────────────
    readonly property string volumeUp: "\uE050"
    readonly property string volumeDown: "\uE04D"
    readonly property string volumeMute: "\uE04E"
    readonly property string volumeOff: "\uE04F"
    readonly property string mic: "\uE31D"
    readonly property string micOff: "\uE02B"

    // ── notifications ────────────────────────────────────────────────────────
    readonly property string notifications: "\uE7F4"
    readonly property string notificationsOff: "\uE7F6"
    readonly property string info: "\uE88E"
    readonly property string warning: "\uE002"
    readonly property string error: "\uE160"

    // ── actions ──────────────────────────────────────────────────────────────
    readonly property string check: "\uE5CA"
    readonly property string close: "\uE5CD"
    readonly property string delete_: "\uE92E"
    readonly property string lock: "\uE9E0"
    readonly property string expandMore: "\uE5CF"
    readonly property string progressActivity: "\uE9D0"
}
