-- @description SGM Studios shared utility library
-- @author Scott Mills
-- @license MIT (c) 2026 Scott Mills / SGM Studios — see LICENSE; kept with the script when redistributed
-- @version 1.1.0
-- @noindex
-- @changelog
--   1.1.0 (2026-11-07)
--     + Add: Utils.load() - every SGM script that needs this library now finds
--       it the same way (own folder, sibling bundle, then the REAPER resource
--       root) instead of each file carrying its own copy of the search list.
--       Uses get_action_context, falling back to a caller-supplied path,
--       because debug.getinfo source is unreliable when a script is wrapped.
--     + Add: Utils.scriptDirectory() so callers can locate sibling files
--       (plugin inventories, preset tables) the same way.
--     + Add: Utils.dbg() gated debug output, used by the bundled scripts.
--   1.0.1 (2026-11-07)
--     + Fix: trim() used "(.-)" (not a Lua pattern) and always returned ""
--     + Doc: JSON.parse is a small number/string/array/object parser, not a
--       full JSON implementation
--   1.0.0 (2026-05-23)
--     + Initial release

local Utils = {}

Utils.VERSION = "1.1.0"

-- Where the calling script lives. Tries get_action_context first: it is the
-- documented way to find your own script path, and it is the only one that
-- survives being run through a wrapper (debug.getinfo's `source` can come back
-- as "=[C]"). `fallback` is the caller's own best guess, usually debug.getinfo.
function Utils.scriptDirectory(fallback)
  local ok, _, script_filename = pcall(reaper.get_action_context)
  if ok and type(script_filename) == "string" and script_filename ~= "" then
    local dir = script_filename:match("^(.*[/\\])")
    if dir then return dir end
  end
  local path = tostring(fallback or ""):gsub("^@", "")
  return path:match("^(.*[/\\])") or ""
end

