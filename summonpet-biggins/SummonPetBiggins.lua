-- SummonPetBiggins.lua
-- Author: Biggins
-- Credits: Inspired by Callie's (Caliaha) classic BartrubySummonPet
-- Ultra-lightweight, event-driven companion pet summoner

local addonName, addon = ...
_G["SummonPetBiggins"] = addon
addon.version = "1.4.0"

-- Localize Keybinding Labels in WoW Settings
_G["BINDING_HEADER_SUMMONPETBIGGINS_HEADER"] = "SummonPet Biggins"
_G["BINDING_NAME_SUMMONPETBIGGINS_TOGGLE"] = "Toggle Companion Summoning"
_G["BINDING_NAME_SUMMONPETBIGGINS_PIN"] = "Pin Currently Summoned Pet"

-- Timing & Debounce Constants (Adjustable Grace Periods)
local DISMOUNT_DEBOUNCE_DELAY = 2.0   -- Buffer (seconds) after dismounting before companion is summoned
local TOUCHDOWN_DEBOUNCE_DELAY = 2.0  -- Buffer (seconds) after landing from flight while mounted
local TICKER_POLL_INTERVAL = 0.25     -- Grounded mount watcher polling frequency (seconds)
local DISMISS_RETRY_INTERVAL = 0.25   -- Debounced dismiss retry interval (seconds)
local MAX_DISMISS_ATTEMPTS = 4        -- Maximum retry attempts for companion dismissal

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

local function IsStealthedActive()
    return IsStealthed and IsStealthed()
end

local function ShouldDismissInStealth()
    return SummonPetBigginsDB and SummonPetBigginsDB.autoDismissInStealth and IsStealthedActive()
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

local function IsInFlightActive()
    local isGliding = (C_PlayerInfo and C_PlayerInfo.GetGlidingInfo and C_PlayerInfo.GetGlidingInfo())
    return (IsFlying and IsFlying()) or (isGliding == true) or (IsFalling and IsFalling())
end

local function IsMountedBlocked()
    if not IsMounted() then
        return false
    end
    -- If mounted: allow only if summonWhileMounted is enabled AND player is on the ground (not flying/falling/gliding)
    if SummonPetBigginsDB and SummonPetBigginsDB.summonWhileMounted then
        return IsInFlightActive()
    end
    return true
end

local function ShouldDismissMounted()
    return IsMounted() and not (SummonPetBigginsDB and SummonPetBigginsDB.summonWhileMounted)
end

-- Consolidated Pre-Condition Guard (Single Source of Truth)
local function CanSummon()
    if not (SummonPetBigginsDB and SummonPetBigginsDB.enabled) then
        return false
    end
    if InCombatLockdown() or UnitIsDeadOrGhost("player") then
        return false
    end
    if IsStealthedActive() or IsMountedBlocked() or ShouldDismissInCurrentInstance() then
        return false
    end
    return true
end

-- Grounded Mount Touchdown Watcher with Landing Debounce
local mountWatcherTicker = nil
local touchdownTimer = nil
local dismountTimer = nil
local wasInFlight = false

local function CancelTouchdownTimer()
    if touchdownTimer then
        touchdownTimer:Cancel()
        touchdownTimer = nil
    end
end

local function CancelDismountTimer()
    if dismountTimer then
        dismountTimer:Cancel()
        dismountTimer = nil
    end
end

local function CancelAllPendingSummons()
    CancelTouchdownTimer()
    CancelDismountTimer()
end

local function StopMountWatcher()
    CancelTouchdownTimer()
    if mountWatcherTicker then
        mountWatcherTicker:Cancel()
        mountWatcherTicker = nil
    end
    wasInFlight = false
end

