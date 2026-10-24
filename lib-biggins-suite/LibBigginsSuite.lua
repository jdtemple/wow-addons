--[[ ==============================================================================
    LibBigginsSuite-1.0 - Embedded Shared Suite Controller for Biggins AddOns
    ------------------------------------------------------------------------------
    Author: Biggins (US-Whisperwind)
    Compatibility: World of Warcraft: Midnight / The War Within (Patch 11.x - 12.x)
============================================================================== ]]--

local MAJOR, MINOR = "LibBigginsSuite-1.0", 1
local Suite = _G["LibBigginsSuite"]
if Suite and Suite.minor and Suite.minor >= MINOR then return end

Suite = Suite or {}
Suite.minor = MINOR
_G["LibBigginsSuite"] = Suite

-- Cache upvalues
local CreateFrame = CreateFrame
local Settings    = Settings
local UIParent    = UIParent

function Suite:GetOrCreateParentCategory(addonDir)
    if self.parentCategory then
        return self.parentCategory
    end

    local parentPanel = CreateFrame("Frame", "BigginsAddOnsParentPanel", UIParent)
    parentPanel.name = "Biggins AddOns"

    -- Title (Blizzard Gold)
    local title = parentPanel:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
    title:SetPoint("TOPLEFT", 16, -16)
    title:SetText("|cFFFFD100Biggins AddOns|r")

    -- Subtitle / Description
    local desc = parentPanel:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
    desc:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -6)
    desc:SetText("High-performance, lightweight World of Warcraft addons with zero Lua garbage generation.")

    -- Suite Logo Texture (Top Right)
    local logo = parentPanel:CreateTexture(nil, "ARTWORK")
    logo:SetPoint("TOPRIGHT", -24, -16)
    logo:SetSize(84, 84)
    logo:SetTexture("Interface\\AddOns\\" .. (addonDir or "AutoJoinBiggins") .. "\\suite-logo.jpg")

    -- Author & Architecture Header
    local authorHeader = parentPanel:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    authorHeader:SetPoint("TOPLEFT", desc, "BOTTOMLEFT", 0, -18)
    authorHeader:SetText("Engineering Philosophy & Standards:")

    local authorInfo = parentPanel:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
    authorInfo:SetPoint("TOPLEFT", authorHeader, "BOTTOMLEFT", 0, -6)
    authorInfo:SetText("Created by |cFFFFD100Biggins|r (US-Whisperwind).\nEvery addon in this suite is built from the ground up for maximum CPU efficiency:\n- Zero Lua memory allocation in update loops (no garbage collector churn)\n- Purely event-driven lifecycle management and hard script detachment\n- Modern Blizzard Canvas Settings integration")

    -- Divider line
    local line = parentPanel:CreateTexture(nil, "ARTWORK")
    line:SetPoint("TOPLEFT", authorInfo, "BOTTOMLEFT", 0, -14)
    line:SetSize(580, 1)
    line:SetColorTexture(0.8, 0.7, 0.2, 0.3)

    -- Installed AddOns Header
    local addonsHeader = parentPanel:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    addonsHeader:SetPoint("TOPLEFT", line, "BOTTOMLEFT", 0, -14)
    addonsHeader:SetText("Installed Suite Modules:")

    -- Dynamic rows for each addon
    local modules = {
        {
            key = "AutoJoin",
            title = "AutoJoin Biggins",
            desc = "Configurable auto-accept for party invitations from Guild, Friends, and BNet.",
            checkLoaded = function() return _G["AutoJoinBiggins"] ~= nil end,
            getVersion = function() return (_G["AutoJoinBiggins"] and _G["AutoJoinBiggins"].version) or "1.2.0" end,
            getCatID = function() return _G["AutoJoinBiggins"] and _G["AutoJoinBiggins"].categoryID end,
        },
        {
            key = "LazySpeed",
            title = "LazySpeed Biggins",
            desc = "High-precision flight, swim, and movement speedometer with dynamic HUD.",
            checkLoaded = function() return _G["LazySpeedBigginsFrame"] ~= nil or _G["LazySpeedBigginsDB"] ~= nil end,
            getVersion = function() return _G["LazySpeedBiggins_Version"] or "3.8.0" end,
            getCatID = function() return _G["LazySpeedBiggins_CategoryID"] end,
        },
        {
            key = "Perf",
            title = "Perf Biggins",
            desc = "High-performance FPS and dual-latency telemetry HUD in a nameplate stack.",
            checkLoaded = function() return _G["PerfBiggins"] ~= nil end,
            getVersion = function() return (_G["PerfBiggins"] and _G["PerfBiggins"].version) or "1.2.0" end,
            getCatID = function() return _G["PerfBiggins"] and _G["PerfBiggins"].categoryID end,
        },
        {
            key = "SummonPet",
            title = "SummonPet Biggins",
            desc = "Ultra-lightweight companion pet summoner with native keybind & smart auto-dismiss.",
            checkLoaded = function() return _G["SummonPetBiggins"] ~= nil end,
            getVersion = function() return (_G["SummonPetBiggins"] and _G["SummonPetBiggins"].version) or "1.2.0" end,
            getCatID = function() return _G["SummonPetBiggins"] and _G["SummonPetBiggins"].categoryID end,
        },
    }

    local prevAnchor = addonsHeader
    parentPanel.moduleRows = {}

    for _, mod in ipairs(modules) do
        local row = CreateFrame("Frame", nil, parentPanel)
        row:SetPoint("TOPLEFT", prevAnchor, "BOTTOMLEFT", 0, -10)
        row:SetSize(580, 42)

        local rowTitle = row:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
        rowTitle:SetPoint("TOPLEFT", 0, 0)
        row.titleText = rowTitle

        local rowDesc = row:CreateFontString(nil, "ARTWORK", "GameFontDisableSmall")
        rowDesc:SetPoint("TOPLEFT", rowTitle, "BOTTOMLEFT", 0, -2)
        rowDesc:SetText(mod.desc)
        row.descText = rowDesc

        local btnConfigure = CreateFrame("Button", nil, row, "UIPanelButtonTemplate")
        btnConfigure:SetPoint("TOPRIGHT", 0, 0)
        btnConfigure:SetSize(110, 22)
        btnConfigure:SetText("Configure")
        btnConfigure:SetScript("OnClick", function()
            local catID = mod.getCatID()
            if catID and Settings and Settings.OpenToCategory then
                Settings.OpenToCategory(catID)
            end
        end)
        row.btnConfigure = btnConfigure

        row.mod = mod
        table.insert(parentPanel.moduleRows, row)
        prevAnchor = row
    end

    local function RefreshParentPanel()
        for _, row in ipairs(parentPanel.moduleRows) do
            local mod = row.mod
            local isLoaded = mod.checkLoaded()
            if isLoaded then
                row.titleText:SetText("|cFFFFD100" .. mod.title .. "|r  |cFF00FF00v" .. mod.getVersion() .. "|r")
                row.descText:SetTextColor(0.8, 0.8, 0.8)
                row.btnConfigure:Show()
                row.btnConfigure:Enable()
                row.btnConfigure:SetAlpha(1.0)
            else
                row.titleText:SetText("|cFF888888" .. mod.title .. "|r  |cFF888888(Available on CurseForge)|r")
                row.descText:SetTextColor(0.5, 0.5, 0.5)
                row.btnConfigure:Hide()
            end
        end
    end

    parentPanel:SetScript("OnShow", RefreshParentPanel)

    local parentCategory = Settings.RegisterCanvasLayoutCategory(parentPanel, "Biggins AddOns")
    Settings.RegisterAddOnCategory(parentCategory)

    self.parentCategory = parentCategory
    self.parentPanel = parentPanel
    self.categoryID = parentCategory:GetID()

    -- Register /biggins slash command to open the suite overview
    SLASH_BIGGINS1 = "/biggins"
    SlashCmdList["BIGGINS"] = function()
        if Settings and Settings.OpenToCategory and Suite.categoryID then
            Settings.OpenToCategory(Suite.categoryID)
        end
    end

    return parentCategory
end

function Suite:RegisterSubcategory(addonDir, panel, shortName)
    if Settings and Settings.RegisterCanvasLayoutSubcategory then
        local parent = self:GetOrCreateParentCategory(addonDir)
        local subcategory = Settings.RegisterCanvasLayoutSubcategory(parent, panel, shortName)
        return subcategory:GetID()
    elseif Settings and Settings.RegisterCanvasLayoutCategory then
        local category = Settings.RegisterCanvasLayoutCategory(panel, panel.name or shortName)
        Settings.RegisterAddOnCategory(category)
        return category:GetID()
    else
        InterfaceOptions_AddCategory(panel)
        return nil
    end
end
