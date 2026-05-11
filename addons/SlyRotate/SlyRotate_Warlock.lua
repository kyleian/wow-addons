-- ============================================================
-- SlyRotate_Warlock — Affliction / Destruction / Demonology
-- TBC Anniversary (Interface 20505)
--
-- Affliction:  Curse management + DoT uptime priority
-- Destruction: Immolate >> Conflagrate >> Shadow Bolt filler
-- Demonology:  Pet management + shadow bolt / corruption spam
-- ============================================================

local M = {}

M.classLabel = "Warlock"
M.headerIcon = "Interface\\Icons\\Spell_Shadow_DeathCoil"
M.specKeys   = { "AFFLICTION", "DESTRUCTION", "DEMONOLOGY" }

-- ─── Spell icons ─────────────────────────────────────────────
-- ─── Row definitions per spec ─────────────────────────────────
local ROWS_AFFLICTION = {
    { key="CURSE",    label="Curse of Agony",       spell="Curse of Agony",      color={0.7, 0.3, 0.9} },
    { key="UA",       label="Unstable Affliction",  spell="Unstable Affliction", color={0.85, 0.4, 1.0} },
    { key="CORRUPT",  label="Corruption",            spell="Corruption",      color={0.6, 0.2, 0.8} },
    { key="IMMO",     label="Immolate",              spell="Immolate",        color={0.95, 0.5, 0.2} },
    { key="SIPHON",   label="Siphon Life",           spell="Siphon Life",      color={0.5, 0.9, 0.5} },
    { key="SBOLT",    label="Shadow Bolt (filler)",  spell="Shadow Bolt",      color={0.5, 0.5, 0.9} },
    { key="LIFETAP",  label="Life Tap (mana)",       spell="Life Tap",         color={0.9, 0.4, 0.4} },
}

local ROWS_DESTRUCTION = {
    { key="IMMO",     label="Immolate",              spell="Immolate",        color={0.95, 0.5, 0.2} },
    { key="CONFLAG",  label="Conflagrate",           spell="Conflagrate",     color={1.0, 0.6, 0.1} },
    { key="INCINERATE", label="Incinerate",          spell="Incinerate",      color={1.0, 0.4, 0.0} },
    { key="SBOLT",    label="Shadow Bolt (filler)",  spell="Shadow Bolt",      color={0.5, 0.5, 0.9} },
    { key="SOULFIRE", label="Soul Fire (if proc)",   spell="Soul Fire",        color={0.9, 0.8, 0.2} },
    { key="LIFETAP",  label="Life Tap (mana)",       spell="Life Tap",         color={0.9, 0.4, 0.4} },
}

local ROWS_DEMONOLOGY = {
    { key="CORRUPT",  label="Corruption",            spell="Corruption",      color={0.6, 0.2, 0.8} },
    { key="IMMO",     label="Immolate",              spell="Immolate",        color={0.95, 0.5, 0.2} },
    { key="CURSE",    label="Curse of Elements",     spell="Curse of the Elements",   color={0.7, 0.3, 0.9} },
    { key="SBOLT",    label="Shadow Bolt (filler)",  spell="Shadow Bolt",      color={0.5, 0.5, 0.9} },
    { key="LIFETAP",  label="Life Tap (mana)",       spell="Life Tap",         color={0.9, 0.4, 0.4} },
}

M.specRows = { AFFLICTION = ROWS_AFFLICTION, DESTRUCTION = ROWS_DESTRUCTION, DEMONOLOGY = ROWS_DEMONOLOGY }

-- ─── Module state ─────────────────────────────────────────────
local spec         = nil   -- "AFFLICTION" | "DESTRUCTION" | "DEMONOLOGY"
local currentRows  = nil
local rows         = {}    -- Frame objects, re-built per spec

-- DoT/debuff tracking on target
local dotExpiry = {
    CURSE   = 0,
    CORRUPT = 0,
    IMMO    = 0,
    UA      = 0,
    SIPHON  = 0,
}

-- Cooldown cache
local conflagrateReady = 0
local lifeTapManaThresh = 0.35  -- tap when below 35% mana

-- ─── Talent detection ─────────────────────────────────────────
-- TBC tab order: 1=Affliction, 2=Demonology, 3=Destruction
local function DetectSpec()
    return SR.DetectSpecByTalents({
        { spec="AFFLICTION",  tab=1 },
        { spec="DEMONOLOGY",  tab=2 },
        { spec="DESTRUCTION", tab=3 },
    }, "AFFLICTION")
end

