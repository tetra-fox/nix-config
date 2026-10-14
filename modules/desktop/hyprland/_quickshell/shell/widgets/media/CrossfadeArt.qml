import qs.lib
import QtQuick

Rectangle {
    id: root

    property string source
    property int slideDir: 1 // 1 = forward (slide left), -1 = backward (slide right)
    readonly property bool ready: artA.status === Image.Ready || artB.status === Image.Ready

    color: Theme.fillFaint
    clip: true

    property bool _showingA: true
    readonly property int _slideDur: 400

    Image {
        id: artA
        anchors.fill: parent
        fillMode: Image.PreserveAspectCrop
        asynchronous: true
        transform: Translate {
            id: slideA
        }
        onStatusChanged: if (!root._showingA && status === Image.Ready)
            root._transition()
    }

    Image {
        id: artB
        anchors.fill: parent
        fillMode: Image.PreserveAspectCrop
        asynchronous: true
        opacity: 0
        transform: Translate {
            id: slideB
        }
        onStatusChanged: if (root._showingA && status === Image.Ready)
            root._transition()
    }

    // targets assigned in _transition(), bound targets would retarget mid-run when _showingA flips
    ParallelAnimation {
        id: transition
        NumberAnimation {
            id: fadeOut
            property: "opacity"
            to: 0
            duration: root._slideDur
            easing.type: Easing.OutExpo
        }
        NumberAnimation {
            id: slideOut
            property: "x"
            from: 0
            to: -root.slideDir * root.width
            duration: root._slideDur
            easing.type: Easing.OutExpo
        }
        NumberAnimation {
            id: fadeIn
            property: "opacity"
            to: 1
            duration: root._slideDur
            easing.type: Easing.OutExpo
        }
        NumberAnimation {
            id: slideIn
            property: "x"
            from: root.slideDir * root.width
            to: 0
            duration: root._slideDur
            easing.type: Easing.OutExpo
        }
    }

    function _transition() {
        const out = _showingA ? artA : artB;
        const inn = _showingA ? artB : artA;
        fadeOut.target = out;
        slideOut.target = out === artA ? slideA : slideB;
        fadeIn.target = inn;
        slideIn.target = inn === artA ? slideA : slideB;
        transition.restart();
        _showingA = !_showingA;
    }

    onSourceChanged: {
        if (root.source === "")
            return;
        if (String(artA.source) === "" && String(artB.source) === "") {
            artA.source = root.source;
            return;
        }
        const hidden = root._showingA ? artB : artA;
        // the hidden image may already hold this art (x, y, x), then statusChanged never fires
        if (String(hidden.source) === root.source) {
            if (hidden.status === Image.Ready)
                root._transition();
            return;
        }
        hidden.source = root.source;
    }
}
