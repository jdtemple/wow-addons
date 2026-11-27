--[[ ==============================================================================
    SafeRelease Biggins - Context & State Evaluation Engine
    ------------------------------------------------------------------------------
    Guard state evaluation for raids, Mythic+ dungeons, delves, modifier keys,
    full raid wipe checks, and usable self-resurrect detection.
============================================================================== ]]--

local addonName, addon = ...

-- Cache global functions
local GetInstanceInfo    = GetInstanceInfo
local IsInInstance       = IsInInstance
local IsInRaid           = IsInRaid
local IsShiftKeyDown     = IsShiftKeyDown
local IsControlKeyDown   = IsControlKeyDown
local IsAltKeyDown       = IsAltKeyDown
local UnitIsDeadOrGhost  = UnitIsDeadOrGhost
local GetNumGroupMembers = GetNumGroupMembers
local UnitExists         = UnitExists
local C_DeathInfo        = C_DeathInfo
local DEFAULT_CHAT_FRAME = DEFAULT_CHAT_FRAME
local print              = print

-- Configuration Defaults
addon.defaults = {
    enabled         = true,
    raids           = true,           -- Protect in Raids (LFR, Normal, Heroic, Mythic)
    dungeons        = false,          -- Protect in Dungeons (Normal, Heroic, Mythic 0)
    mythicPlus      = false,          -- Protect in Mythic+ Dungeons
    delves          = false,          -- Protect in Delves & Scenarios
    mode            = "COUNTDOWN",    -- "COUNTDOWN", "MODIFIER", "HYBRID"
    delaySeconds    = 5,              -- Countdown delay duration (1-10 seconds)
    modifierKey     = "ALT",          -- "ALT", "SHIFT", "CTRL"
    bypassFullWipe  = false,          -- Skip guard if all group members are dead (Default: OFF)
    announce        = true,           -- Echo settings changes to chat
}

-- Print formatted addon message
function addon:PrintMsg(msg)
    if DEFAULT_CHAT_FRAME then
        DEFAULT_CHAT_FRAME:AddMessage("|cFFFFD100SafeRelease Biggins:|r " .. msg)
    else
        print("|cFFFFD100SafeRelease Biggins:|r " .. msg)
    end
end

function addon:IsModifierKeyDown(modKey)
    if modKey == "SHIFT" then
        return IsShiftKeyDown()
    elseif modKey == "CTRL" then
        return IsControlKeyDown()
    else
        return IsAltKeyDown()
    end
end

function addon:GetModifierDisplayName(modKey)
    if modKey == "SHIFT" then return "SHIFT" end
    if modKey == "CTRL"  then return "CTRL" end
    return "ALT"
end

-- Check if entire raid is dead (full wipe)
function addon:IsFullRaidWipe()
    if not IsInRaid() then return false end
    local num = GetNumGroupMembers()
    if not num or num == 0 then return false end

    for i = 1, num do
        local unit = "raid" .. i
        if UnitExists(unit) and not UnitIsDeadOrGhost(unit) then
            return false
        end
    end
    return true
end

-- Check if self-resurrect is ready (Ankh, Soulstone)
function addon:HasUsableSelfResurrect()
    if C_DeathInfo and C_DeathInfo.GetSelfResurrectOptions then
        local options = C_DeathInfo.GetSelfResurrectOptions()
        return (options and #options > 0)
    end
    return false
end

-- Evaluate whether the current zone/instance should be guarded
function addon:IsCurrentContextGuarded()
    local db = SafeReleaseBigginsDB or addon.defaults
    if not db.enabled then return false end

    local inInstance, instanceType = IsInInstance()
    local _, _, difficultyID = GetInstanceInfo()

    if inInstance then
        if instanceType == "raid" then
            if db.bypassFullWipe and addon:IsFullRaidWipe() then
                return false
            end
            return db.raids == true
        elseif instanceType == "party" then
            if difficultyID == 8 then -- Mythic+ Keystone
                return db.mythicPlus == true
            else
                return db.dungeons == true
            end
        elseif instanceType == "scenario" then
            return db.delves == true
        end
    end

    return false
end
