-- ============================================================
-- SlyRotate  v1.0.0
-- Standalone rotation advisor suite for TBC Anniversary.
--
-- Each class is a separate module file (SlyRotate_Warrior.lua
-- etc.) that calls SR.RegisterModule() at load time.  The core
-- here provides shared helpers, the outer frame shell, the
-- spotlight frame, the config panel, and the tick / event loops.
--
-- /slyrotate              toggle show/hide
-- /slyrotate lock         lock both frames in place
-- /slyrotate unlock       allow dragging
-- /slyrotate reset        move to default position
-- /slyrotate spot         toggle spotlight box
-- /slyrotate combat       toggle combat-only mode
-- /slyrotate config       open the class/spec settings panel
-- ============================================================

local ADDON_NAME = "SlyRotate"
local VERSION    = "1.3.0"

-- ─── Public namespace ───────────────────────────────────────
-- Modules are loaded after this file (per .toc order) and call
-- SR.RegisterModule("CLASSNAME", module) at file scope.
SR          = SR or {}
SR._version = VERSION
SR._modules = {}   -- [classKey] = moduleTable
SR._active  = nil  -- module matching the logged-in character

-- ─── DB defaults ────────────────────────────────────────────
local DB_DEFAULTS = {
    rows = {},   -- [classKey][specKey][rowKey] = true/false
    locked       = false,
    shown        = true,
    combatOnly   = false,
    spotShown    = true,
    position     = { point = "CENTER", x = 280, y = 0 },
    spotPosition = { point = "CENTER", x = 0,   y = -150 },
    classes = {
        WARRIOR = {
            enabled   = true,
            showSunder = true,
            specs     = { FURY = true, ARMS = true, PROT = true },
        },
        DRUID = {
            enabled = true,
            specs   = { CAT = true, BEAR = true },
        },
        SHAMAN = {
            enabled = true,
            specs   = { ENHANCE = true, ELEMENTAL = true },
        },
        WARLOCK = {
            enabled = true,
            specs   = { AFFLICTION = true, DESTRUCTION = true, DEMONOLOGY = true },
        },
        MAGE = {
            enabled = true,
            specs   = { ARCANE = true, FIRE = true, FROST = true },
        },
        HUNTER = {
            enabled = true,
            specs   = { BM = true, MM = true, SURVIVAL = true },
        },
        ROGUE = {
            enabled = true,
            specs   = { COMBAT = true, ASSASSINATION = true, SUBTLETY = true },
        },
        PALADIN = {
            enabled = true,
            specs   = { RETRIBUTION = true, PROTECTION = true, HOLY = true },
        },
        PRIEST = {
            enabled = true,
            specs   = { SHADOW = true, HOLY = true, DISCIPLINE = true },
        },
    },
}

local function ApplyDefaults(dest, src)
    for k, v in pairs(src) do
        if dest[k] == nil then
            dest[k] = type(v) == "table" and {} or v
        end
        if type(v) == "table" and type(dest[k]) == "table" then
            ApplyDefaults(dest[k], v)
        end
    end
end

-- ─── Row enable/disable helpers ─────────────────────────────
-- Returns true if a specific row key is enabled for the given class/spec.
-- Defaults to true if no explicit entry exists in the DB.
function SR.IsRowEnabled(classKey, specKey, rowKey)
    local db = SR.db
    if not db or not db.rows then return true end
    local cls = db.rows[classKey]
    if not cls then return true end
    local sp = cls[specKey]
    if not sp then return true end
    local v = sp[rowKey]
    return v ~= false
end

-- Populate any missing row-enable entries as true for a given spec.
function SR.EnsureRowDefaults(classKey, specKey, rowDefs)
    local db = SR.db
    if not db then return end
    db.rows = db.rows or {}
    db.rows[classKey] = db.rows[classKey] or {}
    db.rows[classKey][specKey] = db.rows[classKey][specKey] or {}
    local sp = db.rows[classKey][specKey]
    for _, rd in ipairs(rowDefs) do
        if sp[rd.key] == nil then sp[rd.key] = true end
    end
end

