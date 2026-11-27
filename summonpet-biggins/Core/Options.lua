--[[ ==============================================================================
    SummonPet Biggins - Options & Settings Panel (Canvas Layout)
    ------------------------------------------------------------------------------
    Integrated Blizzard Settings panel providing master enable, auto-dismiss
    filters (stealth, instances, delves, m+), ground mounting, and mode selection.
============================================================================== ]]--

local addonName, addon = ...

-- Cache global functions
local CreateFrame     = CreateFrame
local GameTooltip     = GameTooltip
local UIParent        = UIParent
local Settings        = Settings
local LibBigginsSuite = LibBigginsSuite
local InterfaceOptions_AddCategory = InterfaceOptions_AddCategory
local CopyTable       = CopyTable
local ipairs          = ipairs
local pairs           = pairs
local string_gmatch   = string.gmatch
local IsMounted       = IsMounted

local uiWidgets = {}
addon.uiWidgets = uiWidgets

function addon:UpdateOptionsUI()
    if not uiWidgets.panel or not SummonPetBigginsDB then return end

    local isEnabled = SummonPetBigginsDB.enabled ~= false
    local isInstActive = isEnabled and (SummonPetBigginsDB.autoDismissInstances ~= false)

    if uiWidgets.cbEnable then
        uiWidgets.cbEnable:SetChecked(isEnabled)
    end
    if uiWidgets.cbStealth then
        uiWidgets.cbStealth:SetChecked(SummonPetBigginsDB.autoDismissInStealth)
        uiWidgets.cbStealth:SetEnabled(isEnabled)
        uiWidgets.cbStealth:SetAlpha(isEnabled and 1.0 or 0.5)
    end
    if uiWidgets.cbInstances then
        uiWidgets.cbInstances:SetChecked(SummonPetBigginsDB.autoDismissInstances)
        uiWidgets.cbInstances:SetEnabled(isEnabled)
        uiWidgets.cbInstances:SetAlpha(isEnabled and 1.0 or 0.5)
    end

    local instSubs = {
        { widget = uiWidgets.cbRaid, key = "dismissRaids" },
        { widget = uiWidgets.cbMPlus, key = "dismissMPlus" },
        { widget = uiWidgets.cbDungeon, key = "dismissDungeons" },
        { widget = uiWidgets.cbDelve, key = "dismissDelves" },
    }
    for _, item in ipairs(instSubs) do
        if item.widget then
            item.widget:SetChecked(SummonPetBigginsDB[item.key])
            item.widget:SetEnabled(isInstActive)
            item.widget:SetAlpha(isInstActive and 1.0 or 0.5)
        end
    end

    if uiWidgets.cbMount then
        uiWidgets.cbMount:SetChecked(SummonPetBigginsDB.summonWhileMounted)
        uiWidgets.cbMount:SetEnabled(isEnabled)
        uiWidgets.cbMount:SetAlpha(isEnabled and 1.0 or 0.5)
    end
    if uiWidgets.cbPrint then
        uiWidgets.cbPrint:SetChecked(SummonPetBigginsDB.printStatus)
        uiWidgets.cbPrint:SetEnabled(isEnabled)
        uiWidgets.cbPrint:SetAlpha(isEnabled and 1.0 or 0.5)
    end

    local modeWidgets = { uiWidgets.modeHeader, uiWidgets.radioFav, uiWidgets.radioRand, uiWidgets.radioPin, uiWidgets.pinLabel, uiWidgets.btnPin }
    for _, w in ipairs(modeWidgets) do
        if w then
            if w.SetEnabled then w:SetEnabled(isEnabled) end
            w:SetAlpha(isEnabled and 1.0 or 0.5)
        end
    end

    if uiWidgets.radioFav then
        uiWidgets.radioFav:SetChecked(SummonPetBigginsDB.mode == "FAVORITES")
    end
    if uiWidgets.radioRand then
        uiWidgets.radioRand:SetChecked(SummonPetBigginsDB.mode == "RANDOM")
    end
    if uiWidgets.radioPin then
        uiWidgets.radioPin:SetChecked(SummonPetBigginsDB.mode == "PINNED")
    end
    if uiWidgets.pinLabel then
        local petName = SummonPetBigginsDB.pinnedPetName or "None"
        uiWidgets.pinLabel:SetText("Currently Pinned Pet: |cFF00FF00" .. petName .. "|r")
    end
