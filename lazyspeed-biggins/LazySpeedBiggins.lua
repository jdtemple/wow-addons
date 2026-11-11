--[[ ==============================================================================
    LazySpeedBiggins v4.0.0 - High-Performance Speedometer & Skyriding Vigor HUD
    ------------------------------------------------------------------------------
    Author: Biggins (US-Whisperwind)
    Compatibility: World of Warcraft: Midnight (Patch 12.1.7 / 12.1+)

    ARCHITECTURAL OVERVIEW:
    1. Zero Idle Footprint: When inactive based on user settings (e.g. grounded in
       Flight/Swim-Only mode, or in combat), the OnUpdate script is completely detached
       (SetScript("OnUpdate", nil)) and the frame is hidden (0.00ms CPU).
    2. Dual-Bar Stacked HUD:
       - Speedometer: Dynamic velocity tracking for flight, swim, and ground travel.
       - Skyriding Vigor Bar: 1-6 Surge Forward / Vigor charge tracking with smooth
         fractional recharge progress and live remaining cooldown timers.
    3. Dynamic Layout & Collapse Engine:
       - Configurable Stacking Mode: Vertical (Speedometer on top, Vigor bar below)
         or Horizontal (side-by-side ribbon) with uniform bar sizing.
       - Dynamic Single-Bar Collapse: When not Skyriding, the Vigor bar vanishes
         and the Speedometer cleanly occupies the container with zero gaps.
       - Unified Dragging: Dragging either bar moves the entire stack as a unit.
    4. Dedicated Skyriding Visibility:
       - The Vigor bar displays strictly while mounted in active Skyriding mode.
    5. Contextual Theming:
       - Flight / Ground Speed: Green (Cruising) -> Yellow (High Speed) -> Red (Max Thruster)
       - Swim Speed: Deep Ocean Blue -> Electric Cyan gradient
       - Skyriding Vigor: Electric Skyriding Cyan with full-charge luminescence
    6. Zero-Allocation C++ Rendering: Formats numbers directly in native C++ using
       FontString:SetFormattedText() with pre-cached static format string pointers.
    7. Secret Value & Restricted Environment Protection: Guards against Patch 12.0+
       secret value comparison/arithmetic errors in Mythic+ dungeons and challenge modes.
============================================================================== ]]--

local addonName, addon = ...
_G["LazySpeedBiggins"] = addon
addon.version = "4.0.0"

-- ==============================================================================
-- 1. LOCAL UPVALUE CACHING & RESTRICTION HELPERS (Performance & Safety)
-- ==============================================================================
local GetGlidingInfo      = C_PlayerInfo.GetGlidingInfo
local IsFlying            = IsFlying
local IsSwimming          = IsSwimming
local IsMounted           = IsMounted
local GetUnitSpeed        = GetUnitSpeed
local InCombatLockdown    = InCombatLockdown
local UnitAffectingCombat = UnitAffectingCombat
local issecretvalue       = issecretvalue
local GetTime             = GetTime
local pcall               = pcall
local min                 = math.min
local max                 = math.max
local floor               = math.floor
local STANDARD_TEXT_FONT  = STANDARD_TEXT_FONT or "Fonts\\FRIZQT__.TTF"

-- Spell Constants (Surge Forward & Skyward Ascent share the identical Vigor charge pool)
local SPELL_SURGE_FORWARD       = 372608
local SPELL_SKYWARD_ASCENT      = 372610
local SPELL_THRILL_OF_THE_SKIES = 377234
local SPELL_GROUND_SKIMMING     = 405021

-- Secret Value Detection (Midnight / Patch 12.0+ & Restricted Instances)
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

-- Comprehensive combat check
local function IsPlayerInCombat()
    if InCombatLockdown and InCombatLockdown() then
        return true
    end
    if UnitAffectingCombat and UnitAffectingCombat("player") then
        return true
    end
    return false
end

-- Surge Forward / Skyward Ascent Vigor Charge Helper
local function GetSurgeForwardCharges()
    if C_Spell and C_Spell.GetSpellCharges then
        local info = C_Spell.GetSpellCharges(SPELL_SURGE_FORWARD) or C_Spell.GetSpellCharges(SPELL_SKYWARD_ASCENT)
        if type(info) == "table" then
            local current = info.currentCharges or 0
            local maxVal  = info.maxCharges or 6
            local start   = info.cooldownStartTime or info.cooldownStart or 0
            local dur     = info.cooldownDuration or 0
            return current, maxVal, start, dur
        end
    end
    if GetSpellCharges then
        local current, maxVal, start, dur = GetSpellCharges(SPELL_SURGE_FORWARD)
        if not current then
            current, maxVal, start, dur = GetSpellCharges(SPELL_SKYWARD_ASCENT)
        end
        if current then
            return current, maxVal, start, dur
        end
    end
    return nil
end

-- Fast Player Aura Check for Accelerated Skyriding Recharge Buffs
local function HasPlayerAura(spellID, spellName)
    if C_UnitAuras and C_UnitAuras.GetPlayerAuraBySpellID then
        local aura = C_UnitAuras.GetPlayerAuraBySpellID(spellID)
        if aura then return true end
    end
    if spellName and AuraUtil and AuraUtil.FindAuraByName then
        local name = AuraUtil.FindAuraByName(spellName, "player", "HELPFUL")
        if name then return true end
    end
    if C_UnitAuras and C_UnitAuras.ForEachAura then
        local found = false
        C_UnitAuras.ForEachAura("player", "HELPFUL", nil, function(aura)
            if aura.spellId == spellID or aura.name == spellName then
                found = true
                return true
            end
        end)
        if found then return true end
    end
    return false
end

local function GetSkyridingRechargeBuffs()
    local hasThrill = HasPlayerAura(SPELL_THRILL_OF_THE_SKIES, "Thrill of the Skies")
    local hasSkim   = HasPlayerAura(SPELL_GROUND_SKIMMING, "Ground Skimming") or HasPlayerAura(418590, "Ground Skimming") or HasPlayerAura(418591, "Ground Skimming")
    return hasThrill, hasSkim
end

-- Active Skyriding State Detection
local function IsInSkyridingMode()
    if not (IsMounted and IsMounted()) then
        return false
    end
    if C_PlayerInfo and C_PlayerInfo.GetGlidingInfo then
        local isGliding, canGlide = C_PlayerInfo.GetGlidingInfo()
        if (isGliding or canGlide) == true then
            return true
        end
    end
    return false
end

-- Pre-cached format string constants for Zero-Allocation C++ rendering
local FORMAT_YS    = "%.1f y/s"
local FORMAT_MPH   = "%.1f mph"
local FORMAT_KMH   = "%.1f km/h"
local FORMAT_PCT   = "%.0f%%"
local FORMAT_VIGOR_FULL = "%d / %d Vigor"
local FORMAT_VIGOR_CHG  = "%d / %d (%.1fs)"

-- Unit Conversion Multipliers from Base Yards/Second
local MULTIPLIER_MPH = 2.04545       -- 1 yard/sec = 2.04545 mph
local MULTIPLIER_KMH = 3.29184       -- 1 yard/sec = 3.29184 km/h
local MULTIPLIER_PCT = 100.0 / 7.0   -- 7 yards/sec = 100% base run speed

-- Maximum Speed Caps for 100% Status Bar Fill
local MAX_CAP_FLIGHT = 84.0     -- Max Skyriding speed cap (1,200% / ~172 mph)
local MAX_CAP_SWIM   = 20.0     -- Max Swimming / Aquatic mount speed cap (~41 mph)
local MAX_CAP_GROUND = 42.0     -- Max Ground speed cap (running/sprint/ground mounts)

