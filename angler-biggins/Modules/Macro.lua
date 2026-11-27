--[[ ==============================================================================
    Angler Biggins - Dual-Pole Swapping & Action Bar Macro Engine
    ------------------------------------------------------------------------------
    Generates and maintains the action bar rod toggle macro and provides
    the hover tooltip "Equipped" status indicator.
============================================================================== ]]--

local addonName, addon = ...

-- Cache global functions
local InCombatLockdown             = InCombatLockdown
local GetMacroIndexByName          = GetMacroIndexByName
local EditMacro                    = EditMacro
local GetNumMacros                 = GetNumMacros
local CreateMacro                  = CreateMacro
local ClearCursor                  = ClearCursor
local PickupMacro                  = PickupMacro
local GameTooltip                  = GameTooltip
local TooltipDataProcessor         = TooltipDataProcessor
local Enum                         = Enum
local type                         = type
local tonumber                     = tonumber
local pcall                        = pcall
local GetActionInfo                = GetActionInfo
local GetActionText                = GetActionText
local GetMacroInfo                 = GetMacroInfo
local GetMouseFoci                 = GetMouseFoci
local GetMouseFocus                = GetMouseFocus
local GetInventoryItemID           = GetInventoryItemID

local C_Item                       = C_Item

addon.MACRO_NAME = "AnglerBiggins"
local MACRO_NAME = addon.MACRO_NAME

-- Generate the appropriate macro icon and tooltip text based on current gear state (Current Gear Indicator)
function addon:GetMacroContent()
    local db = AnglerBigginsDB or addon.defaults

    -- Determine currently equipped fishing pole
    local equippedItem = addon:GetEquippedFishingPoleID()

    if equippedItem == addon.UNDERLIGHT_ANGLER_ID then
        -- Currently holding Underlight Angler: display Underlight Angler icon & tooltip
        local icon = (C_Item and C_Item.GetItemIconByID and C_Item.GetItemIconByID(addon.UNDERLIGHT_ANGLER_ID)) or 133755
        local body = "#showtooltip item:" .. addon.UNDERLIGHT_ANGLER_ID .. "\n/anglerb swap"
        return icon, body
    elseif equippedItem and (equippedItem == db.pinnedPoleID or db.pinnedPoleID == nil) then
        -- Currently holding Pinned Pole: display Pinned Pole icon & tooltip
        local icon = db.pinnedPoleIcon or (C_Item and C_Item.GetItemIconByID and C_Item.GetItemIconByID(equippedItem)) or 136240
        local body = "#showtooltip item:" .. equippedItem .. "\n/anglerb swap"
        return icon, body
    elseif equippedItem then
        -- Another rod is equipped: display its icon & tooltip
        local icon = (C_Item and C_Item.GetItemIconByID and C_Item.GetItemIconByID(equippedItem)) or 136240
        local body = "#showtooltip item:" .. equippedItem .. "\n/anglerb swap"
        return icon, body
    else
        -- Inventory is still synchronizing or slot 28 is empty:
        -- Default gracefully to pinned pole if known, otherwise default fishing icon
        if db.pinnedPoleID then
            local icon = db.pinnedPoleIcon or (C_Item and C_Item.GetItemIconByID and C_Item.GetItemIconByID(db.pinnedPoleID)) or 136240
            local body = "#showtooltip item:" .. db.pinnedPoleID .. "\n/anglerb swap"
            return icon, body
        else
            local icon = 136240
            local body = "#showtooltip\n/anglerb swap"
            return icon, body
        end
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
        addon:PrintMsg("|cFFFF5555Cannot create or modify macros during combat lockdown.|r")
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
        addon:PrintMsg("|cFFFF5555Macro storage is full!|r Free up a macro slot (General or Character-Specific) to use the action button.")
        return nil
    end

    macroIdx = CreateMacro(MACRO_NAME, icon, body, isPerChar)
    return macroIdx
end

-- Pick up the AnglerBiggins macro and place it directly onto the cursor
function addon:PickupActionButton()
    if InCombatLockdown() then
        addon:PrintMsg("|cFFFF5555Cannot pick up macros during combat lockdown.|r")
        return
    end

    local macroIdx = addon:EnsureMacro()
    if macroIdx and macroIdx > 0 then
        ClearCursor()
        PickupMacro(macroIdx)
        addon:PrintMsg("Rod swap button placed on cursor. Click any action bar slot to place it.")
    end