end

local function ResetAllToDefaults()
    if not SummonPetBigginsDB then SummonPetBigginsDB = {} end
    for varName, defVal in pairs(addon.defaults) do
        SummonPetBigginsDB[varName] = defVal
    end
    addon:UpdateOptionsUI()
    if SummonPetBigginsDB.enabled then
        addon:Summon()
    else
        addon:Dismiss()
    end
    addon:PrintMsg("All options have been reset to default.")
end

-- Register Modern Blizzard Settings Panel (Canvas Layout)
function addon:RegisterOptions()
    local panel = CreateFrame("Frame", "SummonPetBigginsOptionsPanel", UIParent)
    panel.name = "SummonPet Biggins"
    uiWidgets.panel = panel

    -- Title (Blizzard Gold)
    local title = panel:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
    title:SetPoint("TOPLEFT", 16, -16)
    title:SetText("|cFFFFD100SummonPet Biggins|r")

    -- Subtitle / Description
    local desc = panel:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
    desc:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -6)
    desc:SetText("Ultra-lightweight, event-driven companion pet summoner.\nInspired by Callie's classic BartrubySummonPet.")

    -- Suite Logo Texture (Top Right)
    local logo = panel:CreateTexture(nil, "ARTWORK")
    logo:SetPoint("TOPRIGHT", -24, -16)
    logo:SetSize(64, 64)
    logo:SetTexture("Interface\\AddOns\\SummonPetBiggins\\logo.jpg")

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
        GameTooltip:SetText("Restore default settings for SummonPet Biggins.", 1, 1, 1, true)
        GameTooltip:Show()
    end)
    btnDefaults:SetScript("OnLeave", function()
        GameTooltip:Hide()
    end)

    -- Helper to create and bind checkboxes
    local function CreateSettingCheckbox(key, label, tooltip, anchorPoint, relativeTo, relPoint, x, y, onClickCallback)
        local cb = CreateFrame("CheckButton", nil, panel, "InterfaceOptionsCheckButtonTemplate")
        cb:SetPoint(anchorPoint, relativeTo, relPoint, x, y)
        cb.Text:SetText(label)
        cb.Text:SetFontObject("GameFontHighlight")
        cb.tooltipText = tooltip
        local currentVal = (SummonPetBigginsDB and SummonPetBigginsDB[key] ~= nil) and SummonPetBigginsDB[key] or addon.defaults[key]
        cb:SetChecked(currentVal)
        cb:SetHitRectInsets(0, -320, 0, 0)
        cb:SetScript("OnClick", function(self)
            if not SummonPetBigginsDB then SummonPetBigginsDB = {} end
            SummonPetBigginsDB[key] = self:GetChecked()
            if onClickCallback then onClickCallback(self:GetChecked()) end
            addon:UpdateOptionsUI()
        end)
        cb:SetScript("OnEnter", function(self)
            if self.tooltipText then
                GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
                GameTooltip:ClearLines()
                for line in string_gmatch(self.tooltipText, "[^\r\n]+") do
                    GameTooltip:AddLine(line, 1, 1, 1, true)
                end
                GameTooltip:Show()
            end
        end)
        cb:SetScript("OnLeave", function()
            GameTooltip:Hide()
        end)
        return cb
    end

    -- Master Enable Checkbox
    local cbEnable = CreateSettingCheckbox("enabled", "Enable Companion Auto-Summoning", "Enable or disable automatic companion pet summoning.", "TOPLEFT", desc, "BOTTOMLEFT", 0, -18, function(val)
        if val then addon:Summon() else addon:Dismiss() end
    end)
    uiWidgets.cbEnable = cbEnable

    -- Child Checkboxes (Level 1: Indented 20px)
    local cbStealth = CreateSettingCheckbox("autoDismissInStealth", "Auto-Dismiss in Stealth", "Automatically dismiss companion pet when entering stealth.", "TOPLEFT", cbEnable, "BOTTOMLEFT", 20, -6, function(val)
        if val then
            if addon:IsStealthedActive() then addon:Dismiss(1) end
        elseif not addon:IsStealthedActive() then
            addon:Summon()
        end
    end)
    uiWidgets.cbStealth = cbStealth

    local function OnInstanceSettingChange()
        if addon:ShouldDismissInCurrentInstance() then
            addon:Dismiss(1)
        else
            addon:Summon()
        end
    end

    local cbInstances = CreateSettingCheckbox("autoDismissInstances", "Auto-Dismiss in Instances", "Master toggle: Automatically dismiss pets inside instances.", "TOPLEFT", cbStealth, "BOTTOMLEFT", 0, -6, OnInstanceSettingChange)
    uiWidgets.cbInstances = cbInstances

    -- Nested Instance Checkboxes (Level 2: Indented another 20px, total 40px)
    local cbRaid = CreateSettingCheckbox("dismissRaids", "Raids", "Dismiss companion pets in Raid instances.", "TOPLEFT", cbInstances, "BOTTOMLEFT", 20, -4, OnInstanceSettingChange)
    uiWidgets.cbRaid = cbRaid

    local cbMPlus = CreateSettingCheckbox("dismissMPlus", "Mythic+ Dungeons", "Dismiss companion pets in Mythic+ dungeons.", "TOPLEFT", cbRaid, "BOTTOMLEFT", 0, -4, OnInstanceSettingChange)
    uiWidgets.cbMPlus = cbMPlus

    local cbDungeon = CreateSettingCheckbox("dismissDungeons", "Regular Dungeons", "Dismiss companion pets in Regular, Heroic, and Timewalking dungeons.", "TOPLEFT", cbMPlus, "BOTTOMLEFT", 0, -4, OnInstanceSettingChange)
    uiWidgets.cbDungeon = cbDungeon

    local cbDelve = CreateSettingCheckbox("dismissDelves", "Delves & Labyrinths", "Dismiss companion pets in Delves and Delve Labyrinths.", "TOPLEFT", cbDungeon, "BOTTOMLEFT", 0, -4, OnInstanceSettingChange)
    uiWidgets.cbDelve = cbDelve

    -- Mount Checkbox (Level 1 Indent: back to 20px)
    local cbMount = CreateSettingCheckbox("summonWhileMounted", "Summon Companion While Mounted (Ground Only)", "When enabled, companion pets will summon while mounted on the ground and run alongside you.\n|cFFFF8000Warning:|r Can sometimes disrupt stealth abilities when stealth is used immediately upon landing.", "TOPLEFT", cbDelve, "BOTTOMLEFT", -20, -8, function(val)
        if val then
            if IsMounted() then
                addon:StartMountWatcher()
                if not addon:IsMountedBlocked() then addon:Summon() end
            end
        else
            addon:StopMountWatcher()
            if IsMounted() then addon:Dismiss(1) end
        end
    end)
    uiWidgets.cbMount = cbMount

    -- Visible warning subtext directly beneath the checkbox
    local mountWarn = panel:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
    mountWarn:SetPoint("TOPLEFT", cbMount.Text, "BOTTOMLEFT", 0, -3)
    mountWarn:SetPoint("RIGHT", panel, "RIGHT", -24)
    mountWarn:SetJustifyH("LEFT")
    mountWarn:SetWordWrap(true)
    mountWarn:SetText("|cFFFF8000Warning:|r Can sometimes disrupt stealth abilities when stealth is used immediately upon landing.")
    uiWidgets.mountWarn = mountWarn

    local cbPrint = CreateSettingCheckbox("printStatus", "Show Chat Status on Toggle", "Print a chat notification whenever companion auto-summoning is toggled.", "TOPLEFT", cbMount, "BOTTOMLEFT", 0, -28)
    uiWidgets.cbPrint = cbPrint

    -- Mode Section
    local modeHeader = panel:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    modeHeader:SetPoint("TOPLEFT", cbPrint, "BOTTOMLEFT", 0, -16)
    modeHeader:SetText("Summon Mode:")
    uiWidgets.modeHeader = modeHeader

    -- Radio Helper
    local function CreateModeRadio(modeKey, label, anchorPoint, relativeTo, relPoint, x, y)
        local radio = CreateFrame("CheckButton", nil, panel, "UIRadioButtonTemplate")
        radio:SetPoint(anchorPoint, relativeTo, relPoint, x, y)
        radio.text = radio:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
        radio.text:SetPoint("LEFT", radio, "RIGHT", 4, 0)
        radio.text:SetText(label)
        radio:SetScript("OnClick", function()
            addon:SetMode(modeKey)
        end)
        return radio
    end

    local radioFav = CreateModeRadio("FAVORITES", "Random Favorite Pet (starred in Pet Journal)", "TOPLEFT", modeHeader, "BOTTOMLEFT", 6, -8)
    uiWidgets.radioFav = radioFav

    local radioRand = CreateModeRadio("RANDOM", "Completely Random Pet (any pet in collection)", "TOPLEFT", radioFav, "BOTTOMLEFT", 0, -8)
    uiWidgets.radioRand = radioRand

    local radioPin = CreateModeRadio("PINNED", "Specific Pinned Pet", "TOPLEFT", radioRand, "BOTTOMLEFT", 0, -8)
    uiWidgets.radioPin = radioPin

    -- Pinned Pet Display Label
    local pinLabel = panel:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
    pinLabel:SetPoint("TOPLEFT", radioPin, "BOTTOMLEFT", 24, -8)
    uiWidgets.pinLabel = pinLabel

    -- Button: Use Currently Summoned Pet
    local btnPin = CreateFrame("Button", nil, panel, "UIPanelButtonTemplate")
    btnPin:SetPoint("TOPLEFT", pinLabel, "BOTTOMLEFT", 0, -8)
    btnPin:SetSize(220, 24)
    btnPin:SetText("Use Currently Summoned Pet")
    btnPin:SetScript("OnClick", function()
        addon:PinCurrentPet()
    end)
    btnPin:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:SetText("Pins your currently summoned companion pet as your permanent choice.", 1, 1, 1, true)
        GameTooltip:Show()
    end)
    btnPin:SetScript("OnLeave", function()
        GameTooltip:Hide()
    end)
    uiWidgets.btnPin = btnPin

    -- Keybinding Hint
    local keybindNote = panel:CreateFontString(nil, "ARTWORK", "GameFontDisableSmall")
    keybindNote:SetPoint("TOPLEFT", btnPin, "BOTTOMLEFT", -26, -18)
    keybindNote:SetText("Keybinds: Game Menu -> Options -> Keybindings -> AddOns -> SummonPet Biggins\nSlash commands: |cFFFFD100/summonpetb|r (Type |cFFFFD100/summonpetb ?|r for available commands)")

    panel:SetScript("OnShow", function()
        addon:UpdateOptionsUI()
    end)

    -- Register with modern Settings UI as a subcategory under Biggins AddOns
    if LibBigginsSuite then
        addon.categoryID = LibBigginsSuite:RegisterSubcategory("SummonPetBiggins", panel, "SummonPet")
    elseif Settings and Settings.RegisterCanvasLayoutCategory then
        local category = Settings.RegisterCanvasLayoutCategory(panel, "SummonPet Biggins")
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
        addon:PrintMsg("Options available in Game Menu -> Options -> AddOns -> SummonPet Biggins.")
    end
end
