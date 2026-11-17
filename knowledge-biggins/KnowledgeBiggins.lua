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
    whitelist = {},
    blacklist = {},
}

local KnowledgeBiggins = {}
_G["KnowledgeBiggins"] = KnowledgeBiggins
KnowledgeBiggins.version = "1.1.1"

-- Native Blizzard Keybinding strings
_G["BINDING_HEADER_KNOWLEDGEBIGGINS_HEADER"] = "Knowledge Biggins"
_G["BINDING_CATEGORY_KNOWLEDGEBIGGINS"] = "Knowledge Biggins"
_G["BINDING_NAME_CLICK KnowledgeBigginsButton:LeftButton"] = "Study Knowledge"

local isUpdatePending = false
local knowledgeItemCache = {}
local currentLootedItem = nil
local optionsPanel = nil
local UpdateKnowledgeButton = nil

local function PrintMsg(msg)
    print("|cFFFFD100Knowledge Biggins:|r " .. msg)
end

-- ==============================================================================
-- 1. UNIVERSAL KNOWLEDGE DETECTION ENGINE
-- ==============================================================================

local function HasItemUseEffect(itemID, itemLink)
    if not itemID then return false end
    if C_Item and C_Item.GetItemSpell and C_Item.GetItemSpell(itemID) then
        return true
    end
    if C_TooltipInfo then
        local tooltipData
        if itemLink then
            tooltipData = C_TooltipInfo.GetHyperlink(itemLink)
        else
            tooltipData = C_TooltipInfo.GetItemByID(itemID)
        end
        if tooltipData and tooltipData.lines then
            if TooltipUtil and TooltipUtil.SurfaceArgs then
                TooltipUtil.SurfaceArgs(tooltipData)
            end
            local usePrefix = ITEM_SPELL_TRIGGER_ONUSE or "Use:"
            for _, line in ipairs(tooltipData.lines) do
                local text = line.leftText
                if not text and line.args then
                    for _, arg in ipairs(line.args) do
                        if arg and arg.stringVal and type(arg.stringVal) == "string" and arg.stringVal ~= "" then
                            text = arg.stringVal
                            break
                        end
                    end
                end
                if text and type(text) == "string" then
                    if text:find("^" .. usePrefix) or text:find("^Use:") then
                        return true
                    end
                end
            end
        end
    end
    return false
end

