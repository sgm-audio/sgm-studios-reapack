# Rule of 30 — Test Cases

> **VERIFICATION STATUS: UNVERIFIED (2026-11-07)**
> These test cases require a REAPER 7.0+ runtime.
> Lua syntax and index.xml structure are validated by CI; no runtime verification
> has been performed in this environment.

**Tester**: \_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_
**Date**: \_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_
**REAPER Version**: \_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_

---

## rule-of-30-session-builder

### TC-R30-01: Build complete session (no plugin inventory)
- **Prerequisites**: Empty project. No `plugin_inventory.json`.
- **Steps**:
  1. Run rule-of-30-session-builder
  2. Enter `0` to turn Compact Mode **off**
  3. Enter `1` (Build Session)
- **Expected Result**: The full ~48-track skeleton is created across the 7 folder sections, colored per config, project tempo set to 100 BPM and timebase to beats. **No `attempt to call a nil value (global 'addFX')` error.** One undo point removes the whole build (Ctrl+Z).
- **Pass**: [ ] / [ ]

### TC-R30-01b: Build with Compact Mode ON and no inventory
- **Prerequisites**: Empty project. No `plugin_inventory.json`. Compact Mode ON (default).
- **Steps**:
  1. Run the script → enter `1`
- **Expected Result**: Console notes that no inventory was found, plugin-aware tracks are skipped, and the final summary warns that Compact Mode is ON without an inventory. No crash.
- **Pass**: [ ] / [ ]

### TC-R30-02: Compact Mode toggle
- **Prerequisites**: Any project.
- **Steps**:
  1. Run the script
  2. Enter `0`
- **Expected Result**: Dialog reports Compact Mode ON or OFF. With ON and missing plugins, tracks without matches are skipped with a console notice.
- **Pass**: [ ] / [ ]

### TC-R30-03: Add drum processing chains
- **Prerequisites**: Session built (TC-R30-01).
- **Steps**:
  1. Run the script
  2. Enter `2`
- **Expected Result**: ReaGate / ReaComp / ReaEQ added to matching drum tracks; console shows ✓ per chain; a single undo point covers the operation.
- **Pass**: [ ] / [ ]

### TC-R30-04: Kick/Bass sidechain routing
- **Prerequisites**: Session built (TC-R30-01).
- **Steps**:
  1. Run the script
  2. Enter `6`
  3. Run the script → `6` again
- **Expected Result**: First run creates a send from Kick Out to Bass DI (and Bass Synth where present) with destination channels **3/4** (sidechain, not mono). Second run reports "Sidechain already exists" and does **not** add a duplicate send. Each run creates one undo point.
- **Pass**: [ ] / [ ]

### TC-R30-05: Build twice / tempo marker
- **Prerequisites**: Session already built from TC-R30-01.
- **Steps**:
  1. Run the script → `1` again, then open the tempo envelope
- **Expected Result**: The project still has a single tempo marker at 100 BPM (no new marker inserted at the edit cursor).
- **Pass**: [ ] / [ ]

### TC-R30-06: Cancel the menu
- **Prerequisites**: Any project.
- **Steps**:
  1. Run the script
  2. Click Cancel (or enter an out-of-range value like `9`)
- **Expected Result**: No changes, no undo point created.
- **Pass**: [ ] / [ ]

---

## phase-alignment-tool

### TC-PA-01: Auto-align quad-tracked DIs
- **Prerequisites**: 4 selected **stereo** DI tracks with items sharing transient hits.
- **Steps**:
  1. Run phase-alignment-tool
  2. Enter `1`
- **Expected Result**: Items nudged to align with the earliest transient; the console reports per-track offsets in samples at the **project** sample rate; one undo point; no lingering UI freeze.
- **Pass**: [ ] / [ ]

### TC-PA-01b: Not enough tracks (early exit)
- **Prerequisites**: 0 or 1 track selected.
- **Steps**:
  1. Run the script → `1`
- **Expected Result**: Console asks you to select at least 2 tracks. The arrange view is **not** left un-refreshed (it still redraws) and no undo point is created.
- **Pass**: [ ] / [ ]

### TC-PA-02: Nudge controls
- **Prerequisites**: One or more items selected.
- **Steps**:
  1. Run the script, enter `3` (nudge left 1 ms)
  2. Repeat with `4`, `5`, `6`
- **Expected Result**: Selected items nudged ±1 ms / ±0.1 ms per action; each action creates its own undo point.
- **Pass**: [ ] / [ ]

### TC-PA-03: Analyze phase correlation
- **Prerequisites**: Exactly 2 tracks selected.
- **Steps**:
  1. Run the script
  2. Enter `2`
- **Expected Result**: Console prints the item position difference and a verdict (EXCELLENT / GOOD / ACCEPTABLE / WARNING).
- **Pass**: [ ] / [ ]

---

## Summary

| Test | Pass/Fail |
|------|-----------|
| TC-R30-01 | [ ] / [ ] |
| TC-R30-01b | [ ] / [ ] |
| TC-R30-02 | [ ] / [ ] |
| TC-R30-03 | [ ] / [ ] |
| TC-R30-04 | [ ] / [ ] |
| TC-R30-05 | [ ] / [ ] |
| TC-R30-06 | [ ] / [ ] |
| TC-PA-01 | [ ] / [ ] |
| TC-PA-01b | [ ] / [ ] |
| TC-PA-02 | [ ] / [ ] |
| TC-PA-03 | [ ] / [ ] |
| **Total Pass** | **\_\_/11** |
