--[[ ==============================================================================
    SafeRelease Biggins v1.0.0 - Release Spirit Guard (Raids, Dungeons & Delves)
    ------------------------------------------------------------------------------
    Author: Biggins (US-Whisperwind)
    Compatibility: World of Warcraft: Midnight / The War Within (Patch 11.x - 12.x)

    ARCHITECTURAL OVERVIEW:
    1. Zero-Taint Secure Frame Hooking: Hooks StaticPopup frames securely via
       hooksecurefunc without tampering with Blizzard protected frame scripts.
    2. Click-Interception Overlay: Places an inert, non-interactive overlay button
       directly on top of the native Release button during lockouts, making early
       release physically impossible even with high-frequency mouse spam.
    3. Multiple Guard Modes:
         - Countdown Delay: Visual countdown timer (1-10s) on the button.
         - Modifier Hold: Requires holding Alt, Shift, or Ctrl to release.
         - Hybrid: Visual countdown with an instant modifier-key bypass.
    4. Full Raid Wipe Detection: Automatically bypasses the guard if all group
       members are confirmed dead.
    5. Modern Blizzard Canvas UI: Integrated into Options -> AddOns -> Biggins AddOns -> SafeRelease
       with master enable toggle and top-right [ Defaults ] button.
============================================================================== ]]--

local addonName, addon = ...
_G["SafeReleaseBiggins"] = addon
addon.version = "1.0.0"

-- Upvalue caching
local CreateFrame     = CreateFrame
local GetInstanceInfo = GetInstanceInfo
local IsInInstance    = IsInInstance
local IsInRaid        = IsInRaid
local IsShiftKeyDown  = IsShiftKeyDown
local IsControlKeyDown = IsControlKeyDown
local IsAltKeyDown    = IsAltKeyDown
local UnitIsDeadOrGhost = UnitIsDeadOrGhost
local GetNumGroupMembers = GetNumGroupMembers
local UnitExists      = UnitExists

-- Configuration Defaults
local defaults = {
    enabled         = true,
    raids           = true,           -- Protect in Raids (LFR, Normal, Heroic, Mythic)
    dungeons        = false,          -- Protect in Dungeons (Normal, Heroic, Mythic 0)
    mythicPlus      = false,          -- Protect in Mythic+ Dungeons
    delves          = false,          -- Protect in Delves & Scenarios
    mode            = "COUNTDOWN",    -- "COUNTDOWN", "MODIFIER", "HYBRID"
    delaySeconds    = 5,              -- Countdown delay duration (1-10 seconds)
    modifierKey     = "ALT",          -- "ALT", "SHIFT", "CTRL"
    bypassFullWipe  = false,          -- Skip guard if all group members are dead (Default: OFF)
    announce        = true,           -- Echo settings changes to chat
}

-- UI Widget References for Dynamic Attenuation
local uiWidgets = {
    subControls    = {},
    modKeyControls = {},
    delayControls  = {},
}

-- Print formatted addon message
local function PrintMsg(msg)
    DEFAULT_CHAT_FRAME:AddMessage("|cFFFFD100SafeRelease Biggins:|r " .. msg)
end

-- ==============================================================================
-- 1. CONTEXT & STATE EVALUATION
-- ==============================================================================

local function IsModifierKeyDown(modKey)
    if modKey == "SHIFT" then
        return IsShiftKeyDown()
    elseif modKey == "CTRL" then
        return IsControlKeyDown()
    else
        return IsAltKeyDown()
    end
end

local function GetModifierDisplayName(modKey)
    if modKey == "SHIFT" then return "SHIFT" end
    if modKey == "CTRL"  then return "CTRL" end
    return "ALT"
end

-- Check if entire raid is dead (full wipe)
local function IsFullRaidWipe()
    if not IsInRaid() then return false end
    local num = GetNumGroupMembers()
    if not num or num == 0 then return false end

    for i = 1, num do
        local unit = "raid" .. i
        if UnitExists(unit) and not UnitIsDeadOrGhost(unit) then
            return false
        end
    end
    return true
end

