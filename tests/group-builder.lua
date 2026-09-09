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


-- Standalone deterministic Group Builder integration harness; no game/server writes.
local pending,party,trace,invites,behaviors,nearby={}, {}, {}, {}, {}, {}
local scenario={}
local unresolvedNames={}
local raidActive=false
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
function GetNumRaidMembers() return raidActive and table.getn(party)+1 or (scenario.raid and 5 or 0) end
function IsRaidLeader() return not scenario.notLeader end
function ConvertToRaid() table.insert(trace,{kind="convert",time=GetTime()}); raidActive=true end
function IsInInstance() return scenario.bg and true or false,scenario.bg and "pvp" or "none" end
function IsPartyLeader() return not scenario.notLeader end
function UnitAffectingCombat() return scenario.combat end
function UnitLevel() return 43 end
function UnitName(unit)
    if unit=="player" then return "Tester" end
    local _,_,raidIndex=string.find(unit,"^raid(%d+)$")
    if raidIndex then
        if tonumber(raidIndex)==1 then return "Tester" end
        local name=party[tonumber(raidIndex)-1]
        if name and unresolvedNames[name] and GetTime()<unresolvedNames[name] then
            if scenario.nilName then return nil end
            return scenario.localizedName or "Unknown"
        end
        return name
    end
    local _,_,n=string.find(unit,"^party(%d+)$")
    if n then
        local name=party[tonumber(n)]
        if name and unresolvedNames[name] and GetTime()<unresolvedNames[name] then
            if scenario.nilName then return nil end
            return scenario.localizedName or "Unknown"
        end
        return name
    end
end
local function classFor(name)
    if name=="Humanone" or name=="Humantwo" then return "PRIEST" end
    for class,list in pairs(candidates) do for _,c in ipairs(list) do if c.name==name then return class end end end
end
function UnitClass(unit) local c=classFor(UnitName(unit)); return ManTechPB_LFGClassLabels[c],c end
function UnitExists(unit) return UnitName(unit)~=nil end
function UnitIsVisible(unit) return nearby[UnitName(unit)]==true end
function CheckInteractDistance(unit) return nearby[UnitName(unit)]==true end
function UnitIsConnected() return true end
function UnitIsDeadOrGhost() return scenario.dead end
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
    if scenario.noJoin or (scenario.refuseName and scenario.refuseName==name) then return end
    table.insert(party,name)
    if scenario.slowNames then
        unresolvedNames[name]=GetTime()+scenario.slowNames
        table.insert(trace,{kind="roster_unknown",name=name,time=GetTime()})
    end
    if scenario.unexpectedHuman then
        table.insert(party,"Humanone"); unresolvedNames.Humanone=GetTime()+1
    end
    emit(raidActive and "RAID_ROSTER_UPDATE" or "PARTY_MEMBERS_CHANGED")
end
local builds={WARRIOR="pve prot",PRIEST="pve holy",MAGE="pve frost",ROGUE="pve combat"}
local function chosenBuild(name)
    local slot=ManTechPB_LFG.slots[ManTechPB_LFG.slotIndex]
    local class=classFor(name)
    if slot.role=="dps" and class=="WARRIOR" then return "pve fury" end
    if slot.role=="dps" and class=="PRIEST" then return "pve shadow" end
    return builds[class]
end
local function command(text,name)
    table.insert(trace,{kind="command",name=name,text=text,time=GetTime()})
    text=string.gsub(text,"^BOT\t","")
    if text=="who" then
        if name=="Humanwar" or scenario.noBotReply then return end
        later(function() emit("CHAT_MSG_WHISPER","|h|cffffffffProtection Warrior (|h|cff00ff0043|h|cffffffff lvl), |h|cff00ff00120|h|cffffffff GS (1/2)|r",name) end)
    elseif text=="summon" then
        if scenario.noArrival then return end
        later(function() nearby[name]=true end)
    elseif text=="talents list" then
        if scenario.noBuilds then return end
        local build=chosenBuild(name)
        later(function() emit("CHAT_MSG_PARTY",scenario.buildList or (build.." (0/0/41)."),name) end)
    elseif string.sub(text,1,8)=="talents " or text=="talents" then
        if scenario.rejectTalents then return end
        local build=scenario.currentBuild or chosenBuild(name)
        later(function() emit("CHAT_MSG_WHISPER","My current talent spec is: "..build.." (0/0/41) Link: 000",name) end)
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
            local label=({co="Combat",nc="Non Combat",react="Reaction",de="Dead"})[context]
            later(function() emit("CHAT_MSG_WHISPER",label.." Strategies: "..table.concat(names,", "),name) end)
        end
    elseif string.sub(text,1,5)==".bot " then
        local _,_,action,bot=string.find(text,"^%.bot (%a+) (%a+)$")
        if not action then return end
        local result=({gear="random gear equipped",food="food added",potions="potions added",consumes="consumables added",reagents="reagents added",ammo="ok"})[action]
        if scenario.rejectGear and action=="gear" then result="Not your bot" end
        if scenario.rejectFood and action=="food" then result="Not your bot" end
        if scenario.noSupplyReply then return end
        later(function() emit("CHAT_MSG_SYSTEM",action..": "..bot.." - "..result) end)
    end
end
function SendChatMessage(text,chat,lang,name) command(text,name) end
function SendAddonMessage(prefix,text,chat,name) command(text,name) end

dofile(arg[1])
dofile((string.gsub(arg[1],"ManTechPB.lua$","Recruitment.lua")))
ManTechPB_Recruit.db().mode="legacy"
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
    while (ManTechPB_LFG.building or ManTechPB_LFG.searching) and n<8000 do step(); n=n+1 end
    assert(n<8000,"unbounded workflow")
    for i=1,100 do step() end
