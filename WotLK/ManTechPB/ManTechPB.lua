-- ManTechPB
-- Standalone, task-oriented CMaNGOS PlayerBots manager.

local MTPB_VERSION = "0.6.19"
local MTPB_COMMAND_SEPARATOR = "\\\\"
local MTPB_SELECTED = nil
local MTPB_CURRENT_TAB = "HOME"
local MTPB_FRAME = nil
local MTPB_STATUS = nil
local MTPB_SCOPE_TEXT = nil
local MTPB_ROSTER_TEXT = nil
local MTPB_ROSTER_BUTTONS = {}
local MTPB_ROSTER_FILTER_BUTTONS = {}
local MTPB_ROSTER_VIEW = "PARTY"
local MTPB_PARTY_SCOPE_BUTTON = nil
local MTPB_TAB_BUTTONS = {}
local MTPB_PANELS = {}
local MTPB_STATE_CARDS = {}
local MTPB_ROLE_SLOTS = {}
local MTPB_REFRESH_ELAPSED = 0
local MTPB_MINIMAP_BUTTON = nil
local MTPB_BOT_BAR = nil
local MTPB_TALENT_FRAME = nil
local MTPB_TALENT_TITLE = nil
local MTPB_TALENT_STATUS = nil
local MTPB_TALENT_BUTTONS = {}
local MTPB_TALENT_QUERY_BOT = nil
local MTPB_TALENT_PAGE = 1
local MTPB_TALENT_PAGE_SIZE = 10
local MTPB_TALENT_PAGE_TEXT = nil
local MTPB_TALENT_PREV_BUTTON = nil
local MTPB_TALENT_NEXT_BUTTON = nil
local MTPB_BOTS = {}
local MTPB_SEND_QUEUE = {}
local MTPB_SEND_FRAME = nil
local MTPB_LAST_SEND = -1
local MTPB_WAIT_QUEUE = {}
local MTPB_WAIT_FRAME = nil
local MTPB_PENDING_STRATEGIES = {}
local MTPB_PENDING_TALENT_SYNCS = {}
local MTPB_CheckPendingStrategyReply = nil
local MTPB_ALT_CLICK_FRAME = nil
local MTPB_ALT_LEFT_WAS_DOWN = false
local MTPB_LAST_ALT_OPEN = -10
local MTPB_FOCUS_FRAME = nil
local MTPB_FOCUS_TITLE = nil
local MTPB_FOCUS_SUBTITLE = nil
local MTPB_FOCUS_STATUS = nil
local MTPB_FOCUS_NOTE = nil
local MTPB_FOCUS_ROLE_SLOTS = {}
local MTPB_FOCUS_TABS = {}
local MTPB_FOCUS_PANELS = {}
local MTPB_CHAT_TOGGLE_BUTTON = nil
local MTPB_OUTBOUND_CHAT = {}
local MTPB_CHAT_FILTER_INSTALLED = false
local MTPB_ORIGINAL_CHATFRAME_ONEVENT = nil
local MTPB_VISIBLE_TALENT_QUERY_BOT = nil
local MTPB_VISIBLE_TALENT_QUERY_UNTIL = 0
local MTPB_MANUAL_TALENT_QUERY_SCOPE = nil
local MTPB_MANUAL_TALENT_QUERY_UNTIL = 0
local MTPB_HELP_FRAME = nil
local MTPB_HELP_TITLE = nil
local MTPB_HELP_BODY = nil
local MTPB_HELP_TABS = {}

-- Kept global to avoid consuming another top-level local in the Lua 5.0
-- client, whose chunk-local limit is much lower than later clients.
ManTechPB_FormationButtons = {}
ManTechPB_FormationLayouts = {
    near={{0,4,1},{-7,1,0},{-5,-5,0},{0,-7,0},{5,-5,0},{7,1,0}},
    melee={{0,0,1},{-4,4,0},{4,4,0},{-4,-4,0},{4,-4,0}},
    arrow={{0,0,1},{0,7,0},{-4,-4,0},{4,-4,0},{-7,-7,0},{7,-7,0}},
    far={{0,0,1},{-8,7,0},{8,7,0},{-8,-7,0},{8,-7,0}},
    chaos={{0,0,1},{-7,5,0},{6,7,0},{-3,-7,0},{8,-3,0},{2,4,0}}
}

local function MTPB_TableCount(value)
    local count = 0
    if not value then return count end
    for _ in pairs(value) do count = count + 1 end
    return count
end

local function MTPB_Trim(value)
    if not value then return "" end
    value = string.gsub(value, "^%s+", "")
    value = string.gsub(value, "%s+$", "")
    return value
end

local function MTPB_Split(value, separator)
    local result, start = {}, 1
    local first, last = string.find(value or "", separator, start)
    while first do
        table.insert(result, string.sub(value, start, first - 1))
        start = last + 1
        first, last = string.find(value, separator, start)
    end
    table.insert(result, string.sub(value or "", start))
    return result
end

local function MTPB_Wait(delay, callback, a1, a2, a3, a4)
    if type(delay) ~= "number" or type(callback) ~= "function" then return false end
    if not MTPB_WAIT_FRAME then
        MTPB_WAIT_FRAME = CreateFrame("Frame")
        MTPB_WAIT_FRAME:SetScript("OnUpdate", function(self, elapsed)
            local now, index = GetTime(), 1
            while index <= table.getn(MTPB_WAIT_QUEUE) do
                local record = MTPB_WAIT_QUEUE[index]
                if record.at <= now then
                    table.remove(MTPB_WAIT_QUEUE, index)
                    record.callback(unpack(record.args))
                else
                    index = index + 1
                end
            end
            if table.getn(MTPB_WAIT_QUEUE) == 0 then MTPB_WAIT_FRAME:Hide() end
        end)
    end
    table.insert(MTPB_WAIT_QUEUE, {at=GetTime()+delay, callback=callback, args={a1,a2,a3,a4}})
    MTPB_WAIT_FRAME:Show()
    return true
end

local function MTPB_PartySize()
    local raid = GetNumRaidMembers and GetNumRaidMembers() or 0
    if raid > 0 then return raid end
    return GetNumPartyMembers and GetNumPartyMembers() or 0
end

local function MTPB_CharacterKey()
    local player = UnitName and UnitName("player") or nil
    local realm = GetRealmName and GetRealmName() or ""
    if not player or player == "" then return nil end
    return (realm or "") .. ":" .. player
end

local function MTPB_IsCurrentPartyMember(name)
    if not name or name == "" then return false end
    local count = GetNumRaidMembers and GetNumRaidMembers() or 0
    local prefix = "raid"
    if count == 0 then
        count = GetNumPartyMembers and GetNumPartyMembers() or 0
        prefix = "party"
    end
    local i
    for i = 1, count do
        if UnitName(prefix .. i) == name then return true end
    end
    return false
end

local function MTPB_BarePlayerName(name)
    if not name then return nil end
    local dash = string.find(name, "-", 1, true)
    return dash and string.sub(name, 1, dash - 1) or name
end

local function MTPB_IsKnownBot(name)
    local bare = MTPB_BarePlayerName(name)
    return bare and (MTPB_BOTS[bare] ~= nil or bare == MTPB_SELECTED or bare == MTPB_TALENT_QUERY_BOT)
end

local function MTPB_RememberOutboundChat(text, chat, target)
    if not text or not chat then return end
    table.insert(MTPB_OUTBOUND_CHAT, {text=text, chat=chat, target=MTPB_BarePlayerName(target), untilAt=GetTime()+4})
end

local function MTPB_IsRememberedOutbound(text, chat, target)
    local now, i = GetTime(), 1
    target = MTPB_BarePlayerName(target)
    while i <= table.getn(MTPB_OUTBOUND_CHAT) do
        local record = MTPB_OUTBOUND_CHAT[i]
        if not record or now > record.untilAt then
            table.remove(MTPB_OUTBOUND_CHAT, i)
        elseif record.text == text and record.chat == chat and (not record.target or not target or record.target == target) then
            -- Keep it briefly because ChatFrame_OnEvent runs once per chat tab.
            return true
        else
            i = i + 1
        end
    end
    return false
end

local function MTPB_IsRecognizedBotReply(message)
    if type(message) ~= "string" then return false end
    if string.sub(message, 1, 4) == "BOT\t" then message = string.sub(message, 5) end
    local prefixes = {
        "Combat Strategies:", "Non Combat Strategies:", "Reaction Strategies:", "Dead Strategies:",
        "Formation:", "Stance:", "Mana save level", "Loot strategy:", "My always loot list:",
        "My skip loot list:", "My skip go loot list:", "My current talent spec is:",
        "Found multiple specs:", "Apply talents [", "rti:", "rti cc:", "Roll policy",
        "Role:", "Build:", "PullAction:", "Pull failed:"
    }
    local i
    for i = 1, table.getn(prefixes) do
        if string.find(message, prefixes[i], 1, true) == 1 then return true end
    end
    return string.find(message, "possible specs to choose from", 1, true) ~= nil
end

local function MTPB_IsTalentCommand(message)
    if type(message) ~= "string" then return false end
    if string.sub(message, 1, 4) == "BOT\t" then message = string.sub(message, 5) end
    local lower = string.lower(MTPB_Trim(message))
    return lower == "talents" or string.find(lower, "talents ", 1, true) == 1
end

local function MTPB_IsTalentReply(message)
    if type(message) ~= "string" then return false end
    if string.sub(message, 1, 4) == "BOT\t" then message = string.sub(message, 5) end
    return string.find(message, "My current talent spec is:", 1, true) == 1
        or string.find(message, "Found multiple specs:", 1, true) == 1
        or string.find(message, "Apply talents [", 1, true) == 1
        or string.find(message, "possible specs to choose from", 1, true) ~= nil
end

local function MTPB_ShouldHideBotChat(eventName, message, sender)
    if not ManTechPBDB or not ManTechPBDB.hideBotReplies then return false end
    local visibleTalentBot = MTPB_VISIBLE_TALENT_QUERY_BOT
    if visibleTalentBot and GetTime() <= MTPB_VISIBLE_TALENT_QUERY_UNTIL then
        local bareSender = MTPB_BarePlayerName(sender)
        local visibleMessage = message or ""
        if string.sub(visibleMessage, 1, 4) == "BOT\t" then visibleMessage = string.sub(visibleMessage, 5) end
        if eventName == "CHAT_MSG_WHISPER_INFORM" and bareSender == visibleTalentBot and message == "talents" then
            return false
        end
        if bareSender == visibleTalentBot and string.find(visibleMessage, "My current talent spec is:", 1, true) == 1 then
            return false
        end
    end
    local manualScope = MTPB_MANUAL_TALENT_QUERY_SCOPE
    if manualScope and GetTime() <= MTPB_MANUAL_TALENT_QUERY_UNTIL and MTPB_IsTalentReply(message) then
        local bareSender = MTPB_BarePlayerName(sender)
        if manualScope == "PARTY" or bareSender == manualScope then return false end
    end
    if eventName == "CHAT_MSG_WHISPER_INFORM" then
        local addonOutbound = MTPB_IsRememberedOutbound(message, "WHISPER", sender)
        if not addonOutbound and MTPB_IsTalentCommand(message) then
            MTPB_MANUAL_TALENT_QUERY_SCOPE = MTPB_BarePlayerName(sender)
            MTPB_MANUAL_TALENT_QUERY_UNTIL = GetTime() + 20
        end
        return addonOutbound
    end
    if eventName == "CHAT_MSG_PARTY" or eventName == "CHAT_MSG_PARTY_LEADER" then
        if MTPB_BarePlayerName(sender) == MTPB_BarePlayerName(UnitName("player")) then
            local addonOutbound = MTPB_IsRememberedOutbound(message, "PARTY", nil)
            if not addonOutbound and MTPB_IsTalentCommand(message) then
                MTPB_MANUAL_TALENT_QUERY_SCOPE = "PARTY"
                MTPB_MANUAL_TALENT_QUERY_UNTIL = GetTime() + 20
            end
            return addonOutbound
        end
    elseif eventName ~= "CHAT_MSG_WHISPER" then
        return false
    end
    local bot = MTPB_BarePlayerName(sender)
    if not MTPB_IsKnownBot(bot) then return false end
    -- Do not blanket-hide everything a bot says during a command window; bots
    -- can also produce ordinary conversational/roleplay chat. Suppress only
    -- response formats positively identified as PlayerBot command output.
    return MTPB_IsRecognizedBotReply(message)
end

-- WoW 1.12 embeds Lua 5.0, which cannot use the Lua 5.1 vararg expression
-- (`...`) in a return list. Keep the filter signature explicit so this same
-- file parses on Classic, TBC, and WotLK while preserving every chat field.
local function MTPB_MessageEventFilter(self, eventName, message, sender, a1, a2, a3, a4, a5, a6, a7, a8, a9, a10)
    if MTPB_ShouldHideBotChat(eventName, message, sender) then return true end
    return false, message, sender, a1, a2, a3, a4, a5, a6, a7, a8, a9, a10
end

local function MTPB_ChatFrameOnEvent(selfOrEvent, eventName, a1, a2, a3, a4, a5, a6, a7, a8, a9, a10)
    if type(selfOrEvent) == "string" then
        if MTPB_ShouldHideBotChat(selfOrEvent, arg1, arg2) then return end
        return MTPB_ORIGINAL_CHATFRAME_ONEVENT(selfOrEvent)
    end
    if MTPB_ShouldHideBotChat(eventName, a1, a2) then return end
    return MTPB_ORIGINAL_CHATFRAME_ONEVENT(selfOrEvent, eventName, a1, a2, a3, a4, a5, a6, a7, a8, a9, a10)
end

local function MTPB_InstallChatFilter()
    if MTPB_CHAT_FILTER_INSTALLED then return end
    if type(ChatFrame_AddMessageEventFilter) == "function" then
        pcall(ChatFrame_AddMessageEventFilter, "CHAT_MSG_WHISPER", MTPB_MessageEventFilter)
        pcall(ChatFrame_AddMessageEventFilter, "CHAT_MSG_WHISPER_INFORM", MTPB_MessageEventFilter)
        pcall(ChatFrame_AddMessageEventFilter, "CHAT_MSG_PARTY", MTPB_MessageEventFilter)
        pcall(ChatFrame_AddMessageEventFilter, "CHAT_MSG_PARTY_LEADER", MTPB_MessageEventFilter)
        MTPB_CHAT_FILTER_INSTALLED = true
    elseif type(ChatFrame_OnEvent) == "function" then
        MTPB_ORIGINAL_CHATFRAME_ONEVENT = ChatFrame_OnEvent
        ChatFrame_OnEvent = MTPB_ChatFrameOnEvent
        MTPB_CHAT_FILTER_INSTALLED = true
    end
end

if type(MTPB_TEST_HOOKS) == "table" then
    MTPB_TEST_HOOKS.ShouldHideBotChat = MTPB_ShouldHideBotChat
end

local function MTPB_SendPacket(packet)
    if packet.raw or packet.chat == "SAY" or packet.chat == "GUILD" then
        MTPB_RememberOutboundChat(packet.text, packet.chat, packet.channel)
        SendChatMessage(packet.text, packet.chat, packet.lang, packet.channel)
    elseif packet.chat == "WHISPER" then
        MTPB_RememberOutboundChat("BOT\t" .. packet.text, "WHISPER", packet.channel)
        SendChatMessage("BOT\t" .. packet.text, "WHISPER", packet.lang, packet.channel)
    elseif SendAddonMessage then
        SendAddonMessage("BOT", packet.text, packet.chat, packet.channel)
    else
        SendChatMessage("BOT\t" .. packet.text, packet.chat, packet.lang, packet.channel)
    end
    MTPB_LAST_SEND = GetTime()
end

local function MTPB_QueueCommand(text, chat, lang, channel, raw)
    if type(text) ~= "string" or text == "" then return false end
    if chat == "WHISPER" and (not channel or channel == "") then return false end
    if chat == "PARTY" and MTPB_PartySize() == 0 then return false end
    local start = 1
    repeat
        local separator = not raw and string.find(text, MTPB_COMMAND_SEPARATOR, start, true)
        local part = string.sub(text, start, separator and separator - 1 or string.len(text))
        local limit = (raw or chat == "SAY" or chat == "GUILD") and 255 or 251
        if string.len(part) > limit then
            if DEFAULT_CHAT_FRAME then DEFAULT_CHAT_FRAME:AddMessage("|cffff5555ManTechPB:|r Command is too long and was not sent.") end
            return false
        end
        if part ~= "" then table.insert(MTPB_SEND_QUEUE, {text=part,chat=chat,lang=lang,channel=channel,raw=raw}) end
        start = separator and separator + string.len(MTPB_COMMAND_SEPARATOR) or nil
    until not start
    if table.getn(MTPB_SEND_QUEUE) > 80 then
        if DEFAULT_CHAT_FRAME then DEFAULT_CHAT_FRAME:AddMessage("|cffff5555ManTechPB:|r Command queue is full. Wait a moment and retry.") end
        return false
    end
    if not MTPB_SEND_FRAME then
        MTPB_SEND_FRAME = CreateFrame("Frame")
        MTPB_SEND_FRAME:SetScript("OnUpdate", function(self, elapsed)
            if GetTime() - MTPB_LAST_SEND >= 0.30 and table.getn(MTPB_SEND_QUEUE) > 0 then
                MTPB_SendPacket(table.remove(MTPB_SEND_QUEUE, 1))
            end
            if table.getn(MTPB_SEND_QUEUE) == 0 then MTPB_SEND_FRAME:Hide() end
        end)
    end
    MTPB_SEND_FRAME:Show()
    return true
end

local function MTPB_SendBotCommand(text, chat, lang, channel)
    return MTPB_QueueCommand(text, chat, lang, channel, false)
end

local function MTPB_SendRawCommand(text, chat, lang, channel)
    return MTPB_QueueCommand(text, chat, lang, channel, true)
end

local function MTPB_QueryBotParty()
    -- Only query state that the manager actually displays.  In particular,
    -- "ll ?" makes every bot dump four unrelated loot lists into chat.
    MTPB_SendBotCommand("#a co ?" .. MTPB_COMMAND_SEPARATOR .. "#a nc ?" .. MTPB_COMMAND_SEPARATOR .. "#a react ?" .. MTPB_COMMAND_SEPARATOR .. "formation ?", "PARTY")
end

local function MTPB_QuerySelectedBot(name)
    if not name then return end
    MTPB_SendBotCommand("#a co ?" .. MTPB_COMMAND_SEPARATOR .. "#a nc ?" .. MTPB_COMMAND_SEPARATOR .. "#a react ?" .. MTPB_COMMAND_SEPARATOR .. "formation ?" .. MTPB_COMMAND_SEPARATOR .. "status role" .. MTPB_COMMAND_SEPARATOR .. "status build" .. MTPB_COMMAND_SEPARATOR .. "status pull", "WHISPER", nil, name)
end

local function MTPB_QueryStrategyConfirmation(name, contexts)
    if not name or not contexts then return false end
    local query = ""
    local i
    for i = 1, table.getn(contexts) do
        if query ~= "" then query = query .. MTPB_COMMAND_SEPARATOR end
        query = query .. "#a " .. contexts[i] .. " ?"
    end
    return MTPB_SendBotCommand(query, "WHISPER", nil, name)
end

local function MTPB_UpdateBotList(delay)
    MTPB_Wait(delay or 0, function() MTPB_SendRawCommand(".bot list", "SAY") end)
end

local function MTPB_Capture(text, pattern)
    local _, _, value = string.find(text or "", pattern)
    return value
end

local function MTPB_ParseStrategies(message, sender)
    if not sender or not message then return false end
    if string.sub(message, 1, 4) == "BOT\t" then message = string.sub(message, 5) end
    local context, trimAt
    if string.find(message, "Combat Strategies: ", 1, true) == 1 then context, trimAt = "co", 20
    elseif string.find(message, "Non Combat Strategies: ", 1, true) == 1 then context, trimAt = "nc", 24
    elseif string.find(message, "Reaction Strategies: ", 1, true) == 1 then context, trimAt = "react", 22 end
    if context then
        if not MTPB_BOTS[sender] then MTPB_BOTS[sender] = {} end
        if not MTPB_BOTS[sender].strategy then MTPB_BOTS[sender].strategy = {co={},nc={},react={}} end
        local list, values, i = {}, MTPB_Split(string.sub(message, trimAt), ", "), 1
        for i = 1, table.getn(values) do table.insert(list, MTPB_Trim(values[i])) end
        MTPB_BOTS[sender].strategy[context] = list
        if MTPB_CheckPendingStrategyReply then MTPB_CheckPendingStrategyReply(sender, context, list) end
        return true
    end
    if not MTPB_BOTS[sender] then return false end
    if string.find(message, "Formation: ", 1, true) == 1 then
        local formation = string.gsub(string.sub(message, 12), "|c%x%x%x%x%x%x%x%x", "")
        formation = string.gsub(formation, "|r", "")
        MTPB_BOTS[sender].formation = string.lower(MTPB_Trim(formation))
        return true
    end
    if string.find(message, "Stance: ", 1, true) == 1 then MTPB_BOTS[sender].stance = string.sub(message, 9); return true end
    if string.find(message, "Mana save level set: ", 1, true) == 1 then MTPB_BOTS[sender].savemana = string.sub(message, 22); return true end
    if string.find(message, "Mana save level: ", 1, true) == 1 then MTPB_BOTS[sender].savemana = string.sub(message, 18); return true end
    if string.find(message, "Loot strategy: ", 1, true) == 1 then MTPB_BOTS[sender].loot = string.sub(message, 16); return true end
    if string.find(message, "Roll policy", 1, true) == 1 then
        MTPB_BOTS[sender].rollPolicy = MTPB_Trim(MTPB_Capture(message, "Roll policy[^:]*:%s*(.+)") or "")
        return true
    end
    if string.find(message, "Pull failed: ", 1, true) == 1 then MTPB_SetStatus(sender .. ": " .. message, MTPB_COLORS.red); return true end
    if string.find(message, "Role: ", 1, true) == 1 then
        MTPB_BOTS[sender].reportedRole = MTPB_Trim(MTPB_Capture(message, "Role: ([^;]+)") or "")
        MTPB_BOTS[sender].reportedRange = MTPB_Trim(MTPB_Capture(message, "Range: ([^;]+)") or "")
        MTPB_BOTS[sender].reportedSpec = MTPB_Trim(MTPB_Capture(message, "Spec: ([^;]+)") or "")
        return true
    end
    if string.find(message, "Build: ", 1, true) == 1 then
        MTPB_BOTS[sender].reportedBuild = MTPB_Trim(MTPB_Capture(message, "Build: ([^;]+)") or "")
        MTPB_BOTS[sender].suggestedRole = MTPB_Trim(MTPB_Capture(message, "SuggestedRole: ([^;]+)") or "")
        return true
    end
    if string.find(message, "PullAction: ", 1, true) == 1 then
        MTPB_BOTS[sender].pullAction = MTPB_Trim(MTPB_Capture(message, "PullAction: ([^;]+)") or "")
        MTPB_BOTS[sender].pullReady = MTPB_Trim(MTPB_Capture(message, "Ready: ([^;]+)") or "")
        MTPB_BOTS[sender].pullReason = MTPB_Trim(MTPB_Capture(message, "Reason: (.+)") or "")
        return true
    end
    if string.find(message, "rti cc: ", 1, true) == 1 then MTPB_BOTS[sender].rti_cc = string.sub(message, 9); return true end
    if string.find(message, "rti: ", 1, true) == 1 then MTPB_BOTS[sender].rti = string.sub(message, 6); return true end
    return false
end

