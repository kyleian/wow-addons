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
local VERSION    = "1.3.9"

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
    swingTimerPosition = { point = "CENTER", x = -230, y = -190 },
    swingTimerShown    = true,
    iconCache = {},   -- [spellName] = texturePath, resolved at runtime
    errorLog = {},    -- recent errors, capped at 50
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

-- ─── Icon resolver ───────────────────────────────────────────
-- Call during Build() (after PLAYER_LOGIN) — GetSpellInfo works then.
-- Results are cached in SlyRotateDB.iconCache for subsequent sessions.
local FALLBACK_ICON = "Interface\\Icons\\INV_Misc_QuestionMark"

-- GetSpellInfo(name) only works for spells the player knows.
-- GetSpellInfo(id)   works for ANY spell. Map names → rank-1 IDs for cross-class resolution.
local SPELL_ID_MAP = {
    ["Adrenaline Rush"]        = 13750, ["Aimed Shot"]             = 20904,
    ["Arcane Blast"]           = 30451, ["Arcane Missiles"]        = 5143,
    ["Arcane Power"]           = 12042, ["Arcane Shot"]            = 3044,
    ["Aspect of the Viper"]    = 34074, ["Avenger's Shield"]       = 31935,
    ["Bash"]                   = 5209,  ["Bestial Wrath"]          = 19574,
    ["Blade Flurry"]           = 13877, ["Bloodthirst"]            = 23881,
    ["Chain Lightning"]        = 421,   ["Circle of Healing"]      = 34861,
    ["Cold Blood"]             = 14177, ["Cold Snap"]              = 11958,
    ["Combustion"]             = 11129, ["Conflagrate"]            = 17962,
    ["Consecration"]           = 26573, ["Corruption"]             = 172,
    ["Crusader Strike"]        = 35395, ["Curse of Agony"]         = 980,
    ["Curse of the Elements"]  = 1490,  ["Death Wish"]             = 12292,
    ["Demoralizing Roar"]      = 99,    ["Demoralizing Shout"]     = 1160,
    ["Devastate"]              = 20243, ["Divine Favor"]           = 20216,
    ["Earth Shock"]            = 8042,  ["Elemental Mastery"]      = 16166,
    ["Eviscerate"]             = 2098,  ["Evocation"]              = 12051,
    ["Execute"]                = 5308,  ["Exorcism"]               = 879,
    ["Explosive Trap"]         = 13813, ["Expose Weakness"]        = 34500,
    ["Ferocious Bite"]         = 22568, ["Fire Blast"]             = 2136,
    ["Fireball"]               = 133,   ["Flame Shock"]            = 8050,
    ["Flash Heal"]             = 2061,  ["Flash of Light"]         = 19750,
    ["Frenzied Regeneration"]  = 22842, ["Frostbolt"]              = 116,
    ["Greater Heal"]           = 2060,  ["Hammer of Wrath"]        = 24275,
    ["Hemorrhage"]             = 16511, ["Heroic Strike"]          = 78,
    ["Holy Light"]             = 635,   ["Holy Shield"]            = 20925,
    ["Holy Shock"]             = 20473, ["Icy Veins"]              = 12472,
    ["Immolate"]               = 348,   ["Incinerate"]             = 29722,
    ["Inner Focus"]            = 14751, ["Judgement"]              = 20271,
    ["Kill Command"]           = 34026, ["Lacerate"]               = 33745,
    ["Lay on Hands"]           = 633,   ["Life Tap"]               = 1454,
    ["Lightning Bolt"]         = 403,   ["Mangle (Bear)"]          = 33878,
    ["Mangle (Cat)"]           = 33876, ["Maul"]                   = 6807,
    ["Mind Blast"]             = 8092,  ["Mind Flay"]              = 15407,
    ["Mortal Strike"]          = 12294, ["Multi-Shot"]             = 2643,
    ["Mutilate"]               = 1329,  ["Nature's Swiftness"]     = 16188,
    ["Overpower"]              = 7384,  ["Pain Suppression"]       = 33206,
    ["Power Infusion"]         = 10060, ["Power Word: Shield"]     = 17,
    ["Prayer of Healing"]      = 596,   ["Presence of Mind"]       = 12043,
    ["Rapid Fire"]             = 3045,  ["Revenge"]                = 6572,
    ["Rip"]                    = 1079,  ["Rupture"]                = 1943,
    ["Scorch"]                 = 2948,  ["Seal of Command"]        = 20375,
    ["Seal of Righteousness"]  = 20154, ["Searing Totem"]          = 3599,
    ["Shadow Bolt"]            = 686,   ["Shadow Word: Death"]     = 32379,
    ["Shadow Word: Pain"]      = 589,   ["Shadowfiend"]            = 34433,
    ["Shamanistic Rage"]       = 30823, ["Shield Block"]           = 2565,
    ["Shield Slam"]            = 23922, ["Shred"]                  = 5221,
    ["Sinister Strike"]        = 1752,  ["Siphon Life"]            = 18265,
    ["Slam"]                   = 1464,  ["Slice and Dice"]         = 5171,
    ["Soul Fire"]              = 6353,  ["Steady Shot"]            = 34120,
    ["Stormstrike"]            = 17364, ["Summon Water Elemental"] = 31687,
    ["Sunder Armor"]           = 7386,  ["Thunder Clap"]           = 6343,
    ["Tiger's Fury"]           = 5217,  ["Trueshot Aura"]          = 19506,
    ["Unstable Affliction"]    = 30108, ["Vampiric Touch"]         = 34914,
    ["Whirlwind"]              = 1680,  ["Windfury Totem"]         = 8512,
    ["Wyvern Sting"]           = 19386,
}
SR.SPELL_ID_MAP = SPELL_ID_MAP  -- expose for modules if needed

