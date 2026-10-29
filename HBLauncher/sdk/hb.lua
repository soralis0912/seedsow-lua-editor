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

  -- named colors: the launcher palette as '0xffRRGGBB' constants apps can reuse so
  -- every app looks at home next to the launcher without hardcoding hex everywhere.
  hb.color = {
    bg     = '0xff0c1422',   -- background
    sep    = '0xff22324a',   -- separators / rules (use in gaps; rects draw over text)
    accent = '0xff3f7bd6',   -- accent / cursor
    dim    = '0xff93a6c0',   -- secondary text
    name   = '0xffeef3fb',   -- primary text
    hot    = '0xff9fc6ff',   -- highlighted text
    ok     = '0xff6fd08a',   -- success
    warn   = '0xffd0a86f',   -- warning
    bad    = '0xffd08a6f',   -- error
  }

  -- wrap: break text into a table of lines, each at most maxchars wide. Word-aware,
  -- and hard-splits any single word longer than the limit. maxchars defaults to 72.
  function hb.wrap(text, maxchars)
    text = tostring(text or ''); maxchars = maxchars or 72
    if maxchars < 1 then maxchars = 1 end
    local out, line = {}, ''
    for word in text:gmatch('%S+') do
      while #word > maxchars do                     -- a word wider than a whole line
        if line ~= '' then out[#out + 1] = line; line = '' end
        out[#out + 1] = word:sub(1, maxchars); word = word:sub(maxchars + 1)
      end
      if line == '' then line = word
      elseif #line + 1 + #word <= maxchars then line = line .. ' ' .. word
      else out[#out + 1] = line; line = word end
    end
    if line ~= '' then out[#out + 1] = line end
    if #out == 0 then out[1] = '' end
    return out
  end

  -- lines: draw a table of strings as stacked labels sharing an id prefix
  -- (idPrefix1, idPrefix2, ...). Returns the y just past the last line, so callers
  -- can keep stacking. Pairs naturally with hb.wrap for multi-line text.
  function hb.lines(idPrefix, x, y, size, linesTable, color)
    size = size or 20
    local step = math.floor(size * 1.35 + 0.5)
    linesTable = linesTable or {}
    for i = 1, #linesTable do
      editor.label(idPrefix .. i, x, y + (i - 1) * step, size, tostring(linesTable[i]), color)
    end
    return y + #linesTable * step
  end

  -- safe: pcall wrapper. Returns ok, result (or ok, errormessage). Handy for guarding
  -- native reads or any call that might throw without stopping the whole app.
  function hb.safe(fn, ...)
    return pcall(fn, ...)
  end

  return hb
end

return build
