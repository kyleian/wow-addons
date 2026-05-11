-- ============================================================
-- SlyRotate_Priest — Shadow / Holy / Discipline
-- TBC Anniversary (Interface 20505)
--
-- Shadow:      SW:P → VT → Mind Blast → Mind Flay filler
--              Shadowfiend + Inner Focus CDs; mana indicator
-- Holy:        Guardian Spirit + Circle of Healing + PoH CDs
--              Flash of Light / Greater Heal suggestions
-- Discipline:  PW:Shield (Weakened Soul tracker on target)
--              Pain Suppression + Power Infusion CDs
-- ============================================================

local M = {}

M.classLabel = "Priest"
M.headerIcon = "Interface\\Icons\\ClassIcon_Priest"
M.specKeys   = { "SHADOW", "HOLY", "DISCIPLINE" }

-- ─── Row definitions ─────────────────────────────────────────
local ROWS_SHADOW = {
    { key="VT",     label="Vampiric Touch",   spell="Vampiric Touch",  color={0.7, 0.4, 0.9} },
    { key="SWP",    label="SW: Pain",         spell="Shadow Word: Pain",         color={0.6, 0.2, 0.8} },
    { key="MB",     label="Mind Blast",       spell="Mind Blast",      color={0.5, 0.3, 0.9} },
    { key="SHADOW", label="Shadowfiend",      spell="Shadowfiend",    color={0.5, 0.5, 0.9} },
    { key="IF",     label="Inner Focus",      spell="Inner Focus",     color={0.7, 0.7, 1.0} },
    { key="SWD",    label="SW: Death",        spell="Shadow Word: Death",        color={0.9, 0.3, 0.3} },
    { key="MF",     label="Mind Flay (fill)", spell="Mind Flay",       color={0.4, 0.4, 0.7} },
}

local ROWS_HOLY = {
    { key="GS",     label="Guardian Spirit",  spell="Prayer of Healing", color={1.0, 1.0, 0.6} },
    { key="COH",    label="Circle of Healing",spell="Circle of Healing",   color={0.5, 1.0, 0.5} },
    { key="POH",    label="Prayer of Healing",spell="Prayer of Healing",            color={0.7, 0.9, 0.7} },
    { key="FH",     label="Flash Heal",       spell="Flash Heal",      color={0.9, 0.9, 0.9} },
    { key="GH",     label="Greater Heal",     spell="Greater Heal",    color={0.8, 0.8, 0.5} },
}

local ROWS_DISCIPLINE = {
    { key="PI",     label="Power Infusion",   spell="Power Infusion",  color={0.8, 0.5, 1.0} },
    { key="PS",     label="Pain Suppression", spell="Pain Suppression",color={1.0, 0.7, 0.3} },
    { key="SHIELD", label="PW: Shield",       spell="Power Word: Shield",       color={0.6, 0.7, 1.0} },
    { key="FH",     label="Flash Heal",       spell="Flash Heal",      color={0.9, 0.9, 0.9} },
    { key="GH",     label="Greater Heal",     spell="Greater Heal",    color={0.8, 0.8, 0.5} },
}

M.specRows = { SHADOW = ROWS_SHADOW, HOLY = ROWS_HOLY, DISCIPLINE = ROWS_DISCIPLINE }

-- ─── Module state ─────────────────────────────────────────────
local spec        = nil
local currentRows = nil
local rows        = {}

-- DoT tracking (Shadow)
local vtExpiry    = 0    -- Vampiric Touch on target
local swpExpiry   = 0    -- SW: Pain on target

local REFRESH_AT  = 2    -- reapply if < 2s remaining

-- Weakened Soul tracking (Discipline)
local weakenedSoulExpiry = 0   -- Weakened Soul debuff expires on target

-- ─── Spec detection ───────────────────────────────────────────
local function DetectSpec()
    if GetSpellInfo("Vampiric Touch")   then return "SHADOW"     end
    if GetSpellInfo("Pain Suppression") then return "DISCIPLINE"  end
    return "HOLY"
end

-- ─── Required API ─────────────────────────────────────────────
function M:GetBodyHeight(ROW_H)
    local n = (spec == "SHADOW")     and #ROWS_SHADOW
           or (spec == "HOLY")       and #ROWS_HOLY
           or #ROWS_DISCIPLINE
    return n * (ROW_H + 1) + 4
end

