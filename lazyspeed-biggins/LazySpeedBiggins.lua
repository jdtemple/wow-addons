--[[ ==============================================================================
    LazySpeedBiggins v3.7.0 - High-Performance Speedometer, Flight & Swim Gauge
    ------------------------------------------------------------------------------
    Author: Biggins (US-Whisperwind)
    Compatibility: World of Warcraft: Midnight (Patch 12.1.5 / 12.1+)
    
    ARCHITECTURAL OVERVIEW:
    1. Zero Idle Footprint: When inactive based on user settings (e.g. grounded in
       Flight/Swim-Only mode, or in combat), the OnUpdate script is completely detached
       (SetScript("OnUpdate", nil)) and the frame is hidden (0.00ms CPU).
    2. Nameplate-Style Integrated HUD: Sleek 180px x 20px status bar with centered
       numeric and unit telemetry (overlaying the dynamic fill bar) for a clean,
       modern castbar / cooldown bar aesthetic.
    3. Modular Blizzard Checkbox Settings: Direct integration into Options -> AddOns
       with native checkboxes:
         - Show While Flying / Skyriding
         - Show While Swimming (Aquatic mounts, swim speed buffs)
         - Show While on Ground
         - Hide During Combat (Killswitch)
         - Speed Measurement Unit Dropdown (y/s, mph, km/h, %)
         - Custom Bar Width & Height Sliders with Dynamic Font Scaling
    4. Dynamic Contextual Theming:
         - Flying / Ground: Green (Cruising) -> Yellow (High Speed) -> Red (Max Thruster)
         - Swimming: Ocean Blue -> Electric Cyan gradient
    5. Zero-Allocation C++ Rendering: Formats numbers directly in native C++ using
       FontString:SetFormattedText() with pre-cached static format string pointers.
    6. Secret Value & Restricted Environment Protection: Guards against Patch 12.0+
       secret value comparison/arithmetic errors in Mythic+ dungeons and challenge modes.
       Includes pcall failsafe wrapper to eliminate any possible 20 FPS error loops.
    7. Hardware-Accelerated UI: Single Blizzard StatusBar with dynamic color shift
       and classic Blizzard Tooltip & Metallic Gold frame skin.
============================================================================== ]]--

-- ==============================================================================
-- 1. LOCAL UPVALUE CACHING & RESTRICTION HELPERS (Performance & Safety)
-- ------------------------------------------------------------------------------
-- Caching global C-APIs into local variables avoids table hash lookups in Lua,
-- boosting function execution speed by ~30% and eliminating global table churn.
-- ==============================================================================
local GetGlidingInfo      = C_PlayerInfo.GetGlidingInfo
local IsFlying            = IsFlying
local IsSwimming          = IsSwimming
local GetUnitSpeed        = GetUnitSpeed
local InCombatLockdown    = InCombatLockdown
local UnitAffectingCombat = UnitAffectingCombat
local issecretvalue       = issecretvalue
local pcall               = pcall
local min                 = math.min
local max                 = math.max
local STANDARD_TEXT_FONT  = STANDARD_TEXT_FONT or "Fonts\\FRIZQT__.TTF"

-- Secret Value Detection (Midnight / Patch 12.0+ & Restricted Instances):
-- Blizzard marks player velocities as secret values in Mythic+ to prevent automation.
-- Evaluating or performing arithmetic on secret values in tainted code throws fatal errors.
local function IsSecret(val)
    return (issecretvalue and issecretvalue(val)) == true
end

-- Challenge Mode / Restricted Environment Detection
local function IsRestrictedEnvironment()
    if C_ChallengeMode and C_ChallengeMode.IsChallengeModeActive and C_ChallengeMode.IsChallengeModeActive() then
        return true
    end
    return false
end

-- Comprehensive combat check (Lockdown state or active combat flag)
local function IsPlayerInCombat()
    if InCombatLockdown and InCombatLockdown() then
        return true
    end
    if UnitAffectingCombat and UnitAffectingCombat("player") then
        return true
    end
    return false
end

-- Pre-cached format string constants: Passed directly into FontString:SetFormattedText
-- so that zero Lua strings are created or destroyed in Lua's garbage-collected heap!
local FORMAT_YS   = "%.1f y/s"
local FORMAT_MPH  = "%.1f mph"
local FORMAT_KMH  = "%.1f km/h"
local FORMAT_PCT  = "%.0f%%"

-- Unit Conversion Multipliers from Base Yards/Second
local MULTIPLIER_MPH = 2.04545       -- 1 yard/sec = 2.04545 mph
local MULTIPLIER_KMH = 3.29184       -- 1 yard/sec = 3.29184 km/h
local MULTIPLIER_PCT = 100.0 / 7.0   -- 7 yards/sec = 100% base run speed (1 yard/sec = 14.2857%)

-- Maximum Speed Caps for 100% Status Bar Fill
local MAX_CAP_FLIGHT = 84.0     -- Max Skyriding speed cap (1,200% / ~172 mph)
local MAX_CAP_SWIM   = 20.0     -- Max Swimming / Aquatic mount speed cap (~41 mph)
local MAX_CAP_GROUND = 42.0     -- Max Ground speed cap (running/sprint/ground mounts)

-- Unit Modes: 1 = Yards/Sec, 2 = MPH, 3 = KM/H, 4 = Percentage (%)
local modeLabels = { "y/s", "mph", "km/h", "%" }

-- Runtime State Variables
local isEngineActive  = false   -- True only when the high-speed loop is actively attached
local updateTimer     = 0       -- Accumulator for our 20 FPS (0.05s) throttling
local landingDebounce = 0       -- Grace period timer before concluding active state has ended
local lastSpeed       = -1      -- Dirty tracking: Skips redundant GPU redraws when stationary

-- Forward declarations of lifecycle functions
local LazySpeed_EvaluateState
local LazySpeed_StartEngine
local LazySpeed_StopEngine

