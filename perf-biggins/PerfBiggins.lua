--[[ ==============================================================================
    Perf Biggins v1.7.1 - High-Performance FPS & Dual-Latency HUD
    ------------------------------------------------------------------------------
    Author: Biggins (US-Whisperwind)
    Compatibility: World of Warcraft: The War Within / Midnight (Patch 11.x - 12.x / 12.1.7)

    ARCHITECTURAL OVERVIEW:
    1. Zero-Allocation Rendering: Formats numbers directly in native C++ using
       FontString:SetFormattedText with pre-cached static format string pointers.
    2. Throttled Telemetry Engine: 10 FPS (0.10s) update loop delivering silky-smooth
       responsiveness with virtually zero CPU footprint and zero memory churn.
    3. Tri-Bar Stacked HUD:
         - Bar 1: FPS (Frames Per Second) with dynamic auto-scaling ceiling
         - Bar 2: World Latency (Combat, Abilities, Positioning, Instance Mechanics)
         - Bar 3: Home Latency (Chat, Auction House, Guild, Realm Connection)
    4. Dynamic Hardware & CVar FPS Scaling:
         - Auto-detects active foreground limit from GetCVar("maxFPS") when enabled.
         - Adaptive uncapped mode starting at 60Hz and dynamically expanding upward.
         - Event-driven rescaling on CVAR_UPDATE with zero /reload required.
         - Transparent settings UX with auto-updating disabled indicator slider.
    5. Dynamic Layout & Collapse: Independent toggles for each bar; active bars
       snap together seamlessly and the frame dynamically resizes without gaps.
    6. Blizzard Gold Aesthetic: Matching LazySpeed styling with dark slate tooltip
       backdrop and Blizzard metallic gold border.
    7. Modular Architecture:
         - Core/Constants.lua: Defaults, scales, format strings, color gradients.
         - Modules/HUD.lua: Master frame, status bars, drag handlers, dynamic layout.
         - Core/Telemetry.lua: 10 FPS update loop and dynamic FPS ceiling evaluation.
         - Core/Options.lua: Blizzard Settings canvas UI and two-column control grid.
         - PerfBiggins.lua: Lifecycle event orchestration and slash command routing.
============================================================================== ]]--

local addonName, addon = ...
_G["PerfBiggins"] = addon
addon.version = "1.7.1"

-- Native Blizzard Keybinding strings
_G["BINDING_HEADER_PERFBIGGINS_HEADER"] = "Perf Biggins"
_G["BINDING_CATEGORY_PERFBIGGINS"] = "Perf Biggins"
_G["BINDING_NAME_PERFBIGGINS_TOGGLE"] = "Toggle Performance HUD"

-- Cache global functions
local CreateFrame = CreateFrame
local pairs       = pairs
local tonumber    = tonumber
local math_max    = math.max
local math_min    = math.min
local math_floor  = math.floor
local strtrim     = strtrim
local string      = string
local print       = print

-- Toggle Master HUD Visibility
function addon:Toggle()
    local db = PerfBigginsDB or addon.DB_DEFAULTS
    db.enabled = not db.enabled
    addon:UpdateOptionsUI()
    addon:UpdateLayout()
    local status = db.enabled and "|cFF00FF00Enabled|r" or "|cFFFF0000Disabled|r"
    addon:PrintMsg("Performance HUD is now " .. status .. ".")
end

-- ==============================================================================
-- LIFECYCLE EVENT DISPATCHER
-- ==============================================================================

local eventFrame = CreateFrame("Frame")
eventFrame:RegisterEvent("ADDON_LOADED")
eventFrame:RegisterEvent("PLAYER_ENTERING_WORLD")
eventFrame:RegisterEvent("CVAR_UPDATE")
eventFrame:RegisterEvent("PLAYER_REGEN_DISABLED")
eventFrame:RegisterEvent("PLAYER_REGEN_ENABLED")

