-- ============================================================
-- Sly Suite -- SlySuiteUI.lua  (Rectangle Panel v3)
-- Full rectangular window: header + left nav + right content.
-- J (or /sly) to open. Click a module name to show its panel.
-- ============================================================

-- Layout constants
local SS_W      = 600    -- total panel width
local NAV_W     = 140    -- left module list width
local NAV_PAD   = 6      -- padding inside nav items
local HDR_H     = 28     -- header bar height
local FOOT_H    = 22     -- footer bar height
local SS_H      = 440    -- total panel height
local NAV_ROW_H = 34     -- height per nav module button
local CON_PAD   = 10     -- padding in content area

-- Private state
local _activeModule = nil
local _navBtns      = {}
local _pages        = {}
local _pgFrame      = nil
local _navCont      = nil
local _contentTitle = nil

-- Helpers -------------------------------------------------------
local function FillBg(f, r, g, b, a)
    local t = f:CreateTexture(nil, "BACKGROUND")
    t:SetAllPoints() ; t:SetColorTexture(r, g, b, a or 1)
    return t
end

-- Settings page -------------------------------------------------
local _settingsContent = nil

local function RebuildSettingsList()
    if not _settingsContent then return end
    for _, c in pairs({_settingsContent:GetChildren()}) do c:Hide() ; c:SetParent(nil) end
    local ROW_H = 52
    local PAD   = 6
    local yOff  = 0
    for _, entry in ipairs(SS.registry) do
        local row = CreateFrame("Frame", nil, _settingsContent)
        row:SetPoint("TOPLEFT",  _settingsContent, "TOPLEFT",  0, yOff)
        row:SetPoint("TOPRIGHT", _settingsContent, "TOPRIGHT", 0, yOff)
        row:SetHeight(ROW_H)
        FillBg(row, 0.07, 0.06, 0.10, 1)
        local dot = row:CreateTexture(nil, "OVERLAY")
        dot:SetSize(9, 9) ; dot:SetPoint("LEFT", row, "LEFT", PAD, 0)
        local s = entry.status
        local dc = (s == SS.STATUS.OK      and {0.2, 0.9, 0.2})
               or  (s == SS.STATUS.ERROR   and {0.9, 0.2, 0.2})
               or  (s == SS.STATUS.LOADING and {1.0, 0.82, 0.0})
               or  {0.4, 0.4, 0.4}
        dot:SetColorTexture(dc[1], dc[2], dc[3], 1)
        local iconTx = row:CreateTexture(nil, "ARTWORK")
        iconTx:SetSize(20, 20) ; iconTx:SetPoint("LEFT", row, "LEFT", PAD + 14, 0)
        iconTx:SetTexture(entry.icon or "Interface\\Icons\\INV_Misc_QuestionMark")
        iconTx:SetTexCoord(0.08, 0.92, 0.08, 0.92)
        local nameTx = row:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        nameTx:SetFont(nameTx:GetFont(), 10, "")
        nameTx:SetPoint("TOPLEFT", row, "TOPLEFT", PAD + 40, -7)
        nameTx:SetTextColor(s == SS.STATUS.DISABLED and 0.5 or 0.90,
                            s == SS.STATUS.DISABLED and 0.5 or 0.90,
                            s == SS.STATUS.DISABLED and 0.5 or 0.95)
        nameTx:SetText(entry.name)
        local verTx = row:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        verTx:SetFont(verTx:GetFont(), 8, "")
        verTx:SetPoint("LEFT", nameTx, "RIGHT", 4, 0)
        verTx:SetTextColor(0.38, 0.38, 0.48) ; verTx:SetText("v" .. entry.version)
        local descTx = row:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        descTx:SetFont(descTx:GetFont(), 8, "")
        descTx:SetPoint("TOPLEFT", row, "TOPLEFT", PAD + 40, -22)
        descTx:SetWidth(SS_W - NAV_W - 2 - CON_PAD * 2 - PAD * 2 - 60)
        descTx:SetJustifyH("LEFT")
        descTx:SetTextColor(0.40, 0.40, 0.52) ; descTx:SetText(entry.description)
        local toggleBtn = CreateFrame("Button", nil, row, "UIPanelButtonTemplate")
        toggleBtn:SetSize(50, 16) ; toggleBtn:SetPoint("RIGHT", row, "RIGHT", -PAD, 0)
        local en = (entry.status ~= SS.STATUS.DISABLED)
        toggleBtn:SetText(en and "|cff44ff44ON|r" or "|cffaaaaaa OFF|r")
        local capName = entry.name
        toggleBtn:SetScript("OnClick", function()
            if entry.status == SS.STATUS.DISABLED then SS_EnableSubMod(capName)
            else SS_DisableSubMod(capName) end
            RebuildSettingsList()
        end)
        local sep = row:CreateTexture(nil, "ARTWORK")
        sep:SetHeight(1)
        sep:SetPoint("BOTTOMLEFT",  row, "BOTTOMLEFT")
        sep:SetPoint("BOTTOMRIGHT", row, "BOTTOMRIGHT")
        sep:SetColorTexture(0.14, 0.12, 0.20, 1)
        yOff = yOff - (ROW_H + 1)
    end
    _settingsContent:SetHeight(math.max(-yOff, 10))
