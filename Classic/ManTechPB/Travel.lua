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
    if operation=="go" and not record.goKey then
        record.goKey=key; record.goAt=time and time() or nil; record.identity=T.identity
    end
    T.issued[id]=record
    SendChatMessage(command,"SAY")
end
function T.cooldownRecord()
    local db=R.db(); db.travelCooldowns=db.travelCooldowns or {}
    local key=T.identity or ManTechPB_LFGPlanKey()
    return key and db.travelCooldowns[key],key,db.travelCooldowns
end
function T.startCooldown(started,identity)
    local _,key,records=T.cooldownRecord()
    if not key or (identity and identity~=key) or not time then return end
    -- Current deployment is 300 seconds. PBTP v1 sends no configured duration or
    -- remaining seconds: this is display-only, never an eligibility decision.
    records[key]={expires=(started or time())+300,estimated=true}
    T.cooldownPaint()
end
function T.cooldownUnknown()
    local record,key,records=T.cooldownRecord()
    if key and (type(record)~="table" or type(record.expires)~="number" or not time or record.expires<=time()) then
        records[key]={unknown=true}
    end
    T.cooldownPaint()
end
function T.cooldownText()
    local record=T.cooldownRecord()
    if type(record)=="table" then
        if record.unknown then return "Teleport cooldown: remaining time unknown" end
        if type(record.expires)=="number" and time then
            local remaining=math.max(0,math.ceil(record.expires-time()))
            if remaining>0 and remaining<=300 then
                return "Teleport cooldown: "..math.floor(remaining/60)..":"..string.format("%02d",math.mod(remaining,60)).." (estimated)"
            end
            return "Teleport estimate elapsed - server checks eligibility"
        end
    end
    return "Teleport cooldown: checked by server when building"
end
function T.cooldownPaint()
    if T.cooldownLabel then
        local label=T.cooldownText()
        if T.lastCooldownText~=label then T.cooldownLabel:SetText(label); T.lastCooldownText=label end
    end
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
    ManTechPB_LFGCloseDropdown()
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
    local receipt=T.issued[id]
    if receipt and receipt.expires>=GetTime() and receipt.goKey==key and not receipt.cooldownSeen and
        ((state=="pending" and reason=="transfer") or (state=="arrived" and reason=="ok")) then
        receipt.cooldownSeen=true
        T.startCooldown(receipt.goAt,receipt.identity)
    end
    if T.request and id==T.request.id and key=="all" and (state=="denied" or state=="unsupported") then
        T.catalogFailed(T.reason(reason)); return
    end
    local a=T.active
    if not a or a.id~=id or a.key~=key or a.identity~=T.identity then return end
    if not ManTechPB_LFGLeader() or T.destination~=a.key then ManTechPB_LFGStop("Travel stopped: leader or destination changed."); return end
    if state=="denied" or state=="unsupported" then
        if reason=="cooldown" then T.cooldownUnknown() end
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
    if string.find(text,"^Travelling to .+%.$") then T.startCooldown()
    elseif text=="Travel denied: cooldown." then T.cooldownUnknown() end
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
    local matches=0
    T.dropdown.selectedLabel="No teleport - build here"
    for _,d in ipairs(list) do
        local suffix=not T.valid and " [Unchecked]" or (T.snapshot[d.key]=="unlocked" and " [Unlocked]" or " [Locked]")
        if d.key==T.destination then T.dropdown.selectedLabel=d.label..suffix end
        if T.matchesSearch(d,T.searchText or "") then
            matches=matches+1
            table.insert(choices,{value=d.key,label=d.label..suffix})
        end
    end
    if T.searchCount then T.searchCount:SetText(matches==0 and "No matching dungeons or raids. Clear search to see all." or (matches.." destinations - choose a result below")) end
    T.dropdown.value=T.destination; ManTechPB_LFGSetMenu(T.dropdown,choices)
    if T.styleDropdown then T.styleDropdown(T.dropdown) end
    T.dropdown:SetText(ManTechPB_LFGDropdownText(T.dropdown))
    local d=known[T.destination]
    if d then
        local state=not T.valid and "Discovery not verified. Refresh to check." or (T.snapshot[d.key]=="unlocked" and "Unlocked for this character; travel eligibility is checked at Build." or T.lockedText)
        T.notice:SetText(state.." "..d.note)
    else T.notice:SetText("Optional: select a dungeon. Teleport -> recruit -> summon -> prep. Keep members stay unchanged.") end
