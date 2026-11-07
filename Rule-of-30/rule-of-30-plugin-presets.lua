-- @description Plugin chain presets for the Rule of 30 session builder (stock REAPER FX, real settings)
-- @author Scott Mills
-- @version 3.0.0
-- @changelog
--   3.0.0 (2026-11-07)
--     + Fix: values are no longer hand-guessed normalized numbers. Each setting
--       is written in the units the plug-in itself shows (-18 dB, 10 ms, 3.5 kHz)
--       and converted at apply time by Utils.fx_normalize(), which reads the
--       plug-in's own formatting back to find the matching 0..1 position. The
--       old table paired 0.55 with "-18 dB" and hoped; the real position is 0.58
--       and a guessed 0.55 is a different threshold.
--     + Add: ReaEQ settings go through TrackFX_SetEQParam (band type / band index
--       / freq / gain / Q), because ReaEQ's raw parameter list is not laid out as
--       band/freq/gain and does not expose those as searchable parameters.
--     + Add: Presets.apply() - the chain application logic lives next to the data
--       it validates, and reports values it could not set instead of skipping
--       them silently.
--     + Change: `wet` is the one setting written as a normalized value, because
--       a wet/dry mix has no unit to convert.
--   2.0.0 (2026-11-07)
--     + Rewrite: this file was a list of Waves / iZotope / FabFilter / Neural DSP
--       plugin *names* that the session builder never read. It is now a set of
--       concrete stock-FX presets (ReaEQ / ReaComp / ReaGate / ReaVerbate /
--       ReaDelay) that the builder applies.
--     + Chain keys match the track names the builder actually creates
--       ("Kick In (Click)", "Bass DI (Lows <200Hz)", "Lead Vocal", ...).
--   1.0.1 (2026-10-08)
--     + Top Shelf audit: localize helper functions (no global leaks)
--   1.0.0 (2026-05-23)
--     + Initial release
-- @noindex
-- @about
--   ## Rule of 30 Plugin Presets
--   Stock-FX starting points for the Rule of 30 session builder.
--   Not runnable on its own: `rule-of-30-session-builder.lua` loads it from the
--   same folder. Each entry is { plugin, params, note } where `params` maps a
--   plug-in parameter NAME to a value in that parameter's own units.

-- ===================================
-- HOW VALUES ARE EXPRESSED
-- ===================================
-- Written in the units the plug-in displays, and converted at apply time:
--
--   key("ReaComp", { threshold = -18, ratio = 3, attack = 10, release = 120 },
--       "glue")
--
-- Utils.fx_normalize() asks the plug-in what it shows at position 0 and 1, then
-- bisects to the requested value, so the setting lands where it says it does
-- without anyone hand-mapping the range. If a plug-in refuses to format the
-- value (many third-party plug-ins do), Presets.apply() reports it and moves on
-- rather than writing a guess.
--
-- `wet` is normalized 0..1 on purpose: a wet/dry mix has no unit.
-- ReaEQ is different again - its bands are not exposed as searchable raw
-- parameters, so eq() drives TrackFX_SetEQParam with a band type instead.

local Presets = {}

-- Shortcut for "one FX, a few parameters in the plug-in's own units".
local function fx(plugin, params, note)
  return { plugin = plugin, params = params or {}, note = note }
end

-- A ReaEQ band. bandtype follows TrackFX_SetEQParam:
--   0 = high-pass, 1 = low shelf, 2 = band, 4 = high shelf, 5 = low-pass.
local EQ_BANDS = { hp = 0, loshelf = 1, band = 2, hishelf = 4, lp = 5 }

local function eq(bandtype, band, freq, gain, q, note)
  return {
    plugin = "ReaEQ",
    eq = {
      bandtype = EQ_BANDS[bandtype] or bandtype,
      bandidx = (band or 1) - 1,       -- API is 0-based within the band type
      freq = freq,
      gain = gain,
      q = q,
    },
    note = note,
  }
end

