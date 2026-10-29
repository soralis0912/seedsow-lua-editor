-- Hello -- minimal HBLauncher SDK app.
-- Opened by the launcher with the hb SDK as its only argument. Returns a per-frame
-- update function. Talks only to hb (never the raw editor), so it is portable.
local hb = ...

hb.screen('0xff101820')
hb.label('t', 40, 40, 44, 'Hello from the HBLauncher SDK')
hb.label('a', 40, 120, 24,
  hb.hasACE and 'ACE: enabled (hb.native available)' or 'ACE: off (sandboxed)',
  hb.hasACE and '0xff6fd08a' or '0xff93a6c0')
hb.label('h', 40, 620, 22, 'A: nudge counter     B: back to the launcher', '0xff93a6c0')

local n = 0
return function(h)
  if h.pressed('A') then n = n + 1 end
  h.label('clock', 40, 200, 28, 'engine tick ' .. tostring(h.now()))
  h.label('count', 40, 250, 28, 'A presses: ' .. n)
end
