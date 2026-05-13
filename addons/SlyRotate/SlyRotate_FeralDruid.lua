-- ============================================================
-- SlyRotate — Feral Druid Module
-- Cat DPS (powershift cycle) and Bear Tank priority display.
-- Port of SlySuite_FeralHelper rotation logic.
-- ============================================================

local D = {}

D.classKey   = "DRUID"
D.classLabel = "Druid (Feral)"
D.headerIcon   = "Interface\\Icons\\Ability_Druid_CatForm"
D.headerSpell  = "Claw"
D.headerSpells = { CAT="Shred", BEAR="Mangle (Bear)" }
D.specKeys   = { "CAT", "BEAR" }
D.specLabels = { CAT="Cat DPS", BEAR="Bear Tank" }

-- ─── Spell name constants ──────────────────────────────────
local SP_RIP        = "Rip"
local SP_MANGLE_C   = "Mangle (Cat)"
local SP_MANGLE_B   = "Mangle (Bear)"
local SP_LACERATE   = "Lacerate"
local SP_DEMO_ROAR  = "Demoralizing Roar"
local SP_TF         = "Tiger's Fury"
local SP_BASH       = "Bash"
local SP_FRENZIED   = "Frenzied Regeneration"

-- ─── Row definitions ─────────────────────────────────────────
local CAT_ROWS = {
    { key="RIP",        label="Rip  (≥4CP ≥30E)",   spell="Rip",                color={1.00,0.28,0.28} },
    { key="MANGLE_CAT", label="Mangle  (≥40E)",     spell="Mangle (Cat)",       color={1.00,0.68,0.18} },
    { key="SHRED",      label="Shred  (≥42E)",      spell="Shred",              color={0.38,0.84,1.00} },
    { key="POWERSHIFT", label="Powershift",         icon="Interface\\Icons\\Ability_Druid_CatForm",        color={0.45,1.00,0.45} },
    { key="WAIT",       label="Wait  (tick)",       icon="Interface\\Icons\\Spell_Magic_WardingCurse",     color={0.42,0.42,0.48} },
    { key="FB",         label="+ FB swap (dying)",  spell="Ferocious Bite",     color={1.00,0.55,0.10} },
    { key="TF",         label="Tiger's Fury  (CD)", spell="Tiger's Fury",       color={1.00,0.65,0.00} },
}
local BEAR_ROWS = {
    { key="MANGLE_BEAR", label="Mangle (Bear)",     spell="Mangle (Bear)",      color={1.00,0.55,0.10} },
    { key="LACERATE",    label="Lacerate  (spam)",  spell="Lacerate",           color={0.90,0.28,0.28} },
    { key="MAUL",        label="+ Maul  (off-GCD)", spell="Maul",               color={1.00,0.82,0.22} },
    { key="DEMO_ROAR",   label="Demo Roar  (opt)",  spell="Demoralizing Roar",  color={0.65,0.40,1.00} },
    { key="BASH",        label="Bash",              spell="Bash",               color={0.40,0.85,1.00} },
    { key="FRENZIED",    label="Frenzied  (skip)",  spell="Frenzied Regeneration", color={0.45,0.45,0.50} },
}

D.specRows = { CAT = CAT_ROWS, BEAR = BEAR_ROWS }

-- ─── Combat state ────────────────────────────────────────────
local catEnergy       = 0
local catCPs          = 0
local bearRage        = 0
local playerHP        = 1.0

local ripExpiry       = 0
local mangleCatExpiry = 0
local lacerateExpiry  = 0
local lacerateStacks  = 0
local demoRoarExpiry  = 0
local tfExpiry        = 0

-- ─── Frame references ────────────────────────────────────────
local catContainer  = nil
local bearContainer = nil
local catRowFrames  = {}
local bearRowFrames = {}

