-- ================================================================
-- SlyAuctionUI.lua  —  Main window: item list + detail / buy / sell
--
-- Layout (780 × 500):
--   Header    (34px): title | scan/stop | status | close
--   Col hdrs  (18px): name | T | Floor | 7d Avg | Opp% | Qty
--   Left pane (420px wide, scrollable): one row per tracked item
--   Divider   (1px)
--   Right pane (359px): stats, buy controls, sell controls, history
--   Footer    (28px): last-scan time | version
-- ================================================================

local FRAME_W   = 780
local FRAME_H   = 500
local HDR_H     = 34
local COLHDR_H  = 18
local FOOT_H    = 28
local LIST_W    = 420
local DETAIL_W  = FRAME_W - LIST_W - 1   -- 359
local PAD       = 8
local ROW_H     = 22

-- Column layout for the item list
local COLS = {
    { key="name",    label="Item",    w=152, align="LEFT"   },
    { key="trend",   label="T",       w=20,  align="CENTER" },
    { key="lastMin", label="Floor",   w=78,  align="RIGHT"  },
    { key="avg7d",   label="7d Avg",  w=78,  align="RIGHT"  },
    { key="opp",     label="Opp%",    w=52,  align="RIGHT"  },
    { key="qty",     label="Qty",     w=38,  align="RIGHT"  },
}
-- sum = 152+20+78+78+52+38 = 418 (fits LIST_W)

local SAFrame          = nil
local _itemRows        = {}   -- [itemName] = row widget
local _selectedItem    = nil
local _statusFS        = nil
local _lastScanFS      = nil

-- detail pane widgets
local _dp              = {}   -- populated by _BuildDetailPane

-- ----------------------------------------------------------------
-- Colour helpers
-- ----------------------------------------------------------------
local function _OppColor(opp)
    if     opp >=  0.20 then return 0.0, 1.0, 0.3
    elseif opp >=  0.10 then return 0.4, 1.0, 0.3
    elseif opp >=  0.03 then return 0.8, 1.0, 0.3
    elseif opp >= -0.03 then return 0.9, 0.9, 0.3
    elseif opp >= -0.10 then return 1.0, 0.5, 0.2
    else                     return 1.0, 0.2, 0.2
    end
end

local function _TrendText(trend)
    if not trend     then return "--", 0.6, 0.6, 0.6 end
    if trend > 0.05  then return "UP",  1.0, 0.4, 0.4 end  -- rising  (pricier -> sell)
    if trend < -0.05 then return "DN",  0.4, 1.0, 0.4 end  -- falling (cheaper -> buy)
    return "->", 0.7, 0.7, 0.7
end

local function _AgeStr(t)
    if not t then return "never" end
    local age = time() - t
    if age < 60    then return age .. "s ago" end
    if age < 3600  then return math.floor(age / 60) .. "m ago" end
    if age < 86400 then return math.floor(age / 3600) .. "h ago" end
    return math.floor(age / 86400) .. "d ago"
end

-- ----------------------------------------------------------------
-- Solid background texture factory
-- ----------------------------------------------------------------
local function _Bg(parent, r, g, b, a, layer)
    local t = parent:CreateTexture(nil, layer or "BACKGROUND")
    t:SetAllPoints(parent)
    t:SetColorTexture(r, g, b, a or 1)
    return t
end

local function _HLine(parent, y, xL, xR)
    local t = parent:CreateTexture(nil, "BACKGROUND")
    t:SetHeight(1)
    t:SetPoint("TOPLEFT",  parent, "TOPLEFT",  xL or PAD,      y)
    t:SetPoint("TOPRIGHT", parent, "TOPRIGHT", -(xR or PAD),   y)
    t:SetColorTexture(0.2, 0.2, 0.28, 1)
    return t
end

