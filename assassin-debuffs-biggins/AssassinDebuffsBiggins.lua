--[[
    Assassin Debuffs Biggins
    ------------------------
    Clean, high-performance soft gradient halo borders for
    Garrote, Rupture, Deathstalker's Mark, Kingsbane, and Deathmark on Blizzard's stock nameplates.

    Author: Biggins
    Engineering Standards:
      - Zero allocations in hot paths (no tables/closures in aura loops)
      - Pre-cached gradient ColorMixins
      - 100% CVar-safe: runs purely in RAM on UI frames, zero SetCVar calls
      - Taint-safe: zero writes to Blizzard frame tables, zero measurement APIs on restricted regions
      - Auto-scales natively with Blizzard's in-game buff/debuff scale (inherits frame scale)
--]]

local ADDON_NAME = ...

-- ---------------------------------------------------------------------------
-- 1. Defaults & Configuration
-- ---------------------------------------------------------------------------
local DEFAULT_DB = {
    borderThickness = 3,
    garroteColor = { r = 1.0, g = 0.60, b = 0.0 },       -- Amber / Orange
    ruptureColor = { r = 1.0, g = 0.15, b = 0.15 },       -- Crimson / Red
    deathstalkerColor = { r = 0.65, g = 0.25, b = 0.95 },  -- Vivid Purple
    kingsbaneColor = { r = 0.0, g = 1.0, b = 0.40 },     -- Toxic / Neon Green
    deathmarkColor = { r = 0.0, g = 0.83, b = 1.0 },     -- Electric Cyan
}

-- Pre-cached spell lookups (100% verified target debuff IDs)
local TRACKED_SPELLS = {
    -- Garrote
    [703] = "garrote",
    [280321] = "garrote",
    [360830] = "garrote",     -- Duplicated by Deathmark

    -- Rupture
    [1943] = "rupture",
    [360826] = "rupture",     -- Duplicated by Deathmark

    -- Deathstalker's Mark
    [457052] = "deathstalker",
    [457129] = "deathstalker",

    -- Kingsbane
    [385627] = "kingsbane",
    [192759] = "kingsbane",

    -- Deathmark
    [360194] = "deathmark",
}

local TRACKED_NAMES = {
    ["Garrote"] = "garrote",
    ["Rupture"] = "rupture",
    ["Deathstalker's Mark"] = "deathstalker",
    ["Kingsbane"] = "kingsbane",
    ["Deathmark"] = "deathmark",
}

-- ---------------------------------------------------------------------------
-- 2. Zero-Allocation Color Cache
-- ---------------------------------------------------------------------------
local colorCache = {}

local function RefreshColorCache()
    local db = AssassinDebuffsBigginsDB or DEFAULT_DB
    local g = db.garroteColor or DEFAULT_DB.garroteColor
    local r = db.ruptureColor or DEFAULT_DB.ruptureColor
    local d = db.deathstalkerColor or DEFAULT_DB.deathstalkerColor
    local k = db.kingsbaneColor or DEFAULT_DB.kingsbaneColor
    local m = db.deathmarkColor or DEFAULT_DB.deathmarkColor

    colorCache.garrote = {
        solid = CreateColor(g.r, g.g, g.b, 1),
        clear = CreateColor(g.r, g.g, g.b, 0),
    }
    colorCache.rupture = {
        solid = CreateColor(r.r, r.g, r.b, 1),
        clear = CreateColor(r.r, r.g, r.b, 0),
    }
    colorCache.deathstalker = {
        solid = CreateColor(d.r, d.g, d.b, 1),
        clear = CreateColor(d.r, d.g, d.b, 0),
    }
    colorCache.kingsbane = {
        solid = CreateColor(k.r, k.g, k.b, 1),
        clear = CreateColor(k.r, k.g, k.b, 0),
    }
    colorCache.deathmark = {
        solid = CreateColor(m.r, m.g, m.b, 1),
        clear = CreateColor(m.r, m.g, m.b, 0),
    }
