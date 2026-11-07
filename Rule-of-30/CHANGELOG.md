# Rule of 30 — Changelog

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
