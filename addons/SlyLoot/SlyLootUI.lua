-- SlyLootUI.lua
-- Panel for SlyLoot: tabbed [Rolls] / [Soft Res] interface.
-- Soft Res supports paste-import of softres.it CSV exports.

local SL = SlyLoot  -- alias to namespace set in SlyLoot.lua

local PANEL_W, PANEL_H = 360, 460
local ROW_H = 20
local TAB_H = 26

-- ── Scroll helpers ────────────────────────────────────────────────────────────
local function CreateScrollBox(parent, x, y, w, h)
    local sf = CreateFrame("ScrollFrame", nil, parent, "UIPanelScrollFrameTemplate")
    sf:SetPoint("TOPLEFT", parent, "TOPLEFT", x, y)
    sf:SetSize(w - 18, h)
    local content = CreateFrame("Frame", nil, sf)
    content:SetSize(w - 18, 1)
    sf:SetScrollChild(content)
    return sf, content
end

-- ── Build UI ──────────────────────────────────────────────────────────────────
function SL_BuildUI()
    if SlyLootPanel then SlyLootPanel:Show(); SL.uiRefresh(); return end

    local f = CreateFrame("Frame", "SlyLootPanel", UIParent)
    f:SetSize(PANEL_W, PANEL_H)
    f:SetFrameStrata("HIGH")
    f:SetMovable(true); f:EnableMouse(true); f:RegisterForDrag("LeftButton")
    f:SetScript("OnDragStart", f.StartMoving)
    f:SetScript("OnDragStop", function(self)
        self:StopMovingOrSizing()
        local pt, _, _, x, y = self:GetPoint()
        SlyLootDB.position = { point = pt, x = x, y = y }
    end)
    f:SetBackdrop({
        bgFile   = "Interface\\DialogFrame\\UI-DialogBox-Background",
        edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
        tile = true, tileSize = 32, edgeSize = 16,
        insets = { left=4, right=4, top=4, bottom=4 },
    })

    -- Title bar
    local title = f:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    title:SetPoint("TOP", f, "TOP", 0, -10)
    title:SetText("|cff00ccffSlyGargul|r")
    local close = CreateFrame("Button", nil, f, "UIPanelCloseButton")
    close:SetPoint("TOPRIGHT", f, "TOPRIGHT", 0, 0)
    close:SetScript("OnClick", function() f:Hide() end)

    -- ── Tab buttons ──────────────────────────────────────────────────────────
    local TABS = { "Rolls", "Soft Res" }
    local tabBtns = {}
    local activeTab = "Rolls"

    local function SwitchTab(name)
        activeTab = name
        for _, t in ipairs(TABS) do
            local btn = tabBtns[t]
            if t == name then
                btn:GetNormalTexture():SetVertexColor(0.3, 1, 0.3)
            else
                btn:GetNormalTexture():SetVertexColor(1, 1, 1)
            end
        end
        SL.uiRefresh()
    end

    local tabW = math.floor((PANEL_W - 16) / #TABS)
    for i, t in ipairs(TABS) do
        local btn = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
        btn:SetSize(tabW, TAB_H)
        btn:SetPoint("TOPLEFT", f, "TOPLEFT", 8 + (i-1)*tabW, -30)
        btn:SetText(t)
        btn:SetScript("OnClick", function() SwitchTab(t) end)
        tabBtns[t] = btn
    end

    -- ── ROLLS tab content ─────────────────────────────────────────────────────
    local rollsPane = CreateFrame("Frame", nil, f)
    rollsPane:SetPoint("TOPLEFT", f, "TOPLEFT", 8, -(30 + TAB_H + 4))
    rollsPane:SetSize(PANEL_W - 16, PANEL_H - (30 + TAB_H + 4) - 38)

    -- Current item bar
    local itemBg = CreateFrame("Frame", nil, rollsPane)
    itemBg:SetPoint("TOPLEFT", rollsPane, "TOPLEFT", 0, 0)
    itemBg:SetSize(PANEL_W - 16, 40)
    itemBg:SetBackdrop({ bgFile="Interface\\Buttons\\WHITE8x8", edgeFile="", tileSize=8, tile=true, edgeSize=0, insets={left=0,right=0,top=0,bottom=0} })
    itemBg:SetBackdropColor(0, 0.12, 0.25, 0.8)

    local itemIcon = itemBg:CreateTexture(nil, "ARTWORK")
    itemIcon:SetSize(32, 32)
    itemIcon:SetPoint("LEFT", itemBg, "LEFT", 4, 0)

    local itemLabel = itemBg:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    itemLabel:SetPoint("LEFT", itemIcon, "RIGHT", 6, 4)
    itemLabel:SetText("No active roll")

    local rollCount = itemBg:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    rollCount:SetPoint("LEFT", itemIcon, "RIGHT", 6, -8)
    rollCount:SetTextColor(0.6, 0.8, 1)
    rollCount:SetText("")

    -- Manual item input
    local inputLabel = rollsPane:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    inputLabel:SetPoint("TOPLEFT", rollsPane, "TOPLEFT", 0, -46)
    inputLabel:SetText("Item:")

    local itemInput = CreateFrame("EditBox", "SlyLootItemInput", rollsPane, "InputBoxTemplate")
    itemInput:SetSize(PANEL_W - 116, 20)
    itemInput:SetPoint("TOPLEFT", rollsPane, "TOPLEFT", 36, -44)
    itemInput:SetAutoFocus(false)
    itemInput:SetScript("OnEscapePressed", itemInput.ClearFocus)

    local startBtn = CreateFrame("Button", nil, rollsPane, "UIPanelButtonTemplate")
    startBtn:SetSize(60, 20)
    startBtn:SetPoint("LEFT", itemInput, "RIGHT", 4, 0)
    startBtn:SetText("Roll!")
    startBtn:SetScript("OnClick", function()
        local txt = itemInput:GetText()
        if txt and txt ~= "" then SL:StartRoll(nil, txt); itemInput:SetText("") end
    end)

    -- Roll list header
    local hdrName = rollsPane:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    hdrName:SetPoint("TOPLEFT", rollsPane, "TOPLEFT", 4, -72)
    hdrName:SetText("|cffffffffPlayer|r")
    local hdrRoll = rollsPane:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    hdrRoll:SetPoint("TOPRIGHT", rollsPane, "TOPRIGHT", -4, -72)
    hdrRoll:SetText("|cffffffffRoll|r")

    local rollContentH = rollsPane:GetHeight() - 80
    local rollSF, rollContent = CreateScrollBox(rollsPane, 0, -88, PANEL_W - 16, rollContentH - 2)
    local rollRows = {}
    for i = 1, 20 do
        local row = CreateFrame("Frame", nil, rollContent)
        row:SetSize(PANEL_W - 36, ROW_H)
        row:SetPoint("TOPLEFT", rollContent, "TOPLEFT", 0, -(i-1)*ROW_H)
        row.nameFS = row:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        row.nameFS:SetPoint("LEFT", row, "LEFT", 4, 0)
        row.rollFS = row:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        row.rollFS:SetPoint("RIGHT", row, "RIGHT", -4, 0)
        row:Hide()
        rollRows[i] = row
    end

    -- ── SOFT RES tab content ──────────────────────────────────────────────────
    local srPane = CreateFrame("Frame", nil, f)
    srPane:SetPoint("TOPLEFT", f, "TOPLEFT", 8, -(30 + TAB_H + 4))
    srPane:SetSize(PANEL_W - 16, PANEL_H - (30 + TAB_H + 4) - 38)

    local srHint = srPane:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    srHint:SetPoint("TOPLEFT", srPane, "TOPLEFT", 2, -2)
    srHint:SetWidth(PANEL_W - 20)
    srHint:SetJustifyH("LEFT")
    srHint:SetTextColor(0.7, 0.9, 1)
    srHint:SetText("Paste softres.it CSV export below (Name, ItemId/Name, …):")

    local srInput = CreateFrame("EditBox", "SlyLootSRInput", srPane, "InputBoxTemplate")
    srInput:SetSize(PANEL_W - 20, 60)
    srInput:SetPoint("TOPLEFT", srPane, "TOPLEFT", 0, -18)
    srInput:SetAutoFocus(false)
    srInput:SetMultiLine(true)
    srInput:SetMaxLetters(0)
    srInput:SetScript("OnEscapePressed", srInput.ClearFocus)

    local srImportBtn = CreateFrame("Button", nil, srPane, "UIPanelButtonTemplate")
    srImportBtn:SetSize(80, 22)
    srImportBtn:SetPoint("TOPLEFT", srPane, "TOPLEFT", 0, -84)
    srImportBtn:SetText("Import")
    srImportBtn:SetScript("OnClick", function()
        local txt = srInput:GetText()
        if txt and txt ~= "" then
            SL:ImportSR(txt)
            srInput:SetText("")
        end
    end)

    local srClearBtn = CreateFrame("Button", nil, srPane, "UIPanelButtonTemplate")
    srClearBtn:SetSize(60, 22)
    srClearBtn:SetPoint("LEFT", srImportBtn, "RIGHT", 6, 0)
    srClearBtn:SetText("Clear")
    srClearBtn:SetScript("OnClick", function() SL:ClearSR() end)

    local srCountFS = srPane:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    srCountFS:SetPoint("LEFT", srClearBtn, "RIGHT", 8, 0)
    srCountFS:SetTextColor(0.7, 0.9, 0.5)
    srCountFS:SetText("")

    -- SR item list header
    local srHdrItem = srPane:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    srHdrItem:SetPoint("TOPLEFT", srPane, "TOPLEFT", 4, -112)
    srHdrItem:SetText("|cffffffffItem|r")
    local srHdrPlayers = srPane:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    srHdrPlayers:SetPoint("TOPRIGHT", srPane, "TOPRIGHT", -4, -112)
    srHdrPlayers:SetText("|cffffffffPlayers|r")

    local srListH = srPane:GetHeight() - 120
    local srSF, srContent = CreateScrollBox(srPane, 0, -128, PANEL_W - 16, srListH - 2)
    local srRows = {}
    for i = 1, 30 do
        local row = CreateFrame("Frame", nil, srContent)
        row:SetSize(PANEL_W - 36, ROW_H)
        row:SetPoint("TOPLEFT", srContent, "TOPLEFT", 0, -(i-1)*ROW_H)
        row.itemFS    = row:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        row.itemFS:SetPoint("LEFT", row, "LEFT", 4, 0)
        row.itemFS:SetWidth(math.floor((PANEL_W - 36) * 0.44))
        row.itemFS:SetJustifyH("LEFT")
        row.playersFS = row:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        row.playersFS:SetPoint("RIGHT", row, "RIGHT", -4, 0)
        row.playersFS:SetWidth(math.floor((PANEL_W - 36) * 0.54))
        row.playersFS:SetJustifyH("RIGHT")
        row:Hide()
        srRows[i] = row
    end

    -- ── Bottom bar (shared) ───────────────────────────────────────────────────
    local endBtn = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
    endBtn:SetSize(110, 24)
    endBtn:SetPoint("BOTTOMLEFT", f, "BOTTOMLEFT", 10, 10)
    endBtn:SetText("Declare Winner")
    endBtn:SetScript("OnClick", function() SL:EndRoll() end)

    local clearRollBtn = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
    clearRollBtn:SetSize(60, 24)
    clearRollBtn:SetPoint("LEFT", endBtn, "RIGHT", 4, 0)
    clearRollBtn:SetText("Clear")
    clearRollBtn:SetScript("OnClick", function() SL:ClearRoll() end)

    local channels = { "raid", "party", "say" }
    for i, ch in ipairs(channels) do
        local btn = CreateFrame("Button", "SlyLootCh_"..ch, f, "UIPanelButtonTemplate")
        btn:SetSize(44, 22)
        btn:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", -8 - (3 - i) * 48, 10)
        btn:SetText(ch)
        btn:SetScript("OnClick", function()
            SlyLootDB.announceChannel = ch
            SL:RefreshChannelBtns()
        end)
    end

    -- Restore position
    local p = SlyLootDB.position or { point="CENTER", x=200, y=0 }
    f:ClearAllPoints(); f:SetPoint(p.point, UIParent, p.point, p.x, p.y)
    f:Show()

    -- ── Refresh ───────────────────────────────────────────────────────────────
    function SL.uiRefresh()
        if not SlyLootPanel or not SlyLootPanel:IsShown() then return end

        -- show correct pane
        if activeTab == "Rolls" then
            rollsPane:Show(); srPane:Hide()
        else
            rollsPane:Hide(); srPane:Show()
        end

        -- Rolls pane refresh
        if activeTab == "Rolls" then
            if SL.activeItem then
                itemLabel:SetText(SL.activeItem.name or SL.activeItem.link)
                local n = 0; for _ in pairs(SL.rolls) do n = n + 1 end
                rollCount:SetText(n .. " roll" .. (n == 1 and "" or "s") .. " received")
                if SL.activeItem.icon then itemIcon:SetTexture(SL.activeItem.icon) end
            else
                itemLabel:SetText("No active roll session")
                rollCount:SetText(""); itemIcon:SetTexture(nil)
            end
            local sorted = {}
            for player, roll in pairs(SL.rolls) do sorted[#sorted+1] = { player=player, roll=roll } end
            table.sort(sorted, function(a, b) return a.roll > b.roll end)
            rollContent:SetHeight(math.max(#sorted * ROW_H, 1))
            for i, row in ipairs(rollRows) do
                local entry = sorted[i]
                if entry then
                    row.nameFS:SetText(entry.player)
                    row.rollFS:SetText(tostring(entry.roll))
                    local c = (i == 1) and {0.2,1,0.3} or {1,1,1}
                    row.nameFS:SetTextColor(c[1],c[2],c[3]); row.rollFS:SetTextColor(c[1],c[2],c[3])
                    row:Show()
                else row:Hide() end
            end
        end

        -- SR pane refresh
        if activeTab == "Soft Res" then
            local items = SL.srItems or {}
            srCountFS:SetText(#items .. " item" .. (#items == 1 and "" or "s") .. " reserved")
            srContent:SetHeight(math.max(#items * ROW_H, 1))
            for i, row in ipairs(srRows) do
                local entry = items[i]
                if entry then
                    -- try to resolve numeric IDs to item names
                    local displayName = entry.name
                    if entry.id and tonumber(entry.id) then
                        local n = GetItemInfo(entry.id)
                        if n then displayName = n ; entry.name = n end
                    end
                    row.itemFS:SetText(displayName)
                    row.playersFS:SetText(table.concat(entry.players or {}, ", "))
                    row:Show()
                else row:Hide() end
            end
        end

        SL:RefreshChannelBtns()
        -- highlight active tab
        SwitchTab(activeTab)
    end

    function SL:RefreshChannelBtns()
        for _, ch in ipairs(channels) do
            local btn = _G["SlyLootCh_"..ch]
            if btn then
                if SlyLootDB.announceChannel == ch then
                    btn:GetNormalTexture():SetVertexColor(0.3, 1, 0.3)
                else
                    btn:GetNormalTexture():SetVertexColor(1, 1, 1)
                end
            end
        end
    end

    -- set srRefresh callback used by SL:ImportSR / SL:ClearSR
    SL.srRefresh = function()
        if activeTab ~= "Soft Res" then activeTab = "Soft Res" end
        SL.uiRefresh()
    end

    SwitchTab("Rolls")
    SL.uiRefresh()
end

-- ── Global helper: open panel on Soft Res tab ─────────────────────────────────
function SL_OpenSRTab()
    SL_BuildUI()
    -- after build the panel exists; switch to SR tab via a deferred call
    C_Timer.After(0, function()
        if SlyLootPanel and SlyLootPanel:IsShown() and SL.srRefresh then
            SL.srRefresh()
        end
    end)
end