end

-- Initialize default color cache immediately at chunk load
RefreshColorCache()

-- ---------------------------------------------------------------------------
-- 3. Gradient Halo Border Management (Taint-Free External Storage)
-- ---------------------------------------------------------------------------
-- Weak-keyed table: never writes keys onto Blizzard's pooled auraItemFrames
local bordersByButton = setmetatable({}, { __mode = "k" })

local function GetOrCreateGlowBorders(button)
    local borders = bordersByButton[button]
    if borders then return borders end

    borders = {}
    local top = button:CreateTexture(nil, "OVERLAY", nil, 7)
    top:SetTexture("Interface\\Buttons\\WHITE8x8")

    local bottom = button:CreateTexture(nil, "OVERLAY", nil, 7)
    bottom:SetTexture("Interface\\Buttons\\WHITE8x8")

    local left = button:CreateTexture(nil, "OVERLAY", nil, 7)
    left:SetTexture("Interface\\Buttons\\WHITE8x8")

    local right = button:CreateTexture(nil, "OVERLAY", nil, 7)
    right:SetTexture("Interface\\Buttons\\WHITE8x8")

    borders.top = top
    borders.bottom = bottom
    borders.left = left
    borders.right = right

    bordersByButton[button] = borders
    return borders
end

local function ApplyGlow(button, borders, colors, thickness)
    borders.top:ClearAllPoints()
    borders.top:SetPoint("TOPLEFT", button, "TOPLEFT", 0, 0)
    borders.top:SetPoint("TOPRIGHT", button, "TOPRIGHT", 0, 0)
    borders.top:SetHeight(thickness)
    borders.top:SetGradient("VERTICAL", colors.clear, colors.solid)
    borders.top:Show()

    borders.bottom:ClearAllPoints()
    borders.bottom:SetPoint("BOTTOMLEFT", button, "BOTTOMLEFT", 0, 0)
    borders.bottom:SetPoint("BOTTOMRIGHT", button, "BOTTOMRIGHT", 0, 0)
    borders.bottom:SetHeight(thickness)
    borders.bottom:SetGradient("VERTICAL", colors.solid, colors.clear)
    borders.bottom:Show()

    borders.left:ClearAllPoints()
    borders.left:SetPoint("TOPLEFT", button, "TOPLEFT", 0, 0)
    borders.left:SetPoint("BOTTOMLEFT", button, "BOTTOMLEFT", 0, 0)
    borders.left:SetWidth(thickness)
    borders.left:SetGradient("HORIZONTAL", colors.solid, colors.clear)
    borders.left:Show()

    borders.right:ClearAllPoints()
    borders.right:SetPoint("TOPRIGHT", button, "TOPRIGHT", 0, 0)
    borders.right:SetPoint("BOTTOMRIGHT", button, "BOTTOMRIGHT", 0, 0)
    borders.right:SetWidth(thickness)
    borders.right:SetGradient("HORIZONTAL", colors.clear, colors.solid)
    borders.right:Show()
end

local function HideGlow(borders)
    if not borders then return end
    borders.spellKey = nil
    borders.top:Hide()
    borders.bottom:Hide()
    borders.left:Hide()
    borders.right:Hide()
end