function SR.GetIcon(spellName)
    if not spellName then return FALLBACK_ICON end
    local cache = SR.db and SR.db.iconCache
    if cache and cache[spellName] then
        local v = cache[spellName]
        -- Upgrade old string-encoded fileDataIDs (e.g. "132369") to numbers
        if type(v) == "string" and tonumber(v) then
            v = tonumber(v)
            cache[spellName] = v
        end
        return v
    end
    -- Prefer ID lookup (works for any class); fall back to name lookup
    local key = SPELL_ID_MAP[spellName] or spellName
    -- Try name lookup first — returns string path for spells the player knows.
    -- Only use ID lookup as fallback (returns numeric fileDataID which may not
    -- work with SetTexture in all Classic client builds).
    local _, _, icon = GetSpellInfo(spellName)
    if icon and type(icon) == "string" and icon ~= "" then
        if cache then cache[spellName] = icon end
        return icon
    end
    -- Fallback: ID-based lookup for cross-class or unlearned spells
    local spellID = SPELL_ID_MAP[spellName]
    if spellID then
        local _, _, idIcon = GetSpellInfo(spellID)
        if idIcon and idIcon ~= "" and idIcon ~= 0 then
            if cache then cache[spellName] = idIcon end
            return idIcon
        end
    end
    return FALLBACK_ICON
end

-- Scan the player's spellbook and populate iconCache with string texture paths.
-- GetSpellBookItemTexture returns proper "Interface\\Icons\\..." strings, unlike
-- GetSpellInfo(id) which returns numeric fileDataIDs in modern Classic clients.
function SR.ScanSpellbookIcons()
    if not SR.db then return end
    local cache = SR.db.iconCache
    if not cache then return end
    local numTabs = GetNumSpellTabs and GetNumSpellTabs() or 0
    for tab = 1, numTabs do
        local _, _, offset, count = GetSpellTabInfo(tab)
        for i = offset + 1, offset + count do
            local name = GetSpellBookItemName(i, BOOKTYPE_SPELL)
            local icon = GetSpellBookItemTexture(i, BOOKTYPE_SPELL)
            if name and icon and type(icon) == "string" and icon ~= "" then
                cache[name] = icon  -- highest-rank name wins (last scanned)
            end
        end
    end
end