end

-- Pin the currently equipped fishing pole
function addon:PinCurrentPole()
    local db = AnglerBigginsDB or addon.defaults

    local poleID = addon:GetEquippedFishingPoleID()

    if not poleID then
        addon:PrintMsg("|cFFFF5555No fishing pole currently equipped!|r Equip the pole you want to pin first, then type |cFFFFD100/anglerb pin|r.")
        return false
    end

    if poleID == addon.UNDERLIGHT_ANGLER_ID then
        addon:PrintMsg("|cFFFF5555Cannot pin Underlight Angler as your secondary pole!|r Equip your other fishing pole first, then type |cFFFFD100/anglerb pin|r.")
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

    addon:PrintMsg("Pinned fishing pole: |cFF00FF00" .. (itemLink or itemName) .. "|r.")
    addon:UpdateMacro()
    addon:UpdateOptionsUI()
    return true
end

-- Clear the currently pinned pole
function addon:ClearPinnedPole()
    local db = AnglerBigginsDB or addon.defaults
    db.pinnedPoleID = nil
    db.pinnedPoleName = "None"
    db.pinnedPoleIcon = nil

    addon:PrintMsg("Cleared pinned fishing pole.")
    addon:UpdateMacro()
    addon:UpdateOptionsUI()
end

-- Toggle between Underlight Angler and Pinned Pole
function addon:TogglePoles()
    if InCombatLockdown() then
        addon:PrintMsg("|cFFFF5555Cannot swap fishing poles during combat lockdown.|r")
        return
    end
    if addon:IsPlayerBusy() then
        addon:PrintMsg("|cFFFF5555Cannot swap fishing poles while busy or casting.|r")
        return
    end
    if addon.isActivating then
        return
    end

    local db = AnglerBigginsDB or addon.defaults
    local isUnderlight = addon:IsUnderlightSlotted()

    if isUnderlight then
        -- Currently holding Underlight Angler: swap to Pinned Pole
        local pinnedID = db.pinnedPoleID
        if not pinnedID then
            addon:PrintMsg("|cFFFF5555No secondary fishing pole pinned!|r Equip your main pole and type |cFFFFD100/anglerb pin|r.")
            return
        end

        local count = C_Item and C_Item.GetItemCount and C_Item.GetItemCount(pinnedID)
        if not count or count < 1 then
            local poleName = db.pinnedPoleName or "Pinned Pole"
            addon:PrintMsg("|cFFFF5555Pinned pole (" .. poleName .. ") not found in bags!|r")
            return
        end

        addon.isAwake = false
        addon.isActivating = true
        addon.queue.unequip = true
        addon.queue.equip = pinnedID
        addon:HandleQueue()
    else
        -- Currently holding Pinned Pole (or another rod): swap to Underlight Angler
        if not addon:HasUnderlightAngler() then
            addon:PrintMsg("|cFFFF5555Underlight Angler not found in bags or equipment!|r")
            return
        end

        addon.isActivating = true
        addon.queue.unequip = true
        addon.queue.equip = addon.UNDERLIGHT_ANGLER_ID
        addon:HandleQueue()
    end
end

-- ==============================================================================
-- ACTION BAR TOOLTIP "EQUIPPED" INDICATOR
-- ==============================================================================

local function GetActionSlotFromButton(btn)
    if not btn then return nil end
    if btn.action then
        local act = tonumber(btn.action)
        if act then return act end
    end
    if _G.ActionButton_GetPagedID then
        local ok, act = pcall(_G.ActionButton_GetPagedID, btn)
        if ok and act and tonumber(act) then return tonumber(act) end
    end
    if _G.ActionButton_CalculateAction then
        local ok, act = pcall(_G.ActionButton_CalculateAction, btn, "LeftButton")
        if ok and act and tonumber(act) then return tonumber(act) end
    end
    if btn.GetAttribute then
        local act = tonumber(btn:GetAttribute("action"))
        if act then return act end
    end
    if btn._state_action then
        local act = tonumber(btn._state_action)
        if act then return act end
    end
    if btn.GetActionID then
        local ok, act = pcall(btn.GetActionID, btn)
        if ok and act and tonumber(act) then return tonumber(act) end
    end
    if btn.GetAction then
        local ok, act = pcall(btn.GetAction, btn)
        if ok and act and tonumber(act) then return tonumber(act) end
    end
    return nil
end

