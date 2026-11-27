local addonName, addon = ...

-- Cache upvalues
local math = math
local C_Texture = C_Texture

local Skinning = {}
addon.Skinning = Skinning

-- Returns the atlas name for the 45-degree chamfer squircle mask
local function GetSquircleMaskAtlas()
    if C_Texture and C_Texture.GetAtlasInfo and C_Texture.GetAtlasInfo("UI-HUD-CoolDownManager-Mask") then
        return "UI-HUD-CoolDownManager-Mask"
    end
    return "UI-HUD-ActionBar-IconFrame-Mask"
end

-- Returns the atlas/texture for the subtle drop shadow
local function GetDropShadowAtlas()
    if C_Texture and C_Texture.GetAtlasInfo and C_Texture.GetAtlasInfo("UI-HUD-CoolDownManager-IconOverlay") then
        return "UI-HUD-CoolDownManager-IconOverlay", true
    end
    return "Interface\\Cooldown\\UI-HUD-ActionBar-SecondaryCooldown", false
end

-- Applies the 45-degree chamfer squircle mask to a texture
function Skinning:ApplySquircleMask(texture, parentFrame)
    if not texture or not texture.AddMaskTexture then return end
    parentFrame = parentFrame or texture:GetParent()
    if not parentFrame then return end

    if not parentFrame.__bigginsMask then
        local mask = parentFrame:CreateMaskTexture()
        mask:SetAtlas(GetSquircleMaskAtlas())
        mask:SetAllPoints(texture)
        parentFrame.__bigginsMask = mask
    end

    texture:AddMaskTexture(parentFrame.__bigginsMask)
    return parentFrame.__bigginsMask
end

-- Adds a soft drop shadow strictly behind the frame on the BACKGROUND layer (sublevel -8)
function Skinning:ApplyDropShadow(frame)
    if not frame then return end

    if not frame.__bigginsDropShadow then
        local shadow = frame:CreateTexture(nil, "BACKGROUND", nil, -8)
        local asset, isAtlas = GetDropShadowAtlas()
        if isAtlas then
            shadow:SetAtlas(asset)
        else
            shadow:SetTexture(asset)
        end
        shadow:ClearAllPoints()

        local w, h = frame:GetSize()
        if not w or w <= 0 then w, h = 36, 36 end
        local ox = math.max(4, math.floor(w * 0.16 + 0.5))
        local oy = math.max(3, math.floor(h * 0.14 + 0.5))
        shadow:SetPoint("TOPLEFT", frame, "TOPLEFT", -ox, oy)
        shadow:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", ox, -oy)
        frame.__bigginsDropShadow = shadow
    end

    frame.__bigginsDropShadow:Show()
    return frame.__bigginsDropShadow
end

-- Hides standard Blizzard metallic normal textures and border decorations
function Skinning:HideMetallicFrame(btn)
    if not btn then return end

    if btn.NormalTexture then btn.NormalTexture:SetAlpha(0) end
    local nt = btn.GetNormalTexture and btn:GetNormalTexture()
    if nt then nt:SetAlpha(0) end

    if btn.SlotBackground then btn.SlotBackground:SetAlpha(0) end
    if btn.SlotArt then btn.SlotArt:SetAlpha(0) end
    if btn.Border then btn.Border:SetAlpha(0) end
    if btn.NormalBorder then btn.NormalBorder:SetAlpha(0) end

    -- Flyout textures (e.g. mage teleports/portals)
    if btn.BorderShadow then btn.BorderShadow:SetAlpha(0) end
    if btn.FlyoutBorder then btn.FlyoutBorder:SetAlpha(0) end
    if btn.FlyoutBorderShadow then btn.FlyoutBorderShadow:SetAlpha(0) end
end
