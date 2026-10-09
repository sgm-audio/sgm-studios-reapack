-- @description Build a 48-track industrial/heavy metal session: Drop Bb, 95-110 BPM, massive density
-- @author Scott Mills
-- @version 1.0.1
-- @changelog
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
--   Requires rule-of-30-plugin-presets.lua in the same directory.
-- RULE OF 30 SESSION BUILDER
-- Professional 48+ Track Industrial/Heavy Metal Session Template
-- Drop Bb Tuning | 95-110 BPM | Massive Density Production
-- Version 1.0

reaper.ClearConsole()
reaper.ShowConsoleMsg("=== RULE OF 30 SESSION BUILDER ===\n\n")

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

-- Minimal JSON parser for Lua (Substantiated)
local JSON = {}
function JSON.parse(s)
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

local function loadPluginInventory()
  local resource_path = reaper.GetResourcePath()
  local inventory_path = resource_path .. "/plugin_inventory.json"
  local file = io.open(inventory_path, "r")
  if not file then 
    reaper.ShowConsoleMsg("Warning: plugin_inventory.json not found. Run list-all-available-plugins.lua first.\n")
    return nil 
  end
  local content = file:read("*all")
  file:close()
  
  local ok, inventory = pcall(JSON.parse, content)
  if not ok or not inventory then
    reaper.ShowConsoleMsg("Error: Failed to parse plugin_inventory.json. Regenerate it.\n")
    return nil
  end
  
  CONFIG.inventory = inventory
  return inventory
end

local function getBestPlugin(category, keywords)
  if not CONFIG.inventory then return nil end
  if not CONFIG.inventory.by_category or not CONFIG.inventory.by_category[category] then return nil end
  local list = CONFIG.inventory.by_category[category]
  
  if not keywords or #keywords == 0 then return list[1] end
  
  -- Try to match keywords
  for _, kw in ipairs(keywords) do
    for _, plugin in ipairs(list) do
      if plugin:lower():find(kw:lower()) then
        return plugin
      end
    end
  end
  
  return list[1] -- Fallback to first in category
end

local function addSmartFX(track, category, keywords)
  local plugin = getBestPlugin(category, keywords)
  if plugin then
    addFX(track, plugin)
    return true
  end
  return false
end

-- ===================================
-- UTILITY FUNCTIONS
-- ===================================

local function createTrack(name, color, parent_folder)
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
      reaper.ShowConsoleMsg("  Skipping track (no " .. category .. " found): " .. name .. "\n")
      reaper.ShowConsoleMsg("  ⚠ Run list-all-available-plugins.lua to generate plugin inventory\n")
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

local function addFX(track, fx_name)
  local fx_index = reaper.TrackFX_AddByName(track, fx_name, false, -1)
  return fx_index
end

local function createSend(source_track, dest_track, volume_db, pre_fader)
  local send_index = reaper.CreateTrackSend(source_track, dest_track)

  -- Convert dB to volume (0dB = 1.0)
  local volume = 10^(volume_db/20)
  reaper.SetTrackSendInfo_Value(source_track, 0, send_index, "D_VOL", volume)

  if pre_fader then
    reaper.SetTrackSendInfo_Value(source_track, 0, send_index, "I_SENDMODE", 3)
  end

  return send_index
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

local function buildRuleOf30Session()

  beginUndo()

  -- Set project properties
  reaper.GetSetProjectInfo(0, "PROJECT_SRATE", CONFIG.sample_rate, true)
  reaper.SetTempoTimeSigMarker(0, -1, -1, -1, CONFIG.bpm, 0, 0, false)
  reaper.GetSetProjectInfo(0, "PROJECT_TIMEBASE", 1, true)  -- Time base: beats

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

  -- Add master bus FX chain (placeholders - user will swap with actual plugins)
  -- These are generic names that work across platforms
  addFX(master_track, "ReaComp")  -- Placeholder for SSL Bus Comp
  addFX(master_track, "ReaEQ")    -- Placeholder for final shaping

  reaper.ShowConsoleMsg("\n✅ Session structure complete!\n")
  reaper.ShowConsoleMsg("Total tracks created: " .. reaper.CountTracks(0) .. "\n\n")

  endUndo("Create Rule of 30 Session")

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

  if kick_out and bass_di then
    -- Send kick to sidechain input (channels 3/4) of bass
    local send_idx = reaper.CreateTrackSend(kick_out, bass_di)

    -- Configure as 3/4 output (sidechain)
    reaper.SetTrackSendInfo_Value(kick_out, 0, send_idx, "I_SRCCHAN", 0)  -- Source stereo
    reaper.SetTrackSendInfo_Value(kick_out, 0, send_idx, "I_DSTCHAN", 2 + 1024)  -- Dest 3/4 (sidechain)
    reaper.SetTrackSendInfo_Value(kick_out, 0, send_idx, "D_VOL", 1.0)

    reaper.ShowConsoleMsg("✓ Sidechain: Kick Out -> Bass DI (channels 3/4)\n")

    -- Do the same for bass synth
    if bass_synth then
      local send_idx2 = reaper.CreateTrackSend(kick_out, bass_synth)
      reaper.SetTrackSendInfo_Value(kick_out, 0, send_idx2, "I_SRCCHAN", 0)
      reaper.SetTrackSendInfo_Value(kick_out, 0, send_idx2, "I_DSTCHAN", 2 + 1024)
      reaper.SetTrackSendInfo_Value(kick_out, 0, send_idx2, "D_VOL", 1.0)
      reaper.ShowConsoleMsg("✓ Sidechain: Kick Out -> Bass Synth (channels 3/4)\n")
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