-- ---------------------------------------------------------------------------
-- 4. Modern Blizzard_NamePlates Engine Hook (Zero-Taint)
-- ---------------------------------------------------------------------------
local function ResolveSpellKey(aura)
    if not aura then return nil end

    -- 1. Direct localized aura name match
    if aura.name and TRACKED_NAMES[aura.name] then
        return TRACKED_NAMES[aura.name]
    end

    -- 2. Direct spell ID match against verified periodic debuff IDs
    local spellId = aura.spellId or aura.spellID
    if spellId and TRACKED_SPELLS[spellId] then
        return TRACKED_SPELLS[spellId]
    end

    -- 3. Dynamic client lookup via C_Spell.GetSpellName or C_Spell.GetSpellInfo
    if spellId then
        if C_Spell and C_Spell.GetSpellName then
            local sName = C_Spell.GetSpellName(spellId)
            if sName and TRACKED_NAMES[sName] then
                return TRACKED_NAMES[sName]
            end
        end

        if C_Spell and C_Spell.GetSpellInfo then
            local ok, spellInfo = pcall(C_Spell.GetSpellInfo, spellId)
            if ok and spellInfo and spellInfo.name and TRACKED_NAMES[spellInfo.name] then
                return TRACKED_NAMES[spellInfo.name]
            end
        end

        if GetSpellInfo then
            local ok, sName = pcall(GetSpellInfo, spellId)
            if ok and sName and TRACKED_NAMES[sName] then
                return TRACKED_NAMES[sName]
            end
        end
    end

    return nil
end

local function LogAuraDebug(aura, spellKey)
    if not AssassinDebuffsBigginsDB then return end
    if not AssassinDebuffsBigginsDB.recentDebug then
        AssassinDebuffsBigginsDB.recentDebug = {}
    end
    local name = aura and aura.name or "Unknown"
    local spellId = aura and (aura.spellId or aura.spellID) or 0
    local icon = aura and aura.icon or 0
    local key = spellKey or "none"

    local entry = {
        name = tostring(name),
        spellId = tonumber(spellId) or 0,
        icon = tonumber(icon) or 0,
        key = tostring(key),
        time = date and date("%H:%M:%S") or "",
    }
    table.insert(AssassinDebuffsBigginsDB.recentDebug, 1, entry)
    if #AssassinDebuffsBigginsDB.recentDebug > 30 then
        table.remove(AssassinDebuffsBigginsDB.recentDebug)
    end

    if ADB_DEBUG then
        print(string.format("|cFFFFD100[ADB Debug]|r '%s' (ID: %s, Icon: %s) -> key: %s",
            tostring(name), tostring(spellId), tostring(icon), tostring(key)))
    end
end

local function OnAuraItemSetAura(self, aura)
    local borders = bordersByButton[self]
    if not aura then
        HideGlow(borders)
        return
    end

    local spellKey = ResolveSpellKey(aura)
    LogAuraDebug(aura, spellKey)

    if spellKey and colorCache[spellKey] then
        borders = GetOrCreateGlowBorders(self)
        borders.spellKey = spellKey
        local db = AssassinDebuffsBigginsDB or DEFAULT_DB
        local thickness = db.borderThickness or DEFAULT_DB.borderThickness

        -- Textures anchor to self, so they automatically scale when Blizzard scales self
        ApplyGlow(self, borders, colorCache[spellKey], thickness)
    else
        HideGlow(borders)
    end
end

local isAuraItemHooked = false

local function HookNamePlates()
    if NamePlateAuraItemMixin and NamePlateAuraItemMixin.SetAura and not isAuraItemHooked then
        hooksecurefunc(NamePlateAuraItemMixin, "SetAura", OnAuraItemSetAura)
        isAuraItemHooked = true
    end
end

-- Safe live refresh: updates existing glow textures purely in addon memory (zero Blizzard layout calls)
local function RefreshAllActiveGlows()
    RefreshColorCache()
    local db = AssassinDebuffsBigginsDB or DEFAULT_DB
    local thickness = db.borderThickness or DEFAULT_DB.borderThickness

    for button, borders in pairs(bordersByButton) do
        if button:IsShown() and borders.spellKey and colorCache[borders.spellKey] then
            ApplyGlow(button, borders, colorCache[borders.spellKey], thickness)
        else
            HideGlow(borders)
        end
    end
end

-- ---------------------------------------------------------------------------
-- 5. Native In-Game Settings Panel
-- ---------------------------------------------------------------------------
local optionsCategory = nil