end
local function reset(options)
    ManTechPB_LFGReset()
    ManTechPB_LFGReset()
    scenario=options or {}; party={}; pending={}; trace={}; invites={}; behaviors={}; nearby={}; raidActive=false; unresolvedNames={}
    ManTechPBDB.lfgPlans=nil; ManTechPB_LFG.planRestorePending=nil
    ManTechPB_LFG.rosterAt=nil
    ManTechPB_LFG.slots=nil; ManTechPB_LFG.size=nil; ManTechPB_LFG.page=1
    ManTechPB_LFGInitialize()
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
local lastInvite=0
for _,t in ipairs(trace) do if t.kind=="invite" then lastInvite=t.time end end
local lastSummon=0
for _,t in ipairs(trace) do
    if t.text=="summon" then assert(t.time>=lastInvite,"summoned before all invitations joined"); lastSummon=t.time end
    if t.text=="talents list" then assert(t.time>=lastSummon and table.getn(party)==4,"prep started before group arrival") end
end
local doneCommands=table.getn(trace)
ManTechPB_LFGBuildGroup(); run()
for i=doneCommands+1,table.getn(trace) do assert(not string.find(trace[i].text or "",".bot gear",1,true),"resume rerolled completed gear") end

-- Replace one completed bot: preserve the other three bots and their checkpoints.
local replacementStart=table.getn(trace)
local previousInvites=table.getn(invites)
local replacement=ManTechPB_LFG.slots[4]
local departed=replacement.candidate.name
for i=table.getn(party),1,-1 do if party[i]==departed then table.remove(party,i) end end
replacement.reviewRole=true
ManTechPB_LFGSyncMembers()
assert(not replacement.reviewRole and not replacement.prepareName and not replacement.recruited,"departed bot still owns slot")
assert(not replacement.build and not replacement.supplyDone and not replacement.prepSignature and not replacement.serverArrived,"replacement inherited preparation")
for i=1,3 do assert(ManTechPB_LFG.slots[i].readySignature and not ManTechPB_LFG.slots[i].reviewRole,"unchanged member lost confirmation") end
table.insert(candidates.MAGE,{name="Replacementbot",class="MAGE",level=43})
replacement.preference="MAGE"; replacement.spec="AUTO"; replacement.buildChoice=nil
-- Reconfirming the same role must not wipe class/spec choices or READY state.
ManTechPB_LFGRoleChanged("dps",{slotIndex=4})
assert(replacement.preference=="MAGE","role confirmation erased replacement class")
ManTechPB_LFGBuildGroup(); run()
assert(table.getn(invites)==previousInvites+1 and ManTechPB_LFGMember("Replacementbot"),"replacement did not fill only vacancy")
assert(replacement.state=="READY","replacement preparation incomplete")
for i=replacementStart+1,table.getn(trace) do
    local t=trace[i]
    if t.kind=="command" and (t.text=="talents list" or string.find(t.text,"^%.bot ")) then
        assert(t.name=="Replacementbot" or string.find(t.text," Replacementbot",1,true),"unchanged bot was prepared again")
    end
end
table.remove(candidates.MAGE,table.getn(candidates.MAGE))

-- A departed Keep member must not leave a REVIEW ROLE blocker behind.
reset()
party={"Humanone"}; ManTechPB_LFGSyncMembers()
-- Simulate stale state from the older UI before that member leaves.
ManTechPB_LFG.slots[1].reviewRole=true
party={}; ManTechPB_LFGSyncMembers()
assert(not ManTechPB_LFG.slots[1].reviewRole and not ManTechPB_LFG.slots[1].keepName)
ManTechPB_LFGBuildGroup(); run()
assert(table.getn(party)==4,"departed Keep member blocked fresh build")
print("Replacement regression passed: vacant roles, class changes, preserved members/checkpoints and one-bot preparation.")

reset({noArrival=true})
ManTechPB_LFGBuildGroup(); run()
assert(contains("summon") and not contains("talents list") and not contains(".bot gear"),"unconfirmed arrival allowed prep")

reset({dead=true})
ManTechPB_LFGBuildGroup(); run()
assert(not contains("talents list"),"dead bot was treated as ready")

reset({bg=true})
ManTechPB_LFGBuildGroup(); run()
assert(table.getn(trace)==0,"BG build allowed")

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

reset({rejectFood=true})
ManTechPB_LFGBuildGroup(); run()
assert(contains(".bot gear Tankbot"),"partial prep fixture never geared tank")
scenario.rejectFood=false
local checkpoint=table.getn(trace)
ManTechPB_LFGBuildGroup(); run()
for i=checkpoint+1,table.getn(trace) do assert(trace[i].text~=".bot gear Tankbot","partial resume repeated confirmed gear") end

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
ManTechPB_LFGSyncMembers()
ManTechPB_LFGSourceChanged("PREP",{slotIndex=1})
ManTechPB_LFGBuildGroup(); run()
assert(table.getn(party)==4 and table.getn(invites)==3,"existing-party fill failed")
for _,name in ipairs(invites) do assert(name~="Tankbot","existing member re-invited") end

local ranged=ManTechPB_LFGFindBuild({role="dps",preference="RANGED"},{class="DRUID",talentBuilds={{name="pve dps feral"}}})
assert(not ranged,"ranged preference silently selected melee")
print("Group Builder integration passed: preview, automatic build, bot verification, defaults, pacing, refusal, timeouts, cancellation, existing party, raid/combat guards.")

