-- ============================================================
-- Sly WeakAuras — SlyWeakAurasUI.lua
-- Pack manager panel: list, detail view, paste import, capture
-- ============================================================

local FRAME_W      = 560
local FRAME_H      = 520
local HEADER_H     = 30
local LIST_W       = 190       -- left column: pack list
local DETAIL_W     = FRAME_W - LIST_W - 1  -- right column: pack detail
local LIST_ROW_H   = 36
local PAD          = 8

-- Widget refs
local packListRows = {}      -- [i] = { frame, nameTxt, srcTxt, statusDot, packName }
local selectedPack = nil     -- currently selected pack name

-- -------------------------------------------------------
-- Helpers
-- -------------------------------------------------------
local function FillBg(frame, r, g, b, a)
    local t = frame:CreateTexture(nil, "BACKGROUND")
    t:SetAllPoints(frame)
    t:SetColorTexture(r, g, b, a or 1)
    return t
end

local function MkLabel(parent, text, size, r, g, b)
    local fs = parent:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    fs:SetFont(fs:GetFont(), size or 10, "")
    fs:SetText(text or "")
    fs:SetTextColor(r or 0.85, g or 0.85, b or 0.85)
    return fs
end

local function MkSep(parent, w, xOff, yOff)
    local t = parent:CreateTexture(nil, "ARTWORK")
    t:SetSize(w, 1)
    t:SetPoint("TOPLEFT", parent, "TOPLEFT", xOff, yOff)
    t:SetColorTexture(0.25, 0.25, 0.25, 1)
    return t
end

-- Status dot (small colored square/circle)
local function MkDot(parent)
    local d = parent:CreateTexture(nil, "ARTWORK")
    d:SetSize(10, 10)
    d:SetColorTexture(0.4, 0.4, 0.4, 1)
    return d
end

-- -------------------------------------------------------
-- Status bar at top of panel
-- -------------------------------------------------------
local statusLine  = nil
local auraCountLn = nil

function SlyWA_UIRefreshStatus()
    if not statusLine then return end
    if SlyWA_IsWeakAurasLoaded() then
        local ver = SlyWA_GetWAVersion()
        statusLine:SetText("|cff44ff44● WeakAuras ACTIVE|r  — " .. ver)
        if auraCountLn then
            auraCountLn:SetText(SlyWA_GetInstalledAuraCount() .. " auras installed")
        end
    else
        statusLine:SetText("|cffff4444✖ WeakAuras NOT LOADED|r  — enable in AddOns list & /reload")
        if auraCountLn then auraCountLn:SetText("") end
    end
end

-- -------------------------------------------------------
-- Pack list (left column)
-- -------------------------------------------------------
local function GetPackStatusDotColor(pack)
    if not pack or not pack.auraString or #pack.auraString < 10 then
        return 0.5, 0.3, 0.1   -- orange: empty/no data
    end
    if pack.lastImported then
        return 0.2, 0.9, 0.2   -- green: imported at least once
    end
    return 0.3, 0.6, 1.0       -- blue: has data, not imported yet
end

