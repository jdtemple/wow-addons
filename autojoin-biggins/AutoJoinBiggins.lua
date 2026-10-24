-- AutoJoinBiggins.lua
-- Author: Biggins
-- Lightweight, event-driven party invite auto-accept for Guildmates, Friends, and BNet.

local addonName, addon = ...
_G["AutoJoinBiggins"] = addon
addon.version = "1.2.0"

-- Default Settings
local defaults = {
    enabled = true,
    guild = true,
    friends = true,
    bnet = true,
    all = false,
    autoSwitchChat = true,
    announce = true,
}

-- Print helper with Blizzard Gold prefix
local function PrintMsg(msg)
    print("|cFFFFD100[AutoJoinBiggins]|r " .. msg)
end

addon.PrintMsg = PrintMsg

-- Name normalizer helper
local function NormalizeName(fullName)
    if not fullName then return "", "" end
    local name, realm = strsplit("-", fullName, 2)
    return name or "", realm or ""
end

-- Check Guild Membership
local function IsGuildMember(inviterGUID, inviterName)
    if not IsInGuild() then return false end

    -- Primary: Check GUID against modern C_GuildInfo API
    if inviterGUID and C_GuildInfo and C_GuildInfo.IsGuildMember then
        if C_GuildInfo.IsGuildMember(inviterGUID) then
            return true
        end
    end

    -- Secondary: UnitIsInMyGuild
    if inviterName and UnitIsInMyGuild and UnitIsInMyGuild(inviterName) then
        return true
    end

    -- Fallback: Scan cached Guild Roster
    local numMembers = GetNumGuildMembers and GetNumGuildMembers() or 0
    if numMembers > 0 and inviterName then
        local reqName = NormalizeName(inviterName)
        reqName = string.lower(reqName)
        for i = 1, numMembers do
            local fullName = GetGuildRosterInfo(i)
            if fullName then
                local mName = NormalizeName(fullName)
                if string.lower(mName) == reqName then
                    return true
                end
            end
        end
    end

    return false
end

-- Check Character-Level Friends List
local function IsCharacterFriend(inviterGUID, inviterName)
    -- Primary: Check GUID via C_FriendList
    if inviterGUID and C_FriendList and C_FriendList.IsFriend then
        if C_FriendList.IsFriend(inviterGUID) then
            return true
        end
    end

    -- Secondary: Check Friend Info by name
    if inviterName and C_FriendList and C_FriendList.GetFriendInfo then
        local info = C_FriendList.GetFriendInfo(inviterName)
        if info then
            return true
        end
        local reqName = NormalizeName(inviterName)
        info = C_FriendList.GetFriendInfo(reqName)
        if info then
            return true
        end
    end

    return false
end

-- Check Battle.net Friends
local function IsBattleNetFriend(inviterGUID, inviterName)
    if not BNFeaturesEnabledAndConnected or not BNFeaturesEnabledAndConnected() then
        return false
    end

    local numFriends = BNGetNumFriends and BNGetNumFriends() or 0
    if numFriends == 0 then return false end

    local reqName, reqRealm = NormalizeName(inviterName)
    reqName = string.lower(reqName)
    reqRealm = string.lower(reqRealm)
    local myRealm = string.lower(GetNormalizedRealmName and GetNormalizedRealmName() or GetRealmName() or "")

    for i = 1, numFriends do
        local accountInfo = C_BattleNet and C_BattleNet.GetFriendAccountInfo and C_BattleNet.GetFriendAccountInfo(i)
        if accountInfo and accountInfo.gameAccountInfo and accountInfo.gameAccountInfo.isOnline then
            local gameAccount = accountInfo.gameAccountInfo
            if gameAccount.clientProgram == BNET_CLIENT_WOW then
                -- Match by GUID if available
                if inviterGUID and gameAccount.playerGuid and gameAccount.playerGuid == inviterGUID then
                    return true
                end

                -- Match by Character Name & Realm
                local charName = gameAccount.characterName
                local charRealm = gameAccount.realmName or ""
                if charName and charName ~= "" then
                    charName = string.lower(charName)
                    charRealm = string.lower(charRealm)

                    if charName == reqName then
                        if reqRealm == "" or charRealm == reqRealm or (charRealm == "" and reqRealm == myRealm) then
                            return true
                        end
                    end
                end
            end
        end
    end

    return false
end

