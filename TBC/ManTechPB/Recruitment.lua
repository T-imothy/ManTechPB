-- Optional core contract c87bc38ef3da57282b3643da8e2cbdddb28c0a45.
-- Separate chunk keeps Vanilla's Lua 5.0 closure/upvalue limits intact.
ManTechPB_Recruit = {base={}, epoch=0, touched={}, cancels={}, cancelIds={}, known={}, issued={}, sequence=0,
    classes={WARRIOR=1,PALADIN=2,HUNTER=3,ROGUE=4,PRIEST=5,DEATHKNIGHT=6,SHAMAN=7,MAGE=8,WARLOCK=9,DRUID=11}}
local R=ManTechPB_Recruit
R.base.send=ManTechPB_LFGSend
R.base.search=ManTechPB_LFGStartSearch
R.base.nextWho=ManTechPB_LFGSendNextWho
R.base.invite=ManTechPB_LFGInvite
R.base.arrival=ManTechPB_LFGArrival
R.base.chat=ManTechPB_LFGChatReply
R.base.system=ManTechPB_LFGSystemReply
R.base.stop=ManTechPB_LFGStop
R.base.build=ManTechPB_LFGBuildGroup
R.base.create=ManTechPB_CreateLFGFrame
R.base.supply=ManTechPB_LFGSupply

function R.db()
    ManTechPBDB=ManTechPBDB or {}
    ManTechPBDB.recruit=ManTechPBDB.recruit or {counter=0,journal={}}
    return ManTechPBDB.recruit
end
function R.enabled() return R.db().mode~="legacy" end
function R.id()
    local db=R.db(); db.counter=(db.counter or 0)+1
    return "mtp"..string.format("%.0f",time and time() or 0).."_"..db.counter
end
function R.key(candidate)
    return (GetRealmName and GetRealmName() or "")..":"..UnitName("player")..":"..(candidate.guid or candidate.name)
end
function R.clean(text)
    text=string.gsub(text or "","|c%x%x%x%x%x%x%x%x","")
    return string.gsub(text,"|r","")
end
function R.rememberWire(id,text)
    R.issued[id]={command=text,expires=GetTime()+600}
end
function R.hideWireChat(eventName,message,sender)
    if R.db().debugWire then return false end
    local text=R.clean(message)
    local id
    if eventName=="CHAT_MSG_SYSTEM" then
        local a,b; a,b,id=string.find(text,"^PBRECRUIT 1 ([%w_%-]+) ")
    elseif eventName=="CHAT_MSG_SAY" and string.gsub(sender or "","%-.*$","")==UnitName("player") then
        local a,b; a,b,id=string.find(text,"^%.bot recruit v1 ([%w_%-]+) ")
        if id and R.issued[id] and R.issued[id].command~=text then return false end
    end
    return id and R.issued[id] and R.issued[id].expires>=GetTime() and true or false
end
function R.status(text) ManTechPB_LFGSetStatus(text,"|cffffff00") end
function R.slot() local s=ManTechPB_LFG; return s.slots and s.slots[s.slotIndex or 0] end
function R.guid(slot)
    if not slot or not slot.candidate or ManTechPB_LFGReserved(slot) then return nil end
    if slot.candidate.guid then return slot.candidate.guid end
    local member=ManTechPB_LFGMember(slot.candidate.name)
    local guid=member and UnitGUID and UnitGUID(member.unit)
    -- Legacy WoW player GUIDs are 64-bit hexadecimal strings. Do not parse creature GUIDs.
    if type(guid)=="string" and string.find(guid,"^0x00000000%x%x%x%x%x%x%x%x$") then
        local low=tonumber(string.sub(guid,-8),16)
        if low and low>0 then slot.candidate.guid=string.format("%.0f",low); return slot.candidate.guid end
    end
    if R.known[slot.candidate.name] then slot.candidate.guid=R.known[slot.candidate.name]; return slot.candidate.guid end
