-- Syscalls -- the SVC wrappers this build exposes, resolved to runtime addresses.
-- These are the native targets the ACE's call-return primitive can invoke (which
-- was validated separately: a `blr`-based gadget calls a native function with a
-- controlled argument and returns into the ROP chain). This app itself only does
-- read-free arithmetic (resolve = base + offset), so it never perturbs memory;
-- hb.native today exposes R/W + resolve + addrof, and native CALLS go through the
-- ROP call primitive, not through hb.native. Pure demo of resolve() + the layout.
local hb = ...
local c = hb.color

-- SVC wrappers located in sdk.text for the qualified Seedsow build (svc#, offset).
-- Plain `svc #imm ; ret` thunks except where noted (out-handle handling after svc).
local SVCS = {
  { 'ExitProcess',          0x07, 0x168b24, '' },
  { 'SleepThread',          0x0b, 0x168b54, '' },
  { 'CreateTransferMemory', 0x15, 0x168bd0, 'out-handle' },
  { 'GetSystemTick',        0x1b, 0x168c1c, 'no args' },
  { 'GetInfo',              0x1c, 0x168c24, '' },
  { 'ConnectToNamedPort',   0x1f, 0x168c38, 'out-handle' },
  { 'SendSyncRequest',      0x21, 0x168c4c, '' },
  { 'OutputDebugString',    0x27, 0x168c94, 'Eden logs it' },
}

local function chrome()
  hb.screen(c.bg)
  hb.label('t', 40, 36, 40, 'Syscalls', c.name)
  hb.label('b', 40, 650, 22, 'B: back to the launcher', c.dim)
end

local n = hb.native
if not n then
  chrome()
  hb.lines('e', 40, 130, 24, hb.wrap(
    'hb.native is not available here. Open this app through HBLauncher so it can '
    .. 'bootstrap the privileged layer -- its manifest declares "native": true.', 64), c.warn)
  return
end

chrome()
hb.label('sb', 40, 92, 20, string.format('sdk base = 0x%x   (ASLR defeated at runtime)', n.base.sdk or 0), c.hot)

local rows = { string.format('%-22s %-6s %-14s %s', 'wrapper', 'svc', 'runtime addr', 'note') }
for _, s in ipairs(SVCS) do
  local addr = n.resolve('sdk', s[3])
  rows[#rows + 1] = string.format('%-22s 0x%02x   %-14s %s',
    s[1], s[2], addr and string.format('0x%x', addr) or 'n/a', s[4])
end
hb.lines('r', 40, 130, 22, rows, c.name)

hb.rect('rule', 40, 150, 1160, 1, c.sep)
hb.lines('f', 40, 470, 18, hb.wrap(
  'These addresses are what the ROP call-return primitive dispatches to; calling '
  .. 'is not yet wrapped in hb.native. Offsets are specific to this build.', 92), c.dim)
