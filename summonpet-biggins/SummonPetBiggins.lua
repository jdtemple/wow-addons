--[[ ==============================================================================
    SummonPet Biggins v1.5.5
    ------------------------------------------------------------------------------
    Author: Biggins
    Credits: Inspired by Callie's (Caliaha) classic BartrubySummonPet
    Ultra-lightweight, event-driven companion pet summoner.

    Modular Architecture:
      - Core/Constants.lua: Defaults, grace period timers, environment state guards.
      - Core/Engine.lua: Companion summoning, debounced dismissal, pinning, journal search.
      - Modules/Watcher.lua: Mount touchdown watcher ticker, debounce timers, movement hooks.
      - Core/Options.lua: Blizzard Settings canvas UI, toggles, mode radio controls.
      - SummonPetBiggins.lua: Lifecycle event orchestration and slash command routing.
============================================================================== ]]--

local addonName, addon = ...
_G["SummonPetBiggins"] = addon
addon.version = "1.5.5"

-- Localize Keybinding Labels in WoW Settings
_G["BINDING_HEADER_SUMMONPETBIGGINS_HEADER"] = "SummonPet Biggins"
_G["BINDING_CATEGORY_SUMMONPETBIGGINS"] = "SummonPet Biggins"
_G["BINDING_NAME_SUMMONPETBIGGINS_TOGGLE"] = "Toggle Companion Summoning"
_G["BINDING_NAME_SUMMONPETBIGGINS_PIN"] = "Pin Currently Summoned Pet"

-- Cache global functions
local CreateFrame        = CreateFrame
local IsMounted          = IsMounted
local IsInInstance       = IsInInstance
local GetInstanceInfo    = GetInstanceInfo
local hooksecurefunc     = hooksecurefunc
local pcall              = pcall
local string             = string
local print              = print
local tostring           = tostring
local pairs              = pairs
local CopyTable          = CopyTable
local C_Timer            = C_Timer
local C_Scenario         = C_Scenario

local frame = CreateFrame("Frame")
frame:RegisterEvent("ADDON_LOADED")
frame:RegisterEvent("PLAYER_LOGIN")

-- Dedicated Event Handlers
local function OnPlayerDismounted()
    addon:ScheduleDismountSummon()
end

local function OnPlayerMounted()
    if not (SummonPetBigginsDB and SummonPetBigginsDB.summonWhileMounted) then
        addon:Dismiss(1)
        return
    end

    addon:StartMountWatcher()
    C_Timer.After(0.3, function()
        if IsMounted() and addon:CanSummon() then
            addon:Summon()
        end
    end)
end

local function OnMountDisplayChanged()
    addon:CancelDismountTimer()
    if not IsMounted() then
        OnPlayerDismounted()
    else
        OnPlayerMounted()
    end
end

local function OnPlayerUnstealthed()
    addon:ScheduleUnstealthSummon()
end

local function OnUpdateStealth()
    addon:CancelAllPendingSummons()
    if addon:IsStealthedActive() then
        if SummonPetBigginsDB and SummonPetBigginsDB.autoDismissInStealth then
            addon:Dismiss(1)
        end
        return
    end

    OnPlayerUnstealthed()
end

local function OnSpellcastStarted(unit)
    if unit ~= "player" then return end
    addon:CancelCastIdleTimer()
    addon:CancelUnstealthTimer()
    addon:CancelDismountTimer()
end

local function OnSpellcastStopped(unit)
    if unit ~= "player" then return end
    addon:ScheduleCastIdleSummon()
end

