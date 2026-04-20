import QtQuick
import Quickshell

// design tokens — instantiate as Theme { id: theme } wherever needed
QtObject {

    // ── typography ───────────────────────────────────────────────────────────
    readonly property string fontFamily: "monospace"
    readonly property string fontIconFamily: "Material Symbols Rounded Filled"
    // FILL=1 is baked into the font (see quickshell/default.nix)
    readonly property var fontIconAxes: ({
            "wght": 600,
            "GRAD": 0,
            "opsz": 20
        })
    readonly property int fontXs: 10  // chevrons, tiny indicators
    readonly property int fontSm: 11  // section labels
    readonly property int fontMd: 12  // body text, workspace numbers
    readonly property int fontBase: 13  // clock
    readonly property int fontIcon: 16  // bar-level icons
    readonly property int fontIconLg: 18  // popup-level icons

    // ── colors ───────────────────────────────────────────────────────────────
    // Text
    readonly property color textActive: "#ffffff"    // focused / selected
    readonly property color textPrimary: "#dddddd"    // primary text
    readonly property color textSecondary: "#cfcfcf"    // secondary / percentages
    readonly property color textLabel: "#bdbdbd"    // section labels, headers
    readonly property color textInactive: "#aaaaaa"    // inactive / dim

    // Surfaces
    readonly property color panelBg: "#ce161616"  // pill / popup background
    readonly property color panelBorder: "#26ffffff"   // pill border — white overlay, adapts to surface color
    readonly property color hoverBg: "#26ffffff"  // hover state — white overlay, preserves transparency
    readonly property color pressedBg: "#40ffffff"  // pressed state — stronger white overlay
    readonly property color openBg: withAlpha(accent, 0.15)  // popup-open state — accent tint overlay
    readonly property color inactiveBg: "#e02e2e2e"  // inactive workspace pill, dividers
    readonly property color separatorBg: "#3a3a3a"    // device-list separators
    // ── color helpers ───────────────────────────────────────────────────────
    function withAlpha(color, alpha) {
        return Qt.rgba(color.r, color.g, color.b, alpha);
    }
    readonly property color black: "#000000"
    readonly property color white: "#ffffff"

    // Palette
    readonly property color colorPink: "#ff34a8"   // primary accent
    readonly property color colorPurple: "#b06bff"   // secondary / aux accent
    readonly property color colorBlue: "#4facf7"   // upload, info
    readonly property color colorGreen: "#3dc97a"   // connected, success
    readonly property color colorYellow: "#f0b429"   // caution, warning
    readonly property color colorRed: "#f05268"   // error, danger

    // Semantic
    readonly property color accent: colorPink
    readonly property color danger: colorRed

    // ── shape ────────────────────────────────────────────────────────────────
    readonly property int radiusSm: 3  // workspace pill
    readonly property int radiusMd: 4  // button hit targets
    readonly property int radiusLg: 6  // panels and popups

    // ── screen ───────────────────────────────────────────────────────────────
    readonly property var primaryScreen: Quickshell.screens[0]

    // ── layout ───────────────────────────────────────────────────────────────
    readonly property real barInactiveOpacity: 0.3  // unfocused monitor bar opacity
    readonly property int barHeight: 30  // pill height
    readonly property int barVPad: 4   // vertical gap between pill and screen edge (bar = barHeight + barVPad*2)
    readonly property int centerMaxWidth: 400  // center pill width cap
    readonly property int pillHPad: 12  // horizontal padding inside a pill
    readonly property int pillMargin: 8   // horizontal gap between pill and screen edge
    readonly property int iconHitWidth: fontIcon + iconPadH   // icon button hit target width
    readonly property int iconHitHeight: fontIcon + iconPadV  // icon button hit target height
    readonly property int iconPadH: 10  // horizontal padding around icon hit targets
    readonly property int iconPadV: 6   // vertical padding around icon hit targets
    readonly property int trayIconSize: 15  // system tray icon size
    readonly property int workspacePillHeight: 19  // individual workspace pill height
    readonly property int workspacePillHPad: 15  // total horizontal padding inside workspace pill
    readonly property int workspacePillSpacing: 4   // gap between workspace pills
    readonly property int buttonGap: 8  // gap between icon buttons
    readonly property int popupItemHeight: 32  // menu row height in popups
    readonly property int popupSeparatorHeight: 9   // separator row height in popups

    // ── animation ────────────────────────────────────────────────────────────
    readonly property int animFast: 80   // snappy color transitions
    readonly property int animNormal: 120  // workspace / device color transitions
    readonly property int animSlow: 150  // height / layout transitions
}
