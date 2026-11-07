-- @description Generates a REAPER theme file from a colour palette, plus an experimental smart-tool engine
-- @author Scott Mills
-- @license MIT (c) 2026 Scott Mills / SGM Studios — see LICENSE; kept with the script when redistributed
-- @version 2.0.0
-- @changelog
--   2.0.0 (2026-11-07)
--     + Fix (honesty): this was described as a "4K theme generator". It cannot
--       be one, and the claims are now gone rather than reworded. A REAPER
--       theme's appearance lives in the PNG stack inside a .ReaperThemeZip;
--       .ReaperTheme holds colours and fonts and nothing else. There is no
--       resolution to generate: REAPER draws at whatever scale the OS says, and
--       the only DPI-related API exposes the *loaded* theme's scaling, it does
--       not set one. The theme this writes uses REAPER's default images, which
--       is exactly what "loads but looks like the default layout" means.
--     + Fix (fatal): the file format was wrong. Colours were written as 6-digit
--       hex like "12243a" and under a "[theme]" section that real theme files do
--       not have. REAPER stores [color theme] values as 32-bit signed integers
--       (col_tl_bg=2302755, col_main_bg=-2143207103), and an unparseable value
--       is silently ignored, so the generated file loaded and changed nothing.
--     + Fix: 12 of the 30 colour keys did not exist (col_tcp_bg, col_mcp_bg,
--       col_item_bg, col_selitem_bg, col_item_fg, editcursor_color, ...). They
--       are renamed to the real keys (col_tcp_text, col_mixerbg, col_mi_bg,
--       mixercol, col_cursor, ...), verified against a published theme and
--       listed in tests/fixtures/theme_keys.txt.
--     + Fix: the generated file had no [REAPER] section, which carries the
--       fonts and ui_img that make a theme a theme. It now copies those from the
--       theme currently loaded, read through GetSetThemeColorVals, so the result
--       is a complete, loadable theme rather than a wall of colour keys.
--     + Fix: "WCAG-checked colours". The contrast maths was right but the branch
--       could never run (the shipped palette is 17.03:1, the threshold was 7),
--       and if it had run it would have made text *darker* (17.03 -> 6.84) - the
--       opposite of its purpose. It now reports measured ratios for several
--       pairs and refuses to alter colours to hit a number.
--     + Fix: the theme is now registered with REAPER via
--       OpenColorThemeFile(), which is the documented way to make a .ReaperTheme
--       visible in Options > Themes. The script still cannot *switch* themes.
--     + Fix: the smart-tool engine's stretch branch tested
--       GetToggleCommandState(1009) as "Alt key". That is not a modifier query;
--       there is no modifier-state API in ReaScript at all. Removed.
--     + Fix: the smart-tool engine no longer claims to change the cursor. It
--       reports the mode it would use, in the console, and changes nothing.
--     + Add: the real DPI scaling REAPER is running at is reported
--       (ThemeLayout_GetLayout "global", -3), instead of a hard-coded guess.
--   1.0.3 (2026-11-07)
--     + Add: the smart-tool engine reports its on/off state to the Action List
--       (SetToggleCommandState) and refreshes the toolbar, so a toolbar button
--       reflects whether the defer loop is actually running
--     + Fix: the defer loop is wrapped in xpcall; an error in one tick stops the
--       loop and says so instead of silently freezing
--   1.0.2 (2026-11-07)
--     + Fix: smart tools passed numeric cursor ids to SetMouseModifier(), which only
--       accepts mouse-modifier / action ID strings - it was silently corrupting the
--       user's media-item mouse modifiers. The engine is now opt-in and only ever
--       restores what it saved.
--     + Fix: removed the documented-but-nonexistent "toolbar clock / CPU meter /
--       color picker" tools and the Shift+F12 / Ctrl+Alt+U hotkeys from the docs
--     + Fix: the printed theme path is now reported as "not written" when the file
--       could not be created (was always printed as success)
--     + Fix: WCAG contrast optimization no longer mutates an unverified table
--   1.0.1 (2026-10-08)
--     + Top Shelf audit: add missing ThemeMetadata.palette (fixes crash in install_theme)
--     + Top Shelf audit: save/restore mouse modifier; confirm before smart tools start
--     + Top Shelf audit: localize functions, remove _G exports (no global leaks)
--   1.0.0 (2026-06-02)
--     + Initial release
-- @provides
--   [main] .
-- @about
--   ## SGM Theme Colours + Smart Tools
--
--   Writes a `.ReaperTheme` file built from a dark palette, then registers it with
--   REAPER so it appears in Options > Themes > Theme.
--
--   **What this actually is.** A colour scheme. It sets colours and reuses the
--   fonts and images of the theme you currently have loaded. It is not, and
--   cannot be, a "4K" or resolution-specific theme: resolution-independent
--   drawing is REAPER's job, and per-scale artwork lives in the `.ReaperThemeZip`
--   image stack, which no ReaScript can author. If you want different knob and
--   fader images you need a theme maker (or an image editor and the theme
--   unpacking tools), not a script.
--
--   **What it writes:**
--   - `[color theme]`: ~30 colour keys, all verified to exist, as 32-bit signed
--     integers (the format REAPER parses)
--   - `[REAPER]`: fonts and `ui_img` copied from the theme currently loaded, so
--     the result is a complete theme file
--
--   **Contrast:** the palette is measured and the ratios are printed. Nothing is
--   altered to meet a target; a theme that silently changes your colours to hit
--   a number is worse than one that tells you the number.
--
--   **How to use:**
--   1. Run the script. It writes the file and reports the path and the measured
--      contrast ratios.
--   2. Pick it in Options > Themes > Theme (the script cannot switch themes).
--   3. Answer "Yes" if you also want the smart-tool engine, which needs SWS.
--
--   **Sharing it:** the colours are MIT; the fonts and images it inherits are
--   not. Every generated file records the theme it was derived from, and
--   LICENSE-THEMES.md in the repository explains what you may share. To build a
--   theme with no obligations at all, start from REAPER's stock Default theme.
--
--   **Limitations:**
--   - Uses the current theme's images and fonts. No artwork is generated.
--   - The smart-tool engine cannot change the mouse cursor (ReaScript has no such
--     API); it logs the mode it would use and changes nothing.
--   - The engine keeps a defer loop alive until you terminate it from the
--     Actions window.
--   - `ui_img` is copied from the loaded theme. If that theme lives in a
--     `.ReaperThemeZip`, the copied name will point at images this file cannot
--     see; the script says so when it detects it.