-- Hide disabled rows, show enabled rows, and re-index positions.
-- Returns visible row count.
function SR.RelayoutRowFrames(frames, classKey, specKey)
    if not frames then return 0 end
    local RH  = SR.ROW_H
    local Col = SR.Col
    local vis = 0
    for _, row in ipairs(frames) do
        local key     = row.rowDef and row.rowDef.key
        local enabled = (not key) or SR.IsRowEnabled(classKey, specKey, key)
        if enabled then
            vis = vis + 1
            row:ClearAllPoints()
            row:SetPoint("TOPLEFT", row:GetParent(), "TOPLEFT", 0, -(vis-1)*(RH+1))
            row.bg:SetColorTexture(0, 0, 0, vis % 2 == 0 and 0.18 or 0.05)
            row.num:SetText(Col("444455", tostring(vis)))
            row:Show()
        else
            row:Hide()
        end
    end
    return vis
end

-- ─── Module registration ─────────────────────────────────────
-- Called by each module file before ADDON_LOADED fires:
--   SR.RegisterModule("WARRIOR", { ... })
function SR.RegisterModule(classKey, t)
    t.classKey = classKey
    SR._modules[classKey] = t
end

-- ─── Layout constants (shared with modules) ──────────────────
local FRAME_W  = 220
local HDR_H    = 18
local ROW_H    = 22
local PAD      = 5
local STATUS_W = 72
local SPOT_W   = 220
local SPOT_H   = 68

SR.FRAME_W  = FRAME_W
SR.HDR_H    = HDR_H
SR.ROW_H    = ROW_H
SR.PAD      = PAD
SR.STATUS_W = STATUS_W

-- ─── Theme helper ────────────────────────────────────────────
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

SR.TC = TC

-- ─── Shared utilities ────────────────────────────────────────
local function Col(hex, s)  return string.format("|cff%s%s|r", hex, s) end
local function Fmt(secs)
    if secs <= 0 then return "" end
    if secs >= 10 then return string.format("%.0fs", secs) end
    return string.format("%.1fs", secs)
end
local function SpellCD(name)
    local start, dur = GetSpellCooldown(name)
    if dur and dur > 1.5 then return math.max(0, start + dur - GetTime()) end
    return 0
end

SR.Col     = Col
SR.Fmt     = Fmt
SR.SpellCD = SpellCD

-- ─── Shared row builder ──────────────────────────────────────
-- rowDef must have: key, label, icon, color={r,g,b}
-- rowDef._idx must be set by the caller before invoking.
function SR.BuildRow(parent, rowDef, idx)
    local row = CreateFrame("Frame", nil, parent)
    row:SetSize(FRAME_W, ROW_H)
    row:SetPoint("TOPLEFT", parent, "TOPLEFT", 0, -(idx - 1) * (ROW_H + 1))

    local bg = row:CreateTexture(nil, "BACKGROUND")
    bg:SetAllPoints()
    bg:SetColorTexture(0, 0, 0, idx % 2 == 0 and 0.18 or 0.05)
    row.bg = bg

    local glow = row:CreateTexture(nil, "BORDER")
    glow:SetAllPoints()
    glow:SetColorTexture(rowDef.color[1], rowDef.color[2], rowDef.color[3], 0)
    row.glow = glow

    local num = row:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    num:SetFont(num:GetFont(), 7, "OUTLINE")
    num:SetPoint("LEFT", row, "LEFT", 2, 0)
    num:SetWidth(10)
    num:SetJustifyH("CENTER")
    num:SetText(Col("444455", tostring(idx)))
    row.num = num

    local icon = row:CreateTexture(nil, "ARTWORK")
    icon:SetSize(ROW_H - 6, ROW_H - 6)
    icon:SetPoint("LEFT", row, "LEFT", 14, 0)
    icon:SetTexture(rowDef.icon)
    icon:SetTexCoord(0.07, 0.93, 0.07, 0.93)
    icon:SetAlpha(0.40)
    row.icon = icon

    local lbl = row:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    lbl:SetFont(lbl:GetFont(), 9, "OUTLINE")
    lbl:SetPoint("LEFT", row, "LEFT", 34, 0)
    lbl:SetWidth(FRAME_W - 34 - STATUS_W - PAD)
    lbl:SetJustifyH("LEFT")
    lbl:SetText(rowDef.label)
    lbl:SetTextColor(0.38, 0.38, 0.42)
    row.lbl = lbl

    local status = row:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    status:SetFont(status:GetFont(), 9, "OUTLINE")
    status:SetPoint("RIGHT", row, "RIGHT", -PAD, 0)
    status:SetWidth(STATUS_W)
    status:SetJustifyH("RIGHT")
    status:SetText("")
    row.status = status

    row.rowDef = rowDef
    return row
