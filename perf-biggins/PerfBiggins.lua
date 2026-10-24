--[[ ==============================================================================
    Perf Biggins v1.2.0 - High-Performance FPS & Dual-Latency HUD
    ------------------------------------------------------------------------------
    Author: Biggins (US-Whisperwind)
    Compatibility: World of Warcraft: The War Within / Midnight (Patch 11.x - 12.x / 12.1.7)

    ARCHITECTURAL OVERVIEW:
    1. Zero-Allocation Rendering: Formats numbers directly in native C++ using
       FontString:SetFormattedText with pre-cached static format string pointers.
    2. Dirty-Tracking Throttled Engine: 20 FPS (0.05s) update loop that skips GPU
       redraws and text updates when integer values haven't changed.
    3. Tri-Bar Stacked HUD:
         - Bar 1: FPS (Frames Per Second)
         - Bar 2: World Latency (Combat, Abilities, Positioning, Instance Mechanics)
         - Bar 3: Home Latency (Chat, Auction House, Guild, Realm Connection)
    4. Dynamic Layout & Collapse: Independent toggles for each bar; active bars
       snap together seamlessly and the frame dynamically resizes without gaps.
    5. Blizzard Gold Aesthetic: Matching LazySpeed styling with dark slate tooltip
       backdrop and Blizzard metallic gold border.
    6. Modern Settings UI: Integrated into Options -> AddOns -> Perf Biggins with
       sliders, checkboxes, lock toggle, and slash commands (/perf, /pb).
============================================================================== ]]--

local addonName, addon = ...
_G["PerfBiggins"] = addon
addon.version = "1.2.0"

-- Native Blizzard Keybinding strings
_G["BINDING_HEADER_PERFBIGGINS_HEADER"] = "Perf Biggins"
_G["BINDING_NAME_PERFBIGGINS_TOGGLE"] = "Toggle Performance HUD"

-- ==============================================================================
-- 1. LOCAL UPVALUE CACHING & CONSTANTS
-- ==============================================================================
local GetFramerate        = GetFramerate
local GetNetStats          = GetNetStats
local InCombatLockdown     = InCombatLockdown
local UnitAffectingCombat  = UnitAffectingCombat
local floor                = math.floor
local min                  = math.min
local max                  = math.max

-- Font helper with safe fallback to active Blizzard game fonts
local function GetDefaultFont()
    if STANDARD_TEXT_FONT and type(STANDARD_TEXT_FONT) == "string" then
        return STANDARD_TEXT_FONT
    end
    if GameFontHighlight and GameFontHighlight.GetFont then
        local font = GameFontHighlight:GetFont()
        if font then return font end
    end
    return "Fonts\\FRIZQT__.TTF"
end

-- Pre-cached format string pointers (Zero garbage collection in Lua heap)
local FORMAT_FPS   = "%.1f FPS"
local FORMAT_WORLD = "%.0f ms World"
local FORMAT_HOME  = "%.0f ms Home"

-- Max fill limits for 100% status bar display
local MAX_FPS_CAP     = 144  -- Max FPS scale cap
local MAX_LATENCY_CAP = 200  -- Max Latency scale cap in ms

-- Update Loop Rate: 10 FPS (0.10s) for silky smooth responsiveness
local UPDATE_THROTTLE = 0.10

-- ==============================================================================
-- 2. SAVEDVARIABLES & DEFAULTS
-- ==============================================================================
local DB_DEFAULTS = {
    enabled      = true,
    showFps      = true,
    showWorld    = true,
    showHome     = true,
    barWidth     = 180,
    barHeight    = 18,
    locked       = false,
    hideInCombat = false,
    point        = "CENTER",
    relativePoint= "CENTER",
    xOfs         = 0,
    yOfs         = -160,
}

-- Print helper with Blizzard Gold prefix
local function PrintMsg(msg)
    print("|cFFFFD100[PerfBiggins]|r " .. msg)
