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
> 7.83 SDK header. The unit tests in `tests/` (103 cases) run every main code path
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
| Runtime regression suite | `tests/run_tests.lua`, `run_phase_tests.lua`, `run_builder_tests.lua`, `run_theme_tests.lua` + `tests/reaper_mock.lua` (103 cases) | Crashes, nil-send writes, duplicate sends, wrong destination channels, non-idempotent runs. |
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

Findings A–H are all **fixed and covered by tests**. A, B, C, D and E in the
wiring pass (§9); F, G and H in 2.1.0 / 1.1.0 (§12). Two of them were worse than
recorded here: G had a second, unreported bug that made the feature work never
(see §12), and the "fix" for H in 1.0.3 had replaced one wrong answer with
another.

## 9. Wiring pass — what running the code for real found

The first four passes were all reading. This pass drove the scripts through
`tests/reaper_mock.lua` and asserted on the resulting project state, which turned
out to be the difference between "the arguments look plausible" and "the value is
where it says it is". Every defect below was found by a test, not by reading.

| # | Where | Problem | Status |
|---|-------|---------|--------|
| I | `tests/reaper_mock.lua` | `TrackFX_AddByName(..., 0)` **inserted** the plug-in instead of only querying it. The header is explicit: "Specify a negative value for instantiate to always create a new effect, **0 to only query** the first instance of an effect, or a positive value to add an instance if one is not found". A query that inserts makes every idempotency check look like it added a duplicate — and it hid a real bug for a whole test run. | fixed in the mock |
| J | `tests/reaper_mock.lua` | A script's `loadfile()`d library inherits the real `_G` under Lua 5.4, so the sandbox `_ENV` that supplied `reaper` did not reach the library: every preset lookup died with `attempt to index a nil value (global 'reaper')`. REAPER has `reaper` as a genuine global; the mock now sets it for the duration of a run. | fixed in the mock |
| K | `rule-of-30-session-builder.lua` (`scriptDirectory`) | Used `debug.getinfo(1,"S").source`, which is `"=[C]"` when a script is loaded by a wrapper, so the directory came back empty and neither `SGM_Utils.lua` nor the presets could be found — even though both sit next to the script. `get_action_context` is the documented way to find your own path; it is now tried first. | fixed (2.0.0) |
| L | `rule-of-30-plugin-presets.lua` | Values were hand-guessed normalized numbers with the engineering value in a comment. ReaComp threshold `-18 dB` was annotated "normalized 0.55"; the real position is **0.5781**, so the comment and the setting disagreed. Values are now written in the plug-in's units and converted at apply time by `Utils.fx_normalize()`, which bisects on the plug-in's own formatting. | fixed (3.0.0) |
| M | `rule-of-30-plugin-presets.lua` | ReaEQ was driven through raw parameter names (`"Band 2 Frequency"`), which ReaEQ does not expose as searchable parameters. EQ settings now go through `TrackFX_SetEQParam` with a band type. | fixed (3.0.0) |
| N | `SGM_auto_master.lua` | `TrackFX_SetEQParam` takes **7** arguments and `isnorm` is the last; the call passed 6, so the `false` that says "this frequency is in Hz" was never passed. Also: on a machine where the compressor settings could not be mapped, the console still printed "✓ Compressor (Glue) added". It now reports how many of the four settings it applied. | fixed (1.1.0) |
| O | `SGM_Utils.lua` | `Utils.native_color` takes a packed `0xRRGGBB` integer; `SGM_route_mix_bus` holds `{r, g, b}`. Wiring them together without an adapter raised a bitwise-arithmetic error on a table — a crash that only appears on the path where `SGM_Utils` *is* installed, i.e. the common case. | fixed (1.1.0) |
| P | `SGM_Utils.lua` | `TrackFX_FormatParamValueNormalized` returns **(retval, buf)**. Destructuring three values silently yields `nil` for the text, so every conversion returned `nil` and every setting was skipped — with no error to notice. | fixed (1.1.0) |

Lesson from I, J and P: the harness is code too, and a harness that is wrong in
permissive direction hides the bug it exists to find. The test suites now assert
on values read back **through the plug-in's own formatter**, which is the closest
a mock can get to "the user sees -18.0 dB in the UI".

### Why the previous pass said the opposite

§7 concluded "there is no CPU metric, so open the Performance Meter". The
conclusion was right; the action ID was invented. A tool cannot verify the
existence of a number it was given, so the fix is not another number — it is
resolving the action by name at run time (`kbd_enumerateActions` +
`kbd_getCommandName`, both confirmed present in the header) and reporting when it
cannot be found.

