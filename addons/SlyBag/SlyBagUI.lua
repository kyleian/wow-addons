-- ============================================================
-- SlyBagUI.lua  —  Merged bag window UI
-- ============================================================

local SLOT_SIZE   = 36
local SLOT_PAD    = 4
local CELL        = SLOT_SIZE + SLOT_PAD      -- 40 px per grid cell
local COLS        = 10
local SIDE_PAD    = 8
local SCROLLBAR_W = 16
local FRAME_W     = COLS * CELL + SIDE_PAD * 2 + SCROLLBAR_W  -- 424
local GRID_VIEW_H = 420
local HEADER_H    = 28
local SEARCH_H    = 28
local FOOTER_H    = 22
local FRAME_H     = HEADER_H + SEARCH_H + GRID_VIEW_H + FOOTER_H + 12

local QUAL_COLORS = {
    [0] = { 0.62, 0.62, 0.62 },   -- Poor
    [1] = { 1.00, 1.00, 1.00 },   -- Common
    [2] = { 0.12, 1.00, 0.00 },   -- Uncommon
    [3] = { 0.00, 0.44, 0.87 },   -- Rare
    [4] = { 0.64, 0.21, 0.93 },   -- Epic
    [5] = { 1.00, 0.50, 0.00 },   -- Legendary
    [6] = { 0.90, 0.80, 0.50 },   -- Artifact
}

local slotBtns  = {}   -- reusable button pool
local MAX_SLOTS = 180  -- safety cap
local searchText = ""

-- -------------------------------------------------------
-- NewSlotButton  —  create one reusable item slot button
-- -------------------------------------------------------
local function NewSlotButton(parent, idx)
    local b = CreateFrame("Button", "SlyBagSlot" .. idx, parent)
    b:SetSize(SLOT_SIZE, SLOT_SIZE)

    -- Slot background
    local bg = b:CreateTexture(nil, "BACKGROUND")
    bg:SetAllPoints()
    bg:SetTexture(0.10, 0.10, 0.13, 1)
    b.bg = bg

    -- Item icon (inset 2 px so border shows)
    local icon = b:CreateTexture(nil, "ARTWORK")
    icon:SetPoint("TOPLEFT",     b, "TOPLEFT",     2, -2)
    icon:SetPoint("BOTTOMRIGHT", b, "BOTTOMRIGHT", -2,  2)
    b.icon = icon

    -- Stack count
    local cnt = b:CreateFontString(nil, "OVERLAY", "NumberFontNormal")
    cnt:SetPoint("BOTTOMRIGHT", b, "BOTTOMRIGHT", -2, 2)
    b.count = cnt

    -- Hover highlight
    local hl = b:CreateTexture(nil, "HIGHLIGHT")
    hl:SetAllPoints()
    hl:SetTexture("Interface\\Buttons\\ButtonHilight-Square")
    hl:SetBlendMode("ADD")

    -- Quality border (coloured 1-px frame using the action-button glow texture)
    local qb = b:CreateTexture(nil, "OVERLAY")
    qb:SetPoint("TOPLEFT",     b, "TOPLEFT",     0,  0)
    qb:SetPoint("BOTTOMRIGHT", b, "BOTTOMRIGHT", 0,  0)
    qb:SetTexture("Interface\\Buttons\\UI-ActionButton-Border")
    qb:SetBlendMode("ADD")
    qb:SetAlpha(0.7)
    qb:Hide()
    b.qborder = qb

    b:RegisterForClicks("LeftButtonUp", "RightButtonUp")

    b:SetScript("OnEnter", function(self)
        if self.bag ~= nil then
            GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
            GameTooltip:SetBagItem(self.bag, self.slot)
            GameTooltip:Show()
        end
    end)
    b:SetScript("OnLeave", GameTooltip_Hide or function() GameTooltip:Hide() end)

    b:SetScript("OnClick", function(self, btn)
        if self.bag == nil then return end
        if btn == "LeftButton" then
            PickupContainerItem(self.bag, self.slot)
        elseif btn == "RightButton" then
            UseContainerItem(self.bag, self.slot)
        end
        C_Timer.After(0.05, SlyBag_Refresh)
    end)

    b:Hide()
    return b
end

