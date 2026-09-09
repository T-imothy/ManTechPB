-- Standalone mocked-client regression suite; no live bots or server access.
dofile("ManTechPB-public/tests/group-builder.lua")
local interface=ManTechPB_LFGInterface()
local track=interface>=30000 and "WotLK" or (interface>=20000 and "TBC" or "Classic")
local classes={[1]="WARRIOR",[2]="PALADIN",[3]="HUNTER",[4]="ROGUE",[5]="PRIEST",[6]="DEATHKNIGHT",[7]="SHAMAN",[8]="MAGE",[9]="WARLOCK",[11]="DRUID"}
local count=0
for _,entry in ipairs(dofile("ManTechPB-public/tests/preset-names.lua")) do
    if entry[1]==track then
        assert(MTPB_TEST_HOOKS.FindAIForTalentBuild(classes[entry[2]],entry[3]),"Unmapped preset: "..entry[3])
        count=count+1
    end
end
local function has(values,value)
    for _,v in ipairs(values) do if v==value then return true end end
    return false
end
local function option(values,value)
    for _,v in ipairs(values) do if v.value==value then return true end end
    return false
end
local function choose(class,role,spec,names)
    local builds={}
    for _,name in ipairs(names) do table.insert(builds,{name=name}) end
    return ManTechPB_LFGFindBuild({role=role,preference=class,spec=spec},{class=class,talentBuilds=builds})
end
ManTechPB_LFG.allowPvp=false
assert(choose("SHAMAN","dps","enhancement",{"pve dps elem","pve dps enh"}).name=="pve dps enh")
assert(choose("SHAMAN","dps","elemental",{"pve dps enh","pve dps elem"}).name=="pve dps elem")
assert(not choose("SHAMAN","dps","enhancement",{"pve dps elem"}),"silently replaced Enhancement")
assert(not ManTechPB_LFGFindBuild({role="dps",preference="MAGE"},{class="SHAMAN",talentBuilds={{name="pve elem"}}}),"wrong class accepted")
assert(choose("DRUID","dps","balance",{"pve dps feral cat","pve dps balance"}).name=="pve dps balance")
assert(choose("DRUID","dps","dps feral",{"pve dps balance","pve dps feral cat"}).name=="pve dps feral cat")
assert(choose("PRIEST","heal","holy",{"pve heal disc","pve heal holy","pve dps shadow"}).name=="pve heal holy")
assert(choose("PRIEST","heal","discipline",{"pve heal holy","pve heal disc"}).name=="pve heal disc")
assert(choose("DRUID","heal","restoration",{"Resto Pvp","Restro Pve"}).name=="Restro Pve")
assert(not choose("SHAMAN","dps","enhancement",{"pvp dps enhan (2hand)"}),"silent PvP fallback")
ManTechPB_LFG.allowPvp=true
assert(choose("SHAMAN","dps","enhancement",{"pvp dps enhan (2hand)"}))
assert(not choose("PRIEST","heal","holy",{"pvp dps holy"}),"DPS-labelled holy picked as healer")
ManTechPB_LFG.allowPvp=false
assert(not choose("DRUID","tank","tank feral",{"pve dps resto (regrowth spec bear aoe farm)"}))
assert(choose("WARRIOR","tank","protection",{"furyprot","pve prot"}).name=="pve prot")
assert(not choose("WARRIOR","tank","protection",{"prot/fury"}))
local hybrid=choose("WARRIOR","tank","furyprot",{"pve prot","furyprot"})
assert((hybrid~=nil)==(interface<20000),"Fury/Prot expansion gate")
local specOptions=ManTechPB_LFGSpecOptions({role="dps",preference="SHAMAN"})
assert(option(specOptions,"enhancement") and option(specOptions,"elemental") and not option(specOptions,"restoration"))
specOptions=ManTechPB_LFGSpecOptions({role="dps",preference="DRUID"})
assert(option(specOptions,"balance") and option(specOptions,"dps feral") and not option(specOptions,"tank feral"))
assert(option(ManTechPB_LFGSpecOptions({role="tank",preference="WARRIOR"}),"furyprot")== (interface<20000))
assert(option(ManTechPB_LFGClassOptions({role="tank"}),"DEATHKNIGHT")== (interface>=30000))
local oldBuildInfo=GetBuildInfo
GetBuildInfo=function() return "2.4.3","8606","date" end
assert(ManTechPB_LFGInterface()==20400)
GetBuildInfo=function() return "3.3.5","12340","date" end
assert(ManTechPB_LFGInterface()==30300)
GetBuildInfo=oldBuildInfo

