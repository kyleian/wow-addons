-- ============================================================
-- SlyRotate_Paladin — Retribution / Protection / Holy
-- TBC Anniversary (Interface 20505)
--
-- Retribution: Seal management + Judgement + Crusader Strike
--              Consecration filler; Exorcism vs undead/demon
-- Protection:  Holy Shield + Judgement + Consecration
--              Avenger's Shield pull
-- Holy:        CD tracker — Divine Favor, Holy Shock, LoH
-- ============================================================

local M = {}

M.classLabel = "Paladin"
M.headerIcon = "Interface\\Icons\\ClassIcon_Paladin"
M.specKeys   = { "RETRIBUTION", "PROTECTION", "HOLY" }

-- ─── Icons ───────────────────────────────────────────────────
local ICO = {
    SealCommand     = "Interface\\Icons\\Ability_Paladin_SealOfCommand",
    SealBlood       = "Interface\\Icons\\Ability_Racial_CannibalizeSelf",   -- Blood elf seal
    SealRighteousness="Interface\\Icons\\Spell_Holy_AuraOfLight",
    Judgement       = "Interface\\Icons\\Ability_Paladin_Judgement",
    CrusaderStrike  = "Interface\\Icons\\Spell_Holy_CrusaderStrike",
    Consecration    = "Interface\\Icons\\Spell_Holy_Consecration",
    Exorcism        = "Interface\\Icons\\Spell_Holy_Excorcism",
    HolyShield      = "Interface\\Icons\\Spell_Holy_HolyBolt",
    AvengersShield  = "Interface\\Icons\\Spell_Holy_AvengersShield",
    HammerOfWrath   = "Interface\\Icons\\Ability_Warrior_WarCry",
    DivineFavor     = "Interface\\Icons\\Spell_Holy_DivineFavor",
    HolyShock       = "Interface\\Icons\\Spell_Holy_SearingLight",
    FlashOfLight    = "Interface\\Icons\\Spell_Holy_FlashHeal",
    HolyLight       = "Interface\\Icons\\Spell_Holy_HolyBolt",
    LayOnHands      = "Interface\\Icons\\Spell_Holy_LayOnHands",
}

-- ─── Row definitions per spec ─────────────────────────────────
local ROWS_RETRIBUTION = {
    { key="SEAL",   label="Seal (uptime)",     icon=ICO.SealCommand,    color={0.9, 0.7, 0.3} },
    { key="CS",     label="Crusader Strike",   icon=ICO.CrusaderStrike, color={1.0, 0.6, 0.2} },
    { key="JUDGE",  label="Judgement",         icon=ICO.Judgement,      color={0.8, 0.5, 0.2} },
    { key="CONSC",  label="Consecration",      icon=ICO.Consecration,   color={0.9, 0.8, 0.3} },
    { key="EXORC",  label="Exorcism",          icon=ICO.Exorcism,       color={0.8, 0.9, 0.5} },
    { key="HOW",    label="Hammer of Wrath",   icon=ICO.HammerOfWrath,  color={0.9, 0.3, 0.2} },
}

local ROWS_PROTECTION = {
    { key="AVS",    label="Avenger's Shield",  icon=ICO.AvengersShield, color={0.6, 0.7, 1.0} },
    { key="HOLYSH", label="Holy Shield",       icon=ICO.HolyShield,     color={0.8, 0.8, 1.0} },
    { key="JUDGE",  label="Judgement",         icon=ICO.Judgement,      color={0.8, 0.5, 0.2} },
    { key="CONSC",  label="Consecration",      icon=ICO.Consecration,   color={0.9, 0.8, 0.3} },
    { key="SEAL",   label="Seal (uptime)",     icon=ICO.SealRighteousness, color={0.9, 0.7, 0.3} },
}

local ROWS_HOLY = {
    { key="DF",     label="Divine Favor",      icon=ICO.DivineFavor,    color={1.0, 0.9, 0.4} },
    { key="HSHOCK", label="Holy Shock",        icon=ICO.HolyShock,      color={1.0, 0.7, 0.3} },
    { key="LOH",    label="Lay on Hands",      icon=ICO.LayOnHands,     color={0.8, 0.9, 1.0} },
    { key="FOL",    label="Flash of Light",    icon=ICO.FlashOfLight,   color={0.9, 0.9, 0.9} },
    { key="HL",     label="Holy Light",        icon=ICO.HolyLight,      color={0.9, 0.8, 0.5} },
}