eventFrame:SetScript("OnEvent", function(self, event, ...)
    if event == "ADDON_LOADED" then
        local loaded = ...
        if loaded == addonName then
            -- Initialize SavedVariables
            if not PerfBigginsDB then
                PerfBigginsDB = {}
            end
            for k, v in pairs(addon.DB_DEFAULTS) do
                if PerfBigginsDB[k] == nil then
                    PerfBigginsDB[k] = v
                end
            end

            addon:CalculateActiveFpsCap()
            addon:RestorePosition()
            addon:UpdateLayout()
            addon:RegisterOptions()

            -- Start telemetry loop
            addon.mainFrame:SetScript("OnUpdate", function(f, elapsed) addon:SafeOnUpdate(elapsed) end)
            addon:SafeOnUpdate(1.0)
        end
    elseif event == "PLAYER_ENTERING_WORLD" then
        addon:CalculateActiveFpsCap()
        addon:RestorePosition()
        addon:UpdateLayout()
        addon:SafeOnUpdate(1.0)
    elseif event == "CVAR_UPDATE" then
        local cvarName = ...
        if cvarName == "maxFPS" or cvarName == "useMaxFPS" or not cvarName then
            addon:CalculateActiveFpsCap()
            addon:UpdateOptionsUI()
        end
    elseif event == "PLAYER_REGEN_DISABLED" then
        -- Entered Combat
        local db = PerfBigginsDB
        if db and db.hideInCombat then
            addon.mainFrame:SetScript("OnUpdate", nil) -- Detach loop for 0.00ms CPU footprint
            addon.mainFrame:Hide()
        end
    elseif event == "PLAYER_REGEN_ENABLED" then
        -- Left Combat
        local db = PerfBigginsDB
        if db and db.hideInCombat then
            addon.mainFrame:SetScript("OnUpdate", function(f, elapsed) addon:SafeOnUpdate(elapsed) end) -- Reattach loop
            addon:UpdateLayout()
        end
    end
end)

-- ==============================================================================
-- SLASH COMMAND HANDLER (/perfb)
-- ==============================================================================