local profiles={
    {"WARRIOR","tank","pve prot"},{"WARRIOR","dps","pve arms"},{"WARRIOR","dps","pve fury"},
    {"PALADIN","tank","pve prot"},{"PALADIN","heal","pve holy"},{"PALADIN","dps","pve ret"},
    {"DRUID","tank","Feral Tank Pve"},{"DRUID","dps","Feral dps Pve"},{"DRUID","dps","pve balance"},{"DRUID","heal","pve resto"},
    {"PRIEST","heal","pve holy"},{"PRIEST","heal","pve disc"},{"PRIEST","dps","pve shadow"},
    {"SHAMAN","heal","pve resto"},{"SHAMAN","dps","pve elem"},{"SHAMAN","dps","pve enhan"},
    {"ROGUE","dps","pve combat"},{"ROGUE","dps","pve assassination"},{"ROGUE","dps","pve subtlety"},
    {"HUNTER","dps","pve bm"},{"HUNTER","dps","pve mm"},{"HUNTER","dps","pve surv"},
    {"MAGE","dps","pve arcane"},{"MAGE","dps","pve fire"},{"MAGE","dps","pve frost"},
    {"WARLOCK","dps","pve affli"},{"WARLOCK","dps","pve demo"},{"WARLOCK","dps","pve destro"}
}
if interface>=30000 then
    table.insert(profiles,{"DEATHKNIGHT","tank","Blood Pve"})
    table.insert(profiles,{"DEATHKNIGHT","dps","Frost Pve"})
    table.insert(profiles,{"DEATHKNIGHT","dps","Unholy Pve"})
end
local oldSend=ManTechPB_LFGSend
ManTechPB_LFG.size=5
for _,entry in ipairs(profiles) do
    local slot={role=entry[2],preference=entry[1],candidate={class=entry[1],name="Profilebot"},build={name=entry[3]}}
    local states={co={passive=true},nc={passive=true,stay=true},de={passive=true},react={passive=true}}
    ManTechPB_LFGSend=function(text,name)
        assert(name=="Profilebot" and string.len(text)<=230,"unsafe profile command length/target")
        local _,_,context,ops=string.find(text,"^#a (%a+) (.+)$")
        for op in string.gfind(ops..",","(.-),") do states[context][string.sub(op,2)]=string.sub(op,1,1)=="+" or nil end
        return true
    end
    ManTechPB_LFG.building=true
    ManTechPB_LFGApplyDefaults(slot,"Profilebot")
    ManTechPB_LFG.building=false
    for _,context in ipairs({"co","nc","de","react"}) do
        local required,forbidden=ManTechPB_LFGProfile(slot,context)
        local actual={}
        for key in pairs(states[context]) do table.insert(actual,key) end
        assert(ManTechPB_LFGSettingsMatch(slot,context,actual),entry[3].." profile/application mismatch "..context)
        for i=1,table.getn(required) do
            local incomplete={}
            for j=1,table.getn(required) do if i~=j then table.insert(incomplete,required[j]) end end
            assert(not ManTechPB_LFGSettingsMatch(slot,context,incomplete),"missing required setting accepted: "..required[i])
        end
        for _,bad in ipairs(forbidden) do
            table.insert(actual,bad)
            assert(not ManTechPB_LFGSettingsMatch(slot,context,actual),"conflicting setting accepted: "..bad)
            table.remove(actual)
        end
    end
    local co=ManTechPB_LFGProfile(slot,"co")
    if entry[1]=="SHAMAN" then assert(has(co,"totems")) end
    if entry[1]=="ROGUE" then assert(has(co,"poisons")) end
    if entry[1]=="HUNTER" then assert(has(co,"pet")) end