-- ─── Module required API ──────────────────────────────────────
function M:GetBodyHeight(ROW_H)
    local n = (spec == "AFFLICTION") and #ROWS_AFFLICTION
           or (spec == "DESTRUCTION") and #ROWS_DESTRUCTION
           or #ROWS_DEMONOLOGY
    return n * (ROW_H + 1) + 4
end

function M:GetHeaderText()
    local col = SR.Col
    local base = col("cc66ff", "WARLOCK")
    if spec == "AFFLICTION"  then return base .. " " .. col("997acc", "Affliction")  end
    if spec == "DESTRUCTION" then return base .. " " .. col("ff9944", "Destruction") end
    return base .. " " .. col("7799cc", "Demonology")
end

function M:Build(body)
    for _, f in ipairs(rows) do f:Hide() end
    rows = {}

    currentRows = (spec == "AFFLICTION")  and ROWS_AFFLICTION
               or (spec == "DESTRUCTION") and ROWS_DESTRUCTION
               or ROWS_DEMONOLOGY

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
    local mana    = (UnitPower("player", Enum.PowerType.Mana) / UnitPowerMax("player", Enum.PowerType.Mana))
    local inRange = true  -- assume in range; can extend with range check

    -- Life Tap threshold — highest priority if OOM
    if mana < lifeTapManaThresh then
        return "LIFETAP", SR.Col("ff6666", string.format("%.0f%%", mana * 100))
    end

    if spec == "AFFLICTION" then
        -- Priority: UA >> Curse >> Corruption >> Immolate >> Siphon Life >> SBolt
        if dotExpiry.UA > 0 and (dotExpiry.UA - now) < 2 then
            return "UA", SR.Col("ff9955", SR.Fmt(dotExpiry.UA - now))
        end
        if dotExpiry.UA == 0 or (dotExpiry.UA - now) <= 0 then
            return "UA", SR.Col("ff4444", "MISSING")
        end
        if dotExpiry.CURSE == 0 or (dotExpiry.CURSE - now) <= 0 then
            return "CURSE", SR.Col("ff4444", "MISSING")
        end
        if (dotExpiry.CURSE - now) < 3 then
            return "CURSE", SR.Col("ff9955", SR.Fmt(dotExpiry.CURSE - now))
        end
        if dotExpiry.CORRUPT == 0 or (dotExpiry.CORRUPT - now) <= 0 then
            return "CORRUPT", SR.Col("ff4444", "MISSING")
        end
        if (dotExpiry.CORRUPT - now) < 3 then
            return "CORRUPT", SR.Col("ff9955", SR.Fmt(dotExpiry.CORRUPT - now))
        end
        if dotExpiry.IMMO == 0 or (dotExpiry.IMMO - now) <= 0 then
            return "IMMO", SR.Col("ff4444", "MISSING")
        end
        if (dotExpiry.IMMO - now) < 3 then
            return "IMMO", SR.Col("ff9955", SR.Fmt(dotExpiry.IMMO - now))
        end
        if dotExpiry.SIPHON == 0 or (dotExpiry.SIPHON - now) <= 0 then
            local si = GetSpellInfo("Siphon Life")
            if si then
                return "SIPHON", SR.Col("ff4444", "MISSING")
            end
        end
        return "SBOLT", SR.Col("559955", "filler")

    elseif spec == "DESTRUCTION" then
        -- Priority: Immolate >> Conflagrate (if up) >> Incinerate >> SBolt
        if dotExpiry.IMMO == 0 or (dotExpiry.IMMO - now) <= 0 then
            return "IMMO", SR.Col("ff4444", "MISSING")
        end
        if (dotExpiry.IMMO - now) < 2 then
            return "IMMO", SR.Col("ff9955", SR.Fmt(dotExpiry.IMMO - now))
        end
        local confCD = SR.SpellCD("Conflagrate")
        if confCD == 0 and dotExpiry.IMMO > now then
            return "CONFLAG", SR.Col("55ff55", "READY")
        elseif confCD > 0 then
            -- Conflag on CD, show filler
        end
        -- Incinerate if talented
        local hasIncinerate = GetSpellInfo("Incinerate") ~= nil
        if hasIncinerate then
            return "INCINERATE", SR.Col("559955", "filler")
        end
        return "SBOLT", SR.Col("559955", "filler")

    else -- DEMONOLOGY
        -- Priority: Corruption >> Immolate >> Curse of Elements >> SBolt
        if dotExpiry.CURSE == 0 or (dotExpiry.CURSE - now) <= 0 then
            return "CURSE", SR.Col("ff4444", "MISSING")
        end
        if (dotExpiry.CURSE - now) < 3 then
            return "CURSE", SR.Col("ff9955", SR.Fmt(dotExpiry.CURSE - now))
        end
        if dotExpiry.CORRUPT == 0 or (dotExpiry.CORRUPT - now) <= 0 then
            return "CORRUPT", SR.Col("ff4444", "MISSING")
        end
        if (dotExpiry.CORRUPT - now) < 3 then
            return "CORRUPT", SR.Col("ff9955", SR.Fmt(dotExpiry.CORRUPT - now))
        end
        if dotExpiry.IMMO == 0 or (dotExpiry.IMMO - now) <= 0 then
            return "IMMO", SR.Col("ff4444", "MISSING")
        end
        if (dotExpiry.IMMO - now) < 3 then
            return "IMMO", SR.Col("ff9955", SR.Fmt(dotExpiry.IMMO - now))
        end
        return "SBOLT", SR.Col("559955", "filler")
    end
