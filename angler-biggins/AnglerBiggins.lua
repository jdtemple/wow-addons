--[[ ==============================================================================
    Angler Biggins v2.0.0 - Dual-Rod Fishing Suite & Underlight Angler Automation
    ------------------------------------------------------------------------------
    Author: Biggins (US-Whisperwind)
    Compatibility: World of Warcraft: Midnight / The War Within (Patch 11.x - 12.x)

    ARCHITECTURAL OVERVIEW:
    1. Zero-Taint Event-Driven Lifecycle: Operates purely on native WoW events
       (MOUNT_JOURNAL_USABILITY_CHANGED, MIRROR_TIMER_START, PLAYER_REGEN_ENABLED, UNIT_AURA)
       with zero background OnUpdate script polling or frame churn.
    2. Dual-Rod Pinning & Management: Allows pinning a primary high-stat fishing pole
       (such as engineered or expansion-specific rods) and toggling with the Underlight Angler.
    3. Dynamic Action Bar Button: Generates and auto-maintains an action bar macro that
       dynamically flips its icon, name, and tooltip to show the rod to equip next.
    4. Emergency Water Lifejacket: Automatically equips the Underlight Angler when entering
       water with your primary rod equipped, granting instant fish form and water walking.
    5. Native Profession-Slot Swapping: Resolves Blizzard slot-28 limitations through atomic
       container-to-inventory swaps without item shuffling or abandoned gear.
    6. Modern Blizzard Canvas Settings: Fully integrated into Options -> AddOns ->
       Biggins AddOns -> Angler with master enable toggle, live diagnostics, and [ Defaults ].
============================================================================== ]]--

local addonName, addon = ...
_G["AnglerBiggins"] = addon
addon.version = "2.0.0"

-- Item & Spell Constants
local UNDERLIGHT_ANGLER_ID        = 133755
local INVSLOT_FISHING_TOOL         = 28
local INVSLOT_MAIN_HAND            = 16
local SPELL_FISH_FORM              = 201944 -- Underlight Blessing (Fish Form & Swim Speed)
local SPELL_FISHING_FOR_ATTENTION  = 394009 -- Cosmetic Fishing Visual Aura (Outdoor only)

-- Upvalue caching
local C_ChallengeMode        = C_ChallengeMode
local CreateFrame            = CreateFrame
local GetInstanceInfo        = GetInstanceInfo
local GetTime                = GetTime
local InCombatLockdown       = InCombatLockdown
local IsInInstance           = IsInInstance
local IsMounted              = IsMounted
local IsSubmerged            = IsSubmerged
local IsSwimming             = IsSwimming
local UnitIsDeadOrGhost      = UnitIsDeadOrGhost
local GetInventoryItemID     = GetInventoryItemID
local GetMirrorTimerProgress = GetMirrorTimerProgress
local ClearCursor            = ClearCursor
local PickupInventoryItem    = PickupInventoryItem
local PutItemInBackpack      = PutItemInBackpack
local PutItemInBag           = PutItemInBag
local CONTAINER_BAG_OFFSET   = CONTAINER_BAG_OFFSET or 19

-- Configuration Defaults
local defaults = {
    enabled          = true,  -- Master addon toggle
    enableLifejacket = true,  -- Auto-equip Underlight Angler when entering water (Lifejacket Mode)
    enableInstances  = true,  -- Activate in Dungeons & Raids
    enableDelves     = true,  -- Underwater Delves & Breath Meter detection
    enablePvP        = false, -- Battlegrounds & Arenas (Default: OFF)
    quiet            = true,  -- Suppress chat activation messages
    pinnedPoleID     = nil,   -- Item ID of secondary pinned fishing pole
    pinnedPoleName   = "None",-- Display name of secondary pinned fishing pole
    pinnedPoleIcon   = nil,   -- Icon texture of secondary pinned fishing pole
}

-- UI Widget References for Dynamic Control Attenuation
local uiWidgets = {
    subControls = {},
}

-- State Tracking & Queue Management
local isActivating = false
local lastActivationTime = 0
local ACTIVATION_COOLDOWN = 3.0 -- Cooldown between activations to prevent any loop
local isAwake = false           -- Tracks whether the Underlight Angler traits are currently awake

local queue = {
    unequip = false,
    equip = nil,
}

local queueFrame = CreateFrame("Frame", "AnglerBigginsQueueFrame")
local queueElapsed = 0
local QUEUE_TICK = 0.25
local queueTimeout = 6.0

-- Print formatted addon message
local function PrintMsg(msg)
    DEFAULT_CHAT_FRAME:AddMessage("|cFFFFD100Angler Biggins:|r " .. msg)
end

-- ==============================================================================
-- 1. CONTEXT & STATE EVALUATION
-- ==============================================================================

-- Check if the player currently has the Fishing for Attention aura (spell 394009)
local function HasFishingAura()
    if C_UnitAuras and C_UnitAuras.GetPlayerAuraBySpellID then
        return C_UnitAuras.GetPlayerAuraBySpellID(SPELL_FISHING_FOR_ATTENTION) ~= nil
    end
    return false
end

-- Check if the player currently has the Underlight Blessing (Fish Form) buff
local function HasFishFormBuff()
    if C_UnitAuras and C_UnitAuras.GetPlayerAuraBySpellID then
        local aura = C_UnitAuras.GetPlayerAuraBySpellID(SPELL_FISH_FORM)
        return aura ~= nil
    end
    return false
end

-- Check if the Underlight Angler is equipped in the Fishing Profession Tool slot (Slot 28)
local function IsUnderlightSlotted()
    return GetInventoryItemID("player", INVSLOT_FISHING_TOOL) == UNDERLIGHT_ANGLER_ID
end

