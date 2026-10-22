-- SummonPetBiggins.lua
-- Author: Biggins
-- Credits: Inspired by Callie's (Caliaha) classic BartrubySummonPet
-- Ultra-lightweight, event-driven companion pet summoner

local addonName, addon = ...
_G["SummonPetBiggins"] = addon
addon.version = "1.1.0"

-- Localize Keybinding Labels in WoW Settings
_G["BINDING_HEADER_SUMMONPETBIGGINS_HEADER"] = "SummonPet Biggins"
_G["BINDING_NAME_SUMMONPETBIGGINS_TOGGLE"] = "Toggle Companion Summoning"
_G["BINDING_NAME_SUMMONPETBIGGINS_PIN"] = "Pin Currently Summoned Pet"

-- Default Settings
local defaults = {
    enabled = true,
    mode = "FAVORITES",         -- "FAVORITES", "RANDOM", or "PINNED"
    pinnedPetGUID = nil,        -- GUID of pinned pet
    pinnedPetName = "None",     -- Display name of pinned pet
    autoDismissInStealth = true,
    autoDismissInstances = true, -- Master toggle for instance dismissal
    dismissRaids = true,        -- Raids
    dismissMPlus = true,        -- Mythic+ Dungeons
    dismissDungeons = false,    -- Regular Dungeons
    dismissDelves = false,      -- Delves & Labyrinths
    summonWhileMounted = false, -- Allow companion while mounted on the ground
    printStatus = true,
}

local frame = CreateFrame("Frame")
frame:RegisterEvent("ADDON_LOADED")
frame:RegisterEvent("PLAYER_LOGIN")

-- Print helper with colored prefix
local function PrintMsg(msg)
    print("|cFFFFD100[SummonPetBiggins]|r " .. msg)
end

local function ShouldSuppressStealth()
    return SummonPetBigginsDB and SummonPetBigginsDB.autoDismissInStealth and IsStealthed()
end

-- Instance Content Detection & Auto-Dismiss Check
local function ShouldDismissInCurrentInstance()
    if not (SummonPetBigginsDB and SummonPetBigginsDB.autoDismissInstances) then
        return false
    end

    local inInstance, instanceType = IsInInstance()
    local isScenario = (C_Scenario and C_Scenario.IsInScenario and C_Scenario.IsInScenario())

    if not inInstance and not isScenario then
        -- Catch active Mythic+ challenge mode during zone transitions
        if SummonPetBigginsDB.dismissMPlus and C_ChallengeMode and C_ChallengeMode.IsChallengeModeActive and C_ChallengeMode.IsChallengeModeActive() then
            return true
        end
        return false
    end

    local name, _, difficultyID = GetInstanceInfo()
    name = name or ""
    local nameLower = string.lower(name)

    -- 1. Raids (Normal, Heroic, Mythic, LFR)
    if instanceType == "raid" then
        return SummonPetBigginsDB.dismissRaids
    end

    -- 2. Mythic+ Dungeons (Challenge Mode or Mythic 0)
    local isMPlus = (difficultyID == 8 or difficultyID == 23) or (C_ChallengeMode and C_ChallengeMode.IsChallengeModeActive and C_ChallengeMode.IsChallengeModeActive())
    if isMPlus then
        return SummonPetBigginsDB.dismissMPlus
    end

    -- 3. Delves & Labyrinths (Scenario instance, difficulty 208, active scenario, or name contains delve/labyrinth)
    local isDelveOrLab = (instanceType == "scenario")
        or (difficultyID == 208)
        or isScenario
        or (string.find(nameLower, "delve") ~= nil)
        or (string.find(nameLower, "labyrinth") ~= nil)
    if isDelveOrLab then
        return SummonPetBigginsDB.dismissDelves
    end

    -- 4. Regular Dungeons (Normal, Heroic, Timewalking, Follower)
    if instanceType == "party" then
        return SummonPetBigginsDB.dismissDungeons
    end

    return false
end

local function IsMountedBlocked()
    if not IsMounted() then
        return false
    end
    -- If mounted: allow only if summonWhileMounted is enabled AND player is on the ground (not flying/falling)
    if SummonPetBigginsDB and SummonPetBigginsDB.summonWhileMounted then
        return (IsFlying and IsFlying()) or (IsFalling and IsFalling())
    end
    return true
end

local function ShouldDismissMounted()
    return IsMounted() and not (SummonPetBigginsDB and SummonPetBigginsDB.summonWhileMounted)
