local addonName, addon = ...

-- Cache upvalues
local _G = _G
local pairs = pairs
local ipairs = ipairs
local type = type
local hooksecurefunc = hooksecurefunc
local GetCursorInfo = GetCursorInfo

local ActionBars = {}
addon.ActionBars = ActionBars

local isDragging = false
local trackedButtons = {}

local BUTTON_PREFIXES = {
    "ActionButton",
    "MultiBarBottomLeftButton",
    "MultiBarBottomRightButton",
    "MultiBarRightButton",
    "MultiBarLeftButton",
    "MultiBar5Button",
    "MultiBar6Button",
    "MultiBar7Button",
    "PetActionButton",
    "StanceButton",
    "PossessButton",
}

local STANDALONE_BUTTONS = {
    "ExtraActionButton1",
    "KnowledgeBigginsButton",
}

function ActionBars:FlattenButton(btn)
    if not btn then return end
    addon.Skinning:HideMetallicFrame(btn)

    local icon = btn.icon or btn.Icon or (btn.GetName and _G[btn:GetName() .. "Icon"])
    if icon then
        if btn.NormalBorder then
            icon:ClearAllPoints()
            icon:SetAllPoints(btn)
            icon:SetTexCoord(0, 1, 0, 1)
        end
        addon.Skinning:ApplySquircleMask(icon, btn)
    end

    addon.Skinning:ApplyDropShadow(btn)
    trackedButtons[btn] = true
end

function ActionBars:SkinKnowledgeBiggins()
    local btn = _G["KnowledgeBigginsButton"]
    if btn then
        local db = UIBigginsDB or addon.DB_DEFAULTS
        if db.flattenActionBars then
            self:FlattenButton(btn)
        end
    end
end

function ActionBars:UpdateButtonText(btn)
    if not btn then return end
    local db = UIBigginsDB or addon.DB_DEFAULTS

    -- Macro Name Text
    local nameText = btn.Name or (btn.GetName and _G[btn:GetName() .. "Name"])
    if nameText then
        if db.hideMacroText then
            nameText:SetAlpha(isDragging and 1 or 0)
        else
            nameText:SetAlpha(1)
        end
    end

    -- Hotkey / Keybind Text
    local hotKey = btn.HotKey or (btn.GetName and _G[btn:GetName() .. "HotKey"])
    if hotKey then
        if db.hideKeybindText then
            hotKey:SetAlpha(isDragging and 1 or 0)
        else
            hotKey:SetAlpha(1)
        end
    end
end

function ActionBars:UpdateAllText()
    for btn in pairs(trackedButtons) do
        self:UpdateButtonText(btn)
    end
end

function ActionBars:SetDragging(dragging)
    if isDragging ~= dragging then
        isDragging = dragging
        self:UpdateAllText()
    end
end

local function OnButtonArtUpdate(btn)
    addon.Skinning:HideMetallicFrame(btn)
end

function ActionBars:Initialize()
    local db = UIBigginsDB or addon.DB_DEFAULTS
    local shouldFlatten = db.flattenActionBars

    -- 1. Scan and register standard button matrices (1 to 12)
    for _, prefix in ipairs(BUTTON_PREFIXES) do
        for i = 1, 12 do
            local btn = _G[prefix .. i]
            if btn then
                if shouldFlatten then
                    self:FlattenButton(btn)
                else
                    trackedButtons[btn] = true
                end
                self:UpdateButtonText(btn)
            end
        end
    end

    -- 2. Standalone action buttons
    for _, name in ipairs(STANDALONE_BUTTONS) do
        local btn = _G[name]
        if btn then
            if shouldFlatten then
                self:FlattenButton(btn)
            else
                trackedButtons[btn] = true
            end
            self:UpdateButtonText(btn)
        end
    end

    -- Explicitly protect MainMenuBarVehicleLeaveButton so its arrow graphic is always visible
    if MainMenuBarVehicleLeaveButton then
        local nt = MainMenuBarVehicleLeaveButton.GetNormalTexture and MainMenuBarVehicleLeaveButton:GetNormalTexture()
        if nt then nt:SetAlpha(1) end
        if MainMenuBarVehicleLeaveButton.NormalTexture then
            MainMenuBarVehicleLeaveButton.NormalTexture:SetAlpha(1)
        end
        if MainMenuBarVehicleLeaveButton.__bigginsDropShadow then
            MainMenuBarVehicleLeaveButton.__bigginsDropShadow:Hide()
        end
    end

    -- 3. Spell Flyout popup buttons
    for i = 1, 10 do
        local btn = _G["SpellFlyoutPopupButton" .. i]
        if btn then
            if shouldFlatten then
                self:FlattenButton(btn)
            else
                trackedButtons[btn] = true
            end
            self:UpdateButtonText(btn)
        end
    end

    -- Install hooks if flattening is enabled for this session
    if shouldFlatten then
        if BaseActionButtonMixin and BaseActionButtonMixin.UpdateButtonArt then
            hooksecurefunc(BaseActionButtonMixin, "UpdateButtonArt", OnButtonArtUpdate)
        end
        if FlyoutButtonMixin and FlyoutButtonMixin.UpdateBorderShadow then
            hooksecurefunc(FlyoutButtonMixin, "UpdateBorderShadow", function(btn)
                if btn.BorderShadow then btn.BorderShadow:SetAlpha(0) end
            end)
        end
        if PetActionButtonMixin and PetActionButtonMixin.Update then
            hooksecurefunc(PetActionButtonMixin, "Update", OnButtonArtUpdate)
        end
        if type(ActionButton_Update) == "function" then
            hooksecurefunc("ActionButton_Update", OnButtonArtUpdate)
        end
        if SpellFlyout and SpellFlyout.Toggle then
            hooksecurefunc(SpellFlyout, "Toggle", function()
                for i = 1, 10 do
                    local btn = _G["SpellFlyoutPopupButton" .. i]
                    if btn then
                        ActionBars:FlattenButton(btn)
                        ActionBars:UpdateButtonText(btn)
                    end
                end
            end)
        end
    end

    -- Hotkey hooks for smart text updates
    if ActionButtonMixin and ActionButtonMixin.UpdateHotkeys then
        hooksecurefunc(ActionButtonMixin, "UpdateHotkeys", function(btn)
            ActionBars:UpdateButtonText(btn)
        end)
    end
    if type(ActionButton_UpdateHotkeys) == "function" then
        hooksecurefunc("ActionButton_UpdateHotkeys", function(btn)
            ActionBars:UpdateButtonText(btn)
        end)
    end

    -- Dragging cursor hooks for instant reveal
    hooksecurefunc("PickupAction", function()
        ActionBars:SetDragging(true)
    end)
    hooksecurefunc("PlaceAction", function()
        ActionBars:SetDragging(false)
    end)
    hooksecurefunc("ClearCursor", function()
        ActionBars:SetDragging(false)
    end)
end