-- Evaluate Whitelist Criteria
local function ShouldAutoJoin(inviterName, inviterGUID)
    local db = AutoJoinBigginsDB
    if not db or not db.enabled then
        return false, nil
    end

    -- 1. All / Anyone Toggle (Explicit user opt-in)
    if db.all then
        return true, "All Players"
    end

    -- 2. Guild Members
    if db.guild and IsGuildMember(inviterGUID, inviterName) then
        return true, "Guild Member"
    end

    -- 3. In-Game Friends List
    if db.friends and IsCharacterFriend(inviterGUID, inviterName) then
        return true, "Character Friend"
    end

    -- 4. Battle.net Friends
    if db.bnet and IsBattleNetFriend(inviterGUID, inviterName) then
        return true, "Battle.net Friend"
    end

    return false, nil
end

-- Suppress Standard WoW Invitation Popups
local function SuppressPopups()
    if StaticPopup_Hide then
        StaticPopup_Hide("PARTY_INVITE")
        StaticPopup_Hide("PARTY_INVITE_XREALM")
        StaticPopup_Hide("GROUP_INVITE_CONFIRMATION")
    end
end

-- Switch Active Chat Channel to Group (Instance, Raid, or Party)
local function SwitchActiveChatChannel()
    if not IsInGroup() then return end

    local targetChannel, channelLabel
    if IsInGroup(LE_PARTY_CATEGORY_INSTANCE) then
        targetChannel = "INSTANCE_CHAT"
        channelLabel = "Instance"
    elseif IsInRaid() then
        targetChannel = "RAID"
        channelLabel = "Raid"
    else
        targetChannel = "PARTY"
        channelLabel = "Party"
    end

    local editBox = (ChatEdit_ChooseBoxForSend and ChatEdit_ChooseBoxForSend()) or (DEFAULT_CHAT_FRAME and DEFAULT_CHAT_FRAME.editBox)
    if editBox and targetChannel then
        editBox:SetAttribute("chatType", targetChannel)
        if ChatEdit_UpdateHeader then
            ChatEdit_UpdateHeader(editBox)
        end
        if AutoJoinBigginsDB and AutoJoinBigginsDB.announce then
            PrintMsg(string.format("Active chat channel primed to |cFF00FF00%s|r.", channelLabel))
        end
    end
end

-- Helper to Determine Current Group State ("NONE", "INSTANCE", "RAID", "PARTY")
local function GetCurrentGroupType()
    if not IsInGroup() then
        return "NONE"
    elseif IsInGroup(LE_PARTY_CATEGORY_INSTANCE) then
        return "INSTANCE"
    elseif IsInRaid() then
        return "RAID"
    else
        return "PARTY"
    end
end

-- State Tracking
local lastGroupType = "NONE"

-- Process Party Invitation
local function HandlePartyInvite(inviterName, inviterGUID)
    local shouldAccept, reason = ShouldAutoJoin(inviterName, inviterGUID)
    if not shouldAccept then
        return
    end

    -- Accept the party invite
    AcceptGroup()
    SuppressPopups()

    -- Delayed checks to guarantee dialog dismissal across slow client frames
    if C_Timer and C_Timer.After then
        C_Timer.After(0.05, SuppressPopups)
        C_Timer.After(0.20, SuppressPopups)
    end

    if AutoJoinBigginsDB.announce then
        local displayName = inviterName or "Unknown"
        PrintMsg(string.format("Auto-accepted party invitation from |cFF00FF00%s|r (%s).", displayName, reason or "Whitelisted"))
    end
end

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
            for k, v in pairs(defaults) do
                if AutoJoinBigginsDB[k] == nil then
                    AutoJoinBigginsDB[k] = v
                end
            end

            addon:RegisterOptions()
        end
    elseif event == "PLAYER_ENTERING_WORLD" then
        lastGroupType = GetCurrentGroupType()
    elseif event == "PARTY_INVITE_REQUEST" then
        local inviterName, _, _, _, _, _, inviterGUID = ...
        HandlePartyInvite(inviterName, inviterGUID)
    elseif event == "GROUP_ROSTER_UPDATE" then
        local currentGroupType = GetCurrentGroupType()
        if currentGroupType ~= lastGroupType then
            if currentGroupType ~= "NONE" then
                -- Joined a group or transitioned between Party <-> Raid <-> Instance
                if AutoJoinBigginsDB and AutoJoinBigginsDB.enabled and AutoJoinBigginsDB.autoSwitchChat then
                    if C_Timer and C_Timer.After then
                        C_Timer.After(0.15, SwitchActiveChatChannel)
                    else
                        SwitchActiveChatChannel()
                    end
                end
            end
            lastGroupType = currentGroupType
        end
    end
