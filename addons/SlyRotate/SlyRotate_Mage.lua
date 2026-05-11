-- ============================================================
-- SlyRotate_Mage — Arcane / Fire / Frost
-- TBC Anniversary (Interface 20505)
--
-- Arcane:  AB stack management + live mana forecast
-- Fire:    Scorch debuff → Fireball spam + Combustion CD
-- Frost:   Frostbolt spam + Icy Veins / Water Elem CDs
--          Brain Freeze proc (instant Frostfire Bolt)
-- ============================================================

local M = {}

M.classLabel = "Mage"
M.headerIcon = "Interface\\Icons\\Spell_Holy_MagicSentry"
M.specKeys   = { "ARCANE", "FIRE", "FROST" }

-- ─── Row definitions ─────────────────────────────────────────
local ROWS_ARCANE = {
    { key="APOW",    label="Arcane Power",    spell="Arcane Power",   color={0.6, 0.6, 1.0} },
    { key="POM",     label="Presence of Mind",spell="Presence of Mind",color={0.8, 0.8, 0.4} },
    { key="AB",      label="Arcane Blast",    spell="Arcane Blast",   color={0.5, 0.5, 0.9} },
    { key="AM",      label="Arcane Missiles", spell="Arcane Missiles", color={0.5, 0.8, 1.0} },
    { key="EVOC",    label="Evocation (OOM)", spell="Evocation",     color={0.8, 0.5, 1.0} },
    { key="MANA",    label="Mana Forecast",   spell="Arcane Blast",   color={0.9, 0.9, 0.3} },
}

local ROWS_FIRE = {
    { key="COMB",    label="Combustion",      spell="Combustion",    color={1.0, 0.5, 0.1} },
    { key="SCORCH",  label="Scorch (debuff)", spell="Scorch",        color={0.9, 0.4, 0.2} },
    { key="FIREBALL",label="Fireball (spam)", spell="Fireball",      color={1.0, 0.6, 0.2} },
    { key="FBLAST",  label="Fire Blast",      spell="Fire Blast",     color={1.0, 0.3, 0.1} },
}

local ROWS_FROST = {
    { key="IVEIN",   label="Icy Veins",       spell="Icy Veins",      color={0.5, 0.8, 1.0} },
    { key="WELEM",   label="Water Elemental", spell="Summon Water Elemental",     color={0.3, 0.7, 0.9} },
    { key="CSNAP",   label="Cold Snap",       spell="Cold Snap",      color={0.7, 0.9, 1.0} },
    { key="PROC",    label="Brain Freeze!",   spell="Frostbolt", color={1.0, 0.9, 0.5} },
    { key="FBOLT",   label="Frostbolt (spam)",spell="Frostbolt",     color={0.4, 0.7, 0.9} },
}
M.specRows = { ARCANE = ROWS_ARCANE, FIRE = ROWS_FIRE, FROST = ROWS_FROST }
-- ─── Module state ─────────────────────────────────────────────
local spec        = nil
local currentRows = nil
local rows        = {}

-- Arcane state
local abStacks      = 0           -- Arcane Blast debuff stacks (0-4)
local abStackExpiry = 0           -- when the AB stack buff falls off
local AM_MANA_PCT   = 0.40        -- dump ABx4 stacks → Arcane Missiles below this
local ABX4_MANA_PCT = 0.25        -- EVOC threshold: use Evocation below 25%

-- Combat start time for mana forecast
local combatStart  = nil
local manaAtStart  = nil

-- Fire state
local scorchStacks  = 0  -- Improved Scorch debuff stacks on target (max 5)
local scorchExpiry  = 0

-- Frost state
local brainFreeze   = false    -- Brain Freeze proc active

-- ─── Talent detection ─────────────────────────────────────────
local function DetectSpec()
    -- Deep Arcane: Arcane Power is a Tier-5 talent
    -- Deep Fire: Combustion is available at level 20 baseline but
    --   Improved Scorch is Tier-3 Fire, Pyroblast is Tier-1
    -- Deep Frost: Ice Lance is baseline, Summon Water Elemental Tier-5
    local hasSummonWE = GetSpellInfo("Summon Water Elemental") ~= nil
    local hasIcyVeins = GetSpellInfo("Icy Veins") ~= nil
    local hasFlamestrike = GetSpellInfo("Flamestrike") ~= nil  -- everyone, not useful
    -- Heuristic: check Arcane Power vs Icy Veins vs everything else
    local hasArcanePow = GetSpellInfo("Arcane Power") ~= nil

    if hasArcanePow then
        -- Arcane has Arcane Power as signature talent (Tier 5, 21 pts)
        -- Fire also picks up some arcane, so use deeper check
        -- If they also have Icy Veins it's actually Frost
        if hasIcyVeins then return "FROST" end
        return "ARCANE"
    elseif hasIcyVeins then
        return "FROST"
    else
        return "FIRE"
    end
