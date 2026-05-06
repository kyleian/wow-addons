-- ============================================================
-- SlyRotate — Shaman Module
-- Enhancement: Stormstrike → Earth Shock GCD loop, weapon procs,
--              totem CD tracking (WFT window handled by SlySuite_TotemTwist).
-- Elemental: Flame Shock DoT → Lightning Bolt / Chain Lightning loop,
--            Elemental Mastery / Nature's Swiftness CD tracking.
-- ============================================================

local S = {}

S.classKey   = "SHAMAN"
S.classLabel = "Shaman"
S.headerIcon = "Interface\\Icons\\Spell_Nature_LightningShield"
S.specKeys   = { "ENHANCE", "ELEMENTAL" }
S.specLabels = { ENHANCE="Enhancement", ELEMENTAL="Elemental" }

-- ─── Icons ──────────────────────────────────────────────────
local ICO = {
    SS        = "Interface\\Icons\\Spell_Nature_StormStrike",
    ES        = "Interface\\Icons\\Spell_Nature_EarthShock",
    FS        = "Interface\\Icons\\Spell_Fire_FlameTongue",
    WF        = "Interface\\Icons\\Spell_Nature_CallLightning",
    MGTM      = "Interface\\Icons\\Spell_Nature_ManaRegenTotem",
    NS        = "Interface\\Icons\\Spell_Nature_RavenForm",    -- Nature's Swiftness
    SR        = "Interface\\Icons\\Spell_Nature_ShamanisticRage",
    LB        = "Interface\\Icons\\Spell_Lightning_LightningBolt01",
    CL        = "Interface\\Icons\\Spell_Lightning_LightningBoltBlue",
    EM        = "Interface\\Icons\\Spell_Nature_elementalshields",
    PROC      = "Interface\\Icons\\Spell_Nature_TauntOther",   -- Windfury proc indicator
    LOCAL_DEF = "Interface\\Icons\\Spell_Nature_ThunderClap",
    WFT       = "Interface\\Icons\\Spell_Nature_WinFury",      -- Windfury Totem
    SEAR      = "Interface\\Icons\\Spell_Fire_SearingTotem",   -- Searing Totem
}

-- ─── Enhancement priority row definitions ────────────────────
-- TBC Enhancement loop (weapon MH = Windfury, OH = Flametongue):
--   1. WFT+GoA totem twist     (drop WFT then GoA immediately; refresh ~120s)
--   2. Stormstrike on CD       (12s CD)
--   3. Flame Shock             (DoT uptime — apply/refresh before Earth Shock)
--   4. Earth Shock on CD       (6s CD)
--   5. Searing Totem           (fire totem for DPS, 60s)
--   6. Shamanistic Rage        (big CD, passive indicator)
--   7. Windfury proc window    (tracked from combat log)
local ENHANCE_ROWS = {
    { key="TWIST",  label="WFT + GoA  (twist)",           icon=ICO.WFT,  color={1.00,0.82,0.22} },
    { key="SS",     label="Stormstrike",                  icon=ICO.SS,   color={0.38,0.84,1.00} },
    { key="FS",     label="Flame Shock  (DoT)",           icon=ICO.FS,   color={1.00,0.48,0.12} },
    { key="ES",     label="Earth Shock",                  icon=ICO.ES,   color={0.55,0.88,0.55} },
    { key="SEARING",label="Fire Totem",                  icon=ICO.SEAR, color={0.90,0.35,0.10} },
    { key="SR",     label="Shamanic Rage  (CD)",          icon=ICO.SR,   color={0.60,0.25,0.90} },
    { key="WF_PROC",label="Windfury Proc!",               icon=ICO.PROC, color={1.00,0.95,0.20} },
}