end

local function BuildSettingsPage(pg)
    local title = pg:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    title:SetFont(title:GetFont(), 11, "OUTLINE")
    title:SetPoint("TOPLEFT", pg, "TOPLEFT", CON_PAD, -CON_PAD)
    title:SetText("|cff8899ffSly Suite|r  |cff444455Sub-modules|r")
    local sf = CreateFrame("ScrollFrame", nil, pg, "UIPanelScrollFrameTemplate")
    sf:SetPoint("TOPLEFT",     pg, "TOPLEFT",      0,   -(CON_PAD + 16))
    sf:SetPoint("BOTTOMRIGHT", pg, "BOTTOMRIGHT", -22,   CON_PAD)
    local cont = CreateFrame("Frame", nil, sf)
    cont:SetWidth(SS_W - NAV_W - 2 - CON_PAD * 2 - 22)
    sf:SetScrollChild(cont)
    _settingsContent = cont
    RebuildSettingsList()
end

-- Module page display -------------------------------------------
local function ShowModule(name, entry)
    for _, nb in ipairs(_navBtns) do
        local act = (nb.name == name)
        if nb.selBar then nb.selBar:SetShown(act) end
        if nb.bg     then nb.bg:SetColorTexture(act and 0.10 or 0.04, act and 0.09 or 0.03, act and 0.18 or 0.08, 1) end
        if nb.lbl    then nb.lbl:SetTextColor(act and 0.92 or 0.55, act and 0.88 or 0.55, act and 1.00 or 0.62) end
    end
    _activeModule = name
    for _, pg in pairs(_pages) do pg:Hide() end
    if not _pages[name] then
        local pg = CreateFrame("Frame", nil, _pgFrame)
        pg:SetAllPoints(_pgFrame) ; pg:Hide()
        _pages[name] = pg
        if name == "_settings" then
            BuildSettingsPage(pg)
        elseif entry and entry.contentFn then
            local ok, err = xpcall(
                function() entry.contentFn(pg, _pgFrame:GetWidth(), _pgFrame:GetHeight()) end,
                function(e) return tostring(e) .. "\n" .. debugstack(2, 8, 3) end)
            if not ok then
                local et = pg:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
                et:SetAllPoints() ; et:SetJustifyH("CENTER") ; et:SetJustifyV("MIDDLE")
                et:SetText("|cffff4444Error building module:\n|r" .. tostring(err))
                if SS_LogError then SS_LogError(name, err) end
            end
        elseif entry and entry.launchFn then
            if entry.description and entry.description ~= "" then
                local desc = pg:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
                desc:SetPoint("TOP", pg, "TOP", 0, -CON_PAD * 3)
                desc:SetWidth(SS_W - NAV_W - 2 - CON_PAD * 4) ; desc:SetJustifyH("CENTER")
                desc:SetTextColor(0.5, 0.5, 0.6) ; desc:SetText(entry.description)
            end
            local btn = CreateFrame("Button", nil, pg, "UIPanelButtonTemplate")
            btn:SetSize(SS_W - NAV_W - 2 - CON_PAD * 6, 28)
            btn:SetPoint("TOP", pg, "TOP", 0, -CON_PAD * 7)
            btn:SetText("Open " .. entry.name)
            btn:SetScript("OnClick", function() entry.launchFn() end)
        else
            local et = pg:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
            et:SetAllPoints() ; et:SetJustifyH("CENTER") ; et:SetJustifyV("MIDDLE")
            et:SetTextColor(0.4, 0.4, 0.5) ; et:SetText("No content for\n" .. name)
        end
    end
    _pages[name]:Show()
    if _contentTitle then
        _contentTitle:SetText(entry and entry.name or (name == "_settings" and "Settings" or name))
    end
