--[[ ==============================================================================
    UI Biggins v1.2.0
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
addon.version = "1.2.0"

-- Cache upvalues
local _G = _G
local pairs = pairs
local CreateFrame = CreateFrame
local GetCursorInfo = GetCursorInfo
local Settings = Settings
local LibBigginsSuite = LibBigginsSuite

-- Configuration Defaults
addon.DB_DEFAULTS = {
    flattenActionBars = true,
    skinTellMeWhen    = true,
    tmwBarOpacity     = 25,
    hideMacroText     = true,
    hideKeybindText   = true,
    fontChoice        = "default",
}

-- ==============================================================================
-- LIFECYCLE EVENT DISPATCHER
-- ==============================================================================

local eventFrame = CreateFrame("Frame")
eventFrame:RegisterEvent("ADDON_LOADED")
eventFrame:RegisterEvent("PLAYER_LOGIN")
eventFrame:RegisterEvent("PLAYER_ENTERING_WORLD")
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
            addon.initialFlattenBars = UIBigginsDB.flattenActionBars
            addon.initialSkinTMW     = UIBigginsDB.skinTellMeWhen
            addon.initialFontChoice  = UIBigginsDB.fontChoice or "default"
            if addon.Fonts then
                addon.Fonts:Initialize()
            end
        elseif arg1 == "TellMeWhen" then
            if addon.TellMeWhen then
                addon.TellMeWhen:Initialize()
            end
        elseif arg1 == "KnowledgeBiggins" then
            if addon.ActionBars then
                addon.ActionBars:SkinKnowledgeBiggins()
            end
        end

        -- Re-apply typography when Load-On-Demand Blizzard addons load (e.g. Blizzard_ObjectiveTracker)
        if addon.Fonts and UIBigginsDB and UIBigginsDB.fontChoice and UIBigginsDB.fontChoice ~= "default" then
            addon.Fonts:ApplyFont(UIBigginsDB.fontChoice)
        end
    elseif event == "PLAYER_LOGIN" then
        if addon.Fonts then
            addon.Fonts:Initialize()
        end
        if addon.ActionBars then
            addon.ActionBars:Initialize()
            addon.ActionBars:SkinKnowledgeBiggins()
        end
        if addon.TellMeWhen then
            addon.TellMeWhen:Initialize()
        end
        addon:CreateSettingsPanel()
    elseif event == "PLAYER_ENTERING_WORLD" then
        if addon.Fonts then
            addon.Fonts:Initialize()
        end
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

-- ==============================================================================
-- SLASH COMMANDS
-- ==============================================================================

SLASH_UIBIGGINS1 = "/uibiggins"
SlashCmdList["UIBIGGINS"] = function(msg)
    local raw = string.gsub(msg or "", "^%s*(.-)%s*$", "%1")
    local cmd, arg1 = string.match(raw, "^(%S+)%s*(.*)$")
    cmd = string.lower(cmd or raw)

    if cmd == "?" or cmd == "help" then
        print("|cFFFFD100UI Biggins|r v" .. addon.version .. " commands:")
        print("  |cFFFFD100/uibiggins|r - Open settings panel")
        print("  |cFFFFD100/uibiggins font <default|roboto|firasans|oxanium|sharetech>|r - Set global UI typography")
        print("  |cFFFFD100/uibiggins opacity <0-100>|r - Set TellMeWhen status bar background opacity")
        print("  |cFFFFD100/uibiggins ?|r or |cFFFFD100/uibiggins help|r - Show available commands")
        return
    end

    if cmd == "font" then
        local choice = string.lower(string.gsub(arg1 or "", "^%s*(.-)%s*$", "%1"))
        local targetInfo
        if addon.FontRegistry then
            for _, item in ipairs(addon.FontRegistry) do
                if item.id == choice then
                    targetInfo = item
                    break
                end
            end
        end

        if targetInfo then
            if not UIBigginsDB then UIBigginsDB = {} end
            UIBigginsDB.fontChoice = choice
            if choice ~= "default" and addon.Fonts and addon.Fonts.ApplyFont then
                addon.Fonts:ApplyFont(choice)
            end
            if addon.settingsPanel and addon.settingsPanel.fontDropdown and addon.settingsPanel.fontDropdown.SetDefaultText then
                addon.settingsPanel.fontDropdown:SetDefaultText(targetInfo.name)
            end
            if choice == "default" then
                print("|cFFFFD100UI Biggins:|r Font replacement |cFFFFD100disabled|r (Blizzard Default). Type |cFFFFD100/reload|r to restore stock fonts.")
            else
                print("|cFFFFD100UI Biggins:|r Global UI font set to |cFFFFD100" .. targetInfo.name .. "|r. (A UI reload is recommended for complete redraw).")
            end
        else
            local list = {}
            if addon.FontRegistry then
                for _, item in ipairs(addon.FontRegistry) do
                    table.insert(list, item.id)
                end
            end
            local cur = (UIBigginsDB and UIBigginsDB.fontChoice) or "default"
            print("|cFFFFD100UI Biggins:|r Current UI font is |cFFFFD100" .. cur .. "|r. Available: |cFFFFD100" .. table.concat(list, ", ") .. "|r.")
        end
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