-- Determine whether the Underlight Angler is currently considered active and awakened
local function IsUnderlightAwake()
    -- Underlight Angler MUST be equipped in Slot 28 to be considered active
    if not IsUnderlightSlotted() then
        isAwake = false
        return false
    end

    -- While mounted, Underlight Angler traits are naturally suppressed by the mount
    if IsMounted() then
        return true
    end

    -- Active Underlight Angler traits are evidenced by either:
    -- 1. Fishing for Attention aura (spell 394009) granted upon slot 28 equip/wake
    -- 2. Underlight Blessing (spell 201944) fish form active in water
    if HasFishingAura() or HasFishFormBuff() then
        isAwake = true
        return true
    end

    -- If neither aura exists (e.g. clicked off, combat dropped, or dormant after login), mark dormant:
    isAwake = false
    return false
end

-- Check if Underlight Angler is anywhere on the player (slot 28, main hand, or bags)
local function HasUnderlightAngler()
    if IsUnderlightSlotted() then return true end
    if GetInventoryItemID("player", INVSLOT_MAIN_HAND) == UNDERLIGHT_ANGLER_ID then return true end
    if C_Item and C_Item.GetItemCount and C_Item.GetItemCount(UNDERLIGHT_ANGLER_ID) > 0 then return true end
    return false
end

-- Check if the player is currently in water (swimming, submerged, or breath meter active)
local function IsPlayerInWater()
    local db = AnglerBigginsDB or defaults
    if IsSwimming() or IsSubmerged() then
        return true
    end
    if db.enableDelves and GetMirrorTimerProgress and GetMirrorTimerProgress("BREATH") > 0 then
        return true
    end
    return false
end

-- Check if the current zone allows activation based on settings
local function IsCurrentZoneAllowed()
    local db = AnglerBigginsDB or defaults
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

-- ==============================================================================
-- 2. ASYNC EQUIPMENT QUEUE ENGINE
-- ==============================================================================

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
    if InCombatLockdown() then return false end

    -- Already equipped in slot 28?
    if GetInventoryItemID("player", INVSLOT_FISHING_TOOL) == targetItemID then
        return true
    end

    local bag, slot = FindItemInBags(targetItemID)
    if not bag or not slot then
        return false
    end

    ClearCursor()
    C_Container.PickupContainerItem(bag, slot)
    PickupInventoryItem(INVSLOT_FISHING_TOOL)

    -- If another item was in slot 28, it is now on cursor. Return it to the vacated bag slot:
    local cursorType = GetCursorInfo()
    if cursorType == "item" then
        C_Container.PickupContainerItem(bag, slot)
    end
    ClearCursor()

    return true
end

local function StepUnequipSlot()
    local equippedItem = GetInventoryItemID("player", INVSLOT_FISHING_TOOL)
    if not equippedItem then
        -- Slot 28 is unseated and clear
        queue.unequip = false
        return
    end

    local isHoldingTarget, isHoldingAnything = IsCursorHoldingItem(UNDERLIGHT_ANGLER_ID)
    if isHoldingAnything and not isHoldingTarget then
        -- Player is actively dragging another item; wait for cursor to clear
        return
    elseif not isHoldingAnything then
        PickupInventoryItem(INVSLOT_FISHING_TOOL)
        local holdingNow = IsCursorHoldingItem(UNDERLIGHT_ANGLER_ID)
        if holdingNow then
            if not DepositCursorIntoFirstFreeBag() then
                queue.unequip = false
            end
        end
    elseif isHoldingTarget then
        if not DepositCursorIntoFirstFreeBag() then
            queue.unequip = false
        end
    end
end

local function StepEquipSlot()
    local equippedItem = GetInventoryItemID("player", INVSLOT_FISHING_TOOL)
    if equippedItem == queue.equip then
        -- Desired item is confirmed equipped by server
        queue.equip = nil
        return
    end

    if not queue.equip then
        queue.equip = nil
        return
    end

    if EquipItemToFishingSlot(queue.equip) then
        queue.equip = nil
    end
end

local function HandleQueue()
    if not queue.unequip and not queue.equip then
        queueFrame:SetScript("OnUpdate", nil)
        isActivating = false
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

        -- Timeout, combat, or mounted protection
        if queueTimeout <= 0 or InCombatLockdown() or UnitIsDeadOrGhost("player") or IsMounted() then
            queue.unequip = false
            queue.equip = nil
            self:SetScript("OnUpdate", nil)
            isActivating = false
            return
        end

        if queue.unequip then
            StepUnequipSlot()
        elseif queue.equip then
            StepEquipSlot()
        else
            -- Queue finished successfully: rod is officially awake in slot 28
            self:SetScript("OnUpdate", nil)
            isActivating = false
            isAwake = true
            local db = AnglerBigginsDB or defaults
            if not db.quiet then
                PrintMsg("Underlight Angler activated.")
            end
            addon:UpdateMacro()
            if addon.optionsPanel and addon.optionsPanel:IsShown() then
                addon:UpdateOptionsUI()
            end
        end
    end)
end

local function ActivateUnderlightAngler()
    local db = AnglerBigginsDB or defaults
    if not db.enabled then return end
    if InCombatLockdown() or UnitIsDeadOrGhost("player") or IsMounted() then return end
    if not IsCurrentZoneAllowed() then return end
    if not HasUnderlightAngler() then return end

    -- Once awake for the current session, NEVER unseat the rod again!
    -- This prevents periodic flickering, stealth breaks, and dropping on lakebeds.
    if IsUnderlightAwake() then
        return
    end

    local now = GetTime()
    if (now - lastActivationTime) < ACTIVATION_COOLDOWN then
        return
    end

    lastActivationTime = now
    isActivating = true

    if IsUnderlightSlotted() then
        -- Rod is in slot 28, but dormant. Unseat to bag and re-equip ONCE to wake up:
        queue.unequip = true
        queue.equip = UNDERLIGHT_ANGLER_ID
    else
        -- Rod is in bag: auto-equip into slot 28 (Lifejacket Mode)
        if not db.enableLifejacket then
            isActivating = false
            return
        end
        queue.unequip = false
        queue.equip = UNDERLIGHT_ANGLER_ID
    end

    HandleQueue()
