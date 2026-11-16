--[[ ==============================================================================
    LibBigginsSuite-1.0 - Embedded Shared Suite Controller for Biggins AddOns
    ------------------------------------------------------------------------------
    Author: Biggins (US-Whisperwind)
    Compatibility: World of Warcraft: Midnight / The War Within (Patch 11.x - 12.x)
============================================================================== ]]--

local MAJOR, MINOR = "LibBigginsSuite-1.0", 6
local Suite = _G["LibBigginsSuite"]
if Suite and Suite.minor and Suite.minor >= MINOR then return end

Suite = Suite or {}
Suite.minor = MINOR
_G["LibBigginsSuite"] = Suite

-- Cache upvalues
local CreateFrame = CreateFrame
local Settings    = Settings
local UIParent    = UIParent
local C_AddOns    = C_AddOns
local type        = type

local function IsAddOnLoadedSafe(addonName)
    if C_AddOns and C_AddOns.IsAddOnLoaded then
        if C_AddOns.IsAddOnLoaded(addonName) then return true end
    elseif IsAddOnLoaded then
        if IsAddOnLoaded(addonName) then return true end
    end
    return _G[addonName] ~= nil or _G[addonName .. "Frame"] ~= nil or _G[addonName .. "DB"] ~= nil
end

local function GetAddOnVersion(addonName)
    local ver
    if C_AddOns and C_AddOns.GetAddOnMetadata then
        ver = C_AddOns.GetAddOnMetadata(addonName, "Version")
    elseif GetAddOnMetadata then
        ver = GetAddOnMetadata(addonName, "Version")
    end
    if ver and ver ~= "" then
        return ver
    end
    local tbl = _G[addonName]
    if type(tbl) == "table" and tbl.version then
        return tbl.version
    end
    return _G[addonName .. "_Version"] or ""
end

local function GetAddOnCategoryID(addonName)
    local tbl = _G[addonName]
    if type(tbl) == "table" and tbl.categoryID then
        return tbl.categoryID
    end
    return _G[addonName .. "_CategoryID"]
end

