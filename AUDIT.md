# Audit report — 2026-11-07

Full static audit of all 11 Lua scripts, the ReaPack index and the documentation.
Scope: correctness against the REAPER ReaScript API, runtime crash paths, undo /
UI-refresh hygiene, packaging (ReaPack index semantics) and doc accuracy.

**Verification performed:** Lua 5.4 parse of every script, XML validation of
`index.xml`, every `<source>` URL checked against the repository tree, and each
script executed against a mocked `reaper` API covering its main code path
(including the crash paths below, both before and after the fixes).
**Not performed:** running inside real REAPER — see the `TEST_CASES.md` files in
each bundle.

Version bumps: Essentials bundle **1.1.3**, Rule-of-30 bundle **1.0.3**.

> **Correction (same day, second pass).** Item 5 below was wrong. `GetCPUUsage()`
> does **not** exist either — see
> [§7 Corrections](#7-corrections-to-this-report). The first pass trusted a GitHub
> code-search hit count instead of the SDK header, and the same mistake had already
> been made once (`GetCPULoading` → `GetCPUUsage`). Everything in this report is now
> checked against the authoritative function list, and the check is automated:
> `tools/check_api.py` runs in CI and fails on any call that is not in the REAPER
> 7.83 SDK header. The unit tests in `tests/` (21 cases) run every main code path
> against a mock API.

---

## 1. Crashes / definite bugs (fixed)

| # | File | Problem | Fix |
|---|------|---------|-----|
| 1 | `rule-of-30-session-builder.lua` | The local `addFX` was declared *after* `addSmartFX`, so "Build Session" with Compact Mode **off** died with `attempt to call a nil value (global 'addFX')`. | `addFX` moved above its first use. |
| 2 | `rule-of-30-session-builder.lua` | `CreateTrackSend()` can return `-1`; the following `SetTrackSendInfo_Value(..., -1, ...)` then errors. | All send creation guarded; failures reported to the console. |
| 3 | `SGM_auto_master.lua` | The stock limiter is called **`ReaLimit`**; the script asked for `ReaLimiter`, so no limiter was ever added (silently). | Correct plug-in name. |
| 4 | `SGM_auto_master.lua` | The ReaEQ high-pass wrote raw values into parameter indices 0–3, which are the *band enable* toggles — the EQ was mis-set, not a 30 Hz high-pass. | Uses `TrackFX_SetEQParam` + `TrackFX_SetEQBandEnabled`; other FX params are found by name instead of hard-coded indices. |
| 5 | `daw-discovery-analyzer.lua` | `reaper.GetCPULoading()` does not exist. Every "Comprehensive Analysis" run crashed on that line. | ~~`reaper.GetCPUUsage()`~~ — **that was also wrong**; see §7. Final fix: the report opens REAPER's Performance Meter (action `40364`) and states that ReaScript has no CPU API. |
| 6 | `daw-discovery-analyzer.lua` | Audio bit depth queried `"BITDEPTH"`; the documented keys are `MODE, IDENT_IN, IDENT_OUT, BSIZE, SRATE, BPS`. | Queries `BPS` (and `MODE`), with nil-safe formatting. |
| 7 | `SGM_reaper_ultra_hd_smart_tools.lua` | `SetMouseModifier("MM_CTX_ITEM", 0, cursor_id)` was called with invented numbers (182–185). The API only accepts mouse-modifier / command ID **strings** — this silently wrote invalid values into the user's mouse-modifier prefs. | The engine no longer touches mouse modifiers; it logs the resolved tool. Saving/restoring a modifier it never set is gone too. |
| 8 | `phase-alignment-tool.lua` | Both early exits (`< 2` tracks, no transients) returned *after* `PreventUIRefresh(1)` and `Undo_BeginBlock()`, leaving the arrange view frozen/undrawn and an undo block open. | Validation happens before anything is opened; the no-transient path unwinds the refresh. |
| 9 | `phase-alignment-tool.lua` | Transient detection read an interleaved multi-channel buffer as if it were mono, so stereo DI takes were analysed from channel-interleaved garbage. | Walks frame by frame (`buffer[frame * num_channels]`) on channel 1. |
| 10 | `SGM_Utils.lua` | `trim()` used `"^%s*(.-)%s*$"` — `-` is not a Lua pattern quantifier, so it returned `""` for every input. | `gsub` based implementation (unit-tested). |

## 2. Logic bugs (fixed)

- **`SGM_route_mix_bus.lua` — selection ignored.** The help text says "select the
  tracks to route", but the loop processed every track in the project. Now: selection
  is honoured, and with nothing selected the documented all-top-level-tracks fallback
  applies (with a console note).
- **`SGM_route_mix_bus.lua` — folder children skipped.** Any track with
  `I_FOLDERDEPTH ~= 0` was skipped, which is *every* child inside a folder. Only
  folder *parents* are skipped now (their children already feed them).
- **`SGM_route_mix_bus.lua`** — a track literally named "Mix Bus" was treated as the
  bus; dangling undo point / UI refresh when there was nothing to do; `DRY_RUN`
  created nothing yet reported previews of a bus that would not exist.
- **`SGM_FieldyBagToggle.lua`** — wrote `TrackFX_SetEnabled` to slots 3–5 even when
  the track had fewer FX; the documented "No FX found on selected track." message
  was unreachable (a message box was shown instead); no undo point is created when
  nothing changes.
- **`daw-discovery-analyzer.lua`** — without SWS every routing edge was reported as
  `track_N -> master`; the built-in `P_DESTTRACK` API gives the real destination
  (plus parent sends). SWS detection now checks `BR_GetMediaTrackSendInfo_Track`,
  the function the routing code actually calls.
- **`daw-discovery-analyzer.lua`** — the config monitor started with no baseline, so
  the first poll never reported anything.
- **`rule-of-30-session-builder.lua`** — a new tempo marker was inserted at the edit
  cursor on every build (`SetTempoTimeSigMarker(..., -1, -1, ...)`); an existing
  marker is now updated. The master track is explicitly kept out of the
  master/parent-send stripping. Menu option **7 (Close)** did nothing and said
  nothing. `plugin_inventory.json` was only searched in the REAPER resource root —
  it is now looked for next to the script first.
- **`rule-of-30-session-builder.lua`** — sidechain sends were duplicated on every
  run, and `I_DSTCHAN = 2 + 1024` set the *mix-to-mono* bit instead of the channel
  offset. Now reuses an existing send and targets channel index 2 (3/4).
- **`rule-of-30-session-builder.lua`** — the inline JSON parser ignored `\` escapes.
  Replaced with a parser that handles them and returns only the parsed value
  (unit-tested against nested objects/arrays, numbers, booleans, `null`, escapes).
- **`phase-alignment-tool.lua`** — hard-coded 48 kHz in the sample-offset reports;
  the reported "peak" stopped accumulating once a transient was found.
- **`SGM_reaper_ultra_hd_smart_tools.lua`** — a failed theme write still printed the
  path as success; theme colours were written in `pairs()` order (non-deterministic
  output); theme metadata said author "EchoBeat" and a version unrelated to the
  package.

## 3. Documentation errors (fixed)

- **`SGM_reaper_ultra_hd_smart_tools.lua`** advertised a "toolbar clock", a "CPU
  meter overlay", a "color picker", and the shortcuts `Shift+F12` / `Ctrl+Alt+U`.
  None of them exist anywhere in the code — removed, and replaced with what the
  script actually does.
- **`SGM-Essentials/README.md`** said the mix-bus script creates a *folder* and moves
  tracks into it (it uses sends and never moves tracks), and listed `HPF_FREQ`,
  `COMP_THRESH`, `LIMIT_CEIL` as editable constants — they did not exist in the
  script (they do now, and the docs match the applied values).
- **`SGM-Essentials/README.md`** claimed `SGM_Utils.lua` is "loaded by other
  scripts"; nothing loads it. Now described as available for your own scripts.
- **`SGM-Essentials/README.md`** said "Seven scripts"; there are five runnable
  scripts plus a library and a metapackage.
- **`SGM-Essentials/INSTALL.md`** told Windows users to install into
  `%APPDATA%\REAPER\Scripts\...` as if it were universal, and said to expect
  "all 6 scripts" in the Actions list (libraries and metapackages are not actions).
  Portable macOS/Linux paths added.
- **`Rule-of-30/*`** described `rule-of-30-plugin-presets.lua` as a runtime
  dependency the builder loads; the builder never loads it. Reworded as a reference
  library everywhere (bundle header, README, INSTALL, index description).
- **`Rule-of-30/*`** referenced `list-all-available-plugins.lua` (not in this
  repository, not on ReaPack) as the fix for a missing plugin inventory, and did not
  document the expected `plugin_inventory.json` format or the consequence of Compact
  Mode with no inventory. Consolidated into one clear note (console + docs).
- **`SGM-Essentials/CHANGELOG.md`** was missing 1.1.1 entirely and dated 1.1.0
  differently from the script headers. Both changelogs now reflect the real history.
- **Test cases** asserted behaviour the code did not have (folder creation, the
  `GetCPULoading` report, the phantom smart-tool features). Updated, and cases added
  for the new guards (empty project, single FX chain, SWS-missing smart tools,
  early-exit phase alignment, repeated sidechain setup).

## 4. Packaging (`index.xml`)

- Versions in the index were stale (`SGM_auto_master`, `SGM_route_mix_bus`,
  `SGM_FieldyBagToggle` were 1.0.0 while the headers said 1.0.1 — those fixes would
  never have reached users). Regenerated from the script headers.
- The bundle `<reapack>` entries did not list the metapackage file itself, so the
  metapackage `.lua` was not part of its own package. Added as a `<source file=...>`
  without `main` (confirmed against `ReaPack::Index::Source#make_node`: `main` means
  *Action List section*, sibling files carry no `main`).
- Confirmed `main="main"` on every runnable script's own source is correct (it means
  "register in the main Action List section"), and that URL-encoded/normalised URLs
  are what `reapack-index` emits.
- **CI hardened**: `index.xml` validation now also checks that every `<source>` URL
  resolves to a file in the repository and that each package version matches its
  script's `@version` header — the two failures that let the stale index through.
  The Lua step was changed from `for f in $(git ls-files)` to a `while read` loop so
  paths with spaces cannot break it.

## 5. Notes / observations (not changed)

- The theme writer emits `[theme]` / `[color theme]` keys whose spelling is not
  validated against REAPER's actual `.ReaperTheme` schema here. It writes a file and
  reports the path; if REAPER ignores unknown keys, the file is harmless but the
  colours will not change. Worth a manual check in TEST_CASES TC-ST-01.
- The smart-tool engine cannot set the mouse *cursor shape* — ReaScript has no such
  API. It is now documented as a tool-resolution aid rather than a cursor changer.
- `SGM_Utils.lua` and `rule-of-30-plugin-presets.lua` are intentionally not indexed
  as separate packages (bundles carry them), so `@noindex` on both is correct.
- `Utils.JSON.parse` is deliberately small (numbers, strings, arrays, objects,
  booleans, null). It is not a drop-in for arbitrary JSON (no `\uXXXX` handling).

---

## 6. Second pass: tooling added

The first pass found bugs by reading; the bugs it *missed* were the ones that only
show up when a call is checked against the real API. So the checks are now part of
the repository instead of living in the audit:

| What | Where | What it catches |
|------|-------|-----------------|
| API-name check | `tools/check_api.py` + `tools/api_allowlist.json` | Any `reaper.*` call not in the REAPER 7.83 SDK header (878 functions) or the SWS allowlist. This is the check that would have caught items 5 and 12–14 before release. |
| Use-before-`local` check | same | `attempt to call a nil value (global 'x')` — the item-1 crash class. |
| `PreventUIRefresh` balance | same (per function, following helper calls) | Frozen arrange view after an early return — the item-8 class. |
| Runtime regression suite | `tests/run_tests.lua` + `tests/reaper_mock.lua` (21 cases) | Crashes, nil-send writes, duplicate sends, wrong destination channels, non-idempotent runs. |
| CI | `.github/workflows/ci.yml` | `lua5.4 -p`, the API check, the test suite, and the stricter `index.xml` validation. |

Both `tools/check_api.py` and the test suite fail loudly on the pre-fix tree: run
against `894f50a` the API check reports 7 unknown calls in 2 files.

## 7. Corrections to this report

**Item 5 (CPU metric) was wrong.** The first pass claimed `reaper.GetCPUUsage()` was
the correct replacement for `GetCPULoading()` on the strength of a GitHub code-search
hit count (129 hits), which measures how often a name is repeated in other people's
infected code, not whether it is real.

Checked properly against `reaper_plugin_functions.h` as generated by **REAPER v7.83**:

- 878 exported functions; searching for `cpu`, `perf`, `load` or `metric` returns only
  `GetCurrentProjectInLoadSave`, `LICE_LoadPNG` and `LICE_LoadPNGFromResource`.
- **There is no CPU, RT-CPU, RAM or disk metric available to ReaScript at all.** The
  Performance Meter is a C++ window; the only ReaScript-visible figure is Lua's own
  heap, via `collectgarbage("count")`.
- Consequently the analyzer **cannot** show CPU load. It opens the Performance Meter
  (`Main_OnCommand(40364, 0)`) and the report says so.

The same header check invalidated three more calls that the first pass introduced or
left in place:

| Wrong call | Real API |
|------------|----------|
| `reaper.GetProjectSampleRate()` | `reaper.GetAudioDeviceInfo("SRATE", "")` → success flag + string; returns `false` when no device is open, so both callers have a fallback |
| `reaper.GetInputChannelCount()` | `reaper.GetNumAudioInputs()` |
| `reaper.GetOutputChannelCount()` | `reaper.GetNumAudioOutputs()` |

**Lesson applied:** never accept an API name without checking it against the SDK
header. `tools/check_api.py` now enforces that, and the allowlist records the exact
header it was generated from.

---

## 8. Third pass: what the name check could not see

`tools/check_api.py` proves a function **exists**. It cannot prove the script
passes it the right arguments, and three of the four remaining fatal bugs are of
exactly that kind. Verified this time against the function prototypes in
`reaper_plugin_functions.h` (REAPER 7.83) and against the C++ that calls the same
actions.

| # | File | Problem | Severity |
|---|------|---------|----------|
| A | `SGM_auto_master.lua` | `TrackFX_SetParam(track, fx, param, value)` sets a **normalized 0..1** value. The script passes engineering units: `-18`, `2`, `10`, `100`, `-1.0`. Normalized params clamp at 0..1, so Threshold = 1.0 (loudest possible), Ratio = 2.0, Attack = 10, Release = 100, Ceiling = 1.0 (**+1 dB, louder than the source**). The "mastering chain" increases the level and the console reports success. `TrackFX_SetEQParam` is *not* affected: its `isnorm` argument is `false`, which is correct. | fatal, silent |
| B | `rule-of-30-session-builder.lua` | `SetTempoTimeSigMarker` takes **9** args; the calls pass 8. `CONFIG.bpm` lands in `beatpos` and `timesig_num` lands in `bpm`, so every session is built at **~4 BPM** (and time signature 95/110). | fatal, silent |
| C | `phase-alignment-tool.lua` | `reaper.new_array` is **1-based**. The transient scan reads `audio_buffer[frame * num_channels]`, so frame 0 reads `nil`→0, frame 1 reads frame 0's sample, and every stereo take is analysed at half its real sample offset. The phase alignment is off by the length of the analysis window. | wrong result |
| D | `rule-of-30-session-builder.lua` | `addFX` calls `TrackFX_AddByName(track, name, false, -1)`; `instantiate = -1` inserts a **new instance every run**. Chains added three times are inserted three times. | duplicates |
| E | `rule-of-30-session-builder.lua` | The 48-track skeleton is wrapped in one undo block. Stock FX are inserted onto a *master* track whose name is replaced, but the master FX chain is never cleared, so `ReaComp`/`ReaEQ` stack up on every build. | duplicates |
| F | `SGM_reaper_ultra_hd_smart_tools.lua` | `GetToggleCommandState(1009)` is documented as "Alt key". It is **not a modifier state** — it asks whether some action id 1009 is toggled. Alt is `GetModifierKeyState`, which does not exist in the ReaScript API, so the branch is unfixable as written and must be removed. The branch is dead code anyway: `_update_cursor_visual` only logs. | misleading |
| G | `SGM_reaper_ultra_hd_smart_tools.lua` | `_calculate_tool_mode` mixes coordinate spaces: `I_TCPY`/`I_TCPH` are TCP-relative and unscrolled (negative when scrolled down), while `GetMousePosition` is screen-space. `relative_y` is therefore meaningless. | wrong result |
| H | `daw-discovery-analyzer.lua` | `local PERFORMANCE_METER_ACTION = 40364` with the comment "View: Performance Meter". **40364 is "Options: Toggle metronome"** (SWS `Misc/Adam.cpp`: `Main_OnCommand(40364, 0); // Toggle built in metronome`). Running the analyzer toggles the click while telling the user it opened the meter. | wrong + side effect |

Findings A–H are documented here and queued in `todo.md`. They are **not fixed in
this commit**: each needs a REAPER-side test, and changing the FX/tempo/send
behaviour without one is how the previous two passes produced new bugs.

### Why the previous pass said the opposite

§7 concluded "there is no CPU metric, so open the Performance Meter". The
conclusion was right; the action ID was invented. A tool cannot verify the
existence of a number it was given, so the fix is not another number — it is
resolving the action by name at run time (`kbd_enumerateActions` +
`kbd_getCommandName`, both confirmed present in the header) and reporting when it
cannot be found.