local function BuildPackListRow(parent, idx)
    local row = CreateFrame("Button", nil, parent)
    row:SetHeight(LIST_ROW_H)
    row:SetPoint("LEFT",  parent, "LEFT",  0, 0)
    row:SetPoint("RIGHT", parent, "RIGHT", 0, 0)

    FillBg(row, 0.11, 0.11, 0.11, 0.9)

    local hl = row:CreateTexture(nil, "HIGHLIGHT")
    hl:SetAllPoints(row)
    hl:SetColorTexture(1, 1, 1, 0.06)

    local selHl = row:CreateTexture(nil, "ARTWORK")
    selHl:SetAllPoints(row)
    selHl:SetColorTexture(0.3, 0.55, 1.0, 0.2)
    selHl:Hide()
    row.selHl = selHl

    local dot = MkDot(row)
    dot:SetPoint("LEFT", row, "LEFT", 6, 2)
    row.dot = dot

    local nameTxt = row:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    nameTxt:SetFont(nameTxt:GetFont(), 10, "")
    nameTxt:SetPoint("TOPLEFT", row, "TOPLEFT", 22, -6)
    nameTxt:SetWidth(LIST_W - 28)
    nameTxt:SetJustifyH("LEFT")
    nameTxt:SetTextColor(0.9, 0.9, 0.9)
    row.nameTxt = nameTxt

    local srcTxt = row:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    srcTxt:SetFont(srcTxt:GetFont(), 8, "")
    srcTxt:SetPoint("BOTTOMLEFT", row, "BOTTOMLEFT", 22, 5)
    srcTxt:SetWidth(LIST_W - 28)
    srcTxt:SetJustifyH("LEFT")
    srcTxt:SetTextColor(0.45, 0.45, 0.45)
    row.srcTxt = srcTxt

    row:SetScript("OnClick", function(self)
        if self.packName then
            selectedPack = self.packName
            SlyWA_UIRefreshAll()
        end
    end)

    packListRows[idx] = row
    return row
end

local function RefreshPackListRow(idx, packName)
    local row = packListRows[idx]
    if not row then return end

    if packName then
        local pack = SlyWA.db.packs[packName]
        row.packName = packName
        row.nameTxt:SetText(packName)
        row.srcTxt:SetText(pack and pack.source or "")
        row:SetAlpha(1.0)
        row:EnableMouse(true)

        if pack then
            local r, g, b = GetPackStatusDotColor(pack)
            row.dot:SetColorTexture(r, g, b, 1)
        end

        if selectedPack == packName then
            row.selHl:Show()
        else
            row.selHl:Hide()
        end
    else
        row.packName = nil
        row.nameTxt:SetText("")
        row.srcTxt:SetText("")
        row:SetAlpha(0)
        row:EnableMouse(false)
        row.selHl:Hide()
    end
end

-- -------------------------------------------------------
-- Detail panel (right column) — refs updated each refresh
-- -------------------------------------------------------
local detailName    = nil
local detailSrc     = nil
local detailDesc    = nil
local detailTags    = nil
local detailCount   = nil
local detailImported = nil
local importBtn     = nil
local captureBtn    = nil
local deleteBtn     = nil
local pasteEditBox  = nil
local pasteStoreBtn = nil
local pasteNameBox  = nil

