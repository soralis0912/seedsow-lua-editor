-- HBLauncher (Seedsow) -- launcher.lua
--
-- The on-console applet. The editor installs this as the slot-4 launcher; running
-- it is the one entry that can enable the privileged (arbitrary code execution)
-- layer. Ordinary editor programs never load it, so normal editing stays sandboxed.
--
-- ACE is LAZY and manifest-gated: the menu itself runs fully sandboxed (so the
-- garbage collector stays on and memory stays bounded). Only when you launch an
-- app whose manifest declares "native": true does the launcher bootstrap the
-- exploit and hand that app hb.native. Apps that don't ask for it run sandboxed.
--
-- Apps are slot-INDEPENDENT: named save files discovered from an index:
--   hbapps.list            newline list of installed app ids
--   hbapp.<id>.json        manifest (id,name,version,description,icon,native)
--   hbapp.<id>.lua         source
--   hb.sdk.lua             SDK runtime (loaded here)
--   hb.exploit.lua         ACE bootstrap (loaded on first native launch)
--   hbstage.json/.lua      a staged app, installed on-console with Y
--
-- Controls: Up/Down select, A launch, X refresh, Y install staged app. B returns
-- to the editor (reserved); from the editor, Y re-runs this launcher.

local engine, editor = ...

local BG, SEP, ACCENT = '0xff0c1422', '0xff22324a', '0xff3f7bd6'
local DIM, NAME, HOT, OKC, WARN = '0xff93a6c0', '0xffeef3fb', '0xff9fc6ff', '0xff6fd08a', '0xffd0a86f'

-- ----------------------------------------------------------------- SDK + ACE
local build_sdk
do
  local s = editor.read('hb.sdk.lua')
  if s then local f = loadstring(s, '@hb.sdk')
    if f then local ok, b = pcall(f); if ok then build_sdk = b end end end
end

-- ACE state: 'none' (no bootstrap present), 'ready' (present, not run),
-- 'on' (bootstrapped), 'fail' (bootstrap ran but failed).
local native, ace_state = nil, (editor.read('hb.exploit.lua') and 'ready' or 'none')
local function get_native()
  if ace_state == 'on' or ace_state == 'fail' or ace_state == 'none' then return native end
  local s = editor.read('hb.exploit.lua')
  local f = s and loadstring(s, '@hb.exploit')
  if f then
    local ok, boot = pcall(f)
    if ok and type(boot) == 'function' then
      local o, n = pcall(boot)
      if o and type(n) == 'table' then native = n; ace_state = 'on'; return native end
    end
  end
  ace_state = 'fail'; return nil
end
local function ace_label()
  return ({ none = 'no ACE', ready = 'ACE ready', on = 'ACE on', fail = 'ACE failed' })[ace_state]
end
local function ace_color()
  return (ace_state == 'on') and OKC or (ace_state == 'fail') and WARN or DIM
end

-- ----------------------------------------------------------- app discovery
local function sfield(js, k) return js:match('"' .. k .. '"%s*:%s*"(.-)"') end
local function bfield(js, k) return js:match('"' .. k .. '"%s*:%s*true') ~= nil end
local function initials(s)
  local a, b = s:match('(%w)%w*[%s/_%-]+(%w)')
  if a and b then return (a .. b):upper() end
  return s:sub(1, 2):upper()
end
local entries = {}
local function scan()
  entries = {}
  local list = editor.read('hbapps.list') or ''
  for id in list:gmatch('[^\r\n]+') do
    id = id:match('^%s*(.-)%s*$')
    if id ~= '' then
      local js = editor.read('hbapp.' .. id .. '.json')
      local src = editor.read('hbapp.' .. id .. '.lua')
      if js and src then
        local name = sfield(js, 'name') or id
        entries[#entries + 1] = {
          id = id, name = name, version = sfield(js, 'version'),
          desc = sfield(js, 'description') or '', icon = sfield(js, 'icon') or initials(name),
          native = bfield(js, 'native'),
        }
      end
    end
  end
end

-- install a staged app (hbstage.json + hbstage.lua) as hbapp.<id>.* and index it.
local function install_staged()
  local mj = editor.read('hbstage.json')
  local src = editor.read('hbstage.lua')
  if not (mj and src) then return 'no staged app (write hbstage.json + hbstage.lua)' end
  local id = sfield(mj, 'id')
  if not (id and id:match('^[%w][%w%-]*$')) then return 'staged app: missing/invalid id' end
  editor.write('hbapp.' .. id .. '.json', mj)
  editor.write('hbapp.' .. id .. '.lua', src)
  local list = editor.read('hbapps.list') or ''
  local has = false
  for x in list:gmatch('[^\r\n]+') do if x:match('^%s*(.-)%s*$') == id then has = true end end
  if not has then
    if list ~= '' and list:sub(-1) ~= '\n' then list = list .. '\n' end
    editor.write('hbapps.list', list .. id .. '\n')
  end
  return 'installed ' .. id
