-- HBLauncher SDK runtime (Seedsow) -- hb.lua
--
-- The app-facing API. The launcher loads this module, builds an `hb` object, and
-- passes it to each app it opens. Apps are plain Lua and talk ONLY to `hb`, never
-- to the raw editor, so the same app source runs unchanged whether or not the
-- privileged (arbitrary code execution) layer is present.
--
-- Storage is slot-independent: apps and SDK modules live as named save files
-- (hbapp.<id>.lua, hbapp.<id>.json, hbapps.list, hb.sdk.lua, hb.exploit.lua),
-- not in the editor's numbered program slots.
--
-- Input: this editor build polls buttons with engine:isDown(<numeric keycode>)
-- (no editor.pressed/held). Codes are platform virtual-key values with the
-- engine controller-enum values as fallbacks; the SDK does its own edge detection.
--
-- Usage (inside the launcher): local build = loadstring(editor.read('hb.sdk.lua'))()
--                              local hb = build(engine, editor, native_or_nil)
-- `native` is the table returned by the exploit bootstrap, or nil when ACE is off.

local CODES = {
  A  = { 13, 258 },  B = { 27, 257 }, X = { 112, 259 }, Y = { 113, 256 },
  L  = { 116, 260 }, R = { 117, 261 },
  Up = { 38, 265 },  Down = { 40, 264 }, Left = { 37, 263 }, Right = { 39, 262 },
}

local function build(engine, editor, native)
  local hb = {}
  hb.engine  = engine
  hb.native  = native            -- privileged layer (arb R/W, base info, ...) or nil
  hb.hasACE  = native ~= nil

  -- time
  function hb.now() return engine:now() end

  -- drawing (fullscreen program surface)
  function hb.screen(color) editor.screen(color or '0xff0c1422') end
  function hb.label(id, x, y, size, value, color) editor.label(id, x, y, size, value, color) end
  function hb.rect(id, x, y, w, h, color) editor.rect(id, x, y, w, h, color) end
  hb.print = editor.print

  -- slot-independent storage (named save files)
  function hb.read(name) return editor.read(name) end
  function hb.write(name, data) return editor.write(name, data) end

  -- input: held() is the raw state, pressed() is edge-triggered (per button)
  local function is_down(name)
    for _, code in ipairs(CODES[name] or {}) do
      local ok, v = pcall(function() return engine:isDown(code) end)
      if ok and (v == true or v == 1) then return true end
    end
    return false
  end
  hb.held = is_down
  local prev = {}
  function hb.pressed(name)
    local now = is_down(name)
    local was = prev[name]; prev[name] = now
    return now and not was
  end
  function hb.resetInput() prev = {} end

  return hb
end

return build