end
function R.valid(op)
    local s=ManTechPB_LFG
    if op.epoch~=R.epoch then return false end
    if op.kind=="discover" then return s.searching and op.search==s.searchSerial end
    local slot=R.slot()
    return s.building and op.run==s.runToken and slot and not ManTechPB_LFGReserved(slot)
        and slot.candidate and R.guid(slot)==op.guid and slot.candidate.name==op.name
end
function R.request(kind,guid,args,callback,delay)
    if R.active and not R.valid(R.active) then R.active=nil end
    if R.active then ManTechPB_LFGStop("Recruitment operation overlap; stopped safely."); return end
    local s=ManTechPB_LFG; local slot=R.slot()
    local op={id=R.id(),kind=kind,guid=tostring(guid or 0),args=args or "",callback=callback,
        epoch=R.epoch,run=s.runToken,search=s.searchSerial,name=slot and slot.candidate and slot.candidate.name,
        sendAt=GetTime()+(delay or 0),attempts=0,backoffs=0,rows={}}
    R.active=op
    if s.building then s.deadline=GetTime()+80 end
    return op
end
function R.finish(op,state,result)
    if R.active~=op or not R.valid(op) then return end
    R.active=nil
    op.callback(state,result,op)
end
function R.fail(op,reason)
    R.finish(op,"refused",reason)
end
function R.sendOperation(op)
    if not R.valid(op) then R.active=nil; return end
    local s=ManTechPB_LFG
    if s.building and not ManTechPB_LFGRosterReady() then
        op.sendAt=GetTime()+0.25; return
    end
    if s.building and (not ManTechPB_LFGMembershipValid() or not ManTechPB_LFGLeader() or
        ManTechPB_LFGInBG() or (UnitAffectingCombat and UnitAffectingCombat("player"))) then
        ManTechPB_LFGStop("Recruitment stopped: roster, leadership, combat or activity changed."); return
    end
    if op.kind=="prepare" then
        if not R.base.arrival(op.name) then ManTechPB_LFGStop(op.name..": no longer ready nearby; preparation stopped."); return end
        local slot=R.slot(); local key=R.key(slot.candidate); local journal=R.db().journal
        local record=journal[key]
        if record and record.pending and record.pending.id~=op.id then
            ManTechPB_LFGStop(op.name..": earlier preparation has an unknown result. Inspect the bot; /mtprecruit reconcile "..op.name.." deliberately permits new preparation."); return
        end
        record=record or {done={}}
        if record.signature~=slot.prepSignature then record.done={} end
        record.done=record.done or {}; journal[key]=record
        record.name=op.name; record.signature=slot.prepSignature
        record.pending={id=op.id,operation=op.args,signature=slot.prepSignature}
        op.journalKey=key
    end
    if op.kind=="reserve" or op.kind=="invite" or op.kind=="summon" then R.touched[op.guid]=true end
    op.attempts=op.attempts+1; op.sentAt=GetTime(); op.firstSent=op.firstSent or GetTime()
    op.sendAt=nil; op.nextRetry=GetTime()+8
    op.expires=op.expires or GetTime()+((op.kind=="summon" and 60) or (op.kind=="invite" and 35) or 28)
    if op.kind=="discover" then R.lastDiscovery=GetTime() end
    local command=".bot recruit v1 "..op.id.." "..op.kind.." "..
        (op.kind=="discover" and op.args or op.guid..(op.args~="" and " "..op.args or ""))
    R.rememberWire(op.id,command)
    SendChatMessage(command,"SAY")
end
function R.retryable(reason)
    return reason=="busy" or reason=="discovery_rate_limit" or reason=="receipt_limit" or
        string.find(reason,"rate_limit",1,true) or string.find(reason,"rate limit",1,true)
