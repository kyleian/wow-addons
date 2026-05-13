-- ============================================================
-- SlyRotate_Rogue — Combat / Assassination / Subtlety
-- TBC Anniversary (Interface 20505)
--
-- Combat:      Slice & Dice >> Rupture >> Eviscerate (5CP)
--              Blade Flurry + Adrenaline Rush CDs
-- Assassination: Mutilate >> Slice & Dice >> Rupture >> Evisc
--              Deadly Poison stacks indicator
-- Subtlety:    Hemorrhage >> SnD >> Rupture >> Evisc
-- ============================================================

local M = {}

M.classLabel = "Rogue"
M.headerIcon = "Interface\\Icons\\Ability_Stealth"
M.specKeys   = { "COMBAT", "ASSASSINATION", "SUBTLETY" }

-- ─── Row definitions ─────────────────────────────────────────
local ROWS_COMBAT = {
    { key="AR",     label="Adrenaline Rush",  spell="Adrenaline Rush", color={1.0, 0.7, 0.2} },
    { key="BF",     label="Blade Flurry",     spell="Blade Flurry",    color={0.8, 0.8, 0.3} },
    { key="SND",    label="Slice & Dice",     spell="Slice and Dice",   color={0.4, 0.9, 0.4} },
    { key="RUP",    label="Rupture",          spell="Rupture",        color={0.9, 0.3, 0.3} },
    { key="EVIS",   label="Eviscerate (5CP)", spell="Eviscerate",     color={0.9, 0.6, 0.2} },
    { key="SS",     label="Sinister Strike",  spell="Sinister Strike", color={0.6, 0.6, 0.6} },
}

local ROWS_ASSASSINATION = {
    { key="CB",     label="Cold Blood",       spell="Cold Blood",      color={0.6, 0.8, 1.0} },
    { key="SND",    label="Slice & Dice",     spell="Slice and Dice",   color={0.4, 0.9, 0.4} },
    { key="RUP",    label="Rupture",          spell="Rupture",        color={0.9, 0.3, 0.3} },
    { key="EVIS",   label="Eviscerate (5CP)", spell="Eviscerate",     color={0.9, 0.6, 0.2} },
    { key="MUTILATE", label="Mutilate",       spell="Mutilate",       color={0.7, 0.2, 0.8} },
}

local ROWS_SUBTLETY = {
    { key="SND",    label="Slice & Dice",     spell="Slice and Dice",   color={0.4, 0.9, 0.4} },
    { key="RUP",    label="Rupture",          spell="Rupture",        color={0.9, 0.3, 0.3} },
    { key="EVIS",   label="Eviscerate (5CP)", spell="Eviscerate",     color={0.9, 0.6, 0.2} },
    { key="HEMOR",  label="Hemorrhage",       spell="Hemorrhage",     color={0.7, 0.2, 0.2} },
}
M.specRows = { COMBAT = ROWS_COMBAT, ASSASSINATION = ROWS_ASSASSINATION, SUBTLETY = ROWS_SUBTLETY }
-- ─── Module state ─────────────────────────────────────────────
local spec        = nil
local currentRows = nil
local rows        = {}

-- Tracking
local comboPoints  = 0
local sndExpiry    = 0   -- Slice and Dice expires
local rupExpiry    = 0   -- Rupture expires on target

local SND_REFRESH_AT = 3   -- reapply SnD when < 3s remaining
local RUP_REFRESH_AT = 3   -- reapply Rupture when < 3s remaining

-- ─── Spec detection ───────────────────────────────────────────
-- TBC tab order: 1=Assassination, 2=Combat, 3=Subtlety
local function DetectSpec()
    local db = SR.db
    if db and db.classes.ROGUE and db.classes.ROGUE.specOverride then
        return db.classes.ROGUE.specOverride
    end
    return SR.DetectSpecByTalents({
        { spec="ASSASSINATION", tab=1 },
        { spec="COMBAT",        tab=2 },
        { spec="SUBTLETY",      tab=3 },
    }, "COMBAT")
end

-- ─── Required API ─────────────────────────────────────────────
function M:GetBodyHeight(ROW_H)
    local n = (spec == "COMBAT")       and #ROWS_COMBAT
           or (spec == "ASSASSINATION") and #ROWS_ASSASSINATION
           or #ROWS_SUBTLETY
    return n * (ROW_H + 1) + 4