local function MTPB_ParseRoster(message)
    if not message or string.find(message, "Bot roster: ", 1, true) ~= 1 then return false end
    local fresh, values, i = {}, MTPB_Split(string.sub(message, 13), ", "), 1
    for i = 1, table.getn(values) do
        local line = MTPB_Trim(values[i])
        local marker, splitAt = string.sub(line, 1, 1), string.find(line, " ")
        if splitAt then
            local name = string.sub(line, 2, splitAt - 1)
            fresh[name] = MTPB_BOTS[name] or {}
            fresh[name].class = string.sub(line, splitAt + 1)
            fresh[name].online = marker == "+"
        end
    end
    MTPB_BOTS = fresh
    return true
end

local MTPB_COLORS = {
    gold = "|cffe3b95b",
    blue = "|cff4dd7ff",
    green = "|cff55dd88",
    yellow = "|cffffcc55",
    red = "|cffff6666",
    gray = "|cff9ca9bd",
    white = "|cffffffff"
}

-- Shared readable styling for the three legacy clients. The stock panel
-- button is deliberately replaced with a blue, lightly beveled treatment so
-- controls remain recognizable as buttons without looking like flat blocks.
function ManTechPB_SetReadableFont(region, size, flags)
    if not region or not region.SetFont then return end
    local font = region.GetFont and region:GetFont()
    region:SetFont(font or "Fonts\\FRIZQT__.TTF", size or 12, flags or "OUTLINE")
end

function ManTechPB_StyleButton(button, size)
    if not button or button.mtpbStyled then return button end
    button.mtpbStyled = true
    button:SetBackdrop({
        bgFile="Interface\\Tooltips\\UI-Tooltip-Background",
        edgeFile="Interface\\Tooltips\\UI-Tooltip-Border",
        tile=true, tileSize=16, edgeSize=8,
        insets={left=2,right=2,top=2,bottom=2}
    })
    button:SetBackdropColor(0.07, 0.16, 0.23, 0.98)
    button:SetBackdropBorderColor(0.26, 0.62, 0.82, 0.95)
    button:SetNormalTexture("Interface\\Tooltips\\UI-Tooltip-Background")
    local normal = button:GetNormalTexture()
    if normal then normal:SetAllPoints(button); normal:SetVertexColor(0.08, 0.20, 0.29, 0.90) end
    button:SetPushedTexture("Interface\\Tooltips\\UI-Tooltip-Background")
    local pushed = button:GetPushedTexture()
    if pushed then pushed:SetAllPoints(button); pushed:SetVertexColor(0.03, 0.09, 0.14, 1) end
    button:SetHighlightTexture("Interface\\Buttons\\UI-Listbox-Highlight2", "ADD")
    local highlight = button:GetHighlightTexture()
    if highlight then highlight:SetAllPoints(button); highlight:SetVertexColor(0.30, 0.75, 1.00, 0.55) end
    local shine = button:CreateTexture(nil, "OVERLAY")
    shine:SetTexture("Interface\\Buttons\\UI-Listbox-Highlight2")
    shine:SetPoint("TOPLEFT", button, "TOPLEFT", 4, -3)
    shine:SetPoint("TOPRIGHT", button, "TOPRIGHT", -4, -3)
    shine:SetHeight(4)
    shine:SetVertexColor(0.55, 0.88, 1.00, 0.28)
    local label = button:GetFontString()
    if label then
        ManTechPB_SetReadableFont(label, size or 12, "OUTLINE")
        label:SetTextColor(1.00, 0.84, 0.40)
    end
    return button
end

-- Draw compact top-down formation previews without bundling external artwork.
-- Gold is the formation anchor (the player or current target); blue squares are
-- representative bot slots. The drawings intentionally mirror the five legacy
-- Mangosbot formation choices while remaining readable on all three clients.
function ManTechPB_AddFormationPreview(button, formation)
    local preview = CreateFrame("Frame", nil, button)
    preview:SetWidth(23)
    preview:SetHeight(19)
    preview:SetPoint("LEFT", button, "LEFT", 4, 0)
    preview:SetBackdrop({
        bgFile="Interface\\Tooltips\\UI-Tooltip-Background",
        edgeFile="Interface\\Tooltips\\UI-Tooltip-Border",
        tile=true, tileSize=8, edgeSize=5,
        insets={left=1,right=1,top=1,bottom=1}
    })
    preview:SetBackdropColor(0.01, 0.025, 0.04, 0.96)
    preview:SetBackdropBorderColor(0.18, 0.42, 0.58, 0.90)

    local layout = ManTechPB_FormationLayouts[formation] or {}
    local i, point, marker, size
    for i = 1, table.getn(layout) do
        point = layout[i]
        size = point[3] == 1 and 4 or 3
        marker = preview:CreateTexture(nil, "ARTWORK")
        marker:SetTexture("Interface\\Tooltips\\UI-Tooltip-Background")
        marker:SetWidth(size)
        marker:SetHeight(size)
        marker:SetPoint("CENTER", preview, "CENTER", point[1], point[2])
        if point[3] == 1 then marker:SetVertexColor(1.00, 0.72, 0.10, 1)
        else marker:SetVertexColor(0.20, 0.82, 1.00, 1) end
    end
    button.mtpbFormationPreview = preview
end

function ManTechPB_UpdateFormationButtons()
    if not ManTechPB_FormationButtons then return end
    local names = {}
    if MTPB_SELECTED then table.insert(names, MTPB_SELECTED)
    else
        local partyName
        for partyName in pairs(MTPB_BOTS) do
            if MTPB_IsCurrentPartyMember(partyName) then table.insert(names, partyName) end
        end
    end
    local i, j, button, total, matching, data
    for i = 1, table.getn(ManTechPB_FormationButtons) do
        button = ManTechPB_FormationButtons[i]
        total, matching = 0, 0
        for j = 1, table.getn(names) do
            data = MTPB_BOTS[names[j]]
            total = total + 1
            if data and data.formation == button.form then matching = matching + 1 end
        end
        if total > 0 and matching == total then
            button:SetBackdropBorderColor(0.20, 0.90, 0.45, 1)
        elseif matching > 0 then
            button:SetBackdropBorderColor(1.00, 0.68, 0.16, 1)
        else
            button:SetBackdropBorderColor(0.26, 0.62, 0.82, 0.95)
        end
    end
end

local MTPB_HELP_PAGES = {
    OVERVIEW = {
        title="Manager overview",
        text="|cffe3b95bChoose the scope first.|r  Party affects every controlled party bot. Selecting a name on the left limits supported actions to that bot. My Alts lists known account bots outside the current party. Select an offline alt and use Log In, or select an online bot and use Log Out. All In and All Out affect the full known account-bot roster.\n\n|cff4dd7ffPlay|r has common orders. |cff4dd7ffSetup|r pairs the real talent build with an AI role. |cff4dd7ffCombat|r changes fighting behavior. |cff4dd7ffWorld|r controls movement, formation, and looting. |cff4dd7ffExpert|r contains the complete advanced controls.\n\nGreen borders mean confirmed ON, no border means OFF, gold means pending, and a half-state means a mixed party selection. Read the bottom status line after every change."
    },
    INDIVIDUAL = {
        title="Individual control",
        text="This window always controls the bot named in its title. Open it with Alt-left-click on a bot, or select that bot in the Manager. The Manager button opens the full window without closing this one.\n\nQuick contains immediate orders. Role selects the bot's AI job and opens Talents. Tactic sets assist, range, pulling, threat, and passive/aggressive behavior. Fight controls combat choices. Support controls healing, buffs, and utility. World covers recovery, loot, travel, and RPG behavior.\n\nChanging a card sends the command and waits for the bot to confirm it. A green border is the confirmed state; do not treat the temporary gold border as success."
    },
    TALENTS = {
        title="Talents and roles",
        text="Find Builds asks the selected bot for the exact builds configured on this server. Always use that list; build names differ between Classic, TBC, and WotLK. Click a returned build to apply it. ManTechPB waits for the server to confirm the real build before matching the AI role.\n\nCurrent asks only the selected bot for its talent spec. That one request and reply remain visible in chat even when Bot Chat is hidden, while the bottom line shows only the short spec name. Auto Pick lets PlayerBots choose. Reset Talents requires a second confirmation click.\n\nTalents spend points. Role cards control behavior. A correct healer build can still DPS when Healer DPS is enabled, and a tank build still needs the intended tank strategies."
    },
    BEHAVIOR = {
        title="Combat and world behavior",
        text="Tank Assist makes a bot lead and hold aggro; Damage Assist makes it follow the tank's target. Close and Ranged control combat distance. Pull authorizes a puller; Pull Back tells it to return after drawing the target. Passive prevents normal engagement, while Aggressive enables nearby grinding.\n\nHealer DPS permits damage while healing; turn it off when healing must be the priority. Off-heal lets damage roles help heal. Low Threat reduces threat-generating choices but does not remove class survival abilities.\n\nFormations are group-level controls in Manager > World. Each button contains a top-down preview: gold marks the anchor and blue marks representative bot positions. A green border is the confirmed formation; gold means only part of the selected party uses it. Loot behavior and roll policy are separate: Loot controls corpse interaction; Expert > Loot controls roll preference when supported by the core."
    },
    CHAT = {
        title="Bot chat and Bot Bar",
        text="Bot Chat: Hidden suppresses recognized PlayerBots traffic generated by the manager while the addon still reads confirmations. Commands you type yourself, including talents and talents list, keep their replies visible. Toggle the filter in the Manager or use /mtp chat show and /mtp chat hide. Ordinary bot conversation is not intentionally hidden.\n\nThe Bot Bar sends fast party orders. Tank Pull requires an attackable target and asks the bot identified by the core's @tank filter to pull. Attack, Follow, Stay, Flee, Reset AI, Summon, and Give Leader are party actions. Drag the bar to move it; use /mtp bar to toggle it and /mtp bar reset to restore its position.\n\nOpen ManTechPB with /mtp or /mantechpb. When a command fails, the bottom status line should report the bot or core response."
    }
}

local function MTPB_ShowHelpPage(page)
    local selected = MTPB_HELP_PAGES[page] and page or "OVERVIEW"
    local data = MTPB_HELP_PAGES[selected]
    if MTPB_HELP_TITLE then MTPB_HELP_TITLE:SetText(MTPB_COLORS.gold .. "MANTECHPB HELP" .. MTPB_COLORS.gray .. "  -  " .. MTPB_COLORS.white .. data.title .. "|r") end
    if MTPB_HELP_BODY then MTPB_HELP_BODY:SetText(data.text) end
    local key, button
    for key, button in pairs(MTPB_HELP_TABS) do if key == selected then button:LockHighlight() else button:UnlockHighlight() end end
end

function ManTechPB_ShowHelp(page)
    if not MTPB_HELP_FRAME then
        local frame = CreateFrame("Frame", "ManTechPBHelpFrame", UIParent)
        MTPB_HELP_FRAME = frame
        frame:SetWidth(540); frame:SetHeight(410); frame:SetFrameStrata("TOOLTIP")
        frame:SetMovable(true); frame:EnableMouse(true); frame:SetClampedToScreen(true)
        frame:SetBackdrop({bgFile="Interface\\DialogFrame\\UI-DialogBox-Background",edgeFile="Interface\\DialogFrame\\UI-DialogBox-Border",tile=true,tileSize=32,edgeSize=24,insets={left=8,right=8,top=8,bottom=8}})
        frame:SetBackdropColor(0.025,0.035,0.055,0.99); frame:SetBackdropBorderColor(0.08,0.58,0.78,1)
        frame:SetPoint("CENTER", UIParent, "CENTER", 0, 30)
        local drag = CreateFrame("Button", nil, frame)
        drag:SetPoint("TOPLEFT", frame, "TOPLEFT", 10, -7); drag:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -38, -7); drag:SetHeight(32)
        drag:RegisterForDrag("LeftButton"); drag:SetScript("OnDragStart", function() MTPB_HELP_FRAME:StartMoving() end); drag:SetScript("OnDragStop", function() MTPB_HELP_FRAME:StopMovingOrSizing() end)
        MTPB_HELP_TITLE = frame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        MTPB_HELP_TITLE:SetPoint("TOPLEFT", frame, "TOPLEFT", 18, -16); ManTechPB_SetReadableFont(MTPB_HELP_TITLE, 14, "OUTLINE")
        local close = CreateFrame("Button", nil, frame, "UIPanelCloseButton")
        close:SetPoint("TOPRIGHT", frame, "TOPRIGHT", 3, 3); close:SetScript("OnClick", function() MTPB_HELP_FRAME:Hide() end)
        local pages={{"OVERVIEW","Overview"},{"INDIVIDUAL","Individual"},{"TALENTS","Talents"},{"BEHAVIOR","Behavior"},{"CHAT","Chat & Bar"}}
        local i, tab
        for i=1,table.getn(pages) do
            tab=CreateFrame("Button",nil,frame,"UIPanelButtonTemplate"); tab:SetWidth(96); tab:SetHeight(28); tab:SetPoint("TOPLEFT",frame,"TOPLEFT",18+(i-1)*100,-48); tab:SetText(pages[i][2]); tab.page=pages[i][1]
            ManTechPB_StyleButton(tab,12)
            tab:SetScript("OnClick",function(self) local owner=self or this; MTPB_ShowHelpPage(owner.page) end); MTPB_HELP_TABS[pages[i][1]]=tab
        end
        local bodyPanel=CreateFrame("Frame",nil,frame); bodyPanel:SetPoint("TOPLEFT",frame,"TOPLEFT",18,-86); bodyPanel:SetWidth(504); bodyPanel:SetHeight(302)
        bodyPanel:SetBackdrop({bgFile="Interface\\Tooltips\\UI-Tooltip-Background",edgeFile="Interface\\Tooltips\\UI-Tooltip-Border",tile=true,tileSize=16,edgeSize=10,insets={left=5,right=5,top=5,bottom=5}})
        bodyPanel:SetBackdropColor(0.025,0.065,0.09,0.96); bodyPanel:SetBackdropBorderColor(0.18,0.48,0.66,0.9)
        MTPB_HELP_BODY=bodyPanel:CreateFontString(nil,"OVERLAY","GameFontNormal")
        MTPB_HELP_BODY:SetPoint("TOPLEFT",bodyPanel,"TOPLEFT",14,-14); MTPB_HELP_BODY:SetWidth(476); MTPB_HELP_BODY:SetHeight(274); MTPB_HELP_BODY:SetJustifyH("LEFT"); MTPB_HELP_BODY:SetJustifyV("TOP")
        ManTechPB_SetReadableFont(MTPB_HELP_BODY,13,"")
        frame:Hide()
    end
    MTPB_ShowHelpPage(page or "OVERVIEW")
    MTPB_HELP_FRAME:Show()
end

local MTPB_CLASS_COLORS = {
    DRUID = {1.00, 0.49, 0.04}, HUNTER = {0.67, 0.83, 0.45}, MAGE = {0.41, 0.80, 0.94},
    PALADIN = {0.96, 0.55, 0.73}, PRIEST = {1.00, 1.00, 1.00}, ROGUE = {1.00, 0.96, 0.41},
    SHAMAN = {0.00, 0.44, 0.87}, WARLOCK = {0.58, 0.51, 0.79}, WARRIOR = {0.78, 0.61, 0.43},
    DEATHKNIGHT = {0.77, 0.12, 0.23}
}

local MTPB_SPECS = {
    DRUID = {
        {name="Feral Tank", strategy="tank feral", role="tank", icon="Ability_Racial_BearForm"},
        {name="Feral Damage", strategy="dps feral", role="melee", icon="Ability_Druid_CatForm"},
        {name="Balance", strategy="balance", role="ranged", icon="Spell_Nature_StarFall"},
        {name="Restoration", strategy="restoration", role="heal", icon="Spell_Nature_HealingTouch"}
    },
    HUNTER = {
        {name="Beast Mastery", strategy="beast mastery", role="ranged", icon="Ability_Hunter_BeastTaming"},
        {name="Marksmanship", strategy="marksmanship", role="ranged", icon="Ability_Marksmanship"},
        {name="Survival", strategy="survival", role="ranged", icon="Ability_Hunter_SwiftStrike"}
    },
    MAGE = {
        {name="Arcane", strategy="arcane", role="ranged", icon="Spell_Holy_MagicalSentry"},
        {name="Fire", strategy="fire", role="ranged", icon="Spell_Fire_FireBolt02"},
        {name="Frost", strategy="frost", role="ranged", icon="Spell_Frost_FrostBolt02"}
    },
    PALADIN = {
        {name="Retribution", strategy="retribution", role="melee", icon="Spell_Holy_AuraOfLight"},
        {name="Protection", strategy="protection", role="tank", icon="Spell_Holy_DevotionAura"},
        {name="Holy", strategy="holy", role="heal", icon="Spell_Holy_HolyBolt"}
    },
    PRIEST = {
        {name="Discipline", strategy="discipline", role="heal", icon="Spell_Holy_WordFortitude"},
        {name="Holy", strategy="holy", role="heal", icon="Spell_Holy_HolyBolt"},
        {name="Shadow", strategy="shadow", role="ranged", icon="Spell_Shadow_ShadowWordPain"}
    },
    ROGUE = {
        {name="Combat", strategy="combat", role="melee", icon="Ability_BackStab"},
        {name="Assassination", strategy="assassination", role="melee", icon="Ability_Rogue_Eviscerate"},
        {name="Subtlety", strategy="subtlety", role="melee", icon="Ability_Stealth"}
    },
    SHAMAN = {
        {name="Elemental", strategy="elemental", role="ranged", icon="Spell_Nature_Lightning"},
        {name="Restoration", strategy="restoration", role="heal", icon="Spell_Nature_MagicImmunity"},
        {name="Enhancement", strategy="enhancement", role="melee", icon="Spell_Nature_LightningShield"}
    },
    WARLOCK = {
        {name="Affliction", strategy="affliction", role="ranged", icon="Spell_Shadow_DeathCoil"},
        {name="Demonology", strategy="demonology", role="ranged", icon="Spell_Shadow_Metamorphosis"},
        {name="Destruction", strategy="destruction", role="ranged", icon="Spell_Shadow_RainOfFire"}
    },
    WARRIOR = {
        {name="Arms", strategy="arms", role="melee", icon="Ability_Warrior_SavageBlow"},
        {name="Fury", strategy="fury", role="melee", icon="Ability_Warrior_InnerRage"},
        {name="Protection", strategy="protection", role="tank", icon="INV_Shield_06"}
    },
    DEATHKNIGHT = {
        {name="Blood", strategy="blood", role="tank", icon="Spell_Deathknight_BloodPresence"},
        {name="Frost", strategy="frost", role="melee", icon="Spell_Deathknight_FrostPresence"},
        {name="Unholy", strategy="unholy", role="melee", icon="Spell_Deathknight_UnholyPresence"}
    }
}

-- Exact aliases cover short names used by older CMaNGOS configurations.  They
-- are mapping aliases only: the Talents window never sends one unless the bot
-- returned that exact name from "talents list".  Newer cores use names such as
-- "Holy PvE", while older tracks may use "pve holy".
local MTPB_TALENT_AI_MAP = {
    DRUID = {
        ["pve balance"]="balance", ["pvp balance"]="balance",
        ["pve feral"]="dps feral", ["pvp feral"]="dps feral",
        ["pve resto"]="restoration", ["pvp resto"]="restoration"
    },
    HUNTER = {
        ["pve bm"]="beast mastery", ["pvp bm"]="beast mastery",
        ["pve mm"]="marksmanship", ["pvp mm"]="marksmanship",
        ["pve surv"]="survival", ["pvp surv"]="survival"
    },
    MAGE = {
        ["pve arcane"]="arcane", ["pvp arcane"]="arcane",
        ["pve fire"]="fire", ["pvp fire"]="fire",
        ["pve frost"]="frost", ["pvp frost"]="frost"
    },
    PALADIN = {
        ["pve holy"]="holy", ["pvp holy"]="holy",
        ["pve prot"]="protection", ["pvp prot"]="protection",
        ["pve ret"]="retribution", ["pvp ret"]="retribution"
    },
    PRIEST = {
        ["pve disc"]="discipline", ["pvp disc"]="discipline",
        ["pve holy"]="holy", ["pvp holy"]="holy",
        ["pve shadow"]="shadow", ["pvp shadow"]="shadow"
    },
    ROGUE = {
        ["pve assasination"]="assassination", ["pvp assasination"]="assassination",
        ["pve assassination"]="assassination", ["pvp assassination"]="assassination",
        ["pve combat"]="combat", ["pvp combat"]="combat",
        ["pve subtlety"]="subtlety", ["pvp subtlety"]="subtlety"
    },
    SHAMAN = {
        ["pve elem"]="elemental", ["pvp elem"]="elemental",
        ["pve enhan"]="enhancement", ["pvp enhan"]="enhancement",
        ["pve resto"]="restoration", ["pvp resto"]="restoration"
    },
    WARLOCK = {
        ["pve affli"]="affliction", ["pvp affli"]="affliction",
        ["pve demo"]="demonology", ["pvp demo"]="demonology",
        ["pve destro"]="destruction", ["pvp destro"]="destruction"
    },
    WARRIOR = {
        ["pve arms"]="arms", ["pvp arms"]="arms",
        ["pve fury"]="fury", ["pvp fury"]="fury",
        ["pve prot"]="protection", ["pvp prot"]="protection"
    },
    DEATHKNIGHT = {
        ["pve blood"]="blood", ["pvp blood"]="blood",
        ["pve frost"]="frost", ["pvp frost"]="frost",
        ["pve unholy"]="unholy", ["pvp unholy"]="unholy"
    }
}

-- Some server build families are named for a hybrid talent layout rather than
-- the job the bot should perform. Resolve those unambiguous families before
-- ordinary tree-name matching (for example, "furyprot" contains "fury" but
-- is intended to tank). New server-specific families can be added here
-- without hardcoding every complete build name.
local MTPB_TALENT_AI_PRIORITY_RULES = {
    WARRIOR = {
        {strategy="protection", phrases={"furyprot", "fury prot", "fury/prot", "prot fury", "prot/fury"}}
    }
}

local function MTPB_Chat(text)
    if DEFAULT_CHAT_FRAME then
        DEFAULT_CHAT_FRAME:AddMessage(MTPB_COLORS.green .. "ManTechPB:|r " .. text)
    end
end

local function MTPB_SetStatus(text, color)
    local formatted = (color or MTPB_COLORS.gray) .. text .. "|r"
    if MTPB_STATUS then
        MTPB_STATUS:SetText(formatted)
    end
    if MTPB_FOCUS_STATUS then MTPB_FOCUS_STATUS:SetText(formatted) end
end

local function MTPB_UpdateChatToggleButton()
    if MTPB_CHAT_TOGGLE_BUTTON then
        MTPB_CHAT_TOGGLE_BUTTON:SetText(ManTechPBDB and ManTechPBDB.hideBotReplies and "Bot Chat: Hidden" or "Bot Chat: Shown")
    end
end

local function MTPB_SetBotChatHidden(hidden)
    if not ManTechPBDB then ManTechPBDB = {} end
    ManTechPBDB.hideBotReplies = hidden and true or false
    MTPB_UpdateChatToggleButton()
    MTPB_SetStatus("Bot command messages are now " .. (hidden and "hidden. Use /mtp chat to show them." or "shown."), hidden and MTPB_COLORS.green or MTPB_COLORS.yellow)
end

local function MTPB_ToggleBotChat()
    MTPB_SetBotChatHidden(not (ManTechPBDB and ManTechPBDB.hideBotReplies))
end

local function MTPB_NormalizeClass(value)
    if not value then return nil end
    local result = string.upper(value)
    result = string.gsub(result, "[^A-Z]", "")
    if result == "DEATHKNIGHT" or result == "DEATHKNIGHTCLASS" then return "DEATHKNIGHT" end
    if string.sub(result, 1, 5) == "CLASS" then result = string.sub(result, 6) end
    return result