-- A failed invitation is replaced without removing anyone from a group.
reset({refuseName="Tankbot"})
table.insert(candidates.WARRIOR,{name="Ztank",class="WARRIOR",level=43})
ManTechPB_LFGBuildGroup(); run()
assert(ManTechPB_LFGMember("Ztank") and not ManTechPB_LFGMember("Tankbot"),"declined invitation did not try an alternative")
table.remove(candidates.WARRIOR,table.getn(candidates.WARRIOR))

-- Keep humans untouched without requiring a role-confirmation click.
reset()
party={"Humanone"}
ManTechPB_LFGSyncMembers()
ManTechPB_LFGBuildGroup(); run()
for _,t in ipairs(trace) do assert(t.name~="Humanone" and not string.find(t.text or "",".bot gear Humanone",1,true),"human member was changed") end
assert(table.getn(party)==4,"mixed party did not fill vacancies")

reset()
ManTechPB_LFGBuildGroup()
while ManTechPB_LFG.searching do step() end
table.insert(party,"Humanone")
emit("PARTY_MEMBERS_CHANGED")
assert(not ManTechPB_LFG.building,"unexpected human join did not pause recruitment")

-- Full 40-slot mixed raid with paged controls and bounded class queries.
reset()
ManTechPB_LFGSetSize(40)
assert(ManTechPB_LFG.size==40 and table.getn(ManTechPB_LFG.rows)==8,"raid UI is not paged")
ManTechPB_LFGPage(4)
assert(ManTechPB_LFG.rows[8].role.slotIndex==40,"last raid slot not editable")
party={"Humanone","Humantwo"}
raidActive=true
ManTechPB_LFGSyncMembers()
ManTechPB_LFGRoleChanged("tank",{slotIndex=1})
ManTechPB_LFGRoleChanged("heal",{slotIndex=2})
local originalCandidates=candidates
candidates={WARRIOR={},PRIEST={},MAGE={},ROGUE={}}
for i=1,20 do
    table.insert(candidates.MAGE,{name="Raidmage"..string.char(64+i),class="MAGE",level=43})
    table.insert(candidates.ROGUE,{name="Raidrogue"..string.char(64+i),class="ROGUE",level=43})
end
for i=3,40 do if i~=5 then ManTechPB_LFG.slots[i].preference=(i<=22 and "MAGE" or "ROGUE") end end
ManTechPB_LFGBuildGroup(); run()
assert(table.getn(party)==39 and table.getn(invites)==37,"mixed 40-player raid did not fill exactly 37 bot vacancies")
local queries=0
for _,t in ipairs(trace) do
    if t.kind=="who" then queries=queries+1 end
    assert(t.name~="Humanone" and t.name~="Humantwo","raid human received a bot command")
end
assert(queries==2,"raid searched per slot instead of deduplicating classes")
for i=1,40 do if i~=1 and i~=2 and i~=5 then assert(ManTechPB_LFG.slots[i].state=="READY","raid slot not ready: "..i) end end
candidates=originalCandidates
reset()
ManTechPB_LFGSetSize(10)
ManTechPB_LFG.playerSlot="TANK"
local savedMages=candidates.MAGE
candidates.MAGE={}
for i=1,8 do table.insert(candidates.MAGE,{name="Tenmage"..string.char(64+i),class="MAGE",level=43}) end
for i=3,10 do ManTechPB_LFG.slots[i].preference="MAGE" end
ManTechPB_LFGBuildGroup(); run()
assert(raidActive and table.getn(party)==9,"solo-to-raid conversion did not fill ten slots")
candidates.MAGE=savedMages
print("Mixed raid/summon tests passed: arrival barrier, dead/refused summons, resume, human protection, invite replacement, 40 slots, 37 bots, two class queries.")

-- Core v1 transport simulator: native movement/inventory are mocks, not live realm tests.
local R=ManTechPB_Recruit
local receipts,mutations,requests,coreNear,byGuid,byName={},{},{},{},{},{}
local function v1reset(options)
    reset(options)
    R.active=nil; R.cancels={}; R.cancelIds={}; R.touched={}; R.known={}; R.supported=nil; R.lastDiscovery=nil
    R.db().mode="v1"; R.db().journal={}
    receipts={}; mutations={}; requests={}; coreNear={}; byGuid={}; byName={}
    local n=100
    for _,list in pairs(candidates) do for _,c in ipairs(list) do
        if c.name~="Humanwar" then n=n+1; byGuid[tostring(n)]=c; byName[c.name]=tostring(n) end
    end end
end
local function response(id,guid,state,result)
    return "PBRECRUIT 1 "..id.." "..guid.." "..state.." "..result
end
local function deliver(messages)
    later(function() for _,message in ipairs(messages) do emit("CHAT_MSG_SYSTEM",message) end end)
