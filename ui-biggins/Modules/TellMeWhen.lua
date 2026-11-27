local addonName, addon = ...

-- Cache upvalues
local _G = _G
local pairs = pairs
local math = math
local CreateFrame = CreateFrame
local hooksecurefunc = hooksecurefunc

local TellMeWhen = {}
addon.TellMeWhen = TellMeWhen

-- Helper to check if TMW skinning is enabled
local function IsEnabled()
    local db = UIBigginsDB or addon.DB_DEFAULTS
    if db.skinTellMeWhen ~= nil then
        return db.skinTellMeWhen
    end
    return db.flattenTellMeWhen ~= false
end

-- Helper to check if an icon represents a status bar rather than a square icon
local function IsBar(icon)
    if not icon then return false end
    if icon.group and (icon.group.viewName == "bar" or icon.group.viewName == "barv") then
        return true
    end
    if icon.Modules and (icon.Modules.IconModule_TimerBar_BarDisplay ~= nil or icon.Modules.IconModule_TimerBar ~= nil) then
        return true
    end
    return false
end

-- ==============================================================================
-- 1. SKINNING: Status Bars (Matching LazySpeed and PerfBiggins)
-- ==============================================================================

function TellMeWhen:SkinBar(icon)
    if not icon or not IsEnabled() then return end

    -- Hide any lingering squircle drop shadow mistakenly attached to bar
    if icon.__bigginsDropShadow then
        icon.__bigginsDropShadow:Hide()
    end

    local timerBarModule = icon.Modules and (icon.Modules.IconModule_TimerBar_BarDisplay or icon.Modules.IconModule_TimerBar)
    local bar = timerBarModule and timerBarModule.bar
    if not bar then return end

    local backdropModule = icon.Modules and icon.Modules.IconModule_Backdrop

    -- 1. Dark background base and UI-StatusBar track directly on the bar frame
    -- bgBase is locked to bar with SetAllPoints(bar) so it stays strictly inside the frame without sticking out
    if not bar.__bigginsBgBase then
        local bgBase = bar:CreateTexture(nil, "BACKGROUND", nil, -8)
        bgBase:SetAllPoints(bar)
        bgBase:SetColorTexture(0.05, 0.05, 0.05, 0.85)
        bar.__bigginsBgBase = bgBase
    else
        bar.__bigginsBgBase:ClearAllPoints()
        bar.__bigginsBgBase:SetAllPoints(bar)
        bar.__bigginsBgBase:SetColorTexture(0.05, 0.05, 0.05, 0.85)
        bar.__bigginsBgBase:Show()
    end

    -- bg provides the subtle horizontal gradient telemetry track matching PerfBiggins/LazySpeed
    if not bar.__bigginsBg then
        local bg = bar:CreateTexture(nil, "BACKGROUND", nil, -7)
        bg:SetAllPoints(bar)
        bg:SetTexture("Interface\\TargetingFrame\\UI-StatusBar")
        bg:SetVertexColor(0.05, 0.05, 0.05, 0.75)
        bar.__bigginsBg = bg
    else
        bar.__bigginsBg:SetAllPoints(bar)
        bar.__bigginsBg:SetTexture("Interface\\TargetingFrame\\UI-StatusBar")
        bar.__bigginsBg:SetVertexColor(0.05, 0.05, 0.05, 0.75)
        bar.__bigginsBg:Show()
    end

    -- 2. Blizzard Metallic Gold border overlay parented directly to bar
    -- Anchored 3px outside the bar (-3, 3) with matching 3px insets so the frame sits on the outside
    -- The 45-degree chamfered metallic corner bevel sits directly over bar's 90-degree corners
    local b = icon.__bigginsBarBackdrop
    if not b or b:GetParent() ~= bar then
        if b then b:Hide() end
        b = CreateFrame("Frame", nil, bar, "BackdropTemplate")
        icon.__bigginsBarBackdrop = b
    end

    b:SetFrameLevel(bar:GetFrameLevel() + 2)
    b:ClearAllPoints()
    b:SetPoint("TOPLEFT", bar, "TOPLEFT", -3, 3)
    b:SetPoint("BOTTOMRIGHT", bar, "BOTTOMRIGHT", 3, -3)
    b:SetBackdrop({
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        tile     = true,
        tileSize = 12,
        edgeSize = 12,
        insets   = { left = 3, right = 3, top = 3, bottom = 3 }
    })
    b:SetBackdropBorderColor(0.80, 0.70, 0.20, 1.00)
    b:Show()

    -- 3. Suppress TellMeWhen internal backdrop module and generic black borders
    if backdropModule then
        if backdropModule.border then
            backdropModule.border:SetAlpha(0)
            backdropModule.border:Hide()
        end
        if backdropModule.backdrop then
            backdropModule.backdrop:SetAlpha(0)
        end
        if backdropModule.container then
            backdropModule.container:Hide()
        end
    end

    -- 4. Set smooth UI-StatusBar texture on the bar
    if bar.SetStatusBarTexture then
        bar:SetStatusBarTexture("Interface\\TargetingFrame\\UI-StatusBar")
    end
    if timerBarModule.texture then
        timerBarModule.texture:SetTexture("Interface\\TargetingFrame\\UI-StatusBar")
    end
    if timerBarModule.texture2 then
        timerBarModule.texture2:SetTexture("Interface\\TargetingFrame\\UI-StatusBar")
    end

    -- 5. If the bar group has an icon attached next to the bar, skin that icon
    local containerModule = icon.Modules and (icon.Modules.IconModule_IconContainer_Masque or icon.Modules.IconModule_IconContainer)
    local gspv = icon.group and icon.group.GetSettingsPerView and icon.group:GetSettingsPerView()
    if gspv and gspv.Icon and containerModule and containerModule.container then
        local c = containerModule.container
        local texModule = icon.Modules and (icon.Modules.IconModule_Texture_Colored or icon.Modules.IconModule_Texture)
        local tex = texModule and texModule.texture
        if tex then
            addon.Skinning:ApplySquircleMask(tex, c)
        end
        addon.Skinning:ApplyDropShadow(c)
        if containerModule.border then
            containerModule.border:SetAlpha(0)
            containerModule.border:Hide()
        end
    end