local function StartMountWatcher()
    if mountWatcherTicker or not SummonPetBigginsDB or not SummonPetBigginsDB.summonWhileMounted then
        return
    end

    wasInFlight = IsInFlightActive()
    mountWatcherTicker = C_Timer.NewTicker(TICKER_POLL_INTERVAL, function()
        if not IsMounted() or not SummonPetBigginsDB or not SummonPetBigginsDB.summonWhileMounted then
            StopMountWatcher()
            return
        end

        local inFlightNow = IsInFlightActive()
        if inFlightNow then
            wasInFlight = true
            CancelTouchdownTimer()
            return
        end

        -- If we were in flight and just touched down, delay summon decision by 1.0s
        -- to prevent race conditions when landing and stealthing in one fluid motion!
        if wasInFlight then
            wasInFlight = false
            CancelTouchdownTimer()
            touchdownTimer = C_Timer.After(TOUCHDOWN_DEBOUNCE_DELAY, function()
                touchdownTimer = nil
                if not IsMounted() or not CanSummon() then
                    return
                end
                if not C_PetJournal.GetSummonedPetGUID() then
                    addon:Summon()
                end
            end)
            return
        end

        -- While the 1.0s touchdown timer is running, absolutely NO summons!
        if touchdownTimer then
            return
        end

        -- Grounded mount steady-state check (only when grounded for > 1.0s)
        if not CanSummon() then
            return
        end
        if not C_PetJournal.GetSummonedPetGUID() then
            addon:Summon()
        end
    end)
end

addon.StartMountWatcher = StartMountWatcher
addon.StopMountWatcher = StopMountWatcher
addon.CancelTouchdownTimer = CancelTouchdownTimer
addon.CancelDismountTimer = CancelDismountTimer
addon.CancelAllPendingSummons = CancelAllPendingSummons

-- Grounded Mount Movement Hook (backup trigger when starting movement on a mount)
local function OnMovementStart()
    if not (SummonPetBigginsDB and SummonPetBigginsDB.enabled and SummonPetBigginsDB.summonWhileMounted) then
        return
    end
    if not IsMounted() or IsInFlightActive() or wasInFlight or touchdownTimer then
        return
    end
    if not CanSummon() then
        return
    end
    if C_PetJournal.GetSummonedPetGUID() then
        return
    end

    addon:Summon()
end

-- Core Summon Function (Zero-Garbage)
function addon:Summon()
    if not CanSummon() then
        return
    end

    local currentPet = C_PetJournal.GetSummonedPetGUID()
    local mode = SummonPetBigginsDB.mode or "FAVORITES"

    if mode == "PINNED" and SummonPetBigginsDB.pinnedPetGUID then
        if currentPet ~= SummonPetBigginsDB.pinnedPetGUID then
            C_PetJournal.SummonPetByGUID(SummonPetBigginsDB.pinnedPetGUID)
        end
        return
    end

    -- If already holding an active pet in Random or Favorites, do nothing
    if currentPet then
        return
    end

    if mode == "RANDOM" then
        C_PetJournal.SummonRandomPet(false)
    else
        -- Default: Random Favorite Companion
        C_PetJournal.SummonRandomPet(true)
    end
end

-- Core Dismiss Function (Debounced Safe Dismissal)
function addon:Dismiss(attempt)
    attempt = attempt or 1
    CancelAllPendingSummons()

    if not InCombatLockdown() then
        local currentPet = C_PetJournal.GetSummonedPetGUID()
        if currentPet then
            C_PetJournal.SummonPetByGUID(currentPet)
        end
    end

    -- Retry up to 3 times to catch pets delayed by unmounting or combat sync
    if attempt >= MAX_DISMISS_ATTEMPTS then
        return
    end

    C_Timer.After(DISMISS_RETRY_INTERVAL * attempt, function()
        local shouldDismiss = ShouldDismissInStealth() or ShouldDismissInCurrentInstance() or ShouldDismissMounted()
        if not shouldDismiss then
            return
        end

        local pet = C_PetJournal.GetSummonedPetGUID()
        if pet or InCombatLockdown() then
            addon:Dismiss(attempt + 1)
        end
    end)
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

-- Toggle Function (Triggered via Native Keybind or /summonpetb toggle)
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

-- Search for an owned pet by custom nickname or species name
local function FindPetByName(targetName)
    if not targetName or targetName == "" then return nil end
    local searchLower = targetName:lower()

    local numPets = C_PetJournal.GetNumPets()
    local matchedPetID, matchedDisplayName

    -- First pass: search current view (prioritizing custom nickname over species name)
    for i = 1, numPets do
        local petID, _, isOwned, customName, _, _, _, speciesName = C_PetJournal.GetPetInfoByIndex(i)
        if isOwned and petID then
            if customName and customName:lower() == searchLower then
                return petID, customName
            elseif speciesName and speciesName:lower() == searchLower and not matchedPetID then
                matchedPetID = petID
                matchedDisplayName = speciesName
            end
        end
    end

    if matchedPetID then
        return matchedPetID, matchedDisplayName
    end

    -- Second pass: if user had an active search/filter in Pet Journal, clear filter and retry
    if C_PetJournal.ClearSearchFilter then
        C_PetJournal.ClearSearchFilter()
        numPets = C_PetJournal.GetNumPets()
        for i = 1, numPets do
            local petID, _, isOwned, customName, _, _, _, speciesName = C_PetJournal.GetPetInfoByIndex(i)
            if isOwned and petID then
                if customName and customName:lower() == searchLower then
                    return petID, customName
                elseif speciesName and speciesName:lower() == searchLower and not matchedPetID then
                    matchedPetID = petID
                    matchedDisplayName = speciesName
                end
            end
        end
    end

    return matchedPetID, matchedDisplayName