local function IsAnglerBigginsButton(btn)
    if not btn then return false end

    -- Check displayed Name fontstring (Blizzard ActionButton.Name)
    if btn.Name and btn.Name.GetText then
        local text = btn.Name:GetText()
        if text and (text == MACRO_NAME or text == "AnglerBiggins" or text:find("^Angl")) then
            return true
        end
    end

    -- Check button action slot
    local slot = GetActionSlotFromButton(btn)
    if slot then
        local actionText = GetActionText(slot)
        if actionText and (actionText == MACRO_NAME or actionText:find("^AnglerBiggins")) then
            return true
        end
        local actionType, id = GetActionInfo(slot)
        if actionType == "macro" then
            if id and id == GetMacroIndexByName(MACRO_NAME) then
                return true
            end
            local mName, _, mBody = GetMacroInfo(id)
            if mName == MACRO_NAME or (mBody and mBody:find("/anglerb swap", 1, true)) then
                return true
            end
        end
    end

    -- Check button attributes directly
    if btn.GetAttribute then
        local mAttr = btn:GetAttribute("macro") or btn:GetAttribute("macrotext")
        if mAttr and (mAttr == MACRO_NAME or (type(mAttr) == "string" and mAttr:find("/anglerb", 1, true))) then
            return true
        end
    end

    return false
end

local function IsAnglerBigginsTooltip(tooltip, data)
    if tooltip ~= GameTooltip then return false end

    -- 1. Check tooltip owner
    local owner = tooltip:GetOwner()
    if IsAnglerBigginsButton(owner) then
        return true
    end

    -- 2. Check mouse focus frame (fallback if tooltip owner is UIParent or anchor frame)
    if GetMouseFoci then
        local foci = GetMouseFoci()
        if foci and foci[1] and IsAnglerBigginsButton(foci[1]) then
            return true
        end
    elseif GetMouseFocus then
        local focus = GetMouseFocus()
        if IsAnglerBigginsButton(focus) then
            return true
        end
    end

    -- 3. Check macro data id if data was resolved as a macro
    if data and data.type == Enum.TooltipDataType.Macro and data.id then
        local macroName, _, macroBody = GetMacroInfo(data.id)
        if macroName == MACRO_NAME or (macroBody and macroBody:find("/anglerb swap", 1, true)) then
            return true
        end
    end

    return false
end

local function OnTooltipUpdate(tooltip, data)
    if not IsAnglerBigginsTooltip(tooltip, data) then
        return
    end

    if tooltip.anglerBigginsTagged then
        return
    end
    tooltip.anglerBigginsTagged = true

    local db = AnglerBigginsDB or addon.defaults
    local isSlotted = addon:IsUnderlightSlotted()
    local nextRodName

    if isSlotted then
        nextRodName = db.pinnedPoleName or "|cFF00FF00Pinned Pole|r"
    else
        local _, link = C_Item.GetItemInfo(addon.UNDERLIGHT_ANGLER_ID)
        nextRodName = link or "|cFFE6CC80[Underlight Angler]|r"
    end

    tooltip:AddLine(" ")
    tooltip:AddLine("|cFF00FF00Currently Equipped|r")
    tooltip:AddLine("|cFF888888Click to swap to:|r " .. nextRodName)
end

local tooltipHooked = false
function addon:SetupTooltipHook()
    if tooltipHooked then return end
    tooltipHooked = true

    if TooltipDataProcessor and TooltipDataProcessor.AddTooltipPostCall then
        local allTypes = TooltipDataProcessor.AllTypes or "ALL"
        local ok = pcall(TooltipDataProcessor.AddTooltipPostCall, allTypes, OnTooltipUpdate)
        if not ok then
            if Enum.TooltipDataType.Item then
                pcall(TooltipDataProcessor.AddTooltipPostCall, Enum.TooltipDataType.Item, OnTooltipUpdate)
            end
            if Enum.TooltipDataType.Macro then
                pcall(TooltipDataProcessor.AddTooltipPostCall, Enum.TooltipDataType.Macro, OnTooltipUpdate)
            end
        end
    end

    if GameTooltip and GameTooltip.HookScript then
        GameTooltip:HookScript("OnTooltipCleared", function(tooltip)
            tooltip.anglerBigginsTagged = nil
        end)
        GameTooltip:HookScript("OnHide", function(tooltip)
            tooltip.anglerBigginsTagged = nil
        end)
    end
end