end

-- ==============================================================================
-- 2. SKINNING: Square Icons (Matching Cooldown Manager)
-- ==============================================================================

function TellMeWhen:SkinSquareIcon(icon)
    if not icon or not IsEnabled() then return end

    -- Hide bar backdrop if it was previously applied
    if icon.__bigginsBarBackdrop then
        icon.__bigginsBarBackdrop:Hide()
    end

    -- Locate icon texture from TMW modules or direct children
    local texModule = icon.Modules and (icon.Modules.IconModule_Texture_Colored or icon.Modules.IconModule_Texture)
    local tex = texModule and texModule.texture
    if not tex then
        tex = icon.texture or (icon.GetName and _G[icon:GetName() .. "_Texture"])
    end

    -- Apply 45-degree chamfer squircle mask
    if tex then
        local mask = addon.Skinning:ApplySquircleMask(tex, icon)

        -- Mask cooldown sweeps if present
        local cdModule = icon.Modules and icon.Modules.IconModule_CooldownSweep
        if cdModule and mask then
            if cdModule.cooldown and cdModule.cooldown.GetSwipeTexture then
                local swipe = cdModule.cooldown:GetSwipeTexture()
                if swipe and swipe.AddMaskTexture then
                    swipe:AddMaskTexture(mask)
                end
            end
            if cdModule.cooldown2 and cdModule.cooldown2.GetSwipeTexture then
                local swipe2 = cdModule.cooldown2:GetSwipeTexture()
                if swipe2 and swipe2.AddMaskTexture then
                    swipe2:AddMaskTexture(mask)
                end
            end
        end
    end

    -- Add matching soft drop shadow
    addon.Skinning:ApplyDropShadow(icon)

    -- Strip TellMeWhen default border and normal texture
    local containerModule = icon.Modules and (icon.Modules.IconModule_IconContainer_Masque or icon.Modules.IconModule_IconContainer)
    if containerModule then
        if containerModule.border then
            containerModule.border:SetAlpha(0)
            containerModule.border:Hide()
        end
        if containerModule.container then
            local c = containerModule.container
            if c.border then
                c.border:SetAlpha(0)
                c.border:Hide()
            end
            local nt = c.GetNormalTexture and c:GetNormalTexture()
            if nt then nt:SetAlpha(0) end
        end
    end
    if icon.normaltex then
        icon.normaltex:SetAlpha(0)
    end
    local iconNt = icon.GetNormalTexture and icon:GetNormalTexture()
    if iconNt then iconNt:SetAlpha(0) end
