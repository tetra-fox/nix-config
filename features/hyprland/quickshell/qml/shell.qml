import Quickshell

// one bar per screen
ShellRoot {
    Variants {
        model: Quickshell.screens

        Bar {
            property var modelData
            screen: modelData
        }
    }
}