end

-- Grounded Mount Touchdown Watcher (triggers summon the instant you touch ground from flight)
local mountWatcherTicker = nil

local function StopMountWatcher()
    if mountWatcherTicker then
        mountWatcherTicker:Cancel()
        mountWatcherTicker = nil
    end
end

local function StartMountWatcher()
    if mountWatcherTicker or not SummonPetBigginsDB or not SummonPetBigginsDB.summonWhileMounted then
        return
    end
    mountWatcherTicker = C_Timer.NewTicker(0.25, function()
        if not IsMounted() or not SummonPetBigginsDB or not SummonPetBigginsDB.summonWhileMounted then
            StopMountWatcher()
            return
        end

        -- If grounded on mount and no companion is out, summon immediately!
        local currentPet = C_PetJournal.GetSummonedPetGUID()
        if not currentPet then
            if not IsMountedBlocked() and not InCombatLockdown() and not ShouldSuppressStealth() then
                addon:Summon()
            end
        end
    end)
end

addon.StartMountWatcher = StartMountWatcher
addon.StopMountWatcher = StopMountWatcher

-- Grounded Mount Movement Hook (backup trigger when starting movement on a mount)
local function OnMovementStart()
    if SummonPetBigginsDB and SummonPetBigginsDB.enabled and SummonPetBigginsDB.summonWhileMounted and IsMounted() then
        if not IsMountedBlocked() and not InCombatLockdown() and not ShouldSuppressStealth() then
            local currentPet = C_PetJournal.GetSummonedPetGUID()
            if not currentPet then
                addon:Summon()
            end
        end
    end
end

-- Core Summon Function (Zero-Garbage)
function addon:Summon()
    if not SummonPetBigginsDB or not SummonPetBigginsDB.enabled then
        return
    end

    if InCombatLockdown() or UnitIsDeadOrGhost("player") or IsMountedBlocked() or ShouldSuppressStealth() or ShouldDismissInCurrentInstance() then
        return
    end

    local currentPet = C_PetJournal.GetSummonedPetGUID()
    local mode = SummonPetBigginsDB.mode or "FAVORITES"

    if mode == "PINNED" and SummonPetBigginsDB.pinnedPetGUID then
        if currentPet ~= SummonPetBigginsDB.pinnedPetGUID then
            C_PetJournal.SummonPetByGUID(SummonPetBigginsDB.pinnedPetGUID)
        end
    elseif mode == "RANDOM" then
        if not currentPet then
            C_PetJournal.SummonRandomPet(false)
        end
    else
        -- Default: Random Favorite Companion
        if not currentPet then
            C_PetJournal.SummonRandomPet(true)
        end
    end
end

-- Core Dismiss Function (Debounced Safe Dismissal)
function addon:Dismiss(attempt)
    attempt = attempt or 1

    if not InCombatLockdown() then
        local currentPet = C_PetJournal.GetSummonedPetGUID()
        if currentPet then
            C_PetJournal.SummonPetByGUID(currentPet)
        end
    end

    -- Retry up to 3 times to catch pets delayed by unmounting or combat sync
    if attempt < 4 then
        C_Timer.After(0.25 * attempt, function()
            local shouldDismiss = ShouldSuppressStealth() or ShouldDismissInCurrentInstance() or ShouldDismissMounted()
            if shouldDismiss then
                local pet = C_PetJournal.GetSummonedPetGUID()
                if pet or InCombatLockdown() then
                    addon:Dismiss(attempt + 1)
                end
            end
        end)
    end
end

-- ==============================================================================
-- UI OPTIONS PANEL WIDGETS & STATE SYNC
-- ==============================================================================
local uiWidgets = {}

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

-- Toggle Function (Triggered via Native Keybind or /togglepet)
function addon:Toggle()
    if not SummonPetBigginsDB then
        SummonPetBigginsDB = CopyTable(defaults)
    end

    local newState = not SummonPetBigginsDB.enabled
    SummonPetBigginsDB.enabled = newState

    if newState then
        addon:Summon()
    else
        addon:Dismiss()
    end

    if SummonPetBigginsDB.printStatus then
        local status = newState and "|cFF00FF00Enabled|r" or "|cFFFF0000Disabled|r"
        PrintMsg("Companion auto-summoning is now " .. status .. ".")
    end
    addon:UpdateOptionsUI()
end

