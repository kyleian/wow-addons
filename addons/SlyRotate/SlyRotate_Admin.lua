-- ============================================================
-- SlyRotate_Admin.lua
-- Per-class/spec row configuration panel.
-- Opened via: /slyrotate admin
--
-- Shows all 9 classes as tabs.  Selecting a class shows its
-- specs as buttons.  Each row in that spec gets a checkbox
-- to include/exclude it from the rotation display.
-- ============================================================

local adminFrame = nil

-- Class display config: key, short label, colour
local CLASS_ORDER = {
    { key = "WARRIOR",  label = "Warrior",  short = "WAR", color = {0.78, 0.61, 0.43} },
    { key = "DRUID",    label = "Druid",    short = "DRU", color = {1.00, 0.49, 0.04} },
    { key = "SHAMAN",   label = "Shaman",   short = "SHA", color = {0.00, 0.44, 0.87} },
    { key = "WARLOCK",  label = "Warlock",  short = "WRL", color = {0.58, 0.51, 0.79} },
    { key = "MAGE",     label = "Mage",     short = "MGE", color = {0.41, 0.80, 0.94} },
    { key = "HUNTER",   label = "Hunter",   short = "HUN", color = {0.67, 0.83, 0.45} },
    { key = "ROGUE",    label = "Rogue",    short = "ROG", color = {1.00, 0.96, 0.41} },
    { key = "PALADIN",  label = "Paladin",  short = "PAL", color = {0.96, 0.55, 0.73} },
    { key = "PRIEST",   label = "Priest",   short = "PRI", color = {1.00, 1.00, 1.00} },
}

local SPEC_LABELS = {
    -- Warrior
    FURY = "Fury DPS",  ARMS = "Arms DPS",  PROT = "Prot Tank",
    -- Druid
    CAT  = "Cat DPS",   BEAR = "Bear Tank",
    -- Shaman
    ENHANCE = "Enhancement",  ELEMENTAL = "Elemental",
    -- Warlock
    AFFLICTION = "Affliction",  DESTRUCTION = "Destruction",  DEMONOLOGY = "Demonology",
    -- Mage
    ARCANE = "Arcane",  FIRE = "Fire",  FROST = "Frost",
    -- Hunter
    BM = "Beast Mastery",  MM = "Marksmanship",  SURVIVAL = "Survival",
    -- Rogue
    COMBAT = "Combat",  ASSASSINATION = "Assassination",  SUBTLETY = "Subtlety",
    -- Paladin
    RETRIBUTION = "Retribution",  PROTECTION = "Protection",  HOLY = "Holy",
    -- Priest
    SHADOW = "Shadow",  DISCIPLINE = "Discipline",
}

-- Track which class/spec are currently being viewed
local viewClass = nil
local viewSpec  = nil

-- Refs to dynamic content frames we rebuild on tab change
local specTabsFrame  = nil
local rowListFrame   = nil
local specBtns       = {}
local rowCheckboxes  = {}
local rowFrames      = {}   -- container frames (row BG + all children)

-- ─── Helpers ────────────────────────────────────────────────
local function TC(key)
    if SlyStyle and SlyStyle.Get then
        local c = SlyStyle.Get(key)
        if c then return c[1], c[2], c[3], c[4] or 1 end
    end
    local defaults = {
        frameBg  = {0.05, 0.05, 0.07, 0.97},
        border   = {0.28, 0.28, 0.35, 1},
        headerBg = {0.09, 0.09, 0.14, 1},
        sep      = {0.25, 0.25, 0.32, 1},
    }
    local c = defaults[key] or {0.1, 0.1, 0.1, 1}
    return c[1], c[2], c[3], c[4] or 1
end

local function Col(hex, s) return string.format("|cff%s%s|r", hex, s) end

local function MakeSep(parent, anchorFrame, yOff)
    local sep = parent:CreateTexture(nil, "ARTWORK")
    sep:SetHeight(1)
    sep:SetPoint("TOPLEFT",  parent, "TOPLEFT",   1, yOff)
    sep:SetPoint("TOPRIGHT", parent, "TOPRIGHT",  -1, yOff)
    sep:SetColorTexture(TC("sep"))
    return sep
end

