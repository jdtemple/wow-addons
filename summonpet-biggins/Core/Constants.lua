--[[ ==============================================================================
    SummonPet Biggins - Core Constants & Environment State Guards
    ------------------------------------------------------------------------------
    Default settings, grace period timers, and zero-allocation pre-condition
    guards for flight, stealth, instances, mounted states, and spellcasting.
============================================================================== ]]--

local addonName, addon = ...

-- Cache global functions
local IsStealthed               = IsStealthed
local IsInInstance              = IsInInstance
local GetInstanceInfo           = GetInstanceInfo
local IsFlying                  = IsFlying
local IsMounted                 = IsMounted
local InCombatLockdown          = InCombatLockdown
local UnitIsDeadOrGhost         = UnitIsDeadOrGhost
local UnitCastingInfo           = UnitCastingInfo
local UnitChannelInfo           = UnitChannelInfo
local string_lower              = string.lower
local string_find               = string.find
local print                     = print
local C_Scenario                = C_Scenario
local C_ChallengeMode           = C_ChallengeMode
local C_PlayerInfo              = C_PlayerInfo

-- Timing & Debounce Constants (Adjustable Grace Periods)
addon.DISMOUNT_DEBOUNCE_DELAY  = 1.0   -- Buffer (seconds) after dismounting before companion is summoned
addon.TOUCHDOWN_DEBOUNCE_DELAY = 1.0   -- Buffer (seconds) after landing from flight while mounted
addon.UNSTEALTH_DEBOUNCE_DELAY = 1.0   -- Buffer (seconds) after exiting stealth before companion is summoned
addon.CAST_IDLE_DEBOUNCE_DELAY = 1.5   -- Buffer (seconds) after spellcast/channel finishes before companion is summoned
addon.TICKER_POLL_INTERVAL     = 0.25  -- Grounded mount watcher polling frequency (seconds)
addon.DISMISS_RETRY_INTERVAL   = 0.25  -- Debounced dismiss retry interval (seconds)
addon.MAX_DISMISS_ATTEMPTS     = 4     -- Maximum retry attempts for companion dismissal

-- Default Settings
addon.defaults = {
    enabled              = true,
    mode                 = "FAVORITES", -- "FAVORITES", "RANDOM", or "PINNED"
    pinnedPetGUID        = nil,         -- GUID of pinned pet
    pinnedPetName        = "None",      -- Display name of pinned pet
    autoDismissInStealth = true,
    autoDismissInstances = true,        -- Master toggle for instance dismissal
    dismissRaids         = true,        -- Raids
    dismissMPlus         = true,        -- Mythic+ Dungeons
    dismissDungeons      = false,       -- Regular Dungeons
    dismissDelves        = false,       -- Delves & Labyrinths
    summonWhileMounted   = false,       -- Allow companion while mounted on the ground
    printStatus          = true,
}

-- Print helper with colored prefix
function addon:PrintMsg(msg)
    print("|cFFFFD100[SummonPetBiggins]|r " .. msg)
end

function addon:IsStealthedActive()
    return IsStealthed and IsStealthed()
end

function addon:ShouldDismissInStealth()
    return SummonPetBigginsDB and SummonPetBigginsDB.autoDismissInStealth and addon:IsStealthedActive()
end

-- Instance Content Detection & Auto-Dismiss Check
function addon:ShouldDismissInCurrentInstance()
    if not (SummonPetBigginsDB and SummonPetBigginsDB.autoDismissInstances) then
        return false
    end

    local inInstance, instanceType = IsInInstance()
    local isScenario = (C_Scenario and C_Scenario.IsInScenario and C_Scenario.IsInScenario())

    if not inInstance and not isScenario then
        -- Catch active Mythic+ challenge mode during zone transitions
        if SummonPetBigginsDB.dismissMPlus and C_ChallengeMode and C_ChallengeMode.IsChallengeModeActive and C_ChallengeMode.IsChallengeModeActive() then
            return true
        end
        return false
    end

    local name, _, difficultyID = GetInstanceInfo()
    name = name or ""
    local nameLower = string_lower(name)

    -- 1. Raids (Normal, Heroic, Mythic, LFR)
    if instanceType == "raid" then
        return SummonPetBigginsDB.dismissRaids
    end

    -- 2. Mythic+ Dungeons (Challenge Mode or Mythic 0)
    local isMPlus = (difficultyID == 8 or difficultyID == 23) or (C_ChallengeMode and C_ChallengeMode.IsChallengeModeActive and C_ChallengeMode.IsChallengeModeActive())
    if isMPlus then
        return SummonPetBigginsDB.dismissMPlus
    end

    -- 3. Delves & Labyrinths (Scenario instance, difficulty 208, active scenario, or name contains delve/labyrinth)
    local isDelveOrLab = (instanceType == "scenario")
        or (difficultyID == 208)
        or isScenario
        or (string_find(nameLower, "delve") ~= nil)
        or (string_find(nameLower, "labyrinth") ~= nil)
    if isDelveOrLab then
        return SummonPetBigginsDB.dismissDelves
    end

    -- 4. Regular Dungeons (Normal, Heroic, Timewalking, Follower)
    if instanceType == "party" then
        return SummonPetBigginsDB.dismissDungeons
    end

    return false
end

function addon:IsInFlightActive()
    local isGliding = (C_PlayerInfo and C_PlayerInfo.GetGlidingInfo and C_PlayerInfo.GetGlidingInfo())
    return (IsFlying and IsFlying()) or (isGliding == true)
end

function addon:IsMountedBlocked()
    if not IsMounted() then
        return false
    end
    -- If mounted: allow only if summonWhileMounted is enabled AND player is on the ground (not flying/falling/gliding)
    if SummonPetBigginsDB and SummonPetBigginsDB.summonWhileMounted then
        return addon:IsInFlightActive()
    end
    return true
end

function addon:ShouldDismissMounted()
    if not IsMounted() then
        return false
    end
    if not (SummonPetBigginsDB and SummonPetBigginsDB.summonWhileMounted) then
        return true
    end
    return addon:IsInFlightActive()
end

function addon:IsPlayerCastingOrChanneling()
    return (UnitCastingInfo and UnitCastingInfo("player") ~= nil) or (UnitChannelInfo and UnitChannelInfo("player") ~= nil)
end

-- Consolidated Pre-Condition Guard (Single Source of Truth)
function addon:CanSummon()
    if not (SummonPetBigginsDB and SummonPetBigginsDB.enabled) then
        return false
    end
    if InCombatLockdown() or UnitIsDeadOrGhost("player") then
        return false
    end
    if addon:IsStealthedActive() or addon:IsMountedBlocked() or addon:ShouldDismissInCurrentInstance() then
        return false
    end
    if addon:IsPlayerCastingOrChanneling() then
        return false
    end
    return true
end
