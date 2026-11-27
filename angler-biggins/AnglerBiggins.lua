--[[ ==============================================================================
    Angler Biggins v2.2.2 - Dual-Rod Fishing Suite & Underlight Angler Automation
    ------------------------------------------------------------------------------
    Author: Biggins (US-Whisperwind)
    Compatibility: World of Warcraft: Midnight / The War Within (Patch 11.x - 12.x)
    License: All Rights Reserved
============================================================================== ]]--

local addonName, addon = ...
_G["AnglerBiggins"] = addon
addon.version = "2.2.2"

-- Cache global functions
local CreateFrame              = CreateFrame
local InCombatLockdown         = InCombatLockdown
local CopyTable                = CopyTable
local C_Timer                  = C_Timer
local Settings                 = Settings
local C_Item                   = C_Item
local pairs                    = pairs
local print                    = print

-- Configuration Defaults
addon.defaults = {
    enabled          = true,  -- Master addon toggle
    enableInstances  = true,  -- Activate in Dungeons & Raids
    enableDelves     = true,  -- Underwater Delves & Breath Meter detection
    enablePvP        = false, -- Battlegrounds & Arenas (Default: OFF)
    quiet            = true,  -- Suppress chat activation messages
    pinnedPoleID     = nil,   -- Item ID of secondary pinned fishing pole
    pinnedPoleName   = "None",-- Display name of secondary pinned fishing pole
    pinnedPoleIcon   = nil,   -- Icon texture of secondary pinned fishing pole
}

-- Print formatted addon message
function addon:PrintMsg(msg)
    DEFAULT_CHAT_FRAME:AddMessage("|cFFFFD100Angler Biggins:|r " .. msg)
end

-- ==============================================================================
-- EVENT DISPATCHER
-- ==============================================================================

local eventFrame = CreateFrame("Frame", "AnglerBigginsEventFrame")
eventFrame:RegisterEvent("ADDON_LOADED")
eventFrame:RegisterEvent("PLAYER_LOGIN")
eventFrame:RegisterEvent("PLAYER_ENTERING_WORLD")
eventFrame:RegisterEvent("MOUNT_JOURNAL_USABILITY_CHANGED")
eventFrame:RegisterEvent("MIRROR_TIMER_START")
eventFrame:RegisterEvent("MIRROR_TIMER_STOP")
eventFrame:RegisterEvent("PLAYER_REGEN_DISABLED")
eventFrame:RegisterEvent("PLAYER_REGEN_ENABLED")
eventFrame:RegisterEvent("PLAYER_EQUIPMENT_CHANGED")
eventFrame:RegisterUnitEvent("UNIT_AURA", "player")
eventFrame:RegisterUnitEvent("UNIT_SPELLCAST_STOP", "player")
eventFrame:RegisterUnitEvent("UNIT_SPELLCAST_CHANNEL_STOP", "player")