Presets.chains = {

  -- ===============================
  -- DRUMS
  -- ===============================
  ["Kick In (Click)"] = {
    fx("ReaGate", { threshold = -30, attack = 1, release = 80 },
      "gate the bleed out of the beater mic"),
    eq("band", 1, 3500, 3, nil, "presence, by ear"),
  },

  ["Kick Out (Body)"] = {
    eq("hp", 1, 40, nil, nil, "high-pass: leave the sub to Kick Sub"),
    fx("ReaComp", { threshold = -18, ratio = 6, attack = 5, release = 120 },
      "fast, hard compression for weight"),
  },

  ["Kick Sub (40-60Hz)"] = {
    eq("hp", 1, 30, nil, nil, "isolate the fundamental"),
  },

  ["Snare Top"] = {
    eq("band", 1, 4000, 3, nil, "crack"),
    fx("ReaComp", { threshold = -20, ratio = 4, attack = 10, release = 150 },
      "glue the crack"),
  },

  ["Snare Bottom"] = {
    eq("band", 1, 3000, 0, nil, "snare-wire range, flat to start"),
    fx("ReaGate", { threshold = -24, attack = 1, release = 60 },
      "keep the hats out"),
  },

  ["Glitch Snare (Duplicate)"] = {
    fx("ReaComp", { threshold = -35, ratio = 20 },
      "deliberately crushed parallel-style trigger"),
  },

  ["OH Left"] = { eq("hp", 1, 300, nil, nil, "cymbals only") },
  ["OH Right"] = { eq("hp", 1, 300, nil, nil, "cymbals only") },

  ["Room Mono (Crushed)"] = {
    fx("ReaComp", { threshold = -40, ratio = 20, attack = 30, release = 200 },
      "smash it for room character"),
  },

  ["Tom Rack"] = { eq("hp", 1, 60, nil, nil, "start flat: tune before processing") },
  ["Tom Floor"] = { eq("hp", 1, 40, nil, nil, "start flat: tune before processing") },

  -- ===============================
  -- BASS
  -- ===============================
  ["Bass DI (Lows <200Hz)"] = {
    eq("lp", 1, 200, nil, nil, "this track owns the lows"),
    fx("ReaComp", { threshold = -18, ratio = 4, attack = 5, release = 120 },
      "level control; sidechain input comes from the kick"),
  },

  ["Bass Amp (Mids 200-2k)"] = {
    eq("hp", 1, 200, nil, nil, "high-pass out of the kick's way"),
  },

  ["Bass Fuzz (Highs >2k)"] = {
    eq("hp", 1, 2000, nil, nil, "fuzz only adds the top"),
  },

  ["Bass Synth Layer (Sub)"] = {
    eq("lp", 1, 80, nil, nil, "sub only"),
  },

  -- ===============================
  -- GUITARS
  -- ===============================
  ["Rhythm L1 (100% L)"] = {
    eq("hp", 1, 90, nil, nil, "DIs need the mud gone before the amp sim"),
  },
  ["Rhythm R1 (100% R)"] = {
    eq("hp", 1, 90, nil, nil, "as left"),
  },
  ["Rhythm L2 (80% L)"] = {
    eq("hp", 1, 110, nil, nil, "slightly higher so the second pair sits behind the first"),
  },
  ["Rhythm R2 (80% R)"] = {
    eq("hp", 1, 110, nil, nil, "as left"),
  },

  ["Octave Lead L"] = { eq("band", 1, 2500, 2, nil, "cut through") },
  ["Octave Lead R"] = { eq("band", 1, 2500, 2, nil, "cut through") },
  ["The Scrape (FX)"] = { eq("hp", 1, 200, nil, nil, "sound design: process to taste") },
  ["Clean Ambient (Wet)"] = {
    fx("ReaVerbate", { wet = 0.55, room_size = 0.70 }, "long ambient wash"),
  },

  -- ===============================
  -- GLITCH / ATMOSPHERE
  -- ===============================
  ["White Noise Risers"] = {
    eq("bp", 1, 1000, nil, nil, "band-limit the noise"),
  },
  ["Impact Booms"] = {
    fx("ReaComp", { threshold = -25, ratio = 8 }, "tame the peaks"),
  },
  ["Digital Artifacts"] = { eq("hp", 1, 200, nil, nil, "sound design") },
  ["Dark Pad (Minor)"] = {
    fx("ReaVerbate", { wet = 0.45, room_size = 0.80 }, "space"),
  },
  ["Arpeggiator"] = { fx("ReaDelay", { wet = 0.30 }, "rhythmic echo") },
  ["Reverse Piano"] = {
    fx("ReaVerbate", { wet = 0.50, room_size = 0.75 }, "space"),
  },

  -- ===============================
  -- VOCALS
  -- ===============================
  ["Lead Vocal"] = {
    eq("hp", 1, 100, nil, nil, "clean up the low end"),
    fx("ReaComp", { threshold = -20, ratio = 3, attack = 10, release = 150 },
      "3:1, gentle"),
  },
  ["Double Vocal"] = {
    fx("ReaComp", { threshold = -22, ratio = 2.5 }, "subordinate to the lead"),
  },
  ["Demon Layer (-12st)"] = {
    eq("hp", 1, 150, nil, nil, "dark and narrow"),
  },
  ["Telephonic (500-3k BP)"] = {
    eq("bp", 1, 1500, nil, nil, "band-pass: this is the effect, tune both edges by ear"),
  },
  ["Whisper L (ASMR)"] = {
    eq("hp", 1, 150, nil, nil, "remove the rumble"),
  },
  ["Whisper R (ASMR)"] = {
    eq("hp", 1, 150, nil, nil, "remove the rumble"),
  },
  ["Scream High L"] = {
    fx("ReaComp", { threshold = -24, ratio = 10 }, "hold the scream down"),
  },
  ["Scream High R"] = {
    fx("ReaComp", { threshold = -24, ratio = 10 }, "hold the scream down"),
  },
  ["Growl Center"] = {
    eq("hp", 1, 120, nil, nil, "make room for the lead"),
  },
  ["Ad-lib 1"] = { fx("ReaVerbate", { wet = 0.35, room_size = 0.55 }, "throw") },
  ["Ad-lib 2"] = { fx("ReaVerbate", { wet = 0.35, room_size = 0.55 }, "throw") },
  ["Ad-lib 3"] = { fx("ReaVerbate", { wet = 0.35, room_size = 0.55 }, "throw") },

  -- ===============================
  -- SEND FX BUSES
  -- ===============================
  ["Hall Reverb"] = {
    fx("ReaVerbate", { wet = 1.0, room_size = 0.90 }, "100% wet: it is a bus"),
  },
  ["Plate Reverb"] = {
    fx("ReaVerbate", { wet = 1.0, room_size = 0.55 }, "100% wet"),
  },
  ["1/4 Note Delay"] = {
    fx("ReaDelay", { wet = 1.0 }, "100% wet; set the time to 1/4"),
  },
  ["1/8 Dotted Delay"] = {
    fx("ReaDelay", { wet = 1.0 }, "100% wet; set the time to 1/8 dotted"),
  },
  ["Parallel Drum Crush"] = {
    fx("ReaComp", { threshold = -50, ratio = 20 }, "heavily crushed"),
  },
}

