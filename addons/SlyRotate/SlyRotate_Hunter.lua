-- ============================================================
-- SlyRotate_Hunter — Beast Mastery / Marksmanship / Survival
-- TBC Anniversary (Interface 20505)
--
-- BM:  Bestial Wrath + Kill Command + Arcane Shot + Steady
-- MM:  Aimed Shot + Multi-Shot + Arcane Shot + Steady
-- SV:  Explosive Trap + Expose Weakness + Arcane/Steady
--      Also tracks Aspect (Hawk vs Viper mana warning)
-- ============================================================

local M = {}

M.classLabel = "Hunter"
M.headerIcon = "Interface\\Icons\\Ability_Hunter_BeastMastery"
M.specKeys   = { "BM", "MM", "SURVIVAL" }

-- ─── Icons ───────────────────────────────────────────────────
local ICO = {
    BestialWrath   = "Interface\\Icons\\Ability_Hunter_BestialWrath",
    KillCommand    = "Interface\\Icons\\Ability_Hunter_KillCommand",
    ArcaneShot     = "Interface\\Icons\\Ability_Impalingbolt",
    SteadyShot     = "Interface\\Icons\\Ability_Hunter_SteadyShot",
    MultiShot      = "Interface\\Icons\\Ability_UpgradeMoonGlaive",
    AimedShot      = "Interface\\Icons\\Inv_Spellbook_03",
    TrueshotAura   = "Interface\\Icons\\Ability_Hunter_TrueshotAura",
    RapidFire      = "Interface\\Icons\\Ability_Hunter_RapidKilling",
    WyvernSting    = "Interface\\Icons\\Ability_Hunter_WyvernSting",
    ExplosiveTrap  = "Interface\\Icons\\Spell_Fire_Selfdestruct",
    ExposeWeakness = "Interface\\Icons\\Ability_Hunter_ExposeWeakness",
    HawkAspect     = "Interface\\Icons\\Spell_Nature_AgioOfStamina",
    ViperAspect    = "Interface\\Icons\\Ability_Hunter_AspectOfTheViper",
    PetAttack      = "Interface\\Icons\\Ability_Physical_TauntEye",
}

-- ─── Row definitions ─────────────────────────────────────────
local ROWS_BM = {
    { key="BW",     label="Bestial Wrath",   icon=ICO.BestialWrath,  color={0.95, 0.5, 0.2} },
    { key="RF",     label="Rapid Fire",      icon=ICO.RapidFire,     color={1.0, 0.8, 0.3} },
    { key="KC",     label="Kill Command",    icon=ICO.KillCommand,   color={0.9, 0.3, 0.2} },
    { key="ARCS",   label="Arcane Shot",     icon=ICO.ArcaneShot,    color={0.6, 0.4, 0.9} },
    { key="STEADY", label="Steady Shot",     icon=ICO.SteadyShot,    color={0.5, 0.8, 0.5} },
    { key="VIPER",  label="→ Aspect: Viper", icon=ICO.ViperAspect,   color={0.9, 0.9, 0.3} },
}

local ROWS_MM = {
    { key="RF",     label="Rapid Fire",      icon=ICO.RapidFire,     color={1.0, 0.8, 0.3} },
    { key="AIMED",  label="Aimed Shot",      icon=ICO.AimedShot,     color={0.9, 0.6, 0.2} },
    { key="MULTI",  label="Multi-Shot",      icon=ICO.MultiShot,     color={0.7, 0.5, 0.9} },
    { key="ARCS",   label="Arcane Shot",     icon=ICO.ArcaneShot,    color={0.6, 0.4, 0.9} },
    { key="STEADY", label="Steady Shot",     icon=ICO.SteadyShot,    color={0.5, 0.8, 0.5} },
    { key="TSA",    label="Trueshot Aura ✓", icon=ICO.TrueshotAura,  color={0.9, 0.8, 0.4} },
    { key="VIPER",  label="→ Aspect: Viper", icon=ICO.ViperAspect,   color={0.9, 0.9, 0.3} },
}