function M:GetHeaderText()
    local col  = SR.Col
    local base = col("ddddee", "PRIEST")
    if spec == "SHADOW"     then return base .. " " .. col("9966cc", "Shadow")     end
    if spec == "HOLY"       then return base .. " " .. col("ffffaa", "Holy")       end
    return base .. " " .. col("aaccff", "Discipline")
end

function M:Build(body)
    for _, f in ipairs(rows) do f:Hide() end
    rows = {}

    currentRows = (spec == "SHADOW")     and ROWS_SHADOW
               or (spec == "HOLY")       and ROWS_HOLY
               or ROWS_DISCIPLINE

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
    if spec == "SHADOW" then
        local mana    = UnitPower("player", Enum.PowerType.Mana)
        local maxMana = UnitPowerMax("player", Enum.PowerType.Mana)
        local manaPct = maxMana > 0 and (mana / maxMana) or 1

        -- Shadowfiend to restore mana if low
        if manaPct < 0.35 then
            local sfCD = SR.SpellCD("Shadowfiend")
            if sfCD == 0 then
                return "SHADOW", SR.Col("ff4444", "OOM!")
            end
        end

        -- Inner Focus (free next spell)
        local ifCD = SR.SpellCD("Inner Focus")
        if ifCD == 0 then
            return "IF", SR.Col("55ff55", "READY")
        end

        -- Vampiric Touch uptime (must reapply once it falls off or near end)
        if vtExpiry == 0 or (vtExpiry - now) < REFRESH_AT then
            return "VT", vtExpiry > 0
                and SR.Col("ff9944", SR.Fmt(vtExpiry - now))
                or  SR.Col("ff4444", "MISSING")
        end

        -- SW: Pain uptime
        if swpExpiry == 0 or (swpExpiry - now) < REFRESH_AT then
            return "SWP", swpExpiry > 0
                and SR.Col("ff9944", SR.Fmt(swpExpiry - now))
                or  SR.Col("ff4444", "MISSING")
        end

        -- SW: Death (execute)
        if UnitExists("target") then
            local tHP = UnitHealth("target") / math.max(1, UnitHealthMax("target"))
            if tHP < 0.25 then
                local swdCD = SR.SpellCD("Shadow Word: Death")
                if swdCD == 0 then
                    return "SWD", SR.Col("ff4444", "EXEC")
                end
            end
        end

        -- Mind Blast on CD
        local mbCD = SR.SpellCD("Mind Blast")
        if mbCD == 0 then
            return "MB", SR.Col("55ff55", "READY")
        end

        -- Mind Flay filler
        return "MF", SR.Col("559955", "filler")

    elseif spec == "HOLY" then
        -- Guardian Spirit CD
        local gsCD = SR.SpellCD("Guardian Spirit")
        if gsCD == 0 then
            return "GS", SR.Col("55ff55", "READY")
        end
        -- Circle of Healing
        local cohCD = SR.SpellCD("Circle of Healing")
        if cohCD == 0 then
            return "COH", SR.Col("55ff55", "READY")
        end
        -- Healing suggestion
        if UnitExists("target") then
            local tHP = UnitHealth("target") / math.max(1, UnitHealthMax("target"))
            if tHP < 0.40 then
                return "GH", SR.Col("ffcc44", string.format("%.0f%%", tHP*100))
            end
        end
        return "FH", SR.Col("aaaaaa", "cast")

    else -- DISCIPLINE
        -- Power Infusion
        local piCD = SR.SpellCD("Power Infusion")
        if piCD == 0 then
            return "PI", SR.Col("55ff55", "READY")
        end
        -- Pain Suppression
        local psCD = SR.SpellCD("Pain Suppression")
        if psCD == 0 then
            return "PS", SR.Col("55ff55", "READY")
        end
        -- PW: Shield (Weakened Soul check)
        local wsRem = weakenedSoulExpiry - now
        if wsRem <= 0 then
            return "SHIELD", SR.Col("55ff55", "READY")
        else
            -- Shield on CD (Weakened Soul), suggest healing
            if UnitExists("target") then
                local tHP = UnitHealth("target") / math.max(1, UnitHealthMax("target"))
                if tHP < 0.50 then
                    return "GH", SR.Col("ffcc44", string.format("%.0f%%", tHP*100))
                end
            end
            return "SHIELD", SR.Col("888888", SR.Fmt(wsRem))
        end
    end
end