local function OnPlayerLogin(frameRef)
    -- Register game-state events
    frameRef:RegisterEvent("PLAYER_REGEN_ENABLED")         -- Left combat
    frameRef:RegisterEvent("PLAYER_MOUNT_DISPLAY_CHANGED") -- Mounted/Dismounted
    frameRef:RegisterEvent("UPDATE_STEALTH")               -- Stealthed/Unstealthed
    frameRef:RegisterEvent("PLAYER_ENTERING_WORLD")        -- Zone load
    frameRef:RegisterEvent("ZONE_CHANGED_NEW_AREA")        -- Zone/subzone transition
    frameRef:RegisterEvent("SCENARIO_UPDATE")              -- Scenario/Delve state change
    frameRef:RegisterEvent("CHALLENGE_MODE_START")         -- Mythic+ key started
    frameRef:RegisterEvent("CHALLENGE_MODE_COMPLETED")     -- Mythic+ key finished

    -- Register spellcast events for cast/channel idle debounce (player-filtered)
    frameRef:RegisterUnitEvent("UNIT_SPELLCAST_START", "player")
    frameRef:RegisterUnitEvent("UNIT_SPELLCAST_STOP", "player")
    frameRef:RegisterUnitEvent("UNIT_SPELLCAST_FAILED", "player")
    frameRef:RegisterUnitEvent("UNIT_SPELLCAST_INTERRUPTED", "player")
    frameRef:RegisterUnitEvent("UNIT_SPELLCAST_CHANNEL_START", "player")
    frameRef:RegisterUnitEvent("UNIT_SPELLCAST_CHANNEL_STOP", "player")

    -- Hook forward movement and autorun for grounded mount summoning
    if hooksecurefunc then
        pcall(hooksecurefunc, "MoveForwardStart", function() addon:OnMovementStart() end)
        pcall(hooksecurefunc, "ToggleAutoRun", function() addon:OnMovementStart() end)
    end

    -- Initial check after game world settles
    C_Timer.After(2.0, function()
        if addon:ShouldDismissMounted() then
            addon:Dismiss(1)
        else
            addon:Summon()
        end
    end)

    if IsMounted() and SummonPetBigginsDB and SummonPetBigginsDB.summonWhileMounted then
        addon:StartMountWatcher()
    end
end

local eventHandlers = {
    PLAYER_REGEN_ENABLED = function()
        if addon:ShouldDismissInStealth() or addon:ShouldDismissMounted() then
            addon:Dismiss(1)
        elseif addon:CanSummon() then
            addon:Summon()
        end
    end,

    PLAYER_MOUNT_DISPLAY_CHANGED = OnMountDisplayChanged,

    UPDATE_STEALTH = OnUpdateStealth,

    UNIT_SPELLCAST_START = function(unit)
        OnSpellcastStarted(unit)
    end,

    UNIT_SPELLCAST_CHANNEL_START = function(unit)
        OnSpellcastStarted(unit)
    end,

    UNIT_SPELLCAST_STOP = function(unit)
        OnSpellcastStopped(unit)
    end,

    UNIT_SPELLCAST_CHANNEL_STOP = function(unit)
        OnSpellcastStopped(unit)
    end,

    UNIT_SPELLCAST_FAILED = function(unit)
        OnSpellcastStopped(unit)
    end,

    UNIT_SPELLCAST_INTERRUPTED = function(unit)
        OnSpellcastStopped(unit)
    end,

    CHALLENGE_MODE_START = function()
        if SummonPetBigginsDB and SummonPetBigginsDB.autoDismissInstances and SummonPetBigginsDB.dismissMPlus then
            addon:Dismiss(1)
        end
    end,

    CHALLENGE_MODE_COMPLETED = function()
        if addon:CanSummon() then
            addon:Summon()
        end
    end,

    ZONE_CHANGED_NEW_AREA = function()
        if addon:ShouldDismissInCurrentInstance() then
            addon:Dismiss(1)
        end
    end,

    SCENARIO_UPDATE = function()
        if addon:ShouldDismissInCurrentInstance() then
            addon:Dismiss(1)
        end
    end,

    PLAYER_ENTERING_WORLD = function()
        if addon:ShouldDismissInCurrentInstance() or addon:ShouldDismissMounted() then
            addon:Dismiss(1)
            return
        end
        C_Timer.After(1.5, function()
            if addon:ShouldDismissInCurrentInstance() or addon:ShouldDismissMounted() then
                addon:Dismiss(1)
            else
                addon:Summon()
            end
        end)
    end,
}

-- Event Orchestration
frame:SetScript("OnEvent", function(self, event, ...)
    if event == "ADDON_LOADED" then
        local loadedAddon = ...
        if loadedAddon == addonName then
            if not SummonPetBigginsDB then
                SummonPetBigginsDB = CopyTable(addon.defaults)
            else
                -- Ensure any newly added default keys exist
                for k, v in pairs(addon.defaults) do
                    if SummonPetBigginsDB[k] == nil then
                        SummonPetBigginsDB[k] = v
                    end
                end
            end
            addon:RegisterOptions()
        end
        return
    end

    if event == "PLAYER_LOGIN" then
        OnPlayerLogin(self)
        return
    end

    local handler = eventHandlers[event]
    if handler then
        handler(...)
    end
end)

