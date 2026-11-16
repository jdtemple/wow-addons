--[[ ==============================================================================
    Knowledge Biggins - Zero-Maintenance Profession Knowledge Popup Consumer
    ------------------------------------------------------------------------------
    Author: Biggins (US-Whisperwind)
    Compatibility: World of Warcraft: Midnight / The War Within (Patch 11.x - 12.x)
    License: All Rights Reserved
============================================================================== ]]--

local addonName, ns = ...

-- Cache global functions
local CreateFrame              = CreateFrame
local InCombatLockdown         = InCombatLockdown
local IsShiftKeyDown           = IsShiftKeyDown
local PlaySound                = PlaySound
local GameTooltip              = GameTooltip
local UIParent                 = UIParent
local print                    = print
local type                     = type
local ipairs                   = ipairs
local tonumber                 = tonumber

local C_Container              = C_Container
local C_TooltipInfo            = C_TooltipInfo
local C_Item                   = C_Item

-- Defaults
local defaults = {
    point = "CENTER",
    xOfs = 0,
    yOfs = -140,
    scale = 1.0,
    locked = false,
    alwaysShow = false,
}

local KnowledgeBiggins = {}
_G["KnowledgeBiggins"] = KnowledgeBiggins
KnowledgeBiggins.version = "1.0.0"

local isUpdatePending = false
local knowledgeItemCache = {}
local currentLootedItem = nil

local function PrintMsg(msg)
    print("|cFFFFD100Knowledge Biggins:|r " .. msg)
end

-- ==============================================================================
-- 1. UNIVERSAL KNOWLEDGE DETECTION ENGINE
-- ==============================================================================

local function IsKnowledgeItem(bag, slot, itemID)
    if not itemID then return false end

    -- Check cache first
    if knowledgeItemCache[itemID] ~= nil then
        return knowledgeItemCache[itemID]
    end

    if not C_TooltipInfo then
        return false
    end

    local data = nil
    if bag and slot and C_TooltipInfo.GetBagItem then
        data = C_TooltipInfo.GetBagItem(bag, slot)
    elseif C_TooltipInfo.GetItemByID then
        data = C_TooltipInfo.GetItemByID(itemID)
    end

    if data and data.lines then
        for _, line in ipairs(data.lines) do
            local text = line.leftText
            if text and type(text) == "string" then
                local lower = text:lower()
                -- Match standard Blizzard profession knowledge and skill patterns (case-insensitive)
                if lower:find("study to")
                    or lower:find("increase.-knowledge")
                    or lower:find("grant.-knowledge")
                    or lower:find("gain.-knowledge")
                    or lower:find("increase your .- skill") then
                    knowledgeItemCache[itemID] = true
                    return true
                end
            end
        end
    end

    -- Tooltip lines might not be loaded into client cache yet
    -- Don't permanently cache false if data was missing
    if data and data.lines and #data.lines > 0 then
        knowledgeItemCache[itemID] = false
    end

    return false
end

local function ScanBagsForKnowledge()
    local found = {}
    if not C_Container or not C_Container.GetContainerNumSlots then
        return found
    end

    for bag = 0, 4 do
        local numSlots = C_Container.GetContainerNumSlots(bag) or 0
        for slot = 1, numSlots do
            local info = C_Container.GetContainerItemInfo(bag, slot)
            if info and info.itemID then
                if IsKnowledgeItem(bag, slot, info.itemID) then
                    table.insert(found, {
                        bag = bag,
                        slot = slot,
                        itemID = info.itemID,
                        icon = info.iconFileID or 134400,
                        count = info.stackCount or 1,
                        link = info.hyperlink,
                    })
                end
            end
        end
    end

    return found
end

-- ==============================================================================
-- 2. SECURE POPUP CONSUMER BUTTON (NATIVE ACTION BAR STYLING)
-- ==============================================================================

local button = CreateFrame("Button", "KnowledgeBigginsButton", UIParent, "SecureActionButtonTemplate")
button:SetSize(45, 45)
button:SetMovable(true)
button:SetClampedToScreen(true)
button:RegisterForDrag("LeftButton")
button:RegisterForClicks("LeftButtonDown", "LeftButtonUp", "RightButtonDown", "RightButtonUp")
button:Hide()

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

-- Stack Count FontString (Matches native ActionButton NumberFontNormalSmallGray)
button.Count = button:CreateFontString(nil, "OVERLAY", "NumberFontNormalSmallGray", 2)
button.Count:SetPoint("BOTTOMRIGHT", button, "BOTTOMRIGHT", -3, 3)

