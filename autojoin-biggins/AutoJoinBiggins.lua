--[[ ==============================================================================
    AutoJoin Biggins v1.4.2
    ------------------------------------------------------------------------------
    Author: Biggins
    Lightweight, event-driven party invite auto-accept for Guildmates, Friends, and BNet.

    Modular Architecture:
      - Core/Whitelist.lua: Guild, Friends, and Battle.net whitelist evaluation.
      - Modules/Invite.lua: Party invite handling, popup suppression, chat switching.
      - Core/Options.lua: Blizzard Settings canvas UI and control toggles.
      - AutoJoinBiggins.lua: Lifecycle event orchestration and slash command routing.
============================================================================== ]]--

local addonName, addon = ...
_G["AutoJoinBiggins"] = addon
addon.version = "1.4.2"

-- Cache global functions
local CreateFrame = CreateFrame
local pairs       = pairs
local strtrim     = strtrim
local string      = string
local print       = print
local C_Timer     = C_Timer

-- Default Settings
addon.defaults = {
    enabled        = true,
    guild          = true,
    friends        = true,
    bnet           = true,
    all            = false,
    pauseWhileAFK  = true,
    autoSwitchChat = true,
    announce       = true,
}

-- Print helper with Blizzard Gold prefix
function addon:PrintMsg(msg)
    print("|cFFFFD100[AutoJoinBiggins]|r " .. msg)
end

-- State Tracking
local lastGroupType = "NONE"

-- Event Listener Frame
local frame = CreateFrame("Frame")
frame:RegisterEvent("ADDON_LOADED")
frame:RegisterEvent("PLAYER_ENTERING_WORLD")
frame:RegisterEvent("PARTY_INVITE_REQUEST")
frame:RegisterEvent("GROUP_ROSTER_UPDATE")

frame:SetScript("OnEvent", function(self, event, ...)
    if event == "ADDON_LOADED" then
        local loadedAddon = ...
        if loadedAddon == addonName then
            -- Initialize SavedVariables with defaults
            if not AutoJoinBigginsDB then
                AutoJoinBigginsDB = {}
            end
            for k, v in pairs(addon.defaults) do
                if AutoJoinBigginsDB[k] == nil then
                    AutoJoinBigginsDB[k] = v
                end
            end

            addon:RegisterOptions()
        end
    elseif event == "PLAYER_ENTERING_WORLD" then
        lastGroupType = addon:GetCurrentGroupType()
    elseif event == "PARTY_INVITE_REQUEST" then
        local inviterName, _, _, _, _, _, inviterGUID = ...
        addon:HandlePartyInvite(inviterName, inviterGUID)
    elseif event == "GROUP_ROSTER_UPDATE" then
        local currentGroupType = addon:GetCurrentGroupType()
        if currentGroupType ~= lastGroupType then
            if currentGroupType ~= "NONE" then
                -- Joined a group or transitioned between Party <-> Raid <-> Instance
                if AutoJoinBigginsDB and AutoJoinBigginsDB.enabled and AutoJoinBigginsDB.autoSwitchChat then
                    if C_Timer and C_Timer.After then
                        C_Timer.After(0.15, function() addon:SwitchActiveChatChannel() end)
                    else
                        addon:SwitchActiveChatChannel()
                    end
                end
            end
            lastGroupType = currentGroupType
        end
    end
end)

-- ==============================================================================
-- SLASH COMMAND HANDLER (/autojoinb)
-- ==============================================================================

local function SlashHandler(msg)
    local cmd = string.lower(strtrim(msg or ""))
    local db = AutoJoinBigginsDB or addon.defaults

    if cmd == "" or cmd == "options" or cmd == "config" then
        addon:OpenSettings()
    elseif cmd == "toggle" then
        db.enabled = not db.enabled
        local status = db.enabled and "|cFF00FF00Enabled|r" or "|cFFFF0000Disabled|r"
        addon:PrintMsg("Master Auto-Join is now " .. status .. ".")
        addon:UpdateOptionsUI()
    elseif cmd == "guild" then
        db.guild = not db.guild
        local status = db.guild and "|cFF00FF00Enabled|r" or "|cFFFF0000Disabled|r"
        addon:PrintMsg("Guild auto-join is now " .. status .. ".")
        addon:UpdateOptionsUI()
    elseif cmd == "friends" then
        db.friends = not db.friends
        local status = db.friends and "|cFF00FF00Enabled|r" or "|cFFFF0000Disabled|r"
        addon:PrintMsg("Character Friends auto-join is now " .. status .. ".")
        addon:UpdateOptionsUI()
    elseif cmd == "bnet" then
        db.bnet = not db.bnet
        local status = db.bnet and "|cFF00FF00Enabled|r" or "|cFFFF0000Disabled|r"
        addon:PrintMsg("Battle.net auto-join is now " .. status .. ".")
        addon:UpdateOptionsUI()
    elseif cmd == "all" then
        db.all = not db.all
        local status = db.all and "|cFFFF3333Enabled (ALL PLAYERS)|r" or "|cFF00FF00Disabled|r"
        addon:PrintMsg("All Players auto-join is now " .. status .. ".")
        addon:UpdateOptionsUI()
    elseif cmd == "afk" then
        db.pauseWhileAFK = not db.pauseWhileAFK
        local status = db.pauseWhileAFK and "|cFF00FF00Enabled|r" or "|cFFFF0000Disabled|r"
        addon:PrintMsg("Pause while AFK is now " .. status .. ".")
        addon:UpdateOptionsUI()
    elseif cmd == "chat" then
        db.autoSwitchChat = not db.autoSwitchChat
        local status = db.autoSwitchChat and "|cFF00FF00Enabled|r" or "|cFFFF0000Disabled|r"
        addon:PrintMsg("Auto-switch chat is now " .. status .. ".")
        addon:UpdateOptionsUI()
    elseif cmd == "announce" then
        db.announce = not db.announce
        local status = db.announce and "|cFF00FF00Enabled|r" or "|cFFFF0000Disabled|r"
        addon:PrintMsg("Chat announcements are now " .. status .. ".")
        addon:UpdateOptionsUI()
    elseif cmd == "status" then
        addon:PrintStatus()
    elseif cmd == "help" or cmd == "?" then
        addon:PrintMsg("Commands:")
        print("  |cFFFFD100/autojoinb|r - Open settings panel")
        print("  |cFFFFD100/autojoinb toggle|r - Toggle master auto-join on/off")
        print("  |cFFFFD100/autojoinb guild|r - Toggle Guild auto-join")
        print("  |cFFFFD100/autojoinb friends|r - Toggle Character Friends auto-join")
        print("  |cFFFFD100/autojoinb bnet|r - Toggle Battle.net Friends auto-join")
        print("  |cFFFFD100/autojoinb all|r - Toggle All Players auto-join")
        print("  |cFFFFD100/autojoinb afk|r - Toggle pause while AFK")
        print("  |cFFFFD100/autojoinb chat|r - Toggle auto-switching chat to group")
        print("  |cFFFFD100/autojoinb announce|r - Toggle chat announcements")
        print("  |cFFFFD100/autojoinb status|r - Display current configuration")
        print("  |cFFFFD100/autojoinb help|r or |cFFFFD100/autojoinb ?|r - Show this list of commands")
    else
        addon:PrintMsg("Unknown command '|cFFFFD100" .. cmd .. "|r'. Type |cFFFFD100/autojoinb help|r for available commands.")
    end
end

SLASH_AUTOJOINBIGGINS1 = "/autojoinb"
SlashCmdList["AUTOJOINBIGGINS"] = SlashHandler
