-- ============================================================
-- SlyBagUI.lua  â€”  Merged bag window with IRR set sections
-- Items are grouped by gear set (ItemRackRevived / IRR.db.sets).
-- Items not in any set appear under "Other".
-- ============================================================

local SLOT_SIZE   = 36
local SLOT_PAD    = 4
local CELL        = SLOT_SIZE + SLOT_PAD   -- 40
local COLS        = 10
local SIDE_PAD    = 8
local SECTION_H   = 20
local FRAME_W     = COLS * CELL + SIDE_PAD * 2   -- 408
local GRID_VIEW_H = 420
local HEADER_H    = 28
local SEARCH_H    = 28
local FOOTER_H    = 22
local FRAME_H     = HEADER_H + SEARCH_H + GRID_VIEW_H + FOOTER_H + 12

local QUAL_COLORS = {
    [0] = { 0.62, 0.62, 0.62 },
    [1] = { 1.00, 1.00, 1.00 },
    [2] = { 0.12, 1.00, 0.00 },
    [3] = { 0.00, 0.44, 0.87 },
    [4] = { 0.64, 0.21, 0.93 },
    [5] = { 1.00, 0.50, 0.00 },
    [6] = { 0.90, 0.80, 0.50 },
}

-- Tint colours that cycle across set section headers
local SECTION_TINTS = {
    { 0.18, 0.10, 0.28 },
    { 0.08, 0.18, 0.10 },
    { 0.08, 0.14, 0.26 },
    { 0.24, 0.13, 0.07 },
    { 0.22, 0.08, 0.12 },
    { 0.08, 0.20, 0.22 },
}

local slotBtns    = {}
local sectionHdrs = {}
local searchText  = ""

-- â”€â”€ C_Container shims â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
local _NumSlots, _ItemLink, _ItemInfo, _UseItem, _PickupItem
if C_Container then
    _NumSlots   = C_Container.GetContainerNumSlots
    _ItemLink   = C_Container.GetContainerItemLink
    _ItemInfo   = function(bag, slot)
        local info = C_Container.GetContainerItemInfo(bag, slot)
        if not info then return nil end
        return info.iconFileID, info.stackCount, info.isLocked, info.quality
    end
    _UseItem    = C_Container.UseContainerItem
    _PickupItem = C_Container.PickupContainerItem
else
    _NumSlots   = GetContainerNumSlots
    _ItemLink   = GetContainerItemLink
    _ItemInfo   = function(bag, slot)
        local tex, cnt, locked, qual = GetContainerItemInfo(bag, slot)
        return tex, cnt, locked, qual
    end
    _UseItem    = UseContainerItem
    _PickupItem = PickupContainerItem
end

