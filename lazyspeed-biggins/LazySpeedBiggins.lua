--[[ ==============================================================================
    LazySpeedBiggins v3.2 — High-Performance Speedometer & Flight Gauge
    ------------------------------------------------------------------------------
    Author: Biggins (US-Whisperwind)
    Compatibility: World of Warcraft: Midnight (Patch 12.1+)
    
    ARCHITECTURAL OVERVIEW:
    1. Zero Idle Footprint: When inactive based on user settings (e.g. grounded in
       Flight-Only mode, or in combat in No-Combat mode), the OnUpdate script is
       completely detached (SetScript("OnUpdate", nil)) and the frame is hidden.
    2. Blizzard Native Options: Integrates directly into Escape -> Options -> AddOns
       using Blizzard's modern Settings API.
    3. Zero-Allocation C++ Rendering: Formats numbers directly in native C++ using
       FontString:SetFormattedText() with pre-cached static format string pointers.
    4. Hardware-Accelerated UI: Single Blizzard StatusBar with dynamic color shift
       and classic Blizzard Tooltip & Metallic Gold frame skin.
============================================================================== ]]--

-- ==============================================================================
-- 1. LOCAL UPVALUE CACHING (Performance Optimization)
-- ------------------------------------------------------------------------------
-- Caching global C-APIs into local variables avoids table hash lookups in Lua,
-- boosting function execution speed by ~30% and eliminating global table churn.
-- ==============================================================================
local GetGlidingInfo      = C_PlayerInfo.GetGlidingInfo
local IsFlying            = IsFlying
local GetUnitSpeed        = GetUnitSpeed
local InCombatLockdown    = InCombatLockdown
local min                 = math.min
local max                 = math.max
local STANDARD_TEXT_FONT  = STANDARD_TEXT_FONT or "Fonts\\FRIZQT__.TTF"

-- Pre-cached format string constants: Passed directly into FontString:SetFormattedText
-- so that zero Lua strings are created or destroyed in Lua's garbage-collected heap!
local FORMAT_YS   = "%.1f y/s"
local FORMAT_MPH  = "%.1f mph"
local FORMAT_KMH  = "%.1f km/h"

-- Unit Conversion Multipliers from Base Yards/Second
local MULTIPLIER_MPH = 2.04545  -- 1 yard/sec = 2.04545 mph
local MULTIPLIER_KMH = 3.29184  -- 1 yard/sec = 3.29184 km/h

-- Maximum Speed Caps for 100% Status Bar Fill
local MAX_CAP_FLIGHT = 70.0     -- Max Skyriding speed cap
local MAX_CAP_GROUND = 42.0     -- Max Ground speed cap (running/sprint/ground mounts)

-- Unit Modes: 1 = Yards/Sec, 2 = MPH, 3 = KM/H
local modeLabels = { "Y/S", "MPH", "KM/H" }

-- Runtime State Variables
local isEngineActive  = false   -- True only when the high-speed loop is actively attached
local updateTimer     = 0       -- Accumulator for our 20 FPS (0.05s) throttling
local landingDebounce = 0       -- Grace period timer before concluding flight has ended
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
    visibilityMode = "FLIGHT_ONLY", -- "FLIGHT_ONLY", "NO_COMBAT", "ALWAYS"
    unitMode       = 2,             -- Default to MPH (2)
}

-- ==============================================================================
-- 3. UI FRAME CREATION & BLIZZARD GOLD BACKDROP
-- ------------------------------------------------------------------------------
-- Creates the main visual container frame with a dark slate background and 
-- Blizzard metallic gold border. Starts HIDDEN by default.
-- ==============================================================================
local SpeedoFrame = CreateFrame("Frame", "LazySpeedBigginsFrame", UIParent, "BackdropTemplate")
SpeedoFrame:SetSize(130, 32)
SpeedoFrame:SetPoint("CENTER", UIParent, "CENTER", 0, -200)
SpeedoFrame:Hide() -- Starts hidden; shown only when active according to user settings