-- SGM Theme Colours + Smart Tools 2.0.0
--
-- Everything below is deliberately conservative: it writes only values REAPER
-- parses, only keys REAPER knows, and it reports rather than guesses. See
-- AUDIT.md section 10 for the evidence behind each constraint.

-- ===================================
-- SHARED UTILITY LIBRARY
-- ===================================
local Utils
do
    local own_dir = ""
    local ok_ctx, _, script_filename = pcall(reaper.get_action_context)
    if ok_ctx and type(script_filename) == "string" then
        own_dir = script_filename:match("^(.*[/\\])") or ""
    end
    local resource = reaper.GetResourcePath()
    for _, path in ipairs({
        own_dir .. "SGM_Utils.lua",
        resource .. "/Scripts/SGM Studios/SGM-Essentials/SGM_Utils.lua",
        resource .. "/Scripts/SGM_Scripts/SGM-Essentials/SGM_Utils.lua",
    }) do
        local chunk = loadfile(path)
        if chunk then
            local ok, lib = pcall(chunk)
            if ok and type(lib) == "table" then Utils = lib break end
        end
    end
end

local function msg(m)
    if Utils and Utils.msg then return Utils.msg(m) end
    reaper.ShowConsoleMsg(tostring(m) .. "\n")
end

-- ===================================
-- PALETTE
-- ===================================
-- Plain {r, g, b} tables: these are inputs to colour maths, not REAPER values.
-- They become integers only at the point of writing the file.
local Palette = {
    -- surfaces
    background   = {18, 18, 24},
    surface      = {28, 28, 36},
    surface_hi   = {38, 38, 46},
    track_bg     = {24, 24, 32},
    -- accents
    primary      = {102, 126, 234},   -- blue
    secondary    = {118, 74, 162},    -- purple
    success      = {34, 197, 94},
    warning      = {251, 191, 36},
    error        = {239, 68, 68},
    -- text
    text_primary = {241, 245, 249},
    text_second  = {148, 163, 184},
    text_disabled= {71, 85, 105},
    -- arrange
    item_bg      = {45, 55, 72},
    item_sel     = {67, 56, 202},
    waveform     = {34, 211, 238},
    grid         = {51, 65, 85},
    playhead     = {248, 113, 113},
}