end
function R.reply(message)
    local _,_,id,guid,state,result=string.find(R.clean(message),"^PBRECRUIT 1 ([%w_%-]+) (%d+) ([%w_]+) (.+)$")
    if not id then return false end
    if R.cancelIds[id] then
        if result=="transfer_may_complete" then R.status("Cancelled; an already-started teleport may still complete. Joined members and completed work are kept.") end
        return true
    end
    local op=R.active
    if not op or op.id~=id or not op.sentAt or not R.valid(op) then return true end
    if op.kind~="discover" and guid~=op.guid then return true end
    if op.kind=="discover" and state~="eligible" and guid~="0" then return true end
    R.supported=true; op.ack=true
    if state=="pending" or state=="invite_pending" or state=="summon_pending" then
        R.status((op.name or "Recruitment")..": "..state.." - "..result)
        -- This request will not receive another operation's terminal response.
        if op.kind=="summon" and result=="existing_request" then R.finish(op,state,result) end
        return true
    end
    if op.kind=="discover" and state=="eligible" then
        local _,_,name,class,level=string.find(result,"^ok (%S+) (%d+) (%d+)$")
        if name and guid~="0" and tonumber(class)==R.classes[ManTechPB_LFG.currentQueryClass] then
            op.rows[guid]={name=name,guid=guid,class=ManTechPB_LFG.currentQueryClass,level=tonumber(level)}
        end
        return true
    end
    if op.kind=="discover" and state=="complete" then
        op.completion=result; op.completeAt=op.completeAt or GetTime()+0.5
        return true
    end
    if state=="refused" and R.retryable(result) and op.backoffs<3 then
        -- An explicit refusal did no work. A deliberate retry gets a NEW ID.
        if op.journalKey then R.db().journal[op.journalKey].pending=nil end
        op.backoffs=op.backoffs+1; op.id=R.id(); op.attempts=0; op.ack=nil; op.sentAt=nil
        op.expires=nil; op.firstSent=nil; op.rows={}; op.sendAt=GetTime()+2*op.backoffs
        ManTechPB_LFG.deadline=GetTime()+80
        R.status("Server "..result.."; bounded retry "..op.backoffs.."/3."); return true
    end
    if state=="refused" or state=="timed_out" or state=="cancelled" or state=="complete" or
        state=="eligible" or state=="reserved" or state=="joined" or state=="arrived" then
        R.finish(op,state,result)
    end
    return true
end

-- Stop collecting when the current requested composition can be matched. Counting
-- raw class rows would incorrectly reuse the same warrior for tank and DPS slots.
function R.planComplete(class)
    for _,slot in ipairs(ManTechPB_LFG.slots or {}) do
        if ManTechPB_LFGRecruitSlot(slot) and (not class or ManTechPB_LFGCandidateMatches({class=class},slot)) then
            if not slot.candidate or not slot.candidate.guid or not ManTechPB_LFGCandidateMatches(slot.candidate,slot) then return false end
        end
    end
    return true
end
function R.searchProgress()
    local found,wanted=0,0
    for _,slot in ipairs(ManTechPB_LFG.slots or {}) do
        if ManTechPB_LFGRecruitSlot(slot) then
            wanted=wanted+1; if slot.candidate then found=found+1 end
        end
    end
    return found.."/"..wanted.." candidates (not joined yet)"
end
function R.discoveryDone(state,result,op)
    local s=ManTechPB_LFG
    if state~="complete" then ManTechPB_LFGStop("Bot discovery "..state..": "..result..". Core v1 is required; select Legacy for older cores."); return end
    local _,_,cursor,scanned=string.find(result,"^cursor=(%d+);scanned=(%d+)$")
    if not cursor or (cursor~="0" and tonumber(cursor)<=tonumber(R.cursor or 0)) then ManTechPB_LFGStop("Invalid/non-progressing discovery cursor."); return end
    -- Commit a batch only with its matching completion; lost replies replay the SAME ID/batch.
    for _,c in pairs(op.rows) do
        if c.level>=s.minLevel and c.level<=s.maxLevel and not s.seenCandidates[c.name] and
            c.name~=UnitName("player") and not ManTechPB_LFGMember(c.name) then
            s.seenCandidates[c.name]=true; R.known[c.name]=c.guid; table.insert(s.candidates,c)
        end
    end
    R.cursor=cursor
    ManTechPB_LFGAssignCandidates(); ManTechPB_LFGRefreshRows()
    -- A nonzero cursor means more bots exist, not that we need to scan them.
    ManTechPB_LFGSendNextWho(s.searchSerial,cursor~="0" and not R.planComplete(s.currentQueryClass))