end

-- Pin & Summon Pet by Name
function addon:PinPetByName(targetName)
    if not targetName or targetName:trim() == "" then
        return addon:PinCurrentPet()
    end

    targetName = targetName:trim():gsub('^["\']', ''):gsub('["\']$', '')
    local petID, displayName = FindPetByName(targetName)

    if not petID then
        PrintMsg("|cFFFF5555Could not find an owned companion pet named '|r" .. targetName .. "|cFFFF5555'.|r")
        return false
    end

    SummonPetBigginsDB.mode = "PINNED"
    SummonPetBigginsDB.pinnedPetGUID = petID
    SummonPetBigginsDB.pinnedPetName = displayName

    local currentPet = C_PetJournal.GetSummonedPetGUID()
    if CanSummon() then
        if currentPet ~= petID then
            C_PetJournal.SummonPetByGUID(petID)
        end
        PrintMsg("Pinned and summoned: |cFF00FF00" .. displayName .. "|r (Mode set to Pinned).")
    else
        local reason = "will summon when conditions allow"
        if IsStealthedActive() then
            reason = "will summon when exiting stealth"
        elseif IsInFlightActive() or IsMountedBlocked() then
            reason = "will summon upon landing / dismounting"
        elseif InCombatLockdown() then
            reason = "will summon after combat"
        elseif ShouldDismissInCurrentInstance() then
            reason = "will summon outside instance"
        end
        PrintMsg("Pinned: |cFF00FF00" .. displayName .. "|r (" .. reason .. ").")
    end

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

-- ==============================================================================
-- DEDICATED EVENT HANDLERS (Flat Guard Clauses, Zero-Allocation)
-- ==============================================================================

local function OnPlayerDismounted()
    StopMountWatcher()
    if ShouldDismissInStealth() then
        addon:Dismiss(1)
        return
    end

    -- Debounced dismount summon; tracked and immediately cancellable by UPDATE_STEALTH
    dismountTimer = C_Timer.After(DISMOUNT_DEBOUNCE_DELAY, function()
        dismountTimer = nil
        if IsMounted() or not CanSummon() then
            return
        end

        if IsInFlightActive() then
            dismountTimer = C_Timer.After(DISMOUNT_DEBOUNCE_DELAY, function()
                dismountTimer = nil
                if not IsMounted() and CanSummon() then
                    addon:Summon()
                end
            end)
            return
        end

        addon:Summon()
    end)
end

local function OnPlayerMounted()
    if not (SummonPetBigginsDB and SummonPetBigginsDB.summonWhileMounted) then
        addon:Dismiss(1)
        return
    end

    StartMountWatcher()
    C_Timer.After(0.3, function()
        if IsMounted() and CanSummon() then
            addon:Summon()
        end
    end)
end

local function OnMountDisplayChanged()
    CancelDismountTimer()
    if not IsMounted() then
        OnPlayerDismounted()
    else
        OnPlayerMounted()
    end
end

local function OnUpdateStealth()
    CancelAllPendingSummons()
    if IsStealthed() then
        if SummonPetBigginsDB and SummonPetBigginsDB.autoDismissInStealth then
            addon:Dismiss(1)
        end
        return
    end

    addon:Summon()
end

