local frames = {}
local raidMode = arg[2] == "raid"
local groupEvent = raidMode and "CHAT_MSG_RAID" or "CHAT_MSG_PARTY"
local rosterEvent = raidMode and "RAID_ROSTER_UPDATE" or "PARTY_MEMBERS_CHANGED"
local expectedGroupChannel = raidMode and "RAID" or "PARTY"
local function botSender(name) return raidMode and (name .. "-TestRealm") or name end
local function noop() end
local methods = {}
function methods:RegisterEvent(name) self.events = self.events or {}; self.events[name] = true end
function methods:SetScript(name, fn) self.scripts = self.scripts or {}; self.scripts[name] = fn end
function methods:GetScript(name) return self.scripts and self.scripts[name] end
function methods:Show() self.visible = true; if type(self.scripts)=="table" and self.scripts.OnShow then self.scripts.OnShow(self) end end
function methods:Hide() self.visible = false end
function methods:IsVisible() return self.visible == true end
function methods:SetWidth(value) self.width = value end
function methods:SetHeight(value) self.height = value end
function methods:SetScale(value) self.scale = value end
function methods:GetWidth() return self.width or 140 end
function methods:GetHeight() return self.height or 30 end
function methods:GetCenter() return 500, 500 end
function methods:GetEffectiveScale() return 1 end
function methods:SetPoint(a, b, c, d, e) self.pointArgs = {a, b, c, d, e} end
function methods:GetPoint() if self.pointArgs then return unpack(self.pointArgs) end; return "CENTER", UIParent, "CENTER", 0, 0 end
function methods:SetText(value) self.text = value end
function methods:GetText() return self.text end
function methods:Enable() self.enabled = true end
function methods:Disable() self.enabled = false end
function methods:SetBackdropBorderColor(r, g, b, a) self.borderColor = {r, g, b, a} end
function methods:CreateTexture() local value=setmetatable({}, {__index=methods}); return value end
function methods:CreateFontString() local value=setmetatable({}, {__index=methods}); return value end
function methods:GetFontString() return rawget(self, "fontString") or setmetatable({}, {__index=methods}) end
setmetatable(methods, {__index=function() return noop end})
local function object(name)
    local value = setmetatable({name=name, visible=false, scripts={}, events={}}, {__index=methods})
    table.insert(frames, value)
    return value
end
function CreateFrame(kind, name) local value=object(name); value.kind=kind; if name then _G[name]=value end; return value end
UIParent = object("UIParent")
WorldFrame = object("WorldFrame")
Minimap = object("Minimap")
GameTooltip = object("GameTooltip")
DEFAULT_CHAT_FRAME = object("DEFAULT_CHAT_FRAME")
DEFAULT_CHAT_FRAME.editBox = object("ChatFrameEditBox")
ChatFrameEditBox = DEFAULT_CHAT_FRAME.editBox
SlashCmdList = {}
MTPB_TEST_HOOKS = {}
function getglobal(name) return _G[name] end
local fakeTime = 0
local sentMessages = {}
local sentAddonMessages = {}
local whoQueries = {}
function GetTime() return fakeTime end
function GetCursorPosition() return 540, 540 end
function GetNumPartyMembers() return raidMode and 0 or 2 end
function GetNumRaidMembers() return raidMode and 3 or 0 end
function GetRealmName() return "TestRealm" end
function GetBuildInfo()
    local path = arg[1] or ""
    if string.find(path, "WotLK", 1, true) then return "3.3.5", "12340", "Jun 24 2010", 30300 end
    if string.find(path, "TBC", 1, true) then return "2.4.3", "8606", "Jul 10 2008", 20400 end
    return "1.12.1", "5875", "Sep 19 2006", 11200
end
function UnitLevel() return 42 end
function UnitName(unit)
    if unit=="player" or (raidMode and unit=="raid1") then return "Tester"
    elseif unit=="party1" or (raidMode and unit=="raid2") or unit=="target" then return "Healbot"
    elseif unit=="party2" or (raidMode and unit=="raid3") then return "Tankbot" end
end
function UnitClass(unit)
    if unit=="party1" or (raidMode and unit=="raid2") or unit=="target" then return "Priest", "PRIEST"
    elseif unit=="party2" or (raidMode and unit=="raid3") then return "Warrior", "WARRIOR" end