local function RefreshDetailPanel()
    local pack = selectedPack and SlyWA.db.packs[selectedPack]

    if not pack then
        if detailName   then detailName:SetText("|cff444444Select a pack from the list|r") end
        if detailSrc    then detailSrc:SetText("") end
        if detailDesc   then detailDesc:SetText("") end
        if detailTags   then detailTags:SetText("") end
        if detailCount  then detailCount:SetText("") end
        if detailImported then detailImported:SetText("") end
        if importBtn    then importBtn:SetEnabled(false) end
        if captureBtn   then captureBtn:SetEnabled(false) end
        if deleteBtn    then deleteBtn:SetEnabled(false) end
        return
    end

    if detailName   then detailName:SetText("|cff88aaff" .. pack.name .. "|r") end
    if detailSrc    then detailSrc:SetText("Source: " .. (pack.source or "Unknown")) end
    if detailDesc   then detailDesc:SetText(pack.description or "") end
    if detailTags   then
        local tags = SlyWA_GetTagString(pack)
        detailTags:SetText(tags ~= "" and ("|cff666666Tags:|r " .. tags) or "")
    end

    -- Estimated count
    if detailCount then
        local validity = SlyWA_ValidateAuraString(pack.auraString)
        if validity == "empty" then
            detailCount:SetText("|cffff8844No aura data — paste a WA export string below|r")
        else
            local est = pack.estimatedCount
            if not est then
                est = SlyWA_EstimateCount(pack.auraString)
                pack.estimatedCount = est
            end
            detailCount:SetText("|cff44ff44~" .. est .. " aura(s)|r  "
                .. "|cff444444" .. #pack.auraString .. " bytes|r")
        end
    end

    if detailImported then
        if pack.lastImported then
            detailImported:SetText("Last imported: " .. date("%Y-%m-%d %H:%M", pack.lastImported)
                .. "  (" .. (pack.importCount or 0) .. "x)")
        else
            detailImported:SetText("|cff666666Never imported|r")
        end
    end

    -- Enable/disable buttons
    local hasData = SlyWA_ValidateAuraString(pack.auraString) ~= "empty"
    local waOk    = SlyWA_IsWeakAurasLoaded()
    if importBtn  then importBtn:SetEnabled(hasData and waOk) end
    if captureBtn then captureBtn:SetEnabled(waOk) end
    if deleteBtn  then deleteBtn:SetEnabled(true) end
end

-- -------------------------------------------------------
-- "Add Pack" new-pack row at bottom of list
-- -------------------------------------------------------
local function BuildAddPackRow(parent, yOff)
    local addBtn = CreateFrame("Button", nil, parent, "UIPanelButtonTemplate")
    addBtn:SetSize(LIST_W - 8, 22)
    addBtn:SetPoint("TOPLEFT", parent, "TOPLEFT", 4, yOff)
    addBtn:SetText("+ Add Pack")
    addBtn:SetScript("OnClick", function()
        -- Select a blank entry mode: show paste area, clear selection
        selectedPack      = nil
        if pasteNameBox   then pasteNameBox:SetText("New Pack Name") end
        if pasteEditBox   then pasteEditBox:SetText("") end
        SlyWA_UIRefreshAll()
        if pasteEditBox   then pasteEditBox:SetFocus() end
    end)
end

-- -------------------------------------------------------
-- Capture sub-panel: filter input + capture button
-- -------------------------------------------------------
local captureFilterBox = nil

local function BuildCaptureRow(parent, xOff, yOff)
    local lbl = MkLabel(parent, "Filter:", 9, 0.6, 0.6, 0.6)
    lbl:SetPoint("TOPLEFT", parent, "TOPLEFT", xOff, yOff)

    local filterBox = CreateFrame("EditBox", "SlyWACaptureFilter", parent, "InputBoxTemplate")
    filterBox:SetSize(DETAIL_W - 120, 16)
    filterBox:SetPoint("LEFT", lbl, "RIGHT", 4, 0)
    filterBox:SetAutoFocus(false)
    filterBox:SetMaxLetters(64)
    captureFilterBox = filterBox

    local capBtn = CreateFrame("Button", nil, parent, "UIPanelButtonTemplate")
    capBtn:SetSize(80, 20)
    capBtn:SetPoint("LEFT", filterBox, "RIGHT", 4, 0)
    capBtn:SetText("Capture")
    capBtn:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_TOP")
        GameTooltip:SetText("Capture from WeakAuras", 1, 1, 1)
        GameTooltip:AddLine(
            "Scans installed WeakAuras for groups/auras whose name\n"
            .. "contains the filter text, then saves them to the selected pack.\n"
            .. "Leave filter blank to capture all top-level groups.",
            0.8, 0.8, 0.8, true)
        GameTooltip:Show()
    end)
    capBtn:SetScript("OnLeave", function() GameTooltip:Hide() end)
    capBtn:SetScript("OnClick", function()
        if not selectedPack then
            print("|cff00ccff[SlyWeakAuras]|r Select or create a pack first.")
            return
        end
        if not SlyWA_IsWeakAurasLoaded() then
            print("|cff00ccff[SlyWeakAuras]|r WeakAuras is not loaded.")
            return
        end
        local filter = captureFilterBox and strtrim(captureFilterBox:GetText()) or ""
        SlyWA_CapturePack(selectedPack, filter)
    end)
    captureBtn = capBtn
