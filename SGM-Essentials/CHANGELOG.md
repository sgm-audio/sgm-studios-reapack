# SGM Essentials — Changelog

## 1.5.0 (2026-11-12)

- **SGM_route_mix_bus 1.1.1**: the no-selection fallback routes top-level tracks,
  including folder parents, instead of sending folder children around their parents
  (which bypassed folder processing). Explicitly selected folder parents can now be
  routed as intended. Added mock regression coverage for nested folder layouts.

## 1.1.2 (2026-11-07)

Bug-fix and documentation pass after auditing every script against the ReaScript API.

- **SGM_auto_master 1.0.1**
  - Fixed: the limiter is the stock plug-in **`ReaLimit`**; the script asked for
    `ReaLimiter`, so no limiter was ever inserted.
  - Fixed: the ReaEQ high-pass was written as raw values into parameter indices
    0–3 (which are the band enables, not band/type/freq/Q). It now uses
    `TrackFX_SetEQParam` + `TrackFX_SetEQBandEnabled`.
  - Fixed: ReaComp/ReaLimit values are now found by parameter name instead of
    hard-coded indices.
  - Added: the `HPF_FREQ` / `COMP_THRESH` / `COMP_RATIO` / `LIMIT_CEIL` constants
    the documentation always promised (the hard-coded values differed from the docs).
- **SGM_route_mix_bus 1.0.1**
  - Fixed: the script ignored track selection and routed *every* top-level track.
  - Fixed: nested tracks inside folders were skipped entirely; now only folder
    parents are skipped (children already feed them).
  - Fixed: with nothing to do, no dangling undo point / UI refresh.
  - Fixed: a track literally named "Mix Bus" is no longer mistaken for the bus.
- **SGM_FieldyBagToggle 1.0.1**
  - Fixed: bypass state was written to FX slots that do not exist.
  - Fixed: "No FX found on selected track." is now actually printed (per TEST_CASES).
  - Fixed: no undo point when nothing was toggled.
- **SGM_reaper_ultra_hd_smart_tools 1.0.3**
  - Added: the smart-tool engine now reports its real state with
    `SetToggleCommandState` + `RefreshToolbar2`, so a toolbar button reflects
    whether the defer loop is running (it used to stay lit after the loop died).
  - Fixed: the defer loop is wrapped in `xpcall`; an error in one tick stops the
    loop, corrects the toggle state and prints the traceback instead of dying
    silently.
- **daw-discovery-analyzer 1.0.4**
  - Added: the config monitor publishes its running state to the Action List, for
    the same reason.
- **daw-discovery-analyzer 1.0.3**
  - Fixed (corrects 1.0.2): 1.0.2 replaced the non-existent `GetCPULoading()` with
    `GetCPUUsage()`, which also does not exist. **REAPER exposes no CPU metric to
    ReaScript at all** (verified against the REAPER 7.83 SDK header — 878 exported
    functions, none of them a CPU/performance counter). The report now says so and
    opens REAPER's own Performance Meter (action `40364`) instead of inventing a
    number.
  - Fixed: `GetProjectSampleRate()`, `GetInputChannelCount()` and
    `GetOutputChannelCount()` are not API functions either. Sample rate now comes
    from `GetAudioDeviceInfo("SRATE")`, channels from `GetNumAudioInputs()` /
    `GetNumAudioOutputs()`.
  - Fixed: a closed audio device printed `nil Hz`; it now prints
    `n/a (device closed)`.
- **daw-discovery-analyzer 1.0.2**
  - Fixed: audio bit depth queried `"BITDEPTH"`; the API key is `"BPS"`.
  - Fixed: without SWS every routing edge pointed at `master`; the built-in
    `P_DESTTRACK` API now supplies the real destination (plus parent sends).
  - Fixed: SWS detection checked a mouse-context function that the routing code
    never uses.
  - Fixed: the config monitor started with no baseline.
- **SGM_reaper_ultra_hd_smart_tools 1.0.2**
  - Fixed: smart tools passed numeric cursor ids to `SetMouseModifier()`, which
    only accepts mouse-modifier/action ID strings. The engine no longer touches
    mouse modifiers at all.
  - Removed from the docs: "toolbar clock", "CPU meter overlay", "color picker",
    and the `Shift+F12` / `Ctrl+Alt+U` shortcuts — none of them ever existed.
  - Fixed: a failed theme write is reported instead of printed as success.
  - Fixed: author/metadata now matches the rest of the repository.
- **phase-alignment-tool 1.0.3**
  - Fixed: `reaper.GetProjectSampleRate()` does not exist; the project rate is now
    read with `GetAudioDeviceInfo("SRATE")`, with a 48 kHz fallback when no device
    is open.
- **Bundles**: `SGM_CoreUtilities_Bundle` 1.1.3 and `SGM_RuleOf30_Bundle` 1.0.3
  pick up the two script fixes (ReaPack only offers an update when the
  metapackage version itself changes).
- **SGM_Utils 1.0.1**
  - Fixed: `Utils.trim()` used `(.-)` (not a Lua pattern) and returned an empty
    string for every input.
- **Packaging**: `index.xml` regenerated. Bundle `<reapack>` entries now include
  the metapackage file itself, and every package version matches its script header.

## 1.1.1 (2026-10-08)
- **daw-discovery-analyzer 1.0.1**: `GetUserInputs` menu, localized functions
- **SGM_reaper_ultra_hd_smart_tools 1.0.1**: palette fix (adds the missing
  `ThemeMetadata.palette`), mouse-modifier save/restore, no global exports

## 1.1.0 (2026-06-03)
- **Repository**: Files reorganized into `SGM-Essentials/` package folder
- **Bundle**: Updated `@provides` to reference correct paths for all sub-scripts
- **Bundle**: Added `daw-discovery-analyzer.lua` and
  `SGM_reaper_ultra_hd_smart_tools.lua` to the bundle

## 1.0.0 (2026-04-20)
- **Initial release** of Core Utilities bundle:
  - `SGM_route_mix_bus.lua` — mix bus routing
  - `SGM_auto_master.lua` — one-click mastering
  - `SGM_FieldyBagToggle.lua` — bass FX toggle
  - `SGM_Utils.lua` — shared library
  - `SGM_CoreUtilities_Bundle.lua` — metapackage
