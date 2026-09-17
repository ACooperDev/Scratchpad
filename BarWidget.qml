import QtQuick
import qs.Commons
import qs.Ui

// Bar pill for the scratchpad. Owns nothing but the icon and the click
// routing: Panel.qml holds the note, the text, and the saving.
//
// Modelled on plugins/panels/weather/BarWidget.qml. The open/close/opened
// forwarding below is required, not decorative — Bar.findPanelWidget routes
// shell IPC through this root, and the bar's one-popup-at-a-time coordinator
// reads popoutSwitchClosing off whichever item sits in the slot.
BarWidget {
  id: root
  moduleName: "acooper.scratchpad"

  function injectPanel() {
    var target = panelLoader.item
    if (!target) return
    if ("bar" in target) target.bar = root.bar
    if ("settings" in target) target.settings = root.settings
    if ("anchorItem" in target) target.anchorItem = button
    if ("hostWidget" in target) target.hostWidget = root
  }

  function togglePanel() {
    if (panelLoader.item) panelLoader.item.toggle()
  }

  readonly property bool opened: panelLoader.item ? panelLoader.item.opened === true : false

  function open() {
    if (panelLoader.item) panelLoader.item.open()
  }

  function close() {
    if (panelLoader.item) panelLoader.item.close()
  }

  readonly property bool popoutSwitchClosing: panelLoader.item ? panelLoader.item.popoutSwitchClosing === true : false

  function closeForPopoutSwitch() {
    if (panelLoader.item) panelLoader.item.closeForPopoutSwitch()
  }

  implicitWidth: button.implicitWidth
  implicitHeight: button.implicitHeight

  onBarChanged: injectPanel()
  onSettingsChanged: injectPanel()

  Loader {
    id: panelLoader
    active: true
    source: Qt.resolvedUrl("Panel.qml")
    visible: false
    onLoaded: {
      root.injectPanel()
      Qt.callLater(root.injectPanel)
    }
  }

  BarIconButton {
    id: button
    anchors.fill: parent
    bar: root.bar
    text: ""
    slotSize: Style.bar.statusSlot
    tooltipText: root.opened ? "" : "Scratchpad"

    onPressed: function(b) {
      if (!root.bar) return
      root.togglePanel()
    }
  }
}
