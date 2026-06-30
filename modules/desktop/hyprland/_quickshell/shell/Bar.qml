import qs.components
import qs.widgets
import qs.lib
import Quickshell
import Quickshell.Hyprland
import Quickshell.Wayland
import QtQuick
import QtQuick.Layouts

PanelWindow { // qmllint disable uncreatable-type
    id: root

    required property var lockSession
    required property var notifList

    anchors {
        top: true
        left: true
        right: true
    }
    implicitHeight: Theme.barHeight + Theme.barVPad * 2
    color: "transparent"

    WlrLayershell.namespace: "quickshell-bar"

    readonly property var monitor: Hyprland.monitorFor(root.screen)

    Item {
        anchors.fill: parent

        opacity: Hyprland.focusedMonitor === root.monitor ? 1.0 : Theme.barInactiveOpacity
        Behavior on opacity {
            NumberAnimation {
                duration: Theme.animSlow
                easing.type: Easing.InOutQuad
            }
        }

        // left - workspaces
        Pill {
            anchors {
                left: parent.left
                verticalCenter: parent.verticalCenter
                leftMargin: Theme.pillMargin
            }
            implicitWidth: leftRow.implicitWidth + Theme.pillHPad * 2

            RowLayout {
                id: leftRow
                anchors {
                    fill: parent
                    leftMargin: Theme.pillHPad
                    rightMargin: Theme.pillHPad
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
            width: Math.min(activeWin.implicitWidth + Theme.pillHPad * 2, Theme.centerMaxWidth)
            visible: activeWin.title.length > 0

            ActiveWindow {
                id: activeWin
                anchors {
                    verticalCenter: parent.verticalCenter
                    left: parent.left
                    right: parent.right
                    leftMargin: Theme.pillHPad
                    rightMargin: Theme.pillHPad
                }
                screen: root.screen
            }
        }

        // right - tray + controls + clock
        Pill {
            anchors {
                right: parent.right
                verticalCenter: parent.verticalCenter
                rightMargin: Theme.pillMargin
            }
            implicitWidth: rightRow.implicitWidth + Theme.pillHPad * 2

            RowLayout {
                id: rightRow
                anchors {
                    fill: parent
                    leftMargin: Theme.pillHPad
                    rightMargin: Theme.pillHPad
                }
                spacing: Theme.buttonGap

                Tray {
                    panelWindow: root
                }
                MediaPlayer {
                    panelWindow: root
                }
                Bluetooth {
                    panelWindow: root
                }
                Network {
                    panelWindow: root
                }
                Volume {
                    panelWindow: root
                }
                Clock {
                    panelWindow: root
                    notifList: root.notifList
                }
                SystemMenu {
                    panelWindow: root
                    lockSession: root.lockSession
                }
            }
        }
    }
}
