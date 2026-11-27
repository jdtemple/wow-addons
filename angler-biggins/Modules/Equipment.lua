--[[ ==============================================================================
    Angler Biggins - Asynchronous Equipment Queue Engine
    ------------------------------------------------------------------------------
    Manages safe unseating and equipping of fishing rods in Slot 28 with zero
    combat taint, cursor safety protections, and automatic timeout handling.
============================================================================== ]]--

local addonName, addon = ...

-- Cache global functions
local CreateFrame              = CreateFrame
local GetTime                  = GetTime
local InCombatLockdown         = InCombatLockdown
local UnitIsDeadOrGhost        = UnitIsDeadOrGhost
local IsMounted                = IsMounted
local ClearCursor              = ClearCursor
local GetCursorInfo            = GetCursorInfo
local PickupInventoryItem      = PickupInventoryItem
local PutItemInBackpack        = PutItemInBackpack
local PutItemInBag             = PutItemInBag
local GetInventoryItemID       = GetInventoryItemID

local C_Container              = C_Container
local C_Item                   = C_Item

local CONTAINER_BAG_OFFSET     = CONTAINER_BAG_OFFSET or 19

-- State Tracking & Queue Management
addon.isActivating = false
addon.lastActivationTime = 0
addon.ACTIVATION_COOLDOWN = 3.0 -- Cooldown between activations to prevent any rapid loop
addon.isAwake = false           -- Tracks whether the Underlight Angler traits are currently awake

local queue = {
    unequip = false,
    equip = nil,
}
addon.queue = queue

local queueFrame = CreateFrame("Frame", "AnglerBigginsQueueFrame")
addon.queueFrame = queueFrame

local queueElapsed = 0
local QUEUE_TICK = 0.25
local queueTimeout = 6.0

local function IsCursorHoldingItem(targetItemID)
    local cursorType, itemID = GetCursorInfo()
    if cursorType == "item" then
        return itemID == targetItemID, true
    end
    return false, cursorType ~= nil
end

local function DepositCursorIntoFirstFreeBag()
    for bag = 0, 4 do
        local freeSlots = C_Container.GetContainerNumFreeSlots(bag)
        if freeSlots and freeSlots > 0 then
            if bag == 0 then
                PutItemInBackpack()
            else
                PutItemInBag(CONTAINER_BAG_OFFSET + bag)
            end
            return true
        end
    end
    ClearCursor()
    return false
end

local function FindItemInBags(targetItemID)
    if not targetItemID or not C_Container or not C_Container.GetContainerNumSlots then
        return nil, nil
    end
    for bag = 0, 4 do
        local numSlots = C_Container.GetContainerNumSlots(bag)
        for slot = 1, numSlots do
            local itemID = C_Container.GetContainerItemID(bag, slot)
            if itemID == targetItemID then
                return bag, slot
            end
        end
    end
    return nil, nil
end

local function EquipItemToFishingSlot(targetItemID)
    if not targetItemID then return false end
    if addon:IsPlayerBusy() then return false end

    -- Already equipped in slot 28?
    if GetInventoryItemID("player", addon.INVSLOT_FISHING_TOOL) == targetItemID then
        return true
    end

    local bag, slot = FindItemInBags(targetItemID)
    if not bag or not slot then
        return false
    end

    ClearCursor()
    C_Container.PickupContainerItem(bag, slot)
    PickupInventoryItem(addon.INVSLOT_FISHING_TOOL)

    -- If another item was in slot 28, it is now on cursor. Return it to the vacated bag slot:
    local cursorType = GetCursorInfo()
    if cursorType == "item" then
        C_Container.PickupContainerItem(bag, slot)
    end
    ClearCursor()

    return true
end

local function StepUnequipSlot()
    if addon:IsPlayerBusy() then return end

    local equippedItem = GetInventoryItemID("player", addon.INVSLOT_FISHING_TOOL)
    if not equippedItem then
        -- Slot 28 is unseated and clear
        queue.unequip = false
        return
    end

    local isHoldingEquipped, isHoldingAnything = IsCursorHoldingItem(equippedItem)
    if isHoldingAnything and not isHoldingEquipped then
        -- Player is actively dragging an unrelated item; wait for cursor to clear
        return
    elseif not isHoldingAnything then
        PickupInventoryItem(addon.INVSLOT_FISHING_TOOL)
        local holdingNow = IsCursorHoldingItem(equippedItem)
        if holdingNow then
            if not DepositCursorIntoFirstFreeBag() then
                queue.unequip = false
            end
        end
    elseif isHoldingEquipped then
        if not DepositCursorIntoFirstFreeBag() then
            queue.unequip = false
        end
    end