-- Slash Commands (/summonpetb)
SLASH_SUMMONPETBIGGINS1 = "/summonpetb"
SlashCmdList["SUMMONPETBIGGINS"] = function(msg)
    local raw = msg and msg:trim() or ""
    local cmd, arg = raw:match("^(%S+)%s*(.*)$")
    cmd = cmd and cmd:lower() or ""
    arg = arg and arg:trim() or ""

    if cmd == "" or cmd == "options" or cmd == "config" or cmd == "menu" then
        addon:OpenSettings()
    elseif cmd == "toggle" then
        addon:Toggle()
    elseif cmd == "pin" then
        if arg ~= "" then
            addon:PinPetByName(arg)
        else
            addon:PinCurrentPet()
        end
    elseif cmd == "fav" or cmd == "favorites" then
        addon:SetMode("FAVORITES")
    elseif cmd == "random" or cmd == "rand" then
        addon:SetMode("RANDOM")
    elseif cmd == "mount" or cmd == "mounted" then
        SummonPetBigginsDB.summonWhileMounted = not SummonPetBigginsDB.summonWhileMounted
        local st = SummonPetBigginsDB.summonWhileMounted and "|cFF00FF00Enabled|r" or "|cFFFF0000Disabled|r"
        addon:PrintMsg("Summon while mounted: " .. st .. ".")
        addon:UpdateOptionsUI()
        if SummonPetBigginsDB.summonWhileMounted then
            if IsMounted() then
                addon:StartMountWatcher()
                if not addon:IsMountedBlocked() then addon:Summon() end
            end
        else
            addon:StopMountWatcher()
            if IsMounted() then addon:Dismiss(1) end
        end
    elseif cmd == "status" then
        local st = SummonPetBigginsDB.enabled and "|cFF00FF00Enabled|r" or "|cFFFF0000Disabled|r"
        local mt = SummonPetBigginsDB.summonWhileMounted and "|cFF00FF00Yes|r" or "|cFFFF0000No|r"
        addon:PrintMsg("v" .. addon.version .. " | Auto-summon: " .. st .. " | Mode: |cFF00FF00" .. SummonPetBigginsDB.mode .. "|r | Mounted: " .. mt .. " | Pinned: |cFF00FF00" .. (SummonPetBigginsDB.pinnedPetName or "None") .. "|r")
        local inInst, instType = IsInInstance()
        local name, _, diffID = GetInstanceInfo()
        local isScen = (C_Scenario and C_Scenario.IsInScenario and C_Scenario.IsInScenario()) and "Yes" or "No"
        local shouldDismiss = addon:ShouldDismissInCurrentInstance() and "|cFFFF0000Dismiss|r" or "|cFF00FF00Keep/Summon|r"
        addon:PrintMsg(string.format("Zone Diagnostics: Name='%s' | InInst=%s | Type=%s | DiffID=%s | Scenario=%s -> Status: %s",
            name or "None", tostring(inInst), tostring(instType), tostring(diffID), isScen, shouldDismiss))
        addon:PrintMsg(string.format("Instance Toggles: Master=%s | Raids=%s | M+=%s | Dungeons=%s | Delves/Lab=%s",
            tostring(SummonPetBigginsDB.autoDismissInstances),
            tostring(SummonPetBigginsDB.dismissRaids),
            tostring(SummonPetBigginsDB.dismissMPlus),
            tostring(SummonPetBigginsDB.dismissDungeons),
            tostring(SummonPetBigginsDB.dismissDelves)))
    elseif cmd == "help" or cmd == "?" then
        addon:PrintMsg("Commands:")
        print("  |cFFFFD100/summonpetb|r - Open settings panel")
        print("  |cFFFFD100/summonpetb toggle|r - Toggle companion auto-summoning on/off")
        print("  |cFFFFD100/summonpetb pin [name]|r - Pin current pet, or search and summon by name")
        print("  |cFFFFD100/summonpetb fav|r - Set mode to random favorites")
        print("  |cFFFFD100/summonpetb random|r - Set mode to completely random")
        print("  |cFFFFD100/summonpetb mount|r - Toggle companion summoning while mounted on ground")
        print("  |cFFFFD100/summonpetb options|r - Open settings panel")
        print("  |cFFFFD100/summonpetb status|r - Display current configuration")
        print("  |cFFFFD100/summonpetb help|r or |cFFFFD100/summonpetb ?|r - Show this list of commands")
    else
        addon:PrintMsg("Unknown command '|cFFFFD100" .. cmd .. "|r'. Type |cFFFFD100/summonpetb help|r for available commands.")
    end
end
