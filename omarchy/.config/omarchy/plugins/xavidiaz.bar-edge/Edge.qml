import Quickshell
import Quickshell.Wayland
import QtQuick
import qs.Commons

// A thin line along the bottom edge of the top bar, in the orange of the
// focused window's border (hypr/looknfeel.lua) and the active workspace chip,
// so the bar reads as part of the same frame. The built-in bar has no border
// setting, so this draws its own strip just below it on every monitor.
//
// It sits on the bar's layer, so fullscreen windows still cover it, takes no
// space from windows (the gap under the bar holds it) and lets every click
// through.
Item {
  id: root

  readonly property color lineColor: "#ff9e64"
  // Slightly see-through, so the line edges the bar rather than shouting.
  readonly property real lineOpacity: 0.75
  readonly property int thickness: 2

  Variants {
    model: Quickshell.screens

    PanelWindow {
      required property var modelData
      screen: modelData

      anchors { top: true; left: true; right: true }
      margins.top: Style.bar.sizeHorizontal
      implicitHeight: root.thickness
      color: Qt.rgba(root.lineColor.r, root.lineColor.g, root.lineColor.b, root.lineOpacity)

      // An empty input region: the line is never in the way of a click.
      mask: Region {}

      WlrLayershell.namespace: "xavidiaz-bar-edge"
      WlrLayershell.layer: WlrLayer.Top
      WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
      exclusionMode: ExclusionMode.Ignore
    }
  }
}
