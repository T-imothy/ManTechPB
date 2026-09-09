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
function methods:Show() self.visible = true; if self.scripts and self.scripts.OnShow then self.scripts.OnShow(self) end end
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


-- Standalone deterministic Group Builder integration harness; no game/server writes.
local pending,party,trace,invites,behaviors={}, {}, {}, {}, {}
local scenario={}
local candidates={
    WARRIOR={{name="Humanwar",class="WARRIOR",level=43},{name="Tankbot",class="WARRIOR",level=43}},
    PRIEST={{name="Healbot",class="PRIEST",level=43}},
    MAGE={{name="Magebot",class="MAGE",level=43}},
    ROGUE={{name="Roguebot",class="ROGUE",level=43}}
}
local whoResults={}
local events
local function emit(event,a,b)
    events.scripts.OnEvent(events,event,a,b)
end
local function later(fn) table.insert(pending,{time=GetTime()+0.1,fn=fn}) end
function GetNumPartyMembers() return table.getn(party) end
function GetNumRaidMembers() return scenario.raid and 5 or 0 end
function IsPartyLeader() return not scenario.notLeader end
function UnitAffectingCombat() return scenario.combat end
function UnitLevel() return 43 end
function UnitName(unit)
    if unit=="player" then return "Tester" end
    local _,_,n=string.find(unit,"^party(%d+)$")
    if n then return party[tonumber(n)] end
end
local function classFor(name)
    for class,list in pairs(candidates) do for _,c in ipairs(list) do if c.name==name then return class end end end
end
function UnitClass(unit) local c=classFor(UnitName(unit)); return ManTechPB_LFGClassLabels[c],c end
function UnitExists(unit) return UnitName(unit)~=nil end
function SetWhoToUI(value) scenario.whoToUI=value end
function GetNumWhoResults() return table.getn(whoResults) end
function GetWhoInfo(i)
    local c=whoResults[i]
    -- Vanilla uses no class token; also exercise a bogus seventh field.
    return c.name,"Bots",c.level,"Human",ManTechPB_LFGClassLabels[c.class],"Zone",scenario.badToken and 2 or nil
end
function SendWho(query)
    table.insert(trace,{kind="who",text=query,time=GetTime()})
    if scenario.whoTimeout then return end
    local class=ManTechPB_LFG.currentQueryClass
    later(function()
        whoResults=scenario.zeroWho and {} or candidates[class] or {}
        emit("WHO_LIST_UPDATE")
    end)
end
function InviteByName(name)
    table.insert(invites,name); table.insert(trace,{kind="invite",name=name,time=GetTime()})
    if scenario.noJoin then return end
    table.insert(party,name)
end
local builds={WARRIOR="pve prot",PRIEST="pve holy",MAGE="pve frost",ROGUE="pve combat"}
local function command(text,name)
    table.insert(trace,{kind="command",name=name,text=text,time=GetTime()})
    text=string.gsub(text,"^BOT\t","")
    if text=="who" then
        if name=="Humanwar" or scenario.noBotReply then return end
        later(function() emit("CHAT_MSG_WHISPER","|h|cffffffffProtection Warrior (|h|cff00ff0043|h|cffffffff lvl), |h|cff00ff00120|h|cffffffff GS (1/2)|r",name) end)
    elseif text=="talents list" then
        if scenario.noBuilds then return end
        local build=builds[classFor(name)]
        later(function() emit("CHAT_MSG_PARTY",build.." (0/0/41).",name) end)
    elseif string.sub(text,1,8)=="talents " or text=="talents" then
        if scenario.rejectTalents then return end
        later(function() emit("CHAT_MSG_WHISPER","My current talent spec is: "..builds[classFor(name)].." (0/0/41) Link: 000",name) end)
    elseif string.sub(text,1,3)=="#a " then
        local _,_,context,ops=string.find(text,"^#a (%a+) (.+)$")
        behaviors[name]=behaviors[name] or {co={offdps=true,["offdps raid"]=true},nc={},react={},de={}}
        local values=behaviors[name][context]
        for op in string.gfind(ops..",","(.-),") do
            if string.sub(op,1,1)=="+" then
                local key=string.sub(op,2)
                -- Real contexts do not create unsupported strategies.
                if key~="cure" or ManTechPB_LFGCanCleanse(classFor(name)) then values[key]=true end
            elseif string.sub(op,1,1)=="-" then values[string.sub(op,2)]=nil end
        end
        if ops=="?" then
            local names={}
            for key in pairs(values) do table.insert(names,key) end
            if scenario.rejectSettings and context=="co" then table.insert(names,"offdps raid") end
            local label=({co="Combat",nc="Non Combat",react="Reaction"})[context]
            later(function() emit("CHAT_MSG_WHISPER",label.." Strategies: "..table.concat(names,", "),name) end)
        end
    elseif string.sub(text,1,5)==".bot " then
        local _,_,action,bot=string.find(text,"^%.bot (%a+) (%a+)$")
        if not action then return end
        local result=({gear="random gear equipped",food="food added",potions="potions added",consumes="consumables added",reagents="reagents added",ammo="ok"})[action]
        if scenario.rejectGear and action=="gear" then result="Not your bot" end
        if scenario.noSupplyReply then return end
        later(function() emit("CHAT_MSG_SYSTEM",action..": "..bot.." - "..result) end)
    end