-- Unit Modes: 1 = Yards/Sec, 2 = MPH, 3 = KM/H, 4 = Percentage (%)
local modeLabels = { "y/s", "mph", "km/h", "%" }

-- ==============================================================================
-- 2. COLOR PALETTE CONSTANTS (Central Theme Configuration)
-- ==============================================================================
-- Borders & Backdrops
local COLOR_GOLD_BORDER        = { 0.80, 0.70, 0.20, 1.00 } -- Classic Blizzard Metallic Gold
local COLOR_CONTAINER_BG       = { 0.05, 0.05, 0.05, 0.95 } -- Solid dark backdrop
local COLOR_TRACK_BG           = { 0.05, 0.05, 0.05, 0.75 } -- Empty status bar track

-- Skyriding Vigor States (Normal / Gliding without Buffs)
local COLOR_VIGOR_NORMAL       = { 0.05, 0.80, 0.95, 1.00 } -- Blizzard Skyriding Cyan (Normal gliding & recharging)
local COLOR_VIGOR_NORMAL_FULL  = { 0.10, 0.88, 1.00, 1.00 } -- Full charges Sky Cyan

-- Accelerated Recharge States (Color-Coded Buffs & Flame Auras)
local COLOR_THRILL_BAR         = { 0.00, 0.38, 1.00, 1.00 } -- Thrill of the Skies: Deep Royal / Electric Cobalt Blue
local COLOR_THRILL_AURA        = { 0.00, 0.45, 1.00 }

local COLOR_SKIM_BAR           = { 1.00, 0.15, 0.15, 1.00 } -- Ground Skimming: Danger Crimson Red
local COLOR_SKIM_AURA          = { 1.00, 0.15, 0.15 }

local COLOR_BOTH_BAR           = { 0.85, 0.20, 1.00, 1.00 } -- Both Buffs Active: Radiant Neon Violet / Purple
local COLOR_BOTH_AURA          = { 0.85, 0.20, 1.00 }

-- Speedometer Contextual Grading
local COLOR_SPEED_CRUISE       = { 0.10, 0.90, 0.20, 1.00 } -- Green
local COLOR_SPEED_HIGH         = { 0.90, 0.80, 0.10, 1.00 } -- Yellow
local COLOR_SPEED_MAX          = { 0.90, 0.10, 0.10, 1.00 } -- Red
local COLOR_SPEED_SWIM_SLOW    = { 0.00, 0.55, 0.85, 1.00 } -- Deep Ocean Blue
local COLOR_SPEED_SWIM_FAST    = { 0.00, 0.90, 1.00, 1.00 } -- Electric Cyan

addon.Colors = {
    GOLD_BORDER        = COLOR_GOLD_BORDER,
    CONTAINER_BG       = COLOR_CONTAINER_BG,
    TRACK_BG           = COLOR_TRACK_BG,
    VIGOR_NORMAL       = COLOR_VIGOR_NORMAL,
    VIGOR_NORMAL_FULL  = COLOR_VIGOR_NORMAL_FULL,
    THRILL_BAR         = COLOR_THRILL_BAR,
    THRILL_AURA        = COLOR_THRILL_AURA,
    SKIM_BAR           = COLOR_SKIM_BAR,
    SKIM_AURA          = COLOR_SKIM_AURA,
    BOTH_BAR           = COLOR_BOTH_BAR,
    BOTH_AURA          = COLOR_BOTH_AURA,
    SPEED_CRUISE       = COLOR_SPEED_CRUISE,
    SPEED_HIGH         = COLOR_SPEED_HIGH,
    SPEED_MAX          = COLOR_SPEED_MAX,
    SPEED_SWIM_SLOW    = COLOR_SPEED_SWIM_SLOW,
    SPEED_SWIM_FAST    = COLOR_SPEED_SWIM_FAST,
}

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
local DB_DEFAULTS = {
    enabled       = true,        -- Master enable toggle
    showFlying    = true,        -- Show Speedometer while Flying / Skyriding
    showSwimming  = true,        -- Show Speedometer while Swimming / Submerged in water
    showGround    = false,       -- Show Speedometer while on Ground (foot or ground mounts)
    showVigor     = true,        -- Show Skyriding Vigor / Surge Forward charge bar
    showVigorGlow = true,        -- Show aura glow on accelerated recharge buffs (Thrill/Skim)
    stackingMode  = "VERTICAL",  -- "VERTICAL" (Speedometer on top, Vigor below) or "HORIZONTAL"
    hideInCombat  = true,        -- Hide immediately during combat
    locked        = false,       -- Lock frame position to prevent dragging
    unitMode      = 4,           -- Default to Percentage (4)
    barWidth      = 180,         -- Frame width in pixels (Range: 100 - 300)
    barHeight     = 22,          -- Frame height in pixels (Range: 14 - 36)
    point         = "CENTER",
    relativePoint = "CENTER",
    xOfs          = 0,
    yOfs          = -200,
}

-- ==============================================================================
-- 3. UI FRAME CREATION & NAMEPLATE-STYLE BLIZZARD GOLD BACKDROP
-- ==============================================================================
-- Transparent master container frame managing stack anchoring and unified movement
local mainFrame = CreateFrame("Frame", "LazySpeedBigginsFrame", UIParent)
mainFrame:SetSize(180, 22)
mainFrame:SetPoint("CENTER", UIParent, "CENTER", 0, -200)
mainFrame:SetClampedToScreen(true)
mainFrame:SetMovable(true)
mainFrame:EnableMouse(true)
mainFrame:RegisterForDrag("LeftButton")
mainFrame:Hide()

-- Unified Drag Handlers: Dragging either bar moves the entire stack as a single unit
local function OnDragStartHandler(self)
    local db = LazySpeedBigginsDB or DB_DEFAULTS
    if not db.locked then
        mainFrame:StartMoving()
    end
end

local function OnDragStopHandler(self)
    mainFrame:StopMovingOrSizing()
    local point, _, relPoint, x, y = mainFrame:GetPoint()
    if not LazySpeedBigginsDB then LazySpeedBigginsDB = {} end
    LazySpeedBigginsDB.point = point or "CENTER"
    LazySpeedBigginsDB.relativePoint = relPoint or "CENTER"
    LazySpeedBigginsDB.xOfs = x or 0
    LazySpeedBigginsDB.yOfs = y or -200
end

mainFrame:SetScript("OnDragStart", OnDragStartHandler)
mainFrame:SetScript("OnDragStop", OnDragStopHandler)

-- Helper to create individual status bars wrapped in a Blizzard Gold bordered container
local function CreateTelemetryBar(barName, defaultText)
    local container = CreateFrame("Frame", barName .. "Container", mainFrame, "BackdropTemplate")
    container:SetFrameLevel(3)
    container:SetClampedToScreen(true)
    container:EnableMouse(true)
    container:RegisterForDrag("LeftButton")
    container:SetScript("OnDragStart", OnDragStartHandler)
    container:SetScript("OnDragStop", OnDragStopHandler)

    container:SetBackdrop({
        bgFile   = "Interface\\Tooltips\\UI-Tooltip-Background",
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        tile     = true,
        tileSize = 12,
        edgeSize = 12,
        insets   = { left = 3, right = 3, top = 3, bottom = 3 }
    })
    container:SetBackdropColor(COLOR_CONTAINER_BG[1], COLOR_CONTAINER_BG[2], COLOR_CONTAINER_BG[3], COLOR_CONTAINER_BG[4])
    container:SetBackdropBorderColor(COLOR_GOLD_BORDER[1], COLOR_GOLD_BORDER[2], COLOR_GOLD_BORDER[3], COLOR_GOLD_BORDER[4])

    local bar = CreateFrame("StatusBar", barName, container)
    bar:SetFrameLevel(4)
    bar:SetPoint("CENTER", container, "CENTER", 0, 0)
    bar:SetStatusBarTexture("Interface\\TargetingFrame\\UI-StatusBar")
    bar:SetMinMaxValues(0, 1)
    bar:SetValue(0)

    -- Subtle dark background track behind the status bar
    local bg = bar:CreateTexture(nil, "BACKGROUND")
    bg:SetAllPoints(bar)
    bg:SetTexture("Interface\\TargetingFrame\\UI-StatusBar")
    bg:SetVertexColor(COLOR_TRACK_BG[1], COLOR_TRACK_BG[2], COLOR_TRACK_BG[3], COLOR_TRACK_BG[4])
    bar.bg = bg

    -- Centered text overlay
    local text = bar:CreateFontString(nil, "OVERLAY")
    text:SetPoint("CENTER", bar, "CENTER", 0, 0)
    text:SetFont(STANDARD_TEXT_FONT, 12, "OUTLINE")
    text:SetTextColor(1, 1, 1, 1)
    text:SetShadowOffset(1, -1)
    text:SetShadowColor(0, 0, 0, 1)
    text:SetText(defaultText)
    bar.text = text

    bar.container = container
    return bar
