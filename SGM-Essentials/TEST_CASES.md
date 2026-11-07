# SGM Essentials — Test Cases

> **VERIFICATION STATUS: UNVERIFIED (2026-11-07)**
> These test cases require a REAPER 7.0+ runtime. SWS is only needed for the
> DAW analyzer routing detail and for the smart-tool engine.
> No functional verification has been performed in this environment.
> Lua syntax and index.xml structure have been validated via automated checks.

**Tester**: \_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_
**Date**: \_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_
**REAPER Version**: \_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_

---

## SGM_route_mix_bus

### TC-RM-01: Route selected tracks through mix bus
- **Prerequisites**: Project with 5+ audio tracks containing items. No mix bus exists.
- **Steps**:
  1. Select 3 tracks
  2. Run SGM_route_mix_bus
- **Expected Result**: A new "Mix Bus" track created (at the bottom, coloured). Only the 3 *selected* tracks have their master/parent send disabled and a send to Mix Bus. A single undo point covers the operation.
- **Pass**: [ ] / [ ]
- **Pass**: [ ] / [ ]

### TC-RM-02: DRY_RUN mode
- **Prerequisites**: Same as TC-RM-01. Set `DRY_RUN = true` at top of script.
- **Steps**:
  1. Select 3 tracks
  2. Run SGM_route_mix_bus
- **Expected Result**: Console shows what WOULD happen. No track is created and no send or send-enable state changes.
- **Pass**: [ ] / [ ]

### TC-RM-03: Prevent duplicate routing
- **Prerequisites**: After running TC-RM-01 (mix bus already exists).
- **Steps**:
  1. Select the same 3 tracks
  2. Run SGM_route_mix_bus again
- **Expected Result**: No duplicate sends created. Console indicates routing already exists.
- **Pass**: [ ] / [ ]

### TC-RM-04: Run with no tracks selected
- **Prerequisites**: Project with several tracks, none selected.
- **Steps**:
  1. Deselect everything
  2. Run SGM_route_mix_bus
- **Expected Result**: Every top-level track is routed (documented fallback), folder parents are skipped, and the console reports the count. No Lua error.
- **Pass**: [ ] / [ ]

### TC-RM-05: Run in an empty project
- **Prerequisites**: Empty project (0 tracks).
- **Steps**:
  1. Run SGM_route_mix_bus
- **Expected Result**: Console: "No tracks to route." No Mix Bus created, no error.
- **Pass**: [ ] / [ ]

---

## SGM_auto_master

### TC-AM-01: Apply mastering chain
- **Prerequisites**: Project with at least one audio item. Master track exists (always does).
- **Steps**:
  1. Run SGM_auto_master
  2. Confirm the dialog if it appears (only shown when the master already has FX)
- **Expected Result**: ReaEQ (with band 1 enabled as a high-pass at 30 Hz), ReaComp (threshold −18 dB, ratio 2:1) and **ReaLimit** (ceiling −1.0 dB) inserted on the master track in that order. Console confirms each stage. Open ReaEQ and check band 1 is a high-pass at 30 Hz.
- **Pass**: [ ] / [ ]

### TC-AM-02: Cancel confirmation dialog
- **Prerequisites**: Any project.
- **Steps**:
  1. Run SGM_auto_master
  2. Click Cancel when prompted
- **Expected Result**: No FX added to master track. Undo point not created.
- **Pass**: [ ] / [ ]

### TC-AM-03: Run twice
- **Prerequisites**: Mastering chain already applied from TC-AM-01.
- **Steps**:
  1. Run SGM_auto_master again
  2. Answer **Yes** to "Clear them and apply mastering chain?"
- **Expected Result**: The previous chain is replaced (still exactly 3 FX, not 6) and a single new undo point is created. Answering **No** leaves the project untouched.
- **Pass**: [ ] / [ ]

### TC-AM-04: No master FX (no dialog)
- **Prerequisites**: Master track with no FX.
- **Steps**:
  1. Run SGM_auto_master
- **Expected Result**: No confirmation dialog; the chain is applied straight away.
- **Pass**: [ ] / [ ]

---

## SGM_FieldyBagToggle

### TC-FB-01: Toggle between FX chains
- **Prerequisites**: Track with FX in slots 1–6 (slots 1–3 = Fieldy chain, slots 4–6 = Dimebag chain).
- **Steps**:
  1. Run SGM_FieldyBagToggle
  2. Check which FX are bypassed
- **Expected Result**: If Fieldy was active (1–3 enabled, 4–6 bypassed), now Dimebag is active (4–6 enabled, 1–3 bypassed). Run again to toggle back.
- **Pass**: [ ] / [ ]

### TC-FB-02: Run on track without FX
- **Prerequisites**: Track with no FX.
- **Steps**:
  1. Run SGM_FieldyBagToggle
- **Expected Result**: Console message: "No FX found on selected track." No undo point, no crash.
- **Pass**: [ ] / [ ]

