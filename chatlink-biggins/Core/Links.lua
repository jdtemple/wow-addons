--[[ ==============================================================================
    ChatLink Biggins - URL Formatting & Chat Event Filter
    ------------------------------------------------------------------------------
    Single-pattern web protocol matching, punctuation stripping, sender GUID
    caching, and zero-taint chat event filtering.
============================================================================== ]]--

local addonName, addon = ...

-- Cache global functions
local type                  = type
local pcall                 = pcall
local string_gsub           = string.gsub
local string_sub            = string.sub
local string_find           = string.find
local string_match          = string.match
local select                = select
local issecretvalue         = issecretvalue
local GetTime               = GetTime
local hooksecurefunc        = hooksecurefunc
local EventRegistry         = EventRegistry
local ChatFrame_AddMessageEventFilter = ChatFrame_AddMessageEventFilter
local ChatFrameUtil         = ChatFrameUtil
local C_EventUtils          = C_EventUtils
local ipairs                = ipairs

-- True only for plain strings the addon is allowed to read (guards Retail secret values)
function addon:IsReadableString(v)
    if type(v) ~= "string" then return false end
    if issecretvalue then
        local ok, secret = pcall(issecretvalue, v)
        if not ok or secret then return false end
    end
    return true
end

local senderCache = {}
local senderCacheCount = 0
local MAX_SENDER_CACHE = 500
addon.senderCache = senderCache

function addon:CacheSenderGUID(name, guid)
    if not name or not guid then return end
    if not senderCache[name] then
        if senderCacheCount >= MAX_SENDER_CACHE then
            senderCache = {}
            senderCacheCount = 0
            addon.senderCache = senderCache
        end
        senderCache[name] = guid
        senderCacheCount = senderCacheCount + 1
    end
    local short = string_match(name, "^([^-]+)")
    if short and short ~= name then
        senderCache[short] = guid
    end
end

function addon:FormatLink(url)
    local db = ChatLinkBigginsDB or addon.defaults
    -- Strip trailing sentence punctuation
    local clean = string_gsub(url, "[%.,;:!%?%)%]%}'\"]+$", "")
    local trailing = string_sub(url, #clean + 1)
    local display = (db and db.showBrackets) and ("[" .. clean .. "]") or clean
    return "|cff00ccff|Haddon:ChatLinkBiggins:URL:" .. clean .. "|h" .. display .. "|h|r" .. trailing
end

local function OnChatMessage(self, event, msg, sender, ...)
    local db = ChatLinkBigginsDB or addon.defaults
    -- Cache sender GUID from chat event payload
    if sender and sender ~= "" then
        for i = 1, select("#", ...) do
            local arg = select(i, ...)
            if type(arg) == "string" and string_sub(arg, 1, 7) == "Player-" then
                addon:CacheSenderGUID(sender, arg)
                break
            end
        end
    end

    if not db or not db.enabled then return false, msg, sender, ... end
    if not addon:IsReadableString(msg) then return false, msg, sender, ... end

    -- Fast 0.001ms exit if no web protocol is present
    if not string_find(msg, "https?://") then
        return false, msg, sender, ...
    end

    -- Re-entrancy guard: avoid re-formatting already formatted links
    if string_find(msg, "|Haddon:ChatLinkBiggins:") then
        return false, msg, sender, ...
    end

    -- Single-pass pattern isolation (strictly terminates at whitespace or pipe)
    local newMsg = string_gsub(msg, "(https?://[^%s|]+)", function(url)
        return addon:FormatLink(url)
    end)
    return false, newMsg, sender, ...
end

local lastClickLink, lastClickTime

local function OnLinkClicked(link, text, button, chatFrame)
    if not addon:IsReadableString(link) then return end
    local now = GetTime and GetTime() or 0
    if link == lastClickLink and now == lastClickTime then return end

    if string_sub(link, 1, 26) == "addon:ChatLinkBiggins:URL:" then
        lastClickLink, lastClickTime = link, now
        local url = string_sub(link, 27)
        if url and url ~= "" then
            addon:ShowCopyDialog(url)
        end
    end
end

-- Hook both SetItemRef and modern EventRegistry
hooksecurefunc("SetItemRef", OnLinkClicked)
if EventRegistry and EventRegistry.RegisterCallback then
    EventRegistry:RegisterCallback("SetItemRef", function(_, link, text, button, chatFrame)
        OnLinkClicked(link, text, button, chatFrame)
    end, addonName)
end

local AddMessageEventFilter = ChatFrame_AddMessageEventFilter
    or (ChatFrameUtil and ChatFrameUtil.AddMessageEventFilter)

local function SafeAddFilter(event, func)
    if C_EventUtils and C_EventUtils.IsEventValid and not C_EventUtils.IsEventValid(event) then return end
    if AddMessageEventFilter then
        AddMessageEventFilter(event, func)
    end
end

local CHAT_CHANNELS = {
    "CHAT_MSG_SAY",
    "CHAT_MSG_YELL",
    "CHAT_MSG_GUILD",
    "CHAT_MSG_OFFICER",
    "CHAT_MSG_PARTY",
    "CHAT_MSG_PARTY_LEADER",
    "CHAT_MSG_RAID",
    "CHAT_MSG_RAID_LEADER",
    "CHAT_MSG_RAID_WARNING",
    "CHAT_MSG_INSTANCE_CHAT",
    "CHAT_MSG_INSTANCE_CHAT_LEADER",
    "CHAT_MSG_WHISPER",
    "CHAT_MSG_WHISPER_INFORM",
    "CHAT_MSG_BN_WHISPER",
    "CHAT_MSG_BN_WHISPER_INFORM",
    "CHAT_MSG_CHANNEL",
    "CHAT_MSG_COMMUNITIES_CHANNEL",
}

for _, eventName in ipairs(CHAT_CHANNELS) do
    SafeAddFilter(eventName, OnChatMessage)
end
