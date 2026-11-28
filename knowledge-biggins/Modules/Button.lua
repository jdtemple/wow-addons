--[[ ==============================================================================
    Knowledge Biggins - Secure Action Button Module
    ------------------------------------------------------------------------------
    Secure popup consumer button with native action bar styling, Alt + Right-Click
    dismissal, and dynamic combat mitigation.
============================================================================== ]]--

local addonName, addon = ...

-- Cache global functions
local CreateFrame                  = CreateFrame
local InCombatLockdown             = InCombatLockdown
local IsShiftKeyDown               = IsShiftKeyDown
local IsAltKeyDown                 = IsAltKeyDown
local PlaySound                    = PlaySound
local SOUNDKIT                     = SOUNDKIT
local GameTooltip                  = GameTooltip
local GameTooltip_SetDefaultAnchor = GameTooltip_SetDefaultAnchor
local UIParent                     = UIParent
local string_format                = string.format

local C_Texture                    = C_Texture
local C_Item                       = C_Item
local GetItemCount                 = GetItemCount

-- Secure Action Button Creation
local button = CreateFrame("Button", "KnowledgeBigginsButton", UIParent, "SecureActionButtonTemplate")
button:SetSize(45, 45)
button:SetMovable(true)
button:SetClampedToScreen(true)
button:RegisterForDrag("LeftButton")
button:RegisterForClicks("LeftButtonDown", "LeftButtonUp", "RightButtonUp")
button:Hide()
addon.button = button

-- Native Action Bar Normal Bezel Frame (OVERLAY layer, stretched across full button)
local normalBorder = button:CreateTexture(nil, "OVERLAY", nil, 1)
if C_Texture and C_Texture.GetAtlasInfo and C_Texture.GetAtlasInfo("UI-HUD-ActionBar-IconFrame") then
    normalBorder:SetAtlas("UI-HUD-ActionBar-IconFrame")
elseif C_Texture and C_Texture.GetAtlasInfo and C_Texture.GetAtlasInfo("UI-HUD-ActionBar-IconFrame-Border") then
    normalBorder:SetAtlas("UI-HUD-ActionBar-IconFrame-Border")
else
    normalBorder:SetAtlas("UI-HUD-ActionBar-IconFrame")
end
normalBorder:ClearAllPoints()
normalBorder:SetAllPoints(button)
button.NormalBorder = normalBorder

-- Item Icon Texture (ARTWORK layer, inset by 3px on all sides so bezel frames it seamlessly)
button.Icon = button:CreateTexture(nil, "ARTWORK")
button.Icon:ClearAllPoints()
button.Icon:SetPoint("TOPLEFT", button, "TOPLEFT", 3, -3)
button.Icon:SetPoint("BOTTOMRIGHT", button, "BOTTOMRIGHT", -3, 3)
button.Icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
button.Icon:SetVertexColor(1, 1, 1, 1)

-- Native Action Bar Highlight Texture (Mouseover)
if C_Texture and C_Texture.GetAtlasInfo and C_Texture.GetAtlasInfo("UI-HUD-ActionBar-IconFrame-Mouseover") then
    button:SetHighlightAtlas("UI-HUD-ActionBar-IconFrame-Mouseover", "ADD")
else
    button:SetHighlightTexture("Interface\\Buttons\\ButtonHilight-Square", "ADD")
end

-- Native Action Bar Pushed Texture
if C_Texture and C_Texture.GetAtlasInfo and C_Texture.GetAtlasInfo("UI-HUD-ActionBar-IconFrame-Pushed") then
    button:SetPushedAtlas("UI-HUD-ActionBar-IconFrame-Pushed")
else
    button:SetPushedTexture("Interface\\Buttons\\UI-Quickslot-Depress")
end

-- Stack Count FontString (Matches native Blizzard ActionButton NumberFontNormal)
button.Count = button:CreateFontString(nil, "OVERLAY", "NumberFontNormal")
button.Count:SetPoint("BOTTOMRIGHT", button, "BOTTOMRIGHT", -2, 2)
button.Count:SetJustifyH("RIGHT")