end
function ManTechPB_LFGSendNextWho(serial,retry)
    if not R.enabled() then return R.base.nextWho(serial,retry) end
    local s=ManTechPB_LFG
    if serial~=s.searchSerial or not s.searching then return end
    if R.reuseCandidates then
        s.candidates=R.reuseCandidates; R.reuseCandidates=nil
        for _,c in ipairs(s.candidates) do s.seenCandidates[c.name]=true end
        ManTechPB_LFGAssignCandidates()
    end
    if not retry then s.queryIndex=s.queryIndex+1; R.cursor="0" end
    while s.queryIndex<=table.getn(s.queryClasses) and R.planComplete(s.queryClasses[s.queryIndex]) do
        s.queryIndex=s.queryIndex+1; R.cursor="0"
    end
    if s.queryIndex>table.getn(s.queryClasses) then
        s.searching=nil; s.waitingWho=nil; ManTechPB_LFGAssignCandidates(); ManTechPB_LFGRefreshRows()
        if s.building then R.status("Candidates found. Rechecking and inviting now..."); ManTechPB_LFGBeginSlots()
        else R.status(R.searchProgress()..". Click Build / Resume to recheck and invite.") end
        return
    end
    R.pages=(R.pages or 0)+1
    if R.pages>128 then ManTechPB_LFGStop("Discovery page limit reached. Narrow the class/level criteria."); return end
    s.currentQueryClass=s.queryClasses[s.queryIndex]
    R.status("Searching "..(ManTechPB_LFGClassLabels[s.currentQueryClass] or s.currentQueryClass).." "..s.minLevel.."-"..s.maxLevel.." - "..R.searchProgress())
    R.request("discover","0",R.classes[s.currentQueryClass].." "..s.minLevel.." "..s.maxLevel.." "..R.cursor,
        R.discoveryDone,math.max(0,(R.lastDiscovery or -2)+2.1-GetTime()))
end
function ManTechPB_LFGStartSearch(index,automatic)
    if table.getn(R.cancels)>0 then R.status("Finishing cancellation/release requests before another search."); return end
    if ManTechPB_LFG.searching then return end
    -- Keep complete selections from a cancelled/preview search, but status-check
    -- every bot again before any invitation. No cached eligibility is trusted.
    R.reuseCandidates=nil
    if R.enabled() and automatic and R.planComplete() then R.reuseCandidates=ManTechPB_LFG.candidates end
    if not ManTechPB_LFG.searching then R.pages=0; R.cursor="0" end
    return R.base.search(index,automatic)
end

function R.identityDone(state,result,op)
    local s=ManTechPB_LFG
    if state=="eligible" or state=="joined" or state=="arrived" then
        s.verified=true; s.armed.who=true
    else
        R.status(op.name..": "..state.." - "..result); s.lastRecruitReason=result; s.unavailable=true
    end
end
function R.inviteDone(state,result,op)
    if state=="joined" then R.status(op.name..": accepted; waiting for roster membership.")
    else
        if result=="group_full" or result=="not_leader" or result=="membership_changed" then
            ManTechPB_LFGStop(op.name..": invitation "..result..". Review the roster.")
        else ManTechPB_LFG.deadline=GetTime(); R.status(op.name..": invitation "..state.." - "..result) end
    end
end
function R.reserveDone(state,result,op)
    if state=="reserved" then
        R.request("invite",op.guid,tostring(ManTechPB_LFG.size),R.inviteDone)
    elseif state=="joined" then R.status(op.name..": already joined; checking roster.")
    else R.inviteDone(state,result,op) end
end
function ManTechPB_LFGInvite(name)
    local guid=R.enabled() and R.guid(R.slot())
    if not guid then return R.base.invite(name) end
    R.request("reserve",guid,"",R.reserveDone)
