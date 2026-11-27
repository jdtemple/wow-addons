--[[ ==============================================================================
    LazySpeed Biggins v4.3.1 - High-Performance Movement & Flight Telemetry HUD
    ------------------------------------------------------------------------------
    Author: Biggins (Original logic by Darthterac)
    Compatibility: World of Warcraft: Midnight / The War Within (Patch 11.x - 12.x)
    License: All Rights Reserved
============================================================================== ]]--

local addonName, addon = ...
_G["LazySpeedBiggins"] = addon
addon.version = "4.3.1"
_G["LazySpeedBiggins_Version"] = "4.3.1"

-- Cache global functions
local CreateFrame         = CreateFrame
local GetUnitSpeed        = GetUnitSpeed
local IsFlying            = IsFlying
local IsSwimming          = IsSwimming
local tonumber            = tonumber
local pairs               = pairs
local string_format       = string.format
local DEFAULT_CHAT_FRAME  = DEFAULT_CHAT_FRAME
local Settings            = Settings

local GetGlidingInfo      = C_PlayerInfo and C_PlayerInfo.GetGlidingInfo

-- ==============================================================================
-- EVENT CONTROLLER & PASSIVE WATCHER (Low-Frequency Background Gating)
-- ==============================================================================
local EventWatcherFrame = CreateFrame("Frame")

EventWatcherFrame:RegisterEvent("ADDON_LOADED")                -- SavedVariables ready
EventWatcherFrame:RegisterEvent("PLAYER_ENTERING_WORLD")       -- Login or zoning
EventWatcherFrame:RegisterEvent("PLAYER_REGEN_DISABLED")        -- Entering combat
EventWatcherFrame:RegisterEvent("PLAYER_REGEN_ENABLED")         -- Exiting combat
EventWatcherFrame:RegisterEvent("PLAYER_MOUNT_DISPLAY_CHANGED") -- Mounting / Dismounting
EventWatcherFrame:RegisterEvent("SPELL_UPDATE_CHARGES")        -- Vigor / Surge Forward charges update
EventWatcherFrame:RegisterEvent("UPDATE_SHAPESHIFT_FORM")      -- Flight style / stance update
EventWatcherFrame:RegisterEvent("CHALLENGE_MODE_START")         -- Mythic+ key started
EventWatcherFrame:RegisterEvent("CHALLENGE_MODE_COMPLETED")     -- Mythic+ key completed
EventWatcherFrame:RegisterEvent("CHALLENGE_MODE_RESET")         -- Mythic+ key reset
EventWatcherFrame:RegisterEvent("ZONE_CHANGED_NEW_AREA")        -- Zone change
EventWatcherFrame:RegisterUnitEvent("UNIT_AURA", "player")     -- Aura/buff updates (Thrill/Skim)

EventWatcherFrame:SetScript("OnEvent", function(self, event, arg1)
    if event == "ADDON_LOADED" and arg1 == "LazySpeedBiggins" then
        LazySpeedBigginsDB = LazySpeedBigginsDB or {}

        for key, value in pairs(addon.DB_DEFAULTS) do
            if LazySpeedBigginsDB[key] == nil then
                LazySpeedBigginsDB[key] = value
            end
        end

        addon:RestorePosition()
        addon:UpdateLayout()
        addon:InitializeBlizzardSettings()

    elseif event == "PLAYER_REGEN_DISABLED" then
        local hideCombat = (LazySpeedBigginsDB and LazySpeedBigginsDB.hideInCombat)
        if hideCombat ~= false then
            LazySpeed_StopEngine()
        end

    elseif event == "CHALLENGE_MODE_START" then
        LazySpeed_StopEngine()

    elseif event == "PLAYER_REGEN_ENABLED" or event == "PLAYER_ENTERING_WORLD" or event == "PLAYER_MOUNT_DISPLAY_CHANGED"
        or event == "SPELL_UPDATE_CHARGES" or event == "UPDATE_SHAPESHIFT_FORM"
        or event == "CHALLENGE_MODE_COMPLETED" or event == "CHALLENGE_MODE_RESET" or event == "ZONE_CHANGED_NEW_AREA" then
        addon:UpdateLayout()
    end
end)

