--[[ ==============================================================================
    LazySpeed Biggins - Core Constants & Environment Gating
    ------------------------------------------------------------------------------
    Color palettes, unit conversion factors, spell IDs, defaults, and runtime
    environment / combat restriction helpers.
============================================================================== ]]--

local addonName, addon = ...

-- Upvalue caching
local C_PlayerInfo        = C_PlayerInfo
local C_ChallengeMode     = C_ChallengeMode
local C_Spell             = C_Spell
local C_UnitAuras         = C_UnitAuras
local AuraUtil            = AuraUtil
local GetGlidingInfo      = C_PlayerInfo and C_PlayerInfo.GetGlidingInfo
local IsFlying            = IsFlying
local IsSwimming          = IsSwimming
local IsMounted           = IsMounted
local GetUnitSpeed        = GetUnitSpeed
local InCombatLockdown    = InCombatLockdown
local UnitAffectingCombat = UnitAffectingCombat
local issecretvalue       = issecretvalue
local GetSpellCharges     = GetSpellCharges
local type                = type

-- Spell Constants (Surge Forward & Skyward Ascent share the identical Vigor charge pool)
addon.SPELL_SURGE_FORWARD       = 372608
addon.SPELL_SKYWARD_ASCENT      = 372610
addon.SPELL_THRILL_OF_THE_SKIES = 377234
addon.SPELL_GROUND_SKIMMING     = 405021

-- Secret Value Detection (Midnight / Patch 12.0+ & Restricted Instances)
function addon:IsSecret(val)
    return (issecretvalue and issecretvalue(val)) == true
end

-- Challenge Mode / Restricted Environment Detection
function addon:IsRestrictedEnvironment()
    if C_ChallengeMode and C_ChallengeMode.IsChallengeModeActive and C_ChallengeMode.IsChallengeModeActive() then
        return true
    end
    return false
end

-- Comprehensive combat check
function addon:IsPlayerInCombat()
    if InCombatLockdown and InCombatLockdown() then
        return true
    end
    if UnitAffectingCombat and UnitAffectingCombat("player") then
        return true
    end
    return false
end

-- Surge Forward / Skyward Ascent Vigor Charge Helper
function addon:GetSurgeForwardCharges()
    if C_Spell and C_Spell.GetSpellCharges then
        local info = C_Spell.GetSpellCharges(addon.SPELL_SURGE_FORWARD) or C_Spell.GetSpellCharges(addon.SPELL_SKYWARD_ASCENT)
        if type(info) == "table" then
            local current = info.currentCharges or 0
            local maxVal  = info.maxCharges or 6
            local start   = info.cooldownStartTime or info.cooldownStart or 0
            local dur     = info.cooldownDuration or 0
            return current, maxVal, start, dur
        end
    end
    if GetSpellCharges then
        local current, maxVal, start, dur = GetSpellCharges(addon.SPELL_SURGE_FORWARD)
        if not current then
            current, maxVal, start, dur = GetSpellCharges(addon.SPELL_SKYWARD_ASCENT)
        end
        if current then
            return current, maxVal, start, dur
        end
    end
    return nil
end

-- Fast Player Aura Check for Accelerated Skyriding Recharge Buffs
function addon:HasPlayerAura(spellID, spellName)
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

function addon:GetSkyridingRechargeBuffs()
    local hasThrill = addon:HasPlayerAura(addon.SPELL_THRILL_OF_THE_SKIES, "Thrill of the Skies")
    local hasSkim   = addon:HasPlayerAura(addon.SPELL_GROUND_SKIMMING, "Ground Skimming") or addon:HasPlayerAura(418590, "Ground Skimming") or addon:HasPlayerAura(418591, "Ground Skimming")
    return hasThrill, hasSkim
end

-- Active Skyriding State Detection
function addon:IsInSkyridingMode()
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
addon.FORMAT_YS         = "%.1f y/s"
addon.FORMAT_MPH        = "%.1f mph"
addon.FORMAT_KMH        = "%.1f km/h"
addon.FORMAT_PCT        = "%.0f%%"
addon.FORMAT_VIGOR_FULL = "%d / %d Vigor"
addon.FORMAT_VIGOR_CHG  = "%d / %d (%.1fs)"

-- Unit Conversion Multipliers from Base Yards/Second
addon.MULTIPLIER_MPH = 2.04545       -- 1 yard/sec = 2.04545 mph
addon.MULTIPLIER_KMH = 3.29184       -- 1 yard/sec = 3.29184 km/h
addon.MULTIPLIER_PCT = 100.0 / 7.0   -- 7 yards/sec = 100% base run speed

-- Maximum Speed Caps for 100% Status Bar Fill
addon.MAX_CAP_FLIGHT = 84.0     -- Max Skyriding speed cap (1,200% / ~172 mph)
addon.MAX_CAP_SWIM   = 20.0     -- Max Swimming / Aquatic mount speed cap (~41 mph)
addon.MAX_CAP_GROUND = 42.0     -- Max Ground speed cap (running/sprint/ground mounts)

