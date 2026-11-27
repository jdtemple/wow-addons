--[[ ==============================================================================
    UI Biggins - Options & Settings Panel (Canvas Layout)
    ------------------------------------------------------------------------------
    Integrated Blizzard Settings panel featuring action bar controls, macro/keybind
    text visibility toggles, TellMeWhen bar skinning and opacity slider.
============================================================================== ]]--

local addonName, addon = ...

-- Cache global functions
local _G              = _G
local pairs           = pairs
local math            = math
local tostring        = tostring
local CreateFrame     = CreateFrame
local GameTooltip     = GameTooltip
local UIParent        = UIParent
local Settings        = Settings
local LibBigginsSuite = LibBigginsSuite
local ReloadUI        = ReloadUI
local C_UI            = C_UI

function addon:CreateSettingsPanel()
    if self.settingsPanel then
        return self.settingsPanel
    end

    local panel = CreateFrame("Frame", "UIBigginsSettingsPanel", UIParent)
    panel.name = "UI Biggins"

    -- Title
    local title = panel:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
    title:SetPoint("TOPLEFT", 16, -16)
    title:SetText("|cFFFFD100UI Biggins|r")

    -- Version
    local ver = panel:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
    ver:SetPoint("LEFT", title, "RIGHT", 8, 0)
    ver:SetText("v" .. addon.version)

    -- Suite Logo Texture (Top Right)
    local logo = panel:CreateTexture(nil, "ARTWORK")
    logo:SetPoint("TOPRIGHT", -24, -16)
    logo:SetSize(64, 64)
    logo:SetTexture("Interface\\AddOns\\UIBiggins\\logo.jpg")

    -- State tracking for bulk updates and reload detection
    local checkboxes = {}
    local sliders = {}
    local sliderTMWOpacity
    local UpdateReloadState

    -- Top-Right Defaults Button
    local btnDefaults = CreateFrame("Button", nil, panel, "UIPanelButtonTemplate")
    btnDefaults:SetPoint("TOPRIGHT", logo, "BOTTOMRIGHT", 0, -8)
    btnDefaults:SetSize(110, 22)
    btnDefaults:SetText("Defaults")
    btnDefaults:SetScript("OnClick", function()
        if not UIBigginsDB then UIBigginsDB = {} end
        for k, v in pairs(addon.DB_DEFAULTS) do
            UIBigginsDB[k] = v
        end
        for key, cb in pairs(checkboxes) do
            cb:SetChecked(UIBigginsDB[key])
        end
        for key, slider in pairs(sliders) do
            slider:SetValue(UIBigginsDB[key])
            if slider.valueText then
                slider.valueText:SetText(tostring(UIBigginsDB[key]) .. "%")
            end
        end
        if panel.UpdateDropdownVisual then
            panel.UpdateDropdownVisual("default")
        end
        if panel.UpdateTMWControlsState then
            panel.UpdateTMWControlsState()
        end
        if addon.TellMeWhen and addon.TellMeWhen.UpdateBarOpacity then
            addon.TellMeWhen:UpdateBarOpacity()
        end
        if addon.ActionBars then
            addon.ActionBars:UpdateAllText()
        end
        if UpdateReloadState then
            UpdateReloadState()
        end
        print("|cFFFFD100UI Biggins:|r Settings reset to defaults.")
    end)
    btnDefaults:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:SetText("Restore all UI Biggins settings back to default.", 1, 1, 1, true)
        GameTooltip:Show()
    end)
    btnDefaults:SetScript("OnLeave", function() GameTooltip:Hide() end)

    -- Description
    local desc = panel:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
    desc:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -8)
    desc:SetPoint("RIGHT", logo, "LEFT", -20)
    desc:SetJustifyH("LEFT")
    desc:SetWordWrap(true)
    desc:SetText("Clean action bar and TellMeWhen customization matching modern Cooldown buttons and Biggins status bars.")

    -- Helper to create styled checkboxes
    local function CreateSettingCheckbox(key, label, tooltip, anchorPoint, relativeTo, relPoint, x, y, callback)
        local cb = CreateFrame("CheckButton", nil, panel, "InterfaceOptionsCheckButtonTemplate")
        cb:SetPoint(anchorPoint, relativeTo, relPoint, x, y)
        cb.Text:SetText(label)
        cb.Text:SetFontObject("GameFontHighlight")
        cb.tooltipText = tooltip
        cb:SetChecked(UIBigginsDB and UIBigginsDB[key])
        cb:SetScript("OnClick", function(self)
            UIBigginsDB[key] = self:GetChecked()
            if callback then callback(self:GetChecked()) end
        end)
        cb:SetScript("OnEnter", function(self)
            if self.tooltipText then
                GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
                GameTooltip:SetText(self.tooltipText, 1, 1, 1, true)
                GameTooltip:Show()
            end
        end)
        cb:SetScript("OnLeave", function() GameTooltip:Hide() end)
        checkboxes[key] = cb
        return cb
    end

    -- Helper to create and bind sliders
    local function CreateSettingSlider(key, label, tooltip, minVal, maxVal, step, anchorPoint, relativeTo, relPoint, x, y, unitSuffix)
        local slider = CreateFrame("Slider", nil, panel, "OptionsSliderTemplate")
        slider:SetPoint(anchorPoint, relativeTo, relPoint, x, y)
        slider:SetSize(220, 16)
        slider:SetMinMaxValues(minVal, maxVal)
        slider:SetValueStep(step)
        slider:SetObeyStepOnDrag(true)

        local suffix = unitSuffix or " px"
        local val = (UIBigginsDB and UIBigginsDB[key]) or addon.DB_DEFAULTS[key]
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
            newVal = math.floor(newVal + 0.5)
            if not UIBigginsDB then UIBigginsDB = {} end
            UIBigginsDB[key] = newVal
            valueText:SetText(tostring(newVal) .. suffix)
            if key == "tmwBarOpacity" and addon.TellMeWhen and addon.TellMeWhen.UpdateBarOpacity then
                addon.TellMeWhen:UpdateBarOpacity()
            end
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
        sliders[key] = slider
        return slider
    end

    -- Reload UI elements
    local reloadBtn = CreateFrame("Button", nil, panel, "UIPanelButtonTemplate")
    local reloadNotice = panel:CreateFontString(nil, "ARTWORK", "GameFontHighlight")

    UpdateReloadState = function()
        local initialBars = addon.initialFlattenBars
        local initialTMW  = addon.initialSkinTMW
        local initialFont = addon.initialFontChoice
        local changedBars = (initialBars ~= nil and UIBigginsDB.flattenActionBars ~= initialBars)
        local changedTMW  = (initialTMW ~= nil and UIBigginsDB.skinTellMeWhen ~= initialTMW)
        local changedFont = (initialFont ~= nil and UIBigginsDB.fontChoice ~= initialFont)
        if changedBars or changedTMW or changedFont then
            reloadNotice:SetText("|cFFFF8000Requires UI Reload to take full effect.|r")
            reloadNotice:Show()
        else
            reloadNotice:Hide()
        end
    end

    -- Action Bar Controls
    local cbFlatten = CreateSettingCheckbox(
        "flattenActionBars",
        "Flatten Action Bar Buttons",
        "Strips bulky metallic frames on action bars and standalone buttons (including Knowledge Biggins), preserving native squircle icons with a subtle drop shadow. Requires a UI reload to apply.",
        "TOPLEFT", desc, "BOTTOMLEFT", 0, -18,
        function()
            UpdateReloadState()
        end
    )

    local cbMacro = CreateSettingCheckbox(
        "hideMacroText",
        "Hide Macro Names (Reveals while dragging)",
        "Hides macro names on action buttons during normal play for an uncluttered look, but automatically reveals them whenever you drag spells or macros.",
        "TOPLEFT", cbFlatten, "BOTTOMLEFT", 0, -8,
        function()
            if addon.ActionBars then addon.ActionBars:UpdateAllText() end
        end
    )

    local cbKeybind = CreateSettingCheckbox(
        "hideKeybindText",
        "Hide Keybind Labels (Reveals while dragging)",
        "Hides hotkey labels on action buttons during normal play, but automatically reveals them whenever you drag spells or reorganize buttons.",
        "TOPLEFT", cbMacro, "BOTTOMLEFT", 0, -8,
        function()
            if addon.ActionBars then addon.ActionBars:UpdateAllText() end
        end
    )

    -- Typography & Font Replacement Section
    local fontHeader = panel:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    fontHeader:SetPoint("TOPLEFT", cbKeybind, "BOTTOMLEFT", 0, -18)
    fontHeader:SetText("Typography & Fonts")

    local fontDesc = panel:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
    fontDesc:SetPoint("TOPLEFT", fontHeader, "BOTTOMLEFT", 0, -4)
    fontDesc:SetText("Select an in-game typeface or choose Blizzard Default to disable replacement. Requires a UI reload.")

    -- Dedicated, immutable font objects for the dropdown menu & button preview
    local menuFontObjects = {}
    local function GetMenuFontObject(item)
        if not item then return nil end
        local id = item.id
        if not menuFontObjects[id] then
            local fontObj = CreateFont("UIBigginsMenuFont_" .. id)
            local fontPath = item.path or "Fonts\\FRIZQT__.TTF"
            local ok = pcall(fontObj.SetFont, fontObj, fontPath, 12, "")
            if not ok then
                pcall(fontObj.SetFont, fontObj, "Fonts\\FRIZQT__.TTF", 12, "")
            end
            fontObj:SetTextColor(1, 1, 1, 1)
            fontObj:SetShadowOffset(1, -1)
            fontObj:SetShadowColor(0, 0, 0, 1)
            menuFontObjects[id] = fontObj
        end
        return menuFontObjects[id]
    end

    local fontDropdown = CreateFrame("DropdownButton", "UIBigginsFontDropdown", panel, "WowStyle1DropdownTemplate")
    fontDropdown:SetPoint("TOPLEFT", fontDesc, "BOTTOMLEFT", 0, -8)
    fontDropdown:SetSize(180, 24)

    -- Configure dropdown button text geometry so custom font metrics aren't clipped by the default 10px height
    if fontDropdown.Text then
        fontDropdown.Text:SetHeight(20)
        fontDropdown.Text:ClearAllPoints()
        fontDropdown.Text:SetPoint("LEFT", fontDropdown, "LEFT", 10, 0)
        if fontDropdown.Arrow then
            fontDropdown.Text:SetPoint("RIGHT", fontDropdown.Arrow, "LEFT", -4, 0)
        else
            fontDropdown.Text:SetPoint("RIGHT", fontDropdown, "RIGHT", -24, 0)
        end
        fontDropdown.Text:SetJustifyH("LEFT")
        fontDropdown.Text:SetJustifyV("MIDDLE")
    end

    local function UpdateDropdownVisual(choiceId)
        local info
        if addon.FontRegistry then
            for _, item in ipairs(addon.FontRegistry) do
                if item.id == choiceId then
                    info = item
                    break
                end
            end
        end
        info = info or (addon.FontRegistry and addon.FontRegistry[1])
        local displayName = info and info.name or "Blizzard Default"

        if fontDropdown.SetDefaultText then
            fontDropdown:SetDefaultText(displayName)
        end
        if fontDropdown.SetText then
            fontDropdown:SetText(displayName)
        end

        local fontObj = GetMenuFontObject(info)
        if fontObj and fontDropdown.Text and fontDropdown.Text.SetFontObject then
            fontDropdown.Text:SetFontObject(fontObj)
            fontDropdown.Text:SetText(displayName)
            fontDropdown.Text:SetHeight(20)
        end
    end
    panel.UpdateDropdownVisual = UpdateDropdownVisual

    if fontDropdown.SetupMenu then
        fontDropdown:SetupMenu(function(btn, rootDescription)
            rootDescription:SetTag("UIBIGGINS_FONT_DROPDOWN")
            if addon.FontRegistry then
                for _, item in ipairs(addon.FontRegistry) do
                    local isSelected = function()
                        local cur = (UIBigginsDB and UIBigginsDB.fontChoice) or "default"
                        return cur == item.id
                    end
                    local setSelected = function()
                        if not UIBigginsDB then UIBigginsDB = {} end
                        UIBigginsDB.fontChoice = item.id
                        UpdateDropdownVisual(item.id)
                        if item.id ~= "default" and addon.Fonts and addon.Fonts.ApplyFont then
                            addon.Fonts:ApplyFont(item.id)
                        end
                        if UpdateReloadState then
                            UpdateReloadState()
                        end
                    end
                    local radio = rootDescription:CreateRadio(item.name, isSelected, setSelected, item.id)
                    if radio and radio.AddInitializer then
                        local thisItem = item
                        radio:AddInitializer(function(button)
                            local fontObj = GetMenuFontObject(thisItem)
                            local fs = button.fontString or button.Text
                            if fs and fs.SetFontObject and fontObj then
                                fs:SetFontObject(fontObj)
                                if fs.SetTextToFit then
                                    fs:SetTextToFit(thisItem.name)
                                else
                                    fs:SetText(thisItem.name)
                                end
                            end
                        end)
                    end
                end
            end
        end)
    end
    panel.fontDropdown = fontDropdown

    -- TellMeWhen Section
    local tmwHeader = panel:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    tmwHeader:SetPoint("TOPLEFT", fontDropdown, "BOTTOMLEFT", 0, -18)
    tmwHeader:SetText("TellMeWhen")

    local tmwStatusNote = panel:CreateFontString(nil, "ARTWORK", "GameFontDisableSmall")
    tmwStatusNote:SetPoint("LEFT", tmwHeader, "RIGHT", 8, 0)

    local function GetTMWStatus()
        local isLoaded = (C_AddOns and C_AddOns.IsAddOnLoaded and C_AddOns.IsAddOnLoaded("TellMeWhen"))
                         or (IsAddOnLoaded and IsAddOnLoaded("TellMeWhen"))
        if isLoaded then
            return "LOADED", nil
        end

        local exists = (C_AddOns and C_AddOns.DoesAddOnExist and C_AddOns.DoesAddOnExist("TellMeWhen"))
        if not exists and GetAddOnInfo then
            local name = GetAddOnInfo("TellMeWhen")
            exists = (name ~= nil)
        end

        if exists then
            return "DISABLED", "Installed, but disabled in your AddOns list"
        else
            return "NOT_INSTALLED", "Not installed"
        end
    end

    local cbTMW
    local UpdateTMWControlsState = function()
        local status, message = GetTMWStatus()
        if status ~= "LOADED" then
            tmwStatusNote:SetText("|cFFFF8000(" .. message .. ")|r")
            tmwStatusNote:Show()
            if cbTMW then
                cbTMW:SetEnabled(false)
                cbTMW:SetAlpha(0.4)
            end
            if sliderTMWOpacity then
                sliderTMWOpacity:SetEnabled(false)
                sliderTMWOpacity:SetAlpha(0.4)
            end
        else
            tmwStatusNote:Hide()
            if cbTMW then
                cbTMW:SetEnabled(true)
                cbTMW:SetAlpha(1.0)
            end
            local currentTMWEnabled = (UIBigginsDB and UIBigginsDB.skinTellMeWhen)
            if sliderTMWOpacity then
                sliderTMWOpacity:SetEnabled(currentTMWEnabled)
                sliderTMWOpacity:SetAlpha(currentTMWEnabled and 1.0 or 0.4)
            end
        end
    end
    panel.UpdateTMWControlsState = UpdateTMWControlsState

    cbTMW = CreateSettingCheckbox(
        "skinTellMeWhen",
        "Skin Icons & Bars",
        "Skins TellMeWhen icons (with 45-degree chamfers and drop shadows) and status bars (matching LazySpeed and Perf gold-bordered styling). Requires a UI reload to apply.",
        "TOPLEFT", tmwHeader, "BOTTOMLEFT", 16, -6,
        function(checked)
            UpdateReloadState()
            UpdateTMWControlsState()
        end
    )

    sliderTMWOpacity = CreateSettingSlider(
        "tmwBarOpacity",
        "Bar Background Opacity",
        "Adjust the background opacity of TellMeWhen status bars (0% - 100%). Default is 25%.",
        0, 100, 1,
        "TOPLEFT", cbTMW, "BOTTOMLEFT", 4, -22,
        "%"
    )
    panel.sliderTMWOpacity = sliderTMWOpacity
    UpdateTMWControlsState()

    -- Reload UI Button (dedicated, cleanly placed below the options)
    reloadBtn:SetSize(120, 24)
    reloadBtn:SetPoint("TOPLEFT", sliderTMWOpacity, "BOTTOMLEFT", -20, -22)
    reloadBtn:SetText("Reload UI")
    reloadBtn:SetScript("OnClick", function()
        if C_UI and C_UI.Reload then
            C_UI.Reload()
        else
            ReloadUI()
        end
    end)

    reloadNotice:SetPoint("LEFT", reloadBtn, "RIGHT", 12, 0)
    UpdateReloadState()

    -- Slash Command Help Note
    local helpNote = panel:CreateFontString(nil, "ARTWORK", "GameFontDisableSmall")
    helpNote:SetPoint("TOPLEFT", reloadBtn, "BOTTOMLEFT", 0, -18)
    helpNote:SetJustifyH("LEFT")
    helpNote:SetText("Slash command: |cFFFFD100/uibiggins|r (Type |cFFFFD100/uibiggins ?|r for available commands)")

    addon.settingsPanel = panel

    panel:SetScript("OnShow", function()
        for key, cb in pairs(checkboxes) do
            cb:SetChecked(UIBigginsDB and UIBigginsDB[key])
        end
        for key, slider in pairs(sliders) do
            local val = (UIBigginsDB and UIBigginsDB[key]) or addon.DB_DEFAULTS[key]
            slider:SetValue(val)
            if slider.valueText then
                slider.valueText:SetText(tostring(val) .. "%")
            end
        end
        if panel.UpdateTMWControlsState then
            panel.UpdateTMWControlsState()
        end
        local curChoice = (UIBigginsDB and UIBigginsDB.fontChoice) or "default"
        UpdateDropdownVisual(curChoice)
        UpdateReloadState()
    end)

    -- Register with LibBigginsSuite or Settings API
    local categoryID
    if LibBigginsSuite then
        categoryID = LibBigginsSuite:RegisterSubcategory("UIBiggins", panel, "UI")
        _G["UIBiggins_CategoryID"] = categoryID
        addon.categoryID = categoryID
    elseif Settings and Settings.RegisterCanvasLayoutCategory then
        local category = Settings.RegisterCanvasLayoutCategory(panel, "UI Biggins")
        Settings.RegisterAddOnCategory(category)
        categoryID = category:GetID()
        _G["UIBiggins_CategoryID"] = categoryID
        addon.categoryID = categoryID
    elseif InterfaceOptions_AddCategory then
        InterfaceOptions_AddCategory(panel)
    end
end
