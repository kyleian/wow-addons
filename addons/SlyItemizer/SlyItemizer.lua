-- SlyItemizer.lua
-- Item comparison engine: tooltip stat scanner, DPS score weights, tooltip hook.
-- All stat extraction uses a hidden GameTooltip (TBC has no GetItemStats API).

local ADDON_NAME    = "SlyItemizer"
local ADDON_VERSION = "1.0.0"

SlyItemizer = {}
local SI = SlyItemizer

-- ── Defaults ─────────────────────────────────────────────────────────────────
local DB_DEFAULTS = {
    enabled        = true,
    showDelta      = true,     -- show score delta on tooltips
    class          = nil,      -- detected on login
    spec           = "dps",    -- dps | tank | heal
    customWeights  = nil,      -- overrides preset if set
    position       = { point = "CENTER", x = 0, y = 0 },
}

local function ApplyDefaults(saved, defaults)
    for k, v in pairs(defaults) do
        if saved[k] == nil then
            if type(v) == "table" then saved[k] = {}; ApplyDefaults(saved[k], v)
            else saved[k] = v end
        end
    end
end

-- ── Stat keys (internal) ──────────────────────────────────────────────────────
-- These keys map to tooltip line patterns.
SI.STAT_KEYS = {
    "str","agi","sta","int","spi",
    "ap","rap","sp","hp","shadow_sp","fire_sp","frost_sp","nature_sp","arcane_sp",
    "hit","crit","haste","expertise",
    "defense","dodge","parry","block","blockval","resilience","arp",
    "mp5","feral_ap","weapon_dps","armor",
}

SI.STAT_LABELS = {
    str        = "Strength",        agi       = "Agility",      sta        = "Stamina",
    int        = "Intellect",       spi       = "Spirit",
    ap         = "Attack Power",    rap       = "Ranged AP",     sp         = "Spell Power",
    hp         = "Healing Power",
    shadow_sp  = "Shadow Damage",   fire_sp   = "Fire Damage",
    frost_sp   = "Frost Damage",    nature_sp = "Nature Damage", arcane_sp = "Arcane Damage",
    hit        = "Hit Rating",      crit      = "Crit Rating",   haste     = "Haste Rating",
    expertise  = "Expertise Rtg",
    defense    = "Defense Rtg",     dodge     = "Dodge Rtg",     parry      = "Parry Rtg",
    block      = "Block Rtg",       blockval  = "Block Value",   resilience = "Resilience",
    arp        = "Armor Pen",
    mp5        = "MP5",             feral_ap  = "Feral AP",      weapon_dps = "Weapon DPS",
    armor      = "Armor",
}

-- ── Hidden tooltip for scanning ───────────────────────────────────────────────
local scanTip = CreateFrame("GameTooltip", "SlyItemizerScanTip", nil, "GameTooltipTemplate")
scanTip:SetOwner(WorldFrame, "ANCHOR_NONE")

-- Regex patterns:  { statKey, pattern (captures number) }
-- TBC tooltip lines are English-only server-side for stat numbers.
local PATTERNS = {
    -- Primary stats ("+32 Agility" format)
    { "str",       "([%+%-]?%d+) Strength" },
    { "agi",       "([%+%-]?%d+) Agility" },
    { "sta",       "([%+%-]?%d+) Stamina" },
    { "int",       "([%+%-]?%d+) Intellect" },
    { "spi",       "([%+%-]?%d+) Spirit" },
    -- Equip: attack power
    { "ap",        "[Ii]ncreases? attack power by (%d+)" },
    { "rap",       "[Ii]ncreases? ranged attack power by (%d+)" },
    { "feral_ap",  "[Ii]ncreases? feral attack power by (%d+)" },
    -- Equip: spell power (combined damage + healing)
    { "sp",        "damage and healing done by magical spells and effects by up to (%d+)" },
    { "hp",        "[Ii]ncreases? healing done by spells and effects by up to (%d+)" },
    -- Specific school spell damage
    { "shadow_sp", "[Ii]ncreases? shadow spell damage by up to (%d+)" },
    { "fire_sp",   "[Ii]ncreases? fire spell damage by up to (%d+)" },
    { "frost_sp",  "[Ii]ncreases? frost spell damage by up to (%d+)" },
    { "nature_sp", "[Ii]ncreases? nature spell damage by up to (%d+)" },
    { "arcane_sp", "[Ii]ncreases? arcane spell damage by up to (%d+)" },
    -- Combat ratings
    { "hit",       "[Ii]mproves? hit rating by (%d+)" },
    { "crit",      "[Ii]mproves? critical strike rating by (%d+)" },
    { "crit",      "[Ii]mproves? spell critical strike rating by (%d+)" },
    { "haste",     "[Ii]mproves? haste rating by (%d+)" },
    { "expertise", "[Ii]mproves? expertise rating by (%d+)" },
    { "defense",   "[Ii]mproves? defense rating by (%d+)" },
    { "dodge",     "[Ii]mproves? dodge rating by (%d+)" },
    { "parry",     "[Ii]mproves? parry rating by (%d+)" },
    { "block",     "[Ii]mproves? block rating by (%d+)" },
    { "blockval",  "Increases the block value of your shield by (%d+)" },
    { "resilience","[Ii]ncreases? your resilience rating by (%d+)" },
    { "arp",       "[Ii]ncreases? your armor penetration by (%d+)" },
    { "arp",       "[Ii]ncreases? your armor penetration rating by (%d+)" },
    -- MP5
    { "mp5",       "[Rr]estores? (%d+) mana per 5" },
    -- Weapon DPS
    { "weapon_dps","%((%d+%.?%d*) damage per second%)" },
    -- Armor
    { "armor",     "^(%d+) Armor$" },
    { "armor",     "^(%d+) [Cc]hain" },       -- mail
    { "armor",     "^(%d+) [Pp]late" },        -- plate
}

