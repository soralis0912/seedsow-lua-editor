# HBLauncher (Seedsow)

The on-console homebrew-style launcher for the Seedsow Lua editor, plus a small
SDK for writing apps. It replaces the former `third_party/HBLauncher` submodule:
everything here is plain in-repo source, not a submodule.

## Documentation

- [docs/ARCHITECTURE.md](docs/ARCHITECTURE.md) — how it fits together, the two
  design rules (gated ACE, slot-independent apps), the runtime flow and limits.
- [docs/SDK.md](docs/SDK.md) — the `hb` SDK reference (drawing, input, storage,
  and the privileged `hb.native` layer).
- [docs/APP_AUTHORING.md](docs/APP_AUTHORING.md) — writing a manifest + `main.lua`
  and installing (at build time or on-console with **Y**).

## What it is

- `launcher.lua` — the applet the editor installs to slot 4. Running it is the one
  entry point that can enable the **privileged (arbitrary code execution) layer**.
  The normal editor never loads it, so ordinary editing stays fully sandboxed.
  ACE is **lazy and manifest-gated**: the menu runs sandboxed, and only launching
  an app that declares `"native": true` bootstraps the exploit and hands that app
  `hb.native`. The launcher also installs a staged app on-console with **Y**.
- `sdk/hb.lua` — the app-facing SDK runtime (drawing, input, storage, and the
  optional native layer). Apps talk only to `hb`.
- `sdk/exploit.lua` — the ACE bootstrap. Returns arbitrary read/write and the
  leaked module bases, or nil if the exploit can't be established.
- `apps/<id>/` — example apps (`app.json` manifest + `main.lua`).
- `tools/seed.py` — writes the runtime + apps into a save directory for testing.

## Slot independence

HBLauncher apps do **not** use the editor's numbered program slots. They live as
named save files and are discovered from an index:

| File | Purpose |
| --- | --- |
| `hbapps.list` | newline-separated list of installed app ids |
| `hbapp.<id>.json` | app manifest (`id`, `name`, `version`, `description`, `icon`) |
| `hbapp.<id>.lua` | app source |
| `hb.sdk.lua` | SDK runtime (loaded by the launcher) |
| `hb.exploit.lua` | ACE bootstrap (loaded by the launcher) |

The editor build (`editor/build.py`, `hblauncher_files()`) seeds these from
`sdk/` and `apps/`. `tools/seed.py <save_dir>` does the same for a live save.

## Writing an app

Create `apps/<id>/app.json` and `apps/<id>/main.lua`. The launcher runs `main.lua`
with the `hb` SDK as its only argument and uses the returned value as the per-frame
update (a `function(hb)` or a table with an `update` field).

```lua
local hb = ...
hb.screen('0xff101820')
hb.label('t', 40, 40, 44, 'My App')
return function(h)
  if h.pressed('A') then --[[ ... ]] end
  h.label('clock', 40, 160, 28, 'tick ' .. tostring(h.now()))
end
```

### SDK (`hb`)

| Call | Notes |
| --- | --- |
| `hb.screen(color)` | fullscreen background |
| `hb.label(id,x,y,size,text[,color])` / `hb.rect(id,x,y,w,h,color)` | drawing (rects draw above text) |
| `hb.pressed(name)` / `hb.held(name)` | `A B X Y L R Up Down Left Right` (edge / held) |
| `hb.now()` | engine tick |
| `hb.read(name)` / `hb.write(name,data)` | named save-file storage |
| `hb.hasACE` / `hb.native` | privileged layer, present only via HBLauncher |

### Privileged layer (`hb.native`)

Present only when opened through HBLauncher (the launcher bootstrapped the exploit):

| Field | Notes |
| --- | --- |
| `read_u64(addr)` | read 8 bytes of **mapped RW memory** (destructive at `addr+8`) |
| `write_u64(addr,val)` | write 8 bytes |
| `base.main` / `base.sdk` | leaked module bases (ASLR defeated at runtime) |
| `holder.array` | address of the controlled buffer |
| `addrof(obj)` | heap address of a Lua object |

Reach and limits: arbitrary R/W, the leaked module layout, and single-pointer-arg
native calls are available; the title's capabilities (parsed from its NPDM) permit
IPC and most memory/thread SVCs but **not** code-memory SVCs, so running **new**
native code (shellcode / an NRO) is not possible. See the main project notes for
the full capability analysis.