end

function SR.SetRowState(row, active, statusStr)
    local c = row.rowDef.color
    if active then
        row.glow:SetColorTexture(c[1], c[2], c[3], 0.25)
        row.bg:SetColorTexture(c[1] * 0.10, c[2] * 0.10, c[3] * 0.10, 1)
        row.icon:SetAlpha(1.00)
        row.lbl:SetTextColor(c[1], c[2], c[3])
        row.num:SetText(Col("ffee55", ">"))
    else
        row.glow:SetColorTexture(0, 0, 0, 0)
        local idx = row.rowDef._idx or 1
        row.bg:SetColorTexture(0, 0, 0, idx % 2 == 0 and 0.18 or 0.05)
        row.icon:SetAlpha(0.35)
        row.lbl:SetTextColor(0.35, 0.35, 0.40)
        row.num:SetText(Col("333344", tostring(idx)))
    end
    row.status:SetText(statusStr or "")
end

-- ─── Frame references ────────────────────────────────────────
local mainFrame   = nil
local modeLabel   = nil
local spotFrame   = nil
local spotIcon    = nil
local spotName    = nil
local spotSub     = nil
local configFrame = nil

function SR.SetModeLabel(text)
    if modeLabel then modeLabel:SetText(text or "") end
end

-- ─── Main frame ──────────────────────────────────────────────
local function BuildMainFrame()
    if mainFrame then return end
    local mod = SR._active
    if not mod then return end

    local bodyH  = mod:GetBodyHeight(ROW_H)
    local FRAME_H = HDR_H + 2 + bodyH + 4

    local pos = SR.db.position
    local f = CreateFrame("Frame", "SlyRotateFrame", UIParent)
    f:SetSize(FRAME_W, FRAME_H)
    f:SetFrameStrata("MEDIUM")
    f:SetMovable(true)
    f:EnableMouse(false)
    f:SetClampedToScreen(true)
    f:ClearAllPoints()
    f:SetPoint(pos.point or "CENTER", UIParent, pos.point or "CENTER",
               pos.x or 280, pos.y or 0)

    local border = f:CreateTexture(nil, "BACKGROUND")
    border:SetAllPoints()
    border:SetColorTexture(TC("border"))

    local bg = f:CreateTexture(nil, "BACKGROUND")
    bg:SetPoint("TOPLEFT",     f, "TOPLEFT",      1, -1)
    bg:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", -1,  1)
    bg:SetColorTexture(TC("frameBg"))

    local hdr = CreateFrame("Frame", nil, f)
    hdr:SetSize(FRAME_W, HDR_H)
    hdr:SetPoint("TOPLEFT", f, "TOPLEFT", 0, 0)

    local hdrBg = hdr:CreateTexture(nil, "BACKGROUND")
    hdrBg:SetAllPoints()
    hdrBg:SetColorTexture(TC("headerBg"))

    local hdrIcon = hdr:CreateTexture(nil, "ARTWORK")
    hdrIcon:SetSize(14, 14)
    hdrIcon:SetPoint("LEFT", hdr, "LEFT", 4, 0)
    hdrIcon:SetTexture(mod.headerIcon or "Interface\\Icons\\Ability_Warrior_Bloodthirst")
    hdrIcon:SetTexCoord(0.07, 0.93, 0.07, 0.93)

    local titleTx = hdr:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    titleTx:SetFont(titleTx:GetFont(), 9, "OUTLINE")
    titleTx:SetPoint("LEFT", hdrIcon, "RIGHT", 4, 0)
    titleTx:SetText(mod:GetHeaderText())

    modeLabel = hdr:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    modeLabel:SetFont(modeLabel:GetFont(), 9, "OUTLINE")
    modeLabel:SetPoint("RIGHT", hdr, "RIGHT", -5, 0)
    modeLabel:SetText(Col("444455", "---"))

    local sep = f:CreateTexture(nil, "ARTWORK")
    sep:SetSize(FRAME_W - 2, 1)
    sep:SetPoint("TOPLEFT", f, "TOPLEFT", 1, -HDR_H)
    sep:SetColorTexture(TC("sep"))

    local body = CreateFrame("Frame", nil, f)
    body:SetSize(FRAME_W, bodyH)
    body:SetPoint("TOPLEFT", f, "TOPLEFT", 0, -(HDR_H + 2))

    SR._bodyFrame = body
    mod:Build(body)

    local drag = CreateFrame("Frame", nil, f)
    drag:SetAllPoints()
    drag:EnableMouse(true)
    drag:RegisterForDrag("LeftButton")
    drag:SetScript("OnDragStart", function()
        if not SR.db.locked then f:StartMoving() end
    end)
    drag:SetScript("OnDragStop", function()
        f:StopMovingOrSizing()
        local pt, _, _, x, y = f:GetPoint()
        SR.db.position = { point = pt or "CENTER", x = x or 0, y = y or 0 }
    end)

    mainFrame = f
    SR._mainFrame = f
    if not SR.db.shown then f:Hide() end

    if SlyStyle and SlyStyle.OnThemeChange then
        SlyStyle.OnThemeChange(function()
            border:SetColorTexture(TC("border"))
            bg:SetColorTexture(TC("frameBg"))
            hdrBg:SetColorTexture(TC("headerBg"))
            sep:SetColorTexture(TC("sep"))
        end)
    end
