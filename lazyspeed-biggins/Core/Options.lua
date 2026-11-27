--[[ ==============================================================================
    LazySpeed Biggins - Blizzard Modern Settings API Integration (Canvas Layout)
    ------------------------------------------------------------------------------
    Clean two-column options panel providing live checkboxes, stacking radios,
    speed unit toggles, and dimensions/spacing/opacity sliders.
============================================================================== ]]--

local addonName, addon = ...

-- Cache global functions
local CreateFrame     = CreateFrame
local GameTooltip     = GameTooltip
local UIParent        = UIParent
local pairs           = pairs
local ipairs          = ipairs
local tostring        = tostring
local floor           = math.floor

local LibBigginsSuite = LibBigginsSuite
local Settings        = Settings

local uiWidgets = {}
addon.uiWidgets = uiWidgets
local categoryID = nil

function addon:UpdateOptionsUI()
    if not uiWidgets.panel or not LazySpeedBigginsDB then return end
    local isEnabled = LazySpeedBigginsDB.enabled ~= false

    if uiWidgets.cbEnable   then uiWidgets.cbEnable:SetChecked(isEnabled) end
    if uiWidgets.cbFlying   then uiWidgets.cbFlying:SetChecked(LazySpeedBigginsDB.showFlying) end
    if uiWidgets.cbSwimming then uiWidgets.cbSwimming:SetChecked(LazySpeedBigginsDB.showSwimming) end
    if uiWidgets.cbGround   then uiWidgets.cbGround:SetChecked(LazySpeedBigginsDB.showGround) end
    if uiWidgets.cbVigor    then uiWidgets.cbVigor:SetChecked(LazySpeedBigginsDB.showVigor ~= false) end

    local isVigorActive = isEnabled and (LazySpeedBigginsDB.showVigor ~= false)
    if uiWidgets.cbHideVigorFull then
        uiWidgets.cbHideVigorFull:SetChecked(LazySpeedBigginsDB.hideVigorWhenFull or false)
        if uiWidgets.cbHideVigorFull.SetEnabled then uiWidgets.cbHideVigorFull:SetEnabled(isVigorActive) end
        uiWidgets.cbHideVigorFull:SetAlpha(isVigorActive and 1.0 or 0.5)
    end
    if uiWidgets.cbVigorGlow then
        uiWidgets.cbVigorGlow:SetChecked(LazySpeedBigginsDB.showVigorGlow ~= false)
        if uiWidgets.cbVigorGlow.SetEnabled then uiWidgets.cbVigorGlow:SetEnabled(isVigorActive) end
        uiWidgets.cbVigorGlow:SetAlpha(isVigorActive and 1.0 or 0.5)
    end

    if uiWidgets.cbCombat   then uiWidgets.cbCombat:SetChecked(LazySpeedBigginsDB.hideInCombat) end
    if uiWidgets.cbLocked   then uiWidgets.cbLocked:SetChecked(LazySpeedBigginsDB.locked or false) end

    local isVertical = (LazySpeedBigginsDB.stackingMode or "VERTICAL") == "VERTICAL"
    if uiWidgets.rbVertical   then uiWidgets.rbVertical:SetChecked(isVertical) end
    if uiWidgets.rbHorizontal then uiWidgets.rbHorizontal:SetChecked(not isVertical) end

    local currentUnit = LazySpeedBigginsDB.unitMode or 4
    if uiWidgets.radioMPH then uiWidgets.radioMPH:SetChecked(currentUnit == 2) end
    if uiWidgets.radioYS  then uiWidgets.radioYS:SetChecked(currentUnit == 1) end
    if uiWidgets.radioKMH then uiWidgets.radioKMH:SetChecked(currentUnit == 3) end
    if uiWidgets.radioPCT then uiWidgets.radioPCT:SetChecked(currentUnit == 4) end

    if uiWidgets.sliderWidth then
        uiWidgets.sliderWidth:SetValue(LazySpeedBigginsDB.barWidth or 180)
        if uiWidgets.sliderWidth.valueText then
            uiWidgets.sliderWidth.valueText:SetText(tostring(LazySpeedBigginsDB.barWidth or 180) .. " px")
        end
    end
    if uiWidgets.sliderHeight then
        uiWidgets.sliderHeight:SetValue(LazySpeedBigginsDB.barHeight or 22)
        if uiWidgets.sliderHeight.valueText then
            uiWidgets.sliderHeight.valueText:SetText(tostring(LazySpeedBigginsDB.barHeight or 22) .. " px")
        end
    end
    if uiWidgets.sliderSpacing then
        uiWidgets.sliderSpacing:SetValue(LazySpeedBigginsDB.barSpacing or 4)
        if uiWidgets.sliderSpacing.valueText then
            uiWidgets.sliderSpacing.valueText:SetText(tostring(LazySpeedBigginsDB.barSpacing or 4) .. " px")
        end
    end
    if uiWidgets.sliderBgAlpha then
        local bgVal = LazySpeedBigginsDB.bgAlpha ~= nil and LazySpeedBigginsDB.bgAlpha or 25
        uiWidgets.sliderBgAlpha:SetValue(bgVal)
        if uiWidgets.sliderBgAlpha.valueText then
            uiWidgets.sliderBgAlpha.valueText:SetText(tostring(bgVal) .. "%")
        end
    end

    -- Gray out child controls when disabled
    local childWidgets = {
        uiWidgets.cbFlying, uiWidgets.cbSwimming, uiWidgets.cbGround, uiWidgets.cbVigor, uiWidgets.cbHideVigorFull, uiWidgets.cbVigorGlow, uiWidgets.cbCombat, uiWidgets.cbLocked,
        uiWidgets.stackHeader, uiWidgets.rbVertical, uiWidgets.rbHorizontal,
        uiWidgets.unitHeader, uiWidgets.radioMPH, uiWidgets.radioYS, uiWidgets.radioKMH, uiWidgets.radioPCT,
        uiWidgets.sliderWidth, uiWidgets.sliderHeight, uiWidgets.sliderSpacing, uiWidgets.sliderBgAlpha, uiWidgets.btnResetPos
    }
    for _, w in ipairs(childWidgets) do
        if w then
            if w.SetEnabled then w:SetEnabled(isEnabled) end
            w:SetAlpha(isEnabled and 1.0 or 0.5)
        end
    end
