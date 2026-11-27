--[[ ==============================================================================
    AutoJoin Biggins - Invitation Processing & Chat Channel Switching
    ------------------------------------------------------------------------------
    Manages party invite acceptance, standard popup suppression, and automatic
    chat channel priming upon joining groups.
============================================================================== ]]--

local addonName, addon = ...

-- Cache global functions
local AcceptGroup                 = AcceptGroup
local StaticPopup_Hide            = StaticPopup_Hide
local IsInGroup                   = IsInGroup
local IsInRaid                    = IsInRaid
local LE_PARTY_CATEGORY_INSTANCE  = LE_PARTY_CATEGORY_INSTANCE
local ChatEdit_ChooseBoxForSend   = ChatEdit_ChooseBoxForSend
local ChatEdit_UpdateHeader       = ChatEdit_UpdateHeader
local DEFAULT_CHAT_FRAME          = DEFAULT_CHAT_FRAME
local C_Timer                     = C_Timer
local string_format               = string.format

-- Suppress Standard WoW Invitation Popups
function addon:SuppressPopups()
    if StaticPopup_Hide then
        StaticPopup_Hide("PARTY_INVITE")
        StaticPopup_Hide("PARTY_INVITE_XREALM")
        StaticPopup_Hide("GROUP_INVITE_CONFIRMATION")
    end
end

-- Switch Active Chat Channel to Group (Instance, Raid, or Party)
function addon:SwitchActiveChatChannel()
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
            addon:PrintMsg(string_format("Active chat channel primed to |cFF00FF00%s|r.", channelLabel))
        end
    end
end

-- Helper to Determine Current Group State ("NONE", "INSTANCE", "RAID", "PARTY")
function addon:GetCurrentGroupType()
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

-- Process Party Invitation
function addon:HandlePartyInvite(inviterName, inviterGUID)
    local shouldAccept, reason = addon:ShouldAutoJoin(inviterName, inviterGUID)
    if not shouldAccept then
        if reason == "AFK" and AutoJoinBigginsDB and AutoJoinBigginsDB.announce then
            local displayName = inviterName or "Unknown"
            addon:PrintMsg(string_format("Party invitation from |cFF00FF00%s|r not auto-accepted (you are AFK).", displayName))
        end
        return
    end

    -- Accept the party invite
    AcceptGroup()
    addon:SuppressPopups()

    -- Delayed checks to guarantee dialog dismissal across slow client frames
    if C_Timer and C_Timer.After then
        C_Timer.After(0.05, function() addon:SuppressPopups() end)
        C_Timer.After(0.20, function() addon:SuppressPopups() end)
    end

    if AutoJoinBigginsDB and AutoJoinBigginsDB.announce then
        local displayName = inviterName or "Unknown"
        addon:PrintMsg(string_format("Auto-accepted party invitation from |cFF00FF00%s|r (%s).", displayName, reason or "Whitelisted"))
    end
end
