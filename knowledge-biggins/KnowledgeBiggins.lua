--[[ ==============================================================================
    Knowledge Biggins - Zero-Maintenance Profession Knowledge Popup Consumer
    ------------------------------------------------------------------------------
    Author: Biggins (US-Whisperwind)
    Compatibility: World of Warcraft: Midnight / The War Within (Patch 11.x - 12.x)
    License: All Rights Reserved
============================================================================== ]]--

local addonName, addon = ...

-- Cache global functions
local CreateFrame              = CreateFrame
local InCombatLockdown         = InCombatLockdown
local PlaySound                = PlaySound
local SOUNDKIT                 = SOUNDKIT
local print                    = print
local type                     = type
local pairs                    = pairs
local tonumber                 = tonumber
local CopyTable                = CopyTable
local C_Timer                  = C_Timer
local Settings                 = Settings
local LibBigginsSuite          = LibBigginsSuite

-- Defaults
addon.defaults = {
    enabled = true,
    point = "CENTER",
    xOfs = 0,
    yOfs = -140,
    scale = 1.0,
    locked = false,
    alwaysShow = false,
    whitelist = {},
    blacklist = {},
}

local KnowledgeBiggins = {}
_G["KnowledgeBiggins"] = KnowledgeBiggins
KnowledgeBiggins.version = "1.3.3"

-- Native Blizzard Keybinding strings
_G["BINDING_HEADER_KNOWLEDGEBIGGINS_HEADER"] = "Knowledge Biggins"
_G["BINDING_CATEGORY_KNOWLEDGEBIGGINS"] = "Knowledge Biggins"
_G["BINDING_NAME_CLICK KnowledgeBigginsButton:LeftButton"] = "Study Knowledge"

addon.isUpdatePending = false
addon.currentLootedItem = nil
addon.optionsPanel = nil

function addon:PrintMsg(msg)
    print("|cFFFFD100Knowledge Biggins:|r " .. msg)
end

function KnowledgeBiggins:ResetPosition()
    addon:ResetPosition()
end

function KnowledgeBiggins:OpenSettings()
    if KnowledgeBiggins.categoryID and Settings and Settings.OpenToCategory then
        Settings.OpenToCategory(KnowledgeBiggins.categoryID)
    elseif LibBigginsSuite and LibBigginsSuite.OpenToSubcategory then
        LibBigginsSuite:OpenToSubcategory("KnowledgeBiggins")
    else
        addon:PrintMsg("Settings panel available in Options -> AddOns -> Biggins AddOns -> Knowledge.")
    end
end

-- ==============================================================================
-- EVENT DISPATCHER
-- ==============================================================================

local eventFrame = CreateFrame("Frame", "KnowledgeBigginsEventFrame")
eventFrame:RegisterEvent("ADDON_LOADED")
eventFrame:RegisterEvent("PLAYER_LOGIN")
eventFrame:RegisterEvent("PLAYER_ENTERING_WORLD")
eventFrame:RegisterEvent("BAG_UPDATE_DELAYED")
eventFrame:RegisterEvent("PLAYER_REGEN_DISABLED")
eventFrame:RegisterEvent("PLAYER_REGEN_ENABLED")

eventFrame:SetScript("OnEvent", function(self, event, arg1, ...)
    if event == "ADDON_LOADED" and arg1 == addonName then
        if not KnowledgeBigginsDB then
            KnowledgeBigginsDB = CopyTable(addon.defaults)
        else
            for k, v in pairs(addon.defaults) do
                if KnowledgeBigginsDB[k] == nil then
                    if type(v) == "table" then
                        KnowledgeBigginsDB[k] = CopyTable(v)
                    else
                        KnowledgeBigginsDB[k] = v
                    end
                end
            end
        end
    elseif event == "PLAYER_LOGIN" then
        addon:ApplyPosition()
        addon:RegisterSettingsUI()
    elseif event == "PLAYER_ENTERING_WORLD" then
        addon:UpdateKnowledgeButton()
        if C_Timer and C_Timer.After then
            C_Timer.After(0.5, function()
                if not InCombatLockdown() and addon.UpdateKnowledgeButton then
                    addon:UpdateKnowledgeButton()
                end
            end)
        end
    elseif event == "BAG_UPDATE_DELAYED" then
        addon:UpdateKnowledgeButton()
        if C_Timer and C_Timer.After then
            C_Timer.After(0.25, function()
                if not InCombatLockdown() and addon.UpdateKnowledgeButton then
                    addon:UpdateKnowledgeButton()
                end
            end)
        end
    elseif event == "PLAYER_REGEN_DISABLED" then
        -- In combat: lock button state
    elseif event == "PLAYER_REGEN_ENABLED" then
        -- Out of combat: process any pending updates
        if addon.isUpdatePending then
            addon.isUpdatePending = false
            addon:UpdateKnowledgeButton()
        end
    end
end)

-- ==============================================================================
-- SLASH COMMANDS
-- ==============================================================================

SLASH_KNOWLEDGEBIGGINS1 = "/knowledgeb"
SLASH_KNOWLEDGEBIGGINS2 = "/knowledgebiggins"