end

-- ─── Spotlight ───────────────────────────────────────────────
local function BuildSpotlight()
    if spotFrame then return end
    local sp = SR.db.spotPosition or { point = "CENTER", x = 0, y = -150 }
    local f  = CreateFrame("Frame", "SlyRotateSpot", UIParent)
    f:SetSize(SPOT_W, SPOT_H)
    f:SetFrameStrata("MEDIUM")
    f:SetMovable(true)
    f:SetClampedToScreen(true)
    f:SetPoint(sp.point or "CENTER", UIParent, sp.point or "CENTER", sp.x or 0, sp.y or -150)
    f:EnableMouse(true)
    f:RegisterForDrag("LeftButton")
    f:SetScript("OnDragStart", function()
        if not SR.db.locked then f:StartMoving() end
    end)
    f:SetScript("OnDragStop", function()
        f:StopMovingOrSizing()
        local pt, _, _, x, y = f:GetPoint()
        SR.db.spotPosition = { point = pt or "CENTER", x = x or 0, y = y or 0 }
    end)

    local bdr = f:CreateTexture(nil, "BACKGROUND")
    bdr:SetAllPoints()
    bdr:SetColorTexture(0.28, 0.28, 0.35, 1)
    f._bdr = bdr

    local inner = f:CreateTexture(nil, "BORDER")
    inner:SetPoint("TOPLEFT",     f, "TOPLEFT",      1, -1)
    inner:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", -1,  1)
    inner:SetColorTexture(0.04, 0.04, 0.07, 0.94)

    local ico = f:CreateTexture(nil, "ARTWORK")
    ico:SetSize(52, 52)
    ico:SetPoint("LEFT", f, "LEFT", 8, 0)
    ico:SetTexCoord(0.07, 0.93, 0.07, 0.93)
    spotIcon = ico

    local nm = f:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    nm:SetFont(nm:GetFont(), 15, "OUTLINE")
    nm:SetPoint("TOPLEFT", ico, "TOPRIGHT", 8, -4)
    nm:SetPoint("RIGHT",   f,   "RIGHT",   -6, 0)
    nm:SetJustifyH("LEFT")
    nm:SetWordWrap(false)
    nm:SetText(Col("888888", "--"))
    spotName = nm

    local sub = f:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    sub:SetFont(sub:GetFont(), 10, "OUTLINE")
    sub:SetPoint("BOTTOMLEFT", ico, "BOTTOMRIGHT", 8, 4)
    sub:SetPoint("RIGHT",      f,   "RIGHT",      -6, 0)
    sub:SetJustifyH("LEFT")
    sub:SetText("")
    spotSub = sub

    local tag = f:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    tag:SetFont(tag:GetFont(), 8, "OUTLINE")
    tag:SetPoint("TOPLEFT", f, "TOPLEFT", 4, -3)
    tag:SetText(Col("556655", "NEXT"))

    spotFrame = f
    if SR.db.spotShown == false then f:Hide() end
end

