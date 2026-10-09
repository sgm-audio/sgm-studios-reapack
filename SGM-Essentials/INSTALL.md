# SGM Essentials — Installation Guide

## Option 1: Install via ReaPack (Recommended)

1. **Add the SGM Studios repository** (if not already added):
   - REAPER → **Extensions** → **ReaPack** → **Import repositories**
   - Paste: `https://raw.githubusercontent.com/sgm-audio/sgm-studios-reapack/main/index.xml`
   - Click **Import** → **OK**

2. **Install the bundle**:
   - **Extensions** → **ReaPack** → **Browse packages**
   - Search for **SGM CoreUtilities Bundle**
   - Right-click → **Install**
   - Click **Apply**

3. **Verify**:
   - Press `?` to open Actions
   - Search for "SGM" — you should see all 6 scripts

## Option 2: Manual Installation

1. **Copy files** to your REAPER Scripts folder:
   ```
   %APPDATA%\REAPER\Scripts\SGM Studios\SGM-Essentials\
   ```

   Copy all 7 files:
   - `SGM_route_mix_bus.lua`
   - `SGM_auto_master.lua`
   - `SGM_FieldyBagToggle.lua`
   - `SGM_reaper_ultra_hd_smart_tools.lua`
   - `daw-discovery-analyzer.lua`
   - `SGM_Utils.lua` (library — @noindex)
   - `SGM_CoreUtilities_Bundle.lua` (metapackage — optional for ReaPack)

2. **Register in REAPER**:
   - Actions → Show action list → New action → Load ReaScript
   - Select each `.lua` file (not `SGM_Utils.lua` — it's a library)

## Verification

After installation, press `?` and search for:
- `SGM_route_mix_bus`
- `SGM_auto_master`
- `SGM_FieldyBagToggle`
- `SGM_reaper_ultra_hd_smart_tools`
- `daw-discovery-analyzer`