end

local function MTPB_ListContains(list, value)
    local i
    if not list then return false end
    for i = 1, table.getn(list) do
        if list[i] == value then return true end
    end
    return false
end

local function MTPB_ListContainsStrategy(list, strategy)
    if MTPB_ListContains(list, strategy) then return true end
    if strategy == "offdps" then
        return MTPB_ListContains(list, "offdps pve") or
            MTPB_ListContains(list, "offdps pvp") or
            MTPB_ListContains(list, "offdps raid")
    end
    return false
end

local function MTPB_GetPendingStrategy(strategy)
    local botPending = MTPB_SELECTED and MTPB_PENDING_STRATEGIES[MTPB_SELECTED]
    return botPending and botPending[strategy]
end

local function MTPB_BeginPendingStrategy(strategy, contexts, wanted, label, acceptDelay)
    local bot = MTPB_SELECTED
    if not bot then return end
    if not MTPB_PENDING_STRATEGIES[bot] then MTPB_PENDING_STRATEGIES[bot] = {} end
    local delay = acceptDelay or 0
    local request = {wanted=wanted, contexts=contexts, seen={}, matches={}, label=label, acceptAfter=GetTime()+delay}
    MTPB_PENDING_STRATEGIES[bot][strategy] = request
    MTPB_SetStatus((wanted and "Enabling " or "Disabling ") .. label .. " for " .. bot .. "; waiting for confirmation...", MTPB_COLORS.yellow)
    MTPB_Wait(delay + 10, function(expectedBot, expectedStrategy, expectedRequest)
        local pending = MTPB_PENDING_STRATEGIES[expectedBot]
        if pending and pending[expectedStrategy] == expectedRequest then
            pending[expectedStrategy] = nil
            MTPB_SetStatus(expectedBot .. " did not confirm " .. expectedRequest.label .. ". Its last confirmed setting is shown.", MTPB_COLORS.red)
            if MTPB_QuerySelectedBot then MTPB_QuerySelectedBot(expectedBot) end
        end
    end, bot, strategy, request)
end

MTPB_CheckPendingStrategyReply = function(bot, context, list)
    local pending = MTPB_PENDING_STRATEGIES[bot]
    if not pending then return end
    local strategy, request, i, allSeen, allMatch
    for strategy, request in pairs(pending) do
        for i = 1, table.getn(request.contexts) do
            if request.contexts[i] == context then
                local matchesWanted = MTPB_ListContainsStrategy(list, strategy) == request.wanted
                -- A reply that already shows the requested state is safe to
                -- accept immediately. Only delay a contradictory reply, which
                -- may be stale output from the refresh sent before this click.
                if matchesWanted or GetTime() >= (request.acceptAfter or 0) then
                    request.seen[context] = true
                    request.matches[context] = matchesWanted
                end
            end
        end
        allSeen, allMatch = true, true
        for i = 1, table.getn(request.contexts) do
            context = request.contexts[i]
            if not request.seen[context] then allSeen = false end
            if request.seen[context] and not request.matches[context] then allMatch = false end
        end
        if allSeen then
            pending[strategy] = nil
            if allMatch then
                MTPB_SetStatus(bot .. " confirmed " .. request.label .. " " .. (request.wanted and "ON." or "OFF."), MTPB_COLORS.green)
            else
                MTPB_SetStatus(bot .. " rejected or did not retain " .. request.label .. ". Its confirmed setting is shown.", MTPB_COLORS.red)
            end
        end
    end
end

if type(MTPB_TEST_HOOKS) == "table" then
    MTPB_TEST_HOOKS.HasPendingStrategy = function(bot, strategy)
        return MTPB_PENDING_STRATEGIES[bot] and MTPB_PENDING_STRATEGIES[bot][strategy] ~= nil
    end
end

local function MTPB_CurrentBotData()
    if not MTPB_SELECTED or not MTPB_BOTS then return nil end
    return MTPB_BOTS[MTPB_SELECTED]
end

local function MTPB_GetSelectedClass()
    local data = MTPB_CurrentBotData()
    if data and data.class then return MTPB_NormalizeClass(data.class) end
    local i, name
    for i = 1, 40 do
        name = UnitName("raid" .. i)
        if name == MTPB_SELECTED then
            local _, class = UnitClass("raid" .. i)
            return MTPB_NormalizeClass(class)
        end
        if i <= 4 then
            name = UnitName("party" .. i)
            if name == MTPB_SELECTED then
                local _, class = UnitClass("party" .. i)
                return MTPB_NormalizeClass(class)
            end
        end
    end
    if UnitName("target") == MTPB_SELECTED then
        local _, class = UnitClass("target")
        return MTPB_NormalizeClass(class)
    end
    return nil
end

local function MTPB_PartyBotNames()
    local names = {}
    local seen = {}
    local count = GetNumRaidMembers and GetNumRaidMembers() or 0
    local prefix = "raid"
    if count == 0 then
        count = GetNumPartyMembers and GetNumPartyMembers() or 0
        prefix = "party"
    end
    local i, name
    for i = 1, count do
        name = UnitName(prefix .. i)
        if name and name ~= UnitName("player") and MTPB_BOTS and MTPB_BOTS[name] and not seen[name] then
            table.insert(names, name)
            seen[name] = true
        end
    end
    table.sort(names)
    return names
end

local function MTPB_AllBotNames()
    local names = {}
    local name
    for name in pairs(MTPB_BOTS) do table.insert(names, name) end
    table.sort(names)
    return names
end

local function MTPB_AltBotNames()
    local party = {}
    local partyNames = MTPB_PartyBotNames()
    local i, name
    for i = 1, table.getn(partyNames) do party[partyNames[i]] = true end
    local names = {}
    for name in pairs(MTPB_BOTS) do
        if not party[name] then table.insert(names, name) end
    end
    table.sort(names)
    return names
end

local function MTPB_SendCommands(commands, label, suppressAutomaticRefresh)
    if not MTPB_SendBotCommand then
        MTPB_SetStatus("ManTechPB command transport is unavailable.", MTPB_COLORS.red)
        return false
    end
    local combined = ""
    local i
    for i = 1, table.getn(commands) do
        if combined ~= "" then combined = combined .. MTPB_COMMAND_SEPARATOR end
        combined = combined .. commands[i]
    end
    if combined == "" then return false end
    local sent
    if MTPB_SELECTED then
        sent = MTPB_SendBotCommand(combined, "WHISPER", nil, MTPB_SELECTED)
    else
        if MTPB_PartySize and MTPB_PartySize() == 0 then
            MTPB_SetStatus("Join a party with PlayerBots first.", MTPB_COLORS.red)
            return false
        end
        sent = MTPB_SendBotCommand(combined, "PARTY")
    end
    if sent ~= false then
        MTPB_SetStatus("Sent " .. label .. " to " .. (MTPB_SELECTED or "party") .. ".", MTPB_COLORS.green)
        if MTPB_Wait and not suppressAutomaticRefresh then
            MTPB_Wait(0.9, function()
                if MTPB_SELECTED and MTPB_QuerySelectedBot then MTPB_QuerySelectedBot(MTPB_SELECTED)
                elseif MTPB_QueryBotParty then MTPB_QueryBotParty() end
            end)
        end
        return true
    end
    MTPB_SetStatus("The ManTechPB command queue rejected that action.", MTPB_COLORS.red)
    return false
end

local function MTPB_SendDirect(text, label, requiresTarget)
    if requiresTarget and (not UnitExists("target") or not UnitCanAttack("player", "target")) then
        MTPB_SetStatus("Select an attackable target first.", MTPB_COLORS.red)
        return
    end
    if MTPB_SELECTED then
        MTPB_SendCommands({text}, label)
    else
        if MTPB_PartySize and MTPB_PartySize() == 0 then
            MTPB_SetStatus("Join a party with PlayerBots first.", MTPB_COLORS.red)
            return
        end
        SendChatMessage(text, "PARTY")
        MTPB_SetStatus("Sent " .. label .. " to party.", MTPB_COLORS.green)
    end
end

-- offdps is a combat-only PlayerBots strategy. The core may report its
-- environment variants (offdps pve/pvp/raid) in the combat list, but it does
-- not mirror them into non-combat. Requiring nc made the UI show a false OFF
-- state and made a click try to enable an already-enabled strategy.
local function MTPB_NormalizeStrategyContexts(strategy, contexts)
    if strategy == "offdps" then return {"co"} end
    return contexts or {}
end

local function MTPB_StrategyState(strategy, contexts)
    contexts = MTPB_NormalizeStrategyContexts(strategy, contexts)
    local names = {}
    if MTPB_SELECTED then table.insert(names, MTPB_SELECTED)
    else names = MTPB_PartyBotNames() end
    if table.getn(names) == 0 then return false, false end
    local total, active = 0, 0
    local i, j
    for i = 1, table.getn(names) do
        local data = MTPB_BOTS and MTPB_BOTS[names[i]]
        local every = true
        if not data or not data.strategy then
            every = false
        else
            for j = 1, table.getn(contexts) do
                if not MTPB_ListContainsStrategy(data.strategy[contexts[j]], strategy) then every = false end
            end
        end
        total = total + 1
        if every then active = active + 1 end
    end
    return active == total, active > 0 and active < total
end

local function MTPB_BuildToggleStrategyCommands(strategy, contexts, allActive)
    contexts = MTPB_NormalizeStrategyContexts(strategy, contexts)
    local operation = allActive and "-" or "+"
    local commands = {}
    local i
    for i = 1, table.getn(contexts) do
        local changes = operation .. strategy
        if strategy == "offdps" and operation == "-" then
            changes = "-offdps,-offdps pve,-offdps pvp,-offdps raid"
        end
        table.insert(commands, "#a " .. contexts[i] .. " " .. changes .. ",?")
    end
    return commands
end

local function MTPB_ToggleStrategy(strategy, contexts, label)
    contexts = MTPB_NormalizeStrategyContexts(strategy, contexts)
    local allActive = MTPB_StrategyState(strategy, contexts)
    local commands = MTPB_BuildToggleStrategyCommands(strategy, contexts, allActive)
    if MTPB_SendCommands(commands, (allActive and "disable " or "enable ") .. label) then
        MTPB_BeginPendingStrategy(strategy, contexts, not allActive, label)
    end
end

if type(MTPB_TEST_HOOKS) == "table" then
    MTPB_TEST_HOOKS.NormalizeStrategyContexts = MTPB_NormalizeStrategyContexts
    MTPB_TEST_HOOKS.StrategyState = MTPB_StrategyState
    MTPB_TEST_HOOKS.BuildToggleStrategyCommands = MTPB_BuildToggleStrategyCommands
    MTPB_TEST_HOOKS.SetStrategyFixture = function(name, strategyData)
        MTPB_SELECTED = name
        MTPB_BOTS[name] = {strategy=strategyData}
    end
end

local function MTPB_SetExclusive(addStrategy, removeStrategy, contexts, label)
    local commands = {}
    local i
    for i = 1, table.getn(contexts) do
        table.insert(commands, "#a " .. contexts[i] .. " -" .. removeStrategy .. ",+" .. addStrategy .. ",?")
    end
    MTPB_SendCommands(commands, label)
end

local function MTPB_ApplySpec(spec)
    if not MTPB_SELECTED then
        MTPB_SetStatus("Choose one bot before changing its role or spec.", MTPB_COLORS.red)
        return
    end
    local remove = ""
    local i
    local selectedClass = MTPB_GetSelectedClass()
    local classSpecs = MTPB_SPECS[selectedClass] or {}
    for i = 1, table.getn(classSpecs) do
        if classSpecs[i].strategy ~= spec.strategy then remove = remove .. ",-" .. classSpecs[i].strategy end
    end
    remove = remove .. ",-heal,-tank,-bear"
    local combatExtras = ",+dps assist,-tank assist,+close,-ranged,-pull,-pull back,+behind"
    local nonCombatExtras = ",+dps assist,-tank assist"
    if spec.role == "tank" then
        combatExtras = ",+tank assist,-dps assist,+close,-ranged,+pull,+pull back,-behind"
        nonCombatExtras = ",+tank assist,-dps assist"
    elseif spec.role == "heal" or spec.role == "ranged" then
        combatExtras = ",+dps assist,-tank assist,+ranged,-close,-pull,-pull back,-behind"
    end
    if selectedClass == "DEATHKNIGHT" then
        if spec.strategy == "frost" then combatExtras = combatExtras .. ",+frost aoe,-unholy aoe"
        elseif spec.strategy == "unholy" then combatExtras = combatExtras .. ",+unholy aoe,-frost aoe"
        else combatExtras = combatExtras .. ",-frost aoe,-unholy aoe" end
    end
    -- Only the combat command requests a reply because that is the context used
    -- to confirm the selected role.  Querying every context made one click dump
    -- four long strategy lists into chat.
    local commands = {"#a co " .. string.sub(remove, 2) .. ",+" .. spec.strategy .. combatExtras .. ",?"}
    if selectedClass ~= "DEATHKNIGHT" then
        table.insert(commands, "#a nc " .. string.sub(remove, 2) .. ",+" .. spec.strategy .. nonCombatExtras)
        table.insert(commands, "#a de " .. string.sub(remove, 2) .. ",+" .. spec.strategy)
        table.insert(commands, "#a react " .. string.sub(remove, 2) .. ",+" .. spec.strategy)
    else
        table.insert(commands, "#a nc " .. string.sub(nonCombatExtras, 2))
    end
    if MTPB_SendCommands(commands, "apply " .. spec.name, true) then
        -- Only accept replies produced after every queued role command has had
        -- time to leave the client. Replies from the manager's earlier state
        -- refresh otherwise make a successful role change look rejected.
        local confirmContexts = {"co"}
        local confirmationDelay = math.max(1.5, table.getn(MTPB_SEND_QUEUE) * 0.32 + 0.35)
        MTPB_BeginPendingStrategy(spec.strategy, confirmContexts, true, spec.name, confirmationDelay + 0.15)
        MTPB_Wait(confirmationDelay, function(expectedBot, expectedContexts)
            if MTPB_SELECTED == expectedBot then MTPB_QueryStrategyConfirmation(expectedBot, expectedContexts) end
        end, MTPB_SELECTED, confirmContexts)
    end
end

local function MTPB_SetCardState(card, active, mixed, pending)
    if not card then return end
    if pending then
        card:SetBackdropBorderColor(1.00, 0.72, 0.16, 1)
        card.check:SetText("...")
        card.check:SetTextColor(1, 0.78, 0.22)
    elseif mixed then
        card:SetBackdropBorderColor(0.95, 0.70, 0.20, 1)
        card.check:SetText("~")
        card.check:SetTextColor(1, 0.75, 0.2)
    elseif active then
        card:SetBackdropBorderColor(0.20, 0.90, 0.45, 1)
        card.check:SetText("+")
        card.check:SetTextColor(0.25, 1, 0.45)
    else
        card:SetBackdropBorderColor(0.20, 0.52, 0.70, 0.92)
        card.check:SetText("")
    end
end

local function MTPB_CreateCard(parent, x, y, width, title, description, icon, click)
    local card = CreateFrame("Button", nil, parent)
    card:SetWidth(width)
    card:SetHeight(48)
    card:SetPoint("TOPLEFT", parent, "TOPLEFT", x, y)
    card:EnableMouse(true)
    card:RegisterForClicks("LeftButtonUp")
    card:SetBackdrop({
        bgFile="Interface\\Tooltips\\UI-Tooltip-Background",
        edgeFile="Interface\\Tooltips\\UI-Tooltip-Border",
        tile=true, tileSize=16, edgeSize=10,
        insets={left=3,right=3,top=3,bottom=3}
    })
    card:SetBackdropColor(0.045, 0.095, 0.135, 0.98)
    card:SetBackdropBorderColor(0.20, 0.52, 0.70, 0.92)

    card.shine = card:CreateTexture(nil, "OVERLAY")
    card.shine:SetTexture("Interface\\Buttons\\UI-Listbox-Highlight2")
    card.shine:SetPoint("TOPLEFT", card, "TOPLEFT", 5, -4)
    card.shine:SetPoint("TOPRIGHT", card, "TOPRIGHT", -5, -4)
    card.shine:SetHeight(5)
    card.shine:SetVertexColor(0.45, 0.82, 1.00, 0.20)

    card.icon = card:CreateTexture(nil, "ARTWORK")
    card.icon:SetWidth(30)
    card.icon:SetHeight(30)
    card.icon:SetPoint("LEFT", card, "LEFT", 8, 0)
    card.icon:SetTexture("Interface\\Icons\\" .. (icon or "INV_Misc_QuestionMark"))
    card.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)

    card.title = card:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    card.title:SetPoint("TOPLEFT", card, "TOPLEFT", 45, -8)
    card.title:SetWidth(width - 58)
    card.title:SetJustifyH("LEFT")
    card.title:SetText(title)
    ManTechPB_SetReadableFont(card.title, 12, "OUTLINE")

    card.description = card:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    card.description:SetPoint("TOPLEFT", card.title, "BOTTOMLEFT", 0, -2)
    card.description:SetWidth(width - 58)
    card.description:SetJustifyH("LEFT")
    card.description:SetTextColor(0.65, 0.72, 0.80)
    card.description:SetText(description or "")
    ManTechPB_SetReadableFont(card.description, 11, "")

    card.check = card:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    card.check:SetPoint("TOPRIGHT", card, "TOPRIGHT", -7, -6)

    card:SetScript("OnClick", click)
    card:SetScript("OnEnter", function(self)
        local owner = self or this
        owner:SetBackdropColor(0.08, 0.17, 0.23, 1)
    end)
    card:SetScript("OnLeave", function(self)
        local owner = self or this
        owner:SetBackdropColor(0.045, 0.095, 0.135, 0.98)
    end)
    return card
end

local function MTPB_AddHeading(panel, text, y)
    local line = panel:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    line:SetPoint("TOPLEFT", panel, "TOPLEFT", 4, y)
    line:SetText(MTPB_COLORS.blue .. text .. "|r")
    ManTechPB_SetReadableFont(line, 12, "OUTLINE")
    return line
end

local function MTPB_RegisterStateCard(card, strategy, contexts)
    card.mtbmStrategy = strategy
    card.mtbmContexts = contexts
    table.insert(MTPB_STATE_CARDS, card)
end

local function MTPB_CreateHome(panel)
    MTPB_AddHeading(panel, "COMMON ORDERS", -4)
    local data = {
        {"Attack Target", "Attack what I have targeted", "Ability_DualWield", function() MTPB_SendDirect("attack", "attack", true) end},
        {"Follow Me", "Return to normal follow behavior", "Ability_Hunter_BeastCall", function() MTPB_SendCommands({"#a follow ?"}, "follow") end},
        {"Stay Here", "Hold this exact location", "Spell_Nature_TimeStop", function() MTPB_SendCommands({"#a stay ?"}, "stay") end},
        {"Come to Me", "Summon bots to your position", "Spell_Shadow_Twilight", function() MTPB_SendDirect("summon", "summon") end},
        {"Retreat", "Break combat and return to me", "Ability_Rogue_FeignDeath", function() MTPB_SendCommands({"#a flee ?"}, "retreat") end},
        {"Reset AI", "Clear a stuck action or decision", "INV_Misc_PocketWatch_01", function() MTPB_SendDirect("reset", "reset") end},
        {"Free Roam", "Allow independent movement", "Ability_Rogue_Sprint", function() MTPB_SendCommands({"#a free ?"}, "free movement") end},
        {"Refresh", "Ask bots for current settings", "INV_Misc_Spyglass_03", function()
            if MTPB_UpdateBotList then MTPB_UpdateBotList(0) end
            if MTPB_SELECTED and MTPB_QuerySelectedBot then MTPB_QuerySelectedBot(MTPB_SELECTED)
            elseif MTPB_QueryBotParty then MTPB_QueryBotParty() end
            MTPB_SetStatus("Refreshing bot roster and settings...", MTPB_COLORS.yellow)
        end}
    }
    local i, x, y
    for i = 1, table.getn(data) do
        x = ((i - 1) - math.floor((i - 1) / 2) * 2) * 190 + 4
        y = -28 - math.floor((i - 1) / 2) * 57
        MTPB_CreateCard(panel, x, y, 182, data[i][1], data[i][2], data[i][3], data[i][4])
    end
    local note = panel:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    note:SetPoint("BOTTOMLEFT", panel, "BOTTOMLEFT", 8, 8)
    note:SetWidth(370)
    note:SetJustifyH("LEFT")
    note:SetText(MTPB_COLORS.gray .. "Start here for normal play. Select Party or one bot on the left before issuing an order.|r")
    ManTechPB_SetReadableFont(note, 11, "")
end

local function MTPB_TalentStatus(text, color)
    if MTPB_TALENT_STATUS then
        MTPB_TALENT_STATUS:SetText((color or MTPB_COLORS.gray) .. (text or "") .. "|r")
    end
end

local function MTPB_TalentBuildMatches(buildName, candidate)
    local build = string.lower(buildName or "")
    local value = string.lower(candidate or "")
    return value ~= "" and string.find(build, value, 1, true) ~= nil
end

local function MTPB_FindAIForTalentBuild(buildName, requestedClass)
    local class = requestedClass or MTPB_GetSelectedClass()
    local specs = class and MTPB_SPECS[class]
    if not specs then return nil end
    local normalizedBuild = string.lower(MTPB_Trim(buildName or ""))
    normalizedBuild = string.gsub(normalizedBuild, "%s+", " ")
    local i, j, spec, list, rule
    local priorityRules = MTPB_TALENT_AI_PRIORITY_RULES[class]
    if priorityRules then
        for i = 1, table.getn(priorityRules) do
            rule = priorityRules[i]
            for j = 1, table.getn(rule.phrases) do
                if string.find(normalizedBuild, rule.phrases[j], 1, true) then
                    for _, spec in pairs(specs) do
                        if spec.strategy == rule.strategy then return spec end
                    end
                end
            end
        end
    end
    local exactStrategy = MTPB_TALENT_AI_MAP[class] and MTPB_TALENT_AI_MAP[class][normalizedBuild]
    if exactStrategy then
        for i = 1, table.getn(specs) do
            if specs[i].strategy == exactStrategy then return specs[i] end
        end
    end
    local aliases = {
        ["tank feral"]={"feral tank","bear","tank"},
        ["dps feral"]={"feral dps","feral damage","cat"},
        ["beast mastery"]={"beast mastery","beast"," bm"},
        ["marksmanship"]={"marksmanship","marksman","marks"," mm"},
        ["survival"]={"survival"," surv"},
        ["assassination"]={"assassination","assasination","assassin"},
        ["protection"]={"protection"," prot"},
        ["restoration"]={"restoration"," resto"},
        ["discipline"]={"discipline"," disc"},
        ["retribution"]={"retribution"," ret"},
        ["elemental"]={"elemental"," elem"," ele"},
        ["enhancement"]={"enhancement"," enhance"," enhan"," enh"},
        ["demonology"]={"demonology"," demo"},
        ["destruction"]={"destruction"," destro"},
        ["affliction"]={"affliction"," affli"}
    }
    for i = 1, table.getn(specs) do
        spec = specs[i]
        if MTPB_TalentBuildMatches(buildName, spec.name) or MTPB_TalentBuildMatches(buildName, spec.strategy) then return spec end
        list = aliases[string.lower(spec.strategy)] or aliases[string.lower(spec.name)]
        if list then
            for j = 1, table.getn(list) do
                if MTPB_TalentBuildMatches(" " .. buildName, list[j]) then return spec end
            end
        end
    end
    return nil
end

local function MTPB_NormalizeTalentBuildName(value)
    local normalized = string.lower(MTPB_Trim(value or ""))
    normalized = string.gsub(normalized, "%s+", " ")
    return normalized
