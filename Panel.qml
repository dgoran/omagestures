import QtQuick
import QtQuick.Layouts
import Quickshell
import qs.Commons
import qs.Ui

Panel {
  id: root
  moduleName: "io.github.dgoran.omagestures"
  manageIpc: false

  property var anchorItem: null
  property var hostWidget: null

  readonly property color foreground: bar ? bar.foreground : Color.popups.text
  readonly property string fontFamily: bar ? bar.fontFamily : Style.font.family

  // The host strips __sourceDir from third-party manifests, so this file's own
  // location is the reliable way back to the activation script.
  readonly property string pluginDir: {
    var own = String(Qt.resolvedUrl("."))
    if (own.indexOf("file://") === 0) own = own.substring(7)
    return own.replace(/\/+$/, "")
  }

  // shell.json is the display source; activate.sh keeps its own copy so a
  // Hyprland config reload can reinstall the gestures without the shell.
  function flagOn(name) {
    if (!settings || settings[name] === undefined) return true
    var value = settings[name]
    return !(value === false || value === 0 || value === "0")
  }

  readonly property bool snap: flagOn("enabled")
  readonly property bool corners: flagOn("corners")
  readonly property bool tapFloat: flagOn("tapFloat")
  readonly property bool workspaceStep: flagOn("workspaceStep")
  readonly property bool workspaceSwipe: flagOn("workspaceSwipe")
  readonly property bool expose: flagOn("expose")
  readonly property bool anyEnabled: snap || tapFloat || workspaceStep || workspaceSwipe || expose
  readonly property int outerGap: settings && settings.outerGap !== undefined
    ? Math.round(Number(settings.outerGap)) : 5
  readonly property int innerGap: settings && settings.innerGap !== undefined
    ? Math.round(Number(settings.innerGap)) : 10

  function current() {
    return {
      enabled: snap,
      corners: corners,
      tapFloat: tapFloat,
      workspaceStep: workspaceStep,
      workspaceSwipe: workspaceSwipe,
      expose: expose,
      outerGap: outerGap,
      innerGap: innerGap
    }
  }

  function persist(patch) {
    var next = current()
    for (var key in patch) next[key] = patch[key]
    settings = next
    if (hostWidget && "settings" in hostWidget) hostWidget.settings = next
    if (bar && bar.shell && typeof bar.shell.updateEntryInline === "function")
      bar.shell.updateEntryInline(root.moduleName, next)
    Quickshell.execDetached(["bash", pluginDir + "/activate.sh", "apply",
      next.enabled ? "1" : "0", String(next.outerGap), String(next.innerGap),
      next.corners ? "1" : "0", next.tapFloat ? "1" : "0",
      next.workspaceStep ? "1" : "0", next.workspaceSwipe ? "1" : "0",
      next.expose ? "1" : "0"])
  }

  function switchPanel(direction) {
    return bar && typeof bar.switchPanelFrom === "function"
      ? bar.switchPanelFrom(hostWidget || root, direction) : false
  }

  KeyboardPanel {
    id: popout
    anchorItem: root.anchorItem
    owner: root.hostWidget || root
    bar: root.bar
    open: root.opened
    focusTarget: catcher
    contentWidth: fittedContentWidth(Style.space(360))
    contentHeight: fittedContentHeight(body.implicitHeight)

    PanelKeyCatcher {
      id: catcher
      anchors.fill: parent
      onCloseRequested: root.close()
      onTabRequested: direction => root.switchPanel(direction)

      Flickable {
        id: scroller
        anchors.fill: parent
        contentWidth: width
        contentHeight: body.implicitHeight
        clip: true
        boundsBehavior: Flickable.StopAtBounds
        flickableDirection: Flickable.VerticalFlick
        interactive: contentHeight > height

        Column {
          id: body
          width: scroller.width
          spacing: Style.spacing.panelGap

          Text {
            text: "OmaGestures"
            color: root.foreground
            font.family: root.fontFamily
            font.pixelSize: Style.font.title
            font.bold: true
          }

          Text {
            text: "Three fingers"
            color: root.foreground
            font.family: root.fontFamily
            font.pixelSize: Style.font.subtitle
            font.bold: true
          }

          Toggle {
            width: parent.width
            label: "Half snap"
            description: "Left or right snaps the active floating window to that half."
            checked: root.snap
            foreground: root.foreground
            fontFamily: root.fontFamily
            onClicked: root.persist({ enabled: !root.snap })
          }

          Toggle {
            width: parent.width
            label: "Corner follow-up"
            description: "Up or down within 30 seconds moves that window to the matching corner."
            checked: root.corners
            enabled: root.snap
            foreground: root.foreground
            fontFamily: root.fontFamily
            onClicked: root.persist({ corners: !root.corners })
          }

          RowLayout {
            width: parent.width
            enabled: root.snap
            Text {
              text: "Screen edge gap"
              color: root.foreground
              font.family: root.fontFamily
              font.pixelSize: Style.font.bodySmall
              font.bold: true
              Layout.fillWidth: true
            }
            Text {
              text: root.outerGap + " px"
              color: root.foreground
              font.family: root.fontFamily
              font.pixelSize: Style.font.caption
            }
          }

          PanelSlider {
            width: parent.width
            bar: root.bar
            minimum: 0
            maximum: 40
            step: 1
            integer: true
            enabled: root.snap
            value: root.outerGap
            onMoved: function(value) {
              root.persist({ outerGap: Math.round(value) })
            }
          }

          RowLayout {
            width: parent.width
            enabled: root.snap
            Text {
              text: "Gap between halves"
              color: root.foreground
              font.family: root.fontFamily
              font.pixelSize: Style.font.bodySmall
              font.bold: true
              Layout.fillWidth: true
            }
            Text {
              text: root.innerGap + " px"
              color: root.foreground
              font.family: root.fontFamily
              font.pixelSize: Style.font.caption
            }
          }

          PanelSlider {
            width: parent.width
            bar: root.bar
            minimum: 0
            maximum: 40
            step: 1
            integer: true
            enabled: root.snap
            value: root.innerGap
            onMoved: function(value) {
              root.persist({ innerGap: Math.round(value) })
            }
          }

          Toggle {
            width: parent.width
            label: "Tap to float"
            description: "A three-finger tap toggles the active window between floating and tiling."
            checked: root.tapFloat
            foreground: root.foreground
            fontFamily: root.fontFamily
            onClicked: root.persist({ tapFloat: !root.tapFloat })
          }

          PanelSeparator { width: parent.width; foreground: root.foreground }

          Text {
            text: "Four fingers"
            color: root.foreground
            font.family: root.fontFamily
            font.pixelSize: Style.font.subtitle
            font.bold: true
          }

          Toggle {
            width: parent.width
            label: "Step workspaces"
            description: "Left and right move between workspaces 1 through 10."
            checked: root.workspaceStep
            foreground: root.foreground
            fontFamily: root.fontFamily
            onClicked: root.persist({ workspaceStep: !root.workspaceStep })
          }

          Toggle {
            width: parent.width
            label: "Super swipe"
            description: "Super plus a four-finger swipe changes workspace."
            checked: root.workspaceSwipe
            foreground: root.foreground
            fontFamily: root.fontFamily
            onClicked: root.persist({ workspaceSwipe: !root.workspaceSwipe })
          }

          Toggle {
            width: parent.width
            label: "Exposé"
            description: "Super plus four fingers up toggles Exposé."
            checked: root.expose
            foreground: root.foreground
            fontFamily: root.fontFamily
            onClicked: root.persist({ expose: !root.expose })
          }

          Button {
            width: parent.width
            text: "Reset"
            bordered: true
            foreground: root.foreground
            fontFamily: root.fontFamily
            onClicked: root.persist({
              enabled: true,
              corners: true,
              tapFloat: true,
              workspaceStep: true,
              workspaceSwipe: true,
              expose: true,
              outerGap: 5,
              innerGap: 10
            })
          }
        }
      }
    }
  }
}