-- Check if self-resurrect is ready (Ankh, Soulstone)
local function HasUsableSelfResurrect()
    if C_DeathInfo and C_DeathInfo.GetSelfResurrectOptions then
        local options = C_DeathInfo.GetSelfResurrectOptions()
        return (options and #options > 0)
    end
    return false
end

-- Evaluate whether the current zone/instance should be guarded
local function IsCurrentContextGuarded()
    local db = SafeReleaseBigginsDB or defaults
    if not db.enabled then return false end

    local inInstance, instanceType = IsInInstance()
    local _, _, difficultyID = GetInstanceInfo()

    if inInstance then
        if instanceType == "raid" then
            if db.bypassFullWipe and IsFullRaidWipe() then
                return false
            end
            return db.raids == true
        elseif instanceType == "party" then
            if difficultyID == 8 then -- Mythic+ Keystone
                return db.mythicPlus == true
            else
                return db.dungeons == true
            end
        elseif instanceType == "scenario" then
            return db.delves == true
        end
    end

    return false
end

-- ==============================================================================
-- 2. DEATH POPUP GUARD & OVERLAY ENGINE
-- ==============================================================================

local activePopup = nil
local countdownTimer = nil
local remainingSeconds = 0

local function GetPopupButton(popup, index)
    if popup.GetButton then
        return popup:GetButton(index)
    end
    return popup["button" .. index]
end

local function GetOrCreateOverlay(popup)
    if popup.srbOverlay then
        return popup.srbOverlay
    end

    local releaseBtn = GetPopupButton(popup, 1)
    if not releaseBtn then return nil end

    -- Overlay Button physically positioned on top of the Release button
    local overlay = CreateFrame("Button", nil, popup, "UIPanelButtonTemplate")
    overlay:SetAllPoints(releaseBtn)
    overlay:SetFrameLevel(releaseBtn:GetFrameLevel() + 5)
    overlay:Disable() -- Intercepts all clicks; does nothing

    popup.srbOverlay = overlay
    return overlay
end

local function ClearGuardState(popup)
    if countdownTimer then
        countdownTimer:Cancel()
        countdownTimer = nil
    end
    remainingSeconds = 0

    if popup and popup.srbOverlay then
        popup.srbOverlay:Hide()
    end

    if popup then
        local releaseBtn = GetPopupButton(popup, 1)
        if releaseBtn then
            releaseBtn:SetAlpha(1)
        end
    end
    activePopup = nil
end

local function UnlockRelease(popup)
    ClearGuardState(popup)
    if popup then
        local releaseBtn = GetPopupButton(popup, 1)
        if releaseBtn then
            releaseBtn:SetAlpha(1)
            releaseBtn:Enable()
        end
    end
end

local function UpdateCountdownDisplay(popup)
    if not popup or not popup.srbOverlay then return end
    local overlay = popup.srbOverlay
    local db = SafeReleaseBigginsDB or defaults
    local modName = GetModifierDisplayName(db.modifierKey)

    if db.mode == "HYBRID" then
        overlay:SetText(string.format("Hold %s (%ds)", modName, remainingSeconds))
    else
        overlay:SetText(string.format("Release (%ds)...", remainingSeconds))
    end

    -- If in HYBRID mode and modifier key is currently held, keep overlay hidden and release button active
    if db.mode == "HYBRID" and IsModifierKeyDown(db.modifierKey) then
        overlay:Hide()
        local releaseBtn = GetPopupButton(popup, 1)
        if releaseBtn then
            releaseBtn:SetAlpha(1)
            releaseBtn:Enable()
        end
    else
        overlay:Show()
    end
end

local function StartCountdown(popup)
    local db = SafeReleaseBigginsDB or defaults
    remainingSeconds = db.delaySeconds or 5
    local overlay = GetOrCreateOverlay(popup)
    if not overlay then return end

    local releaseBtn = GetPopupButton(popup, 1)
    local isDown = IsModifierKeyDown(db.modifierKey)

    if db.mode == "HYBRID" and isDown then
        overlay:Hide()
        if releaseBtn then
            releaseBtn:SetAlpha(1)
            releaseBtn:Enable()
        end
    else
        if releaseBtn then
            releaseBtn:SetAlpha(0)
        end
        UpdateCountdownDisplay(popup)
    end

    if countdownTimer then countdownTimer:Cancel() end
    countdownTimer = C_Timer.NewTicker(1, function()
        remainingSeconds = remainingSeconds - 1
        if remainingSeconds <= 0 then
            UnlockRelease(popup)
        else
            UpdateCountdownDisplay(popup)
        end
    end, remainingSeconds)
end

local function ApplyGuard(popup)
    if not popup or popup.which ~= "DEATH" then return end
    if not IsCurrentContextGuarded() then
        ClearGuardState(popup)
        return
    end

    -- If the player has a self-resurrect option (Ankh/Soulstone), let Blizzard handle it
    if HasUsableSelfResurrect() then
        ClearGuardState(popup)
        return
    end

    activePopup = popup
    local db = SafeReleaseBigginsDB or defaults
    local overlay = GetOrCreateOverlay(popup)
    if not overlay then return end

    local releaseBtn = GetPopupButton(popup, 1)
    local isDown = IsModifierKeyDown(db.modifierKey)
    local modName = GetModifierDisplayName(db.modifierKey)

    if db.mode == "MODIFIER" then
        if isDown then
            overlay:Hide()
            if releaseBtn then
                releaseBtn:SetAlpha(1)
                releaseBtn:Enable()
            end
        else
            overlay:Show()
            overlay:SetText(string.format("Hold %s", modName))
            if releaseBtn then releaseBtn:SetAlpha(0) end
        end
    elseif db.mode == "COUNTDOWN" then
        StartCountdown(popup)
    elseif db.mode == "HYBRID" then
        StartCountdown(popup)
    end
end

-- ==============================================================================
-- 3. EVENT LISTENER FRAME & STATIC POPUP HOOKS
-- ==============================================================================

local frame = CreateFrame("Frame")
frame:RegisterEvent("ADDON_LOADED")
frame:RegisterEvent("MODIFIER_STATE_CHANGED")
frame:RegisterEvent("PLAYER_REGEN_ENABLED")

frame:SetScript("OnEvent", function(self, event, ...)
    if event == "ADDON_LOADED" then
        local loaded = ...
        if loaded == addonName then
            if not SafeReleaseBigginsDB then
                SafeReleaseBigginsDB = {}
            end
            for k, v in pairs(defaults) do
                if SafeReleaseBigginsDB[k] == nil then
                    SafeReleaseBigginsDB[k] = v
                end
            end
            addon:RegisterOptions()
        end
    elseif event == "MODIFIER_STATE_CHANGED" then
        if activePopup and activePopup:IsShown() and activePopup.which == "DEATH" then
            local db = SafeReleaseBigginsDB or defaults
            if db.mode == "MODIFIER" or db.mode == "HYBRID" then
                local isDown = IsModifierKeyDown(db.modifierKey)
                local releaseBtn = GetPopupButton(activePopup, 1)
                local overlay = activePopup.srbOverlay
                local modName = GetModifierDisplayName(db.modifierKey)

                if isDown then
                    if overlay then
                        overlay:Hide()
                    end
                    if releaseBtn then
                        releaseBtn:SetAlpha(1)
                        releaseBtn:Enable()
                    end
                else
                    if db.mode == "MODIFIER" then
                        if overlay then
                            overlay:Show()
                            overlay:SetText(string.format("Hold %s", modName))
                        end
                        if releaseBtn then releaseBtn:SetAlpha(0) end
                    elseif db.mode == "HYBRID" then
                        if remainingSeconds > 0 then
                            if overlay then
                                overlay:Show()
                                UpdateCountdownDisplay(activePopup)
                            end
                            if releaseBtn then releaseBtn:SetAlpha(0) end
                        else
                            if overlay then overlay:Hide() end
                            if releaseBtn then releaseBtn:SetAlpha(1) end
                        end
                    end
                end
            end
        end
    elseif event == "PLAYER_REGEN_ENABLED" then
        -- Wipe check upon combat drop
        if activePopup and activePopup:IsShown() and activePopup.which == "DEATH" then
            local db = SafeReleaseBigginsDB or defaults
            if db.bypassFullWipe and IsFullRaidWipe() then
                UnlockRelease(activePopup)
            end
        end
    end
end)

-- Securely hook all 4 StaticPopup dialogs
for i = 1, 4 do
    local popup = _G["StaticPopup" .. i]
    if popup then
        hooksecurefunc(popup, "Show", function(self)
            if self and self.which == "DEATH" then
                ApplyGuard(self)
            end
        end)
        popup:HookScript("OnHide", function(self)
            if self and self.which == "DEATH" then
                ClearGuardState(self)
            end
        end)
    end
end

-- ==============================================================================
-- 4. BLIZZARD MODERN SETTINGS INTEGRATION (Canvas Layout)
-- ==============================================================================

function addon:UpdateOptionsUI()
    local db = SafeReleaseBigginsDB or defaults
    local isEnabled = db.enabled == true

    if uiWidgets.cbMaster then
        uiWidgets.cbMaster:SetChecked(isEnabled)
    end

    -- Dynamic control attenuation for subordinate options
    for _, widget in ipairs(uiWidgets.subControls) do
        if widget.SetEnabled then
            widget:SetEnabled(isEnabled)
        end
        if widget.EnableMouse then
            widget:EnableMouse(isEnabled)
        end
        if widget.SetAlpha then
            widget:SetAlpha(isEnabled and 1.0 or 0.4)
        end
    end

    if uiWidgets.cbRaids then uiWidgets.cbRaids:SetChecked(db.raids) end
    if uiWidgets.cbMPlus then uiWidgets.cbMPlus:SetChecked(db.mythicPlus) end
    if uiWidgets.cbDungeons then uiWidgets.cbDungeons:SetChecked(db.dungeons) end
    if uiWidgets.cbDelves then uiWidgets.cbDelves:SetChecked(db.delves) end
    if uiWidgets.cbFullWipe then uiWidgets.cbFullWipe:SetChecked(db.bypassFullWipe) end
    if uiWidgets.cbAnnounce then uiWidgets.cbAnnounce:SetChecked(db.announce) end

    -- Radio buttons for guard mode
    if uiWidgets.radioCountdown then uiWidgets.radioCountdown:SetChecked(db.mode == "COUNTDOWN") end
    if uiWidgets.radioModifier then uiWidgets.radioModifier:SetChecked(db.mode == "MODIFIER") end
    if uiWidgets.radioHybrid then uiWidgets.radioHybrid:SetChecked(db.mode == "HYBRID") end

    -- Radio buttons for modifier key
    local activeMod = db.modifierKey or "ALT"
    if uiWidgets.radioModAlt then uiWidgets.radioModAlt:SetChecked(activeMod == "ALT") end
    if uiWidgets.radioModShift then uiWidgets.radioModShift:SetChecked(activeMod == "SHIFT") end
    if uiWidgets.radioModCtrl then uiWidgets.radioModCtrl:SetChecked(activeMod == "CTRL") end

    -- Slider value label
    if uiWidgets.sliderDelay and uiWidgets.sliderDelayText then
        uiWidgets.sliderDelay:SetValue(db.delaySeconds or 5)
        uiWidgets.sliderDelayText:SetText(string.format("%d seconds", db.delaySeconds or 5))
    end

    -- Contextual dimming based on active guard mode
    local modControlsActive = isEnabled and (db.mode == "MODIFIER" or db.mode == "HYBRID")
    for _, widget in ipairs(uiWidgets.modKeyControls or {}) do
        if widget.SetEnabled then widget:SetEnabled(modControlsActive) end
        if widget.EnableMouse then widget:EnableMouse(modControlsActive) end
        if widget.SetAlpha then widget:SetAlpha(modControlsActive and 1.0 or 0.4) end
    end

    local delayControlsActive = isEnabled and (db.mode == "COUNTDOWN" or db.mode == "HYBRID")
    for _, widget in ipairs(uiWidgets.delayControls or {}) do
        if widget.SetEnabled then widget:SetEnabled(delayControlsActive) end
        if widget.EnableMouse then widget:EnableMouse(delayControlsActive) end
        if widget.SetAlpha then widget:SetAlpha(delayControlsActive and 1.0 or 0.4) end
    end
end

local function ResetAllToDefaults()
    if not SafeReleaseBigginsDB then SafeReleaseBigginsDB = {} end
    for k, v in pairs(defaults) do
        SafeReleaseBigginsDB[k] = v
    end
    addon:UpdateOptionsUI()
    PrintMsg("All options have been reset to default.")
end

function addon:RegisterOptions()
    local panel = CreateFrame("Frame", "SafeReleaseBigginsOptionsPanel", UIParent)
    panel.name = "SafeRelease Biggins"
    uiWidgets.panel = panel

    -- Title (Blizzard Gold)
    local title = panel:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
    title:SetPoint("TOPLEFT", 16, -16)
    title:SetText("|cFFFFD100SafeRelease Biggins|r")

    -- Subtitle
    local desc = panel:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
    desc:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -6)
    desc:SetText("Guards the Release Spirit button during wipes across raids, Mythic+ dungeons, and delves.\nNever blocks release in open world questing or unselected content.")

    -- Top-Right Defaults Button
    local btnDefaults = CreateFrame("Button", nil, panel, "UIPanelButtonTemplate")
    btnDefaults:SetPoint("TOPRIGHT", -24, -20)
    btnDefaults:SetSize(110, 22)
    btnDefaults:SetText("Defaults")
    btnDefaults:SetScript("OnClick", function()
        ResetAllToDefaults()
    end)
    btnDefaults:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:SetText("Restore default settings for SafeRelease Biggins.", 1, 1, 1, true)
        GameTooltip:Show()
    end)
    btnDefaults:SetScript("OnLeave", function() GameTooltip:Hide() end)

    -- Master Enable Checkbox
    local cbMaster = CreateFrame("CheckButton", nil, panel, "InterfaceOptionsCheckButtonTemplate")
    cbMaster:SetPoint("TOPLEFT", desc, "BOTTOMLEFT", -2, -14)
    cbMaster.Text:SetText("Enable SafeRelease Biggins")
    cbMaster.Text:SetFontObject("GameFontHighlight")
    cbMaster.tooltipText = "Master switch to enable or disable the release guard engine entirely."
    cbMaster:SetScript("OnClick", function(self)
        local val = self:GetChecked()
        SafeReleaseBigginsDB.enabled = val
        addon:UpdateOptionsUI()
        if SafeReleaseBigginsDB.announce then
            local status = val and "|cFF00FF00Enabled|r" or "|cFFFF0000Disabled|r"
            PrintMsg("SafeRelease is now " .. status .. ".")
        end
    end)
    cbMaster:SetScript("OnEnter", function(self)
        if self.tooltipText then
            GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
            GameTooltip:SetText(self.tooltipText, 1, 1, 1, true)
            GameTooltip:Show()
        end
    end)
    cbMaster:SetScript("OnLeave", function() GameTooltip:Hide() end)
    uiWidgets.cbMaster = cbMaster

    -- Section 1: Protected Content Scopes
    local scopeHeader = panel:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    scopeHeader:SetPoint("TOPLEFT", cbMaster, "BOTTOMLEFT", 2, -12)
    scopeHeader:SetText("Protected Content (Instance Scope):")
    table.insert(uiWidgets.subControls, scopeHeader)

    local function CreateSettingCheckbox(key, label, tooltip, anchorTo, x, y)
        local cb = CreateFrame("CheckButton", nil, panel, "InterfaceOptionsCheckButtonTemplate")
        cb:SetPoint("TOPLEFT", anchorTo, "BOTTOMLEFT", x, y)
        cb.Text:SetText(label)
        cb.Text:SetFontObject("GameFontHighlightSmall")
        cb.tooltipText = tooltip
        cb:SetScript("OnClick", function(self)
            SafeReleaseBigginsDB[key] = self:GetChecked()
            addon:UpdateOptionsUI()
        end)
        cb:SetScript("OnEnter", function(self)
            if self.tooltipText then
                GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
                GameTooltip:SetText(self.tooltipText, 1, 1, 1, true)
                GameTooltip:Show()
            end
        end)
        cb:SetScript("OnLeave", function() GameTooltip:Hide() end)
        table.insert(uiWidgets.subControls, cb)
        return cb
    end

    local cbRaids = CreateSettingCheckbox("raids", "Raids (LFR, Normal, Heroic, Mythic)", "Guard release during raid encounters and trash (Recommended).", scopeHeader, 4, -4)
    local cbMPlus = CreateSettingCheckbox("mythicPlus", "Mythic+ Dungeons", "Guard release inside Mythic Keystone dungeons.", cbRaids, 0, -2)
    local cbDungeons = CreateSettingCheckbox("dungeons", "Dungeons (Normal, Heroic, Mythic 0)", "Guard release in standard leveling, heroic, and Mythic 0 dungeons.", cbMPlus, 0, -2)
    local cbDelves = CreateSettingCheckbox("delves", "Delves & Scenarios", "Guard release inside Delves and story scenarios.", cbDungeons, 0, -2)

    uiWidgets.cbRaids = cbRaids
    uiWidgets.cbMPlus = cbMPlus
    uiWidgets.cbDungeons = cbDungeons
    uiWidgets.cbDelves = cbDelves

    -- Section 2: Guard Mode Selection
    local modeHeader = panel:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    modeHeader:SetPoint("TOPLEFT", cbDelves, "BOTTOMLEFT", 0, -14)
    modeHeader:SetText("Guard Mechanism:")
    table.insert(uiWidgets.subControls, modeHeader)

    local function CreateRadio(modeKey, label, tooltip, anchorTo, x, y)
        local rb = CreateFrame("CheckButton", nil, panel, "UIRadioButtonTemplate")
        rb:SetPoint("TOPLEFT", anchorTo, "BOTTOMLEFT", x, y)
        rb.text = panel:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
        rb.text:SetPoint("LEFT", rb, "RIGHT", 4, 1)
        rb.text:SetText(label)
        rb.tooltipText = tooltip
        rb:SetScript("OnClick", function()
            SafeReleaseBigginsDB.mode = modeKey
            addon:UpdateOptionsUI()
        end)
        if tooltip then
            rb:SetScript("OnEnter", function(self)
                GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
                GameTooltip:SetText(tooltip, 1, 1, 1, true)
                GameTooltip:Show()
            end)
            rb:SetScript("OnLeave", function() GameTooltip:Hide() end)
        end
        table.insert(uiWidgets.subControls, rb)
        table.insert(uiWidgets.subControls, rb.text)
        return rb
    end

    local radioCountdown = CreateRadio("COUNTDOWN", "Countdown Timer Delay (Hands-Free)", "Disables the Release button for a set number of seconds on death.", modeHeader, 4, -4)
    local radioModifier  = CreateRadio("MODIFIER", "Modifier-Key Hold (Hold key to reveal button)", "Hides and locks the Release button until Alt, Shift, or Ctrl is held down.", radioCountdown, 0, -4)
    local radioHybrid    = CreateRadio("HYBRID", "Hybrid (Countdown with instant Modifier bypass)", "Runs a countdown delay, but holding the modifier key immediately unlocks release.", radioModifier, 0, -4)

    uiWidgets.radioCountdown = radioCountdown
    uiWidgets.radioModifier  = radioModifier
    uiWidgets.radioHybrid    = radioHybrid

    -- Modifier Key Selection (Active for Modifier Hold & Hybrid modes)
    local modKeyLabel = panel:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
    modKeyLabel:SetPoint("TOPLEFT", radioHybrid, "BOTTOMLEFT", 16, -10)
    modKeyLabel:SetText("Modifier Key:")
    table.insert(uiWidgets.subControls, modKeyLabel)
    table.insert(uiWidgets.modKeyControls, modKeyLabel)

    local function CreateModKeyRadio(keyVal, label, anchorTo, x, y)
        local rb = CreateFrame("CheckButton", nil, panel, "UIRadioButtonTemplate")
        rb:SetPoint("LEFT", anchorTo, "RIGHT", x, y)
        rb.text = panel:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
        rb.text:SetPoint("LEFT", rb, "RIGHT", 4, 1)
        rb.text:SetText(label)
        rb.tooltipText = string.format("Require holding the %s key to unlock release.", label)
        rb:SetScript("OnClick", function()
            SafeReleaseBigginsDB.modifierKey = keyVal
            addon:UpdateOptionsUI()
            if SafeReleaseBigginsDB.announce then
                PrintMsg("Modifier key set to |cFF00FF00" .. keyVal .. "|r.")
            end
        end)
        rb:SetScript("OnEnter", function(self)
            if self.tooltipText then
                GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
                GameTooltip:SetText(self.tooltipText, 1, 1, 1, true)
                GameTooltip:Show()
            end
        end)
        rb:SetScript("OnLeave", function() GameTooltip:Hide() end)
        table.insert(uiWidgets.subControls, rb)
        table.insert(uiWidgets.subControls, rb.text)
        table.insert(uiWidgets.modKeyControls, rb)
        table.insert(uiWidgets.modKeyControls, rb.text)
        return rb
    end

    local radioModAlt   = CreateModKeyRadio("ALT", "Alt", modKeyLabel, 12, 0)
    local radioModShift = CreateModKeyRadio("SHIFT", "Shift", radioModAlt.text, 14, 0)
    local radioModCtrl  = CreateModKeyRadio("CTRL", "Ctrl", radioModShift.text, 14, 0)

    uiWidgets.radioModAlt   = radioModAlt
    uiWidgets.radioModShift = radioModShift
    uiWidgets.radioModCtrl  = radioModCtrl

    -- Delay Seconds Slider
    local slider = CreateFrame("Slider", "SafeReleaseDelaySlider", panel, "OptionsSliderTemplate")
    slider:SetPoint("TOPLEFT", modKeyLabel, "BOTTOMLEFT", 0, -22)
    slider:SetSize(180, 16)
    slider:SetMinMaxValues(1, 10)
    slider:SetValueStep(1)
    slider:SetObeyStepOnDrag(true)
    slider.Low:SetText("1s")
    slider.High:SetText("10s")
    slider.Text:SetText("Countdown Delay Duration")

    local sliderVal = panel:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
    sliderVal:SetPoint("LEFT", slider, "RIGHT", 14, 0)
    uiWidgets.sliderDelayText = sliderVal

    slider:SetScript("OnValueChanged", function(self, val)
        local v = math.floor(val + 0.5)
        SafeReleaseBigginsDB.delaySeconds = v
        sliderVal:SetText(string.format("%d seconds", v))
    end)
    slider:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:SetText("Duration in seconds that the Release Spirit button remains locked on death.", 1, 1, 1, true)
        GameTooltip:Show()
    end)
    slider:SetScript("OnLeave", function() GameTooltip:Hide() end)
    table.insert(uiWidgets.subControls, slider)
    table.insert(uiWidgets.subControls, sliderVal)
    table.insert(uiWidgets.delayControls, slider)
    table.insert(uiWidgets.delayControls, sliderVal)
    uiWidgets.sliderDelay = slider

    -- Section 3: Smart Overrides
    local cbFullWipe = CreateSettingCheckbox("bypassFullWipe", "Instant Unlock on Full Raid Wipe", "Immediately unlocks release if the entire raid group is confirmed dead.", slider, -16, -22)
    local cbAnnounce = CreateSettingCheckbox("announce", "Echo Settings Changes to Chat", nil, cbFullWipe, 0, -2)

    uiWidgets.cbFullWipe = cbFullWipe
    uiWidgets.cbAnnounce = cbAnnounce

    -- Help Note
    local helpNote = panel:CreateFontString(nil, "ARTWORK", "GameFontDisableSmall")
    helpNote:SetPoint("TOPLEFT", cbAnnounce, "BOTTOMLEFT", 0, -16)
    helpNote:SetText("Slash commands: /saferelease or /srb (toggle, countdown, modifier, hybrid, mod <alt|shift|ctrl>, delay <1-10>, raids, status, defaults)")

    panel:SetScript("OnShow", function()
        addon:UpdateOptionsUI()
    end)

    -- Register under Biggins AddOns suite category
    if LibBigginsSuite then
        addon.categoryID = LibBigginsSuite:RegisterSubcategory("SafeReleaseBiggins", panel, "SafeRelease")
    elseif Settings and Settings.RegisterCanvasLayoutCategory then
        local cat = Settings.RegisterCanvasLayoutCategory(panel, "SafeRelease Biggins")
        Settings.RegisterAddOnCategory(cat)
        addon.categoryID = cat:GetID()
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
        PrintMsg("Options available in Game Menu -> Options -> AddOns -> Biggins AddOns -> SafeRelease.")
    end