end
ManTechPB_LFGSend=oldSend
local tank={role="tank",preference="WARRIOR",candidate={class="WARRIOR",name="T1"},build={name="pve prot"}}
local second={role="tank",preference="WARRIOR",candidate={class="WARRIOR",name="T2"},build={name="pve prot"}}
ManTechPB_LFG.size=40; ManTechPB_LFG.slots={tank,second}
assert(has(ManTechPB_LFGProfile(tank,"co"),"pull"))
local required,forbidden=ManTechPB_LFGProfile(second,"co")
assert(not has(required,"pull") and has(forbidden,"pull"),"every raid tank became an autonomous puller")
ManTechPB_LFG.size=5; ManTechPB_LFG.playerSlot="PLAYER"
local before=ManTechPB_LFGReadySignature(tank)
tank.readySignature=before; tank.supplyDone={gear=true}
ManTechPB_LFGSpecChanged("furyprot",{slotIndex=1})
assert(tank.spec=="furyprot" and not tank.readySignature and not tank.supplyDone)
assert(ManTechPB_LFGReadySignature(tank)~=before)
local row=ManTechPB_LFG.rows[1]
assert(row.spec and row.spec.pointArgs[4]+row.spec:GetWidth()<=row.source.pointArgs[4],"spec/source overlap")
assert(row.candidate.pointArgs[4]+row.candidate:GetWidth()<=row.state.pointArgs[4],"candidate/state overlap")
assert(ManTechPBLFGInstructionsButton and ManTechPBLFGInstructionsButton.scripts.OnClick,"Instructions button missing")
assert(ManTechPBLFGDragRegion.pointArgs[4]==-212,"drag region overlaps Instructions")
ManTechPBLFGInstructionsButton.scripts.OnClick()
assert(ManTechPBLFGInstructions:IsVisible(),"Instructions did not open")
local quick=ManTechPB_LFG.instructionBody:GetText()
assert(string.find(quick,"1. Choose",1,true) and string.find(quick,"2. Click Build / Resume",1,true) and string.find(quick,"READY",1,true) and string.find(quick,"4. Go play!",1,true),"quick steps incomplete")
for i=2,4 do
    local tab=ManTechPB_LFG.instructionTabs[i]
    this=tab; tab.scripts.OnClick(); this=nil
    assert(ManTechPB_LFG.instructionBody:GetText()~=quick,"legacy Instructions tab did not switch")
end
ManTechPBLFGInstructionsButton.scripts.OnClick(ManTechPBLFGInstructionsButton)
assert(ManTechPB_LFG.instructionBody:GetText()==quick,"Instructions should always open at quick start")
local warriorOptions=ManTechPB_LFGSpecOptions({role="tank",preference="WARRIOR"})
assert(option(warriorOptions,"BUILD:pve prot"),"exact Protection build missing")
assert(not option(warriorOptions,"BUILD:pve arms") and not option(warriorOptions,"BUILD:pve fury"),"tank menu includes warrior DPS builds")
local warriorDps=ManTechPB_LFGSpecOptions({role="dps",preference="WARRIOR"})
assert(not option(warriorDps,"BUILD:pve prot") and not option(warriorDps,"BUILD:furyprot (slam)"),"DPS menu includes tank builds")
for _,class in ipairs({"DRUID","PALADIN","PRIEST","SHAMAN","WARRIOR"}) do
    for _,role in ipairs({"tank","heal","dps"}) do
        for _,item in ipairs(ManTechPB_LFGSpecOptions({role=role,preference=class})) do
            if string.sub(item.value,1,6)=="BUILD:" then
                local mapped=MTPB_TEST_HOOKS.FindAIForTalentBuild(class,string.sub(item.value,7))
                assert((role=="tank" and mapped.role=="tank") or (role=="heal" and mapped.role=="heal") or
                    (role=="dps" and (mapped.role=="melee" or mapped.role=="ranged")),"wrong-role build shown: "..item.label)
            end
        end
    end
