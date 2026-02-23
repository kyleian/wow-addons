-- ============================================================
-- SlyUFUI.lua  —  Unit frame construction + update functions
-- ============================================================

local BAR_TEX   = "Interface\\TargetingFrame\\UI-StatusBar"
local FRAME_W   = 232      -- main frame width
local FRAME_H   = 64       -- main frame height
local PORT_SZ   = 56       -- portrait size
local BAR_W     = FRAME_W - PORT_SZ - 12   -- ~164 px
local HP_H      = 16
local PWR_H     = 10
local NAME_H    = 14
local PAD       = 4

local PARTY_W   = 190
local PARTY_H   = 46
local PARTY_PORT = 34

local TOT_W     = 148
local TOT_H     = 40

-- -------------------------------------------------------
-- MakeBar(parent, r, g, b, w, h)
-- -------------------------------------------------------
local function MakeBar(parent, r, g, b, w, h)
    local bg = parent:CreateTexture(nil, "BACKGROUND")
    bg:SetTexture(0, 0, 0, 0.55)
    bg:SetSize(w, h)

    local bar = CreateFrame("StatusBar", nil, parent)
    bar:SetStatusBarTexture(BAR_TEX)
    bar:GetStatusBarTexture():SetHorizTile(false)
    bar:SetStatusBarColor(r, g, b)
    bar:SetMinMaxValues(0, 1)
    bar:SetValue(1)
    bar:SetSize(w, h)
    bar.bg = bg

    local label = bar:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    label:SetPoint("CENTER", bar, "CENTER", 0, 0)
    label:SetFont(label:GetFont(), 9, "OUTLINE")
    bar.label = label

    return bar
end

-- -------------------------------------------------------
-- MakeFrame(name)  —  shared backdrop factory
-- -------------------------------------------------------
local function MakeFrame(name, parent)
    local f = CreateFrame("Frame", name, parent or UIParent)
    f:SetBackdrop({
        bgFile   = "Interface\\DialogFrame\\UI-DialogBox-Background",
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        tile = true, tileSize = 16, edgeSize = 10,
        insets = { left = 2, right = 2, top = 2, bottom = 2 },
    })
    f:SetBackdropColor(0.06, 0.06, 0.09, 0.90)
    f:SetBackdropBorderColor(0.22, 0.22, 0.30, 1)
    f:EnableMouse(true)
    f:SetMovable(true)
    f:RegisterForDrag("LeftButton")
    f:SetScript("OnDragStart", f.StartMoving)
    f:SetScript("OnDragStop", function(self)
        self:StopMovingOrSizing()
        local p, _, _, x, y = self:GetPoint()
        if SlyUF.db then
            SlyUF.db.positions[self:GetName() or "?"] = { point = p, x = x, y = y }
        end
    end)
    return f
end

-- -------------------------------------------------------
-- SlyUF_PositionFrame(f, defaultPoint, defaultX, defaultY)
-- -------------------------------------------------------
local function PositionFrame(f, dpt, dx, dy)
    local name = f:GetName()
    local saved = name and SlyUF.db and SlyUF.db.positions[name]
    if saved then
        f:ClearAllPoints()
        f:SetPoint(saved.point, UIParent, saved.point, saved.x, saved.y)
    else
        f:ClearAllPoints()
        f:SetPoint(dpt, UIParent, dpt, dx, dy)
    end
end

-- -------------------------------------------------------
-- BuildPortrait(parent, side)  →  portrait texture
-- side: "LEFT" or "RIGHT"
-- -------------------------------------------------------
local function BuildPortrait(parent, side)
    local port = parent:CreateTexture(nil, "ARTWORK")
    port:SetSize(PORT_SZ - 4, PORT_SZ - 4)
    if side == "LEFT" then
        port:SetPoint("LEFT", parent, "LEFT", 3, 0)
    else
        port:SetPoint("RIGHT", parent, "RIGHT", -3, 0)
    end
    -- Circular mask via clipping frame
    local border = parent:CreateTexture(nil, "OVERLAY")
    border:SetSize(PORT_SZ, PORT_SZ)
    if side == "LEFT" then
        border:SetPoint("LEFT", parent, "LEFT", 1, 0)
    else
        border:SetPoint("RIGHT", parent, "RIGHT", -1, 0)
    end
    border:SetTexture("Interface\\CharacterFrame\\TempPortraitAlphaMask")
    border:SetBlendMode("BLEND")
    return port