-- ===================================
-- APPLYING A CHAIN
-- ===================================
-- `addFx(track, plugin)` is injected by the caller so this file never has to
-- know how the builder instantiates plug-ins. It must return (fx_index, added).
--
-- Returns added, skipped, problems:
--   added    number of plug-ins actually inserted
--   skipped  list of plug-in names the track already had
--   problems list of human-readable strings for anything that did not resolve
function Presets.apply(track, label, chain, addFx)
  local added, skipped, problems = 0, {}, {}
  if not chain then return added, skipped, problems end

  for _, entry in ipairs(chain) do
    local fx_index, was_added = addFx(track, entry.plugin)
    if not fx_index then
      problems[#problems + 1] =
        string.format("%s: %s not available", label, entry.plugin)
    elseif not was_added then
      skipped[#skipped + 1] = entry.plugin
    else
      added = added + 1
      if entry.eq then
        local written, err = Presets.applyEq(track, fx_index, entry.eq)
        if not written then
          problems[#problems + 1] =
            string.format("%s: %s band not set (%s)", label, entry.plugin,
              tostring(err))
        end
      end
      for param_name, wanted in pairs(entry.params or {}) do
        local written, err = Presets.applyParam(track, fx_index, param_name, wanted)
        if not written then
          problems[#problems + 1] =
            string.format("%s: %s %s (%s)", label, entry.plugin, param_name,
              tostring(err))
        end
      end
    end
  end
  return added, skipped, problems
end

-- Map friendly parameter keys to the name fragment the plug-in uses. Stock
-- REAPER plug-ins spell these out; the mapping keeps the tables readable.
local PARAM_ALIASES = {
  threshold = "Threshold",
  ratio = "Ratio",
  attack = "Attack",
  release = "Release",
  knee = "Knee",
  room_size = "Room Size",
  ceiling = "Ceiling",
  wet = "Wet",
}

function Presets.paramName(key)
  return PARAM_ALIASES[key] or key
end

-- Write one parameter. `wet` is a plain 0..1 mix; everything else is in the
-- plug-in's own units and has to be converted, or not written at all.
function Presets.applyParam(track, fx_index, key, wanted)
  if key == "wet" then
    if type(wanted) ~= "number" then return false, "not a number" end
    local idx = Presets.resolveParam(track, fx_index, "Wet")
    if not idx then return false, "no Wet parameter" end
    reaper.TrackFX_SetParamNormalized(track, fx_index, idx,
      math.max(0, math.min(1, wanted)))
    return true
  end

  local name = Presets.paramName(key)
  local idx = Presets.resolveParam(track, fx_index, name)
  if not idx then return false, "parameter not found" end

  local Utils = Presets.Utils
  if not (Utils and Utils.fx_normalize) then
    return false, "SGM_Utils.fx_normalize unavailable"
  end
  local normalized = Utils.fx_normalize(track, fx_index, idx, wanted)
  if not normalized then
    return false, "plug-in would not format this parameter"
  end
  reaper.TrackFX_SetParamNormalized(track, fx_index, idx, normalized)
  return true
end

-- ReaEQ bands are not searchable raw parameters; the dedicated API is the
-- documented way to touch them.
function Presets.applyEq(track, fx_index, band)
  local ok = reaper.TrackFX_SetEQBandEnabled(track, fx_index,
    band.bandtype, band.bandidx, true)
  if ok == false then return false, "not a ReaEQ instance" end
  if band.freq then
    reaper.TrackFX_SetEQParam(track, fx_index, band.bandtype, band.bandidx, 0, band.freq, false)
  end
  if band.gain then
    reaper.TrackFX_SetEQParam(track, fx_index, band.bandtype, band.bandidx, 1, band.gain, false)
  end
  if band.q then
    reaper.TrackFX_SetEQParam(track, fx_index, band.bandtype, band.bandidx, 2, band.q, false)
  end
  return true
end

-- Set by the loader (session builder) so this file can map parameter values
-- through the shared library when it is installed.
Presets.Utils = Presets.Utils

-- Parameter lookup.
--
-- The names above are how the parameters appear in REAPER's UI, but only some of
-- them are searchable: ReaEQ's individual band parameters are exposed as
-- "Band 2 Frequency" style names, while stock ReaComp parameters are simply
-- "Threshold", "Ratio", "Attack", "Release". Rather than trust either, the
-- builder resolves every name against the live parameter list with
-- TrackFX_GetParamName() and reports what it could not find.
function Presets.resolveParam(track, fx_index, wanted)
  local target = tostring(wanted):lower()
  for i = 0, reaper.TrackFX_GetNumParams(track, fx_index) - 1 do
    local _, name = reaper.TrackFX_GetParamName(track, fx_index, i, "")
    if name and name:lower():find(target, 1, true) then
      return i, name
    end
  end
  return nil, nil
end

-- Bus-level chains, applied by role rather than by track name.
Presets.buses = {
  master = {
    fx("ReaComp", { threshold = -14, ratio = 2 }, "2:1 glue"),
    eq("hp", 1, 30, nil, nil, "final shaping: tame the sub, flat otherwise"),
    fx("ReaLimit", { ceiling = -1.0 }, "safety limiter at -1 dBTP"),
  },
}

-- Keys are matched as substrings of the track name, longest first, so
-- "Rhythm L1 (100% L)" wins over a bare "Rhythm".
--
-- Note the em-dash style names the builder uses ("Rhythm L1 (100% L)") are
-- matched on the distinctive part only, so a user renaming a track keeps the
-- preset as long as the instrument name survives.
function Presets.forTrack(track_name)
  if not track_name then return nil end
  local best, best_len = nil, 0
  for key in pairs(Presets.chains) do
    if track_name:find(key, 1, true) and #key > best_len then
      best, best_len = key, #key
    end
  end
  return best and Presets.chains[best] or nil
end

-- True when the preset exists but the plugins it wants are not installed.
-- Returned so the builder can say "ReaXcomp not found" instead of silently
-- building a session that looks processed but is not.
function Presets.missingPluginsFor(track_name, is_installed)
  local chain = Presets.forTrack(track_name)
  if not chain then return {} end
  local missing = {}
  for _, entry in ipairs(chain) do
    if is_installed and not is_installed(entry.plugin) then
      missing[#missing + 1] = entry.plugin
    end
  end
  return missing
end

function Presets.list()
  local names = {}
  for key in pairs(Presets.chains) do names[#names + 1] = key end
  table.sort(names)
  return names
end

return Presets
