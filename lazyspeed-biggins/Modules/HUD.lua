--[[ ==============================================================================
    LazySpeed Biggins - HUD Status Bars & Dynamic Layout Engine
    ------------------------------------------------------------------------------
    Manages the master frame, Blizzard Gold bordered status bars, threat flare
    flame aura animations, mouse interactivity, and dynamic stack layout.
============================================================================== ]]--

local addonName, addon = ...

-- Cache global functions
local CreateFrame         = CreateFrame
local UIParent            = UIParent
local min                 = math.min
local max                 = math.max
local floor               = math.floor
local pi                  = math.pi
local ipairs              = ipairs
local table_insert        = table.insert
local STANDARD_TEXT_FONT  = STANDARD_TEXT_FONT or "Fonts\\FRIZQT__.TTF"

local C_Texture           = C_Texture
local GetGlidingInfo      = C_PlayerInfo and C_PlayerInfo.GetGlidingInfo
local IsFlying            = IsFlying
local IsSwimming          = IsSwimming
local GetUnitSpeed        = GetUnitSpeed

-- Master container frame managing stack anchoring and unified movement
local mainFrame = CreateFrame("Frame", "LazySpeedBigginsFrame", UIParent)
mainFrame:SetSize(180, 22)
mainFrame:SetPoint("CENTER", UIParent, "CENTER", 0, -200)
mainFrame:SetClampedToScreen(true)
mainFrame:SetMovable(true)
mainFrame:EnableMouse(true)
mainFrame:RegisterForDrag("LeftButton")
mainFrame:Hide()
addon.mainFrame = mainFrame

-- Unified Drag Handlers
local function OnDragStartHandler(self)
    local db = LazySpeedBigginsDB or addon.DB_DEFAULTS
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
    container:SetBackdropColor(addon.COLOR_CONTAINER_BG[1], addon.COLOR_CONTAINER_BG[2], addon.COLOR_CONTAINER_BG[3], addon.COLOR_CONTAINER_BG[4])
    container:SetBackdropBorderColor(addon.COLOR_GOLD_BORDER[1], addon.COLOR_GOLD_BORDER[2], addon.COLOR_GOLD_BORDER[3], addon.COLOR_GOLD_BORDER[4])

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
    bg:SetVertexColor(addon.COLOR_TRACK_BG[1], addon.COLOR_TRACK_BG[2], addon.COLOR_TRACK_BG[3], addon.COLOR_TRACK_BG[4])
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

addon.barSpeed = barSpeed
addon.barVigor = barVigor

-- ==============================================================================
-- Accelerated Recharge Perimeter Flame Aura (Stock Nameplate Threat Flare)
-- ==============================================================================
local vigorFlameFrame = CreateFrame("Frame", "LazySpeedBigginsVigorFlameFrame", mainFrame)
vigorFlameFrame:SetFrameStrata(mainFrame:GetFrameStrata())
vigorFlameFrame:SetFrameLevel(1) -- Low priority z-axis: tucked cleanly behind bars
vigorFlameFrame:SetAllPoints(barVigor.container)
vigorFlameFrame:Hide()

addon.vigorFlameFrame = vigorFlameFrame
barVigor.flameFrame   = vigorFlameFrame
barVigor.glow         = vigorFlameFrame

local vigorFlames = {}

local function AddFlameTexture(tex, isAdditive)
    if isAdditive then
        tex:SetBlendMode("ADD")
        tex:SetAlpha(0.65)
    else
        tex:SetBlendMode("BLEND")
        tex:SetAlpha(0.95)
    end
    table_insert(vigorFlames, tex)
    return tex
end

local flareAtlas = "UI-HUD-Nameplates-Aggro-Flare"
local flareInfo  = C_Texture and C_Texture.GetAtlasInfo and C_Texture.GetAtlasInfo(flareAtlas)

-- 1. TOP EDGE FLAMES
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

-- 2. BOTTOM EDGE FLAMES
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
    flameBottomBase:SetRotation(pi)
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
    flameBottomAdd:SetRotation(pi)
    flameBottomAdd:SetHorizTile(true)
end

-- 3. LEFT EDGE FLAMES
local flameLeftBase = AddFlameTexture(vigorFlameFrame:CreateTexture(nil, "BACKGROUND", nil, -2), false)
flameLeftBase:SetPoint("TOPRIGHT", vigorFlameFrame, "TOPLEFT", 4, 1)
flameLeftBase:SetPoint("BOTTOMRIGHT", vigorFlameFrame, "BOTTOMLEFT", 4, -1)
flameLeftBase:SetWidth(14)
flameLeftBase:SetAtlas(flareAtlas)
flameLeftBase:SetRotation(pi / 2)

local flameLeftAdd = AddFlameTexture(vigorFlameFrame:CreateTexture(nil, "BACKGROUND", nil, -1), true)
flameLeftAdd:SetAllPoints(flameLeftBase)
flameLeftAdd:SetAtlas(flareAtlas)
flameLeftAdd:SetRotation(pi / 2)

-- 4. RIGHT EDGE FLAMES
local flameRightBase = AddFlameTexture(vigorFlameFrame:CreateTexture(nil, "BACKGROUND", nil, -2), false)
flameRightBase:SetPoint("TOPLEFT", vigorFlameFrame, "TOPRIGHT", -4, 1)
flameRightBase:SetPoint("BOTTOMLEFT", vigorFlameFrame, "BOTTOMRIGHT", -4, -1)
flameRightBase:SetWidth(14)
flameRightBase:SetAtlas(flareAtlas)
flameRightBase:SetRotation(-pi / 2)

