# Agent notes

## Testing in Eden with AI control

The editor can be driven in the Eden emulator through its AI control API
(`eden/tools/ai-control` in the Eden fork: HTTP on `127.0.0.1:<port>`, also
wrapped as the `eden` MCP server). Emulator results are iteration aids only;
they never replace the hardware regression pass.

### Install the current editor into the emulator save

The save in the emulator holds whatever editor build was last copied there, so
rebuild it after changing `editor/`:

1. Launch the game in Eden once so a save exists. The save folder is
   `~/.local/share/eden/nand/user/save/0000000000000000/<user>/0100EE5021C9E000/`.
   Copy it somewhere first as a backup.
2. ZIP that folder's files flat (without `.nx_save_meta.bin`) and build:
   `python3 editor/build.py --base save.zip --output OUT --replace-slots`
3. Unzip `OUT/Seedsow-Lua-Editor-Save.zip` over the save folder while Eden is
   not running. `ssedit1.lua` now contains the current editor.

To keep the user's own Eden data untouched, run a separate instance with
`XDG_DATA_HOME`, `XDG_CONFIG_HOME` and `XDG_CACHE_HOME` pointing at a scratch
copy, on another port. Make sure an old instance has fully exited before
starting a new one on the same port (check `lsof -iTCP:<port> -sTCP:LISTEN`);
the Qt build does not quit on SIGTERM.

### Open the editor

Start Eden with `--ai-control 8765 -g <game>.nsp`, then:

1. On the title screen (NEW GAME / LOAD / SETTINGS) press Down, then A to open
   LOAD. Stop pressing A once the title is up, or it starts NEW GAME.
2. The load screen shows no cursor and ignores A and touch until you press
   Right once; the cursor then sits on slot 1 "LUA EDITOR".
3. Press A, answer "Load this file?" with YES (A) and wait a few seconds.

Use `frames` rather than `duration_ms` for presses (10-15 frames is reliable),
and wait about a second between presses.

```sh
curl -s -X POST localhost:8765/input/press -d '{"buttons":["Down"],"frames":10}'
curl -s -X POST localhost:8765/input/press -d '{"buttons":["A"],"frames":15}'
curl -s -X POST localhost:8765/input/press -d '{"buttons":["Right"],"frames":10}'
curl -s -X POST localhost:8765/input/press -d '{"buttons":["A"],"frames":10}'
curl -s -X POST localhost:8765/input/press -d '{"buttons":["A"],"frames":10}'
```

Load screen slots: 1 LUA EDITOR / 2 PC INPUT / CALIBRATE / 3 EDITOR BACKUP /
4 HBLauncher (`sscode004.lua` / `sslaunch.lua`, from the in-repo `HBLauncher/`
folder) / 5-6 example programs. R on the load screen turns to page 2: 13 B /
LUA EDITOR / 14 B / PC INPUT / CALIBRATE / 15 B / EDITOR BACKUP / 16 B /
HBLauncher (side B) -- all for side B.

HBLauncher is per-side: slot 4 (side A) and slot 16 (side B) run the same applet
from the in-repo `HBLauncher/` folder, and both read one shared, slot-independent
app store (`hbapps.list` + `hbapp.<id>.*`). It is the app launcher + SDK; see
`HBLauncher/docs/`. Its apps
are slot-INDEPENDENT -- named save files (`hbapps.list` + `hbapp.<id>.json/.lua`),
not program slots -- listed as cards (monogram, name, version, description).
Up/Down selects, A launches the app in-process (handing it the `hb` SDK), X
refreshes, Y installs a staged app (`hbstage.json/.lua`), R uninstalls (two
presses). B returns to the editor; Y from the editor re-runs the launcher. ACE
is lazy and manifest-gated: the menu is sandboxed, and only launching an app
with `"native": true` bootstraps the exploit and hands it `hb.native` (arbitrary
R/W + leaked module bases). Normal editor programs never get ACE. Note: rect
layers draw above text in this engine, so programs must not place labels over a
rect; input is polled via `engine:isDown(<keycode>)` (no editor.pressed/held).

### Inside the editor

- Choose buttons with the D-pad and press A. Touch lands well away from where
  it is aimed (a tap at the middle of the code window hits **Line down**).
- From **Slot -** (where focus starts), Down x3 and Right x4 reach
  **Calibrate input**; **Keyboard +** is Right then Down from **Slot +**.
  **Edit editor** is Right x6 from **Slot -** and **Install to B/A** is Down
  from it. Install needs a second press; it writes `sseditb1-3.lua` +
  `sseditb.sum` from side A (or `ssedit1-3.lua` + `ssedita.sum` from side B).
  **Install launcher** (below Install to B/A) inserts HBLauncher into the
  opposite side's first user slot (A -> slot 16, B -> slot 4) after a second press.
- **Keyboard +** opens the Switch software keyboard and the game stops until it
  is answered. Read it from `GET /status` (`software_keyboard`) and answer with
  `POST /swkbd/submit {"text": "..."}` or `{"cancel": true}`. This game's
  dialog takes at most 32 characters per entry. After each entry the editor
  reopens it, so keep submitting 32-character pieces and finish with
  `{"text": ""}` or a cancel.
- The status line ("N bytes | cursor N") is the easiest way to check edits.
- **Calibrate input** shows live `isDown`/`isPush` codes, which is how to see
  what the game receives for an input. Finishing all six steps saves a new
  button mapping, so in a scratch save just close Eden instead.

### USB keyboard

The game never activates the HID keyboard (it calls `ActivateNpadWithRevision`
and `ActivateTouchScreen` only, visible with the log filter
`*:Info Service.HID:Debug`). Keys sent with `/keyboard/*` therefore never reach
`isDown`: holding letters, Enter, Esc, F1, arrows, Shift and Ctrl shows
`isDown: - | isPush: -` on the calibration screen, while pad X shows `112`.
Codes 13 and 27 seen by the editor come from the game's aliases for pad A and B,
not from a keyboard. On a console a USB keyboard types into the software
keyboard (**Keyboard +**) instead; in Eden that dialog is answered with
`/swkbd/submit`, since the emulated HID keyboard does not reach it either.