end
function UnitExists(unit) return UnitName(unit) ~= nil end
function UnitCanAttack() return true end
function UnitIsEnemy() return false end
function UnitIsPlayer() return true end
function SendChatMessage(text, chat, lang, channel) table.insert(sentMessages, {text=text, chat=chat, channel=channel}) end
function SendAddonMessage(prefix, text, chat, channel) table.insert(sentAddonMessages, {prefix=prefix, text=text, chat=chat, channel=channel}) end
function SetWhoToUI() end
function SendWho(query) table.insert(whoQueries, query) end
function GetNumWhoResults() return 1 end
function GetWhoInfo()
    local class = ManTechPB_LFG and ManTechPB_LFG.currentQueryClass or "WARRIOR"
    local labels = ManTechPB_LFGClassLabels or {}
    local name = string.sub(class, 1, 1) .. string.lower(string.sub(class, 2)) .. "candidate"
    return name, "Bot Guild", 42, "Human", labels[class] or class, "Test Zone", class
end
function InviteByName() end
function IsShiftKeyDown() return false end
function IsAltKeyDown() return true end
function IsMouseButtonDown() return false end
function GetMouseFocus() return WorldFrame end
local unpackValues = unpack or table.unpack
function unpack(value) return unpackValues(value) end
table.getn = table.getn or function(value) return getn(value) end
ManTechPBDB = {selected="Tobuge", selectedByCharacter={ ["TestRealm:Tester"]="Tobuge" }}

local function tick(seconds, count)
    local i, _, frame
    for i = 1, count or 1 do
        fakeTime = fakeTime + seconds
        for _, frame in ipairs(frames) do
            if frame.visible and frame.scripts and frame.scripts.OnUpdate then
                if type(frame.refresh) ~= "number" then frame.refresh = 0 end
                frame.scripts.OnUpdate(frame, seconds)
            end
        end
    end
end

dofile(arg[1] or "work/mantechpb/ManTechPB.lua")
dofile((string.gsub(arg[1] or "work/mantechpb/ManTechPB.lua","ManTechPB.lua$","Recruitment.lua")))
dofile((string.gsub(arg[1] or "work/mantechpb/ManTechPB.lua","ManTechPB.lua$","Destinations.lua")))
dofile((string.gsub(arg[1] or "work/mantechpb/ManTechPB.lua","ManTechPB.lua$","Travel.lua")))
ManTechPB_Recruit.db().mode="legacy"

local presetExpectations = {
    DRUID={{"pve balance","balance","ranged"},{"pve feral","dps feral","melee"},{"pve resto","restoration","heal"}},
    HUNTER={{"pve bm","beast mastery","ranged"},{"pve mm","marksmanship","ranged"},{"pve surv","survival","ranged"}},
    MAGE={{"pve arcane","arcane","ranged"},{"pve fire","fire","ranged"},{"pve frost","frost","ranged"}},
    PALADIN={{"pve holy","holy","heal"},{"pve prot","protection","tank"},{"pve ret","retribution","melee"}},
    PRIEST={{"pve disc","discipline","heal"},{"pve holy","holy","heal"},{"pve shadow","shadow","ranged"}},
    ROGUE={{"pve assasination","assassination","melee"},{"pve combat","combat","melee"},{"pve subtlety","subtlety","melee"}},
    SHAMAN={{"pve elem","elemental","ranged"},{"pve enhan","enhancement","melee"},{"pve resto","restoration","heal"}},
    WARLOCK={{"pve affli","affliction","ranged"},{"pve demo","demonology","ranged"},{"pve destro","destruction","ranged"}},
    WARRIOR={{"pve arms","arms","melee"},{"pve fury","fury","melee"},{"pve prot","protection","tank"}},
    DEATHKNIGHT={{"pve blood","blood","tank"},{"pve frost","frost","melee"},{"pve unholy","unholy","melee"}}
}
for class, expectations in pairs(presetExpectations) do
    for _, expected in ipairs(expectations) do
        local pve = MTPB_TEST_HOOKS.FindAIForTalentBuild(class, expected[1])
        assert(pve and pve.strategy == expected[2] and pve.role == expected[3], class .. " preset did not map: " .. expected[1])
        local pvpName = string.gsub(expected[1], "^pve ", "pvp ")
        local pvp = MTPB_TEST_HOOKS.FindAIForTalentBuild(class, pvpName)
        assert(pvp and pvp.strategy == expected[2] and pvp.role == expected[3], class .. " preset did not map: " .. pvpName)
    end
end

