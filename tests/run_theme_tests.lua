-- @license MIT (c) 2026 Scott Mills / SGM Studios — see LICENSE; kept with the script when redistributed
-- Tests for the theme generator in SGM_reaper_ultra_hd_smart_tools.lua.
--
-- The point of these is narrow and deliberate: a theme file that REAPER silently
-- ignores looks exactly like a working one, so the only useful test is against
-- the real format. tests/fixtures/theme_keys.txt is the key list from a
-- published theme, and tests/fixtures/theme_sample.ReaperTheme is a small file
-- in the real format (32-bit signed decimal values, [color theme] + [REAPER]).
--
--   lua5.4 tests/run_theme_tests.lua

package.path = "tests/?.lua;" .. package.path

local mock = require("reaper_mock")

local passed, failed = 0, 0
local function check(name, condition, detail)
  if condition then
    passed = passed + 1
    io.write("  ok   " .. name .. "\n")
  else
    failed = failed + 1
    io.write("  FAIL " .. name .. (detail and ("\n         " .. detail) or "") .. "\n")
  end
end

local SCRIPT = "SGM-Essentials/SGM_reaper_ultra_hd_smart_tools.lua"
local FIXTURE = "tests/fixtures/theme_sample.ReaperTheme"

-- Load only the pure functions; the script's main() is skipped when the test
-- host table is present.
local function load_host(r)
  _G.SGM_THEME_TEST_HOST = {}
  _G.reaper = r
  local chunk = assert(loadfile(SCRIPT))
  chunk()
  local host = _G.SGM_THEME_TEST_HOST
  _G.SGM_THEME_TEST_HOST = nil
  -- `reaper` stays bound: the methods read it at call time, exactly as they do
  -- inside REAPER where it is a real global.
  return host
end