M.specRows = { RETRIBUTION = ROWS_RETRIBUTION, PROTECTION = ROWS_PROTECTION, HOLY = ROWS_HOLY }

-- ─── Module state ─────────────────────────────────────────────
local spec        = nil
local currentRows = nil
local rows        = {}

local sealExpiry  = 0   -- when our Seal buff expires
local judgeCost   = 0   -- last Judgement cast time (8s CD + talent)

-- ─── spec detection ───────────────────────────────────────────
local function DetectSpec()
    if GetSpellInfo("Crusader Strike")   then return "RETRIBUTION" end
    if GetSpellInfo("Avenger's Shield")  then return "PROTECTION"  end
    return "HOLY"
end

-- ─── Required API ─────────────────────────────────────────────
function M:GetBodyHeight(ROW_H)
    local n = (spec == "RETRIBUTION") and #ROWS_RETRIBUTION
           or (spec == "PROTECTION")  and #ROWS_PROTECTION
           or #ROWS_HOLY
    return n * (ROW_H + 1) + 4
end

function M:GetHeaderText()
    local col  = SR.Col
    local base = col("ffdd88", "PALADIN")
    if spec == "RETRIBUTION" then return base .. " " .. col("ffaa33", "Retribution") end
    if spec == "PROTECTION"  then return base .. " " .. col("88aaff", "Protection")  end
    return base .. " " .. col("ffffaa", "Holy")
end

function M:Build(body)
    for _, f in ipairs(rows) do f:Hide() end
    rows = {}

    currentRows = (spec == "RETRIBUTION") and ROWS_RETRIBUTION
               or (spec == "PROTECTION")  and ROWS_PROTECTION
               or ROWS_HOLY

    for i, rd in ipairs(currentRows) do
        rd._idx = i
        local r = SR.BuildRow(body, rd, i)
        r.key = rd.key
        rows[i] = r
    end    M.specRowFrames = { [spec] = rows }
    M.currentSpec = specend

-- ─── Priority update ──────────────────────────────────────────
local function GetActiveKey(now, db)
    if spec == "RETRIBUTION" then
        -- Seal must be up
        if (sealExpiry - now) < 3 then
            local rem = sealExpiry - now
            return "SEAL", rem > 0 and SR.Col("ff9944", SR.Fmt(rem)) or SR.Col("ff4444", "MISSING")
        end

        -- Crusader Strike (6s CD, or 4.5s with talents)
        local csCD = SR.SpellCD("Crusader Strike")
        if csCD == 0 then
            return "CS", SR.Col("55ff55", "READY")
        end

        -- Judgement (~10s CD baseline, 8s with Improved Judgement)
        local judgeCD = SR.SpellCD("Judgement")
        if judgeCD == 0 then
            return "JUDGE", SR.Col("55ff55", "READY")
        end

        -- Hammer of Wrath (execute, target < 20% HP)
        if UnitExists("target") then
            local targetHP = UnitHealth("target") / UnitHealthMax("target")
            if targetHP < 0.20 then
                local howCD = SR.SpellCD("Hammer of Wrath")
                if howCD == 0 then
                    return "HOW", SR.Col("ff4444", "EXECUTE")
                end
            end
        end

        -- Exorcism (undead / demon targets)
        if UnitExists("target") then
            local ctype = UnitCreatureType("target")
            if ctype == "Undead" or ctype == "Demon" then
                local exCD = SR.SpellCD("Exorcism")
                if exCD == 0 then
                    return "EXORC", SR.Col("55ff55", "READY")
                end
            end
        end

        -- Consecration (mana permitting)
        local mana = UnitMana("player") / UnitManaMax("player")
        if mana > 0.30 then
            local consCD = SR.SpellCD("Consecration")
            if consCD == 0 then
                return "CONSC", SR.Col("55ff55", "READY")
            end
        end

        return "SEAL", SR.Col("33ff33", SR.Fmt(sealExpiry - now))

    elseif spec == "PROTECTION" then
        -- Avenger's Shield on pull
        local avsCD = SR.SpellCD("Avenger's Shield")
        if avsCD == 0 then
            return "AVS", SR.Col("55ffff", "READY")
        end
        -- Holy Shield (4 charges, 10s)
        local hsCD = SR.SpellCD("Holy Shield")
        if hsCD == 0 then
            return "HOLYSH", SR.Col("55ff55", "READY")
        end
        -- Judgement
        local judgeCD = SR.SpellCD("Judgement")
        if judgeCD == 0 then
            return "JUDGE", SR.Col("55ff55", "READY")
        end
        -- Consecration
        local consCD = SR.SpellCD("Consecration")
        if consCD == 0 then
            return "CONSC", SR.Col("55ff55", "READY")
        end
        -- Seal uptime
        if (sealExpiry - now) < 3 then
            return "SEAL", SR.Col("ff9944", SR.Fmt(sealExpiry - now))
        end
        return "SEAL", SR.Col("33ff33", SR.Fmt(sealExpiry - now))

    else -- HOLY
        -- Divine Favor (next cast is crit)
        local dfCD = SR.SpellCD("Divine Favor")
        if dfCD == 0 then
            return "DF", SR.Col("55ff55", "READY")
        end
        -- Holy Shock
        local hsCD = SR.SpellCD("Holy Shock")
        if hsCD == 0 then
            return "HSHOCK", SR.Col("55ff55", "READY")
        end
        -- Lay on Hands (emergency)
        local lohCD = SR.SpellCD("Lay on Hands")
        if lohCD == 0 then
            return "LOH", SR.Col("55ffff", "READY")
        end
        -- Spell suggestion based on tank HP
        if UnitExists("target") then
            local targetHP = UnitHealth("target") / math.max(1, UnitHealthMax("target"))
            if targetHP < 0.50 then
                return "HL", SR.Col("ffcc44", string.format("%.0f%%", targetHP*100))
            end
        end
        return "FOL", SR.Col("aaaaaa", "cast")
    end
