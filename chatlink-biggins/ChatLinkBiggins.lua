--[[ ==============================================================================
    ChatLink Biggins v1.2.2 - Clickable Web Hyperlinks & Player Hover Tooltips
    ------------------------------------------------------------------------------
    Author: Biggins (US-Whisperwind)
    Compatibility: World of Warcraft: Midnight / The War Within (Patch 11.x - 12.x)

    ARCHITECTURAL OVERVIEW:
    1. Single-Pattern Protocol Isolation: Matches standard web protocols
       (https:// and http://) via a single pass, eliminating multi-pattern
       collisions, false positives, and infinite chat loops.
    2. Sentence Punctuation Stripping: Safely trims trailing sentence punctuation
       (.,;:!?)[]'") so URLs copied to the clipboard remain valid.
    3. Draggable Blizzard Factory Dialog: Dedicated frame styled with authentic
       Blizzard dialog textures, freely draggable with position memory and reset.
    4. Zero-Taint Event Filtering: Registered through ChatFrame_AddMessageEventFilter
       and native SetItemRef hooks with same-frame click de-duplication.
    5. Native Player Hover Tooltips:
       - Tier 1 (Group / Target / Proximity): Resolves live Unit Token and invokes
         GameTooltip:SetUnit(), automatically triggering unit tooltip enhancers
         like MouseOverTooltip for item level, spec, mount, and class borders.
       - Tier 2 (Remote / Cross-Zone): Queries C_PlayerInfo.GetPlayerInfoByGUID()
         to render a stock Blizzard-styled identity card (Class, Race, Realm, Guild).
    6. Modular Architecture:
       - Core/Links.lua: Single-pattern URL isolation, sender caching, and chat filter.
       - Modules/Dialog.lua: Draggable Blizzard Factory copy dialog and position memory.
       - Modules/Tooltips.lua: Player name hover tooltips and chat frame hooks.
       - Core/Options.lua: Blizzard Settings canvas UI and feature toggles.
       - ChatLinkBiggins.lua: Lifecycle initialization and /chatlinkb slash dispatcher.
============================================================================== ]]--

local addonName, addon = ...
_G["ChatLinkBiggins"] = addon
addon.version = "1.2.2"

-- Cache global functions
local CreateFrame = CreateFrame
local Settings    = Settings
local pairs       = pairs
local string      = string
local print       = print
local strtrim     = strtrim
local _G          = _G
local DEFAULT_CHAT_FRAME = DEFAULT_CHAT_FRAME

-- Configuration Defaults
addon.defaults = {
    enabled        = true,
    playerTooltips = true,
    showBrackets   = true,
    announce       = true,
    posPoint       = "CENTER",
    posRelPoint    = "CENTER",
    posX           = 0,
    posY           = 100,
}

-- Print formatted addon message
function addon:PrintMsg(msg)
    if DEFAULT_CHAT_FRAME then
        DEFAULT_CHAT_FRAME:AddMessage("|cFFFFD100ChatLink Biggins:|r " .. msg)
    else
        print("|cFFFFD100ChatLink Biggins:|r " .. msg)
    end
end

-- ==============================================================================
-- SLASH COMMANDS (/chatlinkb)
-- ==============================================================================

SLASH_CHATLINKBIGGINS1 = "/chatlinkb"

SlashCmdList["CHATLINKBIGGINS"] = function(msg)
    msg = string.lower(strtrim(msg or ""))
    local db = ChatLinkBigginsDB or addon.defaults

    if msg == "" or msg == "options" or msg == "config" then
        if addon.categoryID and Settings and Settings.OpenToCategory then
            Settings.OpenToCategory(addon.categoryID)
        else
            addon:PrintMsg("Open Options -> AddOns -> Biggins AddOns -> ChatLink.")
        end
    elseif msg == "toggle" then
        db.enabled = not db.enabled
        if addon.settingsPanel and addon.settingsPanel.RefreshControls then
            addon.settingsPanel.RefreshControls()
        end
        addon:PrintMsg(db.enabled and "ChatLink |cFF00FF00enabled|r." or "ChatLink |cFFFF0000disabled|r.")
    elseif msg == "tooltips" or msg == "hover" then
        db.playerTooltips = not db.playerTooltips
        if addon.settingsPanel and addon.settingsPanel.RefreshControls then
            addon.settingsPanel.RefreshControls()
        end
        addon:PrintMsg("Player hover tooltips " .. (db.playerTooltips and "|cFF00FF00enabled|r." or "|cFFFF0000disabled|r."))
    elseif msg == "brackets" then
        db.showBrackets = not db.showBrackets
        if addon.settingsPanel and addon.settingsPanel.RefreshControls then
            addon.settingsPanel.RefreshControls()
        end
        addon:PrintMsg("Link brackets " .. (db.showBrackets and "|cFF00FF00enabled|r." or "|cFFFF0000disabled|r."))
    elseif msg == "reset" then
        addon:ResetDialogPosition()
        addon:PrintMsg("Popup position reset to center.")
    elseif msg == "status" then
        addon:PrintMsg("Status: " .. (db.enabled and "|cFF00FF00Enabled|r" or "|cFFFF0000Disabled|r")
            .. " | Tooltips: " .. (db.playerTooltips and "|cFF00FF00ON|r" or "|cFFFF0000OFF|r")
            .. " | Brackets: " .. (db.showBrackets and "|cFF00FF00ON|r" or "|cFFFF0000OFF|r")
            .. " | Echo: " .. (db.announce and "|cFF00FF00ON|r" or "|cFFFF0000OFF|r")
            .. " | Position: (" .. (db.posX or 0) .. ", " .. (db.posY or 100) .. ")")
    elseif msg == "defaults" then
        for k, v in pairs(addon.defaults) do
            db[k] = v
        end
        addon:ResetDialogPosition()
        if addon.settingsPanel and addon.settingsPanel.RefreshControls then
            addon.settingsPanel.RefreshControls()
        end
        addon:PrintMsg("Settings reset to defaults.")
    elseif msg == "help" or msg == "?" then
        addon:PrintMsg("Commands:")
        print("  |cFFFFD100/chatlinkb|r - Open settings panel")
        print("  |cFFFFD100/chatlinkb toggle|r - Toggle URL detection on/off")
        print("  |cFFFFD100/chatlinkb tooltips|r - Toggle player hover tooltips")
        print("  |cFFFFD100/chatlinkb brackets|r - Toggle visual [brackets] around links")
        print("  |cFFFFD100/chatlinkb reset|r - Reset copy dialog position to center")
        print("  |cFFFFD100/chatlinkb status|r - Display current configuration")
        print("  |cFFFFD100/chatlinkb defaults|r - Reset all settings to defaults")
        print("  |cFFFFD100/chatlinkb help|r or |cFFFFD100/chatlinkb ?|r - Show this list of commands")
    else
        addon:PrintMsg("Unknown command '|cFFFFD100" .. msg .. "|r'. Type |cFFFFD100/chatlinkb help|r for available commands.")
    end
end

-- ==============================================================================
-- INITIALIZATION LIFECYCLE
-- ==============================================================================

local initFrame = CreateFrame("Frame")
initFrame:RegisterEvent("ADDON_LOADED")
initFrame:RegisterEvent("PLAYER_LOGIN")
initFrame:SetScript("OnEvent", function(self, event, arg1)
    if event == "ADDON_LOADED" then
        if arg1 ~= addonName then return end

        -- Initialize SavedVariables
        _G["ChatLinkBigginsDB"] = _G["ChatLinkBigginsDB"] or {}
        local db = _G["ChatLinkBigginsDB"]

        for k, v in pairs(addon.defaults) do
            if db[k] == nil then
                db[k] = v
            end
        end

        addon:CreateSettingsUI()
        self:UnregisterEvent("ADDON_LOADED")
    elseif event == "PLAYER_LOGIN" then
        addon:HookAllChatFrames()
        self:UnregisterEvent("PLAYER_LOGIN")
    end
end)