-- Pin Currently Active Pet
function addon:PinCurrentPet()
    local currentPet = C_PetJournal.GetSummonedPetGUID()
    if not currentPet then
        PrintMsg("|cFFFF5555No companion pet currently summoned!|r Summon a pet first, then pin it.")
        return false
    end

    local _, customName, _, _, _, _, _, speciesName = C_PetJournal.GetPetInfoByPetID(currentPet)
    local displayName = customName or speciesName or "Unknown Pet"

    SummonPetBigginsDB.mode = "PINNED"
    SummonPetBigginsDB.pinnedPetGUID = currentPet
    SummonPetBigginsDB.pinnedPetName = displayName

    PrintMsg("Pinned active companion: |cFF00FF00" .. displayName .. "|r (Mode set to Pinned).")
    addon:UpdateOptionsUI()
    return true
end

-- Set Summon Mode
function addon:SetMode(newMode)
    if newMode == "FAVORITES" or newMode == "RANDOM" or newMode == "PINNED" then
        SummonPetBigginsDB.mode = newMode
        local modeLabels = {
            FAVORITES = "Random Favorites",
            RANDOM = "Completely Random",
            PINNED = "Pinned Pet (" .. (SummonPetBigginsDB.pinnedPetName or "None") .. ")"
        }
        PrintMsg("Mode set to: |cFF00FF00" .. (modeLabels[newMode] or newMode) .. "|r.")
        addon:UpdateOptionsUI()
        addon:Summon()
    end
end

-- Event Orchestration (Event-Driven: 0 CPU while moving or idle)
frame:SetScript("OnEvent", function(self, event, arg1)
    if event == "ADDON_LOADED" and arg1 == addonName then
        if not SummonPetBigginsDB then
            SummonPetBigginsDB = CopyTable(defaults)
        else
            -- Ensure any newly added default keys exist
            for k, v in pairs(defaults) do
                if SummonPetBigginsDB[k] == nil then
                    SummonPetBigginsDB[k] = v
                end
            end
        end
        addon:RegisterOptions()
    elseif event == "PLAYER_LOGIN" then
        -- Register only meaningful game-state events
        self:RegisterEvent("PLAYER_REGEN_ENABLED")         -- Left combat
        self:RegisterEvent("PLAYER_MOUNT_DISPLAY_CHANGED") -- Mounted/Dismounted
        self:RegisterEvent("UPDATE_STEALTH")               -- Stealthed/Unstealthed
        self:RegisterEvent("PLAYER_ENTERING_WORLD")        -- Zone load
        self:RegisterEvent("ZONE_CHANGED_NEW_AREA")        -- Zone/subzone transition
        self:RegisterEvent("SCENARIO_UPDATE")              -- Scenario/Delve state change
        self:RegisterEvent("CHALLENGE_MODE_START")         -- Mythic+ key started
        self:RegisterEvent("CHALLENGE_MODE_COMPLETED")     -- Mythic+ key finished

        -- Hook forward movement and autorun for grounded mount summoning
        if hooksecurefunc then
            pcall(hooksecurefunc, "MoveForwardStart", OnMovementStart)
            pcall(hooksecurefunc, "ToggleAutoRun", OnMovementStart)
        end

        -- Initial check after game world settles
        C_Timer.After(2.0, function()
            if ShouldDismissMounted() then
                addon:Dismiss(1)
            else
                addon:Summon()
            end
        end)
        if IsMounted() and SummonPetBigginsDB and SummonPetBigginsDB.summonWhileMounted then
            StartMountWatcher()
        end
    elseif event == "PLAYER_REGEN_ENABLED" then
        if ShouldSuppressStealth() or ShouldDismissMounted() then
            addon:Dismiss(1)
        elseif SummonPetBigginsDB and SummonPetBigginsDB.enabled and not IsMountedBlocked() then
            addon:Summon()
        end
    elseif event == "PLAYER_MOUNT_DISPLAY_CHANGED" then
        if not IsMounted() then
            StopMountWatcher()
            if ShouldSuppressStealth() then
                addon:Dismiss(1)
            else
                C_Timer.After(0.25, function()
                    if not IsMounted() and not ShouldSuppressStealth() then
                        if IsFalling() then
                            C_Timer.After(0.4, function()
                                if not IsMounted() and not ShouldSuppressStealth() then
                                    addon:Summon()
                                end
                            end)
                        else
                            addon:Summon()
                        end
                    end
                end)
            end
        else
            -- Mounted up
            if SummonPetBigginsDB and SummonPetBigginsDB.summonWhileMounted then
                StartMountWatcher()
                C_Timer.After(0.3, function()
                    if IsMounted() and not IsMountedBlocked() and not ShouldSuppressStealth() then
                        addon:Summon()
                    end
                end)
            else
                addon:Dismiss(1)
            end
        end
    elseif event == "UPDATE_STEALTH" then
        if IsStealthed() then
            if SummonPetBigginsDB and SummonPetBigginsDB.autoDismissInStealth then
                addon:Dismiss(1)
            else
                addon:Summon()
            end
        else
            addon:Summon()
        end
    elseif event == "CHALLENGE_MODE_START" then
        if SummonPetBigginsDB and SummonPetBigginsDB.autoDismissInstances and SummonPetBigginsDB.dismissMPlus then
            addon:Dismiss(1)
        end
    elseif event == "CHALLENGE_MODE_COMPLETED" then
        if SummonPetBigginsDB and SummonPetBigginsDB.enabled and not ShouldDismissInCurrentInstance() then
            addon:Summon()
        end
    elseif event == "ZONE_CHANGED_NEW_AREA" or event == "SCENARIO_UPDATE" then
        if ShouldDismissInCurrentInstance() then
            addon:Dismiss(1)
        end
    elseif event == "PLAYER_ENTERING_WORLD" then
        if ShouldDismissInCurrentInstance() or ShouldDismissMounted() then
            addon:Dismiss(1)
        else
            C_Timer.After(1.5, function()
                if ShouldDismissInCurrentInstance() or ShouldDismissMounted() then
                    addon:Dismiss(1)
                else
                    addon:Summon()
                end
            end)
        end
    end
end)

