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
    if raidIndex then if tonumber(raidIndex)==1 then return "Tester" end; return party[tonumber(raidIndex)-1] end
    local _,_,n=string.find(unit,"^party(%d+)$")
    if n then return party[tonumber(n)] end
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
        later(function() emit("CHAT_MSG_PARTY",build.." (0/0/41).",name) end)
    elseif string.sub(text,1,8)=="talents " or text=="talents" then
        if scenario.rejectTalents then return end
        local build=chosenBuild(name)
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
            local label=({co="Combat",nc="Non Combat",react="Reaction"})[context]
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
    while (ManTechPB_LFG.building or ManTechPB_LFG.searching) and n<5000 do step(); n=n+1 end
    assert(n<5000,"unbounded workflow")
    for i=1,100 do step() end
end
local function reset(options)
    ManTechPB_LFGReset()
    ManTechPB_LFGReset()
    scenario=options or {}; party={}; pending={}; trace={}; invites={}; behaviors={}; nearby={}; raidActive=false
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

-- Preserve humans and require an explicit role assignment.
reset()
party={"Humanone"}
ManTechPB_LFGSyncMembers()
ManTechPB_LFGBuildGroup()
assert(not ManTechPB_LFG.building and table.getn(trace)==0,"unreviewed human role was guessed")
ManTechPB_LFGRoleChanged("tank",{slotIndex=1})
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
assert(pages==40,"cursor discovery missed pages or repeated scans")
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
print("Core v1 tests passed: staged party, authoritative arrival, ID replay, rate limit, uncertainty journal, correlation, full-group race, and legacy identity outcomes.")
