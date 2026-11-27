--[[ ==============================================================================
    UI Biggins v1.0.0
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
addon.version = "1.0.0"

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
        if addon.ActionBars then
            addon.ActionBars:UpdateAllText()
        end
        UpdateReloadState()
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

    -- Track checkboxes for bulk updates
    local checkboxes = {}

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

    -- Reload UI elements
    local reloadBtn = CreateFrame("Button", nil, panel, "UIPanelButtonTemplate")
    local reloadNotice = panel:CreateFontString(nil, "ARTWORK", "GameFontHighlight")

    local function UpdateReloadState()
        local changedBars = (UIBigginsDB.flattenActionBars ~= initialFlattenBars)
        local changedTMW  = (UIBigginsDB.skinTellMeWhen ~= initialSkinTMW)
        if changedBars or changedTMW then
            reloadNotice:SetText("|cFFFF8000Requires UI Reload to take effect.|r")
            reloadNotice:Show()
        else
            reloadNotice:Hide()
        end
    end

    -- Checkbox 1: Flatten Action Buttons
    local cbFlatten = CreateSettingCheckbox(
        "flattenActionBars",
        "Flatten Action Bar Buttons",
        "Strips bulky metallic frames on action bars and standalone buttons (including Knowledge Biggins), preserving native squircle icons with a subtle drop shadow. Requires a UI reload to apply.",
        "TOPLEFT", desc, "BOTTOMLEFT", 0, -20,
        function()
            UpdateReloadState()
        end
    )

    -- Checkbox 2: Skin TellMeWhen (Icons & Bars)
    local cbTMW = CreateSettingCheckbox(
        "skinTellMeWhen",
        "Skin TellMeWhen (Icons & Bars)",
        "Skins TellMeWhen icons (with 45-degree chamfers and drop shadows) and status bars (matching LazySpeed and Perf gold-bordered styling). Requires a UI reload to apply.",
        "TOPLEFT", cbFlatten, "BOTTOMLEFT", 0, -12,
        function()
            UpdateReloadState()
        end
    )

    -- Checkbox 3: Hide Macro Text
    local cbMacro = CreateSettingCheckbox(
        "hideMacroText",
        "Hide Macro Names (Reveals while dragging)",
        "Hides macro names on action buttons during normal play for an uncluttered look, but automatically reveals them whenever you drag spells or macros.",
        "TOPLEFT", cbTMW, "BOTTOMLEFT", 0, -12,
        function()
            if addon.ActionBars then addon.ActionBars:UpdateAllText() end
        end
    )

    -- Checkbox 4: Hide Keybind Text
    local cbKeybind = CreateSettingCheckbox(
        "hideKeybindText",
        "Hide Keybind Labels (Reveals while dragging)",
        "Hides hotkey labels on action buttons during normal play, but automatically reveals them whenever you drag spells or reorganize buttons.",
        "TOPLEFT", cbMacro, "BOTTOMLEFT", 0, -12,
        function()
            if addon.ActionBars then addon.ActionBars:UpdateAllText() end
        end
    )

    -- Reload UI Button (dedicated, cleanly placed below the options)
    reloadBtn:SetSize(120, 24)
    reloadBtn:SetPoint("TOPLEFT", cbKeybind, "BOTTOMLEFT", 0, -20)
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
    helpNote:SetPoint("TOPLEFT", reloadBtn, "BOTTOMLEFT", 0, -20)
    helpNote:SetJustifyH("LEFT")
    helpNote:SetText("Slash command: |cFFFFD100/uibiggins|r (Type |cFFFFD100/uibiggins ?|r for available commands)")

    panel:SetScript("OnShow", function()
        for key, cb in pairs(checkboxes) do
            cb:SetChecked(UIBigginsDB and UIBigginsDB[key])
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
    local cmd = string.lower(string.gsub(msg or "", "^%s*(.-)%s*$", "%1"))

    if cmd == "?" or cmd == "help" then
        print("|cFFFFD100UI Biggins|r v" .. addon.version .. " commands:")
        print("  |cFFFFD100/uibiggins|r - Open settings panel")
        print("  |cFFFFD100/uibiggins ?|r or |cFFFFD100/uibiggins help|r - Show available commands")
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
