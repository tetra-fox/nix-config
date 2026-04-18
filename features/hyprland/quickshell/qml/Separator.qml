import QtQuick
import QtQuick.Layouts

// horizontal rule for use inside ColumnLayout
Rectangle {
    Theme { id: theme }
    Layout.fillWidth: true
    height: 1
    color:  theme.separatorBg
}
