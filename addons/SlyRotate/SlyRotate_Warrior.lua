-- ============================================================
-- SlyRotate — Warrior Module
-- Fury DPS, Arms DPS, Protection Tank
-- Port of SlySuite_WarriorHelper rotation logic into the
-- SR module interface.  Auto-detects spec from known talents.
-- ============================================================

local W = {}

W.classKey   = "WARRIOR"
W.classLabel = "Warrior"
W.headerIcon = "Interface\\Icons\\Ability_Warrior_Bloodthirst"
W.specKeys   = { "FURY", "ARMS", "PROT" }
W.specLabels = { FURY="Fury DPS", ARMS="Arms DPS", PROT="Prot Tank" }

-- ─── Row definitions ─────────────────────────────────────────
local FURY_ROWS = {
    { key="SUNDER",     label="Sunder Armor",         spell="Sunder Armor",        color={0.70,0.70,0.70} },
    { key="BT",         label="Bloodthirst",          spell="Bloodthirst",         color={1.00,0.25,0.25} },
    { key="WW",         label="Whirlwind",            spell="Whirlwind",           color={1.00,0.68,0.18} },
    { key="EXECUTE",    label="Execute  (<20%)",      spell="Execute",             color={1.00,0.40,0.10} },
    { key="OVERPOWER",  label="+ Overpower  (opt)",   spell="Overpower",           color={0.45,1.00,0.45} },
    { key="HS",         label="+ Heroic Strike",      spell="Heroic Strike",       color={1.00,0.82,0.22} },
    { key="DEATH_WISH", label="Death Wish  (passive)",spell="Death Wish",          color={0.60,0.25,0.90} },
    { key="PROCS",      label="Procs  (DST/DS/MG)",   spell="Heroic Strike",       color={0.20,0.90,0.95} },
}
local ARMS_ROWS = {
    { key="SUNDER",     label="Sunder Armor",         spell="Sunder Armor",        color={0.70,0.70,0.70} },
    { key="SLAM",       label="Slam  (post-swing)",   spell="Slam",                color={1.00,0.95,0.35} },
    { key="MS",         label="Mortal Strike",        spell="Mortal Strike",       color={1.00,0.25,0.25} },
    { key="WW",         label="Whirlwind",            spell="Whirlwind",           color={1.00,0.68,0.18} },
    { key="EXECUTE",    label="Execute  (<20%)",      spell="Execute",             color={1.00,0.40,0.10} },
    { key="HS",         label="+ Heroic Strike",      spell="Heroic Strike",       color={1.00,0.82,0.22} },
    { key="DEATH_WISH", label="Death Wish  (passive)",spell="Death Wish",          color={0.60,0.25,0.90} },
    { key="PROCS",      label="Procs  (DST/DS/MG)",   spell="Heroic Strike",       color={0.20,0.90,0.95} },
}
local PROT_ROWS = {
    { key="SHIELD_BLOCK", label="Shield Block  (crit/crush)",spell="Shield Block",       color={0.40,0.85,1.00} },
    { key="SHIELD_SLAM",  label="Shield Slam",              spell="Shield Slam",        color={1.00,0.55,0.10} },
    { key="REVENGE",      label="Revenge",                  spell="Revenge",            color={0.90,0.28,0.28} },
    { key="DEMO_SHOUT",   label="Demo Shout",               spell="Demoralizing Shout", color={0.65,0.40,1.00} },
    { key="THUNDER_CLAP", label="Thunder Clap",             spell="Thunder Clap",       color={0.38,0.84,1.00} },
    { key="DEVASTATE",    label="Devastate  (filler)",      spell="Devastate",          color={0.65,0.65,0.70} },
    { key="HS",           label="+ Heroic Strike  (dump)",  spell="Heroic Strike",      color={1.00,0.82,0.22} },
}

-- Expose row definitions for the admin panel (after all ROWS tables)
W.specRows = { FURY = FURY_ROWS, ARMS = ARMS_ROWS, PROT = PROT_ROWS }

-- ─── Combat state ────────────────────────────────────────────
local playerRage         = 0
local playerHP           = 1.0
local targetHP           = 1.0

local sunderStacks       = 0
local sunderExpiry       = 0
local exposeArmor        = false
local exposeExpiry       = 0
local demoShoutExpiry    = 0
local thunderExpiry      = 0
local dwishExpiry        = 0

