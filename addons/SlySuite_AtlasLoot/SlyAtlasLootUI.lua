-- ============================================================
-- SlyAtlasLootUI.lua
-- Drop rate search panel for SlyAtlasLoot.
-- Panel: item name/link search → scrollable list of
--        (Source Name | Drop %) pairs, sorted descending.
-- ============================================================

local PANEL_W  = 420
local PANEL_H  = 520
local HDR_H    = 30
local PAD      = 10
local ROW_H    = 19
local MAX_ROWS = 18          -- visible result rows before scroll
local MAX_SRC  = 12          -- max source rows per item

SlyAtlasLootPanel = nil      -- main frame (global for PLAYER_LOGOUT)

-- --------------------------------------------------------
-- Visual helpers
-- --------------------------------------------------------
local function FillBg(f, r, g, b, a)
    local t = f:CreateTexture(nil, "BACKGROUND")
    t:SetAllPoints(f)
    t:SetColorTexture(r, g, b, a or 1)
    return t
end

local function Label(parent, text, fontSize, r, g, b, anchor, ox, oy)
    local fs = parent:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    fs:SetFont(fs:GetFont(), fontSize or 11, "")
    if anchor then fs:SetPoint(anchor, parent, anchor, ox or 0, oy or 0) end
    if r then fs:SetTextColor(r, g, b) end
    fs:SetText(text)
    return fs
end

-- --------------------------------------------------------
-- Row pool for the results list
-- --------------------------------------------------------
local resultRows = {}    -- pre-built row frames
local sourceRows = {}    -- pre-built source sub-row frames

-- --------------------------------------------------------
-- State
-- --------------------------------------------------------
local currentResults = {}   -- last search results (array of {itemID, name, link, drops})
local selectedIdx    = nil  -- index into currentResults that is expanded
local resultOffset   = 0    -- scroll offset for result list

-- --------------------------------------------------------
-- Forward declarations
-- --------------------------------------------------------
local RefreshResults, RefreshSources

