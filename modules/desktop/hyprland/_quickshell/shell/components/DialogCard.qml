import qs.lib
import QtQuick
import QtQuick.Layouts

// dialog panel: rounded card whose height follows the content column
Rectangle {
    id: root

    default property alias content: col.data

    width: 300
    height: col.implicitHeight + Theme.pillHPad * 4
    radius: Theme.radiusLg
    color: Theme.panelBg
    border.width: 1
    border.color: Theme.panelBorder
    transformOrigin: Item.Center

    ColumnLayout {
        id: col
        anchors {
            left: parent.left
            right: parent.right
            verticalCenter: parent.verticalCenter
            leftMargin: Theme.pillHPad * 2
            rightMargin: Theme.pillHPad * 2
        }
        spacing: 0
    }
}