end

-- Main evaluation entry point
local function EvaluateWaterState()
    if InCombatLockdown() or UnitIsDeadOrGhost("player") or IsMounted() then return end

    if not IsPlayerInWater() then
        return
    end

    if IsUnderlightAwake() then
        return
    end

    ActivateUnderlightAngler()
end

-- ==============================================================================
-- 3. DUAL-POLE SWAPPING & ACTION BAR MACRO ENGINE
-- ==============================================================================

local MACRO_NAME = "AnglerBiggins"

-- Generate the appropriate macro icon and tooltip text based on current gear state
function addon:GetMacroContent()
    local db = AnglerBigginsDB or defaults
    local isSlotted = IsUnderlightSlotted()

    if isSlotted then
        -- Currently holding Underlight Angler: next click equips Pinned Pole
        if db.pinnedPoleID then
            local icon = db.pinnedPoleIcon or (C_Item and C_Item.GetItemIconByID and C_Item.GetItemIconByID(db.pinnedPoleID)) or 136240
            local body = "#showtooltip item:" .. db.pinnedPoleID .. "\n/anglerb swap"
            return icon, body
        else
            local icon = 136240 -- default fishing icon
            local body = "#showtooltip\n/anglerb swap"
            return icon, body
        end
    else
        -- Currently holding Pinned Pole (or another rod): next click equips Underlight Angler
        local icon = (C_Item and C_Item.GetItemIconByID and C_Item.GetItemIconByID(UNDERLIGHT_ANGLER_ID)) or 133755
        local body = "#showtooltip item:" .. UNDERLIGHT_ANGLER_ID .. "\n/anglerb swap"
        return icon, body
    end
end

-- Update existing macro icon and body without recreating it
function addon:UpdateMacro()
    if InCombatLockdown() then return end

    local macroIdx = GetMacroIndexByName(MACRO_NAME)
    if not macroIdx or macroIdx == 0 then
        return
    end

    local icon, body = addon:GetMacroContent()
    EditMacro(macroIdx, MACRO_NAME, icon, body)
end

-- Create or update the AnglerBiggins macro and return its index
function addon:EnsureMacro()
    if InCombatLockdown() then
        PrintMsg("|cFFFF5555Cannot create or modify macros during combat lockdown.|r")
        return nil
    end

    local icon, body = addon:GetMacroContent()
    local macroIdx = GetMacroIndexByName(MACRO_NAME)

    if macroIdx and macroIdx > 0 then
        EditMacro(macroIdx, MACRO_NAME, icon, body)
        return macroIdx
    end

    -- Macro doesn't exist yet: check slots and create
    local numGlobal, numPerChar = GetNumMacros()
    local isPerChar = false
    if numGlobal < 120 then
        isPerChar = false
    elseif numPerChar < 18 then
        isPerChar = true
    else
        PrintMsg("|cFFFF5555Macro storage is full!|r Free up a macro slot (General or Character-Specific) to use the action button.")
        return nil
    end

    macroIdx = CreateMacro(MACRO_NAME, icon, body, isPerChar)
    return macroIdx
end

-- Pick up the AnglerBiggins macro and place it directly onto the cursor
function addon:PickupActionButton()
    if InCombatLockdown() then
        PrintMsg("|cFFFF5555Cannot pick up macros during combat lockdown.|r")
        return
    end

    local macroIdx = addon:EnsureMacro()
    if macroIdx and macroIdx > 0 then
        ClearCursor()
        PickupMacro(macroIdx)
        PrintMsg("Rod swap button placed on cursor. Click any action bar slot to place it.")
    end
end

-- Pin the currently equipped fishing pole
function addon:PinCurrentPole()
    local db = AnglerBigginsDB or defaults

    -- Check Slot 28 (Fishing Tool) first
    local poleID = GetInventoryItemID("player", INVSLOT_FISHING_TOOL)
    if not poleID or poleID == UNDERLIGHT_ANGLER_ID then
        -- Check weapon slot 16 in case player equipped an old 2H pole as a weapon
        local weaponID = GetInventoryItemID("player", INVSLOT_MAIN_HAND)
        if weaponID and weaponID ~= UNDERLIGHT_ANGLER_ID then
            local _, _, _, _, _, itemClassID, itemSubClassID = C_Item.GetItemInfoInstant(weaponID)
            if itemClassID == 2 and itemSubClassID == 20 then
                poleID = weaponID
            end
        end
    end

    if not poleID then
        PrintMsg("|cFFFF5555No fishing pole currently equipped!|r Equip the pole you want to pin first, then type |cFFFFD100/anglerb pin|r.")
        return false
    end

    if poleID == UNDERLIGHT_ANGLER_ID then
        PrintMsg("|cFFFF5555Cannot pin Underlight Angler as your secondary pole!|r Equip your other fishing pole first, then type |cFFFFD100/anglerb pin|r.")
        return false
    end

    local itemName, itemLink, _, _, _, _, _, _, _, itemTexture = C_Item.GetItemInfo(poleID)
    if not itemName then
        itemName = "Fishing Pole (ID: " .. poleID .. ")"
        itemLink = itemName
        itemTexture = (C_Item and C_Item.GetItemIconByID and C_Item.GetItemIconByID(poleID)) or 136240
    end

    db.pinnedPoleID = poleID
    db.pinnedPoleName = itemLink or itemName
    db.pinnedPoleIcon = itemTexture or 136240

    PrintMsg("Pinned fishing pole: |cFF00FF00" .. (itemLink or itemName) .. "|r.")
    addon:UpdateMacro()
    addon:UpdateOptionsUI()
    return true
