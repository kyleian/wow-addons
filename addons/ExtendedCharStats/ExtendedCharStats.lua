-- ============================================================
-- ExtendedCharStats
-- Interface: 20504 (WoW TBC Anniversary)
-- Movable panel showing extended character statistics.
-- ToS: UI display only. No automation. No external calls.
-- ============================================================

local ADDON_NAME    = "ExtendedCharStats"
local ADDON_VERSION = "1.0.0"

ECS = ECS or {}
ECS.version = ADDON_VERSION

-- -------------------------------------------------------
-- Combat Rating constants (TBC 2.4.x)
-- -------------------------------------------------------
local CR = {
    DEFENSE        = 2,
    DODGE          = 3,
    PARRY          = 4,
    BLOCK          = 5,
    HIT_MELEE      = 6,
    HIT_RANGED     = 7,
    HIT_SPELL      = 8,
    CRIT_MELEE     = 9,
    CRIT_RANGED    = 10,
    CRIT_SPELL     = 11,
    RESILIENCE     = 15,   -- CR_CRIT_TAKEN_MELEE = 15 in TBC
    HASTE_MELEE    = 18,
    HASTE_RANGED   = 19,
    HASTE_SPELL    = 20,
    EXPERTISE      = 24,
    ARMOR_PEN      = 25,
}

-- Spell school indices (for GetSpellBonusDamage)
local SPELL_SCHOOLS = {
    { id=2, label="Holy"   },
    { id=3, label="Fire"   },
    { id=4, label="Nature" },
    { id=5, label="Frost"  },
    { id=6, label="Shadow" },
    { id=7, label="Arcane" },
}

-- -------------------------------------------------------
-- Stat retrieval helpers (all return formatted strings)
-- -------------------------------------------------------

local function safe(fn, ...)
    local ok, v1, v2, v3 = pcall(fn, ...)
    if ok then return v1, v2, v3 end
    return nil
end

local function fmt(n, decimals)
    if not n then return "n/a" end
    if decimals and decimals > 0 then
        return string.format("%." .. decimals .. "f%%", n)
    end
    return string.format("%d", math.floor(n + 0.5))
end