-- ─── Row list population ─────────────────────────────────────
local function PopulateRowList(classKey, specKey)
    -- Clear previous row containers (hides checkboxes, icons, labels)
    for _, rf in ipairs(rowFrames) do rf:Hide() end
    rowFrames      = {}
    rowCheckboxes  = {}

    if not rowListFrame then return end
    rowListFrame:SetHeight(0)

    local mod = SR._modules[classKey]
    if not mod or not mod.specRows then return end

    local rowDefs = mod.specRows[specKey]
    if not rowDefs or #rowDefs == 0 then
        local row = CreateFrame("Frame", nil, rowListFrame)
        row:SetSize(rowListFrame:GetWidth(), 28)
        row:SetPoint("TOPLEFT", rowListFrame, "TOPLEFT", 0, 0)
        local empty = row:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        empty:SetFont(empty:GetFont(), 9, "OUTLINE")
        empty:SetPoint("TOPLEFT", row, "TOPLEFT", 6, -8)
        empty:SetText(Col("555566", "(no rows defined for this spec)"))
        rowFrames[1] = row
        rowListFrame:SetHeight(28)
        return
    end

    -- Ensure DB defaults exist for this spec
    SR.EnsureRowDefaults(classKey, specKey, rowDefs)

    local ROW_H = 28
    local yOff  = 0

    for i, rd in ipairs(rowDefs) do
        local rdLocal = rd
        local ckLocal = classKey
        local skLocal = specKey

        local row = CreateFrame("Frame", nil, rowListFrame)
        row:SetSize(rowListFrame:GetWidth(), ROW_H)
        row:SetPoint("TOPLEFT", rowListFrame, "TOPLEFT", 0, yOff)

        -- Alternating BG
        local rowBg = row:CreateTexture(nil, "BACKGROUND")
        rowBg:SetAllPoints()
        rowBg:SetColorTexture(0, 0, 0, i % 2 == 0 and 0.20 or 0.06)

        -- Checkbox
        local cb = CreateFrame("CheckButton", nil, row, "UICheckButtonTemplate")
        cb:SetSize(22, 22)
        cb:SetPoint("LEFT", row, "LEFT", 4, 0)
        cb:SetChecked(SR.IsRowEnabled(ckLocal, skLocal, rdLocal.key))
        cb:SetScript("OnClick", function(self)
            local v = self:GetChecked()
            SR.db.rows[ckLocal] = SR.db.rows[ckLocal] or {}
            SR.db.rows[ckLocal][skLocal] = SR.db.rows[ckLocal][skLocal] or {}
            SR.db.rows[ckLocal][skLocal][rdLocal.key] = v

            -- Live relayout if this is the currently active module/spec
            local active = SR._active
            if active and active.classKey == ckLocal and active.specRowFrames then
                local frames = active.specRowFrames[skLocal]
                if frames then
                    SR.RelayoutRowFrames(frames, ckLocal, skLocal)
                end
            end
        end)

        -- Icon
        if rdLocal.icon then
            local ico = row:CreateTexture(nil, "ARTWORK")
            ico:SetSize(18, 18)
            ico:SetPoint("LEFT", cb, "RIGHT", 4, 0)
            ico:SetTexture(rdLocal.icon)
            ico:SetTexCoord(0.07, 0.93, 0.07, 0.93)
        end

        -- Label
        local c   = rdLocal.color or {0.7, 0.7, 0.7}
        local hex = string.format("%02x%02x%02x",
            math.floor(c[1]*255), math.floor(c[2]*255), math.floor(c[3]*255))
        local lbl = row:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        lbl:SetFont(lbl:GetFont(), 9, "OUTLINE")
        lbl:SetPoint("LEFT", cb, "RIGHT", 28, 0)
        lbl:SetPoint("RIGHT", row, "RIGHT", -6, 0)
        lbl:SetJustifyH("LEFT")
        lbl:SetText(Col(hex, rdLocal.label))

        rowCheckboxes[i] = cb
        rowFrames[i]     = row
        yOff = yOff - ROW_H
    end

    rowListFrame:SetHeight(math.abs(yOff))
end