-- ================================================================
-- Detail pane
-- ================================================================
local function _BuildDetailPane(parent)
    local pane = CreateFrame("Frame", nil, parent)
    pane:SetPoint("TOPLEFT",     parent, "TOPLEFT",     LIST_W + 1, -HDR_H - COLHDR_H)
    pane:SetPoint("BOTTOMRIGHT", parent, "BOTTOMRIGHT", 0,           FOOT_H)
    _Bg(pane, 0.03, 0.03, 0.06, 1)

    local x0, xR = PAD, -(PAD)
    local y = -6

    -- Title
    local title = pane:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    title:SetPoint("TOPLEFT",  pane, "TOPLEFT",  x0, y)
    title:SetPoint("TOPRIGHT", pane, "TOPRIGHT", xR, y)
    title:SetJustifyH("LEFT")
    title:SetText("Select an item")
    _dp.title = title
    y = y - 22

    -- Stats rows: label on left, value on right
    local STAT_DEFS = {
        { key="lastMin",  label="Floor (last scan)" },
        { key="avg7d",    label="7-day avg" },
        { key="avg14d",   label="14-day avg" },
        { key="in_bags",  label="In bags" },
        { key="trend",    label="Trend" },
        { key="opp",      label="Opportunity" },
        { key="count",    label="Listings (last scan)" },
        { key="lastScan", label="Last scanned" },
    }
    _dp.statVals = {}
    for _, sd in ipairs(STAT_DEFS) do
        local lf = pane:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        lf:SetPoint("TOPLEFT", pane, "TOPLEFT", x0, y)
        lf:SetTextColor(0.55, 0.55, 0.55)
        lf:SetText(sd.label)

        local vf = pane:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        vf:SetPoint("TOPRIGHT", pane, "TOPRIGHT", xR, y)
        vf:SetJustifyH("RIGHT")
        vf:SetText("--")
        _dp.statVals[sd.key] = vf
        y = y - 17
    end

    -- ── BUY section ────────────────────────────────────────────
    _HLine(pane, y - 3, x0, PAD) ; y = y - 14

    local buyHdr = pane:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    buyHdr:SetPoint("TOPLEFT", pane, "TOPLEFT", x0, y)
    buyHdr:SetText("|cffffcc00BUY|r")
    y = y - 18

    local buyInfo = pane:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    buyInfo:SetPoint("TOPLEFT",  pane, "TOPLEFT",  x0,     y)
    buyInfo:SetPoint("TOPRIGHT", pane, "TOPRIGHT", xR,     y)
    buyInfo:SetJustifyH("LEFT")
    buyInfo:SetText("|cff888888Scan first to see live listings|r")
    _dp.buyInfo = buyInfo
    y = y - 20

    -- Qty + Buy button on same row
    local qtyLbl = pane:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    qtyLbl:SetPoint("TOPLEFT", pane, "TOPLEFT", x0, y)
    qtyLbl:SetTextColor(0.65, 0.65, 0.65)
    qtyLbl:SetText("Qty:")

    local qtyBox = CreateFrame("EditBox", nil, pane, "InputBoxTemplate")
    qtyBox:SetSize(46, 20)
    qtyBox:SetPoint("LEFT", qtyLbl, "RIGHT", 6, 0)
    qtyBox:SetAutoFocus(false)
    qtyBox:SetNumeric(true)
    qtyBox:SetText("1")
    qtyBox:SetMaxLetters(4)
    _dp.qtyBox = qtyBox

    local buyBtn = CreateFrame("Button", nil, pane, "UIPanelButtonTemplate")
    buyBtn:SetSize(100, 22)
    buyBtn:SetPoint("LEFT", qtyBox, "RIGHT", 8, 0)
    buyBtn:SetText("Snipe Buy")
    buyBtn:SetEnabled(false)
    buyBtn:SetScript("OnClick", function()
        if not _selectedItem then return end
        local qty = tonumber(_dp.qtyBox:GetText()) or 1
        SA_BuyBelow(_selectedItem, qty)
    end)
    buyBtn:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_TOP")
        GameTooltip:SetText("Buy up to this many units\nbelow the snipe threshold.\nRequires AH to be open.", nil, nil, nil, nil, true)
        GameTooltip:Show()
    end)
    buyBtn:SetScript("OnLeave", function() GameTooltip:Hide() end)
    _dp.buyBtn = buyBtn
    y = y - 26

    -- Snipe threshold
    local sLbl = pane:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    sLbl:SetPoint("TOPLEFT", pane, "TOPLEFT", x0, y)
    sLbl:SetTextColor(0.55, 0.55, 0.55)
    sLbl:SetText("Snipe at <= ")

    local sBox = CreateFrame("EditBox", nil, pane, "InputBoxTemplate")
    sBox:SetSize(38, 18)
    sBox:SetPoint("LEFT", sLbl, "RIGHT", 4, 0)
    sBox:SetAutoFocus(false)
    sBox:SetText("85")
    sBox:SetMaxLetters(3)
    sBox:SetScript("OnEnterPressed", function(self)
        local v = tonumber(self:GetText())
        if v and v > 0 and v <= 200 then
            SA_GetSettings().snipeThreshold = v / 100
        end
        self:ClearFocus()
        _RefreshDetailPane()
    end)
    _dp.snipeBox = sBox

    local sPct = pane:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    sPct:SetPoint("LEFT", sBox, "RIGHT", 3, 0)
    sPct:SetTextColor(0.55, 0.55, 0.55)
    sPct:SetText("% of 7d avg")
    y = y - 26

    -- ── SELL section ───────────────────────────────────────────
    _HLine(pane, y - 3, x0, PAD) ; y = y - 14

    local sellHdr = pane:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    sellHdr:SetPoint("TOPLEFT", pane, "TOPLEFT", x0, y)
    sellHdr:SetText("|cffffcc00SELL|r")
    y = y - 18

    local sugLbl = pane:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    sugLbl:SetPoint("TOPLEFT", pane, "TOPLEFT", x0, y)
    sugLbl:SetTextColor(0.6, 0.6, 0.6)
    sugLbl:SetText("Suggested price:")

    local sugVal = pane:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    sugVal:SetPoint("TOPRIGHT", pane, "TOPRIGHT", xR, y)
    sugVal:SetJustifyH("RIGHT")
    sugVal:SetText("--")
    _dp.suggestVal = sugVal
    y = y - 20

    local fillBtn = CreateFrame("Button", nil, pane, "UIPanelButtonTemplate")
    fillBtn:SetSize(180, 22)
    fillBtn:SetPoint("TOPLEFT", pane, "TOPLEFT", x0, y)
    fillBtn:SetText("Apply Price -> AH Frame")
    fillBtn:SetEnabled(false)
    fillBtn:SetScript("OnClick", function()
        if _selectedItem then SA_ApplySellPrice(_selectedItem) end
    end)
    fillBtn:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_TOP")
        GameTooltip:SetText("Fills the Buyout field\non the Auction House frame.\nDrag your item to the AH slot first.", nil, nil, nil, nil, true)
        GameTooltip:Show()
    end)
    fillBtn:SetScript("OnLeave", function() GameTooltip:Hide() end)
    _dp.fillBtn = fillBtn
    y = y - 28

    -- ── Price history ───────────────────────────────────────────
    _HLine(pane, y - 3, x0, PAD) ; y = y - 14

    local histHdr = pane:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    histHdr:SetPoint("TOPLEFT", pane, "TOPLEFT", x0, y)
    histHdr:SetText("|cff777777Price history (last 8 scans)|r")
    y = y - 17

    _dp.histLines = {}
    for i = 1, 8 do
        local hl = pane:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        hl:SetPoint("TOPLEFT", pane, "TOPLEFT", x0, y)
        hl:SetWidth(DETAIL_W - PAD * 2)
        hl:SetJustifyH("LEFT")
        hl:SetText("")
        _dp.histLines[i] = hl
        y = y - 15
    end

    _dp.pane = pane