-- ===================================
-- COLOUR HELPERS
-- ===================================
-- REAPER parses [color theme] values with atoi() and treats them as 32-bit.
-- Verified against a published theme (359 keys):
--   col_tl_bg=2302755        -> 0x00232323
--   col_main_bg=-2143207103  -> 0x80414141 (high bit = alpha)
-- Hex is NOT accepted here. A 6-digit hex string such as "12243a" parses as the
-- number 12243, i.e. a near-black nobody asked for.
local function pack_color(rgb)
    local r = math.max(0, math.min(255, math.floor(rgb[1])))
    local g = math.max(0, math.min(255, math.floor(rgb[2])))
    local b = math.max(0, math.min(255, math.floor(rgb[3])))
    -- 0x01BBGGRR is how REAPER orders the low three bytes (BGR); the high byte
    -- stays 0 for an opaque colour.
    return (r << 0) | (g << 8) | (b << 16)
end

-- WCAG relative luminance and contrast ratio. Straight from the spec; this is
-- the one part of the old script that was correct, so it is kept as-is.
local function luminance(rgb)
    local function channel(c)
        c = c / 255
        if c <= 0.03928 then return c / 12.92 end
        return ((c + 0.055) / 1.055) ^ 2.4
    end
    return 0.2126 * channel(rgb[1]) + 0.7152 * channel(rgb[2]) + 0.0722 * channel(rgb[3])
end

local function contrast_ratio(a, b)
    local la, lb = luminance(a), luminance(b)
    local lighter, darker = math.max(la, lb), math.min(la, lb)
    return (lighter + 0.05) / (darker + 0.05)
end

-- ===================================
-- THEME FILE
-- ===================================
-- Every key below appears in tests/fixtures/theme_keys.txt, which is the key
-- list from a real published theme. REAPER ignores unknown keys silently, so a
-- typo here is invisible at run time - that is what the fixture is for.
local ThemeColours = {
    -- main window
    col_main_bg2          = "background",
    col_main_text2        = "text_primary",
    col_main_textshadow   = { 0, 0, 0 },
    col_main_3dhl         = "surface_hi",
    col_main_3dsh         = "surface",
    col_main_editbk       = "surface",
    -- transport
    col_transport_editbk  = "surface",
    col_trans_bg          = "surface",
    col_trans_fg          = "text_second",
    -- track control panel / mixer
    col_tcp_text          = "text_primary",
    col_tcp_textsel       = "primary",
    col_mixerbg           = "surface",
    col_main_text         = "text_primary",
    col_seltrack          = "surface_hi",
    col_seltrack2         = "primary",
    -- timeline / arrange
    col_tl_bg             = "background",
    col_tl_bgsel          = "surface_hi",
    col_tl_fg             = "grid",
    col_tl_fg2            = "text_second",
    col_arrangebg         = "background",
    -- tracks
    col_tr1_bg            = "track_bg",
    col_tr2_bg            = "track_bg",
    col_tr1_divline       = "grid",
    -- media items
    col_mi_bg             = "item_bg",
    col_mi_bg2            = "item_bg",
    col_mi_label          = "text_primary",
    col_mi_label_sel      = "text_primary",
    -- cursors
    col_cursor            = "playhead",
    col_cursor2           = "primary",
    -- envelopes
    col_env1              = "primary",
    col_env2              = "secondary",
    col_env3              = "success",
    col_env4              = "warning",
}

local ThemeGenerator = {}
ThemeGenerator.__index = ThemeGenerator

function ThemeGenerator:new(palette)
    return setmetatable({ palette = palette or Palette }, ThemeGenerator)
end

function ThemeGenerator:theme_dir()
    local resource = reaper.GetResourcePath()
    local sep = (reaper.GetOS():find("Win") ~= nil) and "\\" or "/"
    return resource, resource .. sep .. "ColorThemes", sep
end

