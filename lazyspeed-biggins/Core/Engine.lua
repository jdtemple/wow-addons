--[[ ==============================================================================
    LazySpeed Biggins - High-Speed Telemetry & Update Loop Engine (20 FPS)
    ------------------------------------------------------------------------------
    Zero-allocation, throttled telemetry engine updating speed metrics, Skyriding
    surge charges, and contextual status bar coloring.
============================================================================== ]]--

local addonName, addon = ...

-- Cache global functions
local GetGlidingInfo      = C_PlayerInfo and C_PlayerInfo.GetGlidingInfo
local IsFlying            = IsFlying
local IsSwimming          = IsSwimming
local GetUnitSpeed        = GetUnitSpeed
local GetTime             = GetTime
local pcall               = pcall
local min                 = math.min
local max                 = math.max

-- Runtime State Variables
addon.isEngineActive  = false   -- True only when the high-speed loop is actively attached
addon.updateTimer     = 0       -- Accumulator for our 20 FPS (0.05s) throttling
addon.landingDebounce = 0       -- Grace period timer before concluding active state has ended
addon.lastSpeed       = -1      -- Dirty tracking: Skips redundant GPU redraws when stationary

-- High-Speed Update Loop (20 FPS - Throttled & Zero-Allocation)
local function SpeedometerUpdateLoop(self, elapsed)
    local db = LazySpeedBigginsDB or addon.DB_DEFAULTS
    local barSpeed = addon.barSpeed
    local barVigor = addon.barVigor

    -- Combat Check
    if db.hideInCombat and addon:IsPlayerInCombat() then
        LazySpeed_StopEngine()
        return
    end

    -- Environment Check
    if addon:IsRestrictedEnvironment() then
        LazySpeed_StopEngine()
        return
    end

    -- Frame Throttling: Accumulate elapsed time until 0.05 seconds (20 FPS) have passed
    addon.updateTimer = addon.updateTimer + elapsed
    if addon.updateTimer < 0.05 then return end
    addon.updateTimer = 0

    -- 1. SPEEDOMETER TELEMETRY UPDATE
    if barSpeed.container:IsShown() then
        local isGliding, _, forwardSpeed = GetGlidingInfo()
        local rawGroundSpeed = GetUnitSpeed("player")

        if addon:IsSecret(rawGroundSpeed) or addon:IsSecret(forwardSpeed) or addon:IsSecret(isGliding) then
            LazySpeed_StopEngine()
            return
        end

        local isSteadyFlying = IsFlying and IsFlying()
        local isSwimming = IsSwimming and IsSwimming()
        if addon:IsSecret(isSteadyFlying) or addon:IsSecret(isSwimming) then
            LazySpeed_StopEngine()
            return
        end

        local currentSpeed = 0
        local maxCap = addon.MAX_CAP_GROUND
        local isCurrentStateActive = false

        if isGliding then
            currentSpeed = forwardSpeed or 0
            maxCap = addon.MAX_CAP_FLIGHT
            isCurrentStateActive = db.showFlying
        elseif isSteadyFlying then
            currentSpeed = rawGroundSpeed or 0
            maxCap = addon.MAX_CAP_FLIGHT
            isCurrentStateActive = db.showFlying
        elseif isSwimming then
            currentSpeed = rawGroundSpeed or 0
            maxCap = addon.MAX_CAP_SWIM
            isCurrentStateActive = db.showSwimming
        else
            currentSpeed = rawGroundSpeed or 0
            maxCap = addon.MAX_CAP_GROUND
            isCurrentStateActive = db.showGround
        end

        if addon:IsSecret(currentSpeed) then
            LazySpeed_StopEngine()
            return
        end

        -- Landing / State Termination Debounce
        if not isCurrentStateActive then
            addon.landingDebounce = addon.landingDebounce + 0.05
            if addon.landingDebounce >= 1.0 then
                LazySpeed_EvaluateState()
                return
            end
        else
            addon.landingDebounce = 0
        end

        -- Dirty Check & Redraw
        if currentSpeed ~= addon.lastSpeed or addon.lastSpeed == -1 then
            addon.lastSpeed = currentSpeed

            local unit = db.unitMode or 4
            if unit == 1 then
                barSpeed.text:SetFormattedText(addon.FORMAT_YS, currentSpeed)
            elseif unit == 2 then
                barSpeed.text:SetFormattedText(addon.FORMAT_MPH, currentSpeed * addon.MULTIPLIER_MPH)
            elseif unit == 3 then
                barSpeed.text:SetFormattedText(addon.FORMAT_KMH, currentSpeed * addon.MULTIPLIER_KMH)
            else
                barSpeed.text:SetFormattedText(addon.FORMAT_PCT, currentSpeed * addon.MULTIPLIER_PCT)
            end

            local speedRatio = min(max(currentSpeed / maxCap, 0.0), 1.0)
            barSpeed:SetValue(speedRatio)

            -- Dynamic Contextual Theming
            if isSwimming then
                if speedRatio > 0.70 then
                    barSpeed:SetStatusBarColor(addon.COLOR_SPEED_SWIM_FAST[1], addon.COLOR_SPEED_SWIM_FAST[2], addon.COLOR_SPEED_SWIM_FAST[3], addon.COLOR_SPEED_SWIM_FAST[4])
                else
                    barSpeed:SetStatusBarColor(addon.COLOR_SPEED_SWIM_SLOW[1], addon.COLOR_SPEED_SWIM_SLOW[2], addon.COLOR_SPEED_SWIM_SLOW[3], addon.COLOR_SPEED_SWIM_SLOW[4])
                end
            else
                if speedRatio > 0.85 then
                    barSpeed:SetStatusBarColor(addon.COLOR_SPEED_MAX[1], addon.COLOR_SPEED_MAX[2], addon.COLOR_SPEED_MAX[3], addon.COLOR_SPEED_MAX[4])
                elseif speedRatio > 0.50 then
                    barSpeed:SetStatusBarColor(addon.COLOR_SPEED_HIGH[1], addon.COLOR_SPEED_HIGH[2], addon.COLOR_SPEED_HIGH[3], addon.COLOR_SPEED_HIGH[4])
                else
                    barSpeed:SetStatusBarColor(addon.COLOR_SPEED_CRUISE[1], addon.COLOR_SPEED_CRUISE[2], addon.COLOR_SPEED_CRUISE[3], addon.COLOR_SPEED_CRUISE[4])
                end
            end
        end
    else
        -- Speedometer is collapsed/hidden (e.g. while grounded on a Skyriding mount)
        local isGliding = GetGlidingInfo()
        local isSteadyFlying = IsFlying and IsFlying()
        local isSwimming = IsSwimming and IsSwimming()
        local isAirborne = (isGliding or isSteadyFlying)

        if not addon:IsSecret(isGliding) and not addon:IsSecret(isSteadyFlying) and not addon:IsSecret(isSwimming) then
            if (isAirborne and db.showFlying) or (isSwimming and db.showSwimming) or db.showGround then
                addon:UpdateLayout()
                return
            end
        end
    end

    -- 2. SKYRIDING VIGOR TELEMETRY UPDATE
    if barVigor.container:IsShown() then
        if not addon:IsInSkyridingMode() then
            LazySpeed_EvaluateState()
            return
        end

        local charges, maxCharges, startTime, duration = addon:GetSurgeForwardCharges()
        if charges then
            if db.hideVigorWhenFull and maxCharges and (charges >= maxCharges) then
                LazySpeed_EvaluateState()
                return
            end

            local currentVal = charges
            if charges < maxCharges and duration and duration > 0 and startTime and startTime > 0 then
                local elapsed = GetTime() - startTime
                local frac = min(max(elapsed / duration, 0), 1)
                currentVal = charges + frac
                local remaining = max(0, duration - elapsed)
                barVigor.text:SetFormattedText(addon.FORMAT_VIGOR_CHG, charges, maxCharges, remaining)
            else
                barVigor.text:SetFormattedText(addon.FORMAT_VIGOR_FULL, charges, maxCharges)
            end

            barVigor:SetMinMaxValues(0, maxCharges)
            barVigor:SetValue(currentVal)

            -- Accelerated Recharge Aura Glow (Thrill of the Skies & Ground Skimming)
            local showGlow = (db.showVigorGlow ~= false)
            local hasThrill, hasSkim = addon:GetSkyridingRechargeBuffs()

            if hasThrill and hasSkim then
                -- Both active: Maximum turbo recharge -> Radiant Violet / Purple Flame Aura
                if showGlow then
                    addon:SetFlameAuraColor(addon.COLOR_BOTH_AURA[1], addon.COLOR_BOTH_AURA[2], addon.COLOR_BOTH_AURA[3])
                else
                    addon:HideFlameAura()
                end
                barVigor:SetStatusBarColor(addon.COLOR_BOTH_BAR[1], addon.COLOR_BOTH_BAR[2], addon.COLOR_BOTH_BAR[3], addon.COLOR_BOTH_BAR[4])
            elseif hasThrill then
                -- Thrill of the Skies -> Vibrant Blue Flame Aura
                if showGlow then
                    addon:SetFlameAuraColor(addon.COLOR_THRILL_AURA[1], addon.COLOR_THRILL_AURA[2], addon.COLOR_THRILL_AURA[3])
                else
                    addon:HideFlameAura()
                end
                barVigor:SetStatusBarColor(addon.COLOR_THRILL_BAR[1], addon.COLOR_THRILL_BAR[2], addon.COLOR_THRILL_BAR[3], addon.COLOR_THRILL_BAR[4])
            elseif hasSkim then
                -- Ground Skimming -> Crimson Red Flame Aura
                if showGlow then
                    addon:SetFlameAuraColor(addon.COLOR_SKIM_AURA[1], addon.COLOR_SKIM_AURA[2], addon.COLOR_SKIM_AURA[3])
                else
                    addon:HideFlameAura()
                end
                barVigor:SetStatusBarColor(addon.COLOR_SKIM_BAR[1], addon.COLOR_SKIM_BAR[2], addon.COLOR_SKIM_BAR[3], addon.COLOR_SKIM_BAR[4])
            else
                -- Normal (No accelerated recharge)
                addon:HideFlameAura()
                if charges >= maxCharges then
                    barVigor:SetStatusBarColor(addon.COLOR_VIGOR_NORMAL_FULL[1], addon.COLOR_VIGOR_NORMAL_FULL[2], addon.COLOR_VIGOR_NORMAL_FULL[3], addon.COLOR_VIGOR_NORMAL_FULL[4])
                else
                    barVigor:SetStatusBarColor(addon.COLOR_VIGOR_NORMAL[1], addon.COLOR_VIGOR_NORMAL[2], addon.COLOR_VIGOR_NORMAL[3], addon.COLOR_VIGOR_NORMAL[4])
                end
            end
        end
    else
        -- Vigor bar is collapsed/hidden
        if (db.showVigor ~= false) and addon:IsInSkyridingMode() then
            local charges, maxCharges = addon:GetSurgeForwardCharges()
            if charges ~= nil then
                if not (db.hideVigorWhenFull and maxCharges and (charges >= maxCharges)) then
                    addon:UpdateLayout()
                    return
                end
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

-- Lifecycle Controller
function LazySpeed_StartEngine()
    if addon.isEngineActive then return end

    addon.isEngineActive = true
    addon.updateTimer = 0
    addon.landingDebounce = 0

    addon.mainFrame:Show()
    addon.mainFrame:SetScript("OnUpdate", SafeSpeedometerUpdateLoop)
end

function LazySpeed_StopEngine()
    if not addon.isEngineActive then
        addon.mainFrame:Hide()
        addon.barSpeed.container:Hide()
        addon.barVigor.container:Hide()
        addon:HideFlameAura()
        return
    end

    addon.isEngineActive = false
    addon.mainFrame:SetScript("OnUpdate", nil)
    addon.mainFrame:Hide()
    addon.barSpeed.container:Hide()
    addon.barVigor.container:Hide()
    addon:HideFlameAura()
    addon:ResetDisplay()
end

function LazySpeed_EvaluateState()
    addon:UpdateLayout()
end

addon.StartEngine   = LazySpeed_StartEngine
addon.StopEngine    = LazySpeed_StopEngine
addon.EvaluateState = LazySpeed_EvaluateState