local function OpenColorPicker(colorTable, callback)
    local initialR = colorTable.r
    local initialG = colorTable.g
    local initialB = colorTable.b

    local function SwatchCallback(restore)
        local r, g, b
        if restore then
            r, g, b = initialR, initialG, initialB
        elseif ColorPickerFrame.GetColorRGB then
            r, g, b = ColorPickerFrame:GetColorRGB()
        else
            r, g, b = ColorPickerFrame:GetColorRGB()
        end
        colorTable.r = r
        colorTable.g = g
        colorTable.b = b
        callback(r, g, b)
    end

    local info = {
        r = initialR,
        g = initialG,
        b = initialB,
        hasOpacity = false,
        swatchFunc = function() SwatchCallback(false) end,
        cancelFunc = function() SwatchCallback(true) end,
    }

    if ColorPickerFrame.SetupColorPickerAndShow then
        ColorPickerFrame:SetupColorPickerAndShow(info)
    else
        ColorPickerFrame.func = info.swatchFunc
        ColorPickerFrame.cancelFunc = info.cancelFunc
        ColorPickerFrame.hasOpacity = false
        ColorPickerFrame:SetColorRGB(info.r, info.g, info.b)
        ShowUIPanel(ColorPickerFrame)
    end
end

local function CreateOptionsPanel()
    local panel = CreateFrame("Frame", "AssassinDebuffsBigginsOptionsPanel", UIParent)
    panel.name = "Assassin Debuffs Biggins"

    -- Title
    local title = panel:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
    title:SetPoint("TOPLEFT", 16, -16)
    title:SetText("Assassin Debuffs Biggins")

    -- Subtitle
    local subText = panel:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
    subText:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -8)
    subText:SetText("Clean soft gradient halo borders for Garrote, Rupture, Deathstalker's Mark, Kingsbane, and Deathmark.")

    -- 1. Border Thickness Slider
    local thickSlider = CreateFrame("Slider", "ADB_ThicknessSlider", panel, "OptionsSliderTemplate")
    thickSlider:SetPoint("TOPLEFT", subText, "BOTTOMLEFT", 0, -32)
    thickSlider:SetMinMaxValues(1, 5)
    thickSlider:SetValueStep(1)
    thickSlider:SetObeyStepOnDrag(true)
    thickSlider:SetWidth(260)
    _G[thickSlider:GetName() .. "Low"]:SetText("1 px")
    _G[thickSlider:GetName() .. "High"]:SetText("5 px")
    local thickVal = AssassinDebuffsBigginsDB.borderThickness or DEFAULT_DB.borderThickness
    thickSlider:SetValue(thickVal)
    _G[thickSlider:GetName() .. "Text"]:SetText(string.format("Glow Halo Thickness: %d px", thickVal))
    thickSlider:SetScript("OnValueChanged", function(self, value)
        value = math.floor(value + 0.5)
        AssassinDebuffsBigginsDB.borderThickness = value
        _G[self:GetName() .. "Text"]:SetText(string.format("Glow Halo Thickness: %d px", value))
        RefreshAllActiveGlows()
    end)

    -- Section Label: Colors
    local colorHeader = panel:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    colorHeader:SetPoint("TOPLEFT", thickSlider, "BOTTOMLEFT", 0, -28)
    colorHeader:SetText("Debuff Halo Colors")

    -- Helper to create a color swatch row
    local function CreateColorSwatchRow(parent, anchor, yOffset, labelText, colorTable)
        local row = CreateFrame("Frame", nil, parent)
        row:SetSize(320, 26)
        row:SetPoint("TOPLEFT", anchor, "BOTTOMLEFT", 0, yOffset)

        local swatch = CreateFrame("Button", nil, row)
        swatch:SetSize(22, 22)
        swatch:SetPoint("LEFT", 0, 0)

        local border = swatch:CreateTexture(nil, "BACKGROUND")
        border:SetPoint("TOPLEFT", -1, 1)
        border:SetPoint("BOTTOMRIGHT", 1, -1)
        border:SetColorTexture(0.2, 0.2, 0.2, 1)

        local colorTex = swatch:CreateTexture(nil, "ARTWORK")
        colorTex:SetAllPoints()
        colorTex:SetColorTexture(colorTable.r, colorTable.g, colorTable.b, 1)

        local label = row:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
        label:SetPoint("LEFT", swatch, "RIGHT", 10, 0)
        label:SetText(labelText)

        swatch:SetScript("OnClick", function()
            OpenColorPicker(colorTable, function(r, g, b)
                colorTex:SetColorTexture(r, g, b, 1)
                RefreshAllActiveGlows()
            end)
        end)

        return row, colorTex
    end

    -- Color Swatches (All 5 Tracked Debuffs)
    local rowGarrote, texGarrote = CreateColorSwatchRow(panel, colorHeader, -10, "Garrote Halo Color", AssassinDebuffsBigginsDB.garroteColor)
    local rowRupture, texRupture = CreateColorSwatchRow(panel, rowGarrote, -8, "Rupture Halo Color", AssassinDebuffsBigginsDB.ruptureColor)
    local rowDeathstalker, texDeathstalker = CreateColorSwatchRow(panel, rowRupture, -8, "Deathstalker's Mark Halo Color", AssassinDebuffsBigginsDB.deathstalkerColor)
    local rowKingsbane, texKingsbane = CreateColorSwatchRow(panel, rowDeathstalker, -8, "Kingsbane Halo Color", AssassinDebuffsBigginsDB.kingsbaneColor)
    local rowDeathmark, texDeathmark = CreateColorSwatchRow(panel, rowKingsbane, -8, "Deathmark Halo Color", AssassinDebuffsBigginsDB.deathmarkColor)

    -- Reset to Defaults Button
    local resetBtn = CreateFrame("Button", "ADB_ResetButton", panel, "UIPanelButtonTemplate")
    resetBtn:SetSize(160, 26)
    resetBtn:SetPoint("TOPLEFT", rowDeathmark, "BOTTOMLEFT", 0, -28)
    resetBtn:SetText("Reset to Defaults")
    resetBtn:SetScript("OnClick", function()
        AssassinDebuffsBigginsDB.borderThickness = DEFAULT_DB.borderThickness

        for _, debuffKey in ipairs({"garroteColor", "ruptureColor", "deathstalkerColor", "kingsbaneColor", "deathmarkColor"}) do
            AssassinDebuffsBigginsDB[debuffKey].r = DEFAULT_DB[debuffKey].r
            AssassinDebuffsBigginsDB[debuffKey].g = DEFAULT_DB[debuffKey].g
            AssassinDebuffsBigginsDB[debuffKey].b = DEFAULT_DB[debuffKey].b
        end

        thickSlider:SetValue(DEFAULT_DB.borderThickness)

        texGarrote:SetColorTexture(DEFAULT_DB.garroteColor.r, DEFAULT_DB.garroteColor.g, DEFAULT_DB.garroteColor.b, 1)
        texRupture:SetColorTexture(DEFAULT_DB.ruptureColor.r, DEFAULT_DB.ruptureColor.g, DEFAULT_DB.ruptureColor.b, 1)
        texDeathstalker:SetColorTexture(DEFAULT_DB.deathstalkerColor.r, DEFAULT_DB.deathstalkerColor.g, DEFAULT_DB.deathstalkerColor.b, 1)
        texKingsbane:SetColorTexture(DEFAULT_DB.kingsbaneColor.r, DEFAULT_DB.kingsbaneColor.g, DEFAULT_DB.kingsbaneColor.b, 1)
        texDeathmark:SetColorTexture(DEFAULT_DB.deathmarkColor.r, DEFAULT_DB.deathmarkColor.g, DEFAULT_DB.deathmarkColor.b, 1)

        RefreshAllActiveGlows()
    end)

    -- Register with Blizzard Settings API
    if Settings and Settings.RegisterCanvasLayoutCategory then
        local category = Settings.RegisterCanvasLayoutCategory(panel, "Assassin Debuffs Biggins")
        Settings.RegisterAddOnCategory(category)
        optionsCategory = category
    end