end
local function v1command(text)
    local _,_,id,kind,args=string.find(text,"^%.bot recruit v1 ([%w_%-]+) (%a+) (.+)$")
    if not id then return false end
    local _,_,guid,extra=string.find(args,"^(%d+)%s*(.*)$")
    local bot=byGuid[guid]; local name=bot and bot.name
    table.insert(requests,{id=id,kind=kind,args=args,time=GetTime(),name=name})
    if scenario.noV1Reply then return true end
    if receipts[id] then
        assert(receipts[id].payload==kind.." "..args,"ID reused for changed payload")
        if not scenario.loseAllPrep or kind~="prepare" then deliver(receipts[id].messages) end
        return true
    end
    local messages={}
    local function reply(state,result,g) table.insert(messages,response(id,g or guid,state,result)) end
    if scenario.rateLimit and not scenario.didLimit and kind=="discover" then
        scenario.didLimit=true; reply("refused","discovery_rate_limit","0")
    elseif kind=="discover" then
        local _,_,cls,low,high,cursor=string.find(args,"^(%d+) (%d+) (%d+) (%d+)$")
        local list={}
        for g,c in pairs(byGuid) do if R.classes[c.class]==tonumber(cls) then table.insert(list,{g=g,c=c}) end end
        table.sort(list,function(a,b) return tonumber(a.g)<tonumber(b.g) end)
        local nextCursor="0"; local found=0
        for _,v in ipairs(list) do
            if tonumber(v.g)>tonumber(cursor) then
                if found>=1 then nextCursor=messages[1] and string.gsub(messages[1],"^PBRECRUIT 1 %S+ (%d+).*$","%1") or "0"; break end
                reply("eligible","ok "..v.c.name.." "..cls.." "..v.c.level,v.g); found=found+1
            end
        end
        reply("complete","cursor="..nextCursor..";scanned="..found,"0")
    elseif kind=="status" then
        if ManTechPB_LFGMember(name) then reply(coreNear[name] and "arrived" or "joined",coreNear[name] and "ok" or "not_nearby")
        else reply("eligible","ok") end
    elseif kind=="reserve" then reply("reserved","expires_in=15")
    elseif kind=="invite" then
        if scenario.fullRace then reply("refused","group_full")
        else
            reply("invite_pending","ok")
            later(function() InviteByName(name); emit("CHAT_MSG_SYSTEM",response(id,guid,"joined","ok")) end)
        end
    elseif kind=="summon" then
        reply("summon_pending","teleport_started")
        if not scenario.noArrival then
            later(function()
                nearby[name]=true
                if not scenario.clientOnlyArrival then coreNear[name]=true; emit("CHAT_MSG_SYSTEM",response(id,guid,"arrived","ok")) end
            end)
        end
    elseif kind=="prepare" then
        assert(coreNear[name],"structured prep sent before authoritative arrival")
        mutations[name]=mutations[name] or {}; mutations[name][extra]=(mutations[name][extra] or 0)+1
        local results={gear="random gear equipped",food="food added",potions="potions added",consumes="consumables added",reagents="reagents added",ammo="ok"}
        reply("complete",results[extra])
    elseif kind=="cancel" then reply("cancelled",scenario.cancelTransfer and "transfer_may_complete" or "completed_work_kept")
    else error("Unexpected v1 operation "..kind) end
    receipts[id]={payload=kind.." "..args,messages=messages}
    if kind=="prepare" and ((scenario.loseGear and extra=="gear") or scenario.loseAllPrep) then return true end
    if scenario.reordered and kind=="discover" then
        local reversed={}
        for i=table.getn(messages),1,-1 do table.insert(reversed,messages[i]) end
        deliver(reversed)
    else deliver(messages) end
    return true
end
function SendChatMessage(text,chat,lang,name) if not v1command(text) then command(text,name) end end

-- Screenshot regression: fresh/reloaded builder, four existing members, one
-- explicitly configured Paladin vacancy. No per-member confirmation clicks.
candidates.PALADIN={{name="Paladinbot",class="PALADIN",level=43}}
builds.PALADIN="pve dps ret"
for _,transport in ipairs({"legacy","v1"}) do
    v1reset()
    R.db().mode=transport
    party={"Tankbot","Healbot","Humanone"}
    ManTechPB_LFG.slots=nil; ManTechPB_LFGInitialize(); ManTechPB_LFGSyncMembers()
    for i=1,3 do
        local slot=ManTechPB_LFG.slots[i]
        assert(slot.keepName and not slot.reviewRole,"fresh Keep member demanded role confirmation")
        -- Older session state must also be repaired by Build / Resume.
        slot.reviewRole=true; slot.state="REVIEW ROLE"
    end
    local vacancy=ManTechPB_LFG.slots[4]
    vacancy.preference="PALADIN"; vacancy.spec="AUTO"; vacancy.buildChoice="pve dps ret"
    ManTechPB_LFG.range=1
    ManTechPB_LFGBuildGroup(); run()
    assert(table.getn(party)==4 and ManTechPB_LFGMember("Paladinbot"),transport.." fresh-roster refill failed: "..(ManTechPB_LFG.status.text or ""))
    assert(vacancy.state=="READY" and vacancy.buildChoice=="pve dps ret","explicit replacement build lost")
    for i=1,3 do assert(ManTechPB_LFG.slots[i].state=="KEEP" and not ManTechPB_LFG.slots[i].reviewRole,"Keep state not restored") end
    for _,t in ipairs(trace) do
        if t.kind=="invite" then assert(t.name=="Paladinbot","invited existing member") end
        if t.kind=="command" then
            assert(not t.name or t.name=="Paladinbot","sent command to kept member")
            for _,name in ipairs({"Tankbot","Healbot","Humanone"}) do
                assert(not string.find(t.text,name,1,true),"raw command touched kept member")
            end
        end
    end
    for _,q in ipairs(requests) do
        assert(q.kind=="discover" or q.name=="Paladinbot","core command touched kept member")
    end
end
candidates.PALADIN=nil; builds.PALADIN=nil
print("Fresh-roster refill passed: Keep members need no role clicks; only exact Paladin replacement invited and prepared (Legacy/Core v1).")

