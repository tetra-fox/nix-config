import qs.lib
import QtQuick

// dual-image container that crossfades + slides on source change
Rectangle {
    id: root

    property string source
    property int slideDir: 1 // 1 = forward (slide left), -1 = backward (slide right)
    readonly property bool ready: artA.status === Image.Ready || artB.status === Image.Ready

    color: Theme.withAlpha(Theme.white, 0.06)
    clip: true

    property bool _showingA: true

    Image {
        id: artA
        anchors.fill: parent
        fillMode: Image.PreserveAspectCrop
        smooth: true
        asynchronous: true
        transform: Translate {
            id: slideA
        }
    }

    Image {
        id: artB
        anchors.fill: parent
        fillMode: Image.PreserveAspectCrop
        smooth: true
        asynchronous: true
        opacity: 0
        transform: Translate {
            id: slideB
        }
    }

    ParallelAnimation {
        id: transitionAtoB
        NumberAnimation {
            target: artA
            property: "opacity"
            to: 0
            duration: 400
            easing.type: Easing.OutExpo
        }
        NumberAnimation {
            target: slideA
            property: "x"
            from: 0
            to: -root.slideDir * root.width
            duration: 400
            easing.type: Easing.OutExpo
        }
        NumberAnimation {
            target: artB
            property: "opacity"
            to: 1
            duration: 400
            easing.type: Easing.OutExpo
        }
        NumberAnimation {
            target: slideB
            property: "x"
            from: root.slideDir * root.width
            to: 0
            duration: 400
            easing.type: Easing.OutExpo
        }
    }

    ParallelAnimation {
        id: transitionBtoA
        NumberAnimation {
            target: artB
            property: "opacity"
            to: 0
            duration: 400
            easing.type: Easing.OutExpo
        }
        NumberAnimation {
            target: slideB
            property: "x"
            from: 0
            to: -root.slideDir * root.width
            duration: 400
            easing.type: Easing.OutExpo
        }
        NumberAnimation {
            target: artA
            property: "opacity"
            to: 1
            duration: 400
            easing.type: Easing.OutExpo
        }
        NumberAnimation {
            target: slideA
            property: "x"
            from: root.slideDir * root.width
            to: 0
            duration: 400
            easing.type: Easing.OutExpo
        }
    }

    function _transition() {
        if (_showingA)
            transitionAtoB.restart();
        else
            transitionBtoA.restart();
        _showingA = !_showingA;
    }

    Connections {
        target: artA
        function onStatusChanged() {
            if (!root._showingA && artA.status === Image.Ready)
                root._transition();
        }
    }

    Connections {
        target: artB
        function onStatusChanged() {
            if (root._showingA && artB.status === Image.Ready)
                root._transition();
        }
    }

    onSourceChanged: {
        if (root.source === "")
            return;
        if (String(artA.source) === "" && String(artB.source) === "") {
            artA.source = root.source;
            return;
        }
        if (root._showingA)
            artB.source = root.source;
        else
            artA.source = root.source;
    }
}
