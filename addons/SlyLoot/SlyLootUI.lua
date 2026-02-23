-- SlyLootUI.lua
-- Panel for SlyLoot: shows roll session, roll list, winners.

local SL = SlyLoot  -- alias to namespace set in SlyLoot.lua

local PANEL_W, PANEL_H = 340, 420
local ROW_H = 20

-- ── Scroll helpers ────────────────────────────────────────────────────────────
local function CreateScrollBox(parent, x, y, w, h)
    local sf = CreateFrame("ScrollFrame", nil, parent, "UIPanelScrollFrameTemplate")
    sf:SetPoint("TOPLEFT", parent, "TOPLEFT", x, y)
    sf:SetSize(w - 16, h)
    local content = CreateFrame("Frame", nil, sf)
    content:SetSize(w - 16, 1)
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

    -- Title
    local title = f:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    title:SetPoint("TOP", f, "TOP", 0, -10)
    title:SetText("|cff00ccffSly|r Loot")
    local close = CreateFrame("Button", nil, f, "UIPanelCloseButton")
    close:SetPoint("TOPRIGHT", f, "TOPRIGHT", 0, 0)
    close:SetScript("OnClick", function() f:Hide() end)

    -- Current item bar
    local itemBg = CreateFrame("Frame", nil, f)
    itemBg:SetPoint("TOPLEFT", f, "TOPLEFT", 8, -34)
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

    -- Manual item input row
    local inputLabel = f:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    inputLabel:SetPoint("TOPLEFT", f, "TOPLEFT", 12, -80)
    inputLabel:SetText("Item:")

    local itemInput = CreateFrame("EditBox", "SlyLootItemInput", f, "InputBoxTemplate")
    itemInput:SetSize(PANEL_W - 100, 20)
    itemInput:SetPoint("TOPLEFT", f, "TOPLEFT", 48, -78)
    itemInput:SetAutoFocus(false)
    itemInput:SetScript("OnEscapePressed", itemInput.ClearFocus)

    local startBtn = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
    startBtn:SetSize(44, 20)
    startBtn:SetPoint("LEFT", itemInput, "RIGHT", 4, 0)
    startBtn:SetText("Roll!")
    startBtn:SetScript("OnClick", function()
        local txt = itemInput:GetText()
        if txt and txt ~= "" then SL:StartRoll(nil, txt); itemInput:SetText("") end
    end)

    -- Separator
    local sep1 = f:CreateTexture(nil, "ARTWORK")
    sep1:SetSize(PANEL_W - 24, 1)
    sep1:SetPoint("TOPLEFT", f, "TOPLEFT", 12, -104)
    sep1:SetColorTexture(0.3, 0.5, 0.7, 0.5)

    -- Roll list header
    local hdrName = f:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    hdrName:SetPoint("TOPLEFT", f, "TOPLEFT", 16, -112)
    hdrName:SetText("|cffffffffPlayer|r")
    local hdrRoll = f:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    hdrRoll:SetPoint("TOPRIGHT", f, "TOPRIGHT", -48, -112)
    hdrRoll:SetText("|cffffffffRoll|r")

    -- Roll list scroll
    local rollSF, rollContent = CreateScrollBox(f, 8, -128, PANEL_W - 8, 160)
    local rollRows = {}
    for i = 1, 15 do
        local row     = CreateFrame("Frame", nil, rollContent)
        row:SetSize(PANEL_W - 32, ROW_H)
        row:SetPoint("TOPLEFT", rollContent, "TOPLEFT", 0, -(i-1)*ROW_H)
        row.nameFS  = row:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        row.nameFS:SetPoint("LEFT", row, "LEFT", 4, 0)
        row.rollFS  = row:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        row.rollFS:SetPoint("RIGHT", row, "RIGHT", -4, 0)
        row:Hide()
        rollRows[i] = row
    end

    -- Action buttons
    local endBtn = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
    endBtn:SetSize(110, 24)
    endBtn:SetPoint("BOTTOMLEFT", f, "BOTTOMLEFT", 10, 36)
    endBtn:SetText("Declare Winner")
    endBtn:SetScript("OnClick", function() SL:EndRoll() end)

    local clearBtn = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
    clearBtn:SetSize(80, 24)
    clearBtn:SetPoint("LEFT", endBtn, "RIGHT", 6, 0)
    clearBtn:SetText("Clear")
    clearBtn:SetScript("OnClick", function() SL:ClearRoll() end)

    -- Channel & quality selectors (bottom bar)
    local chLabel = f:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    chLabel:SetPoint("BOTTOMLEFT", f, "BOTTOMLEFT", 12, 14)
    chLabel:SetText("Channel:")
    local channels = { "raid", "party", "say" }
    for i, ch in ipairs(channels) do
        local btn = CreateFrame("Button", "SlyLootCh_"..ch, f, "UIPanelButtonTemplate")
        btn:SetSize(44, 16)
        btn:SetPoint("BOTTOMLEFT", f, "BOTTOMLEFT", 60 + (i-1)*48, 12)
        btn:SetText(ch)
        btn:SetScript("OnClick", function()
            SlyLootDB.announceChannel = ch
            SL:RefreshChannelBtns()
        end)
    end

    local qlLabel = f:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    qlLabel:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", -82, 14)
    qlLabel:SetText("Min:")
    local qlBtn = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
    qlBtn:SetSize(70, 16)
    qlBtn:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", -8, 12)
    qlBtn:SetScript("OnClick", function()
        SlyLootDB.minQuality = (SlyLootDB.minQuality + 1) % 6
        SL.uiRefresh()
    end)

    -- Restore position
    local p = SlyLootDB.position or DB_DEFAULTS.position
    f:ClearAllPoints(); f:SetPoint(p.point, UIParent, p.point, p.x, p.y)
    f:Show()

    -- ── Refresh ──────────────────────────────────────────────────────────────
    function SL.uiRefresh()
        if not SlyLootPanel or not SlyLootPanel:IsShown() then return end

        -- Item bar
        if SL.activeItem then
            itemLabel:SetText(SL.activeItem.name or SL.activeItem.link)
            local n = 0; for _ in pairs(SL.rolls) do n = n + 1 end
            rollCount:SetText(n .. " roll" .. (n == 1 and "" or "s") .. " received")
            if SL.activeItem.icon then itemIcon:SetTexture(SL.activeItem.icon) end
        else
            itemLabel:SetText("No active roll session")
            rollCount:SetText("")
            itemIcon:SetTexture(nil)
        end

        -- Roll list - sort descending
        local sorted = {}
        for player, roll in pairs(SL.rolls) do sorted[#sorted+1] = { player=player, roll=roll } end
        table.sort(sorted, function(a, b) return a.roll > b.roll end)

        rollContent:SetHeight(math.max(#sorted * ROW_H, 1))
        for i, row in ipairs(rollRows) do
            local entry = sorted[i]
            if entry then
                row.nameFS:SetText(entry.player)
                row.rollFS:SetText(tostring(entry.roll))
                if i == 1 then
                    row.nameFS:SetTextColor(0.2, 1, 0.3)
                    row.rollFS:SetTextColor(0.2, 1, 0.3)
                else
                    row.nameFS:SetTextColor(1, 1, 1)
                    row.rollFS:SetTextColor(1, 1, 1)
                end
                row:Show()
            else
                row:Hide()
            end
        end

        -- Quality button label
        local col = SL.QUALITY_COLORS[SlyLootDB.minQuality] or ""
        qlBtn:SetText(col .. (SL.QUALITY_NAMES[SlyLootDB.minQuality] or "?") .. "|r+")

        -- Channel buttons highlight
        SL:RefreshChannelBtns()
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

    SL.uiRefresh()
end
