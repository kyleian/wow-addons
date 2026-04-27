-- ============================================================
-- SlySuite_ProcTracker
-- Tracks Dragonstrike / Mongoose / Dragonspine Trophy procs
-- per fight (auto-reset on each new combat) and per session.
--
-- /slyptoc           toggle show/hide
-- /slyptoc lock      lock in place
-- /slyptoc unlock    allow dragging
-- /slyptoc reset     clear session totals and fight cache
-- /slyptoc pos       reset position to default
-- /slyptoc debug     dump all current player buff names
-- /slyptoc watch     log all buff names for 60s into SavedVariables
-- ============================================================

local ADDON_NAME = "SlySuite_ProcTracker"
local VERSION    = "1.5.1"

-- UnitBuff (TBC 2.5.x, no rank field):
--   name(1) icon(2) count(3) debuffType(4) duration(5)
--   expiration(6) caster(7) isStealable(8) shouldConsolidate(9) spellId(10)
-- spellId is NOT available in this build (returns nil/false).
-- DS and DST both create a buff named "Haste"; they can coexist as
-- two distinct buff slots. We count Haste slots per scan — each +1
-- is one proc. DST credited first (if equipped), DS for remainder.
-- Mongoose uses unique name "Lightning Speed" — simple rising-edge.

local DST_ITEM_ID = 28830

local PROCS = {
    { key = "ds",  label = "Dragonstrike", icon = "Interface\\Icons\\inv_mace_39"                   },
    { key = "mg",  label = "Mongoose",     icon = "Interface\\Icons\\spell_nature_unrelentingstorm" },
    { key = "dst", label = "DST",          icon = "Interface\\Icons\\inv_misc_bone_03"              },
}

local PT = {}
PT.db = nil

local inCombat    = false
local fightStart  = 0
local isBossFlag  = false
local bossName    = ""
local instName    = ""

local fightCounts     = { ds = 0, mg = 0, dst = 0, trinity = 0 }
local sessionCounts   = { ds = 0, mg = 0, dst = 0, trinity = 0 }  -- since login/reload, not persisted
local prevHasteCount  = 0   -- ds slot count from last scan
local prevHasteCount2 = 0   -- dst slot count from last scan
local prevMgPresent   = false
local prevTrinityActive = false
local dstEquipped     = false

local MAX_HISTORY = 30

