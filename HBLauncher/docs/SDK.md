# HBLauncher SDK reference (`hb`)

An app receives one argument: the `hb` SDK object. Apps talk only to `hb`, never
to the raw `editor`, so the same source runs whether or not the privileged layer
is present. The object is built by `sdk/hb.lua`; the privileged `hb.native` is
produced by `sdk/exploit.lua` and attached only when the app is opened through
HBLauncher with `"native": true` in its manifest.

```lua
local hb = ...            -- the SDK, passed to main.lua
hb.screen('0xff101820')
return function(h) ... end -- per-frame update
```

Colors are `'0xffRRGGBB'` strings (ARGB). Coordinates are in a 1280x720 surface.

## Lifecycle

| Field | Meaning |
| --- | --- |
| `main.lua` is a chunk run with `hb` as its first argument and `hb` in its environment | one-time setup |
| it returns a `function(hb)` **or** a table `{ update = function(hb) }` | the per-frame update, driven by the launcher |
| returning nothing | a one-shot screen with no updates |
| **B** | reserved by the editor: stops the app and returns to the editor (then **Y** re-runs the launcher) |

## Drawing

Elements are identified by a stable `id`; redraw with the same id to update in
place. **Rect layers draw above text** — never place a rect over text; use rects
only in gaps (rules, separators, bars). Icons are text monograms, not images.

> **A text label's colour is fixed when the label is first created** — redrawing
> the same id with a different colour does not recolour it. To show changing
> state (a held button, a selection), use a fixed-colour **rect** and move it
> on-screen / off-screen (to e.g. y=900), or draw into a fresh id. Rect colour is
> likewise fixed at creation, so create it in its visible colour and toggle only
> its position. The launcher's selection bar and the Controller Test app both do
> this.

| Call | Notes |
| --- | --- |
| `hb.screen(color)` | set the fullscreen background |
| `hb.label(id, x, y, size, value [, color])` | a text label (string `value`) |
| `hb.rect(id, x, y, w, h, color)` | a filled rectangle |
| `hb.print(...)` | write to the editor output log |

## Input

There is no edge API in the engine; the SDK polls `engine:isDown(keycode)` and
does edge detection. Button names: `A B X Y L R Up Down Left Right`.

| Call | Notes |
| --- | --- |
| `hb.held(name)` | true while the button is down |
| `hb.pressed(name)` | true on the frame the button goes down (edge) |
| `hb.resetInput()` | clear edge state (e.g. after a mode switch) |

## Time and storage

| Call | Notes |
| --- | --- |
| `hb.now()` | engine tick (ms-ish; advances per frame, not a wall clock) |
| `hb.read(name)` | read a named save file, or nil |
| `hb.write(name, data)` | write a named save file (persists) |

Storage is the slot-independent save-file store. Apps may keep their own state
in files named, by convention, `hbdata.<id>.*` to avoid clashes.

## Privileged layer: `hb.native`

Present only when the app declares `"native": true` and was opened through
HBLauncher (which bootstrapped the exploit). Otherwise `hb.native` is `nil` and
`hb.hasACE` is `false` — always check before using it:

```lua
local n = hb.native
if not n then hb.label('e', 40, 130, 26, 'Open via HBLauncher.'); return end
```

| Field | Notes |
| --- | --- |
| `n.read_u64(addr)` | read 8 bytes of **mapped RW memory** as an integer (< 2^52). **Destructive**: writes a number tag at `addr+8`, so it corrupts the next 12 bytes — do not use it to walk a buffer forward. RX code memory is not readable this way. |
| `n.write_u64(addr, val)` | write 8 raw bytes (the value's bit pattern) at `addr` |
| `n.resolve(mod, off)` | `mod` = `'main'` or `'sdk'`; returns the runtime address `base + off` (defeats ASLR at runtime) |
| `n.read_at(mod, off)` | convenience: `read_u64(resolve(mod, off))` |
| `n.addrof(obj)` | heap address of a Lua table / function / thread |
| `n.base` | `{ main = <addr>, sdk = <addr> }` leaked module bases |
| `n.holder` | `{ table = <the controlled Lua table>, array = <its data address> }` |
| `n.note` | a short human-readable summary of reach/limits |

Reach: arbitrary R/W, the leaked module layout, `addrof`, and native function
calls (the call primitive lives alongside these when networking is built; see
`sdk/net.lua`). Hard limit: no code-memory SVC capability on this title, so **new**
native code cannot be made executable — everything reuses the title's own code.

## Helpers and widgets

| Call | Notes |
| --- | --- |
| `hb.color` | named palette: `bg, sep, accent, dim, name, hot, ok, warn, bad` (all `'0xff…'`) so apps match the launcher without hardcoding hex |
| `hb.wrap(text, maxchars)` | word-aware wrap into a table of lines (default 72); hard-splits over-long words |
| `hb.lines(idPrefix, x, y, size, lines, color)` | draws a table of strings as stacked labels (`idPrefix1, idPrefix2, …`); returns the next free y. Pairs with `hb.wrap` |
| `hb.safe(fn, ...)` | `pcall` wrapper returning `ok, result` |

`hb.list` — a reusable vertical selection widget. Create it once, then call
`:draw(h)` and `:step(h)` each frame:

```lua
local list = hb.list{ id = 'mods', x = 40, y = 130, rowH = 70, visible = 4,
  items = { { name = 'main', desc = 'base 0x…' }, { name = 'sdk', desc = '…' } } }
-- per frame:
local action = list:step(h)   -- 'select' when A is pressed on an item, else nil
list:draw(h)
if action == 'select' then local item = list:selected() --[[ ... ]] end
```

`:setItems(items)` replaces the list; `:selected()` returns the current item.
Colours come from `hb.color`. See `apps/memmap` for a full example.

## A complete minimal app

```lua
-- main.lua
local hb = ...
hb.screen('0xff101820')
hb.label('t', 40, 40, 44, 'My App')
hb.label('h', 40, 620, 22, 'A: +1   B: back', '0xff93a6c0')
local n = 0
return function(h)
  if h.pressed('A') then n = n + 1 end
  h.label('c', 40, 180, 30, 'count = ' .. n)
end
```

See [APP_AUTHORING.md](APP_AUTHORING.md) for the manifest and installation.