end

-- Clear the currently pinned pole
function addon:ClearPinnedPole()
    local db = AnglerBigginsDB or defaults
    db.pinnedPoleID = nil
    db.pinnedPoleName = "None"
    db.pinnedPoleIcon = nil

    PrintMsg("Cleared pinned fishing pole.")
    addon:UpdateMacro()
    addon:UpdateOptionsUI()
end

-- Toggle between Underlight Angler and Pinned Pole
function addon:TogglePoles()
    if InCombatLockdown() then
        PrintMsg("|cFFFF5555Cannot swap fishing poles during combat lockdown.|r")
        return
    end

    local db = AnglerBigginsDB or defaults
    local isUnderlight = IsUnderlightSlotted()

    if isUnderlight then
        -- Currently holding Underlight Angler: swap to Pinned Pole
        local pinnedID = db.pinnedPoleID
        if not pinnedID then
            PrintMsg("|cFFFF5555No secondary fishing pole pinned!|r Equip your main pole and type |cFFFFD100/anglerb pin|r.")
            return
        end

        local count = C_Item and C_Item.GetItemCount and C_Item.GetItemCount(pinnedID)
        if not count or count < 1 then
            local poleName = db.pinnedPoleName or "Pinned Pole"
            PrintMsg("|cFFFF5555Pinned pole (" .. poleName .. ") not found in bags!|r")
            return
        end

        isAwake = false
        if EquipItemToFishingSlot(pinnedID) then
            if not db.quiet then
                PrintMsg("Equipped |cFF00FF00" .. (db.pinnedPoleName or "Pinned Pole") .. "|r.")
            end
        else
            PrintMsg("|cFFFF5555Failed to equip pinned pole into fishing slot.|r")
        end
    else
        -- Currently holding Pinned Pole (or another rod): swap to Underlight Angler
        if not HasUnderlightAngler() then
            PrintMsg("|cFFFF5555Underlight Angler not found in bags or equipment!|r")
            return
        end

        if EquipItemToFishingSlot(UNDERLIGHT_ANGLER_ID) then
            if not db.quiet then
                PrintMsg("Equipped |cFF00FF00Underlight Angler|r.")
            end
            isAwake = true
        else
            ActivateUnderlightAngler()
        end
    end

    addon:UpdateMacro()
    addon:UpdateOptionsUI()
end

-- ==============================================================================
-- 4. EVENT DISPATCHER
-- ==============================================================================

local eventFrame = CreateFrame("Frame", "AnglerBigginsEventFrame")
eventFrame:RegisterEvent("ADDON_LOADED")
eventFrame:RegisterEvent("PLAYER_LOGIN")
eventFrame:RegisterEvent("PLAYER_ENTERING_WORLD")
eventFrame:RegisterEvent("MOUNT_JOURNAL_USABILITY_CHANGED")
eventFrame:RegisterEvent("MIRROR_TIMER_START")
eventFrame:RegisterEvent("MIRROR_TIMER_STOP")
eventFrame:RegisterEvent("PLAYER_REGEN_DISABLED")
eventFrame:RegisterEvent("PLAYER_REGEN_ENABLED")
eventFrame:RegisterEvent("PLAYER_EQUIPMENT_CHANGED")
eventFrame:RegisterUnitEvent("UNIT_AURA", "player")

eventFrame:SetScript("OnEvent", function(self, event, arg1, ...)
    if event == "ADDON_LOADED" and arg1 == addonName then
        if not AnglerBigginsDB then
            AnglerBigginsDB = CopyTable(defaults)
        else
            for k, v in pairs(defaults) do
                if AnglerBigginsDB[k] == nil then
                    AnglerBigginsDB[k] = v
                end
            end
        end
    elseif event == "PLAYER_LOGIN" then
        addon:CreateSettingsUI()
        addon:UpdateMacro()
    elseif event == "PLAYER_REGEN_DISABLED" then
        -- Combat drops Underlight Angler traits: reset awake state and abort any active queue
        isAwake = false
        isActivating = false
        queue.unequip = false
        queue.equip = nil
        queueFrame:SetScript("OnUpdate", nil)
    elseif event == "PLAYER_REGEN_ENABLED" then
        -- Dropped combat: sync macro and evaluate water state
        addon:UpdateMacro()
        C_Timer.After(0.3, function()
            EvaluateWaterState()
        end)
    elseif event == "PLAYER_EQUIPMENT_CHANGED" then
        if arg1 == INVSLOT_FISHING_TOOL or arg1 == INVSLOT_MAIN_HAND then
            if not isActivating then
                if not IsUnderlightSlotted() then
                    isAwake = false
                end
            end
            addon:UpdateMacro()
            if addon.optionsPanel and addon.optionsPanel:IsShown() then
                addon:UpdateOptionsUI()
            end
        end
    elseif event == "UNIT_AURA" then
        -- Immediately re-awaken if the player is in water and the buff was stripped or clicked off
        if not InCombatLockdown() and not IsMounted() and not isActivating and IsPlayerInWater() and not IsUnderlightAwake() then
            C_Timer.After(0.2, function()
                EvaluateWaterState()
            end)
        end
    elseif event == "MOUNT_JOURNAL_USABILITY_CHANGED" or event == "MIRROR_TIMER_START" then
        -- Debounce rapid swimming state transitions
        C_Timer.After(0.2, function()
            EvaluateWaterState()
        end)
    elseif event == "PLAYER_ENTERING_WORLD" then
        isAwake = false
        addon:UpdateMacro()
        C_Timer.After(1.0, function()
            EvaluateWaterState()
        end)
    end
end)

