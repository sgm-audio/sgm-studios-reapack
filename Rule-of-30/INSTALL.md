# Rule of 30 — Installation Guide

## Option 1: Install via ReaPack (Recommended)

1. **Add the SGM Studios repository** (if not already added):
   - REAPER → **Extensions** → **ReaPack** → **Import repositories**
   - Paste: `https://raw.githubusercontent.com/sgm-audio/sgm-studios-reapack/main/index.xml`
   - Click **Import** → **OK**

2. **Install the bundle**:
   - **Extensions** → **ReaPack** → **Browse packages**
   - Search for **SGM Rule of 30 Bundle**
   - Right-click → **Install**
   - Click **Apply**

3. **Verify**:
   - Press `?` to open Actions
   - Search for "Rule of 30" and "Phase Alignment"

## Option 2: Manual Installation

1. **Copy files** to your REAPER Scripts folder:
   ```
   %APPDATA%\REAPER\Scripts\SGM Studios\Rule-of-30\
   ```

   Copy all 4 files:
   - `rule-of-30-session-builder.lua`
   - `rule-of-30-plugin-presets.lua` (library — @noindex, keep next to the session builder)
   - `phase-alignment-tool.lua`
   - `SGM_RuleOf30_Bundle.lua` (metapackage — optional for ReaPack)

2. **Register in REAPER**:
   - Actions → Show action list → New action → Load ReaScript
   - Select `rule-of-30-session-builder.lua` and `phase-alignment-tool.lua`
   - (Do not load `rule-of-30-plugin-presets.lua` — it is a data library)

## Requirements

- REAPER 7.0+ (Lua 5.4)
- No extensions required — SWS optional
- Processing chains use REAPER stock FX (ReaComp, ReaEQ, ReaGate) by default.
  Swap in Waves / Neural DSP / iZotope etc. per the presets library.

## Verification

After installation, press `?` and search for:
- `Rule of 30 Session Builder`
- `Phase Alignment Tool`