-- Server-defined names differ by expansion and configuration. Verify that the
-- exact names returned by current CMaNGOS configs still map to every role type.
local serverNameExpectations = {
    {"PRIEST", "Holy PvE", "holy", "heal"},
    {"PRIEST", "Disc PvE", "discipline", "heal"},
    {"PRIEST", "Shadow PvE", "shadow", "ranged"},
    {"PALADIN", "Prot Pve", "protection", "tank"},
    {"PALADIN", "Ret Pve", "retribution", "melee"},
    {"SHAMAN", "Resto Pve", "restoration", "heal"},
    {"SHAMAN", "Ele Pve", "elemental", "ranged"},
    {"HUNTER", "MM Pvp", "marksmanship", "ranged"},
    {"ROGUE", "Assassination Pve", "assassination", "melee"},
    {"WARLOCK", "Demo Pve", "demonology", "ranged"},
    {"DRUID", "pve tank feral", "tank feral", "tank"},
    {"DRUID", "pve dps feral", "dps feral", "melee"},
    {"WARRIOR", "pve prot", "protection", "tank"},
    {"WARRIOR", "pve fury", "fury", "melee"},
    {"DEATHKNIGHT", "Frost PvE", "frost", "melee"}
}
for _, expected in ipairs(serverNameExpectations) do
    local mapped = MTPB_TEST_HOOKS.FindAIForTalentBuild(expected[1], expected[2])
    assert(mapped and mapped.strategy == expected[3] and mapped.role == expected[4], "server build did not map: " .. expected[2])
end

for _, frame in ipairs(frames) do
    if frame.events.VARIABLES_LOADED and frame.scripts.OnEvent then frame.scripts.OnEvent(frame, "VARIABLES_LOADED") end
end
tick(0.31, 15)
assert(table.getn(sentAddonMessages) == 0, "login/reload queried bot settings before the manager was opened")
assert(ManTechPBMinimapButton and ManTechPBMinimapButton.width == 24 and ManTechPBMinimapButton.height == 24, "compact minimap button dimensions are wrong")
assert(ManTechPBMinimapButton.mtpbBorder and ManTechPBMinimapButton.mtpbBorder.pointArgs and ManTechPBMinimapButton.mtpbBorder.pointArgs[1] == "TOPLEFT", "minimap tracking border is not anchored to its artwork origin")
assert(ManTechPBDB.hideBotReplies == true, "bot command chat should default to hidden")
for _, frame in ipairs(frames) do
    if frame.events[rosterEvent] and frame.scripts.OnEvent then frame.scripts.OnEvent(frame, rosterEvent) end
end
tick(0.31, 30)
assert(table.getn(sentAddonMessages) == 0, "party roster event queried bot settings automatically")
assert(SlashCmdList.MANTECHPB, "slash handler missing")
SlashCmdList.MANTECHPB()
tick(0.31, 30)
assert(table.getn(sentAddonMessages) > 0, "opening the manager did not query current bot settings")
for _, message in ipairs(sentAddonMessages) do
    assert(not string.find(message.text or "", "ll ?", 1, true), "normal manager refresh requested noisy loot lists")
    if string.find(message.text or "", "#a co ?", 1, true) then
        assert(message.chat == expectedGroupChannel, "group settings query used the wrong party/raid channel")
    end
end
for _, frame in ipairs(frames) do
    if frame.events.CHAT_MSG_SYSTEM and frame.scripts.OnEvent then
        frame.scripts.OnEvent(frame, "CHAT_MSG_SYSTEM", "Bot roster: +Healbot Priest, +Tankbot Warrior, -Bankalt Mage")
        frame.scripts.OnEvent(frame, "CHAT_MSG_WHISPER", "Combat Strategies: holy, ranged, dps assist", "Healbot")
    end
end
assert(ManTechPBFrame and ManTechPBFrame:IsVisible(), "main frame did not open")
assert(ManTechPBFrame.height == 452, "main frame was not enlarged for roster session controls")
assert(ManTechPBFrame.scale == 1.06, "main manager readability scale was not applied")
assert(ManTechPBMainDragRegion and ManTechPBMainDragRegion.pointArgs and ManTechPBMainDragRegion.pointArgs[4] == -252, "main title drag region overlaps LFG/Help/Bot Chat controls")
assert(ManTechPBMainHelpButton and ManTechPBMainHelpButton.scripts.OnClick, "main Help button missing")
assert(ManTechPBLFGButton and ManTechPBLFGButton.scripts.OnClick, "main LFG button missing")
ManTechPBLFGButton.scripts.OnClick(ManTechPBLFGButton)
assert(ManTechPBLFGFrame and ManTechPBLFGFrame:IsVisible(), "LFG button did not open Group Builder")
assert(ManTechPB_LFG and ManTechPB_LFG.slots and table.getn(ManTechPB_LFG.slots) == 5, "Group Builder does not expose five party roles")
assert(ManTechPB_LFG.playerSlot == "DPS3", "Group Builder did not reserve the default player role")
local sawDeathKnight = false
for _, option in ipairs(ManTechPB_LFGClassOptions(ManTechPB_LFG.slots[3])) do if option.value == "DEATHKNIGHT" then sawDeathKnight = true end end
assert(sawDeathKnight == (GetBuildInfo() == "3.3.5"), "Group Builder expansion class list is incorrect")
ManTechPB_LFGStartSearch()
local whoGuard = 0
while ManTechPB_LFG.searching and whoGuard < 200 do
    for _, frame in ipairs(frames) do
        if frame.events.WHO_LIST_UPDATE and frame.scripts.OnEvent then frame.scripts.OnEvent(frame, "WHO_LIST_UPDATE") end
    end
    tick(0.7, 1)
    whoGuard = whoGuard + 1
