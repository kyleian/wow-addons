-- SlyMetricsUI.lua  (TBC Anniversary / Interface 20505)
-- Split pane: DPS/HPS rows on top, Threat rows always visible below.

local W       = 280
local TITLE_H = 20
local TAB_H   = 18
local ROW_H   = 18
local ROW_PAD = 2
local PAD     = 4
local DPS_MAX = 8
local THR_MAX = 6
local SECT_H  = 18
local SEP_H   = 4
local FOOT_H  = 16

local DPS_BLK = DPS_MAX * (ROW_H + ROW_PAD)
local THR_BLK = THR_MAX * (ROW_H + ROW_PAD)
local H = TITLE_H + TAB_H + 2 + DPS_BLK + SEP_H + SECT_H + THR_BLK + FOOT_H + 4

local BAR_TEX = "Interface\\TargetingFrame\\UI-StatusBar"

local CCLR = {
    WARRIOR={0.78,0.61,0.43}, PALADIN={0.96,0.55,0.73},
    HUNTER ={0.67,0.83,0.45}, ROGUE  ={1.00,0.96,0.41},
    PRIEST ={1.00,1.00,1.00}, SHAMAN ={0.00,0.55,0.98},
    MAGE   ={0.41,0.80,0.94}, WARLOCK={0.58,0.51,0.79},
    DRUID  ={1.00,0.49,0.04},
}
local function CC(cls)
    local c = cls and CCLR[cls]
    return c and c[1] or 0.5, c and c[2] or 0.5, c and c[3] or 0.55
end

-- ── row factory ──────────────────────────────────────────────────────────────
local function MakeRow(parent)
    local rw = W - PAD*2
    local r  = CreateFrame("Frame", nil, parent)
    r:SetHeight(ROW_H)
    r:EnableMouse(false)

    r.bg = r:CreateTexture(nil, "BACKGROUND")
    r.bg:SetAllPoints()
    r.bg:SetColorTexture(0, 0, 0, 0.45)

    r.bar = r:CreateTexture(nil, "ARTWORK")
    r.bar:SetPoint("TOPLEFT",    r, "TOPLEFT",    0, 0)
    r.bar:SetPoint("BOTTOMLEFT", r, "BOTTOMLEFT", 0, 0)
    r.bar:SetWidth(2)
    r.bar:SetTexture(BAR_TEX)

    r.rank = r:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    r.rank:SetFont(r.rank:GetFont(), 9, "OUTLINE")
    r.rank:SetPoint("LEFT", r, "LEFT", 2, 0)
    r.rank:SetWidth(14)
    r.rank:SetJustifyH("CENTER")

    r.nm = r:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    r.nm:SetFont(r.nm:GetFont(), 10, "OUTLINE")
    r.nm:SetPoint("LEFT", r, "LEFT", 18, 0)
    r.nm:SetWidth(rw - 18 - 68)
    r.nm:SetJustifyH("LEFT")

    r.val = r:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    r.val:SetFont(r.val:GetFont(), 9, "OUTLINE")
    r.val:SetPoint("RIGHT", r, "RIGHT", -2, 0)
    r.val:SetWidth(66)
    r.val:SetJustifyH("RIGHT")

    r:Hide()
    return r
end

