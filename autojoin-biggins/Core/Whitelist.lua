--[[ ==============================================================================
    AutoJoin Biggins - Whitelist Evaluation Engine
    ------------------------------------------------------------------------------
    Name normalization, Guild membership verification, in-game Character Friends
    check, Battle.net cross-client matching, and AFK safety gating.
============================================================================== ]]--

local addonName, addon = ...

-- Cache global functions
local strsplit                    = strsplit
local string_lower                = string.lower
local IsInGuild                   = IsInGuild
local C_GuildInfo                 = C_GuildInfo
local UnitIsInMyGuild             = UnitIsInMyGuild
local GetNumGuildMembers          = GetNumGuildMembers
local GetGuildRosterInfo          = GetGuildRosterInfo
local C_FriendList                = C_FriendList
local BNFeaturesEnabledAndConnected = BNFeaturesEnabledAndConnected
local BNGetNumFriends             = BNGetNumFriends
local C_BattleNet                 = C_BattleNet
local BNET_CLIENT_WOW             = BNET_CLIENT_WOW
local GetNormalizedRealmName      = GetNormalizedRealmName
local GetRealmName                = GetRealmName
local UnitIsAFK                   = UnitIsAFK

-- Name normalizer helper
function addon:NormalizeName(fullName)
    if not fullName then return "", "" end
    local name, realm = strsplit("-", fullName, 2)
    return name or "", realm or ""
end

-- Check Guild Membership
function addon:IsGuildMember(inviterGUID, inviterName)
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
        local reqName = addon:NormalizeName(inviterName)
        reqName = string_lower(reqName)
        for i = 1, numMembers do
            local fullName = GetGuildRosterInfo(i)
            if fullName then
                local mName = addon:NormalizeName(fullName)
                if string_lower(mName) == reqName then
                    return true
                end
            end
        end
    end

    return false
end

-- Check Character-Level Friends List
function addon:IsCharacterFriend(inviterGUID, inviterName)
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
        local reqName = addon:NormalizeName(inviterName)
        info = C_FriendList.GetFriendInfo(reqName)
        if info then
            return true
        end
    end

    return false
end

-- Check Battle.net Friends
function addon:IsBattleNetFriend(inviterGUID, inviterName)
    if not BNFeaturesEnabledAndConnected or not BNFeaturesEnabledAndConnected() then
        return false
    end

    local numFriends = BNGetNumFriends and BNGetNumFriends() or 0
    if numFriends == 0 then return false end

    local reqName, reqRealm = addon:NormalizeName(inviterName)
    reqName = string_lower(reqName)
    reqRealm = string_lower(reqRealm)
    local myRealm = string_lower(GetNormalizedRealmName and GetNormalizedRealmName() or GetRealmName() or "")

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
                    charName = string_lower(charName)
                    charRealm = string_lower(charRealm)

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
function addon:ShouldAutoJoin(inviterName, inviterGUID)
    local db = AutoJoinBigginsDB or addon.defaults
    if not db or not db.enabled then
        return false, nil
    end

    local isWhitelisted = false
    local reason = nil

    -- 1. All / Anyone Toggle (Explicit user opt-in)
    if db.all then
        isWhitelisted = true
        reason = "All Players"
    -- 2. Guild Members
    elseif db.guild and addon:IsGuildMember(inviterGUID, inviterName) then
        isWhitelisted = true
        reason = "Guild Member"
    -- 3. In-Game Friends List
    elseif db.friends and addon:IsCharacterFriend(inviterGUID, inviterName) then
        isWhitelisted = true
        reason = "Character Friend"
    -- 4. Battle.net Friends
    elseif db.bnet and addon:IsBattleNetFriend(inviterGUID, inviterName) then
        isWhitelisted = true
        reason = "Battle.net Friend"
    end

    if not isWhitelisted then
        return false, nil
    end

    -- AFK Safety Check: Do not auto-accept if player is marked AFK
    if db.pauseWhileAFK and UnitIsAFK and UnitIsAFK("player") then
        return false, "AFK"
    end

    return true, reason
end