-- Load SGM_Utils from wherever it happens to be installed.
--
-- Call this *before* you have the library: it is deliberately a 0-dependency
-- loader that cannot itself rely on Utils. Returns the library table, or nil
-- plus nothing so the caller can fall back to its own helpers.
function Utils.load(fallback_dir)
  local candidates = {}
  local function add(dir)
    if type(dir) == "string" and dir ~= "" then
      candidates[#candidates + 1] = dir .. "SGM_Utils.lua"
      candidates[#candidates + 1] = dir .. "../SGM-Essentials/SGM_Utils.lua"
    end
  end

  add(Utils.scriptDirectory(fallback_dir))

  local ok, resource = pcall(reaper.GetResourcePath)
  if ok and type(resource) == "string" then
    add(resource .. "/Scripts/SGM Studios/SGM-Essentials/")
    add(resource .. "/Scripts/SGM Studios/Rule-of-30/")
    add(resource .. "/Scripts/SGM_Scripts/SGM-Essentials/")
    add(resource .. "/Scripts/SGM_Scripts/Rule-of-30/")
    add(resource .. "/Scripts/SGM Studios/")
    add(resource .. "/Scripts/SGM_Scripts/")
  end

  for _, path in ipairs(candidates) do
    local chunk = loadfile(path)
    if chunk then
      local loaded, lib = pcall(chunk)
      if loaded and type(lib) == "table" then return lib, path end
    end
  end
  return nil, nil
end

-- String utilities
-- NOTE: Lua patterns have no '-' (non-greedy) repetition, so the old
-- "^%s*(.-)%s*$" returned an EMPTY string for any input. Use gsub instead.
function Utils.trim(s)
  return (tostring(s):gsub("^%s+", ""):gsub("%s+$", ""))
end

-- Math utilities
function Utils.clamp(v, lo, hi)
  return math.max(lo, math.min(hi, v))
end

function Utils.db_to_linear(db)
  return 10 ^ (db / 20)
end

function Utils.linear_to_db(lin)
  return (lin > 0) and (20 * math.log(lin, 10)) or -math.huge
end

-- REAPER color utilities
function Utils.native_color(rgb)
  local r = (rgb >> 16) & 0xFF
  local g = (rgb >>  8) & 0xFF
  local b =  rgb        & 0xFF
  return reaper.ColorToNative(r, g, b) | 0x1000000
end

-- Platform utilities
function Utils.is_windows()
  return reaper.GetOS():find("Win") ~= nil
end

function Utils.dir_sep()
  return Utils.is_windows() and "\\" or "/"
end

-- Console output utility (consolidated from 10+ scripts)
function Utils.msg(m)
  reaper.ShowConsoleMsg(tostring(m) .. "\n")
end

-- FX parameter helpers -------------------------------------------------------
-- TrackFX_SetParam takes a NORMALIZED 0..1 value; passing 10 for a 10 ms attack
-- sets something else entirely. Plug-ins print their own value for a given
-- normalized position via TrackFX_FormatParamValueNormalized, so the mapping can
-- be inverted numerically instead of guessed per plug-in.
local function first_number(text)
  if type(text) ~= "string" then return nil end
  return tonumber(text:match("[-+]?%d*%.?%d+"))
end

-- Returns the normalized position matching `engineering` (in the plug-in's
-- displayed units), or nil when the plug-in will not format that parameter or
-- the target is outside the reachable range. Callers must treat nil as "skip
-- this setting and say so" - writing a guess is worse than writing nothing.
function Utils.fx_normalize(track, fx, param, engineering)
  if type(engineering) ~= "number" then return nil end
  if not reaper.TrackFX_FormatParamValueNormalized then return nil end

  local function value_at(n)
    -- Returns (retval, buf): two values, not three. Destructuring three
    -- silently yields nil for the text and makes every conversion fail.
    local ok, text = reaper.TrackFX_FormatParamValueNormalized(
      track, fx, param, n, "", 64)
    if not ok then return nil end
    return first_number(text)
  end

  local low, high = 0, 1
  local v_low, v_high = value_at(low), value_at(high)
  if not v_low or not v_high then return nil end
  if v_low == v_high then return nil end          -- parameter ignores position
  local increasing = v_high > v_low
  local min_v, max_v = math.min(v_low, v_high), math.max(v_low, v_high)
  -- Tolerance: the plug-in prints a rounded number, so compare loosely.
  local tol = math.max(math.abs(max_v - min_v) * 1e-4, 1e-6)
  if engineering < min_v - tol or engineering > max_v + tol then return nil end

  -- 60 halvings takes a 0..1 interval well below any printed precision.
  for _ = 1, 60 do
    local mid = (low + high) / 2
    local v_mid = value_at(mid)
    if not v_mid then return nil end
    local diff = v_mid - engineering
    if math.abs(diff) <= tol then return mid end
    if (diff < 0) == increasing then low = mid else high = mid end
  end
  return (low + high) / 2
end

-- Debug output, silent unless the caller turns it on.
function Utils.dbg(m, enabled)
  if enabled then Utils.msg(tostring(m)) end
end

-- Path utilities
function Utils.get_basename(path)
  local name = path:match("([^/\\]+)$")
  name = name:gsub("%.[^%.]+$", "")
  return name
end

function Utils.get_extension(path)
  return path:match("%.([^%.]+)$") or ""
end

-- JSON parser (same dialect as the one inlined in the Rule of 30 session builder).
-- NOTE: numbers only; this is not a general-purpose JSON library.
Utils.JSON = {}
function Utils.JSON.parse(s)
  local i = 1
  local function parse_value()
    local char = s:sub(i,i)
    if not char or char == "" then return nil end
    if char == '{' then
      i = i + 1
      local res = {}
      while true do
        while s:sub(i,i):match('%s') do i = i + 1 end
        if s:sub(i,i) == '}' then i = i + 1 break end
        local key = s:match('^%s*"([^"]+)"%s*:', i)
        if key then
          i = i + #s:match('^%s*"[^"]+"%s*:', i)
          res[key] = parse_value()
        end
        while s:sub(i,i):match('%s') do i = i + 1 end
        if s:sub(i,i) == ',' then i = i + 1 end
      end
      return res
    elseif char == '[' then
      i = i + 1
      local res = {}
      while true do
        while s:sub(i,i):match('%s') do i = i + 1 end
        if s:sub(i,i) == ']' then i = i + 1 break end
        table.insert(res, parse_value())
        while s:sub(i,i):match('%s') do i = i + 1 end
        if s:sub(i,i) == ',' then i = i + 1 end
      end
      return res
    elseif char == '"' then
      local val = s:match('^"([^"]*)"', i)
      i = i + (val and #val + 2 or 1)
      return val
    elseif s:match('^[%d%.%-]+', i) then
      local val = s:match('^[%d%.%-]+', i)
      i = i + #val
      return tonumber(val)
    elseif s:match('^true', i) then i = i + 4 return true
    elseif s:match('^false', i) then i = i + 5 return false
    elseif s:match('^null', i) then i = i + 4 return nil
    end
    i = i + 1
    return nil
  end
  return parse_value()
end

-- Stem classification (unified from Suno_ZIP_Importer, Suno_01, Suno_05)
Utils.STEM_RULES = {
  { pattern = "no[_%-]?drums?",    label = "No Drums",     color = 0xE84444 },
  { pattern = "no[_%-]?bass",      label = "No Bass",      color = 0x4455E8 },
  { pattern = "no[_%-]?vocals?",   label = "No Vocals",    color = 0xE83A7A },
  { pattern = "instrumental",      label = "Instrumental", color = 0x3A8FE8 },
  { pattern = "vocals?",           label = "Vocals",       color = 0xE83A7A },
  { pattern = "drums?",            label = "Drums",        color = 0xE84444 },
  { pattern = "bass",              label = "Bass",         color = 0x4455E8 },
  { pattern = "guitar",            label = "Guitar",       color = 0x44CC55 },
  { pattern = "piano",             label = "Piano",        color = 0xAA44EE },
  { pattern = "strings?",          label = "Strings",      color = 0x44EEEE },
  { pattern = "other",             label = "Other",        color = 0xEEAA33 },
}

function Utils.classify_stem(filename_lower)
  for _, rule in ipairs(Utils.STEM_RULES) do
    if filename_lower:match(rule.pattern) then
      return rule.label, rule.color
    end
  end
  return nil, nil
end

-- REAPER track utilities
function Utils.create_track(name)
  local idx = reaper.CountTracks(0)
  reaper.InsertTrackAtIndex(idx, false)
  local track = reaper.GetTrack(0, idx)
  reaper.GetSetMediaTrackInfo_String(track, "P_NAME", name, true)
  return track
end

function Utils.set_track_color(track, rgb)
  local r = (rgb >> 16) & 0xFF
  local g = (rgb >>  8) & 0xFF
  local b =  rgb        & 0xFF
  reaper.SetTrackColor(track, reaper.ColorToNative(r, g, b) | 0x1000000)
end

-- File I/O utilities
function Utils.read_all_text(path)
  local file = io.open(path, "r")
  if not file then return nil end
  local content = file:read("*all")
  file:close()
  return content
end

function Utils.write_all_text(path, content)
  local file = io.open(path, "w")
  if not file then return false end
  file:write(content)
  file:close()
  return true
end

return Utils