end

local function MTPB_CurrentTalentBuild(message)
    local _, _, build = string.find(message or "", "^[Mm]y current talent spec is:%s*(.-)%s*%([0-9/%-]+%)")
    return build and MTPB_Trim(build) or nil
end

if type(MTPB_TEST_HOOKS) == "table" then
    MTPB_TEST_HOOKS.FindAIForTalentBuild = function(class, buildName)
        return MTPB_FindAIForTalentBuild(buildName, class)
    end
end

local function MTPB_SendTalentCommand(text, botName)
    local target = botName or MTPB_SELECTED
    if not target then return false end
    -- Talent commands are normal Playerbot chat commands.  Do not add the
    -- BOT<TAB> addon-protocol prefix used by the strategy controls.
    return MTPB_SendRawCommand(text, "WHISPER", nil, target)
end

local function MTPB_RefreshTalentWindow()
    if not MTPB_TALENT_FRAME then return end
    if MTPB_TALENT_TITLE then
        MTPB_TALENT_TITLE:SetText(MTPB_COLORS.gold .. "TALENTS" .. MTPB_COLORS.gray .. "  -  " .. MTPB_COLORS.white .. (MTPB_SELECTED or "Select one bot") .. "|r")
    end
    local data = MTPB_SELECTED and MTPB_BOTS[MTPB_SELECTED]
    local builds = data and data.talentBuilds or {}
    local count = table.getn(builds)
    local pages = math.max(1, math.ceil(count / MTPB_TALENT_PAGE_SIZE))
    if MTPB_TALENT_PAGE > pages then MTPB_TALENT_PAGE = pages end
    if MTPB_TALENT_PAGE < 1 then MTPB_TALENT_PAGE = 1 end
    local startAt = (MTPB_TALENT_PAGE - 1) * MTPB_TALENT_PAGE_SIZE
    local i, button, build
    for i = 1, MTPB_TALENT_PAGE_SIZE do
        button = MTPB_TALENT_BUTTONS[i]
        build = builds[startAt + i]
        if button and build then
            button.build = build
            button:SetText(build.name)
            button:Show()
        elseif button then
            button.build = nil
            button:Hide()
        end
    end
    if MTPB_TALENT_PAGE_TEXT then MTPB_TALENT_PAGE_TEXT:SetText("Page " .. MTPB_TALENT_PAGE .. "/" .. pages) end
    if MTPB_TALENT_PREV_BUTTON then
        if MTPB_TALENT_PAGE > 1 then MTPB_TALENT_PREV_BUTTON:Enable() else MTPB_TALENT_PREV_BUTTON:Disable() end
    end
    if MTPB_TALENT_NEXT_BUTTON then
        if MTPB_TALENT_PAGE < pages then MTPB_TALENT_NEXT_BUTTON:Enable() else MTPB_TALENT_NEXT_BUTTON:Disable() end
    end
    if not MTPB_SELECTED then
        MTPB_TalentStatus("Choose one bot from the main roster first.", MTPB_COLORS.yellow)
    elseif table.getn(builds) == 0 and data and data.talentBuildsQueryPending then
        MTPB_TalentStatus("Loading " .. MTPB_SELECTED .. "'s exact server talent builds...", MTPB_COLORS.yellow)
    elseif table.getn(builds) == 0 then
        MTPB_TalentStatus("No server talent builds have been returned. Click Find Builds to try again.", MTPB_COLORS.gray)
    else
        MTPB_TalentStatus(table.getn(builds) .. " talent build" .. (table.getn(builds) == 1 and "" or "s") .. " available. Click one to apply it to this bot.", MTPB_COLORS.green)
    end
end

local function MTPB_RequestTalentBuilds()
    if not MTPB_SELECTED then
        MTPB_TalentStatus("Choose one bot from the main roster first.", MTPB_COLORS.yellow)
        return
    end
    if not MTPB_BOTS[MTPB_SELECTED] then MTPB_BOTS[MTPB_SELECTED] = {} end
    local data = MTPB_BOTS[MTPB_SELECTED]
    -- A refresh must discard cached or partial names.  Build selectors are
    -- server configuration, not universal across Vanilla/TBC/WotLK.
    data.talentBuilds = {}
    data.talentBuildsServer = nil
    data.talentBuildsQueried = true
    data.talentBuildsQueryPending = true
    data.talentBuildsCollectUntil = nil
    MTPB_TALENT_QUERY_BOT = MTPB_SELECTED
    MTPB_TALENT_PAGE = 1
    MTPB_SendTalentCommand("talents list", MTPB_SELECTED)
    MTPB_RefreshTalentWindow()
    MTPB_TalentStatus("Asking " .. MTPB_SELECTED .. " for its exact server talent builds...", MTPB_COLORS.yellow)
    MTPB_Wait(6.0, function(expectedBot)
        local expectedData = MTPB_BOTS[expectedBot]
        if expectedData and expectedData.talentBuildsQueryPending then
            expectedData.talentBuildsQueryPending = nil
            if MTPB_SELECTED == expectedBot then
                MTPB_RefreshTalentWindow()
                MTPB_TalentStatus("No build list reply yet. Click Find Builds to retry; no guessed command was sent.", MTPB_COLORS.yellow)
            end
        end
        if expectedData then expectedData.talentBuildsCollectUntil = nil end
        if MTPB_TALENT_QUERY_BOT == expectedBot then MTPB_TALENT_QUERY_BOT = nil end
    end, MTPB_SELECTED)
end

local function MTPB_ApplyTalentBuild(build)
    if not MTPB_SELECTED or not build or not build.name then return end
    local botName = MTPB_SELECTED
    local buildName = build.name
    local botData = MTPB_BOTS[botName]
    -- Applying a build ends any prior list collection immediately. Otherwise
    -- follow-up notices such as "New spells learned" can arrive while the old
    -- query bot is still remembered and be mistaken for another build row.
    if botData then
        botData.talentBuildsQueryPending = nil
        botData.talentBuildsCollectUntil = nil
    end
    if MTPB_TALENT_QUERY_BOT == botName then MTPB_TALENT_QUERY_BOT = nil end
    local spec = MTPB_FindAIForTalentBuild(buildName)
    MTPB_SendTalentCommand("talents " .. buildName, botName)
    MTPB_TalentStatus("Sent talents " .. buildName .. " privately to " .. botName .. "; waiting for the server.", MTPB_COLORS.yellow)
    if spec then
        local request = {spec=spec, build=buildName, requestedAt=GetTime()}
        MTPB_PENDING_TALENT_SYNCS[botName] = request
        MTPB_Wait(1.2, function(expectedBot, expectedRequest)
            if MTPB_PENDING_TALENT_SYNCS[expectedBot] == expectedRequest then MTPB_SendTalentCommand("talents", expectedBot) end
        end, botName, request)
        MTPB_Wait(3.5, function(expectedBot, expectedRequest)
            if MTPB_PENDING_TALENT_SYNCS[expectedBot] == expectedRequest then MTPB_SendTalentCommand("talents", expectedBot) end
        end, botName, request)
        MTPB_Wait(8.0, function(expectedBot, expectedRequest)
            if MTPB_PENDING_TALENT_SYNCS[expectedBot] == expectedRequest then
                MTPB_PENDING_TALENT_SYNCS[expectedBot] = nil
                MTPB_TalentStatus("The server did not confirm " .. expectedRequest.build .. "; its AI role was not changed.", MTPB_COLORS.red)
            end
        end, botName, request)
    else
        MTPB_TalentStatus("Talent build sent. Choose the matching AI role below if needed.", MTPB_COLORS.yellow)
    end
end

local function MTPB_ParseTalentReply(message, sender)
    if not message or not sender or not MTPB_BOTS[sender] then return false end
    local clean = message
    if string.sub(clean, 1, 4) == "BOT\t" then clean = string.sub(clean, 5) end
    clean = string.gsub(clean, "|c%x%x%x%x%x%x%x%x", "")
    clean = string.gsub(clean, "|r", "")
    clean = string.gsub(clean, "|h", "")
    clean = MTPB_Trim(clean)

    local lower = string.lower(clean)
    if string.find(lower, "no predefined talents", 1, true) then
        local wasQueryBot = sender == MTPB_TALENT_QUERY_BOT
        MTPB_BOTS[sender].talentBuildsQueryPending = nil
        MTPB_BOTS[sender].talentBuildsCollectUntil = nil
        if wasQueryBot then
            MTPB_TALENT_QUERY_BOT = nil
            MTPB_TalentStatus("The server returned no predefined talent builds; no guessed commands will be shown.", MTPB_COLORS.yellow)
        end
        return true
    end


    -- A current-spec response also contains a parenthesized talent layout.
    -- Handle it before the build-list parser so it never becomes a fake build
    -- button.  The confirmed response is also the safe point to synchronize
    -- the corresponding AI role.
    local currentBuild = MTPB_CurrentTalentBuild(clean)
    if currentBuild then
        MTPB_BOTS[sender].talentStatus = currentBuild
        MTPB_BOTS[sender].currentTalentBuild = currentBuild
        if MTPB_TALENT_FRAME and MTPB_TALENT_FRAME:IsVisible() and sender == MTPB_SELECTED then
            MTPB_TalentStatus("Current spec: " .. currentBuild, MTPB_COLORS.green)
        end
        if sender == MTPB_SELECTED then MTPB_SetStatus("Current spec: " .. currentBuild .. ".", MTPB_COLORS.green) end
        if sender == MTPB_VISIBLE_TALENT_QUERY_BOT then
            MTPB_VISIBLE_TALENT_QUERY_BOT = nil
            MTPB_VISIBLE_TALENT_QUERY_UNTIL = 0
        end
        local pendingSync = MTPB_PENDING_TALENT_SYNCS[sender]
        if pendingSync and MTPB_NormalizeTalentBuildName(currentBuild) == MTPB_NormalizeTalentBuildName(pendingSync.build) then
            MTPB_PENDING_TALENT_SYNCS[sender] = nil
            MTPB_TalentStatus(currentBuild .. " confirmed; synchronizing the matching AI role...", MTPB_COLORS.yellow)
            MTPB_Wait(0.2, function(expectedBot, expectedSpec, expectedBuild)
                if MTPB_SELECTED == expectedBot then
                    MTPB_ApplySpec(expectedSpec)
                    MTPB_TalentStatus(expectedBuild .. " confirmed; waiting for AI-role confirmation.", MTPB_COLORS.yellow)
                end
            end, sender, pendingSync.spec, pendingSync.build)
        end
        return true
    end

    local found = false
    local senderData = MTPB_BOTS[sender]
    local collectingBuilds = sender == MTPB_TALENT_QUERY_BOT and
        (senderData.talentBuildsQueryPending or
        (senderData.talentBuildsCollectUntil and senderData.talentBuildsCollectUntil >= GetTime()))
    -- Only consume replies during an active Find Builds request. Spell and
    -- item links are never talent build names and must not reach this parser.
    if collectingBuilds and
        not string.find(clean, "|H", 1, true) and
        not string.find(lower, "new spells learned:", 1, true) then
        local pieces = MTPB_Split(clean, ",")
        local parsed = {}
        local i, piece, name, layout, j, duplicate
        if not senderData.talentBuilds then senderData.talentBuilds = {} end
        for i = 1, table.getn(pieces) do
            piece = MTPB_Trim(pieces[i])
            -- A real talent layout has at least one tree separator (21/0/0 or
            -- 0-0-053...). A spell id such as (15430) therefore cannot match.
            local _, _, capturedName, capturedLayout = string.find(piece, "^(.-)%s*%(([0-9]+[/%-][0-9/%-]*)%)[%.;]?%s*$")
            name, layout = capturedName, capturedLayout
            if name and layout then
                name = MTPB_Trim(name)
                name = string.gsub(name, "^Found multiple specs:%s*", "")
                name = string.gsub(name, "^Found [0-9]+ possible specs to choose from%.%s*", "")
                if name ~= "" then table.insert(parsed, {name=name, layout=layout}) end
            end
        end
        if table.getn(parsed) > 0 then
            senderData.talentBuildsQueryPending = nil
            senderData.talentBuildsCollectUntil = GetTime() + 0.75
            if not senderData.talentBuildsServer then
                senderData.talentBuilds = {}
                senderData.talentBuildsServer = true
                MTPB_TALENT_PAGE = 1
            end
            for i = 1, table.getn(parsed) do
                name = parsed[i].name
                duplicate = false
                for j = 1, table.getn(senderData.talentBuilds) do
                    if string.lower(senderData.talentBuilds[j].name or "") == string.lower(name) then duplicate = true end
                end
                if not duplicate then table.insert(senderData.talentBuilds, parsed[i]); found = true end
            end
        end
        if found then
            MTPB_RefreshTalentWindow()
            return true
        end
    end

    if string.find(lower, "talent", 1, true) or string.find(lower, "spec", 1, true) then
        MTPB_BOTS[sender].talentStatus = clean
        if MTPB_TALENT_FRAME and MTPB_TALENT_FRAME:IsVisible() and sender == MTPB_SELECTED then
            MTPB_TalentStatus(clean, MTPB_COLORS.green)
        end
        return true
    end
    return false
end

if type(MTPB_TEST_HOOKS) == "table" then
    MTPB_TEST_HOOKS.GetCurrentTalentBuild = function(bot)
        return MTPB_BOTS[bot] and MTPB_BOTS[bot].currentTalentBuild
    end
end

local function MTPB_CreateTalentFrame()
    if MTPB_TALENT_FRAME then return end
    local frame = CreateFrame("Frame", "ManTechPBTalentFrame", UIParent)
    MTPB_TALENT_FRAME = frame
    frame:SetWidth(430); frame:SetHeight(300); frame:SetFrameStrata("DIALOG"); frame:SetScale(1.06)
    frame:SetMovable(true); frame:EnableMouse(true); frame:SetClampedToScreen(true)
    frame:SetBackdrop({bgFile="Interface\\DialogFrame\\UI-DialogBox-Background",edgeFile="Interface\\DialogFrame\\UI-DialogBox-Border",tile=true,tileSize=32,edgeSize=24,insets={left=8,right=8,top=8,bottom=8}})
    frame:SetBackdropColor(0.025,0.035,0.055,0.98)
    frame:SetPoint("CENTER", UIParent, "CENTER", 40, 20)

    -- Keep the transparent drag target out of the Help button's hit rectangle.
    -- Older clients do not consistently resolve overlapping sibling buttons by
    -- creation order, so the drag target must be physically non-overlapping.
    local drag = CreateFrame("Button", "ManTechPBTalentDragRegion", frame)
    drag:SetPoint("TOPLEFT", frame, "TOPLEFT", 10, -7); drag:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -90, -7); drag:SetHeight(28)
    drag:RegisterForDrag("LeftButton")
    drag:SetScript("OnDragStart", function() MTPB_TALENT_FRAME:StartMoving() end)
    drag:SetScript("OnDragStop", function() MTPB_TALENT_FRAME:StopMovingOrSizing() end)
    MTPB_TALENT_TITLE = frame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    MTPB_TALENT_TITLE:SetPoint("TOPLEFT", frame, "TOPLEFT", 18, -15)
    MTPB_TALENT_TITLE:SetWidth(300); MTPB_TALENT_TITLE:SetJustifyH("LEFT")
    ManTechPB_SetReadableFont(MTPB_TALENT_TITLE, 13, "OUTLINE")
    local close = CreateFrame("Button", nil, frame, "UIPanelCloseButton")
    close:SetPoint("TOPRIGHT", frame, "TOPRIGHT", 3, 3); close:SetScript("OnClick", function() MTPB_TALENT_FRAME:Hide() end)
    local help = CreateFrame("Button", "ManTechPBTalentHelpButton", frame, "UIPanelButtonTemplate")
    help:SetWidth(48); help:SetHeight(24); help:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -34, -8); help:SetText("Help"); ManTechPB_StyleButton(help, 12)
    help:RegisterForClicks("LeftButtonUp")
    help:SetScript("OnClick", function() ManTechPB_ShowHelp("TALENTS") end)

    local find = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
    find:SetWidth(94); find:SetHeight(24); find:SetPoint("TOPLEFT", frame, "TOPLEFT", 18, -43); find:SetText("Find Builds")
    ManTechPB_StyleButton(find, 12)
    find:SetScript("OnClick", MTPB_RequestTalentBuilds)
    local current = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
    current:SetWidth(88); current:SetHeight(24); current:SetPoint("LEFT", find, "RIGHT", 5, 0); current:SetText("Current")
    ManTechPB_StyleButton(current, 12)
    current:SetScript("OnClick", function()
        if MTPB_SELECTED then
            -- Keep this selected-bot query visible even when routine bot chat
            -- is hidden. Party chat cannot name-target one exact bot, so a
            -- whisper preserves scope while still showing the request/reply.
            MTPB_VISIBLE_TALENT_QUERY_BOT = MTPB_SELECTED
            MTPB_VISIBLE_TALENT_QUERY_UNTIL = GetTime() + 10
            MTPB_SendTalentCommand("talents", MTPB_SELECTED)
            MTPB_TalentStatus("Checking " .. MTPB_SELECTED .. "'s current spec; reply will also appear in chat.", MTPB_COLORS.yellow)
        end
    end)
    local auto = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
    auto:SetWidth(88); auto:SetHeight(24); auto:SetPoint("LEFT", current, "RIGHT", 5, 0); auto:SetText("Auto Pick")
    ManTechPB_StyleButton(auto, 12)
    auto:SetScript("OnClick", function()
        if MTPB_SELECTED then MTPB_SendTalentCommand("talents auto", MTPB_SELECTED); MTPB_TalentStatus("Asked the server to auto-pick talents.", MTPB_COLORS.yellow) end
    end)
    local reset = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
    reset:SetWidth(105); reset:SetHeight(24); reset:SetPoint("LEFT", auto, "RIGHT", 5, 0); reset:SetText("Reset Talents")
    ManTechPB_StyleButton(reset, 12)
    reset:SetScript("OnClick", function(self)
        local owner = self or this
        if not MTPB_SELECTED then MTPB_TalentStatus("Choose one bot first.", MTPB_COLORS.yellow); return end
        if owner.confirmUntil and owner.confirmUntil >= GetTime() then
            MTPB_SendTalentCommand("talents reset", MTPB_SELECTED)
            owner.confirmUntil = nil; owner:SetText("Reset Talents")
            MTPB_TalentStatus("Talent reset sent to " .. MTPB_SELECTED .. ".", MTPB_COLORS.yellow)
        else
            owner.confirmUntil = GetTime() + 5; owner:SetText("Confirm Reset")
            MTPB_TalentStatus("Click Confirm Reset within five seconds.", MTPB_COLORS.red)
        end
    end)
    reset:SetScript("OnUpdate", function(self)
        local owner = self or this
        if owner.confirmUntil and owner.confirmUntil < GetTime() then owner.confirmUntil=nil; owner:SetText("Reset Talents") end
    end)

    local heading = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    heading:SetPoint("TOPLEFT", frame, "TOPLEFT", 20, -76); heading:SetText(MTPB_COLORS.blue .. "TALENT BUILDS|r")
    ManTechPB_SetReadableFont(heading, 12, "OUTLINE")
    local previousPage = CreateFrame("Button", "ManTechPBTalentPreviousButton", frame, "UIPanelButtonTemplate")
    MTPB_TALENT_PREV_BUTTON = previousPage
    previousPage:SetWidth(54); previousPage:SetHeight(20); previousPage:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -116, -70); previousPage:SetText("< Prev")
    ManTechPB_StyleButton(previousPage, 11)
    previousPage:SetScript("OnClick", function()
        if MTPB_TALENT_PAGE > 1 then MTPB_TALENT_PAGE = MTPB_TALENT_PAGE - 1; MTPB_RefreshTalentWindow() end
    end)
    MTPB_TALENT_PAGE_TEXT = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    MTPB_TALENT_PAGE_TEXT:SetPoint("LEFT", previousPage, "RIGHT", 4, 0); MTPB_TALENT_PAGE_TEXT:SetWidth(50); MTPB_TALENT_PAGE_TEXT:SetJustifyH("CENTER")
    local nextPage = CreateFrame("Button", "ManTechPBTalentNextButton", frame, "UIPanelButtonTemplate")
    MTPB_TALENT_NEXT_BUTTON = nextPage
    nextPage:SetWidth(54); nextPage:SetHeight(20); nextPage:SetPoint("LEFT", MTPB_TALENT_PAGE_TEXT, "RIGHT", 4, 0); nextPage:SetText("Next >")
    ManTechPB_StyleButton(nextPage, 11)
    nextPage:SetScript("OnClick", function()
        local data = MTPB_SELECTED and MTPB_BOTS[MTPB_SELECTED]
        local count = data and data.talentBuilds and table.getn(data.talentBuilds) or 0
        local pages = math.max(1, math.ceil(count / MTPB_TALENT_PAGE_SIZE))
        if MTPB_TALENT_PAGE < pages then MTPB_TALENT_PAGE = MTPB_TALENT_PAGE + 1; MTPB_RefreshTalentWindow() end
    end)
    local i, button, col, row
    for i = 1, MTPB_TALENT_PAGE_SIZE do
        col = (i - 1) - math.floor((i - 1) / 2) * 2
        row = math.floor((i - 1) / 2)
        button = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
        button:SetWidth(192); button:SetHeight(27)
        button:SetPoint("TOPLEFT", frame, "TOPLEFT", 18 + col*199, -94 - row*30)
        ManTechPB_StyleButton(button, 12)
        button:SetScript("OnClick", function(self) local owner=self or this; MTPB_ApplyTalentBuild(owner.build) end)
        button:Hide(); MTPB_TALENT_BUTTONS[i] = button
    end
    MTPB_TALENT_STATUS = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    MTPB_TALENT_STATUS:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", 18, 15); MTPB_TALENT_STATUS:SetWidth(394); MTPB_TALENT_STATUS:SetJustifyH("LEFT")
    ManTechPB_SetReadableFont(MTPB_TALENT_STATUS, 12, "")
    frame:SetScript("OnShow", MTPB_RefreshTalentWindow)
    frame:Hide()
end

local function MTPB_ShowTalentManager()
    if not MTPB_SELECTED then
        MTPB_SetStatus("Choose one bot before opening Talents.", MTPB_COLORS.yellow)
        return
    end
    MTPB_CreateTalentFrame()
    MTPB_RefreshTalentWindow()
    MTPB_TALENT_FRAME:Show()
    local data = MTPB_BOTS[MTPB_SELECTED]
    if not data or not data.talentBuildsQueried then MTPB_RequestTalentBuilds() end
end

local function MTPB_CreateSetup(panel)
    MTPB_AddHeading(panel, "ROLE & BUILD", -4)
    local talents = CreateFrame("Button", nil, panel, "UIPanelButtonTemplate")
    talents:SetWidth(100); talents:SetHeight(23); talents:SetPoint("TOPRIGHT", panel, "TOPRIGHT", -4, 2); talents:SetText("Talents...")
    ManTechPB_StyleButton(talents, 12)
    talents:SetScript("OnClick", MTPB_ShowTalentManager)
    local note = panel:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    note:SetPoint("TOPLEFT", panel, "TOPLEFT", 4, -25)
    note:SetWidth(372)
    note:SetJustifyH("LEFT")
    note:SetText(MTPB_COLORS.gray .. "Choose one bot. Talents changes the real build; the role cards below control how that build behaves.|r")
    ManTechPB_SetReadableFont(note, 11, "")
    panel.note = note
    local i
    for i = 1, 4 do
        local x = ((i - 1) - math.floor((i - 1) / 2) * 2) * 190 + 4
        local y = -70 - math.floor((i - 1) / 2) * 62
        local slot = MTPB_CreateCard(panel, x, y, 182, "", "", "INV_Misc_QuestionMark", function(self)
            local owner = self or this
            if owner.spec then MTPB_ApplySpec(owner.spec) end
        end)
        slot:Hide()
        MTPB_ROLE_SLOTS[i] = slot
    end
    MTPB_AddHeading(panel, "AFTER THE ROLE", -204)
    local one = MTPB_CreateCard(panel, 4, -230, 182, "Tank Assist", "Hold aggro and lead attacks", "Ability_Warrior_DefensiveStance", function()
        MTPB_SetExclusive("tank assist", "dps assist", {"co","nc"}, "tank assist")
    end)
    MTPB_RegisterStateCard(one, "tank assist", {"co","nc"})
    local two = MTPB_CreateCard(panel, 194, -230, 182, "Damage Assist", "Focus the tank's target", "Ability_Warrior_OffensiveStance", function()
        MTPB_SetExclusive("dps assist", "tank assist", {"co","nc"}, "damage assist")
    end)
    MTPB_RegisterStateCard(two, "dps assist", {"co","nc"})