end

local barSpeed = CreateTelemetryBar("LazySpeedBigginsSpeedBar", "0%")
local barVigor = CreateTelemetryBar("LazySpeedBigginsVigorBar", "6 / 6 Vigor")

-- ==============================================================================
-- Accelerated Recharge Perimeter Flame Aura (Stock Nameplate Threat Flare)
-- ==============================================================================
local vigorFlameFrame = CreateFrame("Frame", "LazySpeedBigginsVigorFlameFrame", mainFrame)
vigorFlameFrame:SetFrameStrata(mainFrame:GetFrameStrata())
vigorFlameFrame:SetFrameLevel(1) -- Low priority z-axis: tucked cleanly behind bars and adjacent UI elements
vigorFlameFrame:SetAllPoints(barVigor.container)
vigorFlameFrame:Hide()

local vigorFlames = {}

local function AddFlameTexture(tex, isAdditive)
    if isAdditive then
        tex:SetBlendMode("ADD")
        tex:SetAlpha(0.65)
    else
        tex:SetBlendMode("BLEND")
        tex:SetAlpha(0.95)
    end
    table.insert(vigorFlames, tex)
    return tex
end

local flareAtlas = "UI-HUD-Nameplates-Aggro-Flare"
local flareInfo  = C_Texture and C_Texture.GetAtlasInfo and C_Texture.GetAtlasInfo(flareAtlas)

-- 1. TOP EDGE FLAMES (Shooting upward)
local flameTopBase = AddFlameTexture(vigorFlameFrame:CreateTexture(nil, "BACKGROUND", nil, -2), false)
flameTopBase:SetPoint("BOTTOMLEFT", vigorFlameFrame, "TOPLEFT", -2, -3)
flameTopBase:SetPoint("BOTTOMRIGHT", vigorFlameFrame, "TOPRIGHT", 2, -3)
flameTopBase:SetHeight(14)
flameTopBase:SetAtlas(flareAtlas)
flameTopBase:SetHorizTile(true)

local flameTopAdd = AddFlameTexture(vigorFlameFrame:CreateTexture(nil, "BACKGROUND", nil, -1), true)
flameTopAdd:SetAllPoints(flameTopBase)
flameTopAdd:SetAtlas(flareAtlas)
flameTopAdd:SetHorizTile(true)

-- 2. BOTTOM EDGE FLAMES (Shooting downward, inverted UV coordinates)
local flameBottomBase = AddFlameTexture(vigorFlameFrame:CreateTexture(nil, "BACKGROUND", nil, -2), false)
flameBottomBase:SetPoint("TOPLEFT", vigorFlameFrame, "BOTTOMLEFT", -2, 3)
flameBottomBase:SetPoint("TOPRIGHT", vigorFlameFrame, "BOTTOMRIGHT", 2, 3)
flameBottomBase:SetHeight(14)
if flareInfo then
    flameBottomBase:SetTexture(flareInfo.file)
    flameBottomBase:SetTexCoord(flareInfo.leftTexCoord, flareInfo.rightTexCoord, flareInfo.bottomTexCoord, flareInfo.topTexCoord)
    flameBottomBase:SetHorizTile(true)
else
    flameBottomBase:SetAtlas(flareAtlas)
    flameBottomBase:SetRotation(math.pi)
    flameBottomBase:SetHorizTile(true)
end

local flameBottomAdd = AddFlameTexture(vigorFlameFrame:CreateTexture(nil, "BACKGROUND", nil, -1), true)
flameBottomAdd:SetAllPoints(flameBottomBase)
if flareInfo then
    flameBottomAdd:SetTexture(flareInfo.file)
    flameBottomAdd:SetTexCoord(flareInfo.leftTexCoord, flareInfo.rightTexCoord, flareInfo.bottomTexCoord, flareInfo.topTexCoord)
    flameBottomAdd:SetHorizTile(true)
else
    flameBottomAdd:SetAtlas(flareAtlas)
    flameBottomAdd:SetRotation(math.pi)
    flameBottomAdd:SetHorizTile(true)
end

-- 3. LEFT EDGE FLAMES (Shooting outward to the left)
local flameLeftBase = AddFlameTexture(vigorFlameFrame:CreateTexture(nil, "BACKGROUND", nil, -2), false)
flameLeftBase:SetPoint("TOPRIGHT", vigorFlameFrame, "TOPLEFT", 4, 1)
flameLeftBase:SetPoint("BOTTOMRIGHT", vigorFlameFrame, "BOTTOMLEFT", 4, -1)
flameLeftBase:SetWidth(14)
flameLeftBase:SetAtlas(flareAtlas)
flameLeftBase:SetRotation(math.pi / 2)

local flameLeftAdd = AddFlameTexture(vigorFlameFrame:CreateTexture(nil, "BACKGROUND", nil, -1), true)
flameLeftAdd:SetAllPoints(flameLeftBase)
flameLeftAdd:SetAtlas(flareAtlas)
flameLeftAdd:SetRotation(math.pi / 2)

-- 4. RIGHT EDGE FLAMES (Shooting outward to the right)
local flameRightBase = AddFlameTexture(vigorFlameFrame:CreateTexture(nil, "BACKGROUND", nil, -2), false)
flameRightBase:SetPoint("TOPLEFT", vigorFlameFrame, "TOPRIGHT", -4, 1)
flameRightBase:SetPoint("BOTTOMLEFT", vigorFlameFrame, "BOTTOMRIGHT", -4, -1)
flameRightBase:SetWidth(14)
flameRightBase:SetAtlas(flareAtlas)
flameRightBase:SetRotation(-math.pi / 2)

local flameRightAdd = AddFlameTexture(vigorFlameFrame:CreateTexture(nil, "BACKGROUND", nil, -1), true)
flameRightAdd:SetAllPoints(flameRightBase)
flameRightAdd:SetAtlas(flareAtlas)
flameRightAdd:SetRotation(-math.pi / 2)

local function SetFlameAuraColor(r, g, b)
    if not vigorFlameFrame:IsShown() then
        vigorFlameFrame:Show()
    end
    for _, tex in ipairs(vigorFlames) do
        tex:SetVertexColor(r, g, b)
    end
    barVigor.container:SetBackdropBorderColor(r, g, b, 1.0)
end

local function HideFlameAura()
    if vigorFlameFrame:IsShown() then
        vigorFlameFrame:Hide()
    end
    barVigor.container:SetBackdropBorderColor(COLOR_GOLD_BORDER[1], COLOR_GOLD_BORDER[2], COLOR_GOLD_BORDER[3], COLOR_GOLD_BORDER[4])
