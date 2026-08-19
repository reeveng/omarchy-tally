import QtQuick
import Quickshell
import Quickshell.Io

// What happens around a stream rather than in the bar: while OBS is live the
// desk is put away, and it comes back out when the stream ends. Notifications
// stay off the screen, the idle lock leaves it alone, links open in a browser
// that knows nothing about you, and the clipboard history, the recent files
// and the unread notifications are out of reach of a keystroke.
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
    Quickshell.execDetached(["notify-send", "-u", "low", "󰝥  " + title, body])
  }

  // The desktop entry links are sent to while live. Empty leaves them where
  // they already go.
  readonly property string browser: String(setting("streamBrowser", ""))

  // A desktop entry id makes a poor thing to read out, so it is read out
  // without the part every one of them ends in.
  readonly property string browserName: browser.replace(/\.desktop$/, "")

  function clauses() {
    var said = []
    if (setting("quiet", true)) said.push("notifications are silenced")
    if (setting("stayAwake", true)) said.push("the screen will not lock")
    if (browser !== "") said.push("links open in " + browserName)
    if (setting("hideClipboard", true)) said.push("the clipboard history is empty")
    if (setting("hideRecents", true) || setting("hideNotifications", true))
      said.push("so is what a keystroke opens")
    return said
  }

  function sentence(said) {
    if (said.length === 0) return "Nothing is being held"
    if (said.length === 1) return said[0]
    return said.slice(0, -1).join(", ") + " and " + said[said.length - 1]
  }

  function hold() {
    if (holding) return
    holding = true

    announce("Live", sentence(clauses()))

    var command = [bin + "obs-tally-hold", "hold"]
    if (browser !== "") command.push("--browser", browser)
    if (!setting("quiet", true)) command.push("--no-dnd")
    if (!setting("stayAwake", true)) command.push("--no-awake")
    if (!setting("hideClipboard", true)) command.push("--no-clipboard")
    if (!setting("hideRecents", true)) command.push("--no-recents")
    if (!setting("hideNotifications", true)) command.push("--no-notifications")
    Quickshell.execDetached(command)
  }

  function release() {
    if (!holding) return
    holding = false

    Quickshell.execDetached([bin + "obs-tally-hold", "release"])
    ended.restart()
  }

  onLiveChanged: live ? hold() : release()

  // A shell that is quit or reloaded mid-stream would otherwise leave a desk
  // that never speaks again.
  Component.onDestruction: if (holding) Quickshell.execDetached([bin + "obs-tally-hold", "release"])

  // The message saying notifications are back has to arrive after they are, or
  // do not disturb eats the one notification that is about itself.
  Timer {
    id: ended
    interval: 500
    onTriggered: root.announce("Stream ended", "The desk is back the way you left it")
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
