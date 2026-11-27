--[[ ==============================================================================
    Perf Biggins - Options & Settings Panel (Canvas Layout)
    ------------------------------------------------------------------------------
    Integrated Blizzard Settings panel featuring two-column layout: visibility &
    behavior toggles on the left, stacking mode & dimensions on the right.
============================================================================== ]]--

local addonName, addon = ...

-- Cache global functions
local _G              = _G
local pairs           = pairs
local ipairs          = ipairs
local tostring        = tostring
local math_floor      = math.floor
local CreateFrame     = CreateFrame
local GameTooltip     = GameTooltip
local UIParent        = UIParent
local Settings        = Settings
local LibBigginsSuite = LibBigginsSuite
local InterfaceOptions_AddCategory = InterfaceOptions_AddCategory

local uiWidgets = {}
addon.uiWidgets = uiWidgets

local function ResetAllToDefaults()
    if not PerfBigginsDB then PerfBigginsDB = {} end
    for varName, defVal in pairs(addon.DB_DEFAULTS) do
        PerfBigginsDB[varName] = defVal
    end
    addon:RestorePosition()
    addon:UpdateOptionsUI()
    addon:UpdateLayout()
    addon:PrintMsg("All options and frame position have been reset to default.")
end

function addon:UpdateOptionsUI()
    if not uiWidgets.panel or not PerfBigginsDB then return end
    local isEnabled = PerfBigginsDB.enabled ~= false

    if uiWidgets.cbEnable then uiWidgets.cbEnable:SetChecked(isEnabled) end
    if uiWidgets.cbFps then uiWidgets.cbFps:SetChecked(PerfBigginsDB.showFps) end
    if uiWidgets.cbWorld then uiWidgets.cbWorld:SetChecked(PerfBigginsDB.showWorld) end
    if uiWidgets.cbHome then uiWidgets.cbHome:SetChecked(PerfBigginsDB.showHome) end
    if uiWidgets.cbLocked then uiWidgets.cbLocked:SetChecked(PerfBigginsDB.locked) end
    if uiWidgets.cbCombat then uiWidgets.cbCombat:SetChecked(PerfBigginsDB.hideInCombat) end

    -- Stacking Mode radio buttons
    local isVertical = (PerfBigginsDB.stackingMode or "VERTICAL") == "VERTICAL"
    if uiWidgets.rbVertical   then uiWidgets.rbVertical:SetChecked(isVertical) end
    if uiWidgets.rbHorizontal then uiWidgets.rbHorizontal:SetChecked(not isVertical) end

    -- Auto FPS detection toggle and dynamic cap slider
    local isAutoFps = PerfBigginsDB.autoFpsCap ~= false
    if uiWidgets.cbAutoFps then uiWidgets.cbAutoFps:SetChecked(isAutoFps) end

    if uiWidgets.sliderFpsCap then
        local capVal = isAutoFps and addon.activeFpsCap or (PerfBigginsDB.manualFpsCap or addon.DEFAULT_FPS_CAP)
        uiWidgets.sliderFpsCap:SetValue(capVal)
        if uiWidgets.sliderFpsCap.valueText then
            local suffix = isAutoFps and " FPS (Auto)" or " FPS"
            uiWidgets.sliderFpsCap.valueText:SetText(tostring(math_floor(capVal)) .. suffix)
        end
        uiWidgets.sliderFpsCap:SetEnabled(isEnabled and not isAutoFps)
        uiWidgets.sliderFpsCap:SetAlpha((isEnabled and not isAutoFps) and 1.0 or 0.5)
    end

    if uiWidgets.sliderWidth then
        uiWidgets.sliderWidth:SetValue(PerfBigginsDB.barWidth or 180)
        if uiWidgets.sliderWidth.valueText then
            uiWidgets.sliderWidth.valueText:SetText(tostring(PerfBigginsDB.barWidth or 180) .. " px")
        end
    end
    if uiWidgets.sliderHeight then
        uiWidgets.sliderHeight:SetValue(PerfBigginsDB.barHeight or 18)
        if uiWidgets.sliderHeight.valueText then
            uiWidgets.sliderHeight.valueText:SetText(tostring(PerfBigginsDB.barHeight or 18) .. " px")
        end
    end
    if uiWidgets.sliderSpacing then
        uiWidgets.sliderSpacing:SetValue(PerfBigginsDB.barSpacing or 4)
        if uiWidgets.sliderSpacing.valueText then
            uiWidgets.sliderSpacing.valueText:SetText(tostring(PerfBigginsDB.barSpacing or 4) .. " px")
        end
    end
    if uiWidgets.sliderBgAlpha then
        local bgVal = PerfBigginsDB.bgAlpha ~= nil and PerfBigginsDB.bgAlpha or 25
        uiWidgets.sliderBgAlpha:SetValue(bgVal)
        if uiWidgets.sliderBgAlpha.valueText then
            uiWidgets.sliderBgAlpha.valueText:SetText(tostring(bgVal) .. "%")
        end
    end

    -- Gray out child controls when disabled
    local childWidgets = {
        uiWidgets.cbFps, uiWidgets.cbWorld, uiWidgets.cbHome,
        uiWidgets.stackHeader, uiWidgets.rbVertical, uiWidgets.rbHorizontal,
        uiWidgets.cbAutoFps,
        uiWidgets.cbLocked, uiWidgets.cbCombat,
        uiWidgets.sliderWidth, uiWidgets.sliderHeight, uiWidgets.sliderSpacing, uiWidgets.sliderBgAlpha, uiWidgets.btnResetPos
    }
    for _, w in ipairs(childWidgets) do
        if w then
            if w.SetEnabled then w:SetEnabled(isEnabled) end
            w:SetAlpha(isEnabled and 1.0 or 0.5)
        end
    end