end

barVigor.flameFrame = vigorFlameFrame
barVigor.glow = vigorFlameFrame

addon.mainFrame = mainFrame
addon.barSpeed  = barSpeed
addon.barVigor  = barVigor

-- Restore saved screen position
local function RestorePosition()
    local db = LazySpeedBigginsDB or DB_DEFAULTS
    mainFrame:ClearAllPoints()
    mainFrame:SetPoint(db.point or "CENTER", UIParent, db.relativePoint or "CENTER", db.xOfs or 0, db.yOfs or -200)
end

-- Update mouse interactivity based on locked state
local function UpdateMouseInteractivity()
    local db = LazySpeedBigginsDB or DB_DEFAULTS
    local mouseEnabled = not db.locked
    mainFrame:EnableMouse(mouseEnabled)
    barSpeed.container:EnableMouse(mouseEnabled)
    barVigor.container:EnableMouse(mouseEnabled)
end

-- ==============================================================================
-- 4. DYNAMIC LAYOUT & COLLAPSE ENGINE (PerfBiggins Architectural Standard)
-- ==============================================================================
function addon:UpdateLayout()
    local db = LazySpeedBigginsDB or DB_DEFAULTS
    if db.enabled == false then
        LazySpeed_StopEngine()
        return
    end

    landingDebounce = 0

    if db.hideInCombat and IsPlayerInCombat() then
        LazySpeed_StopEngine()
        return
    end

    if IsRestrictedEnvironment() then
        LazySpeed_StopEngine()
        return
    end

    -- Evaluate Speed Bar Visibility
    local rawGroundSpeed = GetUnitSpeed("player")
    local isGliding, canGlide, forwardSpeed = GetGlidingInfo()
    local isSteadyFlying = IsFlying and IsFlying()
    local isSwimming = IsSwimming and IsSwimming()

    if IsSecret(rawGroundSpeed) or IsSecret(forwardSpeed) or IsSecret(isGliding) or IsSecret(isSteadyFlying) or IsSecret(isSwimming) then
        LazySpeed_StopEngine()
        return
    end

    local isAirborne = isGliding or isSteadyFlying
    local showSpeed = false
    if isAirborne and db.showFlying then
        showSpeed = true
    elseif isSwimming and db.showSwimming then
        showSpeed = true
    elseif db.showGround then
        showSpeed = true
    end

    -- Evaluate Skyriding Vigor Bar Visibility (Strictly mounted in Skyriding mode)
    local showVigor = false
    if (db.showVigor ~= false) and IsInSkyridingMode() then
        local charges = GetSurgeForwardCharges()
        if charges ~= nil then
            showVigor = true
        end
    end

    -- Build list of currently visible bars (Speedometer on top/first, Vigor underneath/second)
    local visibleBars = {}
    if showSpeed then
        table.insert(visibleBars, barSpeed)
    else
        barSpeed.container:Hide()
    end

    if showVigor then
        table.insert(visibleBars, barVigor)
    else
        barVigor.container:Hide()
        HideFlameAura()
    end

    local count = #visibleBars
    if count == 0 then
        LazySpeed_StopEngine()
        return
    end

    -- Bar Sizing & Gap Calculation
    local width  = db.barWidth or 180
    local height = db.barHeight or 22
    local gap    = 4
    local isHorizontal = (db.stackingMode == "HORIZONTAL")

    local totalWidth, totalHeight
    if isHorizontal then
        totalWidth  = (count * width) + ((count - 1) * gap)
        totalHeight = height
    else
        totalWidth  = width
        totalHeight = (count * height) + ((count - 1) * gap)
    end

    mainFrame:SetSize(totalWidth, max(1, totalHeight))

    -- Dynamic font scaling with bar height
    local fontSize = min(max(floor(height * 0.55), 9), 20)
    local prevContainer = nil

    for i, bar in ipairs(visibleBars) do
        local c = bar.container
        c:ClearAllPoints()
        c:SetSize(width, height)

        bar:ClearAllPoints()
        bar:SetPoint("CENTER", c, "CENTER", 0, 0)
        bar:SetSize(max(1, width - 6), max(1, height - 6))
        bar.text:SetFont(STANDARD_TEXT_FONT, fontSize, "OUTLINE")

        if i == 1 then
            c:SetPoint("TOPLEFT", mainFrame, "TOPLEFT", 0, 0)
        elseif isHorizontal then
            c:SetPoint("TOPLEFT", prevContainer, "TOPRIGHT", gap, 0)
        else
            c:SetPoint("TOPLEFT", prevContainer, "BOTTOMLEFT", 0, -gap)
        end
        c:Show()
        bar:Show()
        prevContainer = c
    end

    UpdateMouseInteractivity()
    LazySpeed_StartEngine()
end

-- Helper: Reset visual elements to zero state
local function ResetDisplay()
    local unit = (LazySpeedBigginsDB and LazySpeedBigginsDB.unitMode) or 4
    if unit == 1 then
        barSpeed.text:SetText("0.0 y/s")
    elseif unit == 2 then
        barSpeed.text:SetText("0.0 mph")
    elseif unit == 3 then
        barSpeed.text:SetText("0.0 km/h")
    else
        barSpeed.text:SetText("0%")
    end
    barSpeed:SetValue(0)
    barSpeed:SetStatusBarColor(COLOR_SPEED_CRUISE[1], COLOR_SPEED_CRUISE[2], COLOR_SPEED_CRUISE[3], COLOR_SPEED_CRUISE[4])
    barVigor:SetValue(0)
    barVigor.text:SetText("6 / 6 Vigor")
    barVigor.container:SetBackdropBorderColor(COLOR_GOLD_BORDER[1], COLOR_GOLD_BORDER[2], COLOR_GOLD_BORDER[3], COLOR_GOLD_BORDER[4])
    HideFlameAura()
    lastSpeed = 0
end

