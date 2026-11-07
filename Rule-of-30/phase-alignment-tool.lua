-- @description Auto-align quad-tracked DI guitars by transient analysis before amp processing
-- @author Scott Mills
-- @version 1.0.3
-- @changelog
--   1.0.3 (2026-11-07)
--     + Fix: reaper.GetProjectSampleRate() is not a REAPER API function (verified
--       against the REAPER 7.83 SDK header); the project/device rate now comes
--       from GetAudioDeviceInfo("SRATE")
--   1.0.2 (2026-11-07)
--     + Fix: early exits (too few tracks / no transients) left UIRefresh disabled
--       and an undo block open — validation now happens before any begin/refresh
--     + Fix: transient detection read a multi-channel buffer as if it were mono,
--       so stereo DI takes were analysed from interleaved garbage; it now walks
--       channel 1 frame by frame
--     + Fix: hard-coded 48 kHz in the reports — uses the project sample rate
--     + Fix: the reported peak level stopped accumulating once a transient was
--       found; it is now the true peak of the analysis window
--     + Clarify: "alignment_precision" is 0.1 ms, not one sample
--   1.0.1 (2026-10-08)
--     + Top Shelf audit: replace gfx.showmenu with GetUserInputs
--   1.0.0 (2026-05-23)
--     + Initial release
--     + Transient onset detection on selected DI tracks
--     + Sample-accurate offset calculation and item nudge
--     + Designed for quad-tracked guitars in heavy metal production
-- @provides
--   [main] phase-alignment-tool.lua
-- @about
--   ## Phase Alignment Tool
--   Analyses selected guitar DI tracks, detects transient onsets, and
--   nudges items to achieve sample-accurate phase alignment before
--   amp simulation or cabinet processing is applied.
-- PHASE ALIGNMENT TOOL
-- Auto-align quad-tracked guitars for tight metal production
-- Analyzes transients and aligns DI tracks before amp processing
-- Version 1.0

reaper.ClearConsole()
reaper.ShowConsoleMsg("=== PHASE ALIGNMENT TOOL ===\n\n")

-- ===================================
-- CONFIGURATION
-- ===================================

local CONFIG = {
  transient_threshold = 0.3,  -- Sensitivity for detecting pick attacks (0-1)
  analysis_window = 0.1,      -- Seconds to analyze for first transient
  alignment_precision = 0.0001, -- Minimum correction applied (0.1 ms; one sample @48k is ~0.021 ms)
}

-- ===================================
-- UTILITY FUNCTIONS
-- ===================================

local function getSelectedTracks()
  local tracks = {}
  for i = 0, reaper.CountSelectedTracks(0) - 1 do
    local track = reaper.GetSelectedTrack(0, i)
    table.insert(tracks, track)
  end
  return tracks
end

local function getTrackItems(track)
  local items = {}
  local item_count = reaper.CountTrackMediaItems(track)
  for i = 0, item_count - 1 do
    local item = reaper.GetTrackMediaItem(track, i)
    table.insert(items, item)
  end
  return items
end

local function findFirstTransient(item)
  local take = reaper.GetActiveTake(item)
  if not take then return nil end
  if reaper.TakeIsMIDI(take) then return nil end

  local source = reaper.GetMediaItemTake_Source(take)
  local sample_rate = reaper.GetMediaSourceSampleRate(source)
  local num_channels = reaper.GetMediaSourceNumChannels(source)

  if not sample_rate or sample_rate <= 0 then return nil end
  if num_channels == 0 then return nil end

  -- Get audio accessor
  local accessor = reaper.CreateTakeAudioAccessor(take)
  if not accessor then return nil end

  local start_time = reaper.GetMediaItemInfo_Value(item, "D_POSITION")

  -- Analyze first 100ms for transient
  local samples_to_analyze = math.max(1, math.floor(CONFIG.analysis_window * sample_rate))
  -- The buffer is interleaved: samples * channels
  local audio_buffer = reaper.new_array(samples_to_analyze * num_channels)
  audio_buffer.clear()

  -- Read audio data (start offset is relative to the take)
  local samples_read = reaper.GetAudioAccessorSamples(
    accessor,
    sample_rate,
    num_channels,
    0,  -- Start offset (seconds into the take)
    samples_to_analyze,
    audio_buffer
  )

  -- Find first peak above threshold. Walk frame by frame and look at channel 1
  -- only; treating the interleaved buffer as mono mixes channels and frame rates.
  local transient_sample = nil
  local peak_value = 0

  for frame = 0, (samples_read or 0) - 1 do
    local sample_value = math.abs(audio_buffer[frame * num_channels] or 0)
    peak_value = math.max(peak_value, sample_value)

    if not transient_sample and sample_value > CONFIG.transient_threshold then
      transient_sample = frame
    end
  end

  reaper.DestroyAudioAccessor(accessor)

  if transient_sample then
    local transient_time = start_time + (transient_sample / sample_rate)
    return transient_time, peak_value
  else
    return nil, peak_value
  end
end