end)

-- ==============================================================================
-- BLIZZARD MODERN SETTINGS API INTEGRATION (Canvas Layout)
-- ==============================================================================
local uiWidgets = {}

local function ResetAllToDefaults()
    if not AutoJoinBigginsDB then AutoJoinBigginsDB = {} end
    for k, v in pairs(defaults) do
        AutoJoinBigginsDB[k] = v
    end
    addon:UpdateOptionsUI()
    PrintMsg("All options have been reset to default.")
end

function addon:UpdateOptionsUI()
    if not uiWidgets.panel or not AutoJoinBigginsDB then return end
    local isEnabled = AutoJoinBigginsDB.enabled ~= false

    if uiWidgets.cbEnable then uiWidgets.cbEnable:SetChecked(isEnabled) end
    if uiWidgets.cbGuild then uiWidgets.cbGuild:SetChecked(AutoJoinBigginsDB.guild) end
    if uiWidgets.cbFriends then uiWidgets.cbFriends:SetChecked(AutoJoinBigginsDB.friends) end
    if uiWidgets.cbBnet then uiWidgets.cbBnet:SetChecked(AutoJoinBigginsDB.bnet) end
    if uiWidgets.cbAll then uiWidgets.cbAll:SetChecked(AutoJoinBigginsDB.all) end
    if uiWidgets.cbChat then uiWidgets.cbChat:SetChecked(AutoJoinBigginsDB.autoSwitchChat) end
    if uiWidgets.cbAnnounce then uiWidgets.cbAnnounce:SetChecked(AutoJoinBigginsDB.announce) end

    -- Dynamic Graying Out of Child Checkboxes
    local subWidgets = { uiWidgets.cbGuild, uiWidgets.cbFriends, uiWidgets.cbBnet, uiWidgets.cbAll, uiWidgets.cbChat, uiWidgets.cbAnnounce }
    for _, widget in ipairs(subWidgets) do
        if widget then
            widget:SetEnabled(isEnabled)
            widget:SetAlpha(isEnabled and 1.0 or 0.5)
        end
    end
end

