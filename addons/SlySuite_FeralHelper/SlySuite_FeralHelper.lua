-- ============================================================
-- SlySuite_FeralHelper
-- TBC Feral Druid rotation advisor: Cat DPS + Bear Tank
--
-- Reads current form, energy/rage, combo points, and target
-- debuff timers to highlight the correct next action in priority
-- order — matching the published TBC powershift-cycle rotation.
--
-- /slyferal          toggle show/hide
-- /slyferal lock     lock position
-- /slyferal unlock   allow dragging
-- /slyferal reset    move to default position
-- /slyferal spot     toggle center-screen spotlight box
-- ============================================================

local ADDON_NAME = "SlySuite_FeralHelper"
local VERSION    = "1.7.2"

local FH = {}
FH.db = nil

local DB_DEFAULTS = {
    locked       = false,
    shown        = true,
    position     = { point = "CENTER", x = 250, y = 0 },
    spotShown    = true,
    spotPosition = { point = "CENTER", x = 0, y = -150 },
}

local function ApplyDefaults(dest, src)
    for k, v in pairs(src) do
        if dest[k] == nil then dest[k] = type(v) == "table" and {} or v end
        if type(v) == "table" and type(dest[k]) == "table" then ApplyDefaults(dest[k], v) end
    end
end

-- ────────────────────────────────────────────────────────────
-- Theme helper
-- ────────────────────────────────────────────────────────────
local function TC(key)
    if SlyStyle and SlyStyle.Get then
        local c = SlyStyle.Get(key)
        if c then return c[1], c[2], c[3], c[4] or 1 end
    end
    local t = {
        frameBg  = {0.05, 0.05, 0.07, 0.97},
        border   = {0.28, 0.28, 0.35, 1},
        headerBg = {0.09, 0.09, 0.14, 1},
        sep      = {0.25, 0.25, 0.32, 1},
    }
    local c = t[key] or {0.1, 0.1, 0.1, 1}
    return c[1], c[2], c[3], c[4] or 1
end

-- ────────────────────────────────────────────────────────────
-- Spell names (rank-independent matching)
-- ────────────────────────────────────────────────────────────
local SP_RIP        = "Rip"
local SP_MANGLE_C   = "Mangle (Cat)"
local SP_MANGLE_B   = "Mangle (Bear)"
local SP_SHRED      = "Shred"
local SP_RAKE       = "Rake"
local SP_FB         = "Ferocious Bite"
local SP_TF         = "Tiger's Fury"
local SP_LACERATE   = "Lacerate"
local SP_MAUL       = "Maul"
local SP_SWIPE      = "Swipe"
local SP_DEMO_ROAR  = "Demoralizing Roar"
local SP_BASH       = "Bash"
local SP_FRENZIED   = "Frenzied Regeneration"

-- ────────────────────────────────────────────────────────────
-- Icons (interface path = case-insensitive on actual WoW client)
-- ────────────────────────────────────────────────────────────
local ICO = {
    TF         = "Interface\\Icons\\Ability_Druid_TigersFury",
    RIP        = "Interface\\Icons\\Ability_GhoulFrenzy",
    MANGLE     = "Interface\\Icons\\Ability_Druid_Mangle2",
    SHRED      = "Interface\\Icons\\Spell_Shadow_VampiricAura",
    FB         = "Interface\\Icons\\Ability_Druid_FerociousBite",
    POWERSHIFT = "Interface\\Icons\\Ability_Druid_CatForm",
    WAIT       = "Interface\\Icons\\Spell_Magic_WardingCurse",
    LACERATE   = "Interface\\Icons\\Ability_Druid_Lacerate",
    MAUL       = "Interface\\Icons\\Ability_Druid_Maul",
    SWIPE      = "Interface\\Icons\\Ability_Druid_Swipe",
    DEMO_ROAR  = "Interface\\Icons\\Ability_Druid_DemoralizingRoar",
    BASH       = "Interface\\Icons\\Ability_Druid_Bash",
    FRENZIED   = "Interface\\Icons\\Ability_BullRush",
}

-- ────────────────────────────────────────────────────────────
-- Priority row definitions
-- Cat order matches guide exactly:
--   1. Rip        CPs≥4, E≥30, Rip expired
--   2. Mangle     E≥40, debuff expired
--   3. Shred      E≥42
--   4. Powershift E > 20 below needed for next action
--   5. Wait       (energy tick)
-- Non-priority indicators:
--   FB  — swap row: only lights when target <20% HP, CPs≥4, Rip active
--   TF  — passive: shows buff/CD, never a rotation action mid-fight
-- ────────────────────────────────────────────────────────────
local CAT_ROWS = {
    -- key, label, icon, color{r,g,b}
    { key="RIP",        label="Rip  (≥4CP ≥30E)",  icon=ICO.RIP,        color={1.00, 0.28, 0.28} },
    { key="MANGLE_CAT", label="Mangle  (≥40E)",    icon=ICO.MANGLE,     color={1.00, 0.68, 0.18} },
    { key="SHRED",      label="Shred  (≥42E)",     icon=ICO.SHRED,      color={0.38, 0.84, 1.00} },
    { key="POWERSHIFT", label="Powershift",        icon=ICO.POWERSHIFT, color={0.45, 1.00, 0.45} },
    { key="WAIT",       label="Wait  (tick)",      icon=ICO.WAIT,       color={0.42, 0.42, 0.48} },
    { key="FB",         label="↳ FB swap (dying)", icon=ICO.FB,         color={1.00, 0.55, 0.10} },
    { key="TF",         label="Tiger's Fury (CD)", icon=ICO.TF,         color={1.00, 0.65, 0.00} },
}

