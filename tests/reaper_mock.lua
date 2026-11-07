-- @license MIT (c) 2026 Scott Mills / SGM Studios — see LICENSE; kept with the script when redistributed
-- Minimal in-memory stand-in for REAPER's ReaScript API.
--
-- Purpose: let the scripts' main code paths run in CI so that crashes,
-- nil-index errors and unbalanced undo/UI-refresh blocks are caught without a
-- REAPER install. It is deliberately small: only the functions the scripts
-- actually call are implemented.
--
-- Usage from a test:
--   local mock = dofile("tests/reaper_mock.lua")
--   local reaper = mock.new()
--   -- seed a project
--   local t1 = mock.add_track(reaper, "Kick")
--   mock.select(reaper, { t1 })
--   local err = mock.run_script(reaper, "../../SGM-Essentials/SGM_auto_master.lua")

local mock = {}

local function new_track(name)
  return {
    name = name or "",
    fx = {},
    sends = {},
    mainsend = 1,
    folderdepth = 0,
    vol = 1.0,
    pan = 0.0,
    color = nil,
    items = {},
  }
end

-- Parameter name tables so "find the parameter called Threshold" works.
local FX_PARAMS = {
  ReaEQ = { "Bypass", "Band 1 Enabled", "Band 1 Type", "Band 1 Frequency",
            "Band 1 Gain", "Band 1 Q" },
  ReaComp = { "Bypass", "Threshold", "Ratio", "Attack", "Release", "Knee", "Wet" },
  ReaLimit = { "Bypass", "Ceiling", "Release", "Gain" },
  ReaGate = { "Bypass", "Threshold" },
  ReaVerbate = { "Bypass", "Wet" },
}

-- Engineering ranges for the mock plug-ins, used by
-- TrackFX_FormatParamValueNormalized. "exp" models a frequency/threshold style
-- control; "lin" is linear.
local PARAM_RANGES = {
  ReaComp = {
    Threshold = { min = -60, max = 12, unit = " dB" },
    Ratio     = { min = 1, max = 20, unit = ":1" },
    Attack    = { min = 0, max = 500, unit = " ms" },
    Release   = { min = 0, max = 1000, unit = " ms" },
  },
  ReaLimit = {
    Ceiling = { min = -12, max = 0, unit = " dB" },
  },
  ReaEQ = {
    ["Band 1 Frequency"] = { min = 20, max = 22000, curve = "exp", unit = " Hz" },
  },
}

