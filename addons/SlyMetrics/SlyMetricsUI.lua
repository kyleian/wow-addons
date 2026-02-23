-- ============================================================
-- SlyMetricsUI.lua  —  Window + panel rendering
-- ============================================================

local SM = SlyMetrics

local FRAME_W   = 310
local TITLE_H   = 20
local TAB_H     = 22
local ROW_H     = 18
local ROW_PAD   = 2
local STATUS_H  = 18
local SIDE_PAD  = 4
local MAX_ROWS  = 15

-- Inner row area height
local ROW_AREA_H = MAX_ROWS * (ROW_H + ROW_PAD) + ROW_PAD
local FRAME_H    = TITLE_H + TAB_H + ROW_AREA_H + STATUS_H + 8

local BAR_TEX = "Interface\\TargetingFrame\\UI-StatusBar"

local rowPool = {}   -- reusable row widgets

-- -------------------------------------------------------
-- Class bar colours (fallback grey)
-- -------------------------------------------------------
local CLASS_BAR = {
    WARRIOR     = { 0.78, 0.61, 0.43 },
    PALADIN     = { 0.96, 0.55, 0.73 },
    HUNTER      = { 0.67, 0.83, 0.45 },
    ROGUE       = { 1.00, 0.96, 0.41 },
    PRIEST      = { 1.00, 1.00, 1.00 },
    SHAMAN      = { 0.00, 0.44, 0.87 },
    MAGE        = { 0.41, 0.80, 0.94 },
    WARLOCK     = { 0.58, 0.51, 0.79 },
    DRUID       = { 1.00, 0.49, 0.04 },
    DEATHKNIGHT = { 0.77, 0.12, 0.23 },
    UNKNOWN     = { 0.50, 0.50, 0.50 },
}
local function ClassRGB(cls)
    local c = CLASS_BAR[cls] or CLASS_BAR.UNKNOWN
    return c[1], c[2], c[3]
end

-- -------------------------------------------------------
-- MakeRow(parent, idx) — create a pooled row
-- -------------------------------------------------------
local function MakeRow(parent, idx)
    local r = CreateFrame("Frame", nil, parent)
    r:SetHeight(ROW_H)
    r:EnableMouse(false)

    -- bar background
    local barbg = r:CreateTexture(nil, "BACKGROUND")
    barbg:SetAllPoints()
    barbg:SetTexture(0, 0, 0, 0.4)
    r.barbg = barbg

    -- fill bar
    local bar = r:CreateTexture(nil, "ARTWORK")
    bar:SetPoint("TOPLEFT", r, "TOPLEFT", 0, 0)
    bar:SetPoint("BOTTOMLEFT", r, "BOTTOMLEFT", 0, 0)
    bar:SetWidth(1)
    bar:SetTexture(BAR_TEX)
    r.bar = bar

    -- rank badge
    local rank = r:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    rank:SetFont(rank:GetFont(), 8, "OUTLINE")
    rank:SetPoint("LEFT", r, "LEFT", 3, 0)
    rank:SetWidth(14)
    rank:SetJustifyH("LEFT")
    rank:SetTextColor(1, 1, 0.6)
    r.rank = rank

    -- name
    local name = r:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    name:SetFont(name:GetFont(), 9, "OUTLINE")
    name:SetPoint("LEFT", r, "LEFT", 18, 0)
    name:SetWidth(150)
    name:SetJustifyH("LEFT")
    name:SetTextColor(1, 1, 1)
    r.name = name

    -- value (right side)
    local val = r:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    val:SetFont(val:GetFont(), 9, "OUTLINE")
    val:SetPoint("RIGHT", r, "RIGHT", -3, 0)
    val:SetJustifyH("RIGHT")
    val:SetTextColor(1, 1, 1)
    r.val = val

    r:Hide()
    return r
end

-- Get or create a pooled row
local function GetRow(idx)
    if not rowPool[idx] then
        rowPool[idx] = MakeRow(SlyMetricsRows, idx)
    end
    return rowPool[idx]
end

