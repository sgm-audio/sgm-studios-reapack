-- @description Build a 48-track industrial/heavy metal session: Drop Bb, 95-110 BPM, massive density
-- @author Scott Mills
-- @version 2.0.0
-- @changelog
--   2.0.0 (2026-11-07)
--     + Fix (fatal): SetTempoTimeSigMarker() takes 9 arguments and was called
--       with 8, so the tempo landed in the beatpos slot — every session built at
--       ~4 BPM with a 95/110 time signature. The tempo is now read back with
--       Master_GetTempo() and the build aborts if it did not take.
--     + Fix: plugin chains duplicating. TrackFX_AddByName(..., -1) inserts a new
--       instance every run, so options 2-5 three times gave three chains. Chains
--       now skip an FX the track already has.
--     + Fix: the master FX chain stacked a new ReaComp + ReaEQ on every build.
--     + Add: the Rule of 30 preset library (rule-of-30-plugin-presets.lua) is now
--       actually used — options 2-5 apply real stock-FX settings by parameter
--       name, instead of adding bare plugins with no configuration.
--     + Add: SGM_Utils is used when installed (shared trim/db/clamp helpers).
--     + Add: every chain action reports which plugins it skipped or could not find.
--     + Fix: the console claimed "Added chain: X" even when TrackFX_AddByName
--       returned -1.
--   1.0.2 (2026-11-07)
--     + Fix (fatal): the plugin-aware builder called the `addFX` local before it
--       was declared, so "Build Session" with Compact Mode off raised
--       "attempt to call a nil value (global 'addFX')"
--     + Fix (fatal): CreateTrackSend() can return -1; the send volume/channel
--       setters then errored on a nil send
--     + Fix: the master track is no longer stripped of its master/parent send
--     + Fix: the plugin inventory is read from the directory the script actually
--       lives in (was hard-coded to the REAPER resource root)
--     + Fix: the sidechain send now reuses an existing Kick Out -> Bass send
--       instead of stacking a new one on every run
--     + Fix: an existing tempo/time-signature marker is used instead of adding one
--     + Fix: "Close" (7) is now handled; it used to fall through with no feedback
--     + Fix: sidechain sends reuse an existing Kick Out -> Bass send, guarded
--       against CreateTrackSend() returning -1
--     + Removed: unused helper parameters and dead locals
--   1.0.1 (2026-10-08)
--     + Top Shelf audit: undo + PreventUIRefresh on all six actions
--     + Top Shelf audit: replace gfx.showmenu with GetUserInputs
--   1.0.0 (2026-05-23)
--     + Initial release
--     + 48+ track template: quad guitars, double bass, full drum kit, orchestral layers
--     + Drop Bb tuning, 95-110 BPM range
--     + Bus architecture with parallel compression sends
-- @provides
--   [main] rule-of-30-session-builder.lua
--   [nomain] rule-of-30-plugin-presets.lua
-- @about
--   ## Rule of 30 Session Builder
--   Builds a professional heavy industrial/metal session template. Drop Bb tuning.
--
--   **Plugin inventory (optional):** if a file called `plugin_inventory.json`
--   exists next to this script (or in the REAPER resource folder) it is used to
--   pick "best" plug-ins per category. The JSON must look like:
--   `{"by_category": {"EQ": ["ReaEQ", ...], "Dynamics": ["ReaComp", ...]}}`
--   Without it the builder just creates the track skeleton with stock FX.
--
--   **Compact Mode:** when ON (default), tracks whose category has no matching
--   plug-in are skipped entirely. Toggle it with menu option 0.
-- RULE OF 30 SESSION BUILDER
-- Professional 48+ Track Industrial/Heavy Metal Session Template
-- Drop Bb Tuning | 95-110 BPM | Massive Density Production
-- Version 1.0

reaper.ClearConsole()
reaper.ShowConsoleMsg("=== RULE OF 30 SESSION BUILDER ===\n\n")

-- ===================================
-- SHARED LIBRARIES
-- ===================================
-- SGM_Utils (SGM-Essentials bundle) and the Rule of 30 presets ship next to this
-- script. Both look in the script's own directory first, then in the layout a
-- ReaPack install produces, so the builder works whether it was installed from
-- ReaPack or copied by hand.
-- Where this file lives, so the shared libraries can be found next to it.
-- get_action_context is authoritative inside REAPER; the trailing
-- `select(2, ...)` from pcall is what actually carries the filename, and
-- debug.getinfo is only a fallback because its `source` is unreliable when a
-- script is loaded by a wrapper (it can come back as "=[C]").
local function scriptDirectory()
  local ok, _, script_filename = pcall(reaper.get_action_context)
  if ok and type(script_filename) == "string" and script_filename ~= "" then
    local dir = script_filename:match("^(.*[/\\])")
    if dir then return dir end
  end
  local info_ok, source = pcall(debug.getinfo, 1, "S")
  local path = info_ok and source and source.source or ""
  return (path:gsub("^@", "")):match("^(.*[/\\])") or ""
end

