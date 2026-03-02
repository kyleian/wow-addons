-- SlyLootUI.lua
-- Panel for SlyLoot: tabbed [Rolls] / [Soft Res] interface.
-- Style: matches SlySuite dark theme (SlyChar style guide).

local SL = SlyLoot  -- alias to namespace set in SlyLoot.lua

-- ── Layout constants ─────────────────────────────────────────────────────────
local PANEL_W = 420
local PANEL_H = 520
local HDR_H   = 28
local TAB_H   = 24
local PAD     = 8
local ROW_H   = 20
local FOOT_H  = 36
local PW      = PANEL_W - PAD*2   -- usable inner width
local CONT_TOP = -(HDR_H + TAB_H + 2)
local CONT_H   = PANEL_H - HDR_H - TAB_H - 2 - FOOT_H

-- ── Helpers ──────────────────────────────────────────────────────────────────
local function FillBg(frame, r, g, b, a)
    local t = frame:CreateTexture(nil, "BACKGROUND")
    t:SetAllPoints(frame); t:SetColorTexture(r, g, b, a)
    return t
end

local function MakeDiv(parent, yOff)
    local d = parent:CreateTexture(nil, "ARTWORK")
    d:SetPoint("TOPLEFT",  parent, "TOPLEFT",  0, yOff)
    d:SetPoint("TOPRIGHT", parent, "TOPRIGHT", 0, yOff)
    d:SetHeight(1); d:SetColorTexture(0.20, 0.20, 0.27, 1)
    return d
end

local function MakeLabel(parent, size, r, g, b)
    local fs = parent:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    fs:SetFont(fs:GetFont(), size or 10, "")
    fs:SetTextColor(r or 1, g or 1, b or 1)
    return fs
end

local function CreateScrollBox(parent, x, y, w, h)
    local sf = CreateFrame("ScrollFrame", nil, parent, "UIPanelScrollFrameTemplate")
    sf:SetPoint("TOPLEFT", parent, "TOPLEFT", x, y)
    sf:SetSize(w - 18, h)
    local content = CreateFrame("Frame", nil, sf)
    content:SetSize(w - 18, 1)
    sf:SetScrollChild(content)
    return sf, content
end