end
function SendChatMessage(text,chat,lang,name) command(text,name) end
function SendAddonMessage(prefix,text,chat,name) command(text,name) end

dofile(arg[1])
for _,f in ipairs(frames) do if f.events.CHAT_MSG_SYSTEM then events=f end end
assert(events,"main event handler missing")
ManTechPB_LFGInitialize()
ManTechPB_CreateLFGFrame()
local function step()
    tick(0.1)
    local jobs=pending; pending={}
    for _,p in ipairs(jobs) do if GetTime()>=p.time then p.fn() else table.insert(pending,p) end end
end
local function run()
    local n=0
    while (ManTechPB_LFG.building or ManTechPB_LFG.searching) and n<5000 do step(); n=n+1 end
    assert(n<5000,"unbounded workflow")
    for i=1,100 do step() end
end
local function reset(options)
    ManTechPB_LFGReset()
    ManTechPB_LFGReset()
    scenario=options or {}; party={}; pending={}; trace={}; invites={}; behaviors={}
    ManTechPB_LFG.slots[1].preference="WARRIOR"
    ManTechPB_LFG.slots[2].preference="PRIEST"
    ManTechPB_LFG.slots[3].preference="MAGE"
    ManTechPB_LFG.slots[4].preference="ROGUE"
    ManTechPB_LFG.playerSlot="DPS3"; ManTechPB_LFG.range=2
end
local function contains(fragment,name)
    for _,t in ipairs(trace) do if t.text and string.find(t.text,fragment,1,true) and (not name or t.name==name) then return true end end
end

reset({badToken=true})
ManTechPB_LFGCycleCandidate(1)
assert(ManTechPB_LFG.searching,"empty row did not search")
run()
assert(table.getn(trace)==1 and trace[1].text=='c-"Warrior" 41-45',"row search did not restrict class and levels")
assert(ManTechPB_LFG.slots[1].candidate,"partial matching lost tank when other roles were empty")
assert(table.getn(invites)==0,"preview search sent invitations")

reset()
ManTechPB_LFGBuildGroup()
local serial=ManTechPB_LFG.runToken
ManTechPB_LFGBuildGroup()
assert(serial==ManTechPB_LFG.runToken,"double click started another run")
run()
assert(table.getn(invites)==4,"one-click workflow did not invite four bots")
assert(not contains("talents list","Humanwar"),"unverified ordinary player was configured")
for _,name in ipairs(invites) do assert(name~="Humanwar","ordinary player was invited") end
for i=1,4 do assert(ManTechPB_LFG.slots[i].state=="READY","slot not fully confirmed") end
local lastWho=-100
local seenRole,seenGear={},{}
for _,t in ipairs(trace) do
    if t.kind=="who" then assert(t.time-lastWho>=7.99,"Who requests not paced"); lastWho=t.time end
    if t.kind=="command" then
        if string.find(t.text,"#a react ?",1,true) then seenRole[t.name]=true end
        local _,_,action,name=string.find(t.text,"^%.bot (%a+) (%a+)$")
        if action=="gear" then assert(seenRole[name],"gear sent before role confirmation"); seenGear[name]=true end
        if action and action~="gear" then assert(seenGear[name],"supplies before gear") end
    end