end
function T.matchesSearch(destination,query)
    local words=string.lower(string.gsub(query,"[^%w]+"," "))
    local haystack=string.lower(string.gsub(destination.label.." "..destination.key,"[^%w]+"," "))
    for word in string.gfind(words,"%S+") do
        if not string.find(haystack,word,1,true) then return false end
    end
    return true
end
function T.searchChanged()
    if ManTechPB_LFG.building or ManTechPB_LFG.searching then return end
    T.searchText=T.searchBox:GetText() or ""
    T.dropdown.menuPage=1
    -- Filtering is local only: no selection, unlock request or travel command.
    T.paint()
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
        if T.layoutReady then T.layout() end
    end
end
function ManTechPB_CreateLFGFrame()
    T.base.create()
    if T.dropdown then return end
    local s=ManTechPB_LFG; local f=s.frame
    -- Use the existing spare bottom band; retain all eight raid rows and pagination.
    T.dropdown=ManTechPB_CreateLFGDropdown(f,320,-468,465,{{value="NONE",label="No teleport - build here"}},T.destination,T.select)
    T.dropdown.pageSize=8; T.dropdown.menuWidth=465
    T.dropdown.menuHeaderHeight=54
    T.dropdown.menu:ClearAllPoints(); T.dropdown.menu:SetPoint("BOTTOMLEFT",T.dropdown,"TOPLEFT",0,1)
    local searchLabel=T.dropdown.menu:CreateFontString(nil,"OVERLAY","GameFontNormal")
    searchLabel:SetPoint("TOPLEFT",T.dropdown.menu,"TOPLEFT",8,-13); searchLabel:SetText("Search"); ManTechPB_SetReadableFont(searchLabel,12,"")
    T.searchBox=CreateFrame("EditBox","ManTechPBDungeonSearch",T.dropdown.menu,"InputBoxTemplate")
    T.searchBox:SetPoint("TOPLEFT",T.dropdown.menu,"TOPLEFT",65,-7); T.searchBox:SetWidth(304); T.searchBox:SetHeight(24)
    T.searchBox:SetAutoFocus(false); T.searchBox:SetMaxLetters(80); ManTechPB_SetReadableFont(T.searchBox,12,"")
    T.searchBox:SetScript("OnTextChanged",T.searchChanged)
    T.searchBox:SetScript("OnEnterPressed",function() T.searchBox:ClearFocus() end)
    T.searchBox:SetScript("OnEscapePressed",function() T.searchBox:ClearFocus(); ManTechPB_LFGCloseDropdown() end)
    T.searchClear=CreateFrame("Button",nil,T.dropdown.menu,"UIPanelButtonTemplate")
    T.searchClear:SetPoint("TOPLEFT",T.dropdown.menu,"TOPLEFT",382,-7); T.searchClear:SetWidth(74); T.searchClear:SetHeight(24)
    T.searchClear:SetText("Clear"); ManTechPB_StyleButton(T.searchClear,12)
    T.searchClear:SetScript("OnClick",function() T.searchBox:SetText(""); T.searchChanged(); T.searchBox:SetFocus() end)
    T.searchCount=T.dropdown.menu:CreateFontString(nil,"OVERLAY","GameFontNormal")
    T.searchCount:SetPoint("TOPLEFT",T.dropdown.menu,"TOPLEFT",8,-35); T.searchCount:SetWidth(449); T.searchCount:SetJustifyH("LEFT"); ManTechPB_SetReadableFont(T.searchCount,11,"")
    T.dropdown.menu:SetScript("OnShow",function() T.searchBox:SetFocus() end)
    T.dropdown.menu:SetScript("OnHide",function() T.searchBox:ClearFocus() end)
    T.cooldownLabel=f:CreateFontString(nil,"OVERLAY","GameFontNormal")
    T.cooldownLabel:SetPoint("TOPLEFT",f,"TOPLEFT",605,-450); T.cooldownLabel:SetWidth(365)
    T.cooldownLabel:SetJustifyH("RIGHT"); ManTechPB_SetReadableFont(T.cooldownLabel,11,"")
    T.lastCooldownText=nil; T.cooldownPaint()
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
        if item.text=="Min" then T.minimumLabel=label else T.maximumLabel=label end
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
    T.createLayout(); T.layout()