eventFrame:SetScript("OnEvent", function(self, event, arg1, ...)
    if event == "ADDON_LOADED" and arg1 == addonName then
        if not AnglerBigginsDB then
            AnglerBigginsDB = CopyTable(addon.defaults)
        else
            for k, v in pairs(addon.defaults) do
                if AnglerBigginsDB[k] == nil then
                    AnglerBigginsDB[k] = v
                end
            end
        end
        addon:SetupTooltipHook()
    elseif event == "PLAYER_LOGIN" then
        addon:CreateSettingsUI()
        addon:SetupTooltipHook()
        addon:UpdateMacro()
        C_Timer.After(0.5, function()
            addon:UpdateMacro()
        end)
    elseif event == "PLAYER_REGEN_DISABLED" then
        -- Combat drops Underlight Angler traits: reset awake state and abort any active queue
        addon.isAwake = false
        addon.isActivating = false
        addon.queue.unequip = false
        addon.queue.equip = nil
        addon.queueFrame:SetScript("OnUpdate", nil)
    elseif event == "PLAYER_REGEN_ENABLED" then
        -- Dropped combat: sync macro and evaluate water state
        addon.isAwake = false
        addon:UpdateMacro()
        C_Timer.After(0.4, function()
            if not InCombatLockdown() then
                addon:EvaluateWaterState()
            else
                C_Timer.After(0.4, function()
                    if not InCombatLockdown() then
                        addon:EvaluateWaterState()
                    end
                end)
            end
        end)
    elseif event == "PLAYER_EQUIPMENT_CHANGED" then
        if not addon.isActivating then
            if not addon:IsUnderlightSlotted() then
                addon.isAwake = false
            end
            if addon:IsUnderlightSlotted() and addon:IsPlayerInWater() and not addon:IsUnderlightAwake() then
                C_Timer.After(0.2, function()
                    addon:EvaluateWaterState()
                end)
            end
        end
        addon:UpdateMacro()
        if addon.optionsPanel and addon.optionsPanel:IsShown() then
            addon:UpdateOptionsUI()
        end
    elseif event == "UNIT_AURA" then
        if arg1 == "player" then
            -- Re-evaluate if the player is in water with Underlight slotted, not busy, and Underlight Angler is not awake
            if not addon:IsPlayerBusy() and not addon.isActivating and addon:IsPlayerInWater() and addon:IsUnderlightSlotted() and not addon:IsUnderlightAwake() then
                C_Timer.After(0.2, function()
                    addon:EvaluateWaterState()
                end)
            end
        end
    elseif event == "UNIT_SPELLCAST_STOP" or event == "UNIT_SPELLCAST_CHANNEL_STOP" then
        if arg1 == "player" then
            -- Completed casting/gathering (e.g. mining or herbing): evaluate water state if in water
            if not addon.isActivating and addon:IsPlayerInWater() and addon:IsUnderlightSlotted() then
                addon.isAwake = false
                C_Timer.After(0.3, function()
                    addon:EvaluateWaterState()
                end)
            end
        end
    elseif event == "MIRROR_TIMER_START" or event == "MIRROR_TIMER_STOP" or event == "MOUNT_JOURNAL_USABILITY_CHANGED" then
        -- Debounce rapid swimming state transitions
        C_Timer.After(0.2, function()
            addon:EvaluateWaterState()
        end)
    elseif event == "PLAYER_ENTERING_WORLD" then
        addon.isAwake = false
        -- Defer macro update until inventory settles from zone loading / teleporters
        C_Timer.After(0.5, function()
            addon:UpdateMacro()
        end)
        C_Timer.After(1.0, function()
            addon:UpdateMacro()
            addon:EvaluateWaterState()
        end)
    end
end)

-- ==============================================================================
-- SLASH COMMAND INTERFACE
-- ==============================================================================

SLASH_ANGLERBIGGINS1 = "/anglerb"

