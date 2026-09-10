-- PBTP / PBTPU v1. Server-owned discovery, then travel BEFORE recruitment.
ManTechPB_Travel={issued={},snapshot={},valid=false,destination="NONE",base={}}
local T=ManTechPB_Travel
local R=ManTechPB_Recruit
T.base.create=ManTechPB_CreateLFGFrame
T.base.refresh=ManTechPB_LFGRefreshRows
T.base.stop=ManTechPB_LFGStop
T.base.system=ManTechPB_LFGSystemReply
T.base.hide=R.hideWireChat
T.lockedText="Locked - enter this dungeon once to unlock teleport."

function T.catalog()
    local version=ManTechPB_LFGInterface()<20000 and 1 or (ManTechPB_LFGInterface()<30000 and 2 or 3)
    local list,map={},{}
    for _,d in ipairs(ManTechPB_Destinations) do
        if d.key=="onyxias_lair" then d.note=version==3 and "Outside. Level-80 encounter in Wrath." or "Outside. Level-60 encounter." end
        if version>=d.first and version<=d.last then table.insert(list,d); map[d.key]=d end
    end
    return list,map
end
function T.status(message)
    T.message=message
    if T.notice then T.notice:SetText(message) end
    ManTechPB_LFGSetStatus(message,"|cffffff00")
end
function T.reason(reason)
    local messages={undiscovered=T.lockedText,disabled="Dungeon travel is disabled on this server.",
        storage_unavailable="Dungeon discovery storage is unavailable. Try again later.",
        rate_limit="Server request limit reached. Wait before refreshing discovery.",
        cooldown="Teleport is on cooldown. Wait before trying again.",
        instance="Leave the current dungeon or raid before requesting another teleport.",
        not_leader="Only the group leader may start this workflow.",
        combat="Leave combat before teleporting.",dead="You must be alive before teleporting.",
        wrong_expansion="This destination is unavailable in this game version."}
    return messages[reason] or ("Teleport refused: "..(reason or "unknown")..". No recruitment started.")
end
function T.send(id,operation,key)
    local command=".tp v1 "..id.." "..operation.." "..key
    local record=T.issued[id] or {commands={}}
    record.commands[command]=true; record.expires=GetTime()+180
    T.issued[id]=record
    SendChatMessage(command,"SAY")
end
function R.hideWireChat(eventName,message,sender)
    if not R.db().debugWire then
        local text=R.clean(message)
        local _,_,id=string.find(text,"^PBTPU? 1 ([%w_%-]+) ")
        if eventName=="CHAT_MSG_SYSTEM" and id and T.issued[id] and T.issued[id].expires>=GetTime() then return true end
        if eventName=="CHAT_MSG_SAY" and string.gsub(sender or "","%-.*$","")==UnitName("player") then
            local a,b; a,b,id=string.find(text,"^%.tp v1 ([%w_%-]+) ")
            if id and T.issued[id] and T.issued[id].expires>=GetTime() and T.issued[id].commands[text] then return true end
        end
    end
    return T.base.hide(eventName,message,sender)
end
function T.schedule()
    -- Never infer discovery from a local zone event. It only requests a fresh snapshot.
    T.valid=false; T.refreshWanted=true
end
function T.fetch()
    if T.request or T.active or not T.identity then return end
    local db=R.db(); db.travelCatalogAt=db.travelCatalogAt or {}
    local now=GetTime(); local wall=time and time() or now
    local last=db.travelCatalogAt[T.identity]
    if now<(T.nextFetch or 0) or (type(last)=="number" and wall>=last and wall-last<10) then return end
    db.travelCatalogAt[T.identity]=wall; T.nextFetch=now+10
    T.refreshWanted=nil; T.valid=false
    T.request={id=R.id(),untilAt=now+12,rows={},count=0,identity=T.identity}
    T.send(T.request.id,"unlocks","all")
    T.paint()
end
function T.catalogFailed(message)
    T.request=nil; T.valid=false
    T.status(message); T.paint()
