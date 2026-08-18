import QtQuick
import Quickshell
import Quickshell.Io

// What happens around a stream rather than in the bar: while OBS is live,
// notifications stay off the screen and the idle lock leaves it alone, and
// both go back to whatever they were when the stream ends.
//
// It is the same question the widget asks, asked separately, because a service
// and a bar widget are two components with no way to hold one answer between
// them. Asking twice costs a process every few seconds and keeps either one
// working when the other is not installed.
Item {
  id: root

  // Injected by omarchy-shell.
  property var shell: null
  property var manifest: null

  // closed | idle | live. Not `state`, which every Item already has and means
  // something else.
  property string streamState: "closed"
  readonly property bool live: streamState === "live"

  // Whether this service is the one holding the desk still. The script keeps
  // the detail of what it changed; this only remembers that it was asked.
  property bool holding: false

  readonly property string bin:
    String(Qt.resolvedUrl("bin/")).replace(/^file:\/\//, "")

  // Settings live on the plugin's own entry in shell.json, whether that entry
  // is the bar widget's or a line in plugins[], so one place configures both
  // halves of the plugin.
  function setting(name, fallback) {
    var config = shell ? shell.shellConfig : null
    var entry = config ? entryFor(config) : null
    var value = entry ? entry[name] : undefined
    return value === undefined || value === null ? fallback : value
  }

  function entryFor(config) {
    var lists = []
    if (config.bar && config.bar.layout) {
      lists.push(config.bar.layout.left, config.bar.layout.center, config.bar.layout.right)
    }
    lists.push(config.plugins)

    for (var i = 0; i < lists.length; i++) {
      var list = lists[i]
      if (!Array.isArray(list)) continue
      for (var j = 0; j < list.length; j++) {
        var entry = list[j]
        if (entry && String(entry.id || "").split("#")[0] === "jmad.tally") return entry
      }
    }
    return null
  }

  function announce(title, body) {
    if (!setting("announce", true)) return
    Quickshell.execDetached(["notify-send", "-u", "low", "󰑋  " + title, body])
  }

  function hold() {
    if (holding) return
    holding = true

    announce("Live", "Notifications are silenced and the screen will not lock")

    var command = [bin + "obs-tally-quiet", "hold"]
    if (!setting("quiet", true)) command.push("--no-dnd")
    if (!setting("stayAwake", true)) command.push("--no-awake")
    Quickshell.execDetached(command)
  }

  function release() {
    if (!holding) return
    holding = false

    Quickshell.execDetached([bin + "obs-tally-quiet", "release"])
    ended.restart()
  }

  onLiveChanged: live ? hold() : release()

  // A shell that is quit or reloaded mid-stream would otherwise leave a desk
  // that never speaks again.
  Component.onDestruction: if (holding) Quickshell.execDetached([bin + "obs-tally-quiet", "release"])

  // The message saying notifications are back has to arrive after they are, or
  // do not disturb eats the one notification that is about itself.
  Timer {
    id: ended
    interval: 500
    onTriggered: root.announce("Stream ended", "Notifications and the idle lock are back")
  }

  Process {
    id: probe
    command: [root.bin + "obs-tally-state"]
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
    onTriggered: if (!probe.running) probe.running = true
  }
}