local BEAR_ROWS = {
    { key="MANGLE_BEAR", label="Mangle (Bear)",      icon=ICO.MANGLE,    color={1.00, 0.55, 0.10} },
    { key="LACERATE",    label="Lacerate  (spam)",   icon=ICO.LACERATE,  color={0.90, 0.28, 0.28} },
    { key="MAUL",        label="↳ Maul  (off-GCD)",  icon=ICO.MAUL,      color={1.00, 0.82, 0.22} },
    { key="DEMO_ROAR",   label="Demo Roar  (opt)",   icon=ICO.DEMO_ROAR, color={0.65, 0.40, 1.00} },
    { key="BASH",        label="Bash",               icon=ICO.BASH,      color={0.40, 0.85, 1.00} },
    { key="FRENZIED",    label="Frenzied  (skip)",   icon=ICO.FRENZIED,  color={0.45, 0.45, 0.50} },
}

-- ────────────────────────────────────────────────────────────
-- Combat state
-- ────────────────────────────────────────────────────────────
local catEnergy       = 0
local catCPs          = 0
local bearRage        = 0
local playerHP        = 1.0  -- 0-1

local ripExpiry       = 0    -- GetTime() expiry; 0 = not up
local mangleCatExpiry = 0
local lacerateExpiry  = 0
local lacerateStacks  = 0
local demoRoarExpiry  = 0
local tfExpiry        = 0    -- Tiger's Fury buff on player

local playerGUID      = nil
local currentMode     = "NONE"  -- "CAT", "BEAR", "NONE"

-- ────────────────────────────────────────────────────────────
-- Form detection via shapeshift bar (rank-independent)
-- ────────────────────────────────────────────────────────────
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

-- ────────────────────────────────────────────────────────────
-- Debuff/buff scanners
-- ────────────────────────────────────────────────────────────
local function ScanTargetDebuffs()
    if not UnitExists("target") then
        ripExpiry = 0; mangleCatExpiry = 0; lacerateExpiry = 0; lacerateStacks = 0; demoRoarExpiry = 0
        return
    end
    ripExpiry = 0; mangleCatExpiry = 0; lacerateExpiry = 0; lacerateStacks = 0; demoRoarExpiry = 0
    local i = 1
    while true do
        local name, _, count, _, _, expireTime = UnitDebuff("target", i, "PLAYER")
        if not name then break end
        if name == SP_RIP       then ripExpiry       = expireTime or 0 end
        if name == SP_MANGLE_C  then mangleCatExpiry = expireTime or 0 end
        if name == SP_LACERATE  then lacerateExpiry  = expireTime or 0; lacerateStacks = count or 1 end
        if name == SP_DEMO_ROAR then demoRoarExpiry  = expireTime or 0 end
        -- Mangle (Bear) also applies "Mangle" debuff on target (same debuff name as cat in TBC)
        if name == "Mangle"     then mangleCatExpiry = expireTime or 0 end
        i = i + 1
    end
end

local function ScanPlayerBuffs()
    tfExpiry = 0
    local i = 1
    while true do
        local name, _, _, _, _, expireTime = UnitBuff("player", i)
        if not name then break end
        if name == SP_TF then tfExpiry = expireTime or 0 end
        i = i + 1
    end
end

-- ────────────────────────────────────────────────────────────
-- Cooldown helper — returns seconds remaining on CD, or 0 if ready
-- ────────────────────────────────────────────────────────────
local function SpellCD(spellName)
    local start, dur = GetSpellCooldown(spellName)
    if dur and dur > 1.5 then
        return math.max(0, start + dur - GetTime())
    end
    return 0
end

-- ────────────────────────────────────────────────────────────
-- Format helpers
-- ────────────────────────────────────────────────────────────
local function Fmt(secs)
    if secs <= 0 then return "" end
    if secs >= 10 then return string.format("%.0fs", secs) end
    return string.format("%.1fs", secs)
end

local function Col(hex, s) return string.format("|cff%s%s|r", hex, s) end

-- ────────────────────────────────────────────────────────────
-- UI frames
-- ────────────────────────────────────────────────────────────
local FRAME_W      = 196
local HDR_H        = 18
local ROW_H        = 22
local ICON_S       = 16
local PAD          = 5
local STATUS_W     = 56

local mainFrame    = nil
local modeLabel    = nil
local catContainer = nil
local bearContainer= nil
local catRowFrames = {}
local bearRowFrames= {}

-- Spotlight "next action" frame
local spotFrame    = nil
local spotIcon     = nil
local spotName     = nil
local spotSub      = nil

