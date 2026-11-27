--[[ ==============================================================================
    Angler Biggins - State & Context Evaluation Engine
    ------------------------------------------------------------------------------
    Detects water walking, fish form buffs, Underlight Angler equipment status,
    submersion, delve breath meters, and zone allowances.
============================================================================== ]]--

local addonName, addon = ...

-- Item & Slot Constants
addon.UNDERLIGHT_ANGLER_ID = 133755
addon.INVSLOT_FISHING_TOOL  = 28
addon.INVSLOT_MAIN_HAND     = 16

-- Cache global functions
local AuraUtil                 = AuraUtil
local C_UnitAuras              = C_UnitAuras
local C_Item                   = C_Item
local C_ChallengeMode          = C_ChallengeMode
local GetInventoryItemID       = GetInventoryItemID
local GetInstanceInfo          = GetInstanceInfo
local GetMirrorTimerProgress   = GetMirrorTimerProgress
local InCombatLockdown         = InCombatLockdown
local IsInInstance             = IsInInstance
local IsMounted                = IsMounted
local IsSubmerged              = IsSubmerged
local IsSwimming               = IsSwimming
local UnitIsDeadOrGhost        = UnitIsDeadOrGhost
local UnitCastingInfo          = UnitCastingInfo
local UnitChannelInfo          = UnitChannelInfo
local select                   = select

-- Check if the player currently has the Surface Tension buff (Underlight Angler water walking & trait active)
function addon:HasSurfaceTensionBuff()
    if AuraUtil and AuraUtil.FindAuraByName then
        local aura = AuraUtil.FindAuraByName("Surface Tension", "player")
        if aura then return true end
    end
    if C_UnitAuras and C_UnitAuras.GetAuraDataByIndex then
        for i = 1, 40 do
            local aura = C_UnitAuras.GetAuraDataByIndex("player", i, "HELPFUL")
            if not aura then break end
            if aura.name == "Surface Tension" then
                return true
            end
        end
    end
    return false
end

-- Check if the Underlight Angler is equipped in the Fishing Profession Tool slot (Slot 28)
function addon:IsUnderlightSlotted()
    return GetInventoryItemID("player", addon.INVSLOT_FISHING_TOOL) == addon.UNDERLIGHT_ANGLER_ID
end

-- Determine whether the Underlight Angler is currently considered active and awakened
function addon:IsUnderlightAwake()
    -- Underlight Angler MUST be equipped in Slot 28 to be considered active
    if not addon:IsUnderlightSlotted() then
        addon.isAwake = false
        return false
    end

    -- While mounted, Underlight Angler traits are naturally suppressed by the mount
    if IsMounted() then
        return true
    end

    -- In combat, gear swapping is locked out by Blizzard
    if InCombatLockdown() then
        return true
    end

    -- Active Underlight Angler traits are evidenced strictly by the Surface Tension buff
    if addon:HasSurfaceTensionBuff() then
        addon.isAwake = true
        return true
    end

    addon.isAwake = false
    return false
end

-- Check if Underlight Angler is anywhere on the player (slot 28, main hand, or bags)
function addon:HasUnderlightAngler()
    if addon:IsUnderlightSlotted() then return true end
    if GetInventoryItemID("player", addon.INVSLOT_MAIN_HAND) == addon.UNDERLIGHT_ANGLER_ID then return true end
    if C_Item and C_Item.GetItemCount and C_Item.GetItemCount(addon.UNDERLIGHT_ANGLER_ID) > 0 then return true end
    return false
end

-- Check if the player is currently in water (swimming, submerged, or breath meter active)
function addon:IsPlayerInWater()
    local db = AnglerBigginsDB or addon.defaults
    if IsSwimming() or IsSubmerged() then
        return true
    end
    if db.enableDelves and GetMirrorTimerProgress and GetMirrorTimerProgress("BREATH") > 0 then
        return true
    end
    return false
end

-- Check if the current zone allows activation based on settings
function addon:IsCurrentZoneAllowed()
    local db = AnglerBigginsDB or addon.defaults
    if not db.enabled then return false end

    local inInstance, instanceType = IsInInstance()
    if inInstance then
        -- Suppress in Mythic+ / Challenge Mode runs to avoid equipment lockdown chatter
        if (C_ChallengeMode and C_ChallengeMode.IsChallengeModeActive and C_ChallengeMode.IsChallengeModeActive())
            or (select(3, GetInstanceInfo()) == 8) then
            return false
        end

        if instanceType == "party" or instanceType == "raid" then
            return db.enableInstances == true
        elseif instanceType == "pvp" or instanceType == "arena" then
            return db.enablePvP == true
        elseif instanceType == "scenario" then
            return db.enableDelves == true
        end
    end
    return true
end

-- Check if the player is currently locked in an un-swappable state (combat, dead/ghost, casting, or channeling)
function addon:IsPlayerBusy()
    if InCombatLockdown() or UnitIsDeadOrGhost("player") then
        return true
    end
    if (UnitCastingInfo and UnitCastingInfo("player") ~= nil)
        or (UnitChannelInfo and UnitChannelInfo("player") ~= nil) then
        return true
    end
    return false
end

-- Helper to find currently equipped fishing pole in slot 28 or weapon slot 16
function addon:GetEquippedFishingPoleID()
    local equippedItem = GetInventoryItemID("player", addon.INVSLOT_FISHING_TOOL)
    if not equippedItem then
        local weaponID = GetInventoryItemID("player", addon.INVSLOT_MAIN_HAND)
        if weaponID then
            local _, _, _, _, _, itemClassID, itemSubClassID = C_Item.GetItemInfoInstant(weaponID)
            if itemClassID == 2 and itemSubClassID == 20 then
                equippedItem = weaponID
            end
        end
    end
    return equippedItem
end