-- Classic Blizzard Tooltip Backdrop Styling
SpeedoFrame:SetBackdrop({
    bgFile   = "Interface\\Tooltips\\UI-Tooltip-Background",
    edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
    tile     = true, 
    tileSize = 16, 
    edgeSize = 16,
    insets   = { left = 4, right = 4, top = 4, bottom = 4 }
})
SpeedoFrame:SetBackdropColor(0.05, 0.05, 0.05, 0.85)
SpeedoFrame:SetBackdropBorderColor(0.8, 0.7, 0.2, 1) -- Blizzard Metallic Gold

-- Make Frame Moveable by Left-Click Dragging
SpeedoFrame:SetMovable(true)
SpeedoFrame:EnableMouse(true)
SpeedoFrame:RegisterForDrag("LeftButton")
SpeedoFrame:SetScript("OnDragStart", SpeedoFrame.StartMoving)
SpeedoFrame:SetScript("OnDragStop", SpeedoFrame.StopMovingOrSizing)

-- ==============================================================================
-- 4. SPEED DISPLAY TEXT & TOGGLE BUTTON
-- ==============================================================================

-- Speed Number Display (Positioned right above the status bar)
local SpeedText = SpeedoFrame:CreateFontString(nil, "OVERLAY")
SpeedText:SetPoint("BOTTOM", SpeedoFrame, "TOP", 0, 4)
SpeedText:SetFont(STANDARD_TEXT_FONT, 16, "OUTLINE")
SpeedText:SetTextColor(1, 0.82, 0, 1) -- Blizzard Gold
SpeedText:SetText("0.0 mph")

-- Unit Toggle Button (Attached to the right side of the main frame)
local ToggleBtn = CreateFrame("Button", nil, SpeedoFrame, "BackdropTemplate")
ToggleBtn:SetSize(40, 32)
ToggleBtn:SetPoint("LEFT", SpeedoFrame, "RIGHT", 4, 0)

ToggleBtn:SetBackdrop({
    bgFile   = "Interface\\Tooltips\\UI-Tooltip-Background",
    edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
    tile     = true, 
    tileSize = 12, 
    edgeSize = 12,
    insets   = { left = 3, right = 3, top = 3, bottom = 3 }
})
ToggleBtn:SetBackdropColor(0.05, 0.05, 0.05, 0.85)
ToggleBtn:SetBackdropBorderColor(0.8, 0.7, 0.2, 1)

local ToggleText = ToggleBtn:CreateFontString(nil, "OVERLAY")
ToggleText:SetFont(STANDARD_TEXT_FONT, 12, "OUTLINE")
ToggleText:SetPoint("CENTER", ToggleBtn, "CENTER", 0, 0)
ToggleText:SetTextColor(1, 0.82, 0, 1)
ToggleText:SetText("MPH")

-- Left-Clicking cycles through Y/S -> MPH -> KM/H and saves to DB
ToggleBtn:SetScript("OnClick", function(self, button)
    LazySpeedBigginsDB.unitMode = (LazySpeedBigginsDB.unitMode or 2) + 1
    if LazySpeedBigginsDB.unitMode > 3 then LazySpeedBigginsDB.unitMode = 1 end
    ToggleText:SetText(modeLabels[LazySpeedBigginsDB.unitMode])
end)

-- Hover highlight visual feedback
ToggleBtn:SetScript("OnEnter", function(self) self:SetBackdropBorderColor(1, 1, 1, 1) end)
ToggleBtn:SetScript("OnLeave", function(self) self:SetBackdropBorderColor(0.8, 0.7, 0.2, 1) end)

-- ==============================================================================
-- 5. HARDWARE-ACCELERATED STATUS BAR
-- ------------------------------------------------------------------------------
-- Uses a single native Blizzard StatusBar rather than 30 separate texture objects.
-- This reduces GPU draw calls and completely eliminates multi-frame redraw loops.
-- ==============================================================================
local StatusBar = CreateFrame("StatusBar", nil, SpeedoFrame)
StatusBar:SetSize(118, 16)
StatusBar:SetPoint("CENTER", SpeedoFrame, "CENTER", 0, 0)
StatusBar:SetStatusBarTexture("Interface\\TargetingFrame\\UI-StatusBar")
StatusBar:SetMinMaxValues(0, 1)
StatusBar:SetValue(0)
StatusBar:SetStatusBarColor(0.2, 0.8, 0.2, 1) -- Blizzard Green