end
function R.arrivalDone(state,result,op)
    if state=="arrived" then
        local slot=R.slot(); slot.serverArrived=true
        R.status(op.name..": server confirmed arrival (10 yards and line of sight).")
    elseif state=="summon_pending" and result=="existing_request" then
        R.arrivalPoll={guid=op.guid,epoch=R.epoch,at=GetTime()+3,expires=GetTime()+50}
    else ManTechPB_LFGStop(op.name..": summon "..state.." - "..result) end
end
function R.pollDone(state,result,op)
    if state=="arrived" then R.arrivalPoll=nil; R.arrivalDone(state,result,op)
    elseif state=="joined" then
        if R.arrivalPoll then R.arrivalPoll.at=GetTime()+3 end
        R.status(op.name..": waiting for server arrival - "..result)
    else R.arrivalPoll=nil; ManTechPB_LFGStop(op.name..": arrival "..state.." - "..result) end
end
function ManTechPB_LFGArrival(name)
    local ok,reason=R.base.arrival(name)
    if not ok then return ok,reason end
    if R.enabled() then
        for _,slot in ipairs(ManTechPB_LFG.slots or {}) do
            if not ManTechPB_LFGReserved(slot) and slot.candidate and slot.candidate.name==name and R.guid(slot) then
                if not slot.serverArrived then return false,"waiting for authoritative core arrival" end
            end
        end
    end
    return true,reason
end
function R.prepDone(state,result,op)
    local s=ManTechPB_LFG; local slot=R.slot()
    local record=op.journalKey and R.db().journal[op.journalKey]
    if state=="complete" and result==s.supplyExpected then
        if record then record.pending=nil; record.done[op.args]=true end
        slot.supplyDone=slot.supplyDone or {}; slot.supplyDone[s.supplyIndex]=true; s.supplyConfirmed=true
    else
        -- An explicit terminal denial is known. A lost acknowledgment remains uncertain.
        if record and result~="unknown_result" and state~="complete" then record.pending=nil end
        ManTechPB_LFGStop(op.name..": "..op.args.." "..state.." - "..result)
    end
end
function ManTechPB_LFGSupply()
    local slot=R.slot()
    -- A protocol switch/client reload must not bypass an unknown result by losing its GUID.
    if slot and slot.candidate then
        local prefix=(GetRealmName and GetRealmName() or "")..":"..UnitName("player")..":"
        for key,record in pairs(R.db().journal) do
            if string.sub(key,1,string.len(prefix))==prefix and record.name==slot.candidate.name and record.pending then
                ManTechPB_LFGStop(slot.candidate.name..": preparation result unknown. Inspect the bot, then /mtprecruit reconcile "..slot.candidate.name.." if new preparation is needed."); return
            end
            if string.sub(key,1,string.len(prefix))==prefix and record.name==slot.candidate.name and not record.pending then
                local signature=ManTechPB_LFGReadySignature(slot)..":"..(slot.build and slot.build.name or "")
                if record.signature==signature then
                    slot.prepSignature=signature; slot.supplyDone=slot.supplyDone or {}
                    for i,kind in ipairs({"gear","food","potions","consumes","reagents","ammo"}) do
                        if record.done[kind] then slot.supplyDone[i]=true end
                    end
                end
            end
        end
    end
    if R.enabled() and slot and R.guid(slot) then
        local record=R.db().journal[R.key(slot.candidate)]
        local signature=ManTechPB_LFGReadySignature(slot)..":"..(slot.build and slot.build.name or "")
        if record and record.pending then
            ManTechPB_LFGStop(slot.candidate.name..": preparation result unknown. Inspect the bot, then /mtprecruit reconcile "..slot.candidate.name.." if new preparation is needed."); return
        end
        if record and record.signature==signature then
            slot.prepSignature=signature; slot.supplyDone=slot.supplyDone or {}
            for i,kind in ipairs({"gear","food","potions","consumes","reagents","ammo"}) do
                if record.done[kind] then slot.supplyDone[i]=true end
            end
        end
    end
    R.base.supply()
