-- ============================================================
-- SlySlotUI.lua  —  Action bar profile manager UI
-- ============================================================

local FRAME_W   = 560
local FRAME_H   = 440
local SIDE_PAD  = 10
local LIST_W    = 200
local PANEL_H   = FRAME_H - 60   -- usable height below title
local ROW_H     = 22
local BTN_H     = 22

local selectedProfile = nil   -- currently highlighted profile name
local rowPool         = {}    -- reusable row button pool (no SetParent/destroy)

-- -------------------------------------------------------
-- Layout helpers
-- -------------------------------------------------------
local function FillBg(frame, r, g, b, a)
    local t = frame:CreateTexture(nil, "BACKGROUND")
    t:SetAllPoints()
    t:SetTexture(r, g, b, a)
    return t
end

-- -------------------------------------------------------
-- SlySlot_UIRefresh  —  rebuild profile list rows
-- -------------------------------------------------------
function SlySlot_UIRefresh()
    if not SlySlotFrame then return end
    if not SlySlot.db then return end

    -- Gather sorted names
    local names = {}
    for n in pairs(SlySlot.db.profiles) do
        table.insert(names, n)
    end
    table.sort(names)

    -- Resize scroll content
    local contentH = math.max(PANEL_H - 80, #names * ROW_H + 4)
    SlySlotListContent:SetHeight(contentH)

    -- Hide all pooled rows first (never SetParent(nil) — that orphans frames
    -- onto UIParent and leaves invisible mouse-blocking buttons in the world)
    for _, row in ipairs(rowPool) do
        row:Hide()
    end

    for i, name in ipairs(names) do
        -- Reuse a pooled row or create a new one
        local row = rowPool[i]
        if not row then
            row = CreateFrame("Button", nil, SlySlotListContent)
            row:SetSize(LIST_W - 8, ROW_H)
            local bg = row:CreateTexture(nil, "BACKGROUND")
            bg:SetAllPoints()
            row.bg = bg
            local hl = row:CreateTexture(nil, "HIGHLIGHT")
            hl:SetAllPoints()
            hl:SetTexture(0.25, 0.50, 0.80, 0.3)
            local label = row:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
            label:SetPoint("LEFT", row, "LEFT", 4, 0)
            row.label = label
            rowPool[i] = row
        end

        row:ClearAllPoints()
        row:SetPoint("TOPLEFT", SlySlotListContent, "TOPLEFT", 2, -(i - 1) * ROW_H)

        local isSelected = (name == selectedProfile)
        row.bg:SetTexture(isSelected and 0.20 or 0.10,
                          isSelected and 0.40 or 0.10,
                          isSelected and 0.65 or 0.13,
                          0.5)
        row.label:SetText(name)
        row.label:SetTextColor(isSelected and 1 or 0.85,
                               isSelected and 1 or 0.85,
                               isSelected and 1 or 0.9)

        -- Capture name in closure via local
        local rowName = name
        row:SetScript("OnClick", function()
            selectedProfile = rowName
            SlySlot_UIRefresh()
            if SlySlotNameBox  then SlySlotNameBox:SetText(rowName) end
            if SlySlotExportBox then SlySlotExportBox:SetText("") end
        end)

        row:Show()
    end

    -- Update button state labels
    if SlySlotSelLabel then
        SlySlotSelLabel:SetText(selectedProfile
            and ("|cffffcc00" .. selectedProfile .. "|r selected")
            or  "|cffaaaaaa(none selected)|r")
    end
end

-- -------------------------------------------------------
-- SlySlot_BuildUI  —  construct the frame (called once)
-- -------------------------------------------------------
function SlySlot_BuildUI()
    if SlySlotFrame then return end

    local db = SlySlot.db
    local f = CreateFrame("Frame", "SlySlotFrame", UIParent)
    f:SetSize(FRAME_W, FRAME_H)
    f:SetPoint(db.position.point, UIParent, db.position.point,
               db.position.x, db.position.y)
    f:EnableMouse(false)   -- toggled by OnShow/OnHide; hidden frames must not capture input
    f:SetMovable(true)
    f:RegisterForDrag("LeftButton")
    f:SetScript("OnDragStart", f.StartMoving)
    f:SetScript("OnDragStop", function(self)
        self:StopMovingOrSizing()
        local p, _, _, x, y = self:GetPoint()
        SlySlot.db.position = { point = p, x = x, y = y }
    end)
    f:HookScript("OnShow", function(self) self:EnableMouse(true) end)
    f:HookScript("OnHide", function(self) self:EnableMouse(false) end)
    f:SetBackdrop({
        bgFile   = "Interface\\DialogFrame\\UI-DialogBox-Background",
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        tile = true, tileSize = 16, edgeSize = 12,
        insets = { left = 3, right = 3, top = 3, bottom = 3 },
    })
    f:SetBackdropColor(0.07, 0.07, 0.10, 0.96)
    f:SetBackdropBorderColor(0.30, 0.30, 0.40, 1)

    f:Hide()

    -- ---- Title bar ----
    local title = f:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    title:SetPoint("TOPLEFT", f, "TOPLEFT", SIDE_PAD + 2, -10)
    title:SetText("|cff00ccffSly|r Slot  |cffaaaaaa— Action Bar Profiles|r")

    local closeBtn = CreateFrame("Button", nil, f, "UIPanelCloseButton")
    closeBtn:SetPoint("TOPRIGHT", f, "TOPRIGHT", 2, 2)
    closeBtn:SetScript("OnClick", function() f:Hide() end)

    local divLine = f:CreateTexture(nil, "ARTWORK")
    divLine:SetPoint("TOPLEFT",  f, "TOPLEFT",  SIDE_PAD, -30)
    divLine:SetPoint("TOPRIGHT", f, "TOPRIGHT", -SIDE_PAD, -30)
    divLine:SetHeight(1)
    divLine:SetTexture(0.3, 0.3, 0.4, 0.5)

    -- ============================================================
    -- LEFT PANEL  —  Profile list
    -- ============================================================
    local leftPanel = CreateFrame("Frame", nil, f)
    leftPanel:SetPoint("TOPLEFT", f, "TOPLEFT", SIDE_PAD, -36)
    leftPanel:SetSize(LIST_W, PANEL_H)
    FillBg(leftPanel, 0.07, 0.07, 0.09, 0.6)

    local listTitle = leftPanel:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    listTitle:SetPoint("TOPLEFT", leftPanel, "TOPLEFT", 4, -4)
    listTitle:SetText("|cffaaaaaa  Saved Profiles|r")

    -- Scroll frame for list
    local sf = CreateFrame("ScrollFrame", "SlySlotListScroll", leftPanel)
    sf:SetPoint("TOPLEFT",     leftPanel, "TOPLEFT",     2,  -18)
    sf:SetPoint("BOTTOMRIGHT", leftPanel, "BOTTOMRIGHT", -2,  2)
    sf:EnableMouseWheel(true)
    sf:SetClipsChildren(true)
    sf:SetScript("OnMouseWheel", function(self, delta)
        local cur = self:GetVerticalScroll()
        local max = self:GetVerticalScrollRange()
        self:SetVerticalScroll(math.max(0, math.min(max, cur - delta * ROW_H * 3)))
    end)

    local content = CreateFrame("Frame", "SlySlotListContent", sf)
    content:SetWidth(LIST_W - 8)
    content:SetHeight(200)
    sf:SetScrollChild(content)

    -- ============================================================
    -- RIGHT PANEL  —  Controls
    -- ============================================================
    local rightX = SIDE_PAD + LIST_W + 8
    local rightW = FRAME_W - rightX - SIDE_PAD

    -- Selection indicator
    local selLabel = f:CreateFontString("SlySlotSelLabel", "OVERLAY", "GameFontNormalSmall")
    selLabel:SetPoint("TOPLEFT", f, "TOPLEFT", rightX, -40)
    selLabel:SetText("|cffaaaaaa(none selected)|r")

    -- ---- Name box ----
    local nameLbl = f:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    nameLbl:SetPoint("TOPLEFT", f, "TOPLEFT", rightX, -62)
    nameLbl:SetText("|cffccccccProfile name:|r")

    local nameBg = f:CreateTexture(nil, "ARTWORK")
    nameBg:SetPoint("TOPLEFT",  f, "TOPLEFT",  rightX,          -76)
    nameBg:SetSize(rightW, 22)
    nameBg:SetTexture(0.12, 0.12, 0.16, 1)

    local nameBox = CreateFrame("EditBox", "SlySlotNameBox", f)
    nameBox:SetPoint("TOPLEFT",  f, "TOPLEFT",  rightX + 4,      -77)
    nameBox:SetSize(rightW - 8, 20)
    nameBox:SetFontObject("ChatFontNormal")
    nameBox:SetAutoFocus(false)
    nameBox:SetMaxLetters(64)
    nameBox:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)

    -- ---- Action buttons ----
    local function MakeBtn(parent, lbl, ax, ay, w, fn)
        local b = CreateFrame("Button", nil, parent, "UIPanelButtonTemplate")
        b:SetSize(w or 110, BTN_H)
        b:SetPoint("TOPLEFT", parent, "TOPLEFT", ax, ay)
        b:SetText(lbl)
        b:SetScript("OnClick", fn)
        return b
    end

    -- Save button  — overwrites selectedProfile if one is active, else uses name box
    local saveBtn = MakeBtn(f, "Save", rightX, -104, 120, function()
        -- If a profile is already selected, overwrite it directly
        local isOverwrite = (selectedProfile ~= nil)
        local name = selectedProfile or strtrim(SlySlotNameBox:GetText())
        if not name or name == "" then
            print("|cff00ccff[SlySlot]|r Select a profile or enter a name first.")
            return
        end
        local ok, err = SlySlot_SaveProfile(name)
        if ok then
            selectedProfile = name
            SlySlotNameBox:SetText(name)
            SlySlot_UIRefresh()
            local verb = isOverwrite and "Overwritten" or "Saved"
            print("|cff00ccff[SlySlot]|r " .. verb .. ": |cffffcc00" .. name .. "|r")
        else
            print("|cffff4444[SlySlot]|r " .. (err or "Error"))
        end
    end)

    -- Load button
    MakeBtn(f, "Load Selected", rightX + 126, -104, 120, function()
        if not selectedProfile then
            print("|cff00ccff[SlySlot]|r Select a profile first.")
            return
        end
        local ok, err = SlySlot_LoadProfile(selectedProfile)
        if ok then
            print("|cff00ccff[SlySlot]|r Loaded: |cffffcc00" .. selectedProfile .. "|r")
        else
            print("|cffff4444[SlySlot]|r " .. (err or "Error"))
        end
    end)

    -- Delete button
    MakeBtn(f, "Delete", rightX + 252, -104, 80, function()
        if not selectedProfile then return end
        SlySlot_DeleteProfile(selectedProfile)
        print("|cff00ccff[SlySlot]|r Deleted: |cffffcc00" .. selectedProfile .. "|r")
        selectedProfile = nil
        SlySlotNameBox:SetText("")
        SlySlot_UIRefresh()
    end)

    -- ---- Divider ----
    local mid = f:CreateTexture(nil, "ARTWORK")
    mid:SetPoint("TOPLEFT",  f, "TOPLEFT",  rightX, -134)
    mid:SetSize(rightW, 1)
    mid:SetTexture(0.3, 0.3, 0.4, 0.4)

    -- ---- Export / Import section ----
    local ioTitle = f:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    ioTitle:SetPoint("TOPLEFT", f, "TOPLEFT", rightX, -142)
    ioTitle:SetText("|cffccccccExport / Import|r")

    local exportBg = f:CreateTexture(nil, "ARTWORK")
    exportBg:SetPoint("TOPLEFT",  f, "TOPLEFT",  rightX, -158)
    exportBg:SetSize(rightW, FRAME_H - 200)
    exportBg:SetTexture(0.10, 0.10, 0.13, 1)

    local exportBox = CreateFrame("EditBox", "SlySlotExportBox", f)
    exportBox:SetPoint("TOPLEFT",  f, "TOPLEFT",  rightX + 4, -160)
    exportBox:SetSize(rightW - 8, FRAME_H - 210)
    exportBox:SetFontObject("ChatFontNormal")
    exportBox:SetMultiLine(true)
    exportBox:SetAutoFocus(false)
    exportBox:SetMaxLetters(16384)
    exportBox:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)

    -- Export button
    MakeBtn(f, "Export Selected", rightX, -(FRAME_H - 46), 140, function()
        if not selectedProfile then
            print("|cff00ccff[SlySlot]|r Select a profile to export.")
            return
        end
        local str, err = SlySlot_ExportProfile(selectedProfile)
        if str then
            SlySlotExportBox:SetText(str)
            SlySlotExportBox:SetFocus()
            SlySlotExportBox:HighlightText()
        else
            print("|cffff4444[SlySlot]|r " .. (err or "Error"))
        end
    end)

    -- Import button
    MakeBtn(f, "Import String", rightX + 146, -(FRAME_H - 46), 130, function()
        local str = strtrim(SlySlotExportBox:GetText())
        if str == "" then
            print("|cff00ccff[SlySlot]|r Paste an export string into the text box first.")
            return
        end
        local name, err = SlySlot_ImportProfile(str)
        if name then
            selectedProfile = name
            SlySlot_UIRefresh()
            print("|cff00ccff[SlySlot]|r Imported as: |cffffcc00" .. name .. "|r")
        else
            print("|cffff4444[SlySlot]|r " .. (err or "Error"))
        end
    end)

    f:SetScript("OnShow", SlySlot_UIRefresh)
end