end
-- Builder-only visual layout. Reuses the existing controls and callbacks;
-- no recruitment, travel, ownership or preparation decisions live here.
function T.place(region,x,y,width,height)
    region:ClearAllPoints(); region:SetPoint("TOPLEFT",ManTechPB_LFG.frame,"TOPLEFT",x,-y)
    if width then region:SetWidth(width) end
    if height then region:SetHeight(height) end
end
function T.textStyle(region,size,secondary)
    region:SetFont("Fonts\\ARIALN.TTF",size,"")
    if secondary then region:SetTextColor(0.85,0.90,0.97) else region:SetTextColor(1,0.94,0.62) end
end
function T.uiButton(button,primary)
    local label=button:GetFontString()
    if label then T.textStyle(label,13,false) end
    if T.normalFont then
        button:SetNormalFontObject(T.normalFont); button:SetHighlightFontObject(T.normalFont)
        button:SetDisabledFontObject(T.disabledFont)
    end
    -- Keep the existing bevel/shine and pressed feedback, but remove the stock
    -- grey disabled slab. Disabled choices remain legible, not interactive.
    button:SetDisabledTexture("")
    button:SetBackdropColor(primary and 0.12 or 0.07,primary and 0.32 or 0.16,primary and 0.43 or 0.23,1)
    button:SetBackdropBorderColor(primary and 0.50 or 0.27,primary and 0.85 or 0.46,primary and 1 or 0.60,1)
    local normal=button:GetNormalTexture()
    if normal then normal:SetVertexColor(primary and 0.16 or 0.10,primary and 0.37 or 0.22,primary and 0.49 or 0.31,1) end
end
function T.styleDropdown(dropdown)
    T.uiButton(dropdown)
    for _,button in ipairs(dropdown.options or {}) do T.uiButton(button) end
    if dropdown.pageControlsCreated==true then T.uiButton(dropdown.pagePrevious); T.uiButton(dropdown.pageNext) end