end

local function MTPB_CreateCombat(panel)
    MTPB_AddHeading(panel, "COMBAT BEHAVIOR", -4)
    local data = {
        {"AOE", "Use area attacks", "Spell_Fire_SelfDestruct", "aoe", {"co","nc"}},
        {"Crowd Control", "Use available CC", "Spell_Frost_ChainsOfIce", "cc", {"co"}},
        {"Off-heal", "DPS can help heal", "Spell_Holy_FlashHeal", "offheal", {"co","nc"}},
        {"Healer DPS", "Allow damage spells while healing", "Spell_Holy_HolySmite", "offdps", {"co"}},
        {"Avoid Adds", "Reduce extra pulls", "Ability_Sap", "ads", {"co","nc"}},
        {"Low Threat", "Avoid high-threat actions", "Spell_Magic_LesserInvisibilty", "threat", {"co"}},
        {"Pull", "This bot performs pulls", "Ability_Hunter_SniperShot", "pull", {"co"}},
        {"Pull Back", "Return after pulling", "Ability_Rogue_Sprint", "pull back", {"co"}},
        {"Wait to Attack", "Delay initial attacks", "INV_Misc_PocketWatch_01", "wait for attack", {"co"}},
        {"Use Potions", "Health and mana potions", "INV_Potion_54", "potions", {"react"}},
        {"Buff", "Maintain useful buffs", "Spell_Holy_GreaterBlessingofKings", "buff", {"co","nc"}},
        {"Cleanse", "Remove harmful effects", "Spell_Holy_DispelMagic", "cure", {"co","nc"}}
    }
    local i, x, y, entry, card
    for i = 1, table.getn(data) do
        entry = data[i]
        x = ((i - 1) - math.floor((i - 1) / 2) * 2) * 190 + 4
        y = -25 - math.floor((i - 1) / 2) * 41
        card = MTPB_CreateCard(panel, x, y, 182, entry[1], entry[2], entry[3], function(self)
            local owner = self or this
            MTPB_ToggleStrategy(owner.mtbmStrategy, owner.mtbmContexts, owner.mtbmLabel)
        end)
        card:SetHeight(37)
        card.mtbmLabel = entry[1]
        MTPB_RegisterStateCard(card, entry[4], entry[5])
    end
end

local function MTPB_CreateWorld(panel)
    MTPB_AddHeading(panel, "MOVEMENT", -4)
    local movement = {
        {"Follow", "#a follow ?", "Ability_Hunter_BeastCall"}, {"Stay", "#a stay ?", "Spell_Nature_TimeStop"},
        {"Free", "#a free ?", "Ability_Rogue_Sprint"}, {"Guard", "#a guard ?", "Ability_Defend"}
    }
    local i, b
    for i = 1, table.getn(movement) do
        b = CreateFrame("Button", nil, panel, "UIPanelButtonTemplate")
        b:SetWidth(88); b:SetHeight(24); b:SetText(movement[i][1])
        ManTechPB_StyleButton(b, 12)
        b:SetPoint("TOPLEFT", panel, "TOPLEFT", 4 + (i-1)*94, -26)
        b.command = movement[i][2]; b.label = movement[i][1]
        b:SetScript("OnClick", function(self)
            local owner = self or this
            MTPB_SendCommands({owner.command}, owner.label)
        end)
    end
    MTPB_AddHeading(panel, "FORMATION", -62)
    local forms = {
        {"Near","near","Half-circle close to you"},
        {"Melee","melee","Cluster around your target"},
        {"Arrow","arrow","Tank forward; healers and DPS behind"},
        {"Far","far","Maintain wider spacing"},
        {"Chaos","chaos","Scatter and move freely"}
    }
    for i = 1, table.getn(forms) do
        b = CreateFrame("Button", nil, panel, "UIPanelButtonTemplate")
        b:SetWidth(70); b:SetHeight(30); b:SetText(forms[i][1])
        ManTechPB_StyleButton(b, 11)
        b:SetPoint("TOPLEFT", panel, "TOPLEFT", 4 + (i-1)*75, -84)
        b.form = forms[i][2]; b.label = forms[i][1]
        local formationLabel = b:GetFontString()
        if formationLabel then
            formationLabel:ClearAllPoints()
            formationLabel:SetPoint("CENTER", b, "CENTER", 11, 0)
        end
        ManTechPB_AddFormationPreview(b, b.form)
        table.insert(ManTechPB_FormationButtons, b)
        b:SetScript("OnClick", function(self)
            local owner = self or this
            MTPB_SendCommands({"#a formation " .. owner.form}, owner.label .. " formation")
        end)
        b:SetScript("OnEnter", function(self)
            local owner = self or this
            GameTooltip:SetOwner(owner, "ANCHOR_TOP")
            GameTooltip:SetText(owner.label .. " formation")
            GameTooltip:AddLine(forms[owner.mtpbFormationIndex][3], 1, 1, 1)
            GameTooltip:AddLine("Gold = anchor   Blue = bots", 0.35, 0.82, 1)
            GameTooltip:Show()
        end)
        b:SetScript("OnLeave", function() GameTooltip:Hide() end)
        b.mtpbFormationIndex = i
    end
    MTPB_AddHeading(panel, "WORLD & LOOT", -122)
    local data = {
        {"Food & Drink", "Recover between fights", "INV_Misc_Food_15", "food", {"nc"}},
        {"Loot", "Loot defeated enemies", "INV_Misc_Bag_10", "loot", {"nc"}},
        {"Gather", "Gather herbs and ore", "INV_Misc_Herb_11", "gather", {"nc"}},
        {"Mount", "Mount when appropriate", "Ability_Mount_RidingHorse", "mount", {"nc"}},
        {"Travel", "Long-distance travel logic", "INV_Misc_Map_01", "travel", {"nc"}},
        {"RPG", "Interact with the world", "INV_Misc_Book_11", "rpg", {"nc"}}
    }
    local entry, card, x, y
    for i = 1, table.getn(data) do
        entry = data[i]
        x = ((i - 1) - math.floor((i - 1) / 2) * 2) * 190 + 4
        y = -146 - math.floor((i - 1) / 2) * 44
        card = MTPB_CreateCard(panel, x, y, 182, entry[1], entry[2], entry[3], function(self)
            local owner = self or this
            MTPB_ToggleStrategy(owner.mtbmStrategy, owner.mtbmContexts, owner.mtbmLabel)
        end)
        card:SetHeight(38)
        card.mtbmLabel = entry[1]
        MTPB_RegisterStateCard(card, entry[4], entry[5])
    end
end

local MTPB_EXPERT_PAGE = "BOTS"
local MTPB_EXPERT_PAGE_INDEX = 1
local MTPB_EXPERT_SLOTS = {}
local MTPB_EXPERT_TABS = {}
local MTPB_EXPERT_PAGE_TEXT = nil
local MTPB_EXPERT_PREVIOUS = nil
local MTPB_EXPERT_NEXT = nil

local MTPB_EXPERT_DATA = {
    TACTICS = {
        {"Attack","Attack your selected hostile target","Ability_MeleeDamage","targetcommand",{"attack"}},
        {"Tank Attack","Hold DPS while the tank opens on your target","Ability_Warrior_DefensiveStance","tankattack"},
        {"Passive","Do not initiate or continue normal combat","Ability_Rogue_FeignDeath","toggle","passive",{"co","nc"}},
        {"Aggressive","Actively grind nearby enemies","Ability_DualWield","toggle","grind",{"nc"}},
        {"Retreat","Break combat and return to the master","Ability_Rogue_Sprint","command",{"#a flee ?"}},
        {"Reset AI","Clear the current AI decision state","INV_Misc_PocketWatch_01","command",{"#a reset"}},
        {"Tank Assist","Grab aggro and lead attacks","Ability_Warrior_DefensiveStance","exclusive","tank assist","dps assist",{"co","nc"}},
        {"Damage Assist","Focus the tank's target","Ability_Warrior_OffensiveStance","exclusive","dps assist","tank assist",{"co","nc"}},
        {"Melee / Close","Fight at close range","Ability_MeleeDamage","exclusive","close","ranged",{"co"}},
        {"Ranged","Fight from ranged distance","Ability_Hunter_Quickshot","exclusive","ranged","close",{"co"}},
        {"Pull","Allow this bot to perform pulls","Ability_Hunter_SniperShot","toggle","pull",{"co"}},
        {"Pull Back","Return after drawing the target","Ability_Rogue_Sprint","toggle","pull back",{"co"}},
        {"Wait to Attack","Delay initial engagement","INV_Misc_PocketWatch_01","toggle","wait for attack",{"co"}},
        {"Low Threat","Avoid unnecessary high-threat actions","Spell_Magic_LesserInvisibilty","toggle","threat",{"co"}},
        {"Avoid Adds","Reduce accidental extra pulls","Ability_Sap","toggle","ads",{"co","nc"}},
        {"Avoid Mobs","Avoid hostile mobs while moving","Ability_Rogue_Sprint","toggle","avoid mobs",{"co","nc"}},
        {"Auto Mark","Automatically assign raid targets","Ability_Hunter_SniperShot","toggle","mark rti",{"co"}}
    },
    TARGET = {
        {"Skull","Primary kill target","INV_Misc_QuestionMark","command",{"#a rti skull"}},
        {"Cross","Second kill target","INV_Misc_QuestionMark","command",{"#a rti cross"}},
        {"Circle","Assign orange circle","INV_Misc_QuestionMark","command",{"#a rti circle"}},
        {"Star","Assign yellow star","INV_Misc_QuestionMark","command",{"#a rti star"}},
        {"Square","Assign blue square","INV_Misc_QuestionMark","command",{"#a rti square"}},
        {"Triangle","Assign green triangle","INV_Misc_QuestionMark","command",{"#a rti triangle"}},
        {"Diamond","Assign purple diamond","INV_Misc_QuestionMark","command",{"#a rti diamond"}},
        {"Moon","Assign silver moon","INV_Misc_QuestionMark","command",{"#a rti moon"}},
        {"Clear","Remove kill-target assignment","Spell_Shadow_Teleport","command",{"#a rti none"}}
    },
    CC = {
        {"Skull","Crowd-control Skull","INV_Misc_QuestionMark","command",{"#a rti cc skull"}},
        {"Cross","Crowd-control Cross","INV_Misc_QuestionMark","command",{"#a rti cc cross"}},
        {"Circle","Crowd-control Circle","INV_Misc_QuestionMark","command",{"#a rti cc circle"}},
        {"Star","Crowd-control Star","INV_Misc_QuestionMark","command",{"#a rti cc star"}},
        {"Square","Crowd-control Square","INV_Misc_QuestionMark","command",{"#a rti cc square"}},
        {"Triangle","Crowd-control Triangle","INV_Misc_QuestionMark","command",{"#a rti cc triangle"}},
        {"Diamond","Crowd-control Diamond","INV_Misc_QuestionMark","command",{"#a rti cc diamond"}},
        {"Moon","Crowd-control Moon","INV_Misc_QuestionMark","command",{"#a rti cc moon"}},
        {"Clear","Remove CC assignment","Spell_Frost_ChainsOfIce","command",{"#a rti cc none"}}
    },
    LOOT = {
        {"Loot","Enable or disable looting","INV_Misc_Bag_10","toggle","loot",{"nc"}},
        {"Roll: Auto","Use normal PlayerBot item decisions","INV_Misc_Dice_02","command",{"roll policy auto"}},
        {"Roll: Pass","Always pass on future eligible rolls","INV_Misc_Dice_01","command",{"roll policy pass"}},
        {"Roll: Greed","Greed when permitted, otherwise pass","INV_Misc_Coin_01","command",{"roll policy greed"}},
        {"Roll: Need","Need when permitted, otherwise fall back safely","INV_Chest_Chain","command",{"roll policy need"}},
        {"Roll Status","Show the saved automatic roll policy","INV_Misc_Spyglass_03","command",{"roll policy ?"}},
        {"Equipment","Loot useful upgrades","INV_Chest_Chain","command",{"#a ll ~equip"}},
        {"Quest","Loot quest items","INV_Misc_Note_01","command",{"#a ll ~quest"}},
        {"Tradeskill","Loot profession materials","INV_Misc_Herb_11","command",{"#a ll ~skill"}},
        {"Disenchant","Loot disenchantable items","INV_Enchant_DustStrange","command",{"#a ll ~disenchant"}},
        {"Usable","Loot consumables and reagents","INV_Potion_54","command",{"#a ll ~use"}},
        {"Vendor","Loot vendor-value items","INV_Misc_Coin_01","command",{"#a ll ~vendor"}},
        {"Trash","Loot low-value items","INV_Misc_Gear_01","command",{"#a ll ~trash"}}
    },
    RPG = {
        {"RPG Master","Nearby NPC interaction","INV_Misc_Book_11","toggle","rpg",{"nc"}},
        {"Reveal Nodes","Reveal nearby gathering nodes","INV_Misc_Spyglass_03","toggle","reveal",{"nc"}},
        {"Quests","Talk to quest NPCs","INV_Misc_Note_01","toggle","rpg quest",{"nc"}},
        {"Vendors","Talk to vendors","INV_Misc_Coin_01","toggle","rpg vendor",{"nc"}},
        {"Explore","Use inns and flightmasters","INV_Misc_Map_01","toggle","rpg explore",{"nc"}},
        {"Maintain","Visit armorers and trainers","INV_Misc_ArmorKit_17","toggle","rpg maintenance",{"nc"}},
        {"Players","Duel and trade with players","INV_Misc_GroupLooking","toggle","rpg player",{"nc"}},
        {"Craft","Craft and use utility spells","Trade_BlackSmithing","toggle","rpg craft",{"nc"}},
        {"Battleground","Queue at battlemasters","INV_BannerPVP_01","toggle","rpg bg",{"nc"}}
    },
    SETTINGS = {
        {"Mana 1","No mana conservation","Spell_Nature_Lightning","command",{"#a save mana 1"}},
        {"Mana 2","Light conservation","Spell_Nature_Lightning","command",{"#a save mana 2"}},
        {"Mana 3","Moderate conservation","Spell_Nature_Lightning","command",{"#a save mana 3"}},
        {"Mana 4","Strong conservation","Spell_Nature_Lightning","command",{"#a save mana 4"}},
        {"Mana 5","Maximum conservation","Spell_Nature_Lightning","command",{"#a save mana 5"}},
        {"Mana 6","Very high conservation","Spell_Nature_Lightning","command",{"#a save mana 6"}},
        {"Mana 7","Heavy conservation","Spell_Nature_Lightning","command",{"#a save mana 7"}},
        {"Mana 8","Severe conservation","Spell_Nature_Lightning","command",{"#a save mana 8"}},
        {"Mana 9","Emergency conservation","Spell_Nature_Lightning","command",{"#a save mana 9"}},
        {"Mana 10","Maximum supported conservation","Spell_Nature_Lightning","command",{"#a save mana 10"}},
        {"Role Status","Show the core-confirmed role and range","INV_Misc_Spyglass_03","command",{"status role"}},
        {"Build Status","Show the current build and suggested role","INV_Misc_Spyglass_03","command",{"status build"}},
        {"Pull Status","Show pull action readiness and failure reason","INV_Misc_Spyglass_03","command",{"status pull"}},
        {"Near Stance","Default positioning","Ability_Hunter_BeastCall","command",{"#a stance near"}},
        {"Tank Stance","Off-tank positioning","Ability_Warrior_DefensiveStance","command",{"#a stance tank"}},
        {"Turn Back","Face enemy away from party","Ability_Warrior_ShieldWall","command",{"#a stance turnback"}},
        {"Behind","Melee attacks from behind","Ability_BackStab","command",{"#a stance behind"}},
        {"Conserve","Toggle conservation strategy","Spell_Nature_RavenForm","toggle","conserve mana",{"co"}},
        {"Auto Mark","Automatically mark targets","Ability_Hunter_SniperShot","toggle","mark rti",{"co"}},
        {"Cast Time","Avoid slow casts on dying targets","Spell_Nature_TimeStop","toggle","cast time",{"co"}}
    },
    CHARACTER = {
        {"Random Gear","Generate level-appropriate gear","INV_Chest_Chain","rawbot",".bot gear %s"},
        {"Enchant","Apply relevant enchants","INV_Enchant_EssenceMagicLarge","rawbot",".bot enchants %s"},
        {"Initialize","Major full bot initialization","INV_Misc_PocketWatch_01","rawbot",".bot init %s"},
        {"Learn","Learn available spells","INV_Misc_Book_09","rawbot",".bot learn %s"},
        {"Train","Train class abilities","INV_Misc_Book_11","rawbot",".bot train %s"},
        {"Prepare","Prepare gear and supplies","INV_Misc_Bag_10","rawbot",".bot prepare %s"},
        {"Ammo","Give useful ammunition","INV_Ammo_Arrow_01","rawbot",".bot ammo %s"},
        {"Food","Give food and drink","INV_Misc_Food_15","rawbot",".bot food %s"},
        {"Potions","Give potions and reagents","INV_Potion_54","rawbot",".bot potions %s"},
        {"Reagents","Give class reagents","INV_Misc_Dust_02","rawbot",".bot reagents %s"},
        {"Consumables","Give useful consumables","INV_Misc_Bag_08","rawbot",".bot consumables %s"},
        {"Pet Setup","Initialize hunter/warlock pet","Ability_Hunter_BeastTaming","rawbot",".bot pet %s"}
    }
}

local MTPB_CLASS_BEHAVIOR = {
    DRUID={{"Stealth","Use stealth behavior","Ability_Stealth","toggle","stealth",{"co","nc"}},{"Off-heal","Heal while in damage mode","Spell_Holy_FlashHeal","toggle","offheal",{"co","nc"}},{"Pre-heal","Prepare heals before damage","Spell_Holy_FlashHeal","toggle","preheal",{"co"}}},
    HUNTER={{"Stings","Choose useful stings","Ability_Hunter_Quickshot","toggle","sting",{"co"}},{"Aspects","Choose useful aspects","Spell_Nature_RavenForm","toggle","aspect",{"co","nc"}},{"Pet","Manage combat pet","Ability_Hunter_BeastCall","toggle","pet",{"co","nc"}}},
    MAGE={{"Cure","Remove curses","Spell_Holy_DispelMagic","toggle","cure",{"co","nc"}}},
    PALADIN={
        {"Auras","Choose a useful aura automatically","Spell_Holy_DevotionAura","toggle","aura",{"co","nc"}},
        {"Blessings","Choose useful blessings automatically","Spell_Holy_GreaterBlessingofKings","toggle","blessing",{"co","nc"}},
        {"Off-heal","Heal while DPS","Spell_Holy_FlashHeal","toggle","offheal",{"co","nc"}},
        {"Pre-heal","Prepare heals before damage","Spell_Holy_FlashHeal","toggle","preheal",{"co"}},
        {"Bless: Might","Prefer Blessing of Might","Spell_Holy_FistOfJustice","command",{"#a co +blessing might,?","#a nc +blessing might,?"}},
        {"Bless: Wisdom","Prefer Blessing of Wisdom","Spell_Holy_SealOfWisdom","command",{"#a co +blessing wisdom,?","#a nc +blessing wisdom,?"}},
        {"Bless: Kings","Prefer Blessing of Kings","Spell_Magic_MageArmor","command",{"#a co +blessing kings,?","#a nc +blessing kings,?"}},
        {"Bless: Sanctuary","Prefer Blessing of Sanctuary","Spell_Nature_LightningShield","command",{"#a co +blessing sanctuary,?","#a nc +blessing sanctuary,?"}},
        {"Bless: Light","Prefer Blessing of Light","Spell_Holy_PrayerOfHealing02","command",{"#a co +blessing light,?","#a nc +blessing light,?"}},
        {"Bless: Salvation","Prefer Blessing of Salvation","Spell_Holy_SealOfSalvation","command",{"#a co +blessing salvation,?","#a nc +blessing salvation,?"}},
        {"Aura: Devotion","Prefer Devotion Aura","Spell_Holy_DevotionAura","command",{"#a co +aura devotion,?","#a nc +aura devotion,?"}},
        {"Aura: Retribution","Prefer Retribution Aura","Spell_Holy_AuraOfLight","command",{"#a co +aura retribution,?","#a nc +aura retribution,?"}},
        {"Aura: Concentration","Prefer Concentration Aura","Spell_Holy_MindSooth","command",{"#a co +aura concentration,?","#a nc +aura concentration,?"}},
        {"Aura: Shadow","Prefer Shadow Resistance Aura","Spell_Shadow_SealOfKings","command",{"#a co +aura shadow,?","#a nc +aura shadow,?"}},
        {"Aura: Frost","Prefer Frost Resistance Aura","Spell_Frost_WizardMark","command",{"#a co +aura frost,?","#a nc +aura frost,?"}},
        {"Aura: Fire","Prefer Fire Resistance Aura","Spell_Fire_SealOfFire","command",{"#a co +aura fire,?","#a nc +aura fire,?"}},
        {"Aura: Crusader","Prefer Crusader Aura when supported","Spell_Holy_CrusaderAura","command",{"#a co +aura crusader,?","#a nc +aura crusader,?"}},
        {"Aura: Sanctity","Prefer Sanctity Aura when supported","Spell_Holy_MindVision","command",{"#a co +aura sanctity,?","#a nc +aura sanctity,?"}}
    },
    PRIEST={{"Off-heal","Heal while DPS","Spell_Holy_FlashHeal","toggle","offheal",{"co","nc"}},{"Healer DPS","Damage while healing","Spell_Holy_HolySmite","toggle","offdps",{"co"}},{"Pre-heal","Prepare heals","Spell_Holy_GreaterHeal","toggle","preheal",{"co"}}},
    ROGUE={{"Poisons","Choose useful poisons","Ability_Poisons","toggle","poisons",{"co","nc"}},{"Stealth","Use stealth behavior","Ability_Stealth","toggle","stealth",{"co","nc"}}},
    SHAMAN={{"Totems","Choose useful totems","Spell_Nature_StoneClawTotem","toggle","totems",{"co","nc"}},{"Off-heal","Heal while DPS","Spell_Nature_HealingWaveGreater","toggle","offheal",{"co","nc"}},{"Pre-heal","Prepare heals","Spell_Nature_HealingWaveLesser","toggle","preheal",{"co"}}},
    WARLOCK={{"Curses","Choose useful curses","Spell_Shadow_CurseOfTounges","toggle","curse",{"co"}},{"Pet","Manage combat pet","Spell_Shadow_SummonVoidWalker","toggle","pet",{"co","nc"}}},
    DEATHKNIGHT={{"Frost AOE","Use the Frost AOE strategy","Spell_DeathKnight_FrozenRuneWeapon","toggle","frost aoe",{"co"}},{"Unholy AOE","Use the Unholy AOE strategy","Spell_DeathKnight_ArmyOfTheDead","toggle","unholy aoe",{"co"}},{"Buff DPS","Use DK combat buffs","Spell_Deathknight_ClassIcon","toggle","bdps",{"co"}},{"Pull","Use the Death Knight pull strategy","Spell_Frost_FrostShock","toggle","pull",{"co"}}}
}

