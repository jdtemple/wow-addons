--[[ ==============================================================================
    SafeRelease Biggins - Death Popup Guard & Click-Interception Overlay
    ------------------------------------------------------------------------------
    Zero-taint overlay button positioned over StaticPopup Release buttons,
    countdown ticking, modifier key bypass, and static popup hooking.
============================================================================== ]]--

local addonName, addon = ...

-- Cache global functions
local CreateFrame    = CreateFrame
local C_Timer        = C_Timer
local hooksecurefunc = hooksecurefunc
local string_format  = string.format
local _G             = _G

addon.activePopup = nil
addon.remainingSeconds = 0
local countdownTimer = nil

function addon:GetPopupButton(popup, index)
    if not popup then return nil end
    if popup.GetButton then
        return popup:GetButton(index)
    end
    return popup["button" .. index]
end

function addon:GetOrCreateOverlay(popup)
    if not popup then return nil end
    if popup.srbOverlay then
        return popup.srbOverlay
    end

    local releaseBtn = addon:GetPopupButton(popup, 1)
    if not releaseBtn then return nil end

    -- Overlay Button physically positioned on top of the Release button
    local overlay = CreateFrame("Button", nil, popup, "UIPanelButtonTemplate")
    overlay:SetAllPoints(releaseBtn)
    overlay:SetFrameLevel(releaseBtn:GetFrameLevel() + 5)
    overlay:Disable() -- Intercepts all clicks; does nothing

    popup.srbOverlay = overlay
    return overlay
end

function addon:ClearGuardState(popup)
    if countdownTimer then
        countdownTimer:Cancel()
        countdownTimer = nil
    end
    addon.remainingSeconds = 0

    if popup and popup.srbOverlay then
        popup.srbOverlay:Hide()
    end

    if popup then
        local releaseBtn = addon:GetPopupButton(popup, 1)
        if releaseBtn then
            releaseBtn:SetAlpha(1)
        end
    end
    addon.activePopup = nil
end

function addon:UnlockRelease(popup)
    addon:ClearGuardState(popup)
    if popup then
        local releaseBtn = addon:GetPopupButton(popup, 1)
        if releaseBtn then
            releaseBtn:SetAlpha(1)
            releaseBtn:Enable()
        end
    end
end

function addon:UpdateCountdownDisplay(popup)
    if not popup or not popup.srbOverlay then return end
    local overlay = popup.srbOverlay
    local db = SafeReleaseBigginsDB or addon.defaults
    local modName = addon:GetModifierDisplayName(db.modifierKey)

    if db.mode == "HYBRID" then
        overlay:SetText(string_format("Hold %s (%ds)", modName, addon.remainingSeconds))
    else
        overlay:SetText(string_format("Release (%ds)...", addon.remainingSeconds))
    end

    -- If in HYBRID mode and modifier key is currently held, keep overlay hidden and release button active
    if db.mode == "HYBRID" and addon:IsModifierKeyDown(db.modifierKey) then
        overlay:Hide()
        local releaseBtn = addon:GetPopupButton(popup, 1)
        if releaseBtn then
            releaseBtn:SetAlpha(1)
            releaseBtn:Enable()
        end
    else
        overlay:Show()
    end
end

function addon:StartCountdown(popup)
    local db = SafeReleaseBigginsDB or addon.defaults
    addon.remainingSeconds = db.delaySeconds or 5
    local overlay = addon:GetOrCreateOverlay(popup)
    if not overlay then return end

    local releaseBtn = addon:GetPopupButton(popup, 1)
    local isDown = addon:IsModifierKeyDown(db.modifierKey)

    if db.mode == "HYBRID" and isDown then
        overlay:Hide()
        if releaseBtn then
            releaseBtn:SetAlpha(1)
            releaseBtn:Enable()
        end
    else
        if releaseBtn then
            releaseBtn:SetAlpha(0)
        end
        addon:UpdateCountdownDisplay(popup)
    end

    if countdownTimer then countdownTimer:Cancel() end
    countdownTimer = C_Timer.NewTicker(1, function()
        addon.remainingSeconds = addon.remainingSeconds - 1
        if addon.remainingSeconds <= 0 then
            addon:UnlockRelease(popup)
        else
            addon:UpdateCountdownDisplay(popup)
        end
    end, addon.remainingSeconds)