end
function T.createLayout()
    if T.layoutReady then return end
    local s=ManTechPB_LFG; local f=s.frame
    T.canvas=f:CreateTexture(nil,"BACKGROUND"); T.canvas:SetTexture(0.025,0.037,0.057,0.98)
    T.canvas:SetPoint("TOPLEFT",f,"TOPLEFT",8,-8); T.canvas:SetPoint("BOTTOMRIGHT",f,"BOTTOMRIGHT",-8,8)
    T.groupPanel=f:CreateTexture(nil,"BACKGROUND"); T.groupPanel:SetTexture(0.05,0.08,0.12,1)
    T.travelPanel=f:CreateTexture(nil,"BACKGROUND"); T.travelPanel:SetTexture(0.05,0.08,0.12,1)
    T.stripes={}
    for i=1,8 do
        local stripe=f:CreateTexture(nil,"BACKGROUND"); stripe:SetTexture(0.07,0.105,0.15,i/2==math.floor(i/2) and 0.75 or 0.35)
        T.stripes[i]=stripe
    end
    if CreateFont then
        T.normalFont=CreateFont("ManTechPBBuilderBrightFont"); T.textStyle(T.normalFont,13,false)
        T.disabledFont=CreateFont("ManTechPBBuilderDisabledFont"); T.disabledFont:SetFont("Fonts\\ARIALN.TTF",13,""); T.disabledFont:SetTextColor(0.75,0.81,0.88)
    end
    T.optionsButton=CreateFrame("Button",nil,f,"UIPanelButtonTemplate")
    ManTechPB_StyleButton(T.optionsButton,13)
    T.optionsButton:SetScript("OnClick",function()
        ManTechPB_LFGCloseDropdown(); T.optionsOpen=not T.optionsOpen; T.layout()
    end)
    T.optionNote=f:CreateFontString(nil,"OVERLAY","GameFontNormal")
    T.optionNote:SetText("Preview only searches. Protocol and PvP fallback are optional; the standard settings work for most groups.")
    T.destinationHeading=f:CreateFontString(nil,"OVERLAY","GameFontNormal"); T.destinationHeading:SetText("DESTINATION")
    T.actionHint=f:CreateFontString(nil,"OVERLAY","GameFontNormal"); T.actionHint:SetText("Teleport (optional)  >  Recruit  >  Summon  >  Prepare")
    T.statusHover=CreateFrame("Button",nil,f)
    T.statusHover:SetScript("OnEnter",function()
        GameTooltip:SetOwner(T.statusHover,"ANCHOR_TOP"); GameTooltip:AddLine("Group Builder status")
        GameTooltip:AddLine(s.statusMessage or "",1,1,1,true); GameTooltip:Show()
    end)
    T.statusHover:SetScript("OnLeave",function() GameTooltip:Hide() end)
    T.layoutReady=true