-- Returns a stat table for the current player to populate the panel
function ECS_GetStats()
    local stats = {}

    -- ---- OFFENSIVE ----
    -- Melee
    local apBase, apPos, apNeg = UnitAttackPower("player")
    local apTotal = (apBase or 0) + (apPos or 0) - (apNeg or 0)
    table.insert(stats, { section="OFFENSE", label="Attack Power",   value=fmt(apTotal) })

    local meleeHit = GetCombatRatingBonus(CR.HIT_MELEE) or 0
    table.insert(stats, { label="Melee Hit",      value=string.format("%.2f%%", meleeHit or 0) })

    local meleeCrit = safe(GetCritChance) or 0
    table.insert(stats, { label="Melee Crit",     value=string.format("%.2f%%", meleeCrit) })

    local hasteM = GetCombatRatingBonus(CR.HASTE_MELEE)
    table.insert(stats, { label="Melee Haste",    value=string.format("%.2f%%", hasteM or 0) })

    local expRating = GetCombatRating(CR.EXPERTISE)
    local expBonus  = GetCombatRatingBonus(CR.EXPERTISE)
    local expVal,_  = safe(GetExpertise)
    table.insert(stats, { label="Expertise",
        value=string.format("%d (%d rating)", expVal or 0, expRating or 0) })

    local armorPen = GetCombatRatingBonus(CR.ARMOR_PEN)
    table.insert(stats, { label="Armor Pen.",     value=string.format("%.2f%%", armorPen or 0) })

    -- Ranged
    local rapBase, rapPos, rapNeg = UnitRangedAttackPower("player")
    local rapTotal = (rapBase or 0) + (rapPos or 0) - (rapNeg or 0)
    table.insert(stats, { section="RANGED", label="Ranged AP",     value=fmt(rapTotal) })

    local rangedHit = GetCombatRatingBonus(CR.HIT_RANGED)
    table.insert(stats, { label="Ranged Hit",     value=string.format("%.2f%%", rangedHit or 0) })

    local rangedCrit = safe(GetRangedCritChance) or 0
    table.insert(stats, { label="Ranged Crit",    value=string.format("%.2f%%", rangedCrit) })

    -- Spell
    -- Spell power: highest value across valid TBC schools (2-7); school 0 is invalid in TBC.
    local spellPowerBase = 0
    for _, school in ipairs(SPELL_SCHOOLS) do
        local sp = safe(GetSpellBonusDamage, school.id) or 0
        if sp > spellPowerBase then spellPowerBase = sp end
    end
    table.insert(stats, { section="SPELL", label="Spell Power",   value=fmt(spellPowerBase) })
    -- Only show school breakdowns if they differ from the highest
    for _, school in ipairs(SPELL_SCHOOLS) do
        local sp = safe(GetSpellBonusDamage, school.id) or 0
        if sp ~= spellPowerBase then
            table.insert(stats, { label="  " .. school.label .. " Power", value=fmt(sp) })
        end
    end

    local healPower = safe(GetSpellBonusHealing) or spellPowerBase
    table.insert(stats, { label="Heal Power",     value=fmt(healPower) })

    local spellHit = GetCombatRatingBonus(CR.HIT_SPELL) or 0
    table.insert(stats, { label="Spell Hit",      value=string.format("%.2f%%", spellHit or 0) })

    local spellCrit = safe(GetSpellCritChance) or 0
    table.insert(stats, { label="Spell Crit",     value=string.format("%.2f%%", spellCrit) })

    local hasteSpell = safe(UnitSpellHaste, "player") or GetCombatRatingBonus(CR.HASTE_SPELL)
    table.insert(stats, { label="Spell Haste",    value=string.format("%.2f%%", hasteSpell or 0) })

    -- GetManaRegen returns (notCasting, casting) mana per second; multiply by 5 for mp5
    local mnc, mc = safe(GetManaRegen)
    local mp5nc = mnc and math.floor(mnc * 5 + 0.5) or 0
    local mp5c  = mc  and math.floor(mc  * 5 + 0.5) or 0
    table.insert(stats, { label="MP5 (not cast)",  value=fmt(mp5nc) })
    table.insert(stats, { label="MP5 (casting)",   value=fmt(mp5c) })

    -- ---- DEFENSIVE ----
    local armor = UnitArmor("player")
    table.insert(stats, { section="DEFENSE", label="Armor",         value=fmt(armor) })

    local dodge = safe(GetDodgeChance) or 0
    table.insert(stats, { label="Dodge",          value=string.format("%.2f%%", dodge) })

    local parry = safe(GetParryChance) or 0
    table.insert(stats, { label="Parry",          value=string.format("%.2f%%", parry) })

    local block = safe(GetBlockChance) or 0
    table.insert(stats, { label="Block",          value=string.format("%.2f%%", block) })

    local defRating = GetCombatRating(CR.DEFENSE)
    local defBonus  = GetCombatRatingBonus(CR.DEFENSE)
    local baseDef   = math.floor(safe(UnitDefense, "player") or 0)
    local totalDef  = math.floor(baseDef + (defBonus or 0))
    table.insert(stats, { label="Defense",
        value=string.format("%d (%d + %d rating)", totalDef, baseDef, defRating or 0) })

    local resRating = GetCombatRating(CR.RESILIENCE)
    local resPct    = GetCombatRatingBonus(CR.RESILIENCE)
    table.insert(stats, { label="Resilience",
        value=string.format("%d (%.2f%%)", resRating or 0, resPct or 0) })

    -- ---- CRUSH CAP (tank, vs level 73 boss) ----
    -- Uncrushable = Miss + Dodge + Parry + Block >= 102.4%
    -- Miss vs a level 73 boss: 5% base + (defSkill - 350) * 0.04% per point above 350
    -- Crit immune: need totalDef >= 490 (= 5.6% crit reduction at 0.04%/point above 350)
    local CRUSH_THRESHOLD = 102.4
    local CRIT_IMMUNE_DEF = 490

    local crushMiss = 5.0 + math.max(0, totalDef - 350) * 0.04
    local crushDodge = safe(GetDodgeChance) or 0
    local crushParry = safe(GetParryChance) or 0
    local crushBlock = safe(GetBlockChance) or 0
    local crushTotal = crushMiss + crushDodge + crushParry + crushBlock
    local crushNeeded = CRUSH_THRESHOLD - crushTotal
    local critDefNeeded = math.max(0, CRIT_IMMUNE_DEF - totalDef)

    local crushColor = crushNeeded <= 0 and "|cff00ff00" or "|cffff4444"
    local critColor  = critDefNeeded == 0 and "|cff00ff00" or "|cffff4444"

    table.insert(stats, { section="CRUSH CAP" })
    table.insert(stats, { label="  Miss (vs boss)",  value=string.format("%.2f%%", crushMiss) })
    table.insert(stats, { label="  Dodge",           value=string.format("%.2f%%", crushDodge) })
    table.insert(stats, { label="  Parry",           value=string.format("%.2f%%", crushParry) })
    table.insert(stats, { label="  Block",           value=string.format("%.2f%%", crushBlock) })
    table.insert(stats, { label="  Total / Need 102.4",
        value=crushColor .. string.format("%.2f%%|r", crushTotal) })
    if crushNeeded > 0 then
        table.insert(stats, { label="  Still need",
            value="|cffff4444" .. string.format("%.2f%%|r", crushNeeded) })
    else
        table.insert(stats, { label="  Status",
            value="|cff00ff00UNCRUSHABLE|r" })
    end
    table.insert(stats, { label="  Crit immune (490)",
        value=critColor .. (critDefNeeded == 0 and "YES|r"
            or string.format("need %d more|r", critDefNeeded)) })

    return stats