-- Dragging Scripts (When unlocked, Shift + Left-Click Drag moves the button)
button:SetScript("OnDragStart", function(self)
    if InCombatLockdown() then return end
    local db = KnowledgeBigginsDB or addon.defaults
    if not db.locked and IsShiftKeyDown() then
        self:StartMoving()
        self.isMoving = true
    end
end)

button:SetScript("OnDragStop", function(self)
    if not self.isMoving then return end
    self:StopMovingOrSizing()
    self.isMoving = false
    local point, _, _, xOfs, yOfs = self:GetPoint()
    local db = KnowledgeBigginsDB or addon.defaults
    db.point = point or "CENTER"
    db.xOfs = xOfs or 0
    db.yOfs = yOfs or -140
end)

-- Block list helper
function addon:AddItemToBlacklist(itemID, itemLink)
    if not itemID then return false end
    local db = KnowledgeBigginsDB or addon.defaults
    db.blacklist = db.blacklist or {}
    if not db.blacklist[itemID] then
        db.blacklist[itemID] = true
        addon.knowledgeItemCache[itemID] = false
        PlaySound(SOUNDKIT.IG_MAINMENU_CLOSE)
        addon:PrintMsg("Added " .. (itemLink or ("item " .. itemID)) .. " to block list.")
        addon:UpdateKnowledgeButton()
        if addon.optionsPanel and addon.optionsPanel.RefreshTrays then
            addon.optionsPanel.RefreshTrays()
        end
        return true
    else
        addon:PrintMsg((itemLink or ("Item " .. itemID)) .. " is already on block list.")
        return false
    end
end

-- PreClick: Alt + Right-Click to block current item
button:SetScript("PreClick", function(self, btn, down)
    if InCombatLockdown() then return end

    if btn == "RightButton" and IsAltKeyDown() then
        -- Disarm attributes so right-click cannot trigger secure action
        self.blockingItem = true
        self:SetAttribute("type", nil)
        self:SetAttribute("type1", nil)
        self:SetAttribute("type2", nil)
        self:SetAttribute("macrotext", nil)
        self:SetAttribute("macrotext1", nil)
        self:SetAttribute("macrotext2", nil)

        if not down and addon.currentLootedItem then
            local targetItemID = addon.currentLootedItem.itemID
            local targetLink = addon.currentLootedItem.link
            addon:AddItemToBlacklist(targetItemID, targetLink)
        end
        return
    end
end)

-- PostClick: safely re-arm the button after click event has completely resolved
button:SetScript("PostClick", function(self, btn)
    if InCombatLockdown() then return end
    if self.blockingItem then
        self.blockingItem = nil
        addon:UpdateKnowledgeButton()
    end
end)

-- Tooltip Handling
button:SetScript("OnEnter", function(self)
    GameTooltip_SetDefaultAnchor(GameTooltip, self)
    local db = KnowledgeBigginsDB or addon.defaults
    local currentLootedItem = addon.currentLootedItem
    if currentLootedItem then
        if currentLootedItem.bag and currentLootedItem.slot then
            GameTooltip:SetBagItem(currentLootedItem.bag, currentLootedItem.slot)
        else
            GameTooltip:SetItemByID(currentLootedItem.itemID)
        end
        GameTooltip:AddLine(" ")
        GameTooltip:AddLine("|cFF00FF00Left-Click:|r Study / Consume")
        if not db.locked then
            GameTooltip:AddLine("|cFF888888Shift + Drag:|r Move Button")
        else
            GameTooltip:AddLine("|cFF888888Position Locked (Unlock in Settings to move)|r")
        end
        GameTooltip:AddLine("|cFFFF5555Alt + Right-Click:|r Block Item from Showing")
    else
        GameTooltip:AddLine("|cFFFFD100Knowledge Biggins|r")
        GameTooltip:AddLine("No unconsumed knowledge items in your bags.", 1, 1, 1)
        GameTooltip:AddLine(" ")
        if not db.locked then
            GameTooltip:AddLine("|cFF888888Shift + Drag:|r Move Button")
        else
            GameTooltip:AddLine("|cFF888888Position Locked (Unlock in Settings to move)|r")
        end
        GameTooltip:AddLine("|cFF888888Tip: Alt + Right-Click on an item to block it from showing.|r")
    end
    GameTooltip:Show()
end)