-- ─── Spec tabs ───────────────────────────────────────────────
local function PopulateSpecTabs(classKey)
    -- Clear old spec buttons
    for _, btn in ipairs(specBtns) do
        btn:Hide()
        btn:SetParent(nil)
    end
    specBtns = {}

    if not specTabsFrame then return end

    local mod = SR._modules[classKey]
    if not mod or not mod.specRows then return end

    local specs = {}
    for sk in pairs(mod.specRows) do specs[#specs+1] = sk end
    -- Sort specs for consistent order
    table.sort(specs)

    local BTN_W = 100
    local BTN_H = 22
    local xOff  = 0

    for i, sk in ipairs(specs) do
        local skLocal = sk
        local btn = CreateFrame("Button", nil, specTabsFrame)
        btn:SetSize(BTN_W, BTN_H)
        btn:SetPoint("TOPLEFT", specTabsFrame, "TOPLEFT", xOff, 0)

        local bg = btn:CreateTexture(nil, "BACKGROUND")
        bg:SetAllPoints()
        bg:SetColorTexture(0.12, 0.12, 0.18, 1)
        btn._bg = bg

        local lbl = btn:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        lbl:SetFont(lbl:GetFont(), 9, "OUTLINE")
        lbl:SetAllPoints()
        lbl:SetJustifyH("CENTER")
        lbl:SetText(SPEC_LABELS[sk] or sk)
        btn._lbl = lbl

        btn:SetScript("OnClick", function(self)
            viewSpec = skLocal
            -- Highlight active spec btn
            for _, b in ipairs(specBtns) do
                b._bg:SetColorTexture(0.12, 0.12, 0.18, 1)
                b._lbl:SetTextColor(0.65, 0.65, 0.72)
            end
            self._bg:SetColorTexture(0.18, 0.24, 0.36, 1)
            self._lbl:SetTextColor(0.6, 0.8, 1.0)
            PopulateRowList(classKey, skLocal)
        end)

        btn._lbl:SetTextColor(0.65, 0.65, 0.72)
        specBtns[i] = btn
        xOff = xOff + BTN_W + 4
    end

    -- Auto-select first spec
    if specBtns[1] then
        specBtns[1]:Click()
    end
end

-- ─── Class tab selection ─────────────────────────────────────
local classBtns = {}

local function SelectClass(classKey)
    viewClass = classKey
    -- Highlight active class btn
    for _, btn in ipairs(classBtns) do
        btn._bg:SetColorTexture(0.10, 0.10, 0.15, 1)
        btn._lbl:SetTextColor(0.55, 0.55, 0.62)
    end
    for i, info in ipairs(CLASS_ORDER) do
        if info.key == classKey and classBtns[i] then
            local btn = classBtns[i]
            btn._bg:SetColorTexture(
                info.color[1]*0.25, info.color[2]*0.25, info.color[3]*0.25, 1)
            btn._lbl:SetTextColor(
                info.color[1], info.color[2], info.color[3])
        end
    end

    PopulateSpecTabs(classKey)
end

-- ─── Build the panel ─────────────────────────────────────────
function SR.BuildAdminPanel()
    if adminFrame then
        if adminFrame:IsShown() then adminFrame:Hide()
        else adminFrame:Show() end
        return
    end

    local PW    = 380
    local PH    = 380
    local P     = 8
    local HDR_H = 22
    local TABS_H = 26
    local SPEC_H = 26

    local f = CreateFrame("Frame", "SlyRotateAdminFrame", UIParent)
    f:SetSize(PW, PH)
    f:SetFrameStrata("HIGH")
    f:SetMovable(true)
    f:EnableMouse(true)
    f:RegisterForDrag("LeftButton")
    f:SetScript("OnDragStart", f.StartMoving)
    f:SetScript("OnDragStop",  f.StopMovingOrSizing)
    f:SetClampedToScreen(true)
    f:SetPoint("CENTER")

    -- Border + BG
    local bdr = f:CreateTexture(nil, "BACKGROUND")
    bdr:SetAllPoints()
    bdr:SetColorTexture(TC("border"))
    local bg = f:CreateTexture(nil, "BACKGROUND")
    bg:SetPoint("TOPLEFT",     f, "TOPLEFT",      1, -1)
    bg:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", -1,  1)
    bg:SetColorTexture(TC("frameBg"))

    -- Title bar
    local tbar = CreateFrame("Frame", nil, f)
    tbar:SetSize(PW, HDR_H)
    tbar:SetPoint("TOPLEFT", f, "TOPLEFT", 0, 0)
    local tbarBg = tbar:CreateTexture(nil, "BACKGROUND")
    tbarBg:SetAllPoints()
    tbarBg:SetColorTexture(TC("headerBg"))
    local titleTx = tbar:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    titleTx:SetFont(titleTx:GetFont(), 10, "OUTLINE")
    titleTx:SetPoint("LEFT", tbar, "LEFT", 8, 0)
    titleTx:SetText(Col("ffcc66","SLYROTATE") .. "  " .. Col("8899bb","Row Configuration"))
    local closeBtn = CreateFrame("Button", nil, tbar)
    closeBtn:SetSize(16, 16)
    closeBtn:SetPoint("RIGHT", tbar, "RIGHT", -5, 0)
    local closeTx = closeBtn:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    closeTx:SetFont(closeTx:GetFont(), 11, "OUTLINE")
    closeTx:SetAllPoints()
    closeTx:SetJustifyH("CENTER")
    closeTx:SetText(Col("ff4444","x"))
    closeBtn:SetScript("OnClick", function() f:Hide() end)

    MakeSep(f, tbar, -HDR_H)

    -- Class tabs row
    local classTabY = -(HDR_H + 2)
    local classTabsFrame = CreateFrame("Frame", nil, f)
    classTabsFrame:SetSize(PW - 2, TABS_H)
    classTabsFrame:SetPoint("TOPLEFT", f, "TOPLEFT", 1, classTabY)

    local numClasses = #CLASS_ORDER
    local tabW = math.floor((PW - 2 - (numClasses-1)*2) / numClasses)

    classBtns = {}
    for i, info in ipairs(CLASS_ORDER) do
        local infoLocal = info
        local btn = CreateFrame("Button", nil, classTabsFrame)
        btn:SetSize(tabW, TABS_H)
        btn:SetPoint("TOPLEFT", classTabsFrame, "TOPLEFT", (i-1)*(tabW+2), 0)

        local tbg = btn:CreateTexture(nil, "BACKGROUND")
        tbg:SetAllPoints()
        tbg:SetColorTexture(0.10, 0.10, 0.15, 1)
        btn._bg = tbg

        local tlbl = btn:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        tlbl:SetFont(tlbl:GetFont(), 8, "OUTLINE")
        tlbl:SetAllPoints()
        tlbl:SetJustifyH("CENTER")
        tlbl:SetText(info.short)
        tlbl:SetTextColor(0.55, 0.55, 0.62)
        btn._lbl = tlbl

        -- Tooltip with full class name
        btn:SetScript("OnEnter", function(self)
            GameTooltip:SetOwner(self, "ANCHOR_TOP")
            GameTooltip:AddLine(infoLocal.label, 1, 1, 1)
            if not SR._modules[infoLocal.key] then
                GameTooltip:AddLine("(no module loaded)", 0.6, 0.6, 0.6)
            end
            GameTooltip:Show()
        end)
        btn:SetScript("OnLeave", function() GameTooltip:Hide() end)

        btn:SetScript("OnClick", function()
            SelectClass(infoLocal.key)
        end)

        -- Dim if no module
        if not SR._modules[info.key] then
            tlbl:SetTextColor(0.35, 0.35, 0.40)
            btn:SetScript("OnClick", nil)
        end

        classBtns[i] = btn
    end

    MakeSep(f, nil, classTabY - TABS_H - 1)

    -- Spec tabs row
    local specTabY = classTabY - TABS_H - 3
    specTabsFrame = CreateFrame("Frame", nil, f)
    specTabsFrame:SetSize(PW - P*2, SPEC_H)
    specTabsFrame:SetPoint("TOPLEFT", f, "TOPLEFT", P, specTabY)

    MakeSep(f, nil, specTabY - SPEC_H - 1)

    -- Help label
    local helpY = specTabY - SPEC_H - 5
    local helpTx = f:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    helpTx:SetFont(helpTx:GetFont(), 8, "OUTLINE")
    helpTx:SetPoint("TOPLEFT", f, "TOPLEFT", P, helpY)
    helpTx:SetText(Col("555566", "Uncheck rows to hide them from the rotation list."))

    -- Row list scroll area
    local listY = helpY - 14
    local listH = PH - math.abs(listY) - P

    local listContainer = CreateFrame("Frame", nil, f)
    listContainer:SetSize(PW - P*2, listH)
    listContainer:SetPoint("TOPLEFT", f, "TOPLEFT", P, listY)

    rowListFrame = CreateFrame("Frame", nil, listContainer)
    rowListFrame:SetWidth(PW - P*2)
    rowListFrame:SetHeight(listH)
    rowListFrame:SetPoint("TOPLEFT", listContainer, "TOPLEFT", 0, 0)

    adminFrame = f

    -- Auto-select player's class, or first available
    local _, playerClass = UnitClass("player")
    local defaultClass = playerClass
    if not SR._modules[defaultClass] then
        for _, info in ipairs(CLASS_ORDER) do
            if SR._modules[info.key] then defaultClass = info.key; break end
        end
    end

    if defaultClass then SelectClass(defaultClass) end
end