end

-- Nav list build ------------------------------------------------
local function BuildNavList()
    for _, nb in ipairs(_navBtns) do
        if nb.btn then nb.btn:Hide() ; nb.btn:SetParent(nil) end
    end
    wipe(_navBtns)
    local yOff = 0
    local function MakeNavBtn(icon, name, entry)
        local btn = CreateFrame("Button", nil, _navCont)
        btn:SetHeight(NAV_ROW_H)
        btn:SetPoint("TOPLEFT",  _navCont, "TOPLEFT",  0, yOff)
        btn:SetPoint("TOPRIGHT", _navCont, "TOPRIGHT", 0, yOff)
        btn:EnableMouse(true) ; btn:RegisterForClicks("LeftButtonUp")
        local isActive = (_activeModule == name)
        local bg = btn:CreateTexture(nil, "BACKGROUND")
        bg:SetAllPoints()
        bg:SetColorTexture(isActive and 0.10 or 0.04, isActive and 0.09 or 0.03, isActive and 0.18 or 0.08, 1)
        local hl = btn:CreateTexture(nil, "HIGHLIGHT")
        hl:SetAllPoints() ; hl:SetColorTexture(1, 1, 1, 0.07)
        local selBar = btn:CreateTexture(nil, "OVERLAY")
        selBar:SetSize(3, NAV_ROW_H - 8) ; selBar:SetPoint("LEFT", btn, "LEFT", 0, 0)
        selBar:SetColorTexture(0.50, 0.40, 0.90, 1) ; selBar:SetShown(isActive)
        if icon and icon ~= "" then
            local icTx = btn:CreateTexture(nil, "ARTWORK")
            icTx:SetSize(18, 18) ; icTx:SetPoint("LEFT", btn, "LEFT", NAV_PAD + 5, 0)
            icTx:SetTexture(icon) ; icTx:SetTexCoord(0.07, 0.93, 0.07, 0.93)
        end
        local lbl = btn:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        lbl:SetFont(lbl:GetFont(), 10, "")
        lbl:SetPoint("LEFT",  btn, "LEFT",  NAV_PAD + 28, 0)
        lbl:SetPoint("RIGHT", btn, "RIGHT", -NAV_PAD,     0)
        lbl:SetJustifyH("LEFT")
        lbl:SetTextColor(isActive and 0.92 or 0.55, isActive and 0.88 or 0.55, isActive and 1.00 or 0.62)
        lbl:SetText(name == "_settings" and "Settings" or name)
        local rsep = btn:CreateTexture(nil, "ARTWORK")
        rsep:SetHeight(1)
        rsep:SetPoint("BOTTOMLEFT",  btn, "BOTTOMLEFT",  0, 0)
        rsep:SetPoint("BOTTOMRIGHT", btn, "BOTTOMRIGHT", 0, 0)
        rsep:SetColorTexture(0.10, 0.09, 0.16, 1)
        local capName = name ; local capEntry = entry
        btn:SetScript("OnClick", function() ShowModule(capName, capEntry) end)
        btn:SetScript("OnEnter", function(b)
            bg:SetColorTexture(0.14, 0.12, 0.24, 1)
            GameTooltip:SetOwner(b, "ANCHOR_RIGHT")
            GameTooltip:SetText(capName == "_settings" and "Settings" or capName, 1, 1, 1)
            local d = capEntry and capEntry.description or ""
            if d ~= "" then GameTooltip:AddLine(d, 0.67, 0.67, 0.67, true) end
            GameTooltip:Show()
        end)
        btn:SetScript("OnLeave", function()
            local act = (_activeModule == name)
            bg:SetColorTexture(act and 0.10 or 0.04, act and 0.09 or 0.03, act and 0.18 or 0.08, 1)
            GameTooltip:Hide()
        end)
        table.insert(_navBtns, {btn=btn, bg=bg, lbl=lbl, selBar=selBar, name=name})
        yOff = yOff - (NAV_ROW_H + 1)
    end
    MakeNavBtn("Interface\\Icons\\INV_Misc_Gear_01", "_settings", nil)
    for _, entry in ipairs(SS.registry) do
        MakeNavBtn(entry.icon or "", entry.name, entry)
    end
    _navCont:SetHeight(math.max(math.abs(yOff), 10))
end

