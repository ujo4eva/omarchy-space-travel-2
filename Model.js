function ancIcon(mode) {
  if (mode === "on") return "ANC"
  if (mode === "transparency") return "TRA"
  if (mode === "off") return "OFF"
  return "ST2"
}

function barText(connected, anc, codec) {
  if (!connected) return "󰂲"
  var label = ancIcon(anc)
  if (codec) return "󰋋 " + label + " · " + codec
  return "󰋋 " + label
}

function heroSubtitle(connected, address, battery, codec) {
  if (!connected) return "Not connected"
  var parts = []
  if (battery !== null && battery !== undefined) parts.push(battery + "%")
  if (codec) parts.push(codec)
  if (address) parts.push(address)
  return parts.length > 0 ? parts.join(" · ") : "Connected"
}