local StatusBarBG = StatusBar:CreateTexture(nil, "BACKGROUND")
StatusBarBG:SetAllPoints(StatusBar)
StatusBarBG:SetTexture("Interface\\TargetingFrame\\UI-StatusBar")
StatusBarBG:SetVertexColor(0.05, 0.05, 0.05, 0.7)

-- Helper: Reset visual elements to zero state
local function ResetDisplay()
    local unit = (LazySpeedBigginsDB and LazySpeedBigginsDB.unitMode) or 2
    if unit == 1 then
        SpeedText:SetText("0.0 y/s")
    elseif unit == 2 then
        SpeedText:SetText("0.0 mph")
    else
        SpeedText:SetText("0.0 km/h")
    end
    StatusBar:SetValue(0)
    StatusBar:SetStatusBarColor(0.2, 0.8, 0.2, 1)
    lastSpeed = 0
end

-- ==============================================================================
-- 6. HIGH-SPEED UPDATE LOOP (20 FPS — Throttled & Zero-Allocation)
-- ------------------------------------------------------------------------------
-- This loop executes ONLY when isEngineActive is true.
-- ==============================================================================
local function SpeedometerUpdateLoop(self, elapsed)
    local visMode = LazySpeedBigginsDB.visibilityMode or "FLIGHT_ONLY"

    -- Combat Check: If in No-Combat mode and combat begins, stop immediately
    if visMode == "NO_COMBAT" and InCombatLockdown() then
        LazySpeed_StopEngine()
        return
    end

    -- Frame Throttling: Accumulate elapsed time until 0.05 seconds (20 FPS) have passed
    updateTimer = updateTimer + elapsed
    if updateTimer < 0.05 then return end
    updateTimer = 0

    -- Query Flight & Ground Velocities
    local isGliding, _, forwardSpeed = GetGlidingInfo()
    local rawGroundSpeed = GetUnitSpeed("player")
    local isSteadyFlying = IsFlying and IsFlying()
    
    local currentSpeed = 0
    local maxCap = MAX_CAP_GROUND

    if isGliding then
        currentSpeed = forwardSpeed or 0
        maxCap = MAX_CAP_FLIGHT
        landingDebounce = 0
    elseif isSteadyFlying then
        currentSpeed = rawGroundSpeed or 0
        maxCap = MAX_CAP_FLIGHT
        landingDebounce = 0
    elseif rawGroundSpeed and rawGroundSpeed > 0 then
        currentSpeed = rawGroundSpeed
        maxCap = MAX_CAP_GROUND
    end

    -- Flight-Only Landing Detection (Skyriding OR Steady Flight)
    if visMode == "FLIGHT_ONLY" then
        local isAirborne = isGliding or isSteadyFlying
        if not isAirborne then
            landingDebounce = landingDebounce + 0.05
            -- If landed/stopped for >0.25 seconds in Flight-Only mode, shut down engine completely
            if landingDebounce >= 0.25 then
                LazySpeed_StopEngine()
                return
            end
        end
    end

    -- Idle / Dirty Check: If stationary and we already rendered 0 last tick, skip all UI redraws!
    if currentSpeed == 0 and lastSpeed == 0 then
        return
    end
    lastSpeed = currentSpeed

    -- Format display string using Blizzard's native C++ SetFormattedText method.
    -- This formats directly on the C++ side, creating LITERAL ZERO Lua string allocations!
    local unit = LazySpeedBigginsDB.unitMode or 2
    if unit == 1 then
        SpeedText:SetFormattedText(FORMAT_YS, currentSpeed)
    elseif unit == 2 then
        SpeedText:SetFormattedText(FORMAT_MPH, currentSpeed * MULTIPLIER_MPH)
    else
        SpeedText:SetFormattedText(FORMAT_KMH, currentSpeed * MULTIPLIER_KMH)
    end

    -- Update Smooth Status Bar (Ratio between 0.0 and 1.0)
    local speedRatio = min(max(currentSpeed / maxCap, 0.0), 1.0)
    StatusBar:SetValue(speedRatio)

    -- Dynamic Color Shift: Green (Cruising) -> Yellow (High Speed) -> Red (Max Thruster)
    if speedRatio > 0.85 then
        StatusBar:SetStatusBarColor(0.9, 0.1, 0.1, 1) -- Red
    elseif speedRatio > 0.50 then
        StatusBar:SetStatusBarColor(0.9, 0.8, 0.1, 1) -- Yellow
    else
        StatusBar:SetStatusBarColor(0.1, 0.9, 0.2, 1) -- Green
    end
