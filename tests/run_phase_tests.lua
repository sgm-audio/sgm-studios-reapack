-- @license MIT (c) 2026 Scott Mills / SGM Studios — see LICENSE; kept with the script when redistributed
-- Signal-level tests for the phase alignment tool.
--
-- These are the tests that matter for this script: instead of asserting that
-- the code "runs", they build audio whose misalignment is known to the sample,
-- then check that the tool measures that exact number. A regression in the
-- correlation maths shows up here as a wrong number, not as a silent bad mix.
--
-- Run with: lua5.4 tests/run_phase_tests.lua   (from the repository root)

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

local function near(actual, expected, tolerance, what)
  if type(actual) ~= "number" then
    error(string.format("%s: expected a number, got %s", what or "value", tostring(actual)), 2)
  end
  if math.abs(actual - expected) > tolerance then
    error(string.format("%s: expected %s ± %s, got %s",
      what or "value", tostring(expected), tostring(tolerance), tostring(actual)), 2)
  end
end

local PHASE = "Rule-of-30/phase-alignment-tool.lua"

-- Load the script once against a fresh mock to get its pure-Lua core.
local function core()
  local r = mock.new()
  local host, err = mock.with_test_host(r, PHASE)
  if err then error("script error: " .. tostring(err), 2) end
  if not (host and host.phase) then error("the script did not expose its core", 2) end
  return host.phase, r
end

-- Deterministic pseudo-random signal: a few percussive hits of decaying noise.
local function signal(opts)
  opts = opts or {}
  local n = opts.n or 4096
  local seed = opts.seed or 12345
  local out = {}
  math.randomseed(seed)
  local hits = opts.hits or { 100, 1200, 2500 }
  for i = 0, n - 1 do out[i] = 0 end
  for _, hit in ipairs(hits) do
    local amp = opts.amp or 1.0
    for j = 0, 799 do
      local idx = hit + j
      if idx < n then
        local decay = math.exp(-j / 120)
        out[idx] = out[idx] + amp * decay * (math.random() * 2 - 1)
      end
    end
  end
  return out
end

-- Shift a 0-based sample table by `k` samples (positive = later).
local function shifted(samples, k, n)
  local out = {}
  for i = 0, n - 1 do out[i] = samples[i - k] or 0 end
  return out
end

-- Turn a 0-based signal table into the 1-based buffer a take needs.
-- mock.make_item() audio is 1-based like reaper.new_array; passing a 0-based
-- table straight in silently shifts the audio by one frame.
local function one_channel(src, k, n)
  local out = {}
  for i = 0, n - 1 do out[i + 1] = src[i - k] or 0 end
  return out
end

-- Build the interleaved (1-based) buffer a stereo take needs: channel 1 = `src`
-- delayed by k, channel 2 identical.
local function stereo_of(src, k, n)
  local out = {}
  for i = 0, n - 1 do
    out[i * 2 + 1] = src[i - k] or 0
    out[i * 2 + 2] = src[i - k] or 0
  end
  return out
end


print("phase alignment: correlation core")

test("identical signals correlate perfectly at zero lag", function()
  local p = core()
  local a = signal()
  local lag, r = p.Core.findLag(a, signal(), 200, 8)
  eq(lag, 0, "lag")
  near(r, 1.0, 0.001, "correlation")
end)

test("a signal delayed by N samples is reported as +N", function()
  local p = core()
  local n = 4096
  local a = signal({ n = n })
  for _, k in ipairs({ 1, 7, 64, 119 }) do
    local b = shifted(a, k, n)
    local lag, r = p.Core.findLag(a, b, 200, 8)
    eq(lag, k, "lag for a " .. k .. "-sample delay")
    if r < 0.9 then
      error("correlation too low for a pure delay: " .. tostring(r))
    end
  end
end)

test("an early signal is reported as a negative lag", function()
  local p = core()
  local n = 4096
  local a = signal({ n = n })
  local b = shifted(a, -33, n)
  local lag = p.Core.findLag(a, b, 200, 8)
  eq(lag, -33, "lag")
end)

test("lag detection survives the coarse pass stepping over the answer", function()
  -- coarse_factor 8 means only multiples of 8 are tested first; the fine pass
  -- must recover the exact lag from there.
  local p = core()
  local n = 4096
  local a = signal({ n = n })
  for _, k in ipairs({ 3, 5, 11, 13 }) do
    local lag = p.Core.findLag(a, shifted(a, k, n), 200, 8)
    eq(lag, k, "lag for " .. k)
  end
end)

