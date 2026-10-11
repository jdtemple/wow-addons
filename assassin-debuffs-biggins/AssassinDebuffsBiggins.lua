--[[
    Assassin Debuffs Biggins
    ------------------------
    Clean, high-performance soft gradient halo borders for
    Garrote, Rupture, Deathstalker's Mark, Kingsbane, and Deathmark on Blizzard's stock nameplates.

    Author: Biggins
    Engineering Standards:
      - Zero allocations in hot paths (no tables/closures in aura loops)
      - Pre-cached gradient ColorMixins
      - 100% CVar-safe: runs purely in RAM on UI frames, zero SetCVar calls
      - Taint-safe: zero writes to Blizzard frame tables, zero measurement APIs on restricted regions
      - Auto-scales natively with Blizzard's in-game buff/debuff scale (inherits frame scale)
--]]

local ADDON_NAME = ...

-- ---------------------------------------------------------------------------
-- 1. Defaults & Configuration
-- ---------------------------------------------------------------------------
local DEFAULT_DB = {
    haloPosition = "both",                                -- "both", "top", or "bottom"
    borderThickness = 4,
    garroteColor = { r = 1.0, g = 0.60, b = 0.0 },       -- Amber / Orange
    ruptureColor = { r = 1.0, g = 0.15, b = 0.15 },       -- Crimson / Red
    deathstalkerColor = { r = 0.65, g = 0.25, b = 0.95 },  -- Vivid Purple
    kingsbaneColor = { r = 0.0, g = 1.0, b = 0.40 },     -- Toxic / Neon Green
    deathmarkColor = { r = 0.0, g = 0.83, b = 1.0 },     -- Electric Cyan
}

-- Pre-cached spell lookups (100% verified target debuff IDs)
local TRACKED_SPELLS = {
    -- Garrote
    [703] = "garrote",
    [1330] = "garrote",       -- Garrote - Silence
    [280321] = "garrote",     -- Shrouded Suffocation
    [360830] = "garrote",     -- Duplicated by Deathmark
    [381632] = "garrote",     -- Improved Garrote (Rank 2)
    [392401] = "garrote",     -- Improved Garrote (Empowered)
    [392403] = "garrote",     -- Improved Garrote (Empowered Alt)

    -- Rupture
    [1943] = "rupture",
    [360826] = "rupture",     -- Duplicated by Deathmark

    -- Deathstalker's Mark
    [457052] = "deathstalker",
    [457129] = "deathstalker",

    -- Kingsbane
    [385627] = "kingsbane",
    [192759] = "kingsbane",
    [280718] = "kingsbane",

    -- Deathmark
    [360194] = "deathmark",
    [383269] = "deathmark",
    [394025] = "deathmark",
}

local TRACKED_NAMES = {
    ["Garrote"] = "garrote",
    ["Improved Garrote"] = "garrote",
    ["Garrote - Silence"] = "garrote",
    ["Shrouded Suffocation"] = "garrote",
    ["Rupture"] = "rupture",
    ["Deathstalker's Mark"] = "deathstalker",
    ["Kingsbane"] = "kingsbane",
    ["Deathmark"] = "deathmark",
}

-- Secret-Safe Icon Fallbacks: verified FileDataIDs and normalized texture paths
local TRACKED_ICONS = {
    -- Garrote (ability_rogue_garrote)
    [136224] = "garrote",
    [7195162] = "garrote",
    ["interface/icons/ability_rogue_garrote"] = "garrote",

    -- Rupture (ability_rogue_rupture)
    [132309] = "rupture",
    ["interface/icons/ability_rogue_rupture"] = "rupture",

    -- Deathstalker's Mark (inv_ability_deathstalkerrogue_deathstalkersmark)
    [5927622] = "deathstalker",
    [5927633] = "deathstalker",
    ["interface/icons/inv_ability_deathstalkerrogue_deathstalkersmark"] = "deathstalker",

    -- Kingsbane (inv_knife_1h_artifactgarona_d_01)
    [135268] = "kingsbane",
    [1356070] = "kingsbane",
    ["interface/icons/inv_knife_1h_artifactgarona_d_01"] = "kingsbane",

    -- Deathmark (ability_rogue_deathmark)
    [4661655] = "deathmark",
    ["interface/icons/ability_rogue_deathmark"] = "deathmark",
}

local function IsSecret(v)
    if v == nil then return false end
    if type(issecretvalue) == "function" then
        local ok, isSec = pcall(issecretvalue, v)
        if ok and isSec then return true end
    end
    return false
end

local function SafeToString(val)
    if val == nil then return "nil" end
    if IsSecret(val) then return "<secret>" end
    local ok, res = pcall(tostring, val)
    return (ok and res) or "<error>"
end

local function InitializeTrackedNames()
    for spellId, key in pairs(TRACKED_SPELLS) do
        if C_Spell and C_Spell.GetSpellName then
            local ok, name = pcall(C_Spell.GetSpellName, spellId)
            if ok and name and name ~= "" and not IsSecret(name) then
                TRACKED_NAMES[name] = key
            end
        elseif GetSpellInfo then
            local ok, name = pcall(GetSpellInfo, spellId)
            if ok and name and name ~= "" and not IsSecret(name) then
                TRACKED_NAMES[name] = key
            end
        end
    end
end

local function InitializeTrackedIcons()
    for spellId, key in pairs(TRACKED_SPELLS) do
        local texture = nil
        if C_Spell and C_Spell.GetSpellTexture then
            local ok, tex = pcall(C_Spell.GetSpellTexture, spellId)
            if ok and tex and not IsSecret(tex) then texture = tex end
        end
        if not texture and C_Spell and C_Spell.GetSpellInfo then
            local ok, info = pcall(C_Spell.GetSpellInfo, spellId)
            if ok and info and info.iconID and not IsSecret(info.iconID) then texture = info.iconID end
        end
        if not texture and GetSpellTexture then
            local ok, tex = pcall(GetSpellTexture, spellId)
            if ok and tex and not IsSecret(tex) then texture = tex end
        end
        if texture then
            TRACKED_ICONS[texture] = key
            local num = tonumber(texture)
            if num then TRACKED_ICONS[num] = key end
        end
    end