-- ── Stat scanner ──────────────────────────────────────────────────────────────
function SI:ScanLink(itemLink)
    if not itemLink then return nil end

    local stats = {}
    scanTip:ClearLines()

    -- pcall in case link is invalid / item not cached
    local ok = pcall(function() scanTip:SetHyperlink(itemLink) end)
    if not ok then return nil end

    local n = scanTip:NumLines()
    for i = 2, n do   -- skip line 1 (item name)
        local left  = _G["SlyItemizerScanTipTextLeft"  .. i]
        local right = _G["SlyItemizerScanTipTextRight" .. i]
        local texts = {}
        if left  and left:GetText()  then texts[#texts+1] = left:GetText()  end
        if right and right:GetText() then texts[#texts+1] = right:GetText() end

        for _, text in ipairs(texts) do
            for _, pat in ipairs(PATTERNS) do
                local key, regex = pat[1], pat[2]
                local val = text:match(regex)
                if val then
                    val = tonumber(val) or 0
                    stats[key] = (stats[key] or 0) + val
                end
            end
        end
    end

    -- Extract item level from line 2 ("Item Level XX")
    local iLvlLine = _G["SlyItemizerScanTipTextLeft2"]
    if iLvlLine then
        local il = iLvlLine:GetText()
        if il then stats.ilevel = tonumber(il:match("Item Level (%d+)")) end
    end

    return stats
end

-- ── Score calculation ─────────────────────────────────────────────────────────
function SI:ScoreStats(stats, weights)
    if not stats or not weights then return 0 end
    local score = 0
    for key, w in pairs(weights) do
        score = score + (stats[key] or 0) * w
    end
    return score
end

function SI:ScoreLink(itemLink)
    local stats   = SI:ScanLink(itemLink)
    local weights = SI:GetActiveWeights()
    if not stats or not weights then return 0, stats end
    return SI:ScoreStats(stats, weights), stats
end

-- ── Active weights ────────────────────────────────────────────────────────────
function SI:GetActiveWeights()
    if SlyItemizerDB and SlyItemizerDB.customWeights then
        return SlyItemizerDB.customWeights
    end
    local class = SlyItemizerDB and SlyItemizerDB.class or "WARRIOR"
    local spec  = SlyItemizerDB and SlyItemizerDB.spec  or "dps"
    return SI.PRESETS[class] and SI.PRESETS[class][spec]
        or SI.PRESETS["WARRIOR"]["dps"]
end

-- ── Currently equipped score for a slot ──────────────────────────────────────
function SI:EquippedScore(slotId)
    local link = GetInventoryItemLink("player", slotId)
    if not link then return 0, nil end
    return SI:ScoreLink(link)
end

-- ── Delta vs equipped ─────────────────────────────────────────────────────────
-- Returns: delta (number), equippedScore, newScore, equippedStats, newStats
function SI:CompareLinkToSlot(itemLink, slotId)
    local newScore, newStats   = SI:ScoreLink(itemLink)
    local eqScore,  eqStats    = SI:EquippedScore(slotId)
    return newScore - eqScore, eqScore, newScore, eqStats, newStats
end

-- ── Guess slot from item tooltip ──────────────────────────────────────────────
local EQUIPLOC_TO_SLOT = {
    INVTYPE_HEAD       = 1,   INVTYPE_NECK       = 2,   INVTYPE_SHOULDER = 3,
    INVTYPE_CHEST      = 5,   INVTYPE_WAIST      = 6,   INVTYPE_LEGS     = 7,
    INVTYPE_FEET       = 8,   INVTYPE_WRIST      = 9,   INVTYPE_HAND     = 10,
    INVTYPE_FINGER     = 11,  INVTYPE_TRINKET    = 13,  INVTYPE_CLOAK    = 15,
    INVTYPE_WEAPON     = 16,  INVTYPE_SHIELD     = 17,  INVTYPE_RANGED   = 18,
    INVTYPE_THROWN     = 18,  INVTYPE_2HWEAPON   = 16,  INVTYPE_WEAPONMAINHAND = 16,
    INVTYPE_WEAPONOFFHAND = 17, INVTYPE_HOLDABLE  = 17,
    INVTYPE_BODY       = 4,   INVTYPE_TABARD     = 19,
}

function SI:ItemLinkToSlot(itemLink)
    local _,_,_,_,_,_,_,_,loc = GetItemInfo(itemLink)
    if loc and EQUIPLOC_TO_SLOT[loc] then
        return EQUIPLOC_TO_SLOT[loc]
    end
    return nil
end

-- ── Tooltip hook (shows score delta inline) ───────────────────────────────────
local function HookTooltip(tooltip)
    tooltip:HookScript("OnTooltipSetItem", function(self)
        if not SlyItemizerDB or not SlyItemizerDB.enabled or not SlyItemizerDB.showDelta then return end

        local _, link = self:GetItem()
        if not link then return end

        local slotId = SI:ItemLinkToSlot(link)
        if not slotId then return end

        local delta, eqScore, newScore = SI:CompareLinkToSlot(link, slotId)
        if newScore == 0 then return end  -- no scoreable stats (trinkets, rings w/o stats, etc.)

        -- Format
        local deltaStr, deltaColor
        if delta > 0.5 then
            deltaStr  = string.format("+%.0f", delta)
            deltaColor = "|cff00ff60"
        elseif delta < -0.5 then
            deltaStr  = string.format("%.0f", delta)
            deltaColor = "|cffff4040"
        else
            deltaStr  = "≈ 0 (about equal)"
            deltaColor = "|cffc0c0c0"
        end

        self:AddLine(deltaColor .. "SlyItemizer: " .. deltaStr .. " pts  (equipped " .. string.format("%.0f", eqScore) .. " → " .. string.format("%.0f", newScore) .. ")|r")
        self:Show()
    end)
end

HookTooltip(GameTooltip)
HookTooltip(ItemRefTooltip)
if ShoppingTooltip1 then HookTooltip(ShoppingTooltip1) end
if ShoppingTooltip2 then HookTooltip(ShoppingTooltip2) end

-- ── Print ─────────────────────────────────────────────────────────────────────
function SI:Print(msg)
    DEFAULT_CHAT_FRAME:AddMessage("|cffffff00[SlyItemizer]|r " .. msg)
end

-- ── Init ──────────────────────────────────────────────────────────────────────
function SI:Init()
    SlyItemizerDB = SlyItemizerDB or {}
    ApplyDefaults(SlyItemizerDB, DB_DEFAULTS)

    -- Auto-detect class
    local cls = select(2, UnitClass("player"))
    if cls then SlyItemizerDB.class = cls end

    SLASH_SLYITEM1 = "/slyitem"
    SLASH_SLYITEM2 = "/slyitemizer"
    SlashCmdList["SLYITEM"] = function(raw)
        local cmd, rest = (raw or ""):match("^%s*(%S*)%s*(.*)")
        cmd = (cmd or ""):lower()
        if cmd == "" then
            if SlyItemizerPanel and SlyItemizerPanel:IsShown() then SlyItemizerPanel:Hide()
            else if SI_BuildUI then SI_BuildUI() end end
        elseif cmd == "spec" then
            local s = rest:lower():match("^%s*(.-)%s*$")
            if s == "dps" or s == "tank" or s == "heal" then
                SlyItemizerDB.spec = s
                SI:Print("Spec set to: " .. s)
            else
                SI:Print("Usage: /slyitem spec dps|tank|heal")
            end
        elseif cmd == "delta" then
            SlyItemizerDB.showDelta = not SlyItemizerDB.showDelta
            SI:Print("Tooltip delta: " .. (SlyItemizerDB.showDelta and "ON" or "OFF"))
        elseif cmd == "scan" then
            -- Quick scan of all equipped items
            local total = 0
            for _, slot in ipairs(IRR and IRR.SLOTS or {}) do
                local link = GetInventoryItemLink("player", slot.id)
                if link then
                    local sc = SI:ScoreLink(link)
                    total = total + sc
                end
            end
            SI:Print(string.format("Total equipped score: %.0f", total))
        else
            SI:Print("Commands: /slyitem | spec dps|tank|heal | delta (toggle) | scan (score all equipped)")
        end
    end
end

-- ── Boot ──────────────────────────────────────────────────────────────────────
local boot = CreateFrame("Frame")
boot:RegisterEvent("ADDON_LOADED")
boot:SetScript("OnEvent", function(self, event, name)
    if name ~= ADDON_NAME then return end
    self:UnregisterEvent("ADDON_LOADED")
    if SlySuite_Register then
        SlySuite_Register(ADDON_NAME, ADDON_VERSION, function() SI:Init() end, {
            description = "Item compare, DPS score delta on tooltips, enchant/gem suggestions.",
            slash       = "/slyitem",
            icon        = "Interface\\Icons\\INV_Sword_39",
        })
    else
        SI:Init()
    end
end)