-- ==============================================================================
-- 5. HIGH-SPEED UPDATE LOOP (20 FPS - Throttled & Zero-Allocation)
-- ==============================================================================
local function SpeedometerUpdateLoop(self, elapsed)
    local db = LazySpeedBigginsDB or DB_DEFAULTS

    -- Combat Check
    if db.hideInCombat and IsPlayerInCombat() then
        LazySpeed_StopEngine()
        return
    end

    -- Environment Check
    if IsRestrictedEnvironment() then
        LazySpeed_StopEngine()
        return
    end

    -- Frame Throttling: Accumulate elapsed time until 0.05 seconds (20 FPS) have passed
    updateTimer = updateTimer + elapsed
    if updateTimer < 0.05 then return end
    updateTimer = 0

    -- 1. SPEEDOMETER TELEMETRY UPDATE
    if barSpeed.container:IsShown() then
        local isGliding, _, forwardSpeed = GetGlidingInfo()
        local rawGroundSpeed = GetUnitSpeed("player")

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

        if IsSecret(currentSpeed) then
            LazySpeed_StopEngine()
            return
        end

        -- Landing / State Termination Debounce
        if not isCurrentStateActive then
            landingDebounce = landingDebounce + 0.05
            if landingDebounce >= 1.0 then
                LazySpeed_EvaluateState()
                return
            end
        else
            landingDebounce = 0
        end

        -- Dirty Check & Redraw
        if currentSpeed ~= lastSpeed or lastSpeed == -1 then
            lastSpeed = currentSpeed

            local unit = db.unitMode or 4
            if unit == 1 then
                barSpeed.text:SetFormattedText(FORMAT_YS, currentSpeed)
            elseif unit == 2 then
                barSpeed.text:SetFormattedText(FORMAT_MPH, currentSpeed * MULTIPLIER_MPH)
            elseif unit == 3 then
                barSpeed.text:SetFormattedText(FORMAT_KMH, currentSpeed * MULTIPLIER_KMH)
            else
                barSpeed.text:SetFormattedText(FORMAT_PCT, currentSpeed * MULTIPLIER_PCT)
            end

            local speedRatio = min(max(currentSpeed / maxCap, 0.0), 1.0)
            barSpeed:SetValue(speedRatio)

            -- Dynamic Contextual Theming
            if isSwimming then
                if speedRatio > 0.70 then
                    barSpeed:SetStatusBarColor(COLOR_SPEED_SWIM_FAST[1], COLOR_SPEED_SWIM_FAST[2], COLOR_SPEED_SWIM_FAST[3], COLOR_SPEED_SWIM_FAST[4])
                else
                    barSpeed:SetStatusBarColor(COLOR_SPEED_SWIM_SLOW[1], COLOR_SPEED_SWIM_SLOW[2], COLOR_SPEED_SWIM_SLOW[3], COLOR_SPEED_SWIM_SLOW[4])
                end
            else
                if speedRatio > 0.85 then
                    barSpeed:SetStatusBarColor(COLOR_SPEED_MAX[1], COLOR_SPEED_MAX[2], COLOR_SPEED_MAX[3], COLOR_SPEED_MAX[4])
                elseif speedRatio > 0.50 then
                    barSpeed:SetStatusBarColor(COLOR_SPEED_HIGH[1], COLOR_SPEED_HIGH[2], COLOR_SPEED_HIGH[3], COLOR_SPEED_HIGH[4])
                else
                    barSpeed:SetStatusBarColor(COLOR_SPEED_CRUISE[1], COLOR_SPEED_CRUISE[2], COLOR_SPEED_CRUISE[3], COLOR_SPEED_CRUISE[4])
                end
            end
        end
    else
        -- Speedometer is collapsed/hidden (e.g. while grounded on a Skyriding mount)
        -- Instantly detect takeoff, steady flight, or water immersion to expand the HUD stack
        local isGliding = GetGlidingInfo()
        local isSteadyFlying = IsFlying and IsFlying()
        local isSwimming = IsSwimming and IsSwimming()
        local isAirborne = (isGliding or isSteadyFlying)

        if not IsSecret(isGliding) and not IsSecret(isSteadyFlying) and not IsSecret(isSwimming) then
            if (isAirborne and db.showFlying) or (isSwimming and db.showSwimming) or db.showGround then
                addon:UpdateLayout()
                return
            end
        end
    end

    -- 2. SKYRIDING VIGOR TELEMETRY UPDATE
    if barVigor.container:IsShown() then
        if not IsInSkyridingMode() then
            LazySpeed_EvaluateState()
            return
        end

        local charges, maxCharges, startTime, duration = GetSurgeForwardCharges()
        if charges then
            local currentVal = charges
            if charges < maxCharges and duration and duration > 0 and startTime and startTime > 0 then
                local elapsed = GetTime() - startTime
                local frac = min(max(elapsed / duration, 0), 1)
                currentVal = charges + frac
                local remaining = max(0, duration - elapsed)
                barVigor.text:SetFormattedText(FORMAT_VIGOR_CHG, charges, maxCharges, remaining)
            else
                barVigor.text:SetFormattedText(FORMAT_VIGOR_FULL, charges, maxCharges)
            end

            barVigor:SetMinMaxValues(0, maxCharges)
            barVigor:SetValue(currentVal)

            -- Accelerated Recharge Aura Glow (Thrill of the Skies & Ground Skimming)
            local showGlow = (db.showVigorGlow ~= false)
            local hasThrill, hasSkim = GetSkyridingRechargeBuffs()

            if hasThrill and hasSkim then
                -- Both active: Maximum turbo recharge -> Radiant Violet / Purple Flame Aura (Blue + Red)
                if showGlow then
                    SetFlameAuraColor(COLOR_BOTH_AURA[1], COLOR_BOTH_AURA[2], COLOR_BOTH_AURA[3])
                else
                    HideFlameAura()
                end
                barVigor:SetStatusBarColor(COLOR_BOTH_BAR[1], COLOR_BOTH_BAR[2], COLOR_BOTH_BAR[3], COLOR_BOTH_BAR[4])
            elseif hasThrill then
                -- Thrill of the Skies (Airborne speed recharge) -> Vibrant Blue Flame Aura
                if showGlow then
                    SetFlameAuraColor(COLOR_THRILL_AURA[1], COLOR_THRILL_AURA[2], COLOR_THRILL_AURA[3])
                else
                    HideFlameAura()
                end
                barVigor:SetStatusBarColor(COLOR_THRILL_BAR[1], COLOR_THRILL_BAR[2], COLOR_THRILL_BAR[3], COLOR_THRILL_BAR[4])
            elseif hasSkim then
                -- Ground Skimming (Low-altitude collision danger recharge) -> Crimson Red Flame Aura
                if showGlow then
                    SetFlameAuraColor(COLOR_SKIM_AURA[1], COLOR_SKIM_AURA[2], COLOR_SKIM_AURA[3])
                else
                    HideFlameAura()
                end
                barVigor:SetStatusBarColor(COLOR_SKIM_BAR[1], COLOR_SKIM_BAR[2], COLOR_SKIM_BAR[3], COLOR_SKIM_BAR[4])
            else
                -- Normal (No accelerated recharge) -> NO FLAME, Classic Metallic Gold Border, Cyan Fill
                HideFlameAura()
                if charges >= maxCharges then
                    barVigor:SetStatusBarColor(COLOR_VIGOR_NORMAL_FULL[1], COLOR_VIGOR_NORMAL_FULL[2], COLOR_VIGOR_NORMAL_FULL[3], COLOR_VIGOR_NORMAL_FULL[4])
                else
                    barVigor:SetStatusBarColor(COLOR_VIGOR_NORMAL[1], COLOR_VIGOR_NORMAL[2], COLOR_VIGOR_NORMAL[3], COLOR_VIGOR_NORMAL[4])
                end
            end
        end
    else
        -- Vigor bar is collapsed/hidden (e.g. while unmounted or swimming)
        -- Detect mounting into Skyriding mode to expand the HUD stack
        if (db.showVigor ~= false) and IsInSkyridingMode() then
            local charges = GetSurgeForwardCharges()
            if charges ~= nil then
                addon:UpdateLayout()
                return
            end
        end
    end
end

-- Protected Safe Wrapper for Update Loop
local function SafeSpeedometerUpdateLoop(self, elapsed)
    local ok, err = pcall(SpeedometerUpdateLoop, self, elapsed)
    if not ok then
        LazySpeed_StopEngine()
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

    mainFrame:Show()
    mainFrame:SetScript("OnUpdate", SafeSpeedometerUpdateLoop)
end

function LazySpeed_StopEngine()
    if not isEngineActive then
        mainFrame:Hide()
        barSpeed.container:Hide()
        barVigor.container:Hide()
        HideFlameAura()
        return
    end

    isEngineActive = false
    mainFrame:SetScript("OnUpdate", nil)
    mainFrame:Hide()
    barSpeed.container:Hide()
    barVigor.container:Hide()
    HideFlameAura()
    ResetDisplay()
end

function LazySpeed_EvaluateState()
    addon:UpdateLayout()
end

-- ==============================================================================
-- 7. BLIZZARD MODERN SETTINGS API INTEGRATION (Canvas Layout)
-- ==============================================================================
local uiWidgets = {}
local categoryID = nil

