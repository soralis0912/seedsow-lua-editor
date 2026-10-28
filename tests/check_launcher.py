"""Exercise the HBLauncher Seedsow applet (HBLauncher/seedsow/launcher.lua).

The launcher is an ordinary editor program, so it is driven here against a small
fake of the editor's program API: slot enumeration with @name/@desc metadata,
in-process launch, and refresh."""
import re
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
        b'sscode005.lua': b'-- @name: Alpha\n-- @desc: first app\n'
                          b'probe.ran5=true\nreturn function() probe.tick5=(probe.tick5 or 0)+1 end\n',
        b'ssslot006.ref': b'game6.lua\n',
        b'sscode006.lua': b'-- @name: Beta\nreturn function() end\n',       # name, no desc
        b'ssslot016.ref': b'game16.lua\n',                                   # page 2 user slot
        b'sscode016.lua': b'return function() end\n',                        # no manifest -> filename
        # slot 4 is the launcher itself; 13-15 are editor slots: never listed.
        b'ssslot004.ref': b'hblauncher.lua\n', b'sscode004.lua': b'return function() end\n',
        b'ssslot013.ref': b'x.lua\n', b'sscode013.lua': b'return function() end\n',
    }

    labels = {}
    press = set()
    engine = lua.table()
    engine[b'tag'] = lambda *a: None

    editor = lua.table()
    editor[b'slot'] = 4
    editor[b'read'] = lambda name: reads.get(name)
    editor[b'print'] = lambda *a: None
    editor[b'screen'] = lambda *a: None
    editor[b'rect'] = lambda *a: None
    # label takes an optional 6th color arg now.
    editor[b'label'] = lambda i, x, y, s, v, *c: labels.__setitem__(bytes(i), bytes(v))
    editor[b'openEditor'] = lambda: None
    editor[b'held'] = lambda name: name in press
    editor[b'pressed'] = lambda name: name in press

    loader = lua.eval(b'function(s) return assert(loadstring(s)) end')
    chunk = loader(path.read_bytes())
    update = chunk(engine, editor)

    # Cards list the user slots on both pages, never the editor or itself.
    slots = sorted(int(re.search(rb'\d+', v).group())
                   for k, v in labels.items() if re.match(rb'^s\d$', bytes(k)) and v.startswith(b'slot '))
    assert slots == [5, 6, 16], slots

    # @name / @desc parsed from the source; filename is the fallback.
    assert labels[b'n1'] == b'Alpha', labels[b'n1']
    assert labels[b'd1'] == b'first app', labels[b'd1']
    assert labels[b'n2'] == b'Beta'
    assert labels[b'n3'] == b'game16.lua'                 # no manifest -> filename
    assert labels[b'd3'] == b'runs game16.lua'            # desc fallback

    def drive(upd, *buttons):
        press.clear(); press.update(buttons); upd(engine, editor)

    # A launches the first entry (slot 5) in-process; its update runs each frame.
    drive(update, b'A')
    assert probe[b'ran5'] is True
    drive(update); drive(update)
    assert probe[b'tick5'] == 2, probe[b'tick5']

    # X refreshes: a newly installed slot appears after a rescan.
    update = chunk(engine, editor)
    assert labels[b'foot'].startswith(b'3 apps'), labels[b'foot']
    reads[b'ssslot007.ref'] = b'game7.lua\n'
    reads[b'sscode007.lua'] = b'-- @name: Gamma\nreturn function() end\n'
    drive(update, b'X')
    assert labels[b'foot'].startswith(b'4 apps'), labels[b'foot']
    assert b'Gamma' in {bytes(v) for v in labels.values()}

    # Down then A launches slot 6, not slot 5.
    probe[b'ran5'] = None
    update = chunk(engine, editor)
    drive(update, b'Down')
    drive(update, b'A')
    assert probe[b'ran5'] is None

    print('HBLauncher: cards with name/desc, launch in-process, refresh.')


if __name__ == '__main__':
    check_launcher()
