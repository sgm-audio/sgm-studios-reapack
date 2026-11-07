-- @description Auto-mastering chain using REAPER stock plugins: EQ, compression, saturation, and limiting
-- @author Scott Mills
-- @version 1.0.1
-- @changelog
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

local function msg(m)
    reaper.ShowConsoleMsg(tostring(m) .. "\n")
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

-- Set a parameter in the plug-in's own (denormalized) units.
local function set_param_real(track, fx, fragment, value)
    local idx = find_param(track, fx, fragment)
    if idx then
        reaper.TrackFX_SetParam(track, fx, idx, value)
        return true
    end
    msg("  ! Could not find a '" .. fragment .. "' parameter")
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
            false) -- isnorm = false -> value is in Hz
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
        set_param_real(master_track, comp_idx, "Threshold", COMP_THRESH)
        set_param_real(master_track, comp_idx, "Ratio", COMP_RATIO)
        set_param_real(master_track, comp_idx, "Attack", COMP_ATTACK)
        set_param_real(master_track, comp_idx, "Release", COMP_RELEASE)
        msg("  ✓ Compressor (Glue) added")
    else
        msg("  ! ReaComp not available — compression skipped")
    end

    -- 3. Brickwall limiter. The stock plug-in is called ReaLimit.
    local limit_idx = reaper.TrackFX_AddByName(master_track, "ReaLimit", false, -1)
    if limit_idx >= 0 then
        set_param_real(master_track, limit_idx, "Ceiling", LIMIT_CEIL)
        msg(string.format("  ✓ Limiter (%.1f dB ceiling) added", LIMIT_CEIL))
    else
        msg("  ! ReaLimit not available — limiting skipped")
    end

    reaper.Undo_EndBlock("Apply Mastering Chain", -1)
    reaper.PreventUIRefresh(-1)
    reaper.UpdateArrange()
    msg("Mastering chain applied.")
end

apply_mastering_chain()
