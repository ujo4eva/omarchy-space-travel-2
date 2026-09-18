# omarchy-space-travel-2

Omarchy bar-widget plugin for the **Moondrop Space Travel 2** earbuds.

## What it does

- Bar icon shows connection, ANC mode (`ANC` / `TRA` / `OFF`), and active codec.
- Panel:
  - Photos of the left/right earbud with **per-bud battery %** underneath
    (from spontaneous feature-`0x0d` broadcasts; opportunistic — the last-heard
    values persist between broadcasts).
  - ANC off / on / transparency rows reflecting the **live** mode, set with
    confirmation.
  - Combined battery (BlueZ), codec (`pactl`), MAC address.
- On-device fallbacks always work: **tap-and-hold** cycles ANC modes.
  Game mode (4x tap) has no GAIA command and is intentionally not in the panel.

## Install

```bash
# backend on PATH
install -Dm755 bin/spacetravel2-ctl ~/.local/bin/spacetravel2-ctl

# plugin (pick one)
omarchy plugin add https://github.com/<you>/omarchy-space-travel-2.git --enable
# or by hand:
# cp -r . ~/.config/omarchy/plugins/io.github.ujo4eva.space-travel-2
# omarchy-shell shell rescanPlugins
```

Requires: `bluetoothctl` (BlueZ), `pactl` (PulseAudio/PipeWire), Python 3 stdlib only.

## CLI

```bash
spacetravel2-ctl status --json
spacetravel2-ctl anc <off|on|transparency|query>
spacetravel2-ctl buds
```

## Protocol notes

- GAIA V3 over RFCOMM channel 1, Vendor ID `0x001D`, big-endian framing —
  ported from Gadgetbridge's `MoondropSpaceTravel2Protocol` /
  `MoondropSpaceTravelProtocol` / `GaiaPacket` (AGPL-3.0-or-later; Codeberg
  `Freeyourgadget/Gadgetbridge`). Verified live against real hardware.
- Audio-curation (ANC): feature `0x08`, `GET_MODE` pdu `0x03`, `SET_MODE`
  pdu `0x04`. GET returns a 0-based slot, mapped to bitmask
  Normal=1 / ANC=2 / Transparency=4 (`mode = 1 << slot`). SET takes the
  bitmask, applies asynchronously (~1.5 s), and sends no reply — so the
  backend re-GETs to confirm, with one fresh-connection retry.
- Per-bud battery: feature `0x0d` pushes index/level pairs
  (e.g. `01 64 02 5a` = bud 1 at 100 %, bud 2 at 90 %), broadcast
  intermittently (observed during battery-percent transitions). Bud index
  1 is shown as L, 2 as R by TWS convention — not yet verified against the
  buds' own L/R.
- EQ preset: feature `0x05`, GET pdu `0x02` (e.g. `0x3f` = custom/Harman target).
- `status` and `anc` always read the **live** mode from the earbuds when
  connected; the state file is only a fallback when unreachable.
- Battery comes from BlueZ `Battery1`; codec from `pactl` (`api.bluez5.codec`).

### Safety policy

Only Gadgetbridge's known-safe commands are ever sent (EQ/touch/ANC GETs,
ANC SET). An early version probed unknown features with empty SET packets
and wiped the buds' voice prompts + EQ preset (both restored via the
Moondrop Link app) — never again.

### Visual idiom

The battery meters follow the convention established by
[`ncr/omarchy-headphones`](https://github.com/ncr/omarchy-headphones):
vector-drawn bud shapes that fill bottom-up with their own charge, urgent
colour under the low threshold — no product photography, always crisp at
any scale or theme.