local function BuildRow(parent, rowDef, idx)
    local row = CreateFrame("Frame", nil, parent)
    row:SetSize(FRAME_W, ROW_H)
    row:SetPoint("TOPLEFT", parent, "TOPLEFT", 0, -(idx - 1) * (ROW_H + 1))

    -- Alternating strip bg
    local bg = row:CreateTexture(nil, "BACKGROUND")
    bg:SetAllPoints()
    bg:SetColorTexture(0, 0, 0, idx % 2 == 0 and 0.18 or 0.05)
    row.bg = bg

    -- Glow overlay (active)
    local glow = row:CreateTexture(nil, "BORDER")
    glow:SetAllPoints()
    glow:SetColorTexture(rowDef.color[1], rowDef.color[2], rowDef.color[3], 0)
    row.glow = glow

    -- Priority number
    local num = row:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    num:SetFont(num:GetFont(), 7, "OUTLINE")
    num:SetPoint("LEFT", row, "LEFT", 2, 0)
    num:SetWidth(10)
    num:SetJustifyH("CENTER")
    num:SetText(Col("444455", tostring(idx)))
    row.num = num

    -- Spell icon
    local icon = row:CreateTexture(nil, "ARTWORK")
    icon:SetSize(ICON_S, ICON_S)
    icon:SetPoint("LEFT", row, "LEFT", 14, 0)
    icon:SetTexture(rowDef.icon)
    icon:SetTexCoord(0.07, 0.93, 0.07, 0.93)
    icon:SetAlpha(0.40)
    row.icon = icon

    -- Label
    local lbl = row:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    lbl:SetFont(lbl:GetFont(), 9, "OUTLINE")
    lbl:SetPoint("LEFT", row, "LEFT", 34, 0)
    lbl:SetWidth(FRAME_W - 34 - STATUS_W - PAD)
    lbl:SetJustifyH("LEFT")
    lbl:SetText(rowDef.label)
    lbl:SetTextColor(0.38, 0.38, 0.42)
    row.lbl = lbl

    -- Status / timer
    local status = row:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    status:SetFont(status:GetFont(), 9, "OUTLINE")
    status:SetPoint("RIGHT", row, "RIGHT", -PAD, 0)
    status:SetWidth(STATUS_W)
    status:SetJustifyH("RIGHT")
    status:SetText("")
    row.status = status

    row.rowDef = rowDef
    return row
end

local function SetRowState(row, active, statusStr)
    local c = row.rowDef.color
    if active then
        row.glow:SetColorTexture(c[1], c[2], c[3], 0.25)
        row.bg:SetColorTexture(c[1] * 0.10, c[2] * 0.10, c[3] * 0.10, 1)
        row.icon:SetAlpha(1.00)
        row.lbl:SetTextColor(c[1], c[2], c[3])
        row.num:SetText(Col("ffee55", ">"))
    else
        row.glow:SetColorTexture(0, 0, 0, 0)
        row.bg:SetColorTexture(0, 0, 0, row.rowDef._idx % 2 == 0 and 0.18 or 0.05)
        row.icon:SetAlpha(0.35)
        row.lbl:SetTextColor(0.35, 0.35, 0.40)
        row.num:SetText(Col("333344", tostring(row.rowDef._idx)))
    end
    row.status:SetText(statusStr or "")
end

