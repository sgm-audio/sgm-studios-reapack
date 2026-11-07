-- @description Toggle between Fieldy (Korn) and Dimebag (Pantera) bass FX chains on the selected track
-- @author Scott Mills
-- @license MIT (c) 2026 Scott Mills / SGM Studios — see LICENSE; kept with the script when redistributed
-- @version 1.0.1
-- @changelog
--   1.0.1 (2026-11-07)
--     + Fix: no longer writes bypass state to FX slots that do not exist
--     + Fix: no undo point is created when nothing was actually toggled
--     + Fix: single selected-track lookup (main() and the toggle shared it)
--   1.0.0 (2026-06-02)
--     + Initial release
-- @provides [main] SGM_FieldyBagToggle.lua
-- @about
--   ## Fieldy-Bag Toggle
--   Toggles between two bass guitar FX chains: Fieldy (slap/rock) and
--   Dimebag (metal). Requires the correct plugin ordering on the
--   selected bass track.
--
--   **FX slot layout:**
--   - Slots 1-3: Fieldy chain (Korn-style slap/rock bass)
--   - Slots 4-6: Dimebag chain (Pantera-style metal bass)
--
--   **How it works:**
--   - Running the script checks the state of slot 1
--   - If Fieldy is active (slots 1-3 enabled, 4-6 bypassed), switches to
--     Dimebag (slots 4-6 enabled, 1-3 bypassed)
--   - Run again to toggle back to Fieldy
--   - Console shows which chain is now active
--
--   **How to use:**
--   1. Select a bass track with FX in slots 1-6
--   2. Run the script
--   3. Check the console for the active chain name
--
--   **Edge cases handled:**
--   - No track selected: message box + console note, no crash
--   - Track has no FX: console message "No FX found on selected track.", no crash
--   - Track has fewer than 6 FX: only the slots that exist are toggled

-- ==========================================
-- REAPER SCRIPT: Fieldy-Bag Toggle (2026)
-- ==========================================

local KORN_SLOTS_START, KORN_SLOTS_END = 0, 2      -- Fieldy chain (0-based FX indices)
local DIMEBAG_SLOTS_START, DIMEBAG_SLOTS_END = 3, 5 -- Dimebag chain

local function msg(m)
    reaper.ShowConsoleMsg(tostring(m) .. "\n")
end

local function set_range_enabled(track, first, last, enabled)
    local count = reaper.TrackFX_GetCount(track)
    local changed = false
    for i = first, last do
        if i < count then
            if reaper.TrackFX_GetEnabled(track, i) ~= enabled then
                reaper.TrackFX_SetEnabled(track, i, enabled)
                changed = true
            end
        end
    end
    return changed
end

-- Returns true when at least one FX state actually changed.
local function toggle_bass_chains(track)
    -- Slot 1 decides which chain is currently active
    local is_korn_active = reaper.TrackFX_GetEnabled(track, KORN_SLOTS_START)

    local changed
    if is_korn_active then
        msg("ACTIVATE: DIMEBAG SQUEAL MODE")
        changed = set_range_enabled(track, KORN_SLOTS_START, KORN_SLOTS_END, false)
        changed = set_range_enabled(track, DIMEBAG_SLOTS_START, DIMEBAG_SLOTS_END, true) or changed
    else
        msg("ACTIVATE: KORN SLAP MODE")
        changed = set_range_enabled(track, KORN_SLOTS_START, KORN_SLOTS_END, true)
        changed = set_range_enabled(track, DIMEBAG_SLOTS_START, DIMEBAG_SLOTS_END, false) or changed
    end

    if not changed then
        msg("FX chain already in the requested state.")
    end
    return changed
end

local function main()
    local track = reaper.GetSelectedTrack(0, 0)
    if not track then
        reaper.MB("Select your bass track first.", "Fieldy-Bag Toggle", 0)
        msg("ERROR: No track selected. Select the bass track that holds both FX chains.")
        return
    end

    if reaper.TrackFX_GetCount(track) == 0 then
        msg("No FX found on selected track.")
        return
    end

    -- Nothing to toggle (single chain present) -> no undo point, no busywork.
    if reaper.TrackFX_GetCount(track) < DIMEBAG_SLOTS_START + 1 then
        msg("Only one FX chain present on this track — nothing to toggle.")
        return
    end

    reaper.PreventUIRefresh(1)
    reaper.Undo_BeginBlock()
    toggle_bass_chains(track)
    reaper.Undo_EndBlock("Toggle Bass Chain", -1)
    reaper.PreventUIRefresh(-1)
    reaper.UpdateArrange()
end

main()
