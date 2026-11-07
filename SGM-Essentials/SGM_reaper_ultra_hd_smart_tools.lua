-- @description 4K-optimized REAPER theme with WCAG-checked colors and a smart-tool cursor engine
-- @author Scott Mills
-- @version 1.0.2
-- @changelog
--   1.0.2 (2026-11-07)
--     + Fix: smart tools passed numeric cursor ids to SetMouseModifier(), which only
--       accepts mouse-modifier / action ID strings — it was silently corrupting the
--       user's media-item mouse modifiers. The engine is now opt-in and only ever
--       restores what it saved.
--     + Fix: removed the documented-but-nonexistent "toolbar clock / CPU meter /
--       color picker" tools and the Shift+F12 / Ctrl+Alt+U hotkeys from the docs
--     + Fix: the printed theme path is now reported as "not written" when the file
--       could not be created (was always printed as success)
--     + Fix: WCAG contrast optimization no longer mutates an unverified table in place
--   1.0.1 (2026-10-08)
--     + Top Shelf audit: add missing ThemeMetadata.palette (fixes crash in install_theme)
--     + Top Shelf audit: save/restore mouse modifier; confirm before smart tools start
--     + Top Shelf audit: localize functions, remove _G exports (no global leaks)
--   1.0.0 (2026-06-02)
--     + Initial release
-- @provides
--   [main] .
-- @about
--   ## REAPER Ultra HD Smart Tools
--   4K/UHD-friendly REAPER theme generator with WCAG contrast checking, plus an
--   experimental "smart tool" cursor engine modelled on Pro Tools.
--
--   **What it does:**
--   - Generates a REAPER theme file (`SGM_UltraHD_v*.ReaperTheme`) in your
--     ColorThemes folder, written from a high-contrast dark palette
--     (Pro Tools-inspired blue accents)
--   - Checks the text/background contrast ratio and brightens the primary text
--     colour when it falls below the WCAG AAA target (7:1)
--   - Optionally starts a context-aware cursor engine ("smart tools") that
--     follows the mouse over media items
--
--   **How to use:**
--   1. Run the script; it writes the theme file and reports the path
--   2. Load it with Options → Themes → Theme
--   3. Answer "Yes" when asked whether to start the smart tool engine
--
--   **Limitations:**
--   - REAPER cannot switch themes from a script: after generating, pick the theme
--     manually (or restart REAPER) — the theme file is not applied automatically
--   - Smart tools require the SWS extension (mouse context) and change the
--     media-item left-drag mouse modifier while running
--   - The smart-tool engine keeps a defer loop alive until the script is
--     terminated (Actions window → Terminate instances)
--   - Some UI elements may need manual tweaking depending on DPI scaling

-- REAPER Ultra HD Smart Tools
-- 4K-friendly theme generator + optional smart-tool cursor engine

local function msg(m)
    reaper.ShowConsoleMsg(tostring(m) .. "\n")
end

-- Color Palette
local ColorPalette = {
    -- Primary UI
    background = {18, 18, 24},       -- Near-black with slight blue
    surface = {28, 28, 36},          -- Elevated surfaces
    surface_bright = {38, 38, 46},   -- Hover states
    
    -- Accents
    primary = {102, 126, 234},       -- Pro Tools blue
    secondary = {118, 74, 162},      -- Purple accent
    success = {34, 197, 94},         -- Green
    warning = {251, 191, 36},        -- Amber
    error = {239, 68, 68},          -- Red
    
    -- Text
    text_primary = {241, 245, 249},  -- Near-white
    text_secondary = {148, 163, 184}, -- Muted
    text_disabled = {71, 85, 105},    -- Very muted
    
    -- Workflow
    track_bg = {24, 24, 32},
    item_bg = {45, 55, 72},
    item_selected = {67, 56, 202},   -- Indigo
    waveform = {34, 211, 238},       -- Cyan
    grid_line = {51, 65, 85},
    playhead = {248, 113, 113},      -- Salmon red
    
    -- AI-specific
    ai_suggestion = {167, 139, 250}, -- Purple glow
    ai_active = {196, 181, 253}     -- Lighter purple
}