-- ─── Module API ──────────────────────────────────────────────
function D:GetBodyHeight(ROW_H)
    return math.max(#CAT_ROWS, #BEAR_ROWS) * (ROW_H + 1)
end

function D:GetHeaderText()
    return SR.Col("88ff88","FERAL") .. " " .. SR.Col("888888","ROTATION")
end

function D:Build(body)
    local FW  = SR.FRAME_W
    local RH  = SR.ROW_H
    local catH  = #CAT_ROWS  * (RH + 1)
    local bearH = #BEAR_ROWS * (RH + 1)

    catContainer = CreateFrame("Frame", nil, body)
    catContainer:SetSize(FW, catH)
    catContainer:SetPoint("TOPLEFT", body, "TOPLEFT", 0, 0)
    catRowFrames = {}
    for i, rd in ipairs(CAT_ROWS) do
        rd._idx = i
        catRowFrames[i] = SR.BuildRow(catContainer, rd, i)
    end

    bearContainer = CreateFrame("Frame", nil, body)
    bearContainer:SetSize(FW, bearH)
    bearContainer:SetPoint("TOPLEFT", body, "TOPLEFT", 0, 0)
    bearContainer:Hide()
    bearRowFrames = {}
    for i, rd in ipairs(BEAR_ROWS) do
        rd._idx = i
        bearRowFrames[i] = SR.BuildRow(bearContainer, rd, i)
    end

    D.specRowFrames = { CAT = catRowFrames, BEAR = bearRowFrames }
end

-- ─── Helpers ─────────────────────────────────────────────────
local Col     = function(...) return SR.Col(...) end
local Fmt     = function(...) return SR.Fmt(...) end
local SpellCD = function(...) return SR.SpellCD(...) end

local function TicksNeeded(need, have)
    local deficit = math.max(0, need - have)
    if deficit == 0 then return 0 end
    return math.ceil(deficit / 20)
end

-- ─── Form detection ──────────────────────────────────────────
local function GetDruidForm()
    local n = GetNumShapeshiftForms and GetNumShapeshiftForms() or 0
    for i = 1, n do
        local _, active, _, spellID = GetShapeshiftFormInfo(i)
        if active and spellID then
            local name = GetSpellInfo(spellID)
            if name then
                if name:find("Cat Form",  1, true) then return "CAT"  end
                if name:find("Bear Form", 1, true)
                or name:find("Dire Bear", 1, true) then return "BEAR" end
            end
        end
    end
    return "NONE"
end

-- ─── Debuff / buff scanners ──────────────────────────────────
local function ScanTargetDebuffs()
    ripExpiry = 0; mangleCatExpiry = 0
    lacerateExpiry = 0; lacerateStacks = 0; demoRoarExpiry = 0
    if not UnitExists("target") then return end
    local i = 1
    while true do
        local name, _, count, _, _, expiry = UnitDebuff("target", i, "PLAYER")
        if not name then break end
        if name == SP_RIP       then ripExpiry       = expiry or 0 end
        if name == SP_MANGLE_C  then mangleCatExpiry = expiry or 0 end
        if name == SP_LACERATE  then lacerateExpiry  = expiry or 0; lacerateStacks = count or 1 end
        if name == SP_DEMO_ROAR then demoRoarExpiry  = expiry or 0 end
        if name == "Mangle"     then mangleCatExpiry = expiry or 0 end -- bear mangle debuff
        i = i + 1
    end
end

local function ScanPlayerBuffs()
    tfExpiry = 0
    local i = 1
    while true do
        local name, _, _, _, _, expiry = UnitBuff("player", i)
        if not name then break end
        if name == SP_TF then tfExpiry = expiry or 0 end
        i = i + 1
    end
end

function D:ScanAll()
    ScanTargetDebuffs()
    ScanPlayerBuffs()
end

-- ─── Cat update ──────────────────────────────────────────────
local function UpdateCat(now)
    local energy = catEnergy
    local cps    = catCPs
    local ripL   = ripExpiry       > 0 and math.max(0, ripExpiry       - now) or 0
    local manL   = mangleCatExpiry > 0 and math.max(0, mangleCatExpiry - now) or 0
    local tfL    = tfExpiry        > 0 and math.max(0, tfExpiry        - now) or 0
    local tfCD   = SpellCD(SP_TF)
    local manCD  = SpellCD(SP_MANGLE_C)
    local tgtHP  = UnitExists("target") and
                   (UnitHealth("target") / math.max(1, UnitHealthMax("target"))) or 1.0

    local nextCost, nextName
    if cps >= 4 and ripL == 0 then
        nextCost = 30; nextName = "Rip"
    elseif manL == 0 and manCD <= 0 then
        nextCost = 40; nextName = "Mangle"
    else
        nextCost = 42; nextName = "Shred"
    end

    local best
    if cps >= 4 and energy >= 30 and ripL == 0 then
        best = "RIP"
    elseif manL == 0 and manCD <= 0 and energy >= 40 then
        best = "MANGLE_CAT"
    elseif energy >= 42 then
        best = "SHRED"
    elseif energy < (nextCost - 20) then
        best = "POWERSHIFT"
    else
        best = "WAIT"
    end

    local fbSwap = cps >= 4 and ripL > 0 and tgtHP < 0.20

    for _, row in ipairs(catRowFrames) do
        local k      = row.rowDef.key
        local active = (k == best) or (k == "FB" and fbSwap)
        local s      = ""

        if k == "RIP" then
            if ripL > 0 then
                s = Col("44ff44", Fmt(ripL))
            elseif cps >= 4 and energy >= 30 then
                s = Col("ff4444","CAST!") .. " " .. Col("ffdd88", cps .. "CP")
            elseif cps >= 4 then
                s = Col("ffdd88", cps .. "CP") .. " " .. Col("ff7744", energy .. "E")
            else
                s = Col("aaaaaa", cps .. "CP")
            end
        elseif k == "MANGLE_CAT" then
            if manL > 0 then
                s = Col("44ff44", Fmt(manL))
            elseif manCD > 0 then
                s = Col("ff8844", Fmt(manCD))
            else
                local col = energy >= 40 and "ff4444" or "ff7744"
                s = Col(col,"GONE") .. " " .. Col("888888", energy .. "E")
            end
        elseif k == "SHRED" then
            if energy >= 42 then
                s = Col("55ddff","CAST NOW  ") .. Col("888888", energy .. "E")
            else
                local deficit = 42 - energy
                local ticks   = TicksNeeded(42, energy)
                s = Col("555566", energy .. "E  ") ..
                    Col("888888", "+" .. deficit .. "E  " .. ticks .. "t")
            end
        elseif k == "POWERSHIFT" then
            local deficit = math.max(0, nextCost - energy)
            if best == "POWERSHIFT" then
                s = Col("aaffaa","SHIFT  ") .. Col("888888",">> " .. nextName .. " after")
            else
                local ticks = TicksNeeded(nextCost, energy)
                s = Col("667766", energy .. "E  -" .. deficit .. "  " .. ticks .. "t")
            end
        elseif k == "WAIT" then
            local deficit = math.max(0, nextCost - energy)
            local ticks   = TicksNeeded(nextCost, energy)
            s = Col("888888",">> ") .. Col("aaaacc", nextName) ..
                Col("555566","  +" .. deficit .. "E  ") ..
                Col("888888", ticks .. "t")
        elseif k == "FB" then
            if fbSwap then
                s = Col("ffaa44","SWAP!")
            else
                local hpStr = UnitExists("target") and string.format("%.0f%%", tgtHP*100) or "--"
                s = Col("555566", cps .. "CP " .. hpStr)
            end
        elseif k == "TF" then
            if tfL > 0 then
                s = Col("ffdd55", Fmt(tfL))
            elseif tfCD > 0 then
                s = Col("888888", Fmt(tfCD))
            else
                s = Col("44ff44","PULL")
            end
        end
        SR.SetRowState(row, active, s)
    end

    local cpCol = cps >= 4 and "ffee55" or "aaaaaa"
    SR.SetModeLabel(
        Col("aaaaaa", energy .. "E ") ..
        Col(cpCol, cps .. "CP"))

    local spotStatus = ""
    if best == "RIP" then
        spotStatus = cps .. "CP  " .. energy .. "E"
    elseif best == "MANGLE_CAT" or best == "SHRED" then
        spotStatus = energy .. "E"
    elseif best == "POWERSHIFT" then
        local deficit = math.max(0, nextCost - energy)
        spotStatus = "shift >> " .. nextName .. "  need +" .. deficit .. "E"
    elseif best == "WAIT" then
        local deficit = math.max(0, nextCost - energy)
        local ticks   = TicksNeeded(nextCost, energy)
        spotStatus = ">> " .. nextName .. "  +" .. deficit .. "E  " .. ticks .. "t"
    end
    SR.UpdateSpotlight(CAT_ROWS, best, spotStatus)
end

-- ─── Bear update ─────────────────────────────────────────────
local function UpdateBear(now)
    local rage   = bearRage
    local hp     = playerHP
    local manCD  = SpellCD(SP_MANGLE_B)
    local lacL   = lacerateExpiry > 0 and math.max(0, lacerateExpiry - now) or 0
    local demoL  = demoRoarExpiry > 0 and math.max(0, demoRoarExpiry - now) or 0
    local bashCD = SpellCD(SP_BASH)
    local frCD   = SpellCD(SP_FRENZIED)

    local best
    if manCD <= 0 and rage >= 15 then
        best = "MANGLE_BEAR"
    else
        best = "LACERATE"
    end

    local mangleWaitRage = manCD <= 0 and rage < 15
    local maulDump       = rage >= 60 and not mangleWaitRage

    for _, row in ipairs(bearRowFrames) do
        local k      = row.rowDef.key
        local active = (k == best)
                    or (k == "MANGLE_BEAR" and mangleWaitRage)
                    or (k == "MAUL"        and maulDump)
        local s = ""

        if k == "MANGLE_BEAR" then
            if manCD > 0 then
                s = Col("ff8844", Fmt(manCD)) .. Col("888888","  wait")
            elseif rage >= 15 then
                s = Col("44ff44","CAST NOW  ") .. Col("aaaaaa", rage .. "R")
            else
                s = Col("ffdd22","SAVE RAGE  ") .. Col("ffaa00", rage .. "/15R")
            end
        elseif k == "LACERATE" then
            if lacL == 0 then
                s = Col("ff4444","APPLY!  ") .. Col("aaaaaa", lacerateStacks .. "/5")
            elseif lacL < 2.5 then
                s = Col("ff6622","REFRESH!  ") .. Col("ffcc44", Fmt(lacL)) ..
                    Col("888888","  " .. lacerateStacks .. "/5")
            elseif lacerateStacks < 5 then
                s = Col("ffcc44", lacerateStacks .. "/5 ") ..
                    Col("aaaaaa","build  ") .. Col("888888", Fmt(lacL))
            else
                s = Col("44ff44","5/5  ") .. Col("aaaaaa", Fmt(lacL))
            end
        elseif k == "MAUL" then
            if mangleWaitRage then
                s = Col("ffdd22","HOLD  ") .. Col("888866", rage .. "R >> Mangle")
            elseif maulDump then
                s = Col("ffee55","QUEUE  ") .. Col("aaaaaa", rage .. "R excess")
            elseif rage >= 45 then
                s = Col("888844", rage .. "R  soon")
            else
                s = Col("555566", rage .. "R  not yet")
            end
        elseif k == "DEMO_ROAR" then
            if demoL == 0 then
                s = Col("888888","off  ") .. Col("555566","(optional)")
            elseif demoL < 3 then
                s = Col("ff8844","REFRESH  ") .. Col("ffcc44", Fmt(demoL))
            elseif demoL < 8 then
                s = Col("ffcc44", Fmt(demoL) .. "  ") .. Col("888888","refresh soon")
            else
                s = Col("44aa44", Fmt(demoL))
            end
        elseif k == "BASH" then
            if bashCD > 0 then
                s = Col("888888","CD  ") .. Col("ff8844", Fmt(bashCD))
            else
                s = Col("44ff44","READY  ") .. Col("888888","interrupt/stun")
            end
        elseif k == "FRENZIED" then
            local hpPct = string.format("%.0f%%", hp * 100)
            if frCD > 0 then
                s = Col("555566","CD  " .. Fmt(frCD))
            else
                s = Col("555566","READY  ") .. Col("444455", hpPct .. "  skip raids")
            end
        end
        SR.SetRowState(row, active, s)
    end

    local hpCol = hp < 0.30 and "ff4444" or hp < 0.60 and "ffcc44" or "44ff44"
    SR.SetModeLabel(
        Col("aaaaaa", rage .. "R ") ..
        Col(hpCol, string.format("%.0f%%", hp*100)))

    local bearStatus
    if best == "MANGLE_BEAR" then
        bearStatus = "on CD: " .. (manCD > 0 and Fmt(manCD) or "READY") .. "  " .. rage .. "R"
    else
        bearStatus = lacerateStacks .. "/5  " .. (lacL > 0 and Fmt(lacL) or "GONE") ..
                     "  " .. rage .. "R"
    end
    SR.UpdateSpotlight(BEAR_ROWS, best, bearStatus)
end

-- ─── Main update ─────────────────────────────────────────────
function D:Update(now, db)
    local classDb     = db.classes.DRUID or {}
    local specEnabled = classDb.specs or {}

    catEnergy = UnitPower("player", 3) or 0
    bearRage  = UnitPower("player", 1) or 0
    catCPs    = (GetComboPoints and GetComboPoints("player", "target"))
                or UnitPower("player", 4) or 0
    playerHP  = UnitHealth("player") / math.max(1, UnitHealthMax("player"))

    local form = GetDruidForm()
    D.currentSpec = (form == "CAT") and "CAT" or (form == "BEAR") and "BEAR" or nil

    -- Map form to a spec key for the toggle check
    local formSpec = (form == "CAT") and "CAT" or (form == "BEAR") and "BEAR" or nil

    if formSpec and specEnabled[formSpec] == false then
        if catContainer  then catContainer:Hide()  end
        if bearContainer then bearContainer:Hide() end
        SR.SetModeLabel(SR.Col("555566", formSpec .. " disabled"))
        SR.UpdateSpotlight(nil, nil, nil)
        return
    end

    if form == "CAT" then
        if catContainer  then catContainer:Show()  end
        if bearContainer then bearContainer:Hide() end
        UpdateCat(now)
    elseif form == "BEAR" then
        if catContainer  then catContainer:Hide()  end
        if bearContainer then bearContainer:Show() end
        UpdateBear(now)
    else
        if catContainer  then catContainer:Hide()  end
        if bearContainer then bearContainer:Hide() end
        SR.SetModeLabel(SR.Col("444455","NO FORM"))
        SR.UpdateSpotlight(nil, nil, nil)
    end
end

-- ─── Events ──────────────────────────────────────────────────
function D:OnEvent(event, arg1)
    if event == "PLAYER_TARGET_CHANGED" then
        ScanTargetDebuffs()
    elseif event == "UNIT_AURA" then
        if arg1 == "player" then ScanPlayerBuffs()    end
        if arg1 == "target"  then ScanTargetDebuffs() end
    elseif event == "UPDATE_SHAPESHIFT_FORM" then
        ScanTargetDebuffs()
        ScanPlayerBuffs()
    end
end

function D:RegisterEvents()
    SR.RegisterEvent("UPDATE_SHAPESHIFT_FORM")
end

-- ─── Register ────────────────────────────────────────────────
SR.RegisterModule("DRUID", D)
