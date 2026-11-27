--[[ ==============================================================================
    Perf Biggins - Core Constants & Utility Functions
    ------------------------------------------------------------------------------
    Telemetery format strings, scale caps, SavedVariables defaults, color gradients,
    and combat / environment detection helpers.
============================================================================== ]]--

local addonName, addon = ...

-- Cache upvalues
local InCombatLockdown    = InCombatLockdown
local UnitAffectingCombat = UnitAffectingCombat
local type                = type

-- Pre-cached format string pointers (Zero garbage collection in Lua heap)
addon.FORMAT_FPS   = "%.1f FPS"
addon.FORMAT_WORLD = "%.0f ms World"
addon.FORMAT_HOME  = "%.0f ms Home"

-- Max fill limits for 100% status bar display
addon.DEFAULT_FPS_CAP = 144  -- Default fallback FPS cap
addon.activeFpsCap    = 144  -- Active dynamic FPS scale cap
addon.MAX_LATENCY_CAP = 200  -- Max Latency scale cap in ms

-- Update Loop Rate: 10 FPS (0.10s) for silky smooth responsiveness
addon.UPDATE_THROTTLE = 0.10

-- Configuration Defaults
addon.DB_DEFAULTS = {
    enabled       = true,
    showFps       = true,
    showWorld     = true,
    showHome      = true,
    stackingMode  = "VERTICAL",
    autoFpsCap    = true,
    manualFpsCap  = 144,
    barWidth      = 180,
    barHeight     = 18,
    barSpacing    = 4,
    bgAlpha       = 25,
    locked        = false,
    hideInCombat  = false,
    point         = "CENTER",
    relativePoint = "CENTER",
    xOfs          = 0,
    yOfs          = -160,
}

-- Font helper with safe fallback to active Blizzard game fonts
function addon:GetDefaultFont()
    if STANDARD_TEXT_FONT and type(STANDARD_TEXT_FONT) == "string" then
        return STANDARD_TEXT_FONT
    end
    if GameFontHighlight and GameFontHighlight.GetFont then
        local font = GameFontHighlight:GetFont()
        if font then return font end
    end
    return "Fonts\\FRIZQT__.TTF"
end

-- Print helper with Blizzard Gold prefix
function addon:PrintMsg(msg)
    print("|cFFFFD100[PerfBiggins]|r " .. msg)
end

-- Check if player is in combat
function addon:IsInCombat()
    if InCombatLockdown and InCombatLockdown() then return true end
    if UnitAffectingCombat and UnitAffectingCombat("player") then return true end
    return false
end

-- FPS: High is good (Green >= 59.5 rounds to 60.0 FPS, Yellow 30-59, Red < 30)
function addon:GetFpsColor(fps)
    if fps >= 59.5 then
        return 0.10, 0.90, 0.20 -- Vibrant Emerald Green
    elseif fps >= 29.5 then
        return 0.95, 0.82, 0.10 -- Golden Yellow
    else
        return 0.95, 0.20, 0.20 -- Warning Red
    end
end

-- Latency: Low is good (Green <= 50, Yellow 51-100, Orange 101-200, Red > 200)
function addon:GetLatencyColor(ms)
    if ms <= 50 then
        return 0.10, 0.90, 0.20 -- Optimal Green
    elseif ms <= 100 then
        return 0.95, 0.82, 0.10 -- Acceptable Yellow
    elseif ms <= 200 then
        return 1.00, 0.55, 0.05 -- Elevated Orange
    else
        return 0.95, 0.20, 0.20 -- High Latency Red
    end
end
