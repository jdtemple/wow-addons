--[[ ==============================================================================
    UI Biggins v1.1.0
    ------------------------------------------------------------------------------
    Author: Biggins (US-Whisperwind)
    Compatibility: World of Warcraft: Midnight (Patch 12.1.7 / 12.1+) & The War Within

    FEATURES:
    1. Flatten Action Bar Buttons:
       - Strips bulky metallic frames, background slot art, and decorative bevels.
       - Preserves native icon sizing, proportions, and 45-degree chamfered corners.
       - Adds a soft, subtle drop shadow matching Blizzard's Cooldown Manager buttons.
       - Clean, leak-free design: requires a UI reload to switch states safely.
    2. Skin TellMeWhen (Icons & Bars):
       - Icons: Applies matching 45-degree chamfered squircle masks and soft drop shadows.
       - Bars: Wraps status bars in signature Biggins Suite gold tooltip borders with dark tracks.
       - Strips TellMeWhen default borders.
    3. Smart Macro Text Hiding:
       - Hides macro text labels during normal gameplay for an uncluttered look.
       - Automatically reveals macro labels while dragging spells or macros
         (ACTIONBAR_SHOWGRID / cursor pickup) so you know where you are placing macros.
    4. Smart Keybind Text Hiding:
       - Hides hotkey labels during normal gameplay for an uncluttered look.
       - Automatically reveals hotkeys while dragging abilities so you see slot bindings.
    5. 100% Non-Invasive:
       - Does not alter Edit Mode, unit frames, chat, CVars, or keybindings.
============================================================================== ]]--

local addonName, addon = ...
_G["UIBiggins"] = addon
addon.version = "1.1.0"

-- Cache upvalues
local _G = _G
local pairs = pairs
local CreateFrame = CreateFrame
local GetCursorInfo = GetCursorInfo
local Settings = Settings

-- Configuration Defaults
addon.DB_DEFAULTS = {
    flattenActionBars = true,
    skinTellMeWhen    = true,
    tmwBarOpacity     = 25,
    hideMacroText     = true,
    hideKeybindText   = true,
}

local initialFlattenBars = nil
local initialSkinTMW     = nil

-- ==============================================================================
-- 1. SETTINGS PANEL (LibBigginsSuite & Blizzard Settings API)
-- ==============================================================================

