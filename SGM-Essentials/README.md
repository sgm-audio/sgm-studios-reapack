# SGM Essentials for REAPER

**A free collection of essential REAPER scripts — mix routing, mastering, bass FX toggling, smart tools, and system profiling.**

Six runnable scripts plus a shared library and a ReaPack metapackage. All free, all open-source (MIT), available via ReaPack.

---

## Included Scripts

| Script | Type | What It Does |
|--------|------|-------------|
| **SGM_route_mix_bus.lua** | [main] | Routes tracks through a dedicated Mix Bus track. With tracks selected, only those are routed; with nothing selected, every top-level track is. Folder parents are skipped (their children already feed them), tracks already sent to the bus are not duplicated, and `DRY_RUN` previews the changes. |
| **SGM_auto_master.lua** | [main] | One-click mastering chain on the master bus: ReaEQ high-pass → ReaComp → ReaLimit. Configurable at the top of the script, with a confirmation dialog before existing master FX are replaced. |
| **SGM_FieldyBagToggle.lua** | [main] | Toggles between two bass FX chains: Fieldy (slots 1–3) and Dimebag (slots 4–6). Enables one set and bypasses the other; only touches slots that actually exist. |
| **SGM_reaper_ultra_hd_smart_tools.lua** | [main] | Writes a 4K-friendly `.ReaperTheme` file with a WCAG contrast check (AAA 7:1 target), and can optionally start an experimental smart-tool cursor engine. |
| **daw-discovery-analyzer.lua** | [main] | Profiles the REAPER environment — OS, REAPER version, audio system/device, sample rate, buffer size and bit depth, Lua memory, plugin inventory, track structure and routing graph. Outputs a console report and opens REAPER's Performance Meter for CPU figures (ReaScript has no CPU API). |
| **SGM_Utils.lua** | [nomain] | Shared utility library (string/math/path helpers, REAPER color helpers, a small JSON parser, stem classification, plug-in parameter mapping). The bundled scripts load it automatically when it is installed and fall back to their own helpers when it is not, so you can delete it and everything still runs. |
| **SGM_CoreUtilities_Bundle.lua** | [nomain] / metapackage | ReaPack metapackage — installing this pulls in all six scripts above. |

---

## Quick Start

1. **Install** via ReaPack (recommended) or manually (see [INSTALL.md](INSTALL.md))
2. **Run from Actions** (`?`) — search for "SGM" to see all scripts
3. **Recommended usage order**:
   - Run `daw-discovery-analyzer` first to profile your setup
   - Use `SGM_route_mix_bus` to organise your session
   - Use `SGM_auto_master` on the master bus for a quick reference master
   - Use `SGM_FieldyBagToggle` on bass tracks
   - Try `SGM_reaper_ultra_hd_smart_tools` for theme generation

---

## Configuration

Key configuration constants are at the top of each script:

| Script | Key Config |
|--------|-----------|
| `SGM_route_mix_bus.lua` | `MIX_BUS_NAME`, `MIX_BUS_COLOR`, `DRY_RUN = false` (set to `true` to preview), `DEBUG` |
| `SGM_auto_master.lua` | `HPF_FREQ = 30`, `COMP_THRESH = -18`, `COMP_RATIO = 2`, `COMP_ATTACK`, `COMP_RELEASE`, `LIMIT_CEIL = -1.0` |
| `SGM_FieldyBagToggle.lua` | No config — uses FX slots 1–3 (Fieldy) and 4–6 (Dimebag) |
| `SGM_reaper_ultra_hd_smart_tools.lua` | `ColorPalette` (theme colours), `ThemeMetadata` (name/version/author) |
| `daw-discovery-analyzer.lua` | No config — run it and choose a report from the menu |

---

## Requirements

- REAPER 7.0+ (Lua 5.4)
- SWS/S&M Extension — optional. It is only needed for the routing detail in the DAW analyzer and for the smart-tool cursor engine.

---

## License

MIT — free for personal and commercial use. See [../LICENSE](../LICENSE).

---

## Support

Open an issue on the [ReaPack repository](https://github.com/sgm-audio/sgm-studios-reapack) or contact **SGM Studios**.