-- ─── Elemental priority row definitions ──────────────────────
-- TBC Elemental loop:
--   1. Elemental Mastery   — use on CD for instant LB cast
--   2. Nature's Swiftness  — use on CD for instant CL (multi-target burst)
--   3. Flame Shock         — maintain DoT (12s duration, 6s CD)
--   4. Chain Lightning     — 3+ targets (3s CD)
--   5. Lightning Bolt      — primary filler spam
local ELEMENTAL_ROWS = {
    { key="EM",  label="Elemental Mastery  (CD)",  icon=ICO.EM, color={1.00,0.80,0.10} },
    { key="NS",  label="Nature's Swiftness  (CD)", icon=ICO.NS, color={0.45,1.00,0.45} },
    { key="FS",  label="Flame Shock  (DoT)",       icon=ICO.FS, color={1.00,0.48,0.12} },
    { key="CL",  label="Chain Lightning  (3+ AoE)",icon=ICO.CL, color={0.38,0.70,1.00} },
    { key="LB",  label="Lightning Bolt  (spam)",   icon=ICO.LB, color={0.80,0.80,1.00} },
}

-- ─── Combat state ────────────────────────────────────────────
local playerMana      = 0
local playerMaxMana   = 1
local playerHP        = 1.0

-- Enhancement state
local flameshockExpiry  = 0
local srExpiry          = 0
local nsExpiry          = 0
local wfProcExpiry      = 0

-- Totem twist state (10-second WFT aura cycle — mirrors SlySuite_TotemTwist logic)
-- WFT totem pulses a 10-second "Windfury Totem" aura on nearby melee.
-- Twist: drop WFT → ~8s normal rotation → drop GoA → IMMEDIATELY re-drop WFT.
local WFT_AURA_DUR    = 10.0   -- WFT aura lasts 10s on party melee
local TWIST_URGENT_AT = 2.0    -- flag GoA/WFT drop when < 2s of aura remain
local twistState      = "idle" -- idle | armed | urgent | expired
local wftDropTime     = 0      -- GetTime() when WFT last successfully cast
local goatDropTime    = 0      -- GetTime() when GoA last successfully cast

-- Fire totem state (slot 1: Searing, Magma, Fire Nova, Fire Elemental)
local fireTotemName    = nil
local fireTotemExpiry  = 0

-- Elemental state
local emExpiry          = 0   -- Elemental Mastery buff on player (instant next cast)
-- (Flame shock / NS shared with enhance locals above)

-- ─── Frame references ────────────────────────────────────────
local enhContainer   = nil
local elemContainer  = nil
local enhRowFrames   = {}
local elemRowFrames  = {}