end
function T.snapshotReply(text)
    local _,_,id,key,value=string.find(text,"^PBTPU 1 ([%w_%-]+) ([%w_%-]+) ([%w_%-]+)$")
    local q=T.request
    if not id or not q or id~=q.id or q.identity~=T.identity then return end
    local list,known=T.catalog(); local expected=table.getn(list)
    if key=="begin" then
        if q.begun or tonumber(value)~=expected then T.catalogFailed("Invalid dungeon discovery snapshot; travel remains unverified."); return end
        q.begun=true
    elseif key=="end" then
        if not q.begun or tonumber(value)~=expected or q.count~=expected then T.catalogFailed("Incomplete dungeon discovery snapshot; travel remains unverified."); return end
        T.snapshot=q.rows; T.valid=true; T.request=nil
        T.status("Dungeon discovery checked for this character."); T.paint()
    else
        if not q.begun or not known[key] or q.rows[key] or (value~="locked" and value~="unlocked") then
            T.catalogFailed("Invalid or duplicate dungeon discovery row; travel remains unverified."); return
        end
        q.rows[key]=value; q.count=q.count+1
    end
end
function T.beforeBuild()
    if T.editing then T.editing=nil; T.maxChanged(); T.maximum:ClearFocus() end
    if T.passOnce then T.passOnce=nil; return true end
    if T.destination=="NONE" then return true end
    local _,known=T.catalog()
    if not known[T.destination] then T.status("Select a destination available in this game version."); return false end
    if not T.valid then
        T.refreshWanted=true; T.fetch()
        T.status("Checking dungeon discovery. Wait for the result, then click Build / Resume."); return false
    end
    if T.snapshot[T.destination]~="unlocked" then T.status(T.lockedText); return false end
    if table.getn(R.cancels)>0 then T.status("Wait for pending recruitment cancellations before travelling."); return false end
    local s=ManTechPB_LFG
    T.active={id=R.id(),key=T.destination,phase="check",untilAt=GetTime()+60,identity=T.identity}
    s.building=true; s.stage="travel"; s.slotIndex=nil
    T.status("Checking teleport eligibility before recruiting...")
    ManTechPB_LFGRefreshRows()
    T.send(T.active.id,"check",T.active.key)
    return false
end
function ManTechPB_LFGStop(message,success)
    T.active=nil; T.passOnce=nil
    T.base.stop(message,success)
    if message and T.notice then T.notice:SetText(message) end
end
function T.travelReply(text)
    local _,_,id,key,state,reason=string.find(text,"^PBTP 1 ([%w_%-]+) ([%w_%-]+) ([%w_%-]+) ([%w_%-]+)$")
    if not id then return end
    if T.request and id==T.request.id and key=="all" and (state=="denied" or state=="unsupported") then
        T.catalogFailed(T.reason(reason)); return
    end
    local a=T.active
    if not a or a.id~=id or a.key~=key or a.identity~=T.identity then return end
    if not ManTechPB_LFGLeader() or T.destination~=a.key then ManTechPB_LFGStop("Travel stopped: leader or destination changed."); return end
    if state=="denied" or state=="unsupported" then
        if reason=="undiscovered" then T.snapshot[key]="locked" end
        local message=T.reason(reason); ManTechPB_LFGStop(message); T.status(message); return
    end
    if state=="ready" and reason=="ok" and a.phase=="check" then
        -- Phase changes BEFORE sending go. Duplicate ready replies cannot send it twice.
        a.phase="go"; a.pollAt=GetTime()+2
        T.status("Teleporting you. Waiting for server-confirmed arrival...")
        T.send(a.id,"go",a.key)
    elseif state=="arrived" and reason=="ok" and a.phase=="go" then
        T.active=nil
        -- Travel is a one-shot action. Retried preparation must not teleport again.
        T.destination="NONE"; T.passOnce=true; ManTechPB_LFG.building=nil
        T.status("Arrival confirmed. Recruiting missing bots, then summoning and preparing them.")
        T.paint(); ManTechPB_LFGBuildGroup(); T.passOnce=nil
    end
end
function ManTechPB_LFGSystemReply(message)
    local text=R.clean(message)
    if string.find(text,"^PBTPU ") then T.snapshotReply(text)
    elseif string.find(text,"^PBTP ") then T.travelReply(text)
    else T.base.system(message) end
end
function T.select(value)
    if T.active then ManTechPB_LFGStop("Travel cancelled because the destination changed.") end
    local _,known=T.catalog()
    if value~="NONE" and not known[value] then return end
    T.destination=value; T.paint()
    if value~="NONE" and not T.valid then T.refreshWanted=true; T.fetch() end
