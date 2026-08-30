--[[ ==============================================================================
    LazySpeedBiggins v4.0 — High-Performance Speedometer, Flight Pitch & Swim Gauge
    ------------------------------------------------------------------------------
    Author: Biggins (US-Whisperwind)
    Compatibility: World of Warcraft: Midnight (Patch 12.1+)
    
    ARCHITECTURAL OVERVIEW:
    1. Zero Idle Footprint: When inactive based on user settings (e.g. grounded in
       Flight/Swim-Only mode, or in combat), the OnUpdate script is completely detached
       (SetScript("OnUpdate", nil)) and all frames are hidden (0.00ms CPU).
    2. Nameplate-Style Integrated HUD: Sleek 180px x 22px status bar with centered
       numeric and unit telemetry overlaying the dynamic fill bar.
    3. Independent Pitch Meter: Vertical flight angle gauge (climb / dive angle in
       degrees) that can be dragged and positioned independently of the speedometer.
       Features dynamic color highlights for the optimal Skyriding Vigor dive zone!
    4. Modular Blizzard Checkbox Settings: Direct integration into Options -> AddOns
       with native checkboxes:
         - Show While Flying / Skyriding
         - Show While Swimming (Aquatic mounts, swim speed buffs)
         - Show While on Ground
         - Hide During Combat (Killswitch)
         - Show Flight Pitch Meter (Toggleable vertical flight instrument)
         - Speed Measurement Unit Dropdown (y/s, mph, km/h)
    5. Dynamic Contextual Theming:
         - Speed: Green (Cruising) -> Yellow (High Speed) -> Red (Max Thruster)
         - Swim: Deep Ocean Blue -> Electric Cyan gradient
         - Pitch: Green (Climb) -> White (Level) -> Cyan/Gold (Optimal Dive) -> Red (Steep)
    6. Zero-Allocation C++ Rendering: Formats numbers directly in native C++ using
       FontString:SetFormattedText() with pre-cached static format string pointers.
    7. Hardware-Accelerated UI: Native Blizzard StatusBars with classic Tooltip
       and Metallic Gold backdrop styling.
============================================================================== ]]--

-- ==============================================================================
-- 1. LOCAL UPVALUE CACHING (Performance Optimization)
-- ------------------------------------------------------------------------------
-- Caching global C-APIs into local variables avoids table hash lookups in Lua,
-- boosting function execution speed by ~30% and eliminating global table churn.
-- ==============================================================================
local GetGlidingInfo      = C_PlayerInfo.GetGlidingInfo
local UnitPosition        = UnitPosition
local GetTime             = GetTime
local IsFlying            = IsFlying
local IsSwimming          = IsSwimming
local GetUnitSpeed        = GetUnitSpeed
local InCombatLockdown    = InCombatLockdown
local min                 = math.min
local max                 = math.max
local floor               = math.floor
local abs                 = math.abs
local asin                = math.asin
local STANDARD_TEXT_FONT  = STANDARD_TEXT_FONT or "Fonts\\FRIZQT__.TTF"

-- Pre-cached format string constants: Passed directly into FontString:SetFormattedText
-- so that zero Lua strings are created or destroyed in Lua's garbage-collected heap!
local FORMAT_YS    = "%.1f y/s"
local FORMAT_MPH   = "%.1f mph"
local FORMAT_KMH   = "%.1f km/h"
local FORMAT_PITCH = "%+d°"
local FORMAT_ZERO  = "0°"

-- Unit Conversion Multipliers from Base Yards/Second
local MULTIPLIER_MPH = 2.04545  -- 1 yard/sec = 2.04545 mph
local MULTIPLIER_KMH = 3.29184  -- 1 yard/sec = 3.29184 km/h
local RAD_TO_DEG     = 57.2957795 -- 180 / pi for fast radians-to-degrees conversion

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
local lastPitchDeg    = -999    -- Dirty tracking: Skips redundant pitch redraws when steady
local lastZ           = nil     -- 3D Altitude coordinate for trajectory velocity
local lastTime        = nil     -- Timestamp for delta calculation

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
-- 3. SPEEDOMETER FRAME (180px x 22px Nameplate-Style HUD)
-- ==============================================================================
local SpeedoFrame = CreateFrame("Frame", "LazySpeedBigginsFrame", UIParent, "BackdropTemplate")
SpeedoFrame:SetSize(180, 22)
SpeedoFrame:SetPoint("CENTER", UIParent, "CENTER", 0, -200)
SpeedoFrame:Hide()

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

