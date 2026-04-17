import QtQuick

// design tokens. do Theme { id: theme } wherever you need them
QtObject {

    // ── typography ───────────────────────────────────────────────────────────
    readonly property string fontFamily: "monospace"
    readonly property int fontXs:     10  // chevrons, tiny indicators
    readonly property int fontSm:     11  // section labels
    readonly property int fontMd:     12  // body text, workspace numbers
    readonly property int fontBase:   13  // clock
    readonly property int fontIcon:   15  // bar-level icons
    readonly property int fontIconLg: 16  // popup-level icons

    // ── colours ───────────────────────────────────────────────────────────────
    // Text
    readonly property color textActive:    "#ffffff"    // focused / selected
    readonly property color textPrimary:   "#dddddd"    // primary text
    readonly property color textSecondary: "#cfcfcf"    // secondary / percentages
    readonly property color textLabel:     "#bdbdbd"    // section labels, headers
    readonly property color textInactive:  "#aaaaaa"    // inactive / dim

    // Surfaces
    readonly property color panelBg:      "#e0161616"  // pill / popup background
    readonly property color panelBorder:  "#3a3a3a"    // pill border
    readonly property color hoverBg:      "#2a2a2a"    // hover state
    readonly property color pressedBg:    "#1c1c1c"    // pressed state
    readonly property color openBg:       "#2c2630"    // popup-open state (accent tint)
    readonly property color inactiveBg:   "#2e2e2e"    // inactive workspace pill, dividers
    readonly property color separatorBg:  "#252525"    // device-list separators

    // Semantic
    readonly property color accent: '#ff1ba4'  // focused workspace, active device
    readonly property color danger: "#c9626b"  // muted audio, urgent workspace

    // ── shape ────────────────────────────────────────────────────────────────
    readonly property int radiusSm: 3  // workspace pill
    readonly property int radiusMd: 4  // button hit targets
    readonly property int radiusLg: 6  // panels and popups

    // ── layout ───────────────────────────────────────────────────────────────
    readonly property int barHeight:    30  // pill height
    readonly property int centerMaxWidth: 400  // center pill width cap
    readonly property int pillHPad:     12  // horizontal padding inside a pill
    readonly property int pillMargin:   8   // gap between pill and screen edge
    readonly property int iconPadH:     10  // horizontal padding around icon hit targets
    readonly property int iconPadV:     6   // vertical padding around icon hit targets
    readonly property int trayIconSize: 15  // system tray icon size

    // ── animation ────────────────────────────────────────────────────────────
    readonly property int animFast:   80   // snappy colour transitions
    readonly property int animNormal: 120  // workspace / device colour transitions
    readonly property int animSlow:   150  // height / layout transitions
}
