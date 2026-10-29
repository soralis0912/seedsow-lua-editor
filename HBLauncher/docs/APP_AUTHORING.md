# Writing and installing an HBLauncher app

An app is two files in `samples/<id>/`:

```
samples/my-app/
  app.json     manifest
  main.lua     source, run with the hb SDK
```

## Manifest (`app.json`)

```json
{
  "format": "hblauncher.seedsow-app",
  "abi": 1,
  "id": "my-app",
  "name": "My App",
  "version": "1.0.0",
  "description": "What this app does",
  "icon": "MA",
  "native": false
}
```

| Field | Contract |
| --- | --- |
| `format`, `abi` | `hblauncher.seedsow-app` and `1` |
| `id` | first char alphanumeric, then `[a-z0-9-]`; the storage/file key |
| `name` | shown on the card (nonempty) |
| `version` | shown on the card (string) |
| `description` | shown on the card |
| `icon` | optional 2-char monogram; defaults to initials of `name` |
| `native` | `true` to request the privileged layer (see below); omit/`false` to stay sandboxed |

The manifest is parsed with simple patterns, so keep the fields on plain
`"key": "value"` lines (and `"native": true` for the boolean).

## The app contract (`main.lua`)

The launcher runs `main.lua` with the `hb` SDK as the first argument and drives
the returned value per frame:

```lua
local hb = ...                 -- the SDK
hb.screen('0xff101820')        -- one-time setup
hb.label('t', 40, 40, 44, 'My App')
return function(h)             -- per-frame update (or a table { update = fn })
  if h.pressed('A') then --[[ ... ]] end
  h.label('clock', 40, 180, 28, 'tick ' .. tostring(h.now()))
end
```

Talk only to `hb` (see [SDK.md](SDK.md)); never reach for the raw `editor`. **B**
always returns to the editor, so you don't implement an exit yourself — but do
tell the user ("B: back") on screen.

## Native apps

Set `"native": true` to receive `hb.native` (arbitrary R/W, leaked module bases,
`resolve`, `addrof`). The launcher bootstraps the exploit lazily the first time a
native app runs; sandboxed apps never trigger it. Always guard against the layer
being unavailable:

```lua
local n = hb.native
if not n then
  hb.label('e', 40, 130, 26, 'This app needs ACE -- open it via HBLauncher.')
  return
end
hb.label('m', 40, 130, 24, string.format('sdk base = 0x%x', n.base.sdk or 0))
```

Only request `native` if you need it: it stops the garbage collector for the rest
of the session (see [ARCHITECTURE.md](ARCHITECTURE.md)).

## Installing

**At build time** — put the app in `samples/<id>/`. Both the editor build
(`editor/build.py`, `hblauncher_files()`) and `tools/seed.py` pick it up and write
`hbapp.<id>.json`, `hbapp.<id>.lua`, and the `hbapps.list` index into the save.

```sh
python3 HBLauncher/tools/seed.py <save_dir>
```

**On the console** — stage the app as two save files and install it from the
launcher:

1. Write `hbstage.json` (the manifest) and `hbstage.lua` (the source) into the
   save. From a PC you can send both over the editor's controller transfer (no
   FTP) — `tools/pack_app.py` prepares them; see
   [INSTALL_FROM_PC.md](INSTALL_FROM_PC.md).
2. In the launcher, press **Y**. It writes `hbapp.<id>.*`, adds the id to
   `hbapps.list`, and refreshes. The app appears in the menu.

No program slot is used at any point.

## Checklist

- `id` is unique and matches `[a-z0-9][a-z0-9-]*`.
- `name`, `version`, `description` are set (they show on the card).
- The app draws something and prints "B: back".
- If it uses `hb.native`, it sets `"native": true` and guards for `nil`.
- Rects are only in gaps, never over text.