-- Bootstrapping SGM_Utils has to happen by path (we do not have the library
-- yet); everything after that goes through it.
local function bootstrapUtils()
  local dir = scriptDirectory()
  local resource = reaper.GetResourcePath()
  local candidates = {
    dir .. "SGM_Utils.lua",
    dir .. "../SGM-Essentials/SGM_Utils.lua",
    resource .. "/Scripts/SGM Studios/SGM-Essentials/SGM_Utils.lua",
    resource .. "/Scripts/SGM_Scripts/SGM-Essentials/SGM_Utils.lua",
  }
  for _, path in ipairs(candidates) do
    local chunk = loadfile(path)
    if chunk then
      local ok, lib = pcall(chunk)
      if ok and type(lib) == "table" then return lib, path end
    end
  end
  return nil, nil
end

local Utils = bootstrapUtils()

-- Locate a library that ships next to this script or in either bundle folder.
local function loadLibrary(filename)
  local dir = scriptDirectory()
  local resource = reaper.GetResourcePath()
  local candidates = {
    dir .. filename,
    resource .. "/Scripts/SGM Studios/Rule-of-30/" .. filename,
    resource .. "/Scripts/SGM Studios/SGM-Essentials/" .. filename,
    resource .. "/Scripts/SGM_Scripts/Rule-of-30/" .. filename,
    resource .. "/Scripts/SGM_Scripts/SGM-Essentials/" .. filename,
  }
  for _, path in ipairs(candidates) do
    local chunk = loadfile(path)
    if chunk then
      local ok, lib = pcall(chunk)
      if ok and type(lib) == "table" then return lib, path end
    end
  end
  return nil, nil
end

-- Use the library's own loader when we have it, so the search order is shared.
local utils_path
if Utils and Utils.load then
  local lib, path = Utils.load(scriptDirectory())
  if lib then Utils, utils_path = lib, path end
end

local Presets, presets_path = loadLibrary("rule-of-30-plugin-presets.lua")

-- The preset library needs fx_normalize() to turn "-18 dB" into a 0..1 value.
if Presets then Presets.Utils = Utils end

local function msg(text)
  if Utils and Utils.msg then return Utils.msg(text) end
  reaper.ShowConsoleMsg(tostring(text) .. "\n")
end

reaper.ShowConsoleMsg(Utils and "Shared library: SGM_Utils loaded\n"
  or "Shared library: SGM_Utils not found (using local fallbacks)\n")
reaper.ShowConsoleMsg(Presets and ("Presets: " .. tostring(presets_path) .. "\n")
  or "Presets: rule-of-30-plugin-presets.lua not found (chains will add bare plugins)\n")
reaper.ShowConsoleMsg("\n")

-- ===================================
-- CONFIGURATION
-- ===================================

local CONFIG = {
  project_name = "Rule of 30 - Heavy Session",
  tuning = "Drop Bb (Bb-F-Bb-Eb-G-C)",
  bpm = 100,  -- You can change to 95-110 range
  sample_rate = 48000,
  time_signature_num = 4,
  time_signature_den = 4,

  -- Color scheme (RGB in REAPER format)
  colors = {
    drums = reaper.ColorToNative(255, 69, 0)|0x1000000,      -- Red-Orange
    bass = reaper.ColorToNative(0, 100, 255)|0x1000000,      -- Blue
    guitars = reaper.ColorToNative(139, 0, 0)|0x1000000,     -- Dark Red
    vocals = reaper.ColorToNative(255, 215, 0)|0x1000000,    -- Gold
    fx_glitch = reaper.ColorToNative(128, 0, 128)|0x1000000, -- Purple
    ambient = reaper.ColorToNative(0, 128, 128)|0x1000000,   -- Teal
    bus = reaper.ColorToNative(50, 50, 50)|0x1000000,        -- Dark Gray
    master = reaper.ColorToNative(255, 255, 255)|0x1000000   -- White
  },
  compact_mode = true, -- If true, skip tracks with no found plugins
  inventory = nil
}

-- ===================================
-- PLUGIN AWARENESS UTILITIES
-- ===================================

-- ===================================
-- MINIMAL JSON PARSER
-- ===================================
-- Only needed for the optional plugin inventory file. Handles objects, arrays,
-- strings (with \\ escapes), numbers, booleans and null.
local JSON = {}

local function json_skip_ws(s, i)
  local _, last = s:find("^%s*", i)
  return (last or i - 1) + 1
end