end
assert(not ManTechPB_LFG.searching, "Group Builder /who search did not finish")
assert(table.getn(whoQueries) >= 4, "Group Builder did not query the required classes")
local assigned = 0
for _, slot in ipairs(ManTechPB_LFG.slots) do if slot.key ~= ManTechPB_LFG.playerSlot and slot.candidate then assigned = assigned + 1 end end
local kept=0
for _, slot in ipairs(ManTechPB_LFG.slots) do if slot.keepName then kept=kept+1 end end
assert(assigned == 4-kept, "Group Builder did not fill only vacant slots around kept members")
assert(ManTechPBChatToggleButton and ManTechPBChatToggleButton.scripts.OnClick, "Bot Chat toggle is not clickable")
assert(ManTechPB_FormationButtons and table.getn(ManTechPB_FormationButtons) == 5, "formation preview buttons are incomplete")
for _, button in ipairs(ManTechPB_FormationButtons) do
    assert(button.mtpbFormationPreview, "formation button is missing its top-down preview")
end
local queriedFormation = false
for _, message in ipairs(sentAddonMessages) do
    if string.find(message.text or "", "formation ?", 1, true) then queriedFormation = true end
end
assert(queriedFormation, "manager refresh did not query the confirmed formation")
for _, frame in ipairs(frames) do
    if frame.events.CHAT_MSG_WHISPER and frame.scripts.OnEvent then
        frame.scripts.OnEvent(frame, "CHAT_MSG_WHISPER", "Formation: |cff00ff00arrow|r", "Healbot")
        frame.scripts.OnEvent(frame, "CHAT_MSG_WHISPER", "Formation: |cff00ff00arrow|r", "Tankbot")
    end
end
ManTechPB_UpdateFormationButtons()
for _, button in ipairs(ManTechPB_FormationButtons) do
    if button.form == "arrow" then
        assert(button.borderColor and button.borderColor[2] == 0.90, "confirmed formation was not highlighted")
    end
end
local previousChatState = ManTechPBDB.hideBotReplies
ManTechPBChatToggleButton.scripts.OnClick(ManTechPBChatToggleButton)
assert(ManTechPBDB.hideBotReplies ~= previousChatState, "Bot Chat button did not toggle suppression")
ManTechPBChatToggleButton.scripts.OnClick(ManTechPBChatToggleButton)
assert(ManTechPBDB.hideBotReplies == previousChatState, "Bot Chat button did not toggle suppression back")
ManTechPBMainHelpButton.scripts.OnClick(ManTechPBMainHelpButton)
assert(ManTechPBHelpFrame and ManTechPBHelpFrame:IsVisible(), "main Help button did not open Help")
assert(ManTechPBDB.selected == nil, "legacy account-wide bot selection was not retired")
assert(ManTechPBDB.selectedByCharacter["TestRealm:Tester"] == nil, "out-of-party saved bot was restored on a new session")
assert(MTPB_TEST_HOOKS.ShouldHideBotChat("CHAT_MSG_WHISPER", "Combat Strategies: holy, ranged, dps assist", "Healbot"), "recognized bot strategy reply was not hidden")
assert(not MTPB_TEST_HOOKS.ShouldHideBotChat("CHAT_MSG_WHISPER", "hello, are you ready?", "Healbot"), "ordinary bot conversation was hidden")
assert(not MTPB_TEST_HOOKS.ShouldHideBotChat("CHAT_MSG_WHISPER_INFORM", "talents", "Healbot"), "manually typed talent whisper was hidden")
assert(not MTPB_TEST_HOOKS.ShouldHideBotChat("CHAT_MSG_WHISPER", "My current talent spec is: Disc PvE (31/20/0)", "Healbot"), "reply to manually typed talent whisper was hidden")
assert(not MTPB_TEST_HOOKS.ShouldHideBotChat(groupEvent, "talents", "Tester"), "manually typed group talent command was hidden")
assert(not MTPB_TEST_HOOKS.ShouldHideBotChat(groupEvent, "My current talent spec is: pve prot (0/0/25)", botSender("Tankbot")), "reply to manually typed group talent command was hidden")
assert(MTPB_TEST_HOOKS.ShouldHideBotChat("CHAT_MSG_WHISPER", "Combat Strategies: holy", "Healbot"), "manual talent visibility exposed unrelated bot strategy traffic")
SlashCmdList.MANTECHPB("chat show")
assert(ManTechPBDB.hideBotReplies == false and not MTPB_TEST_HOOKS.ShouldHideBotChat("CHAT_MSG_WHISPER", "Combat Strategies: holy", "Healbot"), "chat show did not disable suppression")
SlashCmdList.MANTECHPB("chat hide")
assert(ManTechPBDB.hideBotReplies == true, "chat hide did not restore suppression")
local partyFilter, altsFilter
for _, frame in ipairs(frames) do
    if frame.text == (raidMode and "Raid" or "Party") then partyFilter = frame end
    if frame.text == "My Alts" then altsFilter = frame end