end
function ManTechPB_LFGSend(text,name,raw,gate)
    local s=ManTechPB_LFG; local slot=R.slot(); local guid=R.enabled() and R.guid(slot)
    if guid and s.building then
        if text=="who" then
            R.request("status",guid,"",R.identityDone); return true
        elseif text=="summon" then
            -- Original tick may ask twice; one logical operation has one deadline/ID.
            if not slot.summonRequested then slot.summonRequested=true; R.request("summon",guid,"",R.arrivalDone) end
            return true
        elseif gate=="supply" then
            s.armed.supply=true
            R.request("prepare",guid,s.supplyCommand,R.prepDone); return true
        end
    end
    return R.base.send(text,name,raw,gate)
end

function ManTechPB_LFGChatReply(message,sender)
    local s=ManTechPB_LFG; local slot=R.slot()
    local bare=string.gsub(sender or "","%-.*$","")
    if s.building and s.stage=="verify" and slot and slot.candidate and bare==slot.candidate.name and s.armed.who then
        local clean=R.clean(message)
        local _,_,reason=string.find(clean,"^Recruitment unavailable: (.+)$")
        if reason then s.unavailable=true; R.status(bare..": unavailable - "..reason); return end
        if clean=="Recruitment pending: transfer" then
            if not R.legacyPending or R.legacyPending.name~=bare then
                R.legacyPending={name=bare,epoch=R.epoch,untilAt=GetTime()+25,nextAt=GetTime()+5}
                s.deadline=GetTime()+25
            end
            R.status(bare..": transferring; bounded wait before invitation."); return
        end
    end
    R.base.chat(message,sender)
end
function ManTechPB_LFGSystemReply(message)
    if R.reply(message) then return end
    local s=ManTechPB_LFG; local slot=R.slot(); local clean=R.clean(message)
    if s.building and slot and slot.candidate then
        local prefix=slot.candidate.name..": "
        if string.sub(clean,1,string.len(prefix))==prefix then
            local _,_,state,reason=string.find(string.sub(clean,string.len(prefix)+1),"^([%w_]+) %((.-)%)$")
            if state and (s.stage=="invite" or s.stage=="arrival") then
                if state=="refused" or state=="timed_out" or state=="cancelled" then
                    if s.stage=="invite" then s.deadline=GetTime(); R.status(clean)
                    else ManTechPB_LFGStop(clean) end
                    return
                end
                R.status(clean)
            end
        end
    end
    if R.active and not R.supported and (string.find(string.lower(clean),"unknown command",1,true) or
        string.find(string.lower(clean),"no such command",1,true)) then
        ManTechPB_LFGStop("Core recruitment v1 is unsupported. Select Legacy mode for older cores; no automatic mutation fallback."); return
    end
    R.base.system(message)
end

function ManTechPB_LFGStop(message,success)
    R.epoch=R.epoch+1; R.active=nil; R.arrivalPoll=nil; R.legacyPending=nil
    -- Cancel only GUIDs touched by THIS builder, not all the player's manual requests.
    for guid in pairs(R.touched) do table.insert(R.cancels,{id=R.id(),guid=guid}) end
    R.touched={}
    R.base.stop(message,success)
end
function ManTechPB_LFGBuildGroup()
    if table.getn(R.cancels)>0 then R.status("Finishing cancellation/release requests. Try Build / Resume in a moment."); return end
    if ManTechPB_LFG.building or ManTechPB_LFG.searching then return end
    R.epoch=R.epoch+1; R.active=nil; R.arrivalPoll=nil; R.legacyPending=nil
    for _,slot in ipairs(ManTechPB_LFG.slots or {}) do slot.serverArrived=nil; slot.summonRequested=nil end
    R.base.build()