local function MTPB_BotCsv()
    local names = MTPB_AllBotNames()
    return table.concat(names, ",")
end

function ManTechPB_UpdateSessionButtons()
    local data = MTPB_SELECTED and MTPB_BOTS[MTPB_SELECTED]
    if ManTechPBLoginButton then
        if data and data.online == false then ManTechPBLoginButton:Enable()
        else ManTechPBLoginButton:Disable() end
    end
    if ManTechPBLogoutButton then
        if data and data.online ~= false then ManTechPBLogoutButton:Enable()
        else ManTechPBLogoutButton:Disable() end
    end
    local hasBots = table.getn(MTPB_AllBotNames()) > 0
    if ManTechPBLoginAllButton then
        if hasBots then ManTechPBLoginAllButton:Enable() else ManTechPBLoginAllButton:Disable() end
    end
    if ManTechPBLogoutAllButton then
        if hasBots then ManTechPBLogoutAllButton:Enable() else ManTechPBLogoutAllButton:Disable() end
    end
end

function ManTechPB_ShowSessionTooltip(button)
    local owner = button or this
    if not owner or not owner.mtpbSessionTip then return end
    GameTooltip:SetOwner(owner, "ANCHOR_RIGHT")
    GameTooltip:SetText(owner:GetText())
    GameTooltip:AddLine(owner.mtpbSessionTip, 1, 1, 1, true)
    GameTooltip:Show()
end

function ManTechPB_SetSelectedBotOnline(online)
    if not MTPB_SELECTED then
        MTPB_SetStatus("Choose one bot under Party or My Alts first.", MTPB_COLORS.red)
        return
    end
    local action = online and "add " or "rm "
    MTPB_SendRawCommand(".bot " .. action .. MTPB_SELECTED, "SAY")
    MTPB_SetStatus((online and "Logging in " or "Logging out ") .. MTPB_SELECTED .. "...", MTPB_COLORS.yellow)
    MTPB_UpdateBotList(0.8)
end

function ManTechPB_SetAllBotsOnline(online)
    local csv = MTPB_BotCsv()
    if csv == "" then
        MTPB_SetStatus("No account bots are known yet. Click Refresh first.", MTPB_COLORS.red)
        return
    end
    local action = online and "add " or "rm "
    MTPB_SendRawCommand(".bot " .. action .. csv, "SAY")
    MTPB_SetStatus(online and "Logging in all known account bots..." or "Logging out all known account bots...", MTPB_COLORS.yellow)
    MTPB_UpdateBotList(0.8)
end

local function MTPB_OpenWhisper()
    if not MTPB_SELECTED then MTPB_SetStatus("Choose one bot first.", MTPB_COLORS.red); return end
    local editBox = getglobal and getglobal("ChatFrameEditBox")
    if not editBox and DEFAULT_CHAT_FRAME then editBox = DEFAULT_CHAT_FRAME.editBox end
    if editBox then editBox:Show(); editBox:SetFocus(); editBox:SetText("/whisper " .. MTPB_SELECTED .. " ") end
end

local function MTPB_BotAdminEntries()
    return {
        {"Log In","Bring selected bot online","Spell_Arcane_TeleportStormWind","login"},
        {"Log Out","Take selected bot offline","Spell_Arcane_TeleportOrgrimmar","logout"},
        {"Invite","Invite selected bot","INV_Misc_GroupLooking","invite"},
        {"Leave","Remove selected bot from party","Ability_Vanish","leave"},
        {"Summon","Summon selected bot","Spell_Shadow_Twilight","summon"},
        {"Whisper","Open a whisper to selected bot","INV_Letter_15","whisper"},
        {"Log In All","Bring every roster bot online","Spell_Arcane_PortalStormWind","loginall"},
        {"Log Out All","Take every roster bot offline","Spell_Arcane_PortalOrgrimmar","logoutall"},
        {"Invite All","Invite every online bot","INV_Misc_GroupNeedMore","inviteall"},
        {"Leave All","Remove all bots from party","Spell_Shadow_Teleport","leaveall"},
        {"Summon All","Summon all online bots","Spell_Shadow_Twilight","summonall"},
        {"Refresh","Refresh complete roster","INV_Misc_Spyglass_03","refresh"}
    }
end

local function MTPB_ClassEntries()
    local entries = {
        {"AOE","Use area attacks","Spell_Fire_SelfDestruct","toggle","aoe",{"co","nc"}},
        {"Buff","Maintain useful buffs","Spell_Holy_GreaterBlessingofKings","toggle","buff",{"co","nc"}},
        {"Boost","Use cooldowns","Spell_Nature_LightningOverload","toggle","boost",{"co","nc"}},
        {"Cleanse","Remove harmful effects","Spell_Holy_DispelMagic","toggle","cure",{"co","nc"}}
    }
    local classEntries = MTPB_CLASS_BEHAVIOR[MTPB_GetSelectedClass()] or {}
    local i
    for i = 1, table.getn(classEntries) do table.insert(entries, classEntries[i]) end
    return entries
end

local function MTPB_ExecuteExpert(entry)
    local kind = entry[4]
    if kind == "command" then MTPB_SendCommands(entry[5], entry[1])
    elseif kind == "toggle" then MTPB_ToggleStrategy(entry[5], entry[6], entry[1])
    elseif kind == "exclusive" then MTPB_SetExclusive(entry[5], entry[6], entry[7], entry[1])
    elseif kind == "targetcommand" then
        if not UnitExists("target") or not UnitCanAttack("player", "target") then
            MTPB_SetStatus("Select an attackable target first.", MTPB_COLORS.red)
        else MTPB_SendCommands(entry[5], entry[1]) end
    elseif kind == "tankattack" then
        if not UnitExists("target") or not UnitCanAttack("player", "target") then
            MTPB_SetStatus("Select an attackable target first.", MTPB_COLORS.red)
        elseif MTPB_SELECTED then
            MTPB_SendCommands({"attack"}, "tank attack")
        else
            MTPB_SendCommands({"#a @dps co -dps assist", "#a @dps nc -dps assist", "#a @tank attack"}, "tank attack")
        end
    elseif kind == "rawbot" then
        if not MTPB_SELECTED then MTPB_SetStatus("Choose one bot first.", MTPB_COLORS.red); return end
        MTPB_SendRawCommand(string.format(entry[5], MTPB_SELECTED), "WHISPER", nil, MTPB_SELECTED)
        MTPB_SetStatus("Sent " .. entry[1] .. " to " .. MTPB_SELECTED .. ".", MTPB_COLORS.green)
    elseif kind == "login" or kind == "logout" then
        if not MTPB_SELECTED then MTPB_SetStatus("Choose one bot first.", MTPB_COLORS.red); return end
        MTPB_SendRawCommand(".bot " .. (kind == "login" and "add " or "rm ") .. MTPB_SELECTED, "SAY")
    elseif kind == "invite" then if MTPB_SELECTED then InviteByName(MTPB_SELECTED) else MTPB_SetStatus("Choose one bot first.", MTPB_COLORS.red) end
    elseif kind == "leave" or kind == "summon" then
        if MTPB_SELECTED then MTPB_SendBotCommand(kind, "WHISPER", nil, MTPB_SELECTED) else MTPB_SetStatus("Choose one bot first.", MTPB_COLORS.red) end
    elseif kind == "whisper" then MTPB_OpenWhisper()
    elseif kind == "loginall" or kind == "logoutall" then
        local csv = MTPB_BotCsv(); if csv ~= "" then MTPB_SendRawCommand(".bot " .. (kind == "loginall" and "add " or "rm ") .. csv, "SAY") end
    elseif kind == "inviteall" then
        local names, i = MTPB_AllBotNames(), 1
        for i = 1, table.getn(names) do MTPB_Wait((i-1)*0.15, InviteByName, names[i]) end
    elseif kind == "leaveall" or kind == "summonall" then
        local names, i, command = MTPB_AllBotNames(), 1, kind == "leaveall" and "leave" or "summon"
        for i = 1, table.getn(names) do MTPB_Wait((i-1)*0.35, MTPB_SendBotCommand, command, "WHISPER", nil, names[i]) end
    elseif kind == "refresh" then MTPB_UpdateBotList(0); if MTPB_PartySize() > 0 then MTPB_QueryBotParty() end end
end

local function MTPB_RenderExpert()
    local entries
    if MTPB_EXPERT_PAGE == "BOTS" then entries = MTPB_BotAdminEntries()
    elseif MTPB_EXPERT_PAGE == "CLASS" then entries = MTPB_ClassEntries()
    else entries = MTPB_EXPERT_DATA[MTPB_EXPERT_PAGE] or {} end
    local pageSize = 9
    local pageCount = math.max(1, math.ceil(table.getn(entries) / pageSize))
    if MTPB_EXPERT_PAGE_INDEX < 1 then MTPB_EXPERT_PAGE_INDEX = 1 end
    if MTPB_EXPERT_PAGE_INDEX > pageCount then MTPB_EXPERT_PAGE_INDEX = pageCount end
    local first = (MTPB_EXPERT_PAGE_INDEX - 1) * pageSize
    local i, slot, entry
    for i = 1, pageSize do
        slot, entry = MTPB_EXPERT_SLOTS[i], entries[first + i]
        if entry then
            slot.entry = entry; slot.title:SetText(entry[1]); slot.icon:SetTexture("Interface\\Icons\\" .. entry[3]); slot:Show()
            slot:SetBackdropBorderColor(0.16,0.42,0.58,0.85)
            if entry[4] == "toggle" then
                local active, mixed = MTPB_StrategyState(entry[5], entry[6])
                if active then slot:SetBackdropBorderColor(0.10,0.85,0.42,1)
                elseif mixed then slot:SetBackdropBorderColor(0.95,0.70,0.20,1) end
            elseif entry[4] == "exclusive" then
                local active, mixed = MTPB_StrategyState(entry[5], entry[7])
                if active then slot:SetBackdropBorderColor(0.10,0.85,0.42,1)
                elseif mixed then slot:SetBackdropBorderColor(0.95,0.70,0.20,1) end
            end
        else slot.entry = nil; slot:Hide() end
    end
    for name, button in pairs(MTPB_EXPERT_TABS) do if name == MTPB_EXPERT_PAGE then button:LockHighlight() else button:UnlockHighlight() end end
    if MTPB_EXPERT_PAGE_TEXT then MTPB_EXPERT_PAGE_TEXT:SetText(MTPB_COLORS.gold .. "Page " .. MTPB_EXPERT_PAGE_INDEX .. " / " .. pageCount .. "|r") end
    if MTPB_EXPERT_PREVIOUS then if MTPB_EXPERT_PAGE_INDEX > 1 then MTPB_EXPERT_PREVIOUS:Enable() else MTPB_EXPERT_PREVIOUS:Disable() end end
    if MTPB_EXPERT_NEXT then if MTPB_EXPERT_PAGE_INDEX < pageCount then MTPB_EXPERT_NEXT:Enable() else MTPB_EXPERT_NEXT:Disable() end end
end

local function MTPB_CreateExpert(panel)
    MTPB_AddHeading(panel, "ADVANCED — ONE CATEGORY AT A TIME", -4)
    local pages = {{"BOTS","Bots"},{"TACTICS","Tactic"},{"TARGET","Mark"},{"CC","CC"},{"LOOT","Loot"},{"RPG","RPG"},{"CLASS","Class"},{"SETTINGS","Setup"},{"CHARACTER","Char"}}
    local i, button
    for i = 1, table.getn(pages) do
        button = CreateFrame("Button", nil, panel, "UIPanelButtonTemplate")
        button:SetWidth(40); button:SetHeight(21); button:SetPoint("TOPLEFT", panel, "TOPLEFT", 1 + (i-1)*42, -23)
        button:SetText(pages[i][2]); button.page = pages[i][1]
        ManTechPB_StyleButton(button, 10)
        button:SetScript("OnClick", function(self) local owner=self or this; MTPB_EXPERT_PAGE=owner.page; MTPB_EXPERT_PAGE_INDEX=1; ManTechPBDB.expertPage=owner.page; MTPB_RenderExpert() end)
        MTPB_EXPERT_TABS[pages[i][1]] = button
    end
    for i = 1, 9 do
        local col = (i-1) - math.floor((i-1)/3)*3
        local row = math.floor((i-1)/3)
        local slot = CreateFrame("Button", nil, panel)
        slot:SetWidth(119); slot:SetHeight(49); slot:SetPoint("TOPLEFT", panel, "TOPLEFT", 3 + col*125, -51 - row*54)
        slot:SetBackdrop({bgFile="Interface\\Tooltips\\UI-Tooltip-Background",edgeFile="Interface\\Tooltips\\UI-Tooltip-Border",tile=true,tileSize=16,edgeSize=9,insets={left=3,right=3,top=3,bottom=3}})
        slot:SetBackdropColor(0.025,0.055,0.085,0.96); slot:SetBackdropBorderColor(0.16,0.42,0.58,0.85)
        slot.icon=slot:CreateTexture(nil,"ARTWORK"); slot.icon:SetWidth(24); slot.icon:SetHeight(24); slot.icon:SetPoint("LEFT",slot,"LEFT",7,0); slot.icon:SetTexCoord(0.08,0.92,0.08,0.92)
        slot.title=slot:CreateFontString(nil,"OVERLAY","GameFontNormalSmall"); slot.title:SetPoint("LEFT",slot,"LEFT",36,0); slot.title:SetWidth(76); slot.title:SetJustifyH("LEFT"); ManTechPB_SetReadableFont(slot.title,11,"OUTLINE")
        slot:SetScript("OnClick", function(self) local owner=self or this; if owner.entry then MTPB_ExecuteExpert(owner.entry) end end)
        slot:SetScript("OnEnter", function(self) local owner=self or this; if owner.entry then GameTooltip:SetOwner(owner,"ANCHOR_RIGHT"); GameTooltip:SetText(owner.entry[1]); GameTooltip:AddLine(owner.entry[2],1,1,1,true); GameTooltip:Show() end end)
        slot:SetScript("OnLeave", function() GameTooltip:Hide() end)
        MTPB_EXPERT_SLOTS[i]=slot
    end
    MTPB_EXPERT_PREVIOUS = CreateFrame("Button", nil, panel, "UIPanelButtonTemplate")
    MTPB_EXPERT_PREVIOUS:SetWidth(58); MTPB_EXPERT_PREVIOUS:SetHeight(20); MTPB_EXPERT_PREVIOUS:SetPoint("TOPLEFT", panel, "TOPLEFT", 90, -220); MTPB_EXPERT_PREVIOUS:SetText("< Prev")
    ManTechPB_StyleButton(MTPB_EXPERT_PREVIOUS, 11)
    MTPB_EXPERT_PREVIOUS:SetScript("OnClick", function() MTPB_EXPERT_PAGE_INDEX=MTPB_EXPERT_PAGE_INDEX-1; MTPB_RenderExpert() end)
    MTPB_EXPERT_PAGE_TEXT = panel:CreateFontString(nil,"OVERLAY","GameFontNormalSmall")
    MTPB_EXPERT_PAGE_TEXT:SetPoint("LEFT",MTPB_EXPERT_PREVIOUS,"RIGHT",10,0); MTPB_EXPERT_PAGE_TEXT:SetWidth(105); MTPB_EXPERT_PAGE_TEXT:SetJustifyH("CENTER")
    MTPB_EXPERT_NEXT = CreateFrame("Button", nil, panel, "UIPanelButtonTemplate")
    MTPB_EXPERT_NEXT:SetWidth(58); MTPB_EXPERT_NEXT:SetHeight(20); MTPB_EXPERT_NEXT:SetPoint("LEFT",MTPB_EXPERT_PAGE_TEXT,"RIGHT",10,0); MTPB_EXPERT_NEXT:SetText("Next >")
    ManTechPB_StyleButton(MTPB_EXPERT_NEXT, 11)
    MTPB_EXPERT_NEXT:SetScript("OnClick", function() MTPB_EXPERT_PAGE_INDEX=MTPB_EXPERT_PAGE_INDEX+1; MTPB_RenderExpert() end)
    MTPB_EXPERT_PAGE = ManTechPBDB.expertPage or "BOTS"
    MTPB_RenderExpert()
end

local function MTPB_UpdateRoleSlots(slots, specs, data)
    local i, slot, spec, active
    for i = 1, 4 do
        slot = slots[i]
        spec = specs and specs[i]
        if slot then
            if spec then
                slot.spec = spec
                slot.title:SetText(spec.name)
                slot.description:SetText(spec.role == "tank" and "Tank role" or spec.role == "heal" and "Healer role" or spec.role == "melee" and "Melee damage" or "Ranged damage")
                slot.icon:SetTexture("Interface\\Icons\\" .. spec.icon)
                local pending = MTPB_GetPendingStrategy(spec.strategy)
                active = pending and pending.wanted or (data and data.strategy and MTPB_ListContains(data.strategy.co, spec.strategy))
                MTPB_SetCardState(slot, active, false, pending)
                slot:Show()
            else
                slot.spec = nil
                slot:Hide()
            end
        end
    end
end

local function MTPB_UpdateRolePanel()
    local class = MTPB_GetSelectedClass()
    local specs = class and MTPB_SPECS[class]
    local data = MTPB_CurrentBotData()
    MTPB_UpdateRoleSlots(MTPB_ROLE_SLOTS, specs, data)
    MTPB_UpdateRoleSlots(MTPB_FOCUS_ROLE_SLOTS, specs, data)
    if not MTPB_SELECTED then
        MTPB_PANELS.SETUP.note:SetText(MTPB_COLORS.yellow .. "Choose one bot on the left. Talents and role changes are intentionally never applied blindly to the whole party.|r")
    elseif not specs then
        MTPB_PANELS.SETUP.note:SetText(MTPB_COLORS.yellow .. "Waiting for " .. MTPB_SELECTED .. "'s class. Press Refresh if it does not appear.|r")
    else
        local coreStatus = ""
        if data and data.reportedRole and data.reportedRole ~= "" then
            coreStatus = " Core: " .. data.reportedRole .. (data.reportedRange and data.reportedRange ~= "" and " / " .. data.reportedRange or "") .. "."
        end
        MTPB_PANELS.SETUP.note:SetText(MTPB_COLORS.gray .. "Setup for " .. MTPB_COLORS.white .. MTPB_SELECTED .. MTPB_COLORS.gray .. " (" .. class .. "). Use Talents for the real build, then tune behavior below." .. coreStatus .. "|r")
    end
    if MTPB_FOCUS_NOTE then
        if not specs then MTPB_FOCUS_NOTE:SetText(MTPB_COLORS.yellow .. "Waiting for the bot's class and confirmed strategies...|r")
        else MTPB_FOCUS_NOTE:SetText(MTPB_COLORS.gray .. "Choose the role this " .. class .. " should perform. Talents changes the real build.|r") end
    end
    if MTPB_FOCUS_TITLE then MTPB_FOCUS_TITLE:SetText(MTPB_COLORS.gold .. string.upper(MTPB_SELECTED or "BOT") .. "  •  INDIVIDUAL CONTROL|r") end
    if MTPB_FOCUS_SUBTITLE then
        local pull = data and data.pullReady and data.pullReady ~= "" and ("  •  pull " .. data.pullReady) or ""
        MTPB_FOCUS_SUBTITLE:SetText(MTPB_COLORS.gray .. (class or "Loading class") .. "  •  confirmed settings only" .. pull .. "|r")
    end
end

local function MTPB_UpdateCards()
    local i, card, active, mixed
    for i = 1, table.getn(MTPB_STATE_CARDS) do
        card = MTPB_STATE_CARDS[i]
        local pending = MTPB_GetPendingStrategy(card.mtbmStrategy)
        active, mixed = MTPB_StrategyState(card.mtbmStrategy, card.mtbmContexts)
        if pending then active, mixed = pending.wanted, false end
        MTPB_SetCardState(card, active, mixed, pending)
    end
    ManTechPB_UpdateFormationButtons()
    MTPB_UpdateRolePanel()
    if MTPB_EXPERT_PAGE and MTPB_RenderExpert then MTPB_RenderExpert() end
end

local function MTPB_Select(name, querySettings)
    MTPB_SELECTED = name
    MTPB_TALENT_PAGE = 1
    if ManTechPBDB then
        if not ManTechPBDB.selectedByCharacter then ManTechPBDB.selectedByCharacter = {} end
        local characterKey = MTPB_CharacterKey()
        if characterKey then ManTechPBDB.selectedByCharacter[characterKey] = name end
        -- Retire the old account-wide field that could contact a bot selected
        -- by a different character.
        ManTechPBDB.selected = nil
    end
    MTPB_SCOPE_TEXT:SetText(name and (MTPB_COLORS.white .. name .. "|r") or (MTPB_COLORS.green .. "Entire Party|r"))
    -- Frame creation restores the saved scope during every login/reload.  Do
    -- not make that bookkeeping contact the bots: the resulting strategy
    -- lists are visible whispers.  User-driven selections keep the default
    -- behavior and request fresh state immediately.
    if querySettings ~= false then
        if name and MTPB_QuerySelectedBot then MTPB_QuerySelectedBot(name)
        elseif MTPB_QueryBotParty then MTPB_QueryBotParty() end
    end
    MTPB_SetStatus(name and ("Controlling " .. name .. ".") or "Controlling the entire bot party.", MTPB_COLORS.gray)
    MTPB_UpdateCards()
    ManTechPB_UpdateSessionButtons()
    if MTPB_TALENT_FRAME and MTPB_TALENT_FRAME:IsVisible() then MTPB_RefreshTalentWindow() end
end

local function MTPB_UpdateRoster()
    if not MTPB_FRAME then return end
    local names = MTPB_ROSTER_VIEW == "ALTS" and MTPB_AltBotNames() or MTPB_PartyBotNames()
    local i, button, name, data, class, color
    for i = 1, 10 do
        button = MTPB_ROSTER_BUTTONS[i]
        name = names[i]
        if name then
            data = MTPB_BOTS and MTPB_BOTS[name]
            class = data and MTPB_NormalizeClass(data.class)
            color = class and MTPB_CLASS_COLORS[class]
            button.name = name
            button:SetText(name .. ((data and data.online == false) and " |cff777777(off)|r" or ""))
            if color then button:GetFontString():SetTextColor(color[1], color[2], color[3])
            else button:GetFontString():SetTextColor(0.85, 0.85, 0.85) end
            button:Show()
        else
            button.name = nil
            button:Hide()
        end
    end
    local label = MTPB_ROSTER_VIEW == "ALTS" and "account alt" or "party bot"
    MTPB_ROSTER_TEXT:SetText(table.getn(names) .. " " .. label .. (table.getn(names) == 1 and "" or "s"))
    for name, button in pairs(MTPB_ROSTER_FILTER_BUTTONS) do
        if name == MTPB_ROSTER_VIEW then button:LockHighlight() else button:UnlockHighlight() end
    end
    ManTechPB_UpdateSessionButtons()
    if MTPB_SELECTED and (not MTPB_BOTS or not MTPB_BOTS[MTPB_SELECTED]) then MTPB_Select(nil) end
end

local function MTPB_SetRosterView(view)
    if view ~= "PARTY" and view ~= "ALTS" then return end
    MTPB_ROSTER_VIEW = view
    if ManTechPBDB then ManTechPBDB.rosterView = view end
    MTPB_UpdateRoster()
end

