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
}

-- ─── Enhancement priority row definitions ────────────────────
-- TBC Enhancement loop (weapon MH = Windfury, OH = Flametongue):
--   1. Stormstrike on CD       (12s CD)
--   2. Earth Shock on CD       (6s CD; purges targets' windfury if needed)
--   3. Flame Shock if expired  (DoT filler, renew ~12s)
-- Off-GCD indicators:
--   4. Shamanistic Rage        (big CD, passive indicator)
--   5. Nature's Swiftness      (utility CD indicator)
--   6. Windfury proc window    (tracked from combat log)
local ENHANCE_ROWS = {
    { key="SS",     label="Stormstrike",          icon=ICO.SS,   color={0.38,0.84,1.00} },
    { key="ES",     label="Earth Shock",          icon=ICO.ES,   color={0.55,0.88,0.55} },
    { key="FS",     label="Flame Shock  (DoT)",   icon=ICO.FS,   color={1.00,0.48,0.12} },
    { key="SR",     label="Shamanic Rage  (CD)",  icon=ICO.SR,   color={0.60,0.25,0.90} },
    { key="NS",     label="Nature's Swiftness",   icon=ICO.NS,   color={0.45,1.00,0.45} },
    { key="WF_PROC",label="Windfury Proc!",       icon=ICO.PROC, color={1.00,0.95,0.20} },
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
local flameshockExpiry  = 0   -- on target
local srExpiry          = 0   -- Shamanistic Rage buff on player
local nsExpiry          = 0   -- Nature's Swiftness buff on player (if consumed → 0)
local wfProcExpiry      = 0   -- Windfury Attack proc window (~1.5s estimate)

-- Elemental state
local emExpiry          = 0   -- Elemental Mastery buff on player (instant next)
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

function S:ScanAll()
    ScanTargetDebuffs()
    ScanPlayerBuffs()
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
    local nsReady = nsExpiry == 0 and SpellCD("Nature's Swiftness") <= 0  -- ready but not consumed
    local wfL     = wfProcExpiry > 0 and math.max(0, wfProcExpiry - now) or 0

    -- Priority: Stormstrike → Earth Shock → Flame Shock refresh
    local best
    if ssCD <= 0 then
        best = "SS"
    elseif esCD <= 0 then
        best = "ES"
    elseif fsL == 0 then
        best = "FS"       -- apply or reapply DoT
    elseif fsL < 3 then
        best = "FS"       -- refresh before it falls off
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

        if k == "SS" then
            if ssCD <= 0 then
                s = Col("44ff44","CAST NOW")
            else
                s = Col("ff8844", Fmt(ssCD))
            end
        elseif k == "ES" then
            if esCD <= 0 then
                s = Col("44ff44","CAST NOW")
            else
                local seqStr = ssCD > 0 and ("  >> SS " .. Fmt(ssCD)) or "  >> SS READY"
                s = Col("ff8844", Fmt(esCD)) .. Col("555566", seqStr)
            end
        elseif k == "FS" then
            if fsL == 0 then
                s = Col("ff4444","MISSING!")
            elseif fsL < 3 then
                s = Col("ff6622","REFRESH!  ") .. Col("ffcc44", Fmt(fsL))
            elseif fsL < 6 then
                s = Col("ffcc44", Fmt(fsL) .. "  ") .. Col("888888","refresh soon")
            else
                s = Col("44aa44", Fmt(fsL))
            end
        elseif k == "SR" then
            if srL > 0 then
                s = Col("cc44ff","ACTIVE  ") .. Col("aaaaaa", Fmt(srL))
            elseif srCD <= 0 then
                s = Col("aa44ff","READY  ") .. Col("888888","use now")
            else
                s = Col("555566","CD  ") .. Col("888888", Fmt(srCD))
            end
        elseif k == "NS" then
            if nsReady then
                s = Col("44ff44","READY  ") .. Col("888888","instant CL on pull")
            elseif nsExpiry > 0 then
                local nsL = math.max(0, nsExpiry - now)
                s = Col("ccff88","ACTIVE  ") .. Col("aaaaaa", Fmt(nsL))
            else
                local nsCD = SpellCD("Nature's Swiftness")
                if nsCD > 0 then
                    s = Col("555566","CD  ") .. Col("888888", Fmt(nsCD))
                else
                    s = Col("44ff44","READY")
                end
            end
        elseif k == "WF_PROC" then
            if wfActive then
                s = Col("ffee00","PROC!  ") .. Col("888888", Fmt(wfL))
            else
                s = Col("333344","—")
            end
        end
        SR.SetRowState(row, active, s)
    end

    local manaCol = manaP < 0.20 and "ff4444" or manaP < 0.40 and "ffcc44" or "4488ff"
    SR.SetModeLabel(
        Col("88ccff","ENHA") .. "  " ..
        Col(manaCol, string.format("%.0f%%", manaP * 100) .. "M"))

    local spotSt = ssCD <= 0 and "CAST" or Fmt(ssCD)
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
                s = Col("ffdd44","ACTIVE  ") .. Col("888888","→ instant LB/CL")
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
function S:OnEvent(event, arg1)
    if event == "PLAYER_TARGET_CHANGED" then
        ScanTargetDebuffs()
    elseif event == "UNIT_AURA" then
        if arg1 == "player" then ScanPlayerBuffs()    end
        if arg1 == "target"  then ScanTargetDebuffs() end
    end
end

function S:RegisterEvents()
    -- Core events (TARGET_CHANGED, UNIT_AURA) already registered by SlyRotate.lua
    -- No additional events needed for Shaman
end

-- ─── Register ────────────────────────────────────────────────
SR.RegisterModule("SHAMAN", S)