-- Walk every built row frame and re-resolve icons.
-- Call after PLAYER_LOGIN when GetSpellInfo is fully reliable.
function SR.RefreshIcons()
    -- Refresh header icon from spellbook cache
    if SR._hdrIconTex and SR._active and SR._active.headerSpell then
        local tex = SR.GetIcon(SR._active.headerSpell)
        if tex then SR._hdrIconTex:SetTexture(tex) end
    end
    local function refreshRows(rowFrames)
        if not rowFrames then return end
        for _, row in ipairs(rowFrames) do
            if row.icon and row.rowDef then
                local rd = row.rowDef
                if not rd.icon then  -- only for spell= rows, not hardcoded icon= rows
                    local tex = SR.GetIcon(rd.spell)
                    if tex and tex ~= FALLBACK_ICON then
                        row.icon:SetTexture(tex)
                    end
                end
            end
        end
    end
    for _, mod in pairs(SR._modules) do
        if mod.specRowFrames then
            for _, frames in pairs(mod.specRowFrames) do
                refreshRows(frames)
            end
        end
    end
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
    local key = SPELL_ID_MAP[name] or name
    local start, dur = GetSpellCooldown(key)
    if dur and dur > 1.5 then return math.max(0, start + dur - GetTime()) end
    return 0
end

SR.Col     = Col
SR.Fmt     = Fmt
SR.SpellCD = SpellCD

-- ─── Shared spec detection ───────────────────────────────────
-- defs: array of { spec=string, tab=number } in any order.
-- A spec wins outright if it has >= 31 pts in its tab (standard deep-spec
-- threshold in TBC — enough to reach Tier 6).  If none qualify, the tab
-- with the most points wins.  If all tabs are 0 (talents not yet loaded),
-- returns default or defs[1].spec.
function SR.DetectSpecByTalents(defs, default)
    if not GetNumTalentTabs then return default or defs[1].spec end
    local pts = {}
    for i = 1, GetNumTalentTabs() do
        local _, _, p = GetTalentTabInfo(i)
        pts[i] = tonumber(p) or 0
    end
    for _, d in ipairs(defs) do
        if (pts[d.tab] or 0) >= 31 then return d.spec end
    end
    local best, bestPts = (default or defs[1].spec), 0
    for _, d in ipairs(defs) do
        if (pts[d.tab] or 0) > bestPts then
            bestPts = pts[d.tab] or 0
            best = d.spec
        end
    end
    return best
end

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
    icon:SetTexture(rowDef.icon or SR.GetIcon(rowDef.spell))
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

function SR.SetSpecLabel(specKey)
    if SR._specLabelTx then
        SR._specLabelTx:SetText(Col("ffcc66", tostring(specKey or "?")))
    end
end

-- ─── Rebuild body rows in-place (used by spec cycle) ─────────
function SR.RebuildBody()
    local mod = SR._active
    if not mod or not SR._bodyFrame or not SR._mainFrame then return end
    if mod.ScanAll then mod:ScanAll() end
    if mod.Build then
        mod:Build(SR._bodyFrame)
        local bodyH = mod:GetBodyHeight(SR.ROW_H)
        SR._bodyFrame:SetHeight(bodyH)
        SR._mainFrame:SetHeight(SR.HDR_H + 2 + bodyH + 4)
    end
end