local function BuildUI()
    if mainFrame then return end

    local catH  = #CAT_ROWS  * (ROW_H + 1)
    local bearH = #BEAR_ROWS * (ROW_H + 1)
    local bodyH = math.max(catH, bearH)
    local FRAME_H = HDR_H + 2 + bodyH + 4

    local f = CreateFrame("Frame", "SlyFeralHelperFrame", UIParent)
    f:SetSize(FRAME_W, FRAME_H)
    f:SetFrameStrata("HIGH")
    f:SetMovable(true)
    f:EnableMouse(false)

    local pos = FH.db.position
    f:ClearAllPoints()
    f:SetPoint(pos.point or "CENTER", UIParent, pos.point or "CENTER",
               pos.x or 250, pos.y or 0)

    -- Border + bg
    local border = f:CreateTexture(nil, "BACKGROUND")
    border:SetAllPoints()
    border:SetColorTexture(TC("border"))
    local bg = f:CreateTexture(nil, "BACKGROUND")
    bg:SetPoint("TOPLEFT",     f, "TOPLEFT",      1, -1)
    bg:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", -1,  1)
    bg:SetColorTexture(TC("frameBg"))

    -- Header
    local hdr = CreateFrame("Frame", nil, f)
    hdr:SetSize(FRAME_W, HDR_H)
    hdr:SetPoint("TOPLEFT", f, "TOPLEFT", 0, 0)
    local hdrBg = hdr:CreateTexture(nil, "BACKGROUND")
    hdrBg:SetAllPoints()
    hdrBg:SetColorTexture(TC("headerBg"))

    local catIcon = hdr:CreateTexture(nil, "ARTWORK")
    catIcon:SetSize(14, 14)
    catIcon:SetPoint("LEFT", hdr, "LEFT", 4, 0)
    catIcon:SetTexture(ICO.POWERSHIFT)
    catIcon:SetTexCoord(0.07, 0.93, 0.07, 0.93)

    local titleTx = hdr:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    titleTx:SetFont(titleTx:GetFont(), 9, "OUTLINE")
    titleTx:SetPoint("LEFT", catIcon, "RIGHT", 4, 0)
    titleTx:SetText(Col("88ff88", "FERAL") .. " " .. Col("888888", "ROTATION"))

    modeLabel = hdr:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    modeLabel:SetFont(modeLabel:GetFont(), 9, "OUTLINE")
    modeLabel:SetPoint("RIGHT", hdr, "RIGHT", -5, 0)
    modeLabel:SetText(Col("444455", "---"))

    local sep = f:CreateTexture(nil, "ARTWORK")
    sep:SetSize(FRAME_W - 2, 1)
    sep:SetPoint("TOPLEFT", f, "TOPLEFT", 1, -HDR_H)
    sep:SetColorTexture(TC("sep"))

    -- Body area
    local body = CreateFrame("Frame", nil, f)
    body:SetSize(FRAME_W, bodyH)
    body:SetPoint("TOPLEFT", f, "TOPLEFT", 0, -(HDR_H + 2))

    -- Cat container
    catContainer = CreateFrame("Frame", nil, body)
    catContainer:SetSize(FRAME_W, catH)
    catContainer:SetPoint("TOPLEFT", body, "TOPLEFT", 0, 0)
    catRowFrames = {}
    for i, rd in ipairs(CAT_ROWS) do
        rd._idx = i
        catRowFrames[i] = BuildRow(catContainer, rd, i)
    end

    -- Bear container (hidden initially)
    bearContainer = CreateFrame("Frame", nil, body)
    bearContainer:SetSize(FRAME_W, bearH)
    bearContainer:SetPoint("TOPLEFT", body, "TOPLEFT", 0, 0)
    bearContainer:Hide()
    bearRowFrames = {}
    for i, rd in ipairs(BEAR_ROWS) do
        rd._idx = i
        bearRowFrames[i] = BuildRow(bearContainer, rd, i)
    end

    -- Drag handle
    local drag = CreateFrame("Frame", nil, f)
    drag:SetAllPoints()
    drag:EnableMouse(true)
    drag:RegisterForDrag("LeftButton")
    drag:SetScript("OnDragStart", function()
        if not FH.db.locked then f:StartMoving() end
    end)
    drag:SetScript("OnDragStop", function()
        f:StopMovingOrSizing()
        local pt, _, _, x, y = f:GetPoint()
        FH.db.position = { point = pt or "CENTER", x = x or 0, y = y or 0 }
    end)

    mainFrame = f
    if not FH.db.shown then f:Hide() end

    if SlyStyle and SlyStyle.OnThemeChange then
        SlyStyle.OnThemeChange(function()
            border:SetColorTexture(TC("border"))
            bg:SetColorTexture(TC("frameBg"))
            hdrBg:SetColorTexture(TC("headerBg"))
            sep:SetColorTexture(TC("sep"))
        end)
    end
end

-- ────────────────────────────────────────────────────────────
-- Spotlight frame — center-screen "NEXT" action display
-- ────────────────────────────────────────────────────────────
local SPOT_W, SPOT_H = 200, 68

local function BuildSpotlight()
    if spotFrame then return end
    local sp = FH.db.spotPosition or { point="CENTER", x=0, y=-150 }
    local f  = CreateFrame("Frame", "SlyFeralHelperSpot", UIParent)
    f:SetSize(SPOT_W, SPOT_H)
    f:SetFrameStrata("HIGH")
    f:SetMovable(true)
    f:SetClampedToScreen(true)
    f:SetPoint(sp.point or "CENTER", UIParent, sp.point or "CENTER", sp.x or 0, sp.y or -150)
    f:EnableMouse(true)
    f:RegisterForDrag("LeftButton")
    f:SetScript("OnDragStart", function()
        if not FH.db.locked then f:StartMoving() end
    end)
    f:SetScript("OnDragStop", function()
        f:StopMovingOrSizing()
        local pt, _, _, x, y = f:GetPoint()
        FH.db.spotPosition = { point = pt or "CENTER", x = x or 0, y = y or 0 }
    end)

    -- Background / border
    local bdr = f:CreateTexture(nil, "BACKGROUND")
    bdr:SetAllPoints()
    bdr:SetColorTexture(0.28, 0.28, 0.35, 1)
    f._bdr = bdr

    local inner = f:CreateTexture(nil, "BORDER")
    inner:SetPoint("TOPLEFT",     f, "TOPLEFT",      1, -1)
    inner:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", -1,  1)
    inner:SetColorTexture(0.04, 0.04, 0.07, 0.94)

    -- Large icon on the left
    local ico = f:CreateTexture(nil, "ARTWORK")
    ico:SetSize(52, 52)
    ico:SetPoint("LEFT", f, "LEFT", 8, 0)
    ico:SetTexCoord(0.07, 0.93, 0.07, 0.93)
    spotIcon = ico

    -- Ability name
    local nm = f:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    nm:SetFont(nm:GetFont(), 15, "OUTLINE")
    nm:SetPoint("TOPLEFT", ico, "TOPRIGHT", 8, -4)
    nm:SetPoint("RIGHT",   f,   "RIGHT",   -6, 0)
    nm:SetJustifyH("LEFT")
    nm:SetWordWrap(false)
    nm:SetText("|cff888888--|r")
    spotName = nm

    -- Sub-line (status, energy, timer)
    local sub = f:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    sub:SetFont(sub:GetFont(), 10, "OUTLINE")
    sub:SetPoint("BOTTOMLEFT", ico, "BOTTOMRIGHT", 8, 4)
    sub:SetPoint("RIGHT",      f,   "RIGHT",      -6, 0)
    sub:SetJustifyH("LEFT")
    sub:SetText("")
    spotSub = sub

    -- Small NEXT label in top-left corner
    local tag = f:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    tag:SetFont(tag:GetFont(), 8, "OUTLINE")
    tag:SetPoint("TOPLEFT", f, "TOPLEFT", 4, -3)
    tag:SetText("|cff556655NEXT|r")

    spotFrame = f
    if FH.db.spotShown == false then f:Hide() end
