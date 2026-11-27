--[[ ==============================================================================
    Angler Biggins - Options & Settings Panel (Canvas Layout)
    ------------------------------------------------------------------------------
    Integrated Blizzard Settings panel featuring master toggle, zone filters,
    dual-rod pinning controls, and live telemetry diagnostics.
============================================================================== ]]--

local addonName, addon = ...

-- Cache global functions
local CreateFrame         = CreateFrame
local GameTooltip         = GameTooltip
local UIParent            = UIParent
local ipairs              = ipairs
local table_insert        = table.insert
local CopyTable           = CopyTable
local GetInventoryItemID  = GetInventoryItemID

local C_Item              = C_Item
local LibBigginsSuite     = LibBigginsSuite
local Settings            = Settings

-- UI Widget References for Dynamic Control Attenuation
local uiWidgets = {
    subControls = {},
}
addon.uiWidgets = uiWidgets

function addon:UpdateOptionsUI()
    local db = AnglerBigginsDB or addon.defaults
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

    if uiWidgets.cbInstances  then uiWidgets.cbInstances:SetChecked(db.enableInstances) end
    if uiWidgets.cbDelves     then uiWidgets.cbDelves:SetChecked(db.enableDelves) end
    if uiWidgets.cbPvP        then uiWidgets.cbPvP:SetChecked(db.enablePvP) end
    if uiWidgets.cbQuiet      then uiWidgets.cbQuiet:SetChecked(db.quiet) end

    if uiWidgets.statusText then
        local equippedPoleID = addon:GetEquippedFishingPoleID()

        local equippedStr
        if equippedPoleID then
            local itemName, itemLink = C_Item.GetItemInfo(equippedPoleID)
            equippedStr = "|cFF00FF00" .. (itemLink or itemName or ("Item ID: " .. equippedPoleID)) .. "|r"
        else
            equippedStr = "|cFFFF5555None|r"
        end

        local inWaterStr = addon:IsPlayerInWater() and "|cFF00FF00Submerged / In Water|r" or "|cFF888888On Dry Land|r"
        local tensionStr = addon:HasSurfaceTensionBuff() and "|cFF00FF00Active|r" or "|cFF888888Inactive|r"
        local pinnedStr = db.pinnedPoleName and ("|cFF00FF00" .. db.pinnedPoleName .. "|r") or "|cFFFF5555None|r"

        uiWidgets.statusText:SetText(
            "|cFFFFD100Equipped Fishing Pole:|r " .. equippedStr .. "\n" ..
            "|cFFFFD100Pinned Main Pole:|r " .. pinnedStr .. "\n" ..
            "|cFFFFD100Current Environment:|r " .. inWaterStr .. "\n" ..
            "|cFFFFD100Surface Tension Buff:|r " .. tensionStr
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
    subtitle:SetWidth(480)
    subtitle:SetJustifyH("LEFT")
    subtitle:SetWordWrap(true)
    subtitle:SetText("Dual-rod fishing suite with one-click action bar swapping, Underlight Angler water walking, and fish form automation.")

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
            addon:EvaluateWaterState()
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
        AnglerBigginsDB = CopyTable(addon.defaults)
        addon:UpdateOptionsUI()
        addon:UpdateMacro()
        addon:PrintMsg("Configuration reset to defaults.")
    end)

    -- Checkbox: Instances (Indented 20px under master)
    local cbInstances = CreateFrame("CheckButton", nil, panel, "InterfaceOptionsCheckButtonTemplate")
    cbInstances:SetPoint("TOPLEFT", cbMaster, "BOTTOMLEFT", 20, -6)
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
    table_insert(uiWidgets.subControls, cbInstances)
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
    table_insert(uiWidgets.subControls, cbDelves)
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
    table_insert(uiWidgets.subControls, cbPvP)
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
    table_insert(uiWidgets.subControls, cbQuiet)
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
    helpNote:SetText("Slash commands: |cFFFFD100/anglerb|r (Type |cFFFFD100/anglerb ?|r for available commands)")

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
