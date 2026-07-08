local ADDON = "AutoShareQuests"

local defaults = {
    auto   = true,
    delay  = 0.0,
    silent = false,
}

local f = CreateFrame("Frame", "AutoShareQuestsFrame")

local queue        = {}
local elapsed      = 0
local sharing      = false
local lastPartySize = 0

local function Print(msg)
    if AutoShareQuestsDB and AutoShareQuestsDB.silent then return end
    DEFAULT_CHAT_FRAME:AddMessage("|cff33ff99AutoShareQuests|r: " .. tostring(msg))
end

local function InGroup()
    return (GetNumPartyMembers() > 0) or (GetNumRaidMembers() > 0)
end

local function BuildQueue()
    wipe(queue)
    local prev = GetQuestLogSelection()
    local numEntries = GetNumQuestLogEntries()
    for i = 1, numEntries do
        local _, _, _, _, isHeader = GetQuestLogTitle(i)
        if not isHeader then
            SelectQuestLogEntry(i)
            if GetQuestLogPushable() then
                table.insert(queue, i)
            end
        end
    end
    SelectQuestLogEntry(prev)
    return #queue
end

local function OnUpdate(self, delta)
    elapsed = elapsed + delta
    local delay = (AutoShareQuestsDB and AutoShareQuestsDB.delay) or 0.6
    if elapsed < delay then return end
    elapsed = 0

    local index = table.remove(queue, 1)
    if not index then
        sharing = false
        self:SetScript("OnUpdate", nil)
        Print("Done sharing quests.")
        return
    end

    SelectQuestLogEntry(index)
    if GetQuestLogPushable() then
        QuestLogPushQuest()
    end
end

local function StartSharing()
    if sharing then
        Print("Already sharing, please wait...")
        return
    end
    if not InGroup() then
        Print("You are not in a group - nothing to share to.")
        return
    end
    local n = BuildQueue()
    if n == 0 then
        Print("No shareable quests found.")
        return
    end
    sharing = true
    elapsed = 0
    Print("Sharing " .. n .. " quest(s) with your party...")
    f:SetScript("OnUpdate", OnUpdate)
end

f:RegisterEvent("ADDON_LOADED")
f:RegisterEvent("PARTY_MEMBERS_CHANGED")
f:SetScript("OnEvent", function(self, event, arg1)
    if event == "ADDON_LOADED" and arg1 == ADDON then
        AutoShareQuestsDB = AutoShareQuestsDB or {}
        for k, v in pairs(defaults) do
            if AutoShareQuestsDB[k] == nil then
                AutoShareQuestsDB[k] = v
            end
        end
        lastPartySize = GetNumPartyMembers()

    elseif event == "PARTY_MEMBERS_CHANGED" then
        local size = GetNumPartyMembers()
        if AutoShareQuestsDB and AutoShareQuestsDB.auto and size > lastPartySize then
            StartSharing()
        end
        lastPartySize = size
    end
end)

SLASH_AUTOSHAREQUESTS1 = "/asq"
SLASH_AUTOSHAREQUESTS2 = "/shareall"
SlashCmdList["AUTOSHAREQUESTS"] = function(msg)
    msg = string.lower(msg or "")
    msg = string.gsub(msg, "^%s+", "")
    msg = string.gsub(msg, "%s+$", "")

    if msg == "auto" then
        AutoShareQuestsDB.auto = not AutoShareQuestsDB.auto
        Print("Auto-share on group join: " ..
            (AutoShareQuestsDB.auto and "|cff00ff00ON|r" or "|cffff0000OFF|r"))
    elseif msg == "silent" then
        AutoShareQuestsDB.silent = not AutoShareQuestsDB.silent
        DEFAULT_CHAT_FRAME:AddMessage("|cff33ff99AutoShareQuests|r: messages " ..
            (AutoShareQuestsDB.silent and "hidden" or "shown"))
    elseif msg == "" or msg == "share" then
        StartSharing()
    else
        Print("Commands: |cffffff00/asq|r share now  |  |cffffff00/asq auto|r toggle auto-share  |  |cffffff00/asq silent|r toggle messages")
    end
end
