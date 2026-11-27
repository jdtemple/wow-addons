--[[ ==============================================================================
    UI Biggins - Typography & Global Font Management Module
    ------------------------------------------------------------------------------
    Author: Biggins (US-Whisperwind)
    Compatibility: World of Warcraft: Midnight & The War Within

    Provides clean, lean, zero-allocation font replacement across Blizzard UI
    elements while preserving native font scale, outlines, and shadow offsets.
    Selecting Blizzard Default completely disables font replacement.
============================================================================== ]]--

local addonName, addon = ...
local Fonts = {}
addon.Fonts = Fonts

-- Cache Lua / WoW globals
local _G       = _G
local ipairs   = ipairs
local type     = type
local pcall    = pcall

-- ==============================================================================
-- FONT REGISTRY
-- Drop-in architecture: add future .ttf files to Fonts/ and declare them below.
-- ==============================================================================

addon.FontRegistry = {
    {
        id   = "default",
        name = "Blizzard Default",
        path = nil,
    },
    {
        id   = "roboto",
        name = "Roboto",
        path = "Interface\\AddOns\\UIBiggins\\Fonts\\Roboto-Medium.ttf",
    },
    {
        id   = "firasans",
        name = "Fira Sans",
        path = "Interface\\AddOns\\UIBiggins\\Fonts\\FiraSans-Medium.ttf",
    },
    {
        id   = "oxanium",
        name = "Oxanium",
        path = "Interface\\AddOns\\UIBiggins\\Fonts\\Oxanium-Medium.ttf",
    },
    {
        id   = "sharetech",
        name = "Share Tech",
        path = "Interface\\AddOns\\UIBiggins\\Fonts\\ShareTech-Regular.ttf",
    },
}

-- Registry lookup helpers
function Fonts:GetFontList()
    return addon.FontRegistry
end

function Fonts:GetFontById(id)
    if not id then return addon.FontRegistry[1] end
    if id == "bitcount" then id = "firasans" end
    for _, item in ipairs(addon.FontRegistry) do
        if item.id == id then
            return item
        end
    end
    return addon.FontRegistry[1]
end

-- ==============================================================================
-- BLIZZARD FONT OBJECTS REPOSITORY
-- Comprehensive collection of core UI, System, Game, Number, Quest, and Chat fonts.
-- ==============================================================================

Fonts.targetFonts = {
    -- Core System Fonts
    "SystemFont_Tiny2",
    "SystemFont_Tiny",
    "SystemFont_Shadow_Small",
    "SystemFont_Small",
    "SystemFont_Small2",
    "SystemFont_Shadow_Small2",
    "SystemFont_Med1",
    "SystemFont_Med2",
    "SystemFont_Med3",
    "SystemFont_Shadow_Med1",
    "SystemFont_Shadow_Med2",
    "SystemFont_Shadow_Med3",
    "SystemFont_Shadow_Med1_Outline",
    "SystemFont_Large",
    "SystemFont_Shadow_Large",
    "SystemFont_Shadow_Large2",
    "SystemFont_Shadow_Large_Outline",
    "SystemFont_Huge1",
    "SystemFont_Huge1_Outline",
    "SystemFont_Huge2",
    "SystemFont_Shadow_Huge1",
    "SystemFont_Shadow_Huge2",
    "SystemFont_Shadow_Huge3",
    "SystemFont_Shadow_Outline_Huge2",
    "SystemFont_Shadow_Outline_Huge3",
    "SystemFont_Shadow_Huge4",
    "SystemFont_Shadow_Outline_Huge4",
    "SystemFont_Outline_Small",
    "SystemFont_Outline",
    "SystemFont_OutlineThick_Huge2",
    "SystemFont_OutlineThick_Huge4",
    "SystemFont_OutlineThick_WTF",

    -- Standard Game Fonts
    "GameFontNormal",
    "GameFontNormalSmall",
    "GameFontNormalMed1",
    "GameFontNormalMed2",
    "GameFontNormalMed3",
    "GameFontNormalLarge",
    "GameFontNormalHuge",
    "GameFontHighlight",
    "GameFontHighlightSmall",
    "GameFontHighlightMed1",
    "GameFontHighlightMed2",
    "GameFontHighlightLarge",
    "GameFontHighlightHuge",
    "GameFontDisable",
    "GameFontDisableSmall",
    "GameFontDisableMed1",
    "GameFontDisableLarge",
    "GameFontGreen",
    "GameFontGreenSmall",
    "GameFontGreenLarge",
    "GameFontRed",
    "GameFontRedSmall",
    "GameFontRedLarge",
    "GameFontWhite",
    "GameFontWhiteSmall",
    "GameFontWhiteMedium",
    "GameFont_Gigantic",

    -- Numeric Game Fonts (Scale-specific)
    "Game10Font_o1",
    "Game11Font",
    "Game11Font_o1",
    "Game12Font",
    "Game12Font_o1",
    "Game13Font",
    "Game13Font_o1",
    "Game13FontShadow",
    "Game15Font",
    "Game15Font_o1",
    "Game16Font",
    "Game18Font",
    "Game20Font",
    "Game24Font",
    "Game27Font",
    "Game30Font",
    "Game32Font",
    "Game36Font",
    "Game42Font",
    "Game46Font",
    "Game48Font",
    "Game48FontShadow",
    "Game60Font",
    "Game72Font",
    "Game120Font",

    -- Action Bar & Telemetry Number Fonts
    "NumberFont_Shadow_Tiny",
    "NumberFont_Shadow_Small",
    "NumberFont_Shadow_Med",
    "NumberFont_Normal_Med",
    "NumberFont_Outline_Med",
    "NumberFont_Outline_Large",
    "NumberFont_Outline_Huge",
    "NumberFont_GameNormal",
    "NumberFont_OutlineThick_Mono_Small",
    "Number11Font",
    "Number12Font",
    "Number12Font_o1",
    "Number13Font",
    "Number15Font",
    "Number18Font",
    "PriceFont",

    -- Tooltips & Status Bars
    "GameTooltipHeader",
    "Tooltip_Med",
    "Tooltip_Small",
    "TextStatusBarText",
    "TextStatusBarTextLarge",

    -- Objective Tracker & Quest Watcher
    "ObjectiveFont",
    "ObjectiveTrackerLineFont",
    "ObjectiveTrackerHeaderFont",
    "ObjectiveTrackerFont12",
    "ObjectiveTrackerFont13",
    "ObjectiveTrackerFont14",
    "ObjectiveTrackerFont15",
    "ObjectiveTrackerFont16",
    "ObjectiveTrackerFont17",
    "ObjectiveTrackerFont18",
    "ObjectiveTrackerFont19",
    "ObjectiveTrackerFont20",
    "ObjectiveTrackerFont21",
    "ObjectiveTrackerFont22",
    "QuestFontNormalSmall",
    "QuestTitleFontBlackShadow",
    "WorldMapTextFont",
    "ZoneTextFont",
    "SubZoneTextFont",
    "ErrorFont",

    -- Quest, Dialogue, Mail, and Splash
    "QuestFont",
    "QuestTitleFont",
    "QuestFont_Large",
    "QuestFont_Huge",
    "QuestFont_Super_Huge",
    "QuestFont_Super_Huge_Outline",
    "QuestFont_Shadow_Small",
    "QuestFont_Shadow_Huge",
    "QuestFont_Outline_Huge",
    "QuestFont_Enormous",
    "MailFont_Large",
    "SpellFont_Small",
    "InvoiceFont_Med",
    "InvoiceFont_Small",
    "SplashHeaderFont",
    "Fancy12Font",
    "Fancy14Font",
    "Fancy16Font",
    "Fancy18Font",
    "Fancy20Font",
    "Fancy22Font",
    "Fancy24Font",
    "Fancy27Font",
    "Fancy30Font",
    "Fancy32Font",
    "Fancy48Font",
    "DestinyFontMed",
    "DestinyFontLarge",
    "DestinyFontHuge",
    "CoreAbilityFont",

    -- Chat & Social
    "ChatFontNormal",
    "ChatFontSmall",
    "ChatFontLarge",
    "ChatBubbleFont",
    "FriendsFont_Normal",
    "FriendsFont_11",
    "FriendsFont_Small",
    "FriendsFont_Large",
    "FriendsFont_UserText",

    -- Nameplates
    "SystemFont_NamePlate",
    "SystemFont_NamePlateFixed",
    "SystemFont_LargeNamePlate",
    "SystemFont_LargeNamePlateFixed",
    "SystemFont_NamePlateCastBar",
}

