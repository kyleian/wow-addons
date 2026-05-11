-- ============================================================
-- SlyRotate — Shaman Module
-- Enhancement: Stormstrike >> Earth Shock GCD loop, weapon procs,
--              totem CD tracking (WFT window handled by SlySuite_TotemTwist).
-- Elemental: Flame Shock DoT >> Lightning Bolt / Chain Lightning loop,
--            Elemental Mastery / Nature's Swiftness CD tracking.
-- ============================================================

local S = {}

S.classKey   = "SHAMAN"
S.classLabel = "Shaman"
S.headerIcon = "Interface\\Icons\\Spell_Nature_LightningShield"
S.specKeys   = { "ENHANCE", "ELEMENTAL" }
S.specLabels = { ENHANCE="Enhancement", ELEMENTAL="Elemental" }

-- ─── Enhancement priority row definitions ────────────────────
-- TBC Enhancement loop (weapon MH = Windfury, OH = Flametongue):
--   1. Stormstrike on CD       (12s CD)
--   2. Flame Shock             (DoT uptime — MUST be up before Earth Shock)
--   3. Earth Shock on CD       (6s CD — only when FS DoT is healthy)
--   4. Searing Totem           (fire totem for DPS, 60s)
--   5. Shamanistic Rage        (use when mana low or on CD — mana recovery)
--   6. Windfury proc window    (tracked from combat log)
-- NOTE: Totem twist handled by SlySuite_TotemTwist (shown below this frame)
local ENHANCE_ROWS = {
    { key="SS",     label="Stormstrike",                  spell="Stormstrike",   color={0.38,0.84,1.00} },
    { key="FS",     label="Flame Shock  (DoT)",           spell="Flame Shock",   color={1.00,0.48,0.12} },
    { key="ES",     label="Earth Shock",                  spell="Earth Shock",   color={0.55,0.88,0.55} },
    { key="SEARING",label="Fire Totem",                   spell="Searing Totem", color={0.90,0.35,0.10} },
    { key="SR",     label="Shamanic Rage  (mana)",        spell="Shamanistic Rage",   color={0.60,0.25,0.90} },
    { key="WF_PROC",label="Windfury Proc!",               spell="Windfury Totem", color={1.00,0.95,0.20} },
}

-- ─── Elemental priority row definitions ──────────────────────
-- TBC Elemental loop:
--   1. Elemental Mastery   — use on CD for instant LB cast
--   2. Nature's Swiftness  — use on CD for instant CL (multi-target burst)
--   3. Flame Shock         — maintain DoT (12s duration, 6s CD)
--   4. Chain Lightning     — 3+ targets (3s CD)
--   5. Lightning Bolt      — primary filler spam
local ELEMENTAL_ROWS = {
    { key="EM",  label="Elemental Mastery  (CD)",  spell="Elemental Mastery",  color={1.00,0.80,0.10} },
    { key="NS",  label="Nature's Swiftness  (CD)", spell="Nature's Swiftness", color={0.45,1.00,0.45} },
    { key="FS",  label="Flame Shock  (DoT)",       spell="Flame Shock",        color={1.00,0.48,0.12} },
    { key="CL",  label="Chain Lightning  (3+ AoE)",spell="Chain Lightning",    color={0.38,0.70,1.00} },
    { key="LB",  label="Lightning Bolt  (spam)",   spell="Lightning Bolt",     color={0.80,0.80,1.00} },
}

-- Expose row definitions for the admin panel (must be after both tables)
S.specRows = { ENHANCE = ENHANCE_ROWS, ELEMENTAL = ELEMENTAL_ROWS }

-- ─── Combat state ────────────────────────────────────────────
local playerMana      = 0
local playerMaxMana   = 1
local playerHP        = 1.0

-- Enhancement state
local flameshockExpiry  = 0
local srExpiry          = 0
local nsExpiry          = 0
local wfProcExpiry      = 0