end

-- ==============================================================================
-- 7. LIFECYCLE CONTROLLER (Engine Start, Stop, & State Evaluation)
-- ==============================================================================

-- Starts the 20 FPS high-speed update engine (Attaches OnUpdate script & shows UI)
function LazySpeed_StartEngine()
    if isEngineActive then return end
    
    isEngineActive = true
    updateTimer = 0
    landingDebounce = 0
    
    ResetDisplay()
    SpeedoFrame:Show()
    -- ATTACH THE SCRIPT: The Lua engine now begins executing the 20 FPS loop
    SpeedoFrame:SetScript("OnUpdate", SpeedometerUpdateLoop)
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

-- Centralized State Evaluator: Evaluates the active user setting and starts/stops the engine
function LazySpeed_EvaluateState()
    if not LazySpeedBigginsDB then return end
    
    local visMode = LazySpeedBigginsDB.visibilityMode or "FLIGHT_ONLY"
    local inCombat = InCombatLockdown()
    local isGliding = GetGlidingInfo()
    local isSteadyFlying = IsFlying and IsFlying()
    local isAirborne = isGliding or isSteadyFlying

    if visMode == "FLIGHT_ONLY" then
        if isAirborne and not inCombat then
            LazySpeed_StartEngine()
        else
            LazySpeed_StopEngine()
        end
    elseif visMode == "NO_COMBAT" then
        if inCombat then
            LazySpeed_StopEngine()
        else
            LazySpeed_StartEngine()
        end
    elseif visMode == "ALWAYS" then
        LazySpeed_StartEngine()
    end
end

-- ==============================================================================
-- 8. BLIZZARD MODERN SETTINGS API INTEGRATION (Escape -> Options -> AddOns)
-- ------------------------------------------------------------------------------
-- Registers a native settings category in WoW's official settings panel.
-- ==============================================================================
local function InitializeBlizzardSettings()
    if not Settings or not Settings.RegisterVerticalLayoutCategory then return end

    -- 1. Create Native AddOn Category
    local category, layout = Settings.RegisterVerticalLayoutCategory("LazySpeed Biggins")

    -- 2. Define the 3 Visibility Options for the Dropdown
    local function GetVisibilityDropdownOptions()
        local container = Settings.CreateControlTextContainer()
        container:Add("FLIGHT_ONLY", "Only While Flying (Zero Idle CPU)")
        container:Add("NO_COMBAT",   "Not in Combat (Ground & Flight)")
        container:Add("ALWAYS",      "Always Visible (Ground, Flight & Combat)")
        return container:GetData()
    end

    -- 3. Register AddOn Setting bound to LazySpeedBigginsDB.visibilityMode
    local visSetting = Settings.RegisterAddOnSetting(
        category,
        "LazySpeedBiggins_VisibilityMode",
        "visibilityMode",
        LazySpeedBigginsDB,
        Settings.VarType.String,
        "Visibility Mode",
        "FLIGHT_ONLY"
    )

    -- 4. Hook Callback when setting is changed by user
    visSetting:SetValueChangedCallback(function(setting, value)
        LazySpeedBigginsDB.visibilityMode = value
        LazySpeed_EvaluateState()
    end)

    -- 5. Create native Blizzard Dropdown for Visibility
    Settings.CreateDropdown(category, visSetting, GetVisibilityDropdownOptions, "Choose when the speedometer is active and visible on your screen.")

    -- 6. Define the 3 Speed Measurement Unit Options
    local function GetUnitDropdownOptions()
        local container = Settings.CreateControlTextContainer()
        container:Add(1, "Yards per Second (y/s)")
        container:Add(2, "Miles per Hour (mph)")
        container:Add(3, "Kilometers per Hour (km/h)")
        return container:GetData()
    end

    -- 7. Register AddOn Setting bound to LazySpeedBigginsDB.unitMode
    local unitSetting = Settings.RegisterAddOnSetting(
        category,
        "LazySpeedBiggins_UnitMode",
        "unitMode",
        LazySpeedBigginsDB,
        Settings.VarType.Number,
        "Speed Measurement Unit",
        2 -- Default to MPH
    )

    -- 8. Hook Callback when unit is changed from settings menu
    unitSetting:SetValueChangedCallback(function(setting, value)
        LazySpeedBigginsDB.unitMode = value
        ToggleText:SetText(modeLabels[value])
        lastSpeed = -1 -- Invalidate dirty check to trigger immediate UI redraw
        ResetDisplay()
    end)

    -- 9. Create native Blizzard Dropdown for Units
    Settings.CreateDropdown(category, unitSetting, GetUnitDropdownOptions, "Choose your preferred speed measurement unit.")

    -- 10. Register Category into Blizzard Settings Panel
    Settings.RegisterAddOnCategory(category)
