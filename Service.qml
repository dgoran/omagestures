import QtQuick
import Quickshell.Io

Item {
    id: root
    property var manifest
    readonly property string pluginDir: String(manifest && manifest.__sourceDir ? manifest.__sourceDir : "")

    Process { id: applyProcess }
    Process { id: reloadProcess }

    function apply(mode) {
        if (!pluginDir) return
        applyProcess.command = ["python3", pluginDir + "/apply.py", mode, pluginDir]
        applyProcess.running = true
    }

    Connections {
        target: applyProcess
        function onRunningChanged() {
            if (!applyProcess.running) {
                reloadProcess.command = ["hyprctl", "reload"]
                reloadProcess.running = true
            }
        }
    }

    Component.onCompleted: apply("enable")
    Component.onDestruction: apply("disable")
}