-- ==============================================================================
-- BLIZZARD MODERN SETTINGS API INTEGRATION (Vertical Layout)
-- ==============================================================================

local function ResetAllToDefaults()
    if not SummonPetBigginsDB then SummonPetBigginsDB = {} end
    for varName, defVal in pairs(defaults) do
        SummonPetBigginsDB[varName] = defVal
    end
    addon:UpdateOptionsUI()
    if SummonPetBigginsDB.enabled then
        addon:Summon()
    else
        addon:Dismiss()
    end
    PrintMsg("All options have been reset to default.")
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

    -- Top-Right "Defaults" Button
    local btnDefaults = CreateFrame("Button", nil, panel, "UIPanelButtonTemplate")
    btnDefaults:SetPoint("TOPRIGHT", -24, -20)
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
        local currentVal = (SummonPetBigginsDB and SummonPetBigginsDB[key] ~= nil) and SummonPetBigginsDB[key] or defaults[key]
        cb:SetChecked(currentVal)
        cb:SetScript("OnClick", function(self)
            if not SummonPetBigginsDB then SummonPetBigginsDB = {} end
            SummonPetBigginsDB[key] = self:GetChecked()
            if onClickCallback then onClickCallback(self:GetChecked()) end
            addon:UpdateOptionsUI()
        end)
        cb:SetScript("OnEnter", function(self)
            if self.tooltipText then
                GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
                GameTooltip:SetText(self.tooltipText, 1, 1, 1, true)
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
            if IsStealthed() then addon:Dismiss(1) end
        else
            addon:Summon()
        end
    end)
    uiWidgets.cbStealth = cbStealth

    local function OnInstanceSettingChange()
        if ShouldDismissInCurrentInstance() then
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
    local cbMount = CreateSettingCheckbox("summonWhileMounted", "Summon Companion While Mounted (Ground Only)", "When enabled, companion pets will summon while mounted on the ground and run alongside you.", "TOPLEFT", cbDelve, "BOTTOMLEFT", -20, -8, function(val)
        if val then
            if IsMounted() then
                StartMountWatcher()
                if not IsMountedBlocked() then addon:Summon() end
            end
        else
            StopMountWatcher()
            if IsMounted() then addon:Dismiss(1) end
        end
    end)
    uiWidgets.cbMount = cbMount

    local cbPrint = CreateSettingCheckbox("printStatus", "Show Chat Status on Toggle", "Print a chat notification whenever companion auto-summoning is toggled.", "TOPLEFT", cbMount, "BOTTOMLEFT", 0, -6)
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
    keybindNote:SetText("Keybinds: Game Menu -> Options -> Keybindings -> AddOns -> SummonPet Biggins\nSlash commands: /togglepet or /spb (fav, random, pin, mount, status)")

    panel:SetScript("OnShow", function()
        addon:UpdateOptionsUI()
    end)

    if Settings and Settings.RegisterCanvasLayoutCategory then
        local category = Settings.RegisterCanvasLayoutCategory(panel, "SummonPet Biggins")
        Settings.RegisterAddOnCategory(category)
        addon.categoryID = category:GetID()
    else
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
        PrintMsg("Options available in Game Menu -> Options -> AddOns -> SummonPet Biggins.")
    end
