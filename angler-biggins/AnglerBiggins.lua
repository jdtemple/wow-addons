--[[ ==============================================================================
    Angler Biggins v1.0.1 - Underlight Angler Water Walking & Fish Form Automation
    ------------------------------------------------------------------------------
    Author: Biggins (US-Whisperwind)
    Compatibility: World of Warcraft: Midnight / The War Within (Patch 11.x - 12.x)

    ARCHITECTURAL OVERVIEW:
    1. Zero-Taint Event-Driven Lifecycle: Operates purely on native WoW events
       (MOUNT_JOURNAL_USABILITY_CHANGED, MIRROR_TIMER_START, PLAYER_REGEN_ENABLED, UNIT_AURA)
       with zero background OnUpdate script polling or frame churn.
    2. Zero Bag Juggling / Dedicated Slot 28 Integration: Interacts directly with
       the player's dedicated Fishing Profession Tool slot (slot 28) and weapon slot (slot 16),
       eliminating item shuffling across random backpack slots.
    3. Modern Passive-Slot Wakeup: Resolves Blizzard's dormant profession equipment
       bug by cleanly triggering the Underlight Angler traits upon water entry.
    4. Instance & Combat Resilience: Fully supported in Dungeons, Raids, and Delves.
       Preserves permanent traits without fragile gear-swapping loops. Safely respects
       combat lockdown.
    5. Persistent Water Walking & Stand-on-Water Fishing: Never unequips on dry land
       or water surface, preserving permanent water walking and allowing seamless
       fishing from the surface of deep water.
    6. Modern Blizzard Canvas Settings: Fully integrated into Options -> AddOns ->
       Biggins AddOns -> Angler with master enable toggle, diagnostics, and [ Defaults ].
============================================================================== ]]--

local addonName, addon = ...
_G["AnglerBiggins"] = addon
addon.version = "1.0.1"

-- Item & Spell Constants
local UNDERLIGHT_ANGLER_ID        = 133755
local INVSLOT_FISHING_TOOL         = 28
local INVSLOT_MAIN_HAND            = 16
local SPELL_FISH_FORM              = 201944 -- Underlight Blessing (Fish Form & Swim Speed)
local SPELL_FISHING_FOR_ATTENTION  = 394009 -- Cosmetic Fishing Visual Aura (Outdoor only)

-- Upvalue caching
local CreateFrame            = CreateFrame
local GetTime                = GetTime
local InCombatLockdown       = InCombatLockdown
local IsInInstance           = IsInInstance
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
    enabled         = true,  -- Master addon toggle
    enableInstances = true,  -- Activate in Dungeons & Raids
    enableDelves    = true,  -- Underwater Delves & Breath Meter detection
    enablePvP       = false, -- Battlegrounds & Arenas (Default: OFF)
    quiet           = true,  -- Suppress chat activation messages
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

-- Determine whether the Underlight Angler is currently considered active and awakened
local function IsUnderlightAwake()
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

-- Check if the Underlight Angler is equipped in the Fishing Profession Tool slot (Slot 28)
local function IsUnderlightSlotted()
    return GetInventoryItemID("player", INVSLOT_FISHING_TOOL) == UNDERLIGHT_ANGLER_ID
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

    if not queue.equip or not C_Item.IsEquippableItem(queue.equip) or C_Item.GetItemCount(queue.equip) < 1 then
        queue.equip = nil
        return
    end

    C_Item.EquipItemByName(queue.equip)
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

        -- Timeout or combat protection
        if queueTimeout <= 0 or InCombatLockdown() or UnitIsDeadOrGhost("player") then
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
        end
    end)
end

local function ActivateUnderlightAngler()
    local db = AnglerBigginsDB or defaults
    if not db.enabled then return end
    if InCombatLockdown() or UnitIsDeadOrGhost("player") then return end
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
        -- Rod is in bag (or recovered from failed state). Equip directly to slot 28:
        queue.unequip = false
        queue.equip = UNDERLIGHT_ANGLER_ID
    end

    HandleQueue()
end

-- Main evaluation entry point
local function EvaluateWaterState()
    if InCombatLockdown() or UnitIsDeadOrGhost("player") then return end

    if not IsPlayerInWater() then
        return
    end

    if IsUnderlightAwake() then
        return
    end

    ActivateUnderlightAngler()
end

