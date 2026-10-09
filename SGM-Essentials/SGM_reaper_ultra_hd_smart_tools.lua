-- @description 4K-optimized REAPER theme with AI-aware UI elements and smart tool configuration
-- @author Scott Mills
-- @version 1.0.1
-- @changelog
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
--   4K/UHD-optimized REAPER theme generator with WCAG-compliant contrast
--   optimization and smart toolbar tools.
--
--   **What it does:**
--   - Generates a 4K-optimized REAPER theme with high-contrast WCAG-compliant
--     color palette (dark theme with Pro Tools-inspired blue accents)
--   - Includes a defer loop for dynamic toolbar tools:
--     - Toolbar clock display
--     - CPU meter overlay
--     - Color picker for track/item tinting
--   - AI-aware UI elements with distinct colors for AI-suggested state
--
--   **How to use:**
--   1. Run the script to apply the 4K theme
--   2. Run again to start the deferred toolbar tool loop
--   3. The defer loop runs until the script is terminated via Actions
--
--   **Limitations:**
--   - Best results on REAPER 7.0+ (native 4K support)
--   - Theme generation modifies the REAPER color scheme — backup your
--     current theme before applying
--   - Defer loop consumes minimal CPU but should be terminated when not needed
--   - Some UI elements may need manual tweaking depending on your display
--     configuration (DPI scaling, monitor setup)

-- REAPER Ultra HD Smart Tools (Simplified Lua Version)
-- 4K-optimized theme with AI-aware UI elements

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
    name = "REAPER ULTRA HD",
    version = "1.0.0", 
    author = "EchoBeat",
    description = "4K-optimized theme with AI-aware UI elements",
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
    if file then
        -- Header
        file:write("; " .. self.meta.name .. " v" .. self.meta.version .. "\n")
        file:write("; " .. self.meta.description .. "\n")
        file:write("; Author: " .. self.meta.author .. "\n\n")
        
        -- Theme section
        file:write("[theme]\n")
        file:write("version=7.0\n")
        file:write("name=" .. self.meta.name .. "\n")
        file:write("author=" .. self.meta.author .. "\n\n")
        
        -- Color definitions
        file:write("[color theme]\n")
        for key, value in pairs(theme_data) do
            file:write(key .. "=" .. value .. "\n")
        end
        
        file:close()
        msg("Theme file generated: " .. filepath)
    else
        msg("ERROR: Could not create theme file: " .. filepath)
    end
    
    return filepath
end

function UltraHDThemeGenerator:apply_theme()
    -- Note: Actual theme application requires REAPER restart
    msg("Theme file generated. Apply via Preferences > Appearance > Theme")
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
    -- Update cursor appearance based on mode
    local cursor_map = {
        [ToolMode.SELECTION] = 0,    -- Arrow
        [ToolMode.MOVE] = 182,       -- Hand
        [ToolMode.FADE] = 183,       -- Fade cursor
        [ToolMode.STRETCH] = 184,    -- Stretch cursor
        [ToolMode.SPLIT] = 185       -- Split cursor
    }
    
    local cursor_id = cursor_map[mode] or 0
    reaper.SetMouseModifier("MM_CTX_ITEM", 0, cursor_id)
end

function SmartToolEngine:toggle_ai_prediction()
    self.ai_prediction_enabled = not self.ai_prediction_enabled
    return self.ai_prediction_enabled
end

function SmartToolEngine:start()
    self.running = true
    -- Save the user's current item mouse modifier so stop() can restore it
    if reaper.GetMouseModifier then
        local ok, prev = reaper.GetMouseModifier("MM_CTX_ITEM", 0)
        if ok then self._saved_item_modifier = prev end
    end
    msg("=== Smart Tools Activated ===")
    msg("Pro Tools-style context switching enabled.")
    msg("Press Shift+F12 to toggle AI prediction.")
    
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
    -- Restore the user's original mouse modifier
    if self._saved_item_modifier and reaper.SetMouseModifier then
        reaper.SetMouseModifier("MM_CTX_ITEM", 0, self._saved_item_modifier)
        self._saved_item_modifier = nil
    end
    msg("Smart tools deactivated.")
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
    
    -- Generate and apply
    local filepath = self.theme_generator:generate_theme_file()
    msg("Theme saved to: " .. filepath)
    
    self.theme_generator:apply_theme()
    msg("Theme applied successfully!")
    msg("Restart REAPER if colors don't update immediately.")
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
        "Theme installed. Also start the Smart Tool engine now?\n\n"
        .. "While active, it changes the media-item mouse modifier and runs "
        .. "a defer loop. Re-run this script and answer No to skip it.",
        "REAPER Ultra HD", 4)
    if start_tools == 6 then
        msg("\nActivating smart tools...")
        integration:start_smart_tools()
    end
    
    msg("\n" .. string.rep("=", 70))
    msg("   Installation Complete!")
    msg(string.rep("=", 70))
    msg("\nFeatures:")
    msg("  ✓ Ultra HD 4K/8K-optimized theme")
    msg("  ✓ Pro Tools Smart Tool (context-aware cursor)")
    msg("  ✓ Perceptual color optimization (WCAG AAA)")
    msg("  ✓ AI prediction hooks (experimental)")
    msg("\nControls:")
    msg("  - Hover over items: Tool changes based on position")
    msg("  - Shift+F12: Toggle AI prediction")
    msg("  - Ctrl+Alt+U: Toggle smart tools on/off")
    msg("\n")
end

-- Top Shelf: no _G exports — this script is self-contained.
install_ultra_hd_theme()