local function json_decode(s, i)
  i = json_skip_ws(s, i)
  local c = s:sub(i, i)

  if c == "{" then
    local res = {}
    i = json_skip_ws(s, i + 1)
    if s:sub(i, i) == "}" then return res, i + 1 end
    while true do
      i = json_skip_ws(s, i)
      local key, next_i = json_decode(s, i)
      if type(key) ~= "string" then return nil, i end
      i = json_skip_ws(s, next_i)
      if s:sub(i, i) ~= ":" then return nil, i end
      local value
      value, i = json_decode(s, i + 1)
      res[key] = value
      i = json_skip_ws(s, i)
      local sep = s:sub(i, i)
      if sep == "," then i = i + 1
      elseif sep == "}" then return res, i + 1
      else return nil, i end
    end

  elseif c == "[" then
    local res = {}
    i = json_skip_ws(s, i + 1)
    if s:sub(i, i) == "]" then return res, i + 1 end
    while true do
      local value
      value, i = json_decode(s, i)
      res[#res + 1] = value
      i = json_skip_ws(s, i)
      local sep = s:sub(i, i)
      if sep == "," then i = i + 1
      elseif sep == "]" then return res, i + 1
      else return nil, i end
    end

  elseif c == '"' then
    local out, j = {}, i + 1
    while j <= #s do
      local ch = s:sub(j, j)
      if ch == "\\" then
        local esc = s:sub(j + 1, j + 1)
        local map = { n = "\n", t = "\t", r = "\r", b = "\b", f = "\f" }
        out[#out + 1] = map[esc] or esc
        j = j + 2
      elseif ch == '"' then
        return table.concat(out), j + 1
      else
        out[#out + 1] = ch
        j = j + 1
      end
    end
    return nil, j

  elseif s:sub(i, i + 3) == "true" then
    return true, i + 4
  elseif s:sub(i, i + 4) == "false" then
    return false, i + 5
  elseif s:sub(i, i + 3) == "null" then
    return nil, i + 4
  else
    local num = s:match("^-?%d+%.?%d*[eE]?[-+]?%d*", i)
    if num and num ~= "" then
      return tonumber(num), i + #num
    end
    return nil, i
  end
end

function JSON.parse(str)
  if type(str) ~= "string" then return nil end
  local value = json_decode(str, 1)
  return value
end

-- Locate plugin_inventory.json: next to this script first, then the REAPER
-- resource root (legacy location), so it works however ReaPack laid the files out.
local function findInventoryPath()
  local candidates = {}
  local function add(dir)
    if dir and dir ~= "" then
      candidates[#candidates + 1] = dir .. "/plugin_inventory.json"
    end
  end

  local ok, _, script_filename = pcall(reaper.get_action_context)
  if ok and type(script_filename) == "string" then
    add(script_filename:match("^(.*)[/\\]"))
  end
  add(reaper.GetResourcePath())
  return candidates
end

local function loadPluginInventory()
  for _, inventory_path in ipairs(findInventoryPath()) do
    local file = io.open(inventory_path, "r")
    if file then
      local content = file:read("*all")
      file:close()

      local ok, inventory = pcall(JSON.parse, content)
      if not ok or type(inventory) ~= "table" then
        reaper.ShowConsoleMsg("Warning: could not parse " .. inventory_path .. " (ignoring).\n")
        return nil
      end

      CONFIG.inventory = inventory
      return inventory
    end
  end

  reaper.ShowConsoleMsg("Note: no plugin_inventory.json found — building the track skeleton only.\n")
  reaper.ShowConsoleMsg("      Expected format: {\"by_category\": {\"EQ\": [\"ReaEQ\"], ...}}\n")
  return nil
end

local function getBestPlugin(category, keywords)
  if not CONFIG.inventory then return nil end
  local by_category = CONFIG.inventory.by_category
  if type(by_category) ~= "table" or type(by_category[category]) ~= "table" then return nil end
  local list = by_category[category]
  if #list == 0 then return nil end

  if not keywords or #keywords == 0 then return list[1] end

  -- Try to match keywords
  for _, kw in ipairs(keywords) do
    for _, plugin in ipairs(list) do
      if type(plugin) == "string" and plugin:lower():find(kw:lower(), 1, true) then
        return plugin
      end
    end
  end

  return list[1] -- Fallback to first in category
end

-- Defined before addSmartFX so the plugin-aware builder can call it.
-- Idempotent: instantiate = -1 inserts a NEW instance every call, which is how
-- running "Drum Chains" three times produced three chains. Check first.
local function addFX(track, fx_name)
  local existing = reaper.TrackFX_AddByName(track, fx_name, false, 0)
  if existing and existing >= 0 then
    return existing, false
  end
  local fx_index = reaper.TrackFX_AddByName(track, fx_name, false, -1)
  if not fx_index or fx_index < 0 then
    msg("  ! could not add " .. fx_name .. " (not installed?)")
    return nil, false
  end
  return fx_index, true
end

local function addSmartFX(track, category, keywords)
  local plugin = getBestPlugin(category, keywords)
  if not plugin then return false end
  local _, added = addFX(track, plugin)
  return added
end

-- Apply the Rule of 30 preset for a track name (if the presets file loaded).
-- Returns the number of plugins actually added and a list of the ones skipped
-- because they were already there. Reports anything that would not resolve —
-- a preset that silently does nothing is worse than no preset.
local function applyChain(track, label, chain)
  if not chain then return 0, {} end
  -- The preset library owns the mapping (engineering value -> 0..1) because it
  -- also owns the values, and it reports anything it could not set.
  local added, skipped, problems = Presets.apply(track, label, chain, addFX)
  for _, problem in ipairs(problems) do
    msg("      ! " .. problem)
  end
  return added, skipped
end

-- Preset for a track name, if one is defined for it.
local function applyPreset(track, track_name)
  if not Presets then return 0, {} end
  return applyChain(track, track_name, Presets.forTrack(track_name))
end

-- ===================================
-- UTILITY FUNCTIONS
-- ===================================

local function createTrack(name, color)
  local track_index = reaper.CountTracks(0)
  reaper.InsertTrackAtIndex(track_index, true)
  local track = reaper.GetTrack(0, track_index)

  reaper.GetSetMediaTrackInfo_String(track, "P_NAME", name, true)

  if color then
    reaper.SetTrackColor(track, color)
  end

  return track
end

local function createSmartTrack(name, color, category, keywords)
  if CONFIG.compact_mode then
    local plugin = getBestPlugin(category, keywords)
    if not plugin then 
      reaper.ShowConsoleMsg("  Skipping track (no " .. category .. " in the plugin inventory): " .. name .. "\n")
      reaper.ShowConsoleMsg("  ⚠ Menu option 0 turns Compact Mode off to build the full skeleton\n")
      return nil 
    end
  end
  
  local track = createTrack(name, color)
  if category then
    addSmartFX(track, category, keywords)
  end
  return track
end

local function createFolder(name, color)
  local track = createTrack(name, color)
  reaper.SetMediaTrackInfo_Value(track, "I_FOLDERDEPTH", 1)
  reaper.SetMediaTrackInfo_Value(track, "I_FOLDERCOMPACT", 0)
  return track
end

local function closeFold()
  local last_track_idx = reaper.CountTracks(0) - 1
  local last_track = reaper.GetTrack(0, last_track_idx)
  if last_track then
    reaper.SetMediaTrackInfo_Value(last_track, "I_FOLDERDEPTH", -1)
  end
end

-- Returns the new send index, or nil when REAPER refused to create the send.
local function createSend(source_track, dest_track, volume_db, send_mode)
  local send_index = reaper.CreateTrackSend(source_track, dest_track)
  if not send_index or send_index < 0 then
    return nil
  end

  -- Convert dB to volume (0dB = 1.0)
  local volume = 10^((volume_db or 0)/20)
  reaper.SetTrackSendInfo_Value(source_track, 0, send_index, "D_VOL", volume)

  if send_mode then
    reaper.SetTrackSendInfo_Value(source_track, 0, send_index, "I_SENDMODE", send_mode)
  end

  return send_index
end

local function findSendIndex(source_track, dest_track)
  for i = 0, reaper.GetTrackNumSends(source_track, 0) - 1 do
    if reaper.GetTrackSendInfo_Value(source_track, 0, i, "P_DESTTRACK") == dest_track then
      return i
    end
  end
  return nil
end

local function setPan(track, pan_value)
  -- Pan: -1 = left, 0 = center, 1 = right
  reaper.SetMediaTrackInfo_Value(track, "D_PAN", pan_value)
end

local function setVolume(track, volume_db)
  local volume = 10^(volume_db/20)
  reaper.SetMediaTrackInfo_Value(track, "D_VOL", volume)
end

-- ===================================
-- SESSION BUILDER CORE
-- ===================================

local function beginUndo()
  reaper.Undo_BeginBlock()
  reaper.PreventUIRefresh(1)
end

local function endUndo(action_name)
  reaper.PreventUIRefresh(-1)
  reaper.Undo_EndBlock(action_name, -1)
  reaper.UpdateArrange()
end

-- Builds the session structure. Undo/UI-refresh is owned by the caller, so
-- every exit path (including the tempo guard below) leaves the block open for
-- the caller to close exactly once.
local function buildRuleOf30Session()

  -- Set project properties
  reaper.GetSetProjectInfo(0, "PROJECT_SRATE", CONFIG.sample_rate, true)
  reaper.GetSetProjectInfo(0, "PROJECT_TIMEBASE", 1, true)  -- Time base: beats

  -- Tempo: update the first tempo marker if one exists, otherwise create it.
  -- SetTempoTimeSigMarker(..., -1, -1, ...) inserts a *new* marker at the edit
  -- cursor every run, which frees the tempo map instead of setting the project tempo.
  -- SetTempoTimeSigMarker(proj, ptidx, timepos, measurepos, beatpos, bpm,
  --                       timesig_num, timesig_denom, lineartempo)
  -- Nine arguments. Passing eight shifts bpm into beatpos and leaves bpm at 0,
  -- which is how every previous build came out at ~4 BPM.
  local tempo_set
  if reaper.CountTempoTimeSigMarkers(0) > 0 then
    tempo_set = reaper.SetTempoTimeSigMarker(0, 0, -1, -1, -1, CONFIG.bpm,
      CONFIG.time_signature_num, CONFIG.time_signature_den, false)
  else
    tempo_set = reaper.SetTempoTimeSigMarker(0, -1, 0, -1, -1, CONFIG.bpm,
      CONFIG.time_signature_num, CONFIG.time_signature_den, true)
  end

  -- Do not trust the return value alone: read the tempo back and refuse to
  -- build a 53-track session at the wrong speed.
  local actual_bpm = reaper.Master_GetTempo()
  if not tempo_set or math.abs(actual_bpm - CONFIG.bpm) > 0.5 then
    msg(string.format("❌ Could not set the project tempo (asked for %.1f BPM, REAPER reports %.1f).",
      CONFIG.bpm, actual_bpm))
    msg("   Nothing was built. Move the edit cursor or remove tempo markers and retry.")
    return false
  end
  msg(string.format("Tempo set to %.1f BPM (%d/%d)", actual_bpm,
    CONFIG.time_signature_num, CONFIG.time_signature_den))

  reaper.ShowConsoleMsg("Building session structure...\n")
  
  loadPluginInventory()
  
  -- ===================================
  -- I. DRUM SECTION (Tracks 1-12)
  -- ===================================

  reaper.ShowConsoleMsg("  [1/7] Building Drum Section...\n")

  local drum_folder = createFolder("🥁 DRUMS (TITAN BUS)", CONFIG.colors.drums)

  -- Kick Folder (3 tracks)
  local kick_folder = createFolder("  ├─ KICK", CONFIG.colors.drums)
  local kick_in = createSmartTrack("    ├─ Kick In (Click)", CONFIG.colors.drums, "Dynamics", {"Gate", "Comp"})
  local kick_out = createSmartTrack("    ├─ Kick Out (Body)", CONFIG.colors.drums, "EQ", {"Kick", "EQ"})
  local kick_sub = createSmartTrack("    └─ Kick Sub (40-60Hz)", CONFIG.colors.drums, "EQ", {"Sub", "EQ"})
  closeFold()

  -- Snare Folder (4 tracks)
  local snare_folder = createFolder("  ├─ SNARE", CONFIG.colors.drums)
  local snare_top = createTrack("    ├─ Snare Top", CONFIG.colors.drums)
  local snare_bottom = createTrack("    ├─ Snare Bottom", CONFIG.colors.drums)
  local snare_sample = createTrack("    ├─ Snare Sample (Trigger)", CONFIG.colors.drums)
  local snare_glitch = createTrack("    └─ Glitch Snare (Duplicate)", CONFIG.colors.drums)
  closeFold()

  -- Cymbals/OH (5 tracks)
  local cymbal_folder = createFolder("  ├─ CYMBALS/OH", CONFIG.colors.drums)
  local oh_left = createTrack("    ├─ OH Left", CONFIG.colors.drums)
  setPan(oh_left, -0.7)
  local oh_right = createTrack("    ├─ OH Right", CONFIG.colors.drums)
  setPan(oh_right, 0.7)
  local hihat = createTrack("    ├─ Hi-Hat Close", CONFIG.colors.drums)
  local ride = createTrack("    ├─ Ride", CONFIG.colors.drums)
  local room_mono = createTrack("    └─ Room Mono (Crushed)", CONFIG.colors.drums)
  closeFold()

  -- Toms (2 tracks)
  local tom_rack = createTrack("  ├─ Tom Rack", CONFIG.colors.drums)
  setPan(tom_rack, -0.3)
  local tom_floor = createTrack("  └─ Tom Floor", CONFIG.colors.drums)
  setPan(tom_floor, 0.3)

  closeFold()  -- Close Drum Folder

  -- ===================================
  -- II. BASS ENGINE (Tracks 13-18)
  -- ===================================

  reaper.ShowConsoleMsg("  [2/7] Building Bass Engine (3-Band Split)...\n")

  local bass_folder = createFolder("🔊 BASS ENGINE (Drop Bb)", CONFIG.colors.bass)

  local bass_di = createTrack("  ├─ Bass DI (Lows <200Hz)", CONFIG.colors.bass)
  local bass_amp = createTrack("  ├─ Bass Amp (Mids 200-2k)", CONFIG.colors.bass)
  local bass_fuzz = createTrack("  ├─ Bass Fuzz (Highs >2k)", CONFIG.colors.bass)
  setPan(bass_fuzz, -0.15)
  local bass_synth = createTrack("  └─ Bass Synth Layer (Sub)", CONFIG.colors.bass)

  closeFold()  -- Close Bass Folder

  -- ===================================
  -- III. WALL OF SOUND - GUITARS (Tracks 19-30)
  -- ===================================

  reaper.ShowConsoleMsg("  [3/7] Building Guitar Wall (Quad-Tracked)...\n")

  local guitar_folder = createFolder("🎸 GUITARS (Wall of Sound)", CONFIG.colors.guitars)

  -- Rhythm Guitars (Quad-tracked)
  local rhythm_folder = createFolder("  ├─ RHYTHM (Quad)", CONFIG.colors.guitars)
  local rhythm_l1 = createTrack("    ├─ Rhythm L1 (100% L)", CONFIG.colors.guitars)
  setPan(rhythm_l1, -1.0)
  local rhythm_r1 = createTrack("    ├─ Rhythm R1 (100% R)", CONFIG.colors.guitars)
  setPan(rhythm_r1, 1.0)
  local rhythm_l2 = createTrack("    ├─ Rhythm L2 (80% L)", CONFIG.colors.guitars)
  setPan(rhythm_l2, -0.8)
  local rhythm_r2 = createTrack("    └─ Rhythm R2 (80% R)", CONFIG.colors.guitars)
  setPan(rhythm_r2, 0.8)
  closeFold()

  -- Texture Guitars
  local texture_folder = createFolder("  ├─ TEXTURE", CONFIG.colors.guitars)
  local octave_lead_l = createTrack("    ├─ Octave Lead L", CONFIG.colors.guitars)
  setPan(octave_lead_l, -0.5)
  local octave_lead_r = createTrack("    ├─ Octave Lead R", CONFIG.colors.guitars)
  setPan(octave_lead_r, 0.5)
  local scrape = createTrack("    ├─ The Scrape (FX)", CONFIG.colors.guitars)
  local clean_ambient = createTrack("    └─ Clean Ambient (Wet)", CONFIG.colors.guitars)
  closeFold()

  closeFold()  -- Close Guitar Folder

  -- ===================================
  -- IV. INDUSTRIAL GLITCH & ATMOSPHERE (Tracks 31-40)
  -- ===================================

  reaper.ShowConsoleMsg("  [4/7] Building Industrial FX Section...\n")

  local glitch_folder = createFolder("⚡ GLITCH & ATMOSPHERE", CONFIG.colors.fx_glitch)

  -- Industrial FX
  local industrial_folder = createFolder("  ├─ INDUSTRIAL FX", CONFIG.colors.fx_glitch)
  local white_noise = createTrack("    ├─ White Noise Risers", CONFIG.colors.fx_glitch)
  local impact_booms = createTrack("    ├─ Impact Booms", CONFIG.colors.fx_glitch)
  local digital_artifacts = createTrack("    └─ Digital Artifacts", CONFIG.colors.fx_glitch)
  closeFold()

  -- Synth Layer
  local synth_folder = createFolder("  └─ SYNTH LAYER", CONFIG.colors.ambient)
  local dark_pad = createTrack("    ├─ Dark Pad (Minor)", CONFIG.colors.ambient)
  local arpeggiator = createTrack("    ├─ Arpeggiator", CONFIG.colors.ambient)
  local reverse_piano = createTrack("    └─ Reverse Piano", CONFIG.colors.ambient)
  closeFold()

  closeFold()  -- Close Glitch Folder

  -- ===================================
  -- V. VOCAL PRODUCTION (Tracks 41-55)
  -- ===================================

  reaper.ShowConsoleMsg("  [5/7] Building Dual-Layer Vocal System...\n")

  local vocal_folder = createFolder("🎤 VOCALS (Corrupted Robot)", CONFIG.colors.vocals)

  -- Core Layer
  local core_folder = createFolder("  ├─ CORE (Intelligibility)", CONFIG.colors.vocals)
  local lead_vocal = createTrack("    ├─ Lead Vocal", CONFIG.colors.vocals)
  local double_vocal = createTrack("    ├─ Double Vocal", CONFIG.colors.vocals)
  setVolume(double_vocal, -6)
  closeFold()

  -- Glitch Layer
  local glitch_vocal_folder = createFolder("  ├─ GLITCH (Corrupted Data)", CONFIG.colors.vocals)
  local demon_layer = createTrack("    ├─ Demon Layer (-12st)", CONFIG.colors.vocals)
  setVolume(demon_layer, -8)
  local telephonic = createTrack("    ├─ Telephonic (500-3k BP)", CONFIG.colors.vocals)
  setVolume(telephonic, -10)
  closeFold()

  -- Whisper Tracks
  local whisper_folder = createFolder("  ├─ WHISPERS (Stereo)", CONFIG.colors.vocals)
  local whisper_l = createTrack("    ├─ Whisper L (ASMR)", CONFIG.colors.vocals)
  setPan(whisper_l, -1.0)
  setVolume(whisper_l, -12)
  local whisper_r = createTrack("    └─ Whisper R (ASMR)", CONFIG.colors.vocals)
  setPan(whisper_r, 1.0)
  setVolume(whisper_r, -12)
  closeFold()

  -- Scream Layers
  local scream_folder = createFolder("  ├─ SCREAMS", CONFIG.colors.vocals)
  local scream_high_l = createTrack("    ├─ Scream High L", CONFIG.colors.vocals)
  setPan(scream_high_l, -0.6)
  local scream_high_r = createTrack("    ├─ Scream High R", CONFIG.colors.vocals)
  setPan(scream_high_r, 0.6)
  local growl_center = createTrack("    └─ Growl Center", CONFIG.colors.vocals)
  closeFold()

  -- Ad-libs
  local adlib_folder = createFolder("  └─ AD-LIBS (Throws)", CONFIG.colors.vocals)
  local adlib_1 = createTrack("    ├─ Ad-lib 1", CONFIG.colors.vocals)
  local adlib_2 = createTrack("    ├─ Ad-lib 2", CONFIG.colors.vocals)
  local adlib_3 = createTrack("    └─ Ad-lib 3", CONFIG.colors.vocals)
  closeFold()

  closeFold()  -- Close Vocal Folder

  -- ===================================
  -- VI. SEND EFFECTS BUSES
  -- ===================================

  reaper.ShowConsoleMsg("  [6/7] Creating Send Effects Buses...\n")

  local send_fx_folder = createFolder("📡 SEND FX", CONFIG.colors.bus)

  local reverb_hall = createTrack("  ├─ Hall Reverb", CONFIG.colors.bus)
  local reverb_plate = createTrack("  ├─ Plate Reverb", CONFIG.colors.bus)
  local delay_quarter = createTrack("  ├─ 1/4 Note Delay", CONFIG.colors.bus)
  local delay_dotted = createTrack("  ├─ 1/8 Dotted Delay", CONFIG.colors.bus)
  local parallel_drum_crush = createTrack("  └─ Parallel Drum Crush", CONFIG.colors.bus)

  closeFold()  -- Close Send FX Folder

  -- ===================================
  -- VII. MASTER BUS
  -- ===================================

  reaper.ShowConsoleMsg("  [7/7] Configuring Master Bus...\n")

  local master_track = reaper.GetMasterTrack(0)
  reaper.GetSetMediaTrackInfo_String(master_track, "P_NAME", "🎛️ MASTER (Ozone Chain)", true)
  -- The master track must always keep its master/parent send enabled.
  reaper.SetMediaTrackInfo_Value(master_track, "B_MAINSEND", 1)

  -- Master chain comes from the preset library so it stays in one place.
  if Presets and Presets.buses and Presets.buses.master then
    local added = applyChain(master_track, "MASTER", Presets.buses.master)
    if added > 0 then
      reaper.ShowConsoleMsg(string.format("  Master bus: +%d FX\n", added))
    end
  else
    addFX(master_track, "ReaComp")
    addFX(master_track, "ReaEQ")
  end

  reaper.ShowConsoleMsg("\n✅ Session structure complete!\n")
  reaper.ShowConsoleMsg("Total tracks in project: " .. reaper.CountTracks(0) .. "\n")
  if CONFIG.compact_mode and not CONFIG.inventory then
    reaper.ShowConsoleMsg("⚠ Compact Mode is ON but no plugin inventory was found,\n")
    reaper.ShowConsoleMsg("  so plugin-aware tracks were skipped. Turn it off with option 0\n")
    reaper.ShowConsoleMsg("  to build the full skeleton with stock FX.\n")
  end
  reaper.ShowConsoleMsg("\n")

  return true
end

-- ===================================
-- SIDECHAIN SETUP FUNCTION
-- ===================================

local function setupKickBassSidechain()
  reaper.ShowConsoleMsg("\n=== SETTING UP KICK/BASS SIDECHAIN ===\n")

  -- Find tracks by name
  local kick_out = nil
  local bass_di = nil
  local bass_synth = nil

  for i = 0, reaper.CountTracks(0) - 1 do
    local track = reaper.GetTrack(0, i)
    local _, name = reaper.GetTrackName(track)

    if name:find("Kick Out") then
      kick_out = track
    elseif name:find("Bass DI") then
      bass_di = track
    elseif name:find("Bass Synth") then
      bass_synth = track
    end
  end

  -- I_DSTCHAN: low 10 bits = starting channel index, bit 1024 = mix to mono.
  -- Destination "3/4" is therefore channel index 2 (0-based) without the mono bit.
  local SIDECHAIN_DST_CHAN = 2

  local function ensureSidechainSend(dest_track, dest_label)
    local send_idx = findSendIndex(kick_out, dest_track)
    if send_idx then
      reaper.ShowConsoleMsg("• Sidechain already exists: Kick Out -> " .. dest_label .. "\n")
    else
      send_idx = reaper.CreateTrackSend(kick_out, dest_track)
      if not send_idx or send_idx < 0 then
        reaper.ShowConsoleMsg("❌ Could not create send: Kick Out -> " .. dest_label .. "\n")
        return
      end
      reaper.ShowConsoleMsg("✓ Sidechain: Kick Out -> " .. dest_label .. " (channels 3/4)\n")
    end

    -- Configure as 3/4 output (sidechain), stereo source 1/2
    reaper.SetTrackSendInfo_Value(kick_out, 0, send_idx, "I_SRCCHAN", 0)
    reaper.SetTrackSendInfo_Value(kick_out, 0, send_idx, "I_DSTCHAN", SIDECHAIN_DST_CHAN)
    reaper.SetTrackSendInfo_Value(kick_out, 0, send_idx, "D_VOL", 1.0)
  end

  if kick_out and bass_di then
    ensureSidechainSend(bass_di, "Bass DI")

    -- Do the same for bass synth
    if bass_synth then
      ensureSidechainSend(bass_synth, "Bass Synth")
    end

    reaper.ShowConsoleMsg("\nNow add a sidechain compressor/dynamic EQ to the bass tracks!\n")
    reaper.ShowConsoleMsg("Recommended: Waves F6, iZotope Neutron Unmask, or ReaComp with detector input 3+4\n")
  else
    reaper.ShowConsoleMsg("❌ Could not find Kick Out or Bass DI tracks\n")
  end
end

-- ===================================
-- PLUGIN CHAIN PRESETS
-- ===================================

-- Apply the preset chains for one section of the session.
-- `section` is the folder name the builder creates ("DRUMS", "BASS", ...).
-- Tracks are matched through the preset table, not by a second hand-written list
-- of names, so adding a track to the builder and a preset to the library is all
-- that is needed for it to be processed.
local function applyChainsForSection(section_label)
  msg("\n=== ADDING " .. section_label .. " CHAINS ===")

  if not Presets then
    msg("  ! rule-of-30-plugin-presets.lua was not found next to this script.")
    msg("    Reinstall the Rule of 30 bundle, then run this again.")
    return
  end

  -- Walk the tracks, remembering which section folder we are inside.
  local current_section, applied, already = nil, 0, 0
  for i = 0, reaper.CountTracks(0) - 1 do
    local track = reaper.GetTrack(0, i)
    local _, name = reaper.GetTrackName(track)
    local is_folder = reaper.GetMediaTrackInfo_Value(track, "I_FOLDERDEPTH") == 1

    if is_folder then
      local matched = false
      for _, label in ipairs({ "DRUMS", "BASS", "GUITARS", "VOCALS", "GLITCH" }) do
        if name:find(label, 1, true) then
          current_section = label
          matched = true
        end
      end
      if not matched then
        -- A nested folder ("KICK", "SNARE", ...) keeps the section it is in.
      end
    end

    local in_section = (current_section == section_label)

    if in_section and not is_folder then
      local added, skipped = applyPreset(track, name)
      if added > 0 then
        msg(string.format("  ✓ %s (+%d FX)", name, added))
        applied = applied + 1
      elseif #skipped > 0 then
        msg(string.format("  · %s already has: %s", name, table.concat(skipped, ", ")))
        already = already + 1
      end
    end
  end

  if applied == 0 and already == 0 then
    msg("  No matching tracks found. Is the section built? (Run option 1 first.)")
  else
    msg(string.format("  %d track(s) processed, %d already had a chain.",
      applied, already))
  end
end

-- Thin wrappers so the menu reads clearly; the menu itself wraps each in its
-- own undo block.
local function addDrumChains() applyChainsForSection("DRUMS") end
local function addBassChains() applyChainsForSection("BASS") end
local function addGuitarChains() applyChainsForSection("GUITARS") end
local function addVocalChains() applyChainsForSection("VOCALS") end

-- ===================================
-- MAIN MENU
-- ===================================

local function showMenu()
  local ok, answer = reaper.GetUserInputs(
    "Rule of 30 Session Builder", 1,
    "0=Toggle Compact Mode  1=Build Session  2=Drum Chains  "
      .. "3=Bass Chains  4=Guitar Chains  5=Vocal Chains  "
      .. "6=Kick/Bass Sidechain  7=Close",
    "1")
  if not ok then return end

  local result = tonumber(answer and answer:match("^%s*(%d+)"))
  if not result or result < 0 or result > 7 then return end

  if result == 0 then
    CONFIG.compact_mode = not CONFIG.compact_mode
    reaper.MB("Compact Mode is now "
      .. (CONFIG.compact_mode and "ON (skip tracks with no plugins)" or "OFF"),
      "Rule of 30 Session Builder", 0)
  elseif result == 1 then
    beginUndo()
    local built = buildRuleOf30Session()
    endUndo(built and "Create Rule of 30 Session" or "Rule of 30: build aborted")
    reaper.ShowConsoleMsg("\n💡 Next steps:\n")
    reaper.ShowConsoleMsg("   1. Run option 2-5 to add plugin chains\n")
    reaper.ShowConsoleMsg("   2. Run option 6 to setup sidechain compression\n")
    reaper.ShowConsoleMsg("   3. Add your Neural DSP plugins to guitar tracks\n")
    reaper.ShowConsoleMsg("   4. Add Waves/iZotope plugins as per your master plan\n\n")
  elseif result == 2 then
    beginUndo()
    addDrumChains()
    endUndo("Rule of 30: Add Drum Processing Chains")
  elseif result == 3 then
    beginUndo()
    addBassChains()
    endUndo("Rule of 30: Add Bass Processing Chains")
  elseif result == 4 then
    beginUndo()
    addGuitarChains()
    endUndo("Rule of 30: Add Guitar Chains")
  elseif result == 5 then
    beginUndo()
    addVocalChains()
    endUndo("Rule of 30: Add Vocal Chains")
  elseif result == 6 then
    beginUndo()
    setupKickBassSidechain()
    endUndo("Rule of 30: Kick/Bass Sidechain Routing")
  elseif result == 7 then
    reaper.ShowConsoleMsg("Closed — no changes made.\n")
  end
end

-- Run the menu
showMenu()
