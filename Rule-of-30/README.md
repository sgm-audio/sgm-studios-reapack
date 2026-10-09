# Rule of 30 for REAPER

**A heavy metal production system — 48-track session builder, plugin chain presets, and DI phase alignment.**

Three scripts for professional heavy industrial / metal production: Drop Bb tuning, 95–110 BPM, quad-tracked guitars, double bass, and full orchestral augmentation layers.

---

## Included Scripts

| Script | Type | What It Does |
|--------|------|-------------|
| **rule-of-30-session-builder.lua** | [main] | Builds the full 48+ track session: 12-track drum section, 3-band bass split, quad guitars, vocals, FX/glitch and ambient layers, buses with parallel compression sends. Plugin-aware — scans your installed plugin inventory and skips missing chains in Compact Mode. |
| **rule-of-30-plugin-presets.lua** | [@noindex] | Plugin chain configuration library — Waves, iZotope, FabFilter, Neural DSP, and Soundtoys chains mapped per instrument. Loaded by the session builder. |
| **phase-alignment-tool.lua** | [main] | Auto-aligns quad-tracked DI guitars by transient analysis before amp processing. Sample-accurate nudging with fine 0.1 ms controls. |
| **SGM_RuleOf30_Bundle.lua** | [@metapackage] | ReaPack metapackage — installing this pulls all scripts above. |

---

## Quick Start

1. **Install** via ReaPack (recommended) or manually (see INSTALL.md)
2. Run `rule-of-30-session-builder` → enter **1** (Build Session)
3. Add processing chains: options **2–6** (drums, bass, guitars, vocals, kick/bass sidechain)
4. Record your quad-tracked DI guitars, then run `phase-alignment-tool` → **1** (Auto-Align)

---

## The Session Layout

48+ tracks across 7 sections:

- **Drums (12)**: Kick In / Out / Sub, Snare Top / Bottom, Glitch Snare, Toms, Overheads, Room Mono
- **Bass (3-band split)**: DI, Amp, Fuzz, Synth
- **Guitars**: Quad-tracked rhythm (L1/R1/L2/R2), Octave Lead, The Scrape, Clean Ambient
- **Vocals**: Lead, Demon Layer, Telephonic, Whisper
- **FX / Glitch** and **Ambient / Orchestral** augmentation layers
- **Buses**: parallel compression sends per section

---

## Configuration

Key configuration constants are at the top of each script:

| Script | Key Config |
|--------|-----------|
| `rule-of-30-session-builder.lua` | `CONFIG.bpm = 100` (95–110 range), `CONFIG.compact_mode = true` (skip tracks with no plugins) |
| `phase-alignment-tool.lua` | `CONFIG.transient_threshold = 0.3`, `CONFIG.analysis_window = 0.1` |
| `rule-of-30-plugin-presets.lua` | Edit the chain tables to match your plugin collection |

---

## License

MIT — free for personal and commercial use. See individual script headers.

---

## Support

Open an issue on the [ReaPack repository](https://github.com/sgm-audio/sgm-studios-reapack) or contact **SGM Studios**.