v1reset({loseGear=true,rateLimit=true})
ManTechPB_LFGBuildGroup(); run()
assert(table.getn(party)==4,"v1 did not fill party: "..(ManTechPB_LFG.status.text or ""))
for i=1,4 do assert(ManTechPB_LFG.slots[i].state=="READY","v1 slot not ready: "..i.." "..(ManTechPB_LFG.status.text or "")) end
for name,ops in pairs(mutations) do for kind,count in pairs(ops) do assert(count==1,"lost acknowledgment duplicated "..kind) end end
local lastDiscovery=-100; local discoveryIds={}; local gearIds={}
for _,q in ipairs(requests) do
    if q.kind=="discover" then assert(q.time-lastDiscovery>=1.99,"discovery not paced"); lastDiscovery=q.time; discoveryIds[q.id]=true end
    if q.kind=="prepare" and string.find(q.args," gear$") then
        if gearIds[q.name] then assert(gearIds[q.name]==q.id,"lost gear reply got NEW ID") else gearIds[q.name]=q.id end
    end
end
assert(scenario.didLimit and R.supported,"structured support/rate-limit handling missing")
assert(not behaviors.Healbot.co.offdps and not behaviors.Healbot.co["offdps raid"],"v1 healer DPS enabled")
for _,t in ipairs(trace) do assert(t.kind~="who","v1 used WHO discovery") end

local v1replacement=ManTechPB_LFG.slots[4]
local v1departed=v1replacement.candidate.name
for i=table.getn(party),1,-1 do if party[i]==v1departed then table.remove(party,i) end end
local v1new={name="Replacementbot",class="MAGE",level=43}
table.insert(candidates.MAGE,v1new); byGuid["999"]=v1new; byName[v1new.name]="999"
ManTechPB_LFGSyncMembers()
v1replacement.preference="MAGE"; v1replacement.spec="AUTO"; v1replacement.buildChoice=nil
local v1requestStart=table.getn(requests)
ManTechPB_LFGBuildGroup(); run()
assert(table.getn(party)==4 and ManTechPB_LFGMember(v1new.name) and v1replacement.state=="READY","v1 replacement failed: "..(ManTechPB_LFG.status.text or ""))
for i=v1requestStart+1,table.getn(requests) do
    local q=requests[i]
    if q.kind=="invite" or q.kind=="prepare" then assert(q.name==v1new.name,"v1 repeated another member's invite/preparation") end
end
for name,ops in pairs(mutations) do for kind,count in pairs(ops) do assert(count==1,"replacement repeated "..name.." "..kind) end end
table.remove(candidates.MAGE,table.getn(candidates.MAGE))
print("Core v1 replacement regression passed: only replacement invited/prepared; existing checkpoints retained.")

-- Save choices, not execution state, across a fresh builder/reordered roster.
local beforeReload=table.getn(trace)
for i=1,4 do
    local slot=ManTechPB_LFG.slots[i]
    slot.preference=slot.candidate.class; slot.buildChoice=slot.build.name; slot.spec="AUTO"
end
ManTechPB_LFG.range=1; ManTechPB_LFG.allowPvp=true
ManTechPB_LFGSavePlan()
local savedPlan=ManTechPBDB.lfgPlans[ManTechPB_LFGPlanKey()]
assert(savedPlan.slots[1].member=="Tankbot" and savedPlan.slots[1].buildChoice=="pve prot")
assert(not savedPlan.slots[1].readySignature and not savedPlan.slots[1].prepareName and not savedPlan.slots[1].candidate,"execution state persisted")
party={"Healbot","Replacementbot","Tankbot","Magebot"}
local reloadState=ManTechPB_LFG
reloadState.slots=nil; reloadState.size=nil; reloadState.range=nil; reloadState.candidates={}
ManTechPB_LFGInitialize(); ManTechPB_LFGSyncMembers(); ManTechPB_LFGRefreshRows()
for i=1,4 do
    local slot=reloadState.slots[i]
    assert(slot.keepName==savedPlan.slots[i].member,"roster reorder attached choices to wrong member")
    assert(slot.preference==savedPlan.slots[i].preference and slot.buildChoice==savedPlan.slots[i].buildChoice and slot.role==savedPlan.slots[i].role,"reload lost class/spec/role")
    assert(not slot.prepareName and not slot.readySignature and not slot.serverArrived,"reload restored unverified authority/readiness")
end
assert(reloadState.range==1 and reloadState.allowPvp,"reload lost range/build policy")
assert(table.getn(trace)==beforeReload,"reload sent commands")
local savedKey=ManTechPB_LFGPlanKey()
local oldRealm=GetRealmName
GetRealmName=function() return "OtherRealm" end
reloadState.slots=nil; reloadState.size=nil; reloadState.range=nil
ManTechPB_LFGInitialize()
assert(not reloadState.slots[1].buildChoice,"plan leaked between realms")
GetRealmName=oldRealm
local oldName=UnitName
UnitName=function(unit) if unit=="player" then return "OtherCharacter" end; return oldName(unit) end
reloadState.slots=nil; reloadState.size=nil
ManTechPB_LFGInitialize()
assert(not reloadState.slots[1].buildChoice,"plan leaked between characters")
UnitName=oldName
reloadState.slots=nil; reloadState.size=nil
ManTechPB_LFGInitialize(); ManTechPB_LFGSyncMembers(); ManTechPB_LFGRefreshRows()
ManTechPB_LFGReset()
assert(reloadState.slots[1].buildChoice==savedPlan.slots[1].buildChoice,"Clear search erased saved choice")
print("Persistence regression passed: reload/reorder, exact choices, Keep-only restoration, character/realm isolation, no commands and Clear search.")

