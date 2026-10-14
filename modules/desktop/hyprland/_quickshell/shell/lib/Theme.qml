pragma Singleton

import QtQuick

QtObject {
    readonly property string fontFamily: "monospace"
    readonly property string fontIconFamily: "Material Symbols Rounded Filled"
    // FILL=1 is baked into the font (quickshell/default.nix)
    readonly property var fontIconAxes: ({
            "wght": 600,
            "GRAD": 0,
            "opsz": 20
        })
    readonly property int fontXs: 10
    readonly property int fontSm: 11
    readonly property int fontMd: 12
    readonly property int fontBase: 13
    readonly property int fontIcon: 16
    readonly property int fontIconLg: 18

    readonly property color textActive: "#ffffff"
    readonly property color textPrimary: "#dddddd"
    readonly property color textSecondary: "#cfcfcf"
    readonly property color textLabel: "#bdbdbd"
    readonly property color textInactive: "#aaaaaa"

    readonly property color panelBg: "#ce161616"
    readonly property color panelBorder: "#26ffffff"
    readonly property color hoverBg: "#26ffffff"
    readonly property color pressedBg: "#40ffffff"
    readonly property color openBg: withAlpha(accent, 0.15)
    readonly property color inactiveBg: "#e02e2e2e"
    readonly property color separatorBg: "#3a3a3a"
    // fades to hoverBg without passing through grey like "transparent" (black) would
    readonly property color idleBg: withAlpha(hoverBg, 0)
    readonly property color fillFaint: withAlpha(white, 0.06)

    function withAlpha(color, alpha) {
        return Qt.rgba(color.r, color.g, color.b, alpha);
    }

    function stateBg(pressed, open, hovered, idle) {
        if (pressed)
            return pressedBg;
        if (open)
            return openBg;
        if (hovered)
            return hoverBg;
        return idle === undefined ? idleBg : idle;
    }
    readonly property color black: "#000000"
    readonly property color white: "#ffffff"

    readonly property color colorPink: "#ff34a8"
    readonly property color colorPurple: "#b06bff"
    readonly property color colorBlue: "#4facf7"
    readonly property color colorGreen: "#3dc97a"
    readonly property color colorYellow: "#f0b429"
    readonly property color colorRed: "#f05268"

    readonly property color accent: colorPink
    readonly property color danger: colorRed

    readonly property int radiusSm: 3
    readonly property int radiusMd: 4
    readonly property int radiusLg: 6

    readonly property bool activateWindows: true

    readonly property real barInactiveOpacity: 0.3
    readonly property int barHeight: 30
    readonly property int barVPad: 4
    readonly property int centerMaxWidth: 400
    readonly property int pillHPad: 12
    readonly property int pillMargin: 8
    readonly property int iconHitWidth: fontIcon + iconPadH
    readonly property int iconHitHeight: fontIcon + iconPadV
    readonly property int iconPadH: 10
    readonly property int iconPadV: 6
    readonly property int trayIconSize: 15
    readonly property int workspacePillHeight: 19
    readonly property int workspacePillHPad: 15
    readonly property int workspacePillSpacing: 4
    readonly property int buttonGap: 8
    readonly property int popupItemHeight: 32
    readonly property int popupSeparatorHeight: 9
    readonly property int popupWidth: 320

    readonly property int animFast: 80
    readonly property int animNormal: 120
    readonly property int animSlow: 150
    // separate from animSlow so sliders/dialogs can be retuned on their own
    readonly property int animSettle: 180
    // per spinner revolution
    readonly property int animSpin: 900

    readonly property int animPopupIn: 280
    readonly property int animPopupSlide: 200
    readonly property real popupOpenScale: 0.82
    readonly property int popupSlideOffset: 16

    readonly property int animDialogIn: 260
    readonly property real dialogOpenScale: 0.88
}
