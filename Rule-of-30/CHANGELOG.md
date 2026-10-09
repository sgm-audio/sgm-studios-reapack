# Rule of 30 — Changelog

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
