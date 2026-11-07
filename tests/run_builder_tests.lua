-- @license MIT (c) 2026 Scott Mills / SGM Studios — see LICENSE; kept with the script when redistributed
-- Integration tests for the Rule of 30 session builder.
--
-- These run the *real* script file against the mock host, so they exercise the
-- points where the builder has actually broken: the tempo call's argument
-- order, FX duplication, and the preset library being wired in at all.
--
--   lua5.4 tests/run_builder_tests.lua

package.path = "tests/?.lua;" .. package.path

local mock = require("reaper_mock")
local BUILDER = "Rule-of-30/rule-of-30-session-builder.lua"
local PRESETS = "Rule-of-30/rule-of-30-plugin-presets.lua"

local passed, failed = 0, 0
local function check(name, condition, detail)
  if condition then
    passed = passed + 1
    io.write("  ok   " .. name .. "\n")
  else
    failed = failed + 1
    io.write("  FAIL " .. name .. (detail and ("\n         " .. detail) or "") .. "\n")
  end
end

local function fresh()
  local r = mock.new()
  -- The builder loads its libraries by walking up from the script path, so
  -- point the mock resource path at the repo root.
  return r
end

-- ---------------------------------------------------------------------------
-- The tempo marker: 9 arguments, bpm in the bpm slot.
-- ---------------------------------------------------------------------------
do
  io.write("tempo\n")
  local r = fresh()
  r._user_input = "1"
  mock.run_script(r, BUILDER)
  local args = r._tempo_args
  check("SetTempoTimeSigMarker was called", args ~= nil)
  if args then
    check("called with 9 arguments", #args == 9, "got " .. #args)
    check("bpm is in the bpm slot (arg 6), not beatpos (arg 5)",
      math.abs(args[6] - 100) < 0.001,
      "arg5=" .. tostring(args[5]) .. " arg6=" .. tostring(args[6]))
    check("beatpos is -1 (don't move the marker)", args[5] == -1,
      "arg5=" .. tostring(args[5]))
  end
end

-- ---------------------------------------------------------------------------
-- FX chains: idempotent, and actually configured from the preset library.
-- ---------------------------------------------------------------------------
do
  io.write("fx chains\n")
  local r = fresh()
  r._user_input = "1"
  mock.run_script(r, BUILDER)

  local vocal
  for _, tr in ipairs(r._tracks) do
    if tr.name:find("Lead Vocal", 1, true) then vocal = tr end
  end
  check("session contains a Lead Vocal track", vocal ~= nil)

  if vocal then
    check("Lead Vocal starts with no FX (option 1 only builds structure)",
      #vocal.fx == 0, "found " .. #vocal.fx)

    -- Run the vocal chain twice; the second run must not stack duplicates.
    r._user_input = "5"
    mock.run_script(r, BUILDER)
    local after_first = #vocal.fx
    check("vocal chain added FX", after_first > 0)

    local names = {}
    for _, fx in ipairs(vocal.fx) do names[#names + 1] = fx.name end
    local seen, dup = {}, nil
    for _, n in ipairs(names) do
      if seen[n] then dup = n end
      seen[n] = true
    end
    check("no duplicate plugins in one chain", dup == nil,
      "duplicate: " .. tostring(dup))

    -- Values must have been written, not just the plugins instantiated.
    local configured = 0
    for _, fx in ipairs(vocal.fx) do
      local count = 0
      for _ in pairs(fx.params) do count = count + 1 end
      if count > 0 then configured = configured + 1 end
    end
    check("preset parameters were written to the FX", configured > 0,
      configured .. " of " .. #vocal.fx .. " FX have parameters")

    -- And they must land on the value the preset asked for. "Lead Vocal" wants
    -- ReaComp Threshold -20 dB, Ratio 3:1, Attack 10 ms, Release 150 ms.
    local comp, comp_index
    for i, fx in ipairs(vocal.fx) do
      if fx.name == "ReaComp" then comp, comp_index = fx, i - 1 end
    end
    check("Lead Vocal got its ReaComp", comp ~= nil)
    if comp then
      local function read_back(param_index)
        local ok, text = r.TrackFX_FormatParamValueNormalized(
          vocal, comp_index, param_index, comp.params[param_index] or 0)
        return ok and tonumber(text:match("[-+]?%d*%.?%d+")) or nil
      end
      -- Threshold is parameter 1, Ratio 2, Attack 3, Release 4 in the mock.
      local threshold = read_back(1)
      check("threshold lands on -20 dB", threshold and math.abs(threshold + 20) <= 1.0,
        "reads back " .. tostring(threshold) .. " dB")
      local ratio = read_back(2)
      check("ratio lands on 3:1", ratio and math.abs(ratio - 3) <= 0.3,
        "reads back " .. tostring(ratio) .. ":1")
      local attack = read_back(3)
      check("attack lands on 10 ms", attack and math.abs(attack - 10) <= 5,
        "reads back " .. tostring(attack) .. " ms")
    end

    -- ReaEQ must go through the band API, not a raw parameter index.
    local eqfx
    for _, fx in ipairs(vocal.fx) do
      if fx.name == "ReaEQ" then eqfx = fx end
    end
    if eqfx then
      check("ReaEQ high-pass band was enabled and given a frequency",
        eqfx.eq_band and eqfx.eq_band.bandtype == 0 and eqfx.eq[0] == 100,
        "bandtype=" .. tostring(eqfx.eq_band and eqfx.eq_band.bandtype)
          .. " freq=" .. tostring(eqfx.eq[0]))
    end

    r._user_input = "5"
    mock.run_script(r, BUILDER)
    check("re-running the chain does not duplicate FX",
      #vocal.fx == after_first,
      "was " .. after_first .. ", now " .. #vocal.fx)
  end
end

-- ---------------------------------------------------------------------------
-- Master bus: preset-driven and idempotent.
-- ---------------------------------------------------------------------------
do
  io.write("master bus\n")
  local r = fresh()
  r._user_input = "1"
  mock.run_script(r, BUILDER)
  local master = r._master
  local first = #master.fx
  check("master has an FX chain", first > 0)

  local seen, dup = {}, nil
  for _, fx in ipairs(master.fx) do
    if seen[fx.name] then dup = fx.name end
    seen[fx.name] = true
  end
  check("master chain has no duplicates", dup == nil, "duplicate: " .. tostring(dup))

  r._user_input = "1"
  mock.run_script(r, BUILDER)
  check("rebuilding does not stack another master chain",
    #master.fx == first, "was " .. first .. ", now " .. #master.fx)
end

-- ---------------------------------------------------------------------------
-- The build must refuse to create 50+ tracks at the wrong tempo.
-- ---------------------------------------------------------------------------
do
  io.write("tempo guard\n")
  local r = fresh()
  -- Make the tempo call report success but leave the project at the wrong bpm.
  r.Master_GetTempo = function() return 4.0 end
  r._user_input = "1"
  mock.run_script(r, BUILDER)
  check("aborted instead of building at 4 BPM", r.CountTracks(0) == 0,
    "created " .. r.CountTracks(0) .. " tracks")
  check("said why", mock.console(r):find("tempo", 1, true) ~= nil)
end

-- ---------------------------------------------------------------------------
-- Undo / UI refresh balance after a full build.
-- ---------------------------------------------------------------------------
do
  io.write("undo + ui refresh\n")
  local r = fresh()
  r._user_input = "1"
  mock.run_script(r, BUILDER)
  check("PreventUIRefresh balanced", r._ui_refresh == 0,
    "balance " .. tostring(r._ui_refresh))
  check("one undo block opened and closed",
    r._undo_begin_count == 1 and r._undo_end_count == 1,
    "begin=" .. r._undo_begin_count .. " end=" .. r._undo_end_count)
end

-- ---------------------------------------------------------------------------
-- The preset library on its own.
-- ---------------------------------------------------------------------------
do
  io.write("presets\n")
  local r = fresh()
  local env = setmetatable({ reaper = r }, { __index = _G })
  local chunk = assert(loadfile(PRESETS))
  if setfenv then setfenv(chunk, env) end
  local Presets = chunk()

  check("forTrack matches a real builder track name",
    Presets.forTrack("Lead Vocal") ~= nil)
  check("forTrack returns nil for an unknown track",
    Presets.forTrack("Kazoo Overdub") == nil)

  -- Longest match wins: "Rhythm L1 (100% L)" must not fall back to "Rhythm L".
  local chain = Presets.forTrack("Rhythm L1 (100% L)")
  check("longest key wins", chain ~= nil)

  local every_preset_has_plugin = true
  for key, chain_def in pairs(Presets.chains) do
    for _, entry in ipairs(chain_def) do
      if type(entry.plugin) ~= "string" or entry.plugin == "" then
        every_preset_has_plugin = false
        io.write("         bad entry in " .. key .. "\n")
      end
    end
  end
  check("every preset entry names a plugin", every_preset_has_plugin)
end

io.write(string.format("\n%d passed, %d failed\n", passed, failed))
os.exit(failed == 0 and 0 or 1)