end

function M:GetHeaderText()
    local col  = SR.Col
    local base = col("ffcc44", "ROGUE")
    if spec == "COMBAT"        then return base .. " " .. col("eecc33", "Combat")        end
    if spec == "ASSASSINATION" then return base .. " " .. col("cc44ff", "Assassination") end
    return base .. " " .. col("888888", "Subtlety")
end

function M:Build(body)
    for _, f in ipairs(rows) do f:Hide() end
    rows = {}

    currentRows = (spec == "COMBAT")        and ROWS_COMBAT
               or (spec == "ASSASSINATION") and ROWS_ASSASSINATION
               or ROWS_SUBTLETY

    for i, rd in ipairs(currentRows) do
        rd._idx = i
        local r = SR.BuildRow(body, rd, i)
        r.key = rd.key
        rows[i] = r
    end
    M.specRowFrames = { [spec] = rows }
    M.currentSpec = spec
end

-- ─── Priority update ──────────────────────────────────────────
local function GetActiveKey(now, db)
    comboPoints = GetComboPoints("player", "target") or 0

    local sndUp  = (sndExpiry - now) > 0
    local rupUp  = (rupExpiry - now) > 0
    local has5CP = comboPoints >= 5
    local hasCP  = comboPoints >= 4

    if spec == "COMBAT" then
        -- Adrenaline Rush opener
        local arCD = SR.SpellCD("Adrenaline Rush")
        if arCD == 0 then
            return "AR", SR.Col("55ff55", "READY")
        end
        -- Blade Flurry
        local bfCD = SR.SpellCD("Blade Flurry")
        if bfCD == 0 then
            return "BF", SR.Col("55ff55", "READY")
        end
        -- SnD uptime is highest priority among finishers
        if not sndUp or (sndExpiry - now) < SND_REFRESH_AT then
            if hasCP then
                return "SND", SR.Col("ffaa33", SR.Fmt(sndExpiry - now))
            end
        end
        -- Rupture if SnD is up
        if sndUp and (not rupUp or (rupExpiry - now) < RUP_REFRESH_AT) then
            if has5CP then
                return "RUP", SR.Col(rupUp and "ffaa33" or "ff4444",
                    rupUp and SR.Fmt(rupExpiry - now) or "MISSING")
            end
        end
        -- Eviscerate at 5 CP if both SnD and Rup are active
        if has5CP and sndUp and rupUp then
            return "EVIS", SR.Col("ff9933", "5CP")
        end
        -- Build combo points
        return "SS", SR.Col("888888", tostring(comboPoints) .. "CP")

    elseif spec == "ASSASSINATION" then
        local cbCD = SR.SpellCD("Cold Blood")
        if cbCD == 0 then
            return "CB", SR.Col("55ff55", "READY")
        end
        if not sndUp or (sndExpiry - now) < SND_REFRESH_AT then
            if hasCP then
                return "SND", SR.Col("ffaa33", SR.Fmt(sndExpiry - now))
            end
        end
        if sndUp and (not rupUp or (rupExpiry - now) < RUP_REFRESH_AT) then
            if has5CP then
                return "RUP", SR.Col(rupUp and "ffaa33" or "ff4444",
                    rupUp and SR.Fmt(rupExpiry - now) or "MISSING")
            end
        end
        if has5CP and sndUp and rupUp then
            return "EVIS", SR.Col("ff9933", "5CP")
        end
        return "MUTILATE", SR.Col("888888", tostring(comboPoints) .. "CP")

    else -- SUBTLETY
        if not sndUp or (sndExpiry - now) < SND_REFRESH_AT then
            if hasCP then
                return "SND", SR.Col("ffaa33", SR.Fmt(sndExpiry - now))
            end
        end
        if sndUp and (not rupUp or (rupExpiry - now) < RUP_REFRESH_AT) then
            if has5CP then
                return "RUP", SR.Col(rupUp and "ffaa33" or "ff4444",
                    rupUp and SR.Fmt(rupExpiry - now) or "MISSING")
            end
        end
        if has5CP and sndUp and rupUp then
            return "EVIS", SR.Col("ff9933", "5CP")
        end
        return "HEMOR", SR.Col("888888", tostring(comboPoints) .. "CP")
    end
end

