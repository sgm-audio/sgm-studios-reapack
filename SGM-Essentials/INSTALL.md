# SGM Essentials — Installation Guide

## Option 1: Install via ReaPack (Recommended)

1. **Add the SGM Studios repository** (if not already added):
   - REAPER → **Extensions** → **ReaPack** → **Import repositories**
   - Paste: `https://raw.githubusercontent.com/sgm-audio/sgm-studios-reapack/main/index.xml`
   - Click **Import** → **OK**

2. **Install the bundle**:
   - **Extensions** → **ReaPack** → **Browse packages**
   - Search for **SGM Studios Essentials: mix bus routing** (the metapackage)
   - Right-click → **Install**
   - Click **Apply**

3. **Verify**:
   - Press `?` to open Actions
   - Search for "SGM" — you should see the five action scripts (the bundle and `SGM_Utils.lua` do not appear as actions)

## Option 2: Manual Installation

1. **Copy files** to your REAPER Scripts folder. The Windows default is:
   ```
   %APPDATA%\REAPER\Scripts\SGM Studios\SGM-Essentials\
   ```
   On macOS/Linux this is `<REAPER resource path>/Scripts/SGM Studios/SGM-Essentials/`
   (find it with **Options** → **Show REAPER resource path in explorer/finder**).

   Copy all 7 files:
   - `SGM_route_mix_bus.lua`
   - `SGM_auto_master.lua`
   - `SGM_FieldyBagToggle.lua`
   - `SGM_reaper_ultra_hd_smart_tools.lua`
   - `daw-discovery-analyzer.lua`
   - `SGM_Utils.lua` (library — not an action)
   - `SGM_CoreUtilities_Bundle.lua` (metapackage — optional outside ReaPack)

2. **Register in REAPER**:
   - Actions → Show action list → New action → Load ReaScript
   - Select the five runnable scripts. Do **not** load `SGM_Utils.lua` (library) or
     `SGM_CoreUtilities_Bundle.lua` (metapackage) as actions.

## Verification

After installation, press `?` and search for:
- `SGM_route_mix_bus`
- `SGM_auto_master`
- `SGM_FieldyBagToggle`
- `SGM_reaper_ultra_hd_smart_tools`
- `daw-discovery-analyzer`

You should find five scripts. If you installed the metapackage through ReaPack and
only see the metapackage, its child sources were not installed — re-run
**ReaPack → Synchronize packages**.

## Requirements

- REAPER 7.0+ (Lua 5.4)
- SWS/S&M Extension — optional (routing detail in the analyzer, and the smart-tool
  cursor engine)
- All processing uses REAPER stock FX (ReaEQ, ReaComp, ReaLimit) — no paid plugins required