end
function T.paint()
    if not T.dropdown then return end
    local list,known=T.catalog()
    local choices={{value="NONE",label="No teleport - build here"}}
    for _,d in ipairs(list) do
        local suffix=not T.valid and " [Unchecked]" or (T.snapshot[d.key]=="unlocked" and " [Unlocked]" or " [Locked]")
        table.insert(choices,{value=d.key,label=d.label..suffix})
    end
    T.dropdown.value=T.destination; ManTechPB_LFGSetMenu(T.dropdown,choices)
    T.dropdown:SetText(ManTechPB_LFGDropdownText(T.dropdown))
    local d=known[T.destination]
    if d then
        local state=not T.valid and "Discovery not verified. Refresh to check." or (T.snapshot[d.key]=="unlocked" and "Unlocked for this character; travel eligibility is checked at Build." or T.lockedText)
        T.notice:SetText(state.." "..d.note)
    else T.notice:SetText("Optional: select a dungeon. Teleport -> recruit -> summon -> prep. Keep members stay unchanged.") end
end
function T.maxChanged()
    local s=ManTechPB_LFG
    if not T.maximum then return end
    if s.building or s.searching then T.levelPaint(); return end
    local value=tonumber(T.maximum:GetText())
    local minimum=ManTechPB_LFGLevelBounds()
    local cap=ManTechPB_LFGInterface()<20000 and 60 or (ManTechPB_LFGInterface()<30000 and 70 or 80)
    if not value or value~=math.floor(value) or value<minimum or value>cap then
        T.status("Maximum bot level must be a whole number from "..minimum.." to "..cap..".")
    else s.maxRecruitLevel=value; ManTechPB_LFGSavePlan() end
    T.levelPaint()
end
function T.levelPaint()
    if not T.minimum then return end
    local minimum,maximum=ManTechPB_LFGLevelBounds()
    T.minimum:SetText(tostring(minimum))
    if not T.editing then T.maximum:SetText(tostring(maximum)) end
end
function ManTechPB_LFGRefreshRows()
    T.base.refresh()
    if T.dropdown then
        local busy=ManTechPB_LFG.building or ManTechPB_LFG.searching
        if busy then T.dropdown:Disable(); T.refreshButton:Disable(); T.maximum:EnableMouse(false)
        else T.dropdown:Enable(); T.refreshButton:Enable(); T.maximum:EnableMouse(true) end
        T.levelPaint(); T.paint()
    end
end
function ManTechPB_CreateLFGFrame()
    T.base.create()
    if T.dropdown then return end
    local s=ManTechPB_LFG; local f=s.frame
    -- Use the existing spare bottom band; retain all eight raid rows and pagination.
    T.dropdown=ManTechPB_CreateLFGDropdown(f,320,-468,465,{{value="NONE",label="No teleport - build here"}},T.destination,T.select)
    T.dropdown.pageSize=8; T.dropdown.menuWidth=465
    T.dropdown.menu:ClearAllPoints(); T.dropdown.menu:SetPoint("BOTTOMLEFT",T.dropdown,"TOPLEFT",0,1)
    T.dropdown:SetScript("OnEnter",function()
        GameTooltip:SetOwner(T.dropdown,"ANCHOR_TOP"); GameTooltip:AddLine("Dungeon teleport")
        GameTooltip:AddLine("Enter the actual dungeon once AFTER the core update to unlock it for this character.",1,1,1,true)
        GameTooltip:AddLine("Shared-map wings unlock together. Old visits, achievements and lockouts are not proof of discovery.",1,1,1,true)
        local _,known=T.catalog(); local d=known[T.destination]
        if d then GameTooltip:AddLine(d.note,1,1,1,true) end
        GameTooltip:AddLine("After arrival this selector resets to No teleport, so Resume won't move you again.",1,1,1,true)
        GameTooltip:Show()
    end)
    T.dropdown:SetScript("OnLeave",function() GameTooltip:Hide() end)
    T.refreshButton=CreateFrame("Button",nil,f,"UIPanelButtonTemplate")
    T.refreshButton:SetWidth(170); T.refreshButton:SetHeight(26); T.refreshButton:SetPoint("TOPLEFT",f,"TOPLEFT",800,-468)
    T.refreshButton:SetText("Refresh unlocks"); ManTechPB_StyleButton(T.refreshButton,12)
    T.refreshButton:SetScript("OnClick",function()
        T.schedule(); T.fetch(); T.status("Refreshing discovery (at most once every 10 seconds).")
    end)
    T.notice=f:CreateFontString(nil,"OVERLAY","GameFontNormal")
    T.notice:SetPoint("TOPLEFT",f,"TOPLEFT",20,-578); T.notice:SetWidth(950); T.notice:SetHeight(34)
    T.notice:SetJustifyH("LEFT"); T.notice:SetJustifyV("TOP"); ManTechPB_SetReadableFont(T.notice,11,"")
    s.status:SetHeight(26)
    s.rangeDropdown:Hide()
    for _,item in ipairs({{text="Min",x=190},{text="Max",x=264}}) do
        local label=f:CreateFontString(nil,"OVERLAY","GameFontNormal")
        label:SetPoint("TOPLEFT",f,"TOPLEFT",item.x,-97); label:SetText(item.text); ManTechPB_SetReadableFont(label,12,"")
    end
    T.minimum=f:CreateFontString(nil,"OVERLAY","GameFontNormal")
    T.minimum:SetPoint("TOPLEFT",f,"TOPLEFT",223,-97); ManTechPB_SetReadableFont(T.minimum,13,"")
    T.maximum=CreateFrame("EditBox","ManTechPBLFGMaximumLevel",f,"InputBoxTemplate")
    T.maximum:SetWidth(36); T.maximum:SetHeight(26); T.maximum:SetPoint("TOPLEFT",f,"TOPLEFT",300,-91)
    T.maximum:SetAutoFocus(false); T.maximum:SetNumeric(true); T.maximum:SetMaxLetters(2); ManTechPB_SetReadableFont(T.maximum,13,"")
    T.maximum:SetScript("OnEditFocusGained",function() T.editing=true end)
    T.maximum:SetScript("OnEditFocusLost",function() T.editing=nil; T.maxChanged() end)
    T.maximum:SetScript("OnEnterPressed",function() T.maximum:ClearFocus() end)
    T.maximum:SetScript("OnEscapePressed",function() T.editing=nil; T.levelPaint(); T.maximum:ClearFocus() end)
    T.levelPaint(); T.paint(); T.refreshWanted=true