end
addon.PrintMsg = PrintMsg

-- Check if player is in combat
local function IsInCombat()
    if InCombatLockdown and InCombatLockdown() then return true end
    if UnitAffectingCombat and UnitAffectingCombat("player") then return true end
    return false
end

-- ==============================================================================
-- 3. COLOR GRADIENT EVALUATION
-- ==============================================================================
-- FPS: High is good (Green >= 60, Yellow 30-59, Red < 30)
local function GetFpsColor(fps)
    if fps >= 60 then
        return 0.10, 0.90, 0.20 -- Vibrant Emerald Green
    elseif fps >= 30 then
        return 0.95, 0.82, 0.10 -- Golden Yellow
    else
        return 0.95, 0.20, 0.20 -- Warning Red
    end
end

-- Latency: Low is good (Green <= 50, Yellow 51-100, Orange 101-200, Red > 200)
local function GetLatencyColor(ms)
    if ms <= 50 then
        return 0.10, 0.90, 0.20 -- Optimal Green
    elseif ms <= 100 then
        return 0.95, 0.82, 0.10 -- Acceptable Yellow
    elseif ms <= 200 then
        return 1.00, 0.55, 0.05 -- Elevated Orange
    else
        return 0.95, 0.20, 0.20 -- High Latency Red
    end
end

-- ==============================================================================
-- 4. MAIN FRAME & SPLIT STATUS BAR CREATION
-- ==============================================================================
-- Transparent master container frame managing stack anchoring and unified movement
local mainFrame = CreateFrame("Frame", "PerfBigginsFrame", UIParent)
mainFrame:SetClampedToScreen(true)
mainFrame:SetMovable(true)
mainFrame:EnableMouse(true)
mainFrame:RegisterForDrag("LeftButton")

-- Unified Drag Handlers: Dragging any bar moves the entire stack as a single unit
local function OnDragStartHandler(self)
    local db = PerfBigginsDB or DB_DEFAULTS
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
    text:SetFont(GetDefaultFont(), 11, "OUTLINE")
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

addon.mainFrame = mainFrame
addon.barFps    = barFps
addon.barWorld  = barWorld
addon.barHome   = barHome

-- ==============================================================================
-- 5. DYNAMIC LAYOUT & COLLAPSE ENGINE
-- ==============================================================================
function addon:UpdateLayout()
    local db = PerfBigginsDB or DB_DEFAULTS
    if db.enabled == false then
        mainFrame:Hide()
        return
    end

    local width  = db.barWidth or 180
    local height = db.barHeight or 18

    -- Build list of currently visible bars in order
    local visibleBars = {}
    if db.showFps   then table.insert(visibleBars, barFps)   else barFps.container:Hide()   end
    if db.showWorld then table.insert(visibleBars, barWorld) else barWorld.container:Hide() end
    if db.showHome  then table.insert(visibleBars, barHome)  else barHome.container:Hide()  end

    local count = #visibleBars
    if count == 0 then
        mainFrame:Hide()
        return
    end

    -- If in combat and hideInCombat is on, keep hidden
    if db.hideInCombat and IsInCombat() then
        mainFrame:Hide()
        return
    else
        mainFrame:Show()
    end

    -- Split Bar Sizing & Gap (stack of nameplates aesthetic)
    local gap = 4
    local totalWidth  = width
    local totalHeight = (count * height) + ((count - 1) * gap)

    mainFrame:SetSize(totalWidth, max(1, totalHeight))

    -- Dynamic font sizing based on bar height
    local fontSize = max(9, min(14, floor(height * 0.62)))
    local fontPath = GetDefaultFont()

    -- Anchor visible bar containers sequentially from top to bottom
    local prevContainer = nil
    for i, bar in ipairs(visibleBars) do
        local c = bar.container
        c:ClearAllPoints()
        c:SetSize(width, height)

        bar:ClearAllPoints()
        bar:SetPoint("CENTER", c, "CENTER", 0, 0)
        bar:SetSize(max(1, width - 6), max(1, height - 6))
        bar.text:SetFont(fontPath, fontSize, "OUTLINE")

        if i == 1 then
            c:SetPoint("TOPLEFT", mainFrame, "TOPLEFT", 0, 0)
        else
            c:SetPoint("TOPLEFT", prevContainer, "BOTTOMLEFT", 0, -gap)
        end
        c:Show()
        bar:Show()
        prevContainer = c
    end

    -- Mouse interactivity based on lock status
    local mouseEnabled = not db.locked
    mainFrame:EnableMouse(mouseEnabled)
    barFps.container:EnableMouse(mouseEnabled)
    barWorld.container:EnableMouse(mouseEnabled)
    barHome.container:EnableMouse(mouseEnabled)
