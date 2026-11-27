--[[ ==============================================================================
    ChatLink Biggins - Options & Settings Panel (Canvas Layout)
    ------------------------------------------------------------------------------
    Integrated Blizzard Settings canvas providing master enable, player hover
    tooltips toggle, link bracket styling, and popup position reset.
============================================================================== ]]--

local addonName, addon = ...

-- Cache global functions
local CreateFrame     = CreateFrame
local UIParent        = UIParent
local Settings        = Settings
local LibBigginsSuite = LibBigginsSuite
local ipairs          = ipairs
local pairs           = pairs
local _G              = _G

local uiWidgets = {
    subControls = {},
}
addon.uiWidgets = uiWidgets

function addon:UpdateControlStates()
    local db = ChatLinkBigginsDB or addon.defaults
    local masterEnabled = db and db.enabled
    for _, ctrl in ipairs(uiWidgets.subControls) do
        if ctrl.SetEnabled then
            ctrl:SetEnabled(masterEnabled)
        end
        if ctrl.label then
            ctrl.label:SetTextColor(
                masterEnabled and 1.0 or 0.5,
                masterEnabled and 1.0 or 0.5,
                masterEnabled and 1.0 or 0.5
            )
        end
    end
end

function addon:CreateSettingsUI()
    local panel = CreateFrame("Frame", "ChatLinkBigginsSettingsPanel", UIParent)
    panel.name = "ChatLink"

    -- Header / Title
    local title = panel:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
    title:SetPoint("TOPLEFT", 16, -16)
    title:SetText("|cFFFFD100ChatLink Biggins|r")

    -- Subtitle
    local subtitle = panel:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
    subtitle:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -4)
    subtitle:SetText("Converts web URLs in chat into clickable links and adds player name hover tooltips.")

    -- Suite Logo Texture (Top Right)
    local logo = panel:CreateTexture(nil, "ARTWORK")
    logo:SetPoint("TOPRIGHT", -24, -16)
    logo:SetSize(64, 64)
    logo:SetTexture("Interface\\AddOns\\ChatLinkBiggins\\logo.jpg")

    -- Top-Right Defaults Button
    local btnDefaults = CreateFrame("Button", nil, panel, "UIPanelButtonTemplate")
    btnDefaults:SetPoint("TOPRIGHT", logo, "BOTTOMRIGHT", 0, -8)
    btnDefaults:SetSize(90, 22)
    btnDefaults:SetText("Defaults")
    btnDefaults:SetScript("OnClick", function()
        local db = ChatLinkBigginsDB or {}
        for k, v in pairs(addon.defaults) do
            db[k] = v
        end
        addon:ResetDialogPosition()
        if panel.RefreshControls then
            panel.RefreshControls()
        end
        addon:UpdateControlStates()
        if db.announce then
            addon:PrintMsg("Settings reset to defaults.")
        end
    end)

    -- Master Enable Checkbox
    local cbEnable = CreateFrame("CheckButton", "ChatLinkBiggins_EnableCB", panel, "UICheckButtonTemplate")
    cbEnable:SetPoint("TOPLEFT", subtitle, "BOTTOMLEFT", 0, -12)
    cbEnable.text = cbEnable.text or cbEnable.Text or _G[cbEnable:GetName() .. "Text"]
    if cbEnable.text then cbEnable.text:SetText("Enable ChatLink Biggins") end
    cbEnable:SetScript("OnClick", function(self)
        local db = ChatLinkBigginsDB or {}
        db.enabled = self:GetChecked()
        addon:UpdateControlStates()
        if db.announce then
            addon:PrintMsg(db.enabled and "ChatLink |cFF00FF00enabled|r." or "ChatLink |cFFFF0000disabled|r.")
        end
    end)

    -- Section: Display Options
    local optHeader = panel:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    optHeader:SetPoint("TOPLEFT", cbEnable, "BOTTOMLEFT", 0, -14)
    optHeader:SetText("Features & Display:")

    -- Player Hover Tooltips Checkbox
    local cbTooltips = CreateFrame("CheckButton", "ChatLinkBiggins_TooltipsCB", panel, "UICheckButtonTemplate")
    cbTooltips:SetPoint("TOPLEFT", optHeader, "BOTTOMLEFT", 12, -4)
    cbTooltips.text = cbTooltips.text or cbTooltips.Text or _G[cbTooltips:GetName() .. "Text"]
    if cbTooltips.text then cbTooltips.text:SetText("Show Player Tooltips on Name Hover") end
    cbTooltips.label = cbTooltips.text
    table.insert(uiWidgets.subControls, cbTooltips)
    cbTooltips:SetScript("OnClick", function(self)
        local db = ChatLinkBigginsDB or {}
        db.playerTooltips = self:GetChecked()
        if db.announce then
            addon:PrintMsg("Player hover tooltips " .. (db.playerTooltips and "|cFF00FF00enabled|r." or "|cFFFF0000disabled|r."))
        end
    end)

    -- Show Brackets Checkbox
    local cbBrackets = CreateFrame("CheckButton", "ChatLinkBiggins_BracketsCB", panel, "UICheckButtonTemplate")
    cbBrackets:SetPoint("TOPLEFT", cbTooltips, "BOTTOMLEFT", 0, -4)
    cbBrackets.text = cbBrackets.text or cbBrackets.Text or _G[cbBrackets:GetName() .. "Text"]
    if cbBrackets.text then cbBrackets.text:SetText("Show Brackets Around Links [ https://... ]") end
    cbBrackets.label = cbBrackets.text
    table.insert(uiWidgets.subControls, cbBrackets)
    cbBrackets:SetScript("OnClick", function(self)
        local db = ChatLinkBigginsDB or {}
        db.showBrackets = self:GetChecked()
        if db.announce then
            addon:PrintMsg("Link brackets " .. (db.showBrackets and "|cFF00FF00enabled|r." or "|cFFFF0000disabled|r."))
        end
    end)

    -- Announce Changes Checkbox
    local cbAnnounce = CreateFrame("CheckButton", "ChatLinkBiggins_AnnounceCB", panel, "UICheckButtonTemplate")
    cbAnnounce:SetPoint("TOPLEFT", cbBrackets, "BOTTOMLEFT", 0, -4)
    cbAnnounce.text = cbAnnounce.text or cbAnnounce.Text or _G[cbAnnounce:GetName() .. "Text"]
    if cbAnnounce.text then cbAnnounce.text:SetText("Echo Settings Changes to Chat") end
    cbAnnounce.label = cbAnnounce.text
    table.insert(uiWidgets.subControls, cbAnnounce)
    cbAnnounce:SetScript("OnClick", function(self)
        local db = ChatLinkBigginsDB or {}
        db.announce = self:GetChecked()
    end)

    -- Section: Dialog Position
    local posHeader = panel:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    posHeader:SetPoint("TOPLEFT", cbAnnounce, "BOTTOMLEFT", -12, -14)
    posHeader:SetText("Popup Position:")

    local posDesc = panel:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
    posDesc:SetPoint("TOPLEFT", posHeader, "BOTTOMLEFT", 0, -4)
    posDesc:SetText("You can freely left-click and drag the popup dialog anywhere on your screen. Its position is automatically saved.")

    local btnResetPos = CreateFrame("Button", nil, panel, "UIPanelButtonTemplate")
    btnResetPos:SetPoint("TOPLEFT", posDesc, "BOTTOMLEFT", 0, -8)
    btnResetPos:SetSize(130, 22)
    btnResetPos:SetText("Reset Position")
    btnResetPos:SetScript("OnClick", function()
        addon:ResetDialogPosition()
        local db = ChatLinkBigginsDB or addon.defaults
        if db.announce then
            addon:PrintMsg("Popup position reset to center.")
        end
    end)

    -- Instructional Helper Note
    local noteBox = CreateFrame("Frame", nil, panel, "BackdropTemplate")
    noteBox:SetPoint("TOPLEFT", btnResetPos, "BOTTOMLEFT", 0, -18)
    noteBox:SetSize(580, 72)
    noteBox:SetBackdrop({
        bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background-Dark",
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        tile = true, tileSize = 16, edgeSize = 12,
        insets = { left = 3, right = 3, top = 3, bottom = 3 }
    })
    noteBox:SetBackdropBorderColor(0.8, 0.7, 0.2, 0.6)

    local noteText = noteBox:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
    noteText:SetPoint("TOPLEFT", 12, -10)
    noteText:SetPoint("BOTTOMRIGHT", -12, 10)
    noteText:SetJustifyH("LEFT")
    noteText:SetJustifyV("TOP")
    noteText:SetText("|cFFFFD100How it works:|r\n- |cFFFFD100URLs:|r Click any link starting with |cFF00CCFFhttps://|r to open the copy dialog, press |cFFFFD100Ctrl+C|r, and tap |cFFFFD100Enter|r to close.\n- |cFFFFD100Player Names:|r Hover over any player name in chat. Party and raid members show the full unit tooltip (integrating with MouseOverTooltip), while distant players show a clean identity card.")

    -- Slash Command Help Note
    local helpNote = panel:CreateFontString(nil, "ARTWORK", "GameFontDisableSmall")
    helpNote:SetPoint("TOPLEFT", noteBox, "BOTTOMLEFT", 0, -14)
    helpNote:SetText("Slash commands: |cFFFFD100/chatlinkb|r (Type |cFFFFD100/chatlinkb ?|r for available commands)")

    -- Refresh UI Controls from SavedVariables
    panel.RefreshControls = function()
        local db = ChatLinkBigginsDB or addon.defaults
        cbEnable:SetChecked(db.enabled)
        cbTooltips:SetChecked(db.playerTooltips)
        cbBrackets:SetChecked(db.showBrackets)
        cbAnnounce:SetChecked(db.announce)
        addon:UpdateControlStates()
    end

    panel:SetScript("OnShow", function()
        panel.RefreshControls()
    end)

    -- Register with LibBigginsSuite
    local Suite = _G["LibBigginsSuite"]
    if Suite and Suite.RegisterSubcategory then
        addon.categoryID = Suite:RegisterSubcategory(addonName, panel, "ChatLink")
    elseif Settings and Settings.RegisterCanvasLayoutCategory then
        local category = Settings.RegisterCanvasLayoutCategory(panel, "ChatLink")
        Settings.RegisterAddOnCategory(category)
        addon.categoryID = category:GetID()
    end

    addon.settingsPanel = panel
end
