# Rule of 30 — Test Cases

> **VERIFICATION STATUS: UNVERIFIED (2026-10-08)**
> These test cases require a REAPER 7.0+ runtime.
> Syntax validated via Lua 5.4 parse; all 12 Top Shelf static audit checks passed.

**Tester**: \_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_
**Date**: \_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_
**REAPER Version**: \_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_

---

## rule-of-30-session-builder

### TC-R30-01: Build complete session
- **Prerequisites**: Empty project.
- **Steps**:
  1. Run rule-of-30-session-builder
  2. Enter `1` (Build Session)
- **Expected Result**: 48+ tracks created across 7 folder sections, colored per config, project tempo set to 100 BPM, timebase beats. One undo point removes the whole build (Ctrl+Z).
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
- **Expected Result**: Send created from Kick Out to Bass DI (and Bass Synth where present), destination channels 3/4 (sidechain). Undo point created.
- **Pass**: [ ] / [ ]

### TC-R30-05: Cancel the menu
- **Prerequisites**: Any project.
- **Steps**:
  1. Run the script
  2. Click Cancel (or enter an out-of-range value like `9`)
- **Expected Result**: No changes, no undo point created.
- **Pass**: [ ] / [ ]

---

## phase-alignment-tool

### TC-PA-01: Auto-align quad-tracked DIs
- **Prerequisites**: 4 selected DI tracks with items sharing transient hits.
- **Steps**:
  1. Run phase-alignment-tool
  2. Enter `1`
- **Expected Result**: Items nudged to align with the first track's transient; console reports per-track offsets; undo available.
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
- **Expected Result**: Console prints a phase correlation report for the two tracks.
- **Pass**: [ ] / [ ]

---

## Summary

| Test | Pass/Fail |
|------|-----------|
| TC-R30-01 | [ ] / [ ] |
| TC-R30-02 | [ ] / [ ] |
| TC-R30-03 | [ ] / [ ] |
| TC-R30-04 | [ ] / [ ] |
| TC-R30-05 | [ ] / [ ] |
| TC-PA-01 | [ ] / [ ] |
| TC-PA-02 | [ ] / [ ] |
| TC-PA-03 | [ ] / [ ] |
| **Total Pass** | **\_\_/8** |
