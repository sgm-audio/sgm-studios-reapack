# SGM Essentials for REAPER

**A free collection of essential REAPER scripts — mix routing, mastering, bass FX toggling, smart tools, and system profiling.**

Seven scripts that add everyday workflow superpowers. All free, all open-source (MIT), available via ReaPack.

---

## Included Scripts

| Script | Type | What It Does |
|--------|------|-------------|
| **SGM_route_mix_bus.lua** | [main] | Routes selected tracks through a mix bus folder — creates the bus, moves tracks in, sets up sends, prevents duplicate routing. Features `DRY_RUN` mode to preview changes. |
| **SGM_auto_master.lua** | [main] | One-click mastering chain on master track: High-pass filter → ReaComp → ReaLimit. Configurable parameters, confirmation dialog to prevent accidents. |
| **SGM_FieldyBagToggle.lua** | [main] | Toggles between two bass guitar FX chains: Fieldy (slap/rock, slots 1–3) and Dimebag (metal, slots 4–6). Bypasses one set and enables the other. |
| **SGM_reaper_ultra_hd_smart_tools.lua** | [main] | Generates a 4K/UHD REAPER theme with WCAG-compliant contrast optimization. Includes a defer loop for dynamic toolbar tools (toolbar clock, CPU meter, color picker). |
| **daw-discovery-analyzer.lua** | [main] | Profiles the REAPER environment — OS, REAPER version, audio device, sample rate, block size, installed extensions, and project stats. Outputs a clean console report. |
| **SGM_Utils.lua** | [@noindex] | Shared utility library — color conversion, track helper functions, log formatting. Not a standalone script. |
| **SGM_CoreUtilities_Bundle.lua** | [@metapackage] | ReaPack metapackage — installing this pulls all 6 scripts above. |

---

## Quick Start

1. **Install** via ReaPack (recommended) or manually (see INSTALL.md)
2. **Run from Actions** (`?`) — search for "SGM" to see all scripts
3. **Recommended usage order**:
   - Run `daw-discovery-analyzer` first to profile your setup
   - Use `SGM_route_mix_bus` to organize your session
   - Use `SGM_auto_master` on your mix bus for quick reference
   - Use `SGM_FieldyBagToggle` on bass tracks
   - Explore `SGM_reaper_ultra_hd_smart_tools` for theme customization

---

## Configuration

Key configuration constants are at the top of each script:

| Script | Key Config |
|--------|-----------|
| `SGM_route_mix_bus.lua` | `DRY_RUN = false` — set to `true` to preview without changes |
| `SGM_auto_master.lua` | `HPF_FREQ = 30`, `COMP_THRESH = -18`, `LIMIT_CEIL = -1.0` |
| `SGM_FieldyBagToggle.lua` | No config — uses FX slots 1–3 (Fieldy) and 4–6 (Dimebag) |
| `SGM_reaper_ultra_hd_smart_tools.lua` | Theme colors, toolbar tool config |
| `daw-discovery-analyzer.lua` | No config — run and read output |

---

## License

MIT — free for personal and commercial use. See individual script headers.

---

## Support

Open an issue on the ReaPack repository or contact **SGM Studios**.