local ROWS_SURVIVAL = {
    { key="RF",     label="Rapid Fire",      icon=ICO.RapidFire,     color={1.0, 0.8, 0.3} },
    { key="EW",     label="Expose Weakness", icon=ICO.ExposeWeakness,color={0.8, 0.7, 0.3} },
    { key="ETRAP",  label="Explosive Trap",  icon=ICO.ExplosiveTrap, color={0.9, 0.4, 0.1} },
    { key="WSTING", label="Wyvern Sting",    icon=ICO.WyvernSting,   color={0.5, 0.8, 0.8} },
    { key="ARCS",   label="Arcane Shot",     icon=ICO.ArcaneShot,    color={0.6, 0.4, 0.9} },
    { key="STEADY", label="Steady Shot",     icon=ICO.SteadyShot,    color={0.5, 0.8, 0.5} },
    { key="VIPER",  label="→ Aspect: Viper", icon=ICO.ViperAspect,   color={0.9, 0.9, 0.3} },
}
M.specRows = { BM = ROWS_BM, MM = ROWS_MM, SURVIVAL = ROWS_SURVIVAL }
-- ─── Module state ─────────────────────────────────────────────
local spec        = nil
local currentRows = nil
local rows        = {}

local VIPER_MANA_THRESH = 0.40   -- swap to Viper below 40%
local HAWK_MANA_THRESH  = 0.80   -- swap back to Hawk above 80%

local inViperAspect = false
local tsaActive     = false      -- Trueshot Aura buffed on player

-- ─── Spec detection ───────────────────────────────────────────
local function DetectSpec()
    if GetSpellInfo("Bestial Wrath") then return "BM" end
    if GetSpellInfo("Aimed Shot")    then return "MM" end
    return "SURVIVAL"
end

-- ─── Required API ─────────────────────────────────────────────
function M:GetBodyHeight(ROW_H)
    local n = (spec == "BM")       and #ROWS_BM
           or (spec == "MM")       and #ROWS_MM
           or #ROWS_SURVIVAL
    return n * (ROW_H + 1) + 4
end

function M:GetHeaderText()
    local col  = SR.Col
    local base = col("aacc55", "HUNTER")
    if spec == "BM"       then return base .. " " .. col("ff9944", "Beast Mastery")   end
    if spec == "MM"       then return base .. " " .. col("88cc88", "Marksmanship")    end
    return base .. " " .. col("ccbb44", "Survival")
end