SlashCmdList["ANGLERBIGGINS"] = function(msg)
    local cmd = (msg or ""):trim():lower()
    local db = AnglerBigginsDB or addon.defaults

    if cmd == "pin" then
        addon:PinCurrentPole()
    elseif cmd == "button" or cmd == "macro" then
        addon:PickupActionButton()
    elseif cmd == "unpin" or cmd == "clear" then
        addon:ClearPinnedPole()
    elseif cmd == "swap" then
        addon:TogglePoles()
    elseif cmd == "toggle" then
        db.enabled = not db.enabled
        addon:PrintMsg("Master toggle: " .. (db.enabled and "|cFF00FF00Enabled|r" or "|cFFFF0000Disabled|r"))
        addon:UpdateOptionsUI()
        if db.enabled then addon:EvaluateWaterState() end
    elseif cmd == "instances" or cmd == "dungeons" or cmd == "raids" then
        db.enableInstances = not db.enableInstances
        addon:PrintMsg("Dungeons & Raids: " .. (db.enableInstances and "|cFF00FF00Enabled|r" or "|cFFFF0000Disabled|r"))
        addon:UpdateOptionsUI()
    elseif cmd == "delves" then
        db.enableDelves = not db.enableDelves
        addon:PrintMsg("Underwater Delves: " .. (db.enableDelves and "|cFF00FF00Enabled|r" or "|cFFFF0000Disabled|r"))
        addon:UpdateOptionsUI()
    elseif cmd == "wake" then
        addon.isAwake = false
        addon.lastActivationTime = 0
        addon:ActivateUnderlightAngler()
        addon:PrintMsg("Underlight Angler activation triggered.")
    elseif cmd == "status" then
        local equippedPoleID = addon:GetEquippedFishingPoleID()

        local equippedStr = "None"
        if equippedPoleID then
            local itemName, itemLink = C_Item.GetItemInfo(equippedPoleID)
            equippedStr = itemLink or itemName or ("Item ID: " .. equippedPoleID)
        end

        local inWater = addon:IsPlayerInWater() and "Submerged / Swimming" or "Dry Land"
        local awakeStr = addon:IsUnderlightSlotted() and (addon:IsUnderlightAwake() and "Awake" or "Dormant") or "N/A (Secondary Pole Active)"
        local tensionStr = addon:HasSurfaceTensionBuff() and "Active" or "Inactive"
        local pinnedStr = db.pinnedPoleName or "None"
        addon:PrintMsg("Status:")
        print("  - Addon State: " .. (db.enabled and "|cFF00FF00Enabled|r" or "|cFFFF0000Disabled|r"))
        print("  - Equipped Pole: |cFFFFD100" .. equippedStr .. "|r")
        print("  - Pinned Main Pole: |cFFFFD100" .. pinnedStr .. "|r")
        print("  - Trait State: |cFFFFD100" .. awakeStr .. "|r")
        print("  - Surface Tension Buff: |cFFFFD100" .. tensionStr .. "|r")
        print("  - Environment: |cFFFFD100" .. inWater .. "|r")
        print("  - Dungeons & Raids: " .. (db.enableInstances and "|cFF00FF00On|r" or "|cFFFF0000Off|r"))
        print("  - Underwater Delves: " .. (db.enableDelves and "|cFF00FF00On|r" or "|cFFFF0000Off|r"))
    elseif cmd == "help" or cmd == "?" then
        addon:PrintMsg("Commands:")
        print("  |cFFFFD100/anglerb|r - Open settings panel")
        print("  |cFFFFD100/anglerb pin|r - Pin currently equipped fishing pole as secondary rod")
        print("  |cFFFFD100/anglerb button|r - Put rod swap button onto cursor to place on action bar")
        print("  |cFFFFD100/anglerb swap|r - Manually swap between Underlight Angler and pinned pole")
        print("  |cFFFFD100/anglerb toggle|r - Toggle master automation on/off")
        print("  |cFFFFD100/anglerb wake|r - Re-engage Underlight Angler traits on demand")
        print("  |cFFFFD100/anglerb instances|r - Toggle activation in Dungeons & Raids")
        print("  |cFFFFD100/anglerb delves|r - Toggle underwater Delve & breath meter detection")
        print("  |cFFFFD100/anglerb status|r - Display current equipment, pinned pole, and buff state")
        print("  |cFFFFD100/anglerb help|r or |cFFFFD100/anglerb ?|r - Show this list of commands")
    else
        -- Open Settings Panel if empty or 'options'/'config', otherwise display help hint
        if cmd == "" or cmd == "options" or cmd == "config" then
            if addon.categoryID and Settings and Settings.OpenToCategory then
                Settings.OpenToCategory(addon.categoryID)
            else
                addon:PrintMsg("Type |cFFFFD100/anglerb help|r to view available commands.")
            end
        else
            addon:PrintMsg("Unknown command '|cFFFFD100" .. cmd .. "|r'. Type |cFFFFD100/anglerb help|r for available commands.")
        end
    end
end