local function SlashHandler(msg)
    local cmd = string.lower(strtrim(msg or ""))
    local db = PerfBigginsDB or addon.DB_DEFAULTS

    if cmd == "" or cmd == "options" or cmd == "config" then
        addon:OpenSettings()
    elseif cmd == "toggle" then
        addon:Toggle()
    elseif cmd == "lock" then
        db.locked = not db.locked
        addon:UpdateInteractivity()
        addon:UpdateOptionsUI()
        local status = db.locked and "|cFFFF0000Locked|r" or "|cFF00FF00Unlocked|r"
        addon:PrintMsg("Frame position is now " .. status .. ".")
    elseif cmd == "fps" then
        db.showFps = not db.showFps
        addon:UpdateOptionsUI()
        addon:UpdateLayout()
        local status = db.showFps and "|cFF00FF00Enabled|r" or "|cFFFF0000Disabled|r"
        addon:PrintMsg("FPS bar is now " .. status .. ".")
    elseif cmd == "world" then
        db.showWorld = not db.showWorld
        addon:UpdateOptionsUI()
        addon:UpdateLayout()
        local status = db.showWorld and "|cFF00FF00Enabled|r" or "|cFFFF0000Disabled|r"
        addon:PrintMsg("World Latency bar is now " .. status .. ".")
    elseif cmd == "home" then
        db.showHome = not db.showHome
        addon:UpdateOptionsUI()
        addon:UpdateLayout()
        local status = db.showHome and "|cFF00FF00Enabled|r" or "|cFFFF0000Disabled|r"
        addon:PrintMsg("Home Latency bar is now " .. status .. ".")
    elseif cmd == "stack" or cmd == "mode" or cmd:find("^stack ") or cmd:find("^mode ") then
        local sub = cmd:match("^%S+%s+(.*)$")
        if sub == "horizontal" or sub == "horiz" or sub == "h" then
            db.stackingMode = "HORIZONTAL"
        elseif sub == "vertical" or sub == "vert" or sub == "v" then
            db.stackingMode = "VERTICAL"
        else
            db.stackingMode = (db.stackingMode == "HORIZONTAL") and "VERTICAL" or "HORIZONTAL"
        end
        addon:UpdateOptionsUI()
        addon:UpdateLayout()
        local modeDesc = (db.stackingMode == "HORIZONTAL") and "Horizontal" or "Vertical"
        addon:PrintMsg("Stacking mode is now |cFF00FF00" .. modeDesc .. "|r.")
    elseif cmd == "combat" then
        db.hideInCombat = not db.hideInCombat
        addon:UpdateOptionsUI()
        addon:UpdateLayout()
        local status = db.hideInCombat and "|cFF00FF00Enabled (Hiding in combat)|r" or "|cFFFF0000Disabled (Always visible)|r"
        addon:PrintMsg("Hide in combat is now " .. status .. ".")
    elseif cmd:find("^spacing") or cmd:find("^gap") then
        local val = tonumber(cmd:match("%d+"))
        if val ~= nil then
            val = math_max(0, math_min(50, math_floor(val + 0.5)))
            db.barSpacing = val
            addon:UpdateLayout()
            addon:UpdateOptionsUI()
            addon:PrintMsg("Bar spacing set to |cFF00FF00" .. val .. " px|r.")
        else
            addon:PrintMsg("Current bar spacing is |cFF00FF00" .. (db.barSpacing or 4) .. " px|r. Usage: |cFFFFD100/perfb spacing <0-50>|r")
        end
    elseif cmd == "reset" then
        db.point = "CENTER"
        db.relativePoint = "CENTER"
        db.xOfs = 0
        db.yOfs = -160
        addon:RestorePosition()
        addon:PrintMsg("Frame position reset to screen center.")
    elseif cmd == "status" then
        local function ColorBool(val) return val and "|cFF00FF00[ON]|r" or "|cFFFF0000[OFF]|r" end
        addon:PrintMsg("Current Configuration:")
        print(string.format("  Master Enable:    %s", ColorBool(db.enabled)))
        print(string.format("  Show FPS Bar:     %s", ColorBool(db.showFps)))
        print(string.format("  Show World Bar:   %s", ColorBool(db.showWorld)))
        print(string.format("  Show Home Bar:    %s", ColorBool(db.showHome)))
        print(string.format("  Stacking Mode:    |cFF00FF00%s|r", (db.stackingMode == "HORIZONTAL") and "Horizontal" or "Vertical"))
        print(string.format("  Frame Locked:     %s", ColorBool(db.locked)))
        print(string.format("  Hide in Combat:   %s", ColorBool(db.hideInCombat)))
        print(string.format("  Auto-Detect FPS:  %s", ColorBool(db.autoFpsCap ~= false)))
        print(string.format("  Active FPS Scale: %d FPS", math_floor(addon.activeFpsCap)))
        print(string.format("  Bar Dimensions:   %d x %d px", db.barWidth, db.barHeight))
        print(string.format("  Bar Spacing:      %d px", db.barSpacing or 4))
        print(string.format("  Background Opacity: %d%%", db.bgAlpha ~= nil and db.bgAlpha or 25))
    elseif cmd:find("^opacity") or cmd:find("^alpha") or cmd:find("^bg") then
        local val = tonumber(cmd:match("%d+"))
        if val ~= nil then
            val = math_max(0, math_min(100, math_floor(val + 0.5)))
            db.bgAlpha = val
            addon:UpdateLayout()
            addon:UpdateOptionsUI()
            addon:PrintMsg("Background opacity set to |cFF00FF00" .. val .. "%|r.")
        else
            addon:PrintMsg("Current background opacity is |cFF00FF00" .. (db.bgAlpha ~= nil and db.bgAlpha or 25) .. "%|r. Usage: |cFFFFD100/perfb opacity <0-100>|r")
        end
    elseif cmd == "help" or cmd == "?" then
        addon:PrintMsg("Commands:")
        print("  |cFFFFD100/perfb|r - Open settings panel")
        print("  |cFFFFD100/perfb toggle|r - Toggle performance HUD on/off")
        print("  |cFFFFD100/perfb lock|r - Toggle frame position lock")
        print("  |cFFFFD100/perfb fps|r - Toggle FPS bar visibility")
        print("  |cFFFFD100/perfb world|r - Toggle World latency bar visibility")
        print("  |cFFFFD100/perfb home|r - Toggle Home latency bar visibility")
        print("  |cFFFFD100/perfb stack [horiz|vert]|r - Switch horizontal or vertical layout")
        print("  |cFFFFD100/perfb spacing <0-50>|r - Adjust spacing between stacked bars in pixels")
        print("  |cFFFFD100/perfb opacity <0-100>|r - Adjust background opacity percentage")
        print("  |cFFFFD100/perfb combat|r - Toggle auto-hiding during combat")
        print("  |cFFFFD100/perfb reset|r - Reset frame position to center")
        print("  |cFFFFD100/perfb status|r - Display current configuration")
        print("  |cFFFFD100/perfb help|r or |cFFFFD100/perfb ?|r - Show this list of commands")
    else
        addon:PrintMsg("Unknown command '|cFFFFD100" .. cmd .. "|r'. Type |cFFFFD100/perfb help|r for available commands.")
    end
end

SLASH_PERFBIGGINS1 = "/perfb"
SlashCmdList["PERFBIGGINS"] = SlashHandler