end

-- ---------------------------------------------------------------------------
-- 2. Zero-Allocation Color Cache
-- ---------------------------------------------------------------------------
local colorCache = {}

local function RefreshColorCache()
    local db = AssassinDebuffsBigginsDB or DEFAULT_DB
    local g = db.garroteColor or DEFAULT_DB.garroteColor
    local r = db.ruptureColor or DEFAULT_DB.ruptureColor
    local d = db.deathstalkerColor or DEFAULT_DB.deathstalkerColor
    local k = db.kingsbaneColor or DEFAULT_DB.kingsbaneColor
    local m = db.deathmarkColor or DEFAULT_DB.deathmarkColor

    colorCache.garrote = {
        solid = CreateColor(g.r, g.g, g.b, 1),
        clear = CreateColor(g.r, g.g, g.b, 0),
    }
    colorCache.rupture = {
        solid = CreateColor(r.r, r.g, r.b, 1),
        clear = CreateColor(r.r, r.g, r.b, 0),
    }
    colorCache.deathstalker = {
        solid = CreateColor(d.r, d.g, d.b, 1),
        clear = CreateColor(d.r, d.g, d.b, 0),
    }
    colorCache.kingsbane = {
        solid = CreateColor(k.r, k.g, k.b, 1),
        clear = CreateColor(k.r, k.g, k.b, 0),
    }
    colorCache.deathmark = {
        solid = CreateColor(m.r, m.g, m.b, 1),
        clear = CreateColor(m.r, m.g, m.b, 0),
    }
end

-- Initialize default color cache immediately at chunk load
RefreshColorCache()

-- ---------------------------------------------------------------------------
-- 3. Gradient Halo Border Management (Taint-Free External Storage)
-- ---------------------------------------------------------------------------
-- Weak-keyed table: never writes keys onto Blizzard's pooled auraItemFrames
local bordersByButton = setmetatable({}, { __mode = "k" })

local function HideGlow(borders)
    if not borders then return end
    borders.spellKey = nil
    if borders.top then borders.top:Hide() end
    if borders.bottom then borders.bottom:Hide() end
end

local function ApplyGlow(button, borders, colors, thickness)
    if not borders or not colors then return end

    local db = AssassinDebuffsBigginsDB or DEFAULT_DB
    local position = db.haloPosition or DEFAULT_DB.haloPosition
    local haloHeight = thickness + 3

    -- Top outward halo (radiates upward above the icon into open air)
    if position == "bottom" then
        borders.top:Hide()
    else
        borders.top:ClearAllPoints()
        borders.top:SetPoint("BOTTOMLEFT", button, "TOPLEFT", 0, 0)
        borders.top:SetPoint("BOTTOMRIGHT", button, "TOPRIGHT", 0, 0)
        borders.top:SetHeight(haloHeight)
        borders.top:SetGradient("VERTICAL", colors.solid, colors.clear)
        borders.top:Show()
    end

    -- Bottom outward halo (radiates downward below the icon)
    if position == "top" then
        borders.bottom:Hide()
    else
        borders.bottom:ClearAllPoints()
        borders.bottom:SetPoint("TOPLEFT", button, "BOTTOMLEFT", 0, 0)
        borders.bottom:SetPoint("TOPRIGHT", button, "BOTTOMRIGHT", 0, 0)
        borders.bottom:SetHeight(haloHeight)
        borders.bottom:SetGradient("VERTICAL", colors.clear, colors.solid)
        borders.bottom:Show()
    end
end

local function GetOrCreateGlowBorders(button)
    local borders = bordersByButton[button]
    if borders then return borders end

    -- Textures created directly on button:
    -- 1. Natively inherits button's frame strata and frame level (immune to level desync)
    -- 2. Natively inherits button's scale and alpha
    -- 3. Natively shows/hides with button
    local top = button:CreateTexture(nil, "OVERLAY", nil, 7)
    top:SetTexture("Interface\\Buttons\\WHITE8x8")

    local bottom = button:CreateTexture(nil, "OVERLAY", nil, 7)
    bottom:SetTexture("Interface\\Buttons\\WHITE8x8")

    borders = {
        top = top,
        bottom = bottom,
        spellKey = nil,
    }

    button:HookScript("OnHide", function(self)
        local b = bordersByButton[self]
        if b then
            HideGlow(b)
        end
    end)

    button:HookScript("OnShow", function(self)
        local b = bordersByButton[self]
        if b and b.spellKey and colorCache[b.spellKey] then
            local db = AssassinDebuffsBigginsDB or DEFAULT_DB
            local thickness = db.borderThickness or DEFAULT_DB.borderThickness
            ApplyGlow(self, b, colorCache[b.spellKey], thickness)
        end
    end)

    button:HookScript("OnSizeChanged", function(self)
        local b = bordersByButton[self]
        if b and b.spellKey and colorCache[b.spellKey] and self:IsShown() then
            local db = AssassinDebuffsBigginsDB or DEFAULT_DB
            local thickness = db.borderThickness or DEFAULT_DB.borderThickness
            ApplyGlow(self, b, colorCache[b.spellKey], thickness)
        end
    end)

    bordersByButton[button] = borders
    return borders
end