end

-- ─── Required API ─────────────────────────────────────────────
function M:GetBodyHeight(ROW_H)
    local n = (spec == "ARCANE") and #ROWS_ARCANE
           or (spec == "FIRE")   and #ROWS_FIRE
           or #ROWS_FROST
    return n * (ROW_H + 1) + 4
end

function M:GetHeaderText()
    local col  = SR.Col
    local base = col("88ccff", "MAGE")
    if spec == "ARCANE" then return base .. " " .. col("8888ff", "Arcane") end
    if spec == "FIRE"   then return base .. " " .. col("ff8844", "Fire")   end
    return base .. " " .. col("55aaff", "Frost")
end

function M:Build(body)
    for _, f in ipairs(rows) do f:Hide() end
    rows = {}

    currentRows = (spec == "ARCANE") and ROWS_ARCANE
               or (spec == "FIRE")   and ROWS_FIRE
               or ROWS_FROST

    for i, rd in ipairs(currentRows) do
        rd._idx = i
        local r = SR.BuildRow(body, rd, i)
        r.key = rd.key
        rows[i] = r
    end
    M.specRowFrames = { [spec] = rows }
    M.currentSpec = spec
end

-- ─── Mana forecast helper ──────────────────────────────────────
-- Estimates mana% at the end of the fight based on current burn rate.
-- Returns projected mana % and time-to-OOM in seconds (nil if not valid).
local function ForecastMana(now)
    if not combatStart or not manaAtStart then return nil, nil end
    local elapsed = now - combatStart
    if elapsed < 5 then return nil, nil end
    local curMana  = UnitPower("player", Enum.PowerType.Mana)
    local maxMana  = UnitPowerMax("player", Enum.PowerType.Mana)
    local spent    = manaAtStart - curMana
    if spent <= 0 then return nil, nil end
    local burnPerSec  = spent / elapsed
    local secsToOOM   = curMana / burnPerSec
    return curMana / maxMana, secsToOOM
end

-- ─── Priority update ──────────────────────────────────────────
local function GetActiveKey(now, db)
    local mana    = UnitPower("player", Enum.PowerType.Mana)
    local maxMana = UnitPowerMax("player", Enum.PowerType.Mana)
    local manaPct = maxMana > 0 and (mana / maxMana) or 1

    if spec == "ARCANE" then
        -- Evocation if critically low
        if manaPct < ABX4_MANA_PCT then
            local evoCD = SR.SpellCD("Evocation")
            if evoCD == 0 then
                return "EVOC", SR.Col("ff4444", "OOM!")
            end
        end

        -- Arcane Power if available
        local apCD = SR.SpellCD("Arcane Power")
        if apCD == 0 then
            return "APOW", SR.Col("55ff55", "READY")
        end

        -- Presence of Mind if available
        local pomCD = SR.SpellCD("Presence of Mind")
        if pomCD == 0 then
            return "POM", SR.Col("55ff55", "READY")
        end

        -- Dump stacks → Arcane Missiles at 4 stacks or if low mana
        local stacksUp = (abStackExpiry > now) and abStacks or 0
        if stacksUp >= 4 or manaPct < AM_MANA_PCT then
            local pct, toom = ForecastMana(now)
            local sub = pct and (string.format("%.0f%% mana", manaPct * 100)) or ""
            return "AM", SR.Col("55aaff", sub)
        end

        -- Mana warning row
        local _, toom = ForecastMana(now)
        if toom and toom < 30 then
            return "MANA", SR.Col("ffaa33", SR.Fmt(toom) .. " OOM")
        end

        -- Build stacks
        local stackStr = stacksUp > 0 and ("x" .. stacksUp) or "x0"
        return "AB", SR.Col("aaaaff", stackStr)

    elseif spec == "FIRE" then
        -- Combustion if available
        local combCD = SR.SpellCD("Combustion")
        if combCD == 0 then
            return "COMB", SR.Col("55ff55", "READY")
        end

        -- Maintain 5× Improved Scorch debuff
        local scorchNow = scorchStacks < 5 or (scorchExpiry - now) < 3
        if scorchNow then
            local status = scorchStacks < 5
                and SR.Col("ff4444", tostring(scorchStacks) .. " stk")
                or SR.Col("ffaa33", SR.Fmt(scorchExpiry - now))
            return "SCORCH", status
        end

        -- Fire Blast if available (instant, weave in)
        local fbCD = SR.SpellCD("Fire Blast")
        if fbCD == 0 then
            return "FBLAST", SR.Col("55ff55", "READY")
        end

        return "FIREBALL", SR.Col("559955", "spam")

    else -- FROST
        -- Brain Freeze proc: free instant Frostfire Bolt
        if brainFreeze then
            return "PROC", SR.Col("ffff55", "PROC!")
        end

        -- Icy Veins
        local ivCD = SR.SpellCD("Icy Veins")
        if ivCD == 0 then
            return "IVEIN", SR.Col("55ff55", "READY")
        end

        -- Water Elemental
        local weCD = SR.SpellCD("Summon Water Elemental")
        if weCD == 0 and not UnitExists("pet") then
            return "WELEM", SR.Col("55ffff", "READY")
        end

        -- Cold Snap if Icy Veins is on CD (reset it)
        local csCD = SR.SpellCD("Cold Snap")
        if csCD == 0 and ivCD > 60 then
            return "CSNAP", SR.Col("55ffff", "USE→IV")
        end

        return "FBOLT", SR.Col("559955", "spam")
    end
