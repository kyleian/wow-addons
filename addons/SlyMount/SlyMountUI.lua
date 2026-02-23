-- SlyMountUI.lua
-- Panel for SlyMount: manage ground/flying favorites, random mount button.

local SM = SlyMount

local PANEL_W, PANEL_H = 300, 400
local ROW_H = 24
local MAX_VISIBLE = 10

-- ── Build ─────────────────────────────────────────────────────────────────────
function SM_BuildUI()
    if SlyMountPanel then SlyMountPanel:Show(); SM.uiRefresh(); return end

    local f = CreateFrame("Frame", "SlyMountPanel", UIParent)
    f:SetSize(PANEL_W, PANEL_H)
    f:SetFrameStrata("HIGH")
    f:SetMovable(true); f:EnableMouse(true); f:RegisterForDrag("LeftButton")
    f:SetScript("OnDragStart", f.StartMoving)
    f:SetScript("OnDragStop", function(self)
        self:StopMovingOrSizing()
        local pt, _, _, x, y = self:GetPoint()
        SlyMountDB.position = { point = pt, x = x, y = y }
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
    title:SetText("|cffa335eeSly|r Mount")
    local close = CreateFrame("Button", nil, f, "UIPanelCloseButton")
    close:SetPoint("TOPRIGHT", f, "TOPRIGHT", 0, 0)
    close:SetScript("OnClick", function() f:Hide() end)

    -- Zone indicator
    local zoneLabel = f:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    zoneLabel:SetPoint("TOPLEFT", f, "TOPLEFT", 12, -32)

    -- Big random button
    local randomBtn = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
    randomBtn:SetSize(130, 28)
    randomBtn:SetPoint("TOP", f, "TOP", 0, -48)
    randomBtn:SetText("▶ Random Mount")
    randomBtn:SetScript("OnClick", function() SM:RandomMount() end)

    -- Tab bar
    local tabs = {}
    local activeTab = "ground"
    local tabData  = { { id="ground", label="Ground" }, { id="flying", label="Flying" } }

    for i, td in ipairs(tabData) do
        local btn = CreateFrame("Button", "SlyMountTab_"..td.id, f, "TabButtonTemplate")
        btn:SetSize(90, 26)
        btn:SetPoint("TOPLEFT", f, "TOPLEFT", 10 + (i-1)*92, -82)
        btn:SetText(td.label)
        btn.tabId = td.id
        btn:SetScript("OnClick", function(self)
            activeTab = self.tabId
            SM.uiRefresh()
        end)
        tabs[td.id] = btn
    end

    -- List area
    local listFrame = CreateFrame("Frame", nil, f)
    listFrame:SetPoint("TOPLEFT", f, "TOPLEFT", 8, -112)
    listFrame:SetSize(PANEL_W - 16, MAX_VISIBLE * ROW_H)

    local rows = {}
    for i = 1, MAX_VISIBLE do
        local row = CreateFrame("Frame", nil, listFrame)
        row:SetSize(PANEL_W - 16, ROW_H)
        row:SetPoint("TOPLEFT", listFrame, "TOPLEFT", 0, -(i-1)*ROW_H)

        -- alternating bg
        local bg = row:CreateTexture(nil, "BACKGROUND")
        bg:SetAllPoints()
        if i % 2 == 0 then bg:SetColorTexture(0,0,0,0.1) else bg:SetColorTexture(0,0,0,0) end

        row.nameFS = row:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        row.nameFS:SetPoint("LEFT", row, "LEFT", 4, 0)
        row.nameFS:SetSize(160, ROW_H)
        row.nameFS:SetJustifyH("LEFT")

        row.castBtn = CreateFrame("Button", nil, row, "UIPanelButtonTemplate")
        row.castBtn:SetSize(46, 18)
        row.castBtn:SetPoint("RIGHT", row, "RIGHT", -52, 0)
        row.castBtn:SetText("Mount")

        row.rmBtn = CreateFrame("Button", nil, row, "UIPanelButtonTemplate")
        row.rmBtn:SetSize(44, 18)
        row.rmBtn:SetPoint("RIGHT", row, "RIGHT", -4, 0)
        row.rmBtn:SetText("Remove")
        row.rmBtn:GetNormalTexture():SetVertexColor(1, 0.4, 0.4)

        row:Hide()
        rows[i] = row
    end

    -- Prev/Next buttons
    local offset = 0
    local prevBtn = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
    prevBtn:SetSize(60, 20)
    prevBtn:SetPoint("TOPLEFT", f, "TOPLEFT", 10, -(116 + MAX_VISIBLE*ROW_H))
    prevBtn:SetText("◀ Prev")
    local nextBtn = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
    nextBtn:SetSize(60, 20)
    nextBtn:SetPoint("LEFT", prevBtn, "RIGHT", 4, 0)
    nextBtn:SetText("Next ▶")

    -- Separator
    local sep = f:CreateTexture(nil, "ARTWORK")
    sep:SetSize(PANEL_W - 24, 1)
    sep:SetPoint("TOPLEFT", f, "TOPLEFT", 12, -(120 + MAX_VISIBLE*ROW_H + 28))
    sep:SetColorTexture(0.4, 0.2, 0.7, 0.5)

    -- Add row
    local addLabel = f:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    addLabel:SetPoint("BOTTOMLEFT", f, "BOTTOMLEFT", 12, 40)
    addLabel:SetText("Spell name:")
    local addInput = CreateFrame("EditBox", "SlyMountAddInput", f, "InputBoxTemplate")
    addInput:SetSize(160, 20)
    addInput:SetPoint("BOTTOMLEFT", f, "BOTTOMLEFT", 82, 38)
    addInput:SetAutoFocus(false)
    addInput:SetScript("OnEscapePressed", addInput.ClearFocus)
    addInput:SetScript("OnEnterPressed", function(self)
        SM:AddMount(activeTab, self:GetText()); self:SetText(""); self:ClearFocus()
    end)
    local addBtn = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
    addBtn:SetSize(44, 20)
    addBtn:SetPoint("LEFT", addInput, "RIGHT", 4, 0)
    addBtn:SetText("Add")
    addBtn:SetScript("OnClick", function()
        SM:AddMount(activeTab, addInput:GetText()); addInput:SetText(""); addInput:ClearFocus()
    end)

    -- Hint
    local hint = f:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    hint:SetPoint("BOTTOM", f, "BOTTOM", 0, 8)
    hint:SetTextColor(0.5, 0.5, 0.5)
    hint:SetText("/slymount random  |  add ground|flying <Name>")

    -- Position restore
    local p = SlyMountDB.position or DB_DEFAULTS.position
    f:ClearAllPoints(); f:SetPoint(p.point, UIParent, p.point, p.x, p.y)
    f:Show()

    -- ── Refresh ──────────────────────────────────────────────────────────────
    function SM.uiRefresh()
        if not SlyMountPanel or not SlyMountPanel:IsShown() then return end

        -- Zone label
        local inOut = SM:InOutland()
        local zone  = GetRealZoneText() or "Unknown"
        if inOut then
            zoneLabel:SetText("|cff00ff96" .. zone .. " — Flying enabled|r")
        else
            zoneLabel:SetText("|cffaaaaaa" .. zone .. " — Ground only|r")
        end

        -- Tab highlight
        for id, btn in pairs(tabs) do
            if id == activeTab then
                btn:GetNormalTexture():SetVertexColor(0.4, 1, 0.4)
            else
                btn:GetNormalTexture():SetVertexColor(1, 1, 1)
            end
        end

        -- List
        local list = SlyMountDB[activeTab] or {}
        local total = #list
        offset = math.min(offset, math.max(0, total - MAX_VISIBLE))

        for i, row in ipairs(rows) do
            local idx  = offset + i
            local name = list[idx]
            if name then
                row.nameFS:SetText(name)
                row.castBtn:SetScript("OnClick", function() SM:CastMount(name) end)
                row.rmBtn:SetScript("OnClick",  function() SM:RemoveMount(activeTab, name) end)
                row:Show()
            else
                row:Hide()
            end
        end

        prevBtn:SetEnabled(offset > 0)
        nextBtn:SetEnabled((offset + MAX_VISIBLE) < total)
    end

    prevBtn:SetScript("OnClick", function() offset = math.max(0, offset - MAX_VISIBLE); SM.uiRefresh() end)
    nextBtn:SetScript("OnClick", function() offset = offset + MAX_VISIBLE; SM.uiRefresh() end)

    SM.uiRefresh()
end
