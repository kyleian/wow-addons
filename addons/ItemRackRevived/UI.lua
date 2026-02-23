-- ============================================================
-- ItemRack Revived — UI.lua
-- Main draggable frame: gear slot icons + gear sets panel
-- ============================================================

-- Layout constants
local FRAME_W       = 440
local FRAME_H       = 560
local HEADER_H      = 28
local ICON_SIZE     = 36
local SLOT_COL_W    = 110   -- width of each slot column (2 columns)
local SLOT_ROW_H    = 50    -- icon (36) + label (10) + padding (4)
local LEFT_W        = SLOT_COL_W * 2 + 20   -- 240
local RIGHT_W       = FRAME_W - LEFT_W - 1  -- divider 1px
local MAX_SET_ROWS  = 12    -- max visible set rows in the list

-- References for later updating
local slotIcons   = {}   -- [slotId] = { button, texture, border } 
local setRowBtns  = {}   -- array of row button frames

local selectedSet = nil  -- currently highlighted set name

-- -----------------------------------------------------------------
-- Helper: create a flat colored background texture on a frame
-- -----------------------------------------------------------------
local function FillBackground(frame, r, g, b, a)
    local bg = frame:CreateTexture(nil, "BACKGROUND")
    bg:SetAllPoints(frame)
    bg:SetColorTexture(r, g, b, a or 1.0)
    return bg
end

-- -----------------------------------------------------------------
-- Helper: standard separator line (horizontal)
-- -----------------------------------------------------------------
local function MakeSeparator(parent, w, xOff, yOff)
    local sep = parent:CreateTexture(nil, "ARTWORK")
    sep:SetSize(w, 1)
    sep:SetPoint("TOPLEFT", parent, "TOPLEFT", xOff, yOff)
    sep:SetColorTexture(0.35, 0.35, 0.35, 1)
    return sep
end

-- -----------------------------------------------------------------
-- Helper: standard label FontString
-- -----------------------------------------------------------------
local function MakeLabel(parent, text, size, r, g, b)
    local fs = parent:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    fs:SetFont(fs:GetFont(), size or 11, "")
    fs:SetText(text)
    fs:SetTextColor(r or 0.9, g or 0.9, b or 0.9)
    return fs
end

-- -----------------------------------------------------------------
-- Slot icon button — shows item icon with quality border + tooltip
-- -----------------------------------------------------------------
local EMPTY_SLOT_TEXTURES = {
    [1]  = "Interface\\PaperDoll\\UI-PaperDoll-Slot-Head",
    [2]  = "Interface\\PaperDoll\\UI-PaperDoll-Slot-Neck",
    [3]  = "Interface\\PaperDoll\\UI-PaperDoll-Slot-Shoulder",
    [4]  = "Interface\\PaperDoll\\UI-PaperDoll-Slot-Shirt",
    [5]  = "Interface\\PaperDoll\\UI-PaperDoll-Slot-Chest",
    [6]  = "Interface\\PaperDoll\\UI-PaperDoll-Slot-Waist",
    [7]  = "Interface\\PaperDoll\\UI-PaperDoll-Slot-Legs",
    [8]  = "Interface\\PaperDoll\\UI-PaperDoll-Slot-Feet",
    [9]  = "Interface\\PaperDoll\\UI-PaperDoll-Slot-Wrist",
    [10] = "Interface\\PaperDoll\\UI-PaperDoll-Slot-Hands",
    [11] = "Interface\\PaperDoll\\UI-PaperDoll-Slot-Finger",
    [12] = "Interface\\PaperDoll\\UI-PaperDoll-Slot-Finger",
    [13] = "Interface\\PaperDoll\\UI-PaperDoll-Slot-Trinket",
    [14] = "Interface\\PaperDoll\\UI-PaperDoll-Slot-Trinket",
    [15] = "Interface\\PaperDoll\\UI-PaperDoll-Slot-Chest",
    [16] = "Interface\\PaperDoll\\UI-PaperDoll-Slot-MainHand",
    [17] = "Interface\\PaperDoll\\UI-PaperDoll-Slot-SecondaryHand",
    [18] = "Interface\\PaperDoll\\UI-PaperDoll-Slot-Ranged",
    [19] = "Interface\\PaperDoll\\UI-PaperDoll-Slot-Tabard",
}