-- Passive Takeoff / Dive / Resume Detector (Runs at low 4 Hz / every 0.25s while inactive)
local passivePollTimer = 0
EventWatcherFrame:SetScript("OnUpdate", function(self, elapsed)
    local db = LazySpeedBigginsDB or addon.DB_DEFAULTS

    if addon.isEngineActive then return end
    if db.hideInCombat and addon:IsPlayerInCombat() then return end

    passivePollTimer = passivePollTimer + elapsed
    if passivePollTimer < 0.25 then return end
    passivePollTimer = 0

    if addon:IsRestrictedEnvironment() then return end

    local testSpeed = GetUnitSpeed("player")
    if addon:IsSecret(testSpeed) then return end

    if db.showGround then
        addon:UpdateLayout()
        return
    end

    local isGliding = GetGlidingInfo and GetGlidingInfo()
    if addon:IsSecret(isGliding) then return end

    local isSteadyFlying = IsFlying and IsFlying()
    local isSwimming = IsSwimming and IsSwimming()
    if addon:IsSecret(isSteadyFlying) or addon:IsSecret(isSwimming) then return end

    local isAirborne = isGliding or isSteadyFlying
    local isSkyriding = addon:IsInSkyridingMode()
    local isVigorNeeded = false
    if isSkyriding and (db.showVigor ~= false) then
        if db.hideVigorWhenFull then
            local charges, maxCharges = addon:GetSurgeForwardCharges()
            if charges and maxCharges and (charges < maxCharges) then
                isVigorNeeded = true
            end
        else
            isVigorNeeded = true
        end
    end

    if (isAirborne and db.showFlying) or (isSwimming and db.showSwimming) or isVigorNeeded then
        addon:UpdateLayout()
    end
end)

