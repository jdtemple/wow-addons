--[[ ==============================================================================
    ChatLink Biggins v1.1.1 - Clickable Web Hyperlinks & Player Hover Tooltips
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
    5. Native Player Hover Tooltips:
       - Tier 1 (Group / Target / Proximity): Resolves live Unit Token and invokes
         GameTooltip:SetUnit(), automatically triggering unit tooltip enhancers
         like MouseOverTooltip for item level, spec, mount, and class borders.
       - Tier 2 (Remote / Cross-Zone): Queries C_PlayerInfo.GetPlayerInfoByGUID()
         to render a stock Blizzard-styled identity card (Class, Race, Realm, Guild).
    6. Modern Blizzard Canvas UI: Integrated into Options -> AddOns -> Biggins AddOns -> ChatLink
       with top-right [ Defaults ] button, [ Reset Position ], and feature toggles.
============================================================================== ]]--

local addonName, addon = ...
_G["ChatLinkBiggins"] = addon
addon.version = "1.2.0"

-- Upvalue caching
local CreateFrame              = CreateFrame
local GetTime                  = GetTime
local hooksecurefunc           = hooksecurefunc
local ChatFrame_AddMessageEventFilter = ChatFrame_AddMessageEventFilter
local ChatFrameUtil            = ChatFrameUtil
local C_ChatInfo             = C_ChatInfo
local C_ClassColor             = C_ClassColor
local C_EventUtils             = C_EventUtils
local C_PlayerInfo             = C_PlayerInfo
local EventRegistry            = EventRegistry
local GameTooltip              = GameTooltip
local GameTooltip_SetDefaultAnchor = GameTooltip_SetDefaultAnchor
local LOCALIZED_CLASS_NAMES_MALE   = LOCALIZED_CLASS_NAMES_MALE
local LOCALIZED_CLASS_NAMES_FEMALE = LOCALIZED_CLASS_NAMES_FEMALE
local GetGuildInfo             = GetGuildInfo
local GetGuildRosterInfo       = GetGuildRosterInfo
local GetNumGroupMembers       = GetNumGroupMembers
local GetNumGuildMembers       = GetNumGuildMembers
local GetPlayerInfoByGUID      = GetPlayerInfoByGUID or (C_PlayerInfo and C_PlayerInfo.GetPlayerInfoByGUID)
local GetRealmName             = GetRealmName
local IsInGroup                = IsInGroup
local IsInGuild                = IsInGuild
local IsInRaid                 = IsInRaid
local RAID_CLASS_COLORS        = RAID_CLASS_COLORS
local Settings                 = Settings
local UIParent                 = UIParent
local UnitExists               = UnitExists
local UnitGUID                 = UnitGUID
local UnitName                 = UnitName
local UnitTokenFromGUID        = UnitTokenFromGUID
local tinsert                  = table.insert