end

function M:Update(now, db)
    if not rows[1] then return end
    local activeKey, statusStr = GetActiveKey(now, db)

    for _, row in ipairs(rows) do
        local isActive = (row.key == activeKey)
        -- For cooldown rows show remaining
        local st = statusStr
        if row.key == "CONFLAG" and not isActive then
            local cd = SR.SpellCD("Conflagrate")
            st = cd > 0 and SR.Col("888888", SR.Fmt(cd)) or ""
        end
        SR.SetRowState(row, isActive, isActive and st or "")
    end

    SR.UpdateSpotlight(currentRows, activeKey, statusStr)
    SR.SetModeLabel(SR.Col("cc66ff", spec and spec:sub(1,4) or "???"))
end

-- ─── Combat-log tracking ──────────────────────────────────────
local DOT_SPELLS = {
    ["Curse of Agony"]       = "CURSE",
    ["Curse of Elements"]    = "CURSE",
    ["Corruption"]           = "CORRUPT",
    ["Immolate"]             = "IMMO",
    ["Unstable Affliction"]  = "UA",
    ["Siphon Life"]          = "SIPHON",
}
local DOT_DURATIONS = {
    ["Curse of Agony"]       = 24,
    ["Curse of Elements"]    = 300,
    ["Corruption"]           = 18,
    ["Immolate"]             = 15,
    ["Unstable Affliction"]  = 18,
    ["Siphon Life"]          = 30,
}

function M:OnEvent(event, arg1)
    if event == "PLAYER_ENTERING_WORLD" or event == "ZONE_CHANGED_NEW_AREA" then
        local newSpec = DetectSpec()
        if newSpec ~= spec then
            spec = newSpec
            -- Rebuild rows via core (fire a PLAYER_TARGET_CHANGED to force rebuild)
            -- Actually we just reset the dot expiry
            for k in pairs(dotExpiry) do dotExpiry[k] = 0 end
        end
    elseif event == "PLAYER_TARGET_CHANGED" then
        for k in pairs(dotExpiry) do dotExpiry[k] = 0 end
        self:ScanAll()
    elseif event == "COMBAT_LOG_EVENT_UNFILTERED" then
        local timestamp, subEvent, hideCaster,
              srcGUID, srcName, srcFlags,
              dstGUID, dstName, dstFlags,
              spellId, spellName, spellSchool,
              auraType, amount = CombatLogGetCurrentEventInfo()

        local playerGUID = UnitGUID("player")
        if srcGUID ~= playerGUID then return end

        if subEvent == "SPELL_AURA_APPLIED" or subEvent == "SPELL_AURA_REFRESH" then
            local dotKey = DOT_SPELLS[spellName]
            if dotKey then
                local dur = DOT_DURATIONS[spellName] or 18
                dotExpiry[dotKey] = GetTime() + dur
            end
        elseif subEvent == "SPELL_AURA_REMOVED" then
            local dotKey = DOT_SPELLS[spellName]
            if dotKey then
                dotExpiry[dotKey] = 0
            end
        end
    end
end

function M:RegisterEvents()
    SR.RegisterEvent("COMBAT_LOG_EVENT_UNFILTERED")
    SR.RegisterEvent("PLAYER_TARGET_CHANGED")
end

function M:ScanAll()
    -- Scan current target debuffs for our DoTs
    for k in pairs(dotExpiry) do dotExpiry[k] = 0 end
    if not UnitExists("target") then return end

    local i = 1
    while true do
        local name, _, _, _, dur, expires, caster = UnitDebuff("target", i)
        if not name then break end
        if caster == "player" then
            local dotKey = DOT_SPELLS[name]
            if dotKey then
                dotExpiry[dotKey] = expires or 0
            end
        end
        i = i + 1
    end

    -- Detect spec on first scan
    if not spec then
        spec = DetectSpec()
    end
end

SR.RegisterModule("WARLOCK", M)