-- Register Modern Blizzard Settings Panel (Canvas Layout)
function addon:RegisterOptions()
    local panel = CreateFrame("Frame", "AutoJoinBigginsOptionsPanel", UIParent)
    panel.name = "AutoJoin Biggins"
    uiWidgets.panel = panel

    -- Title (Blizzard Gold)
    local title = panel:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
    title:SetPoint("TOPLEFT", 16, -16)
    title:SetText("|cFFFFD100AutoJoin Biggins|r")

    -- Subtitle / Description
    local desc = panel:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
    desc:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -6)
    desc:SetText("Configurable auto-accept for party invitations from Guildmates, Friends, and BNet.")

    -- Top-Right "Defaults" Button
    local btnDefaults = CreateFrame("Button", nil, panel, "UIPanelButtonTemplate")
    btnDefaults:SetPoint("TOPRIGHT", -24, -20)
    btnDefaults:SetSize(110, 22)
    btnDefaults:SetText("Defaults")
    btnDefaults:SetScript("OnClick", function()
        ResetAllToDefaults()
    end)
    btnDefaults:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:SetText("Restore default settings for AutoJoin Biggins.", 1, 1, 1, true)
        GameTooltip:Show()
    end)
    btnDefaults:SetScript("OnLeave", function()
        GameTooltip:Hide()
    end)

    -- Helper to create and bind checkboxes with immediate DB sync & hover tooltips
    local function CreateSettingCheckbox(key, label, tooltip, anchorPoint, relativeTo, relPoint, x, y)
        local cb = CreateFrame("CheckButton", nil, panel, "InterfaceOptionsCheckButtonTemplate")
        cb:SetPoint(anchorPoint, relativeTo, relPoint, x, y)
        cb.Text:SetText(label)
        cb.Text:SetFontObject("GameFontHighlight")
        cb.tooltipText = tooltip
        local currentVal = (AutoJoinBigginsDB and AutoJoinBigginsDB[key] ~= nil) and AutoJoinBigginsDB[key] or defaults[key]
        cb:SetChecked(currentVal)
        cb:SetScript("OnClick", function(self)
            if not AutoJoinBigginsDB then AutoJoinBigginsDB = {} end
            AutoJoinBigginsDB[key] = self:GetChecked()
            addon:UpdateOptionsUI()
        end)
        cb:SetScript("OnEnter", function(self)
            if self.tooltipText then
                GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
                GameTooltip:SetText(self.tooltipText, 1, 1, 1, true)
                GameTooltip:Show()
            end
        end)
        cb:SetScript("OnLeave", function()
            GameTooltip:Hide()
        end)
        return cb
    end

    -- Master Enable Checkbox
    local cbEnable = CreateSettingCheckbox("enabled", "Enable Auto-Join System", "Enable or disable all automatic party invitation handling.", "TOPLEFT", desc, "BOTTOMLEFT", 0, -16)
    cbEnable:SetScript("OnClick", function(self)
        if not AutoJoinBigginsDB then AutoJoinBigginsDB = {} end
        AutoJoinBigginsDB.enabled = self:GetChecked()
        local status = AutoJoinBigginsDB.enabled and "|cFF00FF00Enabled|r" or "|cFFFF0000Disabled|r"
        PrintMsg("AutoJoin is now " .. status .. ".")
        addon:UpdateOptionsUI()
    end)
    uiWidgets.cbEnable = cbEnable

    -- Sub-checklists (Indented by 20px for clear visual hierarchy)
    local cbGuild = CreateSettingCheckbox("guild", "Auto-Join Guild Members", "Automatically accept party invitations from players in your current guild.", "TOPLEFT", cbEnable, "BOTTOMLEFT", 20, -8)
    uiWidgets.cbGuild = cbGuild

    local cbFriends = CreateSettingCheckbox("friends", "Auto-Join Character Friends", "Automatically accept party invitations from players on your in-game friends list.", "TOPLEFT", cbGuild, "BOTTOMLEFT", 0, -6)
    uiWidgets.cbFriends = cbFriends

    local cbBnet = CreateSettingCheckbox("bnet", "Auto-Join Battle.net Friends", "Automatically accept party invitations from active Battle.net friends playing WoW.", "TOPLEFT", cbFriends, "BOTTOMLEFT", 0, -6)
    uiWidgets.cbBnet = cbBnet

    local cbAll = CreateSettingCheckbox("all", "Auto-Join All Players (|cFFFF3333Warning|r)", "WARNING: When enabled, direct invites from ANY player (including strangers) will be accepted automatically.", "TOPLEFT", cbBnet, "BOTTOMLEFT", 0, -8)
    cbAll:SetScript("OnClick", function(self)
        if not AutoJoinBigginsDB then AutoJoinBigginsDB = {} end
        AutoJoinBigginsDB.all = self:GetChecked()
        if AutoJoinBigginsDB.all then
            PrintMsg("|cFFFF3333Warning:|r Auto-accepting invites from ALL players is now ACTIVE.")
        end
        addon:UpdateOptionsUI()
    end)
    uiWidgets.cbAll = cbAll

    local cbChat = CreateSettingCheckbox("autoSwitchChat", "Auto-Switch Active Chat to Group Channel", "Automatically primes your chat input to Party, Raid, or Instance chat upon joining a group.", "TOPLEFT", cbAll, "BOTTOMLEFT", 0, -8)
    uiWidgets.cbChat = cbChat

    local cbAnnounce = CreateSettingCheckbox("announce", "Show Chat Announcements on Auto-Join", "Print a notification in the chat window whenever an invite is automatically accepted or chat is switched.", "TOPLEFT", cbChat, "BOTTOMLEFT", 0, -8)
    uiWidgets.cbAnnounce = cbAnnounce

    -- Slash Command Help Note
    local helpNote = panel:CreateFontString(nil, "ARTWORK", "GameFontDisableSmall")
    helpNote:SetPoint("TOPLEFT", cbAnnounce, "BOTTOMLEFT", -20, -24)
    helpNote:SetText("Slash commands: /autojoin or /aj (toggle, guild, friends, bnet, all, chat, announce, status)")

    panel:SetScript("OnShow", function()
        addon:UpdateOptionsUI()
    end)

    -- Register with modern Settings UI as a subcategory under Biggins AddOns
    if LibBigginsSuite then
        addon.categoryID = LibBigginsSuite:RegisterSubcategory("AutoJoinBiggins", panel, "AutoJoin")
    elseif Settings and Settings.RegisterCanvasLayoutCategory then
        local category = Settings.RegisterCanvasLayoutCategory(panel, "AutoJoin Biggins")
        Settings.RegisterAddOnCategory(category)
        addon.categoryID = category:GetID()
    else
        InterfaceOptions_AddCategory(panel)
    end

    addon:UpdateOptionsUI()