local function addDrumChains()
  reaper.ShowConsoleMsg("\n=== ADDING DRUM PROCESSING CHAINS ===\n")

  for i = 0, reaper.CountTracks(0) - 1 do
    local track = reaper.GetTrack(0, i)
    local _, name = reaper.GetTrackName(track)

    -- Kick In Chain
    if name:find("Kick In") then
      addFX(track, "ReaGate")
      addFX(track, "ReaEQ")
      reaper.ShowConsoleMsg("✓ Added chain: Kick In\n")

    -- Kick Out Chain
    elseif name:find("Kick Out") then
      addFX(track, "ReaComp")
      addFX(track, "ReaEQ")
      reaper.ShowConsoleMsg("✓ Added chain: Kick Out\n")

    -- Snare Top Chain
    elseif name:find("Snare Top") then
      addFX(track, "ReaGate")
      addFX(track, "ReaComp")
      addFX(track, "ReaEQ")
      reaper.ShowConsoleMsg("✓ Added chain: Snare Top\n")

    -- Room Mono Chain (Crushing)
    elseif name:find("Room Mono") then
      addFX(track, "ReaComp")  -- Smash it!
      reaper.ShowConsoleMsg("✓ Added chain: Room Mono Crush\n")
    end
  end
end

local function addBassChains()
  reaper.ShowConsoleMsg("\n=== ADDING BASS PROCESSING CHAINS ===\n")

  for i = 0, reaper.CountTracks(0) - 1 do
    local track = reaper.GetTrack(0, i)
    local _, name = reaper.GetTrackName(track)

    -- Bass DI (Low pass at 200Hz)
    if name:find("Bass DI") then
      addFX(track, "ReaEQ")  -- Low pass
      addFX(track, "ReaComp")  -- Sidechain comp here!
      reaper.ShowConsoleMsg("✓ Added chain: Bass DI (add sidechain comp!)\n")

    -- Bass Amp (High pass at 200Hz)
    elseif name:find("Bass Amp") then
      addFX(track, "ReaEQ")  -- High pass
      reaper.ShowConsoleMsg("✓ Added chain: Bass Amp\n")

    -- Bass Fuzz (Distortion + High pass)
    elseif name:find("Bass Fuzz") then
      addFX(track, "ReaEQ")  -- High pass at 200Hz
      reaper.ShowConsoleMsg("✓ Added chain: Bass Fuzz\n")

    -- Bass Synth
    elseif name:find("Bass Synth") then
      addFX(track, "ReaComp")  -- Sidechain comp here too!
      reaper.ShowConsoleMsg("✓ Added chain: Bass Synth (add sidechain comp!)\n")
    end
  end
end

local function addGuitarChains()
  reaper.ShowConsoleMsg("\n=== ADDING GUITAR CHAINS ===\n")

  for i = 0, reaper.CountTracks(0) - 1 do
    local track = reaper.GetTrack(0, i)
    local _, name = reaper.GetTrackName(track)

    -- Rhythm guitars (add amp sim placeholder)
    if name:find("Rhythm") then
      addFX(track, "ReaEQ")  -- EQ after amp sim
      reaper.ShowConsoleMsg("✓ Added chain: " .. name .. " (add Neural DSP here!)\n")

    -- The Scrape (extreme distortion)
    elseif name:find("Scrape") then
      addFX(track, "ReaEQ")
      reaper.ShowConsoleMsg("✓ Added chain: The Scrape\n")

    -- Clean Ambient (reverb/delay)
    elseif name:find("Clean Ambient") then
      reaper.ShowConsoleMsg("✓ Ready: Clean Ambient (send to reverb!)\n")
    end
  end
end

local function addVocalChains()
  reaper.ShowConsoleMsg("\n=== ADDING VOCAL CHAINS ===\n")

  for i = 0, reaper.CountTracks(0) - 1 do
    local track = reaper.GetTrack(0, i)
    local _, name = reaper.GetTrackName(track)

    -- Lead Vocal (core chain)
    if name:find("Lead Vocal") then
      addFX(track, "ReaComp")
      addFX(track, "ReaEQ")
      reaper.ShowConsoleMsg("✓ Added chain: Lead Vocal (add Nectar/pitch correction!)\n")

    -- Demon Layer (pitch shift down)
    elseif name:find("Demon Layer") then
      reaper.ShowConsoleMsg("✓ Ready: Demon Layer (add -12st pitch shift!)\n")

    -- Telephonic (band-pass 500-3k)
    elseif name:find("Telephonic") then
      addFX(track, "ReaEQ")  -- Band-pass filter
      reaper.ShowConsoleMsg("✓ Added chain: Telephonic\n")

    -- Whispers (de-esser)
    elseif name:find("Whisper") then
      reaper.ShowConsoleMsg("✓ Ready: Whisper (add de-esser!)\n")
    end
  end
end

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
    buildRuleOf30Session()
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
  end
end

-- Run the menu
showMenu()