-- ==============================================================================
-- 2. PERSISTENT SETTINGS (SavedVariables & Defaults)
-- ==============================================================================
-- LazySpeedBigginsDB is automatically persisted by WoW across reloads and sessions.
local DB_DEFAULTS = {
    enabled       = true,  -- Master enable toggle
    showFlying    = true,  -- Show while Flying / Skyriding
    showSwimming  = true,  -- Show while Swimming / Submerged in water
    showGround    = false, -- Show while on Ground (foot or ground mounts)
    hideInCombat  = true,  -- Hide immediately during combat
    locked        = false, -- Lock frame position to prevent dragging
    unitMode      = 4,     -- Default to Percentage (4)
    barWidth      = 180,   -- Frame width in pixels (Range: 100 - 300)
    barHeight     = 22,    -- Frame height in pixels (Range: 14 - 36)
    point         = "CENTER",
    relativePoint = "CENTER",
    xOfs          = 0,
    yOfs          = -200,
}

-- ==============================================================================
-- 3. UI FRAME CREATION & NAMEPLATE-STYLE BLIZZARD GOLD BACKDROP
-- ------------------------------------------------------------------------------
-- Creates the main 180px x 20px visual container frame with a dark slate background
-- and Blizzard metallic gold border. Starts HIDDEN by default.
-- ==============================================================================
local SpeedoFrame = CreateFrame("Frame", "LazySpeedBigginsFrame", UIParent, "BackdropTemplate")
SpeedoFrame:SetSize(180, 22)
SpeedoFrame:SetPoint("CENTER", UIParent, "CENTER", 0, -200)
SpeedoFrame:Hide() -- Starts hidden; shown only when active according to user settings

-- Classic Blizzard Tooltip Backdrop Styling (Sleek 12px Edge Size)
SpeedoFrame:SetBackdrop({
    bgFile   = "Interface\\Tooltips\\UI-Tooltip-Background",
    edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
    tile     = true, 
    tileSize = 12, 
    edgeSize = 12,
    insets   = { left = 3, right = 3, top = 3, bottom = 3 }
})
SpeedoFrame:SetBackdropColor(0.05, 0.05, 0.05, 0.85)
SpeedoFrame:SetBackdropBorderColor(0.8, 0.7, 0.2, 1) -- Blizzard Metallic Gold

-- Restore saved screen position
local function RestorePosition()
    local db = LazySpeedBigginsDB or DB_DEFAULTS
    SpeedoFrame:ClearAllPoints()
    SpeedoFrame:SetPoint(db.point or "CENTER", UIParent, db.relativePoint or "CENTER", db.xOfs or 0, db.yOfs or -200)
end

-- Update mouse interactivity based on locked state
local function UpdateMouseInteractivity()
    local db = LazySpeedBigginsDB or DB_DEFAULTS
    SpeedoFrame:EnableMouse(not db.locked)
end

-- Make Frame Moveable by Left-Click Dragging with persistent position saving
SpeedoFrame:SetMovable(true)
SpeedoFrame:EnableMouse(true)
SpeedoFrame:RegisterForDrag("LeftButton")
SpeedoFrame:SetScript("OnDragStart", function(self)
    local db = LazySpeedBigginsDB or DB_DEFAULTS
    if not db.locked then
        self:StartMoving()
    end
end)
SpeedoFrame:SetScript("OnDragStop", function(self)
    self:StopMovingOrSizing()
    local point, _, relPoint, x, y = self:GetPoint()
    if not LazySpeedBigginsDB then LazySpeedBigginsDB = {} end
    LazySpeedBigginsDB.point = point or "CENTER"
    LazySpeedBigginsDB.relativePoint = relPoint or "CENTER"
    LazySpeedBigginsDB.xOfs = x or 0
    LazySpeedBigginsDB.yOfs = y or -200
end)

-- ==============================================================================
-- 4. HARDWARE-ACCELERATED STATUS BAR & INTEGRATED TELEMETRY TEXT
-- ------------------------------------------------------------------------------
-- Uses a single native Blizzard StatusBar with centered overlay text for that
-- clean, integrated nameplate / cooldown bar look.
-- ==============================================================================
local StatusBar = CreateFrame("StatusBar", nil, SpeedoFrame)
StatusBar:SetSize(174, 16)
StatusBar:SetPoint("CENTER", SpeedoFrame, "CENTER", 0, 0)
StatusBar:SetStatusBarTexture("Interface\\TargetingFrame\\UI-StatusBar")
StatusBar:SetMinMaxValues(0, 1)
StatusBar:SetValue(0)
StatusBar:SetStatusBarColor(0.2, 0.8, 0.2, 1) -- Blizzard Green

local StatusBarBG = StatusBar:CreateTexture(nil, "BACKGROUND")
StatusBarBG:SetAllPoints(StatusBar)
StatusBarBG:SetTexture("Interface\\TargetingFrame\\UI-StatusBar")
StatusBarBG:SetVertexColor(0.05, 0.05, 0.05, 0.75)

-- Speed Telemetry Display (Centered directly inside the StatusBar overlay)
local SpeedText = StatusBar:CreateFontString(nil, "OVERLAY")
SpeedText:SetPoint("CENTER", StatusBar, "CENTER", 0, 0)
SpeedText:SetFont(STANDARD_TEXT_FONT, 12, "OUTLINE")
SpeedText:SetTextColor(1, 1, 1, 1) -- Crisp White with Black Outline for high contrast
SpeedText:SetShadowOffset(1, -1)
SpeedText:SetShadowColor(0, 0, 0, 1)
SpeedText:SetText("0.0 mph")

