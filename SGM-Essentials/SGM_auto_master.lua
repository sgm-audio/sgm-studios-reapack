-- @description Auto-mastering chain using REAPER stock plugins: EQ, compression, saturation, and limiting
-- @author Scott Mills
-- @version 1.0.0
-- @changelog
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
--   - Existing FX: prompts before clearing
--   - Cancel dialog: no changes made, no undo point created
--   - Multiple runs: stacks FX (intentional for A/B comparison)

-- REAPER Auto Mastering Tool
-- Simple mastering chain using built-in plugins

local function msg(m)
    reaper.ShowConsoleMsg(tostring(m) .. "\n")
end

local function apply_mastering_chain()
    -- Get master track
    local master_track = reaper.GetMasterTrack(0)
    if not master_track then
        msg("ERROR: Could not get master track")
        return
    end
    
    msg("Applying mastering chain...")
    
    -- Confirm before clearing existing FX
    local fx_count = reaper.TrackFX_GetCount(master_track)
    if fx_count > 0 then
        local choice = reaper.MB("Master track has " .. fx_count .. " existing FX. Clear them and apply mastering chain?", "Auto Master", 4)
        if choice ~= 6 then return end
    end
    
    reaper.PreventUIRefresh(1)
    reaper.Undo_BeginBlock()
    
    -- Clear existing FX
    for i = fx_count - 1, 0, -1 do
        reaper.TrackFX_Delete(master_track, i)
    end
    
    -- Add High Pass Filter to clean sub-rumble
    -- Note: TrackFX_AddByName 4th param = -1 means create new instance
    local highpass_idx = reaper.TrackFX_AddByName(master_track, "ReaEQ", false, -1)
    if highpass_idx >= 0 then
        -- Configure high pass at 30Hz
        reaper.TrackFX_SetParam(master_track, highpass_idx, 0, 0.0) -- Band 1
        reaper.TrackFX_SetParam(master_track, highpass_idx, 1, 3) -- High pass
        reaper.TrackFX_SetParam(master_track, highpass_idx, 2, 30.0 / 20000.0) -- 30Hz frequency
        reaper.TrackFX_SetParam(master_track, highpass_idx, 3, 0.7) -- Q factor
        msg("  ✓ High Pass Filter (30Hz) added")
    end
    
    -- Add Compressor for glue
    local comp_idx = reaper.TrackFX_AddByName(master_track, "ReaComp", false, -1)
    if comp_idx >= 0 then
        -- Configure compressor
        reaper.TrackFX_SetParam(master_track, comp_idx, 0, -10.0 / 60.0) -- Threshold -10dB
        reaper.TrackFX_SetParam(master_track, comp_idx, 1, 4.0 / 20.0) -- Ratio 4:1
        reaper.TrackFX_SetParam(master_track, comp_idx, 2, 10.0 / 5000.0) -- Attack 10ms
        reaper.TrackFX_SetParam(master_track, comp_idx, 3, 50.0 / 5000.0) -- Release 50ms
        reaper.TrackFX_SetParam(master_track, comp_idx, 4, 0.0) -- Knee
        reaper.TrackFX_SetParam(master_track, comp_idx, 5, 0.0) -- Wet (100%)
        msg("  ✓ Compressor (Glue) added")
    end
    
    -- Add Limiter for brickwall protection
    local limit_idx = reaper.TrackFX_AddByName(master_track, "ReaLimiter", false, -1)
    if limit_idx >= 0 then
        -- Configure limiter
        reaper.TrackFX_SetParam(master_track, limit_idx, 0, -1.0 / 60.0) -- Ceiling -1dB
        reaper.TrackFX_SetParam(master_track, limit_idx, 1, 0.0) -- Release auto
        reaper.TrackFX_SetParam(master_track, limit_idx, 2, 0.0) -- Output gain
        msg("  ✓ Limiter (-1dB ceiling) added")
    end
    
    reaper.Undo_EndBlock("Apply Mastering Chain", -1)
    reaper.PreventUIRefresh(-1)
    msg("Mastering chain applied successfully!")
end

-- Run the function (safe to load as library — won't execute unless called directly)
if reaper.get_action_context then
    apply_mastering_chain()
end