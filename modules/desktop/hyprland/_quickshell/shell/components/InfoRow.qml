import qs.lib
import QtQuick
import QtQuick.Layouts

// label + copyable value row for popup detail sections
RowLayout {
    id: root

    property string label
    property alias value: val.text
    property alias elide: val.elide
    property bool disabled: val.text === "-"

    Layout.fillWidth: true

    SectionLabel {
        text: root.label
        Layout.minimumWidth: 64
    }

    CopyableText {
        id: val
        Layout.fillWidth: true
        disabled: root.disabled
    }
}
