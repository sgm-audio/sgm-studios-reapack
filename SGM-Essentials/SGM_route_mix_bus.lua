-- @description Route all tracks through a Mix Bus, then Mix Bus to Master
-- @author Scott Mills
-- @version 1.0.1
-- @license MIT
-- @changelog
--   1.0.1 (2026-11-07)
--     + Fix: selection is now honoured (previously the "select the tracks to route"
--       workflow silently routed *every* top-level track)
--     + Fix: nested tracks inside folders are no longer skipped (only folder parents
--       are skipped, because their children feed them)
--     + Fix: a track literally named "Mix Bus" is no longer mistaken for the bus when
--       an existing bus was reused
--     + Fix: with nothing to do, no undo point or UI refresh is left dangling
--     + Add: console message when no tracks are selected
--   1.0.0 (2026-06-03)
--     + Initial release
-- @provides
--   [main] SGM_route_mix_bus.lua
-- @about
--   ## SGM Route Mix Bus
--   Creates (or finds) a dedicated Mix Bus track, disables Master/Parent
--   send on the routed tracks, and routes them all through the Mix Bus.
--   The Mix Bus itself feeds the Master — perfect for bus compression,
--   overall mix glue, or stem-style mixing workflows.
--
--   **Features:**
--   - DRY_RUN mode: set DRY_RUN = true to preview changes without applying
--   - Selection aware: with tracks selected, only those are routed; with
--     nothing selected, every top-level track is routed
--   - Folder aware: folder parents are left alone (children already feed them)
--   - Duplicate-send prevention: skips tracks already routed to Mix Bus
--   - Color-coded Mix Bus track (configurable RGB color)
--
--   **How to use:**
--   1. Select the tracks to route through the Mix Bus (or select nothing for "all")
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
--   - No tracks at all: shows "No tracks to route."
--   - Mix Bus already exists: reuses existing bus track
--   - Already routed tracks: skips duplicate sends
--   - Selected track *is* the Mix Bus: ignored

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

local function trackName(tr)
    local _, name = reaper.GetSetMediaTrackInfo_String(tr, "P_NAME", "", false)
    return name or ""
end

-- Index of the mix bus in the track list, or nil when it does not exist yet.
local function findMixBus()
    for i = 0, reaper.CountTracks(0) - 1 do
        local tr = reaper.GetTrack(0, i)
        if tr and trackName(tr) == MIX_BUS_NAME then
            return tr, i
        end
    end
    return nil, nil
end

local function createMixBus()
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

-- Builds the list of tracks to route.
-- Mix bus itself is always excluded; folder parents are excluded because
-- their children already feed them through the parent send.
local function collectTargets(mixBus, mixBusIdx)
    local targets = {}
    local selected = reaper.CountSelectedTracks(0)

    local function consider(tr, idx)
        if tr == mixBus or idx == mixBusIdx then return end
        -- Folder parent? Children route into it, so routing it again is redundant.
        if reaper.GetMediaTrackInfo_Value(tr, "I_FOLDERDEPTH") == 1 then
            dbg("Skipping folder parent: '" .. trackName(tr) .. "'")
            return
        end
        targets[#targets + 1] = tr
    end

    if selected > 0 then
        for i = 0, selected - 1 do
            local tr = reaper.GetSelectedTrack(0, i)
            if tr then consider(tr, -1) end
        end
    else
        for i = 0, reaper.CountTracks(0) - 1 do
            consider(reaper.GetTrack(0, i), i)
        end
    end

    return targets
end

local function run()
    if reaper.CountTracks(0) == 0 then
        msg("No tracks to route.")
        return
    end

    local mixBus, mixBusIdx = findMixBus()
    local created = false

    if mixBus then
        msg("Found existing '" .. MIX_BUS_NAME .. "' track.")
    elseif DRY_RUN then
        msg("[DRY RUN] Would create '" .. MIX_BUS_NAME .. "' track.")
        -- Nothing else can be previewed meaningfully without the bus.
        msg("[DRY RUN] No project changes made.")
        return
    else
        mixBus = createMixBus()
        if not mixBus then return end
        mixBusIdx = reaper.CountTracks(0) - 1
        created = true
        msg("Created '" .. MIX_BUS_NAME .. "' track.")
    end

    local targets = collectTargets(mixBus, mixBusIdx)
    if #targets == 0 then
        msg("No tracks to route.")
        return
    end

    -- Pre-scan: does anything actually need changing?
    local needsUndo = created
    for _, tr in ipairs(targets) do
        if reaper.GetMediaTrackInfo_Value(tr, "B_MAINSEND") == 1
            or not isSendToTarget(tr, mixBus) then
            needsUndo = true
            break
        end
    end

    if not DRY_RUN then
        reaper.PreventUIRefresh(1)
        if needsUndo then reaper.Undo_BeginBlock() end
    end

    local routed, skipped = 0, 0
    for _, tr in ipairs(targets) do
        local name = trackName(tr)
        if name == "" then name = "(unnamed)" end

        local alreadyRouted = isSendToTarget(tr, mixBus)
        if not DRY_RUN then
            reaper.SetMediaTrackInfo_Value(tr, "B_MAINSEND", 0)
        end

        if alreadyRouted then
            dbg("Send already exists: '" .. name .. "' -> " .. MIX_BUS_NAME)
            skipped = skipped + 1
        elseif DRY_RUN then
            msg("[DRY RUN] Would route '" .. name .. "' -> " .. MIX_BUS_NAME)
            routed = routed + 1
        else
            local sendIdx = reaper.CreateTrackSend(tr, mixBus)
            if sendIdx < 0 then
                msg("WARNING: Failed to create send from '" .. name .. "' to " .. MIX_BUS_NAME .. ".")
            else
                dbg("Routed '" .. name .. "' -> " .. MIX_BUS_NAME .. " (send " .. sendIdx .. ")")
                routed = routed + 1
            end
        end
    end

    -- The Mix Bus must always keep its master/parent send enabled.
    if not DRY_RUN then
        reaper.SetMediaTrackInfo_Value(mixBus, "B_MAINSEND", 1)
        reaper.PreventUIRefresh(-1)
        reaper.UpdateArrange()
        if needsUndo then
            reaper.Undo_EndBlock("Route tracks through " .. MIX_BUS_NAME, -1)
        end
    end

    if routed == 0 and skipped > 0 then
        msg("All " .. skipped .. " track(s) already routed through " .. MIX_BUS_NAME .. ".")
    elseif routed > 0 then
        msg("Routed " .. routed .. " track(s) through " .. MIX_BUS_NAME
            .. (skipped > 0 and " (" .. skipped .. " already routed)." or "."))
    else
        msg("No tracks to route.")
    end
    if DRY_RUN then msg("[DRY RUN] No project changes made.") end
end

run()