test("an inverted take correlates strongly negative", function()
  local p = core()
  local n = 4096
  local a = signal({ n = n })
  local inverted = {}
  for i = 0, n - 1 do inverted[i] = -(a[i] or 0) end
  local lag, r = p.Core.findLag(a, inverted, 200, 8)
  eq(lag, 0, "lag")
  if r > -0.9 then
    error("expected a strongly negative correlation, got " .. tostring(r))
  end
end)

test("unrelated material does not produce a confident result", function()
  local p = core()
  local n = 4096
  local a = signal({ n = n, seed = 1 })
  local b = signal({ n = n, seed = 999 })
  local lag, r, confidence = p.Core.findLag(a, b, 200, 8)
  if math.abs(r) > 0.3 then
    error("independent noise correlated at r = " .. tostring(r))
  end
  if confidence > 0.3 then
    error("confidence too high for unrelated material: " .. tostring(confidence))
  end
end)

test("silence is reported, not aligned", function()
  local p = core()
  local n = 1024
  local silent = {}
  for i = 0, n - 1 do silent[i] = 0 end
  local lag, r = p.Core.findLag(signal({ n = n }), silent, 100, 8)
  eq(r, 0, "correlation against silence")
end)

test("a window that is too short is refused instead of guessed", function()
  local p = core()
  local tiny = { 1, 2, 3 }
  local lag, r, confidence, reason = p.Core.findLag(tiny, tiny, 10, 8)
  eq(lag, nil, "lag")
  if not reason then error("expected a reason") end
end)

test("onset detection finds the first hit", function()
  local p = core()
  local sig = signal({ n = 4096, hits = { 500 } })
  local onset = p.Core.findOnset(sig, 4096, -40, 48000)
  near(onset, 500, 2, "onset sample")
end)

print("phase alignment: end to end through the mock API")

test("three tracks are aligned to the reference by the measured offset", function()
  local p, r = core()
  local n = 28800  -- 600 ms @ 48 kHz: fits the 500 ms window plus the search range
  local base = signal({ n = n })

  -- reference at 0, one take 19 samples late, one 7 samples early
  local t1 = mock.add_track(r, "Rhythm L (reference)")
  local t2 = mock.add_track(r, "Rhythm R")
  local t3 = mock.add_track(r, "Rhythm L 2")
  t1.items = { mock.make_item({ audio = one_channel(base, 0, n), position = 0 }) }
  t2.items = { mock.make_item({ audio = one_channel(base, 19, n), position = 0 }) }
  t3.items = { mock.make_item({ audio = one_channel(base, -7, n), position = 0 }) }
  mock.select(r, { t1, t2, t3 })
  r._user_input = "1"

  local err = mock.run_script(r, PHASE)
  eq(err, nil, "script error")

  -- The late take must move earlier by 19 samples; the early one later by 7.
  near(t2.items[1].position, -19 / 48000, 1e-9, "Rhythm R position")
  near(t3.items[1].position, 7 / 48000, 1e-9, "Rhythm L 2 position")
  eq(t1.items[1].position, 0, "reference must not move")
  eq(r._undo_begin_count, 1, "exactly one undo block")
  eq(r._ui_refresh, 0, "UI refresh balanced")
end)

test("an unrelated track is reported and left where it is", function()
  local p, r = core()
  local n = 28800
  local a = signal({ n = n, seed = 4 })
  local b = signal({ n = n, seed = 77 })
  local t1 = mock.add_track(r, "Reference")
  local t2 = mock.add_track(r, "Different performance")
  t1.items = { mock.make_item({ audio = one_channel(a, 0, n), position = 0 }) }
  t2.items = { mock.make_item({ audio = one_channel(b, 0, n), position = 0 }) }
  mock.select(r, { t1, t2 })
  r._user_input = "1"

  eq(mock.run_script(r, PHASE), nil, "script error")
  eq(t2.items[1].position, 0, "position must be untouched")
  eq(r._undo_begin_count, 0, "no undo block for a no-op")
  local console = mock.console(r)
  if not console:find("not a reliable alignment", 1, true) then
    error("expected a low-correlation warning; console was:\n" .. console)
  end
end)

test("measure-only mode never moves anything", function()
  local p, r = core()
  local n = 28800
  local base = signal({ n = n })
  local t1 = mock.add_track(r, "A")
  local t2 = mock.add_track(r, "B")
  t1.items = { mock.make_item({ audio = one_channel(base, 0, n), position = 0 }) }
  t2.items = { mock.make_item({ audio = one_channel(base, 40, n), position = 0 }) }
  mock.select(r, { t1, t2 })
  r.SetExtState("SGM_PhaseAlign", "apply", "0", true)
  r._user_input = "1"

  eq(mock.run_script(r, PHASE), nil, "script error")
  eq(t2.items[1].position, 0, "position must be untouched in measure-only mode")
  if not mock.console(r):find("measure only", 1, true) then
    error("expected the measure-only notice")
  end
end)

