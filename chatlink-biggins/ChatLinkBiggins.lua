--[[ ==============================================================================
    ChatLink Biggins v1.0.0 - Clickable Web Hyperlinks for World of Warcraft
    ------------------------------------------------------------------------------
    Author: Biggins (US-Whisperwind)
    Compatibility: World of Warcraft: Midnight / The War Within (Patch 11.x - 12.x)

    ARCHITECTURAL OVERVIEW:
    1. Single-Pattern Protocol Isolation: Matches standard web protocols
       (https:// and http://) via a single pass, eliminating multi-pattern
       collisions, false positives, and infinite chat loops.
    2. Sentence Punctuation Stripping: Safely trims trailing sentence punctuation
       (.,;:!?)[]'") so URLs copied to the clipboard remain valid.
    3. Draggable Blizzard Factory Dialog: Dedicated frame styled with authentic
       Blizzard dialog textures, freely draggable with position memory and reset.
    4. Zero-Taint Event Filtering: Registered through ChatFrame_AddMessageEventFilter
       and native SetItemRef hooks with same-frame click de-duplication.
    5. Modern Blizzard Canvas UI: Integrated into Options -> AddOns -> Biggins AddOns -> ChatLink
       with top-right [ Defaults ] button, [ Reset Position ], and master toggle.
============================================================================== ]]--

local addonName, addon = ...
_G["ChatLinkBiggins"] = addon
addon.version = "1.0.0"

-- Upvalue caching
local CreateFrame              = CreateFrame
local GetTime                  = GetTime
local hooksecurefunc           = hooksecurefunc
local ChatFrame_AddMessageEventFilter = ChatFrame_AddMessageEventFilter
local ChatFrameUtil            = ChatFrameUtil
local C_EventUtils             = C_EventUtils
local EventRegistry            = EventRegistry
local Settings                 = Settings
local UIParent                 = UIParent
local tinsert                  = table.insert

-- Configuration Defaults
local defaults = {
    enabled      = true,
    showBrackets = true,
    announce     = true,
    posPoint     = "CENTER",
    posRelPoint  = "CENTER",
    posX         = 0,
    posY         = 100,
}

local db -- Active database pointer
local uiWidgets = {
    subControls = {},
}

-- Print formatted addon message
local function PrintMsg(msg)
    DEFAULT_CHAT_FRAME:AddMessage("|cFFFFD100ChatLink Biggins:|r " .. msg)
end

-- ==============================================================================
-- 1. DRAGGABLE BLIZZARD FACTORY DIALOG
-- ==============================================================================

local copyDialog
local copyEditBox

local function CreateCopyDialog()
    if copyDialog then return copyDialog end

    local f = CreateFrame("Frame", "ChatLinkBigginsDialog", UIParent, "BackdropTemplate")
    f:SetSize(420, 118)
    f:SetFrameStrata("DIALOG")
    f:SetToplevel(true)
    f:SetClampedToScreen(true)
    f:SetMovable(true)
    f:EnableMouse(true)
    f:RegisterForDrag("LeftButton")
    f:Hide()

    -- Register with UISpecialFrames so pressing ESC closes the dialog
    tinsert(UISpecialFrames, "ChatLinkBigginsDialog")

    -- Authentic Blizzard Factory Dialog Styling
    f:SetBackdrop({
        bgFile   = "Interface\\DialogFrame\\UI-DialogBox-Background-Dark",
        edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
        tile     = true,
        tileSize = 32,
        edgeSize = 24,
        insets   = { left = 6, right = 6, top = 6, bottom = 6 },
    })

    -- Drag Handlers (Save position across sessions)
    f:SetScript("OnDragStart", function(self)
        self:StartMoving()
    end)

    f:SetScript("OnDragStop", function(self)
        self:StopMovingOrSizing()
        local point, _, relPoint, x, y = self:GetPoint()
        if db then
            db.posPoint = point or "CENTER"
            db.posRelPoint = relPoint or "CENTER"
            db.posX = math.floor((x or 0) + 0.5)
            db.posY = math.floor((y or 100) + 0.5)
        end
    end)

    -- Title / Instruction Header
    local title = f:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    title:SetPoint("TOP", 0, -14)
    title:SetText("Copy URL (|cFFFFD100Ctrl+C|r):")

    -- EditBox Container Inset
    local editContainer = CreateFrame("Frame", nil, f, "BackdropTemplate")
    editContainer:SetPoint("TOPLEFT", 18, -38)
    editContainer:SetPoint("TOPRIGHT", -18, -38)
    editContainer:SetHeight(28)
    editContainer:SetBackdrop({
        bgFile   = "Interface\\ChatFrame\\ChatFrameBackground",
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        tile     = true,
        tileSize = 16,
        edgeSize = 12,
        insets   = { left = 3, right = 3, top = 3, bottom = 3 },
    })
    editContainer:SetBackdropColor(0.05, 0.05, 0.05, 0.95)
    editContainer:SetBackdropBorderColor(0.6, 0.6, 0.6, 0.8)

    local eb = CreateFrame("EditBox", nil, editContainer)
    eb:SetPoint("LEFT", 8, 0)
    eb:SetPoint("RIGHT", -8, 0)
    eb:SetHeight(20)
    eb:SetFontObject("ChatFontNormal")
    eb:SetAutoFocus(false)

    eb:SetScript("OnEscapePressed", function()
        f:Hide()
    end)
    eb:SetScript("OnEnterPressed", function()
        f:Hide()
    end)
    eb:SetScript("OnEditFocusLost", function(self)
        self:HighlightText(0, 0)
    end)

    -- Close Button (Classic Blizzard Red)
    local btnClose = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
    btnClose:SetPoint("BOTTOM", 0, 14)
    btnClose:SetSize(90, 22)
    btnClose:SetText("Close")
    btnClose:SetScript("OnClick", function()
        f:Hide()
    end)

    copyDialog = f
    copyEditBox = eb
    return f
end

local function ShowCopyDialog(url)
    local f = CreateCopyDialog()
    f:ClearAllPoints()
    if db and db.posPoint then
        f:SetPoint(db.posPoint, UIParent, db.posRelPoint, db.posX, db.posY)
    else
        f:SetPoint("CENTER", UIParent, "CENTER", 0, 100)
    end

    copyEditBox:SetText(url or "")
    f:Show()
    copyEditBox:SetFocus()
    copyEditBox:HighlightText()
end

local function ResetDialogPosition()
    if db then
        db.posPoint = "CENTER"
        db.posRelPoint = "CENTER"
        db.posX = 0
        db.posY = 100
    end
    if copyDialog then
        copyDialog:ClearAllPoints()
        copyDialog:SetPoint("CENTER", UIParent, "CENTER", 0, 100)
    end
end

-- ==============================================================================
-- 2. URL FORMATTING & CHAT EVENT FILTER
-- ==============================================================================

-- True only for plain strings the addon is allowed to read (guards Retail secret values)
local function IsReadableString(v)
    if type(v) ~= "string" then return false end
    if issecretvalue then
        local ok, secret = pcall(issecretvalue, v)
        if not ok or secret then return false end
    end
    return true
end

local function FormatLink(url)
    -- Strip trailing sentence punctuation
    local clean = string.gsub(url, "[%.,;:!%?%)%]%}'\"]+$", "")
    local trailing = string.sub(url, #clean + 1)
    local display = (db and db.showBrackets) and ("[" .. clean .. "]") or clean
    return "|cff00ccff|Haddon:ChatLinkBiggins:URL:" .. clean .. "|h" .. display .. "|h|r" .. trailing
end

local function OnChatMessage(self, event, msg, sender, ...)
    if not db or not db.enabled then return false, msg, sender, ... end
    if not IsReadableString(msg) then return false, msg, sender, ... end

    -- Fast 0.001ms exit if no web protocol is present
    if not string.find(msg, "https?://") then
        return false, msg, sender, ...
    end

    -- Re-entrancy guard: avoid re-formatting already formatted links
    if string.find(msg, "|Haddon:ChatLinkBiggins:") then
        return false, msg, sender, ...
    end

    -- Single-pass pattern isolation (strictly terminates at whitespace or pipe)
    local newMsg = string.gsub(msg, "(https?://[^%s|]+)", FormatLink)
    return false, newMsg, sender, ...
end

-- ==============================================================================
-- 3. CLICK HANDLING & DE-DUPLICATION
-- ==============================================================================

local lastClickLink, lastClickTime

local function OnLinkClicked(link, text, button, chatFrame)
    if not IsReadableString(link) then return end
    local now = GetTime and GetTime() or 0
    if link == lastClickLink and now == lastClickTime then return end

    if string.sub(link, 1, 26) == "addon:ChatLinkBiggins:URL:" then
        lastClickLink, lastClickTime = link, now
        local url = string.sub(link, 27)
        if url and url ~= "" then
            ShowCopyDialog(url)
        end
    end
end

-- Hook both SetItemRef and modern EventRegistry
hooksecurefunc("SetItemRef", OnLinkClicked)
if EventRegistry and EventRegistry.RegisterCallback then
    EventRegistry:RegisterCallback("SetItemRef", function(_, link, text, button, chatFrame)
        OnLinkClicked(link, text, button, chatFrame)
    end, addonName)
end

-- ==============================================================================
-- 4. CHAT FILTER REGISTRATION
-- ==============================================================================

local AddMessageEventFilter = ChatFrame_AddMessageEventFilter
    or (ChatFrameUtil and ChatFrameUtil.AddMessageEventFilter)

local function SafeAddFilter(event, func)
    if C_EventUtils and C_EventUtils.IsEventValid and not C_EventUtils.IsEventValid(event) then return end
    if AddMessageEventFilter then
        AddMessageEventFilter(event, func)
    end
end

local CHAT_CHANNELS = {
    "CHAT_MSG_SAY",
    "CHAT_MSG_YELL",
    "CHAT_MSG_GUILD",
    "CHAT_MSG_OFFICER",
    "CHAT_MSG_PARTY",
    "CHAT_MSG_PARTY_LEADER",
    "CHAT_MSG_RAID",
    "CHAT_MSG_RAID_LEADER",
    "CHAT_MSG_RAID_WARNING",
    "CHAT_MSG_INSTANCE_CHAT",
    "CHAT_MSG_INSTANCE_CHAT_LEADER",
    "CHAT_MSG_WHISPER",
    "CHAT_MSG_WHISPER_INFORM",
    "CHAT_MSG_BN_WHISPER",
    "CHAT_MSG_BN_WHISPER_INFORM",
    "CHAT_MSG_CHANNEL",
    "CHAT_MSG_COMMUNITIES_CHANNEL",
}

for _, eventName in ipairs(CHAT_CHANNELS) do
    SafeAddFilter(eventName, OnChatMessage)
end

-- ==============================================================================
-- 5. BLIZZARD CANVAS SETTINGS UI
-- ==============================================================================

local function UpdateControlStates()
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

local function CreateSettingsUI()
    local panel = CreateFrame("Frame", "ChatLinkBigginsSettingsPanel", UIParent)
    panel.name = "ChatLink"

    -- Header / Title
    local title = panel:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
    title:SetPoint("TOPLEFT", 16, -16)
    title:SetText("|cFFFFD100ChatLink Biggins|r")

    -- Top-Right Defaults Button
    local btnDefaults = CreateFrame("Button", nil, panel, "UIPanelButtonTemplate")
    btnDefaults:SetPoint("TOPRIGHT", -24, -16)
    btnDefaults:SetSize(90, 22)
    btnDefaults:SetText("Defaults")
    btnDefaults:SetScript("OnClick", function()
        for k, v in pairs(defaults) do
            db[k] = v
        end
        ResetDialogPosition()
        if panel.RefreshControls then
            panel.RefreshControls()
        end
        UpdateControlStates()
        if db.announce then
            PrintMsg("Settings reset to defaults.")
        end
    end)

    -- Subtitle
    local subtitle = panel:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
    subtitle:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -4)
    subtitle:SetText("Converts web URLs in chat into clickable links for instant, native copy-pasting.")

    -- Master Enable Checkbox
    local cbEnable = CreateFrame("CheckButton", "ChatLinkBiggins_EnableCB", panel, "UICheckButtonTemplate")
    cbEnable:SetPoint("TOPLEFT", subtitle, "BOTTOMLEFT", 0, -12)
    cbEnable.text = cbEnable.text or cbEnable.Text or _G[cbEnable:GetName() .. "Text"]
    if cbEnable.text then cbEnable.text:SetText("Enable ChatLink Biggins") end
    cbEnable:SetScript("OnClick", function(self)
        db.enabled = self:GetChecked()
        UpdateControlStates()
        if db.announce then
            PrintMsg(db.enabled and "ChatLink |cFF00FF00enabled|r." or "ChatLink |cFFFF0000disabled|r.")
        end
    end)

    -- Section: Display Options
    local optHeader = panel:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    optHeader:SetPoint("TOPLEFT", cbEnable, "BOTTOMLEFT", 0, -14)
    optHeader:SetText("Display Options:")

    -- Show Brackets Checkbox
    local cbBrackets = CreateFrame("CheckButton", "ChatLinkBiggins_BracketsCB", panel, "UICheckButtonTemplate")
    cbBrackets:SetPoint("TOPLEFT", optHeader, "BOTTOMLEFT", 12, -4)
    cbBrackets.text = cbBrackets.text or cbBrackets.Text or _G[cbBrackets:GetName() .. "Text"]
    if cbBrackets.text then cbBrackets.text:SetText("Show Brackets Around Links [ https://... ]") end
    cbBrackets.label = cbBrackets.text
    table.insert(uiWidgets.subControls, cbBrackets)
    cbBrackets:SetScript("OnClick", function(self)
        db.showBrackets = self:GetChecked()
        if db.announce then
            PrintMsg("Link brackets " .. (db.showBrackets and "|cFF00FF00enabled|r." or "|cFFFF0000disabled|r."))
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
        ResetDialogPosition()
        if db.announce then
            PrintMsg("Popup position reset to center.")
        end
    end)

    -- Instructional Helper Note
    local noteBox = CreateFrame("Frame", nil, panel, "BackdropTemplate")
    noteBox:SetPoint("TOPLEFT", btnResetPos, "BOTTOMLEFT", 0, -18)
    noteBox:SetSize(580, 56)
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
    noteText:SetText("|cFFFFD100How it works:|r\n- Supports all standard web URLs starting with |cFF00CCFFhttps://|r or |cFF00CCFFhttp://|r.\n- Click any link in chat to open the copy box, press |cFFFFD100Ctrl+C|r, and tap |cFFFFD100Enter|r to close.")

    -- Refresh UI Controls from SavedVariables
    panel.RefreshControls = function()
        cbEnable:SetChecked(db.enabled)
        cbBrackets:SetChecked(db.showBrackets)
        cbAnnounce:SetChecked(db.announce)
        UpdateControlStates()
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

-- ==============================================================================
-- 6. SLASH COMMANDS (/clb and /chatlink)
-- ==============================================================================

SLASH_CHATLINKBIGGINS1 = "/clb"
SLASH_CHATLINKBIGGINS2 = "/chatlink"

SlashCmdList["CHATLINKBIGGINS"] = function(msg)
    msg = string.lower(strtrim(msg or ""))

    if msg == "" or msg == "options" or msg == "config" then
        if addon.categoryID and Settings and Settings.OpenToCategory then
            Settings.OpenToCategory(addon.categoryID)
        else
            PrintMsg("Open Options -> AddOns -> Biggins AddOns -> ChatLink.")
        end
    elseif msg == "toggle" then
        db.enabled = not db.enabled
        if addon.settingsPanel and addon.settingsPanel.RefreshControls then
            addon.settingsPanel.RefreshControls()
        end
        PrintMsg(db.enabled and "ChatLink |cFF00FF00enabled|r." or "ChatLink |cFFFF0000disabled|r.")
    elseif msg == "brackets" then
        db.showBrackets = not db.showBrackets
        if addon.settingsPanel and addon.settingsPanel.RefreshControls then
            addon.settingsPanel.RefreshControls()
        end
        PrintMsg("Link brackets " .. (db.showBrackets and "|cFF00FF00enabled|r." or "|cFFFF0000disabled|r."))
    elseif msg == "reset" then
        ResetDialogPosition()
        PrintMsg("Popup position reset to center.")
    elseif msg == "status" then
        PrintMsg("Status: " .. (db.enabled and "|cFF00FF00Enabled|r" or "|cFFFF0000Disabled|r")
            .. " | Brackets: " .. (db.showBrackets and "|cFF00FF00ON|r" or "|cFFFF0000OFF|r")
            .. " | Echo: " .. (db.announce and "|cFF00FF00ON|r" or "|cFFFF0000OFF|r")
            .. " | Position: (" .. (db.posX or 0) .. ", " .. (db.posY or 100) .. ")")
    elseif msg == "defaults" then
        for k, v in pairs(defaults) do
            db[k] = v
        end
        ResetDialogPosition()
        if addon.settingsPanel and addon.settingsPanel.RefreshControls then
            addon.settingsPanel.RefreshControls()
        end
        PrintMsg("Settings reset to defaults.")
    else
        PrintMsg("Commands: |cFFFFD100/clb|r (options), |cFFFFD100/clb toggle|r, |cFFFFD100/clb brackets|r, |cFFFFD100/clb reset|r, |cFFFFD100/clb status|r, |cFFFFD100/clb defaults|r.")
    end
end

-- ==============================================================================
-- 7. INITIALIZATION LIFECYCLE
-- ==============================================================================

local initFrame = CreateFrame("Frame")
initFrame:RegisterEvent("ADDON_LOADED")
initFrame:SetScript("OnEvent", function(self, event, loadedAddon)
    if loadedAddon ~= addonName then return end

    -- Initialize SavedVariables
    _G["ChatLinkBigginsDB"] = _G["ChatLinkBigginsDB"] or {}
    db = _G["ChatLinkBigginsDB"]

    for k, v in pairs(defaults) do
        if db[k] == nil then
            db[k] = v
        end
    end

    CreateSettingsUI()
    self:UnregisterEvent("ADDON_LOADED")
end)