end

-- Open Settings Panel
function addon:OpenSettings()
    addon:UpdateOptionsUI()
    if addon.categoryID and Settings and Settings.OpenToCategory then
        Settings.OpenToCategory(addon.categoryID)
    else
        PrintMsg("Options panel available in Game Menu -> Options -> AddOns -> AutoJoin Biggins.")
    end
end

-- Print Status Summary
function addon:PrintStatus()
    local db = AutoJoinBigginsDB or defaults
    local function ColorBool(val)
        return val and "|cFF00FF00[ON]|r" or "|cFFFF0000[OFF]|r"
    end
    PrintMsg("Current Configuration:")
    print(string.format("  Master Enable:   %s", ColorBool(db.enabled)))
    print(string.format("  Guild Members:   %s", ColorBool(db.guild)))
    print(string.format("  Character Friends:%s", ColorBool(db.friends)))
    print(string.format("  Battle.net:      %s", ColorBool(db.bnet)))
    print(string.format("  All Players:     %s", ColorBool(db.all)))
    print(string.format("  Auto-Switch Chat:%s", ColorBool(db.autoSwitchChat)))
    print(string.format("  Announcements:   %s", ColorBool(db.announce)))
end

-- Slash Command Handler (/autojoin, /aj)
local function SlashHandler(msg)
    local cmd = string.lower(strtrim(msg or ""))
    local db = AutoJoinBigginsDB or defaults

    if cmd == "" or cmd == "options" or cmd == "config" then
        addon:OpenSettings()
    elseif cmd == "toggle" then
        db.enabled = not db.enabled
        local status = db.enabled and "|cFF00FF00Enabled|r" or "|cFFFF0000Disabled|r"
        PrintMsg("Master Auto-Join is now " .. status .. ".")
        addon:UpdateOptionsUI()
    elseif cmd == "guild" then
        db.guild = not db.guild
        local status = db.guild and "|cFF00FF00Enabled|r" or "|cFFFF0000Disabled|r"
        PrintMsg("Guild auto-join is now " .. status .. ".")
        addon:UpdateOptionsUI()
    elseif cmd == "friends" then
        db.friends = not db.friends
        local status = db.friends and "|cFF00FF00Enabled|r" or "|cFFFF0000Disabled|r"
        PrintMsg("Character Friends auto-join is now " .. status .. ".")
        addon:UpdateOptionsUI()
    elseif cmd == "bnet" then
        db.bnet = not db.bnet
        local status = db.bnet and "|cFF00FF00Enabled|r" or "|cFFFF0000Disabled|r"
        PrintMsg("Battle.net auto-join is now " .. status .. ".")
        addon:UpdateOptionsUI()
    elseif cmd == "all" then
        db.all = not db.all
        local status = db.all and "|cFFFF3333Enabled (ALL PLAYERS)|r" or "|cFF00FF00Disabled|r"
        PrintMsg("All Players auto-join is now " .. status .. ".")
        addon:UpdateOptionsUI()
    elseif cmd == "chat" then
        db.autoSwitchChat = not db.autoSwitchChat
        local status = db.autoSwitchChat and "|cFF00FF00Enabled|r" or "|cFFFF0000Disabled|r"
        PrintMsg("Auto-switch chat is now " .. status .. ".")
        addon:UpdateOptionsUI()
    elseif cmd == "announce" then
        db.announce = not db.announce
        local status = db.announce and "|cFF00FF00Enabled|r" or "|cFFFF0000Disabled|r"
        PrintMsg("Chat announcements are now " .. status .. ".")
        addon:UpdateOptionsUI()
    elseif cmd == "status" then
        addon:PrintStatus()
    else
        PrintMsg("Available commands: /aj [toggle | guild | friends | bnet | all | chat | announce | status | config]")
    end
end

SLASH_AUTOJOINBIGGINS1 = "/autojoin"
SLASH_AUTOJOINBIGGINS2 = "/aj"
SlashCmdList["AUTOJOINBIGGINS"] = SlashHandler
