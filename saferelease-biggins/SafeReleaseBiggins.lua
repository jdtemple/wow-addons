--[[ ==============================================================================
    SafeRelease Biggins v1.1.2 - Release Spirit Guard (Raids, Dungeons & Delves)
    ------------------------------------------------------------------------------
    Author: Biggins (US-Whisperwind)
    Compatibility: World of Warcraft: Midnight / The War Within (Patch 11.x - 12.x)

    ARCHITECTURAL OVERVIEW:
    1. Zero-Taint Secure Frame Hooking: Hooks StaticPopup frames securely via
       hooksecurefunc without tampering with Blizzard protected frame scripts.
    2. Click-Interception Overlay: Places an inert, non-interactive overlay button
       directly on top of the native Release button during lockouts, making early
       release physically impossible even with high-frequency mouse spam.
    3. Multiple Guard Modes:
         - Countdown Delay: Visual countdown timer (1-10s) on the button.
         - Modifier Hold: Requires holding Alt, Shift, or Ctrl to release.
         - Hybrid: Visual countdown with an instant modifier-key bypass.
    4. Full Raid Wipe Detection: Automatically bypasses the guard if all group
       members are confirmed dead.
    5. Modular Architecture:
       - Core/State.lua: Configuration defaults, context evaluation, and wipe checks.
       - Modules/Overlay.lua: Click-interception overlay button and StaticPopup hooks.
       - Core/Options.lua: Blizzard Settings canvas UI and control toggles.
       - SafeReleaseBiggins.lua: Lifecycle events and /safereleaseb slash command router.
============================================================================== ]]--

local addonName, addon = ...
_G["SafeReleaseBiggins"] = addon
addon.version = "1.1.2"

-- Cache global functions
local CreateFrame  = CreateFrame
local pairs        = pairs
local strtrim      = strtrim
local string       = string
local print        = print
local tonumber     = tonumber
local math_floor   = math.floor
local math_max     = math.max
local math_min     = math.min

-- ==============================================================================
-- EVENT LISTENER FRAME & POPUP HOOK INITIALIZATION
-- ==============================================================================

local frame = CreateFrame("Frame")
frame:RegisterEvent("ADDON_LOADED")
frame:RegisterEvent("MODIFIER_STATE_CHANGED")
frame:RegisterEvent("PLAYER_REGEN_ENABLED")

frame:SetScript("OnEvent", function(self, event, ...)
    if event == "ADDON_LOADED" then
        local loaded = ...
        if loaded == addonName then
            if not SafeReleaseBigginsDB then
                SafeReleaseBigginsDB = {}
            end
            for k, v in pairs(addon.defaults) do
                if SafeReleaseBigginsDB[k] == nil then
                    SafeReleaseBigginsDB[k] = v
                end
            end
            addon:RegisterOptions()
            addon:HookStaticPopups()
        end
    elseif event == "MODIFIER_STATE_CHANGED" then
        addon:OnModifierStateChanged()
    elseif event == "PLAYER_REGEN_ENABLED" then
        addon:OnRegenEnabled()
    end
end)

-- ==============================================================================
-- SLASH COMMAND HANDLER (/safereleaseb)
-- ==============================================================================