-- ==============================================================================
-- SLASH COMMANDS (/lazyspeedb)
-- ==============================================================================
SLASH_LAZYSPEED1 = "/lazyspeedb"
SlashCmdList["LAZYSPEED"] = function(msg)
    local command = msg:lower():trim()
    local db = LazySpeedBigginsDB or addon.DB_DEFAULTS

    if command == "" or command == "options" or command == "config" or command == "settings" then
        local catID = _G["LazySpeedBiggins_CategoryID"]
        if catID and Settings and Settings.OpenToCategory then
            Settings.OpenToCategory(catID)
        elseif Settings and Settings.OpenToCategory then
            Settings.OpenToCategory("LazySpeed Biggins")
        else
            DEFAULT_CHAT_FRAME:AddMessage("|cFFFFD100LazySpeed Biggins|r: Options available in Game Menu -> Options -> AddOns -> LazySpeed Biggins.")
        end
    elseif command == "toggle" then
        if not LazySpeedBigginsDB then LazySpeedBigginsDB = {} end
        LazySpeedBigginsDB.enabled = not (LazySpeedBigginsDB.enabled ~= false)
        addon:UpdateOptionsUI()
        addon:UpdateLayout()
        local status = LazySpeedBigginsDB.enabled and "|cFF00FF00Enabled|r" or "|cFFFF0000Disabled|r"
        DEFAULT_CHAT_FRAME:AddMessage("|cFFFFD100LazySpeed Biggins|r: HUD is now " .. status .. ".")
    elseif command == "vigor" then
        if not LazySpeedBigginsDB then LazySpeedBigginsDB = {} end
        LazySpeedBigginsDB.showVigor = not (LazySpeedBigginsDB.showVigor ~= false)
        addon:UpdateOptionsUI()
        addon:UpdateLayout()
        local status = LazySpeedBigginsDB.showVigor and "|cFF00FF00Enabled|r" or "|cFFFF0000Disabled|r"
        DEFAULT_CHAT_FRAME:AddMessage("|cFFFFD100LazySpeed Biggins|r: Skyriding Vigor bar is now " .. status .. ".")
    elseif command == "vigorfull" or command == "hidefull" then
        if not LazySpeedBigginsDB then LazySpeedBigginsDB = {} end
        LazySpeedBigginsDB.hideVigorWhenFull = not (LazySpeedBigginsDB.hideVigorWhenFull or false)
        addon:UpdateOptionsUI()
        addon:UpdateLayout()
        local status = LazySpeedBigginsDB.hideVigorWhenFull and "|cFF00FF00Enabled|r" or "|cFFFF0000Disabled|r"
        DEFAULT_CHAT_FRAME:AddMessage("|cFFFFD100LazySpeed Biggins|r: Hide Vigor bar when full is now " .. status .. ".")
    elseif command == "aura" or command == "glow" or command == "flame" then
        if not LazySpeedBigginsDB then LazySpeedBigginsDB = {} end
        LazySpeedBigginsDB.showVigorGlow = not (LazySpeedBigginsDB.showVigorGlow ~= false)
        if not LazySpeedBigginsDB.showVigorGlow then
            addon:HideFlameAura()
        end
        addon:UpdateOptionsUI()
        addon:UpdateLayout()
        local status = LazySpeedBigginsDB.showVigorGlow and "|cFF00FF00Enabled|r" or "|cFFFF0000Disabled|r"
        DEFAULT_CHAT_FRAME:AddMessage("|cFFFFD100LazySpeed Biggins|r: Recharge buff glow is now " .. status .. ".")
    elseif command == "stack" or command == "mode" or command:find("^stack ") or command:find("^mode ") then
        local sub = command:gsub("^[a-z]+%s*", "")
        if sub == "horizontal" or sub == "horiz" or sub == "h" then
            db.stackingMode = "HORIZONTAL"
        elseif sub == "vertical" or sub == "vert" or sub == "v" then
            db.stackingMode = "VERTICAL"
        else
            db.stackingMode = (db.stackingMode == "HORIZONTAL") and "VERTICAL" or "HORIZONTAL"
        end
        addon:UpdateLayout()
        addon:UpdateOptionsUI()
        local modeDesc = (db.stackingMode == "HORIZONTAL") and "Horizontal" or "Vertical"
        DEFAULT_CHAT_FRAME:AddMessage("|cFFFFD100LazySpeed Biggins|r: Stacking mode is now |cFF00FF00" .. modeDesc .. "|r.")
    elseif command == "lock" then
        if not LazySpeedBigginsDB then LazySpeedBigginsDB = {} end
        LazySpeedBigginsDB.locked = not (LazySpeedBigginsDB.locked or false)
        addon:UpdateMouseInteractivity()
        addon:UpdateOptionsUI()
        local status = LazySpeedBigginsDB.locked and "|cFFFF0000Locked|r" or "|cFF00FF00Unlocked|r"
        DEFAULT_CHAT_FRAME:AddMessage("|cFFFFD100LazySpeed Biggins|r: Frame position is now " .. status .. ".")
    elseif command:find("^spacing") or command:find("^gap") then
        local val = tonumber(command:match("%d+"))
        if val ~= nil then
            val = math.max(0, math.min(50, math.floor(val + 0.5)))
            db.barSpacing = val
            addon:UpdateLayout()
            addon:UpdateOptionsUI()
            DEFAULT_CHAT_FRAME:AddMessage("|cFFFFD100LazySpeed Biggins|r: Bar spacing set to |cFF00FF00" .. val .. " px|r.")
        else
            DEFAULT_CHAT_FRAME:AddMessage("|cFFFFD100LazySpeed Biggins|r: Current bar spacing is |cFF00FF00" .. (db.barSpacing or 4) .. " px|r. Usage: |cFFFFD100/lazyspeedb spacing <0-50>|r")
        end
    elseif command == "defaults" or command == "reset defaults" then
        addon:ResetAllToDefaults()
    elseif command == "reset" then
        if not LazySpeedBigginsDB then LazySpeedBigginsDB = {} end
        LazySpeedBigginsDB.point = "CENTER"
        LazySpeedBigginsDB.relativePoint = "CENTER"
        LazySpeedBigginsDB.xOfs = 0
        LazySpeedBigginsDB.yOfs = -200
        addon:RestorePosition()
        addon:UpdateLayout()
        DEFAULT_CHAT_FRAME:AddMessage("|cFFFFD100LazySpeed Biggins|r: Frame position reset to center.")
    elseif command == "status" then
        local function ColorBool(val) return val and "|cFF00FF00[ON]|r" or "|cFFFF0000[OFF]|r" end
        DEFAULT_CHAT_FRAME:AddMessage("|cFFFFD100LazySpeed Biggins|r Current Configuration:")
        DEFAULT_CHAT_FRAME:AddMessage(string_format("  Master Enable:    %s", ColorBool(db.enabled ~= false)))
        DEFAULT_CHAT_FRAME:AddMessage(string_format("  Stacking Mode:    |cFF00FF00%s|r", (db.stackingMode == "HORIZONTAL") and "Horizontal" or "Vertical"))
        DEFAULT_CHAT_FRAME:AddMessage(string_format("  Frame Locked:     %s", ColorBool(db.locked or false)))
        DEFAULT_CHAT_FRAME:AddMessage(string_format("  Show Flying:      %s", ColorBool(db.showFlying)))
        DEFAULT_CHAT_FRAME:AddMessage(string_format("  Show Swimming:    %s", ColorBool(db.showSwimming)))
        DEFAULT_CHAT_FRAME:AddMessage(string_format("  Show Ground:      %s", ColorBool(db.showGround)))
        DEFAULT_CHAT_FRAME:AddMessage(string_format("  Show Vigor Bar:   %s", ColorBool(db.showVigor ~= false)))
        DEFAULT_CHAT_FRAME:AddMessage(string_format("  Hide Vigor Full:  %s", ColorBool(db.hideVigorWhenFull or false)))
        DEFAULT_CHAT_FRAME:AddMessage(string_format("  Show Buff Glow:   %s", ColorBool(db.showVigorGlow ~= false)))
        DEFAULT_CHAT_FRAME:AddMessage(string_format("  Hide in Combat:   %s", ColorBool(db.hideInCombat)))
        DEFAULT_CHAT_FRAME:AddMessage(string_format("  Measurement Unit: %s", addon.modeLabels[db.unitMode or 4] or "%"))
        DEFAULT_CHAT_FRAME:AddMessage(string_format("  Bar Dimensions:   %d x %d px", db.barWidth or 180, db.barHeight or 22))
        DEFAULT_CHAT_FRAME:AddMessage(string_format("  Bar Spacing:      %d px", db.barSpacing or 4))
        DEFAULT_CHAT_FRAME:AddMessage(string_format("  Background Opacity: %d%%", db.bgAlpha ~= nil and db.bgAlpha or 25))
    elseif command:find("^opacity") or command:find("^alpha") or command:find("^bg") then
        local val = tonumber(command:match("%d+"))
        if val ~= nil then
            val = math.max(0, math.min(100, math.floor(val + 0.5)))
            db.bgAlpha = val
            addon:UpdateLayout()
            addon:UpdateOptionsUI()
            DEFAULT_CHAT_FRAME:AddMessage("|cFFFFD100LazySpeed Biggins|r: Background opacity set to |cFF00FF00" .. val .. "%|r.")
        else
            DEFAULT_CHAT_FRAME:AddMessage("|cFFFFD100LazySpeed Biggins|r: Current background opacity is |cFF00FF00" .. (db.bgAlpha ~= nil and db.bgAlpha or 25) .. "%|r. Usage: |cFFFFD100/lazyspeedb opacity <0-100>|r")
        end
    elseif command == "help" or command == "?" then
        DEFAULT_CHAT_FRAME:AddMessage("|cFFFFD100LazySpeed Biggins:|r Commands:")
        DEFAULT_CHAT_FRAME:AddMessage("  |cFFFFD100/lazyspeedb|r - Open options menu")
        DEFAULT_CHAT_FRAME:AddMessage("  |cFFFFD100/lazyspeedb toggle|r - Toggle master HUD on/off")
        DEFAULT_CHAT_FRAME:AddMessage("  |cFFFFD100/lazyspeedb vigor|r - Toggle Skyriding Vigor bar on/off")
        DEFAULT_CHAT_FRAME:AddMessage("  |cFFFFD100/lazyspeedb vigorfull|r - Toggle hiding Vigor bar when full")
        DEFAULT_CHAT_FRAME:AddMessage("  |cFFFFD100/lazyspeedb glow|r (or |cFFFFD100/lazyspeedb aura|r) - Toggle recharge buff glow on/off")
        DEFAULT_CHAT_FRAME:AddMessage("  |cFFFFD100/lazyspeedb stack [horiz/vert]|r - Switch horizontal or vertical layout")
        DEFAULT_CHAT_FRAME:AddMessage("  |cFFFFD100/lazyspeedb spacing <0-50>|r - Adjust spacing between stacked bars in pixels")
        DEFAULT_CHAT_FRAME:AddMessage("  |cFFFFD100/lazyspeedb opacity <0-100>|r - Adjust background opacity percentage")
        DEFAULT_CHAT_FRAME:AddMessage("  |cFFFFD100/lazyspeedb lock|r - Toggle locking frame position")
        DEFAULT_CHAT_FRAME:AddMessage("  |cFFFFD100/lazyspeedb reset|r - Reset frame position to center")
        DEFAULT_CHAT_FRAME:AddMessage("  |cFFFFD100/lazyspeedb defaults|r - Reset all options to default")
        DEFAULT_CHAT_FRAME:AddMessage("  |cFFFFD100/lazyspeedb status|r - Display current configuration")
        DEFAULT_CHAT_FRAME:AddMessage("  |cFFFFD100/lazyspeedb help|r or |cFFFFD100/lazyspeedb ?|r - Show this list of commands")
    else
        DEFAULT_CHAT_FRAME:AddMessage("|cFFFFD100LazySpeed Biggins:|r Unknown command '|cFFFFD100" .. command .. "|r'. Type |cFFFFD100/lazyspeedb help|r for available commands.")
    end
end