local function fixture_lines()
  local lines = {}
  for line in io.lines(FIXTURE) do lines[#lines + 1] = line end
  return lines
end

-- ---------------------------------------------------------------------------
io.write("colour packing (the bug that made every theme a no-op)\n")
-- ---------------------------------------------------------------------------
do
  local host = load_host(mock.new())

  -- REAPER stores a colour as a signed 32-bit decimal in 0xBBGGRR order, so
  -- r=255 g=170 b=13 packs to 0x000DAAFF = 895743. These are arithmetic
  -- identities of the file format, not values copied from any theme.
  check("packs BGR order, not RGB",
    host.pack_color({ 255, 170, 13 }) == 895743,
    "got " .. tostring(host.pack_color({ 255, 170, 13 })))

  check("packs a dark surface correctly",
    host.pack_color({ 35, 35, 35 }) == 2302755,
    "got " .. tostring(host.pack_color({ 35, 35, 35 })))

  -- Values must be plain integers: a hex string is what silently did nothing.
  local v = host.pack_color({ 18, 18, 24 })
  check("returns a number, never a hex string", type(v) == "number")
  check("fits in 32 bits and stays non-negative for opaque colours",
    v >= 0 and v < 2 ^ 31)

  check("clamps out-of-range channels", host.pack_color({ -5, 300, 20 }) >= 0)
end

-- ---------------------------------------------------------------------------
io.write("contrast maths and reporting\n")
-- ---------------------------------------------------------------------------
do
  local host = load_host(mock.new())

  local white, black = { 255, 255, 255 }, { 0, 0, 0 }
  local r = host.contrast_ratio(white, black)
  check("white on black is 21:1", math.abs(r - 21) < 0.01, "got " .. r)

  local same = host.contrast_ratio({ 10, 20, 30 }, { 10, 20, 30 })
  check("identical colours are 1:1", math.abs(same - 1) < 1e-9)

  -- The shipped palette is far above the WCAG AA threshold, which is why the
  -- old "optimizer" branch could never run.
  local text, bg = host.Palette.text_primary, host.Palette.background
  local shipped = host.contrast_ratio(text, bg)
  check("shipped palette text is above AAA (7:1)",
    shipped >= 7, string.format("got %.2f:1", shipped))
end

-- ---------------------------------------------------------------------------
io.write("theme keys are real\n")
-- ---------------------------------------------------------------------------
do
  local valid = {}
  for raw in io.lines("tests/fixtures/theme_keys.txt") do
    local line = raw:match("^%s*(.-)%s*$")
    if line ~= "" and line:sub(1, 1) ~= "#" then valid[line] = true end
  end
  check("fixture has the published key list", next(valid) ~= nil)

  local host = load_host(mock.new())
  local bad = {}
  for key in pairs(host.ThemeColours) do
    if not valid[key] then bad[#bad + 1] = key end
  end
  check("every emitted key exists in a real theme",
    #bad == 0, "invented: " .. table.concat(bad, ", "))
end

-- ---------------------------------------------------------------------------
io.write("inheriting the loaded theme\n")
-- ---------------------------------------------------------------------------
do
  local r = mock.new()
  -- Write into a scratch directory instead of the real resource folder.
  r._resource_path = os.tmpname() .. "_res"
  r._os = "Darwin64"
  local host = load_host(r)

  -- A theme file in the real format, wired in as the "loaded" theme.
  r.GetLastColorThemeFile = function() return FIXTURE end

  local generator = host.ThemeGenerator:new(host.Palette)
  local colours = generator:build()
  local path, err, info = generator:write(colours)

  check("wrote a theme file", path ~= nil, tostring(err))
  if path then
    local lines = {}
    for line in io.lines(path) do lines[#lines + 1] = line end
    os.remove(path)

    check("has a [color theme] section",
      table.concat(lines, "\n"):find("%[color theme%]") ~= nil)
    check("has a [REAPER] section (fonts/ui_img) inherited from the source",
      table.concat(lines, "\n"):find("%[REAPER%]") ~= nil)
    check("does not invent a [theme] section",
      table.concat(lines, "\n"):find("%[theme%]") == nil)

    -- Every value in [color theme] must be a plain integer. (The [REAPER]
    -- section legitimately holds hex font blobs, so it is not checked here.)
    local hex_values, checked = 0, 0
    local in_colours = false
    for _, line in ipairs(lines) do
      if line:match("^%s*%[") then
        in_colours = (line:match("^%s*%[([^%]]+)%]") == "color theme")
      elseif in_colours and line:find("=") then
        checked = checked + 1
        if not line:match("^[%w_]+=[%-]?%d+$") then
          hex_values = hex_values + 1
        end
      end
    end
    check("every [color theme] value is a plain integer", hex_values == 0,
      hex_values .. " of " .. checked .. " values are not")

    check("inherited the source key count", info.total_keys > 100,
      "only " .. tostring(info.total_keys) .. " keys")
    check("replaced only the palette keys it knows",
      info.applied > 20 and info.applied < info.total_keys,
      "applied " .. tostring(info.applied))
    check("kept keys the palette has no opinion about",
      info.total_keys - info.applied > 100)

    -- Sharing: the file has to say where it came from and what is not MIT.
    local text = table.concat(lines, "\n")
    check("records which theme it was derived from",
      text:find("Derived from:", 1, true) ~= nil)
    check("states that inherited artwork keeps its own licence",
      text:find("remain under ITS licence", 1, true) ~= nil)
    check("states that the colour values are MIT",
      text:find("MIT (c) 2026", 1, true) ~= nil)
  end
end

-- ---------------------------------------------------------------------------
io.write("honest refusal\n")
-- ---------------------------------------------------------------------------
do
  local r = mock.new()
  local host = load_host(r)

  -- A .ReaperThemeZip cannot be read as text, so the script must refuse rather
  -- than write a half-theme that looks broken when loaded.
  r.GetLastColorThemeFile = function() return "/themes/Default_7.ReaperThemeZip" end
  local generator = host.ThemeGenerator:new(host.Palette)
  local path, err = generator:write(generator:build())
  check("refuses to edit a zipped theme", path == nil)
  check("explains why", tostring(err):find("ReaperThemeZip") ~= nil, tostring(err))

  -- No loaded theme at all.
  r.GetLastColorThemeFile = function() return "" end
  local path2, err2 = generator:write(generator:build())
  check("refuses when REAPER reports no theme", path2 == nil, tostring(err2))
end

-- ---------------------------------------------------------------------------
io.write("claims\n")
-- ---------------------------------------------------------------------------
do
  local src = io.open(SCRIPT):read("*a")

  check("the description no longer claims 4K",
    not src:match("@description[^\n]*4K"), "still says 4K in @description")
  check("no dpi_scale setting (a script cannot set DPI)",
    src:find("dpi_scale", 1, true) == nil)
  -- The number may only appear in the changelog that explains its removal.
  local code_only = src:gsub("%-%-[^\n]*", "")
  check("no GetToggleCommandState(1009) 'Alt key' fiction in code",
    code_only:find("1009", 1, true) == nil)
  check("declares the MIT licence", src:find("@license MIT", 1, true) ~= nil)
end

io.write(string.format("\n%d passed, %d failed\n", passed, failed))