function M:Build(body)
    for _, f in ipairs(rows) do f:Hide() end
    rows = {}

    currentRows = (spec == "BM")       and ROWS_BM
               or (spec == "MM")       and ROWS_MM
               or ROWS_SURVIVAL

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
    local mana    = UnitMana("player")
    local maxMana = UnitManaMax("player")
    local manaPct = maxMana > 0 and (mana / maxMana) or 1

    -- Aspect of the Viper mana management
    if manaPct < VIPER_MANA_THRESH and not inViperAspect then
        return "VIPER", SR.Col("ffff33", string.format("%.0f%%", manaPct*100))
    end

    if spec == "BM" then
        -- Bestial Wrath on CD
        local bwCD = SR.SpellCD("Bestial Wrath")
        if bwCD == 0 then
            return "BW", SR.Col("55ff55", "READY")
        end
        -- Rapid Fire
        local rfCD = SR.SpellCD("Rapid Fire")
        if rfCD == 0 then
            return "RF", SR.Col("55ff55", "READY")
        end
        -- Kill Command (requires pet crits — just show when available)
        local kcCD = SR.SpellCD("Kill Command")
        if kcCD == 0 then
            return "KC", SR.Col("55ff55", "READY")
        end
        -- Arcane Shot on CD
        local asCD = SR.SpellCD("Arcane Shot")
        if asCD == 0 then
            return "ARCS", SR.Col("55ff55", "READY")
        end
        return "STEADY", SR.Col("559955", "filler")

    elseif spec == "MM" then
        -- Check Trueshot Aura is active
        if not tsaActive then
            return "TSA", SR.Col("ffaa33", "MISSING")
        end
        -- Rapid Fire
        local rfCD = SR.SpellCD("Rapid Fire")
        if rfCD == 0 then
            return "RF", SR.Col("55ff55", "READY")
        end
        -- Aimed Shot
        local aimedCD = SR.SpellCD("Aimed Shot")
        if aimedCD == 0 then
            return "AIMED", SR.Col("55ff55", "READY")
        end
        -- Multi-Shot
        local multiCD = SR.SpellCD("Multi-Shot")
        if multiCD == 0 then
            return "MULTI", SR.Col("55ff55", "READY")
        end
        -- Arcane Shot
        local asCD = SR.SpellCD("Arcane Shot")
        if asCD == 0 then
            return "ARCS", SR.Col("55ff55", "READY")
        end
        return "STEADY", SR.Col("559955", "filler")

    else -- SURVIVAL
        -- Rapid Fire
        local rfCD = SR.SpellCD("Rapid Fire")
        if rfCD == 0 then
            return "RF", SR.Col("55ff55", "READY")
        end
        -- Explosive Trap (lay it early)
        local etCD = SR.SpellCD("Explosive Trap")
        if etCD == 0 then
            return "ETRAP", SR.Col("ff6633", "READY")
        end
        -- Wyvern Sting (CC / opener)
        local wsCD = SR.SpellCD("Wyvern Sting")
        if wsCD == 0 then
            return "WSTING", SR.Col("55ffff", "READY")
        end
        -- Arcane Shot
        local asCD = SR.SpellCD("Arcane Shot")
        if asCD == 0 then
            return "ARCS", SR.Col("55ff55", "READY")
        end
        return "STEADY", SR.Col("559955", "filler")
    end
end

function M:Update(now, db)
    if not rows[1] then return end
    local activeKey, statusStr = GetActiveKey(now, db)

    local mana = UnitMana("player")
    local maxMana = UnitManaMax("player")
    local manaPct = maxMana > 0 and (mana / maxMana) or 1

    for _, row in ipairs(rows) do
        local isActive = (row.key == activeKey)
        local st = isActive and statusStr or ""
        if not isActive then
            if row.key == "VIPER" then
                if inViperAspect then
                    st = SR.Col("33ffcc", string.format("%.0f%%", manaPct*100))
                elseif manaPct < VIPER_MANA_THRESH then
                    st = SR.Col("ff4444", string.format("%.0f%%", manaPct*100))
                end
            elseif row.key == "BW" then
                local cd = SR.SpellCD("Bestial Wrath")
                st = cd > 0 and SR.Col("888888", SR.Fmt(cd)) or SR.Col("55ff55", "READY")
            elseif row.key == "RF" then
                local cd = SR.SpellCD("Rapid Fire")
                st = cd > 0 and SR.Col("888888", SR.Fmt(cd)) or SR.Col("55ff55", "READY")
            elseif row.key == "TSA" then
                st = tsaActive and SR.Col("55ff55", "✓") or SR.Col("ff4444", "OFF")
            end
        end
        SR.SetRowState(row, isActive, st)
    end

    SR.UpdateSpotlight(currentRows, activeKey, statusStr)
    SR.SetModeLabel(SR.Col("aacc55", spec or "???"))
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

    -- Scan player buffs for aspects / Trueshot Aura
    inViperAspect = false
    tsaActive     = false
    local i = 1
    while true do
        local name = UnitBuff("player", i)
        if not name then break end
        if name == "Aspect of the Viper" then inViperAspect = true end
        if name == "Trueshot Aura"        then tsaActive = true end
        i = i + 1
    end
end

SR.RegisterModule("HUNTER", M)
