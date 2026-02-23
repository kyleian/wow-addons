-- ============================================================
-- Sly Suite — SlySuiteUI.lua
-- Main management panel: sub-mod list, status dots, toggle buttons,
-- and an inline error viewer for failed mods.
-- ============================================================

local FRAME_W    = 380
local HEADER_H   = 30
local ROW_H      = 58
local PAD        = 10
local DOT_SIZE   = 12

-- Status dot colors
local DOT_COLOR = {
    [SS.STATUS.OK]       = {0.2,  0.9,  0.2},
    [SS.STATUS.ERROR]    = {0.9,  0.2,  0.2},
    [SS.STATUS.DISABLED] = {0.4,  0.4,  0.4},
    [SS.STATUS.LOADING]  = {1.0,  0.82, 0.0},
}

-- Per-row widget refs keyed by sub-mod name
local rowWidgets = {}  -- [name] = { frame, dot, nameTxt, verTxt, descTxt, toggleBtn, errorBtn }

-- Error viewer state
local errorViewTarget = nil   -- name of sub-mod currently shown in error panel

-- -----------------------------------------------------------------
-- Helpers
-- -----------------------------------------------------------------
local function FillBg(frame, r, g, b, a)
    local t = frame:CreateTexture(nil, "BACKGROUND")
    t:SetAllPoints(frame)
    t:SetColorTexture(r, g, b, a or 1)
    return t
end

local function MakeSep(parent, yOff)
    local t = parent:CreateTexture(nil, "ARTWORK")
    t:SetSize(FRAME_W - PAD * 2, 1)
    t:SetPoint("TOPLEFT", parent, "TOPLEFT", PAD, yOff)
    t:SetColorTexture(0.25, 0.25, 0.25, 1)
    return t
end

-- Invoke a slash command by name (e.g. "/estats") with no args
local function InvokeSlash(slash)
    if not slash or slash == "" then return end
    local upper = slash:lower():gsub("^/",""):gsub("%s.*",""):upper()
    if SlashCmdList[upper] then
        SlashCmdList[upper]("")
    end
end

-- -----------------------------------------------------------------
-- Error viewer panel (child of SlyFrame, shown on demand)
-- -----------------------------------------------------------------
local errorPanel   = nil
local errorText    = nil
local errorTitle   = nil

local function BuildErrorPanel(parent)
    local ep = CreateFrame("Frame", nil, parent)
    ep:SetFrameStrata("FULLSCREEN")
    ep:SetSize(FRAME_W - PAD * 2, 200)
    ep:Hide()

    FillBg(ep, 0.08, 0.02, 0.02, 0.97)
    local bord = ep:CreateTexture(nil, "OVERLAY")
    bord:SetAllPoints(ep)
    bord:SetColorTexture(0.6, 0.1, 0.1, 1)
    local inner = ep:CreateTexture(nil, "BACKGROUND")
    inner:SetPoint("TOPLEFT",     ep, "TOPLEFT",      1, -1)
    inner:SetPoint("BOTTOMRIGHT", ep, "BOTTOMRIGHT", -1,  1)
    inner:SetColorTexture(0.08, 0.02, 0.02, 0.97)

    local hdr = ep:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    hdr:SetFont(hdr:GetFont(), 10, "OUTLINE")
    hdr:SetPoint("TOPLEFT", ep, "TOPLEFT", 6, -4)
    hdr:SetTextColor(1, 0.4, 0.4)
    errorTitle = hdr

    local copyHint = ep:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    copyHint:SetFont(copyHint:GetFont(), 8, "")
    copyHint:SetPoint("TOPRIGHT", ep, "TOPRIGHT", -6, -5)
    copyHint:SetText("(use /sly retry <name> to retry)")
    copyHint:SetTextColor(0.5, 0.5, 0.5)

    -- Scrollable error text
    local sf = CreateFrame("ScrollFrame", "SlySuiteErrorScroll", ep,
        "UIPanelScrollFrameTemplate")
    sf:SetPoint("TOPLEFT",     ep, "TOPLEFT",      6, -20)
    sf:SetPoint("BOTTOMRIGHT", ep, "BOTTOMRIGHT", -24, 4)

    local editBox = CreateFrame("EditBox", nil, sf)
    editBox:SetSize(FRAME_W - PAD * 2 - 30, 600)
    editBox:SetMultiLine(true)
    editBox:SetAutoFocus(false)
    editBox:SetFontObject("GameFontNormalSmall")
    editBox:SetTextColor(1, 0.6, 0.6)
    editBox:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)
    sf:SetScrollChild(editBox)
    errorText = editBox

    -- Close button
    local closeBtn = CreateFrame("Button", nil, ep, "UIPanelCloseButton")
    closeBtn:SetSize(20, 20)
    closeBtn:SetPoint("TOPRIGHT", ep, "TOPRIGHT", 2, 2)
    closeBtn:SetScript("OnClick", function()
        ep:Hide()
        errorViewTarget = nil
    end)

    errorPanel = ep
