import QtQuick

// Material Symbols Rounded codepoint aliases.
// https://fonts.google.com/icons?icon.style=Rounded
// https://raw.githubusercontent.com/google/material-design-icons/refs/heads/master/variablefont/MaterialSymbolsRounded%5BFILL%2CGRAD%2Copsz%2Cwght%5D.codepoints
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

    // ── system ──────────────────────────────────────────────────────────────
    readonly property string computer: "\uE31E"
    readonly property string dns: "\uE875"
    readonly property string desktopWindows: "\uE30C"
    readonly property string systemMenu: "\uF31D"
    readonly property string terminal: "\uEB8E"
    readonly property string timer: "\uE425"
    readonly property string monitoring: "\uF190"
    readonly property string developerBoard: "\uE30D"
    readonly property string memory: "\uE322"
    readonly property string hardDrive: "\uF80E"
    readonly property string swapHoriz: "\uE8D4"
    readonly property string thermostat: "\uE1FF"
    readonly property string deployedCode: "\uF720"
    readonly property string code: "\uE86F"

    // ── power ────────────────────────────────────────────────────────────────
    readonly property string logout: "\uE9BA"
    readonly property string restart: "\uF053"
    readonly property string power: "\uF8C7"

    // ── media ────────────────────────────────────────────────────────────────
    readonly property string playArrow: "\uE037"
    readonly property string pause: "\uE034"
    readonly property string skipPrevious: "\uE045"
    readonly property string skipNext: "\uE044"
    readonly property string musicNote: "\uE405"
    readonly property string stopCircle: "\uE4DB"

    // ── actions ──────────────────────────────────────────────────────────────
    readonly property string check: "\uE5CA"
    readonly property string close: "\uE5CD"
    readonly property string delete_: "\uE92E"
    readonly property string lock: "\uE899"
    readonly property string expandMore: "\uE5CF"
    readonly property string progressActivity: "\uE9D0"
}