end

local function UpdateSpotlight(key, rows, statusStr)
    if not spotFrame or not spotFrame:IsShown() then return end
    local rd
    for _, r in ipairs(rows) do
        if r.key == key then rd = r; break end
    end
    if not rd then
        spotName:SetText("|cff888888--|r")
        spotSub:SetText("")
        spotIcon:SetTexture(nil)
        return
    end
    local c   = rd.color or {1, 1, 1}
    local hex = string.format("%02x%02x%02x",
        math.floor(c[1] * 255), math.floor(c[2] * 255), math.floor(c[3] * 255))
    spotName:SetText("|cff" .. hex .. rd.label .. "|r")
    spotIcon:SetTexture(rd.icon)
    spotSub:SetText(statusStr or "")
    -- Tint the border to match the active ability color
    if spotFrame._bdr then
        spotFrame._bdr:SetColorTexture(c[1] * 0.6, c[2] * 0.6, c[3] * 0.6, 0.95)
    end
end

-- ────────────────────────────────────────────────────────────
-- Cat rotation logic — matches guide priority EXACTLY:
--
--   1. Rip        if CPs≥4 AND E≥30 AND Rip expired
--   2. Mangle     if E≥40 AND Mangle debuff expired
--   3. Shred      if E≥42
--   4. Powershift if energy > 20 below cost of next action*
--   5. Wait       otherwise
--
-- *next action cost = 30 (Rip pending), 40 (Mangle pending), 42 (Shred)
--  Powershift fires when energy < (nextCost - 20)
--
-- Tiger's Fury: on-pull pre-pop ONLY (DPS loss mid-rotation).
--   Shown as passive CD/buff indicator — never as a priority step.
-- Ferocious Bite: swap only when target is dying (<20% HP) or on AoE
--   trash where Rip won't tick full duration. Never in standard cycle.
-- ────────────────────────────────────────────────────────────
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

    -- Determine what the NEXT castable action would be (for powershift threshold)
    -- This mirrors the guide: "more than 20 energy below what is needed for your next action"
    local nextCost
    if cps >= 4 and ripL == 0 then
        nextCost = 30   -- Rip pending
    elseif manL == 0 and manCD <= 0 then
        nextCost = 40   -- Mangle pending
    else
        nextCost = 42   -- Shred is the default
    end

    -- What's the NEXT ability name (for forward-looking display)
    local nextName
    if cps >= 4 and ripL == 0 then
        nextName = "Rip"
    elseif manL == 0 and manCD <= 0 then
        nextName = "Mangle"
    else
        nextName = "Shred"
    end
    -- Energy ticks: ~20E per 2s in cat form. Estimate ticks needed.
    local function TicksNeeded(need, have)
        local deficit = math.max(0, need - have)
        if deficit == 0 then return 0 end
        return math.ceil(deficit / 20)
    end

    -- Strict priority from guide
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

    -- FB swap fires as a visible highlight when target is dying AND Rip is already up
    -- (non-priority — shown alongside whatever step is active)
    local fbSwap = cps >= 4 and ripL > 0 and tgtHP < 0.20

    -- Build status strings and activate rows
    for _, row in ipairs(catRowFrames) do
        local k      = row.rowDef.key
        local active = (k == best) or (k == "FB" and fbSwap)
        local s      = ""

        if k == "RIP" then
            if ripL > 0 then
                s = Col("44ff44", Fmt(ripL))
            elseif cps >= 4 and energy >= 30 then
                s = Col("ff4444", "CAST!") .. " " .. Col("ffdd88", cps .. "CP")
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
                -- Debuff gone — show energy vs needed
                local col = energy >= 40 and "ff4444" or "ff7744"
                s = Col(col, "GONE") .. " " .. Col("888888", energy .. "E")
            end

        elseif k == "SHRED" then
            if energy >= 42 then
                s = Col("55ddff", "CAST NOW  ") .. Col("888888", energy .. "E")
            else
                local need    = 42
                local deficit = need - energy
                local ticks   = TicksNeeded(need, energy)
                local tickStr = ticks == 1 and "~1 tick" or ticks .. " ticks"
                s = Col("555566", energy .. "E  ") .. Col("888888", "+" .. deficit .. "E  " .. tickStr)
            end

        elseif k == "POWERSHIFT" then
            local deficit = nextCost - energy
            local ticks   = TicksNeeded(nextCost, energy)
            local tickStr = ticks == 1 and "~1 tick" or ticks .. " ticks"
            if best == "POWERSHIFT" then
                s = Col("aaffaa", "SHIFT  ") .. Col("888888", "→ " .. nextName .. " after")
            else
                s = Col("667766", energy .. "E  -" .. deficit .. "  " .. tickStr)
            end

        elseif k == "WAIT" then
            local deficit = nextCost - energy
            local ticks   = TicksNeeded(nextCost, energy)
            local tickStr = ticks == 1 and "~1 tick" or ticks .. " ticks"
            s = Col("888888", "→ ") .. Col("aaaacc", nextName) ..
                Col("555566", "  +" .. deficit .. "E  ") .. Col("888888", tickStr)

        elseif k == "FB" then
            -- Passive swap indicator
            if fbSwap then
                s = Col("ffaa44", "SWAP!")
            else
                local hpStr = UnitExists("target") and
                              string.format("%.0f%%", tgtHP * 100) or "--"
                s = Col("555566", cps .. "CP " .. hpStr)
            end

        elseif k == "TF" then
            -- Passive indicator only — never a rotation priority
            if tfL > 0 then
                s = Col("ffdd55", Fmt(tfL))
            elseif tfCD > 0 then
                s = Col("888888", Fmt(tfCD))
            else
                s = Col("44ff44", "PULL")
            end
        end

        SetRowState(row, active, s)
    end

    -- Header badge
    local cpCol = cps >= 4 and "ffee55" or "aaaaaa"
    modeLabel:SetText(
        Col("ff9933", "CAT") .. "  " ..
        Col("aaaaaa", energy .. "E ") ..
        Col(cpCol,    cps .. "CP")
    )

    -- Spotlight: propagate winning action + live status
    local spotStatus = ""
    if best == "RIP" then
        spotStatus = cps .. "CP  " .. energy .. "E"
    elseif best == "MANGLE_CAT" then
        spotStatus = energy .. "E"
    elseif best == "SHRED" then
        spotStatus = energy .. "E"
    elseif best == "POWERSHIFT" then
        local deficit = nextCost - energy
        spotStatus = "shift → " .. nextName .. "  need +" .. deficit .. "E"
    elseif best == "WAIT" then
        local deficit = nextCost - energy
        local ticks   = TicksNeeded(nextCost, energy)
        local tickStr = ticks == 1 and "~1 tick" or ticks .. " ticks"
        spotStatus = "→ " .. nextName .. "  +" .. deficit .. "E  " .. tickStr
    end
    UpdateSpotlight(best, CAT_ROWS, spotStatus)