local flameRightAdd = AddFlameTexture(vigorFlameFrame:CreateTexture(nil, "BACKGROUND", nil, -1), true)
flameRightAdd:SetAllPoints(flameRightBase)
flameRightAdd:SetAtlas(flareAtlas)
flameRightAdd:SetRotation(-pi / 2)

function addon:SetFlameAuraColor(r, g, b)
    if not vigorFlameFrame:IsShown() then
        vigorFlameFrame:Show()
    end
    for _, tex in ipairs(vigorFlames) do
        tex:SetVertexColor(r, g, b)
    end
    barVigor.container:SetBackdropBorderColor(r, g, b, 1.0)
end

function addon:HideFlameAura()
    if vigorFlameFrame:IsShown() then
        vigorFlameFrame:Hide()
    end
    barVigor.container:SetBackdropBorderColor(addon.COLOR_GOLD_BORDER[1], addon.COLOR_GOLD_BORDER[2], addon.COLOR_GOLD_BORDER[3], addon.COLOR_GOLD_BORDER[4])
end

-- Restore saved screen position
function addon:RestorePosition()
    local db = LazySpeedBigginsDB or addon.DB_DEFAULTS
    mainFrame:ClearAllPoints()
    mainFrame:SetPoint(db.point or "CENTER", UIParent, db.relativePoint or "CENTER", db.xOfs or 0, db.yOfs or -200)
end

-- Update mouse interactivity based on locked state
function addon:UpdateMouseInteractivity()
    local db = LazySpeedBigginsDB or addon.DB_DEFAULTS
    local mouseEnabled = not db.locked
    mainFrame:EnableMouse(mouseEnabled)
    barSpeed.container:EnableMouse(mouseEnabled)
    barVigor.container:EnableMouse(mouseEnabled)
end

-- Helper: Reset visual elements to zero state
function addon:ResetDisplay()
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
    barSpeed:SetStatusBarColor(addon.COLOR_SPEED_CRUISE[1], addon.COLOR_SPEED_CRUISE[2], addon.COLOR_SPEED_CRUISE[3], addon.COLOR_SPEED_CRUISE[4])
    barVigor:SetValue(0)
    barVigor.text:SetText("6 / 6 Vigor")
    barVigor.container:SetBackdropBorderColor(addon.COLOR_GOLD_BORDER[1], addon.COLOR_GOLD_BORDER[2], addon.COLOR_GOLD_BORDER[3], addon.COLOR_GOLD_BORDER[4])
    addon:HideFlameAura()
    addon.lastSpeed = 0
end

-- Dynamic Layout & Stacking Engine
function addon:UpdateLayout()
    local db = LazySpeedBigginsDB or addon.DB_DEFAULTS
    if db.enabled == false then
        LazySpeed_StopEngine()
        return
    end

    addon.landingDebounce = 0

    if db.hideInCombat and addon:IsPlayerInCombat() then
        LazySpeed_StopEngine()
        return
    end

    if addon:IsRestrictedEnvironment() then
        LazySpeed_StopEngine()
        return
    end

    -- Evaluate Speed Bar Visibility
    local rawGroundSpeed = GetUnitSpeed("player")
    local isGliding, canGlide, forwardSpeed = GetGlidingInfo()
    local isSteadyFlying = IsFlying and IsFlying()
    local isSwimming = IsSwimming and IsSwimming()

    if addon:IsSecret(rawGroundSpeed) or addon:IsSecret(forwardSpeed) or addon:IsSecret(isGliding) or addon:IsSecret(isSteadyFlying) or addon:IsSecret(isSwimming) then
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
    if (db.showVigor ~= false) and addon:IsInSkyridingMode() then
        local charges, maxCharges = addon:GetSurgeForwardCharges()
        if charges ~= nil then
            if db.hideVigorWhenFull and maxCharges and (charges >= maxCharges) then
                showVigor = false
            else
                showVigor = true
            end
        end
    end

    -- Build list of currently visible bars (Speedometer on top/first, Vigor underneath/second)
    local visibleBars = {}
    if showSpeed then
        table_insert(visibleBars, barSpeed)
    else
        barSpeed.container:Hide()
    end

    if showVigor then
        table_insert(visibleBars, barVigor)
    else
        barVigor.container:Hide()
        addon:HideFlameAura()
    end

    local count = #visibleBars
    if count == 0 then
        LazySpeed_StopEngine()
        return
    end

    -- Bar Sizing & Gap Calculation
    local width  = db.barWidth or 180
    local height = db.barHeight or 22
    local gap    = db.barSpacing or 4
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

    -- Apply background opacity to containers and tracks
    local bgAlpha = (db.bgAlpha ~= nil and db.bgAlpha or 25) / 100
    for _, b in ipairs({ barSpeed, barVigor }) do
        b.container:SetBackdropColor(addon.COLOR_CONTAINER_BG[1], addon.COLOR_CONTAINER_BG[2], addon.COLOR_CONTAINER_BG[3], bgAlpha)
        b.bg:SetVertexColor(addon.COLOR_TRACK_BG[1], addon.COLOR_TRACK_BG[2], addon.COLOR_TRACK_BG[3], bgAlpha * 0.8)
    end

    addon:UpdateMouseInteractivity()
    LazySpeed_StartEngine()
end