end

-- ================================================================
-- Refresh detail pane for the currently selected item
-- ================================================================
function _RefreshDetailPane()
    if not _dp.title then return end
    local name = _selectedItem

    if not name then
        _dp.title:SetText("Select an item")
        for _, vf in pairs(_dp.statVals or {}) do vf:SetText("--") end
        return
    end

    _dp.title:SetText(name)

    local entry = SA_GetStats(name)
    local stats = entry and entry.stats or {}
    local sv    = _dp.statVals
    local cfg   = SA_GetSettings()

    if sv.lastMin  then sv.lastMin:SetText(SA_FormatCopperShort(stats.lastMin)) end
    if sv.avg7d    then sv.avg7d:SetText(SA_FormatCopperShort(stats.avg7d)) end
    if sv.avg14d   then sv.avg14d:SetText(SA_FormatCopperShort(stats.avg14d)) end

    -- Bags count
    local def    = SLYAUCTION_ITEM_BY_NAME and SLYAUCTION_ITEM_BY_NAME[name]
    local itemId = (entry and entry.id ~= 0 and entry.id) or (def and def.id) or 0
    if sv.in_bags then sv.in_bags:SetText(tostring(SA_CountInBags(itemId))) end

    -- Trend
    local tt, tr, tg, tb = _TrendText(stats.trend)
    if sv.trend then sv.trend:SetText(tt) ; sv.trend:SetTextColor(tr, tg, tb) end

    -- Opportunity
    local opp    = stats.opp or 0
    local or_, og, ob = _OppColor(opp)
    local oppTxt = string.format("%+.1f%%", opp * 100)
    if stats.avg7d and stats.lastMin then
        if     opp >= 0.05 then oppTxt = oppTxt .. "  |cff44ff44< BUY|r"
        elseif opp <= -0.05 then oppTxt = oppTxt .. "  |cffff7744< SELL|r"
        end
    end
    if sv.opp then sv.opp:SetText(oppTxt) ; sv.opp:SetTextColor(or_, og, ob) end

    if sv.count    then sv.count:SetText(tostring(stats.lastCount or "--")) end
    if sv.lastScan then sv.lastScan:SetText(_AgeStr(stats.lastScan)) end

    -- Buy panel
    local buyOk = false
    if entry and entry.listings and #entry.listings > 0 and stats.avg7d then
        local thresh = stats.avg7d * cfg.snipeThreshold
        local below, belowQty = 0, 0
        for _, l in ipairs(entry.listings) do
            if l.perUnit <= thresh then
                below    = below    + 1
                belowQty = belowQty + l.qty
            end
        end
        if below > 0 then
            _dp.buyInfo:SetText(string.format(
                "|cff44ff44%d listing%s|r <= threshold  (%d units  @ <= %s ea)",
                below, below == 1 and "" or "s", belowQty, SA_FormatCopperShort(thresh)))
            buyOk = true
        else
            _dp.buyInfo:SetText("|cffaaaaaa0 listings at or below snipe threshold.|r")
        end
    elseif entry then
        _dp.buyInfo:SetText("|cff888888Scan this item to see live listings.|r")
    else
        _dp.buyInfo:SetText("|cff888888No data - Scan All to begin tracking.|r")
    end
    if _dp.buyBtn  then _dp.buyBtn:SetEnabled(buyOk) end
    if _dp.snipeBox then
        _dp.snipeBox:SetText(tostring(math.floor((cfg.snipeThreshold or 0.85) * 100)))
    end

    -- Sell
    local suggest = SA_SuggestSellPrice(name)
    if _dp.suggestVal then
        _dp.suggestVal:SetText(suggest and SA_FormatCopper(suggest) or "--")
    end
    if _dp.fillBtn then
        _dp.fillBtn:SetEnabled(suggest ~= nil)
    end

    -- History
    if entry and entry.scans then
        local scans = entry.scans
        local n     = math.min(8, #scans)
        for i = 1, 8 do
            local hl = _dp.histLines[i]
            if not hl then break end
            local si = #scans - n + i
            if i <= n and si >= 1 then
                local s   = scans[si]
                local age = _AgeStr(s.t)
                hl:SetText(string.format(
                    "|cff777777%s|r  floor |cffffd700%s|r  avg |cff888888%s|r  x%d",
                    age, SA_FormatCopperShort(s.min),
                    SA_FormatCopperShort(s.avg), s.count))
            else
                hl:SetText("")
            end
        end
    else
        for i = 1, 8 do
            if _dp.histLines[i] then _dp.histLines[i]:SetText("") end
        end
    end
end

-- ================================================================
-- Item list rows
-- ================================================================
local function _BuildRow(parent, y, itemName)
    local row = CreateFrame("Button", nil, parent)
    row:SetSize(LIST_W - 20, ROW_H)   -- -20 for scrollbar
    row:SetPoint("TOPLEFT", parent, "TOPLEFT", 0, y)

    local rowBg = row:CreateTexture(nil, "BACKGROUND")
    rowBg:SetAllPoints(row)
    rowBg:SetColorTexture(0, 0, 0, 0)
    row._bg = rowBg

    local hilight = row:CreateTexture(nil, "HIGHLIGHT")
    hilight:SetAllPoints(row)
    hilight:SetColorTexture(0.2, 0.4, 0.8, 0.12)

    -- Column FontStrings
    local xOff = 2
    local fss  = {}
    for ci, col in ipairs(COLS) do
        local fs = row:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        if ci == 1 then
            fs:SetPoint("LEFT",  row, "LEFT", xOff, 0)
            fs:SetWidth(col.w - 4)
        else
            fs:SetPoint("LEFT",  row, "LEFT", xOff, 0)
            fs:SetWidth(col.w)
        end
        fs:SetJustifyH(col.align)
        fss[col.key] = fs
        xOff = xOff + col.w
    end
    fss.name:SetText(itemName)
    row._fs = fss

    row:SetScript("OnClick", function()
        _selectedItem = itemName
        -- Deselect all
        for _, r in pairs(_itemRows) do
            if r._bg then r._bg:SetColorTexture(0, 0, 0, 0) end
        end
        rowBg:SetColorTexture(0.1, 0.3, 0.65, 0.28)
        _RefreshDetailPane()
    end)

    row:SetScript("OnLeave", function()
        if itemName ~= _selectedItem then
            -- keep opp-based tint (set during RefreshRow)
        end
    end)

    return row
end

local function _RefreshRow(row, itemName)
    local entry = SA_GetStats(itemName)
    local stats = entry and entry.stats or {}
    local fs    = row._fs

    -- Trend
    local tt, tr, tg, tb = _TrendText(stats.trend)
    if fs.trend then fs.trend:SetText(tt) ; fs.trend:SetTextColor(tr, tg, tb) end

    -- Floor
    if fs.lastMin then
        fs.lastMin:SetText(SA_FormatCopperShort(stats.lastMin))
        fs.lastMin:SetTextColor(1, 1, 1)
    end

    -- 7d avg
    if fs.avg7d then
        fs.avg7d:SetText(SA_FormatCopperShort(stats.avg7d))
        fs.avg7d:SetTextColor(0.7, 0.7, 0.7)
    end

    -- Opp%
    local opp = stats.opp or 0
    local or_, og, ob = _OppColor(opp)
    if fs.opp then
        fs.opp:SetText(string.format("%+.0f%%", opp * 100))
        fs.opp:SetTextColor(or_, og, ob)
    end

    -- Qty (listing count from last scan)
    if fs.qty then
        fs.qty:SetText(stats.lastCount and tostring(stats.lastCount) or "--")
        fs.qty:SetTextColor(0.55, 0.55, 0.55)
    end

    -- Row background tint based on opportunity
    if itemName == _selectedItem then
        if row._bg then row._bg:SetColorTexture(0.1, 0.3, 0.65, 0.28) end
    elseif stats.opp and stats.opp >= 0.10 then
        if row._bg then row._bg:SetColorTexture(0.0, 0.18, 0.0, 0.18) end
    elseif stats.opp and stats.opp <= -0.10 then
        if row._bg then row._bg:SetColorTexture(0.18, 0.0, 0.0, 0.15) end
    else
        if row._bg then row._bg:SetColorTexture(0, 0, 0, 0) end
    end
end

-- ================================================================
-- Public refresh helpers (called from SlyAuction.lua callbacks)
-- ================================================================
function SA_RefreshItemList()
    if not SAFrame then return end
    for _, item in ipairs(SLYAUCTION_ITEMS) do
        local row = _itemRows[item.name]
        if row then _RefreshRow(row, item.name) end
    end
end

function SA_UpdateLastScanLabel()
    if not _lastScanFS then return end
    if SlyAuctionDB and SlyAuctionDB.lastScanTime then
        _lastScanFS:SetText("Last scan: " .. _AgeStr(SlyAuctionDB.lastScanTime))
    else
        _lastScanFS:SetText("Never scanned - open the Auction House then click Scan All")
    end
end

-- ================================================================
-- Callbacks wired by SlyAuction.lua
-- ================================================================
function SA_UI_OnStatusUpdate()
    if _statusFS then _statusFS:SetText(SlyAuction.statusText or "") end
end

function SA_UI_OnItemScanned(name)
    local row = _itemRows[name]
    if row then _RefreshRow(row, name) end
    if name == _selectedItem then _RefreshDetailPane() end
end

function SA_UI_OnScanComplete()
    SA_RefreshItemList()
    SA_UpdateLastScanLabel()
    if _selectedItem then _RefreshDetailPane() end
end

function SA_UI_OnAHOpen()
    if _statusFS then _statusFS:SetText("Auction House open - click Scan All to begin") end
end

function SA_UI_OnAHClose()
    if _statusFS then _statusFS:SetText("Auction House closed") end
end

-- ================================================================
-- Apply sell price to the Blizzard AH frame
-- ================================================================
function SA_ApplySellPrice(name)
    local price = SA_SuggestSellPrice(name)
    if not price then
        print("|cffffcc00[SlyAuction]|r No price data for " .. name .. " - scan first.")
        return
    end

    -- Blizzard AH frame: try several known EditBox global names
    local buyoutBox = _G["AuctionFrameAuctionsBuyoutPrice"]
                   or (AuctionFrameAuctions and AuctionFrameAuctions.BuyoutPrice)
    if buyoutBox and buyoutBox.SetText then
        buyoutBox:SetText(tostring(price))
        local onChange = buyoutBox:GetScript("OnTextChanged")
        if onChange then onChange(buyoutBox, true) end
        print(string.format("|cff44ff44[SlyAuction]|r Buyout set to %s - drag %s to AH slot & Start Auction",
            SA_FormatCopper(price), name))
    else
        -- Fallback: print to chat so player can manually enter
        print(string.format("|cffffcc00[SlyAuction]|r Suggested price: %s/unit  (open AH to apply)",
            SA_FormatCopper(price)))
    end
end

-- ================================================================
-- Main frame construction
-- ================================================================
function SA_BuildUI()
    if SAFrame then return end

    SAFrame = CreateFrame("Frame", "SlyAuctionFrame", UIParent,
        BackdropTemplateMixin and "BackdropTemplate" or nil)
    SAFrame:SetSize(FRAME_W, FRAME_H)
    SAFrame:SetPoint("CENTER", UIParent, "CENTER", 0, 40)
    SAFrame:SetMovable(true)
    SAFrame:EnableMouse(true)
    SAFrame:RegisterForDrag("LeftButton")
    SAFrame:SetScript("OnDragStart", function(self) self:StartMoving() end)
    SAFrame:SetScript("OnDragStop",  function(self) self:StopMovingOrSizing() end)
    SAFrame:SetFrameStrata("HIGH")
    SAFrame:Hide()

    if SAFrame.SetBackdrop then
        SAFrame:SetBackdrop({
            bgFile   = "Interface\\ChatFrame\\ChatFrameBackground",
            edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
            edgeSize = 12, tile = true, tileSize = 16,
            insets   = { left=3, right=3, top=3, bottom=3 },
        })
        SAFrame:SetBackdropColor(0.04, 0.04, 0.07, 0.97)
        SAFrame:SetBackdropBorderColor(0.28, 0.28, 0.38, 1)
    else
        _Bg(SAFrame, 0.04, 0.04, 0.07, 0.97)
    end

    -- ── Header ──────────────────────────────────────────────────
    local hdr = CreateFrame("Frame", nil, SAFrame)
    hdr:SetHeight(HDR_H)
    hdr:SetPoint("TOPLEFT",  SAFrame, "TOPLEFT",  0, 0)
    hdr:SetPoint("TOPRIGHT", SAFrame, "TOPRIGHT", 0, 0)
    _Bg(hdr, 0.07, 0.07, 0.11, 1)

    local titleFS = hdr:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    titleFS:SetPoint("LEFT", hdr, "LEFT", PAD, 0)
    titleFS:SetText("|cffffcc00SlyAuction|r  |cff666666Market Intelligence|r")

    -- Close
    local closeBtn = CreateFrame("Button", nil, hdr, "UIPanelCloseButton")
    closeBtn:SetPoint("TOPRIGHT", hdr, "TOPRIGHT", 2, 2)
    closeBtn:SetScript("OnClick", function() SAFrame:Hide() end)

    -- Scan All
    local scanBtn = CreateFrame("Button", nil, hdr, "UIPanelButtonTemplate")
    scanBtn:SetSize(80, 22)
    scanBtn:SetPoint("RIGHT", closeBtn, "LEFT", -6, 0)
    scanBtn:SetText("Scan All")
    scanBtn:SetScript("OnClick", function() SA_ScanAll() end)

    -- Stop
    local stopBtn = CreateFrame("Button", nil, hdr, "UIPanelButtonTemplate")
    stopBtn:SetSize(50, 22)
    stopBtn:SetPoint("RIGHT", scanBtn, "LEFT", -4, 0)
    stopBtn:SetText("Stop")
    stopBtn:SetScript("OnClick", function() SA_StopScan() end)

    -- Status
    _statusFS = hdr:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    _statusFS:SetPoint("LEFT",  titleFS, "RIGHT", 10, 0)
    _statusFS:SetPoint("RIGHT", stopBtn, "LEFT",  -8, 0)
    _statusFS:SetJustifyH("LEFT")
    _statusFS:SetTextColor(0.55, 0.55, 0.55)
    _statusFS:SetText("Idle - open the Auction House to scan")

    -- Header bottom border
    local hdrLine = SAFrame:CreateTexture(nil, "BACKGROUND")
    hdrLine:SetHeight(1)
    hdrLine:SetPoint("TOPLEFT",  SAFrame, "TOPLEFT",  0, -HDR_H)
    hdrLine:SetPoint("TOPRIGHT", SAFrame, "TOPRIGHT", 0, -HDR_H)
    hdrLine:SetColorTexture(0.2, 0.2, 0.3, 1)

    -- ── Column headers ───────────────────────────────────────────
    local xOff = 4
    for _, col in ipairs(COLS) do
        local fs = SAFrame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        fs:SetPoint("TOPLEFT", SAFrame, "TOPLEFT", xOff, -(HDR_H + 2))
        fs:SetWidth(col.w)
        fs:SetJustifyH(col.align)
        fs:SetText(col.label)
        fs:SetTextColor(0.65, 0.65, 0.45)
        xOff = xOff + col.w
    end

    local colLine = SAFrame:CreateTexture(nil, "BACKGROUND")
    colLine:SetHeight(1)
    colLine:SetPoint("TOPLEFT",  SAFrame, "TOPLEFT",  0, -(HDR_H + COLHDR_H))
    colLine:SetPoint("TOPRIGHT", SAFrame, "TOPRIGHT", LIST_W, -(HDR_H + COLHDR_H))
    colLine:SetColorTexture(0.18, 0.18, 0.25, 1)

    -- ── Vertical divider ─────────────────────────────────────────
    local vDiv = SAFrame:CreateTexture(nil, "BACKGROUND")
    vDiv:SetWidth(1)
    vDiv:SetPoint("TOPLEFT",    SAFrame, "TOPLEFT",   LIST_W, -HDR_H)
    vDiv:SetPoint("BOTTOMLEFT", SAFrame, "BOTTOMLEFT",LIST_W,  FOOT_H)
    vDiv:SetColorTexture(0.2, 0.2, 0.3, 1)

    -- ── Scroll frame for item list ───────────────────────────────
    local scrollFrame = CreateFrame("ScrollFrame", "SlyAuctionListScroll", SAFrame,
        "UIPanelScrollFrameTemplate")
    scrollFrame:SetPoint("TOPLEFT",     SAFrame, "TOPLEFT",   0, -(HDR_H + COLHDR_H + 1))
    scrollFrame:SetPoint("BOTTOMRIGHT", SAFrame, "BOTTOMLEFT",LIST_W, FOOT_H + 2)

    local scrollChild = CreateFrame("Frame")
    local totalH = #SLYAUCTION_ITEMS * ROW_H + 4
    scrollChild:SetSize(LIST_W - 20, totalH)
    scrollFrame:SetScrollChild(scrollChild)

    -- List background
    local listBg = scrollChild:CreateTexture(nil, "BACKGROUND")
    listBg:SetAllPoints(scrollChild)
    listBg:SetColorTexture(0.025, 0.025, 0.04, 1)

    -- Build rows
    local ry = -1
    for _, item in ipairs(SLYAUCTION_ITEMS) do
        local row = _BuildRow(scrollChild, ry, item.name)
        _itemRows[item.name] = row
        ry = ry - ROW_H
    end

    -- Zebra stripe
    for i, item in ipairs(SLYAUCTION_ITEMS) do
        if i % 2 == 0 then
            local stripe = _itemRows[item.name]:CreateTexture(nil, "BACKGROUND")
            stripe:SetAllPoints(_itemRows[item.name])
            stripe:SetColorTexture(1, 1, 1, 0.025)
        end
    end

    -- ── Footer ───────────────────────────────────────────────────
    _lastScanFS = SAFrame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    _lastScanFS:SetPoint("BOTTOMLEFT", SAFrame, "BOTTOMLEFT", PAD, 8)
    _lastScanFS:SetTextColor(0.45, 0.45, 0.45)

    local verFS = SAFrame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    verFS:SetPoint("BOTTOMRIGHT", SAFrame, "BOTTOMRIGHT", -PAD - 20, 8)
    verFS:SetTextColor(0.35, 0.35, 0.35)
    verFS:SetText("SlyAuction v" .. SlyAuction.version)

    -- ── Detail pane ──────────────────────────────────────────────
    _BuildDetailPane(SAFrame)

    -- ── First population ─────────────────────────────────────────
    SA_RefreshItemList()
    SA_UpdateLastScanLabel()

    tinsert(UISpecialFrames, "SlyAuctionFrame")
end

-- ================================================================
-- Toggle
-- ================================================================
function SA_ToggleUI()
    if not SAFrame then
        SA_BuildUI()
        SA_RefreshItemList()
        SA_UpdateLastScanLabel()
        SAFrame:Show()
        return
    end
    if SAFrame:IsShown() then
        SAFrame:Hide()
    else
        SA_RefreshItemList()
        SA_UpdateLastScanLabel()
        SAFrame:Show()
    end
end
