--[[ ==============================================================================
    ChatLink Biggins - Player Name Hover Tooltips
    ------------------------------------------------------------------------------
    Native player hover tooltips featuring Tier 1 live unit tokens (integrating
    with MouseOverTooltip) and Tier 2 remote cross-zone identity cards.
============================================================================== ]]--

local addonName, addon = ...

-- Cache global functions
local GameTooltip              = GameTooltip
local GameTooltip_SetDefaultAnchor = GameTooltip_SetDefaultAnchor
local UnitName                 = UnitName
local UnitGUID                 = UnitGUID
local UnitExists               = UnitExists
local UnitTokenFromGUID        = UnitTokenFromGUID
local IsInRaid                 = IsInRaid
local IsInGroup                = IsInGroup
local IsInGuild                = IsInGuild
local GetNumGroupMembers       = GetNumGroupMembers
local GetNumGuildMembers       = GetNumGuildMembers
local GetGuildRosterInfo       = GetGuildRosterInfo
local GetGuildInfo             = GetGuildInfo
local GetRealmName             = GetRealmName
local GetPlayerInfoByGUID      = GetPlayerInfoByGUID or (C_PlayerInfo and C_PlayerInfo.GetPlayerInfoByGUID)
local C_ClassColor             = C_ClassColor
local C_ChatInfo               = C_ChatInfo
local RAID_CLASS_COLORS        = RAID_CLASS_COLORS
local LOCALIZED_CLASS_NAMES_MALE   = LOCALIZED_CLASS_NAMES_MALE
local LOCALIZED_CLASS_NAMES_FEMALE = LOCALIZED_CLASS_NAMES_FEMALE
local string_match             = string.match
local tonumber                 = tonumber
local pairs                    = pairs
local ipairs                   = ipairs
local type                     = type
local _G                       = _G
local hooksecurefunc           = hooksecurefunc
local FCF_OpenTemporaryWindow  = FCF_OpenTemporaryWindow

local isShowingPlayerTooltip = false
local currentHoverGuid = nil
local currentHoverFrame = nil

-- Attempt to resolve an active live Unit Token for a given character name / GUID
local function ResolveUnitToken(targetName, targetGuid)
    if not targetName or targetName == "" then return nil end
    local shortName = string_match(targetName, "^([^-]+)") or targetName
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

    local shortName = string_match(rawName, "^([^-]+)") or rawName
    local realm = (pRealm and pRealm ~= "") and pRealm or string_match(rawName, "^[^-]+%-(.+)$")

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
            local gShort = gName and string_match(gName, "^([^-]+)") or gName
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

    -- Line 3: Race, Class, Level descriptor
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
    local db = ChatLinkBigginsDB or addon.defaults
    if not db or not db.enabled or not db.playerTooltips then return end

    local linkData = string_match(link, "^player:(.+)$")
    if not linkData then return end

    -- Extract raw character name (field 1) and lineID (field 2)
    local rawName, lineIDStr = string_match(linkData, "^([^:]+):?(%d*)")
    if not rawName or rawName == "" then return end

    local shortName = string_match(rawName, "^([^-]+)") or rawName

    -- Attempt to resolve GUID from link, chat lineID, or senderCache
    local guid = string_match(linkData, "(Player%-[%w%-]+)")
    if not guid and lineIDStr and lineIDStr ~= "" then
        local numLineID = tonumber(lineIDStr)
        if numLineID and C_ChatInfo and C_ChatInfo.GetChatLineSenderGUID then
            guid = C_ChatInfo.GetChatLineSenderGUID(numLineID)
        end
    end
    if not guid and addon.senderCache then
        guid = addon.senderCache[rawName] or addon.senderCache[shortName]
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
    if not addon:IsReadableString(link) then return end
    local linkType = string_match(link, "^([^:]+)")
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

function addon:HookAllChatFrames()
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
        addon:HookAllChatFrames()
    end)
end