-- Fire totem state (slot 1: Searing, Magma, Fire Nova, Fire Elemental)
local fireTotemName    = nil
local fireTotemExpiry  = 0

-- One-time snap flag: anchor TotemTwist below SlyRotate on first Enhancement load
local ttSnapped = false

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

    S.specRowFrames = { ENHANCE = enhRowFrames, ELEMENTAL = elemRowFrames }
end

-- ─── Spec detection ──────────────────────────────────────────
-- Stormstrike is the 40-pt Enhancement talent.
-- Elemental Mastery is the 31-pt Elemental talent.
local function DetectSpec(db)
    if db and db.classes.SHAMAN and db.classes.SHAMAN.specOverride then
        return db.classes.SHAMAN.specOverride
    end
    -- TBC tab order: 1=Elemental, 2=Enhancement (Restoration not tracked)
    return SR.DetectSpecByTalents({
        { spec="ELEMENTAL", tab=1 },
        { spec="ENHANCE",   tab=2 },
    }, "ENHANCE")
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

    -- ── Fire totem ──
    local fireL      = fireTotemExpiry > 0 and math.max(0, fireTotemExpiry - now) or 0
    local isMagma    = fireTotemName and fireTotemName:find("Magma",     1, true)
    local isFireNova = fireTotemName and fireTotemName:find("Fire Nova", 1, true)
    local isElem     = fireTotemName and fireTotemName:find("Elemental", 1, true)
    -- Searing Totem: 60s duration, refresh when <10s left
    -- Magma Totem:   20s duration, refresh when <5s left
    -- Fire Nova Totem: 4s then explodes — just show countdown, no refresh needed
    -- Fire Elemental: 60s summon, 600s (10min) CD — just show remaining, don't interrupt
    local fireDue = (not fireTotemName) or
                    (isMagma    and fireL < 5)  or
                    (not isMagma and not isFireNova and not isElem and fireL < 10)

    -- ── Priority ──
    -- Correct Enhancement priority:
    --   SS >> FS (missing or expiring <3s) >> ES (only if FS up with ≥3s) >> Fire totem >> SR (mana) >> wait
    -- SR bumps to top when mana is critical and it's off CD
    local manaCritical = manaP < 0.25 and srCD <= 0 and srL <= 0
    local best
    if manaCritical then
        best = "SR"
    elseif ssCD <= 0 then
        best = "SS"
    elseif fsL == 0 then
        best = "FS"           -- DoT missing: apply immediately
    elseif fsL < 3 then
        best = "FS"           -- DoT expiring: refresh before casting ES
    elseif esCD <= 0 then
        best = "ES"           -- FS is healthy: cast Earth Shock
    elseif fireDue then
        best = "SEARING"      -- fire totem needs refreshing
    elseif srCD <= 0 and srL <= 0 and manaP < 0.50 then
        best = "SR"           -- SR available and mana below 50%: use it
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
            if ssCD <= 0 then s = Col("44ff44","CAST NOW")
            else               s = Col("ff8844", Fmt(ssCD)) end

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

        elseif k == "ES" then
            if fsL < 3 then
                -- ES blocked: FS must be applied/refreshed first
                s = Col("555566","wait — ") .. Col("ff8844","FS first!")
            elseif esCD <= 0 then
                s = Col("44ff44","CAST NOW  ") ..
                    Col("888888", ssCD > 0 and ("SS " .. Fmt(ssCD)) or "SS READY")
            else
                s = Col("ff8844", Fmt(esCD)) ..
                    Col("555566", ssCD > 0 and ("  >> SS " .. Fmt(ssCD)) or "  >> SS READY")
            end

        elseif k == "SEARING" then
            if not fireTotemName then
                s = Col("ff4444","DROP FIRE TOTEM  ") .. Col("888888","slot empty")
            elseif isElem then
                -- Fire Elemental: 60s active, 10min CD — just track it, don't redrop
                if fireL > 0 then
                    s = Col("ff6600","FIRE ELEM  ") .. Col("44cc44", Fmt(fireL))
                else
                    local feCD = SpellCD("Fire Elemental Totem")
                    if feCD <= 0 then
                        s = Col("ff6600","FIRE ELEM  ") .. Col("44ff44","READY")
                    else
                        s = Col("ff6600","FIRE ELEM  ") .. Col("888888","CD " .. Fmt(feCD))
                    end
                end
            elseif isMagma then
                -- Magma Totem: 20s duration, AoE damage — refresh at <5s
                if fireL < 5 then
                    s = Col("ff6622","MAGMA  ") .. Col("ffcc44","REFRESH! " .. Fmt(fireL))
                elseif fireL < 8 then
                    s = Col("ff8844","Magma  ") .. Col("ffcc44", Fmt(fireL) .. "  soon")
                else
                    s = Col("ff8844","Magma  ") .. Col("44aa44", Fmt(fireL))
                end
            elseif isFireNova then
                -- Fire Nova Totem: 4s fuse then detonates — just watch it burn
                s = Col("ff4400","FIRE NOVA  ") .. Col("ffcc44","det in " .. Fmt(fireL))
            else
                -- Searing Totem: 60s duration, single-target DPS — refresh at <10s
                if fireL < 10 then
                    s = Col("ff8844","SEARING  ") .. Col("ffcc44","REFRESH! " .. Fmt(fireL))
                elseif fireL < 20 then
                    s = Col("ff8844","Searing  ") .. Col("ffcc44", Fmt(fireL) .. "  soon")
                else
                    s = Col("44aa44","Searing  ") .. Col("44cc44", Fmt(fireL))
                end
            end

        elseif k == "SR" then
            if srL > 0 then
                s = Col("cc44ff","ACTIVE  ") .. Col("aaaaaa", Fmt(srL))
            elseif srCD <= 0 then
                if manaP < 0.25 then
                    s = Col("ff44ff","USE NOW!  ") .. Col("ffcc44", string.format("%.0f%% mana", manaP * 100))
                elseif manaP < 0.50 then
                    s = Col("aa44ff","READY  ") .. Col("888888", string.format("%.0f%% mana — use it", manaP * 100))
                else
                    s = Col("aa44ff","READY  ") .. Col("555566","mana ok")
                end
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
    if best == "SS" then
        spotSt = ssCD <= 0 and "CAST" or Fmt(ssCD)
    elseif best == "FS" then
        spotSt = fsL > 0 and Fmt(fsL) or "MISSING"
    elseif best == "ES" then
        spotSt = esCD <= 0 and "CAST" or Fmt(esCD)
    elseif best == "SEARING" then
        spotSt = fireL > 0 and Fmt(fireL) or "DROP"
    elseif best == "SR" then
        spotSt = "MANA!"
    else
        spotSt = "WAIT"
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
    S.currentSpec = spec

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
        -- Snap TotemTwist below SlyRotate once, matching its width. After that
        -- the player can drag it freely — we never re-anchor.
        if not ttSnapped then
            local ttFrame = SlyTotemTwistFrame
            local srFrame = SlyRotateFrame
            if ttFrame and srFrame then
                ttFrame:ClearAllPoints()
                ttFrame:SetPoint("TOP", srFrame, "BOTTOM", 0, -4)
                ttSnapped = true
            end
        end
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

        if spellName == "Searing Totem"       or
               spellName == "Magma Totem"          or
               spellName == "Fire Nova Totem"      or
               spellName == "Fire Elemental Totem" then
            -- Fire totem cast — eagerly set name and scan for updated expiry
            fireTotemName = spellName
            ScanFireTotem()
        end
    end
end

function S:RegisterEvents()
    SR.RegisterEvent("PLAYER_TOTEM_UPDATE")
    SR.RegisterEvent("UNIT_SPELLCAST_SUCCEEDED")
end

-- ─── Register ────────────────────────────────────────────────
SR.RegisterModule("SHAMAN", S)