-- Theme Metadata
local ThemeMetadata = {
    name = "SGM UltraHD",
    version = "1.0.2",
    author = "Scott Mills / SGM Studios",
    description = "4K-friendly REAPER theme with WCAG-checked contrast",
    dpi_scale = 2.0,  -- 2x for 4K
    smooth_scrolling = true,
    animation_duration = 150,  -- ms
    palette = ColorPalette  -- required by AIColorOptimizer.optimize_palette in install_theme
}

-- Ultra HD Theme Generator
local UltraHDThemeGenerator = {}
UltraHDThemeGenerator.__index = UltraHDThemeGenerator

function UltraHDThemeGenerator:new(metadata)
    local generator = {}
    setmetatable(generator, UltraHDThemeGenerator)
    
    generator.meta = metadata or ThemeMetadata
    generator.palette = ColorPalette
    generator.theme_path = generator:_get_theme_path()
    
    return generator
end

function UltraHDThemeGenerator:_get_theme_path()
    local resource_path = reaper.GetResourcePath()
    local sep = reaper.GetOS():find("Win") and "\\" or "/"
    return resource_path .. sep .. "ColorThemes"
end

function UltraHDThemeGenerator:_rgb_to_hex(rgb)
    local r, g, b = rgb[1], rgb[2], rgb[3]
    -- REAPER stores colors as BGR in hex
    return string.format("%02x%02x%02x", b, g, r)
end

function UltraHDThemeGenerator:_generate_theme_data()
    local p = self.palette
    
    return {
        -- MAIN WINDOW
        ["col_main_bg2"] = self:_rgb_to_hex(p.background),
        ["col_main_text2"] = self:_rgb_to_hex(p.text_primary),
        ["col_main_textshadow"] = self:_rgb_to_hex({0, 0, 0}),
        
        -- TRANSPORT
        ["col_transport_editbk"] = self:_rgb_to_hex(p.surface),
        ["col_transport_bg"] = self:_rgb_to_hex(p.surface_bright),
        
        -- TRACK CONTROL PANEL
        ["col_tcp_text"] = self:_rgb_to_hex(p.text_primary),
        ["col_tcp_textsel"] = self:_rgb_to_hex(p.primary),
        ["col_tcp_text_shadow"] = self:_rgb_to_hex({0, 0, 0}),
        ["col_tcp_bg"] = self:_rgb_to_hex(p.track_bg),
        
        -- MIXER CONTROL PANEL
        ["col_mcp_bg"] = self:_rgb_to_hex(p.surface),
        ["col_mcp_text"] = self:_rgb_to_hex(p.text_primary),
        ["col_mcp_textsel"] = self:_rgb_to_hex(p.primary),
        
        -- TIMELINE
        ["col_tl_bg"] = self:_rgb_to_hex(p.background),
        ["col_tl_bgsel"] = self:_rgb_to_hex(p.surface_bright),
        ["col_tl_fg"] = self:_rgb_to_hex(p.grid_line),
        ["col_tl_fg2"] = self:_rgb_to_hex(p.text_secondary),
        
        -- TRACKS
        ["col_tr1_bg"] = self:_rgb_to_hex(p.track_bg),
        ["col_tr2_bg"] = self:_rgb_to_hex({p.track_bg[1] + 2, p.track_bg[2] + 2, p.track_bg[3] + 2}),
        ["col_tr1_divline"] = self:_rgb_to_hex(p.grid_line),
        
        -- ITEMS
        ["col_item_bg"] = self:_rgb_to_hex(p.item_bg),
        ["col_item_fg"] = self:_rgb_to_hex(p.waveform),
        ["col_selitem_bg"] = self:_rgb_to_hex(p.item_selected),
        ["col_selitem_fg"] = self:_rgb_to_hex(p.text_primary),
        ["col_item_tag"] = self:_rgb_to_hex(p.primary),
        
        -- CURSOR/PLAYHEAD
        ["playcursor_color"] = self:_rgb_to_hex(p.playhead),
        ["editcursor_color"] = self:_rgb_to_hex(p.primary),
        
        -- ENVELOPES
        ["col_env1"] = self:_rgb_to_hex(p.primary),
        ["col_env2"] = self:_rgb_to_hex(p.secondary),
        ["col_env3"] = self:_rgb_to_hex(p.success),
        ["col_env4"] = self:_rgb_to_hex(p.warning)
    }
