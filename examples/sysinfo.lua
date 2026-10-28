-- sysinfo.lua -- System / Lua environment inspector
--
-- Walks everything the game actually exposes to a user Lua program and shows it
-- on screen: the Lua runtime and its heap usage, the standard libraries, the
-- game engine object and its variables, the game-provided globals (game, sys,
-- init, csv, pluto), and a full dump of _G. Scroll with Up/Down (L/R by page),
-- press B to return to the editor.
--
-- Honest about its reach: this Lua runs INSIDE Seedsow Lullaby, not in the
-- Switch OS. The game DOES report some system values (OS name, game version,
-- screen resolution, touch, the save volume) through its `game` table and
-- `engine:var`, and those are shown in the "System" section. But the real
-- Nintendo system calls -- available/total RAM via svcGetInfo, storage device
-- name and free space, firmware version, serial, the running process/title
-- list, applet/permission flags -- are NOT exposed to this sandbox and cannot
-- be read from here. This was checked empirically (see probe notes at the end).
--
-- Install later:
--   * On the console: open the editor, paste this file's text into a fresh
--     slot (Keyboard +), Save, then Publish so it survives a restart.
--   * From a PC: upload it with the Windows/Pi companion (see docs/03-send-files.md).

local ed  = editor   -- editor sandbox API (screen/label/rect/pressed/...)
local eng = engine   -- game engine object (same value as the global `e`)

