-- Run the existing integration suite first, then exercise the real travel wrapper.
dofile("ManTechPB-public/tests/group-builder.lua")
dofile((string.gsub(arg[1],"ManTechPB.lua$","Destinations.lua")))
dofile((string.gsub(arg[1],"ManTechPB.lua$","Travel.lua")))
local T,R,s=ManTechPB_Travel,ManTechPB_Recruit,ManTechPB_LFG
-- End-to-end: real Build button path, travel barrier, real existing core-v1 prep.
local run,step,inviteCount=MTPB_TEST_HOOKS.travelSetup()
local originalSend=SendChatMessage
local travelWire={}
SendChatMessage=function(text,channel,lang,target)
    if string.find(text,"^%.tp ") then table.insert(travelWire,text)
    else originalSend(text,channel,lang,target) end
end
T.identity=ManTechPB_LFGPlanKey(); T.valid=true; T.refreshWanted=nil
local integrationCatalog=T.catalog()
for _,d in ipairs(integrationCatalog) do T.snapshot[d.key]="unlocked" end
T.destination="uldaman"
ManTechPB_LFGBuildGroup()
assert(T.active and inviteCount()==0,"real builder bypassed teleport preflight")
local travelId=T.active.id
ManTechPB_LFGSystemReply("PBTP 1 "..travelId.." uldaman ready ok")
for i=1,8 do step() end
assert(inviteCount()==0,"real builder recruited before confirmed arrival")
ManTechPB_LFGSystemReply("PBTP 1 "..travelId.." uldaman arrived ok")
run()
assert(inviteCount()==4 and not s.building,"real teleport-to-recruit pipeline did not complete")
for i=1,4 do assert(s.slots[i].state=="READY","travel continuation skipped standard preparation") end
SendChatMessage=originalSend
print("End-to-end travel -> recruit -> summon -> prepare passed with four READY bots.")
local clock,wire,builds=100000,{},0
function GetTime() return clock end
function SendChatMessage(text,channel) table.insert(wire,{text=text,channel=channel,time=clock}) end
function ManTechPB_LFGLeader() return true end
local list,known=T.catalog()
local expected=ManTechPB_LFGInterface()<20000 and 32 or (ManTechPB_LFGInterface()<30000 and 57 or 80)
assert(table.getn(list)==expected,"wrong expansion destination inventory")
assert(known.scarlet_library and known.uldaman,"missing Classic locations")
assert((known.naxxramas~=nil)==(expected==80),"Wrath Naxxramas leaked across versions")
assert((known.naxxramas_40~=nil)==(expected~=80),"old Naxxramas leaked into Wrath")
assert((known.hellfire_ramparts~=nil)==(expected>=57),"TBC destinations leaked into Classic")
local function reset()
    clock=clock+200
    T.active=nil; T.request=nil; T.issued={}; T.identity=ManTechPB_LFGPlanKey()
    T.destination="NONE"; T.valid=false; T.refreshWanted=nil; T.snapshot={}; T.nextFetch=nil
    R.db().travelCatalogAt={}; R.cancels={}; s.building=nil; s.searching=nil; wire={}; builds=0
end
local function reply(text) ManTechPB_LFGSystemReply(text) end
local function snapshot(state)
    T.fetch(); local id=T.request.id
    reply("PBTPU 1 "..id.." begin "..expected)
    for _,d in ipairs(list) do reply("PBTPU 1 "..id.." "..d.key.." "..(state or "unlocked")) end
    reply("PBTPU 1 "..id.." end "..expected)
    return id