-- ─── Module API ──────────────────────────────────────────────
function S:GetBodyHeight(ROW_H)
    return math.max(#ENHANCE_ROWS, #ELEMENTAL_ROWS) * (ROW_H + 1)
end

function S:GetHeaderText()
    return SR.Col("88ccff","SHAMAN") .. " " .. SR.Col("888888","ROTATION")
end

function S:Build(body)
    local FW   = SR.FRAME_W
    local RH   = SR.ROW_H
    local enhH  = #ENHANCE_ROWS  * (RH + 1)
    local elemH = #ELEMENTAL_ROWS * (RH + 1)

    enhContainer = CreateFrame("Frame", nil, body)
    enhContainer:SetSize(FW, enhH)
    enhContainer:SetPoint("TOPLEFT", body, "TOPLEFT", 0, 0)
    enhContainer:Hide()
    enhRowFrames = {}
    for i, rd in ipairs(ENHANCE_ROWS) do
        rd._idx = i
        enhRowFrames[i] = SR.BuildRow(enhContainer, rd, i)
    end

    elemContainer = CreateFrame("Frame", nil, body)
    elemContainer:SetSize(FW, elemH)
    elemContainer:SetPoint("TOPLEFT", body, "TOPLEFT", 0, 0)
    elemContainer:Hide()
    elemRowFrames = {}
    for i, rd in ipairs(ELEMENTAL_ROWS) do
        rd._idx = i
        elemRowFrames[i] = SR.BuildRow(elemContainer, rd, i)
    end
end

-- ─── Spec detection ──────────────────────────────────────────
-- Stormstrike is the 40-pt Enhancement talent.
-- Elemental Mastery is the 31-pt Elemental talent.
local function DetectSpec(db)
    if db and db.classes.SHAMAN and db.classes.SHAMAN.specOverride then
        return db.classes.SHAMAN.specOverride
    end
    if GetSpellInfo("Stormstrike")       then return "ENHANCE"   end
    if GetSpellInfo("Elemental Mastery") then return "ELEMENTAL" end
    return "ENHANCE"  -- default: most common TBC Shaman spec
end

-- ─── Helpers ─────────────────────────────────────────────────
local Col     = function(...) return SR.Col(...) end
local Fmt     = function(...) return SR.Fmt(...) end
local SpellCD = function(...) return SR.SpellCD(...) end

-- ─── Scanners ────────────────────────────────────────────────
local function ScanTargetDebuffs()
    flameshockExpiry = 0
    if not UnitExists("target") then return end
    local i = 1
    while true do
        local name, _, _, _, _, expiry = UnitDebuff("target", i, "PLAYER")
        if not name then break end
        if name == "Flame Shock" then flameshockExpiry = expiry or 0 end
        i = i + 1
    end
end

local function ScanPlayerBuffs()
    srExpiry = 0; nsExpiry = 0; emExpiry = 0; wfProcExpiry = 0
    local i = 1
    while true do
        local name, _, _, _, _, expiry = UnitBuff("player", i)
        if not name then break end
        if name == "Shamanistic Rage"   then srExpiry = expiry or 0 end
        if name == "Nature's Swiftness" then nsExpiry = expiry or 0 end
        if name == "Elemental Mastery"  then emExpiry = expiry or 0 end
        if name == "Windfury Attack"    then wfProcExpiry = expiry or 0 end
        i = i + 1
    end
end

local function ScanFireTotem()
    local haveFire, fireName, fireStart, fireDur = GetTotemInfo(1)
    if haveFire and fireName and fireName ~= "" and fireStart and fireDur and fireDur > 0 then
        fireTotemName   = fireName
        fireTotemExpiry = fireStart + fireDur
    else
        fireTotemName   = nil
        fireTotemExpiry = 0
    end
end

function S:ScanAll()
    ScanTargetDebuffs()
    ScanPlayerBuffs()
    ScanFireTotem()
end

-- ─── Enhancement update ──────────────────────────────────────
local function UpdateEnhance(now)
    local mana    = playerMana
    local maxMana = math.max(1, playerMaxMana)
    local manaP   = mana / maxMana

    local ssCD    = SpellCD("Stormstrike")
    local esCD    = SpellCD("Earth Shock")
    local fsL     = flameshockExpiry > 0 and math.max(0, flameshockExpiry - now) or 0
    local srL     = srExpiry > 0 and math.max(0, srExpiry - now) or 0
    local srCD    = SpellCD("Shamanistic Rage")
    local wfL     = wfProcExpiry > 0 and math.max(0, wfProcExpiry - now) or 0

    -- ── Twist state machine (10-second WFT aura cycle) ──
    -- WFT is cast → "armed" (aura ticking down from 10s)
    -- When aura nears expiry (<2s) → urgent to drop GoA
    -- GoA is cast while armed → "urgent" (aura burning, re-drop WFT immediately)
    -- WFT re-cast while urgent → back to "armed" (cycle continues)
    -- Aura expires without GoA → "expired" (missed window, restart)
    local wftAuraLeft = 0
    if twistState == "armed" or twistState == "urgent" then
        wftAuraLeft = math.max(0, WFT_AURA_DUR - (now - wftDropTime))
        if wftAuraLeft <= 0 then
            twistState  = "expired"
            wftAuraLeft = 0
        end
    end

    local twistIsBest =
        twistState == "idle"    or
        twistState == "expired" or
        twistState == "urgent"  or
        (twistState == "armed" and wftAuraLeft <= TWIST_URGENT_AT)

    -- ── Fire totem ──
    local fireL = fireTotemExpiry > 0 and math.max(0, fireTotemExpiry - now) or 0
    local isMagma    = fireTotemName and fireTotemName:find("Magma",     1, true)
    local isFireNova = fireTotemName and fireTotemName:find("Fire Nova", 1, true)
    local isElem     = fireTotemName and fireTotemName:find("Elemental", 1, true)
    -- Searing: refresh at <10s; Magma: refresh at <5s; Fire Nova: instant use, very short
    local fireDue = (not fireTotemName) or
                    (isMagma    and fireL < 5)  or
                    (not isMagma and not isFireNova and not isElem and fireL < 8)

    -- ── Priority ──
    local best
    if twistIsBest then
        best = "TWIST"
    elseif ssCD <= 0 then
        best = "SS"
    elseif esCD <= 0 and fsL > 2 then
        best = "ES"
    elseif fsL > 0 and fsL < 2 then
        best = "FS"
    elseif esCD <= 0 then
        best = "ES"
    elseif fsL == 0 then
        best = "FS"
    elseif fireDue then
        best = "SEARING"
    elseif ssCD <= esCD then
        best = "SS"
    else
        best = "ES"
    end

    local wfActive = wfL > 0

    for _, row in ipairs(enhRowFrames) do
        local k      = row.rowDef.key
        local active = (k == best) or (k == "WF_PROC" and wfActive)
        local s = ""

        if k == "TWIST" then
            if twistState == "idle" then
                s = Col("ff4444","START TWIST  ") .. Col("888888","drop WFT + GoA")
            elseif twistState == "expired" then
                s = Col("ff3333","EXPIRED!  ") .. Col("ff8844","drop WFT now")
            elseif twistState == "urgent" then
                s = Col("ff2222","WFT NOW!  ") .. Col("ffcc44", string.format("%.1fs", wftAuraLeft))
            elseif twistState == "armed" then
                if wftAuraLeft <= TWIST_URGENT_AT then
                    s = Col("ff8800","GoA NOW!  ") .. Col("ffcc44", string.format("%.1fs", wftAuraLeft))
                else
                    local goaIn = math.max(0, wftAuraLeft - TWIST_URGENT_AT)
                    s = Col("44cc44", string.format("%.1fs", wftAuraLeft)) ..
                        Col("888888","  GoA in " .. string.format("%.1fs", goaIn))
                end
            end

        elseif k == "SS" then
            if ssCD <= 0 then s = Col("44ff44","CAST NOW")
            else               s = Col("ff8844", Fmt(ssCD)) end

        elseif k == "FS" then
            if fsL == 0 then
                s = Col("ff4444","MISSING!")
            elseif fsL < 2 then
                s = Col("ff6622","REFRESH!  ") .. Col("ffcc44", Fmt(fsL))
            elseif fsL < 5 then
                s = Col("ffcc44", Fmt(fsL) .. "  ") .. Col("888888","refresh soon")
            else
                s = Col("44aa44", Fmt(fsL))
            end

        elseif k == "ES" then
            if esCD <= 0 then
                s = Col("44ff44","CAST NOW  ") ..
                    Col("888888", ssCD > 0 and ("SS " .. Fmt(ssCD)) or "SS READY")
            else
                s = Col("ff8844", Fmt(esCD)) ..
                    Col("555566", ssCD > 0 and ("  >> SS " .. Fmt(ssCD)) or "  >> SS READY")
            end

        elseif k == "SEARING" then
            if not fireTotemName then
                s = Col("ff4444","DROP SEARING  ") .. Col("888888","fire totem missing")
            elseif isElem then
                s = Col("ff8833","FE  ") .. Col("44cc44", Fmt(fireL))
            elseif isMagma then
                if fireL < 5 then
                    s = Col("ff6622","MAGMA SOON  ") .. Col("ffcc44", Fmt(fireL))
                else
                    s = Col("ff8844","Magma  ") .. Col("44aa44", Fmt(fireL))
                end
            elseif isFireNova then
                s = Col("ff4400","FNT  ") .. Col("ffcc44", Fmt(fireL))
            else
                -- Searing Totem
                if fireL < 8 then
                    s = Col("ff8844","SEARING SOON  ") .. Col("ffcc44", Fmt(fireL))
                else
                    s = Col("44aa44", Fmt(fireL))
                end
            end

        elseif k == "SR" then
            if srL > 0 then
                s = Col("cc44ff","ACTIVE  ") .. Col("aaaaaa", Fmt(srL))
            elseif srCD <= 0 then
                s = Col("aa44ff","READY  ") .. Col("888888","use now")
            else
                s = Col("555566","CD  ") .. Col("888888", Fmt(srCD))
            end

        elseif k == "WF_PROC" then
            if wfActive then s = Col("ffee00","PROC!  ") .. Col("888888", Fmt(wfL))
            else              s = Col("333344","--") end
        end

        SR.SetRowState(row, active, s)
    end

    local manaCol = manaP < 0.20 and "ff4444" or manaP < 0.40 and "ffcc44" or "4488ff"
    SR.SetModeLabel(
        Col("88ccff","ENHA") .. "  " ..
        Col(manaCol, string.format("%.0f%%", manaP * 100) .. "M"))

    local spotSt
    if best == "TWIST" then
        if twistState == "urgent" then
            spotSt = "WFT NOW!"
        elseif twistState == "armed" and wftAuraLeft <= TWIST_URGENT_AT then
            spotSt = "GoA NOW!"
        elseif twistState == "armed" then
            spotSt = string.format("%.1fs", wftAuraLeft)
        else
            spotSt = "START"
        end
    elseif best == "SS" then
        spotSt = ssCD <= 0 and "CAST" or Fmt(ssCD)
    elseif best == "FS" then
        spotSt = fsL > 0 and Fmt(fsL) or "MISSING"
    elseif best == "SEARING" then
        spotSt = fireL > 0 and Fmt(fireL) or "DROP"
    else
        spotSt = esCD <= 0 and "CAST" or Fmt(esCD)
    end
    SR.UpdateSpotlight(ENHANCE_ROWS, best, spotSt)
end

-- ─── Elemental update ────────────────────────────────────────
local function UpdateElemental(now)
    local mana    = playerMana
    local maxMana = math.max(1, playerMaxMana)
    local manaP   = mana / maxMana

    local emL    = emExpiry > 0 and math.max(0, emExpiry - now) or 0
    local emCD   = SpellCD("Elemental Mastery")
    local nsCD   = SpellCD("Nature's Swiftness")
    local nsL    = nsExpiry > 0 and math.max(0, nsExpiry - now) or 0
    local fsL    = flameshockExpiry > 0 and math.max(0, flameshockExpiry - now) or 0
    local clCD   = SpellCD("Chain Lightning")
    local lbUsable = IsUsableSpell and IsUsableSpell("Lightning Bolt")

    -- Use EM first if available — guarantees instant next LB cast
    -- NS: instant CL for AoE / burst (use after EM on pull)
    -- Flame Shock: maintain DoT for +20% crit to LB (Improved Flame Shock talent)
    -- Chain Lightning: use on 3+ targets
    -- Lightning Bolt: primary spam
    local best
    if emL == 0 and emCD <= 0 then
        best = "EM"    -- EM ready, use to make next LB instant
    elseif nsL == 0 and nsCD <= 0 then
        best = "NS"    -- NS ready, instant CL for burst
    elseif fsL == 0 or fsL < 2 then
        best = "FS"    -- DoT missing or about to expire
    elseif clCD <= 0 then
        best = "CL"    -- AoE / secondary
    else
        best = "LB"    -- primary spam
    end

    -- EM active: highlight next cast (LB or CL)
    local emActive = emL > 0

    for _, row in ipairs(elemRowFrames) do
        local k      = row.rowDef.key
        local active = (k == best) or (k == "LB" and emActive and best == "LB")
        local s = ""

        if k == "EM" then
            if emL > 0 then
                s = Col("ffdd44","ACTIVE  ") .. Col("888888","-> instant LB/CL")
            elseif emCD <= 0 then
                s = Col("44ff44","READY  ") .. Col("888888","use on pull")
            else
                s = Col("555566","CD  ") .. Col("888888", Fmt(emCD))
            end
        elseif k == "NS" then
            if nsL > 0 then
                s = Col("ccff88","ACTIVE  ") .. Col("aaaaaa", Fmt(nsL))
            elseif nsCD <= 0 then
                s = Col("44ff44","READY  ") .. Col("888888","instant CL")
            else
                s = Col("555566","CD  ") .. Col("888888", Fmt(nsCD))
            end
        elseif k == "FS" then
            if fsL == 0 then
                s = Col("ff4444","MISSING!")
            elseif fsL < 2 then
                s = Col("ff6622","REFRESH!  ") .. Col("ffcc44", Fmt(fsL))
            elseif fsL < 6 then
                s = Col("ffcc44", Fmt(fsL) .. "  ") .. Col("888888","refresh soon")
            else
                s = Col("44aa44", Fmt(fsL))
            end
        elseif k == "CL" then
            if clCD <= 0 then
                s = Col("44ff44","READY  ") .. Col("888888","3+ targets")
            else
                s = Col("ff8844", Fmt(clCD))
            end
        elseif k == "LB" then
            if emActive then
                s = Col("ffee00","INSTANT!  ") .. Col("aaaaaa","EM active")
            else
                s = Col("888888","spam")
            end
        end
        SR.SetRowState(row, active, s)
    end

    local manaCol = manaP < 0.20 and "ff4444" or manaP < 0.40 and "ffcc44" or "4488ff"
    SR.SetModeLabel(
        Col("88aaff","ELEM") .. "  " ..
        Col(manaCol, string.format("%.0f%%", manaP * 100) .. "M"))

    local spotSt = emActive and "INSTANT!" or (best == "FS" and (fsL > 0 and Fmt(fsL) or "MISSING") or "spam")
    SR.UpdateSpotlight(ELEMENTAL_ROWS, best, spotSt)
end

-- ─── Main update ─────────────────────────────────────────────
function S:Update(now, db)
    local classDb     = db.classes.SHAMAN or {}
    local specEnabled = classDb.specs or {}

    playerMana    = UnitPower("player", 0)       or 0
    playerMaxMana = UnitPowerMax("player", 0)    or 1
    playerHP      = UnitHealth("player") / math.max(1, UnitHealthMax("player"))

    local spec = DetectSpec(db)

    if specEnabled[spec] == false then
        if enhContainer  then enhContainer:Hide()  end
        if elemContainer then elemContainer:Hide() end
        SR.SetModeLabel(SR.Col("555566", spec .. " disabled"))
        SR.UpdateSpotlight(nil, nil, nil)
        return
    end

    if spec == "ENHANCE" then
        if enhContainer  then enhContainer:Show()  end
        if elemContainer then elemContainer:Hide() end
        UpdateEnhance(now)
    else
        if enhContainer  then enhContainer:Hide()  end
        if elemContainer then elemContainer:Show() end
        UpdateElemental(now)
    end
end

-- ─── Events ──────────────────────────────────────────────────
function S:OnEvent(event, arg1, arg2, arg3)
    if event == "PLAYER_TARGET_CHANGED" then
        ScanTargetDebuffs()
    elseif event == "UNIT_AURA" then
        if arg1 == "player" then ScanPlayerBuffs()    end
        if arg1 == "target"  then ScanTargetDebuffs() end
    elseif event == "PLAYER_TOTEM_UPDATE" then
        ScanFireTotem()
    elseif event == "UNIT_SPELLCAST_SUCCEEDED" then
        -- arg1=unit, arg2=castGUID, arg3=spellID  (TBC 2.5.x API)
        if arg1 ~= "player" then return end
        local spellName = arg3 and GetSpellInfo(arg3)
        if not spellName then return end

        if spellName == "Windfury Totem" then
            -- Arm the 10-second WFT aura window (mirrors TotemTwist addon logic)
            twistState  = "armed"
            wftDropTime = GetTime()

        elseif spellName == "Grace of Air Totem" then
            -- GoA dropped while armed → urgent countdown to re-drop WFT
            if twistState == "armed" then
                twistState   = "urgent"
                goatDropTime = GetTime()
            end

        elseif spellName == "Searing Totem"       or
               spellName == "Magma Totem"          or
               spellName == "Fire Nova Totem"      or
               spellName == "Fire Elemental Totem" then
            -- Fire totem cast — GetTotemInfo will update on the next PLAYER_TOTEM_UPDATE,
            -- but eagerly set the name so the row updates within this tick.
            fireTotemName = spellName
            -- expiry set by ScanFireTotem via PLAYER_TOTEM_UPDATE
        end
    end
end

function S:RegisterEvents()
    SR.RegisterEvent("PLAYER_TOTEM_UPDATE")
    SR.RegisterEvent("UNIT_SPELLCAST_SUCCEEDED")
end

-- ─── Register ────────────────────────────────────────────────
SR.RegisterModule("SHAMAN", S)
