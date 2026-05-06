-- ============================================================
-- SlySuite_WarriorHelper
-- TBC Warrior rotation advisor: Fury DPS, Arms DPS, Prot Tank
--
-- Auto-detects spec from known spells (Bloodthirst/Mortal Strike/
-- Devastate). Override with /slywarrior spec fury|arms|prot
--
-- /slywarrior            toggle show/hide
-- /slywarrior lock       lock position
-- /slywarrior unlock     allow dragging
-- /slywarrior reset      move to default position
-- /slywarrior spot       toggle center-screen spotlight box
-- /slywarrior spec <s>   override spec detection
-- ============================================================

local ADDON_NAME = "SlySuite_WarriorHelper"
local VERSION    = "1.1.0"

local WH = {}
WH.db = nil

local DB_DEFAULTS = {
    locked       = false,
    shown        = true,
    combatOnly   = false,
    showSunder   = true,
    position     = { point = "CENTER", x = 250, y = 0 },
    spotShown    = true,
    spotPosition = { point = "CENTER", x = 0, y = -150 },
    spec         = nil,  -- nil = auto-detect each refresh
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
-- Icons
-- ────────────────────────────────────────────────────────────
local ICO = {
    BT         = "Interface\\Icons\\Ability_Warrior_Bloodthirst",
    WW         = "Interface\\Icons\\Ability_Warrior_Whirlwind",
    MS         = "Interface\\Icons\\Ability_Warrior_SavageBlow",
    SLAM       = "Interface\\Icons\\Ability_Warrior_Decimate",
    SS         = "Interface\\Icons\\Ability_Warrior_ShieldSlam",
    REVENGE    = "Interface\\Icons\\Ability_Warrior_Revenge",
    DEVASTATE  = "Interface\\Icons\\Inv_Stone_15",
    EXECUTE    = "Interface\\Icons\\Inv_Sword_48",
    HS         = "Interface\\Icons\\Ability_Warrior_HeroicStrike",
    SUNDER     = "Interface\\Icons\\Ability_Warrior_Sunder",
    DEMO       = "Interface\\Icons\\Ability_Warrior_WarCry",
    TC         = "Interface\\Icons\\Spell_Nature_ThunderClap",
    DW         = "Interface\\Icons\\Spell_Shadow_DeathScream",
    SHIELD_BLK = "Interface\\Icons\\Ability_Defend",
    OVERPOWER  = "Interface\\Icons\\Ability_MeleeDamage",
    RAMPAGE    = "Interface\\Icons\\Ability_Warrior_RampagePurple",
    CLEAVE     = "Interface\\Icons\\Ability_Warrior_Cleave",
    PROCS      = "Interface\\Icons\\Ability_Rogue_Sprint",
}

-- ────────────────────────────────────────────────────────────
-- Priority row definitions
-- ────────────────────────────────────────────────────────────
-- FURY: BT and WW on cooldown, Execute filler <20%, HS rage dump
-- Sunder is opener priority until 5 stacks, then passive.
-- Overpower: optional when dodge-procced, BT+WW both on CD.
-- Death Wish: passive CD — use during BL or Execute phase.
local FURY_ROWS = {
    { key="SUNDER",     label="Sunder Armor",        icon=ICO.SUNDER,    color={0.70, 0.70, 0.70} },
    { key="BT",         label="Bloodthirst",         icon=ICO.BT,        color={1.00, 0.25, 0.25} },
    { key="WW",         label="Whirlwind",           icon=ICO.WW,        color={1.00, 0.68, 0.18} },
    { key="EXECUTE",    label="Execute  (<20%)",     icon=ICO.EXECUTE,   color={1.00, 0.40, 0.10} },
    { key="OVERPOWER",  label="+ Overpower  (opt)",  icon=ICO.OVERPOWER, color={0.45, 1.00, 0.45} },
    { key="HS",         label="+ Heroic Strike",     icon=ICO.HS,        color={1.00, 0.82, 0.22} },
    { key="DEATH_WISH", label="Death Wish  (passive)",icon=ICO.DW,       color={0.60, 0.25, 0.90} },
    { key="PROCS",      label="Procs  (DST/DS/MG)",  icon=ICO.PROCS,    color={0.20, 0.90, 0.95} },
}

-- ARMS: Slam immediately post-swing, then MS → WW on CD,
-- Execute filler at <20%, HS rage dump.
-- Death Wish: passive CD indicator.
local ARMS_ROWS = {
    { key="SUNDER",     label="Sunder Armor",        icon=ICO.SUNDER,    color={0.70, 0.70, 0.70} },
    { key="SLAM",       label="Slam  (post-swing)",  icon=ICO.SLAM,      color={1.00, 0.95, 0.35} },
    { key="MS",         label="Mortal Strike",       icon=ICO.MS,        color={1.00, 0.25, 0.25} },
    { key="WW",         label="Whirlwind",           icon=ICO.WW,        color={1.00, 0.68, 0.18} },
    { key="EXECUTE",    label="Execute  (<20%)",     icon=ICO.EXECUTE,   color={1.00, 0.40, 0.10} },
    { key="HS",         label="+ Heroic Strike",     icon=ICO.HS,        color={1.00, 0.82, 0.22} },
    { key="DEATH_WISH", label="Death Wish  (passive)",icon=ICO.DW,       color={0.60, 0.25, 0.90} },
    { key="PROCS",      label="Procs  (DST/DS/MG)",  icon=ICO.PROCS,    color={0.20, 0.90, 0.95} },
}

-- PROT: Shield Slam > Revenge > demo/TC debuffs > Devastate filler
-- Shield Block: parallel off-GCD track — CRITICAL vs crushing bosses.
-- Heroic Strike: last resort rage dump only.
local PROT_ROWS = {
    { key="SHIELD_BLOCK", label="Shield Block  (crit/crush)", icon=ICO.SHIELD_BLK, color={0.40, 0.85, 1.00} },
    { key="SHIELD_SLAM",  label="Shield Slam",               icon=ICO.SS,          color={1.00, 0.55, 0.10} },
    { key="REVENGE",      label="Revenge",                   icon=ICO.REVENGE,     color={0.90, 0.28, 0.28} },
    { key="DEMO_SHOUT",   label="Demo Shout",                icon=ICO.DEMO,        color={0.65, 0.40, 1.00} },
    { key="THUNDER_CLAP", label="Thunder Clap",              icon=ICO.TC,          color={0.38, 0.84, 1.00} },
    { key="DEVASTATE",    label="Devastate  (filler)",       icon=ICO.DEVASTATE,   color={0.65, 0.65, 0.70} },
    { key="HS",           label="+ Heroic Strike  (dump)",   icon=ICO.HS,          color={1.00, 0.82, 0.22} },
}

-- ────────────────────────────────────────────────────────────
-- Combat state
-- ────────────────────────────────────────────────────────────
local playerRage      = 0
local playerHP        = 1.0
local targetHP        = 1.0
local playerGUID      = nil

-- Debuff/buff timers
local sunderStacks    = 0     -- Sunder Armor stacks on target (0-5)
local sunderExpiry    = 0
local exposeArmor     = false -- Expose Armor (rogue EA) present on target
local exposeExpiry    = 0
local demoShoutExpiry = 0     -- Demoralizing Shout on target
local thunderExpiry   = 0     -- Thunder Clap on target
local dwishExpiry     = 0     -- Death Wish buff on player

-- Arms swing timer
local lastSwingTime   = 0
local swingDuration   = 2.0   -- MH attack speed in seconds

-- Overpower proc window (dodge detected)
local overpowerExpiry = 0

-- Haste proc windows
local dstExpiry          = 0   -- Dragonspine Trophy "Haste" proc
local dragonstrikeExpiry = 0   -- Dragonstrike weapon enchant proc
local mongooseExpiry     = 0   -- Mongoose weapon enchant proc

-- ────────────────────────────────────────────────────────────
-- Spec detection
-- Devastate = 41-pt Prot talent → PROT
-- Bloodthirst = 30-pt Fury talent → FURY
-- Mortal Strike = 30-pt Arms talent → ARMS
-- ────────────────────────────────────────────────────────────
local function DetectSpec()
    if WH.db and WH.db.spec then return WH.db.spec end
    -- Check 30-pt DPS talents first — they are mutually exclusive with each other
    -- and unambiguously identify the primary tree.  Devastate is the 41-pt Prot
    -- talent but check it last so a Fury/Arms warrior who happens to have a few
    -- Prot points doesn't get misidentified.
    if GetSpellInfo("Bloodthirst")   then return "FURY" end
    if GetSpellInfo("Mortal Strike") then return "ARMS" end
    if GetSpellInfo("Devastate")     then return "PROT" end
    return "FURY"
end

-- ────────────────────────────────────────────────────────────
-- Helpers
-- ────────────────────────────────────────────────────────────
local function SpellCD(spellName)
    local start, dur = GetSpellCooldown(spellName)
    if dur and dur > 1.5 then
        return math.max(0, start + dur - GetTime())
    end
    return 0
end

local function Fmt(secs)
    if secs <= 0 then return "" end
    if secs >= 10 then return string.format("%.0fs", secs) end
    return string.format("%.1fs", secs)
end

local function Col(hex, s) return string.format("|cff%s%s|r", hex, s) end

-- ────────────────────────────────────────────────────────────
-- Debuff / buff scanners
-- ────────────────────────────────────────────────────────────
local function ScanTargetDebuffs()
    sunderStacks    = 0
    sunderExpiry    = 0
    exposeArmor     = false
    exposeExpiry    = 0
    demoShoutExpiry = 0
    thunderExpiry   = 0
    if not UnitExists("target") then return end

    local i = 1
    while true do
        local name, _, count, _, _, expireTime = UnitDebuff("target", i)
        if not name then break end
        if name == "Sunder Armor" then
            sunderStacks = count or 1
            sunderExpiry = expireTime or 0
        end
        if name == "Expose Armor" then
            exposeArmor  = true
            exposeExpiry = expireTime or 0
        end
        if name == "Demoralizing Shout" then
            demoShoutExpiry = expireTime or 0
        end
        if name == "Thunder Clap" then
            thunderExpiry = expireTime or 0
        end
        i = i + 1
    end
end

local function ScanPlayerBuffs()
    dwishExpiry         = 0
    dstExpiry           = 0
    dragonstrikeExpiry  = 0
    mongooseExpiry      = 0
    local i = 1
    while true do
        local name, _, _, _, _, expireTime = UnitBuff("player", i)
        if not name then break end
        if name == "Death Wish"   then dwishExpiry         = expireTime or 0 end
        if name == "Haste"        then dstExpiry           = expireTime or 0 end
        if name == "Dragonstrike" then dragonstrikeExpiry  = expireTime or 0 end
        if name == "Mongoose"     then mongooseExpiry      = expireTime or 0 end
        i = i + 1
    end
end

-- ────────────────────────────────────────────────────────────
-- UI constants + frames
-- ────────────────────────────────────────────────────────────
local FRAME_W    = 210
local HDR_H      = 18
local ROW_H      = 22
local ICON_S     = 16
local PAD        = 5
local STATUS_W   = 70

local mainFrame       = nil
local modeLabel       = nil
local furyContainer   = nil
local armsContainer   = nil
local protContainer   = nil
local furyRowFrames   = {}
local armsRowFrames   = {}
local protRowFrames   = {}

local spotFrame = nil
local spotIcon  = nil
local spotName  = nil
local spotSub   = nil

local function BuildRow(parent, rowDef, idx)
    local row = CreateFrame("Frame", nil, parent)
    row:SetSize(FRAME_W, ROW_H)
    row:SetPoint("TOPLEFT", parent, "TOPLEFT", 0, -(idx - 1) * (ROW_H + 1))

    local bg = row:CreateTexture(nil, "BACKGROUND")
    bg:SetAllPoints()
    bg:SetColorTexture(0, 0, 0, idx % 2 == 0 and 0.18 or 0.05)
    row.bg = bg

    local glow = row:CreateTexture(nil, "BORDER")
    glow:SetAllPoints()
    glow:SetColorTexture(rowDef.color[1], rowDef.color[2], rowDef.color[3], 0)
    row.glow = glow

    local num = row:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    num:SetFont(num:GetFont(), 7, "OUTLINE")
    num:SetPoint("LEFT", row, "LEFT", 2, 0)
    num:SetWidth(10)
    num:SetJustifyH("CENTER")
    num:SetText(Col("444455", tostring(idx)))
    row.num = num

    local icon = row:CreateTexture(nil, "ARTWORK")
    icon:SetSize(ICON_S, ICON_S)
    icon:SetPoint("LEFT", row, "LEFT", 14, 0)
    icon:SetTexture(rowDef.icon)
    icon:SetTexCoord(0.07, 0.93, 0.07, 0.93)
    icon:SetAlpha(0.40)
    row.icon = icon

    local lbl = row:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    lbl:SetFont(lbl:GetFont(), 9, "OUTLINE")
    lbl:SetPoint("LEFT", row, "LEFT", 34, 0)
    lbl:SetWidth(FRAME_W - 34 - STATUS_W - PAD)
    lbl:SetJustifyH("LEFT")
    lbl:SetText(rowDef.label)
    lbl:SetTextColor(0.38, 0.38, 0.42)
    row.lbl = lbl

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

-- Show/hide and reposition Sunder rows in Fury and Arms containers.
local function RefreshSunderRows()
    local show = WH.db and WH.db.showSunder ~= false
    local function relayout(rowFrames)
        local visIdx = 0
        for _, row in ipairs(rowFrames) do
            local visible = (row.rowDef.key ~= "SUNDER") or show
            row:SetShown(visible)
            if visible then
                visIdx = visIdx + 1
                row:ClearAllPoints()
                row:SetPoint("TOPLEFT", row:GetParent(), "TOPLEFT", 0, -(visIdx - 1) * (ROW_H + 1))
                row.bg:SetColorTexture(0, 0, 0, visIdx % 2 == 0 and 0.18 or 0.05)
                row.num:SetText(Col("444455", tostring(visIdx)))
            end
        end
    end
    relayout(furyRowFrames)
    relayout(armsRowFrames)
end

local function BuildUI()
    if mainFrame then return end

    local furyH = #FURY_ROWS * (ROW_H + 1)
    local armsH = #ARMS_ROWS * (ROW_H + 1)
    local protH = #PROT_ROWS * (ROW_H + 1)
    local bodyH = math.max(furyH, math.max(armsH, protH))
    local FRAME_H = HDR_H + 2 + bodyH + 4

    local pos = WH.db.position
    local f = CreateFrame("Frame", "SlyWarriorHelperFrame", UIParent)
    f:SetSize(FRAME_W, FRAME_H)
    f:SetFrameStrata("MEDIUM")
    f:SetMovable(true)
    f:EnableMouse(false)
    f:SetClampedToScreen(true)
    f:ClearAllPoints()
    f:SetPoint(pos.point or "CENTER", UIParent, pos.point or "CENTER",
               pos.x or 250, pos.y or 0)

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

    local hdrIcon = hdr:CreateTexture(nil, "ARTWORK")
    hdrIcon:SetSize(14, 14)
    hdrIcon:SetPoint("LEFT", hdr, "LEFT", 4, 0)
    hdrIcon:SetTexture(ICO.BT)
    hdrIcon:SetTexCoord(0.07, 0.93, 0.07, 0.93)

    local titleTx = hdr:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    titleTx:SetFont(titleTx:GetFont(), 9, "OUTLINE")
    titleTx:SetPoint("LEFT", hdrIcon, "RIGHT", 4, 0)
    titleTx:SetText(Col("cc8844", "WARRIOR") .. " " .. Col("888888", "ROTATION"))

    modeLabel = hdr:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    modeLabel:SetFont(modeLabel:GetFont(), 9, "OUTLINE")
    modeLabel:SetPoint("RIGHT", hdr, "RIGHT", -5, 0)
    modeLabel:SetText(Col("444455", "---"))

    local sep = f:CreateTexture(nil, "ARTWORK")
    sep:SetSize(FRAME_W - 2, 1)
    sep:SetPoint("TOPLEFT", f, "TOPLEFT", 1, -HDR_H)
    sep:SetColorTexture(TC("sep"))

    local body = CreateFrame("Frame", nil, f)
    body:SetSize(FRAME_W, bodyH)
    body:SetPoint("TOPLEFT", f, "TOPLEFT", 0, -(HDR_H + 2))

    -- Fury container
    furyContainer = CreateFrame("Frame", nil, body)
    furyContainer:SetSize(FRAME_W, furyH)
    furyContainer:SetPoint("TOPLEFT", body, "TOPLEFT", 0, 0)
    furyContainer:Hide()
    furyRowFrames = {}
    for i, rd in ipairs(FURY_ROWS) do
        rd._idx = i
        furyRowFrames[i] = BuildRow(furyContainer, rd, i)
    end

    -- Arms container
    armsContainer = CreateFrame("Frame", nil, body)
    armsContainer:SetSize(FRAME_W, armsH)
    armsContainer:SetPoint("TOPLEFT", body, "TOPLEFT", 0, 0)
    armsContainer:Hide()
    armsRowFrames = {}
    for i, rd in ipairs(ARMS_ROWS) do
        rd._idx = i
        armsRowFrames[i] = BuildRow(armsContainer, rd, i)
    end

    -- Prot container
    protContainer = CreateFrame("Frame", nil, body)
    protContainer:SetSize(FRAME_W, protH)
    protContainer:SetPoint("TOPLEFT", body, "TOPLEFT", 0, 0)
    protContainer:Hide()
    protRowFrames = {}
    for i, rd in ipairs(PROT_ROWS) do
        rd._idx = i
        protRowFrames[i] = BuildRow(protContainer, rd, i)
    end

    -- Drag handle
    local drag = CreateFrame("Frame", nil, f)
    drag:SetAllPoints()
    drag:EnableMouse(true)
    drag:RegisterForDrag("LeftButton")
    drag:SetScript("OnDragStart", function()
        if not WH.db.locked then f:StartMoving() end
    end)
    drag:SetScript("OnDragStop", function()
        f:StopMovingOrSizing()
        local pt, _, _, x, y = f:GetPoint()
        WH.db.position = { point = pt or "CENTER", x = x or 0, y = y or 0 }
    end)

    mainFrame = f
    if not WH.db.shown then f:Hide() end

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
-- Spotlight frame
-- ────────────────────────────────────────────────────────────
local SPOT_W, SPOT_H = 210, 68

local function BuildSpotlight()
    if spotFrame then return end
    local sp = WH.db.spotPosition or { point="CENTER", x=0, y=-150 }
    local f  = CreateFrame("Frame", "SlyWarriorHelperSpot", UIParent)
    f:SetSize(SPOT_W, SPOT_H)
    f:SetFrameStrata("MEDIUM")
    f:SetMovable(true)
    f:SetClampedToScreen(true)
    f:SetPoint(sp.point or "CENTER", UIParent, sp.point or "CENTER", sp.x or 0, sp.y or -150)
    f:EnableMouse(true)
    f:RegisterForDrag("LeftButton")
    f:SetScript("OnDragStart", function()
        if not WH.db.locked then f:StartMoving() end
    end)
    f:SetScript("OnDragStop", function()
        f:StopMovingOrSizing()
        local pt, _, _, x, y = f:GetPoint()
        WH.db.spotPosition = { point = pt or "CENTER", x = x or 0, y = y or 0 }
    end)

    local bdr = f:CreateTexture(nil, "BACKGROUND")
    bdr:SetAllPoints()
    bdr:SetColorTexture(0.28, 0.28, 0.35, 1)
    f._bdr = bdr

    local inner = f:CreateTexture(nil, "BORDER")
    inner:SetPoint("TOPLEFT",     f, "TOPLEFT",      1, -1)
    inner:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", -1,  1)
    inner:SetColorTexture(0.04, 0.04, 0.07, 0.94)

    local ico = f:CreateTexture(nil, "ARTWORK")
    ico:SetSize(52, 52)
    ico:SetPoint("LEFT", f, "LEFT", 8, 0)
    ico:SetTexCoord(0.07, 0.93, 0.07, 0.93)
    spotIcon = ico

    local nm = f:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    nm:SetFont(nm:GetFont(), 15, "OUTLINE")
    nm:SetPoint("TOPLEFT", ico, "TOPRIGHT", 8, -4)
    nm:SetPoint("RIGHT",   f,   "RIGHT",   -6, 0)
    nm:SetJustifyH("LEFT")
    nm:SetWordWrap(false)
    nm:SetText("|cff888888--|r")
    spotName = nm

    local sub = f:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    sub:SetFont(sub:GetFont(), 10, "OUTLINE")
    sub:SetPoint("BOTTOMLEFT", ico, "BOTTOMRIGHT", 8, 4)
    sub:SetPoint("RIGHT",      f,   "RIGHT",      -6, 0)
    sub:SetJustifyH("LEFT")
    sub:SetText("")
    spotSub = sub

    local tag = f:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    tag:SetFont(tag:GetFont(), 8, "OUTLINE")
    tag:SetPoint("TOPLEFT", f, "TOPLEFT", 4, -3)
    tag:SetText("|cff556655NEXT|r")

    spotFrame = f
    if WH.db.spotShown == false then f:Hide() end
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
    local c   = rd.color
    local hex = string.format("%02x%02x%02x",
        math.floor(c[1]*255), math.floor(c[2]*255), math.floor(c[3]*255))
    spotName:SetText("|cff" .. hex .. rd.label .. "|r")
    spotIcon:SetTexture(rd.icon)
    spotSub:SetText(statusStr or "")
    if spotFrame._bdr then
        spotFrame._bdr:SetColorTexture(c[1]*0.6, c[2]*0.6, c[3]*0.6, 0.95)
    end
end

-- ────────────────────────────────────────────────────────────
-- FURY rotation
-- Priority:
--   1. Sunder Armor   — until 5 stacks (opener/refresh)
--   2. Bloodthirst    — highest priority, always on CD
--   3. Whirlwind      — always on CD
--   4. Execute        — filler only at <20% HP when BT+WW on CD
--   5. Overpower      — optional: dodge proc, BT+WW both on CD
--   6. Heroic Strike  — off-GCD rage dump (never starve BT/WW)
-- Death Wish: passive — use during BL or Execute phase
-- ────────────────────────────────────────────────────────────
local function UpdateFury(now)
    local rage    = playerRage
    local tHP     = targetHP
    local btCD    = SpellCD("Bloodthirst")
    local wwCD    = SpellCD("Whirlwind")
    local dwCD    = SpellCD("Death Wish")
    local dwL     = dwishExpiry > 0 and math.max(0, dwishExpiry - now) or 0
    local sunL    = sunderExpiry > 0 and math.max(0, sunderExpiry - now) or 0
    local exPhase = tHP < 0.20
    -- Overpower: usable only when procced (dodge) + in Battle Stance
    local opReady = IsUsableSpell and IsUsableSpell("Overpower")
    -- GCD buffer — don't use filler if BT or WW are up in < 1 GCD
    local GCD     = 1.5
    local btSoon  = btCD < GCD
    local wwSoon  = wwCD < GCD
    -- Haste proc windows
    local dstL    = dstExpiry          > 0 and math.max(0, dstExpiry          - now) or 0
    local dsL     = dragonstrikeExpiry > 0 and math.max(0, dragonstrikeExpiry - now) or 0
    local mgL     = mongooseExpiry     > 0 and math.max(0, mongooseExpiry     - now) or 0
    local anyProc = dstL > 0 or dsL > 0 or mgL > 0

    -- Priority decision
    local best
    -- Sunder: urgent if stacks < 5, no EA rogue covering, and BT/WW not imminent
    if WH.db.showSunder and sunderStacks < 5 and not exposeArmor and not btSoon and not wwSoon then
        best = "SUNDER"
    elseif btCD <= 0 then
        best = "BT"
    elseif wwCD <= 0 then
        best = "WW"
    elseif exPhase and rage >= 10 and not btSoon and not wwSoon then
        best = "EXECUTE"
    elseif opReady and not btSoon and not wwSoon then
        best = "OVERPOWER"
    elseif btCD <= wwCD then
        best = "BT"    -- BT coming sooner — focus here
    else
        best = "WW"
    end

    -- HS: off-GCD rage dump — only when not risking BT/WW starvation
    -- Lower threshold when haste procs active (swing speed up → more rage income)
    local hsThresh = anyProc and 60 or 70
    local hsDump = rage >= hsThresh and btCD > 0 and wwCD > 0

    for _, row in ipairs(furyRowFrames) do
        local k      = row.rowDef.key
        local active = (k == best) or (k == "HS" and hsDump) or (k == "PROCS" and anyProc)
        local s      = ""

        if k == "SUNDER" then
            if exposeArmor then
                -- EA rogue covering armor slot -- do NOT overwrite a stronger debuff
                local eaL = exposeExpiry > 0 and math.max(0, exposeExpiry - now) or 0
                s = Col("44aa44", "EA up  ") .. Col("888888", eaL > 0 and Fmt(eaL) or "")
            elseif sunderStacks >= 5 then
                if sunL > 0 then
                    s = Col("44aa44", "5/5  ") .. Col("888888", Fmt(sunL))
                else
                    s = Col("ff6622", "5/5 REFRESH")
                end
            elseif sunderStacks > 0 then
                s = Col("ffcc44", sunderStacks .. "/5  ") .. Col("888888", Fmt(sunL))
            else
                s = Col("ff4444", "APPLY NOW")
            end

        elseif k == "BT" then
            if btCD <= 0 then
                s = Col("44ff44", "CAST NOW  ") .. Col("aaaaaa", rage .. "R")
            elseif btSoon then
                s = Col("ffdd22", "SOON  ") .. Col("ff8844", Fmt(btCD))
            else
                -- Show BT countdown and when WW follows after
                local seqStr = wwCD > 0 and ("  → WW " .. Fmt(wwCD)) or "  → WW READY"
                s = Col("ff8844", Fmt(btCD)) .. Col("555566", seqStr)
            end

        elseif k == "WW" then
            if wwCD <= 0 then
                s = Col("44ff44", "CAST NOW  ") .. Col("aaaaaa", rage .. "R")
            elseif wwSoon then
                s = Col("ffdd22", "SOON  ") .. Col("ff8844", Fmt(wwCD))
            else
                -- Show WW countdown and when BT follows after
                local seqStr = btCD > 0 and ("  >> BT " .. Fmt(btCD)) or "  >> BT READY"
                s = Col("ff8844", Fmt(wwCD)) .. Col("555566", seqStr)
            end

        elseif k == "EXECUTE" then
            if exPhase then
                if rage >= 10 and not btSoon and not wwSoon then
                    s = Col("ff4444", "FILLER  ") .. Col("ffcc44", string.format("%.0f%%", tHP * 100))
                elseif btSoon or wwSoon then
                    s = Col("888888", "hold BT/WW  ") .. Col("ffcc44", string.format("%.0f%%", tHP * 100))
                else
                    s = Col("aaaaaa", "low rage  ") .. Col("ffcc44", string.format("%.0f%%", tHP * 100))
                end
            else
                s = Col("555566", string.format("%.0f%%", tHP * 100) .. "  not yet")
            end

        elseif k == "OVERPOWER" then
            if opReady then
                if not btSoon and not wwSoon then
                    s = Col("aaffaa", "PROCCED  ") .. Col("888888", "Battle Stance")
                else
                    s = Col("ff8844", "PROCCED  ") .. Col("555566", "hold BT/WW first")
                end
            else
                s = Col("555566", "no proc")
            end

        elseif k == "HS" then
            -- Off-GCD swing replacement — rage dump
            if hsDump then
                s = Col("ffee55", "QUEUE  ") .. Col("aaaaaa", rage .. "R excess")
            elseif rage >= 50 then
                s = Col("888844", rage .. "R  watch BT/WW")
            else
                s = Col("555566", rage .. "R  save it")
            end

        elseif k == "DEATH_WISH" then
            if dwL > 0 then
                s = Col("cc44ff", "ACTIVE  ") .. Col("aaaaaa", Fmt(dwL))
            elseif dwCD <= 0 then
                s = Col("aa44ff", "READY  ") .. Col("888888", "BL or exec phase")
            else
                s = Col("555566", "CD  ") .. Col("888888", Fmt(dwCD))
            end

        elseif k == "PROCS" then
            if anyProc then
                local parts = {}
                if dstL > 0 then parts[#parts+1] = Col("22ddff", "DST " .. Fmt(dstL)) end
                if dsL  > 0 then parts[#parts+1] = Col("ff9944", "DS "  .. Fmt(dsL))  end
                if mgL  > 0 then parts[#parts+1] = Col("44ff88", "MG "  .. Fmt(mgL))  end
                s = table.concat(parts, Col("555566", " | "))
                if rage >= hsThresh - 10 then
                    s = s .. Col("ffee55", "  HS!")
                end
            else
                s = Col("333344", "—")
            end
        end

        SetRowState(row, active, s)
    end

    local spCol = exPhase and "ff4444" or "aaaaaa"
    modeLabel:SetText(
        Col("cc3333", "FURY") .. "  " ..
        Col("aaaaaa", rage .. "R ") ..
        Col(spCol, string.format("%.0f%%", tHP * 100))
    )

    local nextFury = btCD <= wwCD and "BT" or "WW"
    local nextFuryCD = btCD <= wwCD and btCD or wwCD
    local afterFury  = btCD <= wwCD
                       and (wwCD > 0 and (" >> WW " .. Fmt(wwCD)) or " >> WW READY")
                       or  (btCD > 0 and (" >> BT " .. Fmt(btCD)) or " >> BT READY")
    local spotSt
    if best == "BT" or best == "WW" then
        if nextFuryCD <= 0 then
            spotSt = "CAST" .. afterFury
        else
            spotSt = ">> " .. nextFury .. " " .. Fmt(nextFuryCD) .. afterFury
        end
    elseif best == "EXECUTE" then
        spotSt = string.format("%.0f%%", tHP*100) .. "  " .. rage .. "R"
    else
        spotSt = rage .. "R"
    end
    UpdateSpotlight(best, FURY_ROWS, spotSt)
end

-- ────────────────────────────────────────────────────────────
-- ARMS rotation
-- Priority:
--   1. Sunder Armor   — until 5 stacks
--   2. Slam           — IMMEDIATELY after every MH swing
--   3. Mortal Strike  — first ability after Slam each loop
--   4. Whirlwind      — second ability after Slam each loop
--   5. Execute        — filler at <20%, never ahead of MS/WW
--   6. Heroic Strike  — off-GCD rage dump
-- Loop = Swing → Slam → MS → Swing → Slam → WW → Swing → Slam → filler ∞
-- ────────────────────────────────────────────────────────────
local function UpdateArms(now)
    local rage    = playerRage
    local tHP     = targetHP
    local msCD    = SpellCD("Mortal Strike")
    local wwCD    = SpellCD("Whirlwind")
    local dwCD    = SpellCD("Death Wish")
    local dwL     = dwishExpiry > 0 and math.max(0, dwishExpiry - now) or 0
    local sunL    = sunderExpiry > 0 and math.max(0, sunderExpiry - now) or 0
    local exPhase = tHP < 0.20
    -- Haste proc windows
    local dstL    = dstExpiry          > 0 and math.max(0, dstExpiry          - now) or 0
    local dsL     = dragonstrikeExpiry > 0 and math.max(0, dragonstrikeExpiry - now) or 0
    local mgL     = mongooseExpiry     > 0 and math.max(0, mongooseExpiry     - now) or 0
    local anyProc = dstL > 0 or dsL > 0 or mgL > 0

    -- Swing timer
    local timeSinceSwing = now - lastSwingTime
    local nextSwingIn    = math.max(0, (lastSwingTime + swingDuration) - now)
    -- Slam window: cast within 0.5s of swing completing
    local slamWindow     = (swingDuration > 0) and (timeSinceSwing >= 0) and (timeSinceSwing <= 0.5)

    local GCD    = 1.5
    local msSoon = msCD < GCD
    local wwSoon = wwCD < GCD

    -- Priority decision
    local best
    if WH.db.showSunder and sunderStacks < 5 and not exposeArmor and not slamWindow and not msSoon and not wwSoon then
        best = "SUNDER"
    elseif slamWindow and rage >= 15 then
        best = "SLAM"    -- highest urgency — window is only 0.5s
    elseif msCD <= 0 then
        best = "MS"
    elseif wwCD <= 0 then
        best = "WW"
    elseif exPhase and rage >= 10 and not msSoon and not wwSoon then
        best = "EXECUTE"
    elseif msCD <= wwCD then
        best = "MS"      -- MS coming sooner
    else
        best = "WW"
    end

    local hsThresh = anyProc and 60 or 70
    local hsDump = rage >= hsThresh and not slamWindow and not msSoon and not wwSoon

    for _, row in ipairs(armsRowFrames) do
        local k      = row.rowDef.key
        local active = (k == best) or (k == "HS" and hsDump) or (k == "PROCS" and anyProc)
        local s      = ""

        if k == "SUNDER" then
            if exposeArmor then
                local eaL = exposeExpiry > 0 and math.max(0, exposeExpiry - now) or 0
                s = Col("44aa44", "EA up  ") .. Col("888888", eaL > 0 and Fmt(eaL) or "")
            elseif sunderStacks >= 5 then
                s = Col("44aa44", "5/5  ") .. Col("888888", Fmt(sunL))
            elseif sunderStacks > 0 then
                s = Col("ffcc44", sunderStacks .. "/5  ") .. Col("888888", Fmt(sunL))
            else
                s = Col("ff4444", "APPLY NOW")
            end

        elseif k == "SLAM" then
            -- Entire spec revolves around this timing
            if slamWindow then
                local nextAbility = msCD <= 0 and "MS" or (wwCD <= 0 and "WW" or (msCD <= wwCD and "MS" or "WW"))
                local nextCD      = msCD <= 0 and 0   or (wwCD <= 0 and 0   or math.min(msCD, wwCD))
                local seqStr      = nextCD <= 0 and (" → " .. nextAbility .. " READY") or (" → " .. nextAbility .. " " .. Fmt(nextCD))
                s = Col("ffee00", "CAST NOW!") .. Col("888888", seqStr)
            elseif timeSinceSwing > 0.5 and swingDuration > 0 then
                -- Window passed — show next swing + what comes after
                local nextAbility = msCD <= wwCD and "MS" or "WW"
                local nextCD      = math.min(msCD, wwCD)
                local seqStr      = nextCD <= 0 and (" → " .. nextAbility .. " READY") or (" → " .. nextAbility .. " " .. Fmt(nextCD))
                s = Col("555566", "swing "  ) .. Col("ff8844", string.format("%.1f", nextSwingIn) .. "s") .. Col("555566", seqStr)
            else
                local nextAbility = msCD <= wwCD and "MS" or "WW"
                local seqStr      = " → SLAM → " .. nextAbility
                s = Col("555566", "swing in  ") .. Col("888888", string.format("%.1f", nextSwingIn) .. "s") .. Col("444455", seqStr)
            end

        elseif k == "MS" then
            if msCD <= 0 then
                s = Col("44ff44", "CAST NOW  ") .. Col("aaaaaa", rage .. "R")
            elseif msSoon then
                s = Col("ffdd22", "SOON  ") .. Col("ff8844", Fmt(msCD))
            else
                -- Show MS countdown + when WW follows
                local seqStr = wwCD > 0 and ("  → WW " .. Fmt(wwCD)) or "  → WW READY"
                s = Col("ff8844", Fmt(msCD)) .. Col("555566", seqStr)
            end

        elseif k == "WW" then
            if wwCD <= 0 then
                s = Col("44ff44", "CAST NOW  ") .. Col("aaaaaa", rage .. "R")
            elseif wwSoon then
                s = Col("ffdd22", "SOON  ") .. Col("ff8844", Fmt(wwCD))
            else
                -- Show WW countdown + when MS follows
                local seqStr = msCD > 0 and ("  → MS " .. Fmt(msCD)) or "  → MS READY"
                s = Col("ff8844", Fmt(wwCD)) .. Col("555566", seqStr)
            end

        elseif k == "EXECUTE" then
            if exPhase then
                if not msSoon and not wwSoon and rage >= 10 then
                    s = Col("ff4444", "FILLER  ") .. Col("ffcc44", string.format("%.0f%%", tHP * 100))
                else
                    s = Col("888888", "hold MS/WW  ") .. Col("ffcc44", string.format("%.0f%%", tHP * 100))
                end
            else
                s = Col("555566", string.format("%.0f%%", tHP * 100) .. "  not yet")
            end

        elseif k == "HS" then
            if hsDump then
                s = Col("ffee55", "QUEUE  ") .. Col("aaaaaa", rage .. "R excess")
            elseif rage >= 50 then
                s = Col("888844", rage .. "R  watch MS/WW")
            else
                s = Col("555566", rage .. "R  save it")
            end

        elseif k == "DEATH_WISH" then
            if dwL > 0 then
                s = Col("cc44ff", "ACTIVE  ") .. Col("aaaaaa", Fmt(dwL))
            elseif dwCD <= 0 then
                s = Col("aa44ff", "READY  ") .. Col("888888", "BL or exec phase")
            else
                s = Col("555566", "CD  ") .. Col("888888", Fmt(dwCD))
            end

        elseif k == "PROCS" then
            if anyProc then
                local parts = {}
                if dstL > 0 then parts[#parts+1] = Col("22ddff", "DST " .. Fmt(dstL)) end
                if dsL  > 0 then parts[#parts+1] = Col("ff9944", "DS "  .. Fmt(dsL))  end
                if mgL  > 0 then parts[#parts+1] = Col("44ff88", "MG "  .. Fmt(mgL))  end
                s = table.concat(parts, Col("555566", " | "))
                -- Faster swings = more rage; remind player to HS sooner
                if rage >= hsThresh - 10 then
                    s = s .. Col("ffee55", "  HS!")
                end
            else
                s = Col("333344", "—")
            end
        end

        SetRowState(row, active, s)
    end

    local swCol = slamWindow and "ffee00" or "888888"
    modeLabel:SetText(
        Col("ddcc22", "ARMS") .. "  " ..
        Col("aaaaaa", rage .. "R ") ..
        Col(swCol, string.format("%.1fs", nextSwingIn) .. "sw")
    )

    local nextArms   = msCD <= wwCD and "MS" or "WW"
    local nextArmsCD = msCD <= wwCD and msCD or wwCD
    local afterArms  = msCD <= wwCD
        and (wwCD > 0 and (" → WW " .. Fmt(wwCD)) or " → WW READY")
        or  (msCD > 0 and (" → MS " .. Fmt(msCD)) or " → MS READY")
    local spotSt
    if slamWindow then
        spotSt = "CAST NOW! +" .. string.format("%.2f", timeSinceSwing) .. "s" .. afterArms
    elseif best == "MS" or best == "WW" then
        if nextArmsCD <= 0 then
            spotSt = "CAST" .. afterArms
        else
            spotSt = ">> " .. nextArms .. " " .. Fmt(nextArmsCD) .. afterArms
        end
    elseif best == "EXECUTE" then
        spotSt = string.format("%.0f%%", tHP * 100) .. "  " .. rage .. "R"
    elseif best == "SLAM" then
        spotSt = "swing in " .. string.format("%.1f", nextSwingIn) .. "s" .. afterArms
    else
        spotSt = rage .. "R"
    end
    UpdateSpotlight(best, ARMS_ROWS, spotSt)
end

-- ────────────────────────────────────────────────────────────
-- PROT rotation
-- Main GCD loop: Shield Slam → Revenge → Devastate → Devastate ∞
-- Debuff fillers replacing Devastate when expiring:
--   Demo Shout (<3s left or missing), Thunder Clap (<3s or missing)
-- Parallel tracks (off-GCD / separate priority):
--   Shield Block — CRITICAL vs crushing bosses, keep on CD
--   Heroic Strike — last resort rage dump only
-- ────────────────────────────────────────────────────────────
local function UpdateProt(now)
    local rage    = playerRage
    local hp      = playerHP
    local ssCD    = SpellCD("Shield Slam")
    local revengeReady = SpellCD("Revenge") <= 0   -- proc resets to 0 when available
    local sbCD    = SpellCD("Shield Block")
    local demoL   = demoShoutExpiry > 0 and math.max(0, demoShoutExpiry - now) or 0
    local tcL     = thunderExpiry   > 0 and math.max(0, thunderExpiry   - now) or 0
    local sunL    = sunderExpiry    > 0 and math.max(0, sunderExpiry    - now) or 0
    -- Check if shield is equipped (shield slam becomes unusable without one)
    local ssUsable = IsUsableSpell and IsUsableSpell("Shield Slam")
    local GCD = 1.5

    -- GCD priority: SS → Revenge → debuffs as fillers → Devastate
    local best
    if ssUsable and ssCD <= 0 and rage >= 20 then
        best = "SHIELD_SLAM"
    elseif revengeReady and rage >= 5 then
        best = "REVENGE"
    elseif (demoL == 0 or demoL < 3) and rage >= 10 then
        best = "DEMO_SHOUT"
    elseif (tcL == 0 or tcL < 3) and rage >= 20 then
        best = "THUNDER_CLAP"
    elseif ssCD <= GCD and rage >= 20 then
        -- SS about to come up — hold the GCD
        best = "SHIELD_SLAM"
    else
        best = "DEVASTATE"
    end

    -- Shield Block: off-main-priority track
    -- Highlight as urgent when CD is up (critical vs crushing bosses)
    local sbReady = sbCD <= 0

    -- HS: rage dump when well above threshold and loop is not at risk
    local hsDump  = rage >= 75 and ssCD > 0

    for _, row in ipairs(protRowFrames) do
        local k      = row.rowDef.key
        local active = (k == best)
                    or (k == "SHIELD_BLOCK" and sbReady)
                    or (k == "HS" and hsDump)
        local s      = ""

        if k == "SHIELD_BLOCK" then
            if sbCD <= 0 then
                s = Col("44ddff", "PRESS NOW  ") .. Col("888888", "remove crush")
            elseif sbCD < 3 then
                s = Col("ffdd22", "SOON  ") .. Col("ff8844", Fmt(sbCD))
            else
                s = Col("ff8844", Fmt(sbCD)) .. Col("888888", "  refreshing")
            end

        elseif k == "SHIELD_SLAM" then
            if not ssUsable then
                s = Col("555566", "no shield  ") .. Col("444455", "devastate mode")
            elseif ssCD <= 0 then
                s = Col("44ff44", "CAST NOW  ") .. Col("aaaaaa", rage .. "R")
            elseif ssCD < GCD then
                s = Col("ffdd22", "SOON  ") .. Col("ff8844", Fmt(ssCD))
            else
                s = Col("ff8844", Fmt(ssCD)) .. Col("888888", "  wait")
            end

        elseif k == "REVENGE" then
            if revengeReady then
                s = Col("44ff44", "PROCCED  ") .. Col("aaaaaa", rage .. "R")
            else
                -- Revenge resets on dodge/block/parry — brief 5s window
                -- SpellCD will show the CD when not procced
                local rCD = SpellCD("Revenge")
                if rCD > 0 then
                    s = Col("888888", "wait dodge/block  ") .. Col("555566", Fmt(rCD))
                else
                    s = Col("555566", "no proc yet")
                end
            end

        elseif k == "DEMO_SHOUT" then
            if demoL == 0 then
                s = Col("ff4444", "MISSING!  ") .. Col("888888", "~18% dmg reduc")
            elseif demoL < 3 then
                s = Col("ff6622", "REFRESH!  ") .. Col("ffcc44", Fmt(demoL))
            elseif demoL < 8 then
                s = Col("ffcc44", Fmt(demoL) .. "  ") .. Col("888888", "refresh soon")
            else
                s = Col("44aa44", Fmt(demoL))
            end

        elseif k == "THUNDER_CLAP" then
            if tcL == 0 then
                s = Col("ff4444", "MISSING!  ") .. Col("888888", "~17% dmg reduc")
            elseif tcL < 3 then
                s = Col("ff6622", "REFRESH!  ") .. Col("ffcc44", Fmt(tcL))
            elseif tcL < 8 then
                s = Col("ffcc44", Fmt(tcL) .. "  ") .. Col("888888", "refresh soon")
            else
                s = Col("44aa44", Fmt(tcL))
            end

        elseif k == "DEVASTATE" then
            -- Filler — show Sunder stacks progress (Devastate applies Sunder)
            if sunderStacks >= 5 then
                s = Col("44ff44", "filler  ") .. Col("44aa44", "5/5 sun")
            elseif sunderStacks > 0 then
                s = Col("ffcc44", "filler  ") .. Col("ffaa44", sunderStacks .. "/5 sun")
            else
                s = Col("ff8844", "build sunder  ") .. Col("aaaaaa", "0/5")
            end

        elseif k == "HS" then
            if hsDump then
                s = Col("ffee55", "QUEUE  ") .. Col("aaaaaa", rage .. "R excess")
            elseif rage >= 55 then
                s = Col("888844", rage .. "R  watch SS")
            else
                s = Col("555566", rage .. "R  save for loop")
            end
        end

        SetRowState(row, active, s)
    end

    local hpCol  = hp < 0.30 and "ff4444" or hp < 0.60 and "ffcc44" or "44ff44"
    modeLabel:SetText(
        Col("4488ff", "PROT") .. "  " ..
        Col("aaaaaa", rage .. "R ") ..
        Col(hpCol, string.format("%.0f%%", hp * 100))
    )

    local spotSt
    if best == "SHIELD_SLAM" then
        spotSt = ssCD <= 0 and "CAST  " .. rage .. "R" or "in " .. Fmt(ssCD) .. "  " .. rage .. "R"
    elseif best == "REVENGE" then
        spotSt = "PROCCED  " .. rage .. "R"
    elseif best == "DEMO_SHOUT" then
        spotSt = demoL == 0 and "MISSING" or Fmt(demoL) .. " left"
    elseif best == "THUNDER_CLAP" then
        spotSt = tcL == 0 and "MISSING" or Fmt(tcL) .. " left"
    else
        spotSt = "filler  " .. sunderStacks .. "/5 sun  " .. rage .. "R"
    end
    UpdateSpotlight(best, PROT_ROWS, spotSt)
end

-- ────────────────────────────────────────────────────────────
-- Master display refresh
-- ────────────────────────────────────────────────────────────
local function RefreshDisplay()
    if not mainFrame or not mainFrame:IsShown() then return end
    local spec = DetectSpec()
    local now  = GetTime()

    local showFury = (spec == "FURY")
    local showArms = (spec == "ARMS")
    local showProt = (spec == "PROT")

    if furyContainer then furyContainer:SetShown(showFury) end
    if armsContainer then armsContainer:SetShown(showArms) end
    if protContainer then protContainer:SetShown(showProt) end

    if showFury then      UpdateFury(now)
    elseif showArms then  UpdateArms(now)
    elseif showProt then  UpdateProt(now)
    end
end

-- ────────────────────────────────────────────────────────────
-- OnUpdate ticker (20 fps)
-- ────────────────────────────────────────────────────────────
local tickFrame = CreateFrame("Frame")
local tickAcc   = 0
tickFrame:SetScript("OnUpdate", function(self, dt)
    tickAcc = tickAcc + dt
    if tickAcc < 0.05 then return end
    tickAcc = 0

    playerRage = UnitPower("player", 1) or 0
    playerHP   = UnitHealth("player") / math.max(1, UnitHealthMax("player"))
    targetHP   = UnitExists("target")
                 and (UnitHealth("target") / math.max(1, UnitHealthMax("target")))
                 or 1.0

    RefreshDisplay()
end)

-- ────────────────────────────────────────────────────────────
-- Event frame
-- ────────────────────────────────────────────────────────────
local evtFrame = CreateFrame("Frame")
evtFrame:RegisterEvent("PLAYER_TARGET_CHANGED")
evtFrame:RegisterEvent("UNIT_AURA")
evtFrame:RegisterEvent("COMBAT_LOG_EVENT_UNFILTERED")
evtFrame:RegisterEvent("PLAYER_REGEN_DISABLED")
evtFrame:RegisterEvent("PLAYER_REGEN_ENABLED")
evtFrame:RegisterEvent("PLAYER_LOGOUT")

evtFrame:SetScript("OnEvent", function(self, event, ...)
    if event == "PLAYER_TARGET_CHANGED" then
        ScanTargetDebuffs()

    elseif event == "UNIT_AURA" then
        local arg1 = ...
        if arg1 == "player" then ScanPlayerBuffs()    end
        if arg1 == "target"  then ScanTargetDebuffs() end

    elseif event == "COMBAT_LOG_EVENT_UNFILTERED" then
        -- Track MH swings for Arms Slam window
        local info = {CombatLogGetCurrentEventInfo and CombatLogGetCurrentEventInfo()}
        if not info[1] then return end
        local subevent = info[2]
        local srcGUID  = info[4]
        if srcGUID ~= playerGUID then return end
        if subevent == "SWING_DAMAGE" or subevent == "SWING_MISSED" then
            lastSwingTime = GetTime()
            swingDuration = UnitAttackSpeed("player") or 2.0
        end

    elseif event == "PLAYER_LOGOUT" then
        if mainFrame and WH.db then
            local pt, _, _, x, y = mainFrame:GetPoint()
            WH.db.position = { point = pt or "CENTER", x = x or 0, y = y or 0 }
            WH.db.shown    = mainFrame:IsShown()
        end
        if spotFrame and WH.db then
            local pt, _, _, x, y = spotFrame:GetPoint()
            WH.db.spotPosition = { point = pt or "CENTER", x = x or 0, y = y or 0 }
            WH.db.spotShown    = spotFrame:IsShown()
        end

    elseif event == "PLAYER_REGEN_DISABLED" then
        -- Entered combat — show if combatOnly mode is enabled and window is toggled on
        if WH.db and WH.db.combatOnly and WH.db.shown then
            if mainFrame then mainFrame:Show() end
            if spotFrame and WH.db.spotShown then spotFrame:Show() end
        end

    elseif event == "PLAYER_REGEN_ENABLED" then
        -- Left combat — hide if combatOnly mode is enabled
        if WH.db and WH.db.combatOnly then
            if mainFrame then mainFrame:Hide() end
            if spotFrame then spotFrame:Hide() end
        end
    end
end)

-- ────────────────────────────────────────────────────────────
-- Init
-- ────────────────────────────────────────────────────────────
local function Init()
    local _, classFile = UnitClass("player")
    if classFile ~= "WARRIOR" then return end

    playerGUID = UnitGUID("player")

    SlyWarriorHelperDB = SlyWarriorHelperDB or {}
    ApplyDefaults(SlyWarriorHelperDB, DB_DEFAULTS)
    WH.db = SlyWarriorHelperDB

    SLASH_SLYWARRIOR1 = "/slywarrior"
    SlashCmdList["SLYWARRIOR"] = function(msg)
        msg = strtrim((msg or ""):lower())

        if msg == "lock" then
            WH.db.locked = true
            if mainFrame then mainFrame:EnableMouse(false) end
            DEFAULT_CHAT_FRAME:AddMessage("|cff88ccff[WarriorHelper]|r Locked.")

        elseif msg == "unlock" then
            WH.db.locked = false
            if mainFrame then mainFrame:EnableMouse(true) end
            DEFAULT_CHAT_FRAME:AddMessage("|cff88ccff[WarriorHelper]|r Unlocked — drag to reposition.")

        elseif msg == "reset" then
            WH.db.position = { point = "CENTER", x = 250, y = 0 }
            if mainFrame then
                mainFrame:ClearAllPoints()
                mainFrame:SetPoint("CENTER", UIParent, "CENTER", 250, 0)
            end
            DEFAULT_CHAT_FRAME:AddMessage("|cff88ccff[WarriorHelper]|r Position reset.")

        elseif msg == "spot" then
            if not spotFrame then BuildSpotlight() end
            if spotFrame:IsShown() then
                spotFrame:Hide(); WH.db.spotShown = false
                DEFAULT_CHAT_FRAME:AddMessage("|cff88ccff[WarriorHelper]|r Spotlight hidden.")
            else
                spotFrame:Show(); WH.db.spotShown = true
                DEFAULT_CHAT_FRAME:AddMessage("|cff88ccff[WarriorHelper]|r Spotlight shown.")
            end

        elseif msg:sub(1, 5) == "spec " then
            local s = msg:sub(6)
            if s == "fury" or s == "arms" or s == "prot" then
                WH.db.spec = s:upper()
                DEFAULT_CHAT_FRAME:AddMessage("|cff88ccff[WarriorHelper]|r Spec set to: " .. s:upper())
            elseif s == "auto" then
                WH.db.spec = nil
                DEFAULT_CHAT_FRAME:AddMessage("|cff88ccff[WarriorHelper]|r Spec set to AUTO-DETECT.")
            else
                DEFAULT_CHAT_FRAME:AddMessage("|cff88ccff[WarriorHelper]|r Usage: /slywarrior spec fury|arms|prot|auto")
            end

        elseif msg == "sunder" then
            WH.db.showSunder = not WH.db.showSunder
            RefreshSunderRows()
            if WH.db.showSunder then
                DEFAULT_CHAT_FRAME:AddMessage("|cff88ccff[WarriorHelper]|r Sunder Armor row: |cff44ff44ON|r.")
            else
                DEFAULT_CHAT_FRAME:AddMessage("|cff88ccff[WarriorHelper]|r Sunder Armor row: |cffff4444OFF|r.")
            end

        elseif msg == "combat" then
            WH.db.combatOnly = not WH.db.combatOnly
            if WH.db.combatOnly then
                DEFAULT_CHAT_FRAME:AddMessage("|cff88ccff[WarriorHelper]|r Combat-only: |cffff4444ON|r — window hidden out of combat.")
                if not InCombatLockdown() then
                    if mainFrame then mainFrame:Hide() end
                    if spotFrame then spotFrame:Hide() end
                end
            else
                DEFAULT_CHAT_FRAME:AddMessage("|cff88ccff[WarriorHelper]|r Combat-only: |cff44ff44OFF|r.")
                if WH.db.shown and mainFrame then mainFrame:Show() end
                if WH.db.spotShown and spotFrame then spotFrame:Show() end
            end

        else
            if not mainFrame then BuildUI() end
            if mainFrame:IsShown() then
                mainFrame:Hide(); WH.db.shown = false
            else
                mainFrame:Show(); WH.db.shown = true
            end
        end
    end

    BuildUI()
    RefreshSunderRows()
    BuildSpotlight()
    -- Apply combat-only: hide on login if enabled and currently out of combat
    if WH.db.combatOnly and not InCombatLockdown() then
        if mainFrame then mainFrame:Hide() end
        if spotFrame then spotFrame:Hide() end
    end
    ScanPlayerBuffs()
    ScanTargetDebuffs()

    local spec = DetectSpec()
    DEFAULT_CHAT_FRAME:AddMessage(
        "|cff88ccff[WarriorHelper]|r v" .. VERSION ..
        " — " .. spec .. " rotation loaded. |cffffcc00/slywarrior|r to toggle.")
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
            description = "Warrior rotation advisor — Fury/Arms DPS and Protection Tank priority display.",
            slash       = "/slywarrior",
            icon        = "Interface\\Icons\\Ability_Warrior_Bloodthirst",
        })
    else
        Init()
    end
end)