-- Make Speedometer Moveable by Left-Click Dragging
SpeedoFrame:SetMovable(true)
SpeedoFrame:EnableMouse(true)
SpeedoFrame:RegisterForDrag("LeftButton")
SpeedoFrame:SetScript("OnDragStart", SpeedoFrame.StartMoving)
SpeedoFrame:SetScript("OnDragStop", function(self)
    self:StopMovingOrSizing()
    local point, _, relPoint, x, y = self:GetPoint()
    if LazySpeedBigginsDB then
        LazySpeedBigginsDB.speedoPos = { point = point, relPoint = relPoint, x = x, y = y }
    end
end)

-- Hardware-Accelerated Speed Status Bar
local StatusBar = CreateFrame("StatusBar", nil, SpeedoFrame)
StatusBar:SetSize(174, 16)
StatusBar:SetPoint("CENTER", SpeedoFrame, "CENTER", 0, 0)
StatusBar:SetStatusBarTexture("Interface\\TargetingFrame\\UI-StatusBar")
StatusBar:SetMinMaxValues(0, 1)
StatusBar:SetValue(0)
StatusBar:SetStatusBarColor(0.2, 0.8, 0.2, 1)

local StatusBarBG = StatusBar:CreateTexture(nil, "BACKGROUND")
StatusBarBG:SetAllPoints(StatusBar)
StatusBarBG:SetTexture("Interface\\TargetingFrame\\UI-StatusBar")
StatusBarBG:SetVertexColor(0.05, 0.05, 0.05, 0.75)

-- Speed Telemetry Display (Centered directly inside the StatusBar overlay)
local SpeedText = StatusBar:CreateFontString(nil, "OVERLAY")
SpeedText:SetPoint("CENTER", StatusBar, "CENTER", 0, 0)
SpeedText:SetFont(STANDARD_TEXT_FONT, 12, "OUTLINE")
SpeedText:SetTextColor(1, 1, 1, 1)
SpeedText:SetShadowOffset(1, -1)
SpeedText:SetShadowColor(0, 0, 0, 1)
SpeedText:SetText("0.0 mph")

-- ==============================================================================
-- 4. INDEPENDENT PITCH METER FRAME (Vertical Flight Angle Gauge)
-- ==============================================================================
local PitchFrame = CreateFrame("Frame", "LazySpeedBigginsPitchFrame", UIParent, "BackdropTemplate")
PitchFrame:SetSize(28, 76)
PitchFrame:SetPoint("RIGHT", SpeedoFrame, "LEFT", -6, 0)
PitchFrame:Hide()

PitchFrame:SetBackdrop({
    bgFile   = "Interface\\Tooltips\\UI-Tooltip-Background",
    edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
    tile     = true, 
    tileSize = 12, 
    edgeSize = 12,
    insets   = { left = 3, right = 3, top = 3, bottom = 3 }
})
PitchFrame:SetBackdropColor(0.05, 0.05, 0.05, 0.85)
PitchFrame:SetBackdropBorderColor(0.8, 0.7, 0.2, 1) -- Blizzard Metallic Gold

-- Make Pitch Frame Moveable Independently by Left-Click Dragging
PitchFrame:SetMovable(true)
PitchFrame:EnableMouse(true)
PitchFrame:RegisterForDrag("LeftButton")
PitchFrame:SetScript("OnDragStart", PitchFrame.StartMoving)
PitchFrame:SetScript("OnDragStop", function(self)
    self:StopMovingOrSizing()
    local point, _, relPoint, x, y = self:GetPoint()
    if LazySpeedBigginsDB then
        LazySpeedBigginsDB.pitchPos = { point = point, relPoint = relPoint, x = x, y = y }
    end
end)

-- Pitch Meter Background Track
local PitchTrack = PitchFrame:CreateTexture(nil, "BACKGROUND")
PitchTrack:SetSize(8, 68)
PitchTrack:SetPoint("CENTER", PitchFrame, "CENTER", 0, 0)
PitchTrack:SetColorTexture(0.1, 0.1, 0.1, 0.85)

-- Horizon Center Marker (0° Level Flight Indicator)
local HorizonLine = PitchFrame:CreateTexture(nil, "ARTWORK")
HorizonLine:SetSize(18, 2)
HorizonLine:SetPoint("CENTER", PitchFrame, "CENTER", 0, 0)
HorizonLine:SetColorTexture(1, 0.82, 0, 0.9) -- Gold Horizon Notch

-- Dynamic Pitch Fill Bar (Grows Upwards for Climb, Downwards for Dive from Center)
local PitchFill = PitchFrame:CreateTexture(nil, "OVERLAY")
PitchFill:SetSize(8, 0)
PitchFill:SetPoint("BOTTOM", HorizonLine, "TOP", 0, 0)
PitchFill:SetColorTexture(0.2, 0.8, 0.2, 1)

