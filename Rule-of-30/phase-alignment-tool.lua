-- @description Align selected DI tracks by cross-correlation (sample-accurate phase alignment for quad-tracked guitars)
-- @author Scott Mills
-- @license MIT (c) 2026 Scott Mills / SGM Studios — see LICENSE; kept with the script when redistributed
-- @version 2.0.0
-- @changelog
--   2.0.0 (2026-11-07)
--     + Rewrite: alignment is now measured by normalized cross-correlation of the
--       actual audio, not by "where the first sample above 0.3 happens to be".
--       The old method reported a first-threshold crossing, which moves with the
--       material's gain and misses anything played softly.
--     + Fix: the analysis buffer was indexed as frame*channels; reaper.new_array
--       is 1-based, so every take was measured one frame early.
--     + Fix: tracks with several items only had their first item examined, and a
--       silent first item made the track look unalignable.
--     + Fix: the correlation analyser compared item *positions* and called that
--       phase, which says nothing about the audio inside the items.
--     + Fix: every track was nudged to the earliest transient, so a single
--       detection error dragged the whole group. Tracks are now aligned to one
--       explicit reference track.
--     + Add: polarity check (reports an inverted track instead of aligning it to
--       the wrong lobe), confidence reporting, and a refusal to move a track when
--       the correlation is too weak to mean anything.
--     + Add: settings persist between runs (ExtState) and option 7 edits them.
--     + Add: uses SGM_Utils when it is installed, falls back to local helpers.
--   1.0.3 (2026-11-07)
--     + Fix: reaper.GetProjectSampleRate() is not a REAPER API function (verified
--       against the REAPER 7.83 SDK header); the project/device rate now comes
--       from GetAudioDeviceInfo("SRATE")
--   1.0.2 (2026-11-07)
--     + Fix: early exits (too few tracks / no transients) left UIRefresh disabled
--       and an undo block open — validation now happens before any begin/refresh
--     + Fix: transient detection read a multi-channel buffer as if it were mono
--   1.0.1 (2026-10-08)
--     + Top Shelf audit: replace gfx.showmenu with GetUserInputs
--   1.0.0 (2026-05-23)
--     + Initial release
-- @provides
--   [main] phase-alignment-tool.lua
-- @about
--   ## Phase Alignment Tool 2.0
--   Aligns DI tracks to each other by measuring the actual audio, so that
--   quad-tracked guitars sum instead of comb-filtering.
--
--   **How it works**
--   1. The first selected track with audio is the reference.
--   2. For every other selected track, a window of audio is read from REAPER's
--      audio accessor at the same timeline positions, and the relative arrival
--      is found by normalized cross-correlation (coarse pass on a high-passed,
--      decimated signal, then refined at sample resolution).
--   3. The track is nudged by exactly that many samples, in one undo block.
--
--   **What it reports, and refuses to do**
--   - Correlation coefficient at the best lag. Below the threshold (default 0.30)
--     the track is left alone: two takes that do not correlate cannot be aligned
--     by moving them, and moving them anyway is how sessions get damaged.
--   - Polarity. A strong *negative* correlation means the take is inverted; the
--     tool says so instead of aligning to the opposite lobe.
--   - Silence, missing takes, MIDI takes, and playrate/take-rate oddities are
--     reported per track rather than guessed at.
--
--   **Settings** live in ExtState (`SGM_PhaseAlign`) and are editable from
--   option 7 of the menu, so they survive a restart.
--
--   **Limits, stated plainly**
--   - Playrate other than 1.0 is refused (the offset would not be a constant).
--   - Only the first audio channel of each take is analysed. For DIs that is the
--     signal; for stereo sources it is channel 1.
--   - A track with several items is aligned on the item that overlaps the
--     reference; the other items on that track are not moved.

-- ===================================
-- SHARED UTILITY LIBRARY
-- ===================================
-- SGM_Utils ships in the SGM-Essentials bundle. Load it when it is installed so
-- both bundles share one implementation; degrade to the two helpers used here
-- when it is not, so this script works standalone.
local function scriptDirectory()
  local ok, source = pcall(debug.getinfo, 1, "S")
  local path = ok and source and source.source or ""
  path = path:gsub("^@", "")
  return path:match("^(.*[/\\])") or ""
end