end

-- uninstall an app: there is no file delete, so overwrite its source + manifest empty
-- and drop its id from the index. Called only after a two-press confirmation.
local function uninstall(e)
  editor.write('hbapp.' .. e.id .. '.lua', '')
  editor.write('hbapp.' .. e.id .. '.json', '')
  local list = editor.read('hbapps.list') or ''
  local kept = {}
  for x in list:gmatch('[^\r\n]+') do
    local id = x:match('^%s*(.-)%s*$')
    if id ~= '' and id ~= e.id then kept[#kept + 1] = id end
  end
  editor.write('hbapps.list', #kept > 0 and (table.concat(kept, '\n') .. '\n') or '')
  return 'uninstalled ' .. e.id
end

-- word-wrap for the full-screen error view (the launcher has no hb SDK of its own).
local function wrap(text, maxchars)
  text = tostring(text or ''); maxchars = maxchars or 84
  local out, line = {}, ''
  for word in text:gmatch('%S+') do
    while #word > maxchars do
      if line ~= '' then out[#out + 1] = line; line = '' end
      out[#out + 1] = word:sub(1, maxchars); word = word:sub(maxchars + 1)
    end
    if line == '' then line = word
    elseif #line + 1 + #word <= maxchars then line = line .. ' ' .. word
    else out[#out + 1] = line; line = word end
  end
  if line ~= '' then out[#out + 1] = line end
  return out
end

-- ------------------------------------------------------------------ input
local CODES = {
  A = { 13, 258 }, B = { 27, 257 }, X = { 112, 259 }, Y = { 113, 256 },
  R = { 117, 261 },
  Up = { 38, 265 }, Down = { 40, 264 }, Left = { 37, 263 }, Right = { 39, 262 },
}
local function is_down(name)
  for _, c in ipairs(CODES[name] or {}) do
    local ok, v = pcall(function() return engine:isDown(c) end)
    if ok and (v == true or v == 1) then return true end
  end
  return false
end
local prev = {}
local function pressed(name)
  local now = is_down(name); local was = prev[name]; prev[name] = now
  return now and not was
end

-- ------------------------------------------------------------------ view
local VISIBLE, CARD_TOP, CARD_H = 6, 126, 84
local sel, top, mode, sub, note, app_hb = 1, 0, 'menu', nil, '', nil
local primed = false    -- swallow input left over from the key that launched us
local confirm = nil     -- id pending a second uninstall press (two-press confirm)
local err_msg = nil     -- message shown by the full-screen error view
local function cardY(i) return CARD_TOP + (i - 1) * CARD_H end
local function clampsel()
  if sel > #entries then sel = #entries end
  if sel < 1 then sel = 1 end
  if sel < top + 1 then top = sel - 1 end
  if sel > top + VISIBLE then top = sel - VISIBLE end
  if top < 0 then top = 0 end
end
local function hide_row(i)
  editor.rect('sep' .. i, 40, 900, 1, 1, SEP)
  for _, p in ipairs({ 'm', 'n', 'v', 'd', 's', 't' }) do editor.label(p .. i, 40, 900, 2, '') end
end
local function draw()
  editor.screen(BG)
  editor.label('title', 40, 24, 40, 'HBLauncher', NAME)
  editor.label('ace', 1120, 36, 20, ace_label(), ace_color())
  editor.rect('rule', 40, 86, 1200, 2, ACCENT)
  editor.label('hint', 40, 94, 20,
    'Up/Down select   A launch   X refresh   Y install   R uninstall   B editor', DIM)
  if #entries == 0 then
    editor.label('empty', 40, 200, 24,
      'No apps. Stage one (hbstage.json + hbstage.lua) and press Y, or add via the SDK.', DIM)
    for i = 1, VISIBLE do hide_row(i) end
    editor.rect('cursor', 40, 900, 1, 1, ACCENT)
  else
    editor.rect('cursor', 30, cardY(sel - top) + 4, 6, 68, ACCENT)
    for i = 1, VISIBLE do
      local e = entries[top + i]
      if e then
        local y = cardY(i)
        editor.label('m' .. i, 48, y + 6, 32, e.icon, ACCENT)
        editor.label('n' .. i, 120, y + 8, 26, e.name, (top + i == sel) and HOT or NAME)
        editor.label('t' .. i, 1090, y + 8, 16, e.native and 'native' or '', WARN)
        editor.label('v' .. i, 1090, y + 48, 18, e.version and ('v' .. e.version) or '', DIM)
        editor.label('d' .. i, 120, y + 44, 18, e.desc ~= '' and e.desc or e.id, DIM)
        editor.label('s' .. i, 1090, y + 26, 20, e.id, DIM)
        editor.rect('sep' .. i, 40, y + 78, 1200, 1, SEP)
      else hide_row(i) end
    end
    -- scroll indicator: arrows in the right margin when the list overflows the page
    if #entries > VISIBLE then
      editor.label('scru', 1252, CARD_TOP + 2, 24, top > 0 and '^' or '', ACCENT)
      editor.label('scrd', 1252, cardY(VISIBLE) + 48, 24,
        (top + VISIBLE) < #entries and 'v' or '', ACCENT)
    else
      editor.label('scru', 40, 900, 2, ''); editor.label('scrd', 40, 900, 2, '')
    end
  end
  local showing = #entries == 0 and '' or
    string.format('     showing %d-%d', top + 1, math.min(top + VISIBLE, #entries))
  editor.label('foot', 40, 650, 18,
    string.format('%d app%s%s', #entries, #entries == 1 and '' or 's', showing)
    .. (note ~= '' and ('     ' .. note) or ''), DIM)
end

-- ------------------------------------------------------------------ error view
-- A full-screen error page (replaces the old footer note on failure). The editor
-- owns B while a fullscreen program runs and always returns to the editor, so the
-- page offers B: back out plus X: back to the launcher menu (handled here).
local function draw_error()
  editor.screen(BG)
  editor.label('etitle', 40, 36, 40, 'App error', WARN)
  editor.rect('erule', 40, 88, 1200, 2, WARN)
  local lines = wrap(err_msg or 'unknown error', 84)
  for i = 1, 16 do
    editor.label('eln' .. i, 40, 120 + (i - 1) * 30, 22, lines[i] or '', NAME)
  end
  editor.label('eback', 40, 650, 22, 'B: back to editor      X: back to the menu', DIM)
end
local function fail(msg)
  err_msg, mode, sub, app_hb = tostring(msg), 'error', nil, nil
  draw_error()
end

-- ------------------------------------------------------------------ launch
local function launch(e)
  local src = editor.read('hbapp.' .. e.id .. '.lua')
  if not src then return fail('no source for "' .. e.id .. '"') end
  local fn, why = loadstring(src, '@hbapp.' .. e.id)
  if not fn then return fail('load failed: ' .. tostring(why)) end
  local nat = e.native and get_native() or nil   -- lazy, manifest-gated ACE
  local hb = build_sdk and build_sdk(engine, editor, nat) or nil
  local env = setmetatable({ hb = hb, engine = engine, editor = editor, print = editor.print },
    { __index = _G })
  env._G = _G; setfenv(fn, env)
  local ok, ret = pcall(fn, hb)
  if not ok then return fail(ret) end
  if type(ret) == 'function' then sub = ret
  elseif type(ret) == 'table' and type(ret.update) == 'function' then sub = ret.update
  else sub = nil end
  note, mode, app_hb = '', 'run', hb
end

-- return to the menu from a running/errored app. Re-arm the first-frame swallow so
-- the key that brought us back does not leak into the menu as a stray press.
local function to_menu()
  mode, sub, app_hb, confirm, note, primed = 'menu', nil, nil, nil, '', false
  scan(); clampsel(); draw()
end

scan(); clampsel(); draw()

return function()
  -- first frame: prime edge detection so the launch key does not leak into the menu.
  if not primed then
    primed = true
    for name in pairs(CODES) do pressed(name) end
    return
  end

  if mode == 'run' then
    if sub then
      local ok, why = pcall(sub, app_hb)
      if not ok then fail(why) end   -- an app that errors mid-run shows the error view
    end
    return
  end

  if mode == 'error' then
    -- B is intercepted by the editor (back out); X brings us back to the menu.
    if pressed('X') then to_menu() end
    return
  end

  -- menu
  local pDown, pUp = pressed('Down'), pressed('Up')
  local pX, pY, pA, pR = pressed('X'), pressed('Y'), pressed('A'), pressed('R')
  local moved = false
  -- any non-R action cancels a pending uninstall confirmation
  if confirm and (pDown or pUp or pX or pY or pA) then confirm, note, moved = nil, '', true end
  if pR and #entries > 0 then
    local e = entries[sel]
    if confirm == e.id then note = uninstall(e); confirm = nil; scan(); clampsel()
    else confirm = e.id; note = 'uninstall "' .. e.name .. '"? press R again (other keys cancel)' end
    moved = true
  end
  if pDown and sel < #entries then sel = sel + 1; clampsel(); moved = true end
  if pUp   and sel > 1          then sel = sel - 1; clampsel(); moved = true end
  if pX    then note = ''; scan(); clampsel(); moved = true end
  if pY    then note = install_staged(); scan(); clampsel(); moved = true end
  if pA and #entries > 0 then launch(entries[sel]); return end
  if moved then draw() end
end