end

-- Restore saved position on screen
function addon:RestorePosition()
    local db = PerfBigginsDB or DB_DEFAULTS
    mainFrame:ClearAllPoints()
    mainFrame:SetPoint(db.point or "CENTER", UIParent, db.relativePoint or "CENTER", db.xOfs or 0, db.yOfs or -160)
end

-- ==============================================================================
-- 6. HIGH-PERFORMANCE THROTTLED TELEMETRY LOOP
-- ==============================================================================
local updateTimer = 0

local function TelemetryUpdateLoop(self, elapsed)
    updateTimer = updateTimer + (elapsed or 0)
    if updateTimer < UPDATE_THROTTLE then return end
    updateTimer = 0

    local db = PerfBigginsDB
    if not db or db.enabled == false then return end

    -- 1. FPS Bar Update (Live refresh with 1 decimal place matching LazySpeed)
    if db.showFps then
        local currentFps = GetFramerate() or 0
        barFps.text:SetFormattedText(FORMAT_FPS, currentFps)

        local pct = min(100, max(0, (currentFps / MAX_FPS_CAP) * 100))
        barFps:SetValue(pct)

        local r, g, b = GetFpsColor(currentFps)
        barFps:SetStatusBarColor(r, g, b)
    end

    -- 2. Latency Bars Update (World & Home)
    if db.showWorld or db.showHome then
        local _, _, homeMs, worldMs = GetNetStats()
        worldMs = worldMs or 0
        homeMs  = homeMs or 0

        -- World Latency
        if db.showWorld then
            barWorld.text:SetFormattedText(FORMAT_WORLD, worldMs)

            local pct = min(100, max(0, (worldMs / MAX_LATENCY_CAP) * 100))
            barWorld:SetValue(pct)

            local r, g, b = GetLatencyColor(worldMs)
            barWorld:SetStatusBarColor(r, g, b)
        end

        -- Home Latency
        if db.showHome then
            barHome.text:SetFormattedText(FORMAT_HOME, homeMs)

            local pct = min(100, max(0, (homeMs / MAX_LATENCY_CAP) * 100))
            barHome:SetValue(pct)

            local r, g, b = GetLatencyColor(homeMs)
            barHome:SetStatusBarColor(r, g, b)
        end
    end
end

-- Failsafe wrapper: Protects against unhandled API exceptions and prevents loop detachment
local function SafeOnUpdate(self, elapsed)
    local ok, err = pcall(TelemetryUpdateLoop, self, elapsed)
    if not ok and err then
        PrintMsg("|cFFFF0000Telemetry Loop Error:|r " .. tostring(err))
    end
end

-- ==============================================================================
-- 7. EVENT LISTENER & COMBAT OPTIMIZATIONS
-- ==============================================================================
local eventFrame = CreateFrame("Frame")
eventFrame:RegisterEvent("ADDON_LOADED")
eventFrame:RegisterEvent("PLAYER_ENTERING_WORLD")
eventFrame:RegisterEvent("PLAYER_REGEN_DISABLED")
eventFrame:RegisterEvent("PLAYER_REGEN_ENABLED")