local function UpdateOptionsUI()
    if not uiWidgets.panel or not LazySpeedBigginsDB then return end
    local isEnabled = LazySpeedBigginsDB.enabled ~= false

    if uiWidgets.cbEnable   then uiWidgets.cbEnable:SetChecked(isEnabled) end
    if uiWidgets.cbFlying   then uiWidgets.cbFlying:SetChecked(LazySpeedBigginsDB.showFlying) end
    if uiWidgets.cbSwimming then uiWidgets.cbSwimming:SetChecked(LazySpeedBigginsDB.showSwimming) end
    if uiWidgets.cbGround   then uiWidgets.cbGround:SetChecked(LazySpeedBigginsDB.showGround) end
    if uiWidgets.cbVigor    then uiWidgets.cbVigor:SetChecked(LazySpeedBigginsDB.showVigor ~= false) end
    if uiWidgets.cbVigorGlow then uiWidgets.cbVigorGlow:SetChecked(LazySpeedBigginsDB.showVigorGlow ~= false) end
    if uiWidgets.cbCombat   then uiWidgets.cbCombat:SetChecked(LazySpeedBigginsDB.hideInCombat) end
    if uiWidgets.cbLocked   then uiWidgets.cbLocked:SetChecked(LazySpeedBigginsDB.locked or false) end

    local isVertical = (LazySpeedBigginsDB.stackingMode or "VERTICAL") == "VERTICAL"
    if uiWidgets.rbVertical   then uiWidgets.rbVertical:SetChecked(isVertical) end
    if uiWidgets.rbHorizontal then uiWidgets.rbHorizontal:SetChecked(not isVertical) end

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
        uiWidgets.cbFlying, uiWidgets.cbSwimming, uiWidgets.cbGround, uiWidgets.cbVigor, uiWidgets.cbVigorGlow, uiWidgets.cbCombat, uiWidgets.cbLocked,
        uiWidgets.stackHeader, uiWidgets.rbVertical, uiWidgets.rbHorizontal,
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
    addon:UpdateLayout()
    UpdateOptionsUI()
    lastSpeed = -1
    ResetDisplay()
    DEFAULT_CHAT_FRAME:AddMessage("|cFFFFD100LazySpeed Biggins|r: All options have been reset to default.")
end

_G["LazySpeedBiggins_Version"] = "4.0.0"

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
    desc:SetText("High-precision dynamic speedometer & Skyriding Vigor HUD.")

    -- Suite Logo Texture (Top Right)
    local logo = panel:CreateTexture(nil, "ARTWORK")
    logo:SetPoint("TOPRIGHT", -24, -16)
    logo:SetSize(64, 64)
    logo:SetTexture("Interface\\AddOns\\LazySpeedBiggins\\logo.jpg")

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
            addon:UpdateLayout()
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
    local cbEnable = CreateSettingCheckbox("enabled", "Enable Speedometer & Vigor HUD", "Show or hide the dynamic speedometer and Vigor HUD overlay.", "TOPLEFT", desc, "BOTTOMLEFT", 0, -18, function(val)
        local status = val and "|cFF00FF00Enabled|r" or "|cFFFF0000Disabled|r"
        DEFAULT_CHAT_FRAME:AddMessage("|cFFFFD100LazySpeed Biggins|r: HUD is now " .. status .. ".")
    end)
    uiWidgets.cbEnable = cbEnable

    -- Child Checkboxes (Indented 20px)
    local cbFlying = CreateSettingCheckbox("showFlying", "Show Speedometer While Flying / Skyriding", "Displays speedometer while airborne (Skyriding or Steady Flight).", "TOPLEFT", cbEnable, "BOTTOMLEFT", 20, -6)
    uiWidgets.cbFlying = cbFlying

    local cbSwimming = CreateSettingCheckbox("showSwimming", "Show Speedometer While Swimming", "Displays speedometer while submerged in water, tracking swim and aquatic mount speeds.", "TOPLEFT", cbFlying, "BOTTOMLEFT", 0, -6)
    uiWidgets.cbSwimming = cbSwimming

    local cbGround = CreateSettingCheckbox("showGround", "Show Speedometer While on Ground", "Displays speedometer while running on foot or riding ground mounts.", "TOPLEFT", cbSwimming, "BOTTOMLEFT", 0, -6)
    uiWidgets.cbGround = cbGround

    local cbVigor = CreateSettingCheckbox("showVigor", "Show Skyriding Vigor Bar", "Displays a 1-6 recharge bar for Surge Forward / Vigor while mounted in Skyriding mode.", "TOPLEFT", cbGround, "BOTTOMLEFT", 0, -6)
    uiWidgets.cbVigor = cbVigor

    local cbVigorGlow = CreateSettingCheckbox("showVigorGlow", "Glow on Accelerated Recharge Buffs", "Illuminates a Blue glow for Thrill of the Skies, a Red glow for Ground Skimming, and a Violet glow when both are active. When disabled, only the status bar fill changes color.", "TOPLEFT", cbVigor, "BOTTOMLEFT", 20, -6, function(val)
        if not val then
            HideFlameAura()
        end
    end)
    uiWidgets.cbVigorGlow = cbVigorGlow

    local cbCombat = CreateSettingCheckbox("hideInCombat", "Hide During Combat", "Instantly hides and detaches the HUD during combat to keep your screen clear.", "TOPLEFT", cbVigorGlow, "BOTTOMLEFT", -20, -6)
    uiWidgets.cbCombat = cbCombat

    -- Stacking Mode Section
    local stackHeader = panel:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    stackHeader:SetPoint("TOPLEFT", cbCombat, "BOTTOMLEFT", 0, -12)
    stackHeader:SetText("Stacking Mode:")
    uiWidgets.stackHeader = stackHeader

    local function CreateStackingRadio(modeVal, label, tooltip, anchorPoint, relativeTo, relPoint, x, y)
        local radio = CreateFrame("CheckButton", nil, panel, "UIRadioButtonTemplate")
        radio:SetPoint(anchorPoint, relativeTo, relPoint, x, y)
        radio.text = radio:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
        radio.text:SetPoint("LEFT", radio, "RIGHT", 4, 0)
        radio.text:SetText(label)
        radio.tooltipText = tooltip
        radio:SetScript("OnClick", function()
            if not LazySpeedBigginsDB then LazySpeedBigginsDB = {} end
            LazySpeedBigginsDB.stackingMode = modeVal
            addon:UpdateLayout()
            UpdateOptionsUI()
        end)
        radio:SetScript("OnEnter", function(self)
            if self.tooltipText then
                GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
                GameTooltip:SetText(self.tooltipText, 1, 1, 1, true)
                GameTooltip:Show()
            end
        end)
        radio:SetScript("OnLeave", function() GameTooltip:Hide() end)
        return radio
    end

    local rbVertical = CreateStackingRadio("VERTICAL", "Vertical (Default)", "Stacks speedometer directly above the Surge Forward / Vigor bar.", "TOPLEFT", stackHeader, "BOTTOMLEFT", 4, -4)
    uiWidgets.rbVertical = rbVertical

    local rbHorizontal = CreateStackingRadio("HORIZONTAL", "Horizontal", "Stacks speedometer and Vigor bar side-by-side in a compact horizontal ribbon.", "LEFT", rbVertical.text, "RIGHT", 16, 0)
    uiWidgets.rbHorizontal = rbHorizontal

    local cbLocked = CreateSettingCheckbox("locked", "Lock Frame Position", "Prevents dragging the HUD frame with the mouse.", "TOPLEFT", rbVertical, "BOTTOMLEFT", -4, -8, function(val)
        UpdateMouseInteractivity()
        local status = val and "|cFFFF0000Locked|r" or "|cFF00FF00Unlocked|r"
        DEFAULT_CHAT_FRAME:AddMessage("|cFFFFD100LazySpeed Biggins|r: Frame position is now " .. status .. ".")
    end)
    uiWidgets.cbLocked = cbLocked

    -- Unit Selection Header
    local unitHeader = panel:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    unitHeader:SetPoint("TOPLEFT", cbLocked, "BOTTOMLEFT", 0, -12)
    unitHeader:SetText("Speed Measurement Unit:")
    uiWidgets.unitHeader = unitHeader

    -- Radio Helper for Speed Unit
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

    local radioMPH = CreateUnitRadio(2, "Miles per Hour (mph)", "TOPLEFT", unitHeader, "BOTTOMLEFT", 6, -6)
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
            addon:UpdateLayout()
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
    local sliderWidth = CreateSettingSlider("barWidth", "Bar Width", "Adjust horizontal width of HUD bars in pixels.", 100, 300, 1, "TOPLEFT", radioPCT, "BOTTOMLEFT", -6, -20)
    uiWidgets.sliderWidth = sliderWidth

    local sliderHeight = CreateSettingSlider("barHeight", "Bar Height", "Adjust vertical height of HUD bars in pixels.", 14, 36, 1, "TOPLEFT", sliderWidth, "BOTTOMLEFT", 0, -24)
    uiWidgets.sliderHeight = sliderHeight

    -- Reset Position Button
    local btnResetPos = CreateFrame("Button", nil, panel, "UIPanelButtonTemplate")
    btnResetPos:SetPoint("TOPLEFT", sliderHeight, "BOTTOMLEFT", -6, -20)
    btnResetPos:SetSize(160, 24)
    btnResetPos:SetText("Reset Position")
    btnResetPos:SetScript("OnClick", function()
        if not LazySpeedBigginsDB then LazySpeedBigginsDB = {} end
        LazySpeedBigginsDB.point = "CENTER"
        LazySpeedBigginsDB.relativePoint = "CENTER"
        LazySpeedBigginsDB.xOfs = 0
        LazySpeedBigginsDB.yOfs = -200
        RestorePosition()
        DEFAULT_CHAT_FRAME:AddMessage("|cFFFFD100LazySpeed Biggins|r: Frame position reset to center.")
    end)
    btnResetPos:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:SetText("Resets HUD frame back to center screen.", 1, 1, 1, true)
        GameTooltip:Show()
    end)
    btnResetPos:SetScript("OnLeave", function() GameTooltip:Hide() end)
    uiWidgets.btnResetPos = btnResetPos

    -- Slash Command Help Note
    local helpNote = panel:CreateFontString(nil, "ARTWORK", "GameFontDisableSmall")
    helpNote:SetPoint("TOPLEFT", btnResetPos, "BOTTOMLEFT", 0, -14)
    helpNote:SetText("Slash commands: /lazyspeedb (Type /lazyspeedb ? for available commands)")

    panel:SetScript("OnShow", function()
        UpdateOptionsUI()
    end)

    -- Register with modern Settings UI as a subcategory under Biggins AddOns
    if LibBigginsSuite then
        categoryID = LibBigginsSuite:RegisterSubcategory("LazySpeedBiggins", panel, "LazySpeed")
        _G["LazySpeedBiggins_CategoryID"] = categoryID
    elseif Settings and Settings.RegisterCanvasLayoutCategory then
        local category = Settings.RegisterCanvasLayoutCategory(panel, "LazySpeed Biggins")
        Settings.RegisterAddOnCategory(category)
        categoryID = category:GetID()
        _G["LazySpeedBiggins_CategoryID"] = categoryID
    else
        InterfaceOptions_AddCategory(panel)
    end

    UpdateOptionsUI()