local function OnPlayerLogin(frameRef)
    -- Register game-state events
    frameRef:RegisterEvent("PLAYER_REGEN_ENABLED")         -- Left combat
    frameRef:RegisterEvent("PLAYER_MOUNT_DISPLAY_CHANGED") -- Mounted/Dismounted
    frameRef:RegisterEvent("UPDATE_STEALTH")               -- Stealthed/Unstealthed
    frameRef:RegisterEvent("PLAYER_ENTERING_WORLD")        -- Zone load
    frameRef:RegisterEvent("ZONE_CHANGED_NEW_AREA")        -- Zone/subzone transition
    frameRef:RegisterEvent("SCENARIO_UPDATE")              -- Scenario/Delve state change
    frameRef:RegisterEvent("CHALLENGE_MODE_START")         -- Mythic+ key started
    frameRef:RegisterEvent("CHALLENGE_MODE_COMPLETED")     -- Mythic+ key finished

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
end

local eventHandlers = {
    PLAYER_REGEN_ENABLED = function()
        if ShouldDismissInStealth() or ShouldDismissMounted() then
            addon:Dismiss(1)
        elseif CanSummon() then
            addon:Summon()
        end
    end,

    PLAYER_MOUNT_DISPLAY_CHANGED = OnMountDisplayChanged,

    UPDATE_STEALTH = OnUpdateStealth,

    CHALLENGE_MODE_START = function()
        if SummonPetBigginsDB and SummonPetBigginsDB.autoDismissInstances and SummonPetBigginsDB.dismissMPlus then
            addon:Dismiss(1)
        end
    end,

    CHALLENGE_MODE_COMPLETED = function()
        if CanSummon() then
            addon:Summon()
        end
    end,

    ZONE_CHANGED_NEW_AREA = function()
        if ShouldDismissInCurrentInstance() then
            addon:Dismiss(1)
        end
    end,

    SCENARIO_UPDATE = function()
        if ShouldDismissInCurrentInstance() then
            addon:Dismiss(1)
        end
    end,

    PLAYER_ENTERING_WORLD = function()
        if ShouldDismissInCurrentInstance() or ShouldDismissMounted() then
            addon:Dismiss(1)
            return
        end
        C_Timer.After(1.5, function()
            if ShouldDismissInCurrentInstance() or ShouldDismissMounted() then
                addon:Dismiss(1)
            else
                addon:Summon()
            end
        end)
    end,
}

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
        return
    end

    if event == "PLAYER_LOGIN" then
        OnPlayerLogin(self)
        return
    end

    local handler = eventHandlers[event]
    if handler then
        handler()
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
            if IsStealthedActive() then addon:Dismiss(1) end
        elseif not IsStealthedActive() then
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
    keybindNote:SetText("Keybinds: Game Menu -> Options -> Keybindings -> AddOns -> SummonPet Biggins\nSlash commands: /summonpetb (Type /summonpetb ? for available commands)")

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

-- Slash Commands (/summonpetb)
SLASH_SUMMONPETBIGGINS1 = "/summonpetb"
SlashCmdList["SUMMONPETBIGGINS"] = function(msg)
    local raw = msg and msg:trim() or ""
    local cmd, arg = raw:match("^(%S+)%s*(.*)$")
    cmd = cmd and cmd:lower() or ""
    arg = arg and arg:trim() or ""

    if cmd == "" or cmd == "options" or cmd == "config" or cmd == "menu" then
        addon:OpenSettings()
    elseif cmd == "toggle" then
        addon:Toggle()
    elseif cmd == "pin" then
        if arg ~= "" then
            addon:PinPetByName(arg)
        else
            addon:PinCurrentPet()
        end
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
    elseif cmd == "help" or cmd == "?" then
        PrintMsg("Commands:")
        print("  |cFFFFD100/summonpetb|r - Open settings panel")
        print("  |cFFFFD100/summonpetb toggle|r - Toggle companion auto-summoning on/off")
        print("  |cFFFFD100/summonpetb pin [name]|r - Pin current pet, or search and summon by name")
        print("  |cFFFFD100/summonpetb fav|r - Set mode to random favorites")
        print("  |cFFFFD100/summonpetb random|r - Set mode to completely random")
        print("  |cFFFFD100/summonpetb mount|r - Toggle companion summoning while mounted on ground")
        print("  |cFFFFD100/summonpetb options|r - Open settings panel")
        print("  |cFFFFD100/summonpetb status|r - Display current configuration")
        print("  |cFFFFD100/summonpetb help|r or |cFFFFD100/summonpetb ?|r - Show this list of commands")
    else
        PrintMsg("Unknown command '|cFFFFD100" .. cmd .. "|r'. Type |cFFFFD100/summonpetb help|r for available commands.")
    end
end
