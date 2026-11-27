--[[ ==============================================================================
    Perf Biggins - HUD Status Bars & Dynamic Layout Engine
    ------------------------------------------------------------------------------
    Manages the master frame, Blizzard Gold bordered status bars, unified drag
    handlers, mouse interactivity, and dynamic stack / ribbon layout.
============================================================================== ]]--

local addonName, addon = ...

-- Cache global functions
local CreateFrame  = CreateFrame
local UIParent     = UIParent
local table_insert = table.insert
local ipairs       = ipairs
local math_min     = math.min
local math_max     = math.max
local math_floor   = math.floor

-- Transparent master container frame managing stack anchoring and unified movement
local mainFrame = CreateFrame("Frame", "PerfBigginsFrame", UIParent)
mainFrame:SetClampedToScreen(true)
mainFrame:SetMovable(true)
mainFrame:EnableMouse(true)
mainFrame:RegisterForDrag("LeftButton")
addon.mainFrame = mainFrame

-- Unified Drag Handlers: Dragging any bar moves the entire stack as a single unit
local function OnDragStartHandler(self)
    local db = PerfBigginsDB or addon.DB_DEFAULTS
    if not db.locked then
        mainFrame:StartMoving()
    end
end

local function OnDragStopHandler(self)
    mainFrame:StopMovingOrSizing()
    local point, _, relPoint, x, y = mainFrame:GetPoint()
    local db = PerfBigginsDB
    if db then
        db.point = point or "CENTER"
        db.relativePoint = relPoint or "CENTER"
        db.xOfs = x or 0
        db.yOfs = y or -160
    end
end

mainFrame:SetScript("OnDragStart", OnDragStartHandler)
mainFrame:SetScript("OnDragStop", OnDragStopHandler)

-- Helper to create individual status bars wrapped in a Blizzard Gold bordered container
local function CreateTelemetryBar(barName, defaultText)
    -- Visual container frame with Blizzard metallic gold border (matching LazySpeed)
    local container = CreateFrame("Frame", barName .. "Container", mainFrame, "BackdropTemplate")
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
    container:SetBackdropColor(0.05, 0.05, 0.05, 0.85)
    container:SetBackdropBorderColor(0.8, 0.7, 0.2, 1.0) -- Blizzard Metallic Gold

    local bar = CreateFrame("StatusBar", barName, container)
    bar:SetPoint("CENTER", container, "CENTER", 0, 0)
    bar:SetStatusBarTexture("Interface\\TargetingFrame\\UI-StatusBar")
    bar:SetMinMaxValues(0, 100)
    bar:SetValue(0)

    -- Subtle dark background track behind the status bar
    local bg = bar:CreateTexture(nil, "BACKGROUND")
    bg:SetAllPoints(bar)
    bg:SetTexture("Interface\\TargetingFrame\\UI-StatusBar")
    bg:SetVertexColor(0.05, 0.05, 0.05, 0.75)
    bar.bg = bg

    -- Centered text overlay
    local text = bar:CreateFontString(nil, "OVERLAY")
    text:SetPoint("CENTER", bar, "CENTER", 0, 0)
    text:SetFont(addon:GetDefaultFont(), 11, "OUTLINE")
    text:SetTextColor(1, 1, 1, 1)
    text:SetShadowOffset(1, -1)
    text:SetShadowColor(0, 0, 0, 1)
    text:SetText(defaultText)
    bar.text = text

    bar.container = container
    return bar
end

local barFps   = CreateTelemetryBar("PerfBigginsBarFPS", "--- FPS")
local barWorld = CreateTelemetryBar("PerfBigginsBarWorld", "--- ms World")
local barHome  = CreateTelemetryBar("PerfBigginsBarHome", "--- ms Home")

addon.barFps   = barFps
addon.barWorld = barWorld
addon.barHome  = barHome

-- Dynamic Layout & Collapse Engine
function addon:UpdateLayout()
    local db = PerfBigginsDB or addon.DB_DEFAULTS
    if db.enabled == false then
        mainFrame:Hide()
        return
    end

    local width  = db.barWidth or 180
    local height = db.barHeight or 18

    -- Build list of currently visible bars in order
    local visibleBars = {}
    if db.showFps   then table_insert(visibleBars, barFps)   else barFps.container:Hide()   end
    if db.showWorld then table_insert(visibleBars, barWorld) else barWorld.container:Hide() end
    if db.showHome  then table_insert(visibleBars, barHome)  else barHome.container:Hide()  end

    local count = #visibleBars
    if count == 0 then
        mainFrame:Hide()
        return
    end

    -- If in combat and hideInCombat is on, keep hidden
    if db.hideInCombat and addon:IsInCombat() then
        mainFrame:Hide()
        return
    else
        mainFrame:Show()
    end

    -- Split Bar Sizing & Gap (Vertical stack or Horizontal ribbon)
    local gap = db.barSpacing or 4
    local isHorizontal = (db.stackingMode == "HORIZONTAL")
    local totalWidth, totalHeight
    if isHorizontal then
        totalWidth  = (count * width) + ((count - 1) * gap)
        totalHeight = height
    else
        totalWidth  = width
        totalHeight = (count * height) + ((count - 1) * gap)
    end

    mainFrame:SetSize(totalWidth, math_max(1, totalHeight))

    -- Dynamic font sizing based on bar height
    local fontSize = math_max(9, math_min(14, math_floor(height * 0.62)))
    local fontPath = addon:GetDefaultFont()

    -- Anchor visible bar containers sequentially
    local prevContainer = nil
    for i, bar in ipairs(visibleBars) do
        local c = bar.container
        c:ClearAllPoints()
        c:SetSize(width, height)

        bar:ClearAllPoints()
        bar:SetPoint("CENTER", c, "CENTER", 0, 0)
        bar:SetSize(math_max(1, width - 6), math_max(1, height - 6))
        bar.text:SetFont(fontPath, fontSize, "OUTLINE")

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
    for _, b in ipairs({ barFps, barWorld, barHome }) do
        b.container:SetBackdropColor(0.05, 0.05, 0.05, bgAlpha)
        b.bg:SetVertexColor(0.05, 0.05, 0.05, bgAlpha * 0.88)
    end

    -- Update interactivity
    addon:UpdateInteractivity()
end

-- Update mouse interactivity based on locked setting
function addon:UpdateInteractivity()
    local db = PerfBigginsDB or addon.DB_DEFAULTS
    local mouseEnabled = not db.locked
    mainFrame:EnableMouse(mouseEnabled)
    barFps.container:EnableMouse(mouseEnabled)
    barWorld.container:EnableMouse(mouseEnabled)
    barHome.container:EnableMouse(mouseEnabled)
end

-- Restore saved position on screen
function addon:RestorePosition()
    local db = PerfBigginsDB or addon.DB_DEFAULTS
    mainFrame:ClearAllPoints()
    mainFrame:SetPoint(db.point or "CENTER", UIParent, db.relativePoint or "CENTER", db.xOfs or 0, db.yOfs or -160)
end