end

function M:Update(now, db)
    if not rows[1] then return end
    local activeKey, statusStr = GetActiveKey(now, db)

    -- Mana forecast annotation for the MANA row (Arcane)
    local _, toom = ForecastMana(now)

    for _, row in ipairs(rows) do
        local isActive = (row.key == activeKey)
        local st = ""
        if isActive then
            st = statusStr
        elseif spec == "ARCANE" then
            if row.key == "AM" then
                local stk = (abStackExpiry > now) and abStacks or 0
                st = stk > 0 and SR.Col("888888", "x" .. stk) or ""
            elseif row.key == "APOW" then
                local cd = SR.SpellCD("Arcane Power")
                st = cd > 0 and SR.Col("888888", SR.Fmt(cd)) or SR.Col("55ff55", "READY")
            elseif row.key == "MANA" then
                if toom then
                    local pct = UnitPower("player", Enum.PowerType.Mana) / UnitPowerMax("player", Enum.PowerType.Mana)
                    st = SR.Col("888888", string.format("%.0f%% / %s", pct*100, SR.Fmt(toom)))
                end
            end
        elseif spec == "FIRE" then
            if row.key == "COMB" then
                local cd = SR.SpellCD("Combustion")
                st = cd > 0 and SR.Col("888888", SR.Fmt(cd)) or SR.Col("55ff55", "READY")
            elseif row.key == "SCORCH" then
                st = SR.Col("888888", scorchStacks .. " stk")
            end
        elseif spec == "FROST" then
            if row.key == "IVEIN" then
                local cd = SR.SpellCD("Icy Veins")
                st = cd > 0 and SR.Col("888888", SR.Fmt(cd)) or SR.Col("55ffff", "READY")
            elseif row.key == "WELEM" then
                local cd = SR.SpellCD("Summon Water Elemental")
                st = cd > 0 and SR.Col("888888", SR.Fmt(cd)) or ""
            end
        end
        SR.SetRowState(row, isActive, st)
    end

    SR.UpdateSpotlight(currentRows, activeKey, statusStr)
    SR.SetModeLabel(SR.Col("88ccff", spec and spec:sub(1, 3) or "???"))
end