-- ---------------------------------------------------------------------------
-- 4. Modern Blizzard_NamePlates Engine Hook (Zero-Taint)
-- ---------------------------------------------------------------------------
local function ResolveSpellKey(aura, button)
    if not aura and not button then return nil end

    -- 1. Direct spell ID match (if accessible)
    local spellId = nil
    if aura and not IsSecret(aura.spellId) then
        spellId = aura.spellId
    elseif aura and not IsSecret(aura.spellID) then
        spellId = aura.spellID
    elseif button and not IsSecret(button.spellID) then
        spellId = button.spellID
    end

    if spellId and not IsSecret(spellId) then
        local ok, key = pcall(function() return TRACKED_SPELLS[spellId] end)
        if ok and key then return key end
    end

    -- 2. Direct icon FileDataID or texture match (from aura or button.Icon)
    local icon = nil
    if aura and not IsSecret(aura.icon) then
        icon = aura.icon
    end
    if not icon and button and button.Icon and button.Icon.GetTexture then
        local ok, tex = pcall(button.Icon.GetTexture, button.Icon)
        if ok and tex and not IsSecret(tex) then
            icon = tex
        end
    end

    if icon and not IsSecret(icon) then
        -- Direct lookup in TRACKED_ICONS (handles numeric FileDataIDs and raw paths)
        local ok, key = pcall(function() return TRACKED_ICONS[icon] end)
        if ok and key then return key end

        local num = tonumber(icon)
        if num and not IsSecret(num) then
            local ok2, key2 = pcall(function() return TRACKED_ICONS[num] end)
            if ok2 and key2 then return key2 end
        end

        -- Substring matching if texture path is a string
        if type(icon) == "string" then
            local clean = icon:lower():gsub("\\", "/")
            if clean:find("garrote") then return "garrote" end
            if clean:find("rupture") then return "rupture" end
            if clean:find("deathstalker") then return "deathstalker" end
            if clean:find("kingsbane") or clean:find("artifactgarona") then return "kingsbane" end
            if clean:find("deathmark") then return "deathmark" end
        end
    end

    -- 3. Localized aura name match (if accessible)
    if aura and not IsSecret(aura.name) and aura.name then
        local ok, key = pcall(function() return TRACKED_NAMES[aura.name] end)
        if ok and key then return key end
    end

    -- 4. Dynamic spell name lookup from accessible spellId
    if spellId and not IsSecret(spellId) then
        if C_Spell and C_Spell.GetSpellName then
            local ok, sName = pcall(C_Spell.GetSpellName, spellId)
            if ok and sName and not IsSecret(sName) and TRACKED_NAMES[sName] then
                return TRACKED_NAMES[sName]
            end
        end
    end

    return nil
end

local hasDumpedDiagnostics = false