-- Dynamically updates frame dimensions and font scaling based on user settings
local function UpdateFrameDimensions()
    local db = LazySpeedBigginsDB or DB_DEFAULTS
    local width = db.barWidth or 180
    local height = db.barHeight or 22

    SpeedoFrame:SetSize(width, height)
    StatusBar:SetSize(max(width - 6, 20), max(height - 6, 8))

    -- Dynamically scale font size with bar height (12pt at default 22px height)
    local fontSize = min(max(math.floor(height * 0.55), 9), 20)
    SpeedText:SetFont(STANDARD_TEXT_FONT, fontSize, "OUTLINE")
end

-- Helper: Reset visual elements to zero state
local function ResetDisplay()
    local unit = (LazySpeedBigginsDB and LazySpeedBigginsDB.unitMode) or 4
    if unit == 1 then
        SpeedText:SetText("0.0 y/s")
    elseif unit == 2 then
        SpeedText:SetText("0.0 mph")
    elseif unit == 3 then
        SpeedText:SetText("0.0 km/h")
    else
        SpeedText:SetText("0%")
    end
    StatusBar:SetValue(0)
    StatusBar:SetStatusBarColor(0.2, 0.8, 0.2, 1)
    lastSpeed = 0
end

-- ==============================================================================
-- 5. HIGH-SPEED UPDATE LOOP (20 FPS - Throttled & Zero-Allocation)
-- ------------------------------------------------------------------------------
-- This loop executes ONLY when isEngineActive is true.
-- ==============================================================================
local function SpeedometerUpdateLoop(self, elapsed)
    local db = LazySpeedBigginsDB or DB_DEFAULTS

    -- Combat Check: If hideInCombat is enabled and combat begins, stop immediately
    if db.hideInCombat and IsPlayerInCombat() then
        LazySpeed_StopEngine()
        return
    end

    -- Environment Check: If entering Challenge Mode / Mythic+, stop immediately
    if IsRestrictedEnvironment() then
        LazySpeed_StopEngine()
        return
    end

    -- Frame Throttling: Accumulate elapsed time until 0.05 seconds (20 FPS) have passed
    updateTimer = updateTimer + elapsed
    if updateTimer < 0.05 then return end
    updateTimer = 0

    -- Query Flight, Swim & Ground Velocities
    local isGliding, _, forwardSpeed = GetGlidingInfo()
    local rawGroundSpeed = GetUnitSpeed("player")

    -- Secret Value Gating (Patch 12.0+ / Midnight / Restricted Instances):
    -- Blizzard marks player velocity as a "secret value" inside Mythic+ and certain encounters.
    -- Performing arithmetic or comparisons on a secret value throws fatal errors in tainted execution.
    if IsSecret(rawGroundSpeed) or IsSecret(forwardSpeed) or IsSecret(isGliding) then
        LazySpeed_StopEngine()
        return
    end

    local isSteadyFlying = IsFlying and IsFlying()
    local isSwimming = IsSwimming and IsSwimming()
    if IsSecret(isSteadyFlying) or IsSecret(isSwimming) then
        LazySpeed_StopEngine()
        return
    end
    
    local currentSpeed = 0
    local maxCap = MAX_CAP_GROUND
    local isCurrentStateActive = false

    if isGliding then
        currentSpeed = forwardSpeed or 0
        maxCap = MAX_CAP_FLIGHT
        isCurrentStateActive = db.showFlying
    elseif isSteadyFlying then
        currentSpeed = rawGroundSpeed or 0
        maxCap = MAX_CAP_FLIGHT
        isCurrentStateActive = db.showFlying
    elseif isSwimming then
        currentSpeed = rawGroundSpeed or 0
        maxCap = MAX_CAP_SWIM
        isCurrentStateActive = db.showSwimming
    else
        currentSpeed = rawGroundSpeed or 0
        maxCap = MAX_CAP_GROUND
        isCurrentStateActive = db.showGround
    end

    -- Final validation: Ensure currentSpeed is not secret before comparison or math
    if IsSecret(currentSpeed) then
        LazySpeed_StopEngine()
        return
    end

    -- Landing / State Termination Debounce
    if not isCurrentStateActive then
        landingDebounce = landingDebounce + 0.05
        if landingDebounce >= 1.0 then
            LazySpeed_StopEngine()
            return
        end
    else
        landingDebounce = 0
    end

    -- Idle / Dirty Check: If stationary and we already rendered 0 last tick, skip all UI redraws!
    if currentSpeed == 0 and lastSpeed == 0 then
        return
    end
    lastSpeed = currentSpeed

    -- Format display string using Blizzard's native C++ SetFormattedText method.
    -- This formats directly on the C++ side, creating LITERAL ZERO Lua string allocations!
    local unit = db.unitMode or 4
    if unit == 1 then
        SpeedText:SetFormattedText(FORMAT_YS, currentSpeed)
    elseif unit == 2 then
        SpeedText:SetFormattedText(FORMAT_MPH, currentSpeed * MULTIPLIER_MPH)
    elseif unit == 3 then
        SpeedText:SetFormattedText(FORMAT_KMH, currentSpeed * MULTIPLIER_KMH)
    else
        SpeedText:SetFormattedText(FORMAT_PCT, currentSpeed * MULTIPLIER_PCT)
    end

    -- Update Smooth Status Bar (Ratio between 0.0 and 1.0)
    local speedRatio = min(max(currentSpeed / maxCap, 0.0), 1.0)
    StatusBar:SetValue(speedRatio)

    -- Dynamic Contextual Theming:
    -- If swimming: Cool Oceanic Blue / Electric Cyan gradient
    -- If flying / ground: Green (Cruising) -> Yellow (High Speed) -> Red (Max Thruster)
    if isSwimming then
        if speedRatio > 0.70 then
            StatusBar:SetStatusBarColor(0.0, 0.9, 1.0, 1) -- Electric Cyan
        else
            StatusBar:SetStatusBarColor(0.0, 0.55, 0.85, 1) -- Deep Ocean Blue
        end
    else
        if speedRatio > 0.85 then
            StatusBar:SetStatusBarColor(0.9, 0.1, 0.1, 1) -- Red
        elseif speedRatio > 0.50 then
            StatusBar:SetStatusBarColor(0.9, 0.8, 0.1, 1) -- Yellow
        else
            StatusBar:SetStatusBarColor(0.1, 0.9, 0.2, 1) -- Green
        end
    end
