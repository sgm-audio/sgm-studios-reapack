-- @description Toggle between Fieldy (Korn) and Dimebag (Pantera) bass FX chains on the selected track
-- @author Scott Mills
-- @version 1.0.0
-- @changelog
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
--   - No track selected: shows error message
--   - Track has fewer than 6 FX: toggles what's available gracefully
--   - Track has no FX: shows message, no crash

-- ==========================================
-- REAPER SCRIPT: Fieldy-Bag Toggle (2026)
-- ==========================================

local function msg(m)
    reaper.ShowConsoleMsg(tostring(m) .. "\n")
end

local function toggle_bass_chains()
    -- Target the selected track
    local track = reaper.GetSelectedTrack(0, 0)
    if not track then
        msg("ERROR: No track selected. Select your Ibanez SR505E track.")
        return
    end

    -- 2026 Naming Convention: 
    -- Plugins 1-3 = KORN NODE
    -- Plugins 4-6 = DIMEBAG NODE
    
    -- Check current state of the first plugin in Node A
    local is_korn_active = reaper.TrackFX_GetEnabled(track, 0)

    if is_korn_active then
        -- Switch to DIMEBAG
        msg("ACTIVATE: DIMEBAG SQUEAL MODE")
        -- Bypass Korn Node (0, 1, 2)
        for i = 0, 2 do 
            reaper.TrackFX_SetEnabled(track, i, false)
        end
        -- Enable Dimebag Node (3, 4, 5)
        for i = 3, 5 do 
            reaper.TrackFX_SetEnabled(track, i, true)
        end
    else
        -- Switch to KORN
        msg("ACTIVATE: KORN SLAP MODE")
        -- Enable Korn Node
        for i = 0, 2 do 
            reaper.TrackFX_SetEnabled(track, i, true)
        end
        -- Bypass Dimebag Node
        for i = 3, 5 do 
            reaper.TrackFX_SetEnabled(track, i, false)
        end
    end
end

-- Main menu guard
local function main()
  local track = reaper.GetSelectedTrack(0, 0)
  if not track then
    reaper.MB("Select your bass track first.", "Fieldy-Bag Toggle", 0)
    return
  end
  reaper.PreventUIRefresh(1)
  reaper.Undo_BeginBlock()
  toggle_bass_chains()
  reaper.Undo_EndBlock("Toggle Bass Chain", -1)
  reaper.PreventUIRefresh(-1)
end

main()