end
assert(partyFilter and altsFilter, "Party/My Alts roster filters missing")
altsFilter.scripts.OnClick(altsFilter)
local sawBankalt = false
for _, frame in ipairs(frames) do if frame.visible and type(frame.text) == "string" and string.find(frame.text, "Bankalt", 1, true) then sawBankalt = true end end
assert(sawBankalt, "My Alts view did not show the non-party account bot")
assert(ManTechPBLoginButton and ManTechPBLoginButton.scripts.OnClick, "selected-bot Log In control missing")
assert(ManTechPBLogoutButton and ManTechPBLogoutButton.scripts.OnClick, "selected-bot Log Out control missing")
assert(ManTechPBLoginAllButton and ManTechPBLoginAllButton.scripts.OnClick, "all-bot Log In control missing")
assert(ManTechPBLogoutAllButton and ManTechPBLogoutAllButton.scripts.OnClick, "all-bot Log Out control missing")
local bankaltButton
for _, frame in ipairs(frames) do if frame.visible and frame.name == "Bankalt" and frame.scripts.OnClick then bankaltButton = frame end end
assert(bankaltButton, "offline account alt was not selectable")
bankaltButton.scripts.OnClick(bankaltButton)
ManTechPBLoginButton.scripts.OnClick(ManTechPBLoginButton)
tick(0.31, 15)
local sawSelectedLogin = false
for _, message in ipairs(sentMessages) do
    if message.text == ".bot add Bankalt" and message.chat == "SAY" then sawSelectedLogin = true end
end
if not sawSelectedLogin then
    local payloads = {}
    for _, message in ipairs(sentMessages) do table.insert(payloads, tostring(message.chat) .. ":" .. tostring(message.text)) end
    error("selected offline alt did not receive .bot add; sent: " .. table.concat(payloads, " || "))
end
ManTechPBLogoutAllButton.scripts.OnClick(ManTechPBLogoutAllButton)
tick(0.31, 15)
local sawAllLogout = false
for _, message in ipairs(sentMessages) do
    if message.text == ".bot rm Bankalt,Healbot,Tankbot" and message.chat == "SAY" then sawAllLogout = true end
end
assert(sawAllLogout, "All Out did not use the complete sorted account-bot roster")
partyFilter.scripts.OnClick(partyFilter)
assert(WorldFrame:GetScript("OnMouseUp"), "direct WorldFrame Alt-click hook missing")
assert(ManTechPB_OpenForTarget and ManTechPB_OpenForTarget("Healbot"), "Alt-click target opener failed")
assert(ManTechPBIndividualFrame and ManTechPBIndividualFrame:IsVisible(), "individual bot window did not open")
assert(ManTechPBFrame:IsVisible(), "opening individual controls should not close the full manager")
assert(ManTechPBIndividualFrame.height == 440, "individual bot window was not enlarged to contain its controls")
assert(ManTechPBIndividualFrame.scale == 1.06, "individual window readability scale was not applied")
assert(ManTechPBIndividualDragRegion and ManTechPBIndividualDragRegion.pointArgs and ManTechPBIndividualDragRegion.pointArgs[4] == -168, "individual title drag region overlaps Help/Manager controls")
assert(ManTechPBIndividualManagerButton and ManTechPBIndividualManagerButton.scripts.OnClick, "individual Manager button missing")
assert(ManTechPBIndividualHelpButton and ManTechPBIndividualHelpButton.scripts.OnClick, "individual Help button missing")
local individualTabs = {Tactic=false, Fight=false, Support=false}
for _, frame in ipairs(frames) do
    if individualTabs[frame.text] ~= nil then individualTabs[frame.text] = true end
end
for label, found in pairs(individualTabs) do assert(found, "individual " .. label .. " tab missing") end
local healbotButton, talentsButton, currentButton, managerButton, helpButton
for _, frame in ipairs(frames) do
    if frame.text == "Healbot" and not rawget(frame,"slotIndex") then healbotButton = frame end
    if frame.text == "Talents..." then talentsButton = frame end
    if frame.text == "Manager" and frame.scripts.OnClick then managerButton = frame end
    if frame.text == "Help" and frame.scripts.OnClick then helpButton = frame end
