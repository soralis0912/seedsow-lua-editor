-- Memory Map -- the runtime layout of the loaded modules, computed from the
-- leaked bases (hb.native) and the known segment offsets of this build. Pure
-- read-free arithmetic (resolve), so it never perturbs memory. Uses hb.list.
local hb = ...
local c = hb.color
local n = hb.native

-- segment offsets/sizes of this build's NSOs (memoff, size), from the extracted
-- modules. Each segment maps to [base + memoff, base + memoff + size).
local MODS = {
  { id = 'main', get = function() return n and n.base.main end, segs = {
      { 'text', 0x0,      0x263a90 }, { 'ro', 0x264000, 0x11f05c }, { 'data', 0x384000, 0x30390 } } },
  { id = 'sdk', get = function() return n and n.base.sdk end, segs = {
      { 'text', 0x0,      0x601a40 }, { 'ro', 0x602000, 0x4e6f54 }, { 'data', 0xae9000, 0x5ee20 } } },
}

local function chrome(title)
  hb.screen(c.bg)
  hb.label('t', 40, 36, 40, title, c.name)
end

if not n then
  chrome('Memory Map')
  hb.label('e', 40, 130, 26, 'This app needs ACE -- open it through HBLauncher.', c.bad)
  return
end

local items = {}
for _, m in ipairs(MODS) do
  local b = m.get()
  items[#items + 1] = { name = m.id, desc = b and string.format('base 0x%x', b) or 'base not leaked' }
end
local list = hb.list { id = 'mm', x = 40, y = 130, rowH = 70, visible = 4, items = items }
local mode = 'list'

local function enter_list()
  mode = 'list'; hb.resetInput()
  chrome('Memory Map')
  hb.label('h', 40, 650, 22, 'Up/Down select   A view segments   B back', c.dim)
  list:draw(hb)
end

local function enter_detail(m)
  mode = 'detail'; hb.resetInput()
  chrome('Memory Map / ' .. m.id)
  hb.label('h', 40, 650, 22, 'X back to modules   B back', c.dim)
  local b = m.get()
  local lines = { string.format('base = 0x%x', b or 0) }
  for _, s in ipairs(m.segs) do
    local st = b and (b + s[2])
    local en = st and (st + s[3])
    lines[#lines + 1] = string.format('%-4s  0x%09x .. 0x%09x   (0x%x)', s[1], st or 0, en or 0, s[3])
  end
  hb.lines('d', 40, 130, 26, lines, c.name)
end

enter_list()

return function(h)
  if mode == 'list' then
    local action = list:step(h)
    list:draw(h)
    if action == 'select' then enter_detail(MODS[list.sel]) end
  else
    if h.pressed('X') then enter_list() end
  end
end