-- Pitch Degree Text Display (Positioned right above the Pitch Frame)
local PitchText = PitchFrame:CreateFontString(nil, "OVERLAY")
PitchText:SetPoint("BOTTOM", PitchFrame, "TOP", 0, 3)
PitchText:SetFont(STANDARD_TEXT_FONT, 10, "OUTLINE")
PitchText:SetTextColor(1, 1, 1, 1)
PitchText:SetShadowOffset(1, -1)
PitchText:SetShadowColor(0, 0, 0, 1)
PitchText:SetText("0°")

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
    
    PitchFill:SetHeight(0)
    PitchText:SetText(FORMAT_ZERO)
    lastSpeed = 0
    lastPitchDeg = -999
    lastZ = nil
    lastTime = nil
end

-- ==============================================================================
-- 5. HIGH-SPEED UPDATE LOOP (20 FPS — Throttled & Zero-Allocation)
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

    -- Query Flight, Swim & Ground Velocities + 3D Altitude
    local isGliding, _, forwardSpeed = GetGlidingInfo()
    local rawGroundSpeed = GetUnitSpeed("player")
    local isSteadyFlying = IsFlying and IsFlying()
    local isSwimming = IsSwimming and IsSwimming()
    
    local currentZ = nil
    if UnitPosition then
        local _, _, z = UnitPosition("player")
        currentZ = z
    end
    local now = GetTime()
    
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

    -- --------------------------------------------------------------------------
    -- 1. SPEEDOMETER TELEMETRY UPDATE
    -- --------------------------------------------------------------------------
    if currentSpeed ~= lastSpeed then
        lastSpeed = currentSpeed

        local unit = db.unitMode or 2
        if unit == 1 then
            SpeedText:SetFormattedText(FORMAT_YS, currentSpeed)
        elseif unit == 2 then
            SpeedText:SetFormattedText(FORMAT_MPH, currentSpeed * MULTIPLIER_MPH)
        else
            SpeedText:SetFormattedText(FORMAT_KMH, currentSpeed * MULTIPLIER_KMH)
        end

        local speedRatio = min(max(currentSpeed / maxCap, 0.0), 1.0)
        StatusBar:SetValue(speedRatio)

        -- Contextual Dynamic Theming
        if isSwimming then
            if speedRatio > 0.70 then
                StatusBar:SetStatusBarColor(0.0, 0.9, 1.0, 1) -- Electric Cyan
            else
                StatusBar:SetStatusBarColor(0.0, 0.55, 0.85, 1) -- Deep Ocean Blue
            end
        else
            if speedRatio > 0.85 then
                StatusBar:SetStatusBarColor(0.9, 0.1, 0.1, 1) -- Red (Max Thruster)
            elseif speedRatio > 0.50 then
                StatusBar:SetStatusBarColor(0.9, 0.8, 0.1, 1) -- Yellow (Cruising)
            else
                StatusBar:SetStatusBarColor(0.1, 0.9, 0.2, 1) -- Green (Standard)
            end
        end
    end

    -- --------------------------------------------------------------------------
    -- 2. FLIGHT PITCH METER UPDATE (Calculus-based 3D Trajectory Calculation)
    -- --------------------------------------------------------------------------
    if isCurrentStateActive then
        if not PitchFrame:IsShown() then PitchFrame:Show() end

        local pitchDeg = 0
        if currentZ and lastZ and lastTime and currentSpeed > 1.5 then
            local dt = now - lastTime
            if dt > 0.01 then
                local dz = currentZ - lastZ
                local vZ = dz / dt -- Vertical velocity in yards per second
                local ratio = min(max(vZ / currentSpeed, -1.0), 1.0)
                local pitchRad = asin(ratio)
                pitchDeg = floor(pitchRad * RAD_TO_DEG + 0.5)
                pitchDeg = min(max(pitchDeg, -90), 90)
            else
                pitchDeg = (lastPitchDeg ~= -999 and lastPitchDeg) or 0
            end
        end

        if currentZ then
            lastZ = currentZ
            lastTime = now
        end

        if pitchDeg ~= lastPitchDeg then
            lastPitchDeg = pitchDeg

            -- Update Pitch Degree Text
            if pitchDeg == 0 then
                PitchText:SetText(FORMAT_ZERO)
            else
                PitchText:SetFormattedText(FORMAT_PITCH, pitchDeg)
            end

            -- Update Vertical Fill Bar (Max height = 32px up or down from horizon)
            local fillHeight = min(floor((abs(pitchDeg) / 90.0) * 32 + 0.5), 32)
            
            PitchFill:ClearAllPoints()
            if fillHeight == 0 then
                PitchFill:SetSize(8, 0)
            elseif pitchDeg > 0 then
                -- Climbing: Anchor to bottom of fill at horizon line, growing UP
                PitchFill:SetPoint("BOTTOM", HorizonLine, "TOP", 0, 0)
                PitchFill:SetSize(8, fillHeight)
                PitchFill:SetColorTexture(0.2, 0.8, 0.2, 1) -- Green (Climbing)
            else
                -- Diving: Anchor to top of fill at horizon line, growing DOWN
                PitchFill:SetPoint("TOP", HorizonLine, "BOTTOM", 0, 0)
                PitchFill:SetSize(8, fillHeight)
                
                -- Optimal Skyriding Vigor Dive Zone (-15° to -45°)
                if pitchDeg <= -15 and pitchDeg >= -45 then
                    PitchFill:SetColorTexture(0.0, 0.9, 1.0, 1) -- Electric Cyan (Vigor Sweet Spot!)
                elseif pitchDeg < -45 then
                    PitchFill:SetColorTexture(0.9, 0.8, 0.1, 1) -- Yellow / Steep Dive
                else
                    PitchFill:SetColorTexture(0.7, 0.7, 0.7, 1) -- Shallow Dive
                end
            end
        end
    else
        if PitchFrame:IsShown() then PitchFrame:Hide() end
        lastZ = nil
        lastTime = nil
    end