-- ==============================================================================
-- 3. EVENT DISPATCHER
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
    elseif event == "PLAYER_REGEN_DISABLED" then
        -- Combat drops Underlight Angler traits: reset awake state and abort any active queue
        isAwake = false
        isActivating = false
        queue.unequip = false
        queue.equip = nil
        queueFrame:SetScript("OnUpdate", nil)
    elseif event == "PLAYER_REGEN_ENABLED" then
        -- Dropped combat: evaluate water state after short delay
        C_Timer.After(0.3, function()
            EvaluateWaterState()
        end)
    elseif event == "PLAYER_EQUIPMENT_CHANGED" then
        -- Reset awake state if player manually unequips the rod
        if arg1 == INVSLOT_FISHING_TOOL and not isActivating then
            if not IsUnderlightSlotted() then
                isAwake = false
            end
        end
    elseif event == "UNIT_AURA" then
        -- Immediately re-awaken if the player is in water and the buff was stripped or clicked off
        if not InCombatLockdown() and not isActivating and IsPlayerInWater() and not IsUnderlightAwake() then
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

    if uiWidgets.cbInstances then uiWidgets.cbInstances:SetChecked(db.enableInstances) end
    if uiWidgets.cbDelves    then uiWidgets.cbDelves:SetChecked(db.enableDelves) end
    if uiWidgets.cbPvP       then uiWidgets.cbPvP:SetChecked(db.enablePvP) end
    if uiWidgets.cbQuiet     then uiWidgets.cbQuiet:SetChecked(db.quiet) end

    if uiWidgets.statusText then
        local isSlotted = IsUnderlightSlotted()
        local locStr = isSlotted and "|cFF00FF00Equipped in Fishing Tool Slot (Slot 28)|r" or "|cFFFF0000Not in Fishing Tool Slot|r"
        local inWaterStr = IsPlayerInWater() and "|cFF00FF00Submerged / In Water|r" or "|cFF888888On Dry Land|r"
        local buffStr = HasFishFormBuff() and "|cFF00FF00Active (Underlight Blessing)|r" or "|cFF888888Inactive|r"

        uiWidgets.statusText:SetText(
            "|cFFFFD100Underlight Angler:|r " .. locStr .. "\n" ..
            "|cFFFFD100Current Environment:|r " .. inWaterStr .. "\n" ..
            "|cFFFFD100Fish Form Buff:|r " .. buffStr
        )
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
    subtitle:SetText("Automates Underlight Angler water walking, fish form, and underwater breathing with zero bag clutter.")

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
        PrintMsg("Configuration reset to defaults.")
    end)

    -- Child Checkboxes (Indented 20px under master)
    local cbInstances = CreateFrame("CheckButton", nil, panel, "InterfaceOptionsCheckButtonTemplate")
    cbInstances:SetPoint("TOPLEFT", cbMaster, "BOTTOMLEFT", 20, -6)
    cbInstances.Text:SetText("Enable in Dungeons & Raids")
    cbInstances.Text:SetFontObject("GameFontHighlight")
    cbInstances.tooltipText = "Activates Underlight Angler water buffs during dungeon and raid instances without looping."
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

    -- Status Box Frame (Inset display, un-indented back to master left)
    local statusBox = CreateFrame("Frame", nil, panel, "BackdropTemplate")
    statusBox:SetPoint("TOPLEFT", cbQuiet, "BOTTOMLEFT", -20, -18)
    statusBox:SetSize(580, 80)
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

SLASH_ANGLERBIGGINS1 = "/angb"
SLASH_ANGLERBIGGINS2 = "/anglerbiggins"
SLASH_ANGLERBIGGINS3 = "/angler"
SLASH_ANGLERBIGGINS4 = "/ab"

SlashCmdList["ANGLERBIGGINS"] = function(msg)
    local cmd = (msg or ""):trim():lower()
    local db = AnglerBigginsDB or defaults

    if cmd == "toggle" then
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
    elseif cmd == "wake" or cmd == "reset" then
        isAwake = false
        lastActivationTime = 0
        ActivateUnderlightAngler()
        PrintMsg("Forced Underlight Angler wake cycle initiated.")
    elseif cmd == "status" then
        local isSlotted = IsUnderlightSlotted()
        local locStr = isSlotted and "Equipped in Fishing Tool Slot (28)" or "Not in Fishing Tool Slot"
        local inWater = IsPlayerInWater() and "Submerged / Swimming" or "Dry Land"
        local awakeStr = IsUnderlightAwake() and "Awake" or "Dormant"
        local auraStr = HasFishingAura() and "Active" or "Inactive (or suppressed)"
        local fishForm = HasFishFormBuff() and "Active" or "Inactive"
        PrintMsg("Status:")
        print("  - Addon State: " .. (db.enabled and "|cFF00FF00Enabled|r" or "|cFFFF0000Disabled|r"))
        print("  - Underlight Angler: |cFFFFD100" .. locStr .. "|r")
        print("  - Trait State: |cFFFFD100" .. awakeStr .. "|r")
        print("  - Fishing Aura (394009): |cFFFFD100" .. auraStr .. "|r")
        print("  - Environment: |cFFFFD100" .. inWater .. "|r")
        print("  - Fish Form Buff: |cFFFFD100" .. fishForm .. "|r")
        print("  - Dungeons & Raids: " .. (db.enableInstances and "|cFF00FF00On|r" or "|cFFFF0000Off|r"))
        print("  - Underwater Delves: " .. (db.enableDelves and "|cFF00FF00On|r" or "|cFFFF0000Off|r"))
    else
        -- Open Settings Panel
        if addon.categoryID and Settings and Settings.OpenToCategory then
            Settings.OpenToCategory(addon.categoryID)
        else
            PrintMsg("Type |cFFFFD100/angb status|r or |cFFFFD100/angb toggle|r.")
        end
    end
end