end
assert(managerButton, "individual Manager button missing")
ManTechPBFrame:Hide(); managerButton.scripts.OnClick(managerButton)
assert(ManTechPBFrame:IsVisible() and ManTechPBIndividualFrame:IsVisible(), "individual Manager button did not keep both windows open")
assert(helpButton, "Help button missing")
helpButton.scripts.OnClick(helpButton)
assert(ManTechPBHelpFrame and ManTechPBHelpFrame:IsVisible(), "Help window did not open")
assert(healbotButton and healbotButton.scripts.OnClick, "roster selection button missing")
healbotButton.scripts.OnClick(healbotButton)
tick(0.31, 30)
assert(talentsButton and talentsButton.scripts.OnClick, "talents launcher missing")
talentsButton.scripts.OnClick(talentsButton)
assert(ManTechPBTalentFrame and ManTechPBTalentFrame:IsVisible(), "talent window did not open")
assert(ManTechPBTalentFrame.scale == 1.06, "talent window readability scale was not applied")
assert(ManTechPBTalentDragRegion and ManTechPBTalentDragRegion.pointArgs and ManTechPBTalentDragRegion.pointArgs[4] == -90, "talent title drag region overlaps Help control")
assert(ManTechPBTalentHelpButton and ManTechPBTalentHelpButton.scripts.OnClick, "talent Help button missing")
ManTechPBHelpFrame:Hide()
ManTechPBTalentHelpButton.scripts.OnClick(ManTechPBTalentHelpButton)
assert(ManTechPBHelpFrame:IsVisible(), "talent Help button did not open Help")
for _, frame in ipairs(frames) do if frame.text == "Current" and frame.scripts.OnClick then currentButton = frame end end
assert(currentButton, "Current talent button missing")
currentButton.scripts.OnClick(currentButton)
assert(not MTPB_TEST_HOOKS.ShouldHideBotChat("CHAT_MSG_WHISPER_INFORM", "talents", "Healbot"), "explicit Current request was hidden from chat")
tick(0.31, 5)
local sawCurrentTalentRequest = false
for _, message in ipairs(sentMessages) do
    if message.text == "talents" and message.chat == "WHISPER" and message.channel == "Healbot" then sawCurrentTalentRequest = true end
end
assert(sawCurrentTalentRequest, "Current did not query the selected bot")
for _, frame in ipairs(frames) do
    if frame.events[groupEvent] and frame.scripts.OnEvent then
        frame.scripts.OnEvent(frame, groupEvent, "My current talent spec is: Disc PvE (31/20/0) Link: 05032031303001", botSender("Healbot"))
    end
end
assert(MTPB_TEST_HOOKS.GetCurrentTalentBuild("Healbot") == "Disc PvE", "Current talent status was not reduced to the spec name")
local unsafeFallbackButton
for _, frame in ipairs(frames) do if frame.visible and frame.text == "pve holy" then unsafeFallbackButton = frame end end
assert(not unsafeFallbackButton, "unsafe cross-version fallback talent choice was rendered")
local serverTalentList = "Disc PvE (31/20/0), Holy PvE (21/30/0), Shadow PvE (0/0/51), Disc PvP (31/20/0), Holy PvP (21/30/0), Shadow PvP (0/0/51), holy raid (14/37/0), holy spirit (20/31/0), shadow utility (13/0/38), disc utility (40/11/0), smite (31/20/0), leveling shadow (10/0/41)."
for _, frame in ipairs(frames) do
    if frame.events[groupEvent] and frame.scripts.OnEvent then
        frame.scripts.OnEvent(frame, groupEvent, serverTalentList, botSender("Healbot"))
    end
end
local talentBuildButton
for _, frame in ipairs(frames) do if frame.text == "Holy PvE" then talentBuildButton = frame end end
assert(talentBuildButton and talentBuildButton.scripts.OnClick, "server talent build was not rendered")
tick(0.31, 3) -- Wait for all live-list chunks before issuing a talent mutation.
talentBuildButton.scripts.OnClick(talentBuildButton)
assert(ManTechPBTalentNextButton and ManTechPBTalentNextButton.scripts.OnClick, "talent pagination control missing")
ManTechPBTalentNextButton.scripts.OnClick(ManTechPBTalentNextButton)
local sawSecondPageBuild = false
for _, frame in ipairs(frames) do if frame.visible and frame.text == "smite" then sawSecondPageBuild = true end end
assert(sawSecondPageBuild, "second page of the server talent list was not rendered")
tick(0.31, 40)
local sawRawTalentWhisper = false
local contactedStaleBot = false
for _, message in ipairs(sentMessages) do
    if message.text == "talents Holy PvE" and message.chat == "WHISPER" and message.channel == "Healbot" then sawRawTalentWhisper = true end
    if message.chat == "WHISPER" and message.channel == "Tobuge" then contactedStaleBot = true end
