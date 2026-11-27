--[[ ==============================================================================
    SafeRelease Biggins - Options & Settings Panel (Canvas Layout)
    ------------------------------------------------------------------------------
    Integrated Blizzard Settings canvas providing master toggle, scope filters,
    countdown delay slider, modifier-key radios, and full wipe bypass.
============================================================================== ]]--

local addonName, addon = ...

-- Cache global functions
local CreateFrame     = CreateFrame
local GameTooltip     = GameTooltip
local UIParent        = UIParent
local Settings        = Settings
local LibBigginsSuite = LibBigginsSuite
local InterfaceOptions_AddCategory = InterfaceOptions_AddCategory
local ipairs          = ipairs
local pairs           = pairs
local math_floor      = math.floor
local string_format   = string.format

local uiWidgets = {
    subControls    = {},
    modKeyControls = {},
    delayControls  = {},
}
addon.uiWidgets = uiWidgets

function addon:UpdateOptionsUI()
    local db = SafeReleaseBigginsDB or addon.defaults
    local isEnabled = db.enabled == true

    if uiWidgets.cbMaster then
        uiWidgets.cbMaster:SetChecked(isEnabled)
    end

    -- Dynamic control attenuation for subordinate options
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

    if uiWidgets.cbRaids then uiWidgets.cbRaids:SetChecked(db.raids) end
    if uiWidgets.cbMPlus then uiWidgets.cbMPlus:SetChecked(db.mythicPlus) end
    if uiWidgets.cbDungeons then uiWidgets.cbDungeons:SetChecked(db.dungeons) end
    if uiWidgets.cbDelves then uiWidgets.cbDelves:SetChecked(db.delves) end
    if uiWidgets.cbFullWipe then uiWidgets.cbFullWipe:SetChecked(db.bypassFullWipe) end
    if uiWidgets.cbAnnounce then uiWidgets.cbAnnounce:SetChecked(db.announce) end

    -- Radio buttons for guard mode
    if uiWidgets.radioCountdown then uiWidgets.radioCountdown:SetChecked(db.mode == "COUNTDOWN") end
    if uiWidgets.radioModifier then uiWidgets.radioModifier:SetChecked(db.mode == "MODIFIER") end
    if uiWidgets.radioHybrid then uiWidgets.radioHybrid:SetChecked(db.mode == "HYBRID") end

    -- Radio buttons for modifier key
    local activeMod = db.modifierKey or "ALT"
    if uiWidgets.radioModAlt then uiWidgets.radioModAlt:SetChecked(activeMod == "ALT") end
    if uiWidgets.radioModShift then uiWidgets.radioModShift:SetChecked(activeMod == "SHIFT") end
    if uiWidgets.radioModCtrl then uiWidgets.radioModCtrl:SetChecked(activeMod == "CTRL") end

    -- Slider value label
    if uiWidgets.sliderDelay and uiWidgets.sliderDelayText then
        uiWidgets.sliderDelay:SetValue(db.delaySeconds or 5)
        uiWidgets.sliderDelayText:SetText(string_format("%d seconds", db.delaySeconds or 5))
    end

    -- Contextual dimming based on active guard mode
    local modControlsActive = isEnabled and (db.mode == "MODIFIER" or db.mode == "HYBRID")
    for _, widget in ipairs(uiWidgets.modKeyControls or {}) do
        if widget.SetEnabled then widget:SetEnabled(modControlsActive) end
        if widget.EnableMouse then widget:EnableMouse(modControlsActive) end
        if widget.SetAlpha then widget:SetAlpha(modControlsActive and 1.0 or 0.4) end
    end

    local delayControlsActive = isEnabled and (db.mode == "COUNTDOWN" or db.mode == "HYBRID")
    for _, widget in ipairs(uiWidgets.delayControls or {}) do
        if widget.SetEnabled then widget:SetEnabled(delayControlsActive) end
        if widget.EnableMouse then widget:EnableMouse(delayControlsActive) end
        if widget.SetAlpha then widget:SetAlpha(delayControlsActive and 1.0 or 0.4) end
    end
end

local function ResetAllToDefaults()
    if not SafeReleaseBigginsDB then SafeReleaseBigginsDB = {} end
    for k, v in pairs(addon.defaults) do
        SafeReleaseBigginsDB[k] = v
    end
    addon:UpdateOptionsUI()
    addon:PrintMsg("All options have been reset to default.")