local function SlashHandler(msg)
    local text = strtrim(msg or "")
    local cmd, arg = text:match("^(%S+)%s*(.*)$")
    cmd = string.lower(cmd or "")
    arg = string.lower(strtrim(arg or ""))
    local db = SafeReleaseBigginsDB or addon.defaults

    if cmd == "" or cmd == "options" or cmd == "config" then
        addon:OpenSettings()
    elseif cmd == "toggle" then
        db.enabled = not db.enabled
        addon:UpdateOptionsUI()
        local status = db.enabled and "|cFF00FF00Enabled|r" or "|cFFFF0000Disabled|r"
        addon:PrintMsg("Master release guard is now " .. status .. ".")
    elseif cmd == "countdown" or cmd == "timer" then
        db.mode = "COUNTDOWN"
        addon:UpdateOptionsUI()
        addon:PrintMsg("Guard mode set to |cFF00FF00Countdown Timer|r.")
    elseif cmd == "modifier" or cmd == "mod" or cmd == "key" then
        if arg == "alt" or arg == "shift" or arg == "ctrl" then
            db.modifierKey = string.upper(arg)
            addon:UpdateOptionsUI()
            addon:PrintMsg(string.format("Modifier key set to |cFF00FF00%s|r.", db.modifierKey))
        else
            db.mode = "MODIFIER"
            addon:UpdateOptionsUI()
            addon:PrintMsg(string.format("Guard mode set to |cFF00FF00Modifier Hold (%s)|r. (Use |cFFFFD100/safereleaseb mod alt|shift|ctrl|r to change key)", addon:GetModifierDisplayName(db.modifierKey)))
        end
    elseif cmd == "hybrid" then
        db.mode = "HYBRID"
        addon:UpdateOptionsUI()
        addon:PrintMsg(string.format("Guard mode set to |cFF00FF00Hybrid (Countdown with %s bypass)|r.", addon:GetModifierDisplayName(db.modifierKey)))
    elseif cmd == "delay" or cmd == "time" then
        local sec = tonumber(arg)
        if sec then
            sec = math_floor(math_max(1, math_min(10, sec)))
            db.delaySeconds = sec
            addon:UpdateOptionsUI()
            addon:PrintMsg(string.format("Countdown delay set to |cFF00FF00%d seconds|r.", sec))
        else
            addon:PrintMsg(string.format("Current countdown delay is |cFFFFD100%d seconds|r. Usage: |cFFFFD100/safereleaseb delay <1-10>|r", db.delaySeconds or 5))
        end
    elseif cmd == "raids" then
        db.raids = not db.raids
        addon:UpdateOptionsUI()
        local status = db.raids and "|cFF00FF00Enabled|r" or "|cFFFF0000Disabled|r"
        addon:PrintMsg("Raid protection is now " .. status .. ".")
    elseif cmd == "defaults" or cmd == "reset" then
        if not SafeReleaseBigginsDB then SafeReleaseBigginsDB = {} end
        for k, v in pairs(addon.defaults) do
            SafeReleaseBigginsDB[k] = v
        end
        addon:UpdateOptionsUI()
        addon:PrintMsg("All options have been reset to default.")
    elseif cmd == "status" then
        local function ColorBool(val) return val and "|cFF00FF00[ON]|r" or "|cFFFF0000[OFF]|r" end
        addon:PrintMsg("Current Configuration:")
        print(string.format("  Master Enable:   %s", ColorBool(db.enabled)))
        print(string.format("  Guard Mode:      |cFFFFD100%s|r", db.mode))
        print(string.format("  Delay Seconds:   |cFFFFD100%ds|r", db.delaySeconds or 5))
        print(string.format("  Modifier Key:    |cFFFFD100%s|r", addon:GetModifierDisplayName(db.modifierKey)))
        print(string.format("  Raids Protected: %s", ColorBool(db.raids)))
        print(string.format("  M+ Protected:    %s", ColorBool(db.mythicPlus)))
        print(string.format("  Dungeons:        %s", ColorBool(db.dungeons)))
        print(string.format("  Delves/Scenarios:%s", ColorBool(db.delves)))
        print(string.format("  Full Wipe Bypass:%s", ColorBool(db.bypassFullWipe)))
        print(string.format("  Chat Feedback:   %s", ColorBool(db.announce)))
    elseif cmd == "help" or cmd == "?" then
        addon:PrintMsg("Commands:")
        print("  |cFFFFD100/safereleaseb|r - Open settings panel")
        print("  |cFFFFD100/safereleaseb toggle|r - Toggle release guard on/off")
        print("  |cFFFFD100/safereleaseb countdown|r - Set guard mode to Countdown Timer")
        print("  |cFFFFD100/safereleaseb modifier|r - Set guard mode to Modifier Key hold")
        print("  |cFFFFD100/safereleaseb hybrid|r - Set guard mode to Hybrid (countdown + key bypass)")
        print("  |cFFFFD100/safereleaseb mod <alt|shift|ctrl>|r - Set modifier bypass key")
        print("  |cFFFFD100/safereleaseb delay <1-10>|r - Set countdown delay in seconds")
        print("  |cFFFFD100/safereleaseb raids|r - Toggle raid protection")
        print("  |cFFFFD100/safereleaseb status|r - Display current configuration")
        print("  |cFFFFD100/safereleaseb defaults|r - Reset all settings to defaults")
        print("  |cFFFFD100/safereleaseb help|r or |cFFFFD100/safereleaseb ?|r - Show this list of commands")
    else
        addon:PrintMsg("Unknown command '|cFFFFD100" .. cmd .. "|r'. Type |cFFFFD100/safereleaseb help|r for available commands.")
    end
end

SLASH_SAFERELEASEBIGGINS1 = "/safereleaseb"
SlashCmdList["SAFERELEASEBIGGINS"] = SlashHandler