end
reset(); ManTechPB_CreateLFGFrame()
assert(T.dropdown.pageSize==8 and not s.rangeDropdown:IsVisible(),"destination paging or level controls missing")
local searchWireCount=table.getn(wire)
T.dropdown.menuPage=4; T.searchBox:SetText("  SCARLET lib  "); T.searchChanged()
assert(table.getn(T.dropdown.values)==2 and T.dropdown.values[2].value=="scarlet_library","search not filtering words case-insensitively")
assert(T.dropdown.menuPage==1 and T.destination=="NONE","search selected travel or retained stale page")
assert(T.dropdown.options[1].pointArgs[5]==-57,"search header overlaps first result")
T.destination="uldaman"; T.paint()
assert(string.find(T.dropdown:GetText(),"Uldaman",1,true),"filter hid selected destination label")
T.searchBox:SetText("no_such_dungeon"); T.searchChanged()
assert(table.getn(T.dropdown.values)==1 and string.find(T.searchCount:GetText(),"No matching",1,true),"empty search lacks explanation")
assert(T.destination=="uldaman","zero matches replaced selection")
T.searchClear.scripts.OnClick()
assert(table.getn(T.dropdown.values)==expected+1,"clear did not restore full inventory")
assert(table.getn(wire)==searchWireCount,"local search sent server commands")
T.searchBox:SetText("ahn qiraj"); T.searchChanged()
assert(table.getn(T.dropdown.values)==3,"punctuation-separated raid search failed")
T.searchBox:SetText("scarlet_library"); T.searchChanged()
assert(table.getn(T.dropdown.values)==2,"canonical key search failed")
T.searchClear.scripts.OnClick(); T.destination="NONE"; T.paint()
T.refreshWanted=nil
local id=snapshot("locked")
assert(T.valid and T.snapshot.uldaman=="locked","complete locked snapshot not committed")
assert(R.hideWireChat("CHAT_MSG_SYSTEM","PBTPU 1 "..id.." uldaman locked"),"snapshot leaked into chat")
assert(not R.hideWireChat("CHAT_MSG_SYSTEM","PBTPU 1 manual_id uldaman locked"),"unrelated manual result hidden")
T.select("uldaman"); local count=table.getn(wire)
assert(not T.beforeBuild() and table.getn(wire)==count and not T.active,"locked destination sent check/go")
T.schedule(); T.fetch(); assert(table.getn(wire)==count,"10-second refresh spacing bypassed")
clock=clock+10; T.fetch(); id=T.request.id
reply("PBTPU 1 "..id.." begin "..expected)
reply("PBTPU 1 "..id.." uldaman unlocked")
reply("PBTPU 1 "..id.." end "..expected)
assert(not T.valid and not T.request,"partial snapshot unlocked destinations")
reset(); T.fetch(); id=T.request.id
reply("PBTPU 1 "..id.." begin "..expected)
reply("PBTPU 1 "..id.." uldaman unlocked")
reply("PBTPU 1 "..id.." uldaman unlocked")
assert(not T.valid and not T.request,"duplicate catalog row accepted")
reset(); T.fetch(); id=T.request.id
reply("PBTPU 1 "..id.." begin "..expected)
reply("PBTPU 1 "..id.." invented_dungeon unlocked")
assert(not T.request and not T.valid,"unknown catalog key accepted")
reset(); T.fetch(); id=T.request.id
reply("PBTPU 1 wrong_id begin "..expected)
assert(not T.request.begun,"mismatched catalog ID accepted")
reply("PBTP 1 "..id.." all denied storage_unavailable")
assert(not T.valid and not T.request and string.find(T.message,"storage",1,true),"catalog failure lost")
reset(); T.fetch(); clock=clock+13; T.update()
assert(not T.valid and not T.request,"catalog timeout accepted")

-- Stub only the downstream pipeline; all command gating and receipt parsing is real.
local originalBuild=ManTechPB_LFGBuildGroup
ManTechPB_LFGBuildGroup=function()
    assert(T.passOnce and T.beforeBuild(),"arrival did not authorize exactly one continuation")
    builds=builds+1
end
reset(); snapshot(); T.select("uldaman")
assert(not T.beforeBuild() and T.active and s.building,"travel did not gate recruitment")
id=T.active.id; local checkCount=table.getn(wire)
reply("PBTP 1 wrong_id uldaman ready ok")
reply("PBTP 1 "..id.." scarlet_library ready ok")
reply("PBTP 1 "..id.." uldaman arrived ok")
assert(table.getn(wire)==checkCount and builds==0,"wrong/early receipt advanced pipeline")
reply("PBTP 1 "..id.." uldaman ready ok")
reply("PBTP 1 "..id.." uldaman ready ok")
assert(table.getn(wire)==checkCount+1 and string.find(wire[table.getn(wire)].text," go uldaman",1,true),"go not exactly once")
reply("PBTP 1 "..id.." uldaman pending transfer")
assert(builds==0,"pending treated as arrival")
clock=clock+1; T.update(); assert(table.getn(wire)==checkCount+1,"polled faster than 2 seconds")
clock=clock+1; T.update(); assert(string.find(wire[table.getn(wire)].text," status uldaman",1,true),"status not polled")
reply("PBTP 1 "..id.." uldaman ready ok")
assert(table.getn(wire)==checkCount+2,"status ready resent go")
reply("PBTP 1 "..id.." uldaman arrived ok")
reply("PBTP 1 "..id.." uldaman arrived ok")
assert(builds==1 and T.destination=="NONE" and not T.active,"arrival resumed twice or retained automatic teleport")

