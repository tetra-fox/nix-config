import QtQuick

// bar pill - shared visual properties; size and anchors set at usage site
Rectangle {
    Theme { id: theme }
    height:       theme.barHeight
    radius:       theme.radiusLg
    color:        theme.panelBg
    border.width: 1
    border.color: theme.panelBorder
}