end

-- ────────────────────────────────────────────────────────────
-- Bear rotation logic — matches Wowhead TBC bear guide exactly:
--
--   GCD priority:
--   1. Mangle (Bear)  on cooldown (rage ≥ 15)
--   2. Lacerate       every remaining GCD (static threat on EVERY cast)
--
--   Off-GCD (queue alongside GCD action):
--   3. Maul           when rage is excess (≥ 60) — rage dump
--
--   Passive indicators (never a rotation priority):
--   Demo Roar — optional AP debuff, show timer only
--   Bash      — utility stun/interrupt CD
--   Frenzied  — guide: "should NEVER be used in raids" (waste of rage)
-- ────────────────────────────────────────────────────────────
local function UpdateBear(now)
    local rage    = bearRage
    local hp      = playerHP
    local manCD   = SpellCD(SP_MANGLE_B)
    local lacL    = lacerateExpiry > 0 and math.max(0, lacerateExpiry - now) or 0
    local demoL   = demoRoarExpiry > 0 and math.max(0, demoRoarExpiry - now) or 0
    local bashCD  = SpellCD(SP_BASH)
    local frCD    = SpellCD(SP_FRENZIED)

    -- GCD priority: Mangle on CD, otherwise Lacerate every GCD
    -- Do NOT cast Lacerate if it would leave < 15 rage for Mangle's next CD window
    local best
    if manCD <= 0 and rage >= 15 then
        best = "MANGLE_BEAR"
    else
        -- Lacerate is spammed every available GCD for static threat
        -- (even at max stacks — the static threat component fires every cast)
        best = "LACERATE"
    end

    -- Mangle ready but rage too low — player must know to hold Maul/Lacerate spending
    local mangleWaitRage = manCD <= 0 and rage < 15

    -- Maul is off-GCD (queues onto next auto-attack) — flag separately
    -- Suppress Maul dump if Mangle is ready and waiting for rage — preserve it
    local maulDump = rage >= 60 and not mangleWaitRage

    for _, row in ipairs(bearRowFrames) do
        local k      = row.rowDef.key
        -- Active: main GCD winner, Mangle warning, or Maul off-GCD dump
        local active = (k == best)
                    or (k == "MANGLE_BEAR" and mangleWaitRage)
                    or (k == "MAUL"        and maulDump)
        local s = ""

        if k == "MANGLE_BEAR" then
            -- Three states: waiting on CD | ready to cast | ready but can't afford yet
            if manCD > 0 then
                s = Col("ff8844", Fmt(manCD)) .. Col("888888", "  wait")
            elseif rage >= 15 then
                s = Col("44ff44", "CAST NOW  ") .. Col("aaaaaa", rage .. "R")
            else
                -- CD is up but rage too low — conscious hold
                s = Col("ffdd22", "SAVE RAGE  ") .. Col("ffaa00", rage .. "/15R")
            end

        elseif k == "LACERATE" then
            -- Always the GCD filler — show urgency tiers
            if lacL == 0 then
                -- Not on target yet or fully expired
                s = Col("ff4444", "APPLY!  ") .. Col("aaaaaa", lacerateStacks .. "/5")
            elseif lacL < 2.5 then
                -- About to fall off — urgent refresh
                s = Col("ff6622", "REFRESH!  ") .. Col("ffcc44", Fmt(lacL)) .. Col("888888", "  " .. lacerateStacks .. "/5")
            elseif lacerateStacks < 5 then
                -- Still building stacks
                s = Col("ffcc44", lacerateStacks .. "/5 ") .. Col("aaaaaa", "build  ") .. Col("888888", Fmt(lacL))
            else
                -- Full stacks, comfortable
                s = Col("44ff44", "5/5  ") .. Col("aaaaaa", Fmt(lacL))
            end

        elseif k == "MAUL" then
            -- Off-GCD — communicate rage budget clearly
            if mangleWaitRage then
                -- Holding for Mangle — explicitly say so
                s = Col("ffdd22", "HOLD  ") .. Col("888866", rage .. "R → Mangle")
            elseif maulDump then
                s = Col("ffee55", "QUEUE  ") .. Col("aaaaaa", rage .. "R excess")
            elseif rage >= 45 then
                -- Getting there — watch Mangle first though
                s = Col("888844", rage .. "R  soon")
            else
                s = Col("555566", rage .. "R  not yet")
            end

        elseif k == "DEMO_ROAR" then
            -- Optional AP debuff — show urgency when expiring, otherwise quiet
            if demoL == 0 then
                s = Col("888888", "off  ") .. Col("555566", "(optional)")
            elseif demoL < 3 then
                s = Col("ff8844", "REFRESH  ") .. Col("ffcc44", Fmt(demoL))
            elseif demoL < 8 then
                s = Col("ffcc44", Fmt(demoL) .. "  ") .. Col("888888", "refresh soon")
            else
                s = Col("44aa44", Fmt(demoL))
            end

        elseif k == "BASH" then
            -- Utility interrupt/stun — always show exact state
            if bashCD > 0 then
                s = Col("888888", "CD  ") .. Col("ff8844", Fmt(bashCD))
            else
                s = Col("44ff44", "READY  ") .. Col("888888", "interrupt/stun")
            end

        elseif k == "FRENZIED" then
            -- Guide: never use in raids — always grey regardless of HP
            local hpPct = string.format("%.0f%%", hp * 100)
            if frCD > 0 then
                s = Col("555566", "CD  " .. Fmt(frCD))
            else
                s = Col("555566", "READY  ") .. Col("444455", hpPct .. "  skip in raids")
            end
        end

        SetRowState(row, active, s)
    end

    local hpCol  = hp < 0.30 and "ff4444" or hp < 0.60 and "ffcc44" or "44ff44"
    modeLabel:SetText(
        Col("ff7722", "BEAR") .. "  " ..
        Col("aaaaaa", rage .. "R ") ..
        Col(hpCol, string.format("%.0f%%", hp * 100))
    )

    -- Spotlight: show the main GCD action (Mangle or Lacerate)
    local bearStatus
    if best == "MANGLE_BEAR" then
        bearStatus = "on CD: " .. (manCD > 0 and Fmt(manCD) or "READY") .. "  " .. rage .. "R"
    else
        local stkStr = lacerateStacks .. "/5  " .. (lacL > 0 and Fmt(lacL) or "GONE")
        bearStatus = stkStr .. "  " .. rage .. "R"
    end
    UpdateSpotlight(best, BEAR_ROWS, bearStatus)