function Suite:GetOrCreateParentCategory(addonDir)
    if self.parentCategory then
        return self.parentCategory
    end

    local parentPanel = CreateFrame("Frame", "BigginsAddOnsParentPanel", UIParent)
    parentPanel.name = "Biggins AddOns"
    parentPanel:Hide() -- Force initial hidden state so the first presentation to the user triggers a clean OnShow

    -- Title (Blizzard Gold)
    local title = parentPanel:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
    title:SetPoint("TOPLEFT", 16, -16)
    title:SetText("|cFFFFD100Biggins AddOns|r")

    -- Subtitle / Description
    local desc = parentPanel:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
    desc:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -6)
    desc:SetPoint("RIGHT", logo, "LEFT", -20)
    desc:SetJustifyH("LEFT")
    desc:SetWordWrap(true)
    desc:SetText("High-performance, lightweight World of Warcraft addons with zero Lua garbage generation.")

    -- Suite Logo Texture (Top Right)
    local logo = parentPanel:CreateTexture(nil, "ARTWORK")
    logo:SetPoint("TOPRIGHT", -24, -16)
    logo:SetSize(84, 84)
    logo:SetTexture("Interface\\AddOns\\" .. (addonDir or "AutoJoinBiggins") .. "\\suite-logo.jpg")

    -- Author & Architecture Header
    local authorHeader = parentPanel:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    authorHeader:SetPoint("TOPLEFT", desc, "BOTTOMLEFT", 0, -18)
    authorHeader:SetJustifyH("LEFT")
    authorHeader:SetText("Engineering Philosophy & Standards:")

    local authorInfo = parentPanel:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
    authorInfo:SetPoint("TOPLEFT", authorHeader, "BOTTOMLEFT", 0, -6)
    authorInfo:SetPoint("RIGHT", logo, "LEFT", -20)
    authorInfo:SetJustifyH("LEFT")
    authorInfo:SetJustifyV("TOP")
    authorInfo:SetWordWrap(true)
    authorInfo:SetText("Created by |cFFFFD100Biggins|r (US-Whisperwind).\nEvery addon in this suite is built from the ground up for maximum CPU efficiency:\n  - Zero Lua memory allocation in update loops (no garbage collector churn)\n  - Purely event-driven lifecycle management and hard script detachment\n  - Modern Blizzard Canvas Settings integration")

    -- Divider line
    local line = parentPanel:CreateTexture(nil, "ARTWORK")
    line:SetPoint("TOPLEFT", authorInfo, "BOTTOMLEFT", 0, -14)
    line:SetSize(580, 1)
    line:SetColorTexture(0.8, 0.7, 0.2, 0.3)

    -- Installed AddOns Header
    local addonsHeader = parentPanel:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    addonsHeader:SetPoint("TOPLEFT", line, "BOTTOMLEFT", 0, -14)
    addonsHeader:SetJustifyH("LEFT")
    addonsHeader:SetText("Installed Suite Modules:")

    -- Dynamic rows for each addon (alphabetical, zero hardcoded versions)
    local modules = {
        {
            name  = "AnglerBiggins",
            title = "Angler Biggins",
            desc  = "Automates Underlight Angler water walking, fish form, and underwater breathing.",
        },
        {
            name  = "AutoJoinBiggins",
            title = "AutoJoin Biggins",
            desc  = "Configurable auto-accept for party invitations from Guild, Friends, and BNet.",
        },
        {
            name  = "ChatLinkBiggins",
            title = "ChatLink Biggins",
            desc  = "Converts web URLs into clickable links and displays player tooltips on name hover.",
        },
        {
            name  = "KnowledgeBiggins",
            title = "Knowledge Biggins",
            desc  = "Popup button to instantly study and consume profession knowledge from your bags.",
        },
        {
            name  = "LazySpeedBiggins",
            title = "LazySpeed Biggins",
            desc  = "High-precision flight, swim, and movement speedometer with dynamic HUD.",
        },
        {
            name  = "PerfBiggins",
            title = "Perf Biggins",
            desc  = "High-performance FPS and dual-latency telemetry HUD in a nameplate stack.",
        },
        {
            name  = "SafeReleaseBiggins",
            title = "SafeRelease Biggins",
            desc  = "Guards the Release Spirit button during wipes in raids, M+, and delves.",
        },
        {
            name  = "SummonPetBiggins",
            title = "SummonPet Biggins",
            desc  = "Ultra-lightweight companion pet summoner with native keybind & smart auto-dismiss.",
        },
    }

    local prevAnchor = addonsHeader
    parentPanel.moduleRows = {}

    for _, mod in ipairs(modules) do
        local row = CreateFrame("Frame", nil, parentPanel)
        row:SetPoint("TOPLEFT", prevAnchor, "BOTTOMLEFT", 0, -10)
        row:SetSize(580, 42)

        local btnConfigure = CreateFrame("Button", nil, row, "UIPanelButtonTemplate")
        btnConfigure:SetPoint("TOPRIGHT", 0, 0)
        btnConfigure:SetSize(110, 22)
        btnConfigure:SetText("Configure")
        btnConfigure:SetScript("OnClick", function()
            local catID = GetAddOnCategoryID(mod.name)
            if catID and Settings and Settings.OpenToCategory then
                Settings.OpenToCategory(catID)
            end
        end)
        row.btnConfigure = btnConfigure

        local rowTitle = row:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
        rowTitle:SetPoint("TOPLEFT", 0, 0)
        rowTitle:SetPoint("RIGHT", btnConfigure, "LEFT", -12)
        rowTitle:SetJustifyH("LEFT")
        row.titleText = rowTitle

        local rowDesc = row:CreateFontString(nil, "ARTWORK", "GameFontDisableSmall")
        rowDesc:SetPoint("TOPLEFT", rowTitle, "BOTTOMLEFT", 0, -2)
        rowDesc:SetPoint("RIGHT", btnConfigure, "LEFT", -12)
        rowDesc:SetJustifyH("LEFT")
        rowDesc:SetWordWrap(true)
        rowDesc:SetText(mod.desc)
        row.descText = rowDesc

        row.mod = mod
        table.insert(parentPanel.moduleRows, row)
        prevAnchor = row
    end

    local function RefreshParentPanel()
        for _, row in ipairs(parentPanel.moduleRows) do
            local mod = row.mod
            local isLoaded = IsAddOnLoadedSafe(mod.name)
            if isLoaded then
                local ver = GetAddOnVersion(mod.name)
                local verStr = (ver and ver ~= "") and ("  |cFF00FF00v" .. ver .. "|r") or ""
                row.titleText:SetText("|cFFFFD100" .. mod.title .. "|r" .. verStr)
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
    self.Refresh = RefreshParentPanel
    parentPanel.Refresh = RefreshParentPanel

    -- Initial population so texts and buttons are ready immediately
    RefreshParentPanel()

    local parentCategory = Settings.RegisterCanvasLayoutCategory(parentPanel, "Biggins AddOns")
    Settings.RegisterAddOnCategory(parentCategory)

    self.parentCategory = parentCategory
    self.parentPanel = parentPanel
    self.categoryID = parentCategory:GetID()

    -- Register /biggins slash command to open the suite overview
    SLASH_BIGGINS1 = "/biggins"
    SlashCmdList["BIGGINS"] = function()
        if Suite.Refresh then
            Suite:Refresh()
        end
        if Settings and Settings.OpenToCategory and Suite.categoryID then
            Settings.OpenToCategory(Suite.categoryID)
        end
    end

    return parentCategory
end

function Suite:RegisterSubcategory(addonDir, panel, shortName)
    local subcatID = nil
    if Settings and Settings.RegisterCanvasLayoutSubcategory then
        local parent = self:GetOrCreateParentCategory(addonDir)
        local subcategory = Settings.RegisterCanvasLayoutSubcategory(parent, panel, shortName)
        subcatID = subcategory:GetID()
    elseif Settings and Settings.RegisterCanvasLayoutCategory then
        local category = Settings.RegisterCanvasLayoutCategory(panel, panel.name or shortName)
        Settings.RegisterAddOnCategory(category)
        subcatID = category:GetID()
    else
        InterfaceOptions_AddCategory(panel)
        subcatID = nil
    end

    -- Dynamically refresh parent panel whenever a new subcategory registers
    if self.Refresh then
        self:Refresh()
    end

    return subcatID
end

-- Refresh suite dashboard at PLAYER_LOGIN when all addons are fully loaded into memory
local suiteEventFrame = CreateFrame("Frame")
suiteEventFrame:RegisterEvent("PLAYER_LOGIN")
suiteEventFrame:SetScript("OnEvent", function(frameSelf, event)
    if Suite.Refresh then
        Suite:Refresh()
    end
    frameSelf:UnregisterEvent("PLAYER_LOGIN")
end)