end

-- -------------------------------------------------------
-- Paste import sub-panel
-- -------------------------------------------------------
local function BuildPastePanel(parent, xOff, yOff, availW, availH)
    MkSep(parent, availW, xOff, yOff)

    local hdr = MkLabel(parent, "Paste WeakAuras Export String", 10, 0.6, 0.85, 1.0)
    hdr:SetPoint("TOPLEFT", parent, "TOPLEFT", xOff, yOff - 6)

    local hint = MkLabel(parent,
        "In-game: WeakAuras → select group → Export → copy string, paste below.",
        8, 0.45, 0.45, 0.45)
    hint:SetPoint("TOPLEFT", parent, "TOPLEFT", xOff, yOff - 20)
    hint:SetWidth(availW - 4)
    hint:SetJustifyH("LEFT")

    -- Pack name box
    local nameLbl = MkLabel(parent, "Pack name:", 9, 0.6, 0.6, 0.6)
    nameLbl:SetPoint("TOPLEFT", parent, "TOPLEFT", xOff, yOff - 38)

    local nameBox = CreateFrame("EditBox", "SlyWAPackNameInput", parent, "InputBoxTemplate")
    nameBox:SetSize(availW - 80, 16)
    nameBox:SetPoint("LEFT", nameLbl, "RIGHT", 4, 0)
    nameBox:SetAutoFocus(false)
    nameBox:SetMaxLetters(64)
    nameBox:SetText(selectedPack or "")
    pasteNameBox = nameBox

    -- Export string text area
    local sf = CreateFrame("ScrollFrame", "SlyWAEditScroll", parent, "UIPanelScrollFrameTemplate")
    sf:SetPoint("TOPLEFT", parent, "TOPLEFT", xOff, yOff - 62)
    sf:SetSize(availW, availH - 100)

    local eb = CreateFrame("EditBox", "SlyWAEditBox", sf)
    eb:SetSize(availW - 28, (availH - 100) * 3)
    eb:SetMultiLine(true)
    eb:SetAutoFocus(false)
    eb:SetFontObject("GameFontNormalSmall")
    eb:SetTextColor(0.9, 1.0, 0.7)
    eb:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)
    sf:SetScrollChild(eb)
    pasteEditBox = eb

    -- Pre-fill with selected pack's string
    if selectedPack and SlyWA.db.packs[selectedPack] then
        eb:SetText(SlyWA.db.packs[selectedPack].auraString or "")
    end

    -- [Store] button
    local storeBtn = CreateFrame("Button", nil, parent, "UIPanelButtonTemplate")
    storeBtn:SetSize(80, 22)
    storeBtn:SetPoint("BOTTOMLEFT", parent, "BOTTOMLEFT", xOff, 6)
    storeBtn:SetText("Store Pack")
    storeBtn:SetScript("OnClick", function()
        local name = strtrim(nameBox:GetText())
        local str  = strtrim(eb:GetText())
        if name == "" or name == "New Pack Name" then
            print("|cff00ccff[SlyWeakAuras]|r Enter a pack name first.")
            return
        end
        SlyWA_StorePack(name, str)
        selectedPack = name
        SlyWA_UIRefreshAll()
    end)
    pasteStoreBtn = storeBtn

    -- [Clear] button
    local clearBtn = CreateFrame("Button", nil, parent, "UIPanelButtonTemplate")
    clearBtn:SetSize(60, 22)
    clearBtn:SetPoint("LEFT", storeBtn, "RIGHT", 4, 0)
    clearBtn:SetText("Clear")
    clearBtn:SetScript("OnClick", function()
        eb:SetText("")
        eb:ClearFocus()
    end)
end

