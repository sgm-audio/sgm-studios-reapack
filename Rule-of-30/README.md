# Rule of 30 for REAPER

**A heavy metal production system — 48-track session builder, plugin chain reference, and DI phase alignment.**

Three scripts for heavy industrial / metal production: Drop Bb tuning, 95–110 BPM,
quad-tracked guitars, split bass, and augmentation layers.

---

## Included Scripts

| Script | Type | What It Does |
|--------|------|-------------|
| **rule-of-30-session-builder.lua** | [main] | Builds the session skeleton: 12-track drum section, 3-band bass split, quad guitars, vocal layers, glitch/atmosphere and send-FX buses, project tempo/timebase. Optionally plugin-aware (reads `plugin_inventory.json`) and can skip tracks whose plugin category is missing (Compact Mode). |
| **rule-of-30-plugin-presets.lua** | [nomain] | Plugin chain **reference library** — Waves, iZotope, FabFilter, Neural DSP and Soundtoys chains mapped per instrument. It is shipped so you can read/copy the chains; the session builder does **not** load it at runtime. |
| **phase-alignment-tool.lua** | [main] | Auto-aligns quad-tracked DI guitars by transient analysis before amp processing, plus phase-correlation checks and fine ±1 ms / ±0.1 ms nudge controls. |
| **SGM_RuleOf30_Bundle.lua** | [nomain] / metapackage | ReaPack metapackage — installing this pulls in all scripts above. |

---

## Quick Start

1. **Install** via ReaPack (recommended) or manually (see [INSTALL.md](INSTALL.md))
2. Run `rule-of-30-session-builder` → enter **1** (Build Session)
3. Add processing chains: options **2–6** (drums, bass, guitars, vocals, kick/bass sidechain)
4. Record your quad-tracked DI guitars, then run `phase-alignment-tool` → **1** (Auto-Align)

### About the plugin inventory (optional)

The builder can pick "best" plugins per category if a file called
`plugin_inventory.json` sits **next to the script** or in the REAPER resource folder:

```json
{
  "by_category": {
    "EQ":       ["ReaEQ", "Pro-Q 3"],
    "Dynamics": ["ReaComp", "CLA-76"]
  }
}
```

* With **Compact Mode ON** (default) and no inventory file, tracks whose category has
  no match are skipped — you get a partial skeleton.
* With **Compact Mode OFF** (menu option `0`) the full skeleton is always built, using
  the stock-FX chain pass.

---

## The Session Layout

The builder creates roughly 48 tracks across 7 sections:

- **Drums (12)**: Kick In / Out / Sub, Snare Top / Bottom / Sample / Glitch, OH L/R,
  Hi-Hat, Ride, Room Mono, Tom Rack, Tom Floor
- **Bass (3-band split)**: DI (lows), Amp (mids), Fuzz (highs), Synth layer (sub)
- **Guitars**: quad-tracked rhythm (L1/R1/L2/R2), octave leads, The Scrape, Clean Ambient
- **Vocals**: lead, double, demon layer, telephonic, whispers, screams, ad-libs
- **FX / Glitch**: white-noise risers, impact booms, digital artifacts
- **Ambient / Synth**: dark pad, arpeggiator, reverse piano
- **Send FX**: hall, plate, 1/4 delay, 1/8 dotted delay, parallel drum crush

---

## Configuration

Key configuration constants are at the top of each script:

| Script | Key Config |
|--------|-----------|
| `rule-of-30-session-builder.lua` | `CONFIG.bpm = 100` (95–110 range), `CONFIG.sample_rate`, `CONFIG.colors`, `CONFIG.compact_mode = true` |
| `phase-alignment-tool.lua` | `CONFIG.transient_threshold = 0.3`, `CONFIG.analysis_window = 0.1`, `CONFIG.alignment_precision = 0.0001` |
| `rule-of-30-plugin-presets.lua` | Edit the chain tables to match your plugin collection |

---

## License

MIT — free for personal and commercial use. See [../LICENSE](../LICENSE).

---

## Support

Open an issue on the [ReaPack repository](https://github.com/sgm-audio/sgm-studios-reapack) or contact **SGM Studios**.
