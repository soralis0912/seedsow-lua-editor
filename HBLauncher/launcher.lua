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

-- ------------------------------------------------------------------ input
local CODES = {
  A = { 13, 258 }, B = { 27, 257 }, X = { 112, 259 }, Y = { 113, 256 },
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
    'Up/Down select   A launch   X refresh   Y install   B editor', DIM)
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
  end
  local showing = #entries == 0 and '' or
    string.format('     showing %d-%d', top + 1, math.min(top + VISIBLE, #entries))
  editor.label('foot', 40, 650, 18,
    string.format('%d app%s%s', #entries, #entries == 1 and '' or 's', showing)
    .. (note ~= '' and ('     ' .. note) or ''), DIM)
end

-- ------------------------------------------------------------------ launch
local function launch(e)
  local src = editor.read('hbapp.' .. e.id .. '.lua')
  if not src then note = 'no source: ' .. e.id; draw(); return end
  local fn, why = loadstring(src, '@hbapp.' .. e.id)
  if not fn then note = 'load failed: ' .. tostring(why); draw(); return end
  local nat = e.native and get_native() or nil   -- lazy, manifest-gated ACE
  local hb = build_sdk and build_sdk(engine, editor, nat) or nil
  local env = setmetatable({ hb = hb, engine = engine, editor = editor, print = editor.print },
    { __index = _G })
  env._G = _G; setfenv(fn, env)
  local ok, ret = pcall(fn, hb)
  if not ok then note = 'error: ' .. tostring(ret); draw(); return end
  if type(ret) == 'function' then sub = ret
  elseif type(ret) == 'table' and type(ret.update) == 'function' then sub = ret.update
  else sub = nil end
  note, mode, app_hb = '', 'run', hb
end

scan(); clampsel(); draw()

return function()
  if mode == 'run' then
    if sub then
      local ok = pcall(sub, app_hb)
      if not ok then mode, sub, app_hb = 'menu', nil, nil; prev = {}; scan(); clampsel(); draw() end
    end
    return
  end
  local moved = false
  if pressed('Down') and sel < #entries then sel = sel + 1; clampsel(); moved = true end
  if pressed('Up')   and sel > 1          then sel = sel - 1; clampsel(); moved = true end
  if pressed('X')    then note = ''; scan(); clampsel(); moved = true end
  if pressed('Y')    then note = install_staged(); scan(); clampsel(); moved = true end
  if #entries > 0 and pressed('A') then launch(entries[sel]); return end
  if moved then draw() end
end
