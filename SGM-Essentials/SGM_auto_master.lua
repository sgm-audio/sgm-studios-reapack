-- @description Auto-mastering chain using REAPER stock plugins: EQ, compression, saturation, and limiting
-- @author Scott Mills
-- @version 1.1.0
-- @changelog
--   1.1.0 (2026-11-07)
--     + Fix: compressor / limiter values were written in engineering units
--       (-18 dB, 10 ms) into TrackFX_SetParam, which takes a 0..1 normalized
--       value, so the attack landed nowhere near 10 ms. Values now go through
--       Utils.fx_normalize(), which reads the plug-in's own formatting back and
--       is skipped (with a message) if the plug-in cannot be mapped.
--     + Fix: TrackFX_SetEQParam takes 7 arguments; `isnorm` was omitted, so the
--       high-pass frequency was passed as if it were normalized.
--     + Add: uses the shared SGM_Utils library when it is installed (message
--       output, dB helpers, parameter mapping) and falls back to local helpers
--       when it is not, so this still runs as a standalone file.
--   1.0.1 (2026-11-07)
--     + Fix: stock limiter is "ReaLimit", not "ReaLimiter" (limiter was never inserted)
--     + Fix: ReaEQ high-pass now uses the documented TrackFX_SetEQParam API instead of
--       writing raw normalized values into the wrong parameter indices
--     + Fix: ReaComp/ReaLimit parameters are located by name instead of hard-coded indices
--     + Add: the HPF_FREQ / COMP_* / LIMIT_CEIL constants that the docs always promised
--   1.0.0 (2026-06-02)
--     + Initial release
-- @provides
--   [main] SGM_auto_master.lua
-- @about
--   ## REAPER Auto Mastering Tool
--   Applies a professional mastering chain to the master bus using
--   built-in REAPER plugins (ReaEQ, ReaComp, ReaLimit).
--
--   **Chain order:**
--   1. ReaEQ (High-Pass Filter at 30 Hz) — removes subsonic rumble
--   2. ReaComp — bus compression with configurable threshold
--   3. ReaLimit — peak ceiling at -1.0 dBTP
--
--   **How to use:**
--   1. Run the script
--   2. If the master track has existing FX, a confirmation dialog appears
--   3. Click "Yes" to clear and reapply the mastering chain
--   4. Chain is applied in order: HPF → Compressor → Limiter
--
--   **Configuration (edit at top of script):**
--   - HPF_FREQ = 30: high-pass filter frequency (Hz)
--   - COMP_THRESH = -18: compressor threshold (dB)
--   - COMP_RATIO = 2:1: compressor ratio
--   - LIMIT_CEIL = -1.0: limiter ceiling (dBTP)
--
--   **Edge cases handled:**
--   - Existing FX: prompts before clearing (answer No/Cancel = no changes, no undo point)
--   - Existing FX + "Yes": the old chain is replaced, not stacked
--   - A stock plug-in that is missing/unavailable is reported in the console
--     instead of aborting the whole chain

-- USER SETTINGS ---------------------------------------------------------------
local HPF_FREQ   = 30      -- high-pass filter frequency (Hz)
local COMP_THRESH = -18    -- compressor threshold (dB)
local COMP_RATIO = 2       -- compressor ratio (x:1)
local COMP_ATTACK = 10     -- compressor attack (ms)
local COMP_RELEASE = 100   -- compressor release (ms)
local LIMIT_CEIL = -1.0    -- limiter ceiling (dBTP)
-- END USER SETTINGS -----------------------------------------------------------

-- SGM_Utils (SGM-Essentials bundle) is optional: it shares message output and
-- dB helpers between the bundles. Everything below works without it.
local function bootstrapUtils()
    local resource = reaper.GetResourcePath()
    -- Where this script lives: needed to find a sibling copy of the library,
    -- which is how it is laid out in the repository and in a manual install.
    local own_dir = ""
    local ok_ctx, _, script_filename = pcall(reaper.get_action_context)
    if ok_ctx and type(script_filename) == "string" then
        own_dir = script_filename:match("^(.*[/\\])") or ""
    end
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
                    local found = lib.load()
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

local function db_to_linear(db)
    if Utils and Utils.db_to_linear then return Utils.db_to_linear(db) end
    return 10 ^ (db / 20)
end

-- Convert an engineering value to the 0..1 position TrackFX_SetParam expects.
-- Without SGM_Utils there is no safe mapping, so the caller reports the skip
-- rather than writing a guess into the parameter.
local function normalize_param(track, fx, idx, engineering)
    if Utils and Utils.fx_normalize then
        return Utils.fx_normalize(track, fx, idx, engineering)
    end
    return nil
end