-- ==============================================================================
-- 4. BLIZZARD MODERN SETTINGS INTEGRATION (Canvas Layout)
-- ==============================================================================

function addon:UpdateOptionsUI()
    local db = AnglerBigginsDB or defaults
    local isEnabled = db.enabled == true

    if uiWidgets.cbMaster then
        uiWidgets.cbMaster:SetChecked(isEnabled)
    end

    for _, widget in ipairs(uiWidgets.subControls) do
        if widget.SetEnabled then
            widget:SetEnabled(isEnabled)
        end
        if widget.EnableMouse then
            widget:EnableMouse(isEnabled)
        end
        if widget.SetAlpha then
            widget:SetAlpha(isEnabled and 1.0 or 0.4)
        end
    end

    if uiWidgets.cbLifejacket then uiWidgets.cbLifejacket:SetChecked(db.enableLifejacket) end
    if uiWidgets.cbInstances  then uiWidgets.cbInstances:SetChecked(db.enableInstances) end
    if uiWidgets.cbDelves     then uiWidgets.cbDelves:SetChecked(db.enableDelves) end
    if uiWidgets.cbPvP        then uiWidgets.cbPvP:SetChecked(db.enablePvP) end
    if uiWidgets.cbQuiet      then uiWidgets.cbQuiet:SetChecked(db.quiet) end

    if uiWidgets.statusText then
        local equippedPoleID = GetInventoryItemID("player", INVSLOT_FISHING_TOOL)
        if not equippedPoleID then
            local weaponID = GetInventoryItemID("player", INVSLOT_MAIN_HAND)
            if weaponID then
                local _, _, _, _, _, itemClassID, itemSubClassID = C_Item.GetItemInfoInstant(weaponID)
                if itemClassID == 2 and itemSubClassID == 20 then
                    equippedPoleID = weaponID
                end
            end
        end

        local equippedStr
        if equippedPoleID then
            local itemName, itemLink = C_Item.GetItemInfo(equippedPoleID)
            equippedStr = "|cFF00FF00" .. (itemLink or itemName or ("Item ID: " .. equippedPoleID)) .. "|r"
        else
            equippedStr = "|cFFFF5555None|r"
        end

        local inWaterStr = IsPlayerInWater() and "|cFF00FF00Submerged / In Water|r" or "|cFF888888On Dry Land|r"
        local buffStr = HasFishFormBuff() and "|cFF00FF00Active (Underlight Blessing)|r" or "|cFF888888Inactive|r"
        local pinnedStr = db.pinnedPoleName and ("|cFF00FF00" .. db.pinnedPoleName .. "|r") or "|cFFFF5555None|r"

        uiWidgets.statusText:SetText(
            "|cFFFFD100Equipped Fishing Pole:|r " .. equippedStr .. "\n" ..
            "|cFFFFD100Pinned Main Pole:|r " .. pinnedStr .. "\n" ..
            "|cFFFFD100Current Environment:|r " .. inWaterStr .. "\n" ..
            "|cFFFFD100Fish Form Buff:|r " .. buffStr
        )
    end

    if uiWidgets.pinLabel then
        local poleName = db.pinnedPoleName or "None"
        local colorStr = (db.pinnedPoleID and "|cFF00FF00" or "|cFFFF5555")
        uiWidgets.pinLabel:SetText("Currently Pinned Pole: " .. colorStr .. poleName .. "|r")
    end

    if uiWidgets.btnClearPin then
        uiWidgets.btnClearPin:SetEnabled(db.pinnedPoleID ~= nil)
    end
end