function M:Update(now, db)
    if not rows[1] then return end
    local activeKey, statusStr = GetActiveKey(now, db)

    for _, row in ipairs(rows) do
        local isActive = (row.key == activeKey)
        local st = isActive and statusStr or ""
        if not isActive then
            if row.key == "VT" then
                local rem = vtExpiry - now
                st = rem > 0 and SR.Col("888888", SR.Fmt(rem)) or SR.Col("ff4444", "DOWN")
            elseif row.key == "SWP" then
                local rem = swpExpiry - now
                st = rem > 0 and SR.Col("888888", SR.Fmt(rem)) or SR.Col("ff4444", "DOWN")
            elseif row.key == "MB" then
                local cd = SR.SpellCD("Mind Blast")
                st = cd > 0 and SR.Col("888888", SR.Fmt(cd)) or SR.Col("55ff55", "READY")
            elseif row.key == "SHADOW" then
                local cd = SR.SpellCD("Shadowfiend")
                st = cd > 0 and SR.Col("888888", SR.Fmt(cd)) or SR.Col("55ff55", "READY")
            elseif row.key == "SHIELD" then
                local rem = weakenedSoulExpiry - now
                st = rem > 0 and SR.Col("888888", SR.Fmt(rem)) or SR.Col("55ff55", "READY")
            elseif row.key == "GS" then
                local cd = SR.SpellCD("Guardian Spirit")
                st = cd > 0 and SR.Col("888888", SR.Fmt(cd)) or SR.Col("55ff55", "READY")
            elseif row.key == "COH" then
                local cd = SR.SpellCD("Circle of Healing")
                st = cd > 0 and SR.Col("888888", SR.Fmt(cd)) or SR.Col("55ff55", "READY")
            end
        end
        SR.SetRowState(row, isActive, st)
    end

    SR.UpdateSpotlight(currentRows, activeKey, statusStr)
    SR.SetModeLabel(SR.Col("ddddee", spec and spec:sub(1, 4) or "???"))
end

-- ─── Event handling ───────────────────────────────────────────
local DOT_DURATIONS = {
    ["Vampiric Touch"] = 15,
    ["Shadow Word: Pain"] = 18,
}

function M:OnEvent(event, arg1)
    if event == "PLAYER_ENTERING_WORLD" or event == "ZONE_CHANGED_NEW_AREA" then
        if not spec then spec = DetectSpec() end
        self:ScanAll()
    elseif event == "PLAYER_TARGET_CHANGED" then
        vtExpiry  = 0
        swpExpiry = 0
        weakenedSoulExpiry = 0
        self:ScanAll()
    elseif event == "COMBAT_LOG_EVENT_UNFILTERED" then
        local _, subEvent, _, srcGUID, _, _, dstGUID, _, _,
              spellId, spellName = CombatLogGetCurrentEventInfo()
        local pGUID = UnitGUID("player")

        if subEvent == "SPELL_AURA_APPLIED" or subEvent == "SPELL_AURA_REFRESH" then
            if srcGUID == pGUID then
                if spellName == "Vampiric Touch" then
                    vtExpiry  = GetTime() + (DOT_DURATIONS["Vampiric Touch"] or 15)
                elseif spellName == "Shadow Word: Pain" then
                    swpExpiry = GetTime() + (DOT_DURATIONS["Shadow Word: Pain"] or 18)
                end
            end
            -- Weakened Soul debuff on target (placed by PW:Shield)
            if spellName == "Weakened Soul" and dstGUID == UnitGUID("target") then
                weakenedSoulExpiry = GetTime() + 15   -- WS lasts 15s
            end
        elseif subEvent == "SPELL_AURA_REMOVED" then
            if srcGUID == pGUID then
                if spellName == "Vampiric Touch"   then vtExpiry  = 0 end
                if spellName == "Shadow Word: Pain" then swpExpiry = 0 end
            end
            if spellName == "Weakened Soul" and dstGUID == UnitGUID("target") then
                weakenedSoulExpiry = 0
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
    vtExpiry  = 0
    swpExpiry = 0
    weakenedSoulExpiry = 0

    if not UnitExists("target") then return end

    -- Scan target debuffs for our DoTs and Weakened Soul
    local i = 1
    while true do
        local name, _, _, _, dur, expires, caster = UnitDebuff("target", i)
        if not name then break end
        if caster == "player" then
            if name == "Vampiric Touch"    then vtExpiry  = expires or 0 end
            if name == "Shadow Word: Pain" then swpExpiry = expires or 0 end
        end
        if name == "Weakened Soul" then
            weakenedSoulExpiry = expires or 0
        end
        i = i + 1
    end
end

SR.RegisterModule("PRIEST", M)