v1reset()
ManTechPB_LFGSetSize(40)
ManTechPB_LFG.slots[40].preference="MAGE"
ManTechPB_LFG.slots[40].buildChoice="pve frost"
ManTechPB_LFGSavePlan()
local raidPlanKey=ManTechPB_LFGPlanKey()
local restoreTraffic=table.getn(trace)
ManTechPB_LFG.slots=nil; ManTechPB_LFG.size=nil
ManTechPB_LFGInitialize(); ManTechPB_LFGSyncMembers(); ManTechPB_LFGRefreshRows()
assert(ManTechPB_LFG.size==40 and ManTechPB_LFG.slots[40].buildChoice=="pve frost","raid plan did not restore")
assert(not raidActive and table.getn(trace)==restoreTraffic,"restoring raid plan converted/invited without Build")
local savedBuildInfo=GetBuildInfo
GetBuildInfo=function() return "other","","",99999 end
ManTechPB_LFG.slots=nil; ManTechPB_LFG.size=nil
ManTechPB_LFGInitialize()
assert(ManTechPB_LFG.size==5,"plan leaked between client versions")
GetBuildInfo=savedBuildInfo
ManTechPBDB.lfgPlans[raidPlanKey]={version=1,size=40,slots={{role="broken",preference="broken",buildChoice={}}}}
ManTechPB_LFG.slots=nil; ManTechPB_LFG.size=nil
ManTechPB_LFGInitialize()
assert(ManTechPB_LFG.slots[1].role=="tank" and ManTechPB_LFG.slots[1].preference=="ANY" and not ManTechPB_LFG.slots[1].buildChoice,"invalid plan fields accepted")

-- Model the actual substring lookup: a full requested name can match another
-- role's build. Explicit ambiguity must stop BEFORE any talent mutation.
candidates.DRUID={{name="Druidbot",class="DRUID",level=43}}; builds.DRUID="pve dps feral"
v1reset({buildList="pve dps feral (14/32/5), pve dps feral (dps/tank hybrid) (11/35/5), pve dps balance (boomkin) (38/0/13)."})
party={"Tankbot","Healbot","Magebot"}; ManTechPB_LFGSyncMembers()
ManTechPB_LFG.slots[4].preference="DRUID"; ManTechPB_LFG.slots[4].buildChoice="pve dps feral"
ManTechPB_LFGBuildGroup(); run()
assert(string.find(ManTechPB_LFG.status.text,"Ambiguous build",1,true),"ambiguity not explained")
assert(not contains("talents pve dps feral") and not next(mutations),"ambiguous explicit request mutated talents/gear")
-- A changed current-spec reply is reported verbatim rather than a generic timeout.
v1reset({currentBuild="pve dps feral (dps/tank hybrid)"})
party={"Tankbot","Healbot","Magebot"}; ManTechPB_LFGSyncMembers()
ManTechPB_LFG.slots[4].preference="DRUID"; ManTechPB_LFG.slots[4].buildChoice="pve dps feral"
ManTechPB_LFGBuildGroup(); run()
assert(string.find(ManTechPB_LFG.status.text,"requested 'pve dps feral'",1,true) and string.find(ManTechPB_LFG.status.text,"bot reports 'pve dps feral (dps/tank hybrid)'",1,true),"talent mismatch details missing")
assert(not next(mutations),"mismatched talents allowed prep")
candidates.DRUID=nil; builds.DRUID=nil
print("Talent wire regression passed: ambiguity blocked before sending; mismatches explain requested/observed names; no later prep.")

v1reset({clientOnlyArrival=true})
ManTechPB_LFGBuildGroup(); run()
assert(not next(mutations),"client range was incorrectly treated as server arrival")

v1reset({fullRace=true})
ManTechPB_LFGBuildGroup(); run()
assert(not next(mutations) and string.find(ManTechPB_LFG.status.text,"group_full",1,true),"full-group race not reported")

v1reset({loseAllPrep=true})
ManTechPB_LFGBuildGroup(); run()
local unknownName
for _,record in pairs(R.db().journal) do if record.pending then unknownName=record.name end end
assert(unknownName,"lost prep result was not journaled")
ManTechPB_LFGBuildGroup(); run()
assert(mutations[unknownName].gear==1,"resume repeated uncertain gear operation")
assert(string.find(ManTechPB_LFG.status.text,"unknown",1,true),"uncertain prep not surfaced: "..ManTechPB_LFG.status.text)

v1reset({noV1Reply=true})
ManTechPB_LFGBuildGroup(); run()
assert(not R.supported and table.getn(invites)==0,"timeout invented support or invited players")
for _,t in ipairs(trace) do assert(t.kind~="who","silent automatic legacy fallback") end

-- Correlation rejects a wrong GUID, unknown ID, and stale run before touching state.
v1reset()
ManTechPB_LFGBuildGroup()
while ManTechPB_LFG.searching do step() end
local op=R.active
assert(op and op.kind=="status")
R.sendOperation(op)
emit("CHAT_MSG_SYSTEM",response(op.id,"999999","eligible","ok"))
assert(not ManTechPB_LFG.verified,"wrong GUID accepted")
emit("CHAT_MSG_SYSTEM",response("unrelated",op.guid,"eligible","ok"))
assert(not ManTechPB_LFG.verified,"wrong ID accepted")
ManTechPB_LFGStop("test cancellation")
emit("CHAT_MSG_SYSTEM",response(op.id,op.guid,"eligible","ok"))
assert(not ManTechPB_LFG.building,"late reply restarted cancelled builder")