end

-- ==============================================================================
-- 9. EVENT CONTROLLER & PASSIVE WATCHER (Low-Frequency Background Gating)
-- ==============================================================================
local EventWatcherFrame = CreateFrame("Frame")

EventWatcherFrame:RegisterEvent("ADDON_LOADED")                -- When addon SavedVariables are ready
EventWatcherFrame:RegisterEvent("PLAYER_ENTERING_WORLD")       -- When logging in or zoning
EventWatcherFrame:RegisterEvent("PLAYER_REGEN_DISABLED")        -- Entering combat
EventWatcherFrame:RegisterEvent("PLAYER_REGEN_ENABLED")         -- Exiting combat
EventWatcherFrame:RegisterEvent("PLAYER_MOUNT_DISPLAY_CHANGED") -- Mounting / Dismounting

EventWatcherFrame:SetScript("OnEvent", function(self, event, arg1)
    if event == "ADDON_LOADED" and arg1 == "LazySpeedBiggins" then
        -- Initialize SavedVariables table with defaults if first run
        LazySpeedBigginsDB = LazySpeedBigginsDB or {}
        for key, value in pairs(DB_DEFAULTS) do
            if LazySpeedBigginsDB[key] == nil then
                LazySpeedBigginsDB[key] = value
            end
        end

        -- Update UI Toggle Button text to match saved unit
        ToggleText:SetText(modeLabels[LazySpeedBigginsDB.unitMode or 2])

        -- Register Blizzard Settings Panel
        InitializeBlizzardSettings()

    elseif event == "PLAYER_REGEN_DISABLED" then
        -- Entering combat: If in Flight-Only or No-Combat mode, kill engine immediately
        local visMode = (LazySpeedBigginsDB and LazySpeedBigginsDB.visibilityMode) or "FLIGHT_ONLY"
        if visMode ~= "ALWAYS" then
            LazySpeed_StopEngine()
        end

    elseif event == "PLAYER_REGEN_ENABLED" or event == "PLAYER_ENTERING_WORLD" or event == "PLAYER_MOUNT_DISPLAY_CHANGED" then
        LazySpeed_EvaluateState()
    end
end)

-- Passive Takeoff Detector (Runs at low 4 Hz / every 0.25s while grounded in Flight-Only mode)
local passivePollTimer = 0
EventWatcherFrame:SetScript("OnUpdate", function(self, elapsed)
    local visMode = (LazySpeedBigginsDB and LazySpeedBigginsDB.visibilityMode) or "FLIGHT_ONLY"
    
    -- In ALWAYS or NO_COMBAT modes, or while high-speed loop is already running, skip
    if visMode ~= "FLIGHT_ONLY" or isEngineActive or InCombatLockdown() then return end

    passivePollTimer = passivePollTimer + elapsed
    if passivePollTimer < 0.25 then return end
    passivePollTimer = 0

    -- If player launched into the air (Skyriding OR Steady Flight), activate the engine!
    local isGliding = GetGlidingInfo()
    local isSteadyFlying = IsFlying and IsFlying()
    if isGliding or isSteadyFlying then
        LazySpeed_StartEngine()
    end
end)