end

-- -------------------------------------------------------
-- BuildUnitFrame(name, unit, portSide)
-- Builds player-style frame with portrait, name, HP, power.
-- -------------------------------------------------------
local function BuildUnitFrame(frameName, unit, portSide)
    local f = MakeFrame(frameName)
    f:SetSize(FRAME_W, FRAME_H)
    f.unit = unit

    -- Portrait
    local port = BuildPortrait(f, portSide)
    f.portrait = port

    -- Name + level area
    local barX = portSide == "LEFT" and (PORT_SZ + PAD) or PAD
    local barAnchor = portSide == "LEFT" and "LEFT" or "LEFT"

    local nameText = f:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    nameText:SetFont(nameText:GetFont(), 10, "OUTLINE")
    nameText:SetPoint("TOPLEFT", f, "TOPLEFT", barX, -PAD)
    nameText:SetWidth(BAR_W - 20)
    nameText:SetJustifyH("LEFT")
    nameText:SetTextColor(1, 1, 1)
    f.nameText = nameText

    local levelText = f:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    levelText:SetFont(levelText:GetFont(), 9, "OUTLINE")
    levelText:SetPoint("TOPRIGHT", f, "TOPRIGHT",
        portSide == "RIGHT" and -(PORT_SZ + PAD) or -PAD, -PAD)
    levelText:SetTextColor(0.8, 0.8, 0.8)
    f.levelText = levelText

    -- HP bar
    local hpBar = MakeBar(f, 0.0, 0.8, 0.0, BAR_W, HP_H)
    hpBar:SetPoint("TOPLEFT", f, "TOPLEFT", barX, -(NAME_H + PAD + 2))
    hpBar.bg:SetPoint("TOPLEFT", f, "TOPLEFT", barX, -(NAME_H + PAD + 2))
    f.hpBar = hpBar

    -- Power bar
    local pwrBar = MakeBar(f, 0.0, 0.0, 1.0, BAR_W, PWR_H)
    pwrBar:SetPoint("TOPLEFT", f, "TOPLEFT", barX, -(NAME_H + PAD + 2 + HP_H + 2))
    pwrBar.bg:SetPoint("TOPLEFT", f, "TOPLEFT", barX, -(NAME_H + PAD + 2 + HP_H + 2))
    f.pwrBar = pwrBar

    -- Dead/ghost overlay
    local deadText = f:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    deadText:SetPoint("CENTER", hpBar, "CENTER")
    deadText:SetFont(deadText:GetFont(), 9, "OUTLINE")
    deadText:SetTextColor(0.8, 0.4, 0.4)
    deadText:Hide()
    f.deadText = deadText

    f:Hide()
    return f
end

-- -------------------------------------------------------
-- BuildToTFrame  —  small target-of-target
-- -------------------------------------------------------
local function BuildToTFrame()
    local f = MakeFrame("SlyUFToT")
    f:SetSize(TOT_W, TOT_H)
    f.unit = "targettarget"

    local nameText = f:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    nameText:SetFont(nameText:GetFont(), 9, "OUTLINE")
    nameText:SetPoint("TOPLEFT", f, "TOPLEFT", PAD, -PAD)
    nameText:SetWidth(TOT_W - PAD * 2)
    nameText:SetJustifyH("LEFT")
    nameText:SetTextColor(1, 1, 1)
    f.nameText = nameText

    local hpBar = MakeBar(f, 0.0, 0.8, 0.0, TOT_W - PAD * 2, 11)
    hpBar:SetPoint("TOPLEFT", f, "TOPLEFT", PAD, -(NAME_H + PAD))
    hpBar.bg:SetPoint("TOPLEFT", f, "TOPLEFT", PAD, -(NAME_H + PAD))
    f.hpBar = hpBar

    local pwrBar = MakeBar(f, 0.0, 0.0, 1.0, TOT_W - PAD * 2, 7)
    pwrBar:SetPoint("TOPLEFT", f, "TOPLEFT", PAD, -(NAME_H + PAD + 13))
    pwrBar.bg:SetPoint("TOPLEFT", f, "TOPLEFT", PAD, -(NAME_H + PAD + 13))
    f.pwrBar = pwrBar

    f:Hide()
    return f
