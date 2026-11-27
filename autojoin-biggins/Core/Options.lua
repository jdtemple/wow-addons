--[[ ==============================================================================
    AutoJoin Biggins - Options & Settings Panel (Canvas Layout)
    ------------------------------------------------------------------------------
    Integrated Blizzard Settings canvas providing master toggle, scope checkboxes
    (Guild, Friends, Battle.net, All), AFK safety pause, and chat channel switching.
============================================================================== ]]--

local addonName, addon = ...

-- Cache global functions
local CreateFrame     = CreateFrame
local GameTooltip     = GameTooltip
local UIParent        = UIParent
local Settings        = Settings
local LibBigginsSuite = LibBigginsSuite
local InterfaceOptions_AddCategory = InterfaceOptions_AddCategory
local ipairs          = ipairs
local pairs           = pairs
local print           = print
local string_format   = string.format

local uiWidgets = {}
addon.uiWidgets = uiWidgets

function addon:UpdateOptionsUI()
    if not uiWidgets.panel or not AutoJoinBigginsDB then return end
    local isEnabled = AutoJoinBigginsDB.enabled ~= false

    if uiWidgets.cbEnable then uiWidgets.cbEnable:SetChecked(isEnabled) end
    if uiWidgets.cbGuild then uiWidgets.cbGuild:SetChecked(AutoJoinBigginsDB.guild) end
    if uiWidgets.cbFriends then uiWidgets.cbFriends:SetChecked(AutoJoinBigginsDB.friends) end
    if uiWidgets.cbBnet then uiWidgets.cbBnet:SetChecked(AutoJoinBigginsDB.bnet) end
    if uiWidgets.cbAll then uiWidgets.cbAll:SetChecked(AutoJoinBigginsDB.all) end
    if uiWidgets.cbAFK then uiWidgets.cbAFK:SetChecked(AutoJoinBigginsDB.pauseWhileAFK) end
    if uiWidgets.cbChat then uiWidgets.cbChat:SetChecked(AutoJoinBigginsDB.autoSwitchChat) end
    if uiWidgets.cbAnnounce then uiWidgets.cbAnnounce:SetChecked(AutoJoinBigginsDB.announce) end

    -- Dynamic Graying Out of Child Checkboxes
    local subWidgets = { uiWidgets.cbGuild, uiWidgets.cbFriends, uiWidgets.cbBnet, uiWidgets.cbAll, uiWidgets.cbAFK, uiWidgets.cbChat, uiWidgets.cbAnnounce }
    for _, widget in ipairs(subWidgets) do
        if widget then
            widget:SetEnabled(isEnabled)
            widget:SetAlpha(isEnabled and 1.0 or 0.5)
        end
    end
end

local function ResetAllToDefaults()
    if not AutoJoinBigginsDB then AutoJoinBigginsDB = {} end
    for k, v in pairs(addon.defaults) do
        AutoJoinBigginsDB[k] = v
    end
    addon:UpdateOptionsUI()
    addon:PrintMsg("All options have been reset to default.")
end

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

    -- Suite Logo Texture (Top Right)
    local logo = panel:CreateTexture(nil, "ARTWORK")
    logo:SetPoint("TOPRIGHT", -24, -16)
    logo:SetSize(64, 64)
    logo:SetTexture("Interface\\AddOns\\AutoJoinBiggins\\logo.jpg")

    -- Top-Right "Defaults" Button
    local btnDefaults = CreateFrame("Button", nil, panel, "UIPanelButtonTemplate")
    btnDefaults:SetPoint("TOPRIGHT", logo, "BOTTOMRIGHT", 0, -8)
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
        local currentVal = (AutoJoinBigginsDB and AutoJoinBigginsDB[key] ~= nil) and AutoJoinBigginsDB[key] or addon.defaults[key]
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
        addon:PrintMsg("AutoJoin is now " .. status .. ".")
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
            addon:PrintMsg("|cFFFF3333Warning:|r Auto-accepting invites from ALL players is now ACTIVE.")
        end
        addon:UpdateOptionsUI()
    end)
    uiWidgets.cbAll = cbAll

    local cbAFK = CreateSettingCheckbox("pauseWhileAFK", "Pause Auto-Accept While AFK", "When enabled, party invitations will not be accepted automatically while your character is flagged as Away (AFK). The invitation dialog remains on screen for manual acceptance.", "TOPLEFT", cbAll, "BOTTOMLEFT", 0, -8)
    uiWidgets.cbAFK = cbAFK

    local cbChat = CreateSettingCheckbox("autoSwitchChat", "Auto-Switch Active Chat to Group Channel", "Automatically primes your chat input to Party, Raid, or Instance chat upon joining a group.", "TOPLEFT", cbAFK, "BOTTOMLEFT", 0, -8)
    uiWidgets.cbChat = cbChat

    local cbAnnounce = CreateSettingCheckbox("announce", "Show Chat Announcements on Auto-Join", "Print a notification in the chat window whenever an invite is automatically accepted or chat is switched.", "TOPLEFT", cbChat, "BOTTOMLEFT", 0, -8)
    uiWidgets.cbAnnounce = cbAnnounce

    -- Slash Command Help Note
    local helpNote = panel:CreateFontString(nil, "ARTWORK", "GameFontDisableSmall")
    helpNote:SetPoint("TOPLEFT", cbAnnounce, "BOTTOMLEFT", -20, -24)
    helpNote:SetText("Slash commands: |cFFFFD100/autojoinb|r (Type |cFFFFD100/autojoinb ?|r for available commands)")

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

function addon:OpenSettings()
    addon:UpdateOptionsUI()
    if addon.categoryID and Settings and Settings.OpenToCategory then
        Settings.OpenToCategory(addon.categoryID)
    else
        addon:PrintMsg("Options panel available in Game Menu -> Options -> AddOns -> AutoJoin Biggins.")
    end
end

function addon:PrintStatus()
    local db = AutoJoinBigginsDB or addon.defaults
    local function ColorBool(val)
        return val and "|cFF00FF00[ON]|r" or "|cFFFF0000[OFF]|r"
    end
    addon:PrintMsg("Current Configuration:")
    print(string_format("  Master Enable:   %s", ColorBool(db.enabled)))
    print(string_format("  Guild Members:   %s", ColorBool(db.guild)))
    print(string_format("  Character Friends:%s", ColorBool(db.friends)))
    print(string_format("  Battle.net:       %s", ColorBool(db.bnet)))
    print(string_format("  All Players:      %s", ColorBool(db.all)))
    print(string_format("  Pause While AFK:  %s", ColorBool(db.pauseWhileAFK)))
    print(string_format("  Auto-Switch Chat: %s", ColorBool(db.autoSwitchChat)))
    print(string_format("  Announcements:    %s", ColorBool(db.announce)))
end