-- SS_BuildUI ----------------------------------------------------
function SS_BuildUI()
    if SlyFrame then return end

    local f = CreateFrame("Frame", "SlyFrame", UIParent)
    f:SetSize(SS_W, SS_H)
    f:SetFrameStrata("HIGH") ; f:SetFrameLevel(50)
    f:SetMovable(true) ; f:SetClampedToScreen(true) ; f:Hide()

    local pos = SS.db and SS.db.position
    if pos and pos.point then
        f:SetPoint(pos.point, UIParent, pos.point, pos.x or 0, pos.y or 0)
    else
        f:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
    end
    SlyFrame = f
    tinsert(UISpecialFrames, "SlyFrame")

    -- Outer border + inner fill
    local bord = f:CreateTexture(nil, "BORDER")
    bord:SetAllPoints() ; bord:SetColorTexture(0.22, 0.20, 0.32, 1)
    local bgFill = f:CreateTexture(nil, "BACKGROUND")
    bgFill:SetPoint("TOPLEFT",     f, "TOPLEFT",      1, -1)
    bgFill:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", -1,  1)
    bgFill:SetColorTexture(0.05, 0.04, 0.09, 0.97)

    -- Header bar
    local hdr = CreateFrame("Frame", nil, f)
    hdr:SetHeight(HDR_H)
    hdr:SetPoint("TOPLEFT",  f, "TOPLEFT",  0, 0)
    hdr:SetPoint("TOPRIGHT", f, "TOPRIGHT", 0, 0)
    FillBg(hdr, 0.08, 0.07, 0.15, 1)
    local hdrSep = f:CreateTexture(nil, "ARTWORK")
    hdrSep:SetHeight(1)
    hdrSep:SetPoint("TOPLEFT",  f, "TOPLEFT",  0, -HDR_H)
    hdrSep:SetPoint("TOPRIGHT", f, "TOPRIGHT", 0, -HDR_H)
    hdrSep:SetColorTexture(0.22, 0.19, 0.34, 1)

    local titleTx = hdr:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    titleTx:SetFont(titleTx:GetFont(), 13, "OUTLINE")
    titleTx:SetPoint("LEFT", hdr, "LEFT", 10, 0)
    titleTx:SetText("|cffaa99ffSly|r|cff8877ddSuite|r")

    hdr:EnableMouse(true) ; hdr:RegisterForDrag("LeftButton")
    hdr:SetScript("OnDragStart", function() f:StartMoving() end)
    hdr:SetScript("OnDragStop", function()
        f:StopMovingOrSizing()
        local pt, _, _, x, y = f:GetPoint()
        if SS.db then SS.db.position = {point = pt or "CENTER", x = x or 0, y = y or 0} end
    end)

    -- Close button
    local closeBtn = CreateFrame("Button", nil, hdr)
    closeBtn:SetSize(22, 22) ; closeBtn:SetPoint("RIGHT", hdr, "RIGHT", -4, 0)
    closeBtn:EnableMouse(true) ; closeBtn:RegisterForClicks("LeftButtonUp")
    local clBg = closeBtn:CreateTexture(nil, "BACKGROUND") ; clBg:SetAllPoints() ; clBg:SetColorTexture(0,0,0,0)
    local clHl = closeBtn:CreateTexture(nil, "HIGHLIGHT")  ; clHl:SetAllPoints() ; clHl:SetColorTexture(0.9,0.2,0.2,0.35)
    local clTx = closeBtn:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    clTx:SetFont(clTx:GetFont(), 14, "OUTLINE") ; clTx:SetAllPoints()
    clTx:SetJustifyH("CENTER") ; clTx:SetJustifyV("MIDDLE")
    clTx:SetText("\195\151") ; clTx:SetTextColor(0.75, 0.28, 0.28)
    closeBtn:SetScript("OnClick",  function() f:Hide() end)
    closeBtn:SetScript("OnEnter",  function() clBg:SetColorTexture(0.6,0.1,0.1,0.4) end)
    closeBtn:SetScript("OnLeave",  function() clBg:SetColorTexture(0,0,0,0) end)

    -- Footer bar
    local foot = CreateFrame("Frame", nil, f)
    foot:SetHeight(FOOT_H)
    foot:SetPoint("BOTTOMLEFT",  f, "BOTTOMLEFT",  0, 0)
    foot:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", 0, 0)
    FillBg(foot, 0.06, 0.05, 0.11, 1)
    local footSep = f:CreateTexture(nil, "ARTWORK")
    footSep:SetHeight(1)
    footSep:SetPoint("BOTTOMLEFT",  f, "BOTTOMLEFT",  0, FOOT_H)
    footSep:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", 0, FOOT_H)
    footSep:SetColorTexture(0.18, 0.16, 0.28, 1)
    local footTx = foot:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    footTx:SetFont(footTx:GetFont(), 9, "")
    footTx:SetPoint("LEFT", foot, "LEFT", 10, 0)
    footTx:SetTextColor(0.35, 0.33, 0.50)
    footTx:SetText("J  or  /sly  to toggle")

    -- Left nav column
    local navCol = CreateFrame("Frame", nil, f)
    navCol:SetWidth(NAV_W)
    navCol:SetPoint("TOPLEFT",    f, "TOPLEFT",    0, -(HDR_H + 1))
    navCol:SetPoint("BOTTOMLEFT", f, "BOTTOMLEFT", 0,   FOOT_H + 1)
    FillBg(navCol, 0.04, 0.03, 0.07, 1)

    -- Vertical divider between nav and content
    local navDiv = f:CreateTexture(nil, "ARTWORK")
    navDiv:SetWidth(1)
    navDiv:SetPoint("TOPLEFT",    f, "TOPLEFT",    NAV_W, -(HDR_H + 1))
    navDiv:SetPoint("BOTTOMLEFT", f, "BOTTOMLEFT", NAV_W,   FOOT_H + 1)
    navDiv:SetColorTexture(0.20, 0.18, 0.30, 1)

    -- Scrollable nav rows
    local navSF = CreateFrame("ScrollFrame", nil, navCol, "UIPanelScrollFrameTemplate")
    navSF:SetPoint("TOPLEFT",     navCol, "TOPLEFT",      0,   0)
    navSF:SetPoint("BOTTOMRIGHT", navCol, "BOTTOMRIGHT", -16,  0)
    local navContFrame = CreateFrame("Frame", nil, navSF)
    navContFrame:SetWidth(NAV_W - 16)
    navSF:SetScrollChild(navContFrame)
    _navCont = navContFrame

    -- Right content panel
    local cp = CreateFrame("Frame", nil, f)
    cp:SetPoint("TOPLEFT",     f, "TOPLEFT",     NAV_W + 2, -(HDR_H + 1))
    cp:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", 0,           FOOT_H + 1)

    -- Content sub-header (module name)
    local conHdr = CreateFrame("Frame", nil, cp)
    conHdr:SetHeight(26)
    conHdr:SetPoint("TOPLEFT",  cp, "TOPLEFT",  0, 0)
    conHdr:SetPoint("TOPRIGHT", cp, "TOPRIGHT", 0, 0)
    FillBg(conHdr, 0.07, 0.06, 0.12, 1)
    local conHdrSep = cp:CreateTexture(nil, "ARTWORK")
    conHdrSep:SetHeight(1)
    conHdrSep:SetPoint("TOPLEFT",  conHdr, "BOTTOMLEFT")
    conHdrSep:SetPoint("TOPRIGHT", conHdr, "BOTTOMRIGHT")
    conHdrSep:SetColorTexture(0.18, 0.16, 0.28, 1)
    _contentTitle = conHdr:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    _contentTitle:SetFont(_contentTitle:GetFont(), 11, "OUTLINE")
    _contentTitle:SetPoint("LEFT", conHdr, "LEFT", CON_PAD, 0)
    _contentTitle:SetTextColor(0.78, 0.72, 1.00) ; _contentTitle:SetText("")

    -- Page parent frame
    local pgf = CreateFrame("Frame", nil, cp)
    pgf:SetPoint("TOPLEFT",     cp, "TOPLEFT",     CON_PAD, -(26 + CON_PAD))
    pgf:SetPoint("BOTTOMRIGHT", cp, "BOTTOMRIGHT", -CON_PAD, CON_PAD)
    _pgFrame = pgf

    -- Initial state: open Settings
    BuildNavList()
    ShowModule("_settings", nil)

    SS_UIRefreshAll = function()
        if not SlyFrame then return end
        BuildNavList()
        if _activeModule == "_settings" then RebuildSettingsList() end
    end
    SS_UIRefreshRow = function(_name)
        if not SlyFrame then return end
        BuildNavList()
    end
end

-- SS_ToggleUI  --  called by J keybind and /sly
function SS_ToggleUI()
    if not SlyFrame then SS_BuildUI() end
    if SlyFrame:IsShown() then
        SlyFrame:Hide()
    else
        SS_UIRefreshAll()
        SlyFrame:Show()
    end
end