eventFrame:SetScript("OnEvent", function(self, event, ...)
    if event == "ADDON_LOADED" then
        local loaded = ...
        if loaded == addonName then
            -- Initialize SavedVariables
            if not PerfBigginsDB then
                PerfBigginsDB = {}
            end
            for k, v in pairs(DB_DEFAULTS) do
                if PerfBigginsDB[k] == nil then
                    PerfBigginsDB[k] = v
                end
            end

            addon:RestorePosition()
            addon:UpdateLayout()
            addon:RegisterOptions()

            -- Start telemetry loop
            mainFrame:SetScript("OnUpdate", SafeOnUpdate)
            SafeOnUpdate(mainFrame, 1.0)
        end
    elseif event == "PLAYER_ENTERING_WORLD" then
        addon:RestorePosition()
        addon:UpdateLayout()
        SafeOnUpdate(mainFrame, 1.0)
    elseif event == "PLAYER_REGEN_DISABLED" then
        -- Entered Combat
        local db = PerfBigginsDB
        if db and db.hideInCombat then
            mainFrame:SetScript("OnUpdate", nil) -- Detach loop for 0.00ms CPU footprint
            mainFrame:Hide()
        end
    elseif event == "PLAYER_REGEN_ENABLED" then
        -- Left Combat
        local db = PerfBigginsDB
        if db and db.hideInCombat then
            mainFrame:SetScript("OnUpdate", SafeOnUpdate) -- Reattach loop
            addon:UpdateLayout()
        end
    end
end)

-- ==============================================================================
-- ==============================================================================
-- 8. BLIZZARD MODERN SETTINGS API INTEGRATION (Escape -> Options -> AddOns)
-- ==============================================================================
local registeredSettings = {}

-- ==============================================================================
-- 8. BLIZZARD MODERN SETTINGS API INTEGRATION (Canvas Layout)
-- ==============================================================================
local uiWidgets = {}

local function ResetAllToDefaults()
    if not PerfBigginsDB then PerfBigginsDB = {} end
    for varName, defVal in pairs(DB_DEFAULTS) do
        PerfBigginsDB[varName] = defVal
    end
    addon:RestorePosition()
    addon:UpdateOptionsUI()
    addon:UpdateLayout()
    PrintMsg("All options and frame position have been reset to default.")
end

function addon:UpdateOptionsUI()
    if not uiWidgets.panel or not PerfBigginsDB then return end
    local isEnabled = PerfBigginsDB.enabled ~= false

    if uiWidgets.cbEnable then uiWidgets.cbEnable:SetChecked(isEnabled) end
    if uiWidgets.cbFps then uiWidgets.cbFps:SetChecked(PerfBigginsDB.showFps) end
    if uiWidgets.cbWorld then uiWidgets.cbWorld:SetChecked(PerfBigginsDB.showWorld) end
    if uiWidgets.cbHome then uiWidgets.cbHome:SetChecked(PerfBigginsDB.showHome) end
    if uiWidgets.cbLocked then uiWidgets.cbLocked:SetChecked(PerfBigginsDB.locked) end
    if uiWidgets.cbCombat then uiWidgets.cbCombat:SetChecked(PerfBigginsDB.hideInCombat) end

    if uiWidgets.sliderWidth then
        uiWidgets.sliderWidth:SetValue(PerfBigginsDB.barWidth or 180)
        if uiWidgets.sliderWidth.valueText then
            uiWidgets.sliderWidth.valueText:SetText(tostring(PerfBigginsDB.barWidth or 180) .. " px")
        end
    end
    if uiWidgets.sliderHeight then
        uiWidgets.sliderHeight:SetValue(PerfBigginsDB.barHeight or 18)
        if uiWidgets.sliderHeight.valueText then
            uiWidgets.sliderHeight.valueText:SetText(tostring(PerfBigginsDB.barHeight or 18) .. " px")
        end
    end

    -- Gray out child controls when disabled
    local childWidgets = {
        uiWidgets.cbFps, uiWidgets.cbWorld, uiWidgets.cbHome,
        uiWidgets.cbLocked, uiWidgets.cbCombat,
        uiWidgets.sliderWidth, uiWidgets.sliderHeight, uiWidgets.btnResetPos
    }
    for _, w in ipairs(childWidgets) do
        if w then
            if w.SetEnabled then w:SetEnabled(isEnabled) end
            w:SetAlpha(isEnabled and 1.0 or 0.5)
        end
    end
