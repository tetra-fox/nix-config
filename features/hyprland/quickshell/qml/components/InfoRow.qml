import QtQuick
import QtQuick.Layouts

// label + copyable value row for popup detail sections
RowLayout {
    id: root

    Theme {
        id: theme
    }

    property string label
    property alias value: val.text
    property alias elide: val.elide
    property bool disabled: val.text === "-"

    Layout.fillWidth: true

    Text {
        text: root.label
        color: theme.textLabel
        font.pixelSize: theme.fontSm
        font.family: theme.fontFamily
        Layout.minimumWidth: 64
    }

    CopyableText {
        id: val
        Layout.fillWidth: true
        disabled: root.disabled
    }
}
