pragma ComponentBehavior: Bound

import qs.components
import qs.lib

import Quickshell
import Quickshell.Services.SystemTray
import QtQuick

Item {
    id: root

    required property SystemTrayItem item
    property var panelWindow

    implicitWidth: hitTarget.width
    implicitHeight: hitTarget.height

    Rectangle {
        id: hitTarget
        width: Theme.iconHitWidth
        height: Theme.iconHitHeight
        radius: Theme.radiusMd

        color: Theme.stateBg(trayMouse.pressed, popup.visible, trayMouse.containsMouse)
        Behavior on color {
            ColorAnimation {
                duration: Theme.animFast
                easing.type: Easing.OutQuad
            }
        }

        Image {
            anchors.centerIn: parent
            width: Theme.trayIconSize
            height: Theme.trayIconSize
            source: root.item.icon
            sourceSize.width: width
            sourceSize.height: height
        }

        MouseArea {
            id: trayMouse
            anchors.fill: parent
            hoverEnabled: true
            acceptedButtons: Qt.LeftButton | Qt.RightButton | Qt.MiddleButton
            cursorShape: Qt.PointingHandCursor
            onClicked: mouse => {
                // onlyMenu items make activate() a no-op, so any click opens the menu
                if (root.item.onlyMenu || (mouse.button === Qt.RightButton && root.item.hasMenu))
                    popup.visible = !popup.visible;
                else if (mouse.button === Qt.MiddleButton)
                    root.item.secondaryActivate();
                else
                    root.item.activate();
            }
        }
    }

    QsMenuOpener {
        id: menuOpener
        menu: root.item.menu    // qmllint disable unresolved-type
    }

    // qmllint disable missing-property
    PopupWindow {
        id: popup
        panelWindow: root.panelWindow
        anchorItem: hitTarget

        contentWidth: 200
        contentHeight: menuCol.implicitHeight + 8

        Column {
            id: menuCol
            anchors {
                top: parent.top
                left: parent.left
                right: parent.right
                topMargin: 4
                bottomMargin: 4
            }

            Repeater {
                // empty while closed so reopening starts with submenus collapsed
                // and their dbus openers released
                model: popup.visible ? menuOpener.children : null

                delegate: TrayMenuEntry {
                    required property var modelData
                    width: menuCol.width
                    entry: modelData
                    onActivated: popup.visible = false
                }
            }
        }
    }
}
