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
//
// Right-clicking the bar icon swaps the note for a size form. It shares the
// one card rather than opening a second popup, so the panel you are resizing
// is the panel you are looking at — the numbers take effect as you type them.
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

  // ---- Note state. True between a keystroke and the write that follows it.
  property bool dirty: false
  property bool loaded: false


  // ---- Size state. The saved pair is what shell.json holds; the pending pair
  //      is what the fields currently say. The card follows whichever is live,
  //      so a half-typed number is still a visible panel rather than a blank.
  readonly property int minWidth: 200
  readonly property int maxWidth: 1200
  readonly property int minHeight: 120
  readonly property int maxHeight: 1000

  // Run through clamped() rather than read straight: `omarchy bar set` writes
  // a JSON string unless it is given --json, so a hand-set width can arrive as
  // "420" rather than 420, and a nonsense value should not collapse the card.
  readonly property int savedWidth: root.clamped(root.setting("width", 340), root.minWidth, root.maxWidth, 340)
  readonly property int savedHeight: root.clamped(root.setting("height", 260), root.minHeight, root.maxHeight, 260)

  property bool editingSize: false
  property int pendingWidth: 340
  property int pendingHeight: 260

  readonly property int liveWidth: root.editingSize ? root.pendingWidth : root.savedWidth
  readonly property int liveHeight: root.editingSize ? root.pendingHeight : root.savedHeight

  function save() {
    if (!root.dirty) return
    saveTimer.stop()
    noteFile.setText(editor.text)
    root.dirty = false
  }

  // Lifecycle hangs off the controller's own state rather than overriding the
  // base component's open()/close(). Overrides are not reliably dispatched when
  // the base calls root.open() from its own IpcHandler, so a hotkey summon
  // would skip them; opened changes on every path in and out.
  onOpenedChanged: {
    if (root.opened) {
      // Pick up edits made to the file by anything else while we were closed.
      // Safe here and only here: nothing unsaved can be overwritten, because a
      // dirty note is always flushed on the way out.
      if (!root.dirty) noteFile.reload()
    } else {
      // Dismissing mid-edit discards the pending numbers rather than leaving
      // the form up behind a closed popup, waiting for the next open.
      if (root.editingSize) root.editingSize = false
      root.save()
    }
  }

  // ---- Settings -----------------------------------------------------------

  // Applied locally first so the card resizes on the keystroke itself; the
  // shell.json write comes back through the bar as the same values. Mirrors
  // plugins/panels/clock/Panel.qml, including keeping the host widget's copy
  // in step so a later re-injection can't write a stale entry back out.
  function persistSettings(values) {
    var entry = { id: root.moduleName }
    for (var existing in root.settings) if (existing !== "id") entry[existing] = root.settings[existing]
    for (var key in values) entry[key] = values[key]

    root.settings = entry
    if (root.hostWidget && "settings" in root.hostWidget) root.hostWidget.settings = entry

    if (root.bar && root.bar.shell && typeof root.bar.shell.updateEntryInline === "function") {
      root.bar.shell.updateEntryInline(root.moduleName, entry)
      return
    }

    // Fallback for hosts that hand a third-party widget a bar facade without a
    // shell on it. `omarchy bar set` reaches the same shell.json entry from
    // outside; --json keeps the numbers numbers instead of quoted strings.
    if (root.bar && typeof root.bar.run === "function") {
      for (var name in values)
        root.bar.run("omarchy bar set " + root.moduleName + " " + name + " "
          + root.bar.shellQuote(String(values[name])) + " --json")
    }
  }

  function clamped(text, lo, hi, fallback) {
    var value = parseInt(String(text), 10)
    if (!isFinite(value)) return fallback
    return Math.max(lo, Math.min(hi, value))
  }

  // Right-click toggles: a second one puts the note back without applying.
  function toggleSizeEditor() {
    if (root.editingSize) {
      root.cancelSize()
      return
    }
    root.pendingWidth = root.savedWidth
    root.pendingHeight = root.savedHeight
    root.editingSize = true
    root.controller.show()
    Qt.callLater(function() {
      widthField.text = String(root.savedWidth)
      heightField.text = String(root.savedHeight)
      widthField.selectAll()
      widthField.forceActiveFocus()
    })
  }

  function commitSize() {
    if (root.pendingWidth !== root.savedWidth || root.pendingHeight !== root.savedHeight)
      root.persistSettings({ width: root.pendingWidth, height: root.pendingHeight })
    root.leaveSizeEditor()
  }

  function cancelSize() {
    root.leaveSizeEditor()
  }

  function leaveSizeEditor() {
    root.editingSize = false
    // An invisible item can't hold focus, so the note has to be handed it back
    // explicitly once it is on screen again.
    Qt.callLater(function() { if (root.opened) editor.forceActiveFocus() })
  }

  // Shared by both fields: Tab hops to the other, Enter applies the pair,
  // Escape drops them.
  function handleSizeKey(event, other) {
    if (event.key === Qt.Key_Escape) {
      root.cancelSize()
      event.accepted = true
    } else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
      root.commitSize()
      event.accepted = true
    } else if (event.key === Qt.Key_Tab || event.key === Qt.Key_Backtab) {
      other.selectAll()
      other.forceActiveFocus()
      event.accepted = true
    }
  }

  FileView {
    id: noteFile
    path: root.notePath
    atomicWrites: true
    printErrors: false
    onLoaded: {
      if (!root.dirty) {
        editor.text = noteFile.text()
        // Setting text parks the cursor at 0, so without this you would type
        // into the front of your own note.
        editor.cursorPosition = editor.text.length
      }
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
    focusTarget: root.editingSize ? widthField : editor
    contentWidth: panel.fittedContentWidth(Style.space(root.liveWidth))
    contentHeight: panel.fittedContentHeight(Style.space(root.liveHeight))

    // ---- The note
    ScrollView {
      anchors.fill: parent
      clip: true
      visible: !root.editingSize

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

    // ---- The size form
    Column {
      // Top-aligned, matching the note it replaces: both start at the top-left
      // of the card, so the content does not jump when right-click swaps them.
      anchors.top: parent.top
      anchors.left: parent.left
      anchors.right: parent.right
      spacing: Style.space(14)
      visible: root.editingSize

      Text {
        textFormat: Text.PlainText
        text: "PANEL SIZE"
        color: Qt.darker(root.contentForeground, 1.5)
        font.family: root.contentFontFamily
        font.pixelSize: Style.font.bodySmall
        font.letterSpacing: 1
      }

      Row {
        spacing: Style.space(10)

        Text {
          anchors.verticalCenter: parent.verticalCenter
          text: "W"
          color: Qt.darker(root.contentForeground, 1.5)
          font.family: root.contentFontFamily
          font.pixelSize: Style.font.bodySmall
          font.letterSpacing: 1
        }

        TextField {
          id: widthField
          width: Style.space(70)
          anchors.verticalCenter: parent.verticalCenter
          placeholderText: String(root.minWidth)
          foreground: root.contentForeground
          font.family: root.contentFontFamily
          inputMethodHints: Qt.ImhDigitsOnly

          onTextChanged: root.pendingWidth =
            root.clamped(text, root.minWidth, root.maxWidth, root.savedWidth)
          Keys.onPressed: function(event) { root.handleSizeKey(event, heightField) }
        }

        Text {
          anchors.verticalCenter: parent.verticalCenter
          leftPadding: Style.space(6)
          text: "H"
          color: Qt.darker(root.contentForeground, 1.5)
          font.family: root.contentFontFamily
          font.pixelSize: Style.font.bodySmall
          font.letterSpacing: 1
        }

        TextField {
          id: heightField
          width: Style.space(70)
          anchors.verticalCenter: parent.verticalCenter
          placeholderText: String(root.minHeight)
          foreground: root.contentForeground
          font.family: root.contentFontFamily
          inputMethodHints: Qt.ImhDigitsOnly

          onTextChanged: root.pendingHeight =
            root.clamped(text, root.minHeight, root.maxHeight, root.savedHeight)
          Keys.onPressed: function(event) { root.handleSizeKey(event, widthField) }
        }
      }

      Text {
        textFormat: Text.PlainText
        text: "pixels · Enter to apply · Esc to cancel"
        color: Qt.darker(root.contentForeground, 1.7)
        font.family: root.contentFontFamily
        font.pixelSize: Style.font.bodySmall
      }
    }
  }
}
