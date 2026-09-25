import QtQuick
import Quickshell.Hyprland
import qs.Commons
import qs.Ui

BarWidget {
  id: root
  moduleName: "voyagen.workspaces-dots"

  function workspaceCount() {
    var focused = Hyprland.focusedWorkspace
    var lastId = focused && focused.id > 0 && focused.id <= 10 ? focused.id : 1
    var values = Hyprland.workspaces.values
    for (var i = 0; i < values.length; i++) {
      var id = values[i].id
      if (id > lastId && id <= 10 && values[i].toplevels.values.length > 0) lastId = id
    }
    return lastId
  }

  function focusWorkspace(id) {
    if (!root.bar) return
    root.bar.run("hyprctl dispatch " + Util.shellQuote("hl.dsp.focus({ workspace = \"" + id + "\" })"))
  }

  readonly property real dotSize: Style.spaceReal(8)
  readonly property real pillSize: Style.spaceReal(16)
  readonly property real gapSize: Style.spaceReal(6)
  readonly property real trailingGap: root.vertical ? 0 : Style.spaceReal(1.5)

  implicitWidth: grid.implicitWidth + trailingGap
  implicitHeight: grid.implicitHeight

  Grid {
    id: grid
    anchors.fill: parent
    anchors.rightMargin: root.trailingGap
    columns: root.vertical ? 1 : root.workspaceCount()
    spacing: 0

    Repeater {
      model: root.workspaceCount()

      WidgetButton {
        id: button
        required property int index
        readonly property int workspaceId: index + 1
        property bool ready: false
        readonly property bool focused: Hyprland.focusedWorkspace !== null && Hyprland.focusedWorkspace.id === workspaceId
        readonly property bool expanded: focused && ready
        Component.onCompleted: ready = true

        bar: root.bar
        labelVisible: false
        hasVisualContent: true
        fixedWidth: root.vertical ? root.barSize : (button.expanded ? root.pillSize : root.dotSize) + root.gapSize
        fixedHeight: root.vertical ? (button.expanded ? root.pillSize : root.dotSize) + root.gapSize : root.barSize
        tooltipText: "Workspace " + workspaceId
        onPressed: function(which) {
          if (which === Qt.LeftButton) root.focusWorkspace(workspaceId)
        }

        Behavior on fixedWidth { NumberAnimation { duration: 90; easing.type: Easing.InOutSine } }
        Behavior on fixedHeight { NumberAnimation { duration: 90; easing.type: Easing.InOutSine } }

        Rectangle {
          anchors.centerIn: parent
          width: root.vertical ? root.dotSize : (button.expanded ? root.pillSize : root.dotSize)
          height: root.vertical ? (button.expanded ? root.pillSize : root.dotSize) : root.dotSize
          radius: root.dotSize / 2
          color: button.focused ? Color.accent : (root.bar ? root.bar.barForeground : Color.foreground)
          opacity: button.focused ? 1 : 0.7

          Behavior on width { NumberAnimation { duration: 90; easing.type: Easing.InOutSine } }
          Behavior on height { NumberAnimation { duration: 90; easing.type: Easing.InOutSine } }
          Behavior on color { ColorAnimation { duration: 90 } }
          Behavior on opacity { NumberAnimation { duration: 90 } }
        }
      }
    }
  }
}
