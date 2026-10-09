-- @description SGM Studios shared utility library
-- @author Scott Mills
-- @version 1.0.0
-- @noindex

local Utils = {}

-- String utilities
function Utils.trim(s)
  return s:match("^%s*(.-)%s*$")
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

-- Path utilities
function Utils.get_basename(path)
  local name = path:match("([^/\\]+)$")
  name = name:gsub("%.[^%.]+$", "")
  return name
end

function Utils.get_extension(path)
  return path:match("%.([^%.]+)$") or ""
end

-- JSON parser (consolidated from generate-fx-chains.lua, rule-of-30-session-builder.lua)
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
