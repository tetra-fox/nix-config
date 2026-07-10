import qs.lib
import QtQuick
import QtQuick.Layouts

// bar widget scaffold: icon button + anchored popup with a content column.
// declared children land in the popup column; left click toggles the popup,
// right click only fires rightClicked
Item {
    id: root

    property var panelWindow

    property alias icon: btn.icon
    property alias iconColor: btn.iconColor
    property alias popupVisible: popup.visible
    property alias contentWidth: popup.contentWidth
    property alias animateSize: popup.animateSize
    property alias spacing: col.spacing
    default property alias content: col.data

    signal rightClicked

    implicitWidth: btn.implicitWidth
    implicitHeight: btn.implicitHeight

    IconButton {
        id: btn
        isOpen: popup.visible
        onClicked: mouse => {
            if (mouse.button === Qt.RightButton)
                root.rightClicked();
            else
                popup.visible = !popup.visible;
        }
    }

    PopupWindow {
        id: popup
        panelWindow: root.panelWindow
        anchorItem: btn

        contentWidth: Theme.popupWidth
        contentHeight: col.implicitHeight + Theme.pillHPad * 2

        ColumnLayout {
            id: col
            anchors {
                top: parent.top
                left: parent.left
                right: parent.right
                margins: Theme.pillHPad
            }
            spacing: 10
        }
    }
}