function addon:CreateSettingsUI()
    if self.optionsPanel then return end

    local panel = CreateFrame("Frame", "AnglerBigginsOptionsPanel", UIParent)
    panel.name = "Angler"
    self.optionsPanel = panel

    -- Title
    local title = panel:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
    title:SetPoint("TOPLEFT", 16, -16)
    title:SetText("|cFFFFD100Angler Biggins|r")

    -- Subtitle
    local subtitle = panel:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
    subtitle:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -4)
    subtitle:SetText("Dual-rod fishing suite with one-click action bar swapping, Underlight Angler water walking, and lifejacket water rescue.")

    -- Suite Logo Texture (Top Right)
    local logo = panel:CreateTexture(nil, "ARTWORK")
    logo:SetPoint("TOPRIGHT", -24, -16)
    logo:SetSize(64, 64)
    logo:SetTexture("Interface\\AddOns\\AnglerBiggins\\logo.jpg")

    -- Master Enable Checkbox
    local cbMaster = CreateFrame("CheckButton", nil, panel, "InterfaceOptionsCheckButtonTemplate")
    cbMaster:SetPoint("TOPLEFT", subtitle, "BOTTOMLEFT", 0, -18)
    cbMaster.Text:SetText("Enable Angler Biggins")
    cbMaster.Text:SetFontObject("GameFontNormal")
    cbMaster.tooltipText = "Master toggle for automatic Underlight Angler water walking, fish form, and breathing."
    cbMaster:SetScript("OnClick", function(btn)
        AnglerBigginsDB.enabled = btn:GetChecked()
        addon:UpdateOptionsUI()
        if AnglerBigginsDB.enabled then
            EvaluateWaterState()
        end
    end)
    cbMaster:SetScript("OnEnter", function(self)
        if self.tooltipText then
            GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
            GameTooltip:SetText(self.tooltipText, 1, 1, 1, true)
            GameTooltip:Show()
        end
    end)
    cbMaster:SetScript("OnLeave", function() GameTooltip:Hide() end)
    uiWidgets.cbMaster = cbMaster

    -- Defaults Button (Top Right next to logo)
    local btnDefaults = CreateFrame("Button", nil, panel, "UIPanelButtonTemplate")
    btnDefaults:SetPoint("TOPRIGHT", logo, "BOTTOMRIGHT", 0, -8)
    btnDefaults:SetSize(110, 22)
    btnDefaults:SetText("Defaults")
    btnDefaults:SetScript("OnClick", function()
        AnglerBigginsDB = CopyTable(defaults)
        addon:UpdateOptionsUI()
        addon:UpdateMacro()
        PrintMsg("Configuration reset to defaults.")
    end)

    -- Child Checkboxes (Indented 20px under master)
    local cbLifejacket = CreateFrame("CheckButton", nil, panel, "InterfaceOptionsCheckButtonTemplate")
    cbLifejacket:SetPoint("TOPLEFT", cbMaster, "BOTTOMLEFT", 20, -6)
    cbLifejacket.Text:SetText("Auto-Equip Underlight in Water (Lifejacket Mode)")
    cbLifejacket.Text:SetFontObject("GameFontHighlight")
    cbLifejacket.tooltipText = "Automatically equips the Underlight Angler from your bags when entering water with your pinned pole equipped, granting instant fish form, swim speed, and water walking."
    cbLifejacket:SetScript("OnClick", function(btn)
        AnglerBigginsDB.enableLifejacket = btn:GetChecked()
        if AnglerBigginsDB.enableLifejacket then
            EvaluateWaterState()
        end
    end)
    cbLifejacket:SetScript("OnEnter", function(self)
        if self.tooltipText then
            GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
            GameTooltip:SetText(self.tooltipText, 1, 1, 1, true)
            GameTooltip:Show()
        end
    end)
    cbLifejacket:SetScript("OnLeave", function() GameTooltip:Hide() end)
    table.insert(uiWidgets.subControls, cbLifejacket)
    uiWidgets.cbLifejacket = cbLifejacket

    -- Checkbox: Instances
    local cbInstances = CreateFrame("CheckButton", nil, panel, "InterfaceOptionsCheckButtonTemplate")
    cbInstances:SetPoint("TOPLEFT", cbLifejacket, "BOTTOMLEFT", 0, -6)
    cbInstances.Text:SetText("Enable in Dungeons & Raids (Mythic+ Excluded)")
    cbInstances.Text:SetFontObject("GameFontHighlight")
    cbInstances.tooltipText = "Activates Underlight Angler water buffs during standard dungeon and raid instances.\n\n|cFFFF5555Note:|r Active Mythic+ keystones enforce Blizzard equipment lockdown, so automation is permanently suppressed during timed Challenge Mode runs to prevent gear errors."
    cbInstances:SetScript("OnClick", function(btn)
        AnglerBigginsDB.enableInstances = btn:GetChecked()
    end)
    cbInstances:SetScript("OnEnter", function(self)
        if self.tooltipText then
            GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
            GameTooltip:SetText(self.tooltipText, 1, 1, 1, true)
            GameTooltip:Show()
        end
    end)
    cbInstances:SetScript("OnLeave", function() GameTooltip:Hide() end)
    table.insert(uiWidgets.subControls, cbInstances)
    uiWidgets.cbInstances = cbInstances

    -- Checkbox: Delves
    local cbDelves = CreateFrame("CheckButton", nil, panel, "InterfaceOptionsCheckButtonTemplate")
    cbDelves:SetPoint("TOPLEFT", cbInstances, "BOTTOMLEFT", 0, -6)
    cbDelves.Text:SetText("Enable in Underwater Delves (Breath Meter Detection)")
    cbDelves.Text:SetFontObject("GameFontHighlight")
    cbDelves.tooltipText = "Maintains fish form and permanent underwater breathing throughout submerged Delves (e.g. The Sinkhole), even while walking on the sea floor."
    cbDelves:SetScript("OnClick", function(btn)
        AnglerBigginsDB.enableDelves = btn:GetChecked()
    end)
    cbDelves:SetScript("OnEnter", function(self)
        if self.tooltipText then
            GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
            GameTooltip:SetText(self.tooltipText, 1, 1, 1, true)
            GameTooltip:Show()
        end
    end)
    cbDelves:SetScript("OnLeave", function() GameTooltip:Hide() end)
    table.insert(uiWidgets.subControls, cbDelves)
    uiWidgets.cbDelves = cbDelves

    -- Checkbox: PvP
    local cbPvP = CreateFrame("CheckButton", nil, panel, "InterfaceOptionsCheckButtonTemplate")
    cbPvP:SetPoint("TOPLEFT", cbDelves, "BOTTOMLEFT", 0, -6)
    cbPvP.Text:SetText("Enable in Battlegrounds & Arenas")
    cbPvP.Text:SetFontObject("GameFontHighlight")
    cbPvP.tooltipText = "Allows activation during rated or unrated PvP combat areas."
    cbPvP:SetScript("OnClick", function(btn)
        AnglerBigginsDB.enablePvP = btn:GetChecked()
    end)
    cbPvP:SetScript("OnEnter", function(self)
        if self.tooltipText then
            GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
            GameTooltip:SetText(self.tooltipText, 1, 1, 1, true)
            GameTooltip:Show()
        end
    end)
    cbPvP:SetScript("OnLeave", function() GameTooltip:Hide() end)
    table.insert(uiWidgets.subControls, cbPvP)
    uiWidgets.cbPvP = cbPvP

    -- Checkbox: Quiet Mode
    local cbQuiet = CreateFrame("CheckButton", nil, panel, "InterfaceOptionsCheckButtonTemplate")
    cbQuiet:SetPoint("TOPLEFT", cbPvP, "BOTTOMLEFT", 0, -6)
    cbQuiet.Text:SetText("Quiet Mode (Suppress Chat Messages)")
    cbQuiet.Text:SetFontObject("GameFontHighlight")
    cbQuiet.tooltipText = "Prevents activation and status echoes from printing to the chat window."
    cbQuiet:SetScript("OnClick", function(btn)
        AnglerBigginsDB.quiet = btn:GetChecked()
    end)
    cbQuiet:SetScript("OnEnter", function(self)
        if self.tooltipText then
            GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
            GameTooltip:SetText(self.tooltipText, 1, 1, 1, true)
            GameTooltip:Show()
        end
    end)
    cbQuiet:SetScript("OnLeave", function() GameTooltip:Hide() end)
    table.insert(uiWidgets.subControls, cbQuiet)
    uiWidgets.cbQuiet = cbQuiet

    -- Dual-Pole Swapping Section Header
    local dualHeader = panel:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    dualHeader:SetPoint("TOPLEFT", cbQuiet, "BOTTOMLEFT", -20, -18)
    dualHeader:SetText("Dual-Pole Swapping (Underlight / Main Pole)")

    -- Pinned Pole Status Label
    local pinLabel = panel:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
    pinLabel:SetPoint("TOPLEFT", dualHeader, "BOTTOMLEFT", 0, -6)
    pinLabel:SetText("Currently Pinned Pole: None")
    uiWidgets.pinLabel = pinLabel

    -- Button: Pin Currently Equipped Pole
    local btnPin = CreateFrame("Button", nil, panel, "UIPanelButtonTemplate")
    btnPin:SetPoint("TOPLEFT", pinLabel, "BOTTOMLEFT", 0, -8)
    btnPin:SetSize(210, 22)
    btnPin:SetText("Pin Currently Equipped Pole")
    btnPin:SetScript("OnClick", function()
        addon:PinCurrentPole()
    end)
    uiWidgets.btnPin = btnPin

    -- Button: Clear Pinned Pole
    local btnClearPin = CreateFrame("Button", nil, panel, "UIPanelButtonTemplate")
    btnClearPin:SetPoint("LEFT", btnPin, "RIGHT", 8, 0)
    btnClearPin:SetSize(140, 22)
    btnClearPin:SetText("Clear Pinned Pole")
    btnClearPin:SetScript("OnClick", function()
        addon:ClearPinnedPole()
    end)
    uiWidgets.btnClearPin = btnClearPin

    -- Button: Put Swap Button on Cursor (Option 2)
    local btnPickup = CreateFrame("Button", nil, panel, "UIPanelButtonTemplate")
    btnPickup:SetPoint("TOPLEFT", btnPin, "BOTTOMLEFT", 0, -8)
    btnPickup:SetSize(210, 24)
    btnPickup:SetText("Put Swap Button on Cursor")
    btnPickup:SetScript("OnClick", function()
        addon:PickupActionButton()
    end)
    uiWidgets.btnPickup = btnPickup

    -- Subtext Note for Action Button
    local pickupNote = panel:CreateFontString(nil, "ARTWORK", "GameFontDisableSmall")
    pickupNote:SetPoint("TOPLEFT", btnPickup, "BOTTOMLEFT", 0, -4)
    pickupNote:SetText("Picks up a one-click rod toggle button onto your cursor. Click any action bar slot to place it.")

    -- Status Box Frame (Inset display, anchored below pickupNote)
    local statusBox = CreateFrame("Frame", nil, panel, "BackdropTemplate")
    statusBox:SetPoint("TOPLEFT", pickupNote, "BOTTOMLEFT", 0, -14)
    statusBox:SetSize(580, 95)
    statusBox:SetBackdrop({
        bgFile   = "Interface\\ChatFrame\\ChatFrameBackground",
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        tile     = true, tileSize = 16, edgeSize = 12,
        insets   = { left = 3, right = 3, top = 3, bottom = 3 }
    })
    statusBox:SetBackdropColor(0, 0, 0, 0.5)
    statusBox:SetBackdropBorderColor(0.6, 0.5, 0.2, 0.8)

    local statusTitle = statusBox:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall")
    statusTitle:SetPoint("TOPLEFT", 10, -8)
    statusTitle:SetText("Live Telemetry & Diagnostics:")

    local statusText = statusBox:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
    statusText:SetPoint("TOPLEFT", statusTitle, "BOTTOMLEFT", 0, -4)
    statusText:SetJustifyH("LEFT")
    uiWidgets.statusText = statusText

    -- Slash Command Help Note
    local helpNote = panel:CreateFontString(nil, "ARTWORK", "GameFontDisableSmall")
    helpNote:SetPoint("TOPLEFT", statusBox, "BOTTOMLEFT", 0, -14)
    helpNote:SetText("Slash commands: /anglerb (Type /anglerb ? for available commands)")

    panel:SetScript("OnShow", function()
        addon:UpdateOptionsUI()
    end)

    -- Register subcategory with LibBigginsSuite
    if LibBigginsSuite and LibBigginsSuite.RegisterSubcategory then
        self.categoryID = LibBigginsSuite:RegisterSubcategory("AnglerBiggins", panel, "Angler")
    elseif Settings and Settings.RegisterCanvasLayoutCategory then
        local category = Settings.RegisterCanvasLayoutCategory(panel, "Angler")
        Settings.RegisterAddOnCategory(category)
        self.categoryID = category:GetID()
    end

    self:UpdateOptionsUI()
