import QtQuick
import QtQuick.Controls
import Quickshell
import Quickshell.Io
import qs.Ui
import qs.Commons
import "Model.js" as Model

Panel {
  id: root
  moduleName: "io.github.ujo4eva.space-travel-2"
  ipcTarget: "io.github.ujo4eva.space-travel-2"

  property bool connected: false
  property string address: ""
  property var battery: null
  property string codec: ""
  property string anc: "unknown"
  property string eqName: ""
  property var budLeft: null
  property var budRight: null
  property string lastError: ""

  readonly property string barText: Model.barText(connected, anc, codec)
  readonly property string heroSubtitle: Model.heroSubtitle(connected, address, battery, codec)
  function budLevel(v) { return (v === null || v === undefined) ? -1 : v }

  function budTint(v) {
    var lvl = budLevel(v)
    if (lvl < 0) return Qt.darker(root.bar.foreground, 1.4)
    if (lvl <= 20) return Color.urgent
    return root.bar.foreground
  }

  component BudShapes: Item {
    id: shapes
    property color color: root.bar.foreground

    readonly property real bodyW: Math.max(6, Math.round(width * 0.5))
    readonly property real bodyH: Math.max(8, Math.round(height * 0.52))
    readonly property real stemW: Math.max(3, Math.round(width * 0.2))
    readonly property real cx: Math.round(width / 2)

    Rectangle {
      x: shapes.cx - shapes.bodyW / 2; y: 0
      width: shapes.bodyW; height: shapes.bodyH
      radius: shapes.bodyW / 2
      color: shapes.color
    }
    Rectangle {
      x: shapes.cx - shapes.stemW / 2; y: shapes.bodyH - shapes.stemW
      width: shapes.stemW; height: shapes.height - y
      radius: shapes.stemW / 2
      color: shapes.color
    }
  }

  // Single stemmed bud that fills from the bottom with its own charge.
  // Unknown level draws the dim outline only — quiet, not broken.
  component BudMeter: Item {
    id: meter
    property int level: -1
    property color tint: root.bar.foreground

    readonly property bool known: level >= 0
    readonly property real fillH: {
      if (!known || level <= 0) return 0
      return Math.max(2, Math.round(height * level / 100))
    }

    BudShapes {
      anchors.fill: parent
      color: Qt.darker(root.bar.foreground, 1.7)
      opacity: 0.7
    }

    Item {
      anchors.left: parent.left
      anchors.right: parent.right
      anchors.bottom: parent.bottom
      height: meter.fillH
      clip: true

      Behavior on height { NumberAnimation { duration: 240; easing.type: Easing.OutCubic } }

      BudShapes {
        width: meter.width
        height: meter.height
        y: meter.fillH - meter.height
        color: meter.tint
      }
    }
  }

  readonly property color hoverFill: bar
    ? Style.hoverFillFor(bar.foreground, Color.accent)
    : "transparent"
  readonly property color selectedFill: bar
    ? Style.selectedFillFor(bar.foreground, Color.accent)
    : "transparent"

  property int selectedIndex: 0
  property bool cursorActive: false
  readonly property int rowCount: 3

  function ctlBase() {
    return "spacetravel2-ctl"
  }

  function refresh() {
    if (!statusProc.running) statusProc.running = true
  }

  function parseStatus(raw) {
    var obj = null
    try { obj = JSON.parse(String(raw || "{}")) } catch (e) { return }
    connected = !!obj.connected
    address = obj.address || ""
    battery = (obj.battery === undefined) ? null : obj.battery
    codec = obj.codec || ""
    if (obj.anc) anc = obj.anc
    eqName = obj.eqName || ""
  }

  function parseBuds(raw) {
    var obj = null
    try { obj = JSON.parse(String(raw || "{}")) } catch (e) { return }
    if (obj.left !== undefined && obj.left !== null) budLeft = obj.left
    if (obj.right !== undefined && obj.right !== null) budRight = obj.right
  }

  function refreshBuds() {
    if (connected && !budsProc.running) budsProc.running = true
  }

  property bool ancBusy: false

  function setAnc(mode) {
    if (ancBusy || ancProc.running) {
      lastError = "Still sending the previous change — give it a few seconds."
      return
    }
    ancBusy = true
    anc = mode // optimistic: confirmed (or corrected) when the result lands
    lastError = "Setting " + mode + "…"
    ancProc.command = [ctlBase(), "anc", mode]
    ancProc.running = true
  }

  function moveCursor(delta) {
    selectedIndex = Math.max(0, Math.min(rowCount - 1, selectedIndex + delta))
  }

  function activateRow() {
    if (selectedIndex === 0) setAnc("off")
    else if (selectedIndex === 1) setAnc("on")
    else setAnc("transparency")
  }

  function rowLabel(i) {
    if (i === 0) return "Noise cancelling off"
    if (i === 1) return "Noise cancelling on"
    return "Transparency"
  }

  function rowActive(i) {
    if (i === 0) return anc === "off"
    if (i === 1) return anc === "on"
    return anc === "transparency"
  }

  onOpenedChanged: {
    if (opened) {
      refresh()
      refreshBuds()
      cursorActive = false
      selectedIndex = 0
    }
  }

  implicitWidth: button.implicitWidth
  implicitHeight: button.implicitHeight

  Process {
    id: statusProc
    command: [root.ctlBase(), "status", "--json"]
    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: root.parseStatus(text)
    }
  }

  Process {
    id: ancProc
    onExited: root.ancBusy = false
    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: {
        try {
          var obj = JSON.parse(String(text || "{}"))
          if (obj.mode) root.anc = obj.mode
          if (!obj.live) root.lastError = "No confirmation from earbuds — tap-and-hold on the earbud still cycles ANC."
          else root.lastError = ""
        } catch (e) { root.lastError = "Could not parse anc result." }
        root.refresh()
      }
    }
    stderr: StdioCollector {
      waitForEnd: true
      onStreamFinished: if (String(text || "") !== "") root.lastError = String(text).split("\n")[0]
    }
  }

  Process {
    id: budsProc
    command: [root.ctlBase(), "buds"]
    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: root.parseBuds(text)
    }
  }

  Timer {
    interval: 15000
    running: true
    repeat: true
    triggeredOnStart: true
    onTriggered: root.refresh()
  }

  // Per-bud battery arrives opportunistically; poll slowly in the background.
  Timer {
    interval: 60000
    running: true
    repeat: true
    onTriggered: root.refreshBuds()
  }

  WidgetButton {
    id: button
    anchors.fill: parent
    bar: root.bar
    text: root.barText
    tooltipText: "Space Travel 2"
    onPressed: function(b) { root.toggle() }
  }

  KeyboardPanel {
    id: panel
    anchorItem: button
    owner: root
    bar: root.bar
    open: root.opened
    focusTarget: keyCatcher
    contentWidth: panel.fittedContentWidth(Style.space(360))
    contentHeight: panel.fittedContentHeight(column.implicitHeight, Style.space(520))

    PanelKeyCatcher {
      id: keyCatcher
      anchors.fill: parent
      onMoveRequested: function(dx, dy) {
        if (!root.cursorActive) { root.cursorActive = true; return }
        if (dy !== 0) root.moveCursor(dy)
      }
      onActivateRequested: if (root.cursorActive) root.activateRow()
      onCloseRequested: root.close()
      onTabRequested: function(direction) { root.switchPanel(direction) }

      Column {
        id: column
        anchors.fill: parent
        spacing: Style.space(14)

        Item {
          width: parent.width
          implicitHeight: Math.max(heroIcon.implicitHeight, heroLabels.implicitHeight)

          Text {
            id: heroIcon
            anchors.left: parent.left
            anchors.verticalCenter: parent.verticalCenter
            text: root.connected ? "󰋋" : "󰂲"
            color: root.bar.foreground
            font.family: root.bar.fontFamily
            font.pixelSize: Style.font.display
            opacity: root.connected ? 1.0 : 0.5
          }

          Column {
            id: heroLabels
            anchors.left: heroIcon.right
            anchors.leftMargin: Style.space(14)
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            spacing: Style.space(2)

            Text {
              text: "Space Travel 2"
              color: root.bar.foreground
              font.family: root.bar.fontFamily
              font.pixelSize: Style.font.title
              font.bold: true
              elide: Text.ElideRight
              width: parent.width
            }

            Text {
              text: root.heroSubtitle.toUpperCase()
              color: Qt.darker(root.bar.foreground, 1.4)
              font.family: root.bar.fontFamily
              font.pixelSize: Style.font.caption
              font.bold: true
              font.letterSpacing: 1.2
              elide: Text.ElideRight
              width: parent.width
            }
          }
        }

        PanelSeparator {
          foreground: root.bar.foreground
        }

        Text {
          visible: !root.connected
          text: "Earbuds not connected. Take them out of the case, then connect from the Bluetooth panel."
          color: Qt.darker(root.bar.foreground, 1.5)
          font.family: root.bar.fontFamily
          font.pixelSize: Style.font.bodySmall
          wrapMode: Text.WordWrap
          width: parent.width
        }

        Row {
          visible: root.connected
          width: parent.width
          spacing: Style.space(10)

          Column {
            width: (parent.width - parent.spacing) / 2
            spacing: Style.space(4)

            BudMeter {
              width: Style.space(40)
              height: Style.space(56)
              anchors.horizontalCenter: parent.horizontalCenter
              level: root.budLevel(root.budLeft)
              tint: root.budTint(root.budLeft)
            }

            Text {
              text: "L · " + (root.budLevel(root.budLeft) < 0 ? "—" : root.budLeft + "%")
              color: root.budTint(root.budLeft)
              font.family: root.bar.fontFamily
              font.pixelSize: Style.font.body
              font.bold: true
              anchors.horizontalCenter: parent.horizontalCenter
            }
          }

          Column {
            width: (parent.width - parent.spacing) / 2
            spacing: Style.space(4)

            BudMeter {
              width: Style.space(40)
              height: Style.space(56)
              anchors.horizontalCenter: parent.horizontalCenter
              level: root.budLevel(root.budRight)
              tint: root.budTint(root.budRight)
            }

            Text {
              text: "R · " + (root.budLevel(root.budRight) < 0 ? "—" : root.budRight + "%")
              color: root.budTint(root.budRight)
              font.family: root.bar.fontFamily
              font.pixelSize: Style.font.body
              font.bold: true
              anchors.horizontalCenter: parent.horizontalCenter
            }
          }
        }

        PanelSeparator {
          visible: root.connected
          foreground: root.bar.foreground
        }

        Text {
          visible: root.connected && root.eqName !== ""
          text: ("EQ · " + root.eqName).toUpperCase()
          color: Qt.darker(root.bar.foreground, 1.4)
          font.family: root.bar.fontFamily
          font.pixelSize: Style.font.caption
          font.bold: true
          font.letterSpacing: 1.2
        }

        Column {
          width: parent.width
          spacing: Style.space(6)

          Repeater {
            model: root.rowCount

            delegate: CursorSurface {
              required property int index
              width: column.width
              hasCursor: root.cursorActive && root.selectedIndex === index
              current: root.rowActive(index)
              foreground: root.bar.foreground
              fill: root.hoverFill
              currentFill: root.selectedFill
              implicitHeight: rowText.implicitHeight + Style.spacing.xl

              Text {
                id: rowText
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                anchors.leftMargin: Style.space(10)
                anchors.rightMargin: Style.space(10)
                text: (root.rowActive(index) ? "● " : "○ ") + root.rowLabel(index)
                color: root.bar.foreground
                font.family: root.bar.fontFamily
                font.pixelSize: Style.font.body
                elide: Text.ElideRight
              }

              MouseArea {
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onContainsMouseChanged: if (containsMouse) {
                  root.cursorActive = true
                  root.selectedIndex = index
                }
                onClicked: {
                  root.selectedIndex = index
                  root.activateRow()
                }
              }
            }
          }
        }

        Text {
          visible: root.lastError !== ""
          text: root.lastError
          color: Qt.darker(root.bar.foreground, 1.5)
          font.family: root.bar.fontFamily
          font.pixelSize: Style.font.caption
          wrapMode: Text.WordWrap
          width: parent.width
        }

        Text {
          text: "Tip: tap-and-hold cycles ANC on the earbuds."
          color: Qt.darker(root.bar.foreground, 1.6)
          font.family: root.bar.fontFamily
          font.pixelSize: Style.font.caption
          wrapMode: Text.WordWrap
          width: parent.width
        }
      }
    }
  }
}