test("a non-1.0 playrate is refused with a reason", function()
  local p, r = core()
  local n = 28800
  local base = signal({ n = n })
  local t1 = mock.add_track(r, "A")
  local t2 = mock.add_track(r, "B")
  t1.items = { mock.make_item({ audio = one_channel(base, 0, n), position = 0 }) }
  t2.items = { mock.make_item({ audio = one_channel(base, 0, n), position = 0, playrate = 1.5 }) }
  mock.select(r, { t1, t2 })
  r._user_input = "1"

  eq(mock.run_script(r, PHASE), nil, "script error")
  eq(t2.items[1].position, 0, "must not move")
  if not mock.console(r):find("playrate", 1, true) then
    error("expected a playrate refusal in the console")
  end
end)

test("a stereo take is analysed on one channel, not on interleaved data", function()
  local p, r = core()
  local n = 28800
  -- mono performance, duplicated into both channels of a stereo take
  local mono = signal({ n = n })

  local t1 = mock.add_track(r, "Mono ref")
  local t2 = mock.add_track(r, "Stereo")
  t1.items = { mock.make_item({ audio = one_channel(mono, 0, n), position = 0 }) }
  t2.items = { mock.make_item({ audio = stereo_of(mono, 23, n), position = 0, channels = 2 }) }
  mock.select(r, { t1, t2 })
  r._user_input = "1"

  eq(mock.run_script(r, PHASE), nil, "script error")
  near(t2.items[1].position, -23 / 48000, 1e-9, "stereo take position")
end)

test("a silent reference is refused instead of aligning to noise", function()
  local p, r = core()
  local n = 28800
  local silence = {}
  for i = 0, n - 1 do silence[i + 1] = 0 end
  local t1 = mock.add_track(r, "Silent")
  local t2 = mock.add_track(r, "Audio")
  t1.items = { mock.make_item({ audio = silence, position = 0 }) }
  t2.items = { mock.make_item({ audio = one_channel(signal({ n = n }), 0, n), position = 0 }) }
  mock.select(r, { t1, t2 })
  r._user_input = "1"

  eq(mock.run_script(r, PHASE), nil, "script error")
  if not mock.console(r):find("is silent", 1, true) then
    error("expected a silent-reference refusal; console was:\n" .. mock.console(r))
  end
  eq(r._undo_begin_count, 0, "no undo block")
end)

test("the correlation check measures audio, not item positions", function()
  local p, r = core()
  local n = 28800
  local base = signal({ n = n })
  local t1 = mock.add_track(r, "A")
  local t2 = mock.add_track(r, "B")
  -- Items sit at the same position; the audio inside is 30 samples apart.
  t1.items = { mock.make_item({ audio = one_channel(base, 0, n), position = 0 }) }
  t2.items = { mock.make_item({ audio = one_channel(base, 30, n), position = 0 }) }
  mock.select(r, { t1, t2 })
  r._user_input = "2"

  eq(mock.run_script(r, PHASE), nil, "script error")
  local console = mock.console(r)
  if not console:find("Misaligned", 1, true) then
    error("expected the tool to detect the 30-sample offset; console was:\n" .. console)
  end
  if console:find("Sample-aligned", 1, true) then
    error("tool claimed alignment because the item positions matched")
  end
end)

test("settings round-trip through ExtState", function()
  local p, r = core()
  r.SetExtState("SGM_PhaseAlign", "min_correlation", "0.75", true)
  r.SetExtState("SGM_PhaseAlign", "window_ms", "250", true)
  local p2 = core()
  -- the second load reads what the first wrote
  local r2 = mock.new()
  r2._extstate = r._extstate
  local host = mock.with_test_host(r2, PHASE)
  near(host.phase.CONFIG.min_correlation, 0.75, 1e-9, "min_correlation")
  near(host.phase.CONFIG.window_ms, 250, 1e-9, "window_ms")
end)

test("a corrupt stored setting falls back to the default, not to nonsense", function()
  local r = mock.new()
  r.SetExtState("SGM_PhaseAlign", "window_ms", "NaN surprise", true)
  r.SetExtState("SGM_PhaseAlign", "min_correlation", "-5", true)
  local host = mock.with_test_host(r, PHASE)
  eq(host.phase.CONFIG.window_ms, 500, "window_ms falls back to the default")
  near(host.phase.CONFIG.min_correlation, 0, 1e-9, "min_correlation clamped to 0")
end)

print(string.format("\n%d passed, %d failed", passed, failed))
if failed > 0 then os.exit(1) end
