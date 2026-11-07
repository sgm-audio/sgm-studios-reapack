# Rule of 30 — Installation Guide

## Option 1: Install via ReaPack (Recommended)

1. **Add the SGM Studios repository** (if not already added):
   - REAPER → **Extensions** → **ReaPack** → **Import repositories**
   - Paste: `https://raw.githubusercontent.com/sgm-audio/sgm-studios-reapack/main/index.xml`
   - Click **Import** → **OK**

2. **Install the bundle**:
   - **Extensions** → **ReaPack** → **Browse packages**
   - Search for **SGM Studios Rule of 30 heavy metal production bundle** (the metapackage)
   - Right-click → **Install**
   - Click **Apply**

3. **Verify**:
   - Press `?` to open Actions
   - Search for "Rule of 30" and "Phase Alignment" — you should see two actions

## Option 2: Manual Installation

1. **Copy files** to your REAPER Scripts folder. The Windows default is:
   ```
   %APPDATA%\REAPER\Scripts\SGM Studios\Rule-of-30\
   ```
   On macOS/Linux this is `<REAPER resource path>/Scripts/SGM Studios/Rule-of-30/`
   (find it with **Options** → **Show REAPER resource path in explorer/finder**).

   Copy all 4 files:
   - `rule-of-30-session-builder.lua`
   - `rule-of-30-plugin-presets.lua` (reference library — not an action)
   - `phase-alignment-tool.lua`
   - `SGM_RuleOf30_Bundle.lua` (metapackage — optional outside ReaPack)

2. **Register in REAPER**:
   - Actions → Show action list → New action → Load ReaScript
   - Select `rule-of-30-session-builder.lua` and `phase-alignment-tool.lua`
   - Do **not** load `rule-of-30-plugin-presets.lua` (data library) or
     `SGM_RuleOf30_Bundle.lua` (metapackage)

## Requirements

- REAPER 7.0+ (Lua 5.4)
- No extensions required — SWS optional
- Processing chains use REAPER stock FX (ReaComp, ReaEQ, ReaGate) by default.
  Swap in Waves / Neural DSP / iZotope etc. per the reference library.
- **Optional**: `plugin_inventory.json` next to the session builder for plugin-aware
  track creation. Without it, leave Compact Mode off (menu option `0`) to build the
  full skeleton.

## Verification

After installation, press `?` and search for:
- `Rule of 30 Session Builder`
- `Phase Alignment Tool`
