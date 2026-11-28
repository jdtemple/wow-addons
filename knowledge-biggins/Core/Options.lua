--[[ ==============================================================================
    Knowledge Biggins - Options Panel (Blizzard Settings Integration)
    ------------------------------------------------------------------------------
    Canvas settings panel providing checkboxes, position controls, and visual
    interactive tray for block-listed items.
============================================================================== ]]--

local addonName, addon = ...

-- Cache global functions
local CreateFrame         = CreateFrame
local GameTooltip         = GameTooltip
local UIParent            = UIParent
local pairs               = pairs
local ipairs              = ipairs
local table_insert        = table.insert
local table_sort          = table.sort
local CopyTable           = CopyTable
local GetCursorInfo       = GetCursorInfo
local ClearCursor         = ClearCursor
local PlaySound           = PlaySound
local SOUNDKIT            = SOUNDKIT
local IsShiftKeyDown      = IsShiftKeyDown

local C_Item              = C_Item
local C_Texture           = C_Texture

function addon:RegisterSettingsUI()
    local panel = CreateFrame("Frame", "KnowledgeBigginsOptionsPanel", UIParent)
    panel.name = "Knowledge"
    panel:Hide()
    addon.optionsPanel = panel

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
    desc:SetText("Automatically detects and queues profession knowledge and skill items out of the box with zero setup.\n\nThe Block List below lets you hide any unwanted items: hold Alt + Right-Click on the floating popup button or drop items directly into the tray below.")

    -- Top-Right Defaults Button
    local btnDefaults = CreateFrame("Button", nil, panel, "UIPanelButtonTemplate")
    btnDefaults:SetPoint("TOPRIGHT", logo, "BOTTOMRIGHT", 0, -8)
    btnDefaults:SetSize(110, 22)
    btnDefaults:SetText("Defaults")
    btnDefaults:SetScript("OnClick", function()
        KnowledgeBigginsDB = CopyTable(addon.defaults)
        addon.knowledgeItemCache = {}
        addon:ResetPosition()
        if panel.RefreshControls then
            panel.RefreshControls()
        end
        if panel.RefreshTrays then
            panel.RefreshTrays()
        end
        addon:UpdateKnowledgeButton()
        addon:PrintMsg("Settings reset to defaults.")
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
        local currentVal = (KnowledgeBigginsDB and KnowledgeBigginsDB[key] ~= nil) and KnowledgeBigginsDB[key] or addon.defaults[key]
        cb:SetChecked(currentVal)
        cb:SetScript("OnClick", function(self)
            if not KnowledgeBigginsDB then KnowledgeBigginsDB = {} end
            KnowledgeBigginsDB[key] = self:GetChecked()
            if callback then callback(self:GetChecked()) end
            addon:UpdateKnowledgeButton()
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

    -- Master Enable Checkbox
    local cbEnable = CreateSettingCheckbox("enabled", "Enable Knowledge Biggins", "Enable or disable automatic profession knowledge detection and the floating button.", "TOPLEFT", desc, "BOTTOMLEFT", 0, -16, function(val)
        local status = val and "|cFF00FF00Enabled|r" or "|cFFFF0000Disabled|r"
        addon:PrintMsg("Knowledge Biggins is now " .. status .. ".")
        addon:UpdateKnowledgeButton()
        if panel.RefreshControls then
            panel.RefreshControls()
        end
    end)

    -- Child Controls (Indented 20px under Master Enable)
    local cbAlwaysShow = CreateSettingCheckbox("alwaysShow", "Always Show Button", "Keep the button visible on screen even when you have no knowledge items in your bags.", "TOPLEFT", cbEnable, "BOTTOMLEFT", 20, -8, function(val)
        local status = val and "|cFF00FF00Enabled|r" or "|cFFFF0000Disabled|r"
        addon:PrintMsg("Always Show Button is now " .. status .. ".")
    end)

    -- Checkbox 2: Lock Frame Position (Indented 20px)
    local cbLocked = CreateSettingCheckbox("locked", "Lock Frame Position", "Prevents moving the button. When unchecked, you can hold Shift and drag the button.", "TOPLEFT", cbAlwaysShow, "BOTTOMLEFT", 0, -8, function(val)
        local status = val and "|cFFFF0000Locked|r" or "|cFF00FF00Unlocked|r"
        addon:PrintMsg("Button position is now " .. status .. ".")
    end)

    -- Reset Position Button (Indented 20px)
    local resetBtn = CreateFrame("Button", nil, panel, "UIPanelButtonTemplate")
    resetBtn:SetPoint("TOPLEFT", cbLocked, "BOTTOMLEFT", 0, -14)
    resetBtn:SetSize(130, 24)
    resetBtn:SetText("Reset Position")
    resetBtn:SetScript("OnClick", function()
        addon:ResetPosition()
    end)

    -- --------------------------------------------------------------------------
    -- Block List Tray
    -- --------------------------------------------------------------------------
    local blHeader = panel:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    blHeader:SetPoint("TOPLEFT", resetBtn, "BOTTOMLEFT", -20, -20)
    blHeader:SetText("Block List (Drop items here or Alt + Right-Click floating button to block):")

    local btnResetBl = CreateFrame("Button", nil, panel, "UIPanelButtonTemplate")
    btnResetBl:SetPoint("TOPRIGHT", -24, 0)
    btnResetBl:SetPoint("TOP", blHeader, "TOP", 0, 4)
    btnResetBl:SetSize(115, 20)
    btnResetBl:SetText("Reset Block List")

    local function TryDropItemOnBlacklist()
        local cursorType, itemID, itemLink = GetCursorInfo()
        if cursorType == "item" and itemID then
            ClearCursor()
            addon:AddItemToBlacklist(itemID, itemLink)
            return true
        end
        return false
    end

    local blDropZone = CreateFrame("Button", nil, panel)
    blDropZone:SetPoint("TOPLEFT", blHeader, "BOTTOMLEFT", 0, -4)
    blDropZone:SetSize(420, 34)
    blDropZone:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    blDropZone:SetScript("OnReceiveDrag", TryDropItemOnBlacklist)
    blDropZone:SetScript("OnClick", function()
        TryDropItemOnBlacklist()
    end)

    local blEmpty = panel:CreateFontString(nil, "ARTWORK", "GameFontDisableSmall")
    blEmpty:SetPoint("TOPLEFT", blHeader, "BOTTOMLEFT", 0, -6)
    blEmpty:SetText("(No items blocked - drag & drop items here to block)")

    local blTiles = {}
    for i = 1, 12 do
        local tile = CreateFrame("Button", nil, panel)
        tile:SetSize(30, 30)
        tile:RegisterForClicks("LeftButtonUp", "RightButtonUp")
        tile:SetFrameLevel(blDropZone:GetFrameLevel() + 2)
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
                GameTooltip:AddLine("|cFFFF5555Right-Click to unblock|r")
                GameTooltip:Show()
            end
        end)
        tile:SetScript("OnLeave", function() GameTooltip:Hide() end)
        tile:SetScript("OnReceiveDrag", TryDropItemOnBlacklist)
        tile:SetScript("OnClick", function(self, btn)
            if TryDropItemOnBlacklist() then return end
            if self.itemID and (btn == "RightButton" or not IsShiftKeyDown()) then
                local db = KnowledgeBigginsDB or addon.defaults
                local id = self.itemID
                if db.blacklist then db.blacklist[id] = nil end
                addon.knowledgeItemCache[id] = nil
                PlaySound(SOUNDKIT.IG_MAINMENU_CLOSE)
                local displayName = self.itemLink
                if not displayName then
                    local _, link = C_Item.GetItemInfo(id)
                    displayName = link or (C_Item.GetItemLinkByItemID and C_Item.GetItemLinkByItemID(id)) or ("item " .. id)
                end
                addon:PrintMsg("Unblocked " .. displayName .. ".")
                addon:UpdateKnowledgeButton()
                if panel.RefreshTrays then panel.RefreshTrays() end
                GameTooltip:Hide()
            end
        end)
        tile:Hide()
        blTiles[i] = tile
    end

    btnResetBl:SetScript("OnClick", function()
        local db = KnowledgeBigginsDB or addon.defaults
        db.blacklist = {}
        addon.knowledgeItemCache = {}
        PlaySound(SOUNDKIT.IG_MAINMENU_CLOSE)
        addon:PrintMsg("Block list cleared.")
        addon:UpdateKnowledgeButton()
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
    helpNote:SetText("Slash commands: |cFFFFD100/knowledgeb|r (Type |cFFFFD100/knowledgeb ?|r for available commands)")

    function panel.RefreshControls()
        local db = KnowledgeBigginsDB or addon.defaults
        local isEnabled = db.enabled ~= false
        if cbEnable then cbEnable:SetChecked(isEnabled) end
        if cbAlwaysShow then
            cbAlwaysShow:SetChecked(db.alwaysShow or false)
            cbAlwaysShow:SetEnabled(isEnabled)
            cbAlwaysShow:SetAlpha(isEnabled and 1.0 or 0.5)
        end
        if cbLocked then
            cbLocked:SetChecked(db.locked or false)
            cbLocked:SetEnabled(isEnabled)
            cbLocked:SetAlpha(isEnabled and 1.0 or 0.5)
        end
        if resetBtn then
            resetBtn:SetEnabled(isEnabled)
            resetBtn:SetAlpha(isEnabled and 1.0 or 0.5)
        end
    end

    function panel.RefreshTrays()
        local db = KnowledgeBigginsDB or addon.defaults

        -- Refresh Blacklist Tray
        local blItems = {}
        if db.blacklist then
            for id, enabled in pairs(db.blacklist) do
                if enabled then table_insert(blItems, id) end
            end
        end
        table_sort(blItems)

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

    -- Register subcategory with LibBigginsSuite
    if LibBigginsSuite and LibBigginsSuite.RegisterSubcategory then
        KnowledgeBiggins.categoryID = LibBigginsSuite:RegisterSubcategory("KnowledgeBiggins", panel, "Knowledge")
    elseif Settings and Settings.RegisterCanvasLayoutCategory then
        local category = Settings.RegisterCanvasLayoutCategory(panel, "Knowledge")
        Settings.RegisterAddOnCategory(category)
        KnowledgeBiggins.categoryID = category:GetID()
    end
end
