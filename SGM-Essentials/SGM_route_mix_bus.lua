-- @description Route all tracks through a Mix Bus, then Mix Bus to Master
-- @author Scott Mills
-- @version 1.1.1
-- @license MIT (c) 2026 Scott Mills / SGM Studios — see LICENSE; kept with the script when redistributed
-- @changelog
--   1.1.1 (2026-11-12)
--     + Fix: the no-selection fallback routes top-level tracks, preserving folder
--       processing. Routing folder children directly to the bus bypassed their
--       folder parents' FX, and selected folder parents are now valid targets.
--   1.1.0 (2026-11-07)
--     + Add: uses the shared SGM_Utils library when it is installed (message
--       output, native track colours) and falls back to local helpers when it
--       is not, so this still runs as a standalone file.
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
--   - Folder aware: when nothing is selected, top-level tracks (including folder
--     parents) are routed so their nested tracks still pass through folder FX
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

-- SGM_Utils (SGM-Essentials bundle) is optional: it is the shared home for
-- message output and REAPER colour conversion.
local function bootstrapUtils()
    local own_dir = ""
    local ok_ctx, _, script_filename = pcall(reaper.get_action_context)
    if ok_ctx and type(script_filename) == "string" then
        own_dir = script_filename:match("^(.*[/\\])") or ""
    end
    local resource = reaper.GetResourcePath()
    local candidates = {
        own_dir .. "SGM_Utils.lua",
        resource .. "/Scripts/SGM Studios/SGM-Essentials/SGM_Utils.lua",
        resource .. "/Scripts/SGM_Scripts/SGM-Essentials/SGM_Utils.lua",
        "SGM_Utils.lua",
        "../SGM-Essentials/SGM_Utils.lua",
    }
    for _, path in ipairs(candidates) do
        local chunk = loadfile(path)
        if chunk then
            local ok, lib = pcall(chunk)
            if ok and type(lib) == "table" then
                if lib.load then
                    local found = lib.load(own_dir)
                    if found then return found end
                end
                return lib
            end
        end
    end
    return nil
end

local Utils = bootstrapUtils()

local function msg(m)
    if Utils and Utils.msg then return Utils.msg(m) end
    reaper.ShowConsoleMsg(tostring(m) .. "\n")
end

-- Utils.native_color takes a packed 0xRRGGBB integer; MIX_BUS_COLOR is a
-- {r, g, b} table, so pack it here rather than changing the setting's shape.
local function native_color(rgb)
    local packed = rgb
    if type(rgb) == "table" then
        packed = (rgb.r << 16) | (rgb.g << 8) | rgb.b
    end
    if Utils and Utils.native_color then return Utils.native_color(packed) end
    return reaper.ColorToNative(rgb.r, rgb.g, rgb.b) | 0x1000000
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
    reaper.SetTrackColor(tr, native_color(MIX_BUS_COLOR))
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

-- Builds the list of tracks to route. Explicit selection means route exactly
-- those tracks (including a selected folder parent). With no selection, route
-- top-level tracks only: routing folder children directly would bypass the
-- folder parent's FX and defeat the folder's normal signal path.
local function collectTargets(mixBus, mixBusIdx)
    local targets = {}
    local selected = reaper.CountSelectedTracks(0)

    local function add(tr, idx)
        if tr and tr ~= mixBus and idx ~= mixBusIdx then
            targets[#targets + 1] = tr
        end
    end

    if selected > 0 then
        for i = 0, selected - 1 do
            add(reaper.GetSelectedTrack(0, i), -1)
        end
    else
        for i = 0, reaper.CountTracks(0) - 1 do
            local tr = reaper.GetTrack(0, i)
            if tr and reaper.GetTrackDepth(tr) == 0 then
                add(tr, i)
            end
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
