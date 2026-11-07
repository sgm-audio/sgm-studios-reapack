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
    _toolbar_refreshes = {},
  }

  -- console / app -------------------------------------------------------
  function r.ShowConsoleMsg(s) r._messages[#r._messages + 1] = tostring(s) end
  function r.ClearConsole() r._messages = {} end
  function r.GetOS() return "Win64" end
  function r.GetResourcePath() return "/resource" end
  function r.GetExePath() return "/resource/reaper.exe" end
  function r.GetAppVersion() return "7.83/x64" end
  function r.time_precise() return 1.0 end
  function r.GetPlayPosition() return 0.0 end
  function r.UpdateArrange() end
  function r.RecursiveCreateDirectory() return 1 end
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
  function r.TrackFX_AddByName(tr, name, _, instantiate)
    if instantiate == 0 then
      for i, fx in ipairs(tr.fx) do
        if fx.name == name then return i - 1 end
      end
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
  function r.TrackFX_SetParam(tr, i, p, value)
    tr.fx[i + 1].params[p] = value
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

  -- items / audio access ------------------------------------------------
  function r.TakeIsMIDI() return false end
  function r.GetActiveTake() return nil end
  function r.GetMediaItemTake_Source() return {} end
  function r.GetMediaSourceSampleRate() return 48000 end
  function r.GetMediaSourceNumChannels() return 2 end
  function r.CreateTakeAudioAccessor() return {} end
  function r.DestroyAudioAccessor() end
  function r.GetAudioAccessorSamples() return 0 end
  function r.new_array() return { clear = function() end } end
  function r.GetMediaItemInfo_Value() return 0 end
  function r.SetMediaItemInfo_Value() return true end
  function r.CountSelectedMediaItems() return 0 end
  function r.GetSelectedMediaItem() return nil end
  function r.GetMediaItem_Track() return nil end
  function r.GetToggleCommandState() return 0 end
  function r.get_action_context()
    return "mock.lua", "…/mock.lua", r._action_section, r._action_command, 0, 0
  end
  function r.SetToggleCommandState(section, cmd, state)
    r._toggle_states[#r._toggle_states + 1] = { section, cmd, state }
  end
  function r.RefreshToolbar2(section, cmd)
    r._toolbar_refreshes[#r._toolbar_refreshes + 1] = { section, cmd }
  end

  return r
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
  local chunk, load_err = loadfile(path)
  if not chunk then return "load: " .. tostring(load_err) end

  local env = setmetatable({ reaper = r }, { __index = _G })
  if setfenv then
    setfenv(chunk, env)
  else
    -- Lua 5.4: re-load with an explicit _ENV upvalue
    local source = assert(io.open(path, "r")):read("*a")
    chunk = assert(load(source, "@" .. path, "t", env))
  end

  local ok, err = pcall(chunk)
  if ok then return nil end
  return tostring(err)
end

return mock