end

-- ==============================================================================
-- 5. SLASH COMMAND INTERFACE
-- ==============================================================================

SLASH_ANGLERBIGGINS1 = "/anglerb"

SlashCmdList["ANGLERBIGGINS"] = function(msg)
    local cmd = (msg or ""):trim():lower()
    local db = AnglerBigginsDB or defaults

    if cmd == "pin" then
        addon:PinCurrentPole()
    elseif cmd == "button" or cmd == "macro" then
        addon:PickupActionButton()
    elseif cmd == "unpin" or cmd == "clear" then
        addon:ClearPinnedPole()
    elseif cmd == "swap" then
        addon:TogglePoles()
    elseif cmd == "lifejacket" then
        db.enableLifejacket = not db.enableLifejacket
        PrintMsg("Lifejacket Mode: " .. (db.enableLifejacket and "|cFF00FF00Enabled|r" or "|cFFFF0000Disabled|r"))
        addon:UpdateOptionsUI()
        if db.enableLifejacket then EvaluateWaterState() end
    elseif cmd == "toggle" then
        db.enabled = not db.enabled
        PrintMsg("Master toggle: " .. (db.enabled and "|cFF00FF00Enabled|r" or "|cFFFF0000Disabled|r"))
        addon:UpdateOptionsUI()
        if db.enabled then EvaluateWaterState() end
    elseif cmd == "instances" or cmd == "dungeons" or cmd == "raids" then
        db.enableInstances = not db.enableInstances
        PrintMsg("Dungeons & Raids: " .. (db.enableInstances and "|cFF00FF00Enabled|r" or "|cFFFF0000Disabled|r"))
        addon:UpdateOptionsUI()
    elseif cmd == "delves" then
        db.enableDelves = not db.enableDelves
        PrintMsg("Underwater Delves: " .. (db.enableDelves and "|cFF00FF00Enabled|r" or "|cFFFF0000Disabled|r"))
        addon:UpdateOptionsUI()
    elseif cmd == "wake" then
        isAwake = false
        lastActivationTime = 0
        ActivateUnderlightAngler()
        PrintMsg("Underlight Angler activation triggered.")
    elseif cmd == "status" then
        local equippedPoleID = GetInventoryItemID("player", INVSLOT_FISHING_TOOL)
        if not equippedPoleID then
            local weaponID = GetInventoryItemID("player", INVSLOT_MAIN_HAND)
            if weaponID then
                local _, _, _, _, _, itemClassID, itemSubClassID = C_Item.GetItemInfoInstant(weaponID)
                if itemClassID == 2 and itemSubClassID == 20 then
                    equippedPoleID = weaponID
                end
            end
        end

        local equippedStr = "None"
        if equippedPoleID then
            local itemName, itemLink = C_Item.GetItemInfo(equippedPoleID)
            equippedStr = itemLink or itemName or ("Item ID: " .. equippedPoleID)
        end

        local inWater = IsPlayerInWater() and "Submerged / Swimming" or "Dry Land"
        local awakeStr = IsUnderlightAwake() and "Awake" or "Dormant"
        local auraStr = HasFishingAura() and "Active" or "Inactive (or suppressed)"
        local fishForm = HasFishFormBuff() and "Active" or "Inactive"
        local pinnedStr = db.pinnedPoleName or "None"
        PrintMsg("Status:")
        print("  - Addon State: " .. (db.enabled and "|cFF00FF00Enabled|r" or "|cFFFF0000Disabled|r"))
        print("  - Lifejacket Mode: " .. (db.enableLifejacket and "|cFF00FF00Enabled|r" or "|cFFFF0000Disabled|r"))
        print("  - Equipped Pole: |cFFFFD100" .. equippedStr .. "|r")
        print("  - Pinned Main Pole: |cFFFFD100" .. pinnedStr .. "|r")
        print("  - Trait State: |cFFFFD100" .. awakeStr .. "|r")
        print("  - Fishing Aura (394009): |cFFFFD100" .. auraStr .. "|r")
        print("  - Environment: |cFFFFD100" .. inWater .. "|r")
        print("  - Fish Form Buff: |cFFFFD100" .. fishForm .. "|r")
        print("  - Dungeons & Raids: " .. (db.enableInstances and "|cFF00FF00On|r" or "|cFFFF0000Off|r"))
        print("  - Underwater Delves: " .. (db.enableDelves and "|cFF00FF00On|r" or "|cFFFF0000Off|r"))
    elseif cmd == "help" or cmd == "?" then
        PrintMsg("Commands:")
        print("  |cFFFFD100/anglerb|r - Open settings panel")
        print("  |cFFFFD100/anglerb pin|r - Pin currently equipped fishing pole as secondary rod")
        print("  |cFFFFD100/anglerb button|r - Put rod swap button onto cursor to place on action bar")
        print("  |cFFFFD100/anglerb swap|r - Manually swap between Underlight Angler and pinned pole")
        print("  |cFFFFD100/anglerb lifejacket|r - Toggle auto-equipping Underlight Angler when entering water")
        print("  |cFFFFD100/anglerb toggle|r - Toggle master automation on/off")
        print("  |cFFFFD100/anglerb wake|r - Re-engage Underlight Angler traits on demand")
        print("  |cFFFFD100/anglerb instances|r - Toggle activation in Dungeons & Raids")
        print("  |cFFFFD100/anglerb delves|r - Toggle underwater Delve & breath meter detection")
        print("  |cFFFFD100/anglerb status|r - Display current equipment, pinned pole, and buff state")
        print("  |cFFFFD100/anglerb help|r or |cFFFFD100/anglerb ?|r - Show this list of commands")
    else
        -- Open Settings Panel if empty or 'options'/'config', otherwise display help hint
        if cmd == "" or cmd == "options" or cmd == "config" then
            if addon.categoryID and Settings and Settings.OpenToCategory then
                Settings.OpenToCategory(addon.categoryID)
            else
                PrintMsg("Type |cFFFFD100/anglerb help|r to view available commands.")
            end
        else
            PrintMsg("Unknown command '|cFFFFD100" .. cmd .. "|r'. Type |cFFFFD100/anglerb help|r for available commands.")
        end
    end
end