SlashCmdList["KNOWLEDGEBIGGINS"] = function(msg)
    local cmd = (msg or ""):trim():lower()

    if cmd == "" or cmd == "options" or cmd == "config" or cmd == "opt" or cmd == "settings" then
        KnowledgeBiggins:OpenSettings()
    elseif cmd == "toggle" or cmd == "enable" or cmd == "disable" then
        local db = KnowledgeBigginsDB or addon.defaults
        db.enabled = not (db.enabled ~= false)
        local status = db.enabled and "|cFF00FF00Enabled|r" or "|cFFFF0000Disabled|r"
        addon:PrintMsg("Knowledge Biggins is now " .. status .. ".")
        addon:UpdateKnowledgeButton()
        if addon.optionsPanel and addon.optionsPanel.RefreshControls then
            addon.optionsPanel.RefreshControls()
        end
    elseif cmd == "lock" or cmd == "unlock" then
        local db = KnowledgeBigginsDB or addon.defaults
        db.locked = not db.locked
        local status = db.locked and "|cFFFF0000Locked|r" or "|cFF00FF00Unlocked|r"
        addon:PrintMsg("Button position is now " .. status .. ".")
        addon:UpdateKnowledgeButton()
        if addon.optionsPanel and addon.optionsPanel.RefreshControls then
            addon.optionsPanel.RefreshControls()
        end
    elseif cmd == "show" or cmd == "alwaysshow" then
        local db = KnowledgeBigginsDB or addon.defaults
        db.alwaysShow = not db.alwaysShow
        local status = db.alwaysShow and "|cFF00FF00Enabled|r" or "|cFFFF0000Disabled|r"
        addon:PrintMsg("Always Show Button is now " .. status .. ".")
        addon:UpdateKnowledgeButton()
        if addon.optionsPanel and addon.optionsPanel.RefreshControls then
            addon.optionsPanel.RefreshControls()
        end
    elseif cmd == "ignore" or cmd == "blacklist" or cmd == "block" then
        if addon.currentLootedItem then
            local targetItemID = addon.currentLootedItem.itemID
            local targetLink = addon.currentLootedItem.link
            local db = KnowledgeBigginsDB or addon.defaults
            local wasAllowed = db.whitelist and db.whitelist[targetItemID]
            if wasAllowed then
                db.whitelist[targetItemID] = nil
            end

            local isDefaultKnowledge = addon:IsDefaultKnowledgeItem(addon.currentLootedItem.bag, addon.currentLootedItem.slot, targetItemID)
            PlaySound(SOUNDKIT.IG_MAINMENU_CLOSE)

            if isDefaultKnowledge then
                db.blacklist = db.blacklist or {}
                db.blacklist[targetItemID] = true
                addon.knowledgeItemCache[targetItemID] = false
                addon:PrintMsg("Added " .. (targetLink or ("item " .. targetItemID)) .. " to block list.")
            else
                addon.knowledgeItemCache[targetItemID] = nil
                addon:PrintMsg("Removed " .. (targetLink or ("item " .. targetItemID)) .. " from custom allow list.")
            end

            addon:UpdateKnowledgeButton()
            if addon.optionsPanel and addon.optionsPanel.RefreshTrays then
                addon.optionsPanel.RefreshTrays()
            end
        else
            addon:PrintMsg("No item currently active to dismiss/block. Hold Alt + Right-Click the button when an item appears.")
        end
    elseif cmd:find("^unignore%s*") or cmd:find("^whitelist%s*") or cmd:find("^allow%s*") then
        local arg = cmd:match("^%S+%s*(.*)$")
        local itemID = tonumber(arg) or (arg and tonumber(arg:match("item:(%d+)")))
        local itemLink = (arg and arg:find("%|Hitem:")) and arg or nil
        if itemID then
            addon:AddItemToWhitelist(itemID, itemLink)
        else
            addon:PrintMsg("Usage: /knowledgeb allow <itemID|itemLink>")
        end
    elseif cmd == "clear" or cmd == "resetlists" then
        local db = KnowledgeBigginsDB or addon.defaults
        db.whitelist = {}
        db.blacklist = {}
        addon.knowledgeItemCache = {}
        PlaySound(SOUNDKIT.IG_MAINMENU_CLOSE)
        addon:PrintMsg("Cleared all custom allow and block list items.")
        addon:UpdateKnowledgeButton()
        if addon.optionsPanel and addon.optionsPanel.RefreshTrays then
            addon.optionsPanel.RefreshTrays()
        end
    elseif cmd == "reset" then
        KnowledgeBiggins:ResetPosition()
    elseif cmd == "scan" or cmd == "update" then
        addon:UpdateKnowledgeButton()
        addon:PrintMsg("Bag scan completed.")
    elseif cmd == "help" or cmd == "?" then
        addon:PrintMsg("Commands:")
        print("  |cFFFFD100/knowledgeb|r - Open settings panel")
        print("  |cFFFFD100/knowledgeb toggle|r - Toggle addon enabled/disabled")
        print("  |cFFFFD100/knowledgeb lock|r - Toggle button lock/unlock")
        print("  |cFFFFD100/knowledgeb show|r - Toggle always showing button")
        print("  |cFFFFD100/knowledgeb ignore|r or |cFFFFD100/knowledgeb block|r - Block the currently displayed item")
        print("  |cFFFFD100/knowledgeb allow <id>|r - Manually add item to allow list")
        print("  |cFFFFD100/knowledgeb clear|r - Clear all custom allow and block list items")
        print("  |cFFFFD100/knowledgeb reset|r - Reset button position to center")
        print("  |cFFFFD100/knowledgeb scan|r - Force a bag scan for knowledge items")
        print("  |cFFFFD100/knowledgeb help|r or |cFFFFD100/knowledgeb ?|r - Show this list of commands")
        print("  |cFF888888Shortcuts: Shift+Drag to move | Alt+Right-Click to block item | Drop item to allow|r")
    else
        addon:PrintMsg("Unknown command '|cFFFFD100" .. cmd .. "|r'. Type |cFFFFD100/knowledgeb help|r for available commands.")
    end
end