-- Configuration Defaults
local defaults = {
    enabled        = true,
    playerTooltips = true,
    showBrackets   = true,
    announce       = true,
    posPoint       = "CENTER",
    posRelPoint    = "CENTER",
    posX           = 0,
    posY           = 100,
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

local senderCache = {}
local senderCacheCount = 0
local MAX_SENDER_CACHE = 500

local function CacheSenderGUID(name, guid)
    if not name or not guid then return end
    if not senderCache[name] then
        if senderCacheCount >= MAX_SENDER_CACHE then
            senderCache = {}
            senderCacheCount = 0
        end
        senderCache[name] = guid
        senderCacheCount = senderCacheCount + 1
    end
    local short = string.match(name, "^([^-]+)")
    if short and short ~= name then
        senderCache[short] = guid
    end
end

local function FormatLink(url)
    -- Strip trailing sentence punctuation
    local clean = string.gsub(url, "[%.,;:!%?%)%]%}'\"]+$", "")
    local trailing = string.sub(url, #clean + 1)
    local display = (db and db.showBrackets) and ("[" .. clean .. "]") or clean
    return "|cff00ccff|Haddon:ChatLinkBiggins:URL:" .. clean .. "|h" .. display .. "|h|r" .. trailing
end

local function OnChatMessage(self, event, msg, sender, ...)
    -- Cache sender GUID from chat event payload
    if sender and sender ~= "" then
        for i = 1, select("#", ...) do
            local arg = select(i, ...)
            if type(arg) == "string" and string.sub(arg, 1, 7) == "Player-" then
                CacheSenderGUID(sender, arg)
                break
            end
        end
    end

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
-- 4. PLAYER NAME HOVER TOOLTIPS
-- ==============================================================================

local isShowingPlayerTooltip = false
local currentHoverGuid = nil
local currentHoverFrame = nil

-- Attempt to resolve an active live Unit Token for a given character name / GUID
local function ResolveUnitToken(targetName, targetGuid)
    if not targetName or targetName == "" then return nil end
    local shortName = string.match(targetName, "^([^-]+)") or targetName
    local myName = UnitName("player")

    -- 1. Check self
    if shortName == myName or targetName == myName or (targetGuid and targetGuid == UnitGUID("player")) then
        return "player"
    end

    -- 2. Check current target or focus
    if UnitExists("target") then
        local tName = UnitName("target")
        if (targetGuid and targetGuid == UnitGUID("target")) or (tName and (tName == shortName or tName == targetName)) then
            return "target"
        end
    end
    if UnitExists("focus") then
        local fName = UnitName("focus")
        if (targetGuid and targetGuid == UnitGUID("focus")) or (fName and (fName == shortName or fName == targetName)) then
            return "focus"
        end
    end

    -- 3. Check party / raid group members
    if IsInRaid() then
        local count = GetNumGroupMembers()
        for i = 1, count do
            local unit = "raid" .. i
            local uName = UnitName(unit)
            if (targetGuid and targetGuid == UnitGUID(unit)) or (uName and (uName == shortName or uName == targetName)) then
                return unit
            end
        end
    elseif IsInGroup() then
        local count = GetNumGroupMembers()
        for i = 1, count - 1 do
            local unit = "party" .. i
            local uName = UnitName(unit)
            if (targetGuid and targetGuid == UnitGUID(unit)) or (uName and (uName == shortName or uName == targetName)) then
                return unit
            end
        end
    end

    -- 4. Check nameplate tokens if nearby in 3D world (~60y)
    if targetGuid and UnitTokenFromGUID then
        local token = UnitTokenFromGUID(targetGuid)
        if token and UnitExists(token) then
            return token
        end
    end

    return nil
end

-- Render remote player identity card using native GameTooltip
local function ShowRemotePlayerCard(chatFrame, rawName, guid)
    local locClass, engClass, locRace, engRace, gender, pName, pRealm
    if guid and GetPlayerInfoByGUID then
        locClass, engClass, locRace, engRace, gender, pName, pRealm = GetPlayerInfoByGUID(guid)
    end

    local shortName = string.match(rawName, "^([^-]+)") or rawName
    local realm = (pRealm and pRealm ~= "") and pRealm or string.match(rawName, "^[^-]+%-(.+)$")

    -- Determine Class Colors
    local cr, cg, cb = 1.0, 1.0, 1.0
    if engClass then
        local color = (C_ClassColor and C_ClassColor.GetClassColor(engClass)) or (RAID_CLASS_COLORS and RAID_CLASS_COLORS[engClass])
        if color then
            cr, cg, cb = color.r, color.g, color.b
        end
    end

    if GameTooltip_SetDefaultAnchor then
        GameTooltip_SetDefaultAnchor(GameTooltip, chatFrame)
    else
        GameTooltip:SetOwner(chatFrame, "ANCHOR_NONE")
    end
    GameTooltip:ClearLines()

    -- Guild Roster check for enriched details
    local guildLevel = nil
    local guildZone = nil
    local guildClass = nil
    local guildLine = nil
    if IsInGuild() and GetNumGuildMembers then
        local num = GetNumGuildMembers()
        for i = 1, num do
            local gName, gRank, _, gLvl, gCls, gZ, _, _, gOnline = GetGuildRosterInfo(i)
            local gShort = gName and string.match(gName, "^([^-]+)") or gName
            if gShort and (gShort == shortName or gName == rawName) then
                local myGuild = GetGuildInfo("player")
                if myGuild then
                    guildLine = "<" .. myGuild .. "> - " .. (gRank or "Member")
                end
                if gLvl and gLvl > 0 then guildLevel = gLvl end
                if gZ and gZ ~= "" and gOnline then guildZone = gZ end
                if gCls and gCls ~= "" then guildClass = gCls end
                break
            end
        end
    end

    -- Resolve class token for color coding
    local classToken = engClass
    if not classToken and guildClass then
        for token, locName in pairs(LOCALIZED_CLASS_NAMES_MALE or {}) do
            if locName == guildClass then classToken = token; break end
        end
        if not classToken then
            for token, locName in pairs(LOCALIZED_CLASS_NAMES_FEMALE or {}) do
                if locName == guildClass then classToken = token; break end
            end
        end
    end

    if classToken then
        local color = (C_ClassColor and C_ClassColor.GetClassColor(classToken)) or (RAID_CLASS_COLORS and RAID_CLASS_COLORS[classToken])
        if color then
            cr, cg, cb = color.r, color.g, color.b
        end
    end

    -- Line 1: Character Name (Class Colored)
    GameTooltip:AddLine(shortName, cr, cg, cb)

    -- Line 2: Guild Membership (if player is in our guild)
    if guildLine then
        GameTooltip:AddLine(guildLine, 0.6, 0.8, 1.0)
    end

    -- Line 2: Race, Class, Level descriptor
    local displayClass = locClass or guildClass
    local desc = ""
    if guildLevel then
        desc = "Level " .. guildLevel .. " "
    end
    if locRace and locRace ~= "" then
        desc = desc .. locRace .. " "
    end
    if displayClass and displayClass ~= "" then
        desc = desc .. displayClass
    end
    if desc ~= "" then
        GameTooltip:AddLine(desc, 1.0, 1.0, 1.0)
    end

    -- Line 4: Home Realm (if cross-realm)
    local myRealm = GetRealmName and GetRealmName() or ""
    if realm and realm ~= "" and realm ~= myRealm then
        GameTooltip:AddLine(realm, 0.7, 0.7, 0.7)
    end

    -- Line 5: Current Zone (if known from guild roster)
    if guildZone and guildZone ~= "" then
        GameTooltip:AddLine(guildZone, 0.8, 0.8, 0.6)
    end

    GameTooltip:Show()
    isShowingPlayerTooltip = true
    currentHoverGuid = guid
    currentHoverFrame = chatFrame
end

-- Main dispatcher when mouse enters a player hyperlink in chat
local function OnPlayerHyperlinkEnter(chatFrame, link)
    if not db or not db.enabled or not db.playerTooltips then return end

    local linkData = string.match(link, "^player:(.+)$")
    if not linkData then return end

    -- Extract raw character name (field 1) and lineID (field 2)
    local rawName, lineIDStr = string.match(linkData, "^([^:]+):?(%d*)")
    if not rawName or rawName == "" then return end

    local shortName = string.match(rawName, "^([^-]+)") or rawName

    -- Attempt to resolve GUID from link, chat lineID, or senderCache
    local guid = string.match(linkData, "(Player%-[%w%-]+)")
    if not guid and lineIDStr and lineIDStr ~= "" then
        local numLineID = tonumber(lineIDStr)
        if numLineID and C_ChatInfo and C_ChatInfo.GetChatLineSenderGUID then
            guid = C_ChatInfo.GetChatLineSenderGUID(numLineID)
        end
    end
    if not guid then
        guid = senderCache[rawName] or senderCache[shortName]
    end

    -- Tier 1: Try resolving an active Unit Token (Group, Target, or Proximity)
    local unitToken = ResolveUnitToken(rawName, guid)
    if unitToken then
        if GameTooltip_SetDefaultAnchor then
            GameTooltip_SetDefaultAnchor(GameTooltip, chatFrame)
        else
            GameTooltip:SetOwner(chatFrame, "ANCHOR_NONE")
        end
        GameTooltip:SetUnit(unitToken)
        GameTooltip:Show()
        isShowingPlayerTooltip = true
        currentHoverGuid = guid or (UnitGUID and UnitGUID(unitToken))
        currentHoverFrame = chatFrame
        return
    end

    -- Tier 2: Remote / Cross-zone player identity card
    ShowRemotePlayerCard(chatFrame, rawName, guid)
end

local function OnChatHyperlinkEnter(chatFrame, link, text)
    if not IsReadableString(link) then return end
    local linkType = string.match(link, "^([^:]+)")
    if linkType == "player" then
        OnPlayerHyperlinkEnter(chatFrame, link)
    end
end

local function OnChatHyperlinkLeave(chatFrame)
    if isShowingPlayerTooltip then
        isShowingPlayerTooltip = false
        currentHoverGuid = nil
        currentHoverFrame = nil
        GameTooltip:Hide()
    end
end


-- Safe chat frame hooker
local function HookChatFrame(frame)
    if not frame or frame.clbPlayerHoverHooked then return end
    frame.clbPlayerHoverHooked = true
    if frame.HookScript then
        frame:HookScript("OnHyperlinkEnter", OnChatHyperlinkEnter)
        frame:HookScript("OnHyperlinkLeave", OnChatHyperlinkLeave)
    end
end

local function HookAllChatFrames()
    if type(CHAT_FRAMES) == "table" then
        for _, frameName in ipairs(CHAT_FRAMES) do
            local cf = _G[frameName]
            if cf then
                HookChatFrame(cf)
            end
        end
    end
    local num = NUM_CHAT_WINDOWS or 10
    for i = 1, num do
        local cf = _G["ChatFrame" .. i]
        if cf then
            HookChatFrame(cf)
        end
    end
end

-- Securely hook temporary whisper windows when opened
if FCF_OpenTemporaryWindow then
    hooksecurefunc("FCF_OpenTemporaryWindow", function()
        HookAllChatFrames()
    end)
end

-- ==============================================================================
-- 5. CHAT FILTER REGISTRATION
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
-- 6. BLIZZARD CANVAS SETTINGS UI
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
    optHeader:SetText("Features & Display:")

    -- Player Hover Tooltips Checkbox
    local cbTooltips = CreateFrame("CheckButton", "ChatLinkBiggins_TooltipsCB", panel, "UICheckButtonTemplate")
    cbTooltips:SetPoint("TOPLEFT", optHeader, "BOTTOMLEFT", 12, -4)
    cbTooltips.text = cbTooltips.text or cbTooltips.Text or _G[cbTooltips:GetName() .. "Text"]
    if cbTooltips.text then cbTooltips.text:SetText("Show Player Tooltips on Name Hover") end
    cbTooltips.label = cbTooltips.text
    table.insert(uiWidgets.subControls, cbTooltips)
    cbTooltips:SetScript("OnClick", function(self)
        db.playerTooltips = self:GetChecked()
        if db.announce then
            PrintMsg("Player hover tooltips " .. (db.playerTooltips and "|cFF00FF00enabled|r." or "|cFFFF0000disabled|r."))
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
    helpNote:SetText("Slash commands: /chatlinkb (Type /chatlinkb ? for available commands)")

    -- Refresh UI Controls from SavedVariables
    panel.RefreshControls = function()
        cbEnable:SetChecked(db.enabled)
        cbTooltips:SetChecked(db.playerTooltips)
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
-- 7. SLASH COMMANDS (/chatlinkb)
-- ==============================================================================

SLASH_CHATLINKBIGGINS1 = "/chatlinkb"

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
    elseif msg == "tooltips" or msg == "hover" then
        db.playerTooltips = not db.playerTooltips
        if addon.settingsPanel and addon.settingsPanel.RefreshControls then
            addon.settingsPanel.RefreshControls()
        end
        PrintMsg("Player hover tooltips " .. (db.playerTooltips and "|cFF00FF00enabled|r." or "|cFFFF0000disabled|r."))
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
            .. " | Tooltips: " .. (db.playerTooltips and "|cFF00FF00ON|r" or "|cFFFF0000OFF|r")
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
    elseif msg == "help" or msg == "?" then
        PrintMsg("Commands:")
        print("  |cFFFFD100/chatlinkb|r - Open settings panel")
        print("  |cFFFFD100/chatlinkb toggle|r - Toggle URL detection on/off")
        print("  |cFFFFD100/chatlinkb tooltips|r - Toggle player hover tooltips")
        print("  |cFFFFD100/chatlinkb brackets|r - Toggle visual [brackets] around links")
        print("  |cFFFFD100/chatlinkb reset|r - Reset copy dialog position to center")
        print("  |cFFFFD100/chatlinkb status|r - Display current configuration")
        print("  |cFFFFD100/chatlinkb defaults|r - Reset all settings to defaults")
        print("  |cFFFFD100/chatlinkb help|r or |cFFFFD100/chatlinkb ?|r - Show this list of commands")
    else
        PrintMsg("Unknown command '|cFFFFD100" .. msg .. "|r'. Type |cFFFFD100/chatlinkb help|r for available commands.")
    end
end

-- ==============================================================================
-- 8. INITIALIZATION LIFECYCLE
-- ==============================================================================

local initFrame = CreateFrame("Frame")
initFrame:RegisterEvent("ADDON_LOADED")
initFrame:RegisterEvent("PLAYER_LOGIN")
initFrame:SetScript("OnEvent", function(self, event, arg1)
    if event == "ADDON_LOADED" then
        if arg1 ~= addonName then return end

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
    elseif event == "PLAYER_LOGIN" then
        HookAllChatFrames()
        self:UnregisterEvent("PLAYER_LOGIN")
    end
end)