-- Find a plug-in parameter index by (case-insensitive) name fragment.
-- Returns nil when the plug-in has no parameter matching the fragment.
local function find_param(track, fx, fragment)
    local target = fragment:lower()
    for i = 0, reaper.TrackFX_GetNumParams(track, fx) - 1 do
        local _, name = reaper.TrackFX_GetParamName(track, fx, i, "")
        if name and name:lower():find(target, 1, true) then
            return i
        end
    end
    return nil
end

-- Set a parameter from an engineering value ("10 ms", "-18 dB").
-- TrackFX_SetParam takes 0..1, so the value is converted against the plug-in's
-- own formatting; if that is not possible the setting is skipped and reported.
local function set_param_real(track, fx, fragment, value)
    local idx = find_param(track, fx, fragment)
    if not idx then
        msg("  ! Could not find a '" .. fragment .. "' parameter")
        return false
    end
    local normalized = normalize_param(track, fx, idx, value)
    if normalized then
        reaper.TrackFX_SetParam(track, fx, idx, normalized)
        return true
    end
    msg(string.format("  ! Could not map %s = %s to a normalized value (skipped)",
        fragment, tostring(value)))
    return false
end

local function apply_mastering_chain()
    local master_track = reaper.GetMasterTrack(0)
    if not master_track then
        msg("ERROR: Could not get master track")
        return
    end

    -- Confirm before clearing existing FX
    local fx_count = reaper.TrackFX_GetCount(master_track)
    if fx_count > 0 then
        local choice = reaper.MB(
            "Master track has " .. fx_count .. " existing FX. Clear them and apply mastering chain?",
            "Auto Master", 4)
        if choice ~= 6 then
            msg("Cancelled — no changes made.")
            return
        end
    end

    msg("Applying mastering chain...")

    reaper.PreventUIRefresh(1)
    reaper.Undo_BeginBlock()

    -- Clear existing FX (highest index first so indices stay valid)
    for i = fx_count - 1, 0, -1 do
        reaper.TrackFX_Delete(master_track, i)
    end

    -- 1. High-pass filter to clean sub-rumble.
    -- TrackFX_AddByName(..., instantiate = -1) always creates a new instance.
    local hp_idx = reaper.TrackFX_AddByName(master_track, "ReaEQ", false, -1)
    if hp_idx >= 0 then
        -- ReaEQ band parameters must be set through the dedicated EQ API;
        -- the raw parameter list is not laid out as band/type/freq/Q.
        local ok = reaper.TrackFX_SetEQParam(
            master_track, hp_idx,
            0,   -- bandtype 0 = high-pass
            0,   -- bandidx: first high-pass band
            0,   -- paramtype 0 = frequency
            HPF_FREQ,
            false) -- isnorm = false -> value is in Hz (7 args: isnorm must be passed)
        reaper.TrackFX_SetEQBandEnabled(master_track, hp_idx, 0, 0, true)
        if ok then
            msg(string.format("  ✓ High Pass Filter (%.0f Hz) added", HPF_FREQ))
        else
            msg("  ! ReaEQ added but the high-pass band could not be configured")
        end
    else
        msg("  ! ReaEQ not available — high-pass filter skipped")
    end

    -- 2. Bus compressor for glue
    local comp_idx = reaper.TrackFX_AddByName(master_track, "ReaComp", false, -1)
    if comp_idx >= 0 then
        local set, total = 0, 0
        for _, setting in ipairs({
            { "Threshold", COMP_THRESH }, { "Ratio", COMP_RATIO },
            { "Attack", COMP_ATTACK }, { "Release", COMP_RELEASE },
        }) do
            total = total + 1
            if set_param_real(master_track, comp_idx, setting[1], setting[2]) then
                set = set + 1
            end
        end
        -- Say what actually happened. "added" on its own is what made a
        -- completely unconfigured compressor look like a finished chain.
        if set == total then
            msg("  ✓ Compressor (Glue) added and configured")
        elseif set > 0 then
            msg(string.format("  ~ Compressor added, %d of %d settings applied",
                set, total))
        else
            msg("  ~ Compressor added but NO settings were applied — set it by hand")
        end
    else
        msg("  ! ReaComp not available — compression skipped")
    end

    -- 3. Brickwall limiter. The stock plug-in is called ReaLimit.
    local limit_idx = reaper.TrackFX_AddByName(master_track, "ReaLimit", false, -1)
    if limit_idx >= 0 then
        if set_param_real(master_track, limit_idx, "Ceiling", LIMIT_CEIL) then
            msg(string.format("  ✓ Limiter (%.1f dB ceiling) added and configured", LIMIT_CEIL))
        else
            msg(string.format("  ~ Limiter added, ceiling NOT set (wanted %.1f dB) — check it", LIMIT_CEIL))
        end
    else
        msg("  ! ReaLimit not available — limiting skipped")
    end

    reaper.Undo_EndBlock("Apply Mastering Chain", -1)
    reaper.PreventUIRefresh(-1)
    reaper.UpdateArrange()
    msg("Mastering chain applied.")
end

apply_mastering_chain()