-- ----------------------------------------------------------------------------
-- Report builder
-- ----------------------------------------------------------------------------
local lines = {}
local function add(fmt, ...)
  if select('#', ...) > 0 then fmt = string.format(fmt, ...) end
  lines[#lines + 1] = fmt
end
local function rule(title)
  add("")
  add("== " .. title .. " ==")
end
-- Run fn in a pcall; return its value, or nil on error. Keeps a missing API
-- from aborting the whole report.
local function safe(fn)
  local ok, v = pcall(fn)
  if ok then return v end
  return nil
end

add("Collected at engine tick %s", tostring(safe(function() return eng:now() end)))

-- System (what the game actually reports) -------------------------------------
-- These come from the game's `game` table and engine:var, not from the Switch
-- OS. They are the real values the sandbox can see.
rule("System (reported by the game)")
local gameg = rawget(_G, "game") or {}
local function gv(k)
  local v = gameg[k]
  if v == nil then return "(not reported)" end
  return tostring(v)
end
add("OS:               %s", gv("os"))
add("running on Switch: %s", gv("sw"))
add("game version:     %s", gv("ver"))
add("system version:   %s", gv("sysver"))
add("screen:           %s x %s   (render %s x %s, scale %s)",
    gv("width"), gv("height"), gv("scalewidth"), gv("scaleheight"), gv("scale"))
add("touch input:      %s", gv("touch"))
add("UI locale path:   %s", gv("uipath"))
add("save storage:     %s", tostring(safe(function() return eng:var("s.savepath") end)))
add("save slots:       %s", gv("savemax"))

-- Lua runtime -----------------------------------------------------------------
rule("Lua runtime")
add("version: %s", tostring(_VERSION))
local kb = safe(function() return collectgarbage("count") end)
if kb then
  add("Lua VM heap in use: %.1f KB (%d bytes)", kb, math.floor(kb * 1024))
  add("  (this is the game's Lua heap, NOT system RAM)")
end
local after = safe(function() collectgarbage("collect"); return collectgarbage("count") end)
if after then
  add("after a full GC:    %.1f KB", after)
end

-- Standard libraries ----------------------------------------------------------
rule("Standard libraries")
for _, name in ipairs({ "string", "table", "math", "os", "io",
                        "coroutine", "debug", "bit", "utf8", "package" }) do
  add("  %-10s %s", name, type(rawget(_G, name)))
end

-- Time / os -------------------------------------------------------------------
if type(os) == "table" then
  rule("os / time")
  local t = safe(function() return os.time() end)
  if t then add("os.time():  %s", tostring(t)) end
  local d = safe(function() return os.date("%Y-%m-%d %H:%M:%S", os.time()) end)
  if d then add("os.date():  %s", d) end
  local c = safe(function() return os.clock() end)
  if c then add("os.clock(): %s", tostring(c)) end
end

-- Game engine object ----------------------------------------------------------
rule("Game engine object (`engine` / `e`)")
add("type: %s", type(eng))
for _, m in ipairs({ "now", "var", "tag", "isDown", "getMousePoint",
                     "getTouchCount", "isFileExists", "setEventHandler",
                     "setEventFilter", "file" }) do
  local tv = "n/a"
  local ok, v = pcall(function() return eng[m] end)
  if ok then tv = type(v) end
  add("  engine.%-16s %s", m, tv)
end

-- Engine variables ------------------------------------------------------------
rule("Engine variables (engine:var)")
for _, k in ipairs({ "s.savepath", "s.saveslot.count", "s.saveslot.page",
                     "s.saveslot.last", "s.saveslot.cont" }) do
  local v = safe(function() return eng:var(k) end)
  if v ~= nil and v ~= "" then add("%s = %s", k, tostring(v)) end
end

-- Game-provided globals -------------------------------------------------------
rule("Game-provided globals")
for _, name in ipairs({ "game", "sys", "init", "csv", "pluto" }) do
  add("  %-7s %s", name, type(rawget(_G, name)))
end

local game = rawget(_G, "game")
if type(game) == "table" then
  rule("game.*")
  add("game.sw (running on Switch?): %s", tostring(game.sw))
  add("game.savemax: %s", tostring(game.savemax))
  local shown = 0
  for k, v in pairs(game) do
    if k ~= "sw" and k ~= "savemax" and shown < 12 then
      add("game.%s = %s (%s)", tostring(k), tostring(v), type(v))
      shown = shown + 1
    end
  end
end

local sysg = rawget(_G, "sys")
if type(sysg) == "table" then
  rule("sys.* (top-level keys)")
  local keys = {}
  for k in pairs(sysg) do keys[#keys + 1] = tostring(k) end
  table.sort(keys)
  local row = {}
  for i = 1, #keys do
    row[#row + 1] = keys[i]
    if #row == 4 then add("  " .. table.concat(row, ", ")); row = {} end
  end
  if #row > 0 then add("  " .. table.concat(row, ", ")) end
end

-- Editor sandbox --------------------------------------------------------------
rule("Editor sandbox (`editor` API)")
add("slot:     %s", tostring(ed.slot))
add("filename: %s", tostring(ed.filename))
add("path:     %s", tostring(ed.path))
add("base:     %s", tostring(ed.base))

-- Everything in _G ------------------------------------------------------------
rule("Everything in _G")
local names = {}
for k in pairs(_G) do names[#names + 1] = tostring(k) end
table.sort(names)
add("%d names total:", #names)
do
  local row = {}
  for i = 1, #names do
    row[#row + 1] = names[i]
    if #row == 4 then add("  " .. table.concat(row, ", ")); row = {} end
  end
  if #row > 0 then add("  " .. table.concat(row, ", ")) end
end

-- What this sandbox cannot see ------------------------------------------------
rule("Not reachable from here (probed)")
add("Checked empirically: the engine's metatable __index is a native")
add("function (hidden methods can't be listed), engine:var only returns")
add("'s.savepath', os.getenv returns nil, and the game globals carry no")
add("device fields. So the Switch OS is NOT exposed to this sandbox:")
add("  - available / total system RAM (svcGetInfo)")
add("  - storage device name and free space (only the 'save:' mount)")
add("  - firmware version, console serial, region")
add("  - the running process / title list")
add("  - applet capability & permission flags")
add("The memory figure above is the game's Lua heap only. Getting any of")
add("the above would need a sandbox escape into native code.")

-- ----------------------------------------------------------------------------
-- Screen + scrolling
-- ----------------------------------------------------------------------------
local VISIBLE = 16
local TOP     = 92
local STEP    = 32

ed.screen("0xff0a1626")
ed.label("title", 40, 28, 34, "SYSTEM / LUA ENVIRONMENT INSPECTOR")

local offset = 0
local maxoff = math.max(0, #lines - VISIBLE)
local dirty  = true

local function clamp()
  if offset < 0 then offset = 0 end
  if offset > maxoff then offset = maxoff end
end

local function draw()
  for i = 1, VISIBLE do
    ed.label("l" .. i, 40, TOP + (i - 1) * STEP, 24, lines[offset + i] or "")
  end
  ed.label("foot", 40, TOP + VISIBLE * STEP + 8, 22,
    string.format("Up/Down scroll   L/R page   lines %d-%d of %d   B: editor",
      offset + 1, math.min(offset + VISIBLE, #lines), #lines))
end

return function(e, api)
  if api.pressed("Down") then offset = offset + 1;       clamp(); dirty = true end
  if api.pressed("Up")   then offset = offset - 1;       clamp(); dirty = true end
  if api.pressed("R")    then offset = offset + VISIBLE; clamp(); dirty = true end
  if api.pressed("L")    then offset = offset - VISIBLE; clamp(); dirty = true end
  if dirty then draw(); dirty = false end
end