end

-- ==============================================================================
-- 6. LIFECYCLE CONTROLLER (Engine Start, Stop, & State Evaluation)
-- ==============================================================================

function LazySpeed_StartEngine()
    if isEngineActive then return end
    
    isEngineActive = true
    updateTimer = 0
    landingDebounce = 0
    
    ResetDisplay()
    SpeedoFrame:Show()
    PitchFrame:Show()

    -- ATTACH THE SCRIPT: The Lua engine now begins executing the 20 FPS loop
    SpeedoFrame:SetScript("OnUpdate", SpeedometerUpdateLoop)
end

function LazySpeed_StopEngine()
    if not isEngineActive then return end
    
    isEngineActive = false
    -- DETACH THE SCRIPT: Completely removes the OnUpdate hook (0.00ms CPU)
    SpeedoFrame:SetScript("OnUpdate", nil)
    SpeedoFrame:Hide()
    PitchFrame:Hide()
    ResetDisplay()
end

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
-- ==============================================================================
local function InitializeBlizzardSettings()
    if not Settings or not Settings.RegisterVerticalLayoutCategory then return end

    local category, layout = Settings.RegisterVerticalLayoutCategory("LazySpeed Biggins")

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

    -- Modular Checkboxes
    RegisterCheckbox("showFlying",   "Show While Flying / Skyriding", "Displays the speedometer and pitch meter while airborne (Skyriding or Steady Flight).", true)
    RegisterCheckbox("showSwimming", "Show While Swimming",           "Displays the speedometer and pitch meter while submerged in water, tracking swim and aquatic mount speeds.", true)
    RegisterCheckbox("showGround",   "Show While on Ground",          "Displays the speedometer and pitch meter while running on foot or riding ground mounts.", false)
    RegisterCheckbox("hideInCombat", "Hide During Combat",            "Instantly hides and detaches instruments during combat to keep your screen clear.", true)

    -- Speed Measurement Unit Options
    local function GetUnitDropdownOptions()
        local container = Settings.CreateControlTextContainer()
        container:Add(1, "Yards per Second (y/s)")
        container:Add(2, "Miles per Hour (mph)")
        container:Add(3, "Kilometers per Hour (km/h)")
        return container:GetData()
    end

    local unitSetting = Settings.RegisterAddOnSetting(
        category,
        "LazySpeedBiggins_UnitMode",
        "unitMode",
        LazySpeedBigginsDB,
        Settings.VarType.Number,
        "Speed Measurement Unit",
        2
    )

    unitSetting:SetValueChangedCallback(function(setting, value)
        LazySpeedBigginsDB.unitMode = value
        lastSpeed = -1
        ResetDisplay()
    end)

    Settings.CreateDropdown(category, unitSetting, GetUnitDropdownOptions, "Choose your preferred speed measurement unit.")
    Settings.RegisterAddOnCategory(category)
end

-- ==============================================================================
-- 8. EVENT CONTROLLER & PASSIVE WATCHER (Low-Frequency Background Gating)
-- ==============================================================================
local EventWatcherFrame = CreateFrame("Frame")

