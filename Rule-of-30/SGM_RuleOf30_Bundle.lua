-- @description SGM Studios Rule of 30 heavy metal production bundle: 48-track session, plugin presets, and phase alignment
-- @author Scott Mills
-- @version 1.0.1
-- @metapackage
-- @changelog
--   1.0.1 (2026-10-08)
--     + Top Shelf audit: undo/PUIR on all session-builder actions,
--       GetUserInputs menus, localized helpers (session-builder 1.0.1,
--       phase-alignment-tool 1.0.1, plugin-presets 1.0.1)
--   1.0.0 (2026-05-23)
--     + Initial release
-- @provides
--   [main] rule-of-30-session-builder.lua
--   [nomain] rule-of-30-plugin-presets.lua
--   [main] phase-alignment-tool.lua

return "SGM Studios Bundle: Rule of 30 Heavy Metal Production"

-- @about
--   ## Rule of 30 Heavy Metal Production Bundle
--   A complete session building system for professional heavy industrial
--   and metal production in REAPER.
--
--   Includes:
--   - rule-of-30-session-builder.lua: builds the full 48+ track session
--   - rule-of-30-plugin-presets.lua: plugin chain configuration library (dependency)
--   - phase-alignment-tool.lua: sample-accurate DI guitar alignment
--
--   Drop Bb tuning. 95-110 BPM. Designed for dense, high-track-count productions
--   with quad-tracked guitars, double bass, and full orchestral augmentation layers.