end
function T.layout()
    if not T.layoutReady then return end
    local s=ManTechPB_LFG; local extra=T.optionsOpen and 68 or 0
    local count=math.min(8,s.size)
    local rowStart=150+extra; local rowBottom=rowStart+count*34
    local paged=s.size>8; local travelTop=rowBottom+(paged and 44 or 12)
    local actions=travelTop+116; local height=actions+96
    s.frame:SetWidth(940); s.frame:SetHeight(height)
    if UIParent.GetWidth and UIParent.GetHeight then
        local width,screenHeight=UIParent:GetWidth(),UIParent:GetHeight()
        if type(width)=="number" and type(screenHeight)=="number" and width>400 and screenHeight>300 then
            s.frame:SetScale(math.min(1,(width-24)/940,(screenHeight-24)/height))
        end
    end
    T.place(s.title,20,18,500,22); T.textStyle(s.title,17,false)
    s.title:SetText("GROUP / RAID BUILDER")
    T.place(s.intro,20,47,900,18); T.textStyle(s.intro,13,true)
    s.intro:SetText("Choose your group and destination, then Build / Resume. Keep members are left unchanged.")
    T.place(T.groupPanel,16,71,908,42+extra)
    T.place(s.sizeDropdown,26,78,166,28); T.styleDropdown(s.sizeDropdown)
    T.place(T.minimumLabel,214,85,29,18); T.place(T.minimum,249,85,28,18)
    T.place(T.maximumLabel,287,85,31,18); T.place(T.maximum,327,78,42,28)
    T.textStyle(T.minimumLabel,13,true); T.textStyle(T.maximumLabel,13,true); T.textStyle(T.minimum,14,false); T.textStyle(T.maximum,14,true)
    T.place(s.summary,390,80,406,30); T.textStyle(s.summary,12,true)
    T.place(T.optionsButton,814,78,100,28); T.optionsButton:SetText(T.optionsOpen and "Options -" or "Options +"); T.uiButton(T.optionsButton)
    if T.optionsOpen then
        T.place(s.buildPolicy,26,121,223,28); s.buildPolicy:Show(); T.styleDropdown(s.buildPolicy)
        T.place(s.protocolButton,264,121,242,28); s.protocolButton:Show(); T.uiButton(s.protocolButton)
        T.place(s.searchButton,522,121,163,28); s.searchButton:Show(); T.uiButton(s.searchButton)
        T.place(T.optionNote,26,157,875,18); T.textStyle(T.optionNote,12,true); T.optionNote:Show()
    else s.buildPolicy:Hide(); s.protocolButton:Hide(); s.searchButton:Hide(); T.optionNote:Hide() end
    local columns={{"#",24},{"ROLE",44},{"CLASS",136},{"BUILD / SPEC",259},{"ACTION",461},{"MEMBER / CANDIDATE",586},{"STATUS",818}}
    for i,column in ipairs(columns) do
        local header=s.columnHeaders[i]; T.place(header,column[2],128+extra,nil,18); header:SetText(column[1]); T.textStyle(header,12,true)
    end
    for i,row in ipairs(s.rows) do
        local y=rowStart+(i-1)*34
        T.place(T.stripes[i],20,y-2,902,32)
        if s.slots[(s.page-1)*8+i] then T.stripes[i]:Show() else T.stripes[i]:Hide() end
        T.place(row.label,25,y+6,17,18); T.textStyle(row.label,12,true)
        T.place(row.role,40,y,84,28); T.styleDropdown(row.role)
        T.place(row.dropdown,132,y,115,28); T.styleDropdown(row.dropdown)
        T.place(row.spec,255,y,194,28); T.styleDropdown(row.spec)
        T.place(row.source,457,y,117,28); T.styleDropdown(row.source)
        T.place(row.candidate,582,y,223,28); T.uiButton(row.candidate)
        T.place(row.state,814,y+6,105,19); T.textStyle(row.state,12,false)
        local slot=s.slots[(s.page-1)*8+i]
        if slot then
            if ManTechPB_LFGReserved(slot) then row.state:SetTextColor(0.68,0.84,1)
            elseif slot.state=="READY" then row.state:SetTextColor(0.50,1,0.64)
            elseif slot.state=="STOPPED" then row.state:SetTextColor(1,0.58,0.52) end
        end
    end
    for _,control in ipairs({s.previousPageButton,s.pageLabel,s.nextPageButton}) do if paged then control:Show() else control:Hide() end end
    T.place(s.previousPageButton,20,rowBottom+5,90,26); T.uiButton(s.previousPageButton)
    T.place(s.pageLabel,126,rowBottom+11,110,18); T.textStyle(s.pageLabel,12,true)
    T.place(s.nextPageButton,240,rowBottom+5,90,26); T.uiButton(s.nextPageButton)
    T.place(T.travelPanel,16,travelTop,908,108)
    T.place(T.destinationHeading,28,travelTop+10,180,18); T.textStyle(T.destinationHeading,12,true)
    T.place(T.cooldownLabel,465,travelTop+10,447,18); T.textStyle(T.cooldownLabel,12,true)
    T.place(T.dropdown,28,travelTop+34,694,30); T.styleDropdown(T.dropdown)
    T.place(T.refreshButton,738,travelTop+34,174,30); T.uiButton(T.refreshButton)
    T.place(T.notice,28,travelTop+74,874,30); T.textStyle(T.notice,12,true)
    T.place(T.actionHint,24,actions+10,508,20); T.textStyle(T.actionHint,12,true)
    T.place(s.resetButton,554,actions,150,34); T.uiButton(s.resetButton)
    T.place(s.buildButton,720,actions,196,34); T.uiButton(s.buildButton,true)
    T.place(s.status,24,actions+48,890,40); T.textStyle(s.status,13,true)
    T.place(T.statusHover,20,actions+43,900,47)
    T.uiButton(s.helpButton); T.uiButton(s.instructionsButton)
    T.uiButton(T.searchClear); T.textStyle(T.searchCount,12,true); T.textStyle(T.searchBox,13,true)
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
    T.cooldownPaint()
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
