-- @license MIT (c) 2026 Scott Mills / SGM Studios — see LICENSE; kept with the script when redistributed
-- Regression tests for the SGM Studios scripts.
--
-- Runs entirely without REAPER: each test loads a script with `reaper` bound to
-- tests/reaper_mock.lua, then asserts on the resulting project state.
--
-- Run with:  lua5.4 tests/run_tests.lua      (from the repository root)
-- Exit code is 0 when everything passes, 1 otherwise.

package.path = "tests/?.lua;" .. package.path
local mock = require("reaper_mock")

local passed, failed = 0, 0

local function test(name, fn)
  local ok, err = pcall(fn)
  if ok then
    passed = passed + 1
    print("  ok   " .. name)
  else
    failed = failed + 1
    print("  FAIL " .. name .. "\n         " .. tostring(err))
  end
end

local function eq(actual, expected, what)
  if actual ~= expected then
    error(string.format("%s: expected %s, got %s",
      what or "value", tostring(expected), tostring(actual)), 2)
  end
end

local function contains(haystack, needle, what)
  if not tostring(haystack):find(needle, 1, true) then
    error(string.format("%s: %q not found in console output", what or "console", needle), 2)
  end
end

local ESS = "SGM-Essentials/"
local R30 = "Rule-of-30/"

