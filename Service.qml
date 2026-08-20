import QtQuick
import Quickshell.Io

Item {
    id: root

    // Omarchy injects these into plugin entry points.
    property string omarchyPath: ""
    property var shell
    property var manifest
    property var pluginRegistry

    readonly property string pluginDir: String(manifest && manifest.__sourceDir ? manifest.__sourceDir : "")

    Process {
        id: applyProcess
        onExited: function(exitCode) {
            reloadProcess.command = ["hyprctl", "reload"]
            reloadProcess.running = true
        }
    }

    Process { id: reloadProcess }

    function apply(mode) {
        if (!pluginDir) {
            console.warn("OmaGestures: plugin source directory unavailable")
            return
        }
        applyProcess.command = ["python3", pluginDir + "/apply.py", mode, pluginDir]
        applyProcess.running = true
    }

    Component.onCompleted: {
        console.log("OmaGestures: enabling from " + pluginDir)
        apply("enable")
    }

    Component.onDestruction: apply("disable")
}