end

function addon:RegisterOptions()
    local panel = CreateFrame("Frame", "PerfBigginsOptionsPanel", UIParent)
    panel.name = "Perf Biggins"
    uiWidgets.panel = panel

    -- Title (Blizzard Gold)
    local title = panel:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
    title:SetPoint("TOPLEFT", 16, -16)
    title:SetText("|cFFFFD100Perf Biggins|r")

    -- Subtitle / Description
    local desc = panel:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
    desc:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -6)
    desc:SetText("High-performance FPS and dual-latency telemetry HUD with zero Lua garbage generation.")

    -- Suite Logo Texture (Top Right)
    local logo = panel:CreateTexture(nil, "ARTWORK")
    logo:SetPoint("TOPRIGHT", -24, -16)
    logo:SetSize(64, 64)
    logo:SetTexture("Interface\\AddOns\\PerfBiggins\\logo.jpg")

    -- Top-Right "Defaults" Button
    local btnDefaults = CreateFrame("Button", nil, panel, "UIPanelButtonTemplate")
    btnDefaults:SetPoint("TOPRIGHT", logo, "BOTTOMRIGHT", 0, -8)
    btnDefaults:SetSize(110, 22)
    btnDefaults:SetText("Defaults")
    btnDefaults:SetScript("OnClick", function()
        ResetAllToDefaults()
    end)
    btnDefaults:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:SetText("Restore all Perf Biggins settings and frame position back to default.", 1, 1, 1, true)
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
        local currentVal = (PerfBigginsDB and PerfBigginsDB[key] ~= nil) and PerfBigginsDB[key] or addon.DB_DEFAULTS[key]
        cb:SetChecked(currentVal)
        cb:SetScript("OnClick", function(self)
            if not PerfBigginsDB then PerfBigginsDB = {} end
            PerfBigginsDB[key] = self:GetChecked()
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
    local cbEnable = CreateSettingCheckbox("enabled", "Enable Performance HUD", "Show or hide the performance telemetry HUD overlay.", "TOPLEFT", desc, "BOTTOMLEFT", 0, -18, function(val)
        local status = val and "|cFF00FF00Enabled|r" or "|cFFFF0000Disabled|r"
        addon:PrintMsg("Performance HUD is now " .. status .. ".")
    end)
    uiWidgets.cbEnable = cbEnable

    -- Child Checkboxes (Indented 20px)
    local cbFps = CreateSettingCheckbox("showFps", "Show FPS Bar", "Displays the real-time Frames Per Second bar.", "TOPLEFT", cbEnable, "BOTTOMLEFT", 20, -6)
    uiWidgets.cbFps = cbFps

    local cbWorld = CreateSettingCheckbox("showWorld", "Show World Latency Bar", "Displays World Latency (combat, ability casts, encounter mechanics).", "TOPLEFT", cbFps, "BOTTOMLEFT", 0, -6)
    uiWidgets.cbWorld = cbWorld

    local cbHome = CreateSettingCheckbox("showHome", "Show Home Latency Bar", "Displays Home Latency (chat, auction house, guild system, realm data).", "TOPLEFT", cbWorld, "BOTTOMLEFT", 0, -6)
    uiWidgets.cbHome = cbHome

    local cbLocked = CreateSettingCheckbox("locked", "Lock Frame Position", "Prevents dragging the telemetry frame with the mouse.", "TOPLEFT", cbHome, "BOTTOMLEFT", -20, -8, function(val)
        local status = val and "|cFFFF0000Locked|r" or "|cFF00FF00Unlocked|r"
        addon:PrintMsg("Frame position is now " .. status .. ".")
    end)
    uiWidgets.cbLocked = cbLocked

    local cbCombat = CreateSettingCheckbox("hideInCombat", "Hide During Combat", "Automatically hides the HUD while in combat to reduce screen clutter.", "TOPLEFT", cbLocked, "BOTTOMLEFT", 0, -6)
    uiWidgets.cbCombat = cbCombat

    -- Auto-Detect Max FPS Checkbox
    local cbAutoFps = CreateSettingCheckbox("autoFpsCap", "Auto-Detect Max FPS (Recommended)", "Automatically detects your Max Foreground FPS limit or display refresh rate from WoW settings.", "TOPLEFT", cbCombat, "BOTTOMLEFT", 0, -6, function(val)
        addon:CalculateActiveFpsCap()
        addon:UpdateOptionsUI()
    end)
    uiWidgets.cbAutoFps = cbAutoFps

    -- Helper to create and bind sliders
    local function CreateSettingSlider(key, label, tooltip, minVal, maxVal, step, anchorPoint, relativeTo, relPoint, x, y, unitSuffix)
        local slider = CreateFrame("Slider", nil, panel, "OptionsSliderTemplate")
        slider:SetPoint(anchorPoint, relativeTo, relPoint, x, y)
        slider:SetSize(220, 16)
        slider:SetMinMaxValues(minVal, maxVal)
        slider:SetValueStep(step)
        slider:SetObeyStepOnDrag(true)

        local suffix = unitSuffix or " px"
        local val = (PerfBigginsDB and PerfBigginsDB[key]) or addon.DB_DEFAULTS[key]
        slider:SetValue(val)

        local titleText = slider:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
        titleText:SetPoint("BOTTOMLEFT", slider, "TOPLEFT", 0, 4)
        titleText:SetText(label)

        local valueText = slider:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
        valueText:SetPoint("BOTTOMRIGHT", slider, "TOPRIGHT", 0, 4)
        valueText:SetText(tostring(val) .. suffix)

        if slider.Low then slider.Low:SetText(tostring(minVal)) end
        if slider.High then slider.High:SetText(tostring(maxVal)) end

        slider:SetScript("OnValueChanged", function(self, newVal)
            newVal = math_floor(newVal + 0.5)
            if not PerfBigginsDB then PerfBigginsDB = {} end
            PerfBigginsDB[key] = newVal
            valueText:SetText(tostring(newVal) .. suffix)
            if key == "manualFpsCap" then
                addon:CalculateActiveFpsCap()
            end
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

    -- Sliders (Anchored below checkboxes in left column)
    local sliderFpsCap = CreateSettingSlider("manualFpsCap", "FPS Bar Max Scale", "Sets the frame rate target required for a 100% full status bar.", 60, 360, 1, "TOPLEFT", cbAutoFps, "BOTTOMLEFT", 4, -22, " FPS")
    sliderFpsCap.valueText:SetText(tostring(addon.activeFpsCap) .. " FPS")
    uiWidgets.sliderFpsCap = sliderFpsCap

    -- Right Column: Stacking Mode, Dimensions, Spacing & Position Reset
    local stackHeader = panel:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
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
            if not PerfBigginsDB then PerfBigginsDB = {} end
            PerfBigginsDB.stackingMode = modeVal
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

    local rbVertical = CreateStackingRadio("VERTICAL", "Vertical (Default)", "Stacks telemetry bars vertically top-to-bottom like a compact nameplate stack.", "TOPLEFT", stackHeader, "BOTTOMLEFT", 4, -4)
    uiWidgets.rbVertical = rbVertical

    local rbHorizontal = CreateStackingRadio("HORIZONTAL", "Horizontal", "Stacks telemetry bars horizontally side-by-side in a compact ribbon.", "LEFT", rbVertical.text, "RIGHT", 16, 0)
    uiWidgets.rbHorizontal = rbHorizontal

    local sliderWidth = CreateSettingSlider("barWidth", "Bar Width", "Adjust the horizontal width of telemetry bars in pixels.", 100, 300, 1, "TOPLEFT", rbVertical, "BOTTOMLEFT", -4, -24)
    uiWidgets.sliderWidth = sliderWidth

    local sliderHeight = CreateSettingSlider("barHeight", "Bar Height", "Adjust the vertical height of telemetry bars in pixels.", 12, 36, 1, "TOPLEFT", sliderWidth, "BOTTOMLEFT", 0, -24)
    uiWidgets.sliderHeight = sliderHeight

    local sliderSpacing = CreateSettingSlider("barSpacing", "Bar Spacing", "Adjust the spacing between adjacent telemetry bars in pixels (0 - 50 px).", 0, 50, 1, "TOPLEFT", sliderHeight, "BOTTOMLEFT", 0, -24)
    uiWidgets.sliderSpacing = sliderSpacing

    local sliderBgAlpha = CreateSettingSlider("bgAlpha", "Background Opacity", "Adjust the opacity of the dark background and depleted bar tracks (0% - 100%).", 0, 100, 1, "TOPLEFT", sliderSpacing, "BOTTOMLEFT", 0, -24, "%")
    uiWidgets.sliderBgAlpha = sliderBgAlpha

    -- Reset Position Button
    local btnResetPos = CreateFrame("Button", nil, panel, "UIPanelButtonTemplate")
    btnResetPos:SetPoint("TOPLEFT", sliderBgAlpha, "BOTTOMLEFT", 0, -20)
    btnResetPos:SetSize(160, 24)
    btnResetPos:SetText("Reset Position")
    btnResetPos:SetScript("OnClick", function()
        if not PerfBigginsDB then PerfBigginsDB = {} end
        PerfBigginsDB.point = "CENTER"
        PerfBigginsDB.relativePoint = "CENTER"
        PerfBigginsDB.xOfs = 0
        PerfBigginsDB.yOfs = -160
        addon:RestorePosition()
        addon:PrintMsg("Frame position reset to screen center.")
    end)
    btnResetPos:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:SetText("Resets telemetry HUD back to the center of your screen.", 1, 1, 1, true)
        GameTooltip:Show()
    end)
    btnResetPos:SetScript("OnLeave", function() GameTooltip:Hide() end)
    uiWidgets.btnResetPos = btnResetPos

    -- Slash Command Help Note (anchored below the lowest control on the panel)
    local helpNote = panel:CreateFontString(nil, "ARTWORK", "GameFontDisableSmall")
    helpNote:SetPoint("TOPLEFT", sliderFpsCap, "BOTTOMLEFT", -4, -30)
    helpNote:SetJustifyH("LEFT")
    helpNote:SetText("Keybinds: Game Menu -> Options -> Keybindings -> AddOns -> Perf Biggins\nSlash commands: |cFFFFD100/perfb|r (Type |cFFFFD100/perfb ?|r for available commands)")

    panel:SetScript("OnShow", function()
        addon:UpdateOptionsUI()
    end)

    -- Register with modern Settings UI as a subcategory under Biggins AddOns
    if LibBigginsSuite then
        addon.categoryID = LibBigginsSuite:RegisterSubcategory("PerfBiggins", panel, "Perf")
    elseif Settings and Settings.RegisterCanvasLayoutCategory then
        local category = Settings.RegisterCanvasLayoutCategory(panel, "Perf Biggins")
        Settings.RegisterAddOnCategory(category)
        addon.categoryID = category:GetID()
    elseif InterfaceOptions_AddCategory then
        InterfaceOptions_AddCategory(panel)
    end

    addon:UpdateOptionsUI()
end

-- Open Settings Panel
function addon:OpenSettings()
    addon:UpdateOptionsUI()
    if addon.categoryID and Settings and Settings.OpenToCategory then
        Settings.OpenToCategory(addon.categoryID)
    else
        addon:PrintMsg("Options available in Game Menu -> Options -> AddOns -> Perf Biggins.")
    end
end