-- ----------------------------------------------------------------------
print("SGM_auto_master")
-- ----------------------------------------------------------------------
test("inserts ReaEQ, ReaComp and ReaLimit on the master track", function()
  local r = mock.new()
  eq(mock.run_script(r, ESS .. "SGM_auto_master.lua"), nil, "script error")
  eq(#r._master.fx, 3, "master FX count")
  eq(r._master.fx[1].name, "ReaEQ", "fx 1")
  eq(r._master.fx[2].name, "ReaComp", "fx 2")
  eq(r._master.fx[3].name, "ReaLimit", "fx 3")
end)

test("configures the ReaEQ high-pass through the EQ API", function()
  local r = mock.new()
  mock.run_script(r, ESS .. "SGM_auto_master.lua")
  local eq_band = r._master.fx[1].eq_band
  eq(eq_band.bandtype, 0, "bandtype (0 = high-pass)")
  eq(r._master.fx[1].eq[0], 30, "high-pass frequency in Hz")
  eq(r._master.fx[1].eq_enabled, true, "band enabled")
end)

test("writes parameter values that read back as the documented ones", function()
  local r = mock.new()
  mock.run_script(r, ESS .. "SGM_auto_master.lua")
  local master = r._master

  -- These used to assert the raw stored number, which is how the bug survived:
  -- TrackFX_SetParam takes 0..1, so -18 was silently some other threshold.
  -- Read the value back through the plug-in's own formatter instead.
  local function reads_back(fx_index, param_index)
    local stored = master.fx[fx_index + 1].params[param_index]
    if stored == nil then return nil, "nothing written" end
    if stored < 0 or stored > 1 then
      return nil, "stored " .. tostring(stored) .. " is not a normalized value"
    end
    local ok, text = r.TrackFX_FormatParamValueNormalized(
      master, fx_index, param_index, stored)
    if not ok then return nil, "the plug-in could not format the value" end
    return tonumber(text:match("[-+]?%d*%.?%d+")), text
  end

  local threshold = reads_back(1, 1)
  eq(math.abs(threshold + 18) <= 1.0, true,
    "compressor threshold should read back -18 dB, got " .. tostring(threshold))

  local ceiling = reads_back(2, 1)
  eq(math.abs(ceiling + 1.0) <= 0.2, true,
    "limiter ceiling should read back -1.0 dB, got " .. tostring(ceiling))
end)

test("cancelling the dialog leaves the project untouched", function()
  local r = mock.new()
  r._master.fx[1] = { name = "ExistingFX", enabled = true, params = {}, eq = {} }
  r._mb_answer = 7 -- No
  eq(mock.run_script(r, ESS .. "SGM_auto_master.lua"), nil, "script error")
  eq(#r._master.fx, 1, "master FX count")
  eq(r._master.fx[1].name, "ExistingFX", "existing FX kept")
  eq(r._undo_begin_count, 0, "no undo block opened")
end)

-- ----------------------------------------------------------------------
print("SGM_FieldyBagToggle")
-- ----------------------------------------------------------------------
local function bass_track(r, fx_count)
  local track = mock.add_track(r, "Bass")
  for i = 1, fx_count do
    r.TrackFX_AddByName(track, "FX" .. i, false, -1)
  end
  mock.select(r, { track })
  return track
end

test("toggles slots 1-3 off and 4-6 on", function()
  local r = mock.new()
  local track = bass_track(r, 6)
  eq(mock.run_script(r, ESS .. "SGM_FieldyBagToggle.lua"), nil, "script error")
  eq(track.fx[1].enabled, false, "slot 1")
  eq(track.fx[3].enabled, false, "slot 3")
  eq(track.fx[4].enabled, true, "slot 4")
  eq(track.fx[6].enabled, true, "slot 6")
end)

test("does not touch slots that do not exist", function()
  local r = mock.new()
  -- 4 slots only: the old code wrote to 5 and 6 and errored
  local track = bass_track(r, 4)
  eq(mock.run_script(r, ESS .. "SGM_FieldyBagToggle.lua"), nil, "script error")
  eq(#track.fx, 4, "fx count unchanged")
end)

test("reports 'No FX found' and creates no undo point", function()
  local r = mock.new()
  bass_track(r, 0)
  eq(mock.run_script(r, ESS .. "SGM_FieldyBagToggle.lua"), nil, "script error")
  contains(mock.console(r), "No FX found on selected track.", "console")
  eq(r._undo_begin_count, 0, "no undo block")
end)

test("no track selected shows a message box and does not crash", function()
  local r = mock.new()
  eq(mock.run_script(r, ESS .. "SGM_FieldyBagToggle.lua"), nil, "script error")
  eq(#r._mb_prompts, 1, "message box shown")
end)

-- ----------------------------------------------------------------------
print("SGM_route_mix_bus")
-- ----------------------------------------------------------------------
test("routes only the selected tracks", function()
  local r = mock.new()
  local a, b, c = mock.add_track(r, "A"), mock.add_track(r, "B"), mock.add_track(r, "C")
  mock.select(r, { a, b })
  eq(mock.run_script(r, ESS .. "SGM_route_mix_bus.lua"), nil, "script error")
  eq(#a.sends, 1, "A routed")
  eq(#b.sends, 1, "B routed")
  eq(#c.sends, 0, "C (unselected) not routed")
  eq(c.mainsend, 1, "C keeps its master send")
end)

test("colours the mix bus with the configured RGB", function()
  local r = mock.new()
  local a = mock.add_track(r, "A")
  mock.select(r, { a })
  eq(mock.run_script(r, ESS .. "SGM_route_mix_bus.lua"), nil, "script error")
  local bus
  for _, tr in ipairs(r._tracks) do
    if tr.name == "Mix Bus" then bus = tr end
  end
  eq(bus ~= nil, true, "mix bus created")
  -- MIX_BUS_COLOR = { 255, 180, 50 } -> 0x1000000 | 0xFFB432
  local expected = 0x1000000 | (255 * 65536 + 180 * 256 + 50)
  eq(bus and bus.color, expected, "mix bus colour")
end)

test("does not duplicate an existing send", function()
  local r = mock.new()
  local a = mock.add_track(r, "A")
  mock.select(r, { a })
  mock.run_script(r, ESS .. "SGM_route_mix_bus.lua")
  eq(mock.run_script(r, ESS .. "SGM_route_mix_bus.lua"), nil, "second run")
  eq(#a.sends, 1, "still one send")
end)

test("selected folder parent is a valid routing target", function()
  local r = mock.new()
  local folder = mock.add_track(r, "Folder")
  folder.folderdepth = 2 -- opens two nested folder levels
  mock.select(r, { folder })
  eq(mock.run_script(r, ESS .. "SGM_route_mix_bus.lua"), nil, "script error")
  eq(#folder.sends, 1, "selected folder parent routed")
  eq(folder.mainsend, 0, "folder parent routed through Mix Bus")
  eq(r._ui_refresh, 0, "UI refresh balanced")
end)

test("no-selection fallback routes top-level folder groups, not their children", function()
  local r = mock.new()
  local outer = mock.add_track(r, "Outer Folder")
  outer.depth, outer.folderdepth = 0, 1
  local child = mock.add_track(r, "Child")
  child.depth, child.folderdepth = 1, 1
  local nested = mock.add_track(r, "Nested Folder")
  nested.depth, nested.folderdepth = 2, 1
  local nested_child = mock.add_track(r, "Nested Child")
  nested_child.depth, nested_child.folderdepth = 3, -3
  local standalone = mock.add_track(r, "Standalone")
  standalone.depth = 0

  eq(mock.run_script(r, ESS .. "SGM_route_mix_bus.lua"), nil, "script error")
  eq(#outer.sends, 1, "outer folder routed")
  eq(#child.sends, 0, "child not sent around its folder")
  eq(#nested.sends, 0, "nested folder remains under its top-level parent")
  eq(#nested_child.sends, 0, "nested child not sent around its folder")
  eq(#standalone.sends, 1, "standalone top-level track routed")
  eq(child.mainsend, 1, "child retains its parent send")
end)

test("empty project reports 'No tracks to route'", function()
  local r = mock.new()
  eq(mock.run_script(r, ESS .. "SGM_route_mix_bus.lua"), nil, "script error")
  contains(mock.console(r), "No tracks to route.", "console")
end)

-- ----------------------------------------------------------------------
print("daw-discovery-analyzer")
-- ----------------------------------------------------------------------
test("comprehensive report runs without calling a missing API", function()
  local r = mock.new()
  mock.add_track(r, "Kick")
  r._user_input = "1"
  eq(mock.run_script(r, ESS .. "daw-discovery-analyzer.lua"), nil, "script error")
  contains(mock.console(r), "COMPREHENSIVE DAW ANALYSIS", "report header")
  contains(mock.console(r), "48000 Hz", "sample rate from GetAudioDeviceInfo")
end)

test("closed audio device prints n/a instead of 'nil Hz'", function()
  local r = mock.new()
  r._audio_device_closed = true
  r._user_input = "1"
  eq(mock.run_script(r, ESS .. "daw-discovery-analyzer.lua"), nil, "script error")
  contains(mock.console(r), "n/a (device closed)", "sample rate fallback")
  assert(not mock.console(r):find("nil Hz", 1, true), "printed 'nil Hz'")
end)

test("the config monitor publishes its running state to the Action List", function()
  local r = mock.new()
  r._user_input = "4"     -- Start Config Monitor
  r._action_section, r._action_command = 0, 424242
  eq(mock.run_script(r, ESS .. "daw-discovery-analyzer.lua"), nil, "script error")
  eq(#r._toggle_states, 1, "one SetToggleCommandState call")
  eq(r._toggle_states[1][3], 1, "state reports running")
  eq(#r._toolbar_refreshes, 1, "toolbar refreshed")
end)

test("opens the Performance Meter by resolving the action, not by guessing its id", function()
  local r = mock.new()
  r._user_input = "1"
  eq(mock.run_script(r, ESS .. "daw-discovery-analyzer.lua"), nil, "script error")

  -- The action that described "View: Performance Meter" was resolved and run.
  local ran = r._commands_run[1]
  local description
  for _, a in ipairs(r._actions) do
    if a.cmd == ran then description = a.text end
  end
  eq(description, "View: Performance Meter", "action opened: " .. tostring(description))

  -- And specifically not 40364, which is the metronome. The old test asserted
  -- 40364 "because it is the Performance Meter" - which is how the bug survived.
  local toggled_click = false
  for _, cmd in ipairs(r._commands_run) do
    if cmd == 40364 then toggled_click = true end
  end
  eq(toggled_click, false, "must not run 40364 (Options: Toggle metronome)")
end)

test("says what to do when the action cannot be found", function()
  local r = mock.new()
  r._user_input = "1"
  r._actions = { { cmd = 40364, name = "", text = "Options: Toggle metronome" } }
  eq(mock.run_script(r, ESS .. "daw-discovery-analyzer.lua"), nil, "script error")
  eq(#r._commands_run, 0, "nothing was run")
  contains(mock.console(r), "View > Performance Meter",
    "told the user how to open it by hand")
end)

-- ----------------------------------------------------------------------
print("rule-of-30-session-builder")
-- ----------------------------------------------------------------------
test("builds the full skeleton with Compact Mode off (no addFX crash)", function()
  local r = mock.new()
  -- option 0 toggles compact mode off, then option 1 builds
  r._user_input = "1"
  local source = assert(io.open(R30 .. "rule-of-30-session-builder.lua")):read("*a")
  source = source:gsub("compact_mode = true,", "compact_mode = false,", 1)
  local path = os.tmpname() .. ".lua"
  assert(io.open(path, "w")):write(source):close()
  local err = mock.run_script(r, path)
  os.remove(path)
  eq(err, nil, "script error")
  eq(r._tracks[1].folderdepth, 1, "first track is a folder")
  eq(r._ui_refresh, 0, "UI refresh balanced")
  eq(r._undo_depth, 0, "undo blocks balanced")
end)

test("updates an existing tempo marker instead of inserting one", function()
  local r = mock.new()
  r._tempo_markers = 1
  r._user_input = "1"
  mock.run_script(r, R30 .. "rule-of-30-session-builder.lua")
  eq(r._tempo_args[2], 0, "marker index 0 (update existing)")
end)

test("sidechain targets channels 3/4 and is not duplicated", function()
  local r = mock.new()
  local kick = mock.add_track(r, "  ├─ Kick Out (Body)")
  local bass = mock.add_track(r, "  ├─ Bass DI (Lows <200Hz)")
  r._user_input = "6"
  eq(mock.run_script(r, R30 .. "rule-of-30-session-builder.lua"), nil, "run 1")
  eq(mock.run_script(r, R30 .. "rule-of-30-session-builder.lua"), nil, "run 2")
  eq(#kick.sends, 1, "one send after running twice")
  eq(kick.sends[1].I_DSTCHAN, 2, "destination channel index 2 (3/4, no mono bit)")
  eq(kick.sends[1].dest, bass, "destination track")
end)

-- ----------------------------------------------------------------------
print("phase-alignment-tool")
-- ----------------------------------------------------------------------
test("early exit with too few tracks leaves the UI refresh balanced", function()
  local r = mock.new()
  mock.select(r, {})
  r._user_input = "1"
  eq(mock.run_script(r, R30 .. "phase-alignment-tool.lua"), nil, "script error")
  contains(mock.console(r), "Please select at least 2 tracks", "console")
  eq(r._ui_refresh, 0, "UI refresh balanced")
  eq(r._undo_begin_count, 0, "no undo block opened")
end)

test("nudge with no items selected is a no-op", function()
  local r = mock.new()
  r._user_input = "3"
  eq(mock.run_script(r, R30 .. "phase-alignment-tool.lua"), nil, "script error")
  contains(mock.console(r), "No items selected", "console")
end)

-- ----------------------------------------------------------------------
print(string.format("\n%d passed, %d failed", passed, failed))
if failed > 0 then os.exit(1) end