end

-- -------------------------------------------------------
-- Default saved variables
-- -------------------------------------------------------
local DB_DEFAULTS = {
    enabled  = true,
    position = { point="CENTER", x=-200, y=0 },
    options  = { scale=1.0 },
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

-- -------------------------------------------------------
-- UI
-- -------------------------------------------------------
local FRAME_W   = 310
local ROW_H     = 16
local SECTION_H = 20
local H_PAD     = 8

local statRows  = {}   -- FontString pairs {labelFS, valueFS}

local function FillBg(frame, r, g, b, a)
    local t = frame:CreateTexture(nil, "BACKGROUND")
    t:SetAllPoints(frame)
    t:SetColorTexture(r, g, b, a or 1)
    return t
end

local function BuildStatRow(parent, yOff)
    local row = {}
    local lbl = parent:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    lbl:SetFont(lbl:GetFont(), 10, "")
    lbl:SetPoint("TOPLEFT", parent, "TOPLEFT", H_PAD, yOff)
    lbl:SetTextColor(0.8, 0.8, 0.8)
    lbl:SetText("")
    lbl:SetJustifyH("LEFT")
    lbl:SetWidth(160)
    row.lbl = lbl

    local val = parent:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    val:SetFont(val:GetFont(), 10, "")
    val:SetPoint("TOPRIGHT", parent, "TOPRIGHT", -H_PAD, yOff)
    val:SetTextColor(1, 0.82, 0)
    val:SetText("")
    val:SetJustifyH("RIGHT")
    val:SetWidth(120)
    row.val = val

    return row
end

local function BuildSectionHeader(parent, text, yOff)
    local t = parent:CreateTexture(nil, "ARTWORK")
    t:SetSize(FRAME_W - H_PAD * 2, 1)
    t:SetPoint("TOPLEFT", parent, "TOPLEFT", H_PAD, yOff + 1)
    t:SetColorTexture(0.3, 0.3, 0.3, 1)

    local fs = parent:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    fs:SetFont(fs:GetFont(), 10, "OUTLINE")
    fs:SetPoint("TOPLEFT", parent, "TOPLEFT", H_PAD, yOff)
    fs:SetText(text)
    fs:SetTextColor(0.6, 0.85, 1.0)
    return fs
end

function ECS_BuildUI()
    if ECSFrame then return end

    -- Pre-compute row count (approximate; we'll build max 50 rows)
    local maxRows = 50
    local HEADER_H = 28

    local f = CreateFrame("Frame", "ECSFrame", UIParent)
    f:SetSize(FRAME_W, 600)  -- height adjusted after population
    f:SetFrameStrata("DIALOG")
    f:SetMovable(true)
    f:EnableMouse(true)
    f:RegisterForDrag("LeftButton")
    f:SetScript("OnDragStart", f.StartMoving)
    f:SetScript("OnDragStop",  f.StopMovingOrSizing)
    f:Hide()

    local pos = ECS.db.position
    f:ClearAllPoints()
    f:SetPoint(pos.point or "CENTER", UIParent, pos.point or "CENTER",
        pos.x or -200, pos.y or 0)

    FillBg(f, 0.07, 0.07, 0.07, 0.93)

    -- Border
    local bord = f:CreateTexture(nil, "OVERLAY")
    bord:SetPoint("TOPLEFT",     f, "TOPLEFT",     0,  0)
    bord:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", 0,  0)
    bord:SetColorTexture(0.3, 0.3, 0.3, 1)
    local inner = f:CreateTexture(nil, "BACKGROUND")
    inner:SetPoint("TOPLEFT",     f, "TOPLEFT",      1, -1)
    inner:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", -1,  1)
    inner:SetColorTexture(0.07, 0.07, 0.07, 0.93)

    -- Header
    local hdr = CreateFrame("Frame", nil, f)
    hdr:SetSize(FRAME_W, HEADER_H)
    hdr:SetPoint("TOPLEFT", f, "TOPLEFT", 0, 0)
    FillBg(hdr, 0.13, 0.13, 0.13, 1)

    local title = hdr:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    title:SetFont(title:GetFont(), 13, "OUTLINE")
    title:SetPoint("LEFT", hdr, "LEFT", 10, 0)
    title:SetText("|cff00ccffExtended Character Stats|r")

    local closeBtn = CreateFrame("Button", nil, hdr, "UIPanelCloseButton")
    closeBtn:SetSize(24, 24)
    closeBtn:SetPoint("RIGHT", hdr, "RIGHT", -2, 0)
    closeBtn:SetScript("OnClick", function() f:Hide() end)

    -- Refresh button
    local refreshBtn = CreateFrame("Button", nil, hdr, "UIPanelButtonTemplate")
    refreshBtn:SetSize(22, 22)
    refreshBtn:SetPoint("RIGHT", closeBtn, "LEFT", -2, 0)
    refreshBtn:SetText("R")
    refreshBtn:SetScript("OnClick", function() ECS_UpdatePanel() end)
    refreshBtn:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_BOTTOM")
        GameTooltip:SetText("Refresh stats", 1, 1, 1)
        GameTooltip:Show()
    end)
    refreshBtn:SetScript("OnLeave", function() GameTooltip:Hide() end)

    -- Content area
    local content = CreateFrame("Frame", nil, f)
    content:SetPoint("TOPLEFT",     f, "TOPLEFT",      0, -HEADER_H)
    content:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT",  0,  0)

    -- Pre-build stat rows (we'll fill them in UpdatePanel)
    for i = 1, maxRows do
        local yOff = -((i - 1) * ROW_H) - 4
        statRows[i] = BuildStatRow(content, yOff)
    end

    ECSFrame     = f
    ECSContent   = content
    ECS_UpdatePanel()
end

function ECS_UpdatePanel()
    if not ECSFrame then return end

    local stats   = ECS_GetStats()
    local HEADER_H = 28
    local rowIdx  = 0
    local yOff    = -4
    local sections = {}

    -- Clear all rows first
    for _, row in ipairs(statRows) do
        row.lbl:SetText("")
        row.val:SetText("")
    end

    -- Write stats + section headers
    local sectionHeaders = {}
    local rowData = {}  -- flat list of {type="section"/"stat", label, value}

    for _, stat in ipairs(stats) do
        if stat.section then
            table.insert(rowData, { type="section", label=stat.section })
        end
        table.insert(rowData, { type="stat", label=stat.label, value=stat.value })
    end

    rowIdx = 0
    local contentY = -4
    local lastSection = nil

    for i, entry in ipairs(rowData) do
        if entry.type == "section" and entry.label ~= lastSection then
            rowIdx = rowIdx + 1
            if statRows[rowIdx] then
                statRows[rowIdx].lbl:SetText(
                    "|cff66d4ff" .. entry.label .. "|r")
                statRows[rowIdx].lbl:SetTextColor(0.4, 0.83, 1.0)
                statRows[rowIdx].val:SetText("")
            end
            lastSection = entry.label
        elseif entry.type == "stat" then
            rowIdx = rowIdx + 1
            if statRows[rowIdx] then
                statRows[rowIdx].lbl:SetText(entry.label)
                statRows[rowIdx].lbl:SetTextColor(0.8, 0.8, 0.8)
                statRows[rowIdx].val:SetText(entry.value or "")
            end
        end
    end

    -- Resize frame to fit content
    local totalH = HEADER_H + rowIdx * ROW_H + 16
    ECSFrame:SetHeight(totalH)
end

-- -------------------------------------------------------
-- Events
-- -------------------------------------------------------
local eventFrame = CreateFrame("Frame")
eventFrame:RegisterEvent("ADDON_LOADED")
eventFrame:RegisterEvent("PLAYER_LOGOUT")
eventFrame:RegisterEvent("UNIT_INVENTORY_CHANGED")
eventFrame:RegisterEvent("PLAYER_ENTERING_WORLD")
eventFrame:RegisterEvent("PLAYER_TALENT_UPDATE")

eventFrame:SetScript("OnEvent", function(self, event, ...)
    if event == "ADDON_LOADED" then
        local name = ...
        if name == ADDON_NAME then
            ExtendedCharStatsDB = ExtendedCharStatsDB or {}
            ApplyDefaults(ExtendedCharStatsDB, DB_DEFAULTS)
            ECS.db = ExtendedCharStatsDB

            -- Register with Sly Suite if available; otherwise init standalone
            if SlySuite_Register then
                SlySuite_Register(
                    "ExtendedCharStats",
                    ADDON_VERSION,
                    function() ECS_BuildUI() end,
                    {
                        description = "Spell power, crit, hit, haste, expertise, resilience & more.",
                        slash       = "/estats",
                        icon        = "Interface\\Icons\\Spell_Holy_DevineSpirit",
                    }
                )
                -- SlySuite owns the init call; no print — SlySuite reports it
            else
                -- Standalone fallback (SlySuite not installed)
                ECS_BuildUI()
                print("|cff00ccff[ExtendedCharStats]|r v" .. ADDON_VERSION
                    .. " loaded.  |cffffcc00/estats|r to open.")
            end
        end

    elseif event == "PLAYER_ENTERING_WORLD" then
        if ECSFrame and ECSFrame:IsShown() then ECS_UpdatePanel() end

    elseif event == "UNIT_INVENTORY_CHANGED" then
        local unit = ...
        if unit == "player" and ECSFrame and ECSFrame:IsShown() then
            ECS_UpdatePanel()
        end

    elseif event == "PLAYER_TALENT_UPDATE" then
        if ECSFrame and ECSFrame:IsShown() then ECS_UpdatePanel() end

    elseif event == "PLAYER_LOGOUT" then
        if ECSFrame then
            local point, _, _, x, y = ECSFrame:GetPoint()
            ECS.db.position = { point=point or "CENTER", x=x or -200, y=y or 0 }
        end
    end
end)

-- -------------------------------------------------------
-- Slash commands
-- -------------------------------------------------------
SLASH_EXTENDEDCHARSTATS1 = "/estats"
SLASH_EXTENDEDCHARSTATS2 = "/extendedcharstats"
SlashCmdList["EXTENDEDCHARSTATS"] = function(msg)
    msg = strtrim(msg):lower()
    if msg == "" or msg == "toggle" then
        if ECSFrame then
            if ECSFrame:IsShown() then
                ECSFrame:Hide()
            else
                ECS_UpdatePanel()
                ECSFrame:Show()
            end
        end
    elseif msg == "refresh" then
        ECS_UpdatePanel()
        print("|cff00ccff[ExtendedCharStats]|r Stats refreshed.")
    elseif msg == "reset" then
        ECS.db.position = { point="CENTER", x=-200, y=0 }
        if ECSFrame then
            ECSFrame:ClearAllPoints()
            ECSFrame:SetPoint("CENTER", UIParent, "CENTER", -200, 0)
        end
        print("|cff00ccff[ExtendedCharStats]|r Frame position reset.")
    elseif msg == "help" then
        print("|cff00ccff[ExtendedCharStats]|r Commands:")
        print("  |cffffcc00/estats|r           — toggle the panel")
        print("  |cffffcc00/estats refresh|r   — manually refresh stats")
        print("  |cffffcc00/estats reset|r     — reset frame position")
    end
end
