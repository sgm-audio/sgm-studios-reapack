# SGM Studios — REAPER Scripts

Free REAPER ReaScripts by **Scott Mills / SGM Studios**, distributed via [ReaPack](https://reapack.com).

## Installation

1. In REAPER: **Extensions** → **ReaPack** → **Import repositories…**
2. Paste this URL:

   ```
   https://raw.githubusercontent.com/sgm-audio/sgm-studios-reapack/main/index.xml
   ```

3. **Extensions** → **ReaPack** → **Browse packages…** → install **SGM Studios Essentials** and/or **SGM Rule of 30** → click **Apply**

## Bundles

| Bundle | Scripts | What it does |
|---|---|---|
| **SGM-Essentials** | 5 actions + shared library | Mix bus routing, one-click mastering, bass FX chain toggle, 4K theme generator + smart tools, DAW environment profiler |
| **Rule-of-30** | 2 actions + preset library | 48-track heavy metal session builder (Drop Bb, quad guitars), plugin chain reference, quad-DI phase alignment |

## Repository layout

```
index.xml                     ReaPack package index (generated, do not hand-edit)
SGM-Essentials/               Bundle sources + README / INSTALL / CHANGELOG / TEST_CASES
Rule-of-30/                   Bundle sources + README / INSTALL / CHANGELOG / TEST_CASES
.github/workflows/ci.yml      Lua 5.4 syntax check + index.xml validation
.reapack-index.conf           reapack-index settings (name, about, amend)
```

Package versions live in each script's `@version` header; `index.xml` must be
regenerated (`reapack-index`) after bumping one. CI fails if the two disagree.

## Requirements

- REAPER 7.0+ (Lua 5.4)
- SWS/S&M Extension — optional (routing detail in the DAW analyzer and the smart-tool cursor engine)
- All scripts use REAPER stock FX by default — no paid plugins required

## Also from SGM Studios (paid)

- **Suno AI Workflow Suite** ($24) — six-script pipeline for importing and producing Suno AI tracks in REAPER
- **Hip-Hop/EDM Session Builder** ($12) — 23-track West Coast hip-hop × progressive house session

Available on Gumroad.

## License

MIT — see [LICENSE](LICENSE). Free for personal and commercial use.