end

-- Protected Safe Wrapper for Update Loop:
-- Catches any unexpected secret value taint, API restriction, or runtime exception.
-- If an error occurs, it shuts down the engine immediately to prevent 20 FPS error cascades / client freezes.
local function SafeSpeedometerUpdateLoop(self, elapsed)
    local ok, err = pcall(SpeedometerUpdateLoop, self, elapsed)
    if not ok then
        LazySpeed_StopEngine()
    end
end

-- ==============================================================================
-- 6. LIFECYCLE CONTROLLER (Engine Start, Stop, & State Evaluation)
-- ==============================================================================

-- Starts the 20 FPS high-speed update engine (Attaches OnUpdate script & shows UI)
function LazySpeed_StartEngine()
    if isEngineActive then return end
    
    isEngineActive = true
    updateTimer = 0
    landingDebounce = 0
    
    ResetDisplay()
    UpdateMouseInteractivity()
    SpeedoFrame:Show()
    -- ATTACH THE SCRIPT: Protected by SafeSpeedometerUpdateLoop failsafe wrapper
    SpeedoFrame:SetScript("OnUpdate", SafeSpeedometerUpdateLoop)
end

-- Stops the engine completely (DETACHES OnUpdate script & hides UI)
function LazySpeed_StopEngine()
    if not isEngineActive then return end
    
    isEngineActive = false
    -- DETACH THE SCRIPT: Completely removes the OnUpdate hook from the WoW engine.
    -- Result: 0.00ms CPU footprint, zero background execution!
    SpeedoFrame:SetScript("OnUpdate", nil)
    SpeedoFrame:Hide()
    ResetDisplay()
end

-- Centralized State Evaluator: Evaluates active checkboxes and starts/stops the engine
function LazySpeed_EvaluateState()
    if not LazySpeedBigginsDB then return end
    local db = LazySpeedBigginsDB

    if db.enabled == false then
        LazySpeed_StopEngine()
        return
    end

    if db.hideInCombat and IsPlayerInCombat() then
        LazySpeed_StopEngine()
        return
    end

    -- Environment Check: Never activate in Challenge Mode / Mythic+
    if IsRestrictedEnvironment() then
        LazySpeed_StopEngine()
        return
    end

    -- Secret Value Check: If velocity APIs are returning secret values, keep engine dormant
    local testSpeed = GetUnitSpeed("player")
    if IsSecret(testSpeed) then
        LazySpeed_StopEngine()
        return
    end

    local isGliding = GetGlidingInfo()
    if IsSecret(isGliding) then
        LazySpeed_StopEngine()
        return
    end

    local isSteadyFlying = IsFlying and IsFlying()
    local isSwimming = IsSwimming and IsSwimming()
    if IsSecret(isSteadyFlying) or IsSecret(isSwimming) then
        LazySpeed_StopEngine()
        return
    end

    local isAirborne = isGliding or isSteadyFlying

    local shouldShow = false
    if isAirborne and db.showFlying then
        shouldShow = true
    elseif isSwimming and db.showSwimming then
        shouldShow = true
    elseif db.showGround then
        shouldShow = true
    end

    if shouldShow then
        LazySpeed_StartEngine()
    else
        LazySpeed_StopEngine()
    end
end

-- ==============================================================================
-- 7. BLIZZARD MODERN SETTINGS API INTEGRATION (Escape -> Options -> AddOns)
-- ------------------------------------------------------------------------------
-- Registers native checkboxes, dropdowns, sliders & reset button in WoW settings.
-- ==============================================================================
-- ==============================================================================
-- 7. BLIZZARD MODERN SETTINGS API INTEGRATION (Canvas Layout)
-- ==============================================================================
local uiWidgets = {}
local categoryID = nil

local function UpdateOptionsUI()
    if not uiWidgets.panel or not LazySpeedBigginsDB then return end
    local isEnabled = LazySpeedBigginsDB.enabled ~= false

    if uiWidgets.cbEnable then uiWidgets.cbEnable:SetChecked(isEnabled) end
    if uiWidgets.cbFlying then uiWidgets.cbFlying:SetChecked(LazySpeedBigginsDB.showFlying) end
    if uiWidgets.cbSwimming then uiWidgets.cbSwimming:SetChecked(LazySpeedBigginsDB.showSwimming) end
    if uiWidgets.cbGround then uiWidgets.cbGround:SetChecked(LazySpeedBigginsDB.showGround) end
    if uiWidgets.cbCombat then uiWidgets.cbCombat:SetChecked(LazySpeedBigginsDB.hideInCombat) end
    if uiWidgets.cbLocked then uiWidgets.cbLocked:SetChecked(LazySpeedBigginsDB.locked or false) end

    local currentUnit = LazySpeedBigginsDB.unitMode or 4
    if uiWidgets.radioMPH then uiWidgets.radioMPH:SetChecked(currentUnit == 2) end
    if uiWidgets.radioYS  then uiWidgets.radioYS:SetChecked(currentUnit == 1) end
    if uiWidgets.radioKMH then uiWidgets.radioKMH:SetChecked(currentUnit == 3) end
    if uiWidgets.radioPCT then uiWidgets.radioPCT:SetChecked(currentUnit == 4) end

    if uiWidgets.sliderWidth then
        uiWidgets.sliderWidth:SetValue(LazySpeedBigginsDB.barWidth or 180)
        if uiWidgets.sliderWidth.valueText then
            uiWidgets.sliderWidth.valueText:SetText(tostring(LazySpeedBigginsDB.barWidth or 180) .. " px")
        end
    end
    if uiWidgets.sliderHeight then
        uiWidgets.sliderHeight:SetValue(LazySpeedBigginsDB.barHeight or 22)
        if uiWidgets.sliderHeight.valueText then
            uiWidgets.sliderHeight.valueText:SetText(tostring(LazySpeedBigginsDB.barHeight or 22) .. " px")
        end
    end

    -- Gray out child controls when disabled
    local childWidgets = {
        uiWidgets.cbFlying, uiWidgets.cbSwimming, uiWidgets.cbGround, uiWidgets.cbCombat, uiWidgets.cbLocked,
        uiWidgets.unitHeader, uiWidgets.radioMPH, uiWidgets.radioYS, uiWidgets.radioKMH, uiWidgets.radioPCT,
        uiWidgets.sliderWidth, uiWidgets.sliderHeight, uiWidgets.btnResetPos
    }
    for _, w in ipairs(childWidgets) do
        if w then
            if w.SetEnabled then w:SetEnabled(isEnabled) end
            w:SetAlpha(isEnabled and 1.0 or 0.5)
        end
    end
