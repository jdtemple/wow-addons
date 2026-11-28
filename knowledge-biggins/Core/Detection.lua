--[[ ==============================================================================
    Knowledge Biggins - Detection Engine
    ------------------------------------------------------------------------------
    Universal profession knowledge and skill item detection via dynamic tooltip line
    scanning and instant block list exclusion.
============================================================================== ]]--

local addonName, addon = ...

-- Cache global functions
local ipairs                   = ipairs
local type                     = type
local math_max                 = math.max
local table_insert             = table.insert

local C_Container              = C_Container
local C_TooltipInfo            = C_TooltipInfo
local C_Item                   = C_Item
local TooltipUtil              = TooltipUtil

local NUM_TOTAL_EQUIPPED_BAG_SLOTS = NUM_TOTAL_EQUIPPED_BAG_SLOTS

addon.knowledgeItemCache = {}

function addon:IsDefaultKnowledgeItem(bag, slot, itemID, itemLink)
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

function addon:IsKnowledgeItem(bag, slot, itemID, itemLink)
    if not itemID then return false end

    local db = KnowledgeBigginsDB or addon.defaults

    -- 1. Blacklist / Block List Check (Highest Priority - instant discard)
    if db.blacklist and db.blacklist[itemID] then
        return false
    end

    -- 2. Cache Check (Instant hit for confirmed knowledge items)
    if addon.knowledgeItemCache[itemID] then
        return true
    end

    -- 3. Dynamic Tooltip Evaluation (Do NOT cache false so asynchronous loads are never poisoned)
    if addon:IsDefaultKnowledgeItem(bag, slot, itemID, itemLink) then
        addon.knowledgeItemCache[itemID] = true
        return true
    end

    return false
end

function addon:ScanBagsForKnowledge()
    local found = {}
    if not C_Container or not C_Container.GetContainerNumSlots then
        return found
    end

    local maxBag = math_max(5, NUM_TOTAL_EQUIPPED_BAG_SLOTS or 5)
    for bag = 0, maxBag do
        local numSlots = C_Container.GetContainerNumSlots(bag) or 0
        for slot = 1, numSlots do
            local info = C_Container.GetContainerItemInfo(bag, slot)
            if info and info.itemID then
                if addon:IsKnowledgeItem(bag, slot, info.itemID, info.hyperlink) then
                    table_insert(found, {
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