local lastSwingTime      = 0
local swingDuration      = 2.0
local overpowerExpiry    = 0

local dstExpiry          = 0
local dragonstrikeExpiry = 0
local mongooseExpiry     = 0

-- ─── Frame references ────────────────────────────────────────
local furyContainer  = nil
local armsContainer  = nil
local protContainer  = nil
local furyRowFrames  = {}
local armsRowFrames  = {}
local protRowFrames  = {}

-- ─── Module API ──────────────────────────────────────────────
function W:GetBodyHeight(ROW_H)
    local n = math.max(#FURY_ROWS, math.max(#ARMS_ROWS, #PROT_ROWS))
    return n * (ROW_H + 1)
end

function W:GetHeaderText()
    return SR.Col("cc8844","WARRIOR") .. " " .. SR.Col("888888","ROTATION")
end

function W:Build(body)
    local FW   = SR.FRAME_W
    local RH   = SR.ROW_H

    local furyH  = #FURY_ROWS * (RH + 1)
    local armsH  = #ARMS_ROWS * (RH + 1)
    local protH  = #PROT_ROWS * (RH + 1)

    -- Fury container
    furyContainer = CreateFrame("Frame", nil, body)
    furyContainer:SetSize(FW, furyH)
    furyContainer:SetPoint("TOPLEFT", body, "TOPLEFT", 0, 0)
    furyContainer:Hide()
    furyRowFrames = {}
    for i, rd in ipairs(FURY_ROWS) do
        rd._idx = i
        furyRowFrames[i] = SR.BuildRow(furyContainer, rd, i)
    end

    -- Arms container
    armsContainer = CreateFrame("Frame", nil, body)
    armsContainer:SetSize(FW, armsH)
    armsContainer:SetPoint("TOPLEFT", body, "TOPLEFT", 0, 0)
    armsContainer:Hide()
    armsRowFrames = {}
    for i, rd in ipairs(ARMS_ROWS) do
        rd._idx = i
        armsRowFrames[i] = SR.BuildRow(armsContainer, rd, i)
    end

    -- Prot container
    protContainer = CreateFrame("Frame", nil, body)
    protContainer:SetSize(FW, protH)
    protContainer:SetPoint("TOPLEFT", body, "TOPLEFT", 0, 0)
    protContainer:Hide()
    protRowFrames = {}
    for i, rd in ipairs(PROT_ROWS) do
        rd._idx = i
        protRowFrames[i] = SR.BuildRow(protContainer, rd, i)
    end

    W.specRowFrames = { FURY = furyRowFrames, ARMS = armsRowFrames, PROT = protRowFrames }
end

-- ─── Sunder row visibility ───────────────────────────────────
function W:RefreshSunderRows()
    local show = SR.db and SR.db.classes.WARRIOR and
                 SR.db.classes.WARRIOR.showSunder ~= false
    local function relayout(rowFrames)
        local RH  = SR.ROW_H
        local Col = SR.Col
        local vis = 0
        for _, row in ipairs(rowFrames) do
            local visible = (row.rowDef.key ~= "SUNDER") or show
            row:SetShown(visible)
            if visible then
                vis = vis + 1
                row:ClearAllPoints()
                row:SetPoint("TOPLEFT", row:GetParent(), "TOPLEFT", 0, -(vis-1)*(RH+1))
                row.bg:SetColorTexture(0, 0, 0, vis % 2 == 0 and 0.18 or 0.05)
                row.num:SetText(Col("444455", tostring(vis)))
            end
        end
    end
    relayout(furyRowFrames)
    relayout(armsRowFrames)
end

-- ─── Spec detection ──────────────────────────────────────────
local function DetectSpec(db)
    if db and db.classes.WARRIOR and db.classes.WARRIOR.specOverride then
        return db.classes.WARRIOR.specOverride
    end
    -- GetSpellInfo checks the game DB, not the player's spellbook — unreliable.
    -- Use talent point counts instead: highest tree wins.
    -- TBC tab order: 1=Arms, 2=Fury, 3=Protection
    return SR.DetectSpecByTalents({
        { spec="ARMS", tab=1 },
        { spec="FURY", tab=2 },
        { spec="PROT", tab=3 },
    }, "FURY")
end

-- ─── Debuff / buff scanners ──────────────────────────────────
local function ScanTargetDebuffs()
    sunderStacks    = 0; sunderExpiry    = 0
    exposeArmor     = false; exposeExpiry = 0
    demoShoutExpiry = 0; thunderExpiry   = 0
    if not UnitExists("target") then return end
    local i = 1
    while true do
        local name, _, count, _, _, expiry = UnitDebuff("target", i)
        if not name then break end
        if name == "Sunder Armor"        then sunderStacks = count or 1; sunderExpiry    = expiry or 0 end
        if name == "Expose Armor"        then exposeArmor  = true;       exposeExpiry    = expiry or 0 end
        if name == "Demoralizing Shout"  then demoShoutExpiry = expiry or 0 end
        if name == "Thunder Clap"        then thunderExpiry   = expiry or 0 end
        i = i + 1
    end
end

local function ScanPlayerBuffs()
    dwishExpiry = 0; dstExpiry = 0; dragonstrikeExpiry = 0; mongooseExpiry = 0
    local i = 1
    while true do
        local name, _, _, _, _, expiry = UnitBuff("player", i)
        if not name then break end
        if name == "Death Wish"   then dwishExpiry        = expiry or 0 end
        if name == "Haste"        then dstExpiry          = expiry or 0 end
        if name == "Dragonstrike" then dragonstrikeExpiry = expiry or 0 end
        if name == "Mongoose"     then mongooseExpiry     = expiry or 0 end
        i = i + 1
    end
end

function W:ScanAll()
    ScanTargetDebuffs()
    ScanPlayerBuffs()
end

-- ─── Row update helpers ──────────────────────────────────────
local Col     = function(...) return SR.Col(...) end
local Fmt     = function(...) return SR.Fmt(...) end
local SpellCD = function(...) return SR.SpellCD(...) end

local function UpdateFury(db, now)
    local rage    = playerRage
    local tHP     = targetHP
    local btCD    = SpellCD("Bloodthirst")
    local wwCD    = SpellCD("Whirlwind")
    local dwCD    = SpellCD("Death Wish")
    local dwL     = dwishExpiry > 0 and math.max(0, dwishExpiry - now) or 0
    local sunL    = sunderExpiry > 0 and math.max(0, sunderExpiry - now) or 0
    local exPhase = tHP < 0.20
    local opReady = IsUsableSpell and IsUsableSpell("Overpower")
    local GCD     = 1.5
    local btSoon  = btCD < GCD
    local wwSoon  = wwCD < GCD
    local dstL    = dstExpiry > 0          and math.max(0, dstExpiry - now)          or 0
    local dsL     = dragonstrikeExpiry > 0 and math.max(0, dragonstrikeExpiry - now) or 0
    local mgL     = mongooseExpiry > 0     and math.max(0, mongooseExpiry - now)     or 0
    local anyProc = dstL > 0 or dsL > 0 or mgL > 0

    local showSunder = db.classes.WARRIOR and db.classes.WARRIOR.showSunder ~= false

    local best
    if showSunder and sunderStacks < 5 and not exposeArmor and not btSoon and not wwSoon then
        best = "SUNDER"
    elseif btCD <= 0 then
        best = "BT"
    elseif wwCD <= 0 then
        best = "WW"
    elseif exPhase and rage >= 10 and not btSoon and not wwSoon then
        best = "EXECUTE"
    elseif opReady and not btSoon and not wwSoon then
        best = "OVERPOWER"
    elseif btCD <= wwCD then
        best = "BT"
    else
        best = "WW"
    end

    local hsThresh = anyProc and 60 or 70
    local hsDump   = rage >= hsThresh and btCD > 0 and wwCD > 0

    for _, row in ipairs(furyRowFrames) do
        local k      = row.rowDef.key
        local active = (k == best)
                    or (k == "HS"    and hsDump)
                    or (k == "PROCS" and anyProc)
        local s = ""

        if k == "SUNDER" then
            if exposeArmor then
                local eaL = exposeExpiry > 0 and math.max(0, exposeExpiry - now) or 0
                s = Col("44aa44","EA up  ") .. Col("888888", eaL > 0 and Fmt(eaL) or "")
            elseif sunderStacks >= 5 then
                s = sunL > 0 and (Col("44aa44","5/5  ") .. Col("888888",Fmt(sunL))) or Col("ff6622","5/5 REFRESH")
            elseif sunderStacks > 0 then
                s = Col("ffcc44", sunderStacks .. "/5  ") .. Col("888888", Fmt(sunL))
            else
                s = Col("ff4444","APPLY NOW")
            end
        elseif k == "BT" then
            if btCD <= 0 then
                s = Col("44ff44","CAST NOW  ") .. Col("aaaaaa", rage .. "R")
            elseif btSoon then
                s = Col("ffdd22","SOON  ") .. Col("ff8844", Fmt(btCD))
            else
                local seq = wwCD > 0 and ("  >> WW " .. Fmt(wwCD)) or "  >> WW READY"
                s = Col("ff8844", Fmt(btCD)) .. Col("555566", seq)
            end
        elseif k == "WW" then
            if wwCD <= 0 then
                s = Col("44ff44","CAST NOW  ") .. Col("aaaaaa", rage .. "R")
            elseif wwSoon then
                s = Col("ffdd22","SOON  ") .. Col("ff8844", Fmt(wwCD))
            else
                local seq = btCD > 0 and ("  >> BT " .. Fmt(btCD)) or "  >> BT READY"
                s = Col("ff8844", Fmt(wwCD)) .. Col("555566", seq)
            end
        elseif k == "EXECUTE" then
            if exPhase then
                if rage >= 10 and not btSoon and not wwSoon then
                    s = Col("ff4444","FILLER  ") .. Col("ffcc44", string.format("%.0f%%", tHP*100))
                else
                    s = Col("888888","hold BT/WW  ") .. Col("ffcc44", string.format("%.0f%%", tHP*100))
                end
            else
                s = Col("555566", string.format("%.0f%%", tHP*100) .. "  not yet")
            end
        elseif k == "OVERPOWER" then
            s = opReady and (not btSoon and not wwSoon
                and Col("aaffaa","PROCCED  ") .. Col("888888","Battle Stance")
                or  Col("ff8844","PROCCED  ") .. Col("555566","hold BT/WW first"))
                or Col("555566","no proc")
        elseif k == "HS" then
            if hsDump then
                s = Col("ffee55","QUEUE  ") .. Col("aaaaaa", rage .. "R excess")
            elseif rage >= 50 then
                s = Col("888844", rage .. "R  watch BT/WW")
            else
                s = Col("555566", rage .. "R  save it")
            end
        elseif k == "DEATH_WISH" then
            if dwL > 0 then
                s = Col("cc44ff","ACTIVE  ") .. Col("aaaaaa", Fmt(dwL))
            elseif dwCD <= 0 then
                s = Col("aa44ff","READY  ") .. Col("888888","BL or exec phase")
            else
                s = Col("555566","CD  ") .. Col("888888", Fmt(dwCD))
            end
        elseif k == "PROCS" then
            if anyProc then
                local parts = {}
                if dstL > 0 then parts[#parts+1] = Col("22ddff","DST " .. Fmt(dstL)) end
                if dsL  > 0 then parts[#parts+1] = Col("ff9944","DS "  .. Fmt(dsL))  end
                if mgL  > 0 then parts[#parts+1] = Col("44ff88","MG "  .. Fmt(mgL))  end
                s = table.concat(parts, Col("555566"," | "))
                if rage >= hsThresh - 10 then s = s .. Col("ffee55","  HS!") end
            else
                s = Col("333344","—")
            end
        end
        SR.SetRowState(row, active, s)
    end

    local spCol = exPhase and "ff4444" or "aaaaaa"
    SR.SetModeLabel(
        Col("cc3333","FURY") .. "  " ..
        Col("aaaaaa", rage .. "R ") ..
        Col(spCol, string.format("%.0f%%", tHP*100)))

    local nxt   = btCD <= wwCD and "BT" or "WW"
    local nxtCD = btCD <= wwCD and btCD or wwCD
    local after = btCD <= wwCD
        and (wwCD > 0 and (" >> WW " .. Fmt(wwCD)) or " >> WW READY")
        or  (btCD > 0 and (" >> BT " .. Fmt(btCD)) or " >> BT READY")
    local spotSt
    if best == "BT" or best == "WW" then
        spotSt = nxtCD <= 0 and ("CAST" .. after) or (">> " .. nxt .. " " .. Fmt(nxtCD) .. after)
    elseif best == "EXECUTE" then
        spotSt = string.format("%.0f%%", tHP*100) .. "  " .. rage .. "R"
    else
        spotSt = rage .. "R"
    end
    SR.UpdateSpotlight(FURY_ROWS, best, spotSt)
end

local function UpdateArms(db, now)
    local rage    = playerRage
    local tHP     = targetHP
    local msCD    = SpellCD("Mortal Strike")
    local wwCD    = SpellCD("Whirlwind")
    local dwCD    = SpellCD("Death Wish")
    local dwL     = dwishExpiry > 0 and math.max(0, dwishExpiry - now) or 0
    local sunL    = sunderExpiry > 0 and math.max(0, sunderExpiry - now) or 0
    local exPhase = tHP < 0.20
    local dstL    = dstExpiry > 0          and math.max(0, dstExpiry - now)          or 0
    local dsL     = dragonstrikeExpiry > 0 and math.max(0, dragonstrikeExpiry - now) or 0
    local mgL     = mongooseExpiry > 0     and math.max(0, mongooseExpiry - now)     or 0
    local anyProc = dstL > 0 or dsL > 0 or mgL > 0

    local timeSinceSwing = now - lastSwingTime
    local nextSwingIn    = math.max(0, (lastSwingTime + swingDuration) - now)
    local slamWindow     = swingDuration > 0 and timeSinceSwing >= 0 and timeSinceSwing <= 0.5
    local GCD    = 1.5
    local msSoon = msCD < GCD
    local wwSoon = wwCD < GCD

    local showSunder = db.classes.WARRIOR and db.classes.WARRIOR.showSunder ~= false

    local best
    if showSunder and sunderStacks < 5 and not exposeArmor and not slamWindow and not msSoon and not wwSoon then
        best = "SUNDER"
    elseif slamWindow and rage >= 15 then
        best = "SLAM"
    elseif msCD <= 0 then
        best = "MS"
    elseif wwCD <= 0 then
        best = "WW"
    elseif exPhase and rage >= 10 and not msSoon and not wwSoon then
        best = "EXECUTE"
    elseif msCD <= wwCD then
        best = "MS"
    else
        best = "WW"
    end

    local hsThresh = anyProc and 60 or 70
    local hsDump   = rage >= hsThresh and not slamWindow and not msSoon and not wwSoon

    for _, row in ipairs(armsRowFrames) do
        local k      = row.rowDef.key
        local active = (k == best)
                    or (k == "HS"    and hsDump)
                    or (k == "PROCS" and anyProc)
        local s = ""

        if k == "SUNDER" then
            if exposeArmor then
                local eaL = exposeExpiry > 0 and math.max(0, exposeExpiry - now) or 0
                s = Col("44aa44","EA up  ") .. Col("888888", eaL > 0 and Fmt(eaL) or "")
            elseif sunderStacks >= 5 then
                s = Col("44aa44","5/5  ") .. Col("888888", Fmt(sunL))
            elseif sunderStacks > 0 then
                s = Col("ffcc44", sunderStacks .. "/5  ") .. Col("888888", Fmt(sunL))
            else
                s = Col("ff4444","APPLY NOW")
            end
        elseif k == "SLAM" then
            if slamWindow then
                local na  = msCD <= 0 and "MS" or (wwCD <= 0 and "WW" or (msCD <= wwCD and "MS" or "WW"))
                local ncd = msCD <= 0 and 0   or (wwCD <= 0 and 0   or math.min(msCD, wwCD))
                local seq = ncd <= 0 and (" >> " .. na .. " READY") or (" >> " .. na .. " " .. Fmt(ncd))
                s = Col("ffee00","CAST NOW!") .. Col("888888", seq)
            elseif timeSinceSwing > 0.5 and swingDuration > 0 then
                local na  = msCD <= wwCD and "MS" or "WW"
                s = Col("555566","swing ") .. Col("ff8844", string.format("%.1f",nextSwingIn) .. "s") ..
                    Col("555566"," >> " .. na .. (math.min(msCD,wwCD) <= 0 and " READY" or " " .. Fmt(math.min(msCD,wwCD))))
            else
                s = Col("555566","swing in  ") .. Col("888888", string.format("%.1f",nextSwingIn) .. "s")
            end
        elseif k == "MS" then
            if msCD <= 0 then
                s = Col("44ff44","CAST NOW  ") .. Col("aaaaaa", rage .. "R")
            elseif msSoon then
                s = Col("ffdd22","SOON  ") .. Col("ff8844", Fmt(msCD))
            else
                local seq = wwCD > 0 and ("  >> WW " .. Fmt(wwCD)) or "  >> WW READY"
                s = Col("ff8844", Fmt(msCD)) .. Col("555566", seq)
            end
        elseif k == "WW" then
            if wwCD <= 0 then
                s = Col("44ff44","CAST NOW  ") .. Col("aaaaaa", rage .. "R")
            elseif wwSoon then
                s = Col("ffdd22","SOON  ") .. Col("ff8844", Fmt(wwCD))
            else
                local seq = msCD > 0 and ("  >> MS " .. Fmt(msCD)) or "  >> MS READY"
                s = Col("ff8844", Fmt(wwCD)) .. Col("555566", seq)
            end
        elseif k == "EXECUTE" then
            if exPhase then
                s = (not msSoon and not wwSoon and rage >= 10)
                    and (Col("ff4444","FILLER  ") .. Col("ffcc44", string.format("%.0f%%", tHP*100)))
                    or  (Col("888888","hold MS/WW  ")  .. Col("ffcc44", string.format("%.0f%%", tHP*100)))
            else
                s = Col("555566", string.format("%.0f%%", tHP*100) .. "  not yet")
            end
        elseif k == "HS" then
            if hsDump then
                s = Col("ffee55","QUEUE  ") .. Col("aaaaaa", rage .. "R excess")
            elseif rage >= 50 then
                s = Col("888844", rage .. "R  watch MS/WW")
            else
                s = Col("555566", rage .. "R  save it")
            end
        elseif k == "DEATH_WISH" then
            if dwL > 0 then
                s = Col("cc44ff","ACTIVE  ") .. Col("aaaaaa", Fmt(dwL))
            elseif dwCD <= 0 then
                s = Col("aa44ff","READY  ") .. Col("888888","BL or exec phase")
            else
                s = Col("555566","CD  ") .. Col("888888", Fmt(dwCD))
            end
        elseif k == "PROCS" then
            if anyProc then
                local parts = {}
                if dstL > 0 then parts[#parts+1] = Col("22ddff","DST " .. Fmt(dstL)) end
                if dsL  > 0 then parts[#parts+1] = Col("ff9944","DS "  .. Fmt(dsL))  end
                if mgL  > 0 then parts[#parts+1] = Col("44ff88","MG "  .. Fmt(mgL))  end
                s = table.concat(parts, Col("555566"," | "))
                if rage >= hsThresh - 10 then s = s .. Col("ffee55","  HS!") end
            else
                s = Col("333344","—")
            end
        end
        SR.SetRowState(row, active, s)
    end

    local swCol = slamWindow and "ffee00" or "888888"
    SR.SetModeLabel(
        Col("ddcc22","ARMS") .. "  " ..
        Col("aaaaaa", rage .. "R ") ..
        Col(swCol, string.format("%.1fs",nextSwingIn) .. "sw"))

    local nxt   = msCD <= wwCD and "MS" or "WW"
    local nxtCD = msCD <= wwCD and msCD or wwCD
    local after = msCD <= wwCD
        and (wwCD > 0 and (" >> WW " .. Fmt(wwCD)) or " >> WW READY")
        or  (msCD > 0 and (" >> MS " .. Fmt(msCD)) or " >> MS READY")
    local spotSt
    if slamWindow then
        spotSt = "CAST NOW! +" .. string.format("%.2f", timeSinceSwing) .. "s" .. after
    elseif best == "MS" or best == "WW" then
        spotSt = nxtCD <= 0 and ("CAST" .. after) or (">> " .. nxt .. " " .. Fmt(nxtCD) .. after)
    elseif best == "EXECUTE" then
        spotSt = string.format("%.0f%%", tHP*100) .. "  " .. rage .. "R"
    else
        spotSt = rage .. "R"
    end
    SR.UpdateSpotlight(ARMS_ROWS, best, spotSt)
end

local function UpdateProt(db, now)
    local rage         = playerRage
    local hp           = playerHP
    local ssCD         = SpellCD("Shield Slam")
    local revengeReady = SpellCD("Revenge") <= 0
    local sbCD         = SpellCD("Shield Block")
    local demoL        = demoShoutExpiry > 0 and math.max(0, demoShoutExpiry - now) or 0
    local tcL          = thunderExpiry   > 0 and math.max(0, thunderExpiry   - now) or 0
    local ssUsable     = IsUsableSpell and IsUsableSpell("Shield Slam")
    local GCD          = 1.5
    local sunL         = sunderExpiry > 0 and math.max(0, sunderExpiry - now) or 0

    local best
    if ssUsable and ssCD <= 0 and rage >= 20 then
        best = "SHIELD_SLAM"
    elseif revengeReady and rage >= 5 then
        best = "REVENGE"
    elseif (demoL == 0 or demoL < 3) and rage >= 10 then
        best = "DEMO_SHOUT"
    elseif (tcL == 0 or tcL < 3) and rage >= 20 then
        best = "THUNDER_CLAP"
    elseif ssCD <= GCD and rage >= 20 then
        best = "SHIELD_SLAM"
    else
        best = "DEVASTATE"
    end

    local sbReady = sbCD <= 0
    local hsDump  = rage >= 75 and ssCD > 0

    for _, row in ipairs(protRowFrames) do
        local k      = row.rowDef.key
        local active = (k == best)
                    or (k == "SHIELD_BLOCK" and sbReady)
                    or (k == "HS" and hsDump)
        local s = ""

        if k == "SHIELD_BLOCK" then
            if sbCD <= 0 then
                s = Col("44ddff","PRESS NOW  ") .. Col("888888","remove crush")
            elseif sbCD < 3 then
                s = Col("ffdd22","SOON  ") .. Col("ff8844", Fmt(sbCD))
            else
                s = Col("ff8844", Fmt(sbCD)) .. Col("888888","  refreshing")
            end
        elseif k == "SHIELD_SLAM" then
            if not ssUsable then
                s = Col("555566","no shield  ") .. Col("444455","devastate mode")
            elseif ssCD <= 0 then
                s = Col("44ff44","CAST NOW  ") .. Col("aaaaaa", rage .. "R")
            elseif ssCD < GCD then
                s = Col("ffdd22","SOON  ") .. Col("ff8844", Fmt(ssCD))
            else
                s = Col("ff8844", Fmt(ssCD)) .. Col("888888","  wait")
            end
        elseif k == "REVENGE" then
            if revengeReady then
                s = Col("44ff44","PROCCED  ") .. Col("aaaaaa", rage .. "R")
            else
                local rCD = SpellCD("Revenge")
                s = rCD > 0
                    and Col("888888","wait dodge/block  ") .. Col("555566", Fmt(rCD))
                    or  Col("555566","no proc yet")
            end
        elseif k == "DEMO_SHOUT" then
            if demoL == 0 then
                s = Col("ff4444","MISSING!  ") .. Col("888888","~18% dmg reduc")
            elseif demoL < 3 then
                s = Col("ff6622","REFRESH!  ") .. Col("ffcc44", Fmt(demoL))
            elseif demoL < 8 then
                s = Col("ffcc44", Fmt(demoL) .. "  ") .. Col("888888","refresh soon")
            else
                s = Col("44aa44", Fmt(demoL))
            end
        elseif k == "THUNDER_CLAP" then
            if tcL == 0 then
                s = Col("ff4444","MISSING!  ") .. Col("888888","~17% dmg reduc")
            elseif tcL < 3 then
                s = Col("ff6622","REFRESH!  ") .. Col("ffcc44", Fmt(tcL))
            elseif tcL < 8 then
                s = Col("ffcc44", Fmt(tcL) .. "  ") .. Col("888888","refresh soon")
            else
                s = Col("44aa44", Fmt(tcL))
            end
        elseif k == "DEVASTATE" then
            if sunderStacks >= 5 then
                s = Col("44ff44","filler  ") .. Col("44aa44","5/5 sun")
            elseif sunderStacks > 0 then
                s = Col("ffcc44","filler  ") .. Col("ffaa44", sunderStacks .. "/5 sun")
            else
                s = Col("ff8844","build sunder  ") .. Col("aaaaaa","0/5")
            end
        elseif k == "HS" then
            if hsDump then
                s = Col("ffee55","QUEUE  ") .. Col("aaaaaa", rage .. "R excess")
            elseif rage >= 55 then
                s = Col("888844", rage .. "R  watch SS")
            else
                s = Col("555566", rage .. "R  save for loop")
            end
        end
        SR.SetRowState(row, active, s)
    end

    local hpCol = hp < 0.30 and "ff4444" or hp < 0.60 and "ffcc44" or "44ff44"
    SR.SetModeLabel(
        Col("4488ff","PROT") .. "  " ..
        Col("aaaaaa", rage .. "R ") ..
        Col(hpCol, string.format("%.0f%%", hp*100)))

    local spotSt
    if best == "SHIELD_SLAM" then
        spotSt = ssCD <= 0 and ("CAST  " .. rage .. "R") or ("in " .. Fmt(ssCD) .. "  " .. rage .. "R")
    elseif best == "REVENGE"    then spotSt = "PROCCED  " .. rage .. "R"
    elseif best == "DEMO_SHOUT" then spotSt = demoL == 0 and "MISSING" or Fmt(demoL) .. " left"
    elseif best == "THUNDER_CLAP" then spotSt = tcL == 0 and "MISSING" or Fmt(tcL) .. " left"
    else                             spotSt = rage .. "R" end
    SR.UpdateSpotlight(PROT_ROWS, best, spotSt)
end

-- ─── Main update ─────────────────────────────────────────────
function W:Update(now, db)
    local classDb    = db.classes.WARRIOR or {}
    local specEnabled = classDb.specs or {}

    playerRage = UnitPower("player", 1) or 0
    playerHP   = UnitHealth("player") / math.max(1, UnitHealthMax("player"))
    if UnitExists("target") then
        targetHP = UnitHealth("target") / math.max(1, UnitHealthMax("target"))
    else
        targetHP = 1.0
    end

    local spec = DetectSpec(db)
    W.currentSpec = spec

    -- Enforce per-spec toggle
    if specEnabled[spec] == false then
        if furyContainer  then furyContainer:Hide()  end
        if armsContainer  then armsContainer:Hide()  end
        if protContainer  then protContainer:Hide()  end
        SR.SetModeLabel(Col("555566", spec .. " disabled"))
        SR.UpdateSpotlight(nil, nil, nil)
        return
    end

    if spec == "FURY" then
        if furyContainer  then furyContainer:Show()  end
        if armsContainer  then armsContainer:Hide()  end
        if protContainer  then protContainer:Hide()  end
        UpdateFury(db, now)
    elseif spec == "ARMS" then
        if furyContainer  then furyContainer:Hide()  end
        if armsContainer  then armsContainer:Show()  end
        if protContainer  then protContainer:Hide()  end
        UpdateArms(db, now)
    else
        if furyContainer  then furyContainer:Hide()  end
        if armsContainer  then armsContainer:Hide()  end
        if protContainer  then protContainer:Show()  end
        UpdateProt(db, now)
    end
end

-- ─── Events ──────────────────────────────────────────────────
function W:OnEvent(event, arg1, arg2, arg3)
    if event == "PLAYER_TARGET_CHANGED" then
        ScanTargetDebuffs()
    elseif event == "UNIT_AURA" then
        if arg1 == "player" then ScanPlayerBuffs()    end
        if arg1 == "target"  then ScanTargetDebuffs() end
    elseif event == "COMBAT_LOG_EVENT_UNFILTERED" then
        -- Track main-hand swing timer for Arms Slam window
        local timestamp, subtype, _, sourceGUID = CombatLogGetCurrentEventInfo()
        if (subtype == "SWING_DAMAGE" or subtype == "SWING_MISSED") and
           sourceGUID == UnitGUID("player") then
            local now = GetTime()
            if lastSwingTime > 0 then
                local elapsed = now - lastSwingTime
                -- Sanity: only update if reasonable swing speed (0.5–4s)
                if elapsed >= 0.5 and elapsed <= 4.0 then
                    swingDuration = elapsed
                end
            end
            lastSwingTime = now
        end
    end
end

function W:RegisterEvents()
    SR.RegisterEvent("COMBAT_LOG_EVENT_UNFILTERED")
end

-- ─── Register ────────────────────────────────────────────────
SR.RegisterModule("WARRIOR", W)
