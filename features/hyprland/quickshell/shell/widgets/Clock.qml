import qs.theme
import QtQuick

Item {
    id: root

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

    Text {
        id: timeTextProp
        anchors.centerIn: parent
        text: Qt.formatDateTime(new Date(), "ddd dd MMM • HH:mm:ss")
        color: Theme.textPrimary
        font.pixelSize: Theme.fontBase
        font.family: Theme.fontFamily
    }
}