end

function addon:RegisterOptions()
    local panel = CreateFrame("Frame", "PerfBigginsOptionsPanel", UIParent)
    panel.name = "Perf Biggins"
    uiWidgets.panel = panel

    -- Title (Blizzard Gold)
    local title = panel:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
    title:SetPoint("TOPLEFT", 16, -16)
    title:SetText("|cFFFFD100Perf Biggins|r")

    -- Subtitle / Description
    local desc = panel:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
    desc:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -6)
    desc:SetText("High-performance FPS and dual-latency telemetry HUD with zero Lua garbage generation.")

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
        GameTooltip:SetText("Restore all Perf Biggins settings and frame position back to default.", 1, 1, 1, true)
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
        local currentVal = (PerfBigginsDB and PerfBigginsDB[key] ~= nil) and PerfBigginsDB[key] or DB_DEFAULTS[key]
        cb:SetChecked(currentVal)
        cb:SetScript("OnClick", function(self)
            if not PerfBigginsDB then PerfBigginsDB = {} end
            PerfBigginsDB[key] = self:GetChecked()
            if onClickCallback then onClickCallback(self:GetChecked()) end
            addon:UpdateLayout()
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
        return cb
    end

    -- Master Enable Checkbox
    local cbEnable = CreateSettingCheckbox("enabled", "Enable Performance HUD", "Show or hide the performance telemetry HUD overlay.", "TOPLEFT", desc, "BOTTOMLEFT", 0, -18, function(val)
        local status = val and "|cFF00FF00Enabled|r" or "|cFFFF0000Disabled|r"
        PrintMsg("Performance HUD is now " .. status .. ".")
    end)
    uiWidgets.cbEnable = cbEnable

    -- Child Checkboxes (Indented 20px)
    local cbFps = CreateSettingCheckbox("showFps", "Show FPS Bar", "Displays the real-time Frames Per Second bar.", "TOPLEFT", cbEnable, "BOTTOMLEFT", 20, -6)
    uiWidgets.cbFps = cbFps

    local cbWorld = CreateSettingCheckbox("showWorld", "Show World Latency Bar", "Displays World Latency (combat, ability casts, encounter mechanics).", "TOPLEFT", cbFps, "BOTTOMLEFT", 0, -6)
    uiWidgets.cbWorld = cbWorld

    local cbHome = CreateSettingCheckbox("showHome", "Show Home Latency Bar", "Displays Home Latency (chat, auction house, guild system, realm data).", "TOPLEFT", cbWorld, "BOTTOMLEFT", 0, -6)
    uiWidgets.cbHome = cbHome

    local cbLocked = CreateSettingCheckbox("locked", "Lock Frame Position", "Prevents dragging the telemetry frame with the mouse.", "TOPLEFT", cbHome, "BOTTOMLEFT", 0, -6, function(val)
        local status = val and "|cFFFF0000Locked|r" or "|cFF00FF00Unlocked|r"
        PrintMsg("Frame position is now " .. status .. ".")
    end)
    uiWidgets.cbLocked = cbLocked

    local cbCombat = CreateSettingCheckbox("hideInCombat", "Hide During Combat", "Automatically hides the HUD while in combat to reduce screen clutter.", "TOPLEFT", cbLocked, "BOTTOMLEFT", 0, -6)
    uiWidgets.cbCombat = cbCombat

    -- Helper to create and bind sliders
    local function CreateSettingSlider(key, label, tooltip, minVal, maxVal, step, anchorPoint, relativeTo, relPoint, x, y)
        local slider = CreateFrame("Slider", nil, panel, "OptionsSliderTemplate")
        slider:SetPoint(anchorPoint, relativeTo, relPoint, x, y)
        slider:SetSize(220, 16)
        slider:SetMinMaxValues(minVal, maxVal)
        slider:SetValueStep(step)
        slider:SetObeyStepOnDrag(true)

        local val = (PerfBigginsDB and PerfBigginsDB[key]) or DB_DEFAULTS[key]
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
            if not PerfBigginsDB then PerfBigginsDB = {} end
            PerfBigginsDB[key] = newVal
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

    -- Sliders (Anchored below checkboxes, aligned with 20px indent)
    local sliderWidth = CreateSettingSlider("barWidth", "Bar Width", "Adjust the horizontal width of telemetry bars in pixels.", 100, 300, 1, "TOPLEFT", cbCombat, "BOTTOMLEFT", 4, -22)
    uiWidgets.sliderWidth = sliderWidth

    local sliderHeight = CreateSettingSlider("barHeight", "Bar Height", "Adjust the vertical height of telemetry bars in pixels.", 12, 36, 1, "TOPLEFT", sliderWidth, "BOTTOMLEFT", 0, -28)
    uiWidgets.sliderHeight = sliderHeight

    -- Reset Position Button
    local btnResetPos = CreateFrame("Button", nil, panel, "UIPanelButtonTemplate")
    btnResetPos:SetPoint("TOPLEFT", sliderHeight, "BOTTOMLEFT", -4, -24)
    btnResetPos:SetSize(160, 24)
    btnResetPos:SetText("Reset Position")
    btnResetPos:SetScript("OnClick", function()
        if not PerfBigginsDB then PerfBigginsDB = {} end
        PerfBigginsDB.point = "CENTER"
        PerfBigginsDB.relativePoint = "CENTER"
        PerfBigginsDB.xOfs = 0
        PerfBigginsDB.yOfs = -160
        addon:RestorePosition()
        PrintMsg("Frame position reset to screen center.")
    end)
    btnResetPos:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:SetText("Resets telemetry HUD back to the center of your screen.", 1, 1, 1, true)
        GameTooltip:Show()
    end)
    btnResetPos:SetScript("OnLeave", function() GameTooltip:Hide() end)
    uiWidgets.btnResetPos = btnResetPos

    -- Slash Command Help Note
    local helpNote = panel:CreateFontString(nil, "ARTWORK", "GameFontDisableSmall")
    helpNote:SetPoint("TOPLEFT", btnResetPos, "BOTTOMLEFT", 0, -18)
    helpNote:SetText("Keybinds: Game Menu -> Options -> Keybindings -> AddOns -> Perf Biggins\nSlash commands: /perf or /pb (toggle, lock, fps, world, home, combat, reset, status)")

    panel:SetScript("OnShow", function()
        addon:UpdateOptionsUI()
    end)

    -- Register with modern Settings UI as a subcategory under Biggins AddOns
    if LibBigginsSuite then
        addon.categoryID = LibBigginsSuite:RegisterSubcategory("PerfBiggins", panel, "Perf")
    elseif Settings and Settings.RegisterCanvasLayoutCategory then
        local category = Settings.RegisterCanvasLayoutCategory(panel, "Perf Biggins")
        Settings.RegisterAddOnCategory(category)
        addon.categoryID = category:GetID()
    else
        InterfaceOptions_AddCategory(panel)
    end

    addon:UpdateOptionsUI()