button:SetScript("OnLeave", function(self)
    GameTooltip:Hide()
end)

-- Update the popup button with current unstudied items
function addon:UpdateKnowledgeButton()
    if InCombatLockdown() then
        addon.isUpdatePending = true
        return
    end

    local db = KnowledgeBigginsDB or addon.defaults
    if db.enabled == false then
        addon.currentLootedItem = nil
        button:Hide()
        return
    end

    button:SetScale(db.scale or 1.0)

    local items = addon:ScanBagsForKnowledge()
    if #items == 0 then
        addon.currentLootedItem = nil
        if db.alwaysShow or not db.locked then
            button.Icon:SetTexture(134400)
            button.Icon:SetDesaturated(true)
            button.Count:SetText("")
            button:SetAttribute("type", nil)
            button:SetAttribute("type1", nil)
            button:SetAttribute("type2", nil)
            button:SetAttribute("macrotext", nil)
            button:SetAttribute("macrotext1", nil)
            button:SetAttribute("macrotext2", nil)
            button:SetAttribute("shift-type", "")
            button:SetAttribute("shift-type1", "")
            button:SetAttribute("shift-type2", "")
            button:Show()
        else
            button:Hide()
        end
        return
    end

    -- Target the first unconsumed item
    addon.currentLootedItem = items[1]
    local currentLootedItem = addon.currentLootedItem
    button.Icon:SetDesaturated(false)
    button.Icon:SetTexture(currentLootedItem.icon or 134400)

    -- Count total quantity of this specific item in bags
    local itemCount = (C_Item and C_Item.GetItemCount and C_Item.GetItemCount(currentLootedItem.itemID)) or (GetItemCount and GetItemCount(currentLootedItem.itemID)) or (currentLootedItem.count or 1)
    if itemCount > 1 then
        button.Count:SetText(itemCount)
    else
        button.Count:SetText("")
    end

    -- Configure Secure Action
    local macroText = "/use item:" .. currentLootedItem.itemID
    if currentLootedItem.bag and currentLootedItem.slot then
        macroText = string_format("/use %d %d", currentLootedItem.bag, currentLootedItem.slot)
    end

    button:SetAttribute("type", "macro")
    button:SetAttribute("type1", "macro")
    button:SetAttribute("type2", "macro")
    button:SetAttribute("macrotext", macroText)
    button:SetAttribute("macrotext1", macroText)
    button:SetAttribute("macrotext2", macroText)
    button:SetAttribute("shift-type", "")
    button:SetAttribute("shift-type1", "")
    button:SetAttribute("shift-type2", "")
    button:SetAttribute("shift-macrotext", "")
    button:SetAttribute("shift-macrotext1", "")
    button:SetAttribute("shift-macrotext2", "")

    button:Show()
end

function addon:ApplyPosition()
    local db = KnowledgeBigginsDB or addon.defaults
    button:ClearAllPoints()
    button:SetPoint(db.point or "CENTER", UIParent, db.point or "CENTER", db.xOfs or 0, db.yOfs or -140)
    button:SetScale(db.scale or 1.0)
end

function addon:ResetPosition()
    if InCombatLockdown() then
        addon:PrintMsg("|cFFFF5555Cannot reset button position during combat lockdown.|r")
        return
    end
    local db = KnowledgeBigginsDB or addon.defaults
    db.point = "CENTER"
    db.xOfs = 0
    db.yOfs = -140
    db.scale = 1.0
    addon:ApplyPosition()
    addon:UpdateKnowledgeButton()
    addon:PrintMsg("Button position reset to default.")
end