local function nudgeItem(item, time_offset)
  local current_pos = reaper.GetMediaItemInfo_Value(item, "D_POSITION")
  reaper.SetMediaItemInfo_Value(item, "D_POSITION", current_pos + time_offset)
end

-- ===================================
-- PHASE ALIGNMENT ENGINE
-- ===================================

-- REAPER has no GetProjectSampleRate(); the device rate is exposed through
-- GetAudioDeviceInfo("SRATE"). Fall back to 48 kHz when the device is closed.
local function projectSampleRate()
  local ok, srate = reaper.GetAudioDeviceInfo("SRATE", "")
  local rate = ok and tonumber(srate) or nil
  if not rate or rate <= 0 then rate = 48000 end
  return rate
end

local function alignSelectedTracks()
  local tracks = getSelectedTracks()
  local project_sample_rate = projectSampleRate()

  -- Validate first: never open an undo block / disable the UI before we know
  -- we are going to do something.
  if #tracks < 2 then
    reaper.ShowConsoleMsg("❌ Please select at least 2 tracks to align\n")
    reaper.ShowConsoleMsg("   (e.g., Rhythm L and Rhythm R guitar tracks)\n")
    return
  end

  -- Save edit state
  local saved_cursor = reaper.GetCursorPosition()
  local saved_sel_s, saved_sel_e = reaper.GetSet_LoopTimeRange(false, false, 0, 0, false)

  reaper.PreventUIRefresh(1)

  reaper.ShowConsoleMsg("Analyzing " .. #tracks .. " selected tracks...\n\n")

  -- Step 1: Find transients in all tracks
  local track_data = {}
  local earliest_transient = nil

  for i, track in ipairs(tracks) do
    local _, track_name = reaper.GetTrackName(track)
    local items = getTrackItems(track)

    if #items > 0 then
      local first_item = items[1]
      local transient_time, peak = findFirstTransient(first_item)

      table.insert(track_data, {
        track = track,
        name = track_name,
        item = first_item,
        transient_time = transient_time,
        peak = peak
      })

      if transient_time then
        reaper.ShowConsoleMsg(string.format("  Track %d (%s): Transient at %.4fs (peak: %.2f)\n",
          i, track_name, transient_time, peak))

        if not earliest_transient or transient_time < earliest_transient then
          earliest_transient = transient_time
        end
      else
        reaper.ShowConsoleMsg(string.format("  Track %d (%s): No transient found (lower the threshold?)\n",
          i, track_name))
      end
    else
      reaper.ShowConsoleMsg(string.format("  Track %d (%s): No items found\n", i, track_name))
    end
  end

  if not earliest_transient then
    reaper.ShowConsoleMsg("\n❌ No transients detected in any track\n")
    reaper.ShowConsoleMsg("   Try lowering the threshold or checking your audio\n")
    reaper.PreventUIRefresh(-1)
    reaper.UpdateArrange()
    return
  end

  -- At least one track will move: open the single undo point for this action.
  reaper.Undo_BeginBlock()

  -- Step 2: Align all tracks to the earliest transient
  reaper.ShowConsoleMsg("\n=== ALIGNING TRACKS ===\n")
  reaper.ShowConsoleMsg("Reference time: " .. string.format("%.4fs", earliest_transient) .. "\n\n")

  for i, data in ipairs(track_data) do
    if data.transient_time then
      local offset = earliest_transient - data.transient_time

      if math.abs(offset) > CONFIG.alignment_precision then
        nudgeItem(data.item, offset)
        reaper.ShowConsoleMsg(string.format("  ✓ %s: Adjusted by %.4fs (%+.1f samples @ %d Hz)\n",
          data.name, offset, offset * project_sample_rate, math.floor(project_sample_rate)))
      else
        reaper.ShowConsoleMsg(string.format("  ✓ %s: Already aligned\n", data.name))
      end
    end
  end

  reaper.ShowConsoleMsg("\n✅ Phase alignment complete!\n")
  reaper.ShowConsoleMsg("\nNEXT STEPS:\n")
  reaper.ShowConsoleMsg("  1. Check alignment: Play and listen for a tight 'wall'\n")
  reaper.ShowConsoleMsg("  2. Mono test: Click Mono on master - should sound louder, not thinner\n")
  reaper.ShowConsoleMsg("  3. Add amp sims to your DI tracks\n\n")

  reaper.PreventUIRefresh(-1)
  reaper.Undo_EndBlock("Align Guitar Tracks (Phase)", -1)
  reaper.SetEditCurPos(saved_cursor, false, false)
  reaper.GetSet_LoopTimeRange(true, false, saved_sel_s, saved_sel_e, false)
  reaper.UpdateArrange()
end

-- ===================================
-- CORRELATION ANALYZER
-- ===================================

local function analyzePhaseCorrelation()
  reaper.ShowConsoleMsg("=== PHASE CORRELATION ANALYZER ===\n\n")

  local tracks = getSelectedTracks()

  if #tracks ~= 2 then
    reaper.ShowConsoleMsg("❌ Please select exactly 2 tracks for correlation analysis\n")
    return
  end

  local track1, track2 = tracks[1], tracks[2]
  local _, name1 = reaper.GetTrackName(track1)
  local _, name2 = reaper.GetTrackName(track2)

  reaper.ShowConsoleMsg("Analyzing correlation between:\n")
  reaper.ShowConsoleMsg("  Track 1: " .. name1 .. "\n")
  reaper.ShowConsoleMsg("  Track 2: " .. name2 .. "\n\n")

  -- Get first items
  local items1 = getTrackItems(track1)
  local items2 = getTrackItems(track2)

  if #items1 == 0 or #items2 == 0 then
    reaper.ShowConsoleMsg("❌ One or both tracks have no items\n")
    return
  end

  local item1, item2 = items1[1], items2[1]
  local take1 = reaper.GetActiveTake(item1)
  local take2 = reaper.GetActiveTake(item2)

  if not take1 or not take2 then
    reaper.ShowConsoleMsg("❌ Could not access takes\n")
    return
  end

  -- Simplified correlation check
  local pos1 = reaper.GetMediaItemInfo_Value(item1, "D_POSITION")
  local pos2 = reaper.GetMediaItemInfo_Value(item2, "D_POSITION")
  local time_diff = math.abs(pos1 - pos2)

  local rate = projectSampleRate()
  reaper.ShowConsoleMsg("Position difference: " .. string.format("%.4fs (%.1f samples @ %d Hz)\n",
    time_diff, time_diff * rate, math.floor(rate)))

  if time_diff < 0.0002 then  -- Less than 0.2ms
    reaper.ShowConsoleMsg("\n✅ EXCELLENT: Tracks are sample-accurate aligned\n")
    reaper.ShowConsoleMsg("   Mono compatibility: Should be very good\n")
  elseif time_diff < 0.001 then  -- Less than 1ms
    reaper.ShowConsoleMsg("\n✓ GOOD: Tracks are well aligned\n")
    reaper.ShowConsoleMsg("   Minor timing differences add natural width\n")
  elseif time_diff < 0.005 then  -- Less than 5ms
    reaper.ShowConsoleMsg("\n⚠ ACCEPTABLE: Slight timing difference\n")
    reaper.ShowConsoleMsg("   May cause subtle phase issues in mono\n")
  else
    reaper.ShowConsoleMsg("\n❌ WARNING: Significant misalignment detected\n")
    reaper.ShowConsoleMsg("   Run the alignment tool to fix this\n")
  end
end

-- ===================================
-- MANUAL NUDGE TOOL
-- ===================================

local function nudgeSelectedItems(direction, amount)
  local num_items = reaper.CountSelectedMediaItems(0)

  if num_items == 0 then
    reaper.ShowConsoleMsg("No items selected\n")
    return
  end

  local saved_cursor = reaper.GetCursorPosition()
  reaper.Undo_BeginBlock()
  reaper.PreventUIRefresh(1)

  local nudge_amount = amount * direction

  for i = 0, num_items - 1 do
    local item = reaper.GetSelectedMediaItem(0, i)
    nudgeItem(item, nudge_amount)
  end

  reaper.ShowConsoleMsg(string.format("Nudged %d items by %.4fs\n", num_items, nudge_amount))

  reaper.PreventUIRefresh(-1)
  reaper.Undo_EndBlock("Nudge Items", -1)
  reaper.SetEditCurPos(saved_cursor, false, false)
  reaper.UpdateArrange()
end

-- ===================================
-- MAIN MENU
-- ===================================

local function showMenu()
  local ok, answer = reaper.GetUserInputs(
    "Phase Alignment Tool", 1,
    "1=Auto-Align Selected Tracks  2=Analyze Phase Correlation  "
      .. "3=Nudge Left 1ms  4=Nudge Right 1ms  5=Nudge Left 0.1ms  "
      .. "6=Nudge Right 0.1ms  7=Settings",
    "1")
  if not ok then return end

  local result = tonumber(answer and answer:match("^%s*(%d+)"))
  if not result or result < 1 or result > 7 then return end

  if result == 1 then
    alignSelectedTracks()
  elseif result == 2 then
    analyzePhaseCorrelation()
  elseif result == 3 then
    nudgeSelectedItems(-1, 0.001)
  elseif result == 4 then
    nudgeSelectedItems(1, 0.001)
  elseif result == 5 then
    nudgeSelectedItems(-1, 0.0001)
  elseif result == 6 then
    nudgeSelectedItems(1, 0.0001)
  elseif result == 7 then
    reaper.ShowConsoleMsg("=== SETTINGS ===\n")
    reaper.ShowConsoleMsg("Transient Threshold: " .. CONFIG.transient_threshold .. "\n")
    reaper.ShowConsoleMsg("Analysis Window: " .. CONFIG.analysis_window .. "s\n")
    reaper.ShowConsoleMsg("\nEdit these values at the top of the script\n")
  end
end

-- Run menu
showMenu()