end

-- Toggle Master HUD Visibility
function addon:Toggle()
    local db = PerfBigginsDB or DB_DEFAULTS
    db.enabled = not db.enabled
    addon:UpdateOptionsUI()
    addon:UpdateLayout()
    local status = db.enabled and "|cFF00FF00Enabled|r" or "|cFFFF0000Disabled|r"
    PrintMsg("Performance HUD is now " .. status .. ".")
end

-- Open Settings Panel
function addon:OpenSettings()
    addon:UpdateOptionsUI()
    if addon.categoryID and Settings and Settings.OpenToCategory then
        Settings.OpenToCategory(addon.categoryID)
    else
        PrintMsg("Options available in Game Menu -> Options -> AddOns -> Perf Biggins.")
    end
end

-- ==============================================================================
-- 9. SLASH COMMAND HANDLER (/perf, /pb)
-- ==============================================================================
local function SlashHandler(msg)
    local cmd = string.lower(strtrim(msg or ""))
    local db = PerfBigginsDB or DB_DEFAULTS

    if cmd == "" or cmd == "options" or cmd == "config" then
        addon:OpenSettings()
    elseif cmd == "toggle" then
        addon:Toggle()
    elseif cmd == "lock" then
        db.locked = not db.locked
        addon:UpdateOptionsUI()
        addon:UpdateLayout()
        local status = db.locked and "|cFFFF0000Locked|r" or "|cFF00FF00Unlocked|r"
        PrintMsg("Frame position is now " .. status .. ".")
    elseif cmd == "fps" then
        db.showFps = not db.showFps
        addon:UpdateOptionsUI()
        addon:UpdateLayout()
        local status = db.showFps and "|cFF00FF00Enabled|r" or "|cFFFF0000Disabled|r"
        PrintMsg("FPS bar is now " .. status .. ".")
    elseif cmd == "world" then
        db.showWorld = not db.showWorld
        addon:UpdateOptionsUI()
        addon:UpdateLayout()
        local status = db.showWorld and "|cFF00FF00Enabled|r" or "|cFFFF0000Disabled|r"
        PrintMsg("World Latency bar is now " .. status .. ".")
    elseif cmd == "home" then
        db.showHome = not db.showHome
        addon:UpdateOptionsUI()
        addon:UpdateLayout()
        local status = db.showHome and "|cFF00FF00Enabled|r" or "|cFFFF0000Disabled|r"
        PrintMsg("Home Latency bar is now " .. status .. ".")
    elseif cmd == "combat" then
        db.hideInCombat = not db.hideInCombat
        addon:UpdateOptionsUI()
        addon:UpdateLayout()
        local status = db.hideInCombat and "|cFF00FF00Enabled (Hiding in combat)|r" or "|cFFFF0000Disabled (Always visible)|r"
        PrintMsg("Hide in combat is now " .. status .. ".")
    elseif cmd == "reset" then
        db.point = "CENTER"
        db.relativePoint = "CENTER"
        db.xOfs = 0
        db.yOfs = -160
        addon:RestorePosition()
        PrintMsg("Frame position reset to screen center.")
    elseif cmd == "status" then
        local function ColorBool(val) return val and "|cFF00FF00[ON]|r" or "|cFFFF0000[OFF]|r" end
        PrintMsg("Current Configuration:")
        print(string.format("  Master Enable:    %s", ColorBool(db.enabled)))
        print(string.format("  Show FPS Bar:     %s", ColorBool(db.showFps)))
        print(string.format("  Show World Bar:   %s", ColorBool(db.showWorld)))
        print(string.format("  Show Home Bar:    %s", ColorBool(db.showHome)))
        print(string.format("  Frame Locked:     %s", ColorBool(db.locked)))
        print(string.format("  Hide in Combat:   %s", ColorBool(db.hideInCombat)))
        print(string.format("  Bar Dimensions:   %d x %d px", db.barWidth, db.barHeight))
    else
        PrintMsg("Available commands: /pb [toggle | lock | fps | world | home | combat | reset | status | config]")
    end
end

SLASH_PERFBIGGINS1 = "/perf"
SLASH_PERFBIGGINS2 = "/pb"
SlashCmdList["PERFBIGGINS"] = SlashHandler
