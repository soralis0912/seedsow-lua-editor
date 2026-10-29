# Installing HBLauncher apps from a PC (no FTP)

You do not need a network server (FTP or otherwise) to put an app on the console
from outside. HBLauncher apps are plain named save files, and the editor already
ships a PC→console file transfer that can write an **arbitrary named save file**.
So the external-install path reuses what is already there — no new channel and no
change to the on-console code.

## The channel

The editor's **PC INPUT** receiver (load-menu slot 2 / 14, "PC INPUT /
CALIBRATE") decodes a controller-button stream into a file. A PC companion
(`pc/`) sends the stream through a Raspberry Pi running a Bluetooth
Pro-Controller emulator (`pi/`), which the console reads as an ordinary
Player-1 controller. See [docs/02-pi-setup.md](../../docs/02-pi-setup.md) and
[docs/03-send-files.md](../../docs/03-send-files.md) for the one-time setup.

The transfer packet carries a **filename**, not just a slot number
(`pc/protocol.py` `pack`, decoded in `editor/transfer.lua`). The companion's
**Raw file** mode sends the file under the name you type, verbatim:

- Raw file mode uses the `F000_` prefix (`pc/protocol.py` `destination`,
  returned when the slot is `None`; joined in `pc/client.py` as
  `F000_<filename>`).
- On the console, a name of the form `F<nnn>_<name>` writes `<name>` as-is via
  `save_file()` (`editor/editor.lua`, the `^([PF]%d%d%d)_(.+)$` branch), after
  checking the name is valid and not a protected editor file
  (`editor/storage.lua` `W.valid` / `W.protected`).

HBLauncher's files (`hbstage.json`, `hbstage.lua`, `hbapp.<id>.*`,
`hbapps.list`) are all valid, unprotected names, so Raw file mode can write every
one of them.

## Recommended flow: stage, then install with Y

This is the safe path — the launcher owns the app index, so the PC never has to
rewrite `hbapps.list`.

1. In the PC companion's **Optional: send files** tab, set mode to **Raw file**.
2. Send the manifest as filename **`hbstage.json`**.
3. Send the source as filename **`hbstage.lua`**.
4. On the console, load **HBLauncher** (slot 4 on side A, or slot 16 on side B)
   and press **Y**. The launcher reads `hbstage.*`, writes `hbapp.<id>.json` +
   `hbapp.<id>.lua`, and appends `<id>` to `hbapps.list`. The app appears as a
   card (`HBLauncher/launcher.lua`, `install_staged`).

`tools/pack_app.py` prepares the two staged files from a normal app folder and
prints these steps:

```sh
python3 HBLauncher/tools/pack_app.py HBLauncher/samples/hello
# writes hbstage.json + hbstage.lua, then tells you what to send
```

## Alternative: write the app files directly

If you would rather not use the Y step, send the app's files by their final
names and refresh with **X**:

1. Raw file → **`hbapp.<id>.json`**
2. Raw file → **`hbapp.<id>.lua`**
3. Raw file → **`hbapps.list`** — the *full* index, one id per line (transfers
   replace a file wholesale; there is no append), so include every app already
   installed plus the new id.
4. In HBLauncher press **X** to rescan.

The staged `Y` path is preferred because it maintains `hbapps.list` for you.

## Limits (be honest about them)

- **Slow.** The controller stream is about 0.38 s/byte at Normal speed
  (`pc/protocol.py` `seconds`), so a tiny Lua app takes ~1 minute and a few-KB
  app several minutes. Fine for small apps; not a bulk channel.
- **One file per send**, and there is no console→PC acknowledgement
  ([docs/03-send-files.md](../../docs/03-send-files.md)) — watch the console for
  "PC FILE SAVED".
- Requires the one-time controller calibration and a Player-1 controller source
  (the Pi bridge).
- A bad packet is rejected by an Adler-32 checksum and staged via `.bak`/`.new`
  (`editor/storage.lua`), so a failed transfer never corrupts an existing file.

## What was ruled out

- **NFC / amiibo** as a data carrier: no reader exists on the console side; it
  would need a whole new on-console path. Not worth it.
- **USB mass-storage / SD card:** all file I/O is confined to the title's own
  save mount (`editor/storage.lua`); external storage is not reachable.
- **Sockets (FTP or any TCP/IP server):** out of reach on this title — the ACE
  primitive cannot sequence native calls and the title has no code-memory SVC
  capability, so no in-game network service can be stood up. This transfer avoids
  the problem entirely by using controller input, not a socket.
