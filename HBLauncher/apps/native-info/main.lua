-- Native Info -- demonstrates the privileged hb.native layer (only present when the
-- app is opened through HBLauncher, which bootstraps arbitrary code execution).
local hb = ...

hb.screen('0xff0c1422')
hb.label('t', 40, 40, 40, 'Native Info (ACE)')
hb.label('b', 40, 620, 22, 'B: back to the launcher', '0xff93a6c0')

local n = hb.native
if not n then
  hb.label('e', 40, 130, 26,
    'hb.native is not available. Open this app through HBLauncher.', '0xffd08a6f')
  return
end

hb.label('m', 40, 130, 24, string.format('main base   = 0x%x', n.base.main or 0), '0xffeef3fb')
hb.label('s', 40, 170, 24, string.format('sdk  base   = 0x%x', n.base.sdk or 0), '0xffeef3fb')
hb.label('h', 40, 210, 24, string.format('holder.array = 0x%x', n.holder.array or 0), '0xffeef3fb')

-- arbitrary R/W self-check inside our own controlled buffer (mapped memory)
local probe = n.holder.array + 16 * 40
n.write_u64(probe, 0x1337)
local v = n.read_u64(probe)
hb.label('rw', 40, 270, 24,
  'arb R/W: wrote 0x1337, read ' .. string.format('0x%x', v or 0),
  (v == 0x1337) and '0xff6fd08a' or '0xffd08a6f')

-- resolve: turn a module-relative offset into a runtime address (ASLR defeated)
local longjmp = n.resolve and n.resolve('sdk', 0x5511b4)
hb.label('rs', 40, 310, 24,
  'resolve(sdk,0x5511b4) = ' .. (longjmp and string.format('0x%x', longjmp) or 'n/a'), '0xffeef3fb')

hb.label('note', 40, 370, 18, n.note or '', '0xff93a6c0')
