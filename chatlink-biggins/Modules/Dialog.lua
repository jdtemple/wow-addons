--[[ ==============================================================================
    ChatLink Biggins - Draggable Blizzard Factory Copy Dialog
    ------------------------------------------------------------------------------
    Classic Blizzard dialog box with position persistence and ESC/Enter key handling.
============================================================================== ]]--

local addonName, addon = ...

-- Cache global functions
local CreateFrame     = CreateFrame
local UIParent        = UIParent
local table_insert    = table.insert
local math_floor      = math.floor
local UISpecialFrames = UISpecialFrames

local copyDialog
local copyEditBox

function addon:CreateCopyDialog()
    if copyDialog then return copyDialog end

    local f = CreateFrame("Frame", "ChatLinkBigginsDialog", UIParent, "BackdropTemplate")
    f:SetSize(420, 118)
    f:SetFrameStrata("DIALOG")
    f:SetToplevel(true)
    f:SetClampedToScreen(true)
    f:SetMovable(true)
    f:EnableMouse(true)
    f:RegisterForDrag("LeftButton")
    f:Hide()

    -- Register with UISpecialFrames so pressing ESC closes the dialog
    table_insert(UISpecialFrames, "ChatLinkBigginsDialog")

    -- Authentic Blizzard Factory Dialog Styling
    f:SetBackdrop({
        bgFile   = "Interface\\DialogFrame\\UI-DialogBox-Background-Dark",
        edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
        tile     = true,
        tileSize = 32,
        edgeSize = 24,
        insets   = { left = 6, right = 6, top = 6, bottom = 6 },
    })

    -- Drag Handlers (Save position across sessions)
    f:SetScript("OnDragStart", function(self)
        self:StartMoving()
    end)

    f:SetScript("OnDragStop", function(self)
        self:StopMovingOrSizing()
        local point, _, relPoint, x, y = self:GetPoint()
        local db = ChatLinkBigginsDB
        if db then
            db.posPoint = point or "CENTER"
            db.posRelPoint = relPoint or "CENTER"
            db.posX = math_floor((x or 0) + 0.5)
            db.posY = math_floor((y or 100) + 0.5)
        end
    end)

    -- Title / Instruction Header
    local title = f:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    title:SetPoint("TOP", 0, -14)
    title:SetText("Copy URL (|cFFFFD100Ctrl+C|r):")

    -- EditBox Container Inset
    local editContainer = CreateFrame("Frame", nil, f, "BackdropTemplate")
    editContainer:SetPoint("TOPLEFT", 18, -38)
    editContainer:SetPoint("TOPRIGHT", -18, -38)
    editContainer:SetHeight(28)
    editContainer:SetBackdrop({
        bgFile   = "Interface\\ChatFrame\\ChatFrameBackground",
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        tile     = true,
        tileSize = 16,
        edgeSize = 12,
        insets   = { left = 3, right = 3, top = 3, bottom = 3 },
    })
    editContainer:SetBackdropColor(0.05, 0.05, 0.05, 0.95)
    editContainer:SetBackdropBorderColor(0.6, 0.6, 0.6, 0.8)

    local eb = CreateFrame("EditBox", nil, editContainer)
    eb:SetPoint("LEFT", 8, 0)
    eb:SetPoint("RIGHT", -8, 0)
    eb:SetHeight(20)
    eb:SetFontObject("ChatFontNormal")
    eb:SetAutoFocus(false)

    eb:SetScript("OnEscapePressed", function()
        f:Hide()
    end)
    eb:SetScript("OnEnterPressed", function()
        f:Hide()
    end)
    eb:SetScript("OnEditFocusLost", function(self)
        self:HighlightText(0, 0)
    end)

    -- Close Button (Classic Blizzard Red)
    local btnClose = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
    btnClose:SetPoint("BOTTOM", 0, 14)
    btnClose:SetSize(90, 22)
    btnClose:SetText("Close")
    btnClose:SetScript("OnClick", function()
        f:Hide()
    end)

    copyDialog = f
    copyEditBox = eb
    return f
end

function addon:ShowCopyDialog(url)
    local f = addon:CreateCopyDialog()
    f:ClearAllPoints()
    local db = ChatLinkBigginsDB or addon.defaults
    if db and db.posPoint then
        f:SetPoint(db.posPoint, UIParent, db.posRelPoint, db.posX, db.posY)
    else
        f:SetPoint("CENTER", UIParent, "CENTER", 0, 100)
    end

    copyEditBox:SetText(url or "")
    f:Show()
    copyEditBox:SetFocus()
    copyEditBox:HighlightText()
end

function addon:ResetDialogPosition()
    local db = ChatLinkBigginsDB
    if db then
        db.posPoint = "CENTER"
        db.posRelPoint = "CENTER"
        db.posX = 0
        db.posY = 100
    end
    if copyDialog then
        copyDialog:ClearAllPoints()
        copyDialog:SetPoint("CENTER", UIParent, "CENTER", 0, 100)
    end
end
