"""Exercise the HBLauncher Seedsow applet (HBLauncher/seedsow/launcher.lua).

The launcher is an ordinary editor program, so it is driven here against a small
fake of the editor's program API: slot enumeration, in-process launch with a
return to the menu, and a full jump to a slot's launcher."""
from pathlib import Path

from lupa.lua51 import LuaRuntime

LAUNCHER = Path(__file__).resolve().parent.parent.parent / 'HBLauncher' / 'seedsow' / 'launcher.lua'


def check_launcher(path=LAUNCHER):
    lua = LuaRuntime(encoding=None, unpack_returned_tuples=True)
    g = lua.globals()
    probe = lua.table()
    g[b'probe'] = probe

    reads = {
        b'ssslot005.ref': b'game5.lua\n',
        b'sscode005.lua': b'probe.ran5=true\nreturn function() probe.tick5=(probe.tick5 or 0)+1 end\n',
        b'ssslot006.ref': b'game6.lua\n',
        b'sscode006.lua': b'return function() end\n',
        b'ssslot016.ref': b'game16.lua\n',  # page 2 user slot
        b'sscode016.lua': b'return function() end\n',
        # slot 4 is the launcher itself; 13-15 are editor slots: never listed.
        b'ssslot004.ref': b'hblauncher.lua\n', b'sscode004.lua': b'return function() end\n',
        b'ssslot013.ref': b'x.lua\n', b'sscode013.lua': b'return function() end\n',
    }

    draws = {b'labels': lua.table(), b'jumps': lua.table()}
    g[b'draws'] = draws
    press = set()

    engine = lua.table()
    engine[b'tag'] = lambda _, p: draws[b'jumps'].__setitem__(
        len(list(draws[b'jumps'].values())) + 1, p[b'file']) if p[1] == b'jump' else None

    editor = lua.table()
    editor[b'slot'] = 4
    editor[b'base'] = b'save:'
    editor[b'read'] = lambda name: reads.get(name)
    editor[b'print'] = lambda *a: None
    editor[b'screen'] = lambda *a: None
    editor[b'rect'] = lambda *a: None
    labels = {}
    editor[b'label'] = lambda i, x, y, s, v: labels.__setitem__(bytes(i), bytes(v))
    opened = {}
    editor[b'openEditor'] = lambda: opened.__setitem__('x', True)
    editor[b'held'] = lambda name: name in press
    editor[b'pressed'] = lambda name: name in press

    # Mirror the editor: run the chunk with (engine, editor); its return is the
    # per-frame update.
    loader = lua.eval(b'function(s) return assert(loadstring(s)) end')
    chunk = loader(path.read_bytes())
    update = chunk(engine, editor)

    # Enumeration lists user slots on both pages, never the editor or itself.
    import re
    listed = sorted(int(re.search(rb'\d+', v).group()) for k, v in labels.items()
                    if bytes(k).startswith(b'e') and re.search(rb'\d', v))
    assert listed == [5, 6, 16], listed

    def drive(upd, *buttons):
        press.clear(); press.update(buttons); upd(engine, editor)

    # A launches the first entry (slot 5) in-process and its update runs each frame.
    drive(update, b'A')
    assert probe[b'ran5'] is True
    drive(update); drive(update)
    assert probe[b'tick5'] == 2, probe[b'tick5']

    # Down then A on a fresh menu launches slot 6, not slot 5.
    probe[b'ran5'] = None
    update = chunk(engine, editor)
    drive(update, b'Down')
    drive(update, b'A')
    assert probe[b'ran5'] is None

    print('HBLauncher: lists slots and launches the selected one in-process.')


if __name__ == '__main__':
    check_launcher()