local function MTPB_ShowTab(name)
    MTPB_CURRENT_TAB = name
    if ManTechPBDB then ManTechPBDB.tab = name end
    local key, panel
    for key, panel in pairs(MTPB_PANELS) do
        if key == name then panel:Show() else panel:Hide() end
    end
    for key, panel in pairs(MTPB_TAB_BUTTONS) do
        if key == name then panel:LockHighlight() else panel:UnlockHighlight() end
    end
    MTPB_UpdateCards()
end

local function MTPB_SavePosition()
    if not MTPB_FRAME or not ManTechPBDB then return end
    local point, _, relativePoint, x, y = MTPB_FRAME:GetPoint()
    ManTechPBDB.point = point
    ManTechPBDB.relativePoint = relativePoint
    ManTechPBDB.x = x
    ManTechPBDB.y = y
end

-- Keep restoration outside the large frame-construction closure. The WoW 1.12
-- Lua 5.0 compiler allows at most 32 upvalues per function; capturing these
-- helpers directly in MTPB_CreateFrame would exceed that limit.
local function MTPB_RestoreMainFrameState()
    local characterKey = MTPB_CharacterKey()
    local saved = characterKey and ManTechPBDB.selectedByCharacter and ManTechPBDB.selectedByCharacter[characterKey]
    if saved and MTPB_IsCurrentPartyMember(saved) then
        MTPB_Select(saved, false)
    else
        MTPB_Select(nil, false)
    end
    MTPB_ShowTab(ManTechPBDB.tab or "HOME")
end

local function MTPB_CreateFrame()
    if MTPB_FRAME then return end
    local f = CreateFrame("Frame", "ManTechPBFrame", UIParent)
    MTPB_FRAME = f
    f:SetWidth(558); f:SetHeight(452); f:SetScale(1.06)
    f:SetFrameStrata("DIALOG")
    f:SetMovable(true); f:EnableMouse(true)
    f:SetClampedToScreen(true)
    f:SetBackdrop({
        bgFile="Interface\\DialogFrame\\UI-DialogBox-Background",
        edgeFile="Interface\\DialogFrame\\UI-DialogBox-Border",
        tile=true, tileSize=32, edgeSize=24,
        insets={left=8,right=8,top=8,bottom=8}
    })
    f:SetBackdropColor(0.025, 0.035, 0.055, 0.98)
    f:SetBackdropBorderColor(0.08, 0.58, 0.78, 1)

    local point = ManTechPBDB.point or "CENTER"
    f:SetPoint(point, UIParent, ManTechPBDB.relativePoint or point, ManTechPBDB.x or 0, ManTechPBDB.y or 0)

    local drag = CreateFrame("Button", "ManTechPBMainDragRegion", f)
    drag:SetPoint("TOPLEFT", f, "TOPLEFT", 10, -7)
    -- Stop before the Help and Bot Chat controls. The drag target previously
    -- covered both controls and intercepted their clicks on Classic-era UIs.
    drag:SetPoint("TOPRIGHT", f, "TOPRIGHT", -200, -7)
    drag:SetHeight(28)
    drag:RegisterForDrag("LeftButton")
    drag:SetScript("OnDragStart", function() MTPB_FRAME:StartMoving() end)
    drag:SetScript("OnDragStop", function() MTPB_FRAME:StopMovingOrSizing(); MTPB_SavePosition() end)

    local title = f:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    title:SetPoint("TOPLEFT", f, "TOPLEFT", 18, -15)
    title:SetWidth(270); title:SetJustifyH("LEFT")
    title:SetText(MTPB_COLORS.gold .. "MANTECH BOT MANAGER|r")
    ManTechPB_SetReadableFont(title, 14, "OUTLINE")
    local version = f:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    version:SetPoint("LEFT", title, "RIGHT", 8, 0)
    version:SetText(MTPB_COLORS.gray .. "v" .. MTPB_VERSION .. "|r")

    local close = CreateFrame("Button", nil, f, "UIPanelCloseButton")
    close:SetPoint("TOPRIGHT", f, "TOPRIGHT", 3, 3)
    close:SetScript("OnClick", function() MTPB_FRAME:Hide() end)

    local chatToggle = CreateFrame("Button", "ManTechPBChatToggleButton", f, "UIPanelButtonTemplate")
    MTPB_CHAT_TOGGLE_BUTTON = chatToggle
    chatToggle:SetWidth(105); chatToggle:SetHeight(21); chatToggle:SetPoint("TOPRIGHT", f, "TOPRIGHT", -35, -9)
    ManTechPB_StyleButton(chatToggle, 11)
    chatToggle:RegisterForClicks("LeftButtonUp")
    chatToggle:SetScript("OnClick", MTPB_ToggleBotChat)
    MTPB_UpdateChatToggleButton()

    local help = CreateFrame("Button", "ManTechPBMainHelpButton", f, "UIPanelButtonTemplate")
    help:SetWidth(48); help:SetHeight(21); help:SetPoint("RIGHT", chatToggle, "LEFT", -6, 0); help:SetText("Help")
    ManTechPB_StyleButton(help, 11); help:RegisterForClicks("LeftButtonUp"); help:SetScript("OnClick", function() ManTechPB_ShowHelp("OVERVIEW") end)

    local scopeLabel = f:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    scopeLabel:SetPoint("TOPLEFT", f, "TOPLEFT", 18, -42)
    scopeLabel:SetText(MTPB_COLORS.gray .. "CONTROLLING|r")
    ManTechPB_SetReadableFont(scopeLabel, 11, "OUTLINE")
    MTPB_SCOPE_TEXT = f:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    MTPB_SCOPE_TEXT:SetPoint("LEFT", scopeLabel, "RIGHT", 8, 0)

    local sidebar = CreateFrame("Frame", nil, f)
    sidebar:SetPoint("TOPLEFT", f, "TOPLEFT", 14, -64)
    sidebar:SetWidth(142); sidebar:SetHeight(349)
    sidebar:SetBackdrop({bgFile="Interface\\Tooltips\\UI-Tooltip-Background", edgeFile="Interface\\Tooltips\\UI-Tooltip-Border", tile=true, tileSize=16, edgeSize=10, insets={left=3,right=3,top=3,bottom=3}})
    sidebar:SetBackdropColor(0.02, 0.04, 0.065, 0.96)
    sidebar:SetBackdropBorderColor(0.12, 0.36, 0.50, 0.9)

    MTPB_ROSTER_VIEW = ManTechPBDB.rosterView == "ALTS" and "ALTS" or "PARTY"
    local partyView = CreateFrame("Button", nil, sidebar, "UIPanelButtonTemplate")
    partyView:SetWidth(61); partyView:SetHeight(22); partyView:SetPoint("TOPLEFT", sidebar, "TOPLEFT", 8, -8); partyView:SetText("Party")
    ManTechPB_StyleButton(partyView, 11)
    partyView:SetScript("OnClick", function() MTPB_SetRosterView("PARTY") end); MTPB_ROSTER_FILTER_BUTTONS.PARTY = partyView
    local altsView = CreateFrame("Button", nil, sidebar, "UIPanelButtonTemplate")
    altsView:SetWidth(61); altsView:SetHeight(22); altsView:SetPoint("TOPRIGHT", sidebar, "TOPRIGHT", -8, -8); altsView:SetText("My Alts")
    ManTechPB_StyleButton(altsView, 11)
    altsView:SetScript("OnClick", function() MTPB_SetRosterView("ALTS") end); MTPB_ROSTER_FILTER_BUTTONS.ALTS = altsView

    local party = CreateFrame("Button", nil, sidebar, "UIPanelButtonTemplate")
    MTPB_PARTY_SCOPE_BUTTON = party
    party:SetWidth(126); party:SetHeight(23); party:SetPoint("TOP", sidebar, "TOP", 0, -32); party:SetText("Control Entire Party")
    ManTechPB_StyleButton(party, 11)
    party:SetScript("OnClick", function() MTPB_Select(nil) end)

    for i = 1, 10 do
        local b = CreateFrame("Button", nil, sidebar, "UIPanelButtonTemplate")
        b:SetWidth(126); b:SetHeight(20); b:SetPoint("TOP", sidebar, "TOP", 0, -57 - (i-1)*21)
        ManTechPB_StyleButton(b, 11)
        b:SetScript("OnClick", function(self)
            local owner = self or this
            if owner.name then MTPB_Select(owner.name) end
        end)
        b:Hide()
        MTPB_ROSTER_BUTTONS[i] = b
    end
    MTPB_ROSTER_TEXT = sidebar:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    MTPB_ROSTER_TEXT:SetPoint("BOTTOM", sidebar, "BOTTOM", 0, 8)
    MTPB_ROSTER_TEXT:SetTextColor(0.55, 0.63, 0.72)
    ManTechPB_SetReadableFont(MTPB_ROSTER_TEXT, 11, "")

    local login = CreateFrame("Button", "ManTechPBLoginButton", sidebar, "UIPanelButtonTemplate")
    login:SetWidth(61); login:SetHeight(22); login:SetPoint("TOPLEFT", sidebar, "TOPLEFT", 8, -272); login:SetText("Log In")
    ManTechPB_StyleButton(login, 11); login:SetScript("OnClick", function() ManTechPB_SetSelectedBotOnline(true) end)
    login.mtpbSessionTip = "Log in the selected offline bot. Choose it from My Alts first."
    login:SetScript("OnEnter", ManTechPB_ShowSessionTooltip); login:SetScript("OnLeave", function() GameTooltip:Hide() end)
    local logout = CreateFrame("Button", "ManTechPBLogoutButton", sidebar, "UIPanelButtonTemplate")
    logout:SetWidth(61); logout:SetHeight(22); logout:SetPoint("TOPRIGHT", sidebar, "TOPRIGHT", -8, -272); logout:SetText("Log Out")
    ManTechPB_StyleButton(logout, 11); logout:SetScript("OnClick", function() ManTechPB_SetSelectedBotOnline(false) end)
    logout.mtpbSessionTip = "Log out the selected online bot."
    logout:SetScript("OnEnter", ManTechPB_ShowSessionTooltip); logout:SetScript("OnLeave", function() GameTooltip:Hide() end)
    local loginAll = CreateFrame("Button", "ManTechPBLoginAllButton", sidebar, "UIPanelButtonTemplate")
    loginAll:SetWidth(61); loginAll:SetHeight(22); loginAll:SetPoint("TOPLEFT", sidebar, "TOPLEFT", 8, -298); loginAll:SetText("All In")
    ManTechPB_StyleButton(loginAll, 11); loginAll:SetScript("OnClick", function() ManTechPB_SetAllBotsOnline(true) end)
    loginAll.mtpbSessionTip = "Log in every bot listed by this account's bot roster."
    loginAll:SetScript("OnEnter", ManTechPB_ShowSessionTooltip); loginAll:SetScript("OnLeave", function() GameTooltip:Hide() end)
    local logoutAll = CreateFrame("Button", "ManTechPBLogoutAllButton", sidebar, "UIPanelButtonTemplate")
    logoutAll:SetWidth(61); logoutAll:SetHeight(22); logoutAll:SetPoint("TOPRIGHT", sidebar, "TOPRIGHT", -8, -298); logoutAll:SetText("All Out")
    ManTechPB_StyleButton(logoutAll, 11); logoutAll:SetScript("OnClick", function() ManTechPB_SetAllBotsOnline(false) end)
    logoutAll.mtpbSessionTip = "Log out every bot listed by this account's bot roster."
    logoutAll:SetScript("OnEnter", ManTechPB_ShowSessionTooltip); logoutAll:SetScript("OnLeave", function() GameTooltip:Hide() end)

    local tabNames = {{"HOME","Play"},{"SETUP","Setup"},{"COMBAT","Combat"},{"WORLD","World"},{"EXPERT","Expert"}}
    local i, key, label, tab
    for i = 1, table.getn(tabNames) do
        key = tabNames[i][1]; label = tabNames[i][2]
        tab = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
        tab:SetWidth(74); tab:SetHeight(27); tab:SetPoint("TOPLEFT", f, "TOPLEFT", 165 + (i-1)*76, -63)
        tab:SetText(label); tab.key = key
        ManTechPB_StyleButton(tab, 12)
        tab:SetScript("OnClick", function(self)
            local owner = self or this
            MTPB_ShowTab(owner.key)
        end)
        MTPB_TAB_BUTTONS[key] = tab
    end

    local content = CreateFrame("Frame", nil, f)
    content:SetPoint("TOPLEFT", f, "TOPLEFT", 164, -92)
    content:SetWidth(380); content:SetHeight(321)
    local names = {"HOME","SETUP","COMBAT","WORLD","EXPERT"}
    for i = 1, table.getn(names) do
        local panel = CreateFrame("Frame", nil, content)
        panel:SetAllPoints(content)
        panel:Hide()
        MTPB_PANELS[names[i]] = panel
    end
    MTPB_CreateHome(MTPB_PANELS.HOME)
    MTPB_CreateSetup(MTPB_PANELS.SETUP)
    MTPB_CreateCombat(MTPB_PANELS.COMBAT)
    MTPB_CreateWorld(MTPB_PANELS.WORLD)
    MTPB_CreateExpert(MTPB_PANELS.EXPERT)

    local statusBar = CreateFrame("Frame", nil, f)
    statusBar:SetPoint("BOTTOMLEFT", f, "BOTTOMLEFT", 14, 12)
    statusBar:SetWidth(530); statusBar:SetHeight(23)
    statusBar:SetBackdrop({bgFile="Interface\\Tooltips\\UI-Tooltip-Background", edgeFile="Interface\\Tooltips\\UI-Tooltip-Border", tile=true, tileSize=16, edgeSize=8, insets={left=2,right=2,top=2,bottom=2}})
    statusBar:SetBackdropColor(0.01, 0.02, 0.035, 0.95)
    statusBar:SetBackdropBorderColor(0.10, 0.28, 0.38, 0.8)
    MTPB_STATUS = statusBar:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    MTPB_STATUS:SetPoint("LEFT", statusBar, "LEFT", 8, 0)
    MTPB_STATUS:SetWidth(515); MTPB_STATUS:SetJustifyH("LEFT")
    ManTechPB_SetReadableFont(MTPB_STATUS, 12, "")

    f:SetScript("OnShow", function()
        if MTPB_UpdateBotList then MTPB_UpdateBotList(0) end
        if MTPB_SELECTED and MTPB_QuerySelectedBot then MTPB_QuerySelectedBot(MTPB_SELECTED)
        elseif MTPB_QueryBotParty then MTPB_QueryBotParty() end
        MTPB_UpdateRoster(); MTPB_UpdateCards()
    end)
    f:SetScript("OnUpdate", function(self, elapsed)
        local delta = elapsed or arg1 or 0
        MTPB_REFRESH_ELAPSED = MTPB_REFRESH_ELAPSED + delta
        if MTPB_REFRESH_ELAPSED >= 1 then
            MTPB_REFRESH_ELAPSED = 0
            MTPB_UpdateRoster(); MTPB_UpdateCards()
        end
    end)
    f:Hide()
    MTPB_RestoreMainFrameState()
end

function ManTechPB_Toggle()
    MTPB_CreateFrame()
    if MTPB_FRAME:IsVisible() then MTPB_FRAME:Hide()
    else
        MTPB_FRAME:Show()
    end
end

local function MTPB_ShowFocusTab(name)
    local key, panel
    for key, panel in pairs(MTPB_FOCUS_PANELS) do if key == name then panel:Show() else panel:Hide() end end
    for key, panel in pairs(MTPB_FOCUS_TABS) do if key == name then panel:LockHighlight() else panel:UnlockHighlight() end end
    MTPB_UpdateCards()
end

local function MTPB_CreateFocusToggleCards(panel, data)
    local i, entry, card, col, row
    for i = 1, table.getn(data) do
        entry = data[i]
        col = (i - 1) - math.floor((i - 1) / 2) * 2
        row = math.floor((i - 1) / 2)
        card = MTPB_CreateCard(panel, 4 + col*205, -26 - row*50, 198, entry[1], entry[2], entry[3], function(self)
            local owner = self or this
            if owner.mtbmExclusive then MTPB_SetExclusive(owner.mtbmStrategy, owner.mtbmExclusive, owner.mtbmContexts, owner.mtbmLabel)
            else MTPB_ToggleStrategy(owner.mtbmStrategy, owner.mtbmContexts, owner.mtbmLabel) end
        end)
        card:SetHeight(43)
        card.mtbmLabel = entry[1]
        card.mtbmExclusive = entry[6]
        MTPB_RegisterStateCard(card, entry[4], entry[5])
    end
end

local function MTPB_CreateFocusFrame()
    if MTPB_FOCUS_FRAME then return end
    local f = CreateFrame("Frame", "ManTechPBIndividualFrame", UIParent)
    MTPB_FOCUS_FRAME = f
    f:SetWidth(450); f:SetHeight(440); f:SetFrameStrata("DIALOG"); f:SetScale(1.06)
    f:SetMovable(true); f:EnableMouse(true); f:SetClampedToScreen(true)
    f:SetBackdrop({bgFile="Interface\\DialogFrame\\UI-DialogBox-Background",edgeFile="Interface\\DialogFrame\\UI-DialogBox-Border",tile=true,tileSize=32,edgeSize=24,insets={left=8,right=8,top=8,bottom=8}})
    f:SetBackdropColor(0.025,0.035,0.055,0.98); f:SetBackdropBorderColor(0.08,0.58,0.78,1)
    f:SetPoint("CENTER", UIParent, "CENTER", 0, 20)

    local drag = CreateFrame("Button", "ManTechPBIndividualDragRegion", f)
    -- Leave the entire Help/Manager cluster outside the draggable title area.
    drag:SetPoint("TOPLEFT", f, "TOPLEFT", 10, -7); drag:SetPoint("TOPRIGHT", f, "TOPRIGHT", -168, -7); drag:SetHeight(36)
    drag:RegisterForDrag("LeftButton"); drag:SetScript("OnDragStart", function() f:StartMoving() end); drag:SetScript("OnDragStop", function() f:StopMovingOrSizing() end)
    MTPB_FOCUS_TITLE = f:CreateFontString(nil,"OVERLAY","GameFontNormal")
    MTPB_FOCUS_TITLE:SetPoint("TOPLEFT",f,"TOPLEFT",18,-15); MTPB_FOCUS_TITLE:SetWidth(270); MTPB_FOCUS_TITLE:SetJustifyH("LEFT"); ManTechPB_SetReadableFont(MTPB_FOCUS_TITLE,13,"OUTLINE")
    MTPB_FOCUS_SUBTITLE = f:CreateFontString(nil,"OVERLAY","GameFontNormalSmall")
    MTPB_FOCUS_SUBTITLE:SetPoint("TOPLEFT",f,"TOPLEFT",18,-33); ManTechPB_SetReadableFont(MTPB_FOCUS_SUBTITLE,11,"")
    local close=CreateFrame("Button",nil,f,"UIPanelCloseButton"); close:SetPoint("TOPRIGHT",f,"TOPRIGHT",3,3); close:SetScript("OnClick",function() f:Hide() end)
    local manager=CreateFrame("Button","ManTechPBIndividualManagerButton",f,"UIPanelButtonTemplate"); manager:SetWidth(72); manager:SetHeight(23); manager:SetPoint("TOPRIGHT",f,"TOPRIGHT",-34,-9); manager:SetText("Manager"); ManTechPB_StyleButton(manager,11); manager:RegisterForClicks("LeftButtonUp")
    manager:SetScript("OnClick",function() MTPB_CreateFrame(); MTPB_FRAME:Show() end)
    local help=CreateFrame("Button","ManTechPBIndividualHelpButton",f,"UIPanelButtonTemplate"); help:SetWidth(48); help:SetHeight(23); help:SetPoint("RIGHT",manager,"LEFT",-5,0); help:SetText("Help"); ManTechPB_StyleButton(help,11); help:RegisterForClicks("LeftButtonUp")
    help:SetScript("OnClick",function() ManTechPB_ShowHelp("INDIVIDUAL") end)

    local tabs={{"QUICK","Quick"},{"ROLE","Role"},{"TACTIC","Tactic"},{"COMBAT","Fight"},{"SUPPORT","Support"},{"WORLD","World"}}
    local i, tab
    for i=1,table.getn(tabs) do
        tab=CreateFrame("Button",nil,f,"UIPanelButtonTemplate"); tab:SetWidth(65); tab:SetHeight(25); tab:SetPoint("TOPLEFT",f,"TOPLEFT",18+(i-1)*68,-56); tab:SetText(tabs[i][2]); tab.key=tabs[i][1]
        ManTechPB_StyleButton(tab,11)
        tab:SetScript("OnClick",function(self) local owner=self or this; MTPB_ShowFocusTab(owner.key) end); MTPB_FOCUS_TABS[tabs[i][1]]=tab
    end
    local content=CreateFrame("Frame",nil,f); content:SetPoint("TOPLEFT",f,"TOPLEFT",17,-88); content:SetWidth(416); content:SetHeight(307)
    local names={"QUICK","ROLE","TACTIC","COMBAT","SUPPORT","WORLD"}
    for i=1,table.getn(names) do local panel=CreateFrame("Frame",nil,content); panel:SetAllPoints(content); panel:Hide(); MTPB_FOCUS_PANELS[names[i]]=panel end

    local quick={
        {"Attack Target","Attack your selected enemy","Ability_DualWield",function() MTPB_SendDirect("attack","attack",true) end},
        {"Follow Me","Return to your side","Ability_Hunter_BeastCall",function() MTPB_SendCommands({"#a follow ?"},"follow") end},
        {"Stay Here","Hold this position","Spell_Nature_TimeStop",function() MTPB_SendCommands({"#a stay ?"},"stay") end},
        {"Come to Me","Summon this bot","Spell_Shadow_Twilight",function() MTPB_SendDirect("summon","summon") end},
        {"Retreat","Break combat and return","Ability_Rogue_FeignDeath",function() MTPB_SendCommands({"#a flee ?"},"retreat") end},
        {"Reset AI","Clear a stuck decision","INV_Misc_PocketWatch_01",function() MTPB_SendDirect("reset","reset") end}
    }
    for i=1,table.getn(quick) do local col=(i-1)-math.floor((i-1)/2)*2; local row=math.floor((i-1)/2); MTPB_CreateCard(MTPB_FOCUS_PANELS.QUICK,4+col*205,-10-row*66,198,quick[i][1],quick[i][2],quick[i][3],quick[i][4]) end

    MTPB_FOCUS_NOTE=MTPB_FOCUS_PANELS.ROLE:CreateFontString(nil,"OVERLAY","GameFontNormalSmall"); MTPB_FOCUS_NOTE:SetPoint("TOPLEFT",MTPB_FOCUS_PANELS.ROLE,"TOPLEFT",4,-4); MTPB_FOCUS_NOTE:SetWidth(300); MTPB_FOCUS_NOTE:SetJustifyH("LEFT")
    ManTechPB_SetReadableFont(MTPB_FOCUS_NOTE,11,"")
    local talents=CreateFrame("Button",nil,MTPB_FOCUS_PANELS.ROLE,"UIPanelButtonTemplate"); talents:SetWidth(96); talents:SetHeight(23); talents:SetPoint("TOPRIGHT",MTPB_FOCUS_PANELS.ROLE,"TOPRIGHT",-4,2); talents:SetText("Talents..."); ManTechPB_StyleButton(talents,11); talents:SetScript("OnClick",MTPB_ShowTalentManager)
    for i=1,4 do local col=(i-1)-math.floor((i-1)/2)*2; local row=math.floor((i-1)/2); local slot=MTPB_CreateCard(MTPB_FOCUS_PANELS.ROLE,4+col*205,-47-row*62,198,"","","INV_Misc_QuestionMark",function(self) local owner=self or this; if owner.spec then MTPB_ApplySpec(owner.spec) end end); slot:Hide(); MTPB_FOCUS_ROLE_SLOTS[i]=slot end

    MTPB_CreateFocusToggleCards(MTPB_FOCUS_PANELS.TACTIC,{
        {"Tank Assist","Grab aggro and lead attacks","Ability_Warrior_DefensiveStance","tank assist",{"co","nc"},"dps assist"},{"Damage Assist","Focus the tank's target","Ability_Warrior_OffensiveStance","dps assist",{"co","nc"},"tank assist"},
        {"Melee / Close","Fight at close range","Ability_MeleeDamage","close",{"co"},"ranged"},{"Ranged","Fight from ranged distance","Ability_Hunter_Quickshot","ranged",{"co"},"close"},
        {"Pull","This bot performs pulls","Ability_Hunter_SniperShot","pull",{"co"}},{"Pull Back","Return after drawing the target","Ability_Rogue_Sprint","pull back",{"co"}},
        {"Wait to Attack","Delay initial attacks","INV_Misc_PocketWatch_01","wait for attack",{"co"}},{"Low Threat","Avoid high-threat actions","Spell_Magic_LesserInvisibilty","threat",{"co"}},
        {"Passive","Do not initiate normal combat","Ability_Rogue_FeignDeath","passive",{"co","nc"}},{"Aggressive","Actively grind nearby enemies","Ability_DualWield","grind",{"nc"}}
    })
    MTPB_CreateFocusToggleCards(MTPB_FOCUS_PANELS.COMBAT,{
        {"AOE","Use area attacks","Spell_Fire_SelfDestruct","aoe",{"co","nc"}},{"Crowd Control","Use available CC","Spell_Frost_ChainsOfIce","cc",{"co"}},
        {"Avoid Adds","Reduce extra pulls","Ability_Sap","ads",{"co","nc"}},{"Avoid Mobs","Avoid hostile mobs while moving","Ability_Rogue_Sprint","avoid mobs",{"co","nc"}},
        {"Use Potions","Health and mana potions","INV_Potion_54","potions",{"react"}},{"Conserve Mana","Trade output for mana efficiency","Spell_Nature_RavenForm","conserve mana",{"co"}},
        {"Auto Mark","Automatically assign raid targets","Ability_Hunter_SniperShot","mark rti",{"co"}},{"Cast Time","Avoid long casts on dying targets","Spell_Nature_TimeStop","cast time",{"co"}}
    })
    MTPB_CreateFocusToggleCards(MTPB_FOCUS_PANELS.SUPPORT,{
        {"Cleanse","Remove harmful effects","Spell_Holy_DispelMagic","cure",{"co","nc"}},{"Buff","Maintain useful buffs","Spell_Holy_GreaterBlessingofKings","buff",{"co","nc"}},
        {"Boost","Use cooldown abilities","Spell_Nature_LightningOverload","boost",{"co","nc"}},{"Off-heal","DPS can help heal","Spell_Holy_FlashHeal","offheal",{"co","nc"}},
        {"Healer DPS","Allow damage spells while healing","Spell_Holy_HolySmite","offdps",{"co"}},{"Pre-heal","Prepare healing before damage","Spell_Holy_GreaterHeal","preheal",{"co"}}
    })
    MTPB_CreateFocusToggleCards(MTPB_FOCUS_PANELS.WORLD,{
        {"Food & Drink","Recover between fights","INV_Misc_Food_15","food",{"nc"}},{"Loot","Loot defeated enemies","INV_Misc_Bag_10","loot",{"nc"}},
        {"Gather","Gather herbs and ore","INV_Misc_Herb_11","gather",{"nc"}},{"Mount","Mount when appropriate","Ability_Mount_RidingHorse","mount",{"nc"}},
        {"Travel","Long-distance travel logic","INV_Misc_Map_01","travel",{"nc"}},{"RPG","Interact with the world","INV_Misc_Book_11","rpg",{"nc"}},
        {"Buff","Maintain useful buffs","Spell_Holy_GreaterBlessingofKings","buff",{"co","nc"}},{"Free Roam","Allow independent movement","Ability_Rogue_Sprint","free",{"nc"}}
    })
    local formationNote=MTPB_FOCUS_PANELS.WORLD:CreateFontString(nil,"OVERLAY","GameFontNormalSmall")
    formationNote:SetPoint("BOTTOMLEFT",MTPB_FOCUS_PANELS.WORLD,"BOTTOMLEFT",6,16); formationNote:SetWidth(400); formationNote:SetJustifyH("LEFT")
    ManTechPB_SetReadableFont(formationNote,11,"")
    formationNote:SetText(MTPB_COLORS.gray .. "Group formations (Near, Melee, Arrow, Far, Chaos) are in the full Manager > World tab.|r")

    local status=CreateFrame("Frame",nil,f); status:SetPoint("BOTTOMLEFT",f,"BOTTOMLEFT",15,12); status:SetWidth(420); status:SetHeight(25); status:SetBackdrop({bgFile="Interface\\Tooltips\\UI-Tooltip-Background",edgeFile="Interface\\Tooltips\\UI-Tooltip-Border",tile=true,tileSize=16,edgeSize=8,insets={left=2,right=2,top=2,bottom=2}}); status:SetBackdropColor(0.01,0.02,0.035,0.95)
    MTPB_FOCUS_STATUS=status:CreateFontString(nil,"OVERLAY","GameFontNormalSmall"); MTPB_FOCUS_STATUS:SetPoint("LEFT",status,"LEFT",8,0); MTPB_FOCUS_STATUS:SetWidth(404); MTPB_FOCUS_STATUS:SetJustifyH("LEFT")
    ManTechPB_SetReadableFont(MTPB_FOCUS_STATUS,12,"")
    f:SetScript("OnUpdate",function(self,elapsed) local owner=self or this; owner.refresh=(owner.refresh or 0)+(elapsed or arg1 or 0); if owner.refresh>=0.75 then owner.refresh=0; MTPB_UpdateCards() end end)
    f:Hide(); MTPB_ShowFocusTab("QUICK")