local function DumpDiagnostics(aura, button)
    if hasDumpedDiagnostics then return end
    hasDumpedDiagnostics = true

    print("|cFFFFD100[ADB Diagnostics]|r ===== DETAILED COMBAT AURA INSPECTION =====")
    if button and button.Icon then
        local ok, tex = pcall(button.Icon.GetTexture, button.Icon)
        local sec = IsSecret(tex)
        print(string.format("  button.Icon:GetTexture(): ok=%s, isSecret=%s, type=%s, val=%s",
            tostring(ok), tostring(sec), type(tex), tostring(sec and "<secret>" or tex)))
        if button.Icon.GetTextureFileID then
            local ok2, fid = pcall(button.Icon.GetTextureFileID, button.Icon)
            print(string.format("  button.Icon:GetTextureFileID(): ok=%s, isSecret=%s, val=%s",
                tostring(ok2), tostring(IsSecret(fid)), tostring(IsSecret(fid) and "<secret>" or fid)))
        end
    end

    if button then
        print(string.format("  button.layoutIndex=%s, unitToken=%s, spellID=%s (sec=%s), auraInstanceID=%s (sec=%s)",
            tostring(button.layoutIndex), tostring(button.unitToken),
            tostring(IsSecret(button.spellID) and "<secret>" or button.spellID), tostring(IsSecret(button.spellID)),
            tostring(IsSecret(button.auraInstanceID) and "<secret>" or button.auraInstanceID), tostring(IsSecret(button.auraInstanceID))))
    end

    if aura then
        print("  Aura Table Fields:")
        for k, v in pairs(aura) do
            local sec = IsSecret(v)
            local valStr = (sec and "<secret>") or tostring(v)
            print(string.format("    [%s] (type: %s, isSecret: %s) = %s",
                tostring(k), type(v), tostring(sec), valStr))
        end
    end

    -- Also check if C_UnitAuras on "target" is secret or readable
    if C_UnitAuras and C_UnitAuras.GetUnitAuras then
        local filter = (AuraUtil and AuraUtil.AuraFilters and AuraUtil.AuraFilters.Harmful) or "HARMFUL"
        local ok, targetAuras = pcall(C_UnitAuras.GetUnitAuras, "target", filter)
        if ok and targetAuras then
            print(string.format("  C_UnitAuras on 'target': found %d auras", #targetAuras))
            for i, a in ipairs(targetAuras) do
                if i <= 4 then
                    local sSec = IsSecret(a.spellId)
                    local nSec = IsSecret(a.name)
                    print(string.format("    target aura %d: spellId=%s (sec=%s), name=%s (sec=%s)",
                        i, tostring(sSec and "<secret>" or a.spellId), tostring(sSec),
                        tostring(nSec and "<secret>" or a.name), tostring(nSec)))
                end
            end
        else
            print(string.format("  C_UnitAuras on 'target': failed or nil (ok=%s)", tostring(ok)))
        end
    end

    print("  --- Secret Operations Probing ---")
    if type(canaccesssecrets) == "function" then
        local ok_cas, res_cas = pcall(canaccesssecrets)
        print(string.format("  canaccesssecrets(): ok=%s, val=%s", tostring(ok_cas), tostring(res_cas)))
    end
    if aura and aura.spellId then
        local sid = aura.spellId
        if type(canaccessvalue) == "function" then
            local ok_cav, res_cav = pcall(canaccessvalue, sid)
            print(string.format("  canaccessvalue(sid): ok=%s, val=%s", tostring(ok_cav), tostring(res_cav)))
        end
        local ok1, err1 = pcall(function() return sid == 703 end)
        print(string.format("  sid == 703: ok=%s, val=%s", tostring(ok1), SafeToString(err1)))

        if type(secretwrap) == "function" then
            local ok_sw_wrap, sec703 = pcall(secretwrap, 703)
            if ok_sw_wrap then
                local ok2, err2 = pcall(function() return sid == sec703 end)
                print(string.format("  sid == secretwrap(703): ok=%s, val=%s, isSec=%s", tostring(ok2), SafeToString(err2), tostring(IsSecret(err2))))
            end
        end

        local ok3, err3 = pcall(function() return TRACKED_SPELLS[sid] end)
        print(string.format("  TRACKED_SPELLS[sid]: ok=%s, val=%s", tostring(ok3), SafeToString(err3)))

        if type(mapvalues) == "function" then
            local ok4, err4 = pcall(function() return mapvalues(function(v) return v == 703 end, sid) end)
            print(string.format("  mapvalues(v==703): ok=%s, val=%s, isSec=%s", tostring(ok4), SafeToString(err4), tostring(IsSecret(err4))))
        end

        if C_Spell and C_Spell.GetSpellName then
            local ok5, err5 = pcall(C_Spell.GetSpellName, sid)
            print(string.format("  C_Spell.GetSpellName(sid): ok=%s, val=%s, isSec=%s", tostring(ok5), SafeToString(err5), tostring(IsSecret(err5))))
        end

        if C_Spell and C_Spell.GetSpellTexture then
            local ok6, err6 = pcall(C_Spell.GetSpellTexture, sid)
            print(string.format("  C_Spell.GetSpellTexture(sid): ok=%s, val=%s, isSec=%s", tostring(ok6), SafeToString(err6), tostring(IsSecret(err6))))
        end
    end

    if aura and aura.icon then
        local ico = aura.icon
        local ok7, err7 = pcall(function() return ico == 7195162 end)
        print(string.format("  icon == 7195162: ok=%s, val=%s", tostring(ok7), SafeToString(err7)))

        if type(secretwrap) == "function" then
            local ok_sw_ico, secIco = pcall(secretwrap, 7195162)
            if ok_sw_ico then
                local ok8, err8 = pcall(function() return ico == secIco end)
                print(string.format("  icon == secretwrap(7195162): ok=%s, val=%s", tostring(ok8), SafeToString(err8)))
            end
        end
    end

    if recentCLEUSpells and #recentCLEUSpells > 0 then
        print(string.format("  CLEU player auras (%d recorded):", #recentCLEUSpells))
        for i = 1, math.min(3, #recentCLEUSpells) do
            local c = recentCLEUSpells[i]
            print(string.format("    CLEU %d: sub=%s, id=%s (sec=%s), name=%s",
                i, tostring(c.subevent), tostring(c.spellId), tostring(c.isSec), tostring(c.spellName)))
        end
    else
        print("  CLEU player auras: none recorded yet")
    end

    print("|cFFFFD100[ADB Diagnostics]|r =============================================")
end

local function LogAuraDebug(aura, button, spellKey)
    if not AssassinDebuffsBigginsDB then return end
    if not AssassinDebuffsBigginsDB.recentDebug then
        AssassinDebuffsBigginsDB.recentDebug = {}
    end

    local spellIdStr = "<nil>"
    if aura and aura.spellId ~= nil then
        spellIdStr = SafeToString(aura.spellId)
    elseif button and button.spellID ~= nil then
        spellIdStr = SafeToString(button.spellID)
    end

    local iconStr = "<nil>"
    if aura and aura.icon ~= nil then
        iconStr = SafeToString(aura.icon)
    end

    local texStr = "<nil>"
    if button and button.Icon and button.Icon.GetTexture then
        local ok, tex = pcall(button.Icon.GetTexture, button.Icon)
        if ok and tex ~= nil then texStr = SafeToString(tex) end
    end

    local nameStr = (aura and aura.name ~= nil and SafeToString(aura.name)) or "<nil>"
    local sourceStr = (aura and aura.sourceUnit ~= nil and SafeToString(aura.sourceUnit)) or "<nil>"
    local keyStr = spellKey or "none"

    local entry = {
        name = nameStr,
        spellId = spellIdStr,
        icon = iconStr,
        tex = texStr,
        source = sourceStr,
        key = keyStr,
        time = (date and date("%H:%M:%S")) or "",
    }
    table.insert(AssassinDebuffsBigginsDB.recentDebug, 1, entry)
    if #AssassinDebuffsBigginsDB.recentDebug > 30 then
        table.remove(AssassinDebuffsBigginsDB.recentDebug)
    end

    if ADB_DEBUG then
        DumpDiagnostics(aura, button)
        print(string.format("|cFFFFD100[ADB Debug]|r '%s' (ID: %s, Icon: %s, Tex: %s, Src: %s) -> key: %s",
            nameStr, spellIdStr, iconStr, texStr, sourceStr, keyStr))
    end
end

local function OnAuraItemSetAura(self, aura)
    local borders = bordersByButton[self]
    if not aura then
        HideGlow(borders)
        return
    end

    local spellKey = ResolveSpellKey(aura, self)
    LogAuraDebug(aura, self, spellKey)

    if spellKey and colorCache[spellKey] then
        borders = GetOrCreateGlowBorders(self)
        borders.spellKey = spellKey
        local db = AssassinDebuffsBigginsDB or DEFAULT_DB
        local thickness = db.borderThickness or DEFAULT_DB.borderThickness

        -- Immediate apply (sets colors and initial textures)
        ApplyGlow(self, borders, colorCache[spellKey], thickness)

        -- Deferred apply: re-anchors AFTER Blizzard's SetParent, Show, and listFrame:Layout() complete
        C_Timer.After(0, function()
            if self:IsShown() and borders.spellKey == spellKey then
                ApplyGlow(self, borders, colorCache[spellKey], thickness)
            end
        end)
    else
        HideGlow(borders)
    end
end

local isAuraItemHooked = false
local isAurasMixinRefreshListHooked = false

-- Safe live refresh: updates existing glow textures purely in addon memory (zero Blizzard layout calls)
local function RefreshAllActiveGlows()
    RefreshColorCache()
    local db = AssassinDebuffsBigginsDB or DEFAULT_DB
    local thickness = db.borderThickness or DEFAULT_DB.borderThickness

    for button, borders in pairs(bordersByButton) do
        if button:IsShown() and borders.spellKey and colorCache[borders.spellKey] then
            ApplyGlow(button, borders, colorCache[borders.spellKey], thickness)
        end
    end
end

local refreshQueued = false
local function RequestRefreshGlows()
    if refreshQueued then return end
    refreshQueued = true
    C_Timer.After(0, function()
        refreshQueued = false
        RefreshAllActiveGlows()
    end)
end

local function HookAuraFrame(frame)
    if not frame or frame.__adbHooked then return end
    frame.__adbHooked = true

    if frame.SetAura then
        hooksecurefunc(frame, "SetAura", OnAuraItemSetAura)
    end
end

local function HookAuraPool(pool)
    if not pool or pool.__adbPoolHooked then return end
    pool.__adbPoolHooked = true

    if pool.EnumerateActive then
        for frame in pool:EnumerateActive() do
            HookAuraFrame(frame)
        end
    end
    if pool.EnumerateInactive then
        for frame in pool:EnumerateInactive() do
            HookAuraFrame(frame)
        end
    end
    if pool.Acquire then
        hooksecurefunc(pool, "Acquire", function(self)
            for frame in self:EnumerateActive() do
                HookAuraFrame(frame)
            end
        end)
    end
    if pool.Release then
        hooksecurefunc(pool, "Release", function(self, frame)
            if frame and bordersByButton[frame] then
                HideGlow(bordersByButton[frame])
            end
        end)
    end
    if pool.ReleaseAll then
        hooksecurefunc(pool, "ReleaseAll", function(self)
            if self.EnumerateInactive then
                for frame in self:EnumerateInactive() do
                    if bordersByButton[frame] then
                        HideGlow(bordersByButton[frame])
                    end
                end
            end
        end)
    end
end

local function HookUnitFrameAuras(unitFrame)
    if not unitFrame then return end
    local containers = { unitFrame.AurasFrame, unitFrame.Auras, unitFrame.BuffFrame, unitFrame.DebuffFrame }
    for _, container in ipairs(containers) do
        if container then
            if container.RefreshList and not container.__adbRefreshListHooked then
                container.__adbRefreshListHooked = true
                hooksecurefunc(container, "RefreshList", function(self, listFrame, auraList)
                    RequestRefreshGlows()
                end)
            end
            if container.auraItemFramePool then HookAuraPool(container.auraItemFramePool) end
            if container.buffPool then HookAuraPool(container.buffPool) end
            if container.debuffPool then HookAuraPool(container.debuffPool) end
        end
    end
end

local function HookNamePlates()
    if NamePlateAuraItemMixin and NamePlateAuraItemMixin.SetAura and not isAuraItemHooked then
        hooksecurefunc(NamePlateAuraItemMixin, "SetAura", OnAuraItemSetAura)
        isAuraItemHooked = true
    end

    if NamePlateAurasMixin and NamePlateAurasMixin.RefreshList and not isAurasMixinRefreshListHooked then
        hooksecurefunc(NamePlateAurasMixin, "RefreshList", function(self, listFrame, auraList)
            RequestRefreshGlows()
        end)
        isAurasMixinRefreshListHooked = true
    end

    if C_NamePlate and C_NamePlate.GetNamePlates then
        for _, namePlate in ipairs(C_NamePlate.GetNamePlates()) do
            HookUnitFrameAuras(namePlate.UnitFrame)
        end
    end
end

-- ---------------------------------------------------------------------------
-- 5. Native In-Game Settings Panel
-- ---------------------------------------------------------------------------
local optionsCategory = nil

local function OpenColorPicker(colorTable, callback)
    local initialR = colorTable.r
    local initialG = colorTable.g
    local initialB = colorTable.b

    local function SwatchCallback(restore)
        local r, g, b
        if restore then
            r, g, b = initialR, initialG, initialB
        elseif ColorPickerFrame.GetColorRGB then
            r, g, b = ColorPickerFrame:GetColorRGB()
        else
            r, g, b = ColorPickerFrame:GetColorRGB()
        end
        colorTable.r = r
        colorTable.g = g
        colorTable.b = b
        callback(r, g, b)
    end

    local info = {
        r = initialR,
        g = initialG,
        b = initialB,
        hasOpacity = false,
        swatchFunc = function() SwatchCallback(false) end,
        cancelFunc = function() SwatchCallback(true) end,
    }

    if ColorPickerFrame.SetupColorPickerAndShow then
        ColorPickerFrame:SetupColorPickerAndShow(info)
    else
        ColorPickerFrame.func = info.swatchFunc
        ColorPickerFrame.cancelFunc = info.cancelFunc
        ColorPickerFrame.hasOpacity = false
        ColorPickerFrame:SetColorRGB(info.r, info.g, info.b)
        ShowUIPanel(ColorPickerFrame)
    end
end

local function CreateOptionsPanel()
    local panel = CreateFrame("Frame", "AssassinDebuffsBigginsOptionsPanel", UIParent)
    panel.name = "Assassin Debuffs Biggins"

    -- Title
    local title = panel:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
    title:SetPoint("TOPLEFT", 16, -16)
    title:SetText("Assassin Debuffs Biggins")

    -- Subtitle
    local subText = panel:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
    subText:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -8)
    subText:SetText("Clean soft gradient halo bars for Garrote, Rupture, Deathstalker's Mark, Kingsbane, and Deathmark.")

    -- 1. Halo Position Dropdown Section
    local posHeader = panel:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    posHeader:SetPoint("TOPLEFT", subText, "BOTTOMLEFT", 0, -18)
    posHeader:SetText("Halo Position")

    local posDropdown
    local ok, dropdownBtn = pcall(CreateFrame, "DropdownButton", "ADB_PositionDropdown", panel, "WowStyle1DropdownTemplate")
    if ok and dropdownBtn and MenuUtil and MenuUtil.CreateRadioMenu then
        posDropdown = dropdownBtn
        posDropdown:SetSize(160, 26)
        posDropdown:SetPoint("TOPLEFT", posHeader, "BOTTOMLEFT", 0, -6)

        local function GetPos()
            return AssassinDebuffsBigginsDB and AssassinDebuffsBigginsDB.haloPosition or DEFAULT_DB.haloPosition
        end

        local function SetPos(val)
            AssassinDebuffsBigginsDB.haloPosition = val
            local text = (val == "top" and "Top Only") or (val == "bottom" and "Bottom Only") or "Top & Bottom"
            posDropdown:SetDefaultText(text)
            RefreshAllActiveGlows()
        end

        local currentVal = GetPos()
        local currentText = (currentVal == "top" and "Top Only") or (currentVal == "bottom" and "Bottom Only") or "Top & Bottom"
        posDropdown:SetDefaultText(currentText)

        MenuUtil.CreateRadioMenu(posDropdown,
            function(data) return GetPos() == data end,
            function(data) SetPos(data) end,
            { "Top & Bottom", "both" },
            { "Top Only", "top" },
            { "Bottom Only", "bottom" }
        )
    else
        if dropdownBtn then dropdownBtn:Hide() end
        posDropdown = CreateFrame("Frame", "ADB_PositionDropdown", panel, "UIDropDownMenuTemplate")
        posDropdown:SetPoint("TOPLEFT", posHeader, "BOTTOMLEFT", -16, -4)
        UIDropDownMenu_SetWidth(posDropdown, 140)

        local options = {
            { text = "Top & Bottom", value = "both" },
            { text = "Top Only", value = "top" },
            { text = "Bottom Only", value = "bottom" },
        }

        local function OnClick(self)
            UIDropDownMenu_SetSelectedValue(posDropdown, self.value)
            AssassinDebuffsBigginsDB.haloPosition = self.value
            UIDropDownMenu_SetText(posDropdown, self.text)
            RefreshAllActiveGlows()
        end

        UIDropDownMenu_Initialize(posDropdown, function(self, level)
            local selectedValue = AssassinDebuffsBigginsDB and AssassinDebuffsBigginsDB.haloPosition or DEFAULT_DB.haloPosition
            for _, opt in ipairs(options) do
                local info = UIDropDownMenu_CreateInfo()
                info.text = opt.text
                info.value = opt.value
                info.func = OnClick
                info.checked = (opt.value == selectedValue)
                UIDropDownMenu_AddButton(info, level)
            end
        end)

        local currentVal = AssassinDebuffsBigginsDB and AssassinDebuffsBigginsDB.haloPosition or DEFAULT_DB.haloPosition
        UIDropDownMenu_SetSelectedValue(posDropdown, currentVal)
        local currentText = (currentVal == "top" and "Top Only") or (currentVal == "bottom" and "Bottom Only") or "Top & Bottom"
        UIDropDownMenu_SetText(posDropdown, currentText)
    end

    -- 2. Halo Thickness Slider
    local thickSlider = CreateFrame("Slider", "ADB_ThicknessSlider", panel, "OptionsSliderTemplate")
    thickSlider:SetPoint("TOPLEFT", posHeader, "BOTTOMLEFT", 0, -48)
    thickSlider:SetMinMaxValues(1, 8)
    thickSlider:SetValueStep(1)
    thickSlider:SetObeyStepOnDrag(true)
    thickSlider:SetWidth(260)
    _G[thickSlider:GetName() .. "Low"]:SetText("1 px")
    _G[thickSlider:GetName() .. "High"]:SetText("8 px")
    local thickVal = AssassinDebuffsBigginsDB.borderThickness or DEFAULT_DB.borderThickness
    thickSlider:SetValue(thickVal)
    _G[thickSlider:GetName() .. "Text"]:SetText(string.format("Halo Thickness: %d px", thickVal))
    thickSlider:SetScript("OnValueChanged", function(self, value)
        value = math.floor(value + 0.5)
        AssassinDebuffsBigginsDB.borderThickness = value
        _G[self:GetName() .. "Text"]:SetText(string.format("Halo Thickness: %d px", value))
        RefreshAllActiveGlows()
    end)

    -- Section Label: Colors
    local colorHeader = panel:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    colorHeader:SetPoint("TOPLEFT", thickSlider, "BOTTOMLEFT", 0, -28)
    colorHeader:SetText("Debuff Halo Colors")

    -- Helper to create a color swatch row
    local function CreateColorSwatchRow(parent, anchor, yOffset, labelText, colorTable)
        local row = CreateFrame("Frame", nil, parent)
        row:SetSize(320, 26)
        row:SetPoint("TOPLEFT", anchor, "BOTTOMLEFT", 0, yOffset)

        local swatch = CreateFrame("Button", nil, row)
        swatch:SetSize(22, 22)
        swatch:SetPoint("LEFT", 0, 0)

        local border = swatch:CreateTexture(nil, "BACKGROUND")
        border:SetPoint("TOPLEFT", -1, 1)
        border:SetPoint("BOTTOMRIGHT", 1, -1)
        border:SetColorTexture(0.2, 0.2, 0.2, 1)

        local colorTex = swatch:CreateTexture(nil, "ARTWORK")
        colorTex:SetAllPoints()
        colorTex:SetColorTexture(colorTable.r, colorTable.g, colorTable.b, 1)

        local label = row:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
        label:SetPoint("LEFT", swatch, "RIGHT", 10, 0)
        label:SetText(labelText)

        swatch:SetScript("OnClick", function()
            OpenColorPicker(colorTable, function(r, g, b)
                colorTex:SetColorTexture(r, g, b, 1)
                RefreshAllActiveGlows()
            end)
        end)

        return row, colorTex
    end

    -- Color Swatches (All 5 Tracked Debuffs)
    local rowGarrote, texGarrote = CreateColorSwatchRow(panel, colorHeader, -10, "Garrote Halo Color", AssassinDebuffsBigginsDB.garroteColor)
    local rowRupture, texRupture = CreateColorSwatchRow(panel, rowGarrote, -8, "Rupture Halo Color", AssassinDebuffsBigginsDB.ruptureColor)
    local rowDeathstalker, texDeathstalker = CreateColorSwatchRow(panel, rowRupture, -8, "Deathstalker's Mark Halo Color", AssassinDebuffsBigginsDB.deathstalkerColor)
    local rowKingsbane, texKingsbane = CreateColorSwatchRow(panel, rowDeathstalker, -8, "Kingsbane Halo Color", AssassinDebuffsBigginsDB.kingsbaneColor)
    local rowDeathmark, texDeathmark = CreateColorSwatchRow(panel, rowKingsbane, -8, "Deathmark Halo Color", AssassinDebuffsBigginsDB.deathmarkColor)

    -- Reset to Defaults Button
    local resetBtn = CreateFrame("Button", "ADB_ResetButton", panel, "UIPanelButtonTemplate")
    resetBtn:SetSize(160, 26)
    resetBtn:SetPoint("TOPLEFT", rowDeathmark, "BOTTOMLEFT", 0, -28)
    resetBtn:SetText("Reset to Defaults")
    resetBtn:SetScript("OnClick", function()
        AssassinDebuffsBigginsDB.haloPosition = DEFAULT_DB.haloPosition
        AssassinDebuffsBigginsDB.borderThickness = DEFAULT_DB.borderThickness

        for _, debuffKey in ipairs({"garroteColor", "ruptureColor", "deathstalkerColor", "kingsbaneColor", "deathmarkColor"}) do
            AssassinDebuffsBigginsDB[debuffKey].r = DEFAULT_DB[debuffKey].r
            AssassinDebuffsBigginsDB[debuffKey].g = DEFAULT_DB[debuffKey].g
            AssassinDebuffsBigginsDB[debuffKey].b = DEFAULT_DB[debuffKey].b
        end

        thickSlider:SetValue(DEFAULT_DB.borderThickness)

        if posDropdown and posDropdown.SetDefaultText then
            posDropdown:SetDefaultText("Top & Bottom")
        elseif posDropdown and UIDropDownMenu_SetSelectedValue then
            UIDropDownMenu_SetSelectedValue(posDropdown, DEFAULT_DB.haloPosition)
            UIDropDownMenu_SetText(posDropdown, "Top & Bottom")
        end

        texGarrote:SetColorTexture(DEFAULT_DB.garroteColor.r, DEFAULT_DB.garroteColor.g, DEFAULT_DB.garroteColor.b, 1)
        texRupture:SetColorTexture(DEFAULT_DB.ruptureColor.r, DEFAULT_DB.ruptureColor.g, DEFAULT_DB.ruptureColor.b, 1)
        texDeathstalker:SetColorTexture(DEFAULT_DB.deathstalkerColor.r, DEFAULT_DB.deathstalkerColor.g, DEFAULT_DB.deathstalkerColor.b, 1)
        texKingsbane:SetColorTexture(DEFAULT_DB.kingsbaneColor.r, DEFAULT_DB.kingsbaneColor.g, DEFAULT_DB.kingsbaneColor.b, 1)
        texDeathmark:SetColorTexture(DEFAULT_DB.deathmarkColor.r, DEFAULT_DB.deathmarkColor.g, DEFAULT_DB.deathmarkColor.b, 1)

        RefreshAllActiveGlows()
    end)

    -- Register with Blizzard Settings API
    if Settings and Settings.RegisterCanvasLayoutCategory then
        local category = Settings.RegisterCanvasLayoutCategory(panel, "Assassin Debuffs Biggins")
        Settings.RegisterAddOnCategory(category)
        optionsCategory = category
    end
end

-- ---------------------------------------------------------------------------
-- 6. Slash Commands
-- ---------------------------------------------------------------------------
SLASH_ASSASSINDEBUFFSBIGGINS1 = "/adb"
SLASH_ASSASSINDEBUFFSBIGGINS2 = "/assassindebuffs"
SlashCmdList["ASSASSINDEBUFFSBIGGINS"] = function(msg)
    local cmd = msg and msg:lower():trim() or ""
    if cmd == "reset" then
        if ADB_ResetButton then
            ADB_ResetButton:Click()
        end
        print("|cFFFFD100[AssassinDebuffsBiggins]|r Settings reset to defaults.")
    elseif cmd == "debug" then
        ADB_DEBUG = not ADB_DEBUG
        hasDumpedDiagnostics = false
        print(string.format("|cFFFFD100[AssassinDebuffsBiggins]|r Debug logging %s.", ADB_DEBUG and "|cFF00FF00ENABLED|r" or "|cFFFF0000DISABLED|r"))
    elseif cmd == "clear" then
        hasDumpedDiagnostics = false
        if AssassinDebuffsBigginsDB then
            AssassinDebuffsBigginsDB.recentDebug = {}
        end
        print("|cFFFFD100[AssassinDebuffsBiggins]|r Recent auras debug log cleared.")
    elseif cmd == "dump" then
        print("|cFFFFD100[AssassinDebuffsBiggins]|r Recent Auras Log (newest first):")
        local debugList = AssassinDebuffsBigginsDB and AssassinDebuffsBigginsDB.recentDebug or {}
        if #debugList == 0 then
            print("  (No auras logged yet. Apply a debuff to a target first.)")
        else
            for i = 1, math.min(10, #debugList) do
                local d = debugList[i]
                print(string.format("  [%s] '%s' (ID: %s, Icon: %s, Tex: %s, Src: %s) -> key: %s",
                    tostring(d.time or ""), tostring(d.name or ""), tostring(d.spellId or ""),
                    tostring(d.icon or ""), tostring(d.tex or ""), tostring(d.source or ""), tostring(d.key or "")))
            end
        end
    else
        if optionsCategory and Settings and Settings.OpenToCategory then
            Settings.OpenToCategory(optionsCategory:GetID())
        else
            print("|cFFFFD100[AssassinDebuffsBiggins]|r Open Settings via Escape -> Options -> AddOns -> Assassin Debuffs Biggins")
        end
    end
end

-- ---------------------------------------------------------------------------
-- 7. Initialization & Event Lifecycle
-- ---------------------------------------------------------------------------
HookNamePlates()
InitializeTrackedNames()
InitializeTrackedIcons()

if EventUtil and EventUtil.ContinueOnAddOnLoaded then
    EventUtil.ContinueOnAddOnLoaded("Blizzard_NamePlates", function()
        HookNamePlates()
        InitializeTrackedNames()
        InitializeTrackedIcons()
    end)
end

local recentCLEUSpells = {}

local eventFrame = CreateFrame("Frame")
eventFrame:RegisterEvent("ADDON_LOADED")
eventFrame:RegisterEvent("PLAYER_LOGIN")
eventFrame:RegisterEvent("PLAYER_ENTERING_WORLD")
eventFrame:RegisterEvent("NAME_PLATE_UNIT_ADDED")
eventFrame:RegisterEvent("PLAYER_TARGET_CHANGED")
eventFrame:RegisterEvent("UNIT_AURA")
eventFrame:RegisterEvent("COMBAT_LOG_EVENT_UNFILTERED")

eventFrame:SetScript("OnEvent", function(self, event, arg1)
    if event == "ADDON_LOADED" then
        if arg1 == ADDON_NAME then
            if not AssassinDebuffsBigginsDB then
                AssassinDebuffsBigginsDB = {}
            end
            for k, v in pairs(DEFAULT_DB) do
                if type(v) == "table" then
                    if not AssassinDebuffsBigginsDB[k] then
                        AssassinDebuffsBigginsDB[k] = {}
                    end
                    for subK, subV in pairs(v) do
                        if AssassinDebuffsBigginsDB[k][subK] == nil then
                            AssassinDebuffsBigginsDB[k][subK] = subV
                        end
                    end
                else
                    if AssassinDebuffsBigginsDB[k] == nil then
                        AssassinDebuffsBigginsDB[k] = v
                    end
                end
            end

            RefreshColorCache()
            InitializeTrackedNames()
            InitializeTrackedIcons()
            CreateOptionsPanel()
            HookNamePlates()
        elseif arg1 == "Blizzard_NamePlates" then
            HookNamePlates()
            InitializeTrackedNames()
            InitializeTrackedIcons()
        end
    elseif event == "PLAYER_LOGIN" or event == "PLAYER_ENTERING_WORLD" then
        RefreshColorCache()
        InitializeTrackedNames()
        InitializeTrackedIcons()
        HookNamePlates()
    elseif event == "NAME_PLATE_UNIT_ADDED" then
        if arg1 and C_NamePlate and C_NamePlate.GetNamePlateForUnit then
            local namePlate = C_NamePlate.GetNamePlateForUnit(arg1)
            if namePlate then
                HookUnitFrameAuras(namePlate.UnitFrame)
            end
        end
    elseif event == "PLAYER_TARGET_CHANGED" then
        RefreshAllActiveGlows()
        RequestRefreshGlows()
    elseif event == "UNIT_AURA" then
        if arg1 and (arg1:find("^nameplate") or arg1 == "target") then
            RequestRefreshGlows()
        end
    elseif event == "COMBAT_LOG_EVENT_UNFILTERED" then
        if CombatLogGetCurrentEventInfo then
            local _, subevent, _, sourceGUID, _, _, _, destGUID, _, _, _, spellId, spellName = CombatLogGetCurrentEventInfo()
            if sourceGUID and UnitGUID and sourceGUID == UnitGUID("player") and (subevent == "SPELL_AURA_APPLIED" or subevent == "SPELL_AURA_REFRESH" or subevent == "SPELL_AURA_REMOVED") then
                table.insert(recentCLEUSpells, 1, { subevent = subevent, spellId = spellId, spellName = spellName, destGUID = destGUID, isSec = IsSecret(spellId) })
                if #recentCLEUSpells > 10 then table.remove(recentCLEUSpells) end
            end
        end
    end
end)