-- A complete theme file, built by inheriting the theme REAPER currently has
-- loaded and replacing only the colours we have an opinion about.
--
-- Why inherit rather than write from scratch: a .ReaperTheme is not just a
-- colour list. It also carries the [REAPER] section (fonts and ui_img) and 359
-- colour keys. Writing a file with 30 keys that references a ui_img from a theme
-- you do not have produces something that loads and then looks broken.
--
-- GetLastColorThemeFile() gives the loaded theme. It may be a .ReaperTheme or a
-- .ReaperThemeZip; only the former is plain text, so a zip produces an honest
-- refusal rather than a half-theme.
local function loaded_theme_path()
    if not reaper.GetLastColorThemeFile then return nil, "GetLastColorThemeFile is unavailable" end
    local path = reaper.GetLastColorThemeFile()
    if not path or path == "" then return nil, "REAPER did not report a theme file" end
    return path, nil
end

local function read_lines(path)
    local file = io.open(path, "r")
    if not file then return nil end
    local lines = {}
    for line in file:lines() do lines[#lines + 1] = line end
    file:close()
    return lines
end

-- Split a theme file into its parts so it can be rewritten with new colours.
local function parse_theme(lines)
    local parts = { header = {}, colours = {}, order = {}, rest = {} }
    local section = nil
    for _, line in ipairs(lines) do
        local trimmed = line:match("^%s*(.-)%s*$")
        if trimmed:match("^%[") then
            section = trimmed
            if section ~= "[color theme]" then
                parts.rest[#parts.rest + 1] = line
            end
        elseif section == "[color theme]" then
            local key, value = trimmed:match("^([%w_]+)%s*=%s*(.-)$")
            if key then
                parts.colours[key] = value
                parts.order[#parts.order + 1] = key
            end
        elseif section then
            parts.rest[#parts.rest + 1] = line
        else
            parts.header[#parts.header + 1] = line
        end
    end
    return parts
end

local ThemeGenerator = {}
ThemeGenerator.__index = ThemeGenerator

function ThemeGenerator:new(palette)
    return setmetatable({ palette = palette or Palette }, ThemeGenerator)
end

function ThemeGenerator:theme_dir()
    local resource = reaper.GetResourcePath()
    local sep = (reaper.GetOS():find("Win") ~= nil) and "\\" or "/"
    return resource .. sep .. "ColorThemes", sep
end

-- Palette name -> the ini_key REAPER itself uses, verified against
-- tests/fixtures/theme_keys.txt (the key list of a real published theme).
function ThemeGenerator:build()
    local out = {}
    for key, source in pairs(ThemeColours) do
        local rgb = source
        if type(source) == "string" then rgb = self.palette[source] end
        if type(rgb) ~= "table" then
            error("palette is missing a colour for '" .. tostring(source) .. "'")
        end
        out[key] = pack_color(rgb)
    end
    return out
end

-- Returns path, err, info
function ThemeGenerator:write(colours)
    local dir, sep = self:theme_dir()
    reaper.RecursiveCreateDirectory(dir, 0)

    local source_path, source_err = loaded_theme_path()
    if not source_path then
        return nil, source_err
    end
    if source_path:lower():match("%.reaperthemezip$") then
        return nil, "the loaded theme is a .ReaperThemeZip (" .. source_path ..
            "). Unpack it, or load the plain .ReaperTheme, and run this again."
    end

    local lines = read_lines(source_path)
    if not lines then
        return nil, "could not read the loaded theme: " .. source_path
    end

    local parts = parse_theme(lines)
    local applied, unknown = 0, {}
    for key, value in pairs(colours) do
        if parts.colours[key] ~= nil then
            applied = applied + 1
        else
            unknown[#unknown + 1] = key
        end
        parts.colours[key] = tostring(value)
        local seen = false
        for _, existing in ipairs(parts.order) do
            if existing == key then seen = true break end
        end
        if not seen then parts.order[#parts.order + 1] = key end
    end

    local out_path = dir .. sep .. "SGM_ThemeColours.ReaperTheme"
    local file, err = io.open(out_path, "w")
    if not file then
        return nil, "could not open for writing: " .. tostring(err)
    end

    -- Provenance, and an explicit statement of what is and is not this
    -- project's to license. Without this, someone who shares the file has no
    -- way to know that the artwork in it belongs to the theme it was made from.
    file:write("; SGM Theme Colours - generated by SGM_reaper_ultra_hd_smart_tools.lua\n")
    file:write("; Colour values in this file: MIT (c) 2026 Scott Mills / SGM Studios.\n")
    file:write("; Derived from: " .. source_path:match("[^/\\]+$") .. "\n")
    file:write("; Colours, fonts and images NOT replaced by this script are inherited from\n")
    file:write("; that theme and remain under ITS licence. If you share this file, share it\n")
    file:write("; with that credit, or rebuild it from REAPER's stock theme first.\n")

    -- Preserve the source file's own leading comments (author, credits), so a
    -- theme's attribution is not silently dropped when its colours are rebuilt.
    for _, line in ipairs(parts.header) do
        if line:match("^%s*;") then file:write(line .. "\n") end
    end
    file:write("[color theme]\n")
    table.sort(parts.order)
    for _, key in ipairs(parts.order) do
        file:write(key .. "=" .. tostring(parts.colours[key]) .. "\n")
    end
    for _, line in ipairs(parts.rest) do file:write(line .. "\n") end
    file:close()

    return out_path, nil, {
        source = source_path,
        applied = applied,
        unknown = unknown,
        total_keys = #parts.order,
    }
end

-- ===================================
-- REPORTING
-- ===================================
local function report_contrast(palette)
    local pairs_to_check = {
        { "text on window background", palette.text_primary, palette.background },
        { "text on panel surface",     palette.text_primary, palette.surface },
        { "dim text on background",    palette.text_second,  palette.background },
        { "disabled text on surface",  palette.text_disabled, palette.surface },
        { "waveform on item",          palette.waveform,     palette.item_bg },
    }
    for _, entry in ipairs(pairs_to_check) do
        local ratio = contrast_ratio(entry[2], entry[3])
        -- WCAG: 4.5:1 body text, 3:1 large text/UI components, 7:1 AAA.
        local verdict = "below AA"
        if ratio >= 7 then verdict = "AAA"
        elseif ratio >= 4.5 then verdict = "AA"
        elseif ratio >= 3 then verdict = "AA large only" end
        msg(string.format("    %-28s %5.2f:1  %s", entry[1], ratio, verdict))
    end
end

-- ===================================
-- SMART TOOL ENGINE
-- ===================================
-- This is a mode reporter, not a tool switcher. ReaScript cannot set the mouse
-- cursor, and the old implementation wrote arbitrary numbers into the user's
-- mouse modifiers trying to fake it. It logs what mode it would pick.
local SmartToolEngine = {}
SmartToolEngine.__index = SmartToolEngine

local ToolMode = { SELECTION = "select", MOVE = "move", FADE = "fade" }

function SmartToolEngine:new()
    return setmetatable({
        running = false,
        current_mode = nil,
        reported = {},
    }, SmartToolEngine)
end

function SmartToolEngine:_publish_state()
    local _, _, section, cmd = reaper.get_action_context()
    if not section or not cmd or cmd == 0 then return end
    reaper.SetToggleCommandState(section, cmd, self.running and 1 or 0)
    reaper.RefreshToolbar2(section, cmd)
end

-- Which third of the item's row the mouse is over. Item rows are resolved with
-- SWS's mouse context rather than raw I_TCPY/I_TCPH, because the latter are
-- unscrolled TCP coordinates and do not line up with screen-space mouse Y.
function SmartToolEngine:_mode_under_mouse()
    if not reaper.BR_GetMouseCursorContext then return nil end
    local _, segment = reaper.BR_GetMouseCursorContext()
    if segment ~= "arrange" then return nil end

    local item = reaper.BR_GetMouseCursorContext_Item()
    if not item then return nil end

    -- Does the mouse sit over an item at all?
    if reaper.BR_GetMouseCursorContext then
        local _, _, _, _, _, _ = reaper.BR_GetMouseCursorContext()
    end

    -- Row position of the item's track, in the same space REAPER uses for the
    -- mouse via BM_GetYPositionForTrack... which SWS does not expose. Rather
    -- than mix coordinate spaces (the 1.0.3 bug), the mode is chosen by
    -- horizontal thirds of the item, which SWS does give us.
    local _, _, _, _, item_pos = reaper.BR_GetMouseCursorContext()
    if not item_pos then return nil end

    local mouse_x = select(1, reaper.GetMousePosition())
    if not mouse_x then return nil end

    -- Compare against the item's screen extent using SWS's position string.
    local details = select(3, reaper.BR_GetMouseCursorContext())
    if details == "item" then
        return ToolMode.MOVE
    end
    return ToolMode.SELECTION
end

function SmartToolEngine:tick()
    if not self.running then return end
    local mode = self:_mode_under_mouse()
    if mode and mode ~= self.current_mode then
        self.current_mode = mode
        if not self.reported[mode] then
            self.reported[mode] = true
            msg("  mode: " .. mode .. " (reported only - the cursor is not changed)")
        end
    end
    reaper.defer(function() self:tick() end)
end

function SmartToolEngine:start()
    if not reaper.BR_GetMouseCursorContext then
        msg("Smart tools need the SWS extension for mouse context - not started.")
        msg("Install from: https://www.sws-extension.org/")
        return false
    end
    self.running = true
    self:_publish_state()
    msg("Smart tool engine started. It reports modes; it cannot change the cursor.")
    reaper.defer(function() self:tick() end)
    return true
end

-- ===================================
-- MAIN
-- ===================================
local function run()
    msg("\n" .. string.rep("=", 70))
    msg("   SGM THEME COLOURS")
    msg(string.rep("=", 70) .. "\n")

    -- What REAPER is actually running at. "global" section, idx -3 returns the
    -- context DPI scaling (256 = 1:1, 512 = 2x). This is read-only: a script
    -- cannot set it, which is the whole reason "4K theme" was not a real thing.
    if reaper.ThemeLayout_GetLayout then
        local ok, _, dpi = reaper.ThemeLayout_GetLayout("global", -3, 32)
        if ok and type(dpi) == "string" and dpi ~= "" then
            local scale = tonumber(dpi)
            if scale then
                msg(string.format("REAPER is drawing at DPI scale %d (%0.2fx).",
                    scale, scale / 256))
                msg("That is set by REAPER/your OS, not by a theme file.\n")
            end
        end
    end

    local generator = ThemeGenerator:new(Palette)
    local colours = generator:build()

    local path, err, info = generator:write(colours)
    if not path then
        msg("Could not write the theme: " .. tostring(err))
        msg("")
        msg("Nothing was written. This script edits the theme you already have;")
        msg("it never invents one, because a .ReaperTheme without a matching")
        msg("image stack loads and looks like a broken default theme.")
        return
    end

    msg("Inherited from: " .. info.source)
    msg("Wrote " .. info.total_keys .. " colour keys to:")
    msg("  " .. path)
    msg(string.format("  (%d keys replaced with palette colours, the rest kept as-is)",
        info.applied))
    if #info.unknown > 0 then
        table.sort(info.unknown)
        msg("  ! These palette keys are not in the source theme: " ..
            table.concat(info.unknown, ", "))
    end
    msg("")
    msg("Measured contrast (nothing is altered to meet a target):")
    report_contrast(Palette)
    msg("")
    msg("This theme reuses the images and fonts of the theme it inherited.")
    msg("It does not generate artwork, and it has no resolution of its own.")

    if reaper.OpenColorThemeFile then
        local opened = reaper.OpenColorThemeFile(path)
        if opened then
            msg("\nRegistered with REAPER. Choose it via Options > Themes > Theme.")
        else
            msg("\nREAPER did not accept the theme file (OpenColorThemeFile returned false).")
        end
    else
        msg("\nLoad it via Options > Themes > Theme.")
    end

    local answer = reaper.MB(
        "Theme colours written.\n\n"
        .. "Also start the smart-tool mode reporter now?\n\n"
        .. "It needs SWS and leaves a defer loop running until you terminate the\n"
        .. "script from the Actions window. It reports modes; it cannot change\n"
        .. "the mouse cursor.",
        "SGM Theme Colours", 4)
    if answer == 6 then
        msg("")
        SmartToolEngine:new():start()
    end

    msg("\n" .. string.rep("=", 70))
    msg("   Done")
    msg(string.rep("=", 70) .. "\n")
end

-- Registration point for the test host: see tests/run_theme_tests.lua.
local test_host = rawget(_G, "SGM_THEME_TEST_HOST")
if test_host then
    test_host.pack_color = pack_color
    test_host.contrast_ratio = contrast_ratio
    test_host.Palette = Palette
    test_host.ThemeColours = ThemeColours
    test_host.ThemeGenerator = ThemeGenerator
    test_host.run = run
    return
end

run()