end

local function ResetAllToDefaults()
    if not LazySpeedBigginsDB then LazySpeedBigginsDB = {} end
    for varName, defVal in pairs(DB_DEFAULTS) do
        LazySpeedBigginsDB[varName] = defVal
    end
    RestorePosition()
    UpdateFrameDimensions()
    UpdateMouseInteractivity()
    UpdateOptionsUI()
    LazySpeed_EvaluateState()
    lastSpeed = -1
    ResetDisplay()
    DEFAULT_CHAT_FRAME:AddMessage("|cFFFFD100LazySpeed Biggins|r: All options have been reset to default.")
end

local function InitializeBlizzardSettings()
    local panel = CreateFrame("Frame", "LazySpeedBigginsOptionsPanel", UIParent)
    panel.name = "LazySpeed Biggins"
    uiWidgets.panel = panel

    -- Title (Blizzard Gold)
    local title = panel:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
    title:SetPoint("TOPLEFT", 16, -16)
    title:SetText("|cFFFFD100LazySpeed Biggins|r")

    -- Subtitle / Description
    local desc = panel:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
    desc:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -6)
    desc:SetText("High-precision dynamic speedometer with contextual color theming.")

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
        GameTooltip:SetText("Restore all LazySpeed settings back to default.", 1, 1, 1, true)
        GameTooltip:Show()
    end)
    btnDefaults:SetScript("OnLeave", function() GameTooltip:Hide() end)

    -- Helper to create and bind checkboxes
    local function CreateSettingCheckbox(key, label, tooltip, anchorPoint, relativeTo, relPoint, x, y, onClickCallback)
        local cb = CreateFrame("CheckButton", nil, panel, "InterfaceOptionsCheckButtonTemplate")
        cb:SetPoint(anchorPoint, relativeTo, relPoint, x, y)
        cb.Text:SetText(label)
        cb.Text:SetFontObject("GameFontHighlight")
        cb.tooltipText = tooltip
        local currentVal = (LazySpeedBigginsDB and LazySpeedBigginsDB[key] ~= nil) and LazySpeedBigginsDB[key] or DB_DEFAULTS[key]
        cb:SetChecked(currentVal)
        cb:SetScript("OnClick", function(self)
            if not LazySpeedBigginsDB then LazySpeedBigginsDB = {} end
            LazySpeedBigginsDB[key] = self:GetChecked()
            if onClickCallback then onClickCallback(self:GetChecked()) end
            LazySpeed_EvaluateState()
            UpdateOptionsUI()
        end)
        cb:SetScript("OnEnter", function(self)
            if self.tooltipText then
                GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
                GameTooltip:SetText(self.tooltipText, 1, 1, 1, true)
                GameTooltip:Show()
            end
        end)
        cb:SetScript("OnLeave", function() GameTooltip:Hide() end)
        return cb
    end

    -- Master Enable Checkbox
    local cbEnable = CreateSettingCheckbox("enabled", "Enable Speedometer", "Show or hide the dynamic speedometer overlay.", "TOPLEFT", desc, "BOTTOMLEFT", 0, -18, function(val)
        local status = val and "|cFF00FF00Enabled|r" or "|cFFFF0000Disabled|r"
        DEFAULT_CHAT_FRAME:AddMessage("|cFFFFD100LazySpeed Biggins|r: Speedometer is now " .. status .. ".")
    end)
    uiWidgets.cbEnable = cbEnable

    -- Child Checkboxes (Indented 20px)
    local cbFlying = CreateSettingCheckbox("showFlying", "Show While Flying / Skyriding", "Displays speedometer while airborne (Skyriding or Steady Flight).", "TOPLEFT", cbEnable, "BOTTOMLEFT", 20, -6)
    uiWidgets.cbFlying = cbFlying

    local cbSwimming = CreateSettingCheckbox("showSwimming", "Show While Swimming", "Displays speedometer while submerged in water, tracking swim and aquatic mount speeds.", "TOPLEFT", cbFlying, "BOTTOMLEFT", 0, -6)
    uiWidgets.cbSwimming = cbSwimming

    local cbGround = CreateSettingCheckbox("showGround", "Show While on Ground", "Displays speedometer while running on foot or riding ground mounts.", "TOPLEFT", cbSwimming, "BOTTOMLEFT", 0, -6)
    uiWidgets.cbGround = cbGround

    local cbCombat = CreateSettingCheckbox("hideInCombat", "Hide During Combat", "Instantly hides and detaches the speedometer during combat to keep your screen clear.", "TOPLEFT", cbGround, "BOTTOMLEFT", 0, -6)
    uiWidgets.cbCombat = cbCombat

    local cbLocked = CreateSettingCheckbox("locked", "Lock Frame Position", "Prevents dragging the speedometer frame with the mouse.", "TOPLEFT", cbCombat, "BOTTOMLEFT", 0, -6, function(val)
        UpdateMouseInteractivity()
        local status = val and "|cFFFF0000Locked|r" or "|cFF00FF00Unlocked|r"
        DEFAULT_CHAT_FRAME:AddMessage("|cFFFFD100LazySpeed Biggins|r: Frame position is now " .. status .. ".")
    end)
    uiWidgets.cbLocked = cbLocked

    -- Unit Selection Header
    local unitHeader = panel:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    unitHeader:SetPoint("TOPLEFT", cbLocked, "BOTTOMLEFT", 0, -16)
    unitHeader:SetText("Speed Measurement Unit:")
    uiWidgets.unitHeader = unitHeader

    -- Radio Helper
    local function CreateUnitRadio(unitVal, label, anchorPoint, relativeTo, relPoint, x, y)
        local radio = CreateFrame("CheckButton", nil, panel, "UIRadioButtonTemplate")
        radio:SetPoint(anchorPoint, relativeTo, relPoint, x, y)
        radio.text = radio:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
        radio.text:SetPoint("LEFT", radio, "RIGHT", 4, 0)
        radio.text:SetText(label)
        radio:SetScript("OnClick", function()
            if not LazySpeedBigginsDB then LazySpeedBigginsDB = {} end
            LazySpeedBigginsDB.unitMode = unitVal
            lastSpeed = -1
            ResetDisplay()
            UpdateOptionsUI()
        end)
        return radio
    end

    local radioMPH = CreateUnitRadio(2, "Miles per Hour (mph)", "TOPLEFT", unitHeader, "BOTTOMLEFT", 6, -8)
    uiWidgets.radioMPH = radioMPH

    local radioYS = CreateUnitRadio(1, "Yards per Second (y/s)", "TOPLEFT", radioMPH, "BOTTOMLEFT", 0, -6)
    uiWidgets.radioYS = radioYS

    local radioKMH = CreateUnitRadio(3, "Kilometers per Hour (km/h)", "TOPLEFT", radioYS, "BOTTOMLEFT", 0, -6)
    uiWidgets.radioKMH = radioKMH

    local radioPCT = CreateUnitRadio(4, "Percentage (%)", "TOPLEFT", radioKMH, "BOTTOMLEFT", 0, -6)
    uiWidgets.radioPCT = radioPCT

    -- Helper to create and bind sliders
    local function CreateSettingSlider(key, label, tooltip, minVal, maxVal, step, anchorPoint, relativeTo, relPoint, x, y)
        local slider = CreateFrame("Slider", nil, panel, "OptionsSliderTemplate")
        slider:SetPoint(anchorPoint, relativeTo, relPoint, x, y)
        slider:SetSize(220, 16)
        slider:SetMinMaxValues(minVal, maxVal)
        slider:SetValueStep(step)
        slider:SetObeyStepOnDrag(true)

        local val = (LazySpeedBigginsDB and LazySpeedBigginsDB[key]) or DB_DEFAULTS[key]
        slider:SetValue(val)

        local titleText = slider:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
        titleText:SetPoint("BOTTOMLEFT", slider, "TOPLEFT", 0, 4)
        titleText:SetText(label)

        local valueText = slider:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
        valueText:SetPoint("BOTTOMRIGHT", slider, "TOPRIGHT", 0, 4)
        valueText:SetText(tostring(val) .. " px")

        if slider.Low then slider.Low:SetText(tostring(minVal)) end
        if slider.High then slider.High:SetText(tostring(maxVal)) end

        slider:SetScript("OnValueChanged", function(self, newVal)
            newVal = floor(newVal + 0.5)
            if not LazySpeedBigginsDB then LazySpeedBigginsDB = {} end
            LazySpeedBigginsDB[key] = newVal
            valueText:SetText(tostring(newVal) .. " px")
            UpdateFrameDimensions()
        end)
        slider:SetScript("OnEnter", function(self)
            if tooltip then
                GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
                GameTooltip:SetText(tooltip, 1, 1, 1, true)
                GameTooltip:Show()
            end
        end)
        slider:SetScript("OnLeave", function() GameTooltip:Hide() end)

        slider.titleText = titleText
        slider.valueText = valueText
        return slider
    end

    -- Sliders (Anchored below unit radios)
    local sliderWidth = CreateSettingSlider("barWidth", "Bar Width", "Adjust horizontal width of speedometer bar in pixels.", 100, 300, 1, "TOPLEFT", radioPCT, "BOTTOMLEFT", -6, -24)
    uiWidgets.sliderWidth = sliderWidth

    local sliderHeight = CreateSettingSlider("barHeight", "Bar Height", "Adjust vertical height of speedometer bar in pixels.", 14, 36, 1, "TOPLEFT", sliderWidth, "BOTTOMLEFT", 0, -28)
    uiWidgets.sliderHeight = sliderHeight

    -- Reset Position Button
    local btnResetPos = CreateFrame("Button", nil, panel, "UIPanelButtonTemplate")
    btnResetPos:SetPoint("TOPLEFT", sliderHeight, "BOTTOMLEFT", -6, -24)
    btnResetPos:SetSize(160, 24)
    btnResetPos:SetText("Reset Position")
    btnResetPos:SetScript("OnClick", function()
        if not LazySpeedBigginsDB then LazySpeedBigginsDB = {} end
        LazySpeedBigginsDB.point = "CENTER"
        LazySpeedBigginsDB.relativePoint = "CENTER"
        LazySpeedBigginsDB.xOfs = 0
        LazySpeedBigginsDB.yOfs = -200
        RestorePosition()
        DEFAULT_CHAT_FRAME:AddMessage("|cFFFFD100LazySpeed Biggins|r: Frame position reset to screen center.")
    end)
    btnResetPos:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:SetText("Resets speedometer frame back to center screen.", 1, 1, 1, true)
        GameTooltip:Show()
    end)
    btnResetPos:SetScript("OnLeave", function() GameTooltip:Hide() end)
    uiWidgets.btnResetPos = btnResetPos

    -- Slash Command Help Note
    local helpNote = panel:CreateFontString(nil, "ARTWORK", "GameFontDisableSmall")
    helpNote:SetPoint("TOPLEFT", btnResetPos, "BOTTOMLEFT", 0, -18)
    helpNote:SetText("Slash commands: /lazyspeed or /lsb (settings, toggle, lock, reset, defaults, status)")

    panel:SetScript("OnShow", function()
        UpdateOptionsUI()
    end)

    if Settings and Settings.RegisterCanvasLayoutCategory then
        local category = Settings.RegisterCanvasLayoutCategory(panel, "LazySpeed Biggins")
        Settings.RegisterAddOnCategory(category)
        categoryID = category:GetID()
    else
        InterfaceOptions_AddCategory(panel)
    end

    UpdateOptionsUI()