### TC-FB-02b: Track with only the first chain
- **Prerequisites**: Track with 3 FX (slots 1–3 only).
- **Steps**:
  1. Run SGM_FieldyBagToggle
- **Expected Result**: Console: "Only one FX chain present on this track — nothing to toggle." No Lua error.
- **Pass**: [ ] / [ ]

### TC-FB-03: Run with no track selected
- **Prerequisites**: No tracks selected.
- **Steps**:
  1. Run SGM_FieldyBagToggle
- **Expected Result**: Error message about no track selected. Graceful exit.
- **Pass**: [ ] / [ ]

---

## SGM_reaper_ultra_hd_smart_tools

### TC-ST-01: Theme generation
- **Prerequisites**: REAPER 7.0+.
- **Steps**:
  1. Run SGM_reaper_ultra_hd_smart_tools
  2. Answer **No** to the smart-tool prompt
- **Expected Result**: `SGM_UltraHD_v1.0.2.ReaperTheme` is written to `<resource path>/ColorThemes`; the console prints the full path. Options → Themes → Theme now lists "SGM UltraHD" and selecting it changes the colours. No error.
- **Pass**: [ ] / [ ]

### TC-ST-02: Smart-tool engine (SWS installed)
- **Prerequisites**: Theme generated from TC-ST-01; SWS extension installed; a project with media items.
- **Steps**:
  1. Run the script and answer **Yes** to "Also start the Smart Tool engine now?"
  2. Hover over media items, then stop the script (Actions → Terminate instances)
- **Expected Result**: Console prints one line per resolved tool. **Nothing in your mouse-modifier preferences changes** (this is by design — the old build wrote invalid IDs there). No Lua error.
- **Pass**: [ ] / [ ]

### TC-ST-03: Smart-tool engine (SWS not installed)
- **Prerequisites**: SWS extension NOT installed.
- **Steps**:
  1. Run the script and answer **Yes**
- **Expected Result**: Console: "Smart tools need the SWS extension for mouse context — not started." No defer loop, no error.
- **Pass**: [ ] / [ ]

---

## daw-discovery-analyzer

### TC-DD-01: Environment profiling
- **Prerequisites**: Any REAPER project open.
- **Steps**:
  1. Run daw-discovery-analyzer
  2. Enter `1` (Comprehensive Analysis)
  3. Open View → Console
- **Expected Result**: Cleanly formatted report showing audio system, sample rate, buffer size, bit depth, Lua heap, active FX count, plugin categories, track/connection counts. The CPU line reads `CPU: see the Performance Meter window` and REAPER's Performance Meter opens (action 40364). **No `attempt to call a nil value (field ...)` error for any of `GetCPULoading`, `GetCPUUsage`, `GetProjectSampleRate`, `GetInputChannelCount`, `GetOutputChannelCount`.**
- **Pass**: [ ] / [ ]

### TC-DD-02: Run with no audio device open
- **Prerequisites**: Any REAPER project; close the audio device (Preferences →
  Audio → Device → uncheck "Close audio device when stopped...") or start REAPER
  with no device.
- **Steps**: Run daw-discovery-analyzer → `1` → check the console.
- **Expected Result**: The Sample Rate line reads `n/a (device closed)`, not
  `nil Hz`. The report completes.
- **Pass**: [ ] / [ ]

### TC-DD-03: Run with SWS not installed
- **Prerequisites**: SWS Extension NOT installed. Any project.
- **Steps**:
  1. Run daw-discovery-analyzer
  2. Check console
- **Expected Result**: Report still generates and the signal-flow map shows real send destinations (not every track pointing at `master`). The console prints the SWS "not installed" note at startup. No crash.
- **Pass**: [ ] / [ ]

---

## Summary

| Test | Pass/Fail |
|------|-----------|
| TC-RM-01 | [ ] / [ ] |
| TC-RM-02 | [ ] / [ ] |
| TC-RM-03 | [ ] / [ ] |
| TC-RM-04 | [ ] / [ ] |
| TC-RM-05 | [ ] / [ ] |
| TC-AM-01 | [ ] / [ ] |
| TC-AM-02 | [ ] / [ ] |
| TC-AM-03 | [ ] / [ ] |
| TC-AM-04 | [ ] / [ ] |
| TC-FB-01 | [ ] / [ ] |
| TC-FB-02 | [ ] / [ ] |
| TC-FB-02b | [ ] / [ ] |
| TC-FB-03 | [ ] / [ ] |
| TC-ST-01 | [ ] / [ ] |
| TC-ST-02 | [ ] / [ ] |
| TC-ST-03 | [ ] / [ ] |
| TC-DD-01 | [ ] / [ ] |
| TC-DD-02 | [ ] / [ ] |
| TC-DD-03 | [ ] / [ ] |
| **Total Pass** | **\_\_/19** |
