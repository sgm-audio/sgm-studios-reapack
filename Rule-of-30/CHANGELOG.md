# Rule of 30 — Changelog

## 1.1.0 (2026-11-07) — the actionable system

Documentation release. No script behaviour changed, so no script versions moved
and `index.xml` is unchanged.

- **New: `MIXING-GUIDE.md`** — the twelve-stage procedure (source selection →
  session prep → restoration → corrective EQ → de-masking → dynamics → sidechain
  → depth/width → saturation → reverb → bus → master/delivery), a translation QA
  gate, a plug-in → job map covering iZotope RX/Ozone, Waves Ultimate,
  Kilohearts Ultimate and REAPER stock, and thirty operating rules.
- **New: `TECHNIQUES.md`** — comping, layering, frequency masking, sidechaining
  (with the exact REAPER 4-channel routing), depth vs. width, groove, stereo,
  saturation, automation, and a failure-mode table.
- **New: `SUNO-AI-SOURCE-FIXES.md`** — sixteen signature problems of AI-generated
  audio, each with cause, an evidence grade (measured / reported / claimed /
  mechanism), and the fix. Includes what mastering cannot fix, and an honest
  assessment of the r/SunoAI resources.
- **New: `PROMPTS.md`** — what Suno's four fields actually control, the real
  limits, and reviews of two real prompts with rewrites.
- **Corrected a widely repeated claim**: offsetting a duplicate recording by a
  few milliseconds does not create depth. It is the Haas/precedence effect, it
  produces width, and it comb-filters the source (delay *d* ms → first null at
  `1000/(2d)` Hz, then nulls every `1000/d` Hz). The guide documents the
  mono-safe alternatives instead, and the four cues that do read as depth.
- **Explained why the "10-minute" prompt cannot work**: 8 minutes is the
  per-generation ceiling; length beyond that comes from Extend, with the full
  style prompt re-pasted into each extension to limit drift.

## 1.0.2 (2026-11-07)

Bug-fix and documentation pass after auditing every script against the ReaScript API.

- **rule-of-30-session-builder 1.0.2**
  - Fixed (crash): the plugin-aware builder called the local `addFX()` before it was
    declared, so *Build Session* with Compact Mode **off** failed with
    `attempt to call a nil value (global 'addFX')`.
  - Fixed (crash): `CreateTrackSend()` can return `-1`; the send volume/channel
    setters then errored on a nil send. Send creation is now guarded.
  - Fixed: the sidechain helper reuses an existing Kick Out → Bass send instead of
    stacking a new one on every run.
  - Fixed: `I_DSTCHAN` used `2 + 1024`, which sets the "mix to mono" bit; the
    sidechain now targets channel index 2 (i.e. 3/4) without the mono flag.
  - Fixed: an existing tempo marker is updated instead of inserting a new marker at
    the edit cursor on every build.
  - Fixed: `plugin_inventory.json` is looked for next to the script (it was
    hard-coded to the REAPER resource root).
  - Fixed: the master track keeps its master/parent send enabled.
  - Fixed: menu option **7 (Close)** now reports that nothing changed instead of
    falling through silently.
  - Replaced the inline JSON parser with one that handles escapes and returns only
    the parsed value; added a console note explaining the expected format.
  - Removed dead code (unused parser copy, unused `createSend` arguments, unused
    locals).
- **phase-alignment-tool 1.0.2**
  - Fixed: early exits (`< 2` tracks selected, no transients found) left
    `PreventUIRefresh` disabled and an undo block open. Validation now happens
    before anything is opened.
  - Fixed: transient detection read an interleaved multi-channel buffer as if it
    were mono, so stereo DI takes were analysed from mixed-up samples. It now walks
    frame by frame on channel 1.
  - Fixed: hard-coded 48 kHz in the console reports (now the project sample rate).
  - Fixed: the reported peak stopped accumulating once a transient was found.
  - Clarified: `alignment_precision` is 0.1 ms, not "one sample".
- **plugin-presets 1.0.1** — unchanged in this release (helper functions localized).
- **Packaging**: `index.xml` regenerated; bundle entries now ship the metapackage
  file itself and versions match the script headers.

## 1.0.1 (2026-10-08)
- **session-builder**: undo + PreventUIRefresh wrapping on all six actions (Top Shelf audit)
- **session-builder**: menu converted from `gfx.showmenu` to a guarded `GetUserInputs` dialog
- **phase-alignment-tool**: menu converted from `gfx.showmenu` to a guarded `GetUserInputs` dialog
- **plugin-presets**: helper functions localized (no global leaks)

## 1.0.0 (2026-05-23)
- **Initial release**:
  - `rule-of-30-session-builder.lua` — 48+ track heavy metal session template
  - `rule-of-30-plugin-presets.lua` — plugin chain configuration library
  - `phase-alignment-tool.lua` — quad-track DI phase alignment
  - `SGM_RuleOf30_Bundle.lua` — ReaPack metapackage