local function CreateSlotIcon(parent, slotDef, col, row)
    -- col and row are 1-based grid coordinates
    local xOff = 8 + (col - 1) * SLOT_COL_W + (SLOT_COL_W - ICON_SIZE) / 2
    local yOff = -8 - (row - 1) * SLOT_ROW_H

    -- Container button (for click/hover behavior)
    local btn = CreateFrame("Button", "IRRSlot" .. slotDef.id, parent)
    btn:SetSize(ICON_SIZE, ICON_SIZE)
    btn:SetPoint("TOPLEFT", parent, "TOPLEFT", xOff, yOff)

    -- Item texture
    local tex = btn:CreateTexture(nil, "ARTWORK")
    tex:SetAllPoints(btn)
    tex:SetTexture(EMPTY_SLOT_TEXTURES[slotDef.id]
        or "Interface\\PaperDoll\\UI-PaperDoll-Slot-Bag0")
    tex:SetTexCoord(0.07, 0.93, 0.07, 0.93)

    -- Quality border (1px overlay)
    local border = btn:CreateTexture(nil, "OVERLAY")
    border:SetPoint("TOPLEFT",     btn, "TOPLEFT",     -1,  1)
    border:SetPoint("BOTTOMRIGHT", btn, "BOTTOMRIGHT",  1, -1)
    border:SetTexture("Interface\\Buttons\\UI-SlotHighlight")
    border:SetBlendMode("ADD")
    border:Hide()

    -- Slot label
    local label = parent:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    label:SetFont(label:GetFont(), 9, "")
    label:SetPoint("TOP", btn, "BOTTOM", 0, -1)
    label:SetText(slotDef.label)
    label:SetTextColor(0.7, 0.7, 0.7)

    -- Tooltip on hover
    btn:SetScript("OnEnter", function(self)
        if not IRR.db.options.showTooltips then return end
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:SetInventoryItem("player", slotDef.id)
        GameTooltip:Show()
    end)
    btn:SetScript("OnLeave", function(self)
        GameTooltip:Hide()
    end)

    slotIcons[slotDef.id] = { btn=btn, tex=tex, border=border }
end

-- -----------------------------------------------------------------
-- Live-update a single slot icon to current equipped item
-- -----------------------------------------------------------------
local function RefreshSlotIcon(slotDef)
    local entry = slotIcons[slotDef.id]
    if not entry then return end

    local link    = GetInventoryItemLink("player", slotDef.id)
    local texture = GetInventoryItemTexture("player", slotDef.id)

    if texture then
        entry.tex:SetTexture(texture)
        entry.tex:SetTexCoord(0.07, 0.93, 0.07, 0.93)

        if IRR.db.options.showQualityBorder then
            local _, _, quality = GetItemInfo(link or "")
            if quality and IRR.QUALITY_COLORS[quality] then
                local c = IRR.QUALITY_COLORS[quality]
                entry.border:SetVertexColor(c[1], c[2], c[3])
                if quality >= 2 then
                    entry.border:Show()
                else
                    entry.border:Hide()
                end
            else
                entry.border:Hide()
            end
        end
    else
        -- Empty slot: show placeholder
        entry.tex:SetTexture(EMPTY_SLOT_TEXTURES[slotDef.id]
            or "Interface\\PaperDoll\\UI-PaperDoll-Slot-Bag0")
        entry.tex:SetTexCoord(0.07, 0.93, 0.07, 0.93)
        entry.border:Hide()
    end
end

-- Public: refresh all slot icons
function IRR_UpdateSlots()
    for _, slotDef in ipairs(IRR.SLOTS) do
        RefreshSlotIcon(slotDef)
    end
