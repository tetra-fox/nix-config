import Quickshell
import Quickshell.Hyprland
import Quickshell.Wayland
import QtQuick
import QtQuick.Layouts

PanelWindow { // qmllint disable uncreatable-type
    id: root

    Theme {
        id: theme
    }

    anchors {
        top: true
        left: true
        right: true
    }
    implicitHeight: theme.barHeight + theme.barVPad * 2
    color: "transparent"

    WlrLayershell.namespace: "quickshell-bar"

    readonly property var monitor: Hyprland.monitorFor(root.screen)

    Item {
        anchors.fill: parent

        opacity: Hyprland.focusedWorkspace?.monitor === root.monitor ? 1.0 : 0.3
        Behavior on opacity {
            NumberAnimation {
                duration: theme.animSlow
                easing.type: Easing.InOutQuad
            }
        }

        // left - workspaces
        Pill {
            anchors {
                left: parent.left
                verticalCenter: parent.verticalCenter
                leftMargin: theme.pillMargin
            }
            implicitWidth: leftRow.implicitWidth + theme.pillHPad * 2

            RowLayout {
                id: leftRow
                anchors {
                    fill: parent
                    leftMargin: theme.pillHPad
                    rightMargin: theme.pillHPad
                }
                spacing: 6
                Workspaces {
                    screen: root.screen
                }
            }
        }

        // center - active window
        Pill {
            anchors {
                horizontalCenter: parent.horizontalCenter
                verticalCenter: parent.verticalCenter
            }
            width: Math.min(activeWin.implicitWidth + theme.pillHPad * 2, theme.centerMaxWidth)
            visible: activeWin.title.length > 0

            ActiveWindow {
                id: activeWin
                anchors {
                    verticalCenter: parent.verticalCenter
                    left: parent.left
                    right: parent.right
                    leftMargin: theme.pillHPad
                    rightMargin: theme.pillHPad
                }
                screen: root.screen
            }
        }

        // right - tray + controls + clock
        Pill {
            anchors {
                right: parent.right
                verticalCenter: parent.verticalCenter
                rightMargin: theme.pillMargin
            }
            implicitWidth: rightRow.implicitWidth + theme.pillHPad * 2

            RowLayout {
                id: rightRow
                anchors {
                    fill: parent
                    leftMargin: theme.pillHPad
                    rightMargin: theme.pillHPad
                }
                spacing: theme.barSectionSpacing

                Tray {
                    panelWindow: root
                }
                Network {
                    panelWindow: root
                }
                Bluetooth {}
                Volume {
                    panelWindow: root
                }
                Clock {}
            }
        }
    }
}