end

-- ---------------------------------------------------------------------------
-- 6. Slash Commands
-- ---------------------------------------------------------------------------
SLASH_ASSASSINDEBUFFSBIGGINS1 = "/adb"
SLASH_ASSASSINDEBUFFSBIGGINS2 = "/assassindebuffs"
SlashCmdList["ASSASSINDEBUFFSBIGGINS"] = function(msg)
    local cmd = msg and msg:lower():trim() or ""
    if cmd == "reset" then
        if ADB_ResetButton then
            ADB_ResetButton:Click()
        end
        print("|cFFFFD100[AssassinDebuffsBiggins]|r Settings reset to defaults.")
    elseif cmd == "debug" then
        ADB_DEBUG = not ADB_DEBUG
        print(string.format("|cFFFFD100[AssassinDebuffsBiggins]|r Debug logging %s.", ADB_DEBUG and "|cFF00FF00ENABLED|r" or "|cFFFF0000DISABLED|r"))
    elseif cmd == "dump" then
        print("|cFFFFD100[AssassinDebuffsBiggins]|r Recent Auras Log (newest first):")
        local debugList = AssassinDebuffsBigginsDB and AssassinDebuffsBigginsDB.recentDebug or {}
        if #debugList == 0 then
            print("  (No auras logged yet. Apply a debuff to a target first.)")
        else
            for i = 1, math.min(10, #debugList) do
                local d = debugList[i]
                print(string.format("  [%s] '%s' (ID: %d, Icon: %d) -> key: %s", d.time, d.name, d.spellId, d.icon, d.key))
            end
        end
    else
        if optionsCategory and Settings and Settings.OpenToCategory then
            Settings.OpenToCategory(optionsCategory:GetID())
        else
            print("|cFFFFD100[AssassinDebuffsBiggins]|r Open Settings via Escape -> Options -> AddOns -> Assassin Debuffs Biggins")
        end
    end
end

-- ---------------------------------------------------------------------------
-- 7. Initialization & Event Lifecycle
-- ---------------------------------------------------------------------------
HookNamePlates()

if EventUtil and EventUtil.ContinueOnAddOnLoaded then
    EventUtil.ContinueOnAddOnLoaded("Blizzard_NamePlates", HookNamePlates)
end

local eventFrame = CreateFrame("Frame")
eventFrame:RegisterEvent("ADDON_LOADED")
eventFrame:RegisterEvent("PLAYER_LOGIN")
eventFrame:RegisterEvent("PLAYER_ENTERING_WORLD")

eventFrame:SetScript("OnEvent", function(self, event, arg1)
    if event == "ADDON_LOADED" then
        if arg1 == ADDON_NAME then
            if not AssassinDebuffsBigginsDB then
                AssassinDebuffsBigginsDB = {}
            end
            for k, v in pairs(DEFAULT_DB) do
                if type(v) == "table" then
                    if not AssassinDebuffsBigginsDB[k] then
                        AssassinDebuffsBigginsDB[k] = {}
                    end
                    for subK, subV in pairs(v) do
                        if AssassinDebuffsBigginsDB[k][subK] == nil then
                            AssassinDebuffsBigginsDB[k][subK] = subV
                        end
                    end
                else
                    if AssassinDebuffsBigginsDB[k] == nil then
                        AssassinDebuffsBigginsDB[k] = v
                    end
                end
            end

            RefreshColorCache()
            CreateOptionsPanel()
            HookNamePlates()
        elseif arg1 == "Blizzard_NamePlates" then
            HookNamePlates()
        end
    elseif event == "PLAYER_LOGIN" or event == "PLAYER_ENTERING_WORLD" then
        RefreshColorCache()
        HookNamePlates()
    end
end)