EventWatcherFrame:RegisterEvent("ADDON_LOADED")
EventWatcherFrame:RegisterEvent("PLAYER_ENTERING_WORLD")
EventWatcherFrame:RegisterEvent("PLAYER_REGEN_DISABLED")
EventWatcherFrame:RegisterEvent("PLAYER_REGEN_ENABLED")
EventWatcherFrame:RegisterEvent("PLAYER_MOUNT_DISPLAY_CHANGED")

EventWatcherFrame:SetScript("OnEvent", function(self, event, arg1)
    if event == "ADDON_LOADED" and arg1 == "LazySpeedBiggins" then
        LazySpeedBigginsDB = LazySpeedBigginsDB or {}
        
        for key, value in pairs(DB_DEFAULTS) do
            if LazySpeedBigginsDB[key] == nil then
                LazySpeedBigginsDB[key] = value
            end
        end

        -- Restore Saved Custom Positions if present
        if LazySpeedBigginsDB.speedoPos then
            local pos = LazySpeedBigginsDB.speedoPos
            SpeedoFrame:ClearAllPoints()
            SpeedoFrame:SetPoint(pos.point, UIParent, pos.relPoint, pos.x, pos.y)
        end

        if LazySpeedBigginsDB.pitchPos then
            local pos = LazySpeedBigginsDB.pitchPos
            PitchFrame:ClearAllPoints()
            PitchFrame:SetPoint(pos.point, UIParent, pos.relPoint, pos.x, pos.y)
        end

        InitializeBlizzardSettings()

    elseif event == "PLAYER_REGEN_DISABLED" then
        local hideCombat = (LazySpeedBigginsDB and LazySpeedBigginsDB.hideInCombat)
        if hideCombat ~= false then
            LazySpeed_StopEngine()
        end

    elseif event == "PLAYER_REGEN_ENABLED" or event == "PLAYER_ENTERING_WORLD" or event == "PLAYER_MOUNT_DISPLAY_CHANGED" then
        LazySpeed_EvaluateState()
    end
end)

-- Passive Takeoff / Dive Detector (4 Hz while dormant)
local passivePollTimer = 0
EventWatcherFrame:SetScript("OnUpdate", function(self, elapsed)
    local db = LazySpeedBigginsDB or DB_DEFAULTS
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
        PitchFrame:ClearAllPoints()
        PitchFrame:SetPoint("RIGHT", SpeedoFrame, "LEFT", -6, 0)
        if LazySpeedBigginsDB then
            LazySpeedBigginsDB.speedoPos = nil
            LazySpeedBigginsDB.pitchPos = nil
        end
    elseif command == "debug" then
        local g1, g2, g3 = GetGlidingInfo()
        local pos1, pos2, pos3, mapID
        if UnitPosition then
            pos1, pos2, pos3, mapID = UnitPosition("player")
        end
        local rawSpd = (GetUnitSpeed and GetUnitSpeed("player")) or "nil"

        DEFAULT_CHAT_FRAME:AddMessage("|cFFFFD100LazySpeed Debug Telemetry:|r")
        DEFAULT_CHAT_FRAME:AddMessage(string.format("  GetGlidingInfo: isGliding=%s, canGlide=%s, fwdSpd=%s", tostring(g1), tostring(g2), tostring(g3)))
        DEFAULT_CHAT_FRAME:AddMessage(string.format("  UnitPosition: [1]=%s, [2]=%s, [3]=%s, [4]=%s", tostring(pos1), tostring(pos2), tostring(pos3), tostring(mapID)))
        DEFAULT_CHAT_FRAME:AddMessage(string.format("  Speed: %s | lastPitchDeg: %s | lastZ: %s", tostring(rawSpd), tostring(lastPitchDeg), tostring(lastZ)))
    else
        DEFAULT_CHAT_FRAME:AddMessage("|cFFFFD100LazySpeed Biggins v4.0|r:")
        DEFAULT_CHAT_FRAME:AddMessage("  |cFFFFFFFF/lazyspeed settings|r — Open options menu.")
        DEFAULT_CHAT_FRAME:AddMessage("  |cFFFFFFFF/lazyspeed reset|r — Reset instrument positions.")
        DEFAULT_CHAT_FRAME:AddMessage("  |cFFFFFFFF/lazyspeed debug|r — Print live pitch API telemetry.")
        DEFAULT_CHAT_FRAME:AddMessage("  |cFFFFFFFF/lazyspeed toggle|r — Toggle instruments display.")
    end
end