end
for _,name in ipairs({"furyprot","furyprot (slam)","furyprot (demo shout)"}) do
    assert(option(warriorOptions,"BUILD:"..name)==(interface<20000),"wrong expansion catalogue for "..name)
end
local choice={role="tank",preference="WARRIOR",spec="AUTO",buildChoice="furyprot (slam)"}
local live={class="WARRIOR",talentBuilds={{name="pve prot"},{name="furyprot"},{name="furyprot (slam)"},{name="furyprot (demo shout)"}}}
assert(ManTechPB_LFGFindBuild(choice,live).name=="furyprot (slam)","exact hybrid choice ignored")
table.remove(live.talentBuilds,3)
assert(not ManTechPB_LFGFindBuild(choice,live),"missing exact build silently substituted")
local covered={}
ManTechPB_LFG.allowPvp=true
for _,entry in ipairs(dofile("ManTechPB-public/tests/preset-names.lua")) do
    if entry[1]==track then
        local class=classes[entry[2]]
        local spec=MTPB_TEST_HOOKS.FindAIForTalentBuild(class,entry[3])
        local role=(spec.role=="melee" or spec.role=="ranged") and "dps" or spec.role
        local exact={role=role,preference=class,spec="AUTO",buildChoice=entry[3]}
        -- Only list builds that can actually be selected for this job.
        if ManTechPB_LFGFindBuild(exact,{class=class,talentBuilds={{name=entry[3]}}}) then
            local present=false
            for _,item in ipairs(ManTechPB_LFGSpecOptions(exact)) do
                if string.lower(item.value)==string.lower("BUILD:"..entry[3]) then present=true end
            end
            assert(present,"catalogue omitted "..entry[3])
            covered[class]=true
        end
    end
end
for _,class in pairs(classes) do
    if class~="DEATHKNIGHT" or interface>=30000 then assert(covered[class],"class missing exact options: "..class) end
end
ManTechPB_LFG.allowPvp=false
MTPB_TEST_HOOKS.SetTalentBuildFixture("Custombot","WARRIOR",{{name="pve fury realm custom"}})
local custom={role="dps",preference="WARRIOR",candidate={name="Custombot",class="WARRIOR"}}
local customOptions=ManTechPB_LFGSpecOptions(custom)
assert(option(customOptions,"BUILD:pve fury realm custom") and not option(customOptions,"BUILD:pve arms"),"live list did not replace catalogue")
local menu=ManTechPB_LFG.rows[1].spec
local many={}
for i=1,23 do table.insert(many,{value="BUILD:pve fury variant "..i,label="pve fury variant "..i}) end
ManTechPB_LFGSetMenu(menu,many)
assert(menu.menu:GetWidth()==390 and menu.menu:GetHeight()<=210,"build menu not bounded/readable")
assert(menu.options[1].value==many[1].value and menu.pageNext.enabled,"build menu first page incorrect")
menu.pageNext.scripts.OnClick()
assert(menu.options[1].value==many[9].value,"next build page failed")
menu.pageNext.scripts.OnClick()
assert(menu.options[1].value==many[17].value and not menu.pageNext.enabled,"last build page failed")
menu.pagePrevious.scripts.OnClick()
assert(menu.options[1].value==many[9].value,"previous build page failed")
ManTechPB_LFG.slots={tank,second}; tank.keepName=nil; tank.spec="AUTO"
ManTechPB_LFGSpecChanged("BUILD:pve prot",{slotIndex=1})
assert(tank.buildChoice=="pve prot" and not tank.readySignature,"exact choice was not saved / checkpoint invalidated")
ManTechPB_LFGSpecChanged("AUTO",{slotIndex=1})
assert(not tank.buildChoice,"Auto did not clear exact choice")
print("Exact-build regression passed: all classes/catalogues, four Classic Warrior tank builds, live override, no substitution, paging and checkpoint invalidation.")
print("Spec/profile regression passed: "..track..", "..count.." real presets; exact spec/PvP filtering, version gates, "..table.getn(profiles).." role profiles, four-context checks, packet limits, raid puller and UI layout.")