-- ── Build UI ─────────────────────────────────────────────────────────────────
function SL_BuildUI()
    if not SlyLootDB then
        SlyLootDB = {}
        if SlyLoot and SlyLoot.Init then SlyLoot:Init() end
    end

    if SlyLootPanel then
        SlyLootPanel:Show()
        if SL.uiRefresh then SL.uiRefresh() end
        return
    end

    -- Main frame
    local f = CreateFrame("Frame", "SlyLootPanel", UIParent)
    f:SetSize(PANEL_W, PANEL_H)
    f:SetFrameStrata("DIALOG")
    f:SetMovable(true); f:EnableMouse(true); f:RegisterForDrag("LeftButton")
    f:SetScript("OnDragStart", f.StartMoving)
    f:SetScript("OnDragStop", function(self)
        self:StopMovingOrSizing()
        local pt, _, _, x, y = self:GetPoint()
        SlyLootDB.position = { point=pt, x=x, y=y }
    end)

    -- Background
    local bord = f:CreateTexture(nil, "OVERLAY")
    bord:SetAllPoints(f); bord:SetColorTexture(0.28, 0.28, 0.35, 1)
    FillBg(f, 0.05, 0.05, 0.07, 0.97)
    local inner = f:CreateTexture(nil, "BACKGROUND")
    inner:SetPoint("TOPLEFT",     f, "TOPLEFT",      1, -1)
    inner:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", -1,  1)
    inner:SetColorTexture(0.05, 0.05, 0.07, 0.97)

    -- Header bar
    local hdr = CreateFrame("Frame", nil, f)
    hdr:SetSize(PANEL_W, HDR_H)
    hdr:SetPoint("TOPLEFT", f, "TOPLEFT", 0, 0)
    FillBg(hdr, 0.09, 0.09, 0.14, 1)

    local titleTx = hdr:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    titleTx:SetFont(titleTx:GetFont(), 13, "OUTLINE")
    titleTx:SetPoint("LEFT", hdr, "LEFT", PAD, 0)
    titleTx:SetText("|cff00ccffSlyGargul|r")

    local closeBtn = CreateFrame("Button", nil, hdr, "UIPanelCloseButton")
    closeBtn:SetSize(24, 24)
    closeBtn:SetPoint("RIGHT", hdr, "RIGHT", -2, 0)
    closeBtn:SetScript("OnClick", function() f:Hide() end)

    local hdrSep = f:CreateTexture(nil, "ARTWORK")
    hdrSep:SetPoint("TOPLEFT",  f, "TOPLEFT",  0, -HDR_H)
    hdrSep:SetPoint("TOPRIGHT", f, "TOPRIGHT", 0, -HDR_H)
    hdrSep:SetHeight(1); hdrSep:SetColorTexture(0.25, 0.25, 0.32, 1)

    -- Tab strip
    local TABS    = { "Rolls", "Soft Res" }
    local tabBtns = {}
    local activeTab = "Rolls"

    local function HighlightTab(name)
        for _, t in ipairs(TABS) do
            local b = tabBtns[t]
            if t == name then
                b.bg:SetColorTexture(0.14, 0.30, 0.58, 1)
                b.tx:SetTextColor(1, 1, 1)
            else
                b.bg:SetColorTexture(0.07, 0.07, 0.10, 1)
                b.tx:SetTextColor(0.55, 0.55, 0.60)
            end
        end
    end

    local tw = math.floor(PANEL_W / #TABS)
    for i, t in ipairs(TABS) do
        local b = CreateFrame("Button", nil, f)
        b:SetSize(tw, TAB_H)
        b:SetPoint("TOPLEFT", f, "TOPLEFT", (i-1)*tw, -HDR_H - 1)
        b.bg = b:CreateTexture(nil, "BACKGROUND")
        b.bg:SetAllPoints(); b.bg:SetColorTexture(0.07, 0.07, 0.10, 1)
        local hl = b:CreateTexture(nil, "HIGHLIGHT")
        hl:SetAllPoints(); hl:SetColorTexture(0.3, 0.5, 0.9, 0.18)
        b.tx = b:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        b.tx:SetFont(b.tx:GetFont(), 11, "OUTLINE")
        b.tx:SetAllPoints(); b.tx:SetJustifyH("CENTER")
        b.tx:SetText(t)
        tabBtns[t] = b
        local tabName = t
        b:SetScript("OnClick", function()
            activeTab = tabName
            HighlightTab(activeTab)
            SL.uiRefresh()
        end)
    end

    local tabSep = f:CreateTexture(nil, "ARTWORK")
    tabSep:SetPoint("TOPLEFT",  f, "TOPLEFT",  0, CONT_TOP)
    tabSep:SetPoint("TOPRIGHT", f, "TOPRIGHT", 0, CONT_TOP)
    tabSep:SetHeight(1); tabSep:SetColorTexture(0.20, 0.20, 0.27, 1)

    -- ── ROLLS pane ────────────────────────────────────────────────────────────
    local rollsPane = CreateFrame("Frame", nil, f)
    rollsPane:SetPoint("TOPLEFT",     f, "TOPLEFT",      PAD, CONT_TOP - 1)
    rollsPane:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", -PAD, FOOT_H)

    -- Active-item bar (40px tall)
    local itemBar = CreateFrame("Frame", nil, rollsPane)
    itemBar:SetPoint("TOPLEFT",  rollsPane, "TOPLEFT",  0, 0)
    itemBar:SetPoint("TOPRIGHT", rollsPane, "TOPRIGHT", 0, 0)
    itemBar:SetHeight(40)
    FillBg(itemBar, 0, 0.12, 0.25, 0.80)

    local itemIcon = itemBar:CreateTexture(nil, "ARTWORK")
    itemIcon:SetSize(32, 32)
    itemIcon:SetPoint("LEFT", itemBar, "LEFT", 4, 0)

    local itemLabel = itemBar:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    itemLabel:SetFont(itemLabel:GetFont(), 11, "")
    itemLabel:SetPoint("TOPLEFT", itemIcon, "TOPRIGHT", 6, -5)
    itemLabel:SetText("No active roll session")

    local rollCount = itemBar:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    rollCount:SetFont(rollCount:GetFont(), 9, "")
    rollCount:SetPoint("BOTTOMLEFT", itemIcon, "BOTTOMRIGHT", 6, 4)
    rollCount:SetTextColor(0.6, 0.8, 1)
    rollCount:SetText("")

    MakeDiv(rollsPane, -42)

    -- Item input row (y = -50)
    local inputLbl = MakeLabel(rollsPane, 10, 0.7, 0.7, 0.7)
    inputLbl:SetPoint("TOPLEFT", rollsPane, "TOPLEFT", 0, -50)
    inputLbl:SetText("Item:")

    local itemInput = CreateFrame("EditBox", "SlyLootItemInput", rollsPane, "InputBoxTemplate")
    itemInput:SetSize(PW - 110, 20)
    itemInput:SetPoint("TOPLEFT", rollsPane, "TOPLEFT", 38, -48)
    itemInput:SetAutoFocus(false)
    itemInput:SetScript("OnEscapePressed", itemInput.ClearFocus)

    local startBtn = CreateFrame("Button", nil, rollsPane, "UIPanelButtonTemplate")
    startBtn:SetSize(66, 20)
    startBtn:SetPoint("LEFT", itemInput, "RIGHT", 4, 0)
    startBtn:SetText("Roll!")
    startBtn:SetScript("OnClick", function()
        local txt = itemInput:GetText()
        if txt and txt ~= "" then SL:StartRoll(nil, txt); itemInput:SetText("") end
    end)

    MakeDiv(rollsPane, -74)

    -- Roll list headers
    local hdrName = MakeLabel(rollsPane, 10, 0.65, 0.65, 0.65)
    hdrName:SetPoint("TOPLEFT",  rollsPane, "TOPLEFT",  4, -78)
    hdrName:SetText("Player")
    local hdrRoll = MakeLabel(rollsPane, 10, 0.65, 0.65, 0.65)
    hdrRoll:SetPoint("TOPRIGHT", rollsPane, "TOPRIGHT", -4, -78)
    hdrRoll:SetText("Roll")

    local rollListH = CONT_H - 42 - 36 - 20
    local rollSF, rollContent = CreateScrollBox(rollsPane, 0, -94, PW, rollListH)
    local rollRows = {}
    for i = 1, 20 do
        local row = CreateFrame("Frame", nil, rollContent)
        row:SetSize(PW - 18, ROW_H)
        row:SetPoint("TOPLEFT", rollContent, "TOPLEFT", 0, -(i-1)*ROW_H)
        if i % 2 == 0 then
            local rbg = row:CreateTexture(nil, "BACKGROUND")
            rbg:SetAllPoints(); rbg:SetColorTexture(1,1,1,0.03)
        end
        row.nameFS = row:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        row.nameFS:SetFont(row.nameFS:GetFont(), 10, "")
        row.nameFS:SetPoint("LEFT",  row, "LEFT",  4, 0)
        row.rollFS = row:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        row.rollFS:SetFont(row.rollFS:GetFont(), 10, "")
        row.rollFS:SetPoint("RIGHT", row, "RIGHT", -4, 0)
        row:Hide()
        rollRows[i] = row
    end


    -- -- SOFT RES pane ----------------------------------------------------------
    local srPane = CreateFrame("Frame", nil, f)
    srPane:SetPoint("TOPLEFT",     f, "TOPLEFT",      PAD, CONT_TOP - 1)
    srPane:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", -PAD, FOOT_H)

    -- Step labels
    local srStep1 = MakeLabel(srPane, 10, 1, 0.80, 0)
    srStep1:SetPoint("TOPLEFT", srPane, "TOPLEFT", 0, -6)
    srStep1:SetText("Step 1:")
    local srStep1Txt = MakeLabel(srPane, 10, 0.75, 0.85, 1)
    srStep1Txt:SetPoint("LEFT", srStep1, "RIGHT", 4, 0)
    srStep1Txt:SetText("softres.gg  →  your raid  →  Export  →  Copy CSV")

    local srStep2 = MakeLabel(srPane, 10, 1, 0.80, 0)
    srStep2:SetPoint("TOPLEFT", srPane, "TOPLEFT", 0, -24)
    srStep2:SetText("Step 2:")
    local srStep2Txt = MakeLabel(srPane, 10, 0.75, 0.85, 1)
    srStep2Txt:SetPoint("LEFT", srStep2, "RIGHT", 4, 0)
    srStep2Txt:SetText("Paste the CSV text below, then click Import.")

    MakeDiv(srPane, -42)

    -- Paste box (y = -48, height = 72)
    local srInput = CreateFrame("EditBox", "SlyLootSRInput", srPane, "InputBoxTemplate")
    srInput:SetSize(PW - 4, 72)
    srInput:SetPoint("TOPLEFT", srPane, "TOPLEFT", 0, -48)
    srInput:SetAutoFocus(false)
    srInput:SetMultiLine(true)
    srInput:SetMaxLetters(0)
    srInput:SetScript("OnEscapePressed", srInput.ClearFocus)

    -- Buttons (y = -126)
    local srImportBtn = CreateFrame("Button", nil, srPane, "UIPanelButtonTemplate")
    srImportBtn:SetSize(80, 22)
    srImportBtn:SetPoint("TOPLEFT", srPane, "TOPLEFT", 0, -126)
    srImportBtn:SetText("Import")
    srImportBtn:SetScript("OnClick", function()
        local txt = srInput:GetText()
        if txt and txt ~= "" then SL:ImportSR(txt); srInput:SetText("") end
    end)

    local srClearBtn = CreateFrame("Button", nil, srPane, "UIPanelButtonTemplate")
    srClearBtn:SetSize(66, 22)
    srClearBtn:SetPoint("LEFT", srImportBtn, "RIGHT", 6, 0)
    srClearBtn:SetText("Clear")
    srClearBtn:SetScript("OnClick", function() SL:ClearSR() end)

    local srCountFS = MakeLabel(srPane, 10, 0.6, 0.9, 0.5)
    srCountFS:SetPoint("LEFT", srClearBtn, "RIGHT", 10, 0)
    srCountFS:SetText("")

    MakeDiv(srPane, -154)

    -- SR list headers
    local srHdrItem = MakeLabel(srPane, 10, 0.65, 0.65, 0.65)
    srHdrItem:SetPoint("TOPLEFT",  srPane, "TOPLEFT",  4, -158)
    srHdrItem:SetText("Item")
    local srHdrPlayers = MakeLabel(srPane, 10, 0.65, 0.65, 0.65)
    srHdrPlayers:SetPoint("TOPRIGHT", srPane, "TOPRIGHT", -4, -158)
    srHdrPlayers:SetText("Players")

    -- SR scroll
    local srListH = CONT_H - 172
    local srSF, srContent = CreateScrollBox(srPane, 0, -172, PW, srListH)
    local srRows = {}
    for i = 1, 30 do
        local row = CreateFrame("Frame", nil, srContent)
        row:SetSize(PW - 18, ROW_H)
        row:SetPoint("TOPLEFT", srContent, "TOPLEFT", 0, -(i-1)*ROW_H)
        if i % 2 == 0 then
            local rbg = row:CreateTexture(nil, "BACKGROUND")
            rbg:SetAllPoints(); rbg:SetColorTexture(1,1,1,0.03)
        end
        row.itemFS = row:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        row.itemFS:SetFont(row.itemFS:GetFont(), 10, "")
        row.itemFS:SetPoint("LEFT", row, "LEFT", 4, 0)
        row.itemFS:SetWidth(math.floor((PW - 18) * 0.45))
        row.itemFS:SetJustifyH("LEFT")
        row.playersFS = row:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        row.playersFS:SetFont(row.playersFS:GetFont(), 10, "")
        row.playersFS:SetPoint("RIGHT", row, "RIGHT", -4, 0)
        row.playersFS:SetWidth(math.floor((PW - 18) * 0.53))
        row.playersFS:SetJustifyH("RIGHT")
        row:Hide()
        srRows[i] = row
    end

    -- -- Footer bar ------------------------------------------------------------
    local footSep = f:CreateTexture(nil, "ARTWORK")
    footSep:SetPoint("BOTTOMLEFT",  f, "BOTTOMLEFT",  0, FOOT_H)
    footSep:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", 0, FOOT_H)
    footSep:SetHeight(1); footSep:SetColorTexture(0.20, 0.20, 0.27, 1)
    local footBg = f:CreateTexture(nil, "BACKGROUND")
    footBg:SetPoint("BOTTOMLEFT",  f, "BOTTOMLEFT",  1, 1)
    footBg:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", -1, 1)
    footBg:SetHeight(FOOT_H - 2); footBg:SetColorTexture(0.09, 0.09, 0.14, 1)

    local endBtn = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
    endBtn:SetSize(112, 22)
    endBtn:SetPoint("BOTTOMLEFT", f, "BOTTOMLEFT", PAD, 7)
    endBtn:SetText("Declare Winner")
    endBtn:SetScript("OnClick", function() SL:EndRoll() end)

    local clearRollBtn = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
    clearRollBtn:SetSize(56, 22)
    clearRollBtn:SetPoint("LEFT", endBtn, "RIGHT", 4, 0)
    clearRollBtn:SetText("Clear")
    clearRollBtn:SetScript("OnClick", function() SL:ClearRoll() end)

    local channels = { "raid", "party", "say" }
    for i, ch in ipairs(channels) do
        local btn = CreateFrame("Button", "SlyLootCh_"..ch, f)
        btn:SetSize(44, 20)
        btn:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", -PAD - (3-i)*48, 7)
        btn.bg = btn:CreateTexture(nil, "BACKGROUND")
        btn.bg:SetAllPoints(); btn.bg:SetColorTexture(0.10, 0.10, 0.14, 1)
        local bhl = btn:CreateTexture(nil, "HIGHLIGHT")
        bhl:SetAllPoints(); bhl:SetColorTexture(1,1,1,0.12)
        btn.tx = btn:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        btn.tx:SetFont(btn.tx:GetFont(), 9, "OUTLINE")
        btn.tx:SetAllPoints(); btn.tx:SetJustifyH("CENTER")
        btn.tx:SetText(ch)
        btn:SetScript("OnClick", function()
            SlyLootDB.announceChannel = ch
            SL:RefreshChannelBtns()
        end)
    end

    -- Restore position
    local p = SlyLootDB.position or { point="CENTER", x=200, y=0 }
    f:ClearAllPoints()
    f:SetPoint(p.point, UIParent, p.point, p.x, p.y)
    f:Show()

    -- -- Refresh ---------------------------------------------------------------
    function SL.uiRefresh()
        if not SlyLootPanel or not SlyLootPanel:IsShown() then return end
        if activeTab == "Rolls" then
            rollsPane:Show(); srPane:Hide()
        else
            rollsPane:Hide(); srPane:Show()
        end
        HighlightTab(activeTab)

        if activeTab == "Rolls" then
            if SL.activeItem then
                itemLabel:SetText(SL.activeItem.name or SL.activeItem.link or "?")
                local n = 0; for _ in pairs(SL.rolls) do n = n + 1 end
                rollCount:SetText(n .. " roll" .. (n == 1 and "" or "s") .. " received")
                if SL.activeItem.icon then itemIcon:SetTexture(SL.activeItem.icon) end
            else
                itemLabel:SetText("No active roll session")
                rollCount:SetText(""); itemIcon:SetTexture(nil)
            end
            local sorted = {}
            for player, roll in pairs(SL.rolls) do
                sorted[#sorted+1] = { player=player, roll=roll }
            end
            table.sort(sorted, function(a, b) return a.roll > b.roll end)
            rollContent:SetHeight(math.max(#sorted * ROW_H, 1))
            for i, row in ipairs(rollRows) do
                local entry = sorted[i]
                if entry then
                    row.nameFS:SetText(entry.player)
                    row.rollFS:SetText(tostring(entry.roll))
                    local c = (i == 1) and {0.2,1,0.3} or {1,1,1}
                    row.nameFS:SetTextColor(c[1],c[2],c[3])
                    row.rollFS:SetTextColor(c[1],c[2],c[3])
                    row:Show()
                else row:Hide() end
            end
        end

        if activeTab == "Soft Res" then
            local items = SL.srItems or {}
            srCountFS:SetText(#items .. " item" .. (#items == 1 and "" or "s") .. " reserved")
            srContent:SetHeight(math.max(#items * ROW_H, 1))
            for i, row in ipairs(srRows) do
                local entry = items[i]
                if entry then
                    local displayName = entry.name
                    if entry.id and tonumber(entry.id) then
                        local n = GetItemInfo(entry.id)
                        if n then displayName = n; entry.name = n end
                    end
                    row.itemFS:SetText(displayName or "?")
                    row.playersFS:SetText(table.concat(entry.players or {}, ", "))
                    row:Show()
                else row:Hide() end
            end
        end

        SL:RefreshChannelBtns()
    end

    function SL:RefreshChannelBtns()
        for _, ch in ipairs(channels) do
            local btn = _G["SlyLootCh_"..ch]
            if btn then
                local active = (SlyLootDB.announceChannel == ch)
                btn.bg:SetColorTexture(
                    active and 0.14 or 0.10,
                    active and 0.30 or 0.10,
                    active and 0.58 or 0.14, 1)
                btn.tx:SetTextColor(
                    active and 1 or 0.55,
                    active and 1 or 0.55,
                    active and 1 or 0.60)
            end
        end
    end

    SL.srRefresh = function()
        activeTab = "Soft Res"
        SL.uiRefresh()
    end

    HighlightTab(activeTab)
    SL.uiRefresh()
end

-- -- Global helper: open panel on Soft Res tab ---------------------------------
function SL_OpenSRTab()
    local ok, err = pcall(SL_BuildUI)
    if not ok then
        DEFAULT_CHAT_FRAME:AddMessage("|cffff4444[SlyLoot]|r UI error: " .. tostring(err))
        if SS_LogError then SS_LogError("SlyLoot:SL_BuildUI", err) end
        return
    end
    C_Timer.After(0, function()
        if SlyLootPanel and SlyLootPanel:IsShown() and SL.srRefresh then
            SL.srRefresh()
        end
    end)
end
