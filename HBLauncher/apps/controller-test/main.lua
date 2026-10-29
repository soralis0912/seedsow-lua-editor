-- Controller Test -- lights up each button while it is held. A plain sandboxed
-- SDK app (no "native", so no ACE): it only uses hb.held + drawing.
local hb = ...
local c = hb.color

hb.screen(c.bg)
hb.label('t', 40, 36, 40, 'Controller Test', c.name)
hb.label('h', 40, 650, 22, 'Hold buttons to light them up   B back', c.dim)

local BTNS = { 'A', 'B', 'X', 'Y', 'L', 'R', 'Up', 'Down', 'Left', 'Right' }

-- The engine fixes a text label's colour when the label is created, so we can't
-- recolour a button per frame. Instead each button has a fixed-colour underline
-- rect (created once as accent) that we move on-screen when held and off-screen
-- when released -- position/visibility update reliably, and rects sit in the gap
-- below the text so they never overlap it.
return function(h)
  for i, b in ipairs(BTNS) do
    local x = 60 + ((i - 1) % 5) * 230
    local y = 170 + math.floor((i - 1) / 5) * 120
    h.label('b' .. i, x, y, 40, b, c.name)
    if h.held(b) then h.rect('u' .. i, x, y + 56, 110, 6, c.ok)
    else h.rect('u' .. i, 40, 900, 110, 6, c.ok) end
  end
end