end

-- ────────────────────────────────────────────────────────────
-- Master display refresh (called every tick)
-- ────────────────────────────────────────────────────────────
local function RefreshDisplay()
    if not mainFrame or not mainFrame:IsShown() then return end
    local form = GetDruidForm()
    local now  = GetTime()

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
        modeLabel:SetText(Col("444455", "NO FORM"))
    end
end

-- ────────────────────────────────────────────────────────────
-- OnUpdate ticker (~20 fps — fast enough for energy ticks)
-- ────────────────────────────────────────────────────────────
local tickFrame = CreateFrame("Frame")
local tickAcc   = 0
tickFrame:SetScript("OnUpdate", function(self, dt)
    tickAcc = tickAcc + dt
    if tickAcc < 0.05 then return end
    tickAcc = 0

    catEnergy = UnitPower("player", 3) or 0
    bearRage  = UnitPower("player", 1) or 0
    catCPs    = (GetComboPoints and GetComboPoints("player", "target"))
                or UnitPower("player", 4) or 0
    playerHP  = UnitHealth("player") / math.max(1, UnitHealthMax("player"))

    RefreshDisplay()
end)

-- ────────────────────────────────────────────────────────────
-- Event frame
-- ────────────────────────────────────────────────────────────
local evtFrame = CreateFrame("Frame")
evtFrame:RegisterEvent("PLAYER_TARGET_CHANGED")
evtFrame:RegisterEvent("UNIT_AURA")
evtFrame:RegisterEvent("UPDATE_SHAPESHIFT_FORM")
evtFrame:RegisterEvent("PLAYER_LOGOUT")

