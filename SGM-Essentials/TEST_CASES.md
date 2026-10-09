# SGM Essentials — Test Cases

> **VERIFICATION STATUS: UNVERIFIED (2026-08-02)**
> These test cases require a REAPER 7.0+ runtime with SWS Extension installed.
> No functional verification has been performed in this environment.
> Syntax and structure have been validated via automated checks.

**Tester**: \_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_
**Date**: \_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_
**REAPER Version**: \_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_

---

## SGM_route_mix_bus

### TC-RM-01: Route selected tracks through mix bus
- **Prerequisites**: Project with 3+ audio tracks containing items. No mix bus exists.
- **Steps**:
  1. Select 3 tracks
  2. Run SGM_route_mix_bus
- **Expected Result**: A new "Mix Bus" folder track created. Selected tracks moved inside the folder. Sends from each track to Mix Bus. No duplicate sends.
- **Pass**: [ ] / [ ]

### TC-RM-02: DRY_RUN mode
- **Prerequisites**: Same as TC-RM-01. Set `DRY_RUN = true` at top of script.
- **Steps**:
  1. Select 3 tracks
  2. Run SGM_route_mix_bus
- **Expected Result**: Console shows what WOULD happen. No actual changes to the project.
- **Pass**: [ ] / [ ]

### TC-RM-03: Prevent duplicate routing
- **Prerequisites**: After running TC-RM-01 (mix bus already exists).
- **Steps**:
  1. Select the same 3 tracks
  2. Run SGM_route_mix_bus again
- **Expected Result**: No duplicate sends created. Console indicates routing already exists.
- **Pass**: [ ] / [ ]

### TC-RM-04: Run with no tracks selected
- **Prerequisites**: Empty project or no tracks selected.
- **Steps**:
  1. Run SGM_route_mix_bus
- **Expected Result**: Script shows error message: "No tracks selected." Graceful exit.
- **Pass**: [ ] / [ ]

---

## SGM_auto_master

### TC-AM-01: Apply mastering chain
- **Prerequisites**: Project with at least one audio item. Master track exists (always does).
- **Steps**:
  1. Run SGM_auto_master
  2. Confirm dialog when prompted
- **Expected Result**: HPF (30 Hz), ReaComp, and ReaLimit inserted on master track in order. Console confirms chain applied.
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
  2. Confirm
- **Expected Result**: Second set of FX added after the first. (No deduplication — intentional for comparison.)
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
- **Expected Result**: Console message: "No FX found on selected track." No crash.
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
- **Prerequisites**: REAPER 7.0+ (for 4K theme support).
- **Steps**:
  1. Run SGM_reaper_ultra_hd_smart_tools
  2. Follow theme installation prompt
- **Expected Result**: Theme file generated and applied. TCP and MCP render at higher resolution. Console confirms theme applied.
- **Pass**: [ ] / [ ]

### TC-ST-02: Smart tools defer loop
- **Prerequisites**: Theme installed from TC-ST-01.
- **Steps**:
  1. Run the script again
- **Expected Result**: Defer loop starts. Toolbar clock, CPU meter, or color picker appear (depending on configuration). Script stays running.
- **Pass**: [ ] / [ ]

---

## daw-discovery-analyzer

### TC-DD-01: Environment profiling
- **Prerequisites**: Any REAPER project open.
- **Steps**:
  1. Run daw-discovery-analyzer
  2. Open View → Console
- **Expected Result**: Cleanly formatted report showing: OS, REAPER version, audio device, sample rate, block size, installed extensions, project track count. No Lua error trace noise.
- **Pass**: [ ] / [ ]

### TC-DD-02: Run with SWS not installed
- **Prerequisites**: SWS Extension NOT installed. Any project.
- **Steps**:
  1. Run daw-discovery-analyzer
  2. Check console
- **Expected Result**: Report still generates. SWS-dependent fields show "not available" or similar. No crash.
- **Pass**: [ ] / [ ]

---

## Summary

| Test | Pass/Fail |
|------|-----------|
| TC-RM-01 | [ ] / [ ] |
| TC-RM-02 | [ ] / [ ] |
| TC-RM-03 | [ ] / [ ] |
| TC-RM-04 | [ ] / [ ] |
| TC-AM-01 | [ ] / [ ] |
| TC-AM-02 | [ ] / [ ] |
| TC-AM-03 | [ ] / [ ] |
| TC-FB-01 | [ ] / [ ] |
| TC-FB-02 | [ ] / [ ] |
| TC-FB-03 | [ ] / [ ] |
| TC-ST-01 | [ ] / [ ] |
| TC-ST-02 | [ ] / [ ] |
| TC-DD-01 | [ ] / [ ] |
| TC-DD-02 | [ ] / [ ] |
| **Total Pass** | **\_\_/14** |