end

-- Slash Commands (/togglepet, /spb)
SLASH_SUMMONPETBIGGINS1 = "/togglepet"
SLASH_SUMMONPETBIGGINS2 = "/spb"
SlashCmdList["SUMMONPETBIGGINS"] = function(msg)
    local cmd = msg and msg:trim():lower() or ""

    if cmd == "pin" then
        addon:PinCurrentPet()
    elseif cmd == "fav" or cmd == "favorites" then
        addon:SetMode("FAVORITES")
    elseif cmd == "random" or cmd == "rand" then
        addon:SetMode("RANDOM")
    elseif cmd == "mount" or cmd == "mounted" then
        SummonPetBigginsDB.summonWhileMounted = not SummonPetBigginsDB.summonWhileMounted
        local st = SummonPetBigginsDB.summonWhileMounted and "|cFF00FF00Enabled|r" or "|cFFFF0000Disabled|r"
        PrintMsg("Summon while mounted: " .. st .. ".")
        addon:UpdateOptionsUI()
        if SummonPetBigginsDB.summonWhileMounted then
            if IsMounted() then
                StartMountWatcher()
                if not IsMountedBlocked() then addon:Summon() end
            end
        else
            StopMountWatcher()
            if IsMounted() then addon:Dismiss(1) end
        end
    elseif cmd == "config" or cmd == "options" or cmd == "menu" then
        addon:OpenSettings()
    elseif cmd == "status" then
        local st = SummonPetBigginsDB.enabled and "|cFF00FF00Enabled|r" or "|cFFFF0000Disabled|r"
        local mt = SummonPetBigginsDB.summonWhileMounted and "|cFF00FF00Yes|r" or "|cFFFF0000No|r"
        PrintMsg("v" .. addon.version .. " | Auto-summon: " .. st .. " | Mode: |cFF00FF00" .. SummonPetBigginsDB.mode .. "|r | Mounted: " .. mt .. " | Pinned: |cFF00FF00" .. (SummonPetBigginsDB.pinnedPetName or "None") .. "|r")
        local inInst, instType = IsInInstance()
        local name, _, diffID = GetInstanceInfo()
        local isScen = (C_Scenario and C_Scenario.IsInScenario and C_Scenario.IsInScenario()) and "Yes" or "No"
        local shouldDismiss = ShouldDismissInCurrentInstance() and "|cFFFF0000Dismiss|r" or "|cFF00FF00Keep/Summon|r"
        PrintMsg(string.format("Zone Diagnostics: Name='%s' | InInst=%s | Type=%s | DiffID=%s | Scenario=%s -> Status: %s",
            name or "None", tostring(inInst), tostring(instType), tostring(diffID), isScen, shouldDismiss))
        PrintMsg(string.format("Instance Toggles: Master=%s | Raids=%s | M+=%s | Dungeons=%s | Delves/Lab=%s",
            tostring(SummonPetBigginsDB.autoDismissInstances),
            tostring(SummonPetBigginsDB.dismissRaids),
            tostring(SummonPetBigginsDB.dismissMPlus),
            tostring(SummonPetBigginsDB.dismissDungeons),
            tostring(SummonPetBigginsDB.dismissDelves)))
    elseif cmd == "help" then
        PrintMsg("Commands:")
        print("  |cFFFFD100/togglepet|r or |cFFFFD100/spb|r - Toggle pet summoning on/off")
        print("  |cFFFFD100/spb pin|r - Pin currently summoned pet as your active companion")
        print("  |cFFFFD100/spb fav|r - Set mode to random favorites")
        print("  |cFFFFD100/spb random|r - Set mode to completely random")
        print("  |cFFFFD100/spb mount|r - Toggle companion summoning while mounted on ground")
        print("  |cFFFFD100/spb options|r - Open settings panel")
        print("  |cFFFFD100/spb status|r - Display current configuration")
    else
        addon:Toggle()
    end
end
