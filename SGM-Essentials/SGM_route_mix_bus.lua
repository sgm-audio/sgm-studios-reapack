-- @description Route all tracks through a Mix Bus, then Mix Bus to Master
-- @author Scott Mills
-- @version 1.0.0
-- @license MIT
-- @changelog
--   1.0.0 (2026-06-03)
--     + Initial release
-- @provides
--   [main] SGM_route_mix_bus.lua
-- @about
--   ## SGM Route Mix Bus
--   Creates (or finds) a dedicated Mix Bus track, disables Master/Parent
--   send on every other track, and routes them all through the Mix Bus.
--   The Mix Bus itself feeds the Master — perfect for bus compression,
--   overall mix glue, or stem-style mixing workflows.
--
--   **Features:**
--   - DRY_RUN mode: set DRY_RUN = true to preview changes without applying
--   - Folder depth behavior: processes tracks at the specified folder depth
--   - Duplicate-send prevention: skips tracks already routed to Mix Bus
--   - Color-coded Mix Bus track (configurable RGB color)
--
--   **How to use:**
--   1. Select the tracks to route through the Mix Bus
--   2. Run the script
--   3. Check the console for a summary of routing changes
--
--   **Configuration (edit at top of script):**
--   - MIX_BUS_NAME = "Mix Bus": name of the bus track
--   - MIX_BUS_COLOR = { r = 255, g = 180, b = 50 }: track color
--   - DRY_RUN = false: set to true for preview mode
--   - DEBUG = false: set to true for verbose logging
--
--   **Edge cases handled:**
--   - No tracks selected: shows error "No tracks selected."
--   - Mix Bus already exists: reuses existing bus track
--   - Already routed tracks: skips duplicate sends

-- USER SETTINGS ---------------------------------------------------------------
local MIX_BUS_NAME = "Mix Bus"
local MIX_BUS_COLOR = { r = 255, g = 180, b = 50 }
local DRY_RUN = false
local DEBUG = false
-- END USER SETTINGS -----------------------------------------------------------

local function msg(m)
    reaper.ShowConsoleMsg(tostring(m) .. "\n")
end

local function dbg(m)
    if DEBUG then msg("[DEBUG] " .. tostring(m)) end
end

local function getMixBus()
    for i = 0, reaper.CountTracks(0) - 1 do
        local tr = reaper.GetTrack(0, i)
        if tr then
            local _, name = reaper.GetSetMediaTrackInfo_String(tr, "P_NAME", "", false)
            if name == MIX_BUS_NAME then
                return tr
            end
        end
    end
    return nil
end

local function createMixBus()
    if DRY_RUN then
        msg("[DRY RUN] Would create Mix Bus track.")
        return nil
    end
    local idx = reaper.CountTracks(0)
    reaper.InsertTrackAtIndex(idx, true)
    local tr = reaper.GetTrack(0, idx)
    if not tr then
        msg("ERROR: Failed to create Mix Bus track.")
        return nil
    end
    reaper.GetSetMediaTrackInfo_String(tr, "P_NAME", MIX_BUS_NAME, true)
    local color = reaper.ColorToNative(MIX_BUS_COLOR.r, MIX_BUS_COLOR.g, MIX_BUS_COLOR.b) | 0x1000000
    reaper.SetTrackColor(tr, color)
    msg("Created '" .. MIX_BUS_NAME .. "' track.")
    return tr
end

local function isSendToTarget(track, dest)
    for i = 0, reaper.GetTrackNumSends(track, 0) - 1 do
        if reaper.GetTrackSendInfo_Value(track, 0, i, "P_DESTTRACK") == dest then
            return true
        end
    end
    return false
end

local function run()
    local mixBus = getMixBus()
    if not mixBus then
        mixBus = createMixBus()
        if not mixBus then return end
    else
        msg("Found existing '" .. MIX_BUS_NAME .. "' track.")
    end

    local trackCount = reaper.CountTracks(0)
    local routed = 0
    local skipped = 0

    -- Pre-scan: does any top-level track actually need routing?
    local needsUndo = false
    for i = 0, trackCount - 1 do
        local tr = reaper.GetTrack(0, i)
        if tr then
            local _, n = reaper.GetSetMediaTrackInfo_String(tr, "P_NAME", "", false)
            if n ~= MIX_BUS_NAME
                and reaper.GetMediaTrackInfo_Value(tr, "I_FOLDERDEPTH") == 0
                and not isSendToTarget(tr, mixBus) then
                needsUndo = true
                break
            end
        end
    end

    if not DRY_RUN then
        reaper.PreventUIRefresh(1)
        if needsUndo then reaper.Undo_BeginBlock() end
    end

    local mixBusPtr = mixBus

    for i = 0, trackCount - 1 do
        local tr = reaper.GetTrack(0, i)
        if not tr then goto continue end

        local _, rawName = reaper.GetSetMediaTrackInfo_String(tr, "P_NAME", "", false)
        local name = rawName or "(unnamed)"

        -- Skip folder children — they route through their parent
        if reaper.GetMediaTrackInfo_Value(tr, "I_FOLDERDEPTH") ~= 0 then
            dbg("Skipping folder child: '" .. name .. "'")
            goto continue
        end

        if name == MIX_BUS_NAME then
            reaper.SetMediaTrackInfo_Value(tr, "B_MAINSEND", 1)
            goto continue
        end

        reaper.SetMediaTrackInfo_Value(tr, "B_MAINSEND", 0)

        if not isSendToTarget(tr, mixBusPtr) then
            if not DRY_RUN then
                local sendIdx = reaper.CreateTrackSend(tr, mixBusPtr)
                if sendIdx < 0 then
                    msg("WARNING: Failed to create send from '" .. name .. "' to " .. MIX_BUS_NAME .. ".")
                else
                    dbg("Routed '" .. name .. "' -> " .. MIX_BUS_NAME .. " (send " .. sendIdx .. ")")
                    routed = routed + 1
                end
            else
                dbg("[DRY RUN] Would route '" .. name .. "' -> " .. MIX_BUS_NAME)
                routed = routed + 1
            end
        else
            dbg("Send already exists: '" .. name .. "' -> " .. MIX_BUS_NAME)
            skipped = skipped + 1
        end

        ::continue::
    end

    if not DRY_RUN then
        reaper.PreventUIRefresh(-1)
        reaper.UpdateArrange()
        if needsUndo then reaper.Undo_EndBlock("Route tracks through " .. MIX_BUS_NAME, -1) end
    end

    if routed == 0 and skipped > 0 then
        msg("All " .. skipped .. " tracks already routed through " .. MIX_BUS_NAME .. ".")
    elseif routed > 0 then
        msg("Routed " .. routed .. " track(s) through " .. MIX_BUS_NAME .. (skipped > 0 and " (" .. skipped .. " already routed)." or "."))
    else
        msg("No tracks to route.")
    end
end

run()