end

function addon:ApplyGuard(popup)
    if not popup or popup.which ~= "DEATH" then return end
    if not addon:IsCurrentContextGuarded() then
        addon:ClearGuardState(popup)
        return
    end

    -- If the player has a self-resurrect option (Ankh/Soulstone), let Blizzard handle it
    if addon:HasUsableSelfResurrect() then
        addon:ClearGuardState(popup)
        return
    end

    addon.activePopup = popup
    local db = SafeReleaseBigginsDB or addon.defaults
    local overlay = addon:GetOrCreateOverlay(popup)
    if not overlay then return end

    local releaseBtn = addon:GetPopupButton(popup, 1)
    local isDown = addon:IsModifierKeyDown(db.modifierKey)
    local modName = addon:GetModifierDisplayName(db.modifierKey)

    if db.mode == "MODIFIER" then
        if isDown then
            overlay:Hide()
            if releaseBtn then
                releaseBtn:SetAlpha(1)
                releaseBtn:Enable()
            end
        else
            overlay:Show()
            overlay:SetText(string_format("Hold %s", modName))
            if releaseBtn then releaseBtn:SetAlpha(0) end
        end
    elseif db.mode == "COUNTDOWN" then
        addon:StartCountdown(popup)
    elseif db.mode == "HYBRID" then
        addon:StartCountdown(popup)
    end
end

function addon:OnModifierStateChanged()
    local popup = addon.activePopup
    if not (popup and popup:IsShown() and popup.which == "DEATH") then return end

    local db = SafeReleaseBigginsDB or addon.defaults
    if db.mode == "MODIFIER" or db.mode == "HYBRID" then
        local isDown = addon:IsModifierKeyDown(db.modifierKey)
        local releaseBtn = addon:GetPopupButton(popup, 1)
        local overlay = popup.srbOverlay
        local modName = addon:GetModifierDisplayName(db.modifierKey)

        if isDown then
            if overlay then
                overlay:Hide()
            end
            if releaseBtn then
                releaseBtn:SetAlpha(1)
                releaseBtn:Enable()
            end
        else
            if db.mode == "MODIFIER" then
                if overlay then
                    overlay:Show()
                    overlay:SetText(string_format("Hold %s", modName))
                end
                if releaseBtn then releaseBtn:SetAlpha(0) end
            elseif db.mode == "HYBRID" then
                if addon.remainingSeconds > 0 then
                    if overlay then
                        overlay:Show()
                        addon:UpdateCountdownDisplay(popup)
                    end
                    if releaseBtn then releaseBtn:SetAlpha(0) end
                else
                    if overlay then overlay:Hide() end
                    if releaseBtn then releaseBtn:SetAlpha(1) end
                end
            end
        end
    end
end

function addon:OnRegenEnabled()
    local popup = addon.activePopup
    if popup and popup:IsShown() and popup.which == "DEATH" then
        local db = SafeReleaseBigginsDB or addon.defaults
        if db.bypassFullWipe and addon:IsFullRaidWipe() then
            addon:UnlockRelease(popup)
        end
    end
end

-- Securely hook all 4 StaticPopup dialogs
function addon:HookStaticPopups()
    for i = 1, 4 do
        local popup = _G["StaticPopup" .. i]
        if popup then
            hooksecurefunc(popup, "Show", function(self)
                if self and self.which == "DEATH" then
                    addon:ApplyGuard(self)
                end
            end)
            popup:HookScript("OnHide", function(self)
                if self and self.which == "DEATH" then
                    addon:ClearGuardState(self)
                end
            end)
        end
    end
end
