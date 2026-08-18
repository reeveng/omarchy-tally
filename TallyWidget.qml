import QtQuick
import Quickshell.Io
import qs.Ui
import qs.Commons

// The tally light. Three states, all of them colour: dimmed while OBS is
// closed, plain while it is open and idle, lit while a stream is live.
// Clicking it brings OBS up, or starts it.
//
// The state comes from the banners OBS already writes into its own log, so
// there is no websocket, no port and no password anywhere in this.
BarWidget {
  id: root
  moduleName: "jmad.tally"

  // closed | idle | live. Not `state`, which every Item already has and means
  // something else.
  property string streamState: "closed"

  readonly property bool live: streamState === "live"
  readonly property bool running: streamState !== "closed"

  // The script sits next to this file wherever the plugin was cloned to, so
  // it is found by its own path rather than by being on somebody's PATH.
  readonly property string stateCommand:
    String(Qt.resolvedUrl("bin/obs-tally-state")).replace(/^file:\/\//, "")

  readonly property string tooltip: {
    if (live) return "Live"
    if (running) return "OBS is open, not streaming"
    return "OBS is closed"
  }

  function refresh() {
    if (!probe.running) probe.running = true
  }

  Process {
    id: probe
    command: [root.stateCommand]
    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: {
        var value = String(text || "").trim()
        root.streamState = value === "" ? "closed" : value
      }
    }
  }

  Timer {
    interval: Math.max(1000, root.setting("intervalMs", 3000))
    running: true
    repeat: true
    triggeredOnStart: true
    onTriggered: root.refresh()
  }

  implicitWidth: button.implicitWidth
  implicitHeight: button.implicitHeight

  BarIconButton {
    id: button
    anchors.fill: parent
    bar: root.bar
    text: "󰝥"
    active: root.live
    dimmed: !root.running
    tooltipText: root.tooltip
    onPressed: function (b) {
      root.bar.run("omarchy-launch-or-focus obs 'uwsm-app -- obs'")
      wake.restart()
    }
  }

  // A window takes a moment to appear, and the dot should stop being dim as
  // soon as it does rather than at the end of the next poll.
  Timer {
    id: wake
    interval: 2000
    onTriggered: root.refresh()
  }
}