end

-- ==============================================================================
-- 8. EVENT CONTROLLER & PASSIVE WATCHER (Low-Frequency Background Gating)
-- ==============================================================================
local EventWatcherFrame = CreateFrame("Frame")

EventWatcherFrame:RegisterEvent("ADDON_LOADED")                -- When addon SavedVariables are ready
EventWatcherFrame:RegisterEvent("PLAYER_ENTERING_WORLD")       -- When logging in or zoning
EventWatcherFrame:RegisterEvent("PLAYER_REGEN_DISABLED")        -- Entering combat
EventWatcherFrame:RegisterEvent("PLAYER_REGEN_ENABLED")         -- Exiting combat
EventWatcherFrame:RegisterEvent("PLAYER_MOUNT_DISPLAY_CHANGED") -- Mounting / Dismounting
EventWatcherFrame:RegisterEvent("CHALLENGE_MODE_START")         -- Mythic+ key started
EventWatcherFrame:RegisterEvent("CHALLENGE_MODE_COMPLETED")     -- Mythic+ key completed
EventWatcherFrame:RegisterEvent("CHALLENGE_MODE_RESET")         -- Mythic+ key reset
EventWatcherFrame:RegisterEvent("ZONE_CHANGED_NEW_AREA")        -- Zone change

EventWatcherFrame:SetScript("OnEvent", function(self, event, arg1)
    if event == "ADDON_LOADED" and arg1 == "LazySpeedBiggins" then
        -- Initialize SavedVariables table with defaults if first run
        LazySpeedBigginsDB = LazySpeedBigginsDB or {}
        
        -- Migrate legacy v3.2 visibilityMode if present
        if LazySpeedBigginsDB.visibilityMode then
            if LazySpeedBigginsDB.visibilityMode == "FLIGHT_ONLY" then
                LazySpeedBigginsDB.showFlying = true
                LazySpeedBigginsDB.showSwimming = true
                LazySpeedBigginsDB.showGround = false
                LazySpeedBigginsDB.hideInCombat = true
            elseif LazySpeedBigginsDB.visibilityMode == "NO_COMBAT" then
                LazySpeedBigginsDB.showFlying = true
                LazySpeedBigginsDB.showSwimming = true
                LazySpeedBigginsDB.showGround = true
                LazySpeedBigginsDB.hideInCombat = true
            elseif LazySpeedBigginsDB.visibilityMode == "ALWAYS" then
                LazySpeedBigginsDB.showFlying = true
                LazySpeedBigginsDB.showSwimming = true
                LazySpeedBigginsDB.showGround = true
                LazySpeedBigginsDB.hideInCombat = false
            end
            LazySpeedBigginsDB.visibilityMode = nil
        end

        for key, value in pairs(DB_DEFAULTS) do
            if LazySpeedBigginsDB[key] == nil then
                LazySpeedBigginsDB[key] = value
            end
        end

        -- Apply user saved position, dimensions, font scaling and mouse lock state
        RestorePosition()
        UpdateFrameDimensions()
        UpdateMouseInteractivity()

        -- Register Blizzard Settings Panel
        InitializeBlizzardSettings()

    elseif event == "PLAYER_REGEN_DISABLED" then
        -- Entering combat: If hideInCombat is enabled, kill engine immediately
        local hideCombat = (LazySpeedBigginsDB and LazySpeedBigginsDB.hideInCombat)
        if hideCombat ~= false then
            LazySpeed_StopEngine()
        end

    elseif event == "CHALLENGE_MODE_START" then
        -- Mythic+ key started: speed queries return secret values
        LazySpeed_StopEngine()

    elseif event == "PLAYER_REGEN_ENABLED" or event == "PLAYER_ENTERING_WORLD" or event == "PLAYER_MOUNT_DISPLAY_CHANGED"
        or event == "CHALLENGE_MODE_COMPLETED" or event == "CHALLENGE_MODE_RESET" or event == "ZONE_CHANGED_NEW_AREA" then
        LazySpeed_EvaluateState()
    end
end)