end
assert(sawRawTalentWhisper, "talent choice was not sent as a plain private whisper")
assert(not contactedStaleBot, "stale cross-character bot selection was contacted")

-- A talent preset must not change the AI role until the server confirms the
-- requested build, and a current-spec status line must never become a button.
local tankbotButton
for _, frame in ipairs(frames) do if frame.text == "Tankbot" and frame.scripts.OnClick and not rawget(frame,"slotIndex") then tankbotButton = frame end end
assert(tankbotButton, "warrior roster button missing")
tankbotButton.scripts.OnClick(tankbotButton)
tick(0.31, 40)
talentsButton.scripts.OnClick(talentsButton)
tick(0.31, 15)
local warriorTalentList = "pve arms (31/20/0), pve fury (17/34/0), pve prot (0/0/25), pvp arms (31/20/0), pvp fury (19/32/0), pvp prot (0/32/19)."
for _, frame in ipairs(frames) do
    if frame.events[groupEvent] and frame.scripts.OnEvent then
        frame.scripts.OnEvent(frame, groupEvent, warriorTalentList, botSender("Tankbot"))
    end
end
sentAddonMessages = {}
sentMessages = {}
local protectionBuildButton
for _, frame in ipairs(frames) do if frame.kind == "Button" and frame.text == "pve prot" and frame.scripts.OnClick then protectionBuildButton = frame end end
if not protectionBuildButton then
    local visibleButtons = {}
    for _, frame in ipairs(frames) do if frame.kind == "Button" and frame.visible and frame.text then table.insert(visibleButtons, tostring(frame.text)) end end
    error("warrior protection talent choice missing; visible buttons: " .. table.concat(visibleButtons, ", "))
end
tick(0.31, 3)
protectionBuildButton.scripts.OnClick(protectionBuildButton)
tick(0.31, 6)
local roleSentBeforeTalentConfirmation = false
for _, message in ipairs(sentAddonMessages) do
    if string.find(message.text or "", "+protection", 1, true) then roleSentBeforeTalentConfirmation = true end
end
assert(not roleSentBeforeTalentConfirmation, "AI role was changed before the talent build was confirmed")
for _, frame in ipairs(frames) do
    if frame.events[groupEvent] and frame.scripts.OnEvent then
        frame.scripts.OnEvent(frame, groupEvent, "My current talent spec is: pve prot (0/0/25) Link: 0-0-053351224", botSender("Tankbot"))
    end
end
local currentSpecBecameButton = false
for _, frame in ipairs(frames) do
    if frame.kind == "Button" and type(frame.text) == "string" and string.find(frame.text, "My current talent spec is:", 1, true) == 1 then currentSpecBecameButton = true end
end
assert(not currentSpecBecameButton, "current talent status was added as a selectable build")
-- The bot can answer the first combat-role command before the delayed safety
-- window. A matching reply is definitive and must clear pending immediately;
-- otherwise the UI turns green but later prints a false timeout error.
tick(0.31, 2)
for _, frame in ipairs(frames) do
    if frame.events.CHAT_MSG_WHISPER and frame.scripts.OnEvent then
        frame.scripts.OnEvent(frame, "CHAT_MSG_WHISPER", "Combat Strategies: protection, protection pve, tank assist, close, pull", "Tankbot")
    end
end
assert(not MTPB_TEST_HOOKS.HasPendingStrategy("Tankbot", "protection"), "matching early role reply did not clear pending confirmation")
tick(0.31, 35)
local synchronizedProtection = false
for _, message in ipairs(sentAddonMessages) do
    if string.find(message.text or "", "#a co ", 1, true) == 1 and string.find(message.text or "", "+protection", 1, true) then synchronizedProtection = true end
end
for _, message in ipairs(sentMessages) do
    if string.find(message.text or "", "#a co ", 1, true) and string.find(message.text or "", "+protection", 1, true) then synchronizedProtection = true end
end
assert(synchronizedProtection, "confirmed pve prot build did not synchronize the Protection AI role")
local completeCombatRole, completeNonCombatRole = false, false
for _, message in ipairs(sentAddonMessages) do
    local text = message.text or ""
    if string.find(text, "#a co ", 1, true) and string.find(text, "+protection", 1, true) and string.find(text, "+pull back", 1, true) and string.find(text, "-behind", 1, true) then completeCombatRole = true end
    if string.find(text, "#a nc ", 1, true) and string.find(text, "+protection", 1, true) and string.find(text, "+tank assist", 1, true) and string.find(text, "-dps assist", 1, true) then completeNonCombatRole = true end