-- Legacy identity outcomes are neither bot success nor silent-human detection.
v1reset(); R.db().mode="legacy"
ManTechPB_LFGBuildGroup()
while ManTechPB_LFG.searching do step() end
local slot=ManTechPB_LFG.slots[ManTechPB_LFG.slotIndex]
ManTechPB_LFG.armed.who=true
emit("CHAT_MSG_WHISPER","Recruitment pending: transfer",slot.candidate.name)
assert(R.legacyPending and not ManTechPB_LFG.verified,"pending transfer treated as eligible")
emit("CHAT_MSG_WHISPER","Recruitment unavailable: external_group",slot.candidate.name)
assert(ManTechPB_LFG.unavailable,"legacy refusal not handled")
ManTechPB_LFGStop("end tests")

-- Cursor paging and reordered discovery batches in a mixed 40-member raid.
local priorCandidates=candidates
candidates={MAGE={},ROGUE={}}
for i=1,20 do
    table.insert(candidates.MAGE,{name="Vmage"..string.char(64+i),class="MAGE",level=43})
    table.insert(candidates.ROGUE,{name="Vrogue"..string.char(64+i),class="ROGUE",level=43})
end
v1reset({reordered=true})
ManTechPB_LFGSetSize(40); party={"Humanone","Humantwo"}; raidActive=true
ManTechPB_LFGSyncMembers()
ManTechPB_LFGRoleChanged("tank",{slotIndex=1}); ManTechPB_LFGRoleChanged("heal",{slotIndex=2})
for i=3,40 do if i~=5 then ManTechPB_LFG.slots[i].preference=i<=22 and "MAGE" or "ROGUE" end end
ManTechPB_LFGBuildGroup(); run()
assert(table.getn(party)==39 and table.getn(invites)==37,"v1 mixed raid did not fill 37 vacancies: "..ManTechPB_LFG.status.text)
for i=1,40 do if i~=1 and i~=2 and i~=5 then assert(ManTechPB_LFG.slots[i].state=="READY","v1 raid not ready") end end
assert(not mutations.Humanone and not mutations.Humantwo,"protected humans prepared")
local pages=0
for _,q in ipairs(requests) do if q.kind=="discover" then pages=pages+1 end end
assert(pages==37,"cursor discovery did not stop at the 37 requested bots: "..pages)
candidates=priorCandidates

-- Cancellation keeps a pending preparation journal and allows a started teleport to finish.
v1reset({noArrival=true,cancelTransfer=true})
ManTechPB_LFGBuildGroup()
while ManTechPB_LFG.building and ManTechPB_LFG.stage~="arrival" do step() end
while not R.active or R.active.kind~="summon" or not R.active.sentAt do step() end
local summonOp=R.active
ManTechPB_LFGReset()
nearby[summonOp.name]=true
emit("CHAT_MSG_SYSTEM",response(summonOp.id,summonOp.guid,"arrived","ok"))
for i=1,100 do step() end
assert(not ManTechPB_LFG.building and not next(mutations),"late teleport restarted prep")
assert(string.find(ManTechPB_LFG.status.text,"may still complete",1,true),"cancellation limitation hidden")

-- Current client GUID formats resolve existing member IDs where available.
v1reset(); party={"Tankbot"}; nearby.Tankbot=true
ManTechPB_LFGSyncMembers(); ManTechPB_LFGRoleChanged("tank",{slotIndex=1})
ManTechPB_LFGSourceChanged("PREP",{slotIndex=1})
ManTechPB_LFG.slots[1].candidate={name="Tankbot",class="WARRIOR",level=43}
function UnitGUID() return "0x0000000000000101" end
assert(R.guid(ManTechPB_LFG.slots[1])=="257","legacy client GUID not parsed")
UnitGUID=nil

-- Regression for the live report: do not exhaust priests before searching the
-- three warrior slots. Even a large remaining cursor must stop when enough match.
local beforeLarge=candidates
candidates={WARRIOR={},PRIEST={}}
for i=1,60 do
    table.insert(candidates.WARRIOR,{name="Fastwar"..string.char(64+math.floor((i-1)/26)+1)..string.char(65+math.mod(i-1,26)),class="WARRIOR",level=43})
    table.insert(candidates.PRIEST,{name="Fastpriest"..string.char(64+math.floor((i-1)/26)+1)..string.char(65+math.mod(i-1,26)),class="PRIEST",level=43})
end
v1reset()
ManTechPB_LFG.slots[3].preference="WARRIOR"; ManTechPB_LFG.slots[4].preference="WARRIOR"
local searchStarted=GetTime()
ManTechPB_LFGStartSearch(); run()
local searchCount=0
for _,q in ipairs(requests) do if q.kind=="discover" then searchCount=searchCount+1 end end
assert(searchCount==4,"scanned beyond one priest and three warriors: "..searchCount)
assert(table.getn(invites)==0,"preview invited bots")
local found={}
for i=1,4 do local c=ManTechPB_LFG.slots[i].candidate; assert(c and not found[c.guid],"slot candidate reused"); found[c.guid]=true end
ManTechPB_LFGStop("Cancelled search; candidates kept")
ManTechPB_LFGBuildGroup(); run()
local afterCount,statusCount=0,0
for _,q in ipairs(requests) do
    if q.kind=="discover" then afterCount=afterCount+1 end
    if q.kind=="status" then statusCount=statusCount+1 end