end

-- -----------------------------------------------------------------
-- Right panel: gear sets list
-- -----------------------------------------------------------------
local function RefreshSetRow(idx, name)
    local row = setRowBtns[idx]
    if not row then return end

    if name then
        local count = IRR_GetSetItemCount(name)
        row.nameTxt:SetText(name)
        row.countTxt:SetText(count .. " items")
        row:SetAlpha(1.0)
        row:EnableMouse(true)
        row.setName = name

        -- Highlight selected
        if selectedSet == name then
            row.highlight:Show()
        else
            row.highlight:Hide()
        end
    else
        row.nameTxt:SetText("")
        row.countTxt:SetText("")
        row:SetAlpha(0)
        row:EnableMouse(false)
        row.setName = nil
        row.highlight:Hide()
    end
end

-- Public: rebuild the sets list panel
function IRR_UpdateSetsList()
    local names = IRR_GetSetNames()
    for i = 1, MAX_SET_ROWS do
        RefreshSetRow(i, names[i])
    end

    -- Validate selected set still exists
    if selectedSet and not IRR_SetExists(selectedSet) then
        selectedSet = nil
    end
end

local function CreateSetsPanel(parent, xOff, yOff, availableH)
    -- Header
    local hdr = MakeLabel(parent, "Saved Sets", 12, 1, 0.82, 0)
    hdr:SetPoint("TOPLEFT", parent, "TOPLEFT", xOff + 6, yOff)

    -- Set row list
    local listTop = yOff - 22
    local rowH    = 26
    local listH   = MAX_SET_ROWS * rowH

    local editBox  -- forward ref; assigned below, captured by row OnClick closures

    for i = 1, MAX_SET_ROWS do
        local rowY = listTop - (i - 1) * rowH

        local row = CreateFrame("Button", nil, parent)
        row:SetSize(RIGHT_W - 12, rowH - 2)
        row:SetPoint("TOPLEFT", parent, "TOPLEFT", xOff + 4, rowY)

        -- Row background
        local rowBg = FillBackground(row, 0.15, 0.15, 0.15, 0.8)
        row.bg = rowBg

        -- Selection highlight
        local hl = row:CreateTexture(nil, "ARTWORK")
        hl:SetAllPoints(row)
        hl:SetColorTexture(0.3, 0.6, 1.0, 0.25)
        hl:Hide()
        row.highlight = hl

        -- Hover highlight
        local hoverTex = row:CreateTexture(nil, "HIGHLIGHT")
        hoverTex:SetAllPoints(row)
        hoverTex:SetColorTexture(1, 1, 1, 0.07)

        -- Set name
        local nameTxt = row:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        nameTxt:SetFont(nameTxt:GetFont(), 10, "")
        nameTxt:SetPoint("LEFT", row, "LEFT", 4, 0)
        nameTxt:SetTextColor(0.9, 0.9, 0.9)
        row.nameTxt = nameTxt

        -- Item count
        local countTxt = row:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        countTxt:SetFont(countTxt:GetFont(), 9, "")
        countTxt:SetPoint("RIGHT", row, "RIGHT", -4, 0)
        countTxt:SetTextColor(0.55, 0.55, 0.55)
        row.countTxt = countTxt

        -- Left-click: select + load; Right-click: select only
        row:SetScript("OnClick", function(self, btn)
            if btn == "LeftButton" and self.setName then
                selectedSet = self.setName
                if editBox then editBox:SetText(self.setName) end
                IRR_UpdateSetsList()
                IRR_LoadSet(self.setName)
            elseif btn == "RightButton" and self.setName then
                selectedSet = self.setName
                if editBox then editBox:SetText(self.setName) end
                IRR_UpdateSetsList()
            end
        end)
        row:RegisterForClicks("LeftButtonUp", "RightButtonUp")

        setRowBtns[i] = row
        RefreshSetRow(i, nil)
    end

    -- Separator above input row
    local sepY = listTop - listH - 4
    MakeSeparator(parent, RIGHT_W - 12, xOff + 4, sepY)

    -- "Save current gear as:" label
    local saveLabel = MakeLabel(parent, "Save as:", 10, 0.7, 0.7, 0.7)
    saveLabel:SetPoint("TOPLEFT", parent, "TOPLEFT", xOff + 6, sepY - 10)

    -- EditBox for set name
    editBox = CreateFrame("EditBox", "IRRSetNameInput", parent,
        "InputBoxTemplate")
    editBox:SetSize(RIGHT_W - 24, 20)
    editBox:SetPoint("TOPLEFT", parent, "TOPLEFT", xOff + 4, sepY - 26)
    editBox:SetMaxLetters(32)
    editBox:SetAutoFocus(false)
    editBox:SetText("")
    editBox:SetScript("OnEnterPressed", function(self)
        IRR_SaveCurrentSet(self:GetText())
        self:ClearFocus()
        self:SetText("")
    end)

    -- [Save] button
    local saveBtn = CreateFrame("Button", nil, parent, "UIPanelButtonTemplate")
    saveBtn:SetSize(80, 22)
    saveBtn:SetPoint("TOPLEFT", parent, "TOPLEFT", xOff + 4, sepY - 52)
    saveBtn:SetText("Save Set")
    saveBtn:SetScript("OnClick", function()
        -- Use whatever is in the box (populated on select = overwrite; typed = new)
        local name = strtrim(editBox:GetText())
        if name == "" then
            print("|cff00ccff[ItemRack Revived]|r Select a set to overwrite, or type a name for a new set.")
            return
        end
        local isNew = not IRR_SetExists(name)
        if IRR_SaveCurrentSet(name) then
            selectedSet = name
            IRR_UpdateSetsList()
            if isNew then
                -- Only clear box for brand-new saves; keep name visible after overwrite
                editBox:ClearFocus()
            end
        end
    end)

    -- [Delete] button
    local delBtn = CreateFrame("Button", nil, parent, "UIPanelButtonTemplate")
    delBtn:SetSize(80, 22)
    delBtn:SetPoint("TOPLEFT", parent, "TOPLEFT", xOff + 4, sepY - 78)
    delBtn:SetText("Delete")
    delBtn:SetScript("OnClick", function()
        if selectedSet then
            IRR_DeleteSet(selectedSet)
            selectedSet = nil
            IRR_UpdateSetsList()
        else
            print("|cff00ccff[ItemRack Revived]|r Right-click a set to select it, then Delete.")
        end
    end)

    -- [Load] button
    local loadBtn = CreateFrame("Button", nil, parent, "UIPanelButtonTemplate")
    loadBtn:SetSize(80, 22)
    loadBtn:SetPoint("TOPLEFT", parent, "TOPLEFT", xOff + RIGHT_W - 90, sepY - 52)
    loadBtn:SetText("Equip")
    loadBtn:SetScript("OnClick", function()
        if selectedSet then
            IRR_LoadSet(selectedSet)
        else
            print("|cff00ccff[ItemRack Revived]|r Click or right-click a set to select it.")
        end
    end)
