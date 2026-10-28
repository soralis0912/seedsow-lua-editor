"""Exercise the A/B editor sides: load-menu page 1 boots side A and page 2 side B,
and each side installs an edited runtime only into the other one."""
import zlib

from check import Console, expect_error

CORES={'A':('ssedit1.lua','ssedit2.lua','ssedit3.lua'),'B':('sseditb1.lua','sseditb2.lua','sseditb3.lua')}
SUMS={'A':'ssedita.sum','B':'sseditb.sum'}


def disk(c):
    return {p.name:p.read_bytes() for p in c.directory.iterdir()}


def check_sides(files,directory):
    a=Console(files,directory/'side-a');a.load(1)
    b=Console(files,directory/'side-b');b.load(13)
    assert a.state()[b'side']==b'A' and b.state()[b'side']==b'B'
    assert a.messages[b'zzzzsseditor.00mark']==b'A' and b.messages[b'zzzzsseditor.00mark']==b'B'
    assert a.messages[b'zzzzsseditor.title'].endswith(b'SIDE A')
    assert a.shapes[b'zzzzsseditor.0'][b'color']!=b.shapes[b'zzzzsseditor.0'][b'color']
    assert all(b.metadata[b'saveslot'][b'lock'][i] is True for i in (1,2,3,13,14,15))
    assert b.metadata[b'saveslot'][13][b'file']==b'save0013'

    # Slots 13-15 are editor entries, not user slots; Slot + steps over them.
    s=a.state();s[b'saved']=s[b'buffer']
    a.action('slot');a.reply('14')
    assert s[b'slot']!=14 and b'protected editors' in s[b'status'],s[b'status']
    a.prompt('slot','12');s[b'saved']=s[b'buffer']
    a.action('nextslot');assert s[b'slot']==16
    s[b'saved']=s[b'buffer'];a.action('prevslot');assert s[b'slot']==12

    # Edit editor loads the running runtime; Install writes the other side only,
    # after a second press, and only valid editor source.
    s[b'saved']=s[b'buffer'];a.action('editsrc')
    assert s[b'buffer']==files['ssedit1.lua'] and s[b'filename']==b'editor-src.lua'
    original=disk(a)
    s[b'buffer']=b'not lua @'
    expect_error(lambda:a.action('install'),'Not installed')
    s[b'buffer']=b'print(1)\n'
    expect_error(lambda:a.action('install'),'not editor source')
    updated=b'SIDE_MARK="installed from A"\n'+files['ssedit1.lua']
    s[b'buffer']=updated
    a.action('install')
    assert disk(a)==original and b'again' in s[b'status']
    a.frame();a.frame()
    a.action('install')
    after=disk(a)
    assert all(after[name]==updated for name in CORES['B'])
    assert after[SUMS['B']]==f'{zlib.adler32(updated)}\n'.encode()
    assert all(after[name]==original[name] for name in CORES['A']+(SUMS['A'],))

    # Page 2 now boots the installed runtime and leaves side A alone; page 1 still
    # boots the original.
    nb=Console(after,directory/'side-b-new');nb.load(13)
    assert nb.lua.globals()[b'SIDE_MARK']==b'installed from A'
    assert nb.state()[b'side']==b'B'
    assert all(disk(nb)[name]==original[name] for name in CORES['A'])
    nb.action('repair')
    assert all(disk(nb)[name]==original[name] for name in CORES['A'])
    na=Console(after,directory/'side-a-again');na.load(1)
    assert na.lua.globals()[b'SIDE_MARK'] is None

    # From B, the install goes back to A.
    t=nb.state()
    t[b'saved']=t[b'buffer'];nb.action('editsrc');assert t[b'buffer']==updated
    nb.action('install');nb.frame();nb.frame();nb.action('install')
    assert all(disk(nb)[name]==updated for name in CORES['A'])
    assert b'Load it from page 1' in t[b'status']

    # A damaged side does not take the other side with it.
    broken=disk(nb)
    for name in CORES['B']:broken[name]=b'broken'
    ok=Console(broken,directory/'b-broken');ok.load(1)
    assert ok.state()[b'side']==b'A'
    assert all(disk(ok)[name]==b'broken' for name in CORES['B'])

    # User slots on page 2 run under side B.
    pb=Console(files,directory/'page-2-program');pb.load(13)
    u=pb.state();u[b'saved']=u[b'buffer']
    pb.prompt('slot','16');assert u[b'slot']==16
    u[b'buffer']=b'';u[b'saved']=b'';u[b'cursor']=0
    pb.prompt('keyboard','print("ON SIDE B")\n');pb.action('publish')
    run=Console(disk(pb),directory/'page-2-run',pb.metadata);run.load(16)
    assert run.state()[b'side']==b'B' and run.state()[b'output'][1]==b'ON SIDE B'
    print('A/B sides: page 2 boots side B, installs go only to the other side.')
