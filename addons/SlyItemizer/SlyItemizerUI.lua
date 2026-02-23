-- SlyItemizerUI.lua
-- Tabbed panel: [Compare] [Enchants] [Gems]
-- Compare: side-by-side stat diff for any two item links
-- Enchants: per-slot recommendations vs what's currently equipped
-- Gems: gem color suggestions filtered by active spec role

local SI = SlyItemizer

local PANEL_W, PANEL_H = 520, 480
local COL_W  = 200
local ROW_H  = 18
local TAB_H  = 24

local function Clamp(v, lo, hi) return math.max(lo, math.min(hi, v)) end

local function ColorDelta(delta)
    if delta >  0.5  then return "|cff00ff60"
    elseif delta < -0.5 then return "|cffff4040"
    else return "|ffc0c0c0" end
end

-- ── Build ─────────────────────────────────────────────────────────────────────
function SI_BuildUI()
    if SlyItemizerPanel then SlyItemizerPanel:Show(); return end

    local f = CreateFrame("Frame", "SlyItemizerPanel", UIParent)
    f:SetSize(PANEL_W, PANEL_H)
    f:SetFrameStrata("HIGH")
    f:SetMovable(true); f:EnableMouse(true); f:RegisterForDrag("LeftButton")
    f:SetScript("OnDragStart", f.StartMoving)
    f:SetScript("OnDragStop", function(self)
        self:StopMovingOrSizing()
        local pt, _, _, x, y = self:GetPoint()
        SlyItemizerDB.position = { point = pt, x = x, y = y }
    end)
    f:SetBackdrop({
        bgFile   = "Interface\\DialogFrame\\UI-DialogBox-Background",
        edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
        tile = true, tileSize = 32, edgeSize = 16,
        insets = { left=4, right=4, top=4, bottom=4 },
    })

    -- Title + close
    local title = f:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    title:SetPoint("TOP", f, "TOP", 0, -10)
    title:SetText("|cffffff00Sly|r Itemizer")
    local close = CreateFrame("Button", nil, f, "UIPanelCloseButton")
    close:SetPoint("TOPRIGHT", f, "TOPRIGHT", 0, 0)
    close:SetScript("OnClick", function() f:Hide() end)

    -- Class / Spec selector row
    local clsLabel = f:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    clsLabel:SetPoint("TOPLEFT", f, "TOPLEFT", 14, -30)
    clsLabel:SetText("Spec:")
    local specBtns = {}
    local specList = { "dps", "tank", "heal", "balance" }
    for i, sp in ipairs(specList) do
        local btn = CreateFrame("Button", "SlyItmSpec_"..sp, f, "UIPanelButtonTemplate")
        btn:SetSize(56, 18)
        btn:SetPoint("TOPLEFT", f, "TOPLEFT", 44 + (i-1)*60, -28)
        btn:SetText(sp)
        btn:SetScript("OnClick", function()
            SlyItemizerDB.spec = sp
            SI_RefreshSpecBtns()
            SI_RefreshActiveTab()
        end)
        specBtns[sp] = btn
    end

    -- Tooltip delta toggle
    local deltaToggle = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
    deltaToggle:SetSize(100, 18)
    deltaToggle:SetPoint("TOPRIGHT", f, "TOPRIGHT", -30, -28)
    deltaToggle:SetScript("OnClick", function()
        SlyItemizerDB.showDelta = not SlyItemizerDB.showDelta
        deltaToggle:SetText((SlyItemizerDB.showDelta and "|cff00ff60" or "|cffff4040") .. "Tooltip Delta|r")
    end)

    -- ── Tab bar ───────────────────────────────────────────────────────────────
    local TABS = { "Compare", "Enchants", "Gems" }
    local activeTab = "Compare"
    local tabBtns = {}
    local tabContent = {}  -- { Compare=frame, Enchants=frame, Gems=frame }

    local tabYOffset = -52
    for i, name in ipairs(TABS) do
        local btn = CreateFrame("Button", "SlyItmTab_"..name, f, "TabButtonTemplate")
        btn:SetSize(PANEL_W / #TABS - 4, TAB_H)
        btn:SetPoint("TOPLEFT", f, "TOPLEFT", 6 + (i-1) * (PANEL_W / #TABS), tabYOffset)
        btn:SetText(name)
        btn.tabName = name
        btn:SetScript("OnClick", function(self)
            activeTab = self.tabName
            for _, tc in pairs(tabContent) do tc:Hide() end
            if tabContent[activeTab] then tabContent[activeTab]:Show() end
            SI_RefreshActiveTab()
            SI_RefreshTabBtns()
        end)
        tabBtns[name] = btn
    end

    -- Content area (below tabs)
    local contentY  = tabYOffset - TAB_H - 4
    local contentH  = PANEL_H + contentY - 14
    for _, name in ipairs(TABS) do
        local tc = CreateFrame("Frame", nil, f)
        tc:SetPoint("TOPLEFT",  f, "TOPLEFT",  8, contentY)
        tc:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", -8, 28)
        tc:Hide()
        tabContent[name] = tc
    end

    -- ── ─────────────────────────────────────────────────────────────────────
    -- TAB 1: COMPARE
    -- ── ─────────────────────────────────────────────────────────────────────
    local compareFrame = tabContent["Compare"]

    -- Left column = "Equipped / Item A"     Right column = "Comparison / Item B"
    local function MakeItemPanel(parent, anchorL, title_text, isRight)
        local col = CreateFrame("Frame", nil, parent)
        col:SetSize(COL_W, contentH - 60)
        if isRight then
            col:SetPoint("TOPLEFT", parent, "TOPLEFT", COL_W + 20, -5)
        else
            col:SetPoint("TOPLEFT", parent, "TOPLEFT", 0, -5)
        end

        local hdr = col:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        hdr:SetPoint("TOP", col, "TOP", 0, 0)
        hdr:SetText(title_text)

        local icon = col:CreateTexture(nil, "ARTWORK")
        icon:SetSize(28, 28)
        icon:SetPoint("TOPLEFT", col, "TOPLEFT", 0, -18)

        local nameFS = col:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        nameFS:SetPoint("LEFT", icon, "RIGHT", 4, 4)
        nameFS:SetSize(COL_W - 36, 14)
        nameFS:SetJustifyH("LEFT")
        nameFS:SetWordWrap(false)

        local ilFS = col:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        ilFS:SetPoint("LEFT", icon, "RIGHT", 4, -8)
        ilFS:SetTextColor(0.7, 0.7, 0.7)

        local scoreFS = col:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        scoreFS:SetPoint("TOPLEFT", col, "TOPLEFT", 0, -52)

        local sep = col:CreateTexture(nil, "ARTWORK")
        sep:SetSize(COL_W - 4, 1)
        sep:SetPoint("TOPLEFT", col, "TOPLEFT", 0, -64)
        sep:SetColorTexture(0.5, 0.5, 0.5, 0.4)

        -- Stat rows
        local statRows = {}
        for i = 1, 20 do
            local row = col:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
            row:SetPoint("TOPLEFT", col, "TOPLEFT", 4, -68 - (i-1)*ROW_H)
            row:SetSize(COL_W - 8, ROW_H)
            row:SetJustifyH("LEFT")
            row:Hide()
            statRows[i] = row
        end

        -- Paste input (right panel only — drag and drop item link here)
        local pasteBox
        if isRight then
            local pLabel = parent:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
            pLabel:SetPoint("BOTTOMLEFT", parent, "BOTTOMLEFT", COL_W + 20, 4)
            pLabel:SetText("Paste item link:")
            pasteBox = CreateFrame("EditBox", "SlyItmPasteBox", parent, "InputBoxTemplate")
            pasteBox:SetSize(COL_W - 80, 20)
            pasteBox:SetPoint("BOTTOMLEFT", parent, "BOTTOMLEFT", COL_W + 98, 2)
            pasteBox:SetAutoFocus(false)
            pasteBox:SetScript("OnEscapePressed", pasteBox.ClearFocus)
        end

        return { col=col, icon=icon, nameFS=nameFS, ilFS=ilFS, scoreFS=scoreFS, statRows=statRows, pasteBox=pasteBox }
    end

    local panelA = MakeItemPanel(compareFrame, 0,         "◀ Equipped",    false)
    local panelB = MakeItemPanel(compareFrame, COL_W + 20,"▶ New Item",    true)

    -- Center delta column
    local deltaHdr = compareFrame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    deltaHdr:SetPoint("TOP", compareFrame, "TOP", 0, -5)
    deltaHdr:SetText("Δ Delta")
    deltaHdr:SetTextColor(1, 0.8, 0)

    local deltaRows = {}
    for i = 1, 20 do
        local row = compareFrame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        row:SetPoint("TOP", compareFrame, "TOP", 0, -68 - (i-1)*ROW_H)
        row:SetSize(90, ROW_H)
        row:SetJustifyH("CENTER")
        row:Hide()
        deltaRows[i] = row
    end

    -- Total delta bar
    local totalDeltaFS = compareFrame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    totalDeltaFS:SetPoint("BOTTOM", compareFrame, "BOTTOM", 0, 6)
    totalDeltaFS:SetText("")

    -- Slot selector
    local slotLabel = compareFrame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    slotLabel:SetPoint("BOTTOMLEFT", compareFrame, "BOTTOMLEFT", 0, 6)
    slotLabel:SetText("Slot:")

    -- Populate panels given two stat tables + scores
    local cmpLinkA, cmpLinkB = nil, nil

    local function PopulatePanel(panel, itemLink, score, stats)
        if not itemLink then
            panel.nameFS:SetText("|cff888888(empty)|r")
            panel.ilFS:SetText("")
            panel.scoreFS:SetText("")
            panel.icon:SetTexture("Interface\\Icons\\INV_Misc_QuestionMark")
            for _, r in ipairs(panel.statRows) do r:Hide() end
            return
        end
        local name, _, quality, _, _, _, _, _, _, tex = GetItemInfo(itemLink)
        local qcol = IRR and IRR.QUALITY_COLORS and IRR.QUALITY_COLORS[quality or 1]
        local col = qcol and string.format("|cff%02x%02x%02x", qcol[1]*255, qcol[2]*255, qcol[3]*255) or "|r"
        panel.nameFS:SetText((col or "") .. (name or itemLink) .. "|r")
        panel.ilFS:SetText("iLvl " .. (stats and stats.ilevel or "?"))
        panel.scoreFS:SetText(string.format("|cffffff00Score: %.0f|r", score))
        if tex then panel.icon:SetTexture(tex) end

        -- List non-zero stats
        local i = 0
        for _, key in ipairs(SI.STAT_KEYS) do
            local v = stats and stats[key]
            if v and v ~= 0 then
                i = i + 1
                if panel.statRows[i] then
                    panel.statRows[i]:SetText((SI.STAT_LABELS[key] or key) .. ": " .. tostring(v))
                    panel.statRows[i]:Show()
                end
            end
        end
        for j = i+1, #panel.statRows do panel.statRows[j]:Hide() end
    end

    local function RefreshCompare()
        -- Slot: try to infer from paste box link or use first equipped
        local linkB = panelB.pasteBox and panelB.pasteBox:GetText() or ""
        linkB = linkB ~= "" and linkB or nil
        cmpLinkB = linkB

        local slotId = linkB and SI:ItemLinkToSlot(linkB)
        cmpLinkA = slotId and GetInventoryItemLink("player", slotId) or cmpLinkA

        local scoreA, statsA = 0, nil
        local scoreB, statsB = 0, nil

        if cmpLinkA then scoreA, statsA = SI:ScoreLink(cmpLinkA) end
        if cmpLinkB then scoreB, statsB = SI:ScoreLink(cmpLinkB) end

        PopulatePanel(panelA, cmpLinkA, scoreA, statsA)
        PopulatePanel(panelB, cmpLinkB, scoreB, statsB)

        -- Delta rows
        local i = 0
        for _, key in ipairs(SI.STAT_KEYS) do
            local vA = statsA and statsA[key] or 0
            local vB = statsB and statsB[key] or 0
            local d  = vB - vA
            if d ~= 0 then
                i = i + 1
                if deltaRows[i] then
                    local sign = d > 0 and "+" or ""
                    deltaRows[i]:SetText(ColorDelta(d) .. sign .. string.format("%.0f", d) .. "|r")
                    deltaRows[i]:Show()
                end
            end
        end
        for j = i+1, #deltaRows do deltaRows[j]:Hide() end

        local totalDelta = scoreB - scoreA
        if cmpLinkB and cmpLinkA then
            local sign = totalDelta > 0 and "+" or ""
            totalDeltaFS:SetText(ColorDelta(totalDelta) .. "Total: " .. sign .. string.format("%.0f", totalDelta) .. " pts|r")
        else
            totalDeltaFS:SetText("")
        end
    end

    if panelB.pasteBox then
        panelB.pasteBox:SetScript("OnTextChanged", function() RefreshCompare() end)
    end

    -- ── ─────────────────────────────────────────────────────────────────────
    -- TAB 2: ENCHANTS
    -- ── ─────────────────────────────────────────────────────────────────────
    local enchFrame = tabContent["Enchants"]

    local enchSlotNames = {
        [1]="Head", [3]="Shoulders", [5]="Chest", [9]="Wrists",
        [10]="Hands", [7]="Legs", [8]="Feet", [15]="Cloak",
        [16]="Main Hand", [17]="Off Hand", [18]="Ranged",
    }
    local enchSlotOrder = {1, 3, 5, 9, 10, 7, 8, 15, 16, 17, 18}

    -- Scroll frame for enchant table
    local enchSF = CreateFrame("ScrollFrame", nil, enchFrame, "UIPanelScrollFrameTemplate")
    enchSF:SetPoint("TOPLEFT",    enchFrame, "TOPLEFT",  0, -4)
    enchSF:SetPoint("BOTTOMRIGHT",enchFrame, "BOTTOMRIGHT", -16, 4)
    local enchContent = CreateFrame("Frame", nil, enchSF)
    enchContent:SetSize(PANEL_W - 40, 1)
    enchSF:SetScrollChild(enchContent)

    local enchRows = {}  -- list of FontStrings

    local function RefreshEnchants()
        local role = SlyItemizerDB and SlyItemizerDB.spec or "dps"
        -- wipe old rows
        for _, r in ipairs(enchRows) do r:Hide() end
        enchRows = {}

        local y = 0
        for _, slotId in ipairs(enchSlotOrder) do
            local suggs = SI:GetEnchantSuggestions(slotId, role)
            if #suggs > 0 then
                -- Slot header
                local hdr = enchContent:CreateFontString(nil, "OVERLAY", "GameFontNormal")
                hdr:SetPoint("TOPLEFT", enchContent, "TOPLEFT", 4, y)
                hdr:SetText("|cffffff00" .. (enchSlotNames[slotId] or ("Slot "..slotId)) .. "|r")
                hdr:Show()
                enchRows[#enchRows+1] = hdr
                y = y - 18

                -- Current enchant (if any)
                local current = SI:GetEquippedEnchantName(slotId)
                local curFs = enchContent:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
                curFs:SetPoint("TOPLEFT", enchContent, "TOPLEFT", 10, y)
                curFs:SetText("Equipped: " .. (current and ("|cff00ff96" .. current .. "|r") or "|cffff4040(none)|r"))
                curFs:Show()
                enchRows[#enchRows+1] = curFs
                y = y - ROW_H

                -- Suggestions
                for _, e in ipairs(suggs) do
                    local isEquipped = current and current:lower():find(e.name:lower():sub(1,12), 1, true)
                    local row = enchContent:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
                    row:SetPoint("TOPLEFT", enchContent, "TOPLEFT", 14, y)
                    row:SetSize(PANEL_W - 60, ROW_H)
                    local mark = isEquipped and "|cff00ff96✓ |r" or "   "
                    row:SetText(mark .. e.name .. "  |cff888888" .. e.effect .. "|r")
                    row:Show()
                    enchRows[#enchRows+1] = row
                    y = y - ROW_H
                end
                y = y - 6  -- gap between slots
            end
        end
        enchContent:SetHeight(math.abs(y) + 20)
    end

    -- ── ─────────────────────────────────────────────────────────────────────
    -- TAB 3: GEMS
    -- ── ─────────────────────────────────────────────────────────────────────
    local gemFrame = tabContent["Gems"]

    -- Color filter tabs
    local GEM_COLORS = { "meta", "red", "yellow", "blue", "orange", "green" }
    local GEM_COLOR_HEX = { meta="9d9d9d", red="ff4040", yellow="ffff00", blue="4080ff", orange="ff8000", green="40ff40" }
    local activeGemColor = "red"

    local gemColorBtns = {}
    for i, col in ipairs(GEM_COLORS) do
        local btn = CreateFrame("Button", "SlyItmGem_"..col, gemFrame, "UIPanelButtonTemplate")
        btn:SetSize(60, 20)
        btn:SetPoint("TOPLEFT", gemFrame, "TOPLEFT", 2 + (i-1)*64, -4)
        btn:SetText("|cff"..GEM_COLOR_HEX[col]..col:sub(1,1):upper()..col:sub(2).."|r")
        btn.gemColor = col
        btn:SetScript("OnClick", function(self)
            activeGemColor = self.gemColor
            RefreshGems()
            for _, b in pairs(gemColorBtns) do
                b:GetNormalTexture():SetVertexColor(1,1,1)
            end
            self:GetNormalTexture():SetVertexColor(0.3,1,0.3)
        end)
        gemColorBtns[col] = btn
    end

    -- Gem scroll
    local gemSF = CreateFrame("ScrollFrame", nil, gemFrame, "UIPanelScrollFrameTemplate")
    gemSF:SetPoint("TOPLEFT",    gemFrame, "TOPLEFT",  0, -28)
    gemSF:SetPoint("BOTTOMRIGHT",gemFrame, "BOTTOMRIGHT", -16, 4)
    local gemContent = CreateFrame("Frame", nil, gemSF)
    gemContent:SetSize(PANEL_W - 40, 1)
    gemSF:SetScrollChild(gemContent)

    local gemRows = {}

    function RefreshGems()
        for _, r in ipairs(gemRows) do r:Hide() end
        gemRows = {}

        local role = SlyItemizerDB and SlyItemizerDB.spec or "dps"
        local suggs = SI:GetGemSuggestions(activeGemColor, role)

        -- Also add "all" role if not redundant
        if role ~= "all" then
            for _, g in ipairs(SI.GEM_DB) do
                if g.color == activeGemColor and g.role == "all" then
                    suggs[#suggs+1] = g
                end
            end
        end

        local y = 0
        if #suggs == 0 then
            local none = gemContent:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
            none:SetPoint("TOPLEFT", gemContent, "TOPLEFT", 8, y)
            none:SetText("|cff888888No suggestions for this color + spec.|r")
            none:Show()
            gemRows[#gemRows+1] = none
            y = y - ROW_H
        else
            local hdr = gemContent:CreateFontString(nil, "OVERLAY", "GameFontNormal")
            hdr:SetPoint("TOPLEFT", gemContent, "TOPLEFT", 4, y)
            hdr:SetText("|cffffff00" .. (activeGemColor:sub(1,1):upper()..activeGemColor:sub(2)) .. " Gems  (" .. role .. ")|r  — best first")
            hdr:Show()
            gemRows[#gemRows+1] = hdr
            y = y - 20

            for _, g in ipairs(suggs) do
                local row = gemContent:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
                row:SetPoint("TOPLEFT", gemContent, "TOPLEFT", 14, y)
                row:SetSize(PANEL_W - 60, ROW_H)
                row:SetText("|cff" .. GEM_COLOR_HEX[g.color] .. g.name .. "|r  |cff888888" .. g.effect .. "|r")
                row:Show()
                gemRows[#gemRows+1] = row
                y = y - ROW_H
            end
        end
        gemContent:SetHeight(math.abs(y) + 20)
    end

    -- ── Shared refresh helpers ────────────────────────────────────────────────
    function SI_RefreshSpecBtns()
        for sp, btn in pairs(specBtns) do
            if SlyItemizerDB.spec == sp then
                btn:GetNormalTexture():SetVertexColor(0.3, 1, 0.3)
            else
                btn:GetNormalTexture():SetVertexColor(1, 1, 1)
            end
        end
        deltaToggle:SetText((SlyItemizerDB.showDelta and "|cff00ff60" or "|cffff4040") .. "Tooltip Delta|r")
    end

    function SI_RefreshTabBtns()
        for nm, btn in pairs(tabBtns) do
            if nm == activeTab then
                btn:GetNormalTexture():SetVertexColor(0.3, 1, 0.3)
            else
                btn:GetNormalTexture():SetVertexColor(1, 1, 1)
            end
        end
    end

    function SI_RefreshActiveTab()
        if activeTab == "Compare"  then RefreshCompare()  end
        if activeTab == "Enchants" then RefreshEnchants() end
        if activeTab == "Gems"     then RefreshGems()     end
    end

    -- Restore position + start on Compare
    local p = SlyItemizerDB and SlyItemizerDB.position or { point="CENTER", x=0, y=0 }
    f:ClearAllPoints(); f:SetPoint(p.point, UIParent, p.point, p.x, p.y)

    tabContent["Compare"]:Show()
    SI_RefreshSpecBtns()
    SI_RefreshTabBtns()
    RefreshCompare()
    f:Show()
end