end

-- Main entry point for skinning any TMW icon (dispatches to Bar or Square Icon)
function TellMeWhen:SkinIcon(icon)
    if not icon or not IsEnabled() then return end
    if IsBar(icon) then
        self:SkinBar(icon)
    else
        self:SkinSquareIcon(icon)
    end
end

function TellMeWhen:SkinAll()
    if not IsEnabled() or not TMW then return end

    if TMW.Groups then
        for _, group in pairs(TMW.Groups) do
            if group.numIcons then
                for iconID = 1, group.numIcons do
                    local icon = group[iconID]
                    if icon then
                        self:SkinIcon(icon)
                    end
                end
            end
        end
    end

    for groupID = 1, 50 do
        local group = _G["TellMeWhen_Group" .. groupID]
        if group then
            for iconID = 1, 100 do
                local icon = _G["TellMeWhen_Group" .. groupID .. "_Icon" .. iconID]
                if icon then
                    self:SkinIcon(icon)
                end
            end
        end
    end
end

function TellMeWhen:Initialize()
    if not TMW or not IsEnabled() then return end

    if TMW.RegisterCallback then
        TMW:RegisterCallback("TMW_ICON_SETUP_POST", function(event, icon)
            TellMeWhen:SkinIcon(icon)
        end)
        TMW:RegisterCallback("TMW_GLOBAL_UPDATE_POST", function()
            TellMeWhen:SkinAll()
        end)
    end

    -- Hook border creation on generic icon containers
    if TMW.Classes and TMW.Classes.IconModule_IconContainer then
        hooksecurefunc(TMW.Classes.IconModule_IconContainer, "SetBorder", function(self)
            if IsEnabled() and self.border then
                self.border:SetAlpha(0)
                self.border:Hide()
            end
        end)
    end

    -- Hook border creation on bar backdrops
    if TMW.Classes and TMW.Classes.IconModule_Backdrop then
        hooksecurefunc(TMW.Classes.IconModule_Backdrop, "SetBorder", function(self)
            if IsEnabled() and self.border then
                self.border:SetAlpha(0)
                self.border:Hide()
            end
        end)
        hooksecurefunc(TMW.Classes.IconModule_Backdrop, "SetupForIcon", function(self, icon)
            if IsEnabled() and IsBar(icon) then
                if self.border then
                    self.border:SetAlpha(0)
                    self.border:Hide()
                end
                if self.backdrop then
                    self.backdrop:SetAlpha(0)
                end
                if self.container then
                    self.container:Hide()
                end
            end
        end)
    end

    -- Hook bar updates to ensure smooth texture, scale 1.0, and backdrop positioning persist
    if TMW.Classes and TMW.Classes.IconModule_TimerBar then
        hooksecurefunc(TMW.Classes.IconModule_TimerBar, "OnEnable", function(self)
            if self.icon and IsBar(self.icon) then
                TellMeWhen:SkinBar(self.icon)
            end
        end)
    end
    if TMW.Classes and TMW.Classes.IconModule_TimerBar_BarDisplay then
        hooksecurefunc(TMW.Classes.IconModule_TimerBar_BarDisplay, "OnEnable", function(self)
            if self.icon and IsBar(self.icon) then
                TellMeWhen:SkinBar(self.icon)
            end
        end)
    end

    self:SkinAll()
end