function addon:CreateSettingsPanel()
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
        local tmwEnabled = UIBigginsDB.skinTellMeWhen
        if sliderTMWOpacity then
            sliderTMWOpacity:SetEnabled(tmwEnabled)
            sliderTMWOpacity:SetAlpha(tmwEnabled and 1.0 or 0.5)
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
        local changedBars = (UIBigginsDB.flattenActionBars ~= initialFlattenBars)
        local changedTMW  = (UIBigginsDB.skinTellMeWhen ~= initialSkinTMW)
        if changedBars or changedTMW then
            reloadNotice:SetText("|cFFFF8000Requires UI Reload to take effect.|r")
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

    -- TellMeWhen Section
    local tmwHeader = panel:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    tmwHeader:SetPoint("TOPLEFT", cbKeybind, "BOTTOMLEFT", 0, -18)
    tmwHeader:SetText("TellMeWhen")

    local cbTMW = CreateSettingCheckbox(
        "skinTellMeWhen",
        "Skin Icons & Bars",
        "Skins TellMeWhen icons (with 45-degree chamfers and drop shadows) and status bars (matching LazySpeed and Perf gold-bordered styling). Requires a UI reload to apply.",
        "TOPLEFT", tmwHeader, "BOTTOMLEFT", 16, -6,
        function(checked)
            UpdateReloadState()
            if sliderTMWOpacity then
                sliderTMWOpacity:SetEnabled(checked)
                sliderTMWOpacity:SetAlpha(checked and 1.0 or 0.5)
            end
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
    local tmwEnabled = (UIBigginsDB and UIBigginsDB.skinTellMeWhen)
    sliderTMWOpacity:SetEnabled(tmwEnabled)
    sliderTMWOpacity:SetAlpha(tmwEnabled and 1.0 or 0.5)

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
        local currentTMWEnabled = (UIBigginsDB and UIBigginsDB.skinTellMeWhen)
        if sliderTMWOpacity then
            sliderTMWOpacity:SetEnabled(currentTMWEnabled)
            sliderTMWOpacity:SetAlpha(currentTMWEnabled and 1.0 or 0.5)
        end
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
    else
        InterfaceOptions_AddCategory(panel)
    end
end

-- ==============================================================================
-- 2. LIFECYCLE EVENT DISPATCHER
-- ==============================================================================

local eventFrame = CreateFrame("Frame")
eventFrame:RegisterEvent("ADDON_LOADED")
eventFrame:RegisterEvent("PLAYER_LOGIN")
eventFrame:RegisterEvent("ACTIONBAR_SHOWGRID")
eventFrame:RegisterEvent("ACTIONBAR_HIDEGRID")
eventFrame:RegisterEvent("CURSOR_CHANGED")

eventFrame:SetScript("OnEvent", function(self, event, arg1)
    if event == "ADDON_LOADED" then
        if arg1 == addonName then
            if not UIBigginsDB then
                UIBigginsDB = {}
            end
            for k, v in pairs(addon.DB_DEFAULTS) do
                if UIBigginsDB[k] == nil then
                    UIBigginsDB[k] = v
                end
            end
            -- Migration: preserve legacy flattenTellMeWhen setting if present
            if UIBigginsDB.skinTellMeWhen == nil and UIBigginsDB.flattenTellMeWhen ~= nil then
                UIBigginsDB.skinTellMeWhen = UIBigginsDB.flattenTellMeWhen
            end
            initialFlattenBars = UIBigginsDB.flattenActionBars
            initialSkinTMW     = UIBigginsDB.skinTellMeWhen
        elseif arg1 == "TellMeWhen" then
            if addon.TellMeWhen then
                addon.TellMeWhen:Initialize()
            end
        elseif arg1 == "KnowledgeBiggins" then
            if addon.ActionBars then
                addon.ActionBars:SkinKnowledgeBiggins()
            end
        end
    elseif event == "PLAYER_LOGIN" then
        if addon.ActionBars then
            addon.ActionBars:Initialize()
            addon.ActionBars:SkinKnowledgeBiggins()
        end
        if addon.TellMeWhen then
            addon.TellMeWhen:Initialize()
        end
        addon:CreateSettingsPanel()
    elseif event == "ACTIONBAR_SHOWGRID" then
        if addon.ActionBars then addon.ActionBars:SetDragging(true) end
    elseif event == "ACTIONBAR_HIDEGRID" then
        if addon.ActionBars then addon.ActionBars:SetDragging(false) end
    elseif event == "CURSOR_CHANGED" then
        local cursorType = GetCursorInfo()
        if addon.ActionBars then
            addon.ActionBars:SetDragging(cursorType ~= nil)
        end
    end
end)

-- Slash command
SLASH_UIBIGGINS1 = "/uibiggins"
SlashCmdList["UIBIGGINS"] = function(msg)
    local raw = string.gsub(msg or "", "^%s*(.-)%s*$", "%1")
    local cmd, arg1 = string.match(raw, "^(%S+)%s*(.*)$")
    cmd = string.lower(cmd or raw)

    if cmd == "?" or cmd == "help" then
        print("|cFFFFD100UI Biggins|r v" .. addon.version .. " commands:")
        print("  |cFFFFD100/uibiggins|r - Open settings panel")
        print("  |cFFFFD100/uibiggins opacity <0-100>|r - Set TellMeWhen status bar background opacity")
        print("  |cFFFFD100/uibiggins ?|r or |cFFFFD100/uibiggins help|r - Show available commands")
        return
    end

    if cmd == "opacity" then
        local val = tonumber(arg1)
        if val then
            val = math.floor(math.max(0, math.min(100, val)) + 0.5)
            if not UIBigginsDB then UIBigginsDB = {} end
            UIBigginsDB.tmwBarOpacity = val
            if addon.TellMeWhen and addon.TellMeWhen.UpdateBarOpacity then
                addon.TellMeWhen:UpdateBarOpacity()
            end
            if addon.settingsPanel and addon.settingsPanel.sliderTMWOpacity then
                addon.settingsPanel.sliderTMWOpacity:SetValue(val)
            end
            print("|cFFFFD100UI Biggins:|r TellMeWhen status bar background opacity set to |cFFFFD100" .. val .. "%|r.")
        else
            local cur = (UIBigginsDB and UIBigginsDB.tmwBarOpacity) or addon.DB_DEFAULTS.tmwBarOpacity
            print("|cFFFFD100UI Biggins:|r TellMeWhen status bar background opacity is currently |cFFFFD100" .. cur .. "%|r.")
        end
        return
    end

    if cmd ~= "" and cmd ~= "options" and cmd ~= "config" and cmd ~= "settings" then
        print("|cFFFFD100UI Biggins|r: Unknown command '|cFFFFD100" .. cmd .. "|r'. Type |cFFFFD100/uibiggins ?|r for available commands.")
        return
    end

    if Settings and Settings.OpenToCategory then
        local catID = _G["UIBiggins_CategoryID"]
        if catID then
            Settings.OpenToCategory(catID)
            return
        end
    end
    if LibBigginsSuite and LibBigginsSuite.OpenToSubcategory then
        LibBigginsSuite:OpenToSubcategory("UIBiggins")
        return
    end
    print("|cFFFFD100UI Biggins|r: Settings available in Game Menu -> Options -> AddOns -> Biggins Suite -> UI.")
end