reset(); snapshot(); T.select("uldaman"); T.beforeBuild(); id=T.active.id
reply("PBTP 1 "..id.." uldaman denied undiscovered")
assert(T.snapshot.uldaman=="locked" and not T.active and not s.building,"server undiscovered not enforced")
reset(); snapshot(); T.select("uldaman"); T.beforeBuild(); id=T.active.id
reply("PBTP 1 "..id.." uldaman ready ok")
ManTechPB_LFGStop("Cancelled")
reply("PBTP 1 "..id.." uldaman arrived ok")
assert(builds==0 and not T.active,"late arrival after cancel resumed")
reset(); snapshot(); T.select("uldaman"); T.beforeBuild(); id=T.active.id
T.select("scarlet_library")
reply("PBTP 1 "..id.." uldaman ready ok")
assert(not T.active and builds==0,"destination change failed to cancel")
reset(); snapshot(); T.select("uldaman"); T.beforeBuild(); clock=clock+61; T.update()
assert(not T.active and builds==0,"travel timeout started recruitment")
reset(); snapshot(); T.select("uldaman"); T.beforeBuild(); id=T.active.id
ManTechPB_LFGLeader=function() return false end
reply("PBTP 1 "..id.." uldaman ready ok")
assert(not T.active and builds==0,"leader change failed to cancel")
ManTechPB_LFGLeader=function() return true end
ManTechPB_LFGBuildGroup=originalBuild
reset()
s.maxRecruitLevel=nil; s.observedLevel=nil
local minimum,maximum=ManTechPB_LFGLevelBounds()
assert(minimum==UnitLevel("player") and maximum==minimum+2,"new default range includes lower-level bots")
T.maximum:SetText(tostring(minimum+4)); T.maxChanged()
assert(s.maxRecruitLevel==minimum+4,"maximum input not applied")
T.maximum:SetText("0"); T.maxChanged(); assert(s.maxRecruitLevel==minimum+4,"invalid maximum accepted")
T.event("PLAYER_LEVEL_UP",minimum+1)
local updated=ManTechPB_LFGLevelBounds(); assert(updated==minimum+1,"level-up did not update before UnitLevel refresh")
s.maxRecruitLevel=minimum; local a,b=ManTechPB_LFGLevelBounds(); assert(a==b,"maximum below minimum allowed")
local kept={role="dps",preference="ANY",keepName="Human"}
assert(ManTechPB_LFGReserved(kept),"level checks altered keep ownership")
T.event("PLAYER_ENTERING_WORLD"); assert(not T.valid and T.refreshWanted,"instance entry guessed an unlock locally")
local oldTime=time
local wall=200000
function time() return wall end
R.db().travelCooldowns={}
T.startCooldown()
assert(string.find(T.cooldownText(),"5:00 (estimated)",1,true),"accepted teleport lacks estimated timer")
wall=wall+61
assert(string.find(T.cooldownText(),"3:59",1,true),"cooldown does not count down")
T.cooldownUnknown()
assert(string.find(T.cooldownText(),"3:59",1,true),"cooldown refusal reset a known timer")
T.lastCooldownText=nil; T.cooldownPaint()
assert(string.find(T.cooldownLabel:GetText(),"3:59",1,true),"persisted timer did not redraw")
local identity=T.identity; T.identity="different-character"
assert(not string.find(T.cooldownText(),"3:59",1,true),"cooldown leaked across characters")
T.cooldownUnknown(); assert(string.find(T.cooldownText(),"unknown",1,true),"unknown cooldown fabricated remaining seconds")
T.identity=identity; wall=wall+240
assert(string.find(T.cooldownText(),"estimate elapsed",1,true),"timer expiry promised server eligibility")
reply("Travel denied: cooldown.")
assert(string.find(T.cooldownText(),"unknown",1,true),"expired estimate did not defer to server refusal")
reply("Travelling to Uldaman.")
assert(string.find(T.cooldownText(),"5:00",1,true),"manual teleport success did not start estimate")
time=oldTime
print("Travel tests passed: expansion inventories, atomic discovery, throttle, chat filtering, locked gating, one-shot go, confirmed arrival, cancel, timeout, leader changes and dynamic level bounds.")
