-- Environment Info -- the exploit's view of memory, READS ONLY. Shows the leaked
-- module bases, the controlled buffer, the current lua_State, resolved module
-- offsets and one live pointer read. It never calls a native function (that is the
-- other agent's primitive) -- only resolve + read_u64 + addrof.
--
-- Demonstrates the SDK helpers added for apps: hb.color, hb.wrap, hb.lines, hb.safe.
local hb = ...
local C = hb.color

hb.screen(C.bg)
hb.label('t', 40, 40, 40, 'Environment Info', C.name)
hb.label('b', 40, 650, 22, 'B: back to the launcher', C.dim)

local n = hb.native
if not n then
  -- sandboxed (ACE off): friendly nudge, laid out with the wrap/lines helpers.
  hb.lines('e', 40, 130, 24, hb.wrap(
    'hb.native is not available here. Open this app through HBLauncher so it can '
    .. 'bootstrap the privileged layer -- its manifest declares "native": true.', 64), C.warn)
  return
end

-- helpers ------------------------------------------------------------------
local function hex(v) return v and string.format('0x%x', v) or 'n/a' end

-- leaked layout (straight from the native table; no memory touched) ---------
hb.lines('base', 40, 104, 24, {
  'hasACE         = ' .. tostring(hb.hasACE),
  'main base      = ' .. hex(n.base.main),
  'sdk  base      = ' .. hex(n.base.sdk),
  'holder.array   = ' .. hex(n.holder.array),
}, C.name)

-- a thin rule sits in the gap below the block (rects draw over text, never on it)
hb.rect('rule', 40, 240, 1160, 2, C.sep)

-- derived reads: addrof + resolve (arithmetic) + one live read_u64 ----------
-- current lua_State: a fresh coroutine's thread object lives on this VM's stack.
local okco, co = hb.safe(coroutine.create, function() end)
local state_addr = okco and n.addrof(co) or nil
local tbl_addr = n.addrof({})

-- known module offsets (same ones the ACE bootstrap uses), resolved at runtime.
local GOT_LONGJMP, SDK_LONGJMP = 0x3a2730, 0x5511b4
local sdk_ljmp = n.resolve('sdk', SDK_LONGJMP)
local got_slot = n.resolve('main', GOT_LONGJMP)
-- the single live pointer read: the GOT entry for longjmp (read_u64 is destructive
-- at addr+8, so we do it once here, not per frame).
local ok_got, got_val = hb.safe(n.read_at, 'main', GOT_LONGJMP)

hb.lines('mem', 40, 256, 24, {
  'lua_State      = ' .. hex(state_addr) .. '    (addrof(coroutine))',
  'fresh table    = ' .. hex(tbl_addr) .. '    (addrof({}))',
  'resolve(sdk)   = ' .. hex(sdk_ljmp) .. '    (base.sdk + 0x5511b4)',
  'GOT[longjmp]@  = ' .. hex(got_slot) .. '    (base.main + 0x3a2730)',
  'GOT[longjmp]   = ' .. (ok_got and hex(got_val) or 'n/a') .. '    (live read_u64)',
}, C.name)

-- arb R/W self-check in our own controlled scratch buffer (safe, away from the
-- fake tables): write a marker and read it straight back.
local scratch = n.holder.array + 16 * 40
n.write_u64(scratch, 0xcafebabe)
local back = n.read_u64(scratch)
hb.label('rw', 40, 424, 24,
  'arb R/W check  = wrote 0xcafebabe, read ' .. hex(back),
  (back == 0xcafebabe) and C.ok or C.bad)

-- footer note from the native layer, wrapped to the screen width.
hb.lines('note', 40, 470, 18, hb.wrap(n.note or '', 88), C.dim)