end

-- -------------------------------------------------------
-- BuildPartyFrame(index)
-- -------------------------------------------------------
local function BuildPartyFrame(index)
    local unit = "party" .. index
    local fname = "SlyUFParty" .. index
    local f = MakeFrame(fname)
    f:SetSize(PARTY_W, PARTY_H)
    f.unit = unit

    -- Small portrait
    local port = f:CreateTexture(nil, "ARTWORK")
    port:SetSize(PARTY_PORT, PARTY_PORT)
    port:SetPoint("LEFT", f, "LEFT", 3, 0)
    f.portrait = port

    local bX = PARTY_PORT + PAD + 3
    local bW = PARTY_W - bX - PAD

    local nameText = f:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    nameText:SetFont(nameText:GetFont(), 9, "OUTLINE")
    nameText:SetPoint("TOPLEFT", f, "TOPLEFT", bX, -PAD)
    nameText:SetWidth(bW)
    nameText:SetJustifyH("LEFT")
    nameText:SetTextColor(1, 1, 1)
    f.nameText = nameText

    local hpBar = MakeBar(f, 0.0, 0.8, 0.0, bW, 12)
    hpBar:SetPoint("TOPLEFT", f, "TOPLEFT", bX, -(NAME_H + PAD))
    hpBar.bg:SetPoint("TOPLEFT", f, "TOPLEFT", bX, -(NAME_H + PAD))
    f.hpBar = hpBar

    local pwrBar = MakeBar(f, 0.0, 0.0, 1.0, bW, 7)
    pwrBar:SetPoint("TOPLEFT", f, "TOPLEFT", bX, -(NAME_H + PAD + 14))
    pwrBar.bg:SetPoint("TOPLEFT", f, "TOPLEFT", bX, -(NAME_H + PAD + 14))
    f.pwrBar = pwrBar

    f:Hide()
    return f
end

-- -------------------------------------------------------
-- UpdateUnitFrame(f)  —  refresh all data in a unit frame
-- -------------------------------------------------------
local function UpdateUnitFrame(f)
    if not f then return end
    local unit = f.unit
    if not unit then return end

    local exists = UnitExists(unit)
    if not exists then
        if unit ~= "player" then
            f:Hide()
            return
        end
    end

    if unit ~= "player" then f:Show() end

    -- Portrait
    if f.portrait then
        SetPortraitTexture(f.portrait, unit)
    end

    -- Name
    local name = UnitName(unit) or ""
    local lvl  = UnitLevel(unit) or 0
    if f.nameText then f.nameText:SetText(name) end
    if f.levelText then
        if lvl < 0 then
            f.levelText:SetText("??")
            f.levelText:SetTextColor(0.8, 0.2, 0.2)
        else
            f.levelText:SetText(tostring(lvl))
            f.levelText:SetTextColor(0.8, 0.8, 0.8)
        end
    end

    -- Dead / Ghost
    local isDead = UnitIsDeadOrGhost and UnitIsDeadOrGhost(unit)
    if f.deadText then
        if isDead then
            f.deadText:SetText(UnitIsGhost and UnitIsGhost(unit) and "Ghost" or "Dead")
            f.deadText:Show()
        else
            f.deadText:Hide()
        end
    end

    -- HP bar
    local hp, hpMax = SlyUF.GetHP(unit)
    local hr, hg, hb = SlyUF.GetHPColor(unit)
    if f.hpBar then
        f.hpBar:SetMinMaxValues(0, math.max(1, hpMax))
        f.hpBar:SetValue(hp)
        f.hpBar:SetStatusBarColor(isDead and 0.3 or hr, isDead and 0.3 or hg, isDead and 0.3 or hb)
        f.hpBar.label:SetText(hp .. " / " .. hpMax)
    end

    -- Power bar
    local pw, pwMax, pt = SlyUF.GetPower(unit)
    local pc = SlyUF.POWER_COLORS[pt] or SlyUF.POWER_COLORS[0]
    if f.pwrBar then
        if pwMax == 0 then
            f.pwrBar:SetValue(0)
            f.pwrBar.label:SetText("")
        else
            f.pwrBar:SetMinMaxValues(0, pwMax)
            f.pwrBar:SetValue(pw)
            f.pwrBar:SetStatusBarColor(pc.r, pc.g, pc.b)
            f.pwrBar.label:SetText(pw .. " / " .. pwMax)
        end
    end