end
function T.event(name,level)
    if name=="PLAYER_ENTERING_WORLD" then T.schedule()
    elseif name=="PLAYER_LEVEL_UP" then
        local n=tonumber(level)
        if n then ManTechPB_LFG.observedLevel=n end
        if ManTechPB_LFG.building or ManTechPB_LFG.searching then ManTechPB_LFGStop("Player level changed. Build / Resume to use the updated bot level limits.") end
        T.levelPaint()
    elseif name=="PLAYER_LEAVING_WORLD" then T.inTransfer=true end
    if name=="PLAYER_ENTERING_WORLD" then T.inTransfer=nil end
end
function T.update()
    local now=GetTime()
    if now<(T.updateAt or 0) then return end
    T.updateAt=now+0.25
    local identity=ManTechPB_LFGPlanKey()
    if identity~=T.identity then
        if T.active then ManTechPB_LFGStop("Character changed; travel cancelled.") end
        T.identity=identity; T.request=nil; T.snapshot={}; T.valid=false; T.destination="NONE"; T.refreshWanted=true
    end
    for id,record in pairs(T.issued) do if now>record.expires then T.issued[id]=nil end end
    local a=T.active
    if a then
        if not ManTechPB_LFGLeader() or T.destination~=a.key then ManTechPB_LFGStop("Travel stopped: leader or destination changed.")
        elseif now>=a.untilAt then ManTechPB_LFGStop("Teleport confirmation timed out. No recruitment started; an already-sent teleport may still finish.")
        elseif a.phase=="go" and now>=(a.pollAt or now) and not T.inTransfer then
            a.pollAt=now+2; T.send(a.id,"status",a.key)
        end
    end
    if T.request and now>=T.request.untilAt then T.catalogFailed("Dungeon discovery did not return a complete list. Refresh unlocks to retry; travel remains unverified.") end
    if T.refreshWanted and not T.inTransfer and not ManTechPB_LFG.building and not ManTechPB_LFG.searching then T.fetch() end
end
T.frame=CreateFrame("Frame")
T.frame:RegisterEvent("PLAYER_ENTERING_WORLD"); T.frame:RegisterEvent("PLAYER_LEAVING_WORLD"); T.frame:RegisterEvent("PLAYER_LEVEL_UP")
T.frame:SetScript("OnEvent",function(self,eventName,arg) T.event(eventName or event,arg or arg1) end)
T.frame:SetScript("OnUpdate",T.update); T.frame:Show()