-- Create a directory tree, so scripts that write files can be tested for real.
local function mkdir_p(path)
  local parts, built = {}, ""
  for piece in tostring(path):gmatch("[^/\\]+") do parts[#parts + 1] = piece end
  if tostring(path):sub(1, 1) == "/" then built = "/" end
  for i, piece in ipairs(parts) do
    built = built .. piece .. (i < #parts and "/" or "")
    os.execute('mkdir -p "' .. built .. '" 2>/dev/null')
  end
  return 1
end

function mock.new()
  local r = {
    -- introspection / test hooks
    _tracks = {},
    _master = new_track("MASTER"),
    _selected = {},
    _messages = {},
    _ui_refresh = 0,
    _undo_depth = 0,
    _undo_begin_count = 0,
    _undo_end_count = 0,
    _user_input = "1",
    _mb_answer = 7,        -- default: "No"
    _mb_prompts = {},
    _tempo_markers = 0,
    _commands_run = {},
    _tempo_args = nil,
    _audio_device_closed = false,
    _action_section = 0,
    _action_command = 424242,
    _toggle_states = {},
    _extstate = {},
    _selected_items = {},
    _toolbar_refreshes = {},
  }

  -- console / app -------------------------------------------------------
  function r.ShowConsoleMsg(s) r._messages[#r._messages + 1] = tostring(s) end
  function r.ClearConsole() r._messages = {} end
  function r.GetOS() return r._os or "Win64" end
  function r.GetResourcePath() return r._resource_path or "/resource" end
  function r.GetExePath() return "/resource/reaper.exe" end
  function r.GetAppVersion() return "7.83/x64" end
  function r.time_precise() return 1.0 end
  function r.GetPlayPosition() return 0.0 end
  function r.UpdateArrange() end
  function r.RecursiveCreateDirectory(path) return mkdir_p(path) end
  function r.defer() end
  function r.Main_OnCommand(cmd) r._commands_run[#r._commands_run + 1] = cmd end

  -- modal dialogs ------------------------------------------------------
  function r.MB(_, text, _)
    r._mb_prompts[#r._mb_prompts + 1] = tostring(text)
    return r._mb_answer
  end
  function r.GetUserInputs(_, _, _, _) return true, r._user_input end

  -- undo / UI ----------------------------------------------------------
  function r.Undo_BeginBlock()
    r._undo_begin_count = r._undo_begin_count + 1
    r._undo_depth = r._undo_depth + 1
  end
  function r.Undo_EndBlock() 
    r._undo_end_count = r._undo_end_count + 1
    r._undo_depth = r._undo_depth - 1
  end
  function r.PreventUIRefresh(n) r._ui_refresh = r._ui_refresh + n end
  function r.GetCursorPosition() return 0.0 end
  function r.SetEditCurPos() end
  function r.GetSet_LoopTimeRange() return 0, 0 end

  -- tracks -------------------------------------------------------------
  function r.CountTracks() return #r._tracks end
  function r.GetTrack(_, i) return r._tracks[i + 1] end
  function r.GetMasterTrack() return r._master end
  function r.InsertTrackAtIndex(idx)
    table.insert(r._tracks, idx + 1, new_track(""))
  end
  function r.GetSetMediaTrackInfo_String(tr, _, name, set)
    if set then tr.name = name end
    return true, tr.name
  end
  function r.GetTrackName(tr) return true, tr.name end
  function r.SetTrackColor(tr, color) tr.color = color end
  function r.ColorToNative(rr, gg, bb) return rr * 65536 + gg * 256 + bb end
  function r.CountSelectedTracks() return #r._selected end
  function r.GetSelectedTrack(_, i) return r._selected[i + 1] end

  function r.GetMediaTrackInfo_Value(tr, key)
    if key == "I_FOLDERDEPTH" then return tr.folderdepth
    elseif key == "B_MAINSEND" then return tr.mainsend
    elseif key == "D_VOL" then return tr.vol
    elseif key == "D_PAN" then return tr.pan
    elseif key == "B_MUTE" then return 0
    elseif key == "I_SOLO" then return 0
    elseif key == "IP_TRACKNUMBER" then
      for i, track in ipairs(r._tracks) do
        if track == tr then return i end
      end
      return -1
    elseif key == "I_TCPY" then return 100
    elseif key == "I_TCPH" then return 60
    end
    return 0
  end

  function r.SetMediaTrackInfo_Value(tr, key, value)
    if key == "I_FOLDERDEPTH" then tr.folderdepth = value
    elseif key == "B_MAINSEND" then tr.mainsend = value
    elseif key == "D_VOL" then tr.vol = value
    elseif key == "D_PAN" then tr.pan = value
    end
    return true
  end

  -- sends --------------------------------------------------------------
  function r.GetTrackNumSends(tr) return #tr.sends end
  function r.GetTrackSendInfo_Value(tr, _, i, key)
    local send = tr.sends[i + 1]
    if not send then return 0 end
    -- REAPER distinguishes internal sends (0..N-1, keyed "P_DESTTRACK")
    -- from receives/hardware outputs (negative indices).
    if key == "P_DESTTRACK" then return send.dest end
    return send[key] or 0
  end
  function r.SetTrackSendInfo_Value(tr, _, i, key, value)
    local send = tr.sends[i + 1]
    if not send then error("SetTrackSendInfo_Value on a nil send (index " .. i .. ")") end
    send[key] = value
    return true
  end
  function r.CreateTrackSend(src, dst)
    if not dst then return -1 end
    src.sends[#src.sends + 1] = { dest = dst, D_VOL = 1.0, D_PAN = 0.0 }
    return #src.sends - 1
  end

  -- FX -----------------------------------------------------------------
  function r.TrackFX_GetCount(tr) return #tr.fx end
  -- Mirrors the real semantics from reaper_plugin_functions.h:
  --   negative instantiate -> always create a new instance
  --   0                     -> only query the first instance, -1 if absent
  --   positive              -> add only if one is not already there
  -- The mock used to insert on instantiate == 0, which made "does this FX
  -- already exist" checks look like they had added a duplicate.
  function r.TrackFX_AddByName(tr, name, _, instantiate)
    local existing
    for i, fx in ipairs(tr.fx) do
      if fx.name == name then existing = i - 1 break end
    end
    if instantiate == 0 then
      return existing or -1
    end
    if (instantiate or 0) > 0 and existing then
      return existing
    end
    tr.fx[#tr.fx + 1] = { name = name, enabled = true, params = {}, eq = {} }
    return #tr.fx - 1
  end
  function r.TrackFX_Delete(tr, i) table.remove(tr.fx, i + 1) end

  function r.TrackFX_GetEnabled(tr, i)
    local fx = tr.fx[i + 1]
    return fx and fx.enabled
  end
  function r.TrackFX_SetEnabled(tr, i, value)
    local fx = tr.fx[i + 1]
    if not fx then error("TrackFX_SetEnabled on missing slot " .. tostring(i)) end
    fx.enabled = value
    return true
  end
  function r.TrackFX_GetNumParams(tr, i)
    local fx = tr.fx[i + 1]
    return FX_PARAMS[fx and fx.name] and #FX_PARAMS[fx.name] or 0
  end
  function r.TrackFX_GetParamName(tr, i, p)
    local fx = tr.fx[i + 1]
    local names = FX_PARAMS[fx and fx.name]
    return true, (names and names[p + 1]) or ("Param " .. p)
  end
  function r.TrackFX_GetParam() return 0, 0 end
  function r.TrackFX_GetFormattedParamValue() return true, "" end

  -- Cockos-extension style value formatting. Ranges are declared per parameter
  -- so the tests can prove Utils.fx_normalize() inverts a non-linear mapping,
  -- which is the whole point: TrackFX_SetParam takes 0..1, not engineering units.
  function r.TrackFX_FormatParamValueNormalized(tr, i, p, value)
    local fx = tr.fx[i + 1]
    if not fx then return false, "" end
    local ranges = PARAM_RANGES[fx.name]
    local spec = ranges and ranges[(FX_PARAMS[fx.name] or {})[p + 1]]
    if not spec then return false, "" end
    local v
    if spec.curve == "exp" then
      v = spec.min * (spec.max / spec.min) ^ value
    else
      v = spec.min + (spec.max - spec.min) * value
    end
    local unit = spec.unit or ""
    local text = (math.abs(v) < 10 and string.format("%.2f", v) or string.format("%.1f", v))
    return true, text .. unit
  end
  function r.TrackFX_SetParam(tr, i, p, value)
    tr.fx[i + 1].params[p] = value
    return true
  end
  function r.TrackFX_SetParamNormalized(tr, i, p, value)
    local fx = tr.fx[i + 1]
    if not fx then error("TrackFX_SetParamNormalized on missing slot " .. tostring(i)) end
    if value < 0 or value > 1 then
      error("TrackFX_SetParamNormalized got " .. tostring(value) .. " (must be 0..1)")
    end
    fx.params[p] = value
    return true
  end
  function r.TrackFX_GetPresetIndex() return 0, 0 end
  function r.TrackFX_GetPreset() return true, "" end
  function r.TrackFX_SetEQParam(tr, i, bandtype, bandidx, paramtype, value)
    tr.fx[i + 1].eq[paramtype] = value
    tr.fx[i + 1].eq_band = { bandtype = bandtype, bandidx = bandidx }
    return true
  end
  function r.TrackFX_SetEQBandEnabled(tr, i, _, _, enabled)
    tr.fx[i + 1].eq_enabled = enabled
    return true
  end
  function r.TrackFX_Show() end

  -- project / audio ----------------------------------------------------
  function r.GetSetProjectInfo(_, _, value) return value end
  function r.CountTempoTimeSigMarkers() return r._tempo_markers end
  function r.SetTempoTimeSigMarker(...) r._tempo_args = { ... } return true end
  function r.Master_GetTempo() return 100.0 end
  function r.CountMediaItems() return 0 end
  function r.CountTrackMediaItems() return 0 end

  function r.GetAudioDeviceInfo(key)
    local values = {
      MODE = "WASAPI",
      IDENT_IN = "Microphone",
      IDENT_OUT = "Speakers",
      BSIZE = "512",
      SRATE = "48000",
      BPS = "24",
    }
    if r._audio_device_closed then return false, "" end
    if values[key] then return true, values[key] end
    return false, ""
  end
  function r.GetNumAudioInputs() return 2 end
  function r.GetNumAudioOutputs() return 2 end

  -- items / takes --------------------------------------------------------
  -- An item is { position, length, take = { midi, rate, channels, audio } }
  -- where `audio` is a 1-based table of interleaved samples covering the item.
  function r.TakeIsMIDI(take) return take and take.midi or false end
  function r.GetActiveTake(item) return item and item.take or nil end
  function r.GetMediaItemTake_Source(take) return take or {} end
  function r.GetMediaSourceSampleRate(source) return source.rate or 0 end
  function r.GetMediaSourceNumChannels(source) return source.channels or 0 end
  function r.GetTrackMediaItem(tr, idx) return (tr.items or {})[idx + 1] end
  function r.CountTrackMediaItems(tr) return #(tr.items or {}) end
  function r.GetMediaItemInfo_Value(item, key)
    if key == "D_POSITION" then return item.position or 0
    elseif key == "D_LENGTH" then return item.length or 0
    elseif key == "D_VOL" then return 1 end
    return 0
  end
  function r.SetMediaItemInfo_Value(item, key, value)
    if key == "D_POSITION" then item.position = value end
    return true
  end
  function r.SetMediaItemTakeInfo_Value(take, key, value)
    take[key] = value
    return true
  end
  function r.GetMediaItemTakeInfo_Value(take, key)
    if key == "D_PLAYRATE" then return take.playrate or 1.0
    elseif key == "D_STARTOFFS" then return take.startoffs or 0 end
    return 0
  end
  function r.CountSelectedMediaItems() return #r._selected_items end
  function r.GetSelectedMediaItem(_, i) return r._selected_items[i + 1] end

  -- audio accessor: maps a timeline position onto the item's sample table
  function r.CreateTakeAudioAccessor(take)
    if not take or not take.audio then return nil end
    return { take = take }
  end
  function r.DestroyAudioAccessor() end
  function r.GetAudioAccessorStartTime(aa) return aa.take.position or 0 end
  function r.GetAudioAccessorEndTime(aa)
    return (aa.take.position or 0) + (aa.take.length or 0)
  end
  function r.GetAudioAccessorSamples(aa, rate, channels, starttime, count, buffer)
    local take = aa.take
    local audio = take.audio
    if not audio then return -1 end
    if rate ~= (take.rate or 48000) then
      error("mock: GetAudioAccessorSamples rate " .. tostring(rate)
        .. " does not match the source rate " .. tostring(take.rate))
    end
    local rel = starttime - (take.position or 0)
    local first = math.floor(rel * rate + 0.5)
    for i = 0, count - 1 do
      local src = first + i
      for c = 1, channels do
        -- audio[] is 1-based and interleaved, like reaper.new_array
        buffer[i * channels + c] = audio[src * channels + c] or 0
      end
    end
    return 1
  end
  function r.new_array(n)
    -- REAPER's arrays expose bound methods: buffer.clear() is called with no
    -- arguments, so `clear` must capture the array rather than receive it.
    local t = { _n = n }
    for i = 1, n do t[i] = 0 end
    t.clear = function()
      for i = 1, n do t[i] = 0 end
    end
    return setmetatable(t, { __len = function() return n end })
  end
  function r.GetExtState(section, key)
    local s = r._extstate[section]
    if s and s[key] ~= nil then return true, s[key] end
    return false, ""
  end
  function r.SetExtState(section, key, value, persist)
    r._extstate[section] = r._extstate[section] or {}
    r._extstate[section][key] = value
  end
  function r.GetMediaItem_Track() return nil end
  function r.GetToggleCommandState() return 0 end
  function r.get_action_context()
    local path = r._script_path or "mock.lua"
    return path, path, r._action_section, r._action_command, 0, 0
  end
  function r.SetToggleCommandState(section, cmd, state)
    r._toggle_states[#r._toggle_states + 1] = { section, cmd, state }
  end
  function r.RefreshToolbar2(section, cmd)
    r._toolbar_refreshes[#r._toolbar_refreshes + 1] = { section, cmd }
  end

  return r
end

-- Build an item whose take contains `audio` (1-based, interleaved).
-- `offset_frames` shifts the audio inside the item, as if the performance
-- started later than the item does.
function mock.make_item(opts)
  local channels = opts.channels or 1
  local rate = opts.rate or 48000
  local frames = #opts.audio // channels
  return {
    position = opts.position or 0,
    length = frames / rate,
    take = {
      midi = opts.midi or false,
      rate = rate,
      channels = channels,
      audio = opts.audio,
      playrate = opts.playrate or 1.0,
      startoffs = opts.startoffs or 0,
    },
  }
end

-- Test host for scripts that expose their pure-Lua core. Set SGM_TEST_HOST
-- before running the script; it is filled in by the script itself.
function mock.with_test_host(r, path)
  _G.SGM_TEST_HOST = {}
  local err = mock.run_script(r, path)
  local host = _G.SGM_TEST_HOST
  _G.SGM_TEST_HOST = nil
  return host, err
end

-- helpers used by the tests ---------------------------------------------
function mock.add_track(r, name)
  r.InsertTrackAtIndex(#r._tracks)
  local track = r._tracks[#r._tracks]
  track.name = name or ""
  return track
end

function mock.select(r, tracks)
  r._selected = tracks or {}
end

function mock.console(r)
  return table.concat(r._messages, "")
end

-- Run a script file with `reaper` bound to the mock, returning an error
-- string (or nil on success).
function mock.run_script(r, path)
  -- get_action_context reports the script's own path inside REAPER; scripts use
  -- it to find libraries next to themselves, so the mock must report it too.
  r._script_path = path
  local chunk, load_err = loadfile(path)
  if not chunk then return "load: " .. tostring(load_err) end

  -- Inside REAPER, `reaper` is a genuine global. Putting it only in a sandbox
  -- _ENV and leaving it out of _G looks identical for a single file, but a
  -- script that loadfile()s a library gives that library the real _G - so the
  -- library sees no `reaper` at all. Mirror REAPER: set the global, then
  -- restore whatever was there before.
  local had_reaper = rawget(_G, "reaper")
  local previous = _G.reaper
  _G.reaper = r
  local env = setmetatable({ reaper = r }, { __index = _G })
  if setfenv then
    setfenv(chunk, env)
  else
    -- Lua 5.4: re-load with an explicit _ENV upvalue
    local source = assert(io.open(path, "r")):read("*a")
    chunk = assert(load(source, "@" .. path, "t", env))
  end

  local ok, err = pcall(chunk)
  _G.reaper = previous
  if not had_reaper then _G.reaper = nil end
  if ok then return nil end
  return tostring(err)
end

return mock
