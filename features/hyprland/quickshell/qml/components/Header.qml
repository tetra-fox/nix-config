import QtQuick
import QtQuick.Layouts

// Shared header for popup sections — icon + title + optional subtitle + status badge.
RowLayout {
    id: root

    Theme {
        id: theme
    }

    property string icon
    property color iconColor: theme.textPrimary
    property string title
    property string subtitle: ""

    // StatusBadge props — pass through to the embedded badge
    property bool badgeVisible: false
    property bool badgeActive: false
    property bool badgePulsing: false
    property color badgeColor: badgeActive ? theme.colorGreen : theme.colorRed
    property string badgeText: ""

    Layout.fillWidth: true
    spacing: 10

    Text {
        text: root.icon
        color: root.iconColor
        font.pixelSize: theme.fontIconLg
        font.family: theme.fontIconFamily
        font.variableAxes: theme.fontIconAxes
    }

    ColumnLayout {
        spacing: 1
        Layout.fillWidth: true

        Text {
            text: root.title
            color: theme.textPrimary
            font.pixelSize: theme.fontMd
            font.family: theme.fontFamily
            Layout.fillWidth: true
            elide: Text.ElideRight
        }

        Text {
            visible: root.subtitle !== ""
            text: root.subtitle
            color: theme.textInactive
            font.pixelSize: theme.fontXs
            font.family: theme.fontFamily
        }
    }

    StatusBadge {
        visible: root.badgeVisible
        active: root.badgeActive
        pulsing: root.badgePulsing
        accentColor: root.badgeColor
        text: root.badgeText
    }
}