-- --------------------------------------------------------
-- Build panel
-- --------------------------------------------------------
function SAL_BuildPanel()
    if SlyAtlasLootPanel then return end

    local f = CreateFrame("Frame", "SlyAtlasLootPanel", UIParent)
    f:SetSize(PANEL_W, PANEL_H)
    f:SetFrameStrata("DIALOG")
    f:SetMovable(true)
    f:EnableMouse(true)
    f:RegisterForDrag("LeftButton")
    f:SetScript("OnDragStart", f.StartMoving)
    f:SetScript("OnDragStop", function(self)
        self:StopMovingOrSizing()
        local pt, _, _, x, y = self:GetPoint()
        SAL.db.position = { point = pt, x = x, y = y }
    end)
    f:Hide()

    local pos = SAL.db.position or {}
    f:SetPoint(pos.point or "CENTER", UIParent, pos.point or "CENTER",
        pos.x or 0, pos.y or 0)

    -- Background + border
    FillBg(f, 0.06, 0.06, 0.08, 0.97)
    local bord = f:CreateTexture(nil, "OVERLAY")
    bord:SetAllPoints(f)
    bord:SetColorTexture(0.3, 0.3, 0.35, 1)
    local inner = f:CreateTexture(nil, "BACKGROUND")
    inner:SetPoint("TOPLEFT",     f, "TOPLEFT",     1, -1)
    inner:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", -1,  1)
    inner:SetColorTexture(0.06, 0.06, 0.08, 0.97)

    -- ---- Header ----
    local hdr = CreateFrame("Frame", nil, f)
    hdr:SetSize(PANEL_W, HDR_H)
    hdr:SetPoint("TOPLEFT", f, "TOPLEFT", 0, 0)
    FillBg(hdr, 0.08, 0.10, 0.15, 1)

    local icon = hdr:CreateTexture(nil, "ARTWORK")
    icon:SetSize(18, 18)
    icon:SetPoint("LEFT", hdr, "LEFT", 8, 0)
    icon:SetTexture("Interface\\Icons\\INV_Misc_Map_01")
    icon:SetTexCoord(0.07, 0.93, 0.07, 0.93)

    local title = hdr:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    title:SetFont(title:GetFont(), 13, "OUTLINE")
    title:SetPoint("LEFT", icon, "RIGHT", 6, 0)
    title:SetText("|cff88bbff✦ SlyAtlasLoot|r")
    title:SetTextColor(1, 1, 1)

    local closeBtn = CreateFrame("Button", nil, hdr, "UIPanelCloseButton")
    closeBtn:SetSize(24, 24)
    closeBtn:SetPoint("RIGHT", hdr, "RIGHT", -2, 0)
    closeBtn:SetScript("OnClick", function() f:Hide() end)

    local hdrSep = f:CreateTexture(nil, "ARTWORK")
    hdrSep:SetSize(PANEL_W, 1)
    hdrSep:SetPoint("TOPLEFT", f, "TOPLEFT", 0, -HDR_H)
    hdrSep:SetColorTexture(0.3, 0.3, 0.35, 1)

    -- ---- Stats bar ----
    local statsLbl = f:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    statsLbl:SetFont(statsLbl:GetFont(), 9, "")
    statsLbl:SetPoint("TOPLEFT", f, "TOPLEFT", PAD, -(HDR_H + 6))
    statsLbl:SetTextColor(0.45, 0.45, 0.5)
    statsLbl:SetText("AtlasLoot not loaded")
    SAL.statsLbl = statsLbl

    -- "Open AtlasLoot" button
    local alBtn = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
    alBtn:SetSize(110, 18)
    alBtn:SetPoint("TOPRIGHT", f, "TOPRIGHT", -PAD, -(HDR_H + 4))
    alBtn:SetText("Open AtlasLoot")
    alBtn:SetScript("OnClick", function()
        if _G.AtlasLoot and _G.AtlasLoot.GUI then
            _G.AtlasLoot.GUI:Toggle()
        else
            DEFAULT_CHAT_FRAME:AddMessage("|cff88bbff[SlyAtlasLoot]|r AtlasLoot is not loaded.")
        end
    end)

    -- ---- Settings row ----
    local settingsY = -(HDR_H + 24)

    -- Tooltip toggle
    local tipChk = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
    tipChk:SetSize(80, 18)
    tipChk:SetPoint("TOPLEFT", f, "TOPLEFT", PAD, settingsY)
    local function RefreshTipBtn()
        tipChk:SetText(SAL.db.tooltipEnabled and "|cff44ff44Tip: ON|r" or "|cffaaaaaa Tip: OFF|r")
    end
    RefreshTipBtn()
    tipChk:SetScript("OnClick", function()
        SAL.db.tooltipEnabled = not SAL.db.tooltipEnabled
        RefreshTipBtn()
    end)

    -- Target toggle
    local tgtChk = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
    tgtChk:SetSize(90, 18)
    tgtChk:SetPoint("LEFT", tipChk, "RIGHT", 4, 0)
    local function RefreshTgtBtn()
        tgtChk:SetText(SAL.db.tooltipTarget and "|cff44ff44Target: ON|r" or "|cffaaaaaa Target: OFF|r")
    end
    RefreshTgtBtn()
    tgtChk:SetScript("OnClick", function()
        SAL.db.tooltipTarget = not SAL.db.tooltipTarget
        RefreshTgtBtn()
    end)

    -- Threshold label + editbox
    local threshLbl = f:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    threshLbl:SetFont(threshLbl:GetFont(), 9, "")
    threshLbl:SetPoint("LEFT", tgtChk, "RIGHT", 8, 0)
    threshLbl:SetTextColor(0.6, 0.6, 0.6)
    threshLbl:SetText("Min %:")

    local threshBox = CreateFrame("EditBox", nil, f, "InputBoxTemplate")
    threshBox:SetSize(38, 18)
    threshBox:SetPoint("LEFT", threshLbl, "RIGHT", 4, 0)
    threshBox:SetAutoFocus(false)
    threshBox:SetFontObject("GameFontNormalSmall")
    threshBox:SetText(tostring(SAL.db.tooltipThreshold or 0))
    threshBox:SetScript("OnEnterPressed", function(self)
        local val = tonumber(self:GetText())
        if val then
            SAL.db.tooltipThreshold = math.max(0, math.min(100, val))
        end
        self:ClearFocus()
    end)
    threshBox:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)

    -- ---- Separator ----
    local sep1 = f:CreateTexture(nil, "ARTWORK")
    sep1:SetSize(PANEL_W - PAD * 2, 1)
    sep1:SetPoint("TOPLEFT", f, "TOPLEFT", PAD, settingsY - 22)
    sep1:SetColorTexture(0.25, 0.25, 0.3, 1)

    -- ---- Search box ----
    local searchLabel = f:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    searchLabel:SetFont(searchLabel:GetFont(), 10, "")
    searchLabel:SetPoint("TOPLEFT", f, "TOPLEFT", PAD, settingsY - 30)
    searchLabel:SetTextColor(0.7, 0.7, 0.7)
    searchLabel:SetText("Search item name or paste link:")

    local searchBox = CreateFrame("EditBox", "SALSearchBox", f, "InputBoxTemplate")
    searchBox:SetSize(PANEL_W - PAD * 2 - 70, 20)
    searchBox:SetPoint("TOPLEFT", f, "TOPLEFT", PAD, settingsY - 48)
    searchBox:SetAutoFocus(false)
    searchBox:SetFontObject("GameFontNormal")
    searchBox:SetScript("OnEnterPressed", function(self)
        currentResults = SAL_SearchItems(self:GetText())
        selectedIdx = nil
        resultOffset = 0
        RefreshResults()
        self:ClearFocus()
    end)
    searchBox:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)
    -- Accept item links
    searchBox:SetScript("OnReceiveDrag", function(self)
        local t, id, info = GetCursorInfo()
        if t == "item" then
            local _, link = GetItemInfo(id)
            if link then self:SetText(link) end
        end
        ClearCursor()
    end)

    local searchBtn = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
    searchBtn:SetSize(60, 20)
    searchBtn:SetPoint("LEFT", searchBox, "RIGHT", 6, 0)
    searchBtn:SetText("Search")
    searchBtn:SetScript("OnClick", function()
        currentResults = SAL_SearchItems(searchBox:GetText())
        selectedIdx = nil
        resultOffset = 0
        RefreshResults()
    end)

    -- result count label
    local resultCountLbl = f:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    resultCountLbl:SetFont(resultCountLbl:GetFont(), 9, "")
    resultCountLbl:SetPoint("TOPLEFT", searchBox, "BOTTOMLEFT", 0, -2)
    resultCountLbl:SetTextColor(0.5, 0.5, 0.5)
    resultCountLbl:SetText("Type a name and press Enter, or paste an item link.")
    SAL.resultCountLbl = resultCountLbl

    -- ---- Results list area ----
    local listTop = settingsY - 78
    local listH   = PANEL_H - (HDR_H + 80 + 55) -- dynamic, fills rest

    local listFrame = CreateFrame("Frame", nil, f)
    listFrame:SetPoint("TOPLEFT",  f, "TOPLEFT",  0,        listTop)
    listFrame:SetPoint("TOPRIGHT", f, "TOPRIGHT", 0,        listTop)
    listFrame:SetHeight(listH)
    FillBg(listFrame, 0.04, 0.04, 0.06, 1)

    -- Column headers
    local colHdr = CreateFrame("Frame", nil, f)
    colHdr:SetSize(PANEL_W, 16)
    colHdr:SetPoint("TOPLEFT", f, "TOPLEFT", 0, listTop)
    FillBg(colHdr, 0.1, 0.1, 0.14, 1)

    local hdrItem = colHdr:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    hdrItem:SetFont(hdrItem:GetFont(), 9, "OUTLINE")
    hdrItem:SetPoint("LEFT", colHdr, "LEFT", PAD + 10, 0)
    hdrItem:SetText("|cffaaaaaa ITEM NAME")

    local hdrBest = colHdr:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    hdrBest:SetFont(hdrBest:GetFont(), 9, "OUTLINE")
    hdrBest:SetPoint("RIGHT", colHdr, "RIGHT", -PAD - 100, 0)
    hdrBest:SetText("|cffaaaaaa BEST DROP")

    local hdrSrc = colHdr:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    hdrSrc:SetFont(hdrSrc:GetFont(), 9, "OUTLINE")
    hdrSrc:SetPoint("RIGHT", colHdr, "RIGHT", -PAD, 0)
    hdrSrc:SetText("|cffaaaaaa SOURCES")

    -- Pre-build result rows
    local visibleRows = math.floor(listH / ROW_H)
    for i = 1, visibleRows do
        local row = CreateFrame("Button", nil, listFrame)
        row:SetHeight(ROW_H)
        row:SetPoint("TOPLEFT",  listFrame, "TOPLEFT",  0, -(16 + (i - 1) * ROW_H))
        row:SetPoint("TOPRIGHT", listFrame, "TOPRIGHT", 0, -(16 + (i - 1) * ROW_H))
        row:Hide()

        local bg = row:CreateTexture(nil, "BACKGROUND")
        bg:SetAllPoints(row)
        bg:SetColorTexture(0, 0, 0, 0)
        row._bg = bg

        local nameTxt = row:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        nameTxt:SetFont(nameTxt:GetFont(), 10, "")
        nameTxt:SetPoint("LEFT", row, "LEFT", PAD + 10, 0)
        nameTxt:SetJustifyH("LEFT")
        nameTxt:SetWidth(PANEL_W - 220)
        row._nameTxt = nameTxt

        local bestTxt = row:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        bestTxt:SetFont(bestTxt:GetFont(), 10, "")
        bestTxt:SetPoint("RIGHT", row, "RIGHT", -PAD - 80, 0)
        bestTxt:SetJustifyH("RIGHT")
        row._bestTxt = bestTxt

        local srcTxt = row:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        srcTxt:SetFont(srcTxt:GetFont(), 10, "")
        srcTxt:SetPoint("RIGHT", row, "RIGHT", -PAD, 0)
        srcTxt:SetJustifyH("RIGHT")
        row._srcTxt = srcTxt

        -- Arrow indicator
        local arrow = row:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        arrow:SetFont(arrow:GetFont(), 10, "")
        arrow:SetPoint("LEFT", row, "LEFT", 2, 0)
        row._arrow = arrow

        row:SetScript("OnEnter", function(self)
            self._bg:SetColorTexture(0.15, 0.15, 0.2, 0.8)
        end)
        row:SetScript("OnLeave", function(self)
            local sel = (selectedIdx ~= nil and self._idx == selectedIdx)
            self._bg:SetColorTexture(sel and 0.1 or 0, sel and 0.1 or 0, sel and 0.15 or 0, sel and 0.9 or 0)
        end)
        row:SetScript("OnClick", function(self)
            if selectedIdx == self._idx then
                selectedIdx = nil
            else
                selectedIdx = self._idx
            end
            RefreshResults()
            RefreshSources()
        end)

        resultRows[i] = row
    end

    -- ---- Source sub-panel (expands below the results list) ----
    local srcPanel = CreateFrame("Frame", nil, f)
    srcPanel:SetPoint("TOPLEFT",  listFrame, "BOTTOMLEFT",  0, 0)
    srcPanel:SetPoint("TOPRIGHT", listFrame, "BOTTOMRIGHT", 0, 0)
    srcPanel:SetHeight(MAX_SRC * ROW_H + 22)
    FillBg(srcPanel, 0.03, 0.05, 0.07, 1)
    srcPanel:Hide()
    SAL.srcPanel = srcPanel

    local srcTitle = srcPanel:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    srcTitle:SetFont(srcTitle:GetFont(), 9, "OUTLINE")
    srcTitle:SetPoint("TOPLEFT", srcPanel, "TOPLEFT", PAD, -2)
    srcTitle:SetTextColor(0.5, 0.6, 0.8)
    srcTitle:SetText("DROP SOURCES")
    SAL.srcTitle = srcTitle

    -- Column headers for source panel
    local srcColItem = srcPanel:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    srcColItem:SetFont(srcColItem:GetFont(), 9, "OUTLINE")
    srcColItem:SetPoint("LEFT", srcPanel, "LEFT", PAD + 10, -2)
    srcColItem:SetTextColor(0.4, 0.4, 0.5)

    local srcColPct = srcPanel:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    srcColPct:SetFont(srcColPct:GetFont(), 9, "OUTLINE")
    srcColPct:SetPoint("RIGHT", srcPanel, "RIGHT", -PAD, -2)
    srcColPct:SetTextColor(0.4, 0.4, 0.5)
    srcColPct:SetText("DROP %")

    -- Pre-build source rows
    for i = 1, MAX_SRC do
        local srow = srcPanel:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        srow:SetFont(srow:GetFont(), 10, "")
        srow:SetPoint("TOPLEFT", srcPanel, "TOPLEFT", PAD + 10, -(16 + (i-1) * ROW_H))
        srow:SetJustifyH("LEFT")
        srow:SetWidth(PANEL_W - 120)
        srow:Hide()

        local spct = srcPanel:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        spct:SetFont(spct:GetFont(), 10, "")
        spct:SetPoint("TOPRIGHT", srcPanel, "TOPRIGHT", -PAD, -(16 + (i-1) * ROW_H))
        spct:SetJustifyH("RIGHT")
        spct:Hide()

        sourceRows[i] = { name = srow, pct = spct }
    end

    -- Scroll buttons
    local scrollUp = CreateFrame("Button", nil, listFrame, "UIPanelScrollUpButtonTemplate")
    scrollUp:SetPoint("TOPRIGHT", listFrame, "TOPRIGHT", -2, -18)
    scrollUp:SetScript("OnClick", function()
        if resultOffset > 0 then
            resultOffset = resultOffset - 1
            RefreshResults()
        end
    end)

    local scrollDown = CreateFrame("Button", nil, listFrame, "UIPanelScrollDownButtonTemplate")
    scrollDown:SetPoint("BOTTOMRIGHT", listFrame, "BOTTOMRIGHT", -2, 2)
    scrollDown:SetScript("OnClick", function()
        if resultOffset < math.max(0, #currentResults - visibleRows) then
            resultOffset = resultOffset + 1
            RefreshResults()
        end
    end)

    -- Mouse wheel scroll on list
    listFrame:EnableMouseWheel(true)
    listFrame:SetScript("OnMouseWheel", function(self, delta)
        if delta > 0 and resultOffset > 0 then
            resultOffset = resultOffset - 1
            RefreshResults()
        elseif delta < 0 and resultOffset < math.max(0, #currentResults - visibleRows) then
            resultOffset = resultOffset + 1
            RefreshResults()
        end
    end)

    -- ---- Footer bar ----
    local footer = CreateFrame("Frame", nil, f)
    footer:SetSize(PANEL_W, 22)
    footer:SetPoint("BOTTOM", f, "BOTTOM", 0, 0)
    FillBg(footer, 0.07, 0.07, 0.1, 1)

    local footerHint = footer:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    footerHint:SetFont(footerHint:GetFont(), 8, "")
    footerHint:SetPoint("LEFT", footer, "LEFT", PAD, 0)
    footerHint:SetTextColor(0.35, 0.35, 0.4)
    footerHint:SetText("/slyatlas  •  /slyatlas atlas (open AtlasLoot)  •  /slyatlas stats")

    SlyAtlasLootPanel = f

    -- Update stats label
    SAL_RefreshStatsLabel()

    -- Refresh functions defined below (need closure over local vars)
    RefreshResults = function()
        local n = #currentResults
        if n == 0 then
            for _, row in ipairs(resultRows) do row:Hide() end
            if SAL.resultCountLbl then
                if SAL_GetIndexCount() == 0 then
                    SAL.resultCountLbl:SetText(
                        "|cffff8800AtlasLoot data not yet loaded. Open AtlasLoot once to load data.|r")
                else
                    SAL.resultCountLbl:SetText("No items found. Try a different search.")
                end
            end
            SAL.srcPanel:Hide()
            return
        end
        SAL.resultCountLbl:SetText(string.format("%d result%s", n, n == 1 and "" or "s"))

        for i, row in ipairs(resultRows) do
            local idx = i + resultOffset
            local res = currentResults[idx]
            if res then
                row._idx = idx
                row._nameTxt:SetText(res.link ~= "" and res.link or res.name)
                local best = res.drops[1]
                if best then
                    row._bestTxt:SetText(string.format("|cffffd700%.2f%%|r", best.pct))
                else
                    row._bestTxt:SetText("")
                end
                row._srcTxt:SetText(string.format("|cff888888%d|r", #res.drops))
                local sel = (selectedIdx == idx)
                row._arrow:SetText(sel and "|cff88bbff▶|r" or "")
                row._bg:SetColorTexture(sel and 0.1 or 0, sel and 0.1 or 0,
                    sel and 0.15 or 0, sel and 0.9 or 0)
                row:Show()
            else
                row:Hide()
            end
        end
    end

    RefreshSources = function()
        if not selectedIdx then
            SAL.srcPanel:Hide()
            return
        end
        local res = currentResults[selectedIdx]
        if not res or not res.drops or #res.drops == 0 then
            SAL.srcPanel:Hide()
            return
        end

        SAL.srcTitle:SetText(string.format(
            "DROP SOURCES  —  |cffaaddff%s|r  (%d source%s)",
            res.name, #res.drops, #res.drops == 1 and "" or "s"))

        local shown = math.min(#res.drops, MAX_SRC)
        for i = 1, MAX_SRC do
            local srow = sourceRows[i]
            if i <= shown then
                local entry = res.drops[i]
                local npcName = SAL_GetNPCName(entry.npcID)
                -- Highlight if this is the current target
                local isTgt = SAL.targetNPC and (entry.npcID == SAL.targetNPC)
                if isTgt then
                    srow.name:SetText("|cff00ff88▶ " .. npcName .. "|r")
                else
                    srow.name:SetText("|cffdddddd" .. npcName .. "|r")
                end
                -- Color-code the drop %
                local pct = entry.pct
                local pr, pg, pb
                if pct >= 50 then     pr, pg, pb = 0.2, 1.0, 0.2   -- green
                elseif pct >= 20 then pr, pg, pb = 1.0, 0.85, 0.0  -- gold
                elseif pct >= 5  then pr, pg, pb = 1.0, 0.5,  0.1  -- orange
                else                 pr, pg, pb = 0.7, 0.7,  0.7   -- grey
                end
                srow.pct:SetText(string.format("|cff%02x%02x%02x%.2f%%|r",
                    pr * 255, pg * 255, pb * 255, pct))
                srow.name:Show()
                srow.pct:Show()
            else
                srow.name:Hide()
                srow.pct:Hide()
            end
        end

        SAL.srcPanel:SetHeight(shown * ROW_H + 22)
        SAL.srcPanel:Show()
    end
end

-- --------------------------------------------------------
-- Toggle panel
-- --------------------------------------------------------
function SAL_TogglePanel()
    if not SlyAtlasLootPanel then
        SAL_BuildPanel()
    end
    if SlyAtlasLootPanel:IsShown() then
        SlyAtlasLootPanel:Hide()
    else
        SAL_RefreshStatsLabel()
        SlyAtlasLootPanel:Show()
    end
end

-- --------------------------------------------------------
-- Update the stats label (called on open)
-- --------------------------------------------------------
function SAL_RefreshStatsLabel()
    if not SAL.statsLbl then return end
    local n = SAL_GetIndexCount()
    if n > 0 then
        SAL.statsLbl:SetText(string.format(
            "|cff44cc44AtlasLoot ready|r — |cffffd700%d|r items indexed" ..
            (SAL.targetNPC and (
                "  |cff888888•|r Target: |cff00ff88" .. SAL_GetNPCName(SAL.targetNPC) .. "|r"
            ) or ""), n))
    else
        SAL.statsLbl:SetText(
            "|cffff8800AtlasLoot data not indexed.|r Open AtlasLoot once to load it.")
    end
end