end
function ManTechPB_CreateLFGFrame()
    R.base.create()
    local s=ManTechPB_LFG
    if s.protocolButton then return end
    local b=CreateFrame("Button",nil,s.frame,"UIPanelButtonTemplate"); s.protocolButton=b
    b:SetWidth(230); b:SetHeight(30); b:SetPoint("TOPLEFT",s.frame,"TOPLEFT",605,-508)
    ManTechPB_StyleButton(b,12)
    b:SetText(R.enabled() and "Protocol: Core v1" or "Protocol: Legacy")
    b:SetScript("OnClick",function()
        if s.building or s.searching or table.getn(R.cancels)>0 then R.status("Cancel and finish pending releases before switching protocol."); return end
        R.db().mode=R.enabled() and "legacy" or "v1"; s.candidates={}
        for _,slot in ipairs(s.slots) do if not slot.prepareName and not slot.keepName then slot.candidate=nil end end
        b:SetText(R.enabled() and "Protocol: Core v1" or "Protocol: Legacy")
        R.status(R.enabled() and "Core v1 uses bot-only discovery and authoritative arrival. Existing bots without a client GUID use legacy commands." or "Legacy uses /who and readable replies; no structured arrival or durable operation IDs.")
        ManTechPB_LFGRefreshRows()
    end)
    s.searchButton:SetText("Preview search")
end

function R.update()
    local now=GetTime(); local s=ManTechPB_LFG
    if now>=(R.pruneAt or 0) then
        R.pruneAt=now+30
        for id,record in pairs(R.issued) do if now>record.expires then R.issued[id]=nil end end
    end
    if table.getn(R.cancels)>0 and now>=(R.cancelAt or 0) then
        local c=table.remove(R.cancels,1); R.cancelIds[c.id]=true; R.cancelAt=now+0.75
        local command=".bot recruit v1 "..c.id.." cancel "..c.guid
        R.rememberWire(c.id,command); SendChatMessage(command,"SAY")
    end
    local op=R.active
    if op then
        if not R.valid(op) then R.active=nil
        elseif op.completeAt and now>=op.completeAt then R.finish(op,"complete",op.completion)
        elseif op.sendAt and now>=op.sendAt then R.sendOperation(op)
        elseif op.expires and now>=op.expires then
            if op.kind=="prepare" then R.fail(op,"unknown_result")
            else R.fail(op,"response_timeout (not proof of unsupported core)") end
        elseif op.sentAt and now>=op.nextRetry and op.attempts<3 then
            -- Identical ID AND payload: replay receipts; never renew a mutation deadline.
            R.sendOperation(op)
        end
    elseif R.arrivalPoll and R.arrivalPoll.epoch==R.epoch and s.building then
        if now>=R.arrivalPoll.expires then ManTechPB_LFGStop("Existing summon did not confirm arrival before the deadline.")
        elseif now>=R.arrivalPoll.at then R.request("status",R.arrivalPoll.guid,"",R.pollDone) end
    end
    local p=R.legacyPending
    if p and p.epoch==R.epoch and s.building and s.stage=="verify" and not s.verified then
        if now>=p.untilAt then R.legacyPending=nil; s.unavailable=true
        elseif now>=p.nextAt then p.nextAt=now+5; R.base.send("who",p.name,true,"who") end
    end
end
R.frame=CreateFrame("Frame"); R.frame:SetScript("OnUpdate",R.update); R.frame:Show()

SLASH_MTPBRECRUIT1="/mtprecruit"
SlashCmdList.MTPBRECRUIT=function(text)
    if text=="debug on" or text=="debug off" then
        R.db().debugWire=text=="debug on"
        R.status(R.db().debugWire and "Recruitment diagnostic chat ON." or "Recruitment diagnostic chat OFF. Progress and errors remain in this window.")
        return
    end
    local _,_,name=string.find(text or "","^reconcile (%S+)$")
    if not name or ManTechPB_LFG.building or ManTechPB_LFG.searching then
        R.status("After inspecting uncertain gear/supplies, /mtprecruit reconcile NAME deliberately allows new preparation. Stop the builder first."); return
    end
    local key=(GetRealmName and GetRealmName() or "")..":"..UnitName("player")..":"
    for k,record in pairs(R.db().journal) do
        if string.sub(k,1,string.len(key))==key and record.name==name then R.db().journal[k]=nil end
    end
    for _,slot in ipairs(ManTechPB_LFG.slots or {}) do
        if slot.candidate and slot.candidate.name==name then slot.supplyDone=nil; slot.prepSignature=nil; slot.readySignature=nil end
    end
    R.status(name..": old preparation checkpoints cleared by request. Next Build may generate new gear/supplies.")
end