-- -------------------------------------------------------
-- SlyBag_Refresh  —  collect bag data and re-draw grid
-- -------------------------------------------------------
function SlyBag_Refresh()
    if not SlyBagFrame then return end

    -- 1. Collect all slots across bags 0-4
    local items = {}
    local total, used = 0, 0

    for bag = 0, 4 do
        local n = GetContainerNumSlots(bag)
        for slot = 1, n do
            total = total + 1
            local texture, count, _, quality, _, _, link = GetContainerItemInfo(bag, slot)
            local itemName = ""
            if link then
                itemName = (GetItemInfo(link)) or ""
                used = used + 1
            end
            table.insert(items, {
                bag     = bag,
                slot    = slot,
                empty   = not texture,
                texture = texture or "Interface\\Buttons\\UI-EmptySlot-Disabled",
                count   = count or 0,
                quality = quality or -1,
                name    = itemName,
            })
        end
    end

    -- 2. Filter by search text
    local filtered = {}
    local filter = searchText:lower()
    for _, it in ipairs(items) do
        if filter == "" or it.name:lower():find(filter, 1, true) then
            table.insert(filtered, it)
        end
    end

    -- 3. Resize scroll content to fit rows
    local rows = math.ceil(math.max(1, #filtered) / COLS)
    local contentH = math.max(GRID_VIEW_H, rows * CELL + SLOT_PAD)
    SlyBagContent:SetHeight(contentH)

    -- 4. Position and populate buttons
    for i, it in ipairs(filtered) do
        local b = slotBtns[i]
        if not b then
            b = NewSlotButton(SlyBagContent, i)
            slotBtns[i] = b
        end
        local row = math.floor((i - 1) / COLS)
        local col = (i - 1) % COLS
        b:ClearAllPoints()
        b:SetPoint("TOPLEFT", SlyBagContent, "TOPLEFT",
            SIDE_PAD + col * CELL,
            -(SLOT_PAD + row * CELL))
        b.bag  = it.bag
        b.slot = it.slot

        if it.empty then
            b.icon:SetTexture("Interface\\Buttons\\UI-EmptySlot-Disabled")
            b.icon:SetAlpha(0.35)
            b.count:SetText("")
            b.qborder:Hide()
        else
            b.icon:SetTexture(it.texture)
            b.icon:SetAlpha(1)
            b.count:SetText(it.count > 1 and it.count or "")
            local qc = QUAL_COLORS[it.quality]
            if qc then
                b.qborder:SetVertexColor(qc[1], qc[2], qc[3])
                b.qborder:Show()
            else
                b.qborder:Hide()
            end
        end
        b:Show()
    end

    -- 5. Hide excess buttons
    for i = #filtered + 1, #slotBtns do
        slotBtns[i]:Hide()
    end

    -- 6. Update footer counters
    local gold = GetMoney()
    local g = math.floor(gold / 10000)
    local s = math.floor((gold % 10000) / 100)
    local c = gold % 100
    SlyBagGoldText:SetFormattedText(
        "|cffffcc00%d|rg |cffc0c0c0%d|rs |cffcc7700%d|rc", g, s, c)
    SlyBagSlotText:SetText(used .. "/" .. total .. " slots used")
end

-- -------------------------------------------------------
-- SlyBag_BuildUI  —  construct the frame (called once)
-- -------------------------------------------------------
function SlyBag_BuildUI()
    if SlyBagFrame then return end

    local db = SlyBag.db
    local f = CreateFrame("Frame", "SlyBagFrame", UIParent)
    f:SetSize(FRAME_W, FRAME_H)
    f:SetPoint(db.position.point, UIParent, db.position.point,
               db.position.x, db.position.y)
    f:EnableMouse(true)
    f:SetMovable(true)
    f:RegisterForDrag("LeftButton")
    f:SetScript("OnDragStart", f.StartMoving)
    f:SetScript("OnDragStop", function(self)
        self:StopMovingOrSizing()
        local p, _, _, x, y = self:GetPoint()
        SlyBag.db.position = { point = p, x = x, y = y }
    end)
    f:SetBackdrop({
        bgFile   = "Interface\\DialogFrame\\UI-DialogBox-Background",
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        tile = true, tileSize = 16, edgeSize = 12,
        insets = { left = 3, right = 3, top = 3, bottom = 3 },
    })
    f:SetBackdropColor(0.07, 0.07, 0.10, 0.96)
    f:SetBackdropBorderColor(0.30, 0.30, 0.40, 1)

    f:Hide()

    -- ---- Header ----
    local title = f:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    title:SetPoint("TOPLEFT", f, "TOPLEFT", SIDE_PAD + 2, -8)
    title:SetText("|cff00ccffSly|r Bag")

    local closeBtn = CreateFrame("Button", nil, f, "UIPanelCloseButton")
    closeBtn:SetPoint("TOPRIGHT", f, "TOPRIGHT", 2, 2)
    closeBtn:SetScript("OnClick", function() f:Hide() end)

    -- ---- Search bar ----
    local sbarBg = f:CreateTexture(nil, "ARTWORK")
    sbarBg:SetPoint("TOPLEFT",  f, "TOPLEFT",  SIDE_PAD,     -(HEADER_H + 4))
    sbarBg:SetPoint("TOPRIGHT", f, "TOPRIGHT", -SIDE_PAD,    -(HEADER_H + 4))
    sbarBg:SetHeight(SEARCH_H - 4)
    sbarBg:SetTexture(0.15, 0.15, 0.19, 1)

    local sbox = CreateFrame("EditBox", "SlyBagSearch", f)
    sbox:SetPoint("TOPLEFT",  f, "TOPLEFT",  SIDE_PAD + 6, -(HEADER_H + 6))
    sbox:SetPoint("TOPRIGHT", f, "TOPRIGHT", -(SIDE_PAD + 6), -(HEADER_H + 6))
    sbox:SetHeight(SEARCH_H - 8)
    sbox:SetFontObject("ChatFontNormal")
    sbox:SetAutoFocus(false)
    sbox:SetMaxLetters(64)

    local hint = sbox:CreateFontString(nil, "OVERLAY", "GameFontDisable")
    hint:SetPoint("LEFT", sbox, "LEFT", 0, 0)
    hint:SetText("Search items...")
    sbox:SetScript("OnTextChanged", function(self)
        local txt = self:GetText()
        hint:SetShown(txt == "")
        searchText = txt
        SlyBag_Refresh()
    end)
    sbox:SetScript("OnEscapePressed", function(self)
        self:SetText("") ; self:ClearFocus()
    end)

    -- Clear search button
    local clearBtn = CreateFrame("Button", nil, f)
    clearBtn:SetSize(16, 16)
    clearBtn:SetPoint("RIGHT", sbarBg, "RIGHT", -4, 0)
    local clrTex = clearBtn:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    clrTex:SetText("×")
    clrTex:SetPoint("CENTER")
    clrTex:SetTextColor(0.6, 0.6, 0.7)
    clearBtn:SetScript("OnClick", function() sbox:SetText("") end)

    -- ---- Scroll frame ----
    local sf = CreateFrame("ScrollFrame", "SlyBagScroll", f)
    sf:SetPoint("TOPLEFT",     f, "TOPLEFT",     SIDE_PAD, -(HEADER_H + SEARCH_H + 4))
    sf:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", -SIDE_PAD, FOOTER_H + 6)
    sf:EnableMouseWheel(true)
    sf:SetClipsChildren(true)
    sf:SetScript("OnMouseWheel", function(self, delta)
        local cur = self:GetVerticalScroll()
        local max = self:GetVerticalScrollRange()
        self:SetVerticalScroll(math.max(0, math.min(max, cur - delta * CELL)))
    end)

    local content = CreateFrame("Frame", "SlyBagContent", sf)
    content:SetWidth(FRAME_W - SIDE_PAD * 2)
    content:SetHeight(GRID_VIEW_H)
    sf:SetScrollChild(content)

    -- ---- Footer ----
    local footLine = f:CreateTexture(nil, "ARTWORK")
    footLine:SetPoint("BOTTOMLEFT",  f, "BOTTOMLEFT",  SIDE_PAD, FOOTER_H + 4)
    footLine:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", -SIDE_PAD, FOOTER_H + 4)
    footLine:SetHeight(1)
    footLine:SetTexture(0.3, 0.3, 0.4, 0.5)

    local goldTx = f:CreateFontString("SlyBagGoldText", "OVERLAY", "GameFontNormalSmall")
    goldTx:SetPoint("BOTTOMLEFT", f, "BOTTOMLEFT", SIDE_PAD + 2, 6)

    local slotTx = f:CreateFontString("SlyBagSlotText", "OVERLAY", "GameFontNormalSmall")
    slotTx:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", -(SIDE_PAD + 2), 6)
    slotTx:SetTextColor(0.55, 0.55, 0.62)

    f:SetScript("OnShow", SlyBag_Refresh)
end
