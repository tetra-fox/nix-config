import qs.lib
import QtQuick
import QtQuick.Layouts

// animated expand/collapse container. set label for a clickable toggle header
ColumnLayout {
    id: root

    property bool expanded: false
    property bool loading: false
    property string label: ""
    property string value: ""
    default property alias content: inner.data

    Layout.fillWidth: true
    spacing: 2

    Rectangle {
        Layout.fillWidth: true
        implicitHeight: headerRow.implicitHeight + 14
        radius: Theme.radiusMd
        visible: root.label !== ""
        color: Theme.stateBg(false, false, headerHover.containsMouse)
        Behavior on color {
            ColorAnimation {
                duration: Theme.animFast
            }
        }

        RowLayout {
            id: headerRow
            anchors {
                fill: parent
                leftMargin: 8
                rightMargin: 8
                topMargin: 6
                bottomMargin: 6
            }
            spacing: 8

            SectionLabel {
                text: root.label
            }

            // empty-but-visible fills the slack between label and chevron when value is ""
            Text {
                Layout.fillWidth: true
                text: root.value
                color: Theme.textPrimary
                font.pixelSize: Theme.fontMd
                font.family: Theme.fontFamily
                elide: Text.ElideRight
            }

            Spinner {
                visible: root.loading
            }

            Text {
                text: Icons.expandMore
                color: headerHover.containsMouse ? Theme.textActive : Theme.textLabel
                font.pixelSize: Theme.fontIcon
                font.family: Theme.fontIconFamily
                font.variableAxes: Theme.fontIconAxes
                rotation: root.expanded ? 180 : 0
                Behavior on rotation {
                    NumberAnimation {
                        duration: Theme.animSlow
                        easing.type: Easing.InOutQuad
                    }
                }
                Behavior on color {
                    ColorAnimation {
                        duration: Theme.animFast
                    }
                }
            }
        }

        MouseArea {
            id: headerHover
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: root.expanded = !root.expanded
        }
    }

    Item {
        Layout.fillWidth: true
        Layout.preferredHeight: _height
        clip: true

        property real _height: root.expanded ? inner.implicitHeight : 0
        Behavior on _height {
            NumberAnimation {
                duration: Theme.animSlow
                easing.type: Easing.InOutQuad
            }
        }

        Item {
            id: inner
            anchors {
                top: parent.top
                left: parent.left
                right: parent.right
            }
            implicitHeight: childrenRect.height
        }
    }
}