end
assert(afterCount==searchCount,"resume repeated a complete search")
assert(statusCount>=4 and table.getn(invites)==4,"resume did not verify before inviting")
local firstInvite
for _,t in ipairs(trace) do if t.kind=="invite" and not firstInvite then firstInvite=t.time end end
-- run() deliberately adds ten idle seconds after preview, so allow that margin.
assert(firstInvite and firstInvite-searchStarted<25,"first invitation still waits for exhaustive discovery")
for i=1,4 do assert(ManTechPB_LFG.slots[i].state=="READY","resumed fast search not ready") end

-- Chat presentation must hide only this addon's issued protocol traffic, before
-- AND after the event consumer receives it. Unrelated/manual diagnostics remain.
local sent=requests[1]
local line=response(sent.id,"0","complete","cursor=0;scanned=128")
assert(R.hideWireChat("CHAT_MSG_SYSTEM",line),"own diagnostic system spam visible")
assert(MTPB_TEST_HOOKS.ShouldHideBotChat("CHAT_MSG_SYSTEM",line),"system presentation filter missed protocol")
assert(not R.hideWireChat("CHAT_MSG_SYSTEM",response("manual","0","refused","arguments")),"manual core diagnostic hidden")
assert(not R.hideWireChat("CHAT_MSG_SYSTEM","Inventory is full."),"ordinary error hidden")
assert(not R.hideWireChat("CHAT_MSG_PARTY",line,"Friend"),"player conversation hidden")
local outgoing=".bot recruit v1 "..sent.id.." "..sent.kind.." "..sent.args
assert(R.hideWireChat("CHAT_MSG_SAY",outgoing,"Tester"),"own outbound protocol visible")
assert(not R.hideWireChat("CHAT_MSG_SAY",outgoing,"Friend"),"another player's message hidden")
SlashCmdList.MTPBRECRUIT("debug on")
assert(not R.hideWireChat("CHAT_MSG_SYSTEM",line),"diagnostic opt-in ignored")
SlashCmdList.MTPBRECRUIT("debug off")
candidates=beforeLarge
-- Classic can publish the member count and join event BEFORE UnitName resolves.
-- No commands may target the next bot until a named join plus its two-second gap.
for _,mode in ipairs({"v1","legacy"}) do
    v1reset({slowNames=2}); R.db().mode=mode
    ManTechPB_LFGBuildGroup(); run()
    assert(table.getn(invites)==4,"delayed names stopped "..mode..": "..ManTechPB_LFG.status.text)
    for i=1,4 do assert(ManTechPB_LFG.slots[i].state=="READY","delayed-name bot not prepared in "..mode) end
    local previous
    for _,t in ipairs(trace) do
        if t.kind=="invite" then
            if previous then assert(t.time-previous>=3.99,"next invite did not wait for name resolution + 2 seconds") end
            previous=t.time
        end
    end
    for _,slot in ipairs(ManTechPB_LFG.slots) do assert(slot.keepName~="Unknown","loading placeholder became a kept member") end
end
v1reset({slowNames=1,nilName=true})
ManTechPB_LFGBuildGroup(); run()
assert(table.getn(invites)==4 and ManTechPB_LFG.slots[4].state=="READY","nil roster name did not recover")
UNKNOWNOBJECT="Unbekannt"
v1reset({slowNames=1,localizedName=UNKNOWNOBJECT})
ManTechPB_LFGBuildGroup(); run()
assert(table.getn(invites)==4 and ManTechPB_LFG.slots[4].state=="READY","localized placeholder did not recover")
UNKNOWNOBJECT=nil

v1reset({slowNames=30})
ManTechPB_LFGBuildGroup(); run()
assert(table.getn(invites)==1 and not next(mutations),"unresolved roster allowed more invitations/prep")
assert(string.find(ManTechPB_LFG.status.text,"10 seconds",1,true),"name timeout not reported")
for _,slot in ipairs(ManTechPB_LFG.slots) do assert(slot.keepName~="Unknown","timed-out placeholder became human assignment") end

v1reset({slowNames=2,unexpectedHuman=true})
ManTechPB_LFGBuildGroup(); run()
assert(table.getn(invites)==1 and not mutations.Humanone,"unknown human was treated as invited bot")
assert(string.find(ManTechPB_LFG.status.text,"Humanone joined",1,true),"resolved unexpected human did not stop workflow")

v1reset({slowNames=2}); R.db().mode="legacy"
ManTechPB_LFGBuildGroup()
while table.getn(invites)==0 do step() end
local firstName=invites[1]
assert(ManTechPB_LFG.building and ManTechPB_LFG.rosterPending,"transient roster event stopped build")
ManTechPB_LFGSend("talents",firstName,true)
local queuedAt=GetTime()
run()
local delivered
for _,t in ipairs(trace) do if t.text=="talents" and t.name==firstName and t.time>=queuedAt then delivered=t.time; break end end
assert(delivered and delivered-queuedAt>=1.8,"pending roster discarded or prematurely sent queued packet")

v1reset({slowNames=2})
ManTechPB_LFGBuildGroup()
while table.getn(invites)==0 do step() end
ManTechPB_LFGReset()
for i=1,80 do step() end
assert(not ManTechPB_LFG.building and table.getn(invites)==1 and not next(mutations),"cancel during unknown roster resumed operations")
print("Roster-loading regression passed: Unknown/nil/localized names, sequential join gaps, timeout, unexpected human, held packets and cancellation.")
print("Fast discovery/UI regression passed: four queries for four bots, reused cancelled candidates, fresh identity checks, scoped protocol chat filtering.")
print("Core v1 tests passed: staged party, authoritative arrival, ID replay, rate limit, uncertainty journal, correlation, full-group race, and legacy identity outcomes.")