end

local function StepEquipSlot()
    local equippedItem = GetInventoryItemID("player", addon.INVSLOT_FISHING_TOOL)
    if equippedItem == queue.equip then
        -- Desired item is confirmed equipped by server
        queue.equip = nil
        return
    end

    if not queue.equip then
        return
    end

    if addon:IsPlayerBusy() then
        -- Player is busy (e.g. casting or channeling); wait for cast to finish
        return
    end

    EquipItemToFishingSlot(queue.equip)
end

function addon:HandleQueue()
    if not queue.unequip and not queue.equip then
        queueFrame:SetScript("OnUpdate", nil)
        addon.isActivating = false
        return
    end

    queueElapsed = 0
    queueTimeout = 6.0

    queueFrame:SetScript("OnUpdate", function(self, elapsed)
        queueElapsed = queueElapsed + elapsed
        if queueElapsed < QUEUE_TICK then
            return
        end

        queueTimeout = queueTimeout - queueElapsed
        queueElapsed = 0

        -- Timeout, combat, or death protection
        if queueTimeout <= 0 or InCombatLockdown() or UnitIsDeadOrGhost("player") then
            queue.unequip = false
            queue.equip = nil
            self:SetScript("OnUpdate", nil)
            addon.isActivating = false
            return
        end

        if queue.unequip then
            StepUnequipSlot()
        elseif queue.equip then
            StepEquipSlot()
        else
            -- Queue finished successfully: rod is officially equipped in slot 28
            self:SetScript("OnUpdate", nil)
            addon.isActivating = false
            local db = AnglerBigginsDB or addon.defaults
            local currentSlotItem = GetInventoryItemID("player", addon.INVSLOT_FISHING_TOOL)
            if currentSlotItem == addon.UNDERLIGHT_ANGLER_ID then
                addon.isAwake = true
                if not db.quiet then
                    local _, link = C_Item.GetItemInfo(addon.UNDERLIGHT_ANGLER_ID)
                    local displayLink = link or "|cFFE6CC80[Underlight Angler]|r"
                    addon:PrintMsg("Equipped " .. displayLink .. ".")
                end
            else
                addon.isAwake = false
                if not db.quiet then
                    local name = db.pinnedPoleName or "|cFF00FF00Pinned Pole|r"
                    addon:PrintMsg("Equipped " .. name .. ".")
                end
            end
            addon:UpdateMacro()
            if addon.optionsPanel and addon.optionsPanel:IsShown() then
                addon:UpdateOptionsUI()
            end
        end
    end)
end

function addon:ActivateUnderlightAngler()
    local db = AnglerBigginsDB or addon.defaults
    if not db.enabled then return end
    if addon:IsPlayerBusy() or IsMounted() then return end
    if not addon:IsCurrentZoneAllowed() then return end
    if not addon:IsUnderlightSlotted() then return end

    if addon:IsUnderlightAwake() then
        return
    end

    local now = GetTime()
    if (now - addon.lastActivationTime) < addon.ACTIVATION_COOLDOWN then
        return
    end

    addon.lastActivationTime = now
    addon.isActivating = true

    -- Rod is already in slot 28, but dormant or suppressed (e.g. by gathering).
    -- Unseat to bag and re-equip to wake up:
    queue.unequip = true
    queue.equip = addon.UNDERLIGHT_ANGLER_ID
    addon:HandleQueue()
end

-- Main evaluation entry point
function addon:EvaluateWaterState()
    if addon:IsPlayerBusy() or IsMounted() then return end

    if not addon:IsPlayerInWater() then
        addon.isAwake = false
        return
    end

    -- If Underlight Angler is not equipped in slot 28, do nothing (manual swapping only)
    if not addon:IsUnderlightSlotted() then
        return
    end

    if addon:IsUnderlightAwake() then
        return
    end

    addon:ActivateUnderlightAngler()
end