end

-- ==============================================================================
-- 8. EVENT CONTROLLER & PASSIVE WATCHER (Low-Frequency Background Gating)
-- ==============================================================================
local EventWatcherFrame = CreateFrame("Frame")

EventWatcherFrame:RegisterEvent("ADDON_LOADED")                -- SavedVariables ready
EventWatcherFrame:RegisterEvent("PLAYER_ENTERING_WORLD")       -- Login or zoning
EventWatcherFrame:RegisterEvent("PLAYER_REGEN_DISABLED")        -- Entering combat
EventWatcherFrame:RegisterEvent("PLAYER_REGEN_ENABLED")         -- Exiting combat
EventWatcherFrame:RegisterEvent("PLAYER_MOUNT_DISPLAY_CHANGED") -- Mounting / Dismounting
EventWatcherFrame:RegisterEvent("SPELL_UPDATE_CHARGES")        -- Vigor / Surge Forward charges update
EventWatcherFrame:RegisterEvent("UPDATE_SHAPESHIFT_FORM")      -- Flight style / stance update
EventWatcherFrame:RegisterEvent("CHALLENGE_MODE_START")         -- Mythic+ key started
EventWatcherFrame:RegisterEvent("CHALLENGE_MODE_COMPLETED")     -- Mythic+ key completed
EventWatcherFrame:RegisterEvent("CHALLENGE_MODE_RESET")         -- Mythic+ key reset
EventWatcherFrame:RegisterEvent("ZONE_CHANGED_NEW_AREA")        -- Zone change
EventWatcherFrame:RegisterUnitEvent("UNIT_AURA", "player")     -- Aura/buff updates (Thrill/Skim)

EventWatcherFrame:SetScript("OnEvent", function(self, event, arg1)
    if event == "ADDON_LOADED" and arg1 == "LazySpeedBiggins" then
        LazySpeedBigginsDB = LazySpeedBigginsDB or {}

        for key, value in pairs(DB_DEFAULTS) do
            if LazySpeedBigginsDB[key] == nil then
                LazySpeedBigginsDB[key] = value
            end
        end

        RestorePosition()
        addon:UpdateLayout()
        InitializeBlizzardSettings()

    elseif event == "PLAYER_REGEN_DISABLED" then
        local hideCombat = (LazySpeedBigginsDB and LazySpeedBigginsDB.hideInCombat)
        if hideCombat ~= false then
            LazySpeed_StopEngine()
        end

    elseif event == "CHALLENGE_MODE_START" then
        LazySpeed_StopEngine()

    elseif event == "PLAYER_REGEN_ENABLED" or event == "PLAYER_ENTERING_WORLD" or event == "PLAYER_MOUNT_DISPLAY_CHANGED"
        or event == "SPELL_UPDATE_CHARGES" or event == "UPDATE_SHAPESHIFT_FORM"
        or event == "CHALLENGE_MODE_COMPLETED" or event == "CHALLENGE_MODE_RESET" or event == "ZONE_CHANGED_NEW_AREA" then
        addon:UpdateLayout()
    end
end)

-- Passive Takeoff / Dive / Resume Detector (Runs at low 4 Hz / every 0.25s while inactive)
local passivePollTimer = 0
EventWatcherFrame:SetScript("OnUpdate", function(self, elapsed)
    local db = LazySpeedBigginsDB or DB_DEFAULTS

    if isEngineActive then return end
    if db.hideInCombat and IsPlayerInCombat() then return end

    passivePollTimer = passivePollTimer + elapsed
    if passivePollTimer < 0.25 then return end
    passivePollTimer = 0

    if IsRestrictedEnvironment() then return end

    local testSpeed = GetUnitSpeed("player")
    if IsSecret(testSpeed) then return end

    if db.showGround then
        addon:UpdateLayout()
        return
    end

    local isGliding = GetGlidingInfo()
    if IsSecret(isGliding) then return end

    local isSteadyFlying = IsFlying and IsFlying()
    local isSwimming = IsSwimming and IsSwimming()
    if IsSecret(isSteadyFlying) or IsSecret(isSwimming) then return end

    local isAirborne = isGliding or isSteadyFlying
    local isSkyriding = IsInSkyridingMode()

    if (isAirborne and db.showFlying) or (isSwimming and db.showSwimming) or (isSkyriding and db.showVigor ~= false) then
        addon:UpdateLayout()
    end
end)