## 10. The "4K theme generator": what it actually does

The claim under review was that `SGM_reaper_ultra_hd_smart_tools.lua` "generates
4K themes". It cannot, and it never could. This section is the evidence, because
the honest answer ("it writes a colour scheme") and the claimed one ("it makes a
4K theme") differ in ways that matter to anyone who installs it.

### What a REAPER theme is

A theme is one of:

| Form | Contents | Can a ReaScript write it? |
|------|----------|---------------------------|
| `.ReaperTheme` | Plain text: `[color theme]` (colours) + `[REAPER]` (fonts, `ui_img`) | **Yes** — this is what the script edits |
| `.ReaperThemeZip` | The above, plus the entire PNG image stack (`tcp_*`, `mcp_*`, faders, knobs, per-DPI artwork) | **No** — it is binary artwork, authored in an image editor |

Evidence: a published theme (`gapalil001/FlatMadness`,
`Sources/Flat Madness Dark.ReaperTheme/Flat_madness_Dark_edition_EDIT.ReaperTheme`)
is 384 lines / 359 keys in `[color theme]` plus 21 `[REAPER]` entries. REAPER's
own theme adjuster (`Cockos/Default_7.0_theme_adjuster.lua`, shipped with REAPER)
does exactly this: read the file, change colour integers, write it back, call
`OpenColorThemeFile`. `amagalma_Adjust theme colors.lua` (ReaTeam/ReaScripts)
does the same and further demonstrates that a `.ReaperThemeZip` must be unzipped
before the colours inside are even reachable — the artwork is not scriptable.

### Resolution

There is no resolution in a theme file. REAPER draws at whatever scale the OS and
its own DPI setting request, and the API exposes that only as a *read*:

- `ThemeLayout_GetLayout(section, -3, buf, sz)` returns the current DPI scale
  (`256` = 1:1, `512` = 2x). There is no setter for it.
- `GetIconThemePointerForDPI(name, dpisc)` reads a per-scale icon from a loaded
  theme; it does not create one.
- The old script's `dpi_scale = 2.0` was never written to the file. Grep of the
  writer showed it referenced zero metadata fields.
- What actually changes at 4K is the **image stack**: a theme author supplies
  higher-resolution PNGs. Nothing a script can do.

### Colour mapping

The old writer emitted colours as 6-digit hex strings (`"12243a"`) under a
`[theme]` section that real theme files do not contain. REAPER parses
`[color theme]` values with `atoi()` into 32-bit integers:

The encoding is 0xRRGGBB little-endian, stored as a signed 32-bit decimal, so
`r=255, g=170, b=13` becomes `0x000DAAFF` = `895743` and `r=35, g=35, b=35`
becomes `0x00232323` = `2302755`; the high bit carries alpha, which is why a
theme's main background can appear as a large negative number.

A hex string parses as its leading digits — `"12243a"` becomes `12243`, a
near-black nobody chose — and unknown sections and keys are **silently ignored**.
So the generated theme loaded, changed nothing visible, and reported success.
That is the worst failure mode a theme generator can have, because there is no
error to notice.

Twelve of the thirty keys the old script wrote did not exist at all:
`col_tcp_bg`, `col_mcp_bg`, `col_mcp_text`, `col_mcp_textsel`, `col_item_bg`,
`col_item_fg`, `col_selitem_bg`, `col_selitem_fg`, `col_item_tag`,
`col_tcp_text_shadow`, `col_transport_bg`, `editcursor_color`. The real names are
`col_mixerbg`, `col_main_text`, `col_mi_bg`, `col_mi_bg2`, `col_cursor`, etc.

### Design assets

None were created, by any version. There is no image writer, no `ui_img`
generation, and no font creation. The old file referenced no images at all — and
a `.ReaperTheme` that names a `ui_img` the user does not have is precisely the
"loads and looks broken" case. The 2.0.0 rewrite inherits the `[REAPER]` section
(including `ui_img` and the font blobs) from the theme that is loaded, so the
output is a complete theme rather than a fragment.

### The contrast claim

The WCAG maths was correct; the claim around it was not.

- The shipped palette's primary text on its background measures **17.03:1**.
  The "optimise for AAA (7:1)" branch is guarded by `if contrast < 7.0`, so it
  could never execute. The feature was dead code with a marketing line attached.
- Had it executed, it would have **reduced** contrast: `sqrt(7/17.03) = 0.641`
  darkens text from 241,245,249 to 154,157,159, taking the ratio from 17.03:1 to
  **6.84:1** — further from the 7:1 it was aiming for, because scaling RGB is not
  how you raise a luminance ratio.

2.0.0 measures and prints five real ratios and changes nothing. A theme that
silently recolours your UI to reach an arbitrary number is a worse promise than
one that tells you the number.

### What 2.0.0 does instead

1. Reads the loaded theme via `GetLastColorThemeFile()`; refuses if it is a
   `.ReaperThemeZip` (it cannot read the artwork).
2. Parses it, replaces 33 colour keys (each verified against the published key
   list, which is now a test fixture), keeps the other ~326.
3. Writes integers, in `[color theme]`, with the `[REAPER]` section preserved.
4. Calls `OpenColorThemeFile()` to register it, and says plainly that switching
   theme is still a menu action.
5. Reports the DPI scale REAPER is actually drawing at.

`tests/run_theme_tests.lua` (25 cases) checks the packing against known values
from the real file, that every emitted key exists, that no colour is hex, that
the `[REAPER]` section survives, that the source's unknown-to-us keys are kept,
and that a zip is refused. It also asserts the false claims stay gone.

### The smart-tool half

Separate from the theme, the same file claimed a Pro Tools-style "smart tool".
It cannot exist as described: ReaScript has **no API to set the mouse cursor**.

- `GetToggleCommandState(1009)` was labelled "Alt key". It is not a modifier
  query, and there is no modifier-state function in the API at all.
- Version 1.0.2 already found that `SetMouseModifier` takes modifier-context and
  action-ID *strings*, and that passing numbers quietly corrupted the user's
  mouse-modifier preferences.
- What remains in 2.0.0 is a mode reporter: it logs which mode it would pick and
  changes neither the cursor nor any preference.

## 11. Licence: the theme-sharing problem, and a mistake made here

### The mistake

While building the theme-format fixture for §10, I copied a published theme's
contents into `tests/fixtures/theme_sample.ReaperTheme` and described it in a
comment as a "real theme file". It was: `gapalil001/FlatMadness`, which is
**GPL-3.0**. All 362 values were byte-identical, including its `ui_img` name and
font blobs. Committed to an MIT repository in commit `5e6c8b2`.

That is the exact failure this repository's audit exists to catch, and it was
introduced by the audit. Fixed in the next commit:

- The fixture is now generated from REAPER's documented stock defaults: every
  colour `0`, `ui_img=` empty, no font blobs. It exercises the parser (same keys,
  same sections, same value grammar) and contains nothing from anyone's theme.
  Verified: zero values shared with the GPL file.
- `theme_keys.txt` keeps the **key names** only. A list of INI key names is not
  creative content, but the credit is now in the file header rather than implied.
- Nothing from that theme ever reached the scripts themselves (checked: no font
  blob, no `ui_img` value, no colour value appears in any `.lua` file).

### The real licensing question

You cannot make generated themes shareable by relicensing this repository. The
scripts are already MIT, which is about as permissive as a licence gets; MIT is
not the obstacle. The obstacle is that **a theme file is mostly inherited
content**:

| Component of a generated `.ReaperTheme` | Whose it is |
|---|---|
| The ~33 colour values our palette writes | Ours — MIT |
| The other ~326 colour keys | The source theme's |
| `ui_img` (names the source theme's image stack) | The source theme's artwork |
| `[REAPER]` font blobs | The source theme's (or REAPER's defaults) |

The script inherits the loaded theme rather than inventing one, because a colour
file without the matching image stack loads and looks broken (§10). That choice
is correct technically and means the output is a derivative work. Relicensing our
side cannot change what someone else's licence says about their artwork.

### What was changed instead

1. **`LICENSE-THEMES.md`** — a permissive statement of what people may do with
   generated files: use, share, modify, sell; what must travel with the file; and
   the one route to a theme with no obligations at all (build from REAPER's stock
   Default theme, so the inherited parts are Cockos's).
2. **Provenance in the file.** Every generated theme now begins with a comment
   block naming the theme it was derived from, stating that the colour values are
   MIT and that the inherited artwork keeps its own licence. Somebody who finds
   the file in three years can tell where it came from without asking.
3. **Author credit is preserved.** Leading `;` comment lines from the source theme
   are copied through, so an author's own attribution is not silently dropped
   when their colours are rebuilt. (Before this, the header block was collected by
   the parser and then discarded.)
4. **The zip refusal stays.** Refusing to edit a `.ReaperThemeZip` is now also a
   licensing safeguard: it cannot produce a recolour of artwork it cannot read.
5. **CI guard.** A `license-headers` job fails if any `.lua` file lacks an
   `@license MIT` line, so a future file cannot quietly ship without one.

### What was not done, and why

- **Not relicensed to CC0 / Unlicense.** It would not change the theme problem at
  all (the inherited parts still are not ours to relicense), and MIT's attribution
  requirement is worth keeping for a project whose output people redistribute.
- **Not GPL.** Copyleft would *worsen* theme sharing: a recolour made from a GPL
  theme is already GPL, and making the scripts GPL as well would add an obligation
  to a workflow that currently has none.
- **No blanket permission over third-party artwork.** That is not ours to grant,
  and claiming it would be the same category of error as the "4K theme" claim.

## 12. F, G and H: fixed, and what the audit had missed

### F — the "Alt key" branch

Removed rather than repaired. `GetToggleCommandState(1009)` asks whether an
*action* is toggled; it is not a modifier query, and the API has no
modifier-state function at all (checked against the 7.83 header, 878 functions).
STRETCH is gone from the mode table. SPLIT went with it: it triggered within
100 ms of the edit cursor, so the middle of any item near the playhead became a
split zone whether or not that was wanted.

Tested: no mode resolves to `stretch`, and the engine makes zero
`GetToggleCommandState` calls while resolving a mode.

### G — the coordinate mix, plus a bug the audit did not find

The recorded defect was mixing unscrolled TCP coordinates with screen-space mouse
Y. That was real, but the function could never produce a result in the first
place:

```lua
local _, _, _, _, item_pos = reaper.BR_GetMouseCursorContext()
if not item_pos then return nil end          -- always nil
```

`BR_GetMouseCursorContext` returns **three** strings — window, segment, details.
Confirmed in SWS `Breeder/BR_ReaScript.h`:

```c
void BR_GetMouseCursorContext (char* windowOut, int windowOut_sz,
                               char* segmentOut, int segmentOut_sz,
                               char* detailsOut, int detailsOut_sz);
```

Destructuring five yields `nil` for the last two, so the guard returned on every
call and the smart-tool reporter had never reported a single mode — including in
the 2.0.0 rewrite, which is the version that introduced this line while
"fixing" the coordinates.

Rewritten in one consistent space: the row position comes from
`BR_GetMouseCursorContext_Position()` (arrange-view time under the cursor)
compared against the item's own `D_POSITION`/`D_LENGTH`, giving a 0..1 position
along the item. Both axes are then in item space. No screen-vs-TCP conversion is
attempted, because there is no API for "screen Y of a track row".

Tested at 0.5 s / 5 s / 9.5 s along a 10 s item (select / move / fade), with the
cursor past the item end and with the cursor over an empty arrange area. A test
asserts the modes are non-nil specifically so this class of bug cannot return
silently.

### H — action 40364

1.0.3 correctly identified that a phantom CPU function had been invented and then
replaced it with a remembered action id. The id was wrong: 40364 is
"Options: Toggle metronome", so the report opened nothing and switched the click
on. One wrong answer was swapped for another.

1.1.0 resolves the action from its description at run time:

```lua
local section = reaper.SectionFromUniqueID(0)
local cmd, name = reaper.kbd_enumerateActions(section, idx, "")
local text = reaper.kbd_getTextFromCmd(cmd, section)   -- the Action List text
```

Note `kbd_getCommandName` is a red herring — the SDK header says outright that it
"doesn't return the command's name". `kbd_getTextFromCmd` is the description.
The resolved id is printed, and on failure nothing runs:

```
Could not open the Performance Meter automatically: no action matching 'View: Performance Meter'
  Open it with: View > Performance Meter
```

The mock's action table contains the real 40364 with its real description, so a
reintroduced hard-coded id fails the suite. (The previous test asserted
`_commands_run[1] == 40364` *"because it is the Performance Meter"* — the test
was asserting the bug.)

### Verified, not assumed

Each fix was checked by reinstating the old code and confirming the suite fails:

| Reintroduced | Result |
|---|---|
| Five-value destructuring in `_mode_under_mouse` | 4 tests fail |
| `cmd = 40364` hard-coded in `showPerformanceMeter` | 2 tests fail |