local function IsDefaultKnowledgeItem(bag, slot, itemID, itemLink)
    if not itemID then return false end

    -- Check if item data is cached by client; request if missing
    if C_Item and C_Item.IsItemDataCachedByID and not C_Item.IsItemDataCachedByID(itemID) then
        if C_Item.RequestLoadItemDataByID then
            C_Item.RequestLoadItemDataByID(itemID)
        end
    end

    if not C_TooltipInfo then return false end

    local data = nil
    if bag and slot and C_TooltipInfo.GetBagItem then
        data = C_TooltipInfo.GetBagItem(bag, slot)
    end
    if (not data or not data.lines or #data.lines == 0) and itemLink and C_TooltipInfo.GetHyperlink then
        data = C_TooltipInfo.GetHyperlink(itemLink)
    end
    if (not data or not data.lines or #data.lines == 0) and C_TooltipInfo.GetItemByID then
        data = C_TooltipInfo.GetItemByID(itemID)
    end

    if not data or not data.lines or #data.lines == 0 then
        return false
    end

    if TooltipUtil and TooltipUtil.SurfaceArgs then
        TooltipUtil.SurfaceArgs(data)
    end

    for _, line in ipairs(data.lines) do
        local text = line.leftText
        if not text and line.args then
            for _, arg in ipairs(line.args) do
                if arg and arg.stringVal and type(arg.stringVal) == "string" and arg.stringVal ~= "" then
                    text = arg.stringVal
                    break
                end
            end
        end

        if text and type(text) == "string" then
            local lower = text:lower()
            -- Match standard Blizzard profession knowledge and skill patterns (case-insensitive)
            if lower:find("study to")
                or lower:find("increase.-knowledge")
                or lower:find("grant.-knowledge")
                or lower:find("gain.-knowledge")
                or lower:find("increase your .- skill") then
                return true
            end
        end
    end

    return false
end

local function IsKnowledgeItem(bag, slot, itemID, itemLink)
    if not itemID then return false end

    local db = KnowledgeBigginsDB or defaults

    -- 1. Blacklist / Block List Check (Highest Priority - instant discard)
    if db.blacklist and db.blacklist[itemID] then
        return false
    end

    -- 2. Whitelist / Allow List Check (User curated - accept if usable)
    if db.whitelist and db.whitelist[itemID] then
        if HasItemUseEffect(itemID, itemLink) then
            return true
        end
        return false
    end

    -- 3. Cache Check (Instant hit for confirmed knowledge items)
    if knowledgeItemCache[itemID] then
        return true
    end

    -- 4. Dynamic Tooltip Evaluation (Do NOT cache false so asynchronous loads are never poisoned)
    if IsDefaultKnowledgeItem(bag, slot, itemID, itemLink) then
        knowledgeItemCache[itemID] = true
        return true
    end

    return false
end

local function ScanBagsForKnowledge()
    local found = {}
    if not C_Container or not C_Container.GetContainerNumSlots then
        return found
    end

    local maxBag = math.max(5, NUM_TOTAL_EQUIPPED_BAG_SLOTS or 5)
    for bag = 0, maxBag do
        local numSlots = C_Container.GetContainerNumSlots(bag) or 0
        for slot = 1, numSlots do
            local info = C_Container.GetContainerItemInfo(bag, slot)
            if info and info.itemID then
                if IsKnowledgeItem(bag, slot, info.itemID, info.hyperlink) then
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
button:RegisterForClicks("LeftButtonDown", "LeftButtonUp", "RightButtonUp")
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

-- Stack Count FontString (Matches native Blizzard ActionButton NumberFontNormal)
button.Count = button:CreateFontString(nil, "OVERLAY", "NumberFontNormal")
button.Count:SetPoint("BOTTOMRIGHT", button, "BOTTOMRIGHT", -2, 2)
button.Count:SetJustifyH("RIGHT")

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

-- Allow list helper with Use: action validation
local function AddItemToWhitelist(itemID, itemLink, deferUpdate)
    if not itemID then return false end

    if not HasItemUseEffect(itemID, itemLink) then
        PlaySound(SOUNDKIT.IG_MAINMENU_CLOSE)
        PrintMsg("Cannot allow " .. (itemLink or ("item " .. itemID)) .. " - item has no Use action.")
        return false
    end

    local db = KnowledgeBigginsDB or defaults
    local isDefault = IsDefaultKnowledgeItem(nil, nil, itemID, itemLink)

    if isDefault then
        -- Check if it was blocked; dragging/allowing it should unblock it
        if db.blacklist and db.blacklist[itemID] then
            db.blacklist[itemID] = nil
            if db.whitelist then db.whitelist[itemID] = nil end
            knowledgeItemCache[itemID] = true
            PlaySound(SOUNDKIT.IG_BACKPACK_COIN_OK)
            PrintMsg("Unblocked " .. (itemLink or ("item " .. itemID)) .. " (automatically detected by default).")
            if not deferUpdate and UpdateKnowledgeButton then
                UpdateKnowledgeButton()
            end
            if optionsPanel and optionsPanel.RefreshTrays then
                optionsPanel.RefreshTrays()
            end
            return true
        else
            PlaySound(SOUNDKIT.IG_MAINMENU_CLOSE)
            PrintMsg((itemLink or ("item " .. itemID)) .. " is already automatically detected by default.")
            return false
        end
    end

    db.whitelist = db.whitelist or {}
    if not db.whitelist[itemID] then
        db.whitelist[itemID] = true
        if db.blacklist then db.blacklist[itemID] = nil end
        knowledgeItemCache[itemID] = true
        PlaySound(SOUNDKIT.IG_BACKPACK_COIN_OK)
        PrintMsg("Added " .. (itemLink or ("item " .. itemID)) .. " to custom allow list.")
        if not deferUpdate and UpdateKnowledgeButton then
            UpdateKnowledgeButton()
        end
        if optionsPanel and optionsPanel.RefreshTrays then
            optionsPanel.RefreshTrays()
        end
        return true
    else
        PrintMsg((itemLink or ("Item " .. itemID)) .. " is already on custom allow list.")
        return false
    end
end

-- Drag and drop item onto button to allow
button:SetScript("OnReceiveDrag", function(self)
    if InCombatLockdown() then return end
    local cursorType, itemID, itemLink = GetCursorInfo()
    if cursorType == "item" and itemID then
        ClearCursor()
        AddItemToWhitelist(itemID, itemLink, false)
    end
end)

-- Intercept drops via click or Alt + Right-Click to block
button:SetScript("PreClick", function(self, btn, down)
    if InCombatLockdown() then return end

    -- Check if cursor is dropping an item via click
    local cursorType, itemID, itemLink = GetCursorInfo()
    if cursorType == "item" and itemID then
        -- CRITICAL: Instantly disarm the secure button so this click CANNOT consume the dropped or queued item
        self.droppingItem = true
        self:SetAttribute("type", nil)
        self:SetAttribute("type1", nil)
        self:SetAttribute("type2", nil)
        self:SetAttribute("macrotext", nil)
        self:SetAttribute("macrotext1", nil)
        self:SetAttribute("macrotext2", nil)
        ClearCursor()
        AddItemToWhitelist(itemID, itemLink, true) -- defer UpdateKnowledgeButton until PostClick
        return
    end

    -- Alt + Right-Click to block current item from showing
    if btn == "RightButton" and IsAltKeyDown() then
        -- Disarm attributes so right-click cannot trigger secure action
        self.droppingItem = true
        self:SetAttribute("type", nil)
        self:SetAttribute("type1", nil)
        self:SetAttribute("type2", nil)
        self:SetAttribute("macrotext", nil)
        self:SetAttribute("macrotext1", nil)
        self:SetAttribute("macrotext2", nil)

        -- Only execute the block/dismiss mutation on mouse button release (not down) to prevent firing twice per click
        if not down and currentLootedItem then
            local targetItemID = currentLootedItem.itemID
            local targetLink = currentLootedItem.link
            local db = KnowledgeBigginsDB or defaults
            local wasAllowed = db.whitelist and db.whitelist[targetItemID]
            if wasAllowed then
                db.whitelist[targetItemID] = nil
            end

            -- Test if item naturally matches default knowledge criteria
            local isDefaultKnowledge = IsDefaultKnowledgeItem(currentLootedItem.bag, currentLootedItem.slot, targetItemID)

            PlaySound(SOUNDKIT.IG_MAINMENU_CLOSE)

            if isDefaultKnowledge then
                -- Naturally matches default criteria: must add to block list so dynamic scanner won't pick it up again
                db.blacklist = db.blacklist or {}
                db.blacklist[targetItemID] = true
                knowledgeItemCache[targetItemID] = false
                PrintMsg("Added " .. (targetLink or ("item " .. targetItemID)) .. " to block list.")
            else
                -- Custom allowed item: removing from allow list is sufficient to prevent it from ever showing
                knowledgeItemCache[targetItemID] = nil
                PrintMsg("Removed " .. (targetLink or ("item " .. targetItemID)) .. " from custom allow list.")
            end

            if optionsPanel and optionsPanel.RefreshTrays then
                optionsPanel.RefreshTrays()
            end
        end
        return
    end
end)

-- PostClick: safely re-arm the button after the click event has completely resolved
button:SetScript("PostClick", function(self, btn)
    if InCombatLockdown() then return end
    if self.droppingItem then
        self.droppingItem = nil
        if UpdateKnowledgeButton then
            UpdateKnowledgeButton()
        end
    end
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
        if db.whitelist and db.whitelist[currentLootedItem.itemID] and not IsDefaultKnowledgeItem(currentLootedItem.bag, currentLootedItem.slot, currentLootedItem.itemID) then
            GameTooltip:AddLine("|cFFFF5555Alt + Right-Click:|r Remove from Allow List")
        else
            GameTooltip:AddLine("|cFFFF5555Alt + Right-Click:|r Block Item from Showing")
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
        GameTooltip:AddLine("|cFF888888Tip: Drop any click-to-use item here to allow it.|r")
    end
    GameTooltip:Show()
end)

button:SetScript("OnLeave", function(self)
    GameTooltip:Hide()
end)

-- Update the popup button with current unstudied items
UpdateKnowledgeButton = function()
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
    desc:SetText("Automatically detects and queues profession knowledge and skill items out of the box with zero setup.\n\nThe Allow List and Block List below let you tailor behavior for your character: any click-to-use item can be added by dropping it onto the floating button, and unwanted items can be blocked with Alt + Right-Click.")

    -- Top-Right Defaults Button
    local btnDefaults = CreateFrame("Button", nil, panel, "UIPanelButtonTemplate")
    btnDefaults:SetPoint("TOPRIGHT", logo, "BOTTOMRIGHT", 0, -8)
    btnDefaults:SetSize(110, 22)
    btnDefaults:SetText("Defaults")
    btnDefaults:SetScript("OnClick", function()
        KnowledgeBigginsDB = CopyTable(defaults)
        knowledgeItemCache = {}
        KnowledgeBiggins:ResetPosition()
        if panel.RefreshControls then
            panel.RefreshControls()
        end
        if panel.RefreshTrays then
            panel.RefreshTrays()
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
    resetBtn:SetPoint("TOPLEFT", cbLocked, "BOTTOMLEFT", 0, -14)
    resetBtn:SetSize(130, 24)
    resetBtn:SetText("Reset Position")
    resetBtn:SetScript("OnClick", function()
        KnowledgeBiggins:ResetPosition()
    end)

    -- --------------------------------------------------------------------------
    -- Custom Allow List Tray
    -- --------------------------------------------------------------------------
    local wlHeader = panel:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    wlHeader:SetPoint("TOPLEFT", resetBtn, "BOTTOMLEFT", 0, -16)
    wlHeader:SetText("Custom Allow List (Drop any click-to-use item onto floating button to add):")

    local btnResetWl = CreateFrame("Button", nil, panel, "UIPanelButtonTemplate")
    btnResetWl:SetPoint("TOPRIGHT", -24, 0)
    btnResetWl:SetPoint("TOP", wlHeader, "TOP", 0, 4)
    btnResetWl:SetSize(115, 20)
    btnResetWl:SetText("Reset Allow List")

    local wlEmpty = panel:CreateFontString(nil, "ARTWORK", "GameFontDisableSmall")
    wlEmpty:SetPoint("TOPLEFT", wlHeader, "BOTTOMLEFT", 0, -6)
    wlEmpty:SetText("(No custom items in allow list)")

    local wlTiles = {}
    for i = 1, 12 do
        local tile = CreateFrame("Button", nil, panel)
        tile:SetSize(30, 30)
        tile:RegisterForClicks("LeftButtonUp", "RightButtonUp")
        if i == 1 then
            tile:SetPoint("TOPLEFT", wlHeader, "BOTTOMLEFT", 0, -6)
        else
            tile:SetPoint("LEFT", wlTiles[i - 1], "RIGHT", 4, 0)
        end

        local icon = tile:CreateTexture(nil, "ARTWORK")
        icon:SetPoint("TOPLEFT", 2, -2)
        icon:SetPoint("BOTTOMRIGHT", -2, 2)
        tile.icon = icon

        local border = tile:CreateTexture(nil, "OVERLAY")
        border:SetAllPoints(tile)
        if C_Texture and C_Texture.GetAtlasInfo and C_Texture.GetAtlasInfo("UI-HUD-ActionBar-IconFrame") then
            border:SetAtlas("UI-HUD-ActionBar-IconFrame")
        else
            border:SetTexture("Interface\\Buttons\\UI-Quickslot2")
        end

        tile:SetHighlightTexture("Interface\\Buttons\\ButtonHilight-Square", "ADD")

        tile:SetScript("OnEnter", function(self)
            if self.itemID then
                GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
                GameTooltip:SetItemByID(self.itemID)
                GameTooltip:AddLine(" ")
                GameTooltip:AddLine("|cFFFF5555Right-Click to remove from allow list|r")
                GameTooltip:Show()
            end
        end)
        tile:SetScript("OnLeave", function() GameTooltip:Hide() end)
        tile:SetScript("OnClick", function(self)
            if self.itemID then
                local db = KnowledgeBigginsDB or defaults
                local id = self.itemID
                if db.whitelist then db.whitelist[id] = nil end
                knowledgeItemCache[id] = nil
                PlaySound(SOUNDKIT.IG_MAINMENU_CLOSE)
                local displayName = self.itemLink
                if not displayName then
                    local _, link = C_Item.GetItemInfo(id)
                    displayName = link or (C_Item.GetItemLinkByItemID and C_Item.GetItemLinkByItemID(id)) or ("item " .. id)
                end
                PrintMsg("Removed " .. displayName .. " from custom allow list.")
                UpdateKnowledgeButton()
                if panel.RefreshTrays then panel.RefreshTrays() end
                GameTooltip:Hide()
            end
        end)
        tile:Hide()
        wlTiles[i] = tile
    end

    btnResetWl:SetScript("OnClick", function()
        local db = KnowledgeBigginsDB or defaults
        db.whitelist = {}
        knowledgeItemCache = {}
        PlaySound(SOUNDKIT.IG_MAINMENU_CLOSE)
        PrintMsg("Custom allow list cleared.")
        UpdateKnowledgeButton()
        if panel.RefreshTrays then panel.RefreshTrays() end
    end)
    btnResetWl:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:SetText("Clear all items from the custom allow list.", 1, 1, 1, true)
        GameTooltip:Show()
    end)
    btnResetWl:SetScript("OnLeave", function() GameTooltip:Hide() end)

    -- --------------------------------------------------------------------------
    -- Block List Tray
    -- --------------------------------------------------------------------------
    local blHeader = panel:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    blHeader:SetPoint("TOPLEFT", wlHeader, "BOTTOMLEFT", 0, -42)
    blHeader:SetText("Block List (Alt + Right-Click floating button to block/ignore):")

    local btnResetBl = CreateFrame("Button", nil, panel, "UIPanelButtonTemplate")
    btnResetBl:SetPoint("TOPRIGHT", -24, 0)
    btnResetBl:SetPoint("TOP", blHeader, "TOP", 0, 4)
    btnResetBl:SetSize(115, 20)
    btnResetBl:SetText("Reset Block List")

    local blEmpty = panel:CreateFontString(nil, "ARTWORK", "GameFontDisableSmall")
    blEmpty:SetPoint("TOPLEFT", blHeader, "BOTTOMLEFT", 0, -6)
    blEmpty:SetText("(No items blocked)")

    local blTiles = {}
    for i = 1, 12 do
        local tile = CreateFrame("Button", nil, panel)
        tile:SetSize(30, 30)
        tile:RegisterForClicks("LeftButtonUp", "RightButtonUp")
        if i == 1 then
            tile:SetPoint("TOPLEFT", blHeader, "BOTTOMLEFT", 0, -6)
        else
            tile:SetPoint("LEFT", blTiles[i - 1], "RIGHT", 4, 0)
        end

        local icon = tile:CreateTexture(nil, "ARTWORK")
        icon:SetPoint("TOPLEFT", 2, -2)
        icon:SetPoint("BOTTOMRIGHT", -2, 2)
        tile.icon = icon

        local border = tile:CreateTexture(nil, "OVERLAY")
        border:SetAllPoints(tile)
        if C_Texture and C_Texture.GetAtlasInfo and C_Texture.GetAtlasInfo("UI-HUD-ActionBar-IconFrame") then
            border:SetAtlas("UI-HUD-ActionBar-IconFrame")
        else
            border:SetTexture("Interface\\Buttons\\UI-Quickslot2")
        end

        tile:SetHighlightTexture("Interface\\Buttons\\ButtonHilight-Square", "ADD")

        tile:SetScript("OnEnter", function(self)
            if self.itemID then
                GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
                GameTooltip:SetItemByID(self.itemID)
                GameTooltip:AddLine(" ")
                GameTooltip:AddLine("|cFF00FF00Right-Click to unblock (restore)|r")
                GameTooltip:Show()
            end
        end)
        tile:SetScript("OnLeave", function() GameTooltip:Hide() end)
        tile:SetScript("OnClick", function(self)
            if self.itemID then
                local db = KnowledgeBigginsDB or defaults
                local id = self.itemID
                if db.blacklist then db.blacklist[id] = nil end
                knowledgeItemCache[id] = nil
                PlaySound(SOUNDKIT.IG_MAINMENU_CLOSE)
                local displayName = self.itemLink
                if not displayName then
                    local _, link = C_Item.GetItemInfo(id)
                    displayName = link or (C_Item.GetItemLinkByItemID and C_Item.GetItemLinkByItemID(id)) or ("item " .. id)
                end
                PrintMsg("Unblocked " .. displayName .. " from block list.")
                UpdateKnowledgeButton()
                if panel.RefreshTrays then panel.RefreshTrays() end
                GameTooltip:Hide()
            end
        end)
        tile:Hide()
        blTiles[i] = tile
    end

    btnResetBl:SetScript("OnClick", function()
        local db = KnowledgeBigginsDB or defaults
        db.blacklist = {}
        knowledgeItemCache = {}
        PlaySound(SOUNDKIT.IG_MAINMENU_CLOSE)
        PrintMsg("Block list cleared.")
        UpdateKnowledgeButton()
        if panel.RefreshTrays then panel.RefreshTrays() end
    end)
    btnResetBl:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:SetText("Clear all items from the block list.", 1, 1, 1, true)
        GameTooltip:Show()
    end)
    btnResetBl:SetScript("OnLeave", function() GameTooltip:Hide() end)

    -- Help Info
    local helpText = panel:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
    helpText:SetPoint("TOPLEFT", blHeader, "BOTTOMLEFT", 0, -42)
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

    function panel.RefreshTrays()
        local db = KnowledgeBigginsDB or defaults

        -- Refresh Whitelist Tray
        local wlItems = {}
        if db.whitelist then
            for id, enabled in pairs(db.whitelist) do
                if enabled then table.insert(wlItems, id) end
            end
        end
        table.sort(wlItems)

        if #wlItems == 0 then
            wlEmpty:Show()
            for i = 1, 12 do
                wlTiles[i].itemID = nil
                wlTiles[i].itemLink = nil
                wlTiles[i]:Hide()
            end
        else
            wlEmpty:Hide()
            for i = 1, 12 do
                if i <= #wlItems then
                    local id = wlItems[i]
                    wlTiles[i].itemID = id
                    if C_Item and C_Item.RequestLoadItemDataByID then
                        C_Item.RequestLoadItemDataByID(id)
                    end
                    local _, itemLink = C_Item.GetItemInfo(id)
                    wlTiles[i].itemLink = itemLink or (C_Item.GetItemLinkByItemID and C_Item.GetItemLinkByItemID(id))
                    local iconFile = C_Item.GetItemIconByID(id) or 134400
                    wlTiles[i].icon:SetTexture(iconFile)
                    wlTiles[i]:Show()
                else
                    wlTiles[i].itemID = nil
                    wlTiles[i].itemLink = nil
                    wlTiles[i]:Hide()
                end
            end
        end

        -- Refresh Blacklist Tray
        local blItems = {}
        if db.blacklist then
            for id, enabled in pairs(db.blacklist) do
                if enabled then table.insert(blItems, id) end
            end
        end
        table.sort(blItems)

        if #blItems == 0 then
            blEmpty:Show()
            for i = 1, 12 do
                blTiles[i].itemID = nil
                blTiles[i].itemLink = nil
                blTiles[i]:Hide()
            end
        else
            blEmpty:Hide()
            for i = 1, 12 do
                if i <= #blItems then
                    local id = blItems[i]
                    blTiles[i].itemID = id
                    if C_Item and C_Item.RequestLoadItemDataByID then
                        C_Item.RequestLoadItemDataByID(id)
                    end
                    local _, itemLink = C_Item.GetItemInfo(id)
                    blTiles[i].itemLink = itemLink or (C_Item.GetItemLinkByItemID and C_Item.GetItemLinkByItemID(id))
                    local iconFile = C_Item.GetItemIconByID(id) or 134400
                    blTiles[i].icon:SetTexture(iconFile)
                    blTiles[i]:Show()
                else
                    blTiles[i].itemID = nil
                    blTiles[i].itemLink = nil
                    blTiles[i]:Hide()
                end
            end
        end
    end

    panel:SetScript("OnShow", function()
        panel.RefreshControls()
        panel.RefreshTrays()
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
eventFrame:RegisterEvent("PLAYER_ENTERING_WORLD")
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
                    if type(v) == "table" then
                        KnowledgeBigginsDB[k] = CopyTable(v)
                    else
                        KnowledgeBigginsDB[k] = v
                    end
                end
            end
        end
    elseif event == "PLAYER_LOGIN" then
        ApplyPosition()
        RegisterSettingsUI()
    elseif event == "PLAYER_ENTERING_WORLD" then
        UpdateKnowledgeButton()
        if C_Timer and C_Timer.After then
            C_Timer.After(0.5, function()
                if not InCombatLockdown() and UpdateKnowledgeButton then
                    UpdateKnowledgeButton()
                end
            end)
        end
    elseif event == "BAG_UPDATE_DELAYED" then
        UpdateKnowledgeButton()
        if C_Timer and C_Timer.After then
            C_Timer.After(0.25, function()
                if not InCombatLockdown() and UpdateKnowledgeButton then
                    UpdateKnowledgeButton()
                end
            end)
        end
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
    elseif cmd == "ignore" or cmd == "blacklist" or cmd == "block" then
        if currentLootedItem then
            local targetItemID = currentLootedItem.itemID
            local targetLink = currentLootedItem.link
            local db = KnowledgeBigginsDB or defaults
            local wasAllowed = db.whitelist and db.whitelist[targetItemID]
            if wasAllowed then
                db.whitelist[targetItemID] = nil
            end

            local isDefaultKnowledge = IsDefaultKnowledgeItem(currentLootedItem.bag, currentLootedItem.slot, targetItemID)
            PlaySound(SOUNDKIT.IG_MAINMENU_CLOSE)

            if isDefaultKnowledge then
                db.blacklist = db.blacklist or {}
                db.blacklist[targetItemID] = true
                knowledgeItemCache[targetItemID] = false
                PrintMsg("Added " .. (targetLink or ("item " .. targetItemID)) .. " to block list.")
            else
                knowledgeItemCache[targetItemID] = nil
                PrintMsg("Removed " .. (targetLink or ("item " .. targetItemID)) .. " from custom allow list.")
            end

            UpdateKnowledgeButton()
            if optionsPanel and optionsPanel.RefreshTrays then
                optionsPanel.RefreshTrays()
            end
        else
            PrintMsg("No item currently active to dismiss/block. Hold Alt + Right-Click the button when an item appears.")
        end
    elseif cmd:find("^unignore%s*") or cmd:find("^whitelist%s*") or cmd:find("^allow%s*") then
        local arg = cmd:match("^%S+%s*(.*)$")
        local itemID = tonumber(arg) or (arg and tonumber(arg:match("item:(%d+)")))
        local itemLink = (arg and arg:find("%|Hitem:")) and arg or nil
        if itemID then
            AddItemToWhitelist(itemID, itemLink)
        else
            PrintMsg("Usage: /knowledgeb allow <itemID|itemLink>")
        end
    elseif cmd == "clear" or cmd == "resetlists" then
        local db = KnowledgeBigginsDB or defaults
        db.whitelist = {}
        db.blacklist = {}
        knowledgeItemCache = {}
        PlaySound(SOUNDKIT.IG_MAINMENU_CLOSE)
        PrintMsg("Cleared all custom allow and block list items.")
        UpdateKnowledgeButton()
        if optionsPanel and optionsPanel.RefreshTrays then
            optionsPanel.RefreshTrays()
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
        print("  |cFFFFD100/knowledgeb ignore|r or |cFFFFD100/knowledgeb block|r - Block the currently displayed item")
        print("  |cFFFFD100/knowledgeb allow <id>|r - Manually add item to allow list")
        print("  |cFFFFD100/knowledgeb clear|r - Clear all custom allow and block list items")
        print("  |cFFFFD100/knowledgeb reset|r - Reset button position to center")
        print("  |cFFFFD100/knowledgeb scan|r - Force a bag scan for knowledge items")
        print("  |cFFFFD100/knowledgeb help|r or |cFFFFD100/knowledgeb ?|r - Show this list of commands")
        print("  |cFF888888Shortcuts: Shift+Drag to move | Alt+Right-Click to block item | Drop item to allow|r")
    else
        PrintMsg("Unknown command '|cFFFFD100" .. cmd .. "|r'. Type |cFFFFD100/knowledgeb help|r for available commands.")
    end
end