-- ─── Cycle through specKeys for the active class ──────────────
function SR.CycleSpec()
    local mod = SR._active
    if not mod or not mod.specKeys or #mod.specKeys < 2 then return end
    local _, classFile = UnitClass("player")
    if not classFile then return end
    SR.db.classes[classFile] = SR.db.classes[classFile] or {}
    -- Use current known spec (override or last detected) as starting point
    local current = SR.db.classes[classFile].specOverride or mod.currentSpec
    local keys = mod.specKeys
    local idx = 0
    for i, k in ipairs(keys) do
        if k == current then idx = i; break end
    end
    if idx == 0 then idx = 1 end
    local nextIdx = (idx % #keys) + 1
    local nextSpec = keys[nextIdx]
    SR.db.classes[classFile].specOverride = nextSpec
    SR.RebuildBody()
    SR.SetSpecLabel(nextSpec)
    DEFAULT_CHAT_FRAME:AddMessage(
        Col("88ff88", "[SlyRotate]") .. " Spec set to " .. Col("ffcc00", nextSpec))
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
    hdrIcon:SetTexture(mod.headerIcon or "Interface\\Icons\\INV_Misc_QuestionMark")
    hdrIcon:SetTexCoord(0.07, 0.93, 0.07, 0.93)
    SR._hdrIconTex = hdrIcon

    -- Spec label (replaces title; clickable to cycle spec)
    local initSpec = (SR.db.classes[select(2,UnitClass("player"))] or {}).specOverride
                     or mod.currentSpec
                     or (mod.specKeys and mod.specKeys[1])
                     or ""
    local specLabelTx = hdr:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    specLabelTx:SetFont(specLabelTx:GetFont(), 9, "OUTLINE")
    specLabelTx:SetPoint("LEFT", hdrIcon, "RIGHT", 4, 0)
    specLabelTx:SetText(Col("ffcc66", tostring(initSpec)))
    SR._specLabelTx = specLabelTx

    SR._specCycleBtn = nil
    if mod.specKeys and #mod.specKeys > 1 then
        local hoverBtn = CreateFrame("Button", nil, hdr)
        hoverBtn:SetSize(80, HDR_H)
        hoverBtn:SetPoint("LEFT", specLabelTx, "LEFT", -2, 0)
        hoverBtn:EnableMouse(true)
        hoverBtn:SetScript("OnClick", SR.CycleSpec)
        hoverBtn:SetScript("OnEnter", function()
            specLabelTx:SetTextColor(1, 1, 0.5)
            GameTooltip:SetOwner(hoverBtn, "ANCHOR_BOTTOM")
            GameTooltip:SetText("Click to switch spec", 1, 1, 1)
            GameTooltip:Show()
        end)
        hoverBtn:SetScript("OnLeave", function()
            specLabelTx:SetTextColor(1, 0.8, 0.4)
            GameTooltip:Hide()
        end)
        SR._specCycleBtn = hoverBtn
    end

    modeLabel = hdr:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    modeLabel:SetFont(modeLabel:GetFont(), 9, "OUTLINE")
    modeLabel:SetPoint("RIGHT", hdr, "RIGHT", -5, 0)
    modeLabel:SetText("")

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
    spotIcon:SetTexture(rd.icon or SR.GetIcon(rd.spell))
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

    -- Spec override section: label + "Auto" + one per spec (active class only)
    local _, specClassFile = UnitClass("player")
    local activeSpecKeys = SR._active and SR._active.specKeys
    local specOverrideLines = 0
    if specClassFile and activeSpecKeys and #activeSpecKeys > 0 then
        specOverrideLines = 1 + 1 + #activeSpecKeys  -- label + Auto + each spec
    end
    local totalLines = 3 + specOverrideLines  -- combat-only, spotlight, spec override, "Classes" separator
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

    -- Spec Override radio group (active player class only, reload to apply)
    if specClassFile and activeSpecKeys and #activeSpecKeys > 0 then
        MakeLabel(Col("666677", "── Spec Override (reload to apply) ──"))
        local radioGroup = {}
        local function RefreshRadios()
            local override = SR.db.classes[specClassFile] and SR.db.classes[specClassFile].specOverride
            for _, entry in ipairs(radioGroup) do
                entry.btn:SetChecked(entry.value == override)
            end
        end
        -- Auto-detect option
        local autoRb = CreateFrame("CheckButton", nil, content, "UICheckButtonTemplate")
        autoRb:SetSize(20, 20)
        autoRb:SetPoint("TOPLEFT", content, "TOPLEFT", 0, yOff - 1)
        yOff = yOff - LH
        if autoRb.text then autoRb.text:SetText("Auto-detect"); autoRb.text:SetTextColor(0.78, 0.78, 0.78) end
        table.insert(radioGroup, { btn = autoRb, value = nil })
        autoRb:SetScript("OnClick", function()
            SR.db.classes[specClassFile] = SR.db.classes[specClassFile] or {}
            SR.db.classes[specClassFile].specOverride = nil
            RefreshRadios()
        end)
        -- One radio per spec
        for _, sk in ipairs(activeSpecKeys) do
            local skLocal = sk
            local rb = CreateFrame("CheckButton", nil, content, "UICheckButtonTemplate")
            rb:SetSize(20, 20)
            rb:SetPoint("TOPLEFT", content, "TOPLEFT", 20, yOff - 1)
            yOff = yOff - LH
            if rb.text then rb.text:SetText(specLabel[skLocal] or skLocal); rb.text:SetTextColor(0.78, 0.78, 0.78) end
            table.insert(radioGroup, { btn = rb, value = skLocal })
            rb:SetScript("OnClick", function()
                SR.db.classes[specClassFile] = SR.db.classes[specClassFile] or {}
                SR.db.classes[specClassFile].specOverride = skLocal
                RefreshRadios()
            end)
        end
        RefreshRadios()
    end

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
evtFrame:RegisterEvent("PLAYER_ENTERING_WORLD")
evtFrame:RegisterEvent("PLAYER_LOGOUT")

evtFrame:SetScript("OnEvent", function(self, event, arg1, arg2, arg3)
    -- Forward to active module first
    local mod = SR._active
    if mod and mod.OnEvent then
        local ok, err = pcall(mod.OnEvent, mod, event, arg1, arg2, arg3)
        if not ok then SR.LogError("OnEvent:"..event, err) end
    end

    -- Core logic
    if event == "PLAYER_REGEN_DISABLED" then
        if SR.db and SR.db.combatOnly and SR.db.shown then
            if mainFrame then mainFrame:Show() end
            if spotFrame and SR.db.spotShown then spotFrame:Show() end
        end

    elseif event == "PLAYER_REGEN_ENABLED" then
        -- Only hide for combatOnly if we are NOT simultaneously entering a new
        -- zone (BGs fire PLAYER_REGEN_ENABLED on zone-in even when the player
        -- is about to enter combat immediately).  We guard with InCombatLockdown
        -- which will already be false here; hide is safe.
        if SR.db and SR.db.combatOnly then
            if mainFrame then mainFrame:Hide() end
            if spotFrame then spotFrame:Hide() end
        end

    elseif event == "PLAYER_ENTERING_WORLD" then
        -- Scan spellbook then refresh icons — spellbook gives string paths, not numeric IDs.
        C_Timer.After(0.5, function()
            SR.ScanSpellbookIcons()
            SR.RefreshIcons()
        end)
        -- Restore frame visibility after zone transitions (BGs, instances).
        -- Run on the next frame to let the zone fully settle first.
        if mainFrame then
            C_Timer.After(0, function()
                if not SR.db then return end
                if SR.db.combatOnly then
                    -- combatOnly: show if in combat, hide if not
                    if InCombatLockdown() and SR.db.shown then
                        mainFrame:Show()
                        if spotFrame and SR.db.spotShown then spotFrame:Show() end
                    else
                        mainFrame:Hide()
                        if spotFrame then spotFrame:Hide() end
                    end
                else
                    -- Always-on mode: restore saved visibility
                    if SR.db.shown then
                        mainFrame:Show()
                        if spotFrame and SR.db.spotShown then spotFrame:Show() end
                    end
                end
            end)
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
        -- Save warrior swing timer position
        local wm = SR._modules and SR._modules.WARRIOR
        if wm and wm.swingFrame and SR.db then
            local pt2, _, _, x2, y2 = wm.swingFrame:GetPoint()
            SR.db.swingTimerPosition = { point = pt2 or "CENTER", x = x2 or 0, y = y2 or 0 }
            SR.db.swingTimerShown    = wm.swingTimerShown
        end
    end
end)

-- ─── Error logging ─────────────────────────────────────────
function SR.LogError(context, err)
    SR.db = SR.db or {}
    SR.db.errorLog = SR.db.errorLog or {}
    local entry = (date and date("%H:%M:%S") or "??") .. "  [" .. context .. "]  " .. tostring(err)
    table.insert(SR.db.errorLog, entry)
    if #SR.db.errorLog > 50 then table.remove(SR.db.errorLog, 1) end
    DEFAULT_CHAT_FRAME:AddMessage(Col("ff4444","[SlyRotate ERR] ") .. Col("ffaaaa", tostring(err)))
    -- Also persist to SlyError so /slyerror captures it across sessions
    if SlyError and SlyError.Log then
        SlyError.Log("SlyRotate:" .. tostring(context), tostring(err))
    end
end

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
    local ok, err = pcall(mod.Update, mod, GetTime(), SR.db)
    if not ok then SR.LogError("Update", err) end
    if mod.currentSpec then
        if SR._specLabelTx then
            SR._specLabelTx:SetText(Col("ffcc66", mod.currentSpec))
        end
        if SR._hdrIconTex then
            local spell = (mod.headerSpells and mod.headerSpells[mod.currentSpec])
                          or mod.headerSpell
            if spell then
                local tex = SR.GetIcon(spell)
                if tex then SR._hdrIconTex:SetTexture(tex) end
            end
        end
    end
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

        elseif msg:sub(1, 5) == "spec " then
            -- /slyrotate spec shadow|holy|discipline|fury|arms|etc.
            local _, classFile = UnitClass("player")
            local override = msg:sub(6):upper():gsub("%s+", "")
            local mod = SR._active
            if not mod or not classFile then
                DEFAULT_CHAT_FRAME:AddMessage(Col("ff4444","[SlyRotate]") .. " No active module.")
            else
                local valid = false
                if mod.specKeys then
                    for _, k in ipairs(mod.specKeys) do
                        if k == override then valid = true; break end
                    end
                end
                if not valid then
                    local opts = mod.specKeys and table.concat(mod.specKeys, ", ") or "?"
                    DEFAULT_CHAT_FRAME:AddMessage(Col("ff4444","[SlyRotate]") .. " Unknown spec. Options: " .. Col("ffcc00", opts))
                else
                    SR.db.classes[classFile] = SR.db.classes[classFile] or {}
                    SR.db.classes[classFile].specOverride = override
                    DEFAULT_CHAT_FRAME:AddMessage(Col("88ff88","[SlyRotate]") .. " Spec locked to " .. Col("ffcc00", override) .. ". /reload to apply.")
                end
            end

        elseif msg == "spec" then
            -- /slyrotate spec — clear override and auto-detect
            local _, classFile = UnitClass("player")
            if classFile and SR.db.classes[classFile] then
                SR.db.classes[classFile].specOverride = nil
            end
            DEFAULT_CHAT_FRAME:AddMessage(Col("88ff88","[SlyRotate]") .. " Spec override cleared. /reload to auto-detect.")

        elseif msg == "errors" then
            local log = SR.db and SR.db.errorLog
            if not log or #log == 0 then
                DEFAULT_CHAT_FRAME:AddMessage(Col("88ff88","[SlyRotate]") .. " No errors logged.")
            else
                DEFAULT_CHAT_FRAME:AddMessage(Col("ff4444","[SlyRotate] Last " .. #log .. " error(s):"))
                for i = math.max(1, #log - 9), #log do
                    DEFAULT_CHAT_FRAME:AddMessage(Col("ffaaaa", log[i]))
                end
            end

        elseif msg == "dumpicons" then
            -- Resolve all spell icons now and dump to SavedVariables for static mapping
            local dump = {}
            local spells = {
                "Adrenaline Rush","Aimed Shot","Arcane Blast","Arcane Missiles","Arcane Power",
                "Arcane Shot","Aspect of the Viper","Avenger's Shield","Bash","Bestial Wrath",
                "Blade Flurry","Bloodthirst","Chain Lightning","Circle of Healing","Cold Blood",
                "Cold Snap","Combustion","Conflagrate","Consecration","Corruption",
                "Crusader Strike","Curse of Agony","Curse of the Elements","Death Wish",
                "Demoralizing Roar","Demoralizing Shout","Devastate","Divine Favor",
                "Earth Shock","Elemental Mastery","Eviscerate","Evocation","Execute",
                "Exorcism","Explosive Trap","Expose Weakness","Ferocious Bite","Fire Blast",
                "Fireball","Flame Shock","Flash Heal","Flash of Light","Frenzied Regeneration",
                "Frostbolt","Greater Heal","Hammer of Wrath","Hemorrhage","Heroic Strike",
                "Holy Light","Holy Shield","Holy Shock","Icy Veins","Immolate","Incinerate",
                "Inner Focus","Judgement","Kill Command","Lacerate","Lay on Hands","Life Tap",
                "Lightning Bolt","Mangle (Bear)","Mangle (Cat)","Maul","Mind Blast","Mind Flay",
                "Mortal Strike","Multi-Shot","Mutilate","Nature's Swiftness","Overpower",
                "Pain Suppression","Power Infusion","Power Word: Shield","Prayer of Healing",
                "Presence of Mind","Rapid Fire","Revenge","Rip","Rupture","Scorch",
                "Seal of Command","Seal of Righteousness","Searing Totem","Shadow Bolt",
                "Shadow Word: Death","Shadow Word: Pain","Shadowfiend","Shamanistic Rage",
                "Shield Block","Shield Slam","Shred","Sinister Strike","Siphon Life","Slam",
                "Slice and Dice","Soul Fire","Steady Shot","Stormstrike","Summon Water Elemental",
                "Sunder Armor","Thunder Clap","Tiger's Fury","Trueshot Aura","Unstable Affliction",
                "Vampiric Touch","Whirlwind","Windfury Totem","Wyvern Sting",
            }
            local found, missing = 0, 0
            for _, name in ipairs(spells) do
                local key = SPELL_ID_MAP[name] or name
                local _, _, icon, _, _, _, spellID = GetSpellInfo(key)
                if icon and icon ~= "" and icon ~= 0 then
                    dump[name] = { icon = icon, id = spellID or 0 }
                    found = found + 1
                else
                    dump[name] = { icon = "MISSING", id = 0 }
                    missing = missing + 1
                end
            end
            SR.db.iconDump = dump
            DEFAULT_CHAT_FRAME:AddMessage(
                Col("88ff88","[SlyRotate]") ..
                " Icon dump: " .. Col("44ff44", found .. " found") ..
                ", " .. Col("ff4444", missing .. " missing") ..
                ". Saved to SlyRotateDB.iconDump — /reload then check SavedVariables.")

        elseif msg == "reseticons" then
            if SR.db then SR.db.iconCache = {} end
            DEFAULT_CHAT_FRAME:AddMessage(Col("88ff88", "[SlyRotate]") .. " Icon cache cleared. /reload to re-resolve.")

        elseif msg == "testspell" then
            -- Debug: print raw GetSpellInfo return values by name vs by ID
            local testSpells = { "Heroic Strike", "Fireball", "Corruption", "Steady Shot" }
            DEFAULT_CHAT_FRAME:AddMessage(Col("88ff88","[SlyRotate]") .. " GetSpellInfo debug (name | id):")
            for _, sn in ipairs(testSpells) do
                local a,b,c = GetSpellInfo(sn)
                local spellID = SPELL_ID_MAP[sn]
                local da,db,dc = spellID and GetSpellInfo(spellID)
                DEFAULT_CHAT_FRAME:AddMessage(string.format(
                    "  %s: byName=icon:%s(%s) | byID(%s)=icon:%s(%s)",
                    sn, tostring(c), type(c), tostring(spellID), tostring(dc), type(dc)
                ))
            end

        elseif msg == "swing" then
            local wm = SR._modules and SR._modules.WARRIOR
            local sf = wm and wm.swingFrame
            if not sf then
                DEFAULT_CHAT_FRAME:AddMessage(
                    Col("ff8844","[SlyRotate]") .. " Swing timer is Warrior-only.")
            elseif wm.swingTimerShown then
                wm.swingTimerShown = false
                sf:Hide()
                if SR.db then SR.db.swingTimerShown = false end
                DEFAULT_CHAT_FRAME:AddMessage(Col("88ff88","[SlyRotate]") .. " Swing timer hidden.")
            else
                wm.swingTimerShown = true
                sf:Show()
                if SR.db then SR.db.swingTimerShown = true end
                DEFAULT_CHAT_FRAME:AddMessage(Col("88ff88","[SlyRotate]") .. " Swing timer shown.")
            end

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

    local specHint = ""
    if SR._active.specKeys then
        specHint = " · |cffffcc00/slyrotate spec " .. SR._active.specKeys[1] .. "|r to force spec"
    end
    DEFAULT_CHAT_FRAME:AddMessage(
        Col("88ff88", "[SlyRotate]") .. " v" .. VERSION ..
        " — " .. (SR._active.classLabel or classFile) ..
        " rotation loaded. |cffffcc00/slyrotate|r toggle · |cffffcc00/slyrotate config|r settings" .. specHint .. ".")
end

-- ─── Boot ────────────────────────────────────────────────────
local bootFrame = CreateFrame("Frame")
bootFrame:RegisterEvent("ADDON_LOADED")
bootFrame:SetScript("OnEvent", function(self, event, name)
    if name ~= ADDON_NAME then return end
    self:UnregisterEvent("ADDON_LOADED")
    Init()
end)