evtFrame:SetScript("OnEvent", function(self, event, arg1)
    if event == "PLAYER_TARGET_CHANGED" then
        ScanTargetDebuffs()

    elseif event == "UNIT_AURA" then
        if arg1 == "player" then ScanPlayerBuffs()   end
        if arg1 == "target"  then ScanTargetDebuffs() end

    elseif event == "UPDATE_SHAPESHIFT_FORM" then
        -- Form changed — rescan debuffs in case we re-targeted
        ScanTargetDebuffs()
        ScanPlayerBuffs()

    elseif event == "PLAYER_LOGOUT" then
        if mainFrame and FH.db then
            local pt, _, _, x, y = mainFrame:GetPoint()
            FH.db.position = { point = pt or "CENTER", x = x or 0, y = y or 0 }
            FH.db.shown    = mainFrame:IsShown()
        end
        if spotFrame and FH.db then
            local pt, _, _, x, y = spotFrame:GetPoint()
            FH.db.spotPosition = { point = pt or "CENTER", x = x or 0, y = y or 0 }
            FH.db.spotShown    = spotFrame:IsShown()
        end
    end
end)

-- ────────────────────────────────────────────────────────────
-- Init
-- ────────────────────────────────────────────────────────────
local function Init()
    local _, classFile = UnitClass("player")
    if classFile ~= "DRUID" then return end

    playerGUID = UnitGUID("player")

    SlyFeralHelperDB = SlyFeralHelperDB or {}
    ApplyDefaults(SlyFeralHelperDB, DB_DEFAULTS)
    FH.db = SlyFeralHelperDB

    SLASH_SLYFERAL1 = "/slyferal"
    SlashCmdList["SLYFERAL"] = function(msg)
        msg = strtrim((msg or ""):lower())
        if msg == "lock" then
            FH.db.locked = true
            if mainFrame then mainFrame:EnableMouse(false) end
            DEFAULT_CHAT_FRAME:AddMessage("|cff88ff88[FeralHelper]|r Locked.")
        elseif msg == "unlock" then
            FH.db.locked = false
            if mainFrame then mainFrame:EnableMouse(true) end
            DEFAULT_CHAT_FRAME:AddMessage("|cff88ff88[FeralHelper]|r Unlocked — drag to reposition.")
        elseif msg == "reset" then
            FH.db.position = { point = "CENTER", x = 250, y = 0 }
            if mainFrame then
                mainFrame:ClearAllPoints()
                mainFrame:SetPoint("CENTER", UIParent, "CENTER", 250, 0)
            end
            DEFAULT_CHAT_FRAME:AddMessage("|cff88ff88[FeralHelper]|r Position reset.")
        elseif msg == "spot" then
            if not spotFrame then BuildSpotlight() end
            if spotFrame:IsShown() then
                spotFrame:Hide() ; FH.db.spotShown = false
                DEFAULT_CHAT_FRAME:AddMessage("|cff88ff88[FeralHelper]|r Spotlight hidden.")
            else
                spotFrame:Show() ; FH.db.spotShown = true
                DEFAULT_CHAT_FRAME:AddMessage("|cff88ff88[FeralHelper]|r Spotlight shown.")
            end
        else
            if not mainFrame then BuildUI() end
            if mainFrame:IsShown() then
                mainFrame:Hide() ; FH.db.shown = false
            else
                mainFrame:Show() ; FH.db.shown = true
            end
        end
    end

    BuildUI()
    BuildSpotlight()
    ScanPlayerBuffs()
    ScanTargetDebuffs()

    DEFAULT_CHAT_FRAME:AddMessage(
        "|cff88ff88[FeralHelper]|r v" .. VERSION ..
        " — Cat/Bear rotation advisor loaded. |cffffcc00/slyferal|r to toggle.")
end

-- ────────────────────────────────────────────────────────────
-- Boot
-- ────────────────────────────────────────────────────────────
local bootFrame = CreateFrame("Frame")
bootFrame:RegisterEvent("ADDON_LOADED")
bootFrame:SetScript("OnEvent", function(self, event, name)
    if name ~= ADDON_NAME then return end
    self:UnregisterEvent("ADDON_LOADED")
    if SlySuiteDataFrame and SlySuiteDataFrame.Register then
        SlySuiteDataFrame.Register(ADDON_NAME, VERSION, Init, {
            description = "Feral Druid rotation advisor — Cat DPS (powershift cycle) and Bear Tank priority display.",
            slash       = "/slyferal",
            icon        = "Interface\\Icons\\Ability_Druid_CatForm",
        })
    else
        Init()
    end
end)
