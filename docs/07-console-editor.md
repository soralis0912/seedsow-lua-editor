# Use the console editor

Manual editing needs no network or Pi. Load slot **1** or **3** for the ordinary
editor. Slots 1–3 and 13–15 are reserved for editor recovery; use the other
slots from **4–120** for programs. Fresh saves ship **HBLauncher** in slot 4 — a
menu that lists your program slots and launches the selected one (Up/Down to
select, A to run, B to return to the editor, then Y to reopen the menu).

## Write and keep a program

1. Choose a free user slot.
2. Select **Keyboard +** to insert text at the byte cursor. A wired USB keyboard
   can type into the console's text-entry dialog, which accepts **32 characters
   per entry** in this Switch build. The dialog reopens after each entry for
   longer text; an empty entry or Cancel closes it.
   **Edit line** replaces the current line segment; use insertion and deletion
   controls for edits that exceed the keyboard limit.
3. The on-screen character grid is available for printable ASCII, newline,
   tab and backspace.
4. Choose **RUN buffer** to run the current contents, including unsaved edits.
5. Choose **Save + publish** to save the source and create a normal load-menu
   entry for your selected slot. **Save file** writes the file without publishing.
6. Restart Seedsow and load your numbered slot to run the saved program.

User source filenames default to `sscode004.lua` and similar names. A
`ssslot004.ref` file records the source filename for that slot. **File / new**
can open another plain filename; a missing file starts a new buffer.

## Controls

| Input | Action |
| --- | --- |
| Touch, or D-pad then A | Select and activate a button |
| B | Leave cursor mode; otherwise backspace or return from a running program |
| L / R | Move the byte cursor |
| X | Open console text entry |
| Y | Run the buffer |
| Byte offset | Move to a zero-based byte position |
| Undo | Restore one of the last 12 in-memory edits |

Unsaved changes require a repeated open/navigation action before discarding.
**Restore .bak** loads the previous file version into the buffer for inspection.

Direct USB typing into the editor window is not exposed by this game's Switch
input path: the game never turns on the HID keyboard. A wired keyboard works
inside the system dialog. The character grid and optional Pi uploads do not
have its 32-character dialog cap.

## Type with a USB keyboard

Open **Keyboard +** (X) and type into the system dialog. After each entry is
inserted the dialog opens again at the new cursor position, so you can keep
typing 32 characters at a time and press Enter between them. Submit an empty
entry or cancel to close it. Enter in the dialog submits the entry, so add new
lines with the character grid's **ENTER**. In HEX mode the reopened dialog
keeps taking hex pairs.

## A/B editor sides

The editor is installed twice. Page 1 of the game's load menu (slots 1–3:
editor, PC input / calibrate, backup) is **side A** with a navy background and a
large **A**; page 2 (slots 13–15) is **side B** with a purple background and a
large **B**. Programs in slots 16–24 run under side B, all others under side A.

To update the editor on the console:

1. Choose **Edit editor**. The running side's editor source opens in the buffer
   as `editor-src.lua`.
2. Edit it, for example with a USB keyboard through **Keyboard +**. **Save file**
   keeps the work in `editor-src.lua`.
3. Choose **Install to B** (on side B, **Install to A**) and choose it again to
   confirm. The buffer must be valid Lua editor source; otherwise nothing is
   written.
4. Return to the title and load the other side's editor from its page.

An editor never writes its own side, and **Repair editors** only repairs its own
side. If the installed side does not start, load the other page and install a
working editor back into it.

## Place and move the cursor

Tap the code to select its window and place the cursor at the nearest insertion
point. With a controller, move focus into the code window and press **A**.
The line along its left edge is light while hovered or focused, and black while
selected.

While selected, **D-pad left/right** moves a byte and **up/down** moves a line,
preserving the preferred column across short lines. Hold a direction to repeat.
**B** returns to button navigation without deleting text. **X** opens text entry
and returns to cursor mode afterward. Tapping another button changes focus to it.
In HEX mode, D-pad up/down moves 16 bytes.

## Scrolling and moving between lines

Six buttons above the code preview control navigation in **TEXT** mode:

| Button | Action |
| --- | --- |
| Line up / Line down | Move the cursor one line, keeping its byte column where possible. A short or empty line clamps the cursor; the original column is restored on a longer line. |
| Scroll up / Scroll down | Browse one line without moving the cursor or changing the code. |
| Page up / Page down | Browse six lines without moving the cursor. |

Select a button with the D-pad and press A, or tap it. Moving the cursor or editing
resumes automatic scrolling so its line stays visible. Long lines also follow the
cursor horizontally. The preview shows **one-based line numbers**, `>` beside
the cursor's line, and **`[|]` at the insertion point**. The marker is display-only;
it is not inserted into your program. **Byte offset** still uses zero-based byte
positions.

Fresh saves include these controls in the main editor in slot 1 and its backup
in slot 3. Older installations can add the current editor in a fresh user slot
using the [update guide](04-updates-recovery.md). In HEX mode, use L/R or
**Byte offset**. The current fresh-save build was reported working on console on
2026-10-27; detailed feature coverage was not recorded.

Ordinary editing uses the game's standard Switch input codes and aliases without
requiring calibration. An existing learned mapping is reused when available.
**Calibrate input** remains an optional fallback for nonstandard inputs and Pi
uploads: hold physical **A, B, X, Y, L, R** as prompted, releasing each before
the next step. Manual calibration needs no PC/Pi and returns to editing.

## Raw hex editing

**TEXT / HEX** changes how bytes are displayed and entered. In HEX mode, enter
two hex digits per byte; `00` is supported. **Keyboard +** accepts pairs of hex
digits separated by whitespace. **INSERT / PATCH** selects insertion or
overwrite. Patching past EOF extends the file.

Files are bounded at **1 MiB**; writable plain filenames at **72 characters**
inside the console editor. The PC uploader uses a stricter 64-character limit
to leave space for transfer metadata. Raw writes store literal bytes and do not
repair file formats. Use **Save file** for raw native-save bytes; publishing
requires a separate Lua source filename.

## Lua program interface

```lua
print("Hello")
local data = editor.read("notes.txt")
editor.write("notes.txt", "saved from Lua\n")
return function(engine, editor)
    -- Called once per frame. editor.openEditor() returns to editing.
end
```

The default environment inherits available game globals. `e` and `engine` refer
to the game engine; `print` appears in the editor output. The game's own save
directory is added to `package.path` for plain Lua modules.

A fullscreen program (one that calls `editor.screen`) owns the controller:
read it with `editor.held(name)` and `editor.pressed(name)` (an edge) for
`A B X Y L R Up Down Left Right`. **B** is reserved — it stops the program and
returns to the editor — so use the other buttons. HBLauncher in slot 4 is a
worked example.

The optional **Guard** limits Lua instructions around user chunks/callbacks.
It is initially on. Native calls may not be interruptible, and a program that
replaces event handlers or changes the UI may require reloading an editor slot.
User Lua can bypass normal storage protections. Keep working recovery entries
and your external backup.