-- The search list lives in SGM_Utils.load() so every bundle finds the library
-- the same way. Bootstrapping it means loading the file once by path here; the
-- library's own load() is then used for the real lookup (and by other scripts).
local function bootstrapUtils()
  local resource = reaper.GetResourcePath()
  local candidates = {
    scriptDirectory() .. "SGM_Utils.lua",
    scriptDirectory() .. "../SGM-Essentials/SGM_Utils.lua",
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

local function loadSharedUtils()
  local first, first_path = bootstrapUtils()
  if first and first.load then
    local lib, path = first.load(scriptDirectory())
    if lib then return lib, path end
  end
  return first, first_path
end

local Utils = loadSharedUtils()

local function msg(m)
  if Utils and Utils.msg then return Utils.msg(m) end
  reaper.ShowConsoleMsg(tostring(m) .. "\n")
end

local function clamp(v, lo, hi)
  if Utils and Utils.clamp then return Utils.clamp(v, lo, hi) end
  return math.max(lo, math.min(hi, v))
end

-- ===================================
-- CONFIGURATION (persisted)
-- ===================================

local EXT_SECTION = "SGM_PhaseAlign"

local DEFAULTS = {
  window_ms = 500,       -- audio analysed per comparison
  search_ms = 20,        -- maximum expected misalignment (each direction)
  min_correlation = 0.30, -- below this a track is reported and left alone
  apply = true,          -- false = measure and report only
  channel = 1,           -- 1-based channel inside the take that is analysed
}

local CONFIG = {}

local function loadSettings()
  for key, default in pairs(DEFAULTS) do
    local exists, value = reaper.GetExtState(EXT_SECTION, key)
    if not exists or value == nil or value == "" then
      -- Never seen: use the default. (Treating a missing key as "false" would
      -- silently start every fresh install in measure-only mode.)
      CONFIG[key] = default
    elseif type(default) == "boolean" then
      CONFIG[key] = (value == "1")
    else
      local number = tonumber(value)
      CONFIG[key] = number or default
    end
  end
  -- Defensive: a stored value from an older run must not break the maths.
  CONFIG.window_ms = clamp(CONFIG.window_ms, 20, 5000)
  CONFIG.search_ms = clamp(CONFIG.search_ms, 1, 500)
  CONFIG.min_correlation = clamp(CONFIG.min_correlation, 0, 1)
  CONFIG.channel = math.floor(clamp(CONFIG.channel, 1, 64))
end

local function saveSettings()
  reaper.SetExtState(EXT_SECTION, "window_ms", tostring(CONFIG.window_ms), true)
  reaper.SetExtState(EXT_SECTION, "search_ms", tostring(CONFIG.search_ms), true)
  reaper.SetExtState(EXT_SECTION, "min_correlation", tostring(CONFIG.min_correlation), true)
  reaper.SetExtState(EXT_SECTION, "apply", CONFIG.apply and "1" or "0", true)
  reaper.SetExtState(EXT_SECTION, "channel", tostring(CONFIG.channel), true)
end

loadSettings()

-- ===================================
-- SMALL HELPERS
-- ===================================

local function getSelectedTracks()
  local tracks = {}
  for i = 0, reaper.CountSelectedTracks(0) - 1 do
    local track = reaper.GetSelectedTrack(0, i)
    if track then tracks[#tracks + 1] = track end
  end
  return tracks
end

local function trackName(track)
  local _, name = reaper.GetTrackName(track)
  if not name or name == "" then return "(unnamed)" end
  return name
end

local function getTrackItems(track)
  local items = {}
  for i = 0, reaper.CountTrackMediaItems(track) - 1 do
    local item = reaper.GetTrackMediaItem(track, i)
    if item then items[#items + 1] = item end
  end
  return items
end

-- Everything the analyser needs to know about one take, or nil + a reason.
local function takeAudioInfo(item)
  local take = reaper.GetActiveTake(item)
  if not take then return nil, "no take" end
  if reaper.TakeIsMIDI(take) then return nil, "MIDI take" end

  local source = reaper.GetMediaItemTake_Source(take)
  if not source then return nil, "no source" end

  local rate = reaper.GetMediaSourceSampleRate(source)
  local channels = reaper.GetMediaSourceNumChannels(source)
  if not rate or rate <= 0 then return nil, "no sample rate" end
  if not channels or channels == 0 then return nil, "no channels" end

  local playrate = reaper.GetMediaItemTakeInfo_Value(take, "D_PLAYRATE")
  if playrate and math.abs(playrate - 1.0) > 1e-6 then
    -- A constant time offset cannot align material that plays at a different
    -- rate; refusing is honest, silently nudging is not.
    return nil, string.format("playrate %.3f (only 1.0 is supported)", playrate)
  end

  return {
    take = take,
    rate = rate,
    channels = channels,
    position = reaper.GetMediaItemInfo_Value(item, "D_POSITION"),
    length = reaper.GetMediaItemInfo_Value(item, "D_LENGTH"),
    startoffs = reaper.GetMediaItemTakeInfo_Value(take, "D_STARTOFFS"),
  }
end

-- Read `count` frames of one channel, starting at a timeline position, as a
-- 0-based Lua table. Returns nil + reason when REAPER has no audio there.
--   timeline -> source:  source_time = startoffs + (timeline - position)
local function readChannel(accessor, info, timeline_start, count, rate, channel)
  local source_time = info.startoffs + (timeline_start - info.position)
  if source_time < 0 then return nil, "analysis window starts before the take" end

  local buffer = reaper.new_array(count * info.channels)
  buffer.clear()
  local ok = reaper.GetAudioAccessorSamples(
    accessor, rate, info.channels, source_time, count, buffer)
  if not ok or ok <= 0 then return nil, "no audio at the analysis window" end

  local out = {}
  local idx = channel
  for i = 0, count - 1 do
    out[i] = buffer[idx] or 0
    idx = idx + info.channels
  end
  return out
end

-- Where the analysis window starts on the timeline.
-- It must be far enough inside the take that the search range fits on both
-- sides without reading before the take's audio: the accessor cannot reach
-- source time < 0, and a window that starts at the item position would leave the
-- whole "earlier than the reference" half of the search unreadable.
-- The analysis window must fit inside the material: reading past an item's end
-- returns zeros, and correlating against a mostly-zero buffer reports a
-- confident r for a window that is mostly silence. Returns seconds, or nil.
local function windowSecondsFor(info)
  local search = CONFIG.search_ms / 1000
  local available = (info.length or 0) - 2 * search
  if available <= 0 then return nil end
  local wanted = CONFIG.window_ms / 1000
  return math.min(wanted, available), available < wanted
end

local function windowStartFor(info)
  local search = CONFIG.search_ms / 1000
  local earliest = info.position - info.startoffs   -- timeline of source time 0
  return math.max(info.position, earliest + search)
end

local function rms(samples, first, count)
  local sum, n = 0, 0
  for i = first, first + count - 1 do
    local v = samples[i] or 0
    sum = sum + v * v
    n = n + 1
  end
  if n == 0 then return 0 end
  return math.sqrt(sum / n)
end

-- ===================================
-- CORRELATION CORE
-- ===================================
-- Pure Lua, no REAPER calls: the tests drive these directly with synthetic
-- signals whose offset is known exactly.
local Core = {}

-- First difference: a cheap high-pass that emphasises attacks and removes DC and
-- low-frequency rumble, which otherwise dominate a raw cross-correlation on
-- close-miked DI tracks.
function Core.derivative(samples, first, count)
  local out = {}
  local prev = samples[first - 1] or 0
  for i = first, first + count - 1 do
    local v = samples[i] or 0
    out[i - first] = v - prev
    prev = v
  end
  return out
end

-- Attack envelope: per block, the mean absolute first difference.
--
-- The coarse search runs over hundreds of lags, so it needs a signal several
-- times shorter than the audio. Averaging the *signed* signal would be wrong:
-- a DI track starts with a noise burst, and the mean of eight signed noise
-- samples is ~0 — it erases the attack we are looking for. Averaging the
-- absolute difference keeps it, and is polarity-blind, which is fine because the
-- fine pass decides the sign.
function Core.envelope(samples, first, count, factor)
  factor = math.max(1, math.floor(factor))
  local out = {}
  local oi, i, finish = 0, first, first + count - 1
  while i <= finish do
    local sum, k = 0, 0
    local prev = samples[i - 1] or 0
    local used = 0
    for _ = 1, factor do
      local v = samples[i]
      if v == nil then break end
      sum = sum + math.abs(v - prev)
      prev = v
      used = used + 1
      i = i + 1
    end
    if used == 0 then break end
    out[oi] = sum / used
    oi = oi + 1
  end
  return out
end

-- Pearson correlation of a[first..first+count-1] against b[first+offset..],
-- ignoring positions where either side is missing. Returns 0 for degenerate input.
local function pearson(a, b, offset, first, count)
  local sa, sb, n = 0, 0, 0
  for k = first, first + count - 1 do
    local av, bv = a[k], b[k + offset]
    if av ~= nil and bv ~= nil then
      sa, sb, n = sa + av, sb + bv, n + 1
    end
  end
  if n < 8 then return 0 end
  local ma, mb = sa / n, sb / n
  local num, da, db = 0, 0, 0
  for k = first, first + count - 1 do
    local av, bv = a[k], b[k + offset]
    if av ~= nil and bv ~= nil then
      av, bv = av - ma, bv - mb
      num = num + av * bv
      da = da + av * av
      db = db + bv * bv
    end
  end
  if da <= 1e-20 or db <= 1e-20 then return 0 end
  return num / math.sqrt(da * db)
end

-- Find the lag (in samples) that best aligns b onto a.
--   a, b      0-based tables of samples at identical timeline positions
--   max_lag   samples searched in each direction
-- Returns best_lag, coefficient, confidence, reason.
--
-- Sign convention: if b's audio arrives L samples LATER than a's, the best lag
-- is +L, and b must move by -L / rate seconds to line up.
function Core.findLag(a, b, max_lag, coarse_factor)
  max_lag = math.max(1, math.floor(max_lag))
  coarse_factor = math.max(1, math.floor(coarse_factor or 8))

  local n = math.min(#a + 1, #b + 1) -- tables are 0-based
  if n < 256 then return nil, 0, 0, "analysis window too short" end

  -- Search window: leave max_lag of overlap on each side so every lag in range
  -- compares the same amount of audio.
  local full_margin = math.min(max_lag, math.floor(n / 4))
  local count = n - 2 * full_margin
  if count < 64 then return nil, 0, 0, "analysis window too short" end

  -- Coarse pass: envelope, decimated, whole search range.
  local ea = Core.envelope(a, full_margin, count, coarse_factor)
  local eb = Core.envelope(b, full_margin, count, coarse_factor)
  local ecount = math.min(#ea + 1, #eb + 1)
  local coarse_max = math.max(1, math.ceil(max_lag / coarse_factor))
  local emargin = math.min(coarse_max, math.floor(ecount / 4))
  if ecount - 2 * emargin < 8 then return nil, 0, 0, "analysis window too short" end

  -- Score every coarse lag, then keep the best few. A single winner is not
  -- enough: the envelope is a smoothed version of the attack, so its peak can
  -- sit a block or two away from the true lag, and a fine search around only one
  -- candidate then locks onto the edge of its search range.
  local candidates = {}
  for lag = -coarse_max, coarse_max do
    local r = pearson(ea, eb, lag, emargin, ecount - 2 * emargin)
    candidates[#candidates + 1] = { lag = lag, r = r }
  end
  table.sort(candidates, function(x, y) return x.r > y.r end)

  local best_lag, best_r, best_abs = 0, 0, -2
  local tried = {}
  for i = 1, math.min(5, #candidates) do
    local centre = candidates[i].lag * coarse_factor
    for lag = centre - coarse_factor, centre + coarse_factor do
      if math.abs(lag) <= max_lag and not tried[lag] then
        tried[lag] = true
        local r = pearson(a, b, lag, full_margin, count)
        -- Align on |r|, not on r: an inverted take correlates strongly *negative*
        -- at the correct lag, and maximising r would walk away from it to the
        -- nearest place where the signal merely decorrelates.
        if math.abs(r) > best_abs then
          best_lag, best_r, best_abs = lag, r, math.abs(r)
        end
      end
    end
  end

  -- Confidence: how much better the winner is than the best value a long way
  -- from it. A flat surface means this pair cannot be aligned by moving one of
  -- them, whatever the single best number happens to be.
  local far = math.max(2, math.floor(max_lag / 2))
  local far_abs = 0
  for _, lag in ipairs({ best_lag - far, best_lag + far }) do
    if math.abs(lag) <= max_lag then
      local r = math.abs(pearson(a, b, lag, full_margin, count))
      if r > far_abs then far_abs = r end
    end
  end

  return best_lag, best_r, best_abs - far_abs
end


-- First position where the envelope crosses `threshold_db` (dBFS), searching
-- within the analysed block. Returns a 0-based sample index or nil.
function Core.findOnset(samples, count, threshold_db, rate)
  local threshold = 10 ^ (threshold_db / 20)
  -- 2 ms envelope, to survive single-sample spikes without smoothing away attacks
  local span = math.max(1, math.floor(rate * 0.002))
  local peak = 0
  for i = 0, count - 1 do
    local v = math.abs(samples[i] or 0)
    if v > peak then peak = v end
    if v >= threshold then return i end
  end
  if peak > 0 then return 0 end
  return nil
end

-- ===================================
-- TRACK ANALYSIS
-- ===================================

local function analysisRate(reference, other)
  -- Both accessors are asked for the same rate so the comparison is like for
  -- like; REAPER resamples internally. Use the lower of the two source rates so
  -- nothing is upsampled past what the material contains.
  local rate = math.min(reference.rate, other.rate)
  if rate <= 0 then rate = 48000 end
  return math.floor(rate)
end

-- Pick the item on `track` that overlaps the reference window best.
local function pickItem(items, window_start, window_end)
  for _, item in ipairs(items) do
    local pos = reaper.GetMediaItemInfo_Value(item, "D_POSITION")
    local len = reaper.GetMediaItemInfo_Value(item, "D_LENGTH")
    if pos <= window_end and pos + len >= window_start then
      return item
    end
  end
  return nil
end

-- Analyse one candidate track against the reference.
-- Returns a result table; on failure it carries .reason and no .lag.
local function analyseTrack(track, reference)
  local result = { track = track, name = trackName(track) }

  local items = getTrackItems(track)
  if #items == 0 then
    result.reason = "no items"
    return result
  end

  local window_start = reference.window_start
  local window_end = window_start + CONFIG.window_ms / 1000

  local item = pickItem(items, window_start, window_end)
  if not item then
    result.reason = "no item overlaps the reference window"
    return result
  end
  result.item = item

  local info, reason = takeAudioInfo(item)
  if not info then
    result.reason = reason
    return result
  end

  local rate = analysisRate(reference.info, info)
  local window_seconds, _ = windowSecondsFor(info)
  if not window_seconds or window_seconds < (reference.window_seconds or 0) * 0.999 then
    result.reason = string.format(
      "item is shorter than the %.0f ms analysis window",
      (reference.window_seconds or 0) * 1000)
    return result
  end
  local window_frames = math.floor((reference.window_seconds or window_seconds) * rate)
  local max_lag = math.floor(CONFIG.search_ms / 1000 * rate)
  local total = window_frames + 2 * max_lag

  local accessor = reaper.CreateTakeAudioAccessor(info.take)
  if not accessor then
    result.reason = "could not create an audio accessor"
    return result
  end

  -- Read a block that is `max_lag` longer on each side so the search range is
  -- covered without another REAPER call.
  local read_start = window_start - CONFIG.search_ms / 1000
  local samples, read_reason = readChannel(
    accessor, info, read_start, total, rate, CONFIG.channel)
  reaper.DestroyAudioAccessor(accessor)

  if not samples then
    result.reason = read_reason
    return result
  end

  result.rate = rate
  result.samples = samples
  result.frames = total
  result.max_lag = max_lag
  result.window_start = window_start

  local level = rms(samples, 0, total)
  result.rms = level
  if level < 1e-4 then
    result.reason = "silent (RMS below -80 dBFS)"
    return result
  end

  -- Sanity: the reference must have been read at the same rate to compare.
  if rate ~= reference.rate then
    result.reason = string.format(
      "sample rate %d differs from the reference (%d)", rate, reference.rate)
    return result
  end

  return result
end

-- ===================================
-- MAIN ACTIONS
-- ===================================

local function describeLevel(rms_value)
  if rms_value <= 0 then return "-inf dBFS" end
  return string.format("%.1f dBFS", 20 * math.log(rms_value, 10))
end

local function alignSelectedTracks()
  local tracks = getSelectedTracks()
  if #tracks < 2 then
    msg("❌ Please select at least 2 tracks to align")
    msg("   (e.g. Rhythm L and Rhythm R guitar tracks)")
    return
  end

  msg(string.format("Analysing with a %.0f ms window, ±%.0f ms search, minimum r = %.2f%s",
    CONFIG.window_ms, CONFIG.search_ms, CONFIG.min_correlation,
    CONFIG.apply and "" or "  [measure only]"))

  -- Reference: the first selected track that has usable audio.
  local reference, reference_index
  for i, track in ipairs(tracks) do
    local items = getTrackItems(track)
    if #items > 0 then
      local info, reason = takeAudioInfo(items[1])
      if info then
        reference_index = i
        reference = { track = track, info = info, item = items[1] }
        break
      else
        msg(string.format("  ! %s skipped as reference (%s)", trackName(track), reason))
      end
    end
  end

  if not reference then
    msg("❌ No track with usable audio to use as the reference")
    return
  end

  reference.window_start = windowStartFor(reference.info)
  reference.rate = 0 -- filled below once frames are read
  -- The candidate is analysed by analyseTrack(); give it the sample rate up
  -- front, because analysisTrack() compares against reference.rate and would
  -- otherwise reject every track for "differing" from 0.
  reference.rate = math.floor(reference.info.rate)

  local rate = math.floor(reference.info.rate)
  reference.rate = rate

  local window_seconds, was_capped = windowSecondsFor(reference.info)
  if not window_seconds or window_seconds < 0.05 then
    msg(string.format(
      "❌ The reference item is too short for this analysis (%.0f ms available, "
        .. "need at least 50 ms plus the search range)", (reference.info.length or 0) * 1000))
    return
  end
  if was_capped then
    msg(string.format("   (window shortened to %.0f ms to fit the item)",
      window_seconds * 1000))
  end
  reference.window_seconds = window_seconds

  local window_frames = math.floor(window_seconds * rate)
  local max_lag = math.floor(CONFIG.search_ms / 1000 * rate)
  local total = window_frames + 2 * max_lag

  local accessor = reaper.CreateTakeAudioAccessor(reference.info.take)
  if not accessor then
    msg("❌ Could not create an audio accessor for the reference track")
    return
  end
  local read_start = reference.window_start - CONFIG.search_ms / 1000
  local ref_samples, ref_reason = readChannel(
    accessor, reference.info, read_start, total, rate, CONFIG.channel)
  reaper.DestroyAudioAccessor(accessor)

  if not ref_samples then
    msg("❌ Reference track: " .. tostring(ref_reason))
    return
  end

  local ref_rms = rms(ref_samples, 0, total)
  if ref_rms < 1e-4 then
    msg(string.format("❌ Reference track '%s' is silent at %.3fs (%s)",
      trackName(reference.track), reference.window_start, describeLevel(ref_rms)))
    msg("   Move the analysis window or pick another reference.")
    return
  end

  msg(string.format("\nReference: %s  (%.3fs, %s)",
    trackName(reference.track), reference.window_start, describeLevel(ref_rms)))
  msg("")

  -- Analysis pass: everything is measured before anything moves, so a failure
  -- halfway through cannot leave the project half-aligned.
  local plan = {}
  for i, track in ipairs(tracks) do
    if i == reference_index then
      plan[#plan + 1] = { track = track, name = trackName(track), is_reference = true }
    else
      local result = analyseTrack(track, reference)
      if result.reason then
        msg(string.format("  ✗ %s: %s", result.name, result.reason))
      else
        local lag, r, confidence = Core.findLag(ref_samples, result.samples,
          math.min(max_lag, result.max_lag), 8)
        result.lag = lag
        result.r = r
        result.confidence = confidence

        if not lag then
          msg(string.format("  ✗ %s: %s", result.name, tostring(r)))
        else
          local offset = -lag / rate
          result.offset = offset
          msg(string.format(
            "  %s %s: %+d samples (%+.3f ms)  r = %+.2f  confidence = %.2f",
            math.abs(r) >= CONFIG.min_correlation and "·" or "!",
            result.name, -lag, offset * 1000, r, confidence))
          if r < -CONFIG.min_correlation then
            msg("      ⚠ this take is POLARITY INVERTED relative to the reference")
          elseif math.abs(r) < CONFIG.min_correlation then
            msg(string.format("      ⚠ correlation below %.2f — not a reliable alignment",
              CONFIG.min_correlation))
          end
        end
      end
      plan[#plan + 1] = result
    end
  end

  -- Decide what is actually applicable.
  local movable = {}
  for _, entry in ipairs(plan) do
    if not entry.is_reference and entry.offset
        and math.abs(entry.offset) > 0.5 / rate
        and math.abs(entry.r or 0) >= CONFIG.min_correlation then
      movable[#movable + 1] = entry
    end
  end

  if #movable == 0 then
    msg("\n✅ Nothing to move: every track is already aligned within one sample")
    return
  end

  if not CONFIG.apply then
    msg(string.format("\n[measure only] %d track(s) would move. Turn apply on in option 7.",
      #movable))
    return
  end

  msg("")
  local saved_cursor = reaper.GetCursorPosition()
  local sel_start, sel_end = reaper.GetSet_LoopTimeRange(false, false, 0, 0, false)

  reaper.PreventUIRefresh(1)
  reaper.Undo_BeginBlock()

  for _, entry in ipairs(movable) do
    local current = reaper.GetMediaItemInfo_Value(entry.item, "D_POSITION")
    reaper.SetMediaItemInfo_Value(entry.item, "D_POSITION", current + entry.offset)
    msg(string.format("  → moved %s by %+.3f ms", entry.name, entry.offset * 1000))
  end

  reaper.Undo_EndBlock("Align Tracks by Cross-Correlation", -1)
  reaper.PreventUIRefresh(-1)
  reaper.SetEditCurPos(saved_cursor, false, false)
  reaper.GetSet_LoopTimeRange(true, false, sel_start, sel_end, false)
  reaper.UpdateArrange()

  msg(string.format("\n✅ Aligned %d track(s) to '%s'",
    #movable, trackName(reference.track)))
  msg("")
  msg("NEXT STEPS:")
  msg("  1. Listen for a tight 'wall' rather than a phasey 'whoosh'")
  msg("  2. Check the mono button: the sum should get louder, not thinner")
  msg("  3. Run option 2 to re-measure — a good result reads r ≈ +1.00 at 0 samples")
end

-- Correlation report between exactly two tracks, computed from the audio.
local function analyzePhaseCorrelation()
  local tracks = getSelectedTracks()
  if #tracks ~= 2 then
    msg("❌ Select exactly 2 tracks for the correlation check")
    return
  end

  local info1, reason1 = takeAudioInfo((getTrackItems(tracks[1]))[1] or {})
  local info2, reason2 = takeAudioInfo((getTrackItems(tracks[2]))[1] or {})
  if not info1 then
    msg("❌ " .. trackName(tracks[1]) .. ": " .. tostring(reason1))
    return
  end
  if not info2 then
    msg("❌ " .. trackName(tracks[2]) .. ": " .. tostring(reason2))
    return
  end

  local rate = analysisRate(info1, info2)
  local w1 = windowSecondsFor(info1)
  local w2 = windowSecondsFor(info2)
  local window_seconds = math.min(w1 or 0, w2 or 0)
  if window_seconds < 0.05 then
    msg("❌ One of the takes is too short for the analysis window")
    return
  end
  local frames = math.floor(window_seconds * rate)
  local max_lag = math.floor(CONFIG.search_ms / 1000 * rate)
  local total = frames + 2 * max_lag
  -- Both takes must be read at the same positions; start where both have audio
  -- and leave room for the search range.
  local start = math.max(windowStartFor(info1), windowStartFor(info2))

  local function grab(info)
    local accessor = reaper.CreateTakeAudioAccessor(info.take)
    if not accessor then return nil end
    local samples = readChannel(accessor, info, start - CONFIG.search_ms / 1000,
      total, rate, CONFIG.channel)
    reaper.DestroyAudioAccessor(accessor)
    return samples
  end

  local a, b = grab(info1), grab(info2)
  if not a then msg("❌ No audio in the analysis window on " .. trackName(tracks[1])) return end
  if not b then msg("❌ No audio in the analysis window on " .. trackName(tracks[2])) return end

  local lag, r = Core.findLag(a, b, max_lag, 8)
  msg(string.format("Correlation: r = %+.3f at %+d samples (%+.3f ms)",
    r, -lag, -lag / rate * 1000))

  if r < -CONFIG.min_correlation then
    msg("⚠ INVERTED: the two takes are in opposite polarity")
  elseif math.abs(r) < CONFIG.min_correlation then
    msg("⚠ LOW correlation: these takes may be different performances")
  elseif math.abs(lag) <= 1 then
    msg("✅ Sample-aligned and in phase")
  else
    msg(string.format("Misaligned by %.3f ms — run option 1", math.abs(lag) / rate * 1000))
  end
end

local function nudgeSelectedItems(direction, amount)
  local count = reaper.CountSelectedMediaItems(0)
  if count == 0 then
    msg("No items selected")
    return
  end

  local saved_cursor = reaper.GetCursorPosition()
  reaper.Undo_BeginBlock()
  reaper.PreventUIRefresh(1)

  local delta = amount * direction
  for i = 0, count - 1 do
    local item = reaper.GetSelectedMediaItem(0, i)
    if item then
      local pos = reaper.GetMediaItemInfo_Value(item, "D_POSITION")
      reaper.SetMediaItemInfo_Value(item, "D_POSITION", pos + delta)
    end
  end

  reaper.Undo_EndBlock("Nudge Items", -1)
  reaper.PreventUIRefresh(-1)
  reaper.SetEditCurPos(saved_cursor, false, false)
  reaper.UpdateArrange()

  local rate = 48000
  local ok, srate = reaper.GetAudioDeviceInfo("SRATE", "")
  if ok and tonumber(srate) then rate = tonumber(srate) end
  msg(string.format("Nudged %d item(s) by %+.4f s (%.1f samples @ %d Hz)",
    count, delta, delta * rate, math.floor(rate)))
end

-- ===================================
-- SETTINGS
-- ===================================

local function editSettings()
  local ok, retvals = reaper.GetUserInputs(
    "Phase Alignment Settings", 4,
    string.format("Analysis window (ms, 20-5000)=%d,Search range (ms, 1-500)=%d,"
      .. "Minimum correlation (0-1)=%.2f,Apply moves (1=yes 0=no)=%d",
      math.floor(CONFIG.window_ms), math.floor(CONFIG.search_ms),
      CONFIG.min_correlation, CONFIG.apply and 1 or 0),
    string.format("%d,%d,%.2f,%d", math.floor(CONFIG.window_ms),
      math.floor(CONFIG.search_ms), CONFIG.min_correlation,
      CONFIG.apply and 1 or 0))
  if not ok then return end

  local w, s, m, a = (retvals or ""):match("([^,]*),([^,]*),([^,]*),([^,]*)")
  if not w then
    msg("Settings unchanged (could not read the values).")
    return
  end

  CONFIG.window_ms = clamp(tonumber(w) or CONFIG.window_ms, 20, 5000)
  CONFIG.search_ms = clamp(tonumber(s) or CONFIG.search_ms, 1, 500)
  CONFIG.min_correlation = clamp(tonumber(m) or CONFIG.min_correlation, 0, 1)
  CONFIG.apply = (tonumber(a) == 1)

  saveSettings()
  msg(string.format("Settings saved: window %.0f ms, search ±%.0f ms, min r %.2f, apply %s",
    CONFIG.window_ms, CONFIG.search_ms, CONFIG.min_correlation,
    CONFIG.apply and "on" or "off"))
end

-- ===================================
-- MAIN MENU
-- ===================================

-- Test seam: the regression suite sets the global SGM_TEST_HOST before running
-- this file, and gets the pure-Lua correlation core back. In REAPER the global
-- never exists, so this costs one table lookup and nothing else.
local test_host = rawget(_G, "SGM_TEST_HOST")
if type(test_host) == "table" then
  test_host.phase = {
    Core = Core,
    CONFIG = CONFIG,
    analyseTrack = analyseTrack,
    readChannel = readChannel,
    takeAudioInfo = takeAudioInfo,
  }
end

local function showMenu()
  local ok, answer = reaper.GetUserInputs(
    "Phase Alignment Tool", 1,
    "1=Auto-Align to Reference  2=Check Correlation  3=Nudge Left 1ms  "
      .. "4=Nudge Right 1ms  5=Nudge Left 0.1ms  6=Nudge Right 0.1ms  "
      .. "7=Settings",
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
    editSettings()
  end
end

reaper.ClearConsole()
msg("=== PHASE ALIGNMENT TOOL 2.0 ===")
msg(Utils and "shared library: SGM_Utils loaded" or "shared library: using local fallback")
msg("")
showMenu()