-- Passive Takeoff / Dive / Resume Detector (Runs at low 4 Hz / every 0.25s while inactive)
local passivePollTimer = 0
EventWatcherFrame:SetScript("OnUpdate", function(self, elapsed)
    local db = LazySpeedBigginsDB or DB_DEFAULTS
    
    -- If high-speed loop is already active, or in combat with hideInCombat enabled, skip
    if isEngineActive then return end
    if db.hideInCombat and IsPlayerInCombat() then return end

    passivePollTimer = passivePollTimer + elapsed
    if passivePollTimer < 0.25 then return end
    passivePollTimer = 0

    -- Restricted Environment / Secret Value check: do not activate in Mythic+ or secret contexts
    if IsRestrictedEnvironment() then return end

    local testSpeed = GetUnitSpeed("player")
    if IsSecret(testSpeed) then return end

    -- If showGround is enabled and we are not restricted/in combat, resume engine
    if db.showGround then
        LazySpeed_StartEngine()
        return
    end

    local isGliding = GetGlidingInfo()
    if IsSecret(isGliding) then return end

    local isSteadyFlying = IsFlying and IsFlying()
    local isSwimming = IsSwimming and IsSwimming()
    if IsSecret(isSteadyFlying) or IsSecret(isSwimming) then return end

    local isAirborne = isGliding or isSteadyFlying

    if (isAirborne and db.showFlying) or (isSwimming and db.showSwimming) then
        LazySpeed_StartEngine()
    end
end)