function M:Update(now, db)
    if not rows[1] then return end
    local activeKey, statusStr = GetActiveKey(now, db)

    for _, row in ipairs(rows) do
        local isActive = (row.key == activeKey)
        local st = isActive and statusStr or ""
        if not isActive then
            if row.key == "SND" then
                local rem = sndExpiry - now
                st = rem > 0 and SR.Col("33bb33", SR.Fmt(rem)) or SR.Col("ff4444", "DOWN")
            elseif row.key == "RUP" then
                local rem = rupExpiry - now
                st = rem > 0 and SR.Col("bb3333", SR.Fmt(rem)) or SR.Col("ff4444", "DOWN")
            elseif row.key == "AR" or row.key == "BF" or row.key == "CB" then
                local spName = (row.key == "AR") and "Adrenaline Rush"
                            or (row.key == "BF") and "Blade Flurry"
                            or "Cold Blood"
                local cd = SR.SpellCD(spName)
                st = cd > 0 and SR.Col("888888", SR.Fmt(cd)) or SR.Col("55ff55", "READY")
            end
        end
        SR.SetRowState(row, isActive, st)
    end

    local cpStr = SR.Col("ffcc44", tostring(comboPoints) .. "CP")
    SR.UpdateSpotlight(currentRows, activeKey, cpStr)
    SR.SetModeLabel(SR.Col("ffcc44", tostring(comboPoints) .. "CP"))
end

-- ─── Events ───────────────────────────────────────────────────
function M:OnEvent(event, arg1)
    if event == "PLAYER_ENTERING_WORLD" or event == "ZONE_CHANGED_NEW_AREA" then
        if not spec then spec = DetectSpec() end
        self:ScanAll()
    elseif event == "PLAYER_TARGET_CHANGED" then
        rupExpiry = 0
        self:ScanAll()
    elseif event == "COMBAT_LOG_EVENT_UNFILTERED" then
        local _, subEvent, _, srcGUID, _, _, dstGUID, _, _,
              spellId, spellName = CombatLogGetCurrentEventInfo()
        local pGUID = UnitGUID("player")

        if subEvent == "SPELL_AURA_APPLIED" or subEvent == "SPELL_AURA_REFRESH" then
            if srcGUID == pGUID then
                -- SnD on player
                if spellName == "Slice and Dice" and dstGUID == pGUID then
                    -- Duration: 9s at 5CP (base) + Improved SnD talent
                    -- We'll just read it from UnitBuff
                    local j = 1
                    while true do
                        local n, _, _, _, dur, exp = UnitBuff("player", j)
                        if not n then break end
                        if n == "Slice and Dice" then
                            sndExpiry = exp or (GetTime() + 9)
                            break
                        end
                        j = j + 1
                    end
                end
                -- Rupture on target
                if spellName == "Rupture" then
                    local k = 1
                    while true do
                        local n, _, _, _, dur, exp, caster = UnitDebuff("target", k)
                        if not n then break end
                        if n == "Rupture" and caster == "player" then
                            rupExpiry = exp or (GetTime() + 18)
                            break
                        end
                        k = k + 1
                    end
                end
            end
        elseif subEvent == "SPELL_AURA_REMOVED" then
            if spellName == "Slice and Dice" and dstGUID == pGUID then
                sndExpiry = 0
            end
            if spellName == "Rupture" and srcGUID == pGUID then
                rupExpiry = 0
            end
        end
    end
end

function M:RegisterEvents()
    SR.RegisterEvent("COMBAT_LOG_EVENT_UNFILTERED")
    SR.RegisterEvent("PLAYER_TARGET_CHANGED")
end

function M:ScanAll()
    if not spec then spec = DetectSpec() end
    comboPoints = GetComboPoints("player", "target") or 0

    -- Scan for SnD on player
    sndExpiry = 0
    local i = 1
    while true do
        local name, _, _, _, dur, expires = UnitBuff("player", i)
        if not name then break end
        if name == "Slice and Dice" then
            sndExpiry = expires or 0
        end
        i = i + 1
    end

    -- Scan for Rupture on target
    rupExpiry = 0
    if UnitExists("target") then
        local j = 1
        while true do
            local name, _, _, _, dur, expires, caster = UnitDebuff("target", j)
            if not name then break end
            if name == "Rupture" and caster == "player" then
                rupExpiry = expires or 0
            end
            j = j + 1
        end
    end
end

SR.RegisterModule("ROGUE", M)