local DB_DEFAULTS = {
    locked   = false,
    shown    = true,
    position = { point = "CENTER", x = 220, y = 0 },
    alltime  = { ds = 0, mg = 0, dst = 0, trinity = 0 },
    history  = {},
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

local function FormatDuration(secs)
    secs = math.floor(secs)
    return string.format("%d:%02d", math.floor(secs / 60), secs % 60)
end

local function CheckDSTEquipped()
    local foundNotNil = false
    for slot = 1, 19 do
        local link = GetInventoryItemLink("player", slot)
        if link then
            foundNotNil = true
            local id = tonumber(link:match("item:(%d+)"))
            if id == DST_ITEM_ID then
                dstEquipped = true
                return
            end
        end
    end
    if foundNotNil then dstEquipped = false end
end

local function GetCurrentInstance()
    local name = GetRealZoneText()
    if name and name ~= "" then return name end
    return GetZoneText() or "Unknown"
end

-- UI ─────────────────────────────────────────────────────────
local W        = 280
local TITLE_H  = 16
local COLHDR_H = 16
local ROW_H    = 18
local ROW_PAD  = 2
local PAD      = 4
local FOOT_H   = 16
local FRAME_H  = TITLE_H + COLHDR_H + 1 + #PROCS * (ROW_H + ROW_PAD) + 1 + (ROW_H + ROW_PAD) + 1 + FOOT_H + 4

-- Three right-aligned columns: ALL TIME | SESSION | FIGHT (rightmost)
local COL_ALL_W   = 46
local COL_SESS_W  = 42
local COL_FIGHT_W = 38
local COL_GAP     = 2
local OFF_ALL     = PAD
local OFF_SESS    = PAD + COL_ALL_W + COL_GAP
local OFF_FIGHT   = PAD + COL_ALL_W + COL_GAP + COL_SESS_W + COL_GAP

local mainFrame  = nil
local rowWidgets = {}
local footLabel  = nil

local function BuildUI()
    if mainFrame then return end
    local f = CreateFrame("Frame", "SlyProcTrackerFrame", UIParent)
    f:SetSize(W, FRAME_H)
    f:SetMovable(true)
    f:EnableMouse(true)
    f:RegisterForDrag("LeftButton")
    f:SetFrameStrata("HIGH")
    f:SetClampedToScreen(true)

    local pos = PT.db.position
    f:ClearAllPoints()
    f:SetPoint(pos.point or "CENTER", UIParent, pos.point or "CENTER", pos.x or 220, pos.y or 0)

    f:SetScript("OnDragStart", function(self)
        if not PT.db.locked then self:StartMoving() end
    end)
    f:SetScript("OnDragStop", function(self)
        self:StopMovingOrSizing()
        local pt, _, _, x, y = self:GetPoint()
        PT.db.position = { point = pt or "CENTER", x = x or 220, y = y or 0 }
    end)

    local border = f:CreateTexture(nil, "BACKGROUND")
    border:SetAllPoints()
    border:SetColorTexture(0.20, 0.20, 0.30, 1)

    local bg = f:CreateTexture(nil, "BACKGROUND")
    bg:SetPoint("TOPLEFT",     f, "TOPLEFT",      1, -1)
    bg:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", -1,  1)
    bg:SetColorTexture(0.02, 0.02, 0.04, 1.0)

    local tbar = f:CreateTexture(nil, "ARTWORK")
    tbar:SetPoint("TOPLEFT",  f, "TOPLEFT",  2, -2)
    tbar:SetPoint("TOPRIGHT", f, "TOPRIGHT", -2, -2)
    tbar:SetHeight(TITLE_H)
    tbar:SetColorTexture(0.08, 0.08, 0.13, 1)

    local title = f:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    title:SetFont(title:GetFont(), 10, "OUTLINE")
    title:SetPoint("LEFT", f, "TOPLEFT", 6, -TITLE_H/2)
    title:SetText("|cff00ccffSly|rProcs")

    local cBtn = CreateFrame("Button", nil, f, "UIPanelCloseButton")
    cBtn:SetSize(16, 16)
    cBtn:SetPoint("TOPRIGHT", f, "TOPRIGHT", -2, -1)
    cBtn:SetScript("OnClick", function() f:Hide(); PT.db.shown = false end)

    local rBtn = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
    rBtn:SetSize(40, 13)
    rBtn:SetPoint("RIGHT", cBtn, "LEFT", -2, 0)
    rBtn:SetText("Reset")
    rBtn:SetScript("OnClick", function()
        if PT.db then
            PT.db.alltime = { ds = 0, mg = 0, dst = 0, trinity = 0 }
            PT.db.history = {}
            sessionCounts = { ds = 0, mg = 0, dst = 0, trinity = 0 }
            fightCounts   = { ds = 0, mg = 0, dst = 0, trinity = 0 }
            PT.UpdateDisplay()
            DEFAULT_CHAT_FRAME:AddMessage("|cff88bbff[ProcTracker]|r All totals cleared.")
        end
    end)

    local colTop = -(TITLE_H + 2)
    local colBg = f:CreateTexture(nil, "ARTWORK")
    colBg:SetPoint("TOPLEFT",  f, "TOPLEFT",   2, colTop)
    colBg:SetPoint("TOPRIGHT", f, "TOPRIGHT", -2, colTop)
    colBg:SetHeight(COLHDR_H)
    colBg:SetColorTexture(0.08, 0.08, 0.13, 1)

    local colF = f:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    colF:SetFont(colF:GetFont(), 8, "OUTLINE")
    colF:SetPoint("TOPRIGHT", f, "TOPRIGHT", -(OFF_FIGHT), colTop - 2)
    colF:SetWidth(COL_FIGHT_W)
    colF:SetHeight(COLHDR_H)
    colF:SetJustifyH("RIGHT")
    colF:SetTextColor(0.55, 0.55, 0.65)
    colF:SetText("FIGHT")

    local colS = f:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    colS:SetFont(colS:GetFont(), 8, "OUTLINE")
    colS:SetPoint("TOPRIGHT", f, "TOPRIGHT", -(OFF_SESS), colTop - 2)
    colS:SetWidth(COL_SESS_W)
    colS:SetHeight(COLHDR_H)
    colS:SetJustifyH("RIGHT")
    colS:SetTextColor(0.55, 0.55, 0.65)
    colS:SetText("SESSION")

    local colA = f:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    colA:SetFont(colA:GetFont(), 8, "OUTLINE")
    colA:SetPoint("TOPRIGHT", f, "TOPRIGHT", -(OFF_ALL), colTop - 2)
    colA:SetWidth(COL_ALL_W)
    colA:SetHeight(COLHDR_H)
    colA:SetJustifyH("RIGHT")
    colA:SetTextColor(0.55, 0.55, 0.65)
    colA:SetText("ALL TIME")

    local div1 = f:CreateTexture(nil, "ARTWORK")
    div1:SetPoint("TOPLEFT",  f, "TOPLEFT",  0, colTop - COLHDR_H)
    div1:SetPoint("TOPRIGHT", f, "TOPRIGHT", 0, colTop - COLHDR_H)
    div1:SetHeight(1)
    div1:SetColorTexture(0.20, 0.20, 0.30, 1)

    local rowsTop = colTop - COLHDR_H - 1

    for i, proc in ipairs(PROCS) do
        local rowY = rowsTop - (i - 1) * (ROW_H + ROW_PAD)

        local rbg = f:CreateTexture(nil, "BACKGROUND")
        rbg:SetPoint("TOPLEFT",  f, "TOPLEFT",   2, rowY)
        rbg:SetPoint("TOPRIGHT", f, "TOPRIGHT", -2, rowY)
        rbg:SetHeight(ROW_H)
        rbg:SetColorTexture(0, 0, 0, 0.55)

        local icon = f:CreateTexture(nil, "ARTWORK")
        icon:SetSize(ROW_H - 2, ROW_H - 2)
        icon:SetPoint("TOPLEFT", f, "TOPLEFT", PAD + 2, rowY - 1)
        icon:SetTexture(proc.icon)
        icon:SetTexCoord(0.07, 0.93, 0.07, 0.93)

        local nameLabel = f:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        nameLabel:SetFont(nameLabel:GetFont(), 10, "OUTLINE")
        nameLabel:SetPoint("LEFT",  icon, "RIGHT", 4, 0)
        nameLabel:SetPoint("RIGHT", f, "TOPRIGHT", -(OFF_FIGHT + COL_FIGHT_W + 4), rowY - 1)
        nameLabel:SetJustifyH("LEFT")
        nameLabel:SetTextColor(0.85, 0.85, 0.85)
        nameLabel:SetText(proc.label)

        local fNum = f:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        fNum:SetFont(fNum:GetFont(), 10, "OUTLINE")
        fNum:SetWidth(COL_FIGHT_W)
        fNum:SetJustifyH("RIGHT")
        fNum:SetPoint("TOPRIGHT", f, "TOPRIGHT", -(OFF_FIGHT), rowY - 1)
        fNum:SetText("|cff666677-|r")

        local sNum = f:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        sNum:SetFont(sNum:GetFont(), 10, "OUTLINE")
        sNum:SetWidth(COL_SESS_W)
        sNum:SetJustifyH("RIGHT")
        sNum:SetPoint("TOPRIGHT", f, "TOPRIGHT", -(OFF_SESS), rowY - 1)
        sNum:SetText("|cff444455-|r")

        local aNum = f:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        aNum:SetFont(aNum:GetFont(), 10, "OUTLINE")
        aNum:SetWidth(COL_ALL_W)
        aNum:SetJustifyH("RIGHT")
        aNum:SetPoint("TOPRIGHT", f, "TOPRIGHT", -(OFF_ALL), rowY - 1)
        aNum:SetText("|cff444455-|r")

        rowWidgets[proc.key] = { fightNum = fNum, sessNum = sNum, allNum = aNum, icon = icon }
    end

    local div2 = f:CreateTexture(nil, "ARTWORK")
    local div2Y = rowsTop - #PROCS * (ROW_H + ROW_PAD)
    div2:SetPoint("TOPLEFT",  f, "TOPLEFT",  0, div2Y)
    div2:SetPoint("TOPRIGHT", f, "TOPRIGHT", 0, div2Y)
    div2:SetHeight(1)
    div2:SetColorTexture(0.15, 0.15, 0.25, 1)

    -- Holy Trinity row
    local trinY = div2Y - 1

    local trinBg = f:CreateTexture(nil, "BACKGROUND")
    trinBg:SetPoint("TOPLEFT",  f, "TOPLEFT",   2, trinY)
    trinBg:SetPoint("TOPRIGHT", f, "TOPRIGHT", -2, trinY)
    trinBg:SetHeight(ROW_H)
    trinBg:SetColorTexture(0.20, 0.15, 0.02, 0.6)

    local trinIcon = f:CreateTexture(nil, "ARTWORK")
    trinIcon:SetSize(ROW_H - 2, ROW_H - 2)
    trinIcon:SetPoint("TOPLEFT", f, "TOPLEFT", PAD + 2, trinY - 1)
    trinIcon:SetTexture("Interface\\Icons\\spell_holy_auraoflight")
    trinIcon:SetTexCoord(0.07, 0.93, 0.07, 0.93)

    local trinLabel = f:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    trinLabel:SetFont(trinLabel:GetFont(), 10, "OUTLINE")
    trinLabel:SetPoint("LEFT",  trinIcon, "RIGHT", 4, 0)
    trinLabel:SetPoint("RIGHT", f, "TOPRIGHT", -(OFF_FIGHT + COL_FIGHT_W + 4), trinY - 1)
    trinLabel:SetJustifyH("LEFT")
    trinLabel:SetTextColor(1.0, 0.82, 0.2)
    trinLabel:SetText("Holy Trinity")

    local trinF = f:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    trinF:SetFont(trinF:GetFont(), 10, "OUTLINE")
    trinF:SetWidth(COL_FIGHT_W)
    trinF:SetJustifyH("RIGHT")
    trinF:SetPoint("TOPRIGHT", f, "TOPRIGHT", -(OFF_FIGHT), trinY - 1)
    trinF:SetText("|cff666677-|r")

    local trinS = f:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    trinS:SetFont(trinS:GetFont(), 10, "OUTLINE")
    trinS:SetWidth(COL_SESS_W)
    trinS:SetJustifyH("RIGHT")
    trinS:SetPoint("TOPRIGHT", f, "TOPRIGHT", -(OFF_SESS), trinY - 1)
    trinS:SetText("|cff444455-|r")

    local trinA = f:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    trinA:SetFont(trinA:GetFont(), 10, "OUTLINE")
    trinA:SetWidth(COL_ALL_W)
    trinA:SetJustifyH("RIGHT")
    trinA:SetPoint("TOPRIGHT", f, "TOPRIGHT", -(OFF_ALL), trinY - 1)
    trinA:SetText("|cff444455-|r")

    rowWidgets["trinity"] = { fightNum = trinF, sessNum = trinS, allNum = trinA, icon = trinIcon }

    local div3 = f:CreateTexture(nil, "ARTWORK")
    local div3Y = trinY - ROW_H - ROW_PAD
    div3:SetPoint("TOPLEFT",  f, "TOPLEFT",  0, div3Y)
    div3:SetPoint("TOPRIGHT", f, "TOPRIGHT", 0, div3Y)
    div3:SetHeight(1)
    div3:SetColorTexture(0.15, 0.15, 0.25, 1)

    footLabel = f:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    footLabel:SetFont(footLabel:GetFont(), 9, "OUTLINE")
    footLabel:SetPoint("BOTTOMLEFT",  f, "BOTTOMLEFT",   PAD + 2, 3)
    footLabel:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", -(PAD + 2), 3)
    footLabel:SetJustifyH("CENTER")
    footLabel:SetTextColor(0.48, 0.48, 0.60)
    footLabel:SetText("No data")

    mainFrame = f
    if not PT.db.shown then f:Hide() end
end

-- Display ─────────────────────────────────────────────────────
local glowTimers = { ds = 0, mg = 0, dst = 0, trinity = 0 }

function PT.UpdateDisplay()
    if not mainFrame then return end
    for _, proc in ipairs(PROCS) do
        local w = rowWidgets[proc.key]
        if w then
            local fc = fightCounts[proc.key] or 0
            local sc = sessionCounts[proc.key] or 0
            local ac = (PT.db.alltime and PT.db.alltime[proc.key]) or 0
            if inCombat then
                w.fightNum:SetText("|cffffdd44" .. fc .. "|r")
            else
                w.fightNum:SetText("|cff666677" .. fc .. "|r")
            end
            if sc > 0 then
                w.sessNum:SetText("|cff88ddff" .. sc .. "|r")
            else
                w.sessNum:SetText("|cff444455" .. sc .. "|r")
            end
            if ac > 0 then
                w.allNum:SetText("|cffaaffaa" .. ac .. "|r")
            else
                w.allNum:SetText("|cff444455" .. ac .. "|r")
            end
        end
    end
    -- Holy Trinity row
    local tw = rowWidgets["trinity"]
    if tw then
        local fc = fightCounts.trinity or 0
        local sc = sessionCounts.trinity or 0
        local ac = (PT.db.alltime and PT.db.alltime.trinity) or 0
        if inCombat then
            tw.fightNum:SetText("|cffffd700" .. fc .. "|r")
        else
            tw.fightNum:SetText("|cff666677" .. fc .. "|r")
        end
        tw.sessNum:SetText(sc > 0 and ("|cffffd700" .. sc .. "|r") or "|cff444455" .. sc .. "|r")
        tw.allNum:SetText(ac > 0 and ("|cffffd700" .. ac .. "|r") or "|cff444455" .. ac .. "|r")
    end
    if inCombat then
        local elapsed = FormatDuration(GetTime() - fightStart)
        local tag  = isBossFlag and "|cffff8800[BOSS] |r" or ""
        local name = (bossName ~= "" and bossName) or instName or "Combat"
        footLabel:SetText(tag .. "|cffffff77" .. name .. "|r  |cff88ff88" .. elapsed .. "|r")
    elseif PT.db.history and #PT.db.history > 0 then
        local last = PT.db.history[1]
        footLabel:SetText(
            "|cff888899Last: |r|cffffcc00" ..
            (last.boss ~= "" and last.boss or last.instance) ..
            "|r  DS " .. last.ds .. "  MG " .. last.mg .. "  DST " .. last.dst ..
            "  " .. FormatDuration(last.duration))
    else
        footLabel:SetText("|cff555566Out of combat|r")
    end
end

-- Glow flash ──────────────────────────────────────────────────
local GLOW_DURATION        = 0.35
local TRINITY_GLOW_DURATION = 1.2

local function FlashGlow(key)
    local w = rowWidgets[key]
    if not w then return end
    local dur = (key == "trinity") and TRINITY_GLOW_DURATION or GLOW_DURATION
    glowTimers[key] = dur
    if key == "trinity" then
        w.icon:SetVertexColor(1, 0.9, 0.1)
    else
        w.icon:SetVertexColor(1, 1, 0.4)
    end
end

-- Proc registration ───────────────────────────────────────────
local function OnProc(key)
    fightCounts[key]   = (fightCounts[key] or 0) + 1
    sessionCounts[key] = (sessionCounts[key] or 0) + 1
    if PT.db and PT.db.alltime then
        PT.db.alltime[key] = (PT.db.alltime[key] or 0) + 1
    end
    FlashGlow(key)
    PT.UpdateDisplay()
end

-- Aura scanner ────────────────────────────────────────────────
-- DS  (spell 21165): "Haste" buff, gives +212 Haste Rating
-- DST (spell 34775): "Haste" buff, gives +325 Haste Rating
-- Both are named "Haste" — we tell them apart by reading the tooltip
-- for each buff slot via a hidden GameTooltip. DST says "325", DS says "212".
-- Mongoose ("Lightning Speed") is unique — simple rising-edge.

local _scanTip = CreateFrame("GameTooltip", "SlyProcScanTooltip", nil, "GameTooltipTemplate")
_scanTip:SetOwner(WorldFrame, "ANCHOR_NONE")

local function GetBuffTooltipText(index)
    _scanTip:ClearLines()
    _scanTip:SetUnitBuff("player", index)
    local text = ""
    for j = 1, 10 do
        local fs = _G["SlyProcScanTooltipTextLeft" .. j]
        if fs then
            local t = fs:GetText()
            if t then text = text .. t .. "|" end
        end
    end
    return text
end

local DST_RATING = "325"  -- DST Haste buff = +325 Haste Rating
-- DS Haste buff = +212 Haste Rating (anything not 325)

local watchExpiry = 0

local function ScanAuras()
    local dsCount   = 0
    local dstCount  = 0
    local mgPresent = false
    local watching  = (watchExpiry > 0 and GetTime() < watchExpiry)

    local i = 1
    while true do
        local bname = UnitBuff("player", i)
        if not bname then break end
        local nl = bname:lower()

        if nl == "haste" then
            local tipText = GetBuffTooltipText(i)
            if watching and PT.db and PT.db.watchLog then
                table.insert(PT.db.watchLog, string.format("[%d] Haste tip: %s", i, tipText))
            end
            if tipText:find(DST_RATING, 1, true) then
                dstCount = dstCount + 1
            else
                dsCount = dsCount + 1
            end
        elseif nl == "lightning speed" then
            mgPresent = true
        end
        i = i + 1
    end

    -- Rising-edge for DS
    if dsCount > prevHasteCount then
        for _ = 1, (dsCount - prevHasteCount) do OnProc("ds") end
    end
    prevHasteCount = dsCount

    -- Rising-edge for DST
    if dstCount > prevHasteCount2 then
        for _ = 1, (dstCount - prevHasteCount2) do OnProc("dst") end
    end
    prevHasteCount2 = dstCount

    -- Mongoose rising-edge
    if mgPresent and not prevMgPresent then OnProc("mg") end
    prevMgPresent = mgPresent

    -- Holy Trinity: all three simultaneously active (rising-edge)
    local trinityActive = (dsCount > 0) and (dstCount > 0) and mgPresent
    if trinityActive and not prevTrinityActive then OnProc("trinity") end
    prevTrinityActive = trinityActive
end

-- Boss detection ──────────────────────────────────────────────
local function CheckTargetForBoss()
    if not inCombat then return end
    if UnitExists("target") then
        local level = UnitLevel("target")
        local class = UnitClassification("target")
        if level == -1 or class == "worldboss" then
            if not isBossFlag then
                isBossFlag = true
                local name = UnitName("target") or ""
                if name ~= "" then bossName = name end
            end
        end
    end
end

-- Combat events ───────────────────────────────────────────────
local function OnCombatStart()
    if not PT.db then return end
    inCombat       = true
    fightStart     = GetTime()
    isBossFlag     = false
    bossName       = ""
    instName       = GetCurrentInstance()
    fightCounts     = { ds = 0, mg = 0, dst = 0, trinity = 0 }
    prevHasteCount  = 0
    prevHasteCount2 = 0
    prevMgPresent   = false
    prevTrinityActive = false
    PT.UpdateDisplay()
end

local function OnCombatEnd()
    if not inCombat then return end
    inCombat = false
    local duration = GetTime() - fightStart
    if isBossFlag and duration >= 5 then
        local record = {
            boss     = bossName,
            instance = instName,
            ds       = fightCounts.ds,
            mg       = fightCounts.mg,
            dst      = fightCounts.dst,
            duration = math.floor(duration),
            time     = time(),
        }
        if PT.db and PT.db.history then
            table.insert(PT.db.history, 1, record)
            while #PT.db.history > MAX_HISTORY do
                table.remove(PT.db.history)
            end
        end
    end
    PT.UpdateDisplay()
end

-- OnUpdate ticker ─────────────────────────────────────────────
local tickFrame = CreateFrame("Frame")
local tickAcc   = 0
local footAcc   = 0
local dstAcc    = 0
local TICK_RATE = 0.067
local FOOT_RATE = 0.25
local DST_RATE  = 5.0

tickFrame:SetScript("OnUpdate", function(self, dt)
    tickAcc = tickAcc + dt
    footAcc = footAcc + dt
    dstAcc  = dstAcc  + dt

    if tickAcc >= TICK_RATE then
        tickAcc = 0
        if inCombat then
            ScanAuras()
            CheckTargetForBoss()
        end
    end

    if dstAcc >= DST_RATE then
        dstAcc = 0
        CheckDSTEquipped()
    end

    for key, remaining in pairs(glowTimers) do
        if remaining > 0 then
            glowTimers[key] = remaining - dt
            local w = rowWidgets[key]
            if w then
                local maxDur = (key == "trinity") and TRINITY_GLOW_DURATION or GLOW_DURATION
                local frac = math.max(remaining / maxDur, 0)
                if frac < 0.1 then
                    w.icon:SetVertexColor(1, 1, 1)
                else
                    w.icon:SetVertexColor(1, (1 - frac * 0.6) + 0.4, frac * 0.4)
                end
            end
        end
    end

    if footAcc >= FOOT_RATE then
        footAcc = 0
        if inCombat and mainFrame and mainFrame:IsShown() then
            PT.UpdateDisplay()
        end
    end
end)

-- Event frame ─────────────────────────────────────────────────
local evtFrame = CreateFrame("Frame")
evtFrame:RegisterEvent("PLAYER_ENTERING_WORLD")
evtFrame:RegisterEvent("PLAYER_REGEN_DISABLED")
evtFrame:RegisterEvent("PLAYER_REGEN_ENABLED")
evtFrame:RegisterEvent("UNIT_AURA")
evtFrame:RegisterEvent("PLAYER_TARGET_CHANGED")
evtFrame:RegisterEvent("PLAYER_EQUIPMENT_CHANGED")
evtFrame:RegisterEvent("PLAYER_LOGOUT")

evtFrame:SetScript("OnEvent", function(self, event, ...)
    if event == "PLAYER_ENTERING_WORLD" then
        CheckDSTEquipped()
    elseif event == "PLAYER_REGEN_DISABLED" then
        OnCombatStart()
    elseif event == "PLAYER_REGEN_ENABLED" then
        OnCombatEnd()
    elseif event == "UNIT_AURA" then
        if (...) == "player" then ScanAuras() end
    elseif event == "PLAYER_TARGET_CHANGED" then
        CheckTargetForBoss()
    elseif event == "PLAYER_EQUIPMENT_CHANGED" then
        CheckDSTEquipped()
    elseif event == "PLAYER_LOGOUT" then
        if mainFrame and PT.db then
            local pt, _, _, x, y = mainFrame:GetPoint()
            PT.db.position = { point = pt or "CENTER", x = x or 220, y = y or 0 }
            PT.db.shown    = mainFrame:IsShown()
        end
    end
end)

-- Init ────────────────────────────────────────────────────────
local function Init()
    SlyProcTrackerDB = SlyProcTrackerDB or {}
    ApplyDefaults(SlyProcTrackerDB, DB_DEFAULTS)
    PT.db = SlyProcTrackerDB

    CheckDSTEquipped()

    SLASH_SLYPTOC1 = "/slyptoc"
    SlashCmdList["SLYPTOC"] = function(msg)
        msg = strtrim((msg or ""):lower())
        if msg == "lock" then
            PT.db.locked = true
            if mainFrame then mainFrame:EnableMouse(false) end
            DEFAULT_CHAT_FRAME:AddMessage("|cff88bbff[ProcTracker]|r Locked.")
        elseif msg == "unlock" then
            PT.db.locked = false
            if mainFrame then mainFrame:EnableMouse(true) end
            DEFAULT_CHAT_FRAME:AddMessage("|cff88bbff[ProcTracker]|r Unlocked.")
        elseif msg == "reset" then
            PT.db.alltime    = { ds = 0, mg = 0, dst = 0 }
            PT.db.history    = {}
            sessionCounts    = { ds = 0, mg = 0, dst = 0 }
            fightCounts      = { ds = 0, mg = 0, dst = 0 }
            PT.UpdateDisplay()
            DEFAULT_CHAT_FRAME:AddMessage("|cff88bbff[ProcTracker]|r All totals cleared.")
        elseif msg == "watch" then
            PT.db.watchLog = {}
            watchExpiry    = GetTime() + 60
            DEFAULT_CHAT_FRAME:AddMessage("|cff88bbff[ProcTracker]|r Watch ON 60s — proc something then /reload.")
        elseif msg == "debug" then
            DEFAULT_CHAT_FRAME:AddMessage("|cff88bbff[ProcTracker]|r Buffs (dstEquipped=" .. tostring(dstEquipped) .. "):")
            local idx = 1
            while true do
                local bname = UnitBuff("player", idx)
                if not bname then break end
                DEFAULT_CHAT_FRAME:AddMessage(string.format("  [%d] |cffffdd44%s|r", idx, bname))
                idx = idx + 1
            end
            if idx == 1 then DEFAULT_CHAT_FRAME:AddMessage("  (none)") end
        elseif msg == "pos" then
            PT.db.position = { point = "CENTER", x = 220, y = 0 }
            if mainFrame then
                mainFrame:ClearAllPoints()
                mainFrame:SetPoint("CENTER", UIParent, "CENTER", 220, 0)
            end
            DEFAULT_CHAT_FRAME:AddMessage("|cff88bbff[ProcTracker]|r Position reset.")
        else
            if not mainFrame then BuildUI() end
            if mainFrame:IsShown() then
                mainFrame:Hide(); PT.db.shown = false
            else
                mainFrame:Show(); PT.db.shown = true
            end
        end
    end

    BuildUI()
    PT.UpdateDisplay()

    DEFAULT_CHAT_FRAME:AddMessage(
        "|cff88bbff[ProcTracker]|r v" .. VERSION ..
        " loaded. |cffffcc00/slyptoc|r to toggle." ..
        (dstEquipped and " |cffff8800(DST equipped)|r" or ""))
end

-- Boot ────────────────────────────────────────────────────────
local bootFrame = CreateFrame("Frame")
bootFrame:RegisterEvent("ADDON_LOADED")
bootFrame:SetScript("OnEvent", function(self, event, name)
    if name ~= ADDON_NAME then return end
    self:UnregisterEvent("ADDON_LOADED")
    if SlySuiteDataFrame and SlySuiteDataFrame.Register then
        SlySuiteDataFrame.Register(ADDON_NAME, VERSION, Init, {
            description = "Dragonstrike / Mongoose / DST proc tracker per fight and session.",
            slash       = "/slyptoc",
            icon        = "Interface\\Icons\\Ability_Rogue_Sprint",
        })
    else
        Init()
    end
end)
