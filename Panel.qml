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
  readonly property bool gesturesEnabled: settings && settings.enabled !== undefined
    ? settings.enabled !== false : true
  readonly property int outerGap: settings && settings.outerGap !== undefined
    ? Math.round(Number(settings.outerGap)) : 5
  readonly property int innerGap: settings && settings.innerGap !== undefined
    ? Math.round(Number(settings.innerGap)) : 10

  function persist(enabled, outer, inner) {
    var next = { enabled: enabled, outerGap: outer, innerGap: inner }
    settings = next
    if (hostWidget && "settings" in hostWidget) hostWidget.settings = next
    if (bar && bar.shell && typeof bar.shell.updateEntryInline === "function")
      bar.shell.updateEntryInline(root.moduleName, next)
    Quickshell.execDetached(["bash", pluginDir + "/activate.sh", "apply",
      enabled ? "1" : "0", String(outer), String(inner)])
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
    contentWidth: fittedContentWidth(Style.space(320))
    contentHeight: fittedContentHeight(body.implicitHeight)

    PanelKeyCatcher {
      id: catcher
      anchors.fill: parent
      onCloseRequested: root.close()
      onTabRequested: direction => root.switchPanel(direction)

      Column {
        id: body
        width: parent.width
        spacing: Style.spacing.panelGap

        Text {
          text: "OmaGestures"
          color: root.foreground
          font.family: root.fontFamily
          font.pixelSize: Style.font.title
          font.bold: true
        }

        Toggle {
          width: parent.width
          label: "Gestures"
          description: root.gesturesEnabled ? "Three-finger snapping is on"
                                            : "Three-finger snapping is off"
          checked: root.gesturesEnabled
          foreground: root.foreground
          fontFamily: root.fontFamily
          onClicked: root.persist(!root.gesturesEnabled, root.outerGap, root.innerGap)
        }

        PanelSeparator { width: parent.width; foreground: root.foreground }

        RowLayout {
          width: parent.width
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
          enabled: root.gesturesEnabled
          value: root.outerGap
          onMoved: function(value) {
            root.persist(root.gesturesEnabled, Math.round(value), root.innerGap)
          }
        }

        RowLayout {
          width: parent.width
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
          enabled: root.gesturesEnabled
          value: root.innerGap
          onMoved: function(value) {
            root.persist(root.gesturesEnabled, root.outerGap, Math.round(value))
          }
        }

        PanelSeparator { width: parent.width; foreground: root.foreground }

        Text {
          width: parent.width
          wrapMode: Text.WordWrap
          text: "Three fingers left or right snaps the active floating window "
              + "to that half. Up or down within 30 seconds moves it to the "
              + "matching corner. Tiled and fullscreen windows are left alone."
          color: Qt.darker(root.foreground, 1.5)
          font.family: root.fontFamily
          font.pixelSize: Style.font.caption
        }

        Button {
          width: parent.width
          text: "Reset gaps"
          bordered: true
          foreground: root.foreground
          fontFamily: root.fontFamily
          enabled: root.gesturesEnabled
          onClicked: root.persist(root.gesturesEnabled, 5, 10)
        }
      }
    }
  }
}
