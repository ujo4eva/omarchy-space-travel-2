function ancIcon(mode) {
  if (mode === "on") return "ANC"
  if (mode === "transparency") return "TRA"
  if (mode === "off") return "OFF"
  return "ST2"
}

function barText(connected, anc) {
  if (!connected) return "󰂲"
  return "󰋋 " + ancIcon(anc)
}

function heroSubtitle(connected, address, battery, codec) {
  if (!connected) return "Not connected"
  var parts = []
  if (battery !== null && battery !== undefined) parts.push(battery + "%")
  if (codec) parts.push(codec)
  if (address) parts.push(address)
  return parts.length > 0 ? parts.join(" · ") : "Connected"
}
