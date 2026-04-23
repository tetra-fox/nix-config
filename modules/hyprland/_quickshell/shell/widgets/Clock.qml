import qs.notifications
import qs.lib
import QtQuick

Item {
    id: root

    required property var panelWindow
    required property var notifList

    implicitWidth: timeTextProp.implicitWidth + Theme.iconPadH
    implicitHeight: timeTextProp.implicitHeight + Theme.iconPadV

    Timer {
        interval: 1000
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: root.tick()
    }

    function tick() {
        timeTextProp.text = Qt.formatDateTime(new Date(), "ddd dd MMM • HH:mm:ss");
    }

    Rectangle {
        id: bg
        anchors.fill: parent
        radius: Theme.radiusMd
        color: {
            if (area.pressed)
                return Theme.pressedBg;
            if (popup.visible)
                return Theme.openBg;
            if (area.containsMouse)
                return Theme.hoverBg;
            return Theme.withAlpha(Theme.hoverBg, 0);
        }
        Behavior on color {
            ColorAnimation {
                duration: Theme.animFast
                easing.type: Easing.OutQuad
            }
        }
    }

    Text {
        id: timeTextProp
        anchors.centerIn: parent
        text: Qt.formatDateTime(new Date(), "ddd dd MMM • HH:mm:ss")
        color: Theme.textPrimary
        font.pixelSize: Theme.fontBase
        font.family: Theme.fontFamily
    }

    MouseArea {
        id: area
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: popup.visible = !popup.visible
    }

    NotificationCenter {
        id: popup
        anchorItem: root
        panelWindow: root.panelWindow
        notifList: root.notifList
    }
}