-- -------------------------------------------------------
-- Main UI builder
-- -------------------------------------------------------
function SlyWA_BuildUI()
    if SlyWAFrame then return end

    local f = CreateFrame("Frame", "SlyWAFrame", UIParent)
    f:SetSize(FRAME_W, FRAME_H)
    f:SetFrameStrata("DIALOG")
    f:SetMovable(true)
    f:EnableMouse(true)
    f:RegisterForDrag("LeftButton")
    f:SetScript("OnDragStart", f.StartMoving)
    f:SetScript("OnDragStop",  f.StopMovingOrSizing)
    f:Hide()

    local pos = SlyWA.db.position
    f:ClearAllPoints()
    f:SetPoint(pos.point or "CENTER", UIParent, pos.point or "CENTER",
        pos.x or 200, pos.y or 0)

    -- Backgrounds + border
    FillBg(f, 0.07, 0.07, 0.07, 0.95)
    local bord = f:CreateTexture(nil, "OVERLAY")
    bord:SetAllPoints(f)
    bord:SetColorTexture(0.28, 0.28, 0.28, 1)
    local inner = f:CreateTexture(nil, "BACKGROUND")
    inner:SetPoint("TOPLEFT",     f, "TOPLEFT",      1, -1)
    inner:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", -1,  1)
    inner:SetColorTexture(0.07, 0.07, 0.07, 0.95)

    -- ---- Header ----
    local hdr = CreateFrame("Frame", nil, f)
    hdr:SetSize(FRAME_W, HEADER_H)
    hdr:SetPoint("TOPLEFT", f, "TOPLEFT", 0, 0)
    FillBg(hdr, 0.09, 0.09, 0.14, 1.0)

    local icon = hdr:CreateTexture(nil, "ARTWORK")
    icon:SetSize(18, 18)
    icon:SetPoint("LEFT", hdr, "LEFT", 8, 0)
    icon:SetTexture("Interface\\Icons\\Spell_Holy_MindVision")
    icon:SetTexCoord(0.07, 0.93, 0.07, 0.93)

    local title = hdr:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    title:SetFont(title:GetFont(), 13, "OUTLINE")
    title:SetPoint("LEFT", icon, "RIGHT", 6, 0)
    title:SetText("|cff88aaffSly WeakAuras|r")

    local verLbl = hdr:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    verLbl:SetFont(verLbl:GetFont(), 9, "")
    verLbl:SetPoint("LEFT", title, "RIGHT", 8, 0)
    verLbl:SetText("v" .. SlyWA.version)
    verLbl:SetTextColor(0.4, 0.4, 0.4)

    local closeBtn = CreateFrame("Button", nil, hdr, "UIPanelCloseButton")
    closeBtn:SetSize(24, 24)
    closeBtn:SetPoint("RIGHT", hdr, "RIGHT", -2, 0)
    closeBtn:SetScript("OnClick", function() f:Hide() end)

    -- ---- Status bar (below header) ----
    local statusBar = CreateFrame("Frame", nil, f)
    statusBar:SetSize(FRAME_W, 20)
    statusBar:SetPoint("TOPLEFT", f, "TOPLEFT", 0, -HEADER_H)
    FillBg(statusBar, 0.05, 0.05, 0.1, 1.0)

    statusLine = statusBar:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    statusLine:SetFont(statusLine:GetFont(), 9, "")
    statusLine:SetPoint("LEFT", statusBar, "LEFT", PAD, 0)
    statusLine:SetText("Checking WeakAuras...")

    auraCountLn = statusBar:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    auraCountLn:SetFont(auraCountLn:GetFont(), 9, "")
    auraCountLn:SetPoint("RIGHT", statusBar, "RIGHT", -PAD, 0)
    auraCountLn:SetTextColor(0.5, 0.5, 0.5)

    MkSep(f, FRAME_W, 0, -(HEADER_H + 20))

    local BODY_TOP  = -(HEADER_H + 21)
    local BODY_H    = FRAME_H - HEADER_H - 21

    -- ---- Left column: pack list ----
    local leftPane = CreateFrame("Frame", nil, f)
    leftPane:SetSize(LIST_W, BODY_H)
    leftPane:SetPoint("TOPLEFT", f, "TOPLEFT", 0, BODY_TOP)
    FillBg(leftPane, 0.065, 0.065, 0.065, 1.0)

    local listLbl = MkLabel(leftPane, "Packs", 10, 0.5, 0.7, 1.0)
    listLbl:SetPoint("TOPLEFT", leftPane, "TOPLEFT", 6, -4)

    -- Scroll frame for the pack list
    local listScroll = CreateFrame("ScrollFrame", "SlyWAListScroll", leftPane,
        "UIPanelScrollFrameTemplate")
    listScroll:SetPoint("TOPLEFT",     leftPane, "TOPLEFT",      0, -18)
    listScroll:SetPoint("BOTTOMRIGHT", leftPane, "BOTTOMRIGHT", -16, 30)

    local listContent = CreateFrame("Frame", nil, listScroll)
    listContent:SetSize(LIST_W, 600)
    listScroll:SetScrollChild(listContent)

    -- Pre-build pack list rows
    for i = 1, 24 do
        local row = BuildPackListRow(listContent, i)
        row:SetPoint("TOPLEFT",  listContent, "TOPLEFT",  0, -((i-1) * LIST_ROW_H))
        row:SetPoint("TOPRIGHT", listContent, "TOPRIGHT", 0, -((i-1) * LIST_ROW_H))
    end

    BuildAddPackRow(leftPane, -BODY_H + 26)

    -- ---- Vertical divider ----
    local vdiv = f:CreateTexture(nil, "ARTWORK")
    vdiv:SetSize(1, BODY_H)
    vdiv:SetPoint("TOPLEFT", f, "TOPLEFT", LIST_W, BODY_TOP)
    vdiv:SetColorTexture(0.25, 0.25, 0.25, 1)

    -- ---- Right column: detail + paste ----
    local rightPane = CreateFrame("Frame", nil, f)
    rightPane:SetSize(DETAIL_W, BODY_H)
    rightPane:SetPoint("TOPLEFT", f, "TOPLEFT", LIST_W + 1, BODY_TOP)
    FillBg(rightPane, 0.07, 0.07, 0.07, 1.0)

    -- Pack detail section
    local dOff = -6

    detailName = MkLabel(rightPane, "", 12, 0.88, 0.88, 1.0)
    detailName:SetPoint("TOPLEFT", rightPane, "TOPLEFT", PAD, dOff)
    detailName:SetWidth(DETAIL_W - PAD * 2)
    dOff = dOff - 18

    detailSrc = MkLabel(rightPane, "", 9, 0.5, 0.5, 0.5)
    detailSrc:SetPoint("TOPLEFT", rightPane, "TOPLEFT", PAD, dOff)
    dOff = dOff - 14

    detailDesc = MkLabel(rightPane, "", 9, 0.7, 0.7, 0.7)
    detailDesc:SetPoint("TOPLEFT", rightPane, "TOPLEFT", PAD, dOff)
    detailDesc:SetWidth(DETAIL_W - PAD * 2)
    detailDesc:SetJustifyH("LEFT")
    dOff = dOff - 14

    detailTags = MkLabel(rightPane, "", 8, 0.5, 0.5, 0.5)
    detailTags:SetPoint("TOPLEFT", rightPane, "TOPLEFT", PAD, dOff)
    dOff = dOff - 14

    detailCount = MkLabel(rightPane, "", 9, 0.7, 0.7, 0.7)
    detailCount:SetPoint("TOPLEFT", rightPane, "TOPLEFT", PAD, dOff)
    dOff = dOff - 14

    detailImported = MkLabel(rightPane, "", 8, 0.45, 0.45, 0.45)
    detailImported:SetPoint("TOPLEFT", rightPane, "TOPLEFT", PAD, dOff)
    dOff = dOff - 18

    -- Action buttons row
    MkSep(rightPane, DETAIL_W - PAD * 2, PAD, dOff)
    dOff = dOff - 10

    importBtn = CreateFrame("Button", nil, rightPane, "UIPanelButtonTemplate")
    importBtn:SetSize(100, 22)
    importBtn:SetPoint("TOPLEFT", rightPane, "TOPLEFT", PAD, dOff)
    importBtn:SetText("▶ Import to WA")
    importBtn:SetEnabled(false)
    importBtn:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_TOP")
        GameTooltip:SetText("Import Pack", 1, 1, 1)
        GameTooltip:AddLine(
            "Opens the WeakAuras import dialog with this pack's\n"
            .. "export string. You confirm before any auras are added.",
            0.8, 0.8, 0.8, true)
        GameTooltip:Show()
    end)
    importBtn:SetScript("OnLeave", function() GameTooltip:Hide() end)
    importBtn:SetScript("OnClick", function()
        if selectedPack then SlyWA_ImportPack(selectedPack) end
    end)

    deleteBtn = CreateFrame("Button", nil, rightPane, "UIPanelButtonTemplate")
    deleteBtn:SetSize(70, 22)
    deleteBtn:SetPoint("LEFT", importBtn, "RIGHT", 4, 0)
    deleteBtn:SetText("Delete")
    deleteBtn:SetEnabled(false)
    deleteBtn:SetScript("OnClick", function()
        if not selectedPack then return end
        if SlyWA.db.options.confirmDelete then
            -- Simple confirmation via StaticPopup
            SlyWADeleteTarget = selectedPack
            StaticPopup_Show("SLYWA_CONFIRM_DELETE")
        else
            SlyWA_DeletePack(selectedPack)
            selectedPack = nil
        end
    end)

    -- Confirmation dialog registration (once)
    if not StaticPopupDialogs["SLYWA_CONFIRM_DELETE"] then
        StaticPopupDialogs["SLYWA_CONFIRM_DELETE"] = {
            text          = "Delete pack: |cffffcc00%s|r?",
            button1       = "Delete",
            button2       = "Cancel",
            OnAccept      = function()
                if SlyWADeleteTarget then
                    SlyWA_DeletePack(SlyWADeleteTarget)
                    selectedPack = nil
                    SlyWADeleteTarget = nil
                end
            end,
            OnCancel      = function() SlyWADeleteTarget = nil end,
            timeout       = 0,
            whileDead     = true,
            hideOnEscape  = true,
            showAlert     = true,
        }
    end

    dOff = dOff - 28

    -- Capture row
    BuildCaptureRow(rightPane, PAD, dOff)
    dOff = dOff - 28

    -- Paste panel (takes remaining space)
    local pasteH = BODY_H - (-dOff) - 10
    BuildPastePanel(rightPane, PAD, dOff, DETAIL_W - PAD * 2, pasteH)

    SlyWAFrame = f

    -- Initial data
    SlyWA_UIRefreshStatus()
    SlyWA_UIRefreshAll()
end

-- -------------------------------------------------------
-- Full refresh (pack list + detail)
-- -------------------------------------------------------
function SlyWA_UIRefreshAll()
    if not SlyWAFrame then return end

    SlyWA_UIRefreshStatus()

    local names = SlyWA_GetPackNames()
    for i = 1, 24 do
        RefreshPackListRow(i, names[i])
    end

    RefreshDetailPanel()

    -- Sync paste box with selected pack
    if pasteEditBox then
        local str = selectedPack and SlyWA.db.packs[selectedPack]
                    and SlyWA.db.packs[selectedPack].auraString or ""
        pasteEditBox:SetText(str)
    end
    if pasteNameBox and selectedPack then
        pasteNameBox:SetText(selectedPack)
    end
end