end

local function MTPB_GetFriendlyTargetName()
    if not UnitExists("target") or UnitIsEnemy("target", "player") or not UnitIsPlayer("target") then return nil end
    local name = UnitName("target")
    if not name or name == UnitName("player") then return nil end
    return name
end

function ManTechPB_OpenForTarget(requestedName)
    local name = requestedName or MTPB_GetFriendlyTargetName()
    if not name then return false end
    if GetTime() - MTPB_LAST_ALT_OPEN < 0.20 and name == MTPB_SELECTED and MTPB_FOCUS_FRAME and MTPB_FOCUS_FRAME:IsVisible() then return true end
    MTPB_LAST_ALT_OPEN = GetTime()
    if not MTPB_BOTS[name] then MTPB_BOTS[name] = {online=true} end
    if UnitName("target") == name then
        local _, class = UnitClass("target")
        if class then MTPB_BOTS[name].class = class end
    end
    MTPB_CreateFrame()
    MTPB_CreateFocusFrame()
    MTPB_Select(name)
    MTPB_ShowFocusTab("QUICK")
    MTPB_FOCUS_FRAME:Show()
    MTPB_UpdateRoster()
    MTPB_SetStatus("Loading " .. name .. "'s confirmed bot settings...", MTPB_COLORS.yellow)
    return true
end

local function MTPB_CreateAltClickWatcher()
    if MTPB_ALT_CLICK_FRAME then return end
    MTPB_ALT_CLICK_FRAME = CreateFrame("Frame")
    if WorldFrame and WorldFrame.GetScript and WorldFrame.SetScript then
        local previousMouseUp = WorldFrame:GetScript("OnMouseUp")
        WorldFrame:SetScript("OnMouseUp", function(self, button)
            if previousMouseUp then previousMouseUp(self, button) end
            local clicked = button or arg1
            if clicked == "LeftButton" and IsAltKeyDown and IsAltKeyDown() then
                MTPB_Wait(0.04, function() ManTechPB_OpenForTarget() end)
            end
        end)
    end
    MTPB_ALT_CLICK_FRAME:SetScript("OnUpdate", function()
        local down = IsMouseButtonDown and IsMouseButtonDown("LeftButton")
        if down and not MTPB_ALT_LEFT_WAS_DOWN and IsAltKeyDown and IsAltKeyDown() then
            local focus = GetMouseFocus and GetMouseFocus()
            if not focus or focus == WorldFrame then
                MTPB_Wait(0.06, function() ManTechPB_OpenForTarget() end)
            end
        end
        MTPB_ALT_LEFT_WAS_DOWN = down and true or false
    end)
end

local MTPB_BOT_BAR_ACTIONS = {
    {title="Attack", icon="Interface\\Icons\\Ability_MeleeDamage", command="attack", target=true, tip="Order the party bots to attack your target."},
    {title="Tank Pull", icon="Interface\\Icons\\Ability_Warrior_DefensiveStance", prepare="@tank co +pull", command="@tank pull", target=true, tip="Enable pulling and order the party's tank bot to pull your target.", scope="Targets the party's tank bot."},
    {title="Follow", icon="Interface\\Icons\\Ability_Tracking", command="follow", tip="Order every party bot to follow you."},
    {title="Stay", icon="Interface\\Icons\\Ability_Defend", command="stay", tip="Order every party bot to stay here."},
    {title="Flee", icon="Interface\\Icons\\Ability_Rogue_Sprint", command="flee", tip="Break combat and return to the master."},
    {title="Reset AI", icon="Interface\\Icons\\INV_Misc_PocketWatch_01", command="reset", tip="Clear the party bots' current AI state."},
    {title="Summon", icon="Interface\\Icons\\Spell_Shadow_Twilight", command="summon", tip="Ask the party bots to summon to you."},
    {title="Give Leader", icon="Interface\\Icons\\INV_BannerPVP_01", command="give leader", tip="Ask the bot leader to promote you."}
}

local function MTPB_SaveBotBarPosition()
    if not MTPB_BOT_BAR or not ManTechPBDB then return end
    local point, _, relativePoint, x, y = MTPB_BOT_BAR:GetPoint()
    ManTechPBDB.botBarPoint = point
    ManTechPBDB.botBarRelativePoint = relativePoint
    ManTechPBDB.botBarX = x
    ManTechPBDB.botBarY = y
end

local function MTPB_SendBotBarAction(action)
    if MTPB_PartySize() == 0 then
        MTPB_Chat("Join a party with PlayerBots first.")
        return
    end
    if action.target and (not UnitExists("target") or not UnitCanAttack("player", "target")) then
        MTPB_Chat("Select an attackable target first.")
        return
    end
    if action.prepare then MTPB_SendRawCommand(action.prepare, "PARTY") end
    MTPB_SendRawCommand(action.command, "PARTY")
end

local function MTPB_CreateBotBar()
    if MTPB_BOT_BAR then return end
    local count = table.getn(MTPB_BOT_BAR_ACTIONS)
    local frame = CreateFrame("Frame", "ManTechPBBotBar", UIParent)
    MTPB_BOT_BAR = frame
    frame:SetWidth(331); frame:SetHeight(70)
    frame:SetFrameStrata("MEDIUM")
    frame:SetMovable(true); frame:EnableMouse(true)
    frame:SetBackdrop({
        bgFile="Interface\\DialogFrame\\UI-DialogBox-Background",
        edgeFile="Interface\\DialogFrame\\UI-DialogBox-Border",
        tile=true, tileSize=16, edgeSize=16,
        insets={left=5,right=5,top=5,bottom=5}
    })
    frame:SetBackdropColor(0.025, 0.035, 0.055, 0.96)
    frame:ClearAllPoints()
    frame:SetPoint(ManTechPBDB.botBarPoint or "CENTER", UIParent,
        ManTechPBDB.botBarRelativePoint or "CENTER",
        ManTechPBDB.botBarX or 0, ManTechPBDB.botBarY or -180)

    local title = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    title:SetPoint("TOPLEFT", frame, "TOPLEFT", 10, -10)
    title:SetText(MTPB_COLORS.gold .. "MANTECH BOT BAR|r")

    local open = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
    open:SetWidth(62); open:SetHeight(20); open:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -8, -5)
    open:SetText("Manager")
    ManTechPB_StyleButton(open, 10)
    open:SetScript("OnClick", function() ManTechPB_Toggle() end)

    local help = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
    help:SetWidth(22); help:SetHeight(20); help:SetPoint("RIGHT", open, "LEFT", -4, 0); help:SetText("?")
    ManTechPB_StyleButton(help, 11); help:SetScript("OnClick", function() ManTechPB_ShowHelp("CHAT") end)

    local drag = CreateFrame("Button", nil, frame)
    drag:SetPoint("TOPLEFT", frame, "TOPLEFT", 7, -4)
    drag:SetPoint("TOPRIGHT", open, "TOPLEFT", -3, 0)
    drag:SetHeight(22); drag:RegisterForDrag("LeftButton")
    drag:SetScript("OnDragStart", function() MTPB_BOT_BAR:StartMoving() end)
    drag:SetScript("OnDragStop", function() MTPB_BOT_BAR:StopMovingOrSizing(); MTPB_SaveBotBarPosition() end)

    local i
    for i = 1, count do
        local action = MTPB_BOT_BAR_ACTIONS[i]
        local button = CreateFrame("Button", "ManTechPBBotBarButton" .. i, frame)
        button:SetWidth(36); button:SetHeight(36)
        button:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", 10 + (i-1)*39, 7)
        button:RegisterForClicks("LeftButtonUp")
        button.action = action
        local background = button:CreateTexture(nil, "BACKGROUND")
        background:SetTexture("Interface\\Buttons\\UI-Quickslot2")
        background:SetAllPoints(button)
        local icon = button:CreateTexture(nil, "ARTWORK")
        icon:SetTexture(action.icon); icon:SetTexCoord(0.08,0.92,0.08,0.92)
        icon:SetPoint("TOPLEFT", button, "TOPLEFT", 4, -4)
        icon:SetPoint("BOTTOMRIGHT", button, "BOTTOMRIGHT", -4, 4)
        button:SetHighlightTexture("Interface\\Buttons\\ButtonHilight-Square")
        button:SetScript("OnClick", function(self)
            local owner = self or this
            MTPB_SendBotBarAction(owner.action)
        end)
        button:SetScript("OnEnter", function(self)
            local owner = self or this
            GameTooltip:SetOwner(owner, "ANCHOR_TOP")
            GameTooltip:SetText(owner.action.title, 1, 0.82, 0)
            GameTooltip:AddLine(owner.action.tip, 1, 1, 1, true)
            GameTooltip:AddLine(owner.action.scope or "Affects the entire PlayerBot party.", 0.45, 0.8, 1, true)
            GameTooltip:Show()
        end)
        button:SetScript("OnLeave", function() GameTooltip:Hide() end)
    end
    if ManTechPBDB.botBarShown == false then frame:Hide() else frame:Show() end
end

function ManTechPB_ToggleBotBar()
    MTPB_CreateBotBar()
    if MTPB_BOT_BAR:IsVisible() then
        MTPB_BOT_BAR:Hide(); ManTechPBDB.botBarShown = false
    else
        MTPB_BOT_BAR:Show(); ManTechPBDB.botBarShown = true
    end
end

local function MTPB_UpdateMinimapPosition()
    if not MTPB_MINIMAP_BUTTON or not Minimap then return end
    MTPB_MINIMAP_BUTTON:ClearAllPoints()
    MTPB_MINIMAP_BUTTON:SetPoint("CENTER", Minimap, "CENTER", ManTechPBDB.minimapX or -56, ManTechPBDB.minimapY or -56)
end

local function MTPB_MoveMinimapButton()
    local owner = this or MTPB_MINIMAP_BUTTON
    if not owner or not Minimap then return end
    local x, y = GetCursorPosition()
    local scale = UIParent:GetEffectiveScale() or 1
    local centerX, centerY = Minimap:GetCenter()
    if not centerX or not centerY then return end
    x, y = x / scale - centerX, y / scale - centerY
    local distance = math.sqrt(x*x + y*y)
    if distance < 1 then return end
    local radius = ((Minimap:GetWidth() or 140) / 2) + 8
    ManTechPBDB.minimapX = x / distance * radius
    ManTechPBDB.minimapY = y / distance * radius
    owner.wasDragged = true
    MTPB_UpdateMinimapPosition()
end

local function MTPB_CreateMinimapButton()
    if MTPB_MINIMAP_BUTTON or not Minimap then return end
    local button = CreateFrame("Button", "ManTechPBMinimapButton", Minimap)
    MTPB_MINIMAP_BUTTON = button
    -- The tracking-border artwork is drawn in the upper-left of its texture,
    -- not around the texture's center. Centering that texture displaced the
    -- ring from the icon and produced the black-ring/stray-art appearance.
    button:SetWidth(24); button:SetHeight(24); button:SetFrameStrata("MEDIUM")
    button:EnableMouse(true); button:RegisterForClicks("LeftButtonUp", "RightButtonUp"); button:RegisterForDrag("LeftButton")
    if button.SetHitRectInsets then button:SetHitRectInsets(-4, -4, -4, -4) end
    local bg = button:CreateTexture(nil, "BACKGROUND")
    bg:SetTexture("Interface\\Minimap\\UI-Minimap-Background"); bg:SetWidth(20); bg:SetHeight(20); bg:SetPoint("CENTER", button, "CENTER")
    local icon = button:CreateTexture(nil, "ARTWORK")
    icon:SetTexture("Interface\\Icons\\Ability_Hunter_BeastCall"); icon:SetWidth(16); icon:SetHeight(16); icon:SetPoint("CENTER", button, "CENTER"); icon:SetTexCoord(0.12,0.88,0.12,0.88)
    local border = button:CreateTexture(nil, "OVERLAY")
    border:SetTexture("Interface\\Minimap\\MiniMap-TrackingBorder"); border:SetWidth(42); border:SetHeight(42); border:SetPoint("TOPLEFT", button, "TOPLEFT", 0, 0)
    button.mtpbIcon = icon
    button.mtpbBorder = border
    button:SetHighlightTexture("Interface\\Minimap\\UI-Minimap-ZoomButton-Highlight")
    button:SetScript("OnClick", function(self, buttonName)
        local owner, clicked = self or this, buttonName or arg1
        if clicked == "RightButton" then ManTechPBDB.minimapX = -56; ManTechPBDB.minimapY = -56; MTPB_UpdateMinimapPosition()
        elseif not owner.wasDragged then ManTechPB_Toggle() end
        owner.wasDragged = nil
    end)
    button:SetScript("OnDragStart", function(self)
        local owner = self or this
        owner.wasDragged = nil; owner:LockHighlight(); owner:SetScript("OnUpdate", MTPB_MoveMinimapButton)
    end)
    button:SetScript("OnDragStop", function(self)
        local owner = self or this
        owner:UnlockHighlight(); owner:SetScript("OnUpdate", nil)
    end)
    button:SetScript("OnEnter", function(self)
        local owner = self or this
        GameTooltip:SetOwner(owner, "ANCHOR_LEFT"); GameTooltip:SetText("ManTechPB", 0.30, 0.85, 1)
        GameTooltip:AddLine("Left-click: open PlayerBots manager", 1, 1, 1)
        GameTooltip:AddLine("Drag: move icon", 1, 1, 1)
        GameTooltip:AddLine("Right-click: reset position", 1, 1, 1); GameTooltip:Show()
    end)
    button:SetScript("OnLeave", function() GameTooltip:Hide() end)
    MTPB_UpdateMinimapPosition()
end

SLASH_MANTECHPB1 = "/mtp"
SLASH_MANTECHPB2 = "/mantechpb"
SlashCmdList.MANTECHPB = function(message)
    local command = MTPB_Trim(message or "")
    if command == "bar" then ManTechPB_ToggleBotBar()
    elseif command == "chat" then MTPB_ToggleBotChat()
    elseif command == "chat hide" then MTPB_SetBotChatHidden(true)
    elseif command == "chat show" then MTPB_SetBotChatHidden(false)
    elseif command == "bar reset" then
        ManTechPBDB.botBarPoint = "CENTER"; ManTechPBDB.botBarRelativePoint = "CENTER"
        ManTechPBDB.botBarX = 0; ManTechPBDB.botBarY = -180
        if MTPB_BOT_BAR then
            MTPB_BOT_BAR:ClearAllPoints()
            MTPB_BOT_BAR:SetPoint("CENTER", UIParent, "CENTER", 0, -180)
        end
    else ManTechPB_Toggle() end
end

local MTPB_EVENTS = CreateFrame("Frame")
MTPB_EVENTS:RegisterEvent("VARIABLES_LOADED")
MTPB_EVENTS:RegisterEvent("PARTY_MEMBERS_CHANGED")
MTPB_EVENTS:RegisterEvent("PLAYER_TARGET_CHANGED")
MTPB_EVENTS:RegisterEvent("CHAT_MSG_WHISPER")
MTPB_EVENTS:RegisterEvent("CHAT_MSG_PARTY")
pcall(MTPB_EVENTS.RegisterEvent, MTPB_EVENTS, "CHAT_MSG_PARTY_LEADER")
MTPB_EVENTS:RegisterEvent("CHAT_MSG_ADDON")
MTPB_EVENTS:RegisterEvent("CHAT_MSG_SYSTEM")
MTPB_EVENTS:SetScript("OnEvent", function(self, eventName, a1, a2, a3, a4)
    local currentEvent = eventName or event
    local p1, p2, p3, p4 = a1 or arg1, a2 or arg2, a3 or arg3, a4 or arg4
    if currentEvent == "VARIABLES_LOADED" then
        if not ManTechPBDB then ManTechPBDB = {} end
        if ManTechPBDB.hideBotReplies == nil then ManTechPBDB.hideBotReplies = true end
        MTPB_InstallChatFilter()
        MTPB_CreateMinimapButton()
        MTPB_CreateBotBar()
        MTPB_CreateFrame()
        MTPB_CreateAltClickWatcher()
        MTPB_UpdateBotList(0.2)
        MTPB_Chat("loaded. Use /mtp or the minimap button.")
    elseif currentEvent == "CHAT_MSG_SYSTEM" then
        MTPB_ParseRoster(p1)
        if MTPB_FRAME then MTPB_UpdateRoster(); MTPB_UpdateCards() end
    elseif currentEvent == "CHAT_MSG_WHISPER" then
        MTPB_ParseTalentReply(p1, p2)
        MTPB_ParseStrategies(p1, p2)
        if MTPB_FRAME then MTPB_UpdateCards() end
    elseif currentEvent == "CHAT_MSG_PARTY" or currentEvent == "CHAT_MSG_PARTY_LEADER" then
        -- Some Playerbot cores answer a privately whispered "talents list"
        -- in party chat. Capture that response without treating ordinary party
        -- conversation as a command result.
        MTPB_ParseTalentReply(p1, p2)
        MTPB_ParseStrategies(p1, p2)
    elseif currentEvent == "CHAT_MSG_ADDON" then
        if p1 == "BOT" then MTPB_ParseTalentReply(p2, p4); MTPB_ParseStrategies(p2, p4) end
        if MTPB_FRAME then MTPB_UpdateCards() end
    elseif currentEvent == "PARTY_MEMBERS_CHANGED" then
        -- Roster changes can fire several times while logging in or reloading.
        -- Refresh the local UI only; query settings when the user opens the
        -- manager, selects a bot, or presses Refresh.
        if MTPB_FRAME then MTPB_UpdateRoster(); MTPB_UpdateCards() end
    elseif currentEvent == "PLAYER_TARGET_CHANGED" and IsAltKeyDown and IsAltKeyDown() then
        ManTechPB_OpenForTarget()
    elseif MTPB_FRAME then
        MTPB_UpdateRoster()
        MTPB_UpdateCards()
    end
end)
