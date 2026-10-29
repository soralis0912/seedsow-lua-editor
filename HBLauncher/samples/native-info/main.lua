-- Native Info -- demonstrates the privileged hb.native layer (only present when the
-- app is opened through HBLauncher, which bootstraps arbitrary code execution).
-- Shows the leaked bases, an arbitrary R/W self-check, and resolve(); see the
-- Syscalls app for the reachable SVC wrappers the call primitive can target.
local hb = ...
local c = hb.color

hb.screen(c.bg)
hb.label('t', 40, 40, 40, 'Native Info (ACE)', c.name)
hb.label('b', 40, 650, 22, 'B: back to the launcher', c.dim)

local n = hb.native
if not n then
  hb.lines('e', 40, 130, 26, hb.wrap(
    'hb.native is not available. Open this app through HBLauncher so it can '
    .. 'bootstrap the privileged layer -- its manifest declares "native": true.', 60), c.bad)
  return
end

local function hex(v) return v and string.format('0x%x', v) or 'n/a' end

hb.lines('base', 40, 118, 24, {
  'main base    = ' .. hex(n.base.main),
  'sdk  base    = ' .. hex(n.base.sdk),
  'holder.array = ' .. hex(n.holder.array),
}, c.name)
hb.rect('rule', 40, 232, 1160, 1, c.sep)

-- arbitrary R/W self-check inside our own controlled buffer (mapped memory)
local probe = n.holder.array + 16 * 40
n.write_u64(probe, 0x1337)
local v = n.read_u64(probe)
hb.label('rw', 40, 248, 24,
  'arb R/W   : wrote 0x1337, read ' .. hex(v), (v == 0x1337) and c.ok or c.bad)

-- resolve: turn a module-relative offset into a runtime address (ASLR defeated)
local longjmp = n.resolve and n.resolve('sdk', 0x5511b4)
hb.label('rs', 40, 288, 24, 'resolve   : sdk+0x5511b4 (longjmp) = ' .. hex(longjmp), c.name)

hb.lines('reach', 40, 344, 20, hb.wrap(
  'Reach: arbitrary R/W, leaked module layout, addrof, and native function calls '
  .. 'via the ROP call-return primitive (validated separately). New native code '
  .. 'cannot be mapped (no code-memory SVC) -- everything reuses the title\'s code.', 90), c.dim)
hb.label('note', 40, 470, 18, n.note or '', c.dim)