end

-- -------------------------------------------------------
-- Public update functions
-- -------------------------------------------------------
function SlyUF.UpdatePlayer()
    if not SlyUF.db or not SlyUF.db.enabled then return end
    UpdateUnitFrame(SlyUF.frames.player)
end

function SlyUF.UpdateTarget()
    if not SlyUF.db or not SlyUF.db.enabled then return end
    local f = SlyUF.frames.target
    if not f then return end
    if UnitExists("target") then
        UpdateUnitFrame(f)
    else
        f:Hide()
    end
end

function SlyUF.UpdateToT()
    if not SlyUF.db or not SlyUF.db.enabled then return end
    local f = SlyUF.frames.tot
    if not f then return end
    if UnitExists("targettarget") then
        UpdateUnitFrame(f)
    else
        f:Hide()
    end
end

function SlyUF.UpdatePartyMember(idx)
    if not SlyUF.db or not SlyUF.db.enabled then return end
    local f = SlyUF.frames["party" .. idx]
    if not f then return end
    if UnitExists("party" .. idx) then
        UpdateUnitFrame(f)
    else
        f:Hide()
    end
end

function SlyUF.UpdateParty()
    for i = 1, 4 do SlyUF.UpdatePartyMember(i) end
end

function SlyUF.UpdateAll()
    SlyUF.UpdatePlayer()
    SlyUF.UpdateTarget()
    SlyUF.UpdateToT()
    SlyUF.UpdateParty()
end

-- -------------------------------------------------------
-- Periodic refresh (portrait + misc every 1s)
-- -------------------------------------------------------
local refreshTimer = 0
local refreshFrame = CreateFrame("Frame")
refreshFrame:SetScript("OnUpdate", function(self, elapsed)
    if not SlyUF.db or not SlyUF.db.enabled then return end
    refreshTimer = refreshTimer + elapsed
    if refreshTimer < 1.0 then return end
    refreshTimer = 0
    -- Just refresh portraits and names (HP is event-driven)
    for _, f in pairs(SlyUF.frames) do
        if f and f:IsShown() and f.unit and UnitExists(f.unit) then
            if f.portrait then SetPortraitTexture(f.portrait, f.unit) end
        end
    end
end)

-- -------------------------------------------------------
-- SlyUF_PositionAll  —  apply saved or default positions
-- -------------------------------------------------------
function SlyUF_PositionAll()
    local pf = SlyUF.frames.player
    local tf = SlyUF.frames.target
    local tot = SlyUF.frames.tot

    -- Default anchors (BOTTOMLEFT of screen)
    -- Player: bottom-left above action bar
    PositionFrame(pf,  "BOTTOMLEFT", 7, 172)
    -- Target: right of player
    PositionFrame(tf,  "BOTTOMLEFT", 7 + FRAME_W + 8, 172)
    -- ToT: above target
    PositionFrame(tot, "BOTTOMLEFT", 7 + FRAME_W + 8, 172 + FRAME_H + 4)

    -- Party frames: stacked above player
    for i = 1, 4 do
        local f = SlyUF.frames["party" .. i]
        if f then
            PositionFrame(f, "BOTTOMLEFT", 7, 172 + FRAME_H + 4 + (i - 1) * (PARTY_H + 3))
        end
    end
end

-- -------------------------------------------------------
-- SlyUF_BuildAll  —  main entry, called once on load
-- -------------------------------------------------------
function SlyUF_BuildAll()
    -- Player
    local playerF = BuildUnitFrame("SlyUFPlayer", "player", "LEFT")
    SlyUF.frames.player = playerF
    -- Always show player frame
    playerF:Show()

    -- Target
    local targetF = BuildUnitFrame("SlyUFTarget", "target", "RIGHT")
    SlyUF.frames.target = targetF

    -- ToT
    local totF = BuildToTFrame()
    SlyUF.frames.tot = totF

    -- Party frames
    for i = 1, 4 do
        local pf = BuildPartyFrame(i)
        SlyUF.frames["party" .. i] = pf
    end

    SlyUF_PositionAll()

    -- Only enable if saved as enabled
    if SlyUF.db and SlyUF.db.enabled then
        SlyUF.Enable()
    end
end