end

-- Show or hide the error panel for a given sub-mod name
local function ToggleErrorPanel(name, anchorRow)
    if errorViewTarget == name and errorPanel:IsShown() then
        errorPanel:Hide()
        errorViewTarget = nil
        return
    end

    local entry = SS.index[name]
    if not entry or entry.status ~= SS.STATUS.ERROR then
        errorPanel:Hide()
        errorViewTarget = nil
        return
    end

    errorViewTarget = name
    errorTitle:SetText("Error in: " .. name)

    local errMsg = entry.lastError or "Unknown error"
    errorText:SetText(errMsg)

    -- Position below the row that was clicked
    errorPanel:ClearAllPoints()
    errorPanel:SetPoint("TOPLEFT", anchorRow, "BOTTOMLEFT", 0, -2)

    errorPanel:Show()
end

-- -----------------------------------------------------------------
-- Build a single sub-mod row widget (not anchored here)
-- -----------------------------------------------------------------
local function BuildSubModRow(parent, entry)
    local row = CreateFrame("Frame", nil, parent)
    row:SetSize(FRAME_W - PAD * 2, ROW_H)

    FillBg(row, 0.11, 0.11, 0.11, 0.9)

    -- Hover highlight
    row:EnableMouse(true)
    local hl = row:CreateTexture(nil, "HIGHLIGHT")
    hl:SetAllPoints(row)
    hl:SetColorTexture(1, 1, 1, 0.04)

    -- Status dot
    local dot = row:CreateTexture(nil, "ARTWORK")
    dot:SetSize(DOT_SIZE, DOT_SIZE)
    dot:SetPoint("LEFT", row, "LEFT", 8, 0)
    dot:SetColorTexture(0.4, 0.4, 0.4, 1)

    -- Name
    local nameTxt = row:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    nameTxt:SetFont(nameTxt:GetFont(), 12, "")
    nameTxt:SetPoint("TOPLEFT", row, "TOPLEFT", 28, -8)
    nameTxt:SetTextColor(1, 1, 1)
    nameTxt:SetText(entry.name)

    -- Version
    local verTxt = row:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    verTxt:SetFont(verTxt:GetFont(), 9, "")
    verTxt:SetPoint("LEFT", nameTxt, "RIGHT", 6, 0)
    verTxt:SetTextColor(0.5, 0.5, 0.5)
    verTxt:SetText("v" .. entry.version)

    -- Description
    local descTxt = row:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    descTxt:SetFont(descTxt:GetFont(), 9, "")
    descTxt:SetPoint("BOTTOMLEFT", row, "BOTTOMLEFT", 28, 8)
    descTxt:SetTextColor(0.55, 0.55, 0.55)
    descTxt:SetText(entry.description
        .. (entry.slash ~= "" and ("  |cff666666" .. entry.slash .. "|r") or ""))

    -- Open button (launches the sub-mod's slash command)
    local openBtn = CreateFrame("Button", nil, row, "UIPanelButtonTemplate")
    openBtn:SetSize(52, 20)
    openBtn:SetPoint("RIGHT", row, "RIGHT", -78, 6)
    openBtn:SetText("|cffaaddffOpen ▶|r")
    if entry.slash == "" then openBtn:Hide() end
    openBtn:SetScript("OnClick", function()
        InvokeSlash(entry.slash)
    end)

    -- Toggle button (right side)
    local toggleBtn = CreateFrame("Button", nil, row, "UIPanelButtonTemplate")
    toggleBtn:SetSize(62, 20)
    toggleBtn:SetPoint("RIGHT", row, "RIGHT", -8, 6)

    -- Error / details button (shown only on ERROR)
    local errorBtn = CreateFrame("Button", nil, row, "UIPanelButtonTemplate")
    errorBtn:SetSize(62, 20)
    errorBtn:SetPoint("RIGHT", row, "RIGHT", -8, -16)
    errorBtn:SetText("|cffff6666Error ▾|r")
    errorBtn:Hide()
    errorBtn:SetScript("OnClick", function()
        ToggleErrorPanel(entry.name, row)
    end)

    -- Slash link tooltip on name hover
    if entry.slash ~= "" then
        row:SetScript("OnEnter", function(self)
            GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
            GameTooltip:SetText(entry.name, 1, 1, 1)
            GameTooltip:AddLine(entry.description, 0.8, 0.8, 0.8, true)
            if entry.slash ~= "" then
                GameTooltip:AddLine("Slash: " .. entry.slash, 1, 0.82, 0)
            end
            GameTooltip:Show()
        end)
        row:SetScript("OnLeave", function() GameTooltip:Hide() end)
    end

    local widgets = {
        row       = row,
        dot       = dot,
        nameTxt   = nameTxt,
        verTxt    = verTxt,
        descTxt   = descTxt,
        openBtn   = openBtn,
        toggleBtn = toggleBtn,
        errorBtn  = errorBtn,
    }
    rowWidgets[entry.name] = widgets

    -- Wire toggle button (uses closure over widgets)
    toggleBtn:SetScript("OnClick", function()
        local e = SS.index[entry.name]
        if not e then return end
        if e.dbRecord.enabled and e.status ~= SS.STATUS.DISABLED then
            SS_DisableSubMod(entry.name)
        else
            SS_EnableSubMod(entry.name)
        end
        SS_UIRefreshRow(entry.name)
    end)

    return widgets
end

-- -----------------------------------------------------------------
-- Refresh one row's visual state from SS.index
-- -----------------------------------------------------------------
function SS_UIRefreshRow(name)
    local w     = rowWidgets[name]
    local entry = SS.index[name]
    if not w or not entry then return end

    -- Dot color
    local dc = DOT_COLOR[entry.status] or {0.5, 0.5, 0.5}
    w.dot:SetColorTexture(dc[1], dc[2], dc[3], 1)

    -- Toggle button label
    local enabled = entry.dbRecord.enabled and entry.status ~= SS.STATUS.DISABLED
    w.toggleBtn:SetText(enabled and "|cff44ff44ON|r" or "|cffaaaaaa OFF|r")

    -- Error button visibility
    if entry.status == SS.STATUS.ERROR then
        w.errorBtn:Show()
    else
        w.errorBtn:Hide()
        -- Close error panel if it was showing this mod
        if errorViewTarget == name and errorPanel and errorPanel:IsShown() then
            errorPanel:Hide()
            errorViewTarget = nil
        end
    end

    -- Row background tint: slightly red if errored
    if entry.status == SS.STATUS.ERROR then
        w.row:SetAlpha(1.0)
        FillBg(w.row, 0.18, 0.08, 0.08, 0.9)
    elseif entry.status == SS.STATUS.DISABLED then
        w.row:SetAlpha(0.7)
    else
        w.row:SetAlpha(1.0)
    end
end

-- -----------------------------------------------------------------
-- Refresh all rows and resize frame to fit content
-- -----------------------------------------------------------------
function SS_UIRefreshAll()
    if not SlyFrame then return end

    -- Rebuild row anchor positions in case registry changed
    local yOff = -(HEADER_H + 6)
    for i, entry in ipairs(SS.registry) do
        local w = rowWidgets[entry.name]
        if not w then
            -- New entry since last build — create row
            w = BuildSubModRow(SlyContentFrame, entry)
        end
        w.row:ClearAllPoints()
        w.row:SetPoint("TOPLEFT",  SlyContentFrame, "TOPLEFT", PAD, yOff)
        w.row:SetPoint("TOPRIGHT", SlyContentFrame, "TOPRIGHT", -PAD, yOff)
        yOff = yOff - ROW_H - 4
        SS_UIRefreshRow(entry.name)
    end

    -- Footer separator + label
    -- Position error panel anchor correctly
    if errorPanel then
        errorPanel:ClearAllPoints()
        errorPanel:SetPoint("TOPLEFT",  SlyContentFrame, "TOPLEFT", PAD, yOff - 4)
        errorPanel:SetPoint("TOPRIGHT", SlyContentFrame, "TOPRIGHT", -PAD, yOff - 4)
        yOff = errorPanel:IsShown() and (yOff - errorPanel:GetHeight() - 4) or yOff
    end

    -- Footer
    local footerH  = 28
    local totalH   = HEADER_H + (-yOff) + footerH + 6
    totalH = math.max(totalH, HEADER_H + 80)
    SlyFrame:SetHeight(totalH)
end

-- -----------------------------------------------------------------
-- Main frame builder — called from SlySuite.lua after DB init
-- -----------------------------------------------------------------
function SS_BuildUI()
    if SlyFrame then return end

    -- ---- Main frame ----
    local f = CreateFrame("Frame", "SlyFrame", UIParent)
    f:SetWidth(FRAME_W)
    f:SetHeight(200)   -- will be adjusted by SS_UIRefreshAll
    f:SetFrameStrata("DIALOG")
    f:SetMovable(true)
    f:EnableMouse(true)
    f:RegisterForDrag("LeftButton")
    f:SetScript("OnDragStart", f.StartMoving)
    f:SetScript("OnDragStop", function(self)
        self:StopMovingOrSizing()
        local pt, _, _, x, y = self:GetPoint()
        SS.db.position = { point = pt, x = x, y = y }
    end)
    f:Hide()

    local pos = SS.db.position
    f:ClearAllPoints()
    f:SetPoint(pos.point or "CENTER", UIParent, pos.point or "CENTER",
        pos.x or 0, pos.y or 200)

    -- Background
    FillBg(f, 0.07, 0.07, 0.07, 0.95)
    local bord = f:CreateTexture(nil, "OVERLAY")
    bord:SetAllPoints(f)
    bord:SetColorTexture(0.3, 0.3, 0.3, 1)
    local inner = f:CreateTexture(nil, "BACKGROUND")
    inner:SetPoint("TOPLEFT",     f, "TOPLEFT",      1, -1)
    inner:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", -1,  1)
    inner:SetColorTexture(0.07, 0.07, 0.07, 0.95)

    -- ---- Header ----
    local hdr = CreateFrame("Frame", nil, f)
    hdr:SetSize(FRAME_W, HEADER_H)
    hdr:SetPoint("TOPLEFT", f, "TOPLEFT", 0, 0)
    FillBg(hdr, 0.1, 0.1, 0.15, 1.0)

    -- Star icon texture (if available)
    local starIcon = hdr:CreateTexture(nil, "ARTWORK")
    starIcon:SetSize(18, 18)
    starIcon:SetPoint("LEFT", hdr, "LEFT", 8, 0)
    starIcon:SetTexture("Interface\\Icons\\Achievement_GuildPerk_HaveGroupWillTravel")
    starIcon:SetTexCoord(0.07, 0.93, 0.07, 0.93)

    local title = hdr:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    title:SetFont(title:GetFont(), 13, "OUTLINE")
    title:SetPoint("LEFT", starIcon, "RIGHT", 6, 0)
    title:SetText("|cff88aaff✦ Sly Suite|r")

    local verLbl = hdr:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    verLbl:SetFont(verLbl:GetFont(), 9, "")
    verLbl:SetPoint("LEFT", title, "RIGHT", 8, 0)
    verLbl:SetText("v" .. SS.version)
    verLbl:SetTextColor(0.4, 0.4, 0.4)

    -- Close button
    local closeBtn = CreateFrame("Button", nil, hdr, "UIPanelCloseButton")
    closeBtn:SetSize(24, 24)
    closeBtn:SetPoint("RIGHT", hdr, "RIGHT", -2, 0)
    closeBtn:SetScript("OnClick", function() f:Hide() end)

    -- Header separator
    local sep = f:CreateTexture(nil, "ARTWORK")
    sep:SetSize(FRAME_W, 1)
    sep:SetPoint("TOPLEFT", f, "TOPLEFT", 0, -HEADER_H)
    sep:SetColorTexture(0.3, 0.3, 0.3, 1)

    -- ---- Content frame (sub-mod rows live here) ----
    local content = CreateFrame("Frame", "SlyContentFrame", f)
    content:SetPoint("TOPLEFT",  f, "TOPLEFT",  0, 0)
    content:SetPoint("TOPRIGHT", f, "TOPRIGHT", 0, 0)
    content:SetHeight(500)  -- oversized; frame itself is sized by SS_UIRefreshAll

    -- ---- Empty state label (shown when no sub-mods registered) ----
    local emptyLbl = content:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    emptyLbl:SetPoint("CENTER", content, "CENTER", 0, -60)
    emptyLbl:SetText("|cff666666No sub-mods registered yet.|r")
    emptyLbl:SetTextColor(0.4, 0.4, 0.4)

    -- ---- Footer bar ----
    local footer = CreateFrame("Frame", nil, f)
    footer:SetSize(FRAME_W, 24)
    footer:SetPoint("BOTTOM", f, "BOTTOM", 0, 0)
    FillBg(footer, 0.08, 0.08, 0.12, 1)

    local footerHint = footer:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    footerHint:SetFont(footerHint:GetFont(), 8, "")
    footerHint:SetPoint("LEFT", footer, "LEFT", PAD, 0)
    footerHint:SetText("|cff444444/sly status  •  /sly retry <name>  •  /reload|r")

    -- ---- Error panel (built once, shown on demand) ----
    BuildErrorPanel(content)

    SlyContentFrame = content
    SlyFrame        = f
end
