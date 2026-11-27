--[[ ==============================================================================
    Perf Biggins - Telemetry Engine
    ------------------------------------------------------------------------------
    Throttled 10 FPS update loop monitoring framerate (FPS), World latency, and
    Home latency with dynamic CVar / hardware scaling.
============================================================================== ]]--

local addonName, addon = ...

-- Cache upvalues
local GetFramerate  = GetFramerate
local GetNetStats   = GetNetStats
local GetCVar       = GetCVar
local GetCVarBool   = GetCVarBool
local tonumber      = tonumber
local tostring      = tostring
local pcall         = pcall
local math_floor    = math.floor
local math_min      = math.min
local math_max      = math.max

-- Helper to calculate the active maximum FPS scale ceiling
function addon:CalculateActiveFpsCap()
    local db = PerfBigginsDB or addon.DB_DEFAULTS
    if not db.autoFpsCap then
        addon.activeFpsCap = math_max(30, db.manualFpsCap or addon.DEFAULT_FPS_CAP)
        return addon.activeFpsCap, "Manual"
    end

    -- Tier 1: Check foreground maxFPS CVar (Only if the checkbox useMaxFPS is enabled)
    local useMax = (GetCVarBool and GetCVarBool("useMaxFPS")) or (GetCVar and GetCVar("useMaxFPS") == "1")
    if useMax then
        local maxFpsStr = GetCVar and GetCVar("maxFPS")
        local maxFps = tonumber(maxFpsStr) or 0
        if maxFps > 0 then
            addon.activeFpsCap = maxFps
            addon._lastFpsTier = "maxFPS"
            return addon.activeFpsCap, "maxFPS"
        end
    end

    -- Tier 2: Adaptive floor for uncapped setups (start at 60Hz baseline, expand with actual FPS)
    local baseline = 60
    if addon.activeFpsCap and addon.activeFpsCap > baseline and (addon._lastFpsTier == "Adaptive") then
        baseline = addon.activeFpsCap
    end
    addon._lastFpsTier = "Adaptive"
    addon.activeFpsCap = baseline
    return addon.activeFpsCap, "Adaptive"
end

local updateTimer = 0

local function TelemetryUpdateLoop(self, elapsed)
    updateTimer = updateTimer + (elapsed or 0)
    if updateTimer < addon.UPDATE_THROTTLE then return end
    updateTimer = 0

    local db = PerfBigginsDB
    if not db or db.enabled == false then return end

    -- 1. FPS Bar Update (Live refresh with 1 decimal place matching LazySpeed)
    if db.showFps and addon.barFps then
        local currentFps = GetFramerate() or 0
        addon.barFps.text:SetFormattedText(addon.FORMAT_FPS, currentFps)

        -- If completely uncapped (Tier 3 Adaptive) in Auto mode and current FPS exceeds current ceiling by >= 1 FPS, adapt upward cleanly
        if db.autoFpsCap and addon._lastFpsTier == "Adaptive" and currentFps >= (addon.activeFpsCap + 1.0) then
            addon.activeFpsCap = math_floor(currentFps + 0.5)
            if addon.UpdateOptionsUI then addon:UpdateOptionsUI() end
        end

        local cap = math_max(30, addon.activeFpsCap or addon.DEFAULT_FPS_CAP)
        local pct = math_min(100, math_max(0, (currentFps / cap) * 100))
        addon.barFps:SetValue(pct)

        local r, g, b = addon:GetFpsColor(currentFps)
        addon.barFps:SetStatusBarColor(r, g, b)
    end

    -- 2. Latency Bars Update (World & Home)
    if (db.showWorld or db.showHome) and (addon.barWorld and addon.barHome) then
        local _, _, homeMs, worldMs = GetNetStats()
        worldMs = worldMs or 0
        homeMs  = homeMs or 0

        -- World Latency
        if db.showWorld then
            addon.barWorld.text:SetFormattedText(addon.FORMAT_WORLD, worldMs)

            local pct = math_min(100, math_max(0, (worldMs / addon.MAX_LATENCY_CAP) * 100))
            addon.barWorld:SetValue(pct)

            local r, g, b = addon:GetLatencyColor(worldMs)
            addon.barWorld:SetStatusBarColor(r, g, b)
        end

        -- Home Latency
        if db.showHome then
            addon.barHome.text:SetFormattedText(addon.FORMAT_HOME, homeMs)

            local pct = math_min(100, math_max(0, (homeMs / addon.MAX_LATENCY_CAP) * 100))
            addon.barHome:SetValue(pct)

            local r, g, b = addon:GetLatencyColor(homeMs)
            addon.barHome:SetStatusBarColor(r, g, b)
        end
    end
end

-- Failsafe wrapper: Protects against unhandled API exceptions and prevents loop detachment
function addon:SafeOnUpdate(elapsed)
    local ok, err = pcall(TelemetryUpdateLoop, addon.mainFrame, elapsed)
    if not ok and err then
        addon:PrintMsg("|cFFFF0000Telemetry Loop Error:|r " .. tostring(err))
    end
end