-- ─── Events ───────────────────────────────────────────────────
function M:OnEvent(event, arg1)
    if event == "PLAYER_ENTERING_WORLD" or event == "ZONE_CHANGED_NEW_AREA"
    or event == "CHARACTER_POINTS_CHANGED" then
        local newSpec = DetectSpec()
        if newSpec ~= spec then
            spec = newSpec
            abStacks = 0; abStackExpiry = 0
            scorchStacks = 0; scorchExpiry = 0
            brainFreeze = false
        end
    elseif event == "PLAYER_REGEN_DISABLED" then
        -- Entered combat
        combatStart = GetTime()
        manaAtStart = UnitPower("player", Enum.PowerType.Mana)
    elseif event == "PLAYER_REGEN_ENABLED" then
        combatStart = nil; manaAtStart = nil
    elseif event == "PLAYER_TARGET_CHANGED" then
        scorchStacks = 0; scorchExpiry = 0
        self:ScanAll()
    elseif event == "COMBAT_LOG_EVENT_UNFILTERED" then
        local _, subEvent, _, srcGUID, _, _,
              dstGUID, _, _, spellId, spellName, _, auraType = CombatLogGetCurrentEventInfo()
        local pGUID = UnitGUID("player")

        if subEvent == "SPELL_AURA_APPLIED" or subEvent == "SPELL_AURA_REFRESH" then
            -- Track Arcane Blast stack debuff on player
            if spellName == "Arcane Blast" and dstGUID == pGUID then
                abStacks = math.min(4, abStacks + 1)
                abStackExpiry = GetTime() + 8  -- AB debuff lasts 8s
            end
            -- Track Improved Scorch debuff on target
            if spellName == "Fire Vulnerability" and srcGUID == pGUID then
                scorchStacks = math.min(5, scorchStacks + 1)
                scorchExpiry = GetTime() + 30
            end
            -- Track Brain Freeze proc on player
            if spellName == "Brain Freeze" and dstGUID == pGUID then
                brainFreeze = true
            end
        elseif subEvent == "SPELL_AURA_REMOVED" then
            if spellName == "Arcane Blast" and dstGUID == pGUID then
                abStacks = 0; abStackExpiry = 0
            end
            if spellName == "Fire Vulnerability" and dstGUID ~= pGUID then
                scorchStacks = 0; scorchExpiry = 0
            end
            if spellName == "Brain Freeze" and dstGUID == pGUID then
                brainFreeze = false
            end
        elseif subEvent == "SPELL_AURA_APPLIED_DOSE" then
            if spellName == "Arcane Blast" and dstGUID == pGUID then
                local _, _, _, _, _, _, _, _, _, _, _, _, _, amount = CombatLogGetCurrentEventInfo()
                abStacks = amount or math.min(4, abStacks + 1)
                abStackExpiry = GetTime() + 8
            end
            if spellName == "Fire Vulnerability" and srcGUID == pGUID then
                local _, _, _, _, _, _, _, _, _, _, _, _, _, amount = CombatLogGetCurrentEventInfo()
                scorchStacks = math.min(5, amount or (scorchStacks + 1))
                scorchExpiry = GetTime() + 30
            end
        elseif subEvent == "SPELL_CAST_SUCCESS" then
            -- Casting Frostfire Bolt consumes Brain Freeze
            if (spellName == "Frostfire Bolt") and srcGUID == pGUID then
                brainFreeze = false
            end
            -- Casting Arcane Missiles resets AB stacks
            if spellName == "Arcane Missiles" and srcGUID == pGUID then
                abStacks = 0; abStackExpiry = 0
            end
        end
    end
end

function M:RegisterEvents()
    SR.RegisterEvent("COMBAT_LOG_EVENT_UNFILTERED")
    SR.RegisterEvent("PLAYER_TARGET_CHANGED")
    SR.RegisterEvent("PLAYER_REGEN_DISABLED")
    SR.RegisterEvent("PLAYER_REGEN_ENABLED")
    SR.RegisterEvent("CHARACTER_POINTS_CHANGED")
end

function M:ScanAll()
    if not spec then spec = DetectSpec() end
    if not UnitExists("target") then return end

    -- Scan for Improved Scorch debuff on target
    scorchStacks = 0; scorchExpiry = 0
    local i = 1
    while true do
        local name, _, count, _, _, expires, caster = UnitDebuff("target", i)
        if not name then break end
        if name == "Fire Vulnerability" then
            scorchStacks = count or 0
            scorchExpiry = expires or 0
        end
        i = i + 1
    end

    -- Scan for AB stack buff on player and Brain Freeze
    abStacks = 0; abStackExpiry = 0; brainFreeze = false
    local j = 1
    while true do
        local name, _, count, _, _, expires = UnitBuff("player", j)
        if not name then break end
        if name == "Arcane Blast" then
            abStacks = count or 1
            abStackExpiry = expires or 0
        end
        if name == "Brain Freeze" then
            brainFreeze = true
        end
        j = j + 1
    end
end

SR.RegisterModule("MAGE", M)