end
assert(not behaviors.Healbot.co.offdps and not behaviors.Healbot.co["offdps raid"] and not behaviors.Healbot.nc.offdps,"healer DPS remained enabled")
assert(behaviors.Healbot.co.holy and behaviors.Healbot.nc.food and behaviors.Healbot.react.potions and behaviors.Healbot.co.aoe and behaviors.Healbot.co.boost and behaviors.Healbot.co.buff,"healer defaults missing")
assert(behaviors.Tankbot.co["tank assist"] and behaviors.Tankbot.co.pull,"tank defaults missing")
assert(not contains(".bot prepare"),"broad preparation command used")

reset({rejectTalents=true})
ManTechPB_LFGBuildGroup(); run()
assert(not contains("#a co ") and not contains(".bot gear"),"rejected talents still changed roles or gear")
assert(ManTechPB_LFG.slots[1].state=="STOPPED","failure reported as ready")

reset({noBuilds=true})
ManTechPB_LFGBuildGroup(); run()
assert(not contains("talents pve") and not contains(".bot gear"),"missing presets did not stop setup")

reset({rejectSettings=true})
ManTechPB_LFGBuildGroup(); run()
assert(not contains(".bot gear Healbot"),"unconfirmed healer settings still triggered gear")
assert(ManTechPB_LFG.slots[2].state=="STOPPED","mixed healer DPS status accepted")

reset({rejectGear=true})
ManTechPB_LFGBuildGroup(); run()
assert(contains(".bot gear") and not contains(".bot food"),"gear refusal did not stop supplies")

reset({noSupplyReply=true})
ManTechPB_LFGBuildGroup(); run()
assert(not contains(".bot food"),"missing gear ack advanced the workflow")

reset({whoTimeout=true})
ManTechPB_LFGBuildGroup(); run()
local queries=0
for _,t in ipairs(trace) do if t.kind=="who" then queries=queries+1 end end
assert(queries==2 and table.getn(invites)==0,"Who timeout was not bounded or invited candidates")

reset({zeroWho=true})
ManTechPB_LFGBuildGroup(); run()
assert(table.getn(invites)==0,"empty Who results invited bots")

reset({noJoin=true})
ManTechPB_LFGBuildGroup(); run()
assert(not contains("talents list"),"unjoined bot was configured")

reset({noBotReply=true})
ManTechPB_LFGBuildGroup(); run()
assert(table.getn(invites)==0,"unverified bots were invited")

reset()
ManTechPB_LFGBuildGroup()
while ManTechPB_LFG.stage~="settings" or ManTechPB_LFG.searching do step() end
local before=table.getn(trace)
ManTechPB_LFGReset()
for i=1,500 do step() end
assert(table.getn(trace)==before,"Cancel allowed queued commands or timers to continue")

reset({raid=true})
ManTechPB_LFGBuildGroup()
assert(not ManTechPB_LFG.building and table.getn(trace)==0,"raid build allowed")
reset({combat=true})
ManTechPB_LFGBuildGroup()
assert(not ManTechPB_LFG.building and table.getn(trace)==0,"combat build allowed")

-- Existing known party member stays in the group and is never re-invited.
reset()
party={"Tankbot"}
ManTechPB_LFGBuildGroup(); run()
assert(table.getn(party)==4 and table.getn(invites)==3,"existing-party fill failed")
for _,name in ipairs(invites) do assert(name~="Tankbot","existing member re-invited") end

local ranged=ManTechPB_LFGFindBuild({role="dps",preference="RANGED"},{class="DRUID",talentBuilds={{name="pve dps feral"}}})
assert(not ranged,"ranged preference silently selected melee")
print("Group Builder integration passed: preview, automatic build, bot verification, defaults, pacing, refusal, timeouts, cancellation, existing party, raid/combat guards.")
