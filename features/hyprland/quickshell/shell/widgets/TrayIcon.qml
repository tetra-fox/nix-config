pragma ComponentBehavior: Bound

import qs.components

import Quickshell
import Quickshell.Services.SystemTray
import QtQuick

// single tray icon - left-click activates, right-click opens context menu
Item {
    id: root

    Theme {
        id: theme
    }

    required property SystemTrayItem item
    property var panelWindow

    implicitWidth: hitTarget.width
    implicitHeight: hitTarget.height

    Rectangle {
        id: hitTarget
        width: theme.trayIconSize + theme.iconPadH
        height: theme.trayIconSize + theme.iconPadV
        radius: theme.radiusMd

        color: {
            if (trayMouse.pressed)
                return theme.pressedBg;
            if (popup.visible)
                return theme.openBg;
            if (trayMouse.containsMouse)
                return theme.hoverBg;
            return "transparent";
        }
        Behavior on color {
            ColorAnimation {
                duration: theme.animFast
                easing.type: Easing.OutQuad
            }
        }

        Image {
            anchors.centerIn: parent
            width: theme.trayIconSize
            height: theme.trayIconSize
            source: root.item.icon
            sourceSize.width: width
            sourceSize.height: height
            smooth: true
        }

        MouseArea {
            id: trayMouse
            anchors.fill: parent
            hoverEnabled: true
            acceptedButtons: Qt.LeftButton | Qt.RightButton
            cursorShape: Qt.PointingHandCursor
            onClicked: mouse => {
                if (mouse.button === Qt.RightButton && root.item.hasMenu)
                    popup.visible = !popup.visible;
                else
                    root.item.activate();
            }
        }
    }

    QsMenuOpener {
        id: menuOpener
        menu: root.item.menu    // qmllint disable unresolved-type
    }

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
                model: menuOpener.children

                delegate: MenuItem {
                    id: menuItem
                    required property var modelData
                    width: menuCol.width
                    text: menuItem.modelData.text ?? ""
                    enabled: menuItem.modelData.enabled ?? true
                    isSeparator: menuItem.modelData.isSeparator
                    onClicked: {
                        menuItem.modelData.triggered();
                        popup.visible = false;
                    }
                }
            }
        }
    }
}
