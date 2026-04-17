import Quickshell
import Quickshell.Hyprland
import Quickshell.Wayland
import QtQuick
import QtQuick.Layouts

PanelWindow {
    id: root

    Theme { id: theme }

    anchors {
        top: true
        left: true
        right: true
    }

    implicitHeight: 38
    color: "transparent"

    WlrLayershell.namespace: "quickshell-bar"

    readonly property var monitor: Hyprland.monitorFor(root.screen)

    Item {
        anchors.fill: parent

        opacity: Hyprland.focusedWorkspace?.monitor === root.monitor ? 1.0 : 0.3
        Behavior on opacity { NumberAnimation { duration: theme.animSlow; easing.type: Easing.InOutQuad } }

        // ── Left pill — workspaces ───────────────────────────────────────────
        Rectangle {
            anchors {
                left: parent.left
                verticalCenter: parent.verticalCenter
                leftMargin: theme.pillMargin
            }
            height: theme.barHeight
            implicitWidth: leftRow.implicitWidth + theme.pillHPad * 2
            radius: theme.radiusLg
            color: theme.panelBg
            border.width: 1
            border.color: theme.panelBorder

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

        // ── Center pill — active window ──────────────────────────────────────
        Rectangle {
            anchors {
                horizontalCenter: parent.horizontalCenter
                verticalCenter: parent.verticalCenter
            }
            height: theme.barHeight
            width: Math.min(centerContent.implicitWidth + theme.pillHPad * 2, theme.centerMaxWidth)
            radius: theme.radiusLg
            color: theme.panelBg
            border.width: 1
            border.color: theme.panelBorder
            visible: centerContent.title.length > 0

            ActiveWindow {
                id: centerContent
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

        // ── Right pill — tray + volume + clock ───────────────────────────────
        Rectangle {
            anchors {
                right: parent.right
                verticalCenter: parent.verticalCenter
                rightMargin: theme.pillMargin
            }
            height: theme.barHeight
            implicitWidth: rightRow.implicitWidth + theme.pillHPad * 2
            radius: theme.radiusLg
            color: theme.panelBg
            border.width: 1
            border.color: theme.panelBorder

            RowLayout {
                id: rightRow
                anchors {
                    fill: parent
                    leftMargin: theme.pillHPad
                    rightMargin: theme.pillHPad
                }
                spacing: 12

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
