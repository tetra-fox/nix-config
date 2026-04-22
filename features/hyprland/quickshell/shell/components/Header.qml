import qs.lib
import QtQuick
import QtQuick.Layouts

// section header: icon + title + optional subtitle + status badge
RowLayout {
    id: root

    property string icon
    property color iconColor: Theme.textPrimary
    property string title
    property string subtitle: ""

    property bool badgeVisible: false
    property bool badgeActive: false
    property bool badgePulsing: false
    property color badgeColor: badgeActive ? Theme.colorGreen : Theme.colorRed
    property string badgeText: ""

    Layout.fillWidth: true
    spacing: 10

    Text {
        text: root.icon
        color: root.iconColor
        font.pixelSize: Theme.fontIconLg
        font.family: Theme.fontIconFamily
        font.variableAxes: Theme.fontIconAxes
    }

    ColumnLayout {
        spacing: 1
        Layout.fillWidth: true

        Text {
            text: root.title
            color: Theme.textPrimary
            font.pixelSize: Theme.fontMd
            font.family: Theme.fontFamily
            Layout.fillWidth: true
            elide: Text.ElideRight
        }

        CopyableText {
            visible: root.subtitle !== ""
            text: root.subtitle
            baseColor: Theme.textInactive
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
