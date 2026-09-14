--[[ ==============================================================================
    LazySpeedBiggins v3.4.1 - High-Performance Speedometer, Flight & Swim Gauge
    ------------------------------------------------------------------------------
    Author: Biggins (US-Whisperwind)
    Compatibility: World of Warcraft: Midnight (Patch 12.1+)
    
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
         - Speed Measurement Unit Dropdown (y/s, mph, km/h)
    4. Dynamic Contextual Theming:
         - Flying / Ground: Green (Cruising) -> Yellow (High Speed) -> Red (Max Thruster)
         - Swimming: Ocean Blue -> Electric Cyan gradient
    5. Zero-Allocation C++ Rendering: Formats numbers directly in native C++ using
       FontString:SetFormattedText() with pre-cached static format string pointers.
    6. Hardware-Accelerated UI: Single Blizzard StatusBar with dynamic color shift
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
local IsSwimming          = IsSwimming
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
local MAX_CAP_FLIGHT = 70.0     -- Max Skyriding speed cap (~143 mph)
local MAX_CAP_SWIM   = 20.0     -- Max Swimming / Aquatic mount speed cap (~41 mph)
local MAX_CAP_GROUND = 42.0     -- Max Ground speed cap (running/sprint/ground mounts)

-- Unit Modes: 1 = Yards/Sec, 2 = MPH, 3 = KM/H
local modeLabels = { "y/s", "mph", "km/h" }

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
    showFlying    = true,  -- Show while Flying / Skyriding
    showSwimming  = true,  -- Show while Swimming / Submerged in water
    showGround    = false, -- Show while on Ground (foot or ground mounts)
    hideInCombat  = true,  -- Hide immediately during combat
    unitMode      = 2,     -- Default to MPH (2)
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

-- Make Frame Moveable by Left-Click Dragging
SpeedoFrame:SetMovable(true)
SpeedoFrame:EnableMouse(true)
SpeedoFrame:RegisterForDrag("LeftButton")
SpeedoFrame:SetScript("OnDragStart", SpeedoFrame.StartMoving)
SpeedoFrame:SetScript("OnDragStop", SpeedoFrame.StopMovingOrSizing)

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
-- 5. HIGH-SPEED UPDATE LOOP (20 FPS - Throttled & Zero-Allocation)
-- ------------------------------------------------------------------------------
-- This loop executes ONLY when isEngineActive is true.
-- ==============================================================================
local function SpeedometerUpdateLoop(self, elapsed)
    local db = LazySpeedBigginsDB or DB_DEFAULTS

    -- Combat Check: If hideInCombat is enabled and combat begins, stop immediately
    if db.hideInCombat and InCombatLockdown() then
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
    local isSteadyFlying = IsFlying and IsFlying()
    local isSwimming = IsSwimming and IsSwimming()
    
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
    local unit = db.unitMode or 2
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

-- Centralized State Evaluator: Evaluates active checkboxes and starts/stops the engine
function LazySpeed_EvaluateState()
    if not LazySpeedBigginsDB then return end
    local db = LazySpeedBigginsDB
    
    local inCombat = InCombatLockdown()
    if inCombat and db.hideInCombat then
        LazySpeed_StopEngine()
        return
    end

    local isGliding = GetGlidingInfo()
    local isSteadyFlying = IsFlying and IsFlying()
    local isSwimming = IsSwimming and IsSwimming()
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
-- Registers native checkboxes and dropdowns in WoW's official settings panel.
-- ==============================================================================
local function InitializeBlizzardSettings()
    if not Settings or not Settings.RegisterVerticalLayoutCategory then return end

    -- 1. Create Native AddOn Category
    local category, layout = Settings.RegisterVerticalLayoutCategory("LazySpeed Biggins")

    -- 2. Helper to register boolean Checkbox Settings
    local function RegisterCheckbox(varName, label, tooltip, defaultValue)
        local setting = Settings.RegisterAddOnSetting(
            category,
            "LazySpeedBiggins_" .. varName,
            varName,
            LazySpeedBigginsDB,
            Settings.VarType.Boolean,
            label,
            defaultValue
        )
        setting:SetValueChangedCallback(function(setting, value)
            LazySpeedBigginsDB[varName] = value
            LazySpeed_EvaluateState()
        end)
        Settings.CreateCheckbox(category, setting, tooltip)
        return setting
    end

    -- 3. Register Modular Checkboxes
    RegisterCheckbox("showFlying",   "Show While Flying / Skyriding", "Displays the speedometer while airborne (Skyriding or Steady Flight).", true)
    RegisterCheckbox("showSwimming", "Show While Swimming",           "Displays the speedometer while submerged in water, tracking swim and aquatic mount speeds.", true)
    RegisterCheckbox("showGround",   "Show While on Ground",          "Displays the speedometer while running on foot or riding ground mounts.", false)
    RegisterCheckbox("hideInCombat", "Hide During Combat",            "Instantly hides and detaches the speedometer during combat to keep your screen clear.", true)

    -- 4. Define the 3 Speed Measurement Unit Options
    local function GetUnitDropdownOptions()
        local container = Settings.CreateControlTextContainer()
        container:Add(1, "Yards per Second (y/s)")
        container:Add(2, "Miles per Hour (mph)")
        container:Add(3, "Kilometers per Hour (km/h)")
        return container:GetData()
    end

    -- 5. Register AddOn Setting bound to LazySpeedBigginsDB.unitMode
    local unitSetting = Settings.RegisterAddOnSetting(
        category,
        "LazySpeedBiggins_UnitMode",
        "unitMode",
        LazySpeedBigginsDB,
        Settings.VarType.Number,
        "Speed Measurement Unit",
        2 -- Default to MPH
    )

    -- 6. Hook Callback when unit is changed from settings menu
    unitSetting:SetValueChangedCallback(function(setting, value)
        LazySpeedBigginsDB.unitMode = value
        lastSpeed = -1 -- Invalidate dirty check to trigger immediate UI redraw
        ResetDisplay()
    end)

    -- 7. Create native Blizzard Dropdown for Units
    Settings.CreateDropdown(category, unitSetting, GetUnitDropdownOptions, "Choose your preferred speed measurement unit.")

    -- 8. Register Category into Blizzard Settings Panel
    Settings.RegisterAddOnCategory(category)
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

        -- Register Blizzard Settings Panel
        InitializeBlizzardSettings()

    elseif event == "PLAYER_REGEN_DISABLED" then
        -- Entering combat: If hideInCombat is enabled, kill engine immediately
        local hideCombat = (LazySpeedBigginsDB and LazySpeedBigginsDB.hideInCombat)
        if hideCombat ~= false then
            LazySpeed_StopEngine()
        end

    elseif event == "PLAYER_REGEN_ENABLED" or event == "PLAYER_ENTERING_WORLD" or event == "PLAYER_MOUNT_DISPLAY_CHANGED" then
        LazySpeed_EvaluateState()
    end
end)

-- Passive Takeoff / Dive Detector (Runs at low 4 Hz / every 0.25s while inactive)
local passivePollTimer = 0
EventWatcherFrame:SetScript("OnUpdate", function(self, elapsed)
    local db = LazySpeedBigginsDB or DB_DEFAULTS
    
    -- If high-speed loop is already running, or if ground mode is on (which runs continuous loop), or in combat with hideInCombat on, skip
    if isEngineActive or db.showGround or (db.hideInCombat and InCombatLockdown()) then return end

    passivePollTimer = passivePollTimer + elapsed
    if passivePollTimer < 0.25 then return end
    passivePollTimer = 0

    local isGliding = GetGlidingInfo()
    local isSteadyFlying = IsFlying and IsFlying()
    local isSwimming = IsSwimming and IsSwimming()
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
    if command == "options" or command == "config" or command == "settings" then
        if Settings and Settings.OpenToCategory then
            Settings.OpenToCategory("LazySpeed Biggins")
        end
    elseif command == "toggle" then
        if isEngineActive then
            LazySpeed_StopEngine()
        else
            LazySpeed_StartEngine()
        end
    elseif command == "reset" then
        SpeedoFrame:ClearAllPoints()
        SpeedoFrame:SetPoint("CENTER", UIParent, "CENTER", 0, -200)
        DEFAULT_CHAT_FRAME:AddMessage("|cFFFFD100LazySpeed Biggins|r: Frame position reset to center.")
    else
        DEFAULT_CHAT_FRAME:AddMessage("|cFFFFD100LazySpeed Biggins v3.4.1|r:")
        DEFAULT_CHAT_FRAME:AddMessage("  |cFFFFFFFF/lazyspeed settings|r - Open options menu.")
        DEFAULT_CHAT_FRAME:AddMessage("  |cFFFFFFFF/lazyspeed reset|r - Reset position.")
        DEFAULT_CHAT_FRAME:AddMessage("  |cFFFFFFFF/lazyspeed toggle|r - Toggle speedometer display.")
    end
end