function SR.UpdateSpotlight(rows, activeKey, statusStr)
    if not spotFrame or not spotFrame:IsShown() then return end
    if not activeKey or not rows then
        if spotName then spotName:SetText(Col("888888", "--")) end
        if spotSub  then spotSub:SetText("") end
        if spotIcon then spotIcon:SetTexture(nil) end
        return
    end
    local rd
    for _, r in ipairs(rows) do
        if r.key == activeKey then rd = r; break end
    end
    if not rd then
        if spotName then spotName:SetText(Col("888888", "--")) end
        if spotSub  then spotSub:SetText("") end
        if spotIcon then spotIcon:SetTexture(nil) end
        return
    end
    local c   = rd.color
    local hex = string.format("%02x%02x%02x",
        math.floor(c[1]*255), math.floor(c[2]*255), math.floor(c[3]*255))
    spotName:SetText(Col(hex, rd.label))
    spotIcon:SetTexture(rd.icon)
    spotSub:SetText(statusStr or "")
    if spotFrame._bdr then
        spotFrame._bdr:SetColorTexture(c[1]*0.6, c[2]*0.6, c[3]*0.6, 0.95)
    end
end

-- ─── Config panel ────────────────────────────────────────────
-- Panel structure:
--   [x] Combat only       [x] Spotlight
--   ── Classes ──
--   [x] Warrior      [x] Fury DPS  [x] Arms DPS  [x] Prot Tank
--                    [x] Show Sunder row
--   [x] Druid        [x] Cat DPS   [x] Bear Tank
--   [x] Shaman       [x] Enhancement  [x] Elemental
local function BuildConfigPanel()
    if configFrame then
        if configFrame:IsShown() then configFrame:Hide()
        else configFrame:Show() end
        return
    end

    local PW  = 260
    local LH  = 22
    local P   = 10
    local TITLE_H = 22

    -- Determine height dynamically
    local classOrder = { "WARRIOR", "DRUID", "SHAMAN", "WARLOCK", "MAGE", "HUNTER", "ROGUE", "PALADIN", "PRIEST" }
    local specOrder  = {
        WARRIOR  = { "FURY", "ARMS", "PROT" },
        DRUID    = { "CAT", "BEAR" },
        SHAMAN   = { "ENHANCE", "ELEMENTAL" },
        WARLOCK  = { "AFFLICTION", "DESTRUCTION", "DEMONOLOGY" },
        MAGE     = { "ARCANE", "FIRE", "FROST" },
        HUNTER   = { "BM", "MM", "SURVIVAL" },
        ROGUE    = { "COMBAT", "ASSASSINATION", "SUBTLETY" },
        PALADIN  = { "RETRIBUTION", "PROTECTION", "HOLY" },
        PRIEST   = { "SHADOW", "HOLY", "DISCIPLINE" },
    }
    local specLabel  = {
        FURY="Fury DPS", ARMS="Arms DPS", PROT="Prot Tank",
        CAT="Cat DPS", BEAR="Bear Tank",
        ENHANCE="Enhancement", ELEMENTAL="Elemental",
        AFFLICTION="Affliction", DESTRUCTION="Destruction", DEMONOLOGY="Demonology",
        ARCANE="Arcane", FIRE="Fire", FROST="Frost",
        BM="Beast Mastery", MM="Marksmanship", SURVIVAL="Survival",
        COMBAT="Combat", ASSASSINATION="Assassination", SUBTLETY="Subtlety",
        RETRIBUTION="Retribution", PROTECTION="Protection", HOLY="Holy",
        SHADOW="Shadow", DISCIPLINE="Discipline",
    }
    local classLabel = {
        WARRIOR="Warrior", DRUID="Druid (Feral)", SHAMAN="Shaman",
        WARLOCK="Warlock", MAGE="Mage", HUNTER="Hunter",
        ROGUE="Rogue", PALADIN="Paladin", PRIEST="Priest",
    }

    local totalLines = 3  -- combat-only, spotlight, "Classes" separator
    for _, ck in ipairs(classOrder) do
        if SR._modules[ck] then
            totalLines = totalLines + 1  -- class row
            if specOrder[ck] then
                totalLines = totalLines + math.ceil(#specOrder[ck] / 3)
            end
            -- Warrior gets an extra "Show Sunder" line
            if ck == "WARRIOR" then totalLines = totalLines + 1 end
        end
    end

    local PH = TITLE_H + P + totalLines * LH + P

    local f = CreateFrame("Frame", "SlyRotateConfigFrame", UIParent)
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
    tbar:SetSize(PW, TITLE_H)
    tbar:SetPoint("TOPLEFT", f, "TOPLEFT", 0, 0)
    local tbarBg = tbar:CreateTexture(nil, "BACKGROUND")
    tbarBg:SetAllPoints()
    tbarBg:SetColorTexture(TC("headerBg"))
    local titleTx = tbar:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    titleTx:SetFont(titleTx:GetFont(), 10, "OUTLINE")
    titleTx:SetPoint("LEFT", tbar, "LEFT", 8, 0)
    titleTx:SetText(Col("ffcc66", "SLYROTATE") .. "  " .. Col("666677", "Settings"))
    local closeBtn = CreateFrame("Button", nil, tbar)
    closeBtn:SetSize(16, 16)
    closeBtn:SetPoint("RIGHT", tbar, "RIGHT", -5, 0)
    local closeTx = closeBtn:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    closeTx:SetFont(closeTx:GetFont(), 11, "OUTLINE")
    closeTx:SetAllPoints()
    closeTx:SetJustifyH("CENTER")
    closeTx:SetText(Col("ff4444", "x"))
    closeBtn:SetScript("OnClick", function() f:Hide() end)

    -- Content area
    local content = CreateFrame("Frame", nil, f)
    content:SetPoint("TOPLEFT",     f, "TOPLEFT",      P, -(TITLE_H + P))
    content:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", -P,   P)

    local yOff = 0  -- current Y offset from TOPLEFT of content (negative = down)

    -- Helper: make a checkbox at current yOff, advances yOff by LH
    local function MakeCheck(label, getVal, setVal, indent)
        local cb = CreateFrame("CheckButton", nil, content, "UICheckButtonTemplate")
        cb:SetSize(20, 20)
        cb:SetPoint("TOPLEFT", content, "TOPLEFT", (indent or 0), yOff - 1)
        yOff = yOff - LH

        -- UICheckButtonTemplate provides .text fontstring
        if cb.text then
            cb.text:SetText(label)
            cb.text:SetTextColor(0.78, 0.78, 0.78)
        end

        cb:SetChecked(getVal() ~= false)
        cb:SetScript("OnClick", function(self)
            setVal(self:GetChecked())
        end)
        return cb
    end

    -- Helper: section label
    local function MakeLabel(text)
        local tx = content:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        tx:SetFont(tx:GetFont(), 9, "OUTLINE")
        tx:SetPoint("TOPLEFT", content, "TOPLEFT", 0, yOff)
        tx:SetText(text)
        yOff = yOff - LH
    end

    -- Top options
    MakeCheck("Combat only (hide outside combat)",
        function() return SR.db.combatOnly end,
        function(v)
            SR.db.combatOnly = v
            if v and not InCombatLockdown() then
                if mainFrame then mainFrame:Hide() end
                if spotFrame then spotFrame:Hide() end
            elseif not v then
                if SR.db.shown and mainFrame then mainFrame:Show() end
                if SR.db.spotShown and spotFrame then spotFrame:Show() end
            end
        end)

    MakeCheck("Spotlight box (center-screen NEXT action)",
        function() return SR.db.spotShown end,
        function(v)
            SR.db.spotShown = v
            if spotFrame then
                if v then spotFrame:Show() else spotFrame:Hide() end
            end
        end)

    MakeLabel(Col("666677", "── Classes ──"))

    for _, ck in ipairs(classOrder) do
        if SR._modules[ck] then
            local ckLocal = ck
            -- Class row
            MakeCheck(classLabel[ck] or ck,
                function()
                    local c = SR.db.classes[ckLocal]
                    return c and c.enabled ~= false
                end,
                function(v)
                    if SR.db.classes[ckLocal] then
                        SR.db.classes[ckLocal].enabled = v
                    end
                end)

            -- Spec rows (indented)
            if specOrder[ck] then
                for _, sk in ipairs(specOrder[ck]) do
                    local skLocal = sk
                    MakeCheck(specLabel[sk] or sk,
                        function()
                            local c = SR.db.classes[ckLocal]
                            return c and c.specs and c.specs[skLocal] ~= false
                        end,
                        function(v)
                            local c = SR.db.classes[ckLocal]
                            if c and c.specs then c.specs[skLocal] = v end
                        end,
                        20)
                end
            end

            -- Warrior-specific: Sunder toggle
            if ck == "WARRIOR" then
                MakeCheck("Show Sunder Armor row",
                    function()
                        local c = SR.db.classes.WARRIOR
                        return c and c.showSunder ~= false
                    end,
                    function(v)
                        if SR.db.classes.WARRIOR then
                            SR.db.classes.WARRIOR.showSunder = v
                            local mod = SR._modules.WARRIOR
                            if mod and mod.RefreshSunderRows then
                                mod:RefreshSunderRows()
                            end
                        end
                    end,
                    20)
            end
        end
    end

    configFrame = f
end

-- ─── Event registration helper ───────────────────────────────
local evtFrame = CreateFrame("Frame")

function SR.RegisterEvent(event)
    evtFrame:RegisterEvent(event)
end

-- Core events always registered
evtFrame:RegisterEvent("PLAYER_TARGET_CHANGED")
evtFrame:RegisterEvent("UNIT_AURA")
evtFrame:RegisterEvent("PLAYER_REGEN_DISABLED")
evtFrame:RegisterEvent("PLAYER_REGEN_ENABLED")
evtFrame:RegisterEvent("PLAYER_LOGOUT")

evtFrame:SetScript("OnEvent", function(self, event, arg1, arg2, arg3)
    -- Forward to active module first
    local mod = SR._active
    if mod and mod.OnEvent then
        mod:OnEvent(event, arg1, arg2, arg3)
    end

    -- Core logic
    if event == "PLAYER_REGEN_DISABLED" then
        if SR.db and SR.db.combatOnly and SR.db.shown then
            if mainFrame then mainFrame:Show() end
            if spotFrame and SR.db.spotShown then spotFrame:Show() end
        end

    elseif event == "PLAYER_REGEN_ENABLED" then
        if SR.db and SR.db.combatOnly then
            if mainFrame then mainFrame:Hide() end
            if spotFrame then spotFrame:Hide() end
        end

    elseif event == "PLAYER_LOGOUT" then
        if mainFrame and SR.db then
            local pt, _, _, x, y = mainFrame:GetPoint()
            SR.db.position = { point = pt or "CENTER", x = x or 0, y = y or 0 }
            SR.db.shown    = mainFrame:IsShown()
        end
        if spotFrame and SR.db then
            local pt, _, _, x, y = spotFrame:GetPoint()
            SR.db.spotPosition = { point = pt or "CENTER", x = x or 0, y = y or 0 }
            SR.db.spotShown    = spotFrame:IsShown()
        end
    end
end)

-- ─── Tick (50 ms) ────────────────────────────────────────────
local tickFrame = CreateFrame("Frame")
local tickAcc   = 0
tickFrame:SetScript("OnUpdate", function(self, dt)
    tickAcc = tickAcc + dt
    if tickAcc < 0.05 then return end
    tickAcc = 0
    if not mainFrame or not mainFrame:IsShown() then return end
    local mod = SR._active
    if not mod then return end
    local classDb = SR.db.classes[mod.classKey]
    if classDb and classDb.enabled == false then return end
    mod:Update(GetTime(), SR.db)
end)

-- ─── Slash commands ──────────────────────────────────────────
local function SetupSlashCmd()
    SLASH_SLYROTATE1 = "/slyrotate"
    SlashCmdList["SLYROTATE"] = function(msg)
        msg = strtrim((msg or ""):lower())

        if msg == "lock" then
            SR.db.locked = true
            DEFAULT_CHAT_FRAME:AddMessage(Col("88ff88", "[SlyRotate]") .. " Locked.")

        elseif msg == "unlock" then
            SR.db.locked = false
            DEFAULT_CHAT_FRAME:AddMessage(Col("88ff88", "[SlyRotate]") .. " Unlocked.")

        elseif msg == "reset" then
            SR.db.position = { point = "CENTER", x = 280, y = 0 }
            if mainFrame then
                mainFrame:ClearAllPoints()
                mainFrame:SetPoint("CENTER", UIParent, "CENTER", 280, 0)
            end
            DEFAULT_CHAT_FRAME:AddMessage(Col("88ff88", "[SlyRotate]") .. " Position reset.")

        elseif msg == "spot" then
            if not spotFrame then BuildSpotlight() end
            if spotFrame:IsShown() then
                spotFrame:Hide(); SR.db.spotShown = false
                DEFAULT_CHAT_FRAME:AddMessage(Col("88ff88", "[SlyRotate]") .. " Spotlight hidden.")
            else
                spotFrame:Show(); SR.db.spotShown = true
                DEFAULT_CHAT_FRAME:AddMessage(Col("88ff88", "[SlyRotate]") .. " Spotlight shown.")
            end

        elseif msg == "combat" then
            SR.db.combatOnly = not SR.db.combatOnly
            if SR.db.combatOnly then
                DEFAULT_CHAT_FRAME:AddMessage(
                    Col("88ff88", "[SlyRotate]") .. " Combat-only: " .. Col("ff4444", "ON"))
                if not InCombatLockdown() then
                    if mainFrame then mainFrame:Hide() end
                    if spotFrame then spotFrame:Hide() end
                end
            else
                DEFAULT_CHAT_FRAME:AddMessage(
                    Col("88ff88", "[SlyRotate]") .. " Combat-only: " .. Col("44ff44", "OFF"))
                if SR.db.shown and mainFrame then mainFrame:Show() end
                if SR.db.spotShown and spotFrame then spotFrame:Show() end
            end

        elseif msg == "config" then
            BuildConfigPanel()

        elseif msg == "admin" then
            if SR.BuildAdminPanel then SR.BuildAdminPanel()
            else DEFAULT_CHAT_FRAME:AddMessage(Col("88ff88","[SlyRotate]") .. " Admin module not loaded.") end

        else
            -- Toggle show/hide
            if not mainFrame then
                if SR._active then
                    BuildMainFrame()
                    BuildSpotlight()
                else
                    DEFAULT_CHAT_FRAME:AddMessage(
                        Col("88ff88", "[SlyRotate]") .. " No module for your class. " ..
                        Col("ffcc00", "/slyrotate config") .. " to manage.")
                    return
                end
            end
            if mainFrame:IsShown() then
                mainFrame:Hide(); SR.db.shown = false
            else
                mainFrame:Show(); SR.db.shown = true
            end
        end
    end
end

-- ─── Init ────────────────────────────────────────────────────
local function Init()
    local _, classFile = UnitClass("player")

    SlyRotateDB = SlyRotateDB or {}
    ApplyDefaults(SlyRotateDB, DB_DEFAULTS)
    SR.db = SlyRotateDB

    SetupSlashCmd()

    SR._active = SR._modules[classFile]

    if not SR._active then
        DEFAULT_CHAT_FRAME:AddMessage(
            Col("88ff88", "[SlyRotate]") .. " v" .. VERSION ..
            " loaded. No rotation module for " .. (classFile or "?") ..
            ". |cffffcc00/slyrotate config|r")
        return
    end

    local classDb = SR.db.classes[classFile]
    if classDb and classDb.enabled == false then
        DEFAULT_CHAT_FRAME:AddMessage(
            Col("88ff88", "[SlyRotate]") .. " v" .. VERSION ..
            " — " .. classFile .. " disabled. |cffffcc00/slyrotate config|r to enable.")
        return
    end

    if SR._active.RegisterEvents then SR._active:RegisterEvents() end

    -- ScanAll must run first so spec-dependent modules know their spec
    -- before GetBodyHeight() and Build() are called by BuildMainFrame().
    if SR._active.ScanAll then SR._active:ScanAll() end

    BuildMainFrame()
    BuildSpotlight()

    if SR.db.combatOnly and not InCombatLockdown() then
        if mainFrame then mainFrame:Hide() end
        if spotFrame then spotFrame:Hide() end
    end

    DEFAULT_CHAT_FRAME:AddMessage(
        Col("88ff88", "[SlyRotate]") .. " v" .. VERSION ..
        " — " .. (SR._active.classLabel or classFile) ..
        " rotation loaded. |cffffcc00/slyrotate|r toggle · |cffffcc00/slyrotate config|r settings.")
end

-- ─── Boot ────────────────────────────────────────────────────
local bootFrame = CreateFrame("Frame")
bootFrame:RegisterEvent("ADDON_LOADED")
bootFrame:SetScript("OnEvent", function(self, event, name)
    if name ~= ADDON_NAME then return end
    self:UnregisterEvent("ADDON_LOADED")
    Init()
end)