-- ==============================================================================
-- 9. SLASH COMMANDS (/lazyspeedb)
-- ==============================================================================
SLASH_LAZYSPEED1 = "/lazyspeedb"
SlashCmdList["LAZYSPEED"] = function(msg)
    local command = msg:lower():trim()
    local db = LazySpeedBigginsDB or DB_DEFAULTS

    if command == "" or command == "options" or command == "config" or command == "settings" then
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
        addon:UpdateLayout()
        local status = LazySpeedBigginsDB.enabled and "|cFF00FF00Enabled|r" or "|cFFFF0000Disabled|r"
        DEFAULT_CHAT_FRAME:AddMessage("|cFFFFD100LazySpeed Biggins|r: HUD is now " .. status .. ".")
    elseif command == "vigor" then
        if not LazySpeedBigginsDB then LazySpeedBigginsDB = {} end
        LazySpeedBigginsDB.showVigor = not (LazySpeedBigginsDB.showVigor ~= false)
        UpdateOptionsUI()
        addon:UpdateLayout()
        local status = LazySpeedBigginsDB.showVigor and "|cFF00FF00Enabled|r" or "|cFFFF0000Disabled|r"
        DEFAULT_CHAT_FRAME:AddMessage("|cFFFFD100LazySpeed Biggins|r: Skyriding Vigor bar is now " .. status .. ".")
    elseif command == "aura" or command == "glow" or command == "flame" then
        if not LazySpeedBigginsDB then LazySpeedBigginsDB = {} end
        LazySpeedBigginsDB.showVigorGlow = not (LazySpeedBigginsDB.showVigorGlow ~= false)
        if not LazySpeedBigginsDB.showVigorGlow then
            HideFlameAura()
        end
        UpdateOptionsUI()
        addon:UpdateLayout()
        local status = LazySpeedBigginsDB.showVigorGlow and "|cFF00FF00Enabled|r" or "|cFFFF0000Disabled|r"
        DEFAULT_CHAT_FRAME:AddMessage("|cFFFFD100LazySpeed Biggins|r: Recharge buff glow is now " .. status .. ".")
    elseif command == "stack" or command == "mode" or command:find("^stack ") or command:find("^mode ") then
        local sub = command:gsub("^[a-z]+%s*", "")
        if sub == "horizontal" or sub == "horiz" or sub == "h" then
            db.stackingMode = "HORIZONTAL"
        elseif sub == "vertical" or sub == "vert" or sub == "v" then
            db.stackingMode = "VERTICAL"
        else
            db.stackingMode = (db.stackingMode == "HORIZONTAL") and "VERTICAL" or "HORIZONTAL"
        end
        addon:UpdateLayout()
        UpdateOptionsUI()
        local modeDesc = (db.stackingMode == "HORIZONTAL") and "Horizontal" or "Vertical"
        DEFAULT_CHAT_FRAME:AddMessage("|cFFFFD100LazySpeed Biggins|r: Stacking mode is now |cFF00FF00" .. modeDesc .. "|r.")
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
        addon:UpdateLayout()
        DEFAULT_CHAT_FRAME:AddMessage("|cFFFFD100LazySpeed Biggins|r: Frame position reset to center.")
    elseif command == "status" then
        local function ColorBool(val) return val and "|cFF00FF00[ON]|r" or "|cFFFF0000[OFF]|r" end
        DEFAULT_CHAT_FRAME:AddMessage("|cFFFFD100LazySpeed Biggins|r Current Configuration:")
        DEFAULT_CHAT_FRAME:AddMessage(string.format("  Master Enable:    %s", ColorBool(db.enabled ~= false)))
        DEFAULT_CHAT_FRAME:AddMessage(string.format("  Stacking Mode:    |cFF00FF00%s|r", (db.stackingMode == "HORIZONTAL") and "Horizontal" or "Vertical"))
        DEFAULT_CHAT_FRAME:AddMessage(string.format("  Frame Locked:     %s", ColorBool(db.locked or false)))
        DEFAULT_CHAT_FRAME:AddMessage(string.format("  Show Flying:      %s", ColorBool(db.showFlying)))
        DEFAULT_CHAT_FRAME:AddMessage(string.format("  Show Swimming:    %s", ColorBool(db.showSwimming)))
        DEFAULT_CHAT_FRAME:AddMessage(string.format("  Show Ground:      %s", ColorBool(db.showGround)))
        DEFAULT_CHAT_FRAME:AddMessage(string.format("  Show Vigor Bar:   %s", ColorBool(db.showVigor ~= false)))
        DEFAULT_CHAT_FRAME:AddMessage(string.format("  Show Buff Glow:   %s", ColorBool(db.showVigorGlow ~= false)))
        DEFAULT_CHAT_FRAME:AddMessage(string.format("  Hide in Combat:   %s", ColorBool(db.hideInCombat)))
        DEFAULT_CHAT_FRAME:AddMessage(string.format("  Measurement Unit: %s", modeLabels[db.unitMode or 4] or "%"))
        DEFAULT_CHAT_FRAME:AddMessage(string.format("  Bar Dimensions:   %d x %d px", db.barWidth or 180, db.barHeight or 22))
    elseif command == "help" or command == "?" then
        DEFAULT_CHAT_FRAME:AddMessage("|cFFFFD100LazySpeed Biggins:|r Commands:")
        DEFAULT_CHAT_FRAME:AddMessage("  |cFFFFD100/lazyspeedb|r - Open options menu")
        DEFAULT_CHAT_FRAME:AddMessage("  |cFFFFD100/lazyspeedb toggle|r - Toggle master HUD on/off")
        DEFAULT_CHAT_FRAME:AddMessage("  |cFFFFD100/lazyspeedb vigor|r - Toggle Skyriding Vigor bar on/off")
        DEFAULT_CHAT_FRAME:AddMessage("  |cFFFFD100/lazyspeedb glow|r (or |cFFFFD100/lazyspeedb aura|r) - Toggle recharge buff glow on/off")
        DEFAULT_CHAT_FRAME:AddMessage("  |cFFFFD100/lazyspeedb stack [horiz/vert]|r - Switch horizontal or vertical layout")
        DEFAULT_CHAT_FRAME:AddMessage("  |cFFFFD100/lazyspeedb lock|r - Toggle locking frame position")
        DEFAULT_CHAT_FRAME:AddMessage("  |cFFFFD100/lazyspeedb reset|r - Reset frame position to center")
        DEFAULT_CHAT_FRAME:AddMessage("  |cFFFFD100/lazyspeedb defaults|r - Reset all options to default")
        DEFAULT_CHAT_FRAME:AddMessage("  |cFFFFD100/lazyspeedb status|r - Display current configuration")
        DEFAULT_CHAT_FRAME:AddMessage("  |cFFFFD100/lazyspeedb help|r or |cFFFFD100/lazyspeedb ?|r - Show this list of commands")
        DEFAULT_CHAT_FRAME:AddMessage("  |cFFFFD100/lazyspeedb defaults|r - Reset all options to default")
        DEFAULT_CHAT_FRAME:AddMessage("  |cFFFFD100/lazyspeedb status|r - Display current configuration")
        DEFAULT_CHAT_FRAME:AddMessage("  |cFFFFD100/lazyspeedb help|r or |cFFFFD100/lazyspeedb ?|r - Show this list of commands")
    else
        DEFAULT_CHAT_FRAME:AddMessage("|cFFFFD100LazySpeed Biggins:|r Unknown command '|cFFFFD100" .. command .. "|r'. Type |cFFFFD100/lazyspeedb help|r for available commands.")
    end
end