-- â”€â”€ IRR set helpers â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
local function GetSetNames()
    if not IRR or not IRR.db or not IRR.db.sets then return {} end
    local names = {}
    for name in pairs(IRR.db.sets) do names[#names + 1] = name end
    table.sort(names)
    return names
end

local function BuildSetMap()
    local map = {}
    if not IRR or not IRR.db or not IRR.db.sets then return map end
    for setName, setData in pairs(IRR.db.sets) do
        for _, itemId in pairs(setData) do
            if not map[itemId] then map[itemId] = {} end
            local dup = false
            for _, n in ipairs(map[itemId]) do
                if n == setName then dup = true; break end
            end
            if not dup then map[itemId][#map[itemId] + 1] = setName end
        end
    end
    for _, list in pairs(map) do table.sort(list) end
    return map
end

local function ItemIdFromLink(link)
    if not link then return nil end
    return tonumber(link:match("|Hitem:(%d+):"))
end

-- â”€â”€ Widget constructors â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
local function NewSlotButton(parent, idx)
    local b = CreateFrame("Button", "SlyBagSlot" .. idx, parent)
    b:SetSize(SLOT_SIZE, SLOT_SIZE)

    local bg = b:CreateTexture(nil, "BACKGROUND")
    bg:SetAllPoints()
    bg:SetColorTexture(0.10, 0.10, 0.13, 1)
    b.bg = bg

    local icon = b:CreateTexture(nil, "ARTWORK")
    icon:SetPoint("TOPLEFT",     b, "TOPLEFT",     2, -2)
    icon:SetPoint("BOTTOMRIGHT", b, "BOTTOMRIGHT", -2,  2)
    b.icon = icon

    local cnt = b:CreateFontString(nil, "OVERLAY", "NumberFontNormal")
    cnt:SetPoint("BOTTOMRIGHT", b, "BOTTOMRIGHT", -2, 2)
    b.count = cnt

    local hl = b:CreateTexture(nil, "HIGHLIGHT")
    hl:SetAllPoints()
    hl:SetTexture("Interface\\Buttons\\ButtonHilight-Square")
    hl:SetBlendMode("ADD")

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
    b:SetScript("OnLeave", function() GameTooltip:Hide() end)

    b:SetScript("OnClick", function(self, btn)
        if self.bag == nil then return end
        if btn == "LeftButton" then
            _PickupItem(self.bag, self.slot)
        elseif btn == "RightButton" then
            _UseItem(self.bag, self.slot)
        end
        C_Timer.After(0.05, SlyBag_Refresh)
    end)

    b:Hide()
    return b
end

local function NewSectionHeader(parent, idx)
    local f = CreateFrame("Frame", "SlyBagSection" .. idx, parent)
    f:SetHeight(SECTION_H)

    local bg = f:CreateTexture(nil, "BACKGROUND")
    bg:SetAllPoints()
    f.bg = bg

    local accent = f:CreateTexture(nil, "ARTWORK")
    accent:SetSize(2, SECTION_H)
    accent:SetPoint("LEFT", f, "LEFT", 0, 0)
    f.accent = accent

    local ico = f:CreateTexture(nil, "ARTWORK")
    ico:SetSize(SECTION_H - 4, SECTION_H - 4)
    ico:SetPoint("LEFT", f, "LEFT", SIDE_PAD, 0)
    f.ico = ico

    local lbl = f:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    lbl:SetPoint("LEFT", f, "LEFT", SIDE_PAD + SECTION_H, 0)
    lbl:SetJustifyH("LEFT")
    f.lbl = lbl

    local cntLbl = f:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    cntLbl:SetPoint("RIGHT", f, "RIGHT", -SIDE_PAD, 0)
    cntLbl:SetJustifyH("RIGHT")
    cntLbl:SetTextColor(0.50, 0.50, 0.60)
    f.cntLbl = cntLbl

    f:Hide()
    return f
end

-- â”€â”€ SlyBag_Refresh â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
function SlyBag_Refresh()
    if not SlyBagFrame then return end

    local setMap   = BuildSetMap()
    local setNames = GetSetNames()
    local filter   = searchText:lower()

    -- Collect all slots
    local items = {}
    local total, used = 0, 0
    for bag = 0, 4 do
        local n = _NumSlots(bag) or 0
        for slot = 1, n do
            total = total + 1
            local link   = _ItemLink(bag, slot)
            local tex, stackCnt, _, quality = _ItemInfo(bag, slot)
            local itemId   = ItemIdFromLink(link)
            local itemName = ""
            if link then
                itemName = GetItemInfo(link) or ""
                used = used + 1
            end
            items[#items + 1] = {
                bag     = bag,
                slot    = slot,
                empty   = not tex,
                texture = tex or "Interface\\Buttons\\UI-EmptySlot-Disabled",
                count   = stackCnt or 0,
                quality = quality or -1,
                name    = itemName,
                sets    = itemId and setMap[itemId] or nil,
            }
        end
    end

    -- Filter
    local function passes(it)
        if it.empty then return filter == "" end
        return filter == "" or it.name:lower():find(filter, 1, true)
    end

    -- Bucket by primary set
    local buckets   = {}
    local bucketIdx = {}
    for _, name in ipairs(setNames) do
        local b = { name = name, items = {} }
        buckets[#buckets + 1] = b
        bucketIdx[name] = b
    end
    local otherBucket = { name = "Other", items = {} }
    buckets[#buckets + 1] = otherBucket

    for _, it in ipairs(items) do
        if passes(it) then
            local placed = false
            if it.sets and #it.sets > 0 then
                local b = bucketIdx[it.sets[1]]
                if b then b.items[#b.items + 1] = it; placed = true end
            end
            if not placed then
                otherBucket.items[#otherBucket.items + 1] = it
            end
        end
    end

    -- Only show non-empty buckets
    local visible = {}
    for _, b in ipairs(buckets) do
        if #b.items > 0 then visible[#visible + 1] = b end
    end

    -- Build virtual row list
    local rows = {}
    local tintI = 0
    local multiSection = #visible > 1

    for _, b in ipairs(visible) do
        tintI = tintI + 1
        local ci = ((tintI - 1) % #SECTION_TINTS) + 1
        if multiSection or b.name ~= "Other" then
            rows[#rows + 1] = { type = "header", bucket = b, tintIdx = ci }
        end
        for i = 1, #b.items, COLS do
            local row = { type = "items", slots = {} }
            for j = i, math.min(i + COLS - 1, #b.items) do
                row.slots[#row.slots + 1] = b.items[j]
            end
            rows[#rows + 1] = row
        end
    end

    -- Resize content
    local contentH = SLOT_PAD
    for _, row in ipairs(rows) do
        contentH = contentH + (row.type == "header" and (SECTION_H + 2) or CELL)
    end
    contentH = math.max(GRID_VIEW_H, contentH)
    SlyBagContent:SetHeight(contentH)

    -- Render
    local btnI = 0
    local hdrI = 0
    local curY = -SLOT_PAD

    for _, row in ipairs(rows) do
        if row.type == "header" then
            hdrI = hdrI + 1
            local h = sectionHdrs[hdrI]
            if not h then
                h = NewSectionHeader(SlyBagContent, hdrI)
                sectionHdrs[hdrI] = h
            end
            h:ClearAllPoints()
            h:SetPoint("TOPLEFT",  SlyBagContent, "TOPLEFT",  0, curY)
            h:SetPoint("TOPRIGHT", SlyBagContent, "TOPRIGHT", 0, curY)

            local t = SECTION_TINTS[row.tintIdx]
            h.bg:SetColorTexture(t[1], t[2], t[3], 0.92)
            h.accent:SetColorTexture(t[1] * 3, t[2] * 3, t[3] * 3, 1)

            local b = row.bucket
            local icon = IRR and IRR.db and IRR.db.setIcons and IRR.db.setIcons[b.name]
            if icon then h.ico:SetTexture(icon); h.ico:Show()
            else h.ico:Hide() end

            local nonEmpty = 0
            for _, it in ipairs(b.items) do if not it.empty then nonEmpty = nonEmpty + 1 end end
            h.lbl:SetText(b.name ~= "Other"
                and ("|cffffff99" .. b.name .. "|r")
                or  "|cff888888Other|r")
            h.cntLbl:SetText(nonEmpty .. (nonEmpty == 1 and " item" or " items"))
            h:Show()
            curY = curY - (SECTION_H + 2)

        else
            for colPos, it in ipairs(row.slots) do
                btnI = btnI + 1
                local b = slotBtns[btnI]
                if not b then
                    b = NewSlotButton(SlyBagContent, btnI)
                    slotBtns[btnI] = b
                end
                b:ClearAllPoints()
                b:SetPoint("TOPLEFT", SlyBagContent, "TOPLEFT",
                    SIDE_PAD + (colPos - 1) * CELL, curY)
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
            curY = curY - CELL
        end
    end

    for i = btnI + 1, #slotBtns   do slotBtns[i]:Hide()    end
    for i = hdrI + 1, #sectionHdrs do sectionHdrs[i]:Hide() end

    -- Footer
    local gold = GetMoney()
    local g = math.floor(gold / 10000)
    local s = math.floor((gold % 10000) / 100)
    local c = gold % 100
    SlyBagGoldText:SetFormattedText(
        "|cffffcc00%d|rg |cffc0c0c0%d|rs |cffcc7700%d|rc", g, s, c)
    SlyBagSlotText:SetText(used .. "/" .. total .. " slots used")
end

-- â”€â”€ SlyBag_BuildUI â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
function SlyBag_BuildUI()
    if SlyBagFrame then return end

    local db = SlyBag.db
    local f = CreateFrame("Frame", "SlyBagFrame", UIParent)
    f:SetSize(FRAME_W, FRAME_H)
    f:SetPoint(db.position.point, UIParent, db.position.point,
               db.position.x, db.position.y)
    f:SetMovable(true)
    f:EnableMouse(true)
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

    -- Header
    local title = f:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    title:SetPoint("TOPLEFT", f, "TOPLEFT", SIDE_PAD + 2, -8)
    title:SetText("|cff00ccffSly|r Bag")

    local setHint = f:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    setHint:SetPoint("LEFT", title, "RIGHT", 6, -1)
    setHint:SetTextColor(0.45, 0.45, 0.55)
    f.setHint = setHint

    local closeBtn = CreateFrame("Button", nil, f, "UIPanelCloseButton")
    closeBtn:SetPoint("TOPRIGHT", f, "TOPRIGHT", 2, 2)
    closeBtn:SetScript("OnClick", function() f:Hide() end)

    -- Search bar
    local sbarBg = f:CreateTexture(nil, "ARTWORK")
    sbarBg:SetPoint("TOPLEFT",  f, "TOPLEFT",  SIDE_PAD,  -(HEADER_H + 4))
    sbarBg:SetPoint("TOPRIGHT", f, "TOPRIGHT", -SIDE_PAD, -(HEADER_H + 4))
    sbarBg:SetHeight(SEARCH_H - 4)
    sbarBg:SetColorTexture(0.13, 0.13, 0.17, 1)

    local sbox = CreateFrame("EditBox", "SlyBagSearch", f)
    sbox:SetPoint("TOPLEFT",  f, "TOPLEFT",  SIDE_PAD + 6,      -(HEADER_H + 6))
    sbox:SetPoint("TOPRIGHT", f, "TOPRIGHT", -(SIDE_PAD + 22),  -(HEADER_H + 6))
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

    local clearBtn = CreateFrame("Button", nil, f)
    clearBtn:SetSize(16, 16)
    clearBtn:SetPoint("RIGHT", sbarBg, "RIGHT", -4, 0)
    local clrTex = clearBtn:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    clrTex:SetText("Ã—") ; clrTex:SetPoint("CENTER")
    clrTex:SetTextColor(0.6, 0.6, 0.7)
    clearBtn:SetScript("OnClick", function() sbox:SetText("") end)

    -- Scroll frame
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

    -- Footer
    local footLine = f:CreateTexture(nil, "ARTWORK")
    footLine:SetPoint("BOTTOMLEFT",  f, "BOTTOMLEFT",  SIDE_PAD,  FOOTER_H + 4)
    footLine:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", -SIDE_PAD, FOOTER_H + 4)
    footLine:SetHeight(1)
    footLine:SetColorTexture(0.3, 0.3, 0.4, 0.5)

    local goldTx = f:CreateFontString("SlyBagGoldText", "OVERLAY", "GameFontNormalSmall")
    goldTx:SetPoint("BOTTOMLEFT", f, "BOTTOMLEFT", SIDE_PAD + 2, 6)

    local slotTx = f:CreateFontString("SlyBagSlotText", "OVERLAY", "GameFontNormalSmall")
    slotTx:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", -(SIDE_PAD + 2), 6)
    slotTx:SetTextColor(0.55, 0.55, 0.62)

    f:SetScript("OnShow", function()
        local n = #GetSetNames()
        f.setHint:SetText(n > 0 and (n .. " set" .. (n == 1 and "" or "s")) or "")
        SlyBag_Refresh()
    end)

    f:Hide()
end