end

-- -----------------------------------------------------------------
-- Main frame builder (called once from IRR_Init)
-- -----------------------------------------------------------------
function IRR_BuildUI()
    if IRRFrame then return end  -- already built

    -- ---- Main frame ----
    local f = CreateFrame("Frame", "IRRFrame", UIParent)
    f:SetSize(FRAME_W, FRAME_H)
    f:SetFrameStrata("DIALOG")
    f:SetMovable(true)
    f:EnableMouse(true)
    f:RegisterForDrag("LeftButton")
    f:SetScript("OnDragStart", f.StartMoving)
    f:SetScript("OnDragStop",  f.StopMovingOrSizing)
    f:Hide()

    -- Restore saved position
    local pos = IRR.db.position
    f:ClearAllPoints()
    f:SetPoint(pos.point or "CENTER", UIParent, pos.point or "CENTER",
        pos.x or 0, pos.y or 0)

    -- ---- Background ----
    FillBackground(f, 0.07, 0.07, 0.07, 0.93)

    -- Outer border texture
    local borderTex = f:CreateTexture(nil, "OVERLAY")
    borderTex:SetPoint("TOPLEFT",     f, "TOPLEFT",      0,  0)
    borderTex:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT",  0,  0)
    borderTex:SetColorTexture(0.3, 0.3, 0.3, 1)

    -- Inner fill on top of border
    local innerBg = f:CreateTexture(nil, "BACKGROUND")
    innerBg:SetPoint("TOPLEFT",     f, "TOPLEFT",      1, -1)
    innerBg:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", -1,  1)
    innerBg:SetColorTexture(0.07, 0.07, 0.07, 0.93)

    -- ---- Header ----
    local header = CreateFrame("Frame", nil, f)
    header:SetSize(FRAME_W, HEADER_H)
    header:SetPoint("TOPLEFT", f, "TOPLEFT", 0, 0)
    FillBackground(header, 0.13, 0.13, 0.13, 1.0)

    local title = header:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    title:SetFont(title:GetFont(), 13, "OUTLINE")
    title:SetPoint("LEFT", header, "LEFT", 10, 0)
    title:SetText("|cff00ccffItemRack Revived|r")
    title:SetTextColor(1, 1, 1)

    -- Version tag
    local verTxt = header:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    verTxt:SetFont(verTxt:GetFont(), 9, "")
    verTxt:SetPoint("RIGHT", header, "RIGHT", -36, 0)
    verTxt:SetText("v" .. IRR.version)
    verTxt:SetTextColor(0.5, 0.5, 0.5)

    -- Close button
    local closeBtn = CreateFrame("Button", nil, header, "UIPanelCloseButton")
    closeBtn:SetSize(24, 24)
    closeBtn:SetPoint("RIGHT", header, "RIGHT", -2, 0)
    closeBtn:SetScript("OnClick", function() f:Hide() end)

    -- Header separator
    MakeSeparator(f, FRAME_W, 0, -HEADER_H)

    -- ---- Left panel label ----
    local gearLbl = MakeLabel(f, "Equipped Gear", 12, 1, 0.82, 0)
    gearLbl:SetPoint("TOPLEFT", f, "TOPLEFT", 8, -(HEADER_H + 10))

    -- ---- Build slot icon grid ----
    local slotContentTop = -(HEADER_H + 26)
    local rowIdx = 0
    for _, pair in ipairs(IRR.SLOT_PAIRS) do
        rowIdx = rowIdx + 1
        if pair[1] then CreateSlotIcon(f, pair[1], 1, rowIdx) end
        if pair[2] then CreateSlotIcon(f, pair[2], 2, rowIdx) end
    end

    -- Vertical divider between left and right panels
    local vdiv = f:CreateTexture(nil, "ARTWORK")
    vdiv:SetSize(1, FRAME_H - HEADER_H - 2)
    vdiv:SetPoint("TOPLEFT", f, "TOPLEFT", LEFT_W, -(HEADER_H + 1))
    vdiv:SetColorTexture(0.3, 0.3, 0.3, 1)

    -- ---- Right panel: sets ----
    CreateSetsPanel(f, LEFT_W + 6, -(HEADER_H + 10),
        FRAME_H - HEADER_H - 20)

    -- ---- Initial data load ----
    IRR_UpdateSlots()
    IRR_UpdateSetsList()

    IRRFrame = f
end

-- -----------------------------------------------------------------
-- Toggle visibility
-- -----------------------------------------------------------------
function IRR_ToggleUI()
    if not IRRFrame then return end
    if IRRFrame:IsShown() then
        IRRFrame:Hide()
    else
        IRR_UpdateSlots()
        IRR_UpdateSetsList()
        IRRFrame:Show()
    end
end