end

function addon:RegisterOptions()
    local panel = CreateFrame("Frame", "SafeReleaseBigginsOptionsPanel", UIParent)
    panel.name = "SafeRelease Biggins"
    uiWidgets.panel = panel

    -- Title (Blizzard Gold)
    local title = panel:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
    title:SetPoint("TOPLEFT", 16, -16)
    title:SetText("|cFFFFD100SafeRelease Biggins|r")

    -- Subtitle
    local desc = panel:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
    desc:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -6)
    desc:SetText("Guards the Release Spirit button during wipes across raids, Mythic+ dungeons, and delves.\nNever blocks release in open world questing or unselected content.")

    -- Suite Logo Texture (Top Right)
    local logo = panel:CreateTexture(nil, "ARTWORK")
    logo:SetPoint("TOPRIGHT", -24, -16)
    logo:SetSize(64, 64)
    logo:SetTexture("Interface\\AddOns\\SafeReleaseBiggins\\logo.jpg")

    -- Top-Right Defaults Button
    local btnDefaults = CreateFrame("Button", nil, panel, "UIPanelButtonTemplate")
    btnDefaults:SetPoint("TOPRIGHT", logo, "BOTTOMRIGHT", 0, -8)
    btnDefaults:SetSize(110, 22)
    btnDefaults:SetText("Defaults")
    btnDefaults:SetScript("OnClick", function()
        ResetAllToDefaults()
    end)
    btnDefaults:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:SetText("Restore default settings for SafeRelease Biggins.", 1, 1, 1, true)
        GameTooltip:Show()
    end)
    btnDefaults:SetScript("OnLeave", function() GameTooltip:Hide() end)

    -- Master Enable Checkbox
    local cbMaster = CreateFrame("CheckButton", nil, panel, "InterfaceOptionsCheckButtonTemplate")
    cbMaster:SetPoint("TOPLEFT", desc, "BOTTOMLEFT", -2, -14)
    cbMaster.Text:SetText("Enable SafeRelease Biggins")
    cbMaster.Text:SetFontObject("GameFontHighlight")
    cbMaster.tooltipText = "Master switch to enable or disable the release guard engine entirely."
    cbMaster:SetScript("OnClick", function(self)
        local val = self:GetChecked()
        SafeReleaseBigginsDB.enabled = val
        addon:UpdateOptionsUI()
        if SafeReleaseBigginsDB.announce then
            local status = val and "|cFF00FF00Enabled|r" or "|cFFFF0000Disabled|r"
            addon:PrintMsg("SafeRelease is now " .. status .. ".")
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

    -- Section 1: Protected Content Scopes
    local scopeHeader = panel:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    scopeHeader:SetPoint("TOPLEFT", cbMaster, "BOTTOMLEFT", 2, -12)
    scopeHeader:SetText("Protected Content (Instance Scope):")
    table.insert(uiWidgets.subControls, scopeHeader)

    local function CreateSettingCheckbox(key, label, tooltip, anchorTo, x, y)
        local cb = CreateFrame("CheckButton", nil, panel, "InterfaceOptionsCheckButtonTemplate")
        cb:SetPoint("TOPLEFT", anchorTo, "BOTTOMLEFT", x, y)
        cb.Text:SetText(label)
        cb.Text:SetFontObject("GameFontHighlightSmall")
        cb.tooltipText = tooltip
        cb:SetScript("OnClick", function(self)
            SafeReleaseBigginsDB[key] = self:GetChecked()
            addon:UpdateOptionsUI()
        end)
        cb:SetScript("OnEnter", function(self)
            if self.tooltipText then
                GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
                GameTooltip:SetText(self.tooltipText, 1, 1, 1, true)
                GameTooltip:Show()
            end
        end)
        cb:SetScript("OnLeave", function() GameTooltip:Hide() end)
        table.insert(uiWidgets.subControls, cb)
        return cb
    end

    local cbRaids = CreateSettingCheckbox("raids", "Raids (LFR, Normal, Heroic, Mythic)", "Guard release during raid encounters and trash (Recommended).", scopeHeader, 4, -4)
    local cbMPlus = CreateSettingCheckbox("mythicPlus", "Mythic+ Dungeons", "Guard release inside Mythic Keystone dungeons.", cbRaids, 0, -2)
    local cbDungeons = CreateSettingCheckbox("dungeons", "Dungeons (Normal, Heroic, Mythic 0)", "Guard release in standard leveling, heroic, and Mythic 0 dungeons.", cbMPlus, 0, -2)
    local cbDelves = CreateSettingCheckbox("delves", "Delves & Scenarios", "Guard release inside Delves and story scenarios.", cbDungeons, 0, -2)

    uiWidgets.cbRaids = cbRaids
    uiWidgets.cbMPlus = cbMPlus
    uiWidgets.cbDungeons = cbDungeons
    uiWidgets.cbDelves = cbDelves

    -- Section 2: Guard Mode Selection
    local modeHeader = panel:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    modeHeader:SetPoint("TOPLEFT", cbDelves, "BOTTOMLEFT", 0, -14)
    modeHeader:SetText("Guard Mechanism:")
    table.insert(uiWidgets.subControls, modeHeader)

    local function CreateRadio(modeKey, label, tooltip, anchorTo, x, y)
        local rb = CreateFrame("CheckButton", nil, panel, "UIRadioButtonTemplate")
        rb:SetPoint("TOPLEFT", anchorTo, "BOTTOMLEFT", x, y)
        rb.text = panel:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
        rb.text:SetPoint("LEFT", rb, "RIGHT", 4, 1)
        rb.text:SetText(label)
        rb.tooltipText = tooltip
        rb:SetScript("OnClick", function()
            SafeReleaseBigginsDB.mode = modeKey
            addon:UpdateOptionsUI()
        end)
        if tooltip then
            rb:SetScript("OnEnter", function(self)
                GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
                GameTooltip:SetText(tooltip, 1, 1, 1, true)
                GameTooltip:Show()
            end)
            rb:SetScript("OnLeave", function() GameTooltip:Hide() end)
        end
        table.insert(uiWidgets.subControls, rb)
        table.insert(uiWidgets.subControls, rb.text)
        return rb
    end

    local radioCountdown = CreateRadio("COUNTDOWN", "Countdown Timer Delay (Hands-Free)", "Disables the Release button for a set number of seconds on death.", modeHeader, 4, -4)
    local radioModifier  = CreateRadio("MODIFIER", "Modifier-Key Hold (Hold key to reveal button)", "Hides and locks the Release button until Alt, Shift, or Ctrl is held down.", radioCountdown, 0, -4)
    local radioHybrid    = CreateRadio("HYBRID", "Hybrid (Countdown with instant Modifier bypass)", "Runs a countdown delay, but holding the modifier key immediately unlocks release.", radioModifier, 0, -4)

    uiWidgets.radioCountdown = radioCountdown
    uiWidgets.radioModifier  = radioModifier
    uiWidgets.radioHybrid    = radioHybrid

    -- Modifier Key Selection (Active for Modifier Hold & Hybrid modes)
    local modKeyLabel = panel:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
    modKeyLabel:SetPoint("TOPLEFT", radioHybrid, "BOTTOMLEFT", 16, -10)
    modKeyLabel:SetText("Modifier Key:")
    table.insert(uiWidgets.subControls, modKeyLabel)
    table.insert(uiWidgets.modKeyControls, modKeyLabel)

    local function CreateModKeyRadio(keyVal, label, anchorTo, x, y)
        local rb = CreateFrame("CheckButton", nil, panel, "UIRadioButtonTemplate")
        rb:SetPoint("LEFT", anchorTo, "RIGHT", x, y)
        rb.text = panel:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
        rb.text:SetPoint("LEFT", rb, "RIGHT", 4, 1)
        rb.text:SetText(label)
        rb.tooltipText = string_format("Require holding the %s key to unlock release.", label)
        rb:SetScript("OnClick", function()
            SafeReleaseBigginsDB.modifierKey = keyVal
            addon:UpdateOptionsUI()
            if SafeReleaseBigginsDB.announce then
                addon:PrintMsg("Modifier key set to |cFF00FF00" .. keyVal .. "|r.")
            end
        end)
        rb:SetScript("OnEnter", function(self)
            if self.tooltipText then
                GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
                GameTooltip:SetText(self.tooltipText, 1, 1, 1, true)
                GameTooltip:Show()
            end
        end)
        rb:SetScript("OnLeave", function() GameTooltip:Hide() end)
        table.insert(uiWidgets.subControls, rb)
        table.insert(uiWidgets.subControls, rb.text)
        table.insert(uiWidgets.modKeyControls, rb)
        table.insert(uiWidgets.modKeyControls, rb.text)
        return rb
    end

    local radioModAlt   = CreateModKeyRadio("ALT", "Alt", modKeyLabel, 12, 0)
    local radioModShift = CreateModKeyRadio("SHIFT", "Shift", radioModAlt.text, 14, 0)
    local radioModCtrl  = CreateModKeyRadio("CTRL", "Ctrl", radioModShift.text, 14, 0)

    uiWidgets.radioModAlt   = radioModAlt
    uiWidgets.radioModShift = radioModShift
    uiWidgets.radioModCtrl  = radioModCtrl

    -- Delay Seconds Slider
    local slider = CreateFrame("Slider", "SafeReleaseDelaySlider", panel, "OptionsSliderTemplate")
    slider:SetPoint("TOPLEFT", modKeyLabel, "BOTTOMLEFT", 0, -22)
    slider:SetSize(180, 16)
    slider:SetMinMaxValues(1, 10)
    slider:SetValueStep(1)
    slider:SetObeyStepOnDrag(true)
    slider.Low:SetText("1s")
    slider.High:SetText("10s")
    slider.Text:SetText("Countdown Delay Duration")

    local sliderVal = panel:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
    sliderVal:SetPoint("LEFT", slider, "RIGHT", 14, 0)
    uiWidgets.sliderDelayText = sliderVal

    slider:SetScript("OnValueChanged", function(self, val)
        local v = math_floor(val + 0.5)
        SafeReleaseBigginsDB.delaySeconds = v
        sliderVal:SetText(string_format("%d seconds", v))
    end)
    slider:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:SetText("Duration in seconds that the Release Spirit button remains locked on death.", 1, 1, 1, true)
        GameTooltip:Show()
    end)
    slider:SetScript("OnLeave", function() GameTooltip:Hide() end)
    table.insert(uiWidgets.subControls, slider)
    table.insert(uiWidgets.subControls, sliderVal)
    table.insert(uiWidgets.delayControls, slider)
    table.insert(uiWidgets.delayControls, sliderVal)
    uiWidgets.sliderDelay = slider

    -- Section 3: Smart Overrides
    local cbFullWipe = CreateSettingCheckbox("bypassFullWipe", "Instant Unlock on Full Raid Wipe", "Immediately unlocks release if the entire raid group is confirmed dead.", slider, -16, -22)
    local cbAnnounce = CreateSettingCheckbox("announce", "Echo Settings Changes to Chat", nil, cbFullWipe, 0, -2)

    uiWidgets.cbFullWipe = cbFullWipe
    uiWidgets.cbAnnounce = cbAnnounce

    -- Help Note
    local helpNote = panel:CreateFontString(nil, "ARTWORK", "GameFontDisableSmall")
    helpNote:SetPoint("TOPLEFT", cbAnnounce, "BOTTOMLEFT", 0, -16)
    helpNote:SetText("Slash commands: |cFFFFD100/safereleaseb|r (Type |cFFFFD100/safereleaseb ?|r for available commands)")

    panel:SetScript("OnShow", function()
        addon:UpdateOptionsUI()
    end)

    -- Register under Biggins AddOns suite category
    if LibBigginsSuite then
        addon.categoryID = LibBigginsSuite:RegisterSubcategory("SafeReleaseBiggins", panel, "SafeRelease")
    elseif Settings and Settings.RegisterCanvasLayoutCategory then
        local cat = Settings.RegisterCanvasLayoutCategory(panel, "SafeRelease Biggins")
        Settings.RegisterAddOnCategory(cat)
        addon.categoryID = cat:GetID()
    else
        InterfaceOptions_AddCategory(panel)
    end

    addon:UpdateOptionsUI()
end

function addon:OpenSettings()
    addon:UpdateOptionsUI()
    if addon.categoryID and Settings and Settings.OpenToCategory then
        Settings.OpenToCategory(addon.categoryID)
    else
        addon:PrintMsg("Options available in Game Menu -> Options -> AddOns -> Biggins AddOns -> SafeRelease.")
    end
end