end
for _, message in ipairs(sentMessages) do
    local text = message.text or ""
    if string.find(text, "#a co ", 1, true) and string.find(text, "+protection", 1, true) and string.find(text, "+pull back", 1, true) and string.find(text, "-behind", 1, true) then completeCombatRole = true end
    if string.find(text, "#a nc ", 1, true) and string.find(text, "+protection", 1, true) and string.find(text, "+tank assist", 1, true) and string.find(text, "-dps assist", 1, true) then completeNonCombatRole = true end
end
if not completeCombatRole then
    local payloads = {}
    for _, message in ipairs(sentAddonMessages) do table.insert(payloads, message.text or "") end
    for _, message in ipairs(sentMessages) do table.insert(payloads, message.text or "") end
    error("tank role did not synchronize Pull Back and front-facing positioning; sent: " .. table.concat(payloads, " || "))
end
assert(completeNonCombatRole, "tank role did not synchronize non-combat assist behavior")
assert(MTPB_TEST_HOOKS.ShouldHideBotChat("CHAT_MSG_WHISPER", "Pull failed: no usable ranged weapon.", "Tankbot"), "core pull diagnostic was not routed through bot-chat suppression")
assert(not MTPB_TEST_HOOKS.HasPendingStrategy("Tankbot", "protection"), "cleared role confirmation returned and could time out falsely")
local lfgTankBuild = ManTechPB_LFGFindBuild(ManTechPB_LFG.slots[1], {class="WARRIOR", talentBuilds={{name="pvp fury",layout="19/32/0"},{name="pve prot",layout="0/0/25"}}})
assert(lfgTankBuild and lfgTankBuild.name == "pve prot", "Group Builder did not choose the matching PvE tank build")
local lfgHealBuild = ManTechPB_LFGFindBuild(ManTechPB_LFG.slots[2], {class="PRIEST", talentBuilds={{name="pvp shadow",layout="0/0/41"},{name="pve holy",layout="14/47/0"}}})
assert(lfgHealBuild and lfgHealBuild.name == "pve holy", "Group Builder did not choose the matching PvE healer build")
sentAddonMessages = {}; sentMessages = {}
ManTechPB_LFG.slots[1].candidate={class="WARRIOR",name="Tankbot",level=42}
ManTechPB_LFG.slots[1].build=lfgTankBuild
ManTechPB_LFG.slots[2].candidate={class="PRIEST",name="Healbot",level=42}
ManTechPB_LFG.slots[2].build=lfgHealBuild
ManTechPB_LFGApplyDefaults(ManTechPB_LFG.slots[1], "Tankbot")
ManTechPB_LFGApplyDefaults(ManTechPB_LFG.slots[2], "Healbot")
tick(0.31, 100)
local sawLfgTankDefaults, sawLfgHealerDefaults = false, false
for _, message in ipairs(sentAddonMessages) do
    local text = message.text or ""
    if message.channel == "Tankbot" and string.find(text, "+tank assist", 1, true) and string.find(text, "+pull", 1, true) then sawLfgTankDefaults = true end
    if message.channel == "Healbot" and string.find(text, "-offdps", 1, true) and string.find(text, "-offdps raid", 1, true) then sawLfgHealerDefaults = true end
end
for _, message in ipairs(sentMessages) do
    local text = message.text or ""
    if message.channel == "Tankbot" and string.find(text, "+tank assist", 1, true) and string.find(text, "+pull", 1, true) then sawLfgTankDefaults = true end
    if message.channel == "Healbot" and string.find(text, "-offdps", 1, true) and string.find(text, "-offdps raid", 1, true) then sawLfgHealerDefaults = true end
end
assert(sawLfgTankDefaults, "Group Builder did not enforce tank assist/pull defaults")
assert(sawLfgHealerDefaults, "Group Builder did not force Healer DPS off")
ManTechPB_LFG.candidates = {
    {name="Onlyhybrid",class="DRUID",level=42}, {name="Onlytank",class="WARRIOR",level=42},
    {name="Damageone",class="MAGE",level=42}, {name="Damagetwo",class="ROGUE",level=42}
}
for _, slot in ipairs(ManTechPB_LFG.slots) do slot.preference="ANY"; slot.candidate=nil; slot.keepName=nil; slot.prepareName=nil; slot.locked=nil end
ManTechPB_LFGAssignCandidates()
assert(ManTechPB_LFG.slots[1].candidate and ManTechPB_LFG.slots[1].candidate.class == "WARRIOR", "Group Builder consumed the only healer-capable hybrid for the tank slot")
assert(ManTechPB_LFG.slots[2].candidate and ManTechPB_LFG.slots[2].candidate.class == "DRUID", "Group Builder did not backtrack into a valid healer assignment")
print("ManTechPB runtime smoke passed")
