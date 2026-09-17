import QtQuick
import QtQuick.Controls
import Quickshell
import Quickshell.Io
import qs.Commons
import qs.Ui

// The scratchpad's floating note. A KeyboardPanel rather than a plain popup
// because the card has to take keyboard focus to be typed into — that
// component primes WlrKeyboardFocus.Exclusive on open, settles on OnDemand,
// and brings its own outside-click dismissal.
//
// Saving is deliberately dumb: the editor is the source of truth while the
// panel is open, and the file is written on dismissal plus a one-second idle
// debounce. Nothing watches the file, so our own atomic write can't race the
// text out from under the cursor.
Panel {
  id: root
  moduleName: "acooper.scratchpad"
  ipcTarget: "acooper.scratchpad"

  property var anchorItem: null

  // The bar tracks the widget in its slot — BarWidget.qml — not this nested
  // panel, so the popout coordinator has to be handed that identity.
  property var hostWidget: null
  readonly property var barIdentity: hostWidget || root

  readonly property string defaultNotePath: Quickshell.env("HOME") + "/.local/state/omarchy/scratchpad.txt"
  readonly property string notePath: {
    var configured = String(root.setting("notePath", "")).trim()
    if (configured === "") return root.defaultNotePath
    if (configured.indexOf("~/") === 0) return Quickshell.env("HOME") + configured.substring(1)
    return configured
  }

  readonly property color contentForeground: bar ? bar.foreground : Color.popups.text
  readonly property string contentFontFamily: bar ? bar.fontFamily : Style.font.family

  // True between a keystroke and the write that follows it.
  property bool dirty: false
  property bool loaded: false

  function save() {
    if (!root.dirty) return
    saveTimer.stop()
    noteFile.setText(editor.text)
    root.dirty = false
  }

  function open() {
    // Pick up edits made to the file by anything else while we were closed.
    // Safe here and only here: the panel is shut, so there is no cursor to
    // disturb and nothing unsaved to overwrite.
    if (!root.dirty) noteFile.reload()
    root.controller.show()
  }

  function close() {
    root.save()
    root.controller.hide()
  }

  // Covers every dismissal path at once — outside click, Esc, another bar
  // icon stealing the popout, or a shell IPC hide.
  onOpenedChanged: if (!opened) root.save()

  FileView {
    id: noteFile
    path: root.notePath
    atomicWrites: true
    printErrors: false
    onLoaded: {
      if (!root.dirty) editor.text = noteFile.text()
      root.loaded = true
    }
    // No file yet is the normal first run, not an error: start empty and let
    // the first save create it.
    onLoadFailed: root.loaded = true
  }

  Timer {
    id: saveTimer
    interval: 1000
    onTriggered: root.save()
  }

  KeyboardPanel {
    id: panel
    anchorItem: root.anchorItem
    owner: root.barIdentity
    bar: root.bar
    open: root.opened
    focusTarget: editor
    contentWidth: panel.fittedContentWidth(Style.space(root.setting("width", 340)))
    contentHeight: panel.fittedContentHeight(Style.space(root.setting("height", 260)))

    ScrollView {
      anchors.fill: parent
      clip: true

      TextArea {
        id: editor
        wrapMode: TextArea.Wrap
        placeholderText: root.setting("placeholder", "Scratchpad")
        color: root.contentForeground
        placeholderTextColor: Qt.darker(root.contentForeground, 1.6)
        selectionColor: Style.selectionFillFor(root.contentForeground, Color.accent)
        selectedTextColor: root.contentForeground
        font.family: root.contentFontFamily
        font.pixelSize: Style.font.body
        // The card already paints the popup surface and its border.
        background: null
        padding: 0

        onTextChanged: {
          if (!root.loaded) return
          root.dirty = true
          saveTimer.restart()
        }

        Keys.onEscapePressed: function(event) {
          root.close()
          event.accepted = true
        }
      }
    }
  }
}