-- Dragging Scripts (When unlocked, Shift + Left-Click Drag moves the button)
button:SetScript("OnDragStart", function(self)
    if InCombatLockdown() then return end
    local db = KnowledgeBigginsDB or defaults
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
    local db = KnowledgeBigginsDB or defaults
    db.point = point or "CENTER"
    db.xOfs = xOfs or 0
    db.yOfs = yOfs or -140
end)

-- Tooltip Handling
button:SetScript("OnEnter", function(self)
    GameTooltip:SetOwner(self, "ANCHOR_TOP")
    local db = KnowledgeBigginsDB or defaults
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
    else
        GameTooltip:AddLine("|cFFFFD100Knowledge Biggins|r")
        GameTooltip:AddLine("No unconsumed knowledge items in your bags.", 1, 1, 1)
        GameTooltip:AddLine(" ")
        if not db.locked then
            GameTooltip:AddLine("|cFF888888Shift + Drag:|r Move Button")
        else
            GameTooltip:AddLine("|cFF888888Position Locked (Unlock in Settings to move)|r")
        end
    end
    GameTooltip:Show()
end)

button:SetScript("OnLeave", function(self)
    GameTooltip:Hide()
end)

-- Update the popup button with current unstudied items
local function UpdateKnowledgeButton()
    if InCombatLockdown() then
        isUpdatePending = true
        return
    end

    local db = KnowledgeBigginsDB or defaults
    button:SetScale(db.scale or 1.0)

    local items = ScanBagsForKnowledge()
    if #items == 0 then
        currentLootedItem = nil
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
    currentLootedItem = items[1]
    button.Icon:SetDesaturated(false)
    button.Icon:SetTexture(currentLootedItem.icon or 134400)

    -- Count total knowledge items in bags
    local totalCount = 0
    for _, itm in ipairs(items) do
        totalCount = totalCount + (itm.count or 1)
    end

    if totalCount > 1 then
        button.Count:SetText(totalCount)
    else
        button.Count:SetText("")
    end

    -- Configure Secure Action
    local macroText = "/use item:" .. currentLootedItem.itemID
    if currentLootedItem.bag and currentLootedItem.slot then
        macroText = string.format("/use %d %d", currentLootedItem.bag, currentLootedItem.slot)
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

-- ==============================================================================
-- 3. POSITIONING & SETTINGS
-- ==============================================================================

local function ApplyPosition()
    local db = KnowledgeBigginsDB or defaults
    button:ClearAllPoints()
    button:SetPoint(db.point or "CENTER", UIParent, db.point or "CENTER", db.xOfs or 0, db.yOfs or -140)
    button:SetScale(db.scale or 1.0)
end

function KnowledgeBiggins:ResetPosition()
    if InCombatLockdown() then
        PrintMsg("|cFFFF5555Cannot reset button position during combat lockdown.|r")
        return
    end
    local db = KnowledgeBigginsDB or defaults
    db.point = "CENTER"
    db.xOfs = 0
    db.yOfs = -140
    db.scale = 1.0
    ApplyPosition()
    UpdateKnowledgeButton()
    PrintMsg("Button position reset to default.")
end

-- ==============================================================================
-- 4. BLIZZARD CANVAS SETTINGS INTEGRATION
-- ==============================================================================

local optionsPanel = nil