-- ==============================================================================
-- APPLICATION ENGINE
-- ==============================================================================

function Fonts:ApplyFont(fontId)
    local info = self:GetFontById(fontId)
    local targetPath = info and info.path

    if not targetPath or info.id == "default" then
        -- Selecting Blizzard Default disables font replacement.
        -- A UI reload restores native Blizzard fonts cleanly without artifacts.
        return
    end

    -- Apply selected custom font while preserving proportional sizes and style flags
    for _, fontName in ipairs(self.targetFonts) do
        local obj = _G[fontName]
        if obj and type(obj) == "table" and obj.GetFont and obj.SetFont then
            local _, size, flags = obj:GetFont()
            if size then
                pcall(obj.SetFont, obj, targetPath, size, flags or "")
            end
        end
    end

    -- Update Blizzard engine string globals
    _G.STANDARD_TEXT_FONT = targetPath
    _G.UNIT_NAME_FONT     = targetPath
    _G.NAMEPLATE_FONT     = targetPath

    -- Refresh ObjectiveTracker if already instantiated
    if _G.ObjectiveTrackerFrame and _G.ObjectiveTrackerFrame.Update then
        pcall(_G.ObjectiveTrackerFrame.Update, _G.ObjectiveTrackerFrame)
    end

    -- Refresh Biggins Suite companion telemetry bars (LazySpeed & Perf)
    if _G.LazySpeedBiggins and _G.LazySpeedBiggins.UpdateLayout then
        pcall(_G.LazySpeedBiggins.UpdateLayout, _G.LazySpeedBiggins)
    end
    local suiteBars = {
        _G.LazySpeedBigginsSpeedBar,
        _G.LazySpeedBigginsVigorBar,
        _G.PerfBigginsFPSBar,
        _G.PerfBigginsMSBar,
        _G.PerfBigginsMemoryBar,
    }
    for _, bar in ipairs(suiteBars) do
        if bar and bar.text and bar.text.SetFont then
            local _, size, flags = bar.text:GetFont()
            pcall(bar.text.SetFont, bar.text, targetPath, size or 12, flags or "OUTLINE")
        end
    end

end

function Fonts:Initialize()
    local choice = (UIBigginsDB and UIBigginsDB.fontChoice) or (addon.DB_DEFAULTS and addon.DB_DEFAULTS.fontChoice) or "default"
    if not choice or choice == "default" then
        -- Font replacement disabled: leave Blizzard default fonts completely untouched
        return
    end
    self:ApplyFont(choice)
end
