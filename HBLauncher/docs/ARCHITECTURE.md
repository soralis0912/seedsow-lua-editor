# HBLauncher architecture (Seedsow)

HBLauncher is the on-console app launcher for the Seedsow Lua editor, plus a small
SDK for writing apps. This document explains how the pieces fit together and the
two design rules that shape everything: **ACE is gated**, and **apps are
slot-independent**.

## The two environments

The Seedsow Lua editor runs user programs as sandboxed Lua chunks. Each program
is a chunk the editor calls with `(engine, editor)`; it draws with the editor API
and returns a per-frame update function. That is the whole trust boundary:

- **Normal editor programs** are ordinary sandboxed Lua. They have no native
  capabilities. Nothing about running or editing a program enables arbitrary code
  execution.
- **HBLauncher** is itself such a program — the one installed in slot 4. It is the
  single entry point that can turn on the privileged layer. Running HBLauncher is
  an explicit act; opening the editor and running your own code is not.

This is the first rule: **the normal editor stays sandboxed; only HBLauncher can
enable ACE, and only for apps that ask for it.**

## Components

```
HBLauncher/
  launcher.lua        the slot-4 applet: menu, app loading, ACE gating, install
  sdk/
    hb.lua            the app-facing SDK runtime (drawing, input, storage, native)
    exploit.lua       the ACE bootstrap: returns arbitrary R/W + leaked bases, or nil
    net.lua           socket wrappers over the native call primitive (networking)
  apps/<id>/
    app.json          manifest: id, name, version, description, icon, native
    main.lua          app source (run with the hb SDK)
  tools/seed.py       writes the runtime + apps into a save directory
  docs/               this documentation
```

At runtime these live in the editor save as **named files**, not program slots
(see "Slot independence"). `editor/build.py` (`hblauncher_files()`) and
`tools/seed.py` both produce the same set of save files from this folder.

## Runtime flow

1. The editor opens slot 4 and runs `launcher.lua` with `(engine, editor)`.
2. The launcher loads the SDK builder from `hb.sdk.lua` and reads the app index
   (`hbapps.list`). The menu renders. **No exploit has run yet** — the menu is
   fully sandboxed, so the garbage collector stays on and memory stays bounded.
3. The user selects an app and presses **A**.
4. If that app's manifest has `"native": true`, the launcher **lazily** bootstraps
   ACE: it loads `hb.exploit.lua`, runs its `bootstrap()`, and caches the returned
   `native` table. Apps without `"native": true` skip this and run sandboxed.
5. The launcher builds an `hb` object (`sdk/hb.lua` + the `native` table or nil)
   and runs the app's `main.lua` with it. The app's returned function is driven
   per frame.
6. **B** returns to the editor (reserved by the editor); from the editor, **Y**
   re-runs the launcher.

Lazy, manifest-gated ACE is the practical form of the first rule: the launcher
itself never needs the exploit, so the common path (browsing, running non-native
apps) carries no ACE cost or risk.

## The ACE layer

`sdk/exploit.lua` packages the memory-corruption chain that was verified on this
build:

> `pluto.unpersist` loads unverified Lua 5.1 bytecode, giving an out-of-bounds
> `LOADK` constant read. That builds a fake `Table` whose `array` pointer we
> control (a raw pointer encoded as an IEEE subnormal via `math.ldexp`), which is
> arbitrary memory read/write. The module base is recovered from
> `luaB_collectgarbage`'s native pointer; the sdk base from main's GOT entry for
> `longjmp`.

`bootstrap()` returns a `native` table — see [SDK.md](SDK.md) for the fields.
Reach and limits are honest: arbitrary R/W, the leaked module layout, and native
function calls are available, but the title's kernel capabilities (parsed from its
NPDM) do **not** include code-memory SVCs, so running **new** machine code
(shellcode / an NRO) is not possible. Everything is done by reading/writing memory
and reusing the title's own code.

A consequence: once ACE is bootstrapped, the garbage collector stays stopped for
the rest of that session (the fake table points at memory the collector must not
walk). The menu and non-native apps keep the collector on; only running a native
app turns it off, so long native sessions should be mindful of memory growth.

## Slot independence

The editor's numbered program slots are for editing your own programs. HBLauncher
apps deliberately do **not** use them. Instead apps are named save files found via
an index:

| File | Purpose |
| --- | --- |
| `hbapps.list` | newline-separated list of installed app ids |
| `hbapp.<id>.json` | the app's manifest |
| `hbapp.<id>.lua` | the app's source |
| `hb.sdk.lua` | the SDK runtime, loaded by the launcher |
| `hb.exploit.lua` | the ACE bootstrap, loaded on first native launch |
| `hbstage.json` / `hbstage.lua` | a staged app, installed on-console with **Y** |

This is the second rule: **apps opened from HBLauncher never depend on a program
slot.** You can install any number of apps without touching the editor's slots,
and apps move as plain files (seeded at build time, transferred later, or staged
and installed with **Y** on the console).

## Installing apps

- **At build time:** `editor/build.py` seeds `sdk/` and `apps/` into the save via
  `hblauncher_files()`. `tools/seed.py <save_dir>` does the same for a live save.
- **On the console:** write a `hbstage.json` + `hbstage.lua` into the save (by any
  means the editor offers) and press **Y** in the launcher. It registers the app
  as `hbapp.<id>.*` and adds it to `hbapps.list`.

See [APP_AUTHORING.md](APP_AUTHORING.md) for the manifest and the app contract.