local function RegisterSettingsUI()
    local panel = CreateFrame("Frame", "KnowledgeBigginsOptionsPanel", UIParent)
    panel.name = "Knowledge"
    panel:Hide()
    optionsPanel = panel

    local title = panel:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
    title:SetPoint("TOPLEFT", 16, -16)
    title:SetText("|cFFFFD100Knowledge Biggins|r")

    -- Suite Logo Texture (Top Right)
    local logo = panel:CreateTexture(nil, "ARTWORK")
    logo:SetPoint("TOPRIGHT", -24, -16)
    logo:SetSize(64, 64)
    logo:SetTexture("Interface\\AddOns\\KnowledgeBiggins\\logo.jpg")

    local desc = panel:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
    desc:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -8)
    desc:SetPoint("RIGHT", logo, "LEFT", -20)
    desc:SetJustifyH("LEFT")
    desc:SetWordWrap(true)
    desc:SetText("Zero-maintenance, one-click popup button to study and consume profession knowledge directly from your bags.")

    -- Top-Right Defaults Button
    local btnDefaults = CreateFrame("Button", nil, panel, "UIPanelButtonTemplate")
    btnDefaults:SetPoint("TOPRIGHT", logo, "BOTTOMRIGHT", 0, -8)
    btnDefaults:SetSize(110, 22)
    btnDefaults:SetText("Defaults")
    btnDefaults:SetScript("OnClick", function()
        KnowledgeBigginsDB = CopyTable(defaults)
        KnowledgeBiggins:ResetPosition()
        if panel.RefreshControls then
            panel.RefreshControls()
        end
        UpdateKnowledgeButton()
        PrintMsg("Settings reset to defaults.")
    end)
    btnDefaults:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:SetText("Restore default settings for Knowledge Biggins.", 1, 1, 1, true)
        GameTooltip:Show()
    end)
    btnDefaults:SetScript("OnLeave", function()
        GameTooltip:Hide()
    end)

    -- Helper for Checkboxes
    local function CreateSettingCheckbox(key, label, tooltip, anchorPoint, relativeTo, relPoint, x, y, callback)
        local cb = CreateFrame("CheckButton", nil, panel, "InterfaceOptionsCheckButtonTemplate")
        cb:SetPoint(anchorPoint, relativeTo, relPoint, x, y)
        cb.Text:SetText(label)
        cb.Text:SetFontObject("GameFontHighlight")
        cb.tooltipText = tooltip
        local currentVal = (KnowledgeBigginsDB and KnowledgeBigginsDB[key] ~= nil) and KnowledgeBigginsDB[key] or defaults[key]
        cb:SetChecked(currentVal)
        cb:SetScript("OnClick", function(self)
            if not KnowledgeBigginsDB then KnowledgeBigginsDB = {} end
            KnowledgeBigginsDB[key] = self:GetChecked()
            if callback then callback(self:GetChecked()) end
            UpdateKnowledgeButton()
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

    -- Checkbox 1: Always Show Button
    local cbAlwaysShow = CreateSettingCheckbox("alwaysShow", "Always Show Button", "Keep the button visible on screen even when you have no knowledge items in your bags.", "TOPLEFT", desc, "BOTTOMLEFT", 0, -18, function(val)
        local status = val and "|cFF00FF00Enabled|r" or "|cFFFF0000Disabled|r"
        PrintMsg("Always Show Button is now " .. status .. ".")
    end)

    -- Checkbox 2: Lock Frame Position
    local cbLocked = CreateSettingCheckbox("locked", "Lock Frame Position", "Prevents moving the button. When unchecked, you can hold Shift and drag the button.", "TOPLEFT", cbAlwaysShow, "BOTTOMLEFT", 0, -8, function(val)
        local status = val and "|cFFFF0000Locked|r" or "|cFF00FF00Unlocked|r"
        PrintMsg("Button position is now " .. status .. ".")
    end)

    -- Reset Position Button
    local resetBtn = CreateFrame("Button", nil, panel, "UIPanelButtonTemplate")
    resetBtn:SetPoint("TOPLEFT", cbLocked, "BOTTOMLEFT", 0, -16)
    resetBtn:SetSize(130, 26)
    resetBtn:SetText("Reset Position")
    resetBtn:SetScript("OnClick", function()
        KnowledgeBiggins:ResetPosition()
    end)

    -- Help Info
    local helpText = panel:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
    helpText:SetPoint("TOPLEFT", resetBtn, "BOTTOMLEFT", 0, -16)
    helpText:SetText("|cFFFFD100Positioning:|r When unlocked, hold |cFF00FF00Shift|r and drag the button with Left-Click to place it anywhere.\nRegular Left-Click always consumes knowledge items directly from your bags.")

    -- Slash Command Help Note
    local helpNote = panel:CreateFontString(nil, "ARTWORK", "GameFontDisableSmall")
    helpNote:SetPoint("TOPLEFT", helpText, "BOTTOMLEFT", 0, -14)
    helpNote:SetText("Slash commands: /knowledgeb (Type /knowledgeb ? for available commands)")

    function panel.RefreshControls()
        local db = KnowledgeBigginsDB or defaults
        if cbAlwaysShow then cbAlwaysShow:SetChecked(db.alwaysShow or false) end
        if cbLocked then cbLocked:SetChecked(db.locked or false) end
    end

    panel:SetScript("OnShow", function()
        panel.RefreshControls()
    end)

    if LibBigginsSuite and LibBigginsSuite.RegisterSubcategory then
        KnowledgeBiggins.categoryID = LibBigginsSuite:RegisterSubcategory("KnowledgeBiggins", panel, "Knowledge")
    elseif Settings and Settings.RegisterCanvasLayoutCategory then
        local category = Settings.RegisterCanvasLayoutCategory(panel, "Knowledge")
        Settings.RegisterAddOnCategory(category)
        KnowledgeBiggins.categoryID = category:GetID()
    end
end

-- ==============================================================================
-- 5. EVENT DISPATCHER
-- ==============================================================================

local eventFrame = CreateFrame("Frame", "KnowledgeBigginsEventFrame")
eventFrame:RegisterEvent("ADDON_LOADED")
eventFrame:RegisterEvent("PLAYER_LOGIN")
eventFrame:RegisterEvent("BAG_UPDATE_DELAYED")
eventFrame:RegisterEvent("PLAYER_REGEN_DISABLED")
eventFrame:RegisterEvent("PLAYER_REGEN_ENABLED")

eventFrame:SetScript("OnEvent", function(self, event, arg1, ...)
    if event == "ADDON_LOADED" and arg1 == addonName then
        if not KnowledgeBigginsDB then
            KnowledgeBigginsDB = CopyTable(defaults)
        else
            for k, v in pairs(defaults) do
                if KnowledgeBigginsDB[k] == nil then
                    KnowledgeBigginsDB[k] = v
                end
            end
        end
    elseif event == "PLAYER_LOGIN" then
        ApplyPosition()
        RegisterSettingsUI()
        UpdateKnowledgeButton()
    elseif event == "BAG_UPDATE_DELAYED" then
        UpdateKnowledgeButton()
    elseif event == "PLAYER_REGEN_DISABLED" then
        -- In combat: lock button state
    elseif event == "PLAYER_REGEN_ENABLED" then
        -- Out of combat: process any pending updates
        if isUpdatePending then
            isUpdatePending = false
            UpdateKnowledgeButton()
        end
    end
end)

-- ==============================================================================
-- 6. SLASH COMMANDS
-- ==============================================================================

function KnowledgeBiggins:OpenSettings()
    if KnowledgeBiggins.categoryID and Settings and Settings.OpenToCategory then
        Settings.OpenToCategory(KnowledgeBiggins.categoryID)
    else
        PrintMsg("Settings panel available in Options -> AddOns -> Biggins AddOns -> Knowledge.")
    end
end

SLASH_KNOWLEDGEBIGGINS1 = "/knowledgeb"
SLASH_KNOWLEDGEBIGGINS2 = "/knowledgebiggins"

SlashCmdList["KNOWLEDGEBIGGINS"] = function(msg)
    local cmd = (msg or ""):trim():lower()

    if cmd == "" or cmd == "options" or cmd == "config" or cmd == "opt" or cmd == "settings" then
        KnowledgeBiggins:OpenSettings()
    elseif cmd == "lock" or cmd == "unlock" then
        local db = KnowledgeBigginsDB or defaults
        db.locked = not db.locked
        local status = db.locked and "|cFFFF0000Locked|r" or "|cFF00FF00Unlocked|r"
        PrintMsg("Button position is now " .. status .. ".")
        UpdateKnowledgeButton()
        if optionsPanel and optionsPanel.RefreshControls then
            optionsPanel.RefreshControls()
        end
    elseif cmd == "show" or cmd == "alwaysshow" then
        local db = KnowledgeBigginsDB or defaults
        db.alwaysShow = not db.alwaysShow
        local status = db.alwaysShow and "|cFF00FF00Enabled|r" or "|cFFFF0000Disabled|r"
        PrintMsg("Always Show Button is now " .. status .. ".")
        UpdateKnowledgeButton()
        if optionsPanel and optionsPanel.RefreshControls then
            optionsPanel.RefreshControls()
        end
    elseif cmd == "reset" then
        KnowledgeBiggins:ResetPosition()
    elseif cmd == "scan" or cmd == "update" then
        UpdateKnowledgeButton()
        PrintMsg("Bag scan completed.")
    elseif cmd == "help" or cmd == "?" then
        PrintMsg("Commands:")
        print("  |cFFFFD100/knowledgeb|r - Open settings panel")
        print("  |cFFFFD100/knowledgeb lock|r - Toggle button lock/unlock")
        print("  |cFFFFD100/knowledgeb show|r - Toggle always showing button")
        print("  |cFFFFD100/knowledgeb reset|r - Reset button position to center")
        print("  |cFFFFD100/knowledgeb scan|r - Force a bag scan for knowledge items")
        print("  |cFFFFD100/knowledgeb help|r or |cFFFFD100/knowledgeb ?|r - Show this list of commands")
        print("  |cFF888888Tip: When unlocked, hold Shift and drag to reposition.|r")
    else
        PrintMsg("Unknown command '|cFFFFD100" .. cmd .. "|r'. Type |cFFFFD100/knowledgeb help|r for available commands.")
    end
end