local function EnsurePool(pool, host, n)
    while #pool < n do
        pool[#pool+1] = MakeRow(host)
    end
end

local function RenderRows(pool, host, rows, maxN, maxVal, labelFn)
    local rw = W - PAD*2
    local n  = math.min(#rows, maxN)
    EnsurePool(pool, host, n)
    for i = 1, n do
        local d = rows[i]
        local r = pool[i]
        r:ClearAllPoints()
        r:SetPoint("TOPLEFT", host, "TOPLEFT", 0, -(i-1)*(ROW_H+ROW_PAD))
        r:SetWidth(rw)
        local pct  = (maxVal or 0) > 0 and (d._sort or 0)/maxVal or 0
        local barW = math.max(2, math.floor(rw * pct))
        r.bar:SetWidth(barW)
        local cr, cg, cb = CC(d.cls)
        r.bar:SetVertexColor(cr*0.6, cg*0.6, cb*0.6, 0.9)
        r.rank:SetText(i)
        r.nm:SetText(d.name or "")
        r.nm:SetTextColor(cr, cg, cb)
        r.val:SetText(labelFn(d))
        r.bg:SetColorTexture(d.isTank and 0.20 or 0, d.isTank and 0.04 or 0, 0, 0.45)
        r:Show()
    end
    for i = n+1, #pool do pool[i]:Hide() end
end

local dpsPool = {}
local thrPool = {}
local tabs    = {}

local function HighlightTabs()
    for id, t in pairs(tabs) do
        local on = (id == SM.panel)
        t.bg:SetColorTexture(
            on and 0.14 or 0.07,
            on and 0.30 or 0.07,
            on and 0.58 or 0.10, 1)
        t.tx:SetTextColor(
            on and 1 or 0.55,
            on and 1 or 0.55,
            on and 1 or 0.60)
    end
end

local function SetStatus(txt)
    local f = SlyMetricsFrame
    if f and f._st then f._st:SetText(txt or "") end
end

-- ── refresh functions ─────────────────────────────────────────────────────────

function SM_RefreshDPS()
    local f = SlyMetricsFrame
    if not f or not f:IsShown() then return end
    local rows, tot, el = SM.GetDPSRows()
    tot = tot or 0
    el  = el  or 0
    for _, r in ipairs(rows) do r._sort = r.dmg end
    RenderRows(dpsPool, f._dpsHost, rows, DPS_MAX, tot, function(d)
        local dps = el > 0 and d.dmg/el or 0
        return string.format("|cffffcc00%s|r |cffaaaaaa%s/s|r",
            SM.Fmt(d.dmg), SM.Fmt(dps))
    end)
    if SM.inCombat then
        SetStatus("|cffff4444In combat...|r")
    elseif tot > 0 then
        local dps = el > 0 and tot/el or 0
        SetStatus(string.format("|cffffcc00%s|r dmg  |cffaaaaaa%.0fs  %s/s|r",
            SM.Fmt(tot), el, SM.Fmt(dps)))
    else
        SetStatus("|cff888888No data — fight something!|r")
    end
end

function SM_RefreshHPS()
    local f = SlyMetricsFrame
    if not f or not f:IsShown() then return end
    local rows, tot, el = SM.GetHPSRows()
    tot = tot or 0
    el  = el  or 0
    for _, r in ipairs(rows) do r._sort = r.heal end
    RenderRows(dpsPool, f._dpsHost, rows, DPS_MAX, tot, function(d)
        local hps = el > 0 and d.heal/el or 0
        return string.format("|cff66ff88%s|r |cffaaaaaa%s/s|r",
            SM.Fmt(d.heal), SM.Fmt(hps))
    end)
    if SM.inCombat then
        SetStatus("|cffff4444In combat...|r")
    elseif tot > 0 then
        local hps = el > 0 and tot/el or 0
        SetStatus(string.format("|cff66ff88%s|r heal  |cffaaaaaa%.0fs  %s/s|r",
            SM.Fmt(tot), el, SM.Fmt(hps)))
    else
        SetStatus("|cff888888No heal data|r")
    end
end

function SM_RefreshThreat()
    local f = SlyMetricsFrame
    if not f or not f:IsShown() then return end
    local rows = SM.threat or {}
    if #rows == 0 then
        for _, r in ipairs(thrPool) do r:Hide() end
        if f._thrLabel then
            f._thrLabel:SetText("|cff888888THREAT|r  " ..
                (UnitExists("target")
                    and "|cffaaaaaa(no data)|r"
                    or  "|cffaaaaaa(no target)|r"))
        end
        return
    end
    local maxV = rows[1].val or 1
    for _, r in ipairs(rows) do r._sort = r.val end
    RenderRows(thrPool, f._thrHost, rows, THR_MAX, maxV, function(d)
        return string.format("%s|cffffcc00%d%%|r |cffaaaaaa%s|r",
            d.isTank and "|cffff6666T|r " or "",
            math.floor(d.pct or 0),
            SM.Fmt(d.val))
    end)
    if f._thrLabel then
        f._thrLabel:SetText(string.format("|cff888888THREAT|r  |cffcccccc%s|r",
            UnitName("target") or "target"))
    end
end

function SM_Refresh()
    local f = SlyMetricsFrame
    if not f or not f:IsShown() then return end
    HighlightTabs()
    if SM.panel == "hps" then SM_RefreshHPS() else SM_RefreshDPS() end
    SM_RefreshThreat()
end

-- ── SM_BuildUI ────────────────────────────────────────────────────────────────

function SM_BuildUI()
    if SlyMetricsFrame then return end

    local db = (SM and SM.db) or {}

    local f = CreateFrame("Frame", "SlyMetricsFrame", UIParent)
    f:SetSize(W, H)
    f:SetMovable(true)
    f:EnableMouse(true)
    f:RegisterForDrag("LeftButton")
    f:SetFrameStrata("HIGH")
    f:SetClampedToScreen(true)

    -- Restore saved position only if mx >= 0 (not off left edge of screen).
    if db.mx and db.my and db.mx >= 0 then
        f:SetPoint("TOPLEFT", UIParent, "TOPLEFT", db.mx, db.my)
    else
        f:SetPoint("RIGHT", UIParent, "RIGHT", -60, 100)
    end

    f:SetScript("OnDragStart", f.StartMoving)
    f:SetScript("OnDragStop", function(self)
        self:StopMovingOrSizing()
        local _, _, _, x, y = self:GetPoint()
        if SM.db then SM.db.mx = x ; SM.db.my = y end
    end)
    f:SetScript("OnShow", SM_Refresh)

    -- background
    if f.SetBackdrop then
        f:SetBackdrop({
            bgFile   = "Interface\\DialogFrame\\UI-DialogBox-Background",
            edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
            tile=true, tileSize=16, edgeSize=8,
            insets={left=2, right=2, top=2, bottom=2},
        })
        f:SetBackdropColor(0.04, 0.04, 0.07, 0.95)
        f:SetBackdropBorderColor(0.20, 0.20, 0.30, 1)
    else
        local bg = f:CreateTexture(nil, "BACKGROUND")
        bg:SetAllPoints()
        bg:SetColorTexture(0.04, 0.04, 0.07, 0.95)
    end

    -- title bar
    local tbar = f:CreateTexture(nil, "ARTWORK")
    tbar:SetPoint("TOPLEFT",  f, "TOPLEFT",  2, -2)
    tbar:SetPoint("TOPRIGHT", f, "TOPRIGHT", -2, -2)
    tbar:SetHeight(TITLE_H)
    tbar:SetColorTexture(0.08, 0.08, 0.13, 1)

    local title = f:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    title:SetFont(title:GetFont(), 10, "OUTLINE")
    title:SetPoint("LEFT", f, "TOPLEFT", 6, -TITLE_H/2)
    title:SetText("|cff00ccffSly|rMetrics")

    local cBtn = CreateFrame("Button", nil, f, "UIPanelCloseButton")
    cBtn:SetSize(20, 20)
    cBtn:SetPoint("TOPRIGHT", f, "TOPRIGHT", 4, 4)
    cBtn:SetScript("OnClick", function() f:Hide() end)

    local rBtn = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
    rBtn:SetSize(42, 14)
    rBtn:SetPoint("RIGHT", cBtn, "LEFT", -2, 1)
    rBtn:SetText("Reset")
    rBtn:SetScript("OnClick", function()
        SM.Reset()
        SM_Refresh()
    end)

    -- DPS / HPS tabs
    local tw = math.floor(W/2)
    local tabDefs = { {id="dps", label="DPS"}, {id="hps", label="HPS"} }
    for i, td in ipairs(tabDefs) do
        local b = CreateFrame("Button", nil, f)
        b:SetSize(tw, TAB_H)
        b:SetPoint("TOPLEFT", f, "TOPLEFT", (i-1)*tw, -TITLE_H)

        b.bg = b:CreateTexture(nil, "BACKGROUND")
        b.bg:SetAllPoints()
        b.bg:SetColorTexture(0.07, 0.07, 0.10, 1)

        local hl = b:CreateTexture(nil, "HIGHLIGHT")
        hl:SetAllPoints()
        hl:SetColorTexture(0.3, 0.5, 0.9, 0.18)

        b.tx = b:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        b.tx:SetAllPoints()
        b.tx:SetJustifyH("CENTER")
        b.tx:SetFont(b.tx:GetFont(), 11, "OUTLINE")
        b.tx:SetText(td.label)

        local pid = td.id
        b:SetScript("OnClick", function()
            SM.panel = pid
            HighlightTabs()
            if pid == "hps" then SM_RefreshHPS() else SM_RefreshDPS() end
        end)
        tabs[pid] = b
    end

    -- divider below tabs
    local div = f:CreateTexture(nil, "ARTWORK")
    div:SetPoint("TOPLEFT",  f, "TOPLEFT",  0, -(TITLE_H + TAB_H))
    div:SetPoint("TOPRIGHT", f, "TOPRIGHT", 0, -(TITLE_H + TAB_H))
    div:SetHeight(2)
    div:SetColorTexture(0.20, 0.20, 0.30, 1)

    -- DPS row host
    local dpsTop  = -(TITLE_H + TAB_H + 2)
    local dpsHost = CreateFrame("Frame", nil, f)
    dpsHost:SetPoint("TOPLEFT",  f, "TOPLEFT",   PAD,  dpsTop)
    dpsHost:SetPoint("TOPRIGHT", f, "TOPRIGHT", -PAD,  dpsTop)
    dpsHost:SetHeight(DPS_BLK)
    dpsHost:EnableMouse(false)
    f._dpsHost = dpsHost

    -- separator + THREAT header
    local sepTop = dpsTop - DPS_BLK - SEP_H
    local sep = f:CreateTexture(nil, "ARTWORK")
    sep:SetPoint("TOPLEFT",  f, "TOPLEFT",  0, sepTop)
    sep:SetPoint("TOPRIGHT", f, "TOPRIGHT", 0, sepTop)
    sep:SetHeight(1)
    sep:SetColorTexture(0.15, 0.15, 0.25, 1)

    local thrLabel = f:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    thrLabel:SetFont(thrLabel:GetFont(), 10, "OUTLINE")
    thrLabel:SetPoint("TOPLEFT", f, "TOPLEFT", PAD+2, sepTop - 1)
    thrLabel:SetHeight(SECT_H)
    thrLabel:SetJustifyH("LEFT")
    thrLabel:SetTextColor(0.55, 0.55, 0.65)
    thrLabel:SetText("|cff888888THREAT|r")
    f._thrLabel = thrLabel

    -- Threat row host
    local thrTop  = sepTop - SECT_H
    local thrHost = CreateFrame("Frame", nil, f)
    thrHost:SetPoint("TOPLEFT",  f, "TOPLEFT",   PAD,  thrTop)
    thrHost:SetPoint("TOPRIGHT", f, "TOPRIGHT", -PAD,  thrTop)
    thrHost:SetHeight(THR_BLK)
    thrHost:EnableMouse(false)
    f._thrHost = thrHost

    -- status footer
    local st = f:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    st:SetFont(st:GetFont(), 9, "OUTLINE")
    st:SetPoint("BOTTOMLEFT",  f, "BOTTOMLEFT",   PAD+2, 3)
    st:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", -(PAD+2), 3)
    st:SetJustifyH("CENTER")
    st:SetTextColor(0.48, 0.48, 0.60)
    st:SetText("No data")
    f._st = st

    HighlightTabs()
    f:Show()
end