end

-- ==============================================================================
-- 5. SLASH COMMAND HANDLER (/saferelease, /srb)
-- ==============================================================================

local function SlashHandler(msg)
    local text = strtrim(msg or "")
    local cmd, arg = text:match("^(%S+)%s*(.*)$")
    cmd = string.lower(cmd or "")
    arg = string.lower(strtrim(arg or ""))
    local db = SafeReleaseBigginsDB or defaults

    if cmd == "" or cmd == "options" or cmd == "config" then
        addon:OpenSettings()
    elseif cmd == "toggle" then
        db.enabled = not db.enabled
        addon:UpdateOptionsUI()
        local status = db.enabled and "|cFF00FF00Enabled|r" or "|cFFFF0000Disabled|r"
        PrintMsg("Master release guard is now " .. status .. ".")
    elseif cmd == "countdown" or cmd == "timer" then
        db.mode = "COUNTDOWN"
        addon:UpdateOptionsUI()
        PrintMsg("Guard mode set to |cFF00FF00Countdown Timer|r.")
    elseif cmd == "modifier" or cmd == "mod" or cmd == "key" then
        if arg == "alt" or arg == "shift" or arg == "ctrl" then
            db.modifierKey = string.upper(arg)
            addon:UpdateOptionsUI()
            PrintMsg(string.format("Modifier key set to |cFF00FF00%s|r.", db.modifierKey))
        else
            db.mode = "MODIFIER"
            addon:UpdateOptionsUI()
            PrintMsg(string.format("Guard mode set to |cFF00FF00Modifier Hold (%s)|r. (Use |cFFFFD100/srb mod alt|shift|ctrl|r to change key)", GetModifierDisplayName(db.modifierKey)))
        end
    elseif cmd == "hybrid" then
        db.mode = "HYBRID"
        addon:UpdateOptionsUI()
        PrintMsg(string.format("Guard mode set to |cFF00FF00Hybrid (Countdown with %s bypass)|r.", GetModifierDisplayName(db.modifierKey)))
    elseif cmd == "delay" or cmd == "time" then
        local sec = tonumber(arg)
        if sec then
            sec = math.floor(math.max(1, math.min(10, sec)))
            db.delaySeconds = sec
            addon:UpdateOptionsUI()
            PrintMsg(string.format("Countdown delay set to |cFF00FF00%d seconds|r.", sec))
        else
            PrintMsg(string.format("Current countdown delay is |cFFFFD100%d seconds|r. Usage: |cFFFFD100/srb delay <1-10>|r", db.delaySeconds or 5))
        end
    elseif cmd == "raids" then
        db.raids = not db.raids
        addon:UpdateOptionsUI()
        local status = db.raids and "|cFF00FF00Enabled|r" or "|cFFFF0000Disabled|r"
        PrintMsg("Raid protection is now " .. status .. ".")
    elseif cmd == "defaults" or cmd == "reset" then
        ResetAllToDefaults()
    elseif cmd == "status" then
        local function ColorBool(val) return val and "|cFF00FF00[ON]|r" or "|cFFFF0000[OFF]|r" end
        PrintMsg("Current Configuration:")
        print(string.format("  Master Enable:   %s", ColorBool(db.enabled)))
        print(string.format("  Guard Mode:      |cFFFFD100%s|r", db.mode))
        print(string.format("  Delay Seconds:   |cFFFFD100%ds|r", db.delaySeconds or 5))
        print(string.format("  Modifier Key:    |cFFFFD100%s|r", GetModifierDisplayName(db.modifierKey)))
        print(string.format("  Raids Protected: %s", ColorBool(db.raids)))
        print(string.format("  M+ Protected:    %s", ColorBool(db.mythicPlus)))
        print(string.format("  Dungeons:        %s", ColorBool(db.dungeons)))
        print(string.format("  Delves/Scenarios:%s", ColorBool(db.delves)))
        print(string.format("  Full Wipe Bypass:%s", ColorBool(db.bypassFullWipe)))
        print(string.format("  Chat Feedback:   %s", ColorBool(db.announce)))
    else
        PrintMsg("Available commands: /srb [toggle | countdown | modifier | hybrid | mod <alt|shift|ctrl> | delay <1-10> | raids | status | defaults]")
    end
end

SLASH_SAFERELEASEBIGGINS1 = "/saferelease"
SLASH_SAFERELEASEBIGGINS2 = "/srb"
SlashCmdList["SAFERELEASEBIGGINS"] = SlashHandler