end

function M:Update(now, db)
    if not rows[1] then return end
    local activeKey, statusStr = GetActiveKey(now, db)

    for _, row in ipairs(rows) do
        local isActive = (row.key == activeKey)
        local st = isActive and statusStr or ""
        if not isActive then
            if row.key == "SEAL" then
                local rem = sealExpiry - now
                st = rem > 0 and SR.Col("888888", SR.Fmt(rem)) or SR.Col("ff4444", "DOWN")
            elseif row.key == "JUDGE" then
                local cd = SR.SpellCD("Judgement")
                st = cd > 0 and SR.Col("888888", SR.Fmt(cd)) or SR.Col("55ff55", "READY")
            elseif row.key == "CS" then
                local cd = SR.SpellCD("Crusader Strike")
                st = cd > 0 and SR.Col("888888", SR.Fmt(cd)) or SR.Col("55ff55", "READY")
            elseif row.key == "HOLYSH" then
                local cd = SR.SpellCD("Holy Shield")
                st = cd > 0 and SR.Col("888888", SR.Fmt(cd)) or SR.Col("55ff55", "READY")
            elseif row.key == "DF" then
                local cd = SR.SpellCD("Divine Favor")
                st = cd > 0 and SR.Col("888888", SR.Fmt(cd)) or SR.Col("55ff55", "READY")
            end
        end
        SR.SetRowState(row, isActive, st)
    end

    SR.UpdateSpotlight(currentRows, activeKey, statusStr)
    SR.SetModeLabel(SR.Col("ffdd88", spec and spec:sub(1, 4) or "???"))
end

-- ─── Events ───────────────────────────────────────────────────
function M:OnEvent(event, arg1)
    if event == "PLAYER_ENTERING_WORLD" or event == "ZONE_CHANGED_NEW_AREA" then
        if not spec then spec = DetectSpec() end
        self:ScanAll()
    elseif event == "UNIT_AURA" then
        if arg1 == "player" then self:ScanAll() end
    end
end

function M:RegisterEvents()
    SR.RegisterEvent("UNIT_AURA")
end

function M:ScanAll()
    if not spec then spec = DetectSpec() end
    sealExpiry = 0

    -- Scan for any Seal buff on player
    local SEAL_NAMES = {
        ["Seal of Command"]       = true,
        ["Seal of Blood"]         = true,
        ["Seal of Righteousness"] = true,
        ["Seal of Justice"]       = true,
        ["Seal of Wisdom"]        = true,
        ["Seal of Light"]         = true,
        ["Seal of the Crusader"]  = true,
    }
    local i = 1
    while true do
        local name, _, _, _, dur, expires = UnitBuff("player", i)
        if not name then break end
        if SEAL_NAMES[name] then
            sealExpiry = expires or 0
            break
        end
        i = i + 1
    end
end

SR.RegisterModule("PALADIN", M)