-- -------------------------------------------------------
-- SM_ShowRows(rows, valueFn, pctFn, labelFn)
-- Generic row renderer.
-- -------------------------------------------------------
local function ShowRows(rows, valueFn, pctFn, labelFn)
    local shown = math.min(#rows, MAX_ROWS)
    for i = 1, shown do
        local row = rows[i]
        local r = GetRow(i)

        r:ClearAllPoints()
        r:SetPoint("TOPLEFT", SlyMetricsRows, "TOPLEFT",
            0, -(ROW_PAD + (i-1) * (ROW_H + ROW_PAD)))
        r:SetWidth(FRAME_W - SIDE_PAD * 2)

        local pct = pctFn(row, rows)
        local barW = math.max(1, math.floor((FRAME_W - SIDE_PAD * 2) * pct))
        r.bar:SetWidth(barW)

        local cr, cg, cb = ClassRGB(row.class or "UNKNOWN")
        r.bar:SetVertexColor(cr * 0.7, cg * 0.7, cb * 0.7, 0.85)

        r.rank:SetText(i)
        r.name:SetText(row.name or "")
        r.val:SetText(labelFn(row))

        -- Tanking highlight (threat panel)
        if row.isTanking then
            r.barbg:SetTexture(0.25, 0.05, 0.05, 0.6)
        else
            r.barbg:SetTexture(0, 0, 0, 0.4)
        end

        r:Show()
    end
    -- Hide excess
    for i = shown + 1, #rowPool do
        rowPool[i]:Hide()
    end
end

-- -------------------------------------------------------
-- Panel refresh functions (called from core + OnUpdate)
-- -------------------------------------------------------
function SM_Refresh()
    if not SlyMetricsFrame or not SlyMetricsFrame:IsShown() then return end
    if SM.activePanel == "dps" then
        SM_RefreshDPS()
    elseif SM.activePanel == "hps" then
        SM_RefreshHPS()
    elseif SM.activePanel == "threat" then
        SM_RefreshThreat()
    end
end

function SM_RefreshDPS()
    local rows, total, elapsed = SM.GetDamageRows()
    ShowRows(rows,
        function(r) return r.total end,
        function(r, all) return total > 0 and r.total / total or 0 end,
        function(r)
            return string.format("%s  |cffaaaaaa%s/s|r",
                SM.FormatLarge(r.total),
                SM.FormatLarge(r.dps))
        end)
    if not SM.inCombat then
        SM_SetStatusText(string.format("%.0fs  |cffffcc00%s|r dmg  |cffaaaaaa%s/s avg|r",
            elapsed,
            SM.FormatLarge(total),
            total > 0 and SM.FormatLarge(total / elapsed) or "0"))
    end
end

function SM_RefreshHPS()
    local rows, total, elapsed = SM.GetHealRows()
    ShowRows(rows,
        function(r) return r.total end,
        function(r, all) return total > 0 and r.total / total or 0 end,
        function(r)
            return string.format("%s  |cffaaaaaa%s/s|r",
                SM.FormatLarge(r.total),
                SM.FormatLarge(r.hps))
        end)
    if not SM.inCombat then
        SM_SetStatusText(string.format("%.0fs  |cff44ff88%s|r heal",
            elapsed, SM.FormatLarge(total)))
    end
end

function SM_RefreshThreat()
    local rows = SM.threatData
    if not rows or #rows == 0 then
        for i = 1, #rowPool do rowPool[i]:Hide() end
        SM_SetStatusText(UnitExists("target") and "No threat data" or "No target")
        return
    end
    local maxVal = rows[1].value
    ShowRows(rows,
        function(r) return r.value end,
        function(r, all) return maxVal > 0 and r.value / maxVal or 0 end,
        function(r)
            local tank = r.isTanking and "|cffff4444[TANK]|r " or ""
            return string.format("%s|cffffcc00%d%%|r  |cffaaaaaa%s|r",
                tank,
                math.floor(r.pct or 0),
                SM.FormatLarge(r.value))
        end)
    local target = UnitName("target") or "target"
    SM_SetStatusText(string.format("%d units on |cffffcc00%s|r", #rows, target))
end

function SM_SetStatusText(txt)
    if SlyMetricsStatus then
        SlyMetricsStatus:SetText(txt)
    end
end

-- -------------------------------------------------------
-- Tab button highlight
-- -------------------------------------------------------
local tabButtons = {}
local function UpdateTabHighlight()
    for panel, btn in pairs(tabButtons) do
        if panel == SM.activePanel then
            btn:SetFontObject("GameFontNormal")
            btn.bg:SetTexture(0.20, 0.40, 0.70, 0.6)
        else
            btn:SetFontObject("GameFontNormalSmall")
            btn.bg:SetTexture(0.10, 0.10, 0.14, 0.6)
        end
    end
end

-- -------------------------------------------------------
-- SM_BuildUI  —  construct the window (called once)
-- -------------------------------------------------------
function SM_BuildUI()
    if SlyMetricsFrame then return end

    local db = SM.db
    local f = CreateFrame("Frame", "SlyMetricsFrame", UIParent)
    f:SetSize(FRAME_W, FRAME_H)
    f:SetPoint(db.position.point, UIParent, db.position.point,
               db.position.x, db.position.y)
    f:SetBackdrop({
        bgFile   = "Interface\\DialogFrame\\UI-DialogBox-Background",
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        tile = true, tileSize = 16, edgeSize = 10,
        insets = { left = 2, right = 2, top = 2, bottom = 2 },
    })
    f:SetBackdropColor(0.05, 0.05, 0.08, 0.94)
    f:SetBackdropBorderColor(0.25, 0.25, 0.35, 1)
    f:EnableMouse(false)
    f:SetMovable(true)
    f:RegisterForDrag("LeftButton")
    f:SetScript("OnDragStart", f.StartMoving)
    f:SetScript("OnDragStop", function(self)
        self:StopMovingOrSizing()
        local p, _, _, x, y = self:GetPoint()
        SM.db.position = { point = p, x = x, y = y }
    end)
    f:HookScript("OnShow", function(self) self:EnableMouse(true)  ; SM_Refresh() end)
    f:HookScript("OnHide", function(self) self:EnableMouse(false) end)
    f:Hide()

    -- ---- Title bar ----
    local titleBg = f:CreateTexture(nil, "ARTWORK")
    titleBg:SetPoint("TOPLEFT",  f, "TOPLEFT",  2,  -2)
    titleBg:SetPoint("TOPRIGHT", f, "TOPRIGHT", -2, -2)
    titleBg:SetHeight(TITLE_H)
    titleBg:SetTexture(0.10, 0.10, 0.15, 1)

    local titleTx = f:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    titleTx:SetPoint("LEFT", f, "LEFT", SIDE_PAD + 2, FRAME_H / 2 - TITLE_H / 2 + 1)
    titleTx:SetPoint("TOPLEFT", f, "TOPLEFT", SIDE_PAD + 2, -3)
    titleTx:SetText("|cff00ccffSly|rMetrics")
    titleTx:SetFont(titleTx:GetFont(), 10, "OUTLINE")

    -- Reset button
    local resetBtn = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
    resetBtn:SetSize(42, 16)
    resetBtn:SetPoint("TOPRIGHT", f, "TOPRIGHT", -22, -3)
    resetBtn:SetText("Reset")
    resetBtn:SetScript("OnClick", function() SM.Reset() end)

    -- Close button
    local closeBtn = CreateFrame("Button", nil, f, "UIPanelCloseButton")
    closeBtn:SetSize(20, 20)
    closeBtn:SetPoint("TOPRIGHT", f, "TOPRIGHT", 2, 2)
    closeBtn:SetScript("OnClick", function() f:Hide() end)

    -- ---- Tab bar ----
    local tabY = -(TITLE_H + 2)
    local tabW = math.floor((FRAME_W - SIDE_PAD * 2) / 3)
    local tabDefs = {
        { id = "dps",    label = "DPS"    },
        { id = "hps",    label = "HPS"    },
        { id = "threat", label = "Threat" },
    }
    for i, td in ipairs(tabDefs) do
        local tab = CreateFrame("Button", nil, f)
        tab:SetSize(tabW, TAB_H)
        tab:SetPoint("TOPLEFT", f, "TOPLEFT",
            SIDE_PAD + (i - 1) * tabW, tabY)

        local tbg = tab:CreateTexture(nil, "BACKGROUND")
        tbg:SetAllPoints()
        tbg:SetTexture(0.10, 0.10, 0.14, 0.6)
        tab.bg = tbg

        local thl = tab:CreateTexture(nil, "HIGHLIGHT")
        thl:SetAllPoints()
        thl:SetTexture(0.30, 0.50, 0.90, 0.25)

        local ttx = tab:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        ttx:SetAllPoints()
        ttx:SetJustifyH("CENTER")
        ttx:SetText(td.label)
        ttx:SetTextColor(1, 1, 1)
        tab:SetFontObject("GameFontNormalSmall")

        local panelId = td.id
        tab:SetScript("OnClick", function()
            SM.activePanel = panelId
            UpdateTabHighlight()
            SM_Refresh()
        end)

        tabButtons[td.id] = tab
    end
    UpdateTabHighlight()

    -- Divider under tabs
    local div = f:CreateTexture(nil, "ARTWORK")
    div:SetPoint("TOPLEFT",  f, "TOPLEFT",  SIDE_PAD, tabY - TAB_H)
    div:SetPoint("TOPRIGHT", f, "TOPRIGHT", -SIDE_PAD, tabY - TAB_H)
    div:SetHeight(1)
    div:SetTexture(0.25, 0.25, 0.35, 0.8)

    -- ---- Row area ----
    local rowHost = CreateFrame("Frame", "SlyMetricsRows", f)
    rowHost:SetPoint("TOPLEFT",  f, "TOPLEFT",  SIDE_PAD, tabY - TAB_H - 2)
    rowHost:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", -SIDE_PAD, STATUS_H + 4)
    rowHost:EnableMouse(false)

    -- ---- Status bar ----
    local status = f:CreateFontString("SlyMetricsStatus", "OVERLAY", "GameFontNormalSmall")
    status:SetPoint("BOTTOMLEFT",  f, "BOTTOMLEFT",  SIDE_PAD + 2, 4)
    status:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", -(SIDE_PAD + 2), 4)
    status:SetJustifyH("CENTER")
    status:SetFont(status:GetFont(), 8, "OUTLINE")
    status:SetTextColor(0.55, 0.55, 0.65)
    status:SetText("No data")
end