-- Unit Modes: 1 = Yards/Sec, 2 = MPH, 3 = KM/H, 4 = Percentage (%)
addon.modeLabels = { "y/s", "mph", "km/h", "%" }

-- Color Palettes
addon.COLOR_GOLD_BORDER        = { 0.80, 0.70, 0.20, 1.00 } -- Classic Blizzard Metallic Gold
addon.COLOR_CONTAINER_BG       = { 0.05, 0.05, 0.05, 0.95 } -- Solid dark backdrop
addon.COLOR_TRACK_BG           = { 0.05, 0.05, 0.05, 0.75 } -- Empty status bar track

addon.COLOR_VIGOR_NORMAL       = { 0.05, 0.80, 0.95, 1.00 } -- Blizzard Skyriding Cyan (Normal gliding & recharging)
addon.COLOR_VIGOR_NORMAL_FULL  = { 0.10, 0.88, 1.00, 1.00 } -- Full charges Sky Cyan

addon.COLOR_THRILL_BAR         = { 0.00, 0.38, 1.00, 1.00 } -- Thrill of the Skies: Deep Royal / Electric Cobalt Blue
addon.COLOR_THRILL_AURA        = { 0.00, 0.45, 1.00 }

addon.COLOR_SKIM_BAR           = { 1.00, 0.15, 0.15, 1.00 } -- Ground Skimming: Danger Crimson Red
addon.COLOR_SKIM_AURA          = { 1.00, 0.15, 0.15 }

addon.COLOR_BOTH_BAR           = { 0.85, 0.20, 1.00, 1.00 } -- Both Buffs Active: Radiant Neon Violet / Purple
addon.COLOR_BOTH_AURA          = { 0.85, 0.20, 1.00 }

addon.COLOR_SPEED_CRUISE       = { 0.10, 0.90, 0.20, 1.00 } -- Green
addon.COLOR_SPEED_HIGH         = { 0.90, 0.80, 0.10, 1.00 } -- Yellow
addon.COLOR_SPEED_MAX          = { 0.90, 0.10, 0.10, 1.00 } -- Red
addon.COLOR_SPEED_SWIM_SLOW    = { 0.00, 0.55, 0.85, 1.00 } -- Deep Ocean Blue
addon.COLOR_SPEED_SWIM_FAST    = { 0.00, 0.90, 1.00, 1.00 } -- Electric Cyan

addon.Colors = {
    GOLD_BORDER        = addon.COLOR_GOLD_BORDER,
    CONTAINER_BG       = addon.COLOR_CONTAINER_BG,
    TRACK_BG           = addon.COLOR_TRACK_BG,
    VIGOR_NORMAL       = addon.COLOR_VIGOR_NORMAL,
    VIGOR_NORMAL_FULL  = addon.COLOR_VIGOR_NORMAL_FULL,
    THRILL_BAR         = addon.COLOR_THRILL_BAR,
    THRILL_AURA        = addon.COLOR_THRILL_AURA,
    SKIM_BAR           = addon.COLOR_SKIM_BAR,
    SKIM_AURA          = addon.COLOR_SKIM_AURA,
    BOTH_BAR           = addon.COLOR_BOTH_BAR,
    BOTH_AURA          = addon.COLOR_BOTH_AURA,
    SPEED_CRUISE       = addon.COLOR_SPEED_CRUISE,
    SPEED_HIGH         = addon.COLOR_SPEED_HIGH,
    SPEED_MAX          = addon.COLOR_SPEED_MAX,
    SPEED_SWIM_SLOW    = addon.COLOR_SPEED_SWIM_SLOW,
    SPEED_SWIM_FAST    = addon.COLOR_SPEED_SWIM_FAST,
}

-- Persistent Settings Defaults
addon.DB_DEFAULTS = {
    enabled           = true,        -- Master enable toggle
    showFlying        = true,        -- Show Speedometer while Flying / Skyriding
    showSwimming      = true,        -- Show Speedometer while Swimming / Submerged in water
    showGround        = false,       -- Show Speedometer while on Ground (foot or ground mounts)
    showVigor         = true,        -- Show Skyriding Vigor / Surge Forward charge bar
    hideVigorWhenFull = false,       -- Automatically hide Vigor bar when charges are at maximum
    showVigorGlow     = true,        -- Show aura glow on accelerated recharge buffs (Thrill/Skim)
    stackingMode  = "VERTICAL",  -- "VERTICAL" (Speedometer on top, Vigor below) or "HORIZONTAL"
    hideInCombat  = true,        -- Hide immediately during combat
    locked        = false,       -- Lock frame position to prevent dragging
    unitMode      = 4,           -- Default to Percentage (4)
    barWidth      = 180,         -- Frame width in pixels (Range: 100 - 300)
    barHeight     = 22,          -- Frame height in pixels (Range: 14 - 36)
    barSpacing    = 4,           -- Spacing between stacked HUD bars in pixels (Range: 0 - 50)
    bgAlpha       = 25,          -- Background opacity percentage (Range: 0 - 100)
    point         = "CENTER",
    relativePoint = "CENTER",
    xOfs          = 0,
    yOfs          = -200,
}