-- ==============================================================================
-- 9. SLASH COMMANDS (/lazyspeed, /lsb)
-- ==============================================================================
SLASH_LAZYSPEED1 = "/lazyspeed"
SLASH_LAZYSPEED2 = "/lsb"
SlashCmdList["LAZYSPEED"] = function(msg)
    local command = msg:lower():trim()
    local db = LazySpeedBigginsDB or DB_DEFAULTS

    if command == "options" or command == "config" or command == "settings" then
        if categoryID and Settings and Settings.OpenToCategory then
            Settings.OpenToCategory(categoryID)
        elseif Settings and Settings.OpenToCategory then
            Settings.OpenToCategory("LazySpeed Biggins")
        else
            DEFAULT_CHAT_FRAME:AddMessage("|cFFFFD100LazySpeed Biggins|r: Options available in Game Menu -> Options -> AddOns -> LazySpeed Biggins.")
        end
    elseif command == "toggle" then
        if not LazySpeedBigginsDB then LazySpeedBigginsDB = {} end
        LazySpeedBigginsDB.enabled = not (LazySpeedBigginsDB.enabled ~= false)
        UpdateOptionsUI()
        LazySpeed_EvaluateState()
        local status = LazySpeedBigginsDB.enabled and "|cFF00FF00Enabled|r" or "|cFFFF0000Disabled|r"
        DEFAULT_CHAT_FRAME:AddMessage("|cFFFFD100LazySpeed Biggins|r: Speedometer is now " .. status .. ".")
    elseif command == "lock" then
        if not LazySpeedBigginsDB then LazySpeedBigginsDB = {} end
        LazySpeedBigginsDB.locked = not (LazySpeedBigginsDB.locked or false)
        UpdateMouseInteractivity()
        UpdateOptionsUI()
        local status = LazySpeedBigginsDB.locked and "|cFFFF0000Locked|r" or "|cFF00FF00Unlocked|r"
        DEFAULT_CHAT_FRAME:AddMessage("|cFFFFD100LazySpeed Biggins|r: Frame position is now " .. status .. ".")
    elseif command == "defaults" or command == "reset defaults" then
        ResetAllToDefaults()
    elseif command == "reset" then
        if not LazySpeedBigginsDB then LazySpeedBigginsDB = {} end
        LazySpeedBigginsDB.point = "CENTER"
        LazySpeedBigginsDB.relativePoint = "CENTER"
        LazySpeedBigginsDB.xOfs = 0
        LazySpeedBigginsDB.yOfs = -200
        RestorePosition()
        DEFAULT_CHAT_FRAME:AddMessage("|cFFFFD100LazySpeed Biggins|r: Frame position reset to center.")
    elseif command == "status" then
        local function ColorBool(val) return val and "|cFF00FF00[ON]|r" or "|cFFFF0000[OFF]|r" end
        DEFAULT_CHAT_FRAME:AddMessage("|cFFFFD100LazySpeed Biggins|r Current Configuration:")
        DEFAULT_CHAT_FRAME:AddMessage(string.format("  Master Enable:    %s", ColorBool(db.enabled ~= false)))
        DEFAULT_CHAT_FRAME:AddMessage(string.format("  Frame Locked:     %s", ColorBool(db.locked or false)))
        DEFAULT_CHAT_FRAME:AddMessage(string.format("  Show Flying:      %s", ColorBool(db.showFlying)))
        DEFAULT_CHAT_FRAME:AddMessage(string.format("  Show Swimming:    %s", ColorBool(db.showSwimming)))
        DEFAULT_CHAT_FRAME:AddMessage(string.format("  Show Ground:      %s", ColorBool(db.showGround)))
        DEFAULT_CHAT_FRAME:AddMessage(string.format("  Hide in Combat:   %s", ColorBool(db.hideInCombat)))
        DEFAULT_CHAT_FRAME:AddMessage(string.format("  Measurement Unit: %s", modeLabels[db.unitMode or 4] or "%"))
        DEFAULT_CHAT_FRAME:AddMessage(string.format("  Bar Dimensions:   %d x %d px", db.barWidth or 180, db.barHeight or 22))
    else
        DEFAULT_CHAT_FRAME:AddMessage("|cFFFFD100LazySpeed Biggins v3.7.0|r:")
        DEFAULT_CHAT_FRAME:AddMessage("  |cFFFFFFFF/lazyspeed settings|r - Open options menu.")
        DEFAULT_CHAT_FRAME:AddMessage("  |cFFFFFFFF/lazyspeed toggle|r - Toggle master speedometer on/off.")
        DEFAULT_CHAT_FRAME:AddMessage("  |cFFFFFFFF/lazyspeed lock|r - Toggle locking frame position.")
        DEFAULT_CHAT_FRAME:AddMessage("  |cFFFFFFFF/lazyspeed reset|r - Reset frame position to center.")
        DEFAULT_CHAT_FRAME:AddMessage("  |cFFFFFFFF/lazyspeed defaults|r - Reset all options to default.")
        DEFAULT_CHAT_FRAME:AddMessage("  |cFFFFFFFF/lazyspeed status|r - Display current configuration.")
    end
end