end

function addon:ResetAllToDefaults()
    if not LazySpeedBigginsDB then LazySpeedBigginsDB = {} end
    for varName, defVal in pairs(addon.DB_DEFAULTS) do
        LazySpeedBigginsDB[varName] = defVal
    end
    addon:RestorePosition()
    addon:UpdateLayout()
    addon:UpdateOptionsUI()
    addon.lastSpeed = -1
    addon:ResetDisplay()
    DEFAULT_CHAT_FRAME:AddMessage("|cFFFFD100LazySpeed Biggins|r: All options have been reset to default.")
end

function addon:InitializeBlizzardSettings()
    local panel = CreateFrame("Frame", "LazySpeedBigginsOptionsPanel", UIParent)
    panel.name = "LazySpeed Biggins"
    uiWidgets.panel = panel
    addon.optionsPanel = panel

    -- Title (Blizzard Gold)
    local title = panel:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
    title:SetPoint("TOPLEFT", 16, -16)
    title:SetText("|cFFFFD100LazySpeed Biggins|r")

    -- Subtitle / Description
    local desc = panel:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
    desc:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -6)
    desc:SetText("High-precision dynamic speedometer & Skyriding Vigor HUD.")

    -- Suite Logo Texture (Top Right)
    local logo = panel:CreateTexture(nil, "ARTWORK")
    logo:SetPoint("TOPRIGHT", -24, -16)
    logo:SetSize(64, 64)
    logo:SetTexture("Interface\\AddOns\\LazySpeedBiggins\\logo.jpg")

    -- Top-Right "Defaults" Button
    local btnDefaults = CreateFrame("Button", nil, panel, "UIPanelButtonTemplate")
    btnDefaults:SetPoint("TOPRIGHT", logo, "BOTTOMRIGHT", 0, -8)
    btnDefaults:SetSize(110, 22)
    btnDefaults:SetText("Defaults")
    btnDefaults:SetScript("OnClick", function()
        addon:ResetAllToDefaults()
    end)
    btnDefaults:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:SetText("Restore all LazySpeed settings back to default.", 1, 1, 1, true)
        GameTooltip:Show()
    end)
    btnDefaults:SetScript("OnLeave", function() GameTooltip:Hide() end)

    -- Helper to create and bind checkboxes
    local function CreateSettingCheckbox(key, label, tooltip, anchorPoint, relativeTo, relPoint, x, y, onClickCallback)
        local cb = CreateFrame("CheckButton", nil, panel, "InterfaceOptionsCheckButtonTemplate")
        cb:SetPoint(anchorPoint, relativeTo, relPoint, x, y)
        cb.Text:SetText(label)
        cb.Text:SetFontObject("GameFontHighlight")
        cb.tooltipText = tooltip
        local currentVal = (LazySpeedBigginsDB and LazySpeedBigginsDB[key] ~= nil) and LazySpeedBigginsDB[key] or addon.DB_DEFAULTS[key]
        cb:SetChecked(currentVal)
        cb:SetScript("OnClick", function(self)
            if not LazySpeedBigginsDB then LazySpeedBigginsDB = {} end
            LazySpeedBigginsDB[key] = self:GetChecked()
            if onClickCallback then onClickCallback(self:GetChecked()) end
            addon:UpdateLayout()
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
        return cb
    end

    -- Master Enable Checkbox
    local cbEnable = CreateSettingCheckbox("enabled", "Enable Speedometer & Vigor HUD", "Show or hide the dynamic speedometer and Vigor HUD overlay.", "TOPLEFT", desc, "BOTTOMLEFT", 0, -18, function(val)
        local status = val and "|cFF00FF00Enabled|r" or "|cFFFF0000Disabled|r"
        DEFAULT_CHAT_FRAME:AddMessage("|cFFFFD100LazySpeed Biggins|r: HUD is now " .. status .. ".")
    end)
    uiWidgets.cbEnable = cbEnable

    -- Child Checkboxes (Indented 20px)
    local cbFlying = CreateSettingCheckbox("showFlying", "Show Speedometer While Flying / Skyriding", "Displays speedometer while airborne (Skyriding or Steady Flight).", "TOPLEFT", cbEnable, "BOTTOMLEFT", 20, -6)
    uiWidgets.cbFlying = cbFlying

    local cbSwimming = CreateSettingCheckbox("showSwimming", "Show Speedometer While Swimming", "Displays speedometer while submerged in water, tracking swim and aquatic mount speeds.", "TOPLEFT", cbFlying, "BOTTOMLEFT", 0, -6)
    uiWidgets.cbSwimming = cbSwimming

    local cbGround = CreateSettingCheckbox("showGround", "Show Speedometer While on Ground", "Displays speedometer while running on foot or riding ground mounts.", "TOPLEFT", cbSwimming, "BOTTOMLEFT", 0, -6)
    uiWidgets.cbGround = cbGround

    local cbVigor = CreateSettingCheckbox("showVigor", "Show Skyriding Vigor Bar", "Displays a 1-6 recharge bar for Surge Forward / Vigor while mounted in Skyriding mode.", "TOPLEFT", cbGround, "BOTTOMLEFT", 0, -6, function()
        addon:UpdateOptionsUI()
    end)
    uiWidgets.cbVigor = cbVigor

    local cbHideVigorFull = CreateSettingCheckbox("hideVigorWhenFull", "Hide Vigor Bar When Full", "Automatically hides the Vigor bar while at maximum charges (e.g. 6/6), reappearing whenever Vigor is spent and recharging.", "TOPLEFT", cbVigor, "BOTTOMLEFT", 20, -6)
    uiWidgets.cbHideVigorFull = cbHideVigorFull

    local cbVigorGlow = CreateSettingCheckbox("showVigorGlow", "Glow on Accelerated Recharge Buffs", "Illuminates a Blue glow for Thrill of the Skies, a Red glow for Ground Skimming, and a Violet glow when both are active. When disabled, only the status bar fill changes color.", "TOPLEFT", cbHideVigorFull, "BOTTOMLEFT", 0, -6, function(val)
        if not val then
            addon:HideFlameAura()
        end
    end)
    uiWidgets.cbVigorGlow = cbVigorGlow

    local cbCombat = CreateSettingCheckbox("hideInCombat", "Hide During Combat", "Instantly hides and detaches the HUD during combat to keep your screen clear.", "TOPLEFT", cbVigorGlow, "BOTTOMLEFT", -20, -6)
    uiWidgets.cbCombat = cbCombat

    local cbLocked = CreateSettingCheckbox("locked", "Lock Frame Position", "Prevents dragging the HUD frame with the mouse.", "TOPLEFT", cbCombat, "BOTTOMLEFT", 0, -6, function(val)
        addon:UpdateMouseInteractivity()
        local status = val and "|cFFFF0000Locked|r" or "|cFF00FF00Unlocked|r"
        DEFAULT_CHAT_FRAME:AddMessage("|cFFFFD100LazySpeed Biggins|r: Frame position is now " .. status .. ".")
    end)
    uiWidgets.cbLocked = cbLocked

    -- =========================================================================
    -- Right Column: Stacking Mode, Units, Dimensions & Position Reset
    -- =========================================================================
    local stackHeader = panel:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    stackHeader:SetPoint("TOPLEFT", panel, "TOPLEFT", 340, -120)
    stackHeader:SetText("Stacking Mode:")
    uiWidgets.stackHeader = stackHeader

    local function CreateStackingRadio(modeVal, label, tooltip, anchorPoint, relativeTo, relPoint, x, y)
        local radio = CreateFrame("CheckButton", nil, panel, "UIRadioButtonTemplate")
        radio:SetPoint(anchorPoint, relativeTo, relPoint, x, y)
        radio.text = radio:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
        radio.text:SetPoint("LEFT", radio, "RIGHT", 4, 0)
        radio.text:SetText(label)
        radio.tooltipText = tooltip
        radio:SetScript("OnClick", function()
            if not LazySpeedBigginsDB then LazySpeedBigginsDB = {} end
            LazySpeedBigginsDB.stackingMode = modeVal
            addon:UpdateLayout()
            addon:UpdateOptionsUI()
        end)
        radio:SetScript("OnEnter", function(self)
            if self.tooltipText then
                GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
                GameTooltip:SetText(self.tooltipText, 1, 1, 1, true)
                GameTooltip:Show()
            end
        end)
        radio:SetScript("OnLeave", function() GameTooltip:Hide() end)
        return radio
    end

    local rbVertical = CreateStackingRadio("VERTICAL", "Vertical (Default)", "Stacks speedometer directly above the Surge Forward / Vigor bar.", "TOPLEFT", stackHeader, "BOTTOMLEFT", 4, -4)
    uiWidgets.rbVertical = rbVertical

    local rbHorizontal = CreateStackingRadio("HORIZONTAL", "Horizontal", "Stacks speedometer and Vigor bar side-by-side in a compact horizontal ribbon.", "LEFT", rbVertical.text, "RIGHT", 16, 0)
    uiWidgets.rbHorizontal = rbHorizontal

    -- Unit Selection Header
    local unitHeader = panel:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    unitHeader:SetPoint("TOPLEFT", rbVertical, "BOTTOMLEFT", -4, -12)
    unitHeader:SetText("Speed Measurement Unit:")
    uiWidgets.unitHeader = unitHeader

    -- Radio Helper for Speed Unit
    local function CreateUnitRadio(unitVal, label, anchorPoint, relativeTo, relPoint, x, y)
        local radio = CreateFrame("CheckButton", nil, panel, "UIRadioButtonTemplate")
        radio:SetPoint(anchorPoint, relativeTo, relPoint, x, y)
        radio.text = radio:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
        radio.text:SetPoint("LEFT", radio, "RIGHT", 4, 0)
        radio.text:SetText(label)
        radio:SetScript("OnClick", function()
            if not LazySpeedBigginsDB then LazySpeedBigginsDB = {} end
            LazySpeedBigginsDB.unitMode = unitVal
            addon.lastSpeed = -1
            addon:ResetDisplay()
            addon:UpdateOptionsUI()
        end)
        return radio
    end

    local radioMPH = CreateUnitRadio(2, "Miles per Hour (mph)", "TOPLEFT", unitHeader, "BOTTOMLEFT", 4, -6)
    uiWidgets.radioMPH = radioMPH

    local radioYS = CreateUnitRadio(1, "Yards per Second (y/s)", "TOPLEFT", radioMPH, "BOTTOMLEFT", 0, -6)
    uiWidgets.radioYS = radioYS

    local radioKMH = CreateUnitRadio(3, "Kilometers per Hour (km/h)", "TOPLEFT", radioYS, "BOTTOMLEFT", 0, -6)
    uiWidgets.radioKMH = radioKMH

    local radioPCT = CreateUnitRadio(4, "Percentage (%)", "TOPLEFT", radioKMH, "BOTTOMLEFT", 0, -6)
    uiWidgets.radioPCT = radioPCT

    -- Helper to create and bind sliders
    local function CreateSettingSlider(key, label, tooltip, minVal, maxVal, step, anchorPoint, relativeTo, relPoint, x, y, unitSuffix)
        local slider = CreateFrame("Slider", nil, panel, "OptionsSliderTemplate")
        slider:SetPoint(anchorPoint, relativeTo, relPoint, x, y)
        slider:SetSize(220, 16)
        slider:SetMinMaxValues(minVal, maxVal)
        slider:SetValueStep(step)
        slider:SetObeyStepOnDrag(true)

        local suffix = unitSuffix or " px"
        local val = (LazySpeedBigginsDB and LazySpeedBigginsDB[key]) or addon.DB_DEFAULTS[key]
        slider:SetValue(val)

        local titleText = slider:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
        titleText:SetPoint("BOTTOMLEFT", slider, "TOPLEFT", 0, 4)
        titleText:SetText(label)

        local valueText = slider:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
        valueText:SetPoint("BOTTOMRIGHT", slider, "TOPRIGHT", 0, 4)
        valueText:SetText(tostring(val) .. suffix)

        if slider.Low then slider.Low:SetText(tostring(minVal) .. suffix) end
        if slider.High then slider.High:SetText(tostring(maxVal) .. suffix) end

        slider:SetScript("OnValueChanged", function(self, newVal)
            newVal = floor(newVal + 0.5)
            if not LazySpeedBigginsDB then LazySpeedBigginsDB = {} end
            LazySpeedBigginsDB[key] = newVal
            valueText:SetText(tostring(newVal) .. suffix)
            addon:UpdateLayout()
        end)
        slider:SetScript("OnEnter", function(self)
            if tooltip then
                GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
                GameTooltip:SetText(tooltip, 1, 1, 1, true)
                GameTooltip:Show()
            end
        end)
        slider:SetScript("OnLeave", function() GameTooltip:Hide() end)

        slider.titleText = titleText
        slider.valueText = valueText
        return slider
    end

    -- Sliders (Anchored below unit radios)
    local sliderWidth = CreateSettingSlider("barWidth", "Bar Width", "Adjust horizontal width of HUD bars in pixels.", 100, 300, 1, "TOPLEFT", radioPCT, "BOTTOMLEFT", -4, -20)
    uiWidgets.sliderWidth = sliderWidth

    local sliderHeight = CreateSettingSlider("barHeight", "Bar Height", "Adjust vertical height of HUD bars in pixels.", 14, 36, 1, "TOPLEFT", sliderWidth, "BOTTOMLEFT", 0, -24)
    uiWidgets.sliderHeight = sliderHeight

    local sliderSpacing = CreateSettingSlider("barSpacing", "Bar Spacing", "Adjust spacing between adjacent HUD bars in pixels (0 - 50 px).", 0, 50, 1, "TOPLEFT", sliderHeight, "BOTTOMLEFT", 0, -24)
    uiWidgets.sliderSpacing = sliderSpacing

    local sliderBgAlpha = CreateSettingSlider("bgAlpha", "Background Opacity", "Adjust the opacity of the dark background and depleted bar tracks (0% - 100%).", 0, 100, 1, "TOPLEFT", sliderSpacing, "BOTTOMLEFT", 0, -24, "%")
    uiWidgets.sliderBgAlpha = sliderBgAlpha

    -- Reset Position Button
    local btnResetPos = CreateFrame("Button", nil, panel, "UIPanelButtonTemplate")
    btnResetPos:SetPoint("TOPLEFT", sliderBgAlpha, "BOTTOMLEFT", 0, -20)
    btnResetPos:SetSize(160, 24)
    btnResetPos:SetText("Reset Position")
    btnResetPos:SetScript("OnClick", function()
        if not LazySpeedBigginsDB then LazySpeedBigginsDB = {} end
        LazySpeedBigginsDB.point = "CENTER"
        LazySpeedBigginsDB.relativePoint = "CENTER"
        LazySpeedBigginsDB.xOfs = 0
        LazySpeedBigginsDB.yOfs = -200
        addon:RestorePosition()
        DEFAULT_CHAT_FRAME:AddMessage("|cFFFFD100LazySpeed Biggins|r: Frame position reset to center.")
    end)
    btnResetPos:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:SetText("Resets HUD frame back to center screen.", 1, 1, 1, true)
        GameTooltip:Show()
    end)
    btnResetPos:SetScript("OnLeave", function() GameTooltip:Hide() end)
    uiWidgets.btnResetPos = btnResetPos

    -- Slash Command Help Note (anchored below all controls across both columns)
    local helpNote = panel:CreateFontString(nil, "ARTWORK", "GameFontDisableSmall")
    helpNote:SetPoint("TOPLEFT", btnResetPos, "BOTTOMLEFT", -324, -24)
    helpNote:SetJustifyH("LEFT")
    helpNote:SetText("Slash commands: |cFFFFD100/lazyspeedb|r (Type |cFFFFD100/lazyspeedb ?|r for available commands)")

    panel:SetScript("OnShow", function()
        addon:UpdateOptionsUI()
    end)

    -- Register with modern Settings UI as a subcategory under Biggins AddOns
    if LibBigginsSuite then
        categoryID = LibBigginsSuite:RegisterSubcategory("LazySpeedBiggins", panel, "LazySpeed")
        _G["LazySpeedBiggins_CategoryID"] = categoryID
    elseif Settings and Settings.RegisterCanvasLayoutCategory then
        local category = Settings.RegisterCanvasLayoutCategory(panel, "LazySpeed Biggins")
        Settings.RegisterAddOnCategory(category)
        categoryID = category:GetID()
        _G["LazySpeedBiggins_CategoryID"] = categoryID
    else
        InterfaceOptions_AddCategory(panel)
    end

    addon:UpdateOptionsUI()
end