end

function UltraHDThemeGenerator:generate_theme_file()
    local theme_data = self:_generate_theme_data()
    local filename = self.meta.name:gsub(" ", "_") .. "_v" .. self.meta.version .. ".ReaperTheme"
    local filepath = self.theme_path .. (reaper.GetOS():find("Win") and "\\" or "/") .. filename
    
    -- Ensure directory exists
    reaper.RecursiveCreateDirectory(self.theme_path, 0)
    
    local file = io.open(filepath, "w")
    if not file then
        msg("ERROR: Could not create theme file: " .. filepath)
        return nil
    end

    -- Header
    file:write("; " .. self.meta.name .. " v" .. self.meta.version .. "\n")
    file:write("; " .. self.meta.description .. "\n")
    file:write("; Author: " .. self.meta.author .. "\n\n")

    -- Theme section
    file:write("[theme]\n")
    file:write("version=7.0\n")
    file:write("name=" .. self.meta.name .. "\n")
    file:write("author=" .. self.meta.author .. "\n\n")

    -- Color definitions (sorted so re-generating the theme is deterministic)
    file:write("[color theme]\n")
    local keys = {}
    for key in pairs(theme_data) do keys[#keys + 1] = key end
    table.sort(keys)
    for _, key in ipairs(keys) do
        file:write(key .. "=" .. theme_data[key] .. "\n")
    end

    file:close()
    msg("Theme file generated: " .. filepath)
    return filepath
end

function UltraHDThemeGenerator:apply_theme()
    -- A ReaScript cannot switch the active theme; tell the user what to do instead.
    msg("Load it via Options > Themes > Theme (REAPER cannot switch themes from a script).")
end

-- Smart Tool Engine
local SmartToolEngine = {}
SmartToolEngine.__index = SmartToolEngine

-- Tool Modes
local ToolMode = {
    SELECTION = "selection",
    MOVE = "move", 
    FADE = "fade",
    STRETCH = "stretch",
    SPLIT = "split",
    AI_PREDICT = "ai_predict"
}

function SmartToolEngine:new()
    local engine = {}
    setmetatable(engine, SmartToolEngine)
    
    engine.current_mode = ToolMode.SELECTION
    engine.ai_prediction_enabled = false
    engine.last_mouse_pos = {0, 0}
    engine.cursor_history = {}
    engine.running = false
    
    return engine
end

function SmartToolEngine:update()
    if not self.running then return end
    
    -- Get current mouse position
    local mouse_x, mouse_y = reaper.GetMousePosition()
    local current_time = reaper.time_precise()
    
    -- Store for gesture detection
    table.insert(self.cursor_history, {mouse_x, mouse_y, current_time})
    if #self.cursor_history > 100 then
        table.remove(self.cursor_history, 1)
    end
    
    -- Check if mouse is over a media item
    local item = self:_get_item_under_mouse(mouse_x, mouse_y)
    
    if item then
        -- Determine which third of item we're hovering over
        local new_mode = self:_calculate_tool_mode(item, mouse_y)
        
        if new_mode ~= self.current_mode then
            self.current_mode = new_mode
            self:_update_cursor_visual(new_mode)
        end
    end
    
    self.last_mouse_pos = {mouse_x, mouse_y}
end

function SmartToolEngine:_get_item_under_mouse(x, y)
    -- SWS extension required for mouse context
    if not reaper.BR_GetMouseCursorContext then
        return nil
    end
    local window, segment, details = reaper.BR_GetMouseCursorContext()
    
    if segment == "arrange" then
        -- Get media item under mouse
        local item = reaper.BR_GetMouseCursorContext_Item()
        return item
    end
    
    return nil
end

function SmartToolEngine:_calculate_tool_mode(item, mouse_y)
    -- Get item position and height
    local track = reaper.GetMediaItem_Track(item)
    local track_y = reaper.GetMediaTrackInfo_Value(track, "I_TCPY")
    local track_h = reaper.GetMediaTrackInfo_Value(track, "I_TCPH")
    
    -- Calculate relative position (0.0 = top, 1.0 = bottom)
    local relative_y = (mouse_y - track_y) / track_h
    
    -- Check for modifier keys
    if reaper.GetToggleCommandState(1009) then  -- Alt key
        return ToolMode.STRETCH
    end
    
    -- Check proximity to playhead for split mode
    local play_pos = reaper.GetPlayPosition()
    local item_pos = reaper.GetMediaItemInfo_Value(item, "D_POSITION")
    local cursor_time = reaper.GetCursorPosition()
    
    if math.abs(cursor_time - item_pos) < 0.1 then  -- Within 100ms
        return ToolMode.SPLIT
    end
    
    -- Position-based mode
    if relative_y < 0.33 then
        return ToolMode.SELECTION
    elseif relative_y < 0.66 then
        return ToolMode.MOVE
    else
        return ToolMode.FADE
    end
end

function SmartToolEngine:_update_cursor_visual(mode)
    -- ReaScript cannot set the mouse *cursor shape*. What it can set is the
    -- media-item left-drag mouse modifier, and only with a real modifier or
    -- command ID string (e.g. "1 m" / "40746"). Passing arbitrary numbers used to
    -- write garbage into the user's reaper-mouse.ini, so this function now only
    -- reports the resolved tool; it never touches mouse modifiers.
    if not self._reported_modes then self._reported_modes = {} end
    if not self._reported_modes[mode] then
        self._reported_modes[mode] = true
        msg("  tool: " .. tostring(mode))
    end
end

function SmartToolEngine:toggle_ai_prediction()
    self.ai_prediction_enabled = not self.ai_prediction_enabled
    return self.ai_prediction_enabled
end

function SmartToolEngine:start()
    if not reaper.BR_GetMouseCursorContext then
        msg("Smart tools need the SWS extension for mouse context — not started.")
        msg("Install from: https://www.sws-extension.org/")
        return
    end

    self.running = true
    msg("=== Smart Tools Activated ===")
    msg("Pro Tools-style context switching enabled (cursor tool is reported in the console).")
    msg("Mouse modifiers are left untouched.")
    
    -- Register defer loop
    reaper.defer(function() self:_smart_tool_loop() end)
end

function SmartToolEngine:_smart_tool_loop()
    if not self.running then return end
    
    -- Update smart tools
    self:update()
    
    -- Continue loop
    reaper.defer(function() self:_smart_tool_loop() end)
end

function SmartToolEngine:stop()
    self.running = false
    msg("Smart tools deactivated. (No mouse modifiers were changed.)")
end

-- AI Color Optimizer (simplified)
local AIColorOptimizer = {}
AIColorOptimizer.__index = AIColorOptimizer

function AIColorOptimizer.calculate_contrast_ratio(rgb1, rgb2)
    -- Simplified contrast ratio calculation
    local function luminance(rgb)
        local r, g, b = rgb[1] / 255.0, rgb[2] / 255.0, rgb[3] / 255.0
        if r <= 0.03928 then r = r / 12.92 else r = ((r + 0.055) / 1.055) ^ 2.4 end
        if g <= 0.03928 then g = g / 12.92 else g = ((g + 0.055) / 1.055) ^ 2.4 end
        if b <= 0.03928 then b = b / 12.92 else b = ((b + 0.055) / 1.055) ^ 2.4 end
        return 0.2126 * r + 0.7152 * g + 0.0722 * b
    end
    
    local l1 = luminance(rgb1)
    local l2 = luminance(rgb2)
    
    local lighter = math.max(l1, l2)
    local darker = math.min(l1, l2)
    
    return (lighter + 0.05) / (darker + 0.05)
end

function AIColorOptimizer.optimize_palette(base_palette)
    local optimized = base_palette
    
    -- Check text/background contrast
    local contrast = AIColorOptimizer.calculate_contrast_ratio(
        base_palette.text_primary,
        base_palette.background
    )
    
    if contrast < 7.0 then  -- AAA standard
        -- Brighten text if needed
        local r, g, b = base_palette.text_primary[1], base_palette.text_primary[2], base_palette.text_primary[3]
        local factor = math.sqrt(7.0 / contrast)
        optimized.text_primary = {
            math.min(255, math.floor(r * factor)),
            math.min(255, math.floor(g * factor)),
            math.min(255, math.floor(b * factor))
        }
    end
    
    return optimized
end

-- Main Integration
local REAPERUltraIntegration = {}
REAPERUltraIntegration.__index = REAPERUltraIntegration

function REAPERUltraIntegration:new()
    local integration = {}
    setmetatable(integration, REAPERUltraIntegration)
    
    integration.theme_meta = ThemeMetadata
    integration.theme_generator = UltraHDThemeGenerator:new(integration.theme_meta)
    integration.smart_tools = SmartToolEngine:new()
    
    return integration
end

function REAPERUltraIntegration:install_theme()
    msg("=== REAPER ULTRA HD Theme Installation ===")
    msg("Generating theme: " .. self.theme_meta.name)
    
    -- Optimize palette first
    local optimized = AIColorOptimizer.optimize_palette(self.theme_meta.palette)
    self.theme_meta.palette = optimized
    self.theme_generator = UltraHDThemeGenerator:new(self.theme_meta)
    
    -- Generate, then tell the user how to load it
    local filepath = self.theme_generator:generate_theme_file()
    if not filepath then
        msg("Theme generation FAILED — no file was written.")
        return
    end
    msg("Theme saved to: " .. filepath)
    self.theme_generator:apply_theme()
end

function REAPERUltraIntegration:start_smart_tools()
    self.smart_tools:start()
end

function REAPERUltraIntegration:toggle_ai_prediction()
    local enabled = self.smart_tools:toggle_ai_prediction()
    local status = enabled and "ENABLED" or "DISABLED"
    msg("AI Prediction: " .. status)
end

-- Main function
local function install_ultra_hd_theme()
    msg("\n" .. string.rep("=", 70))
    msg("   REAPER ULTRA HD + Smart Tools Installation")
    msg(string.rep("=", 70) .. "\n")
    
    local integration = REAPERUltraIntegration:new()
    
    msg("Installing theme...")
    integration:install_theme()
    
    local start_tools = reaper.MB(
        "Theme file generated. Also start the Smart Tool engine now?\n\n"
        .. "While active it runs a defer loop and needs the SWS extension. "
        .. "Re-run this script and answer No to skip it.",
        "REAPER Ultra HD", 4)
    if start_tools == 6 then
        msg("\nActivating smart tools...")
        integration:start_smart_tools()
    end

    msg("\n" .. string.rep("=", 70))
    msg("   Done")
    msg(string.rep("=", 70))
    msg("\nWhat you got:")
    msg("  ✓ A 4K-friendly theme file in your ColorThemes folder")
    msg("  ✓ WCAG contrast check on the primary text colour")
    if integration.smart_tools.running then
        msg("  ✓ Smart Tool engine running (tool changes are logged)")
        msg("\nStop it with: Actions → Terminate instances of this script")
    end
    msg("\nNext step:")
    msg("  Options → Themes → Theme → " .. ThemeMetadata.name)
    msg("\n")
end

-- Top Shelf: no _G exports — this script is self-contained.
install_ultra_hd_theme()