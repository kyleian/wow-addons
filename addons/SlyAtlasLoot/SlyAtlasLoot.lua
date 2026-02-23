-- ============================================================
-- SlyAtlasLoot.lua
-- AtlasLoot drop rate integration for SlySuite.
-- * Hooks AtlasLoot.Data.Droprate.AddData to build a reverse
--   itemID → [{npcID, pct}] index.
-- * Tracks current target NPC ID via UnitGUID.
-- * Adds drop % lines to GameTooltip (and item ref tooltips).
-- * Provides a search panel via /slyatlas.
-- ============================================================

SAL = SAL or {}
SAL.version = "1.0.0"

-- --------------------------------------------------------
-- Saved-variable defaults
-- --------------------------------------------------------
local DB_DEFAULTS = {
    enabled         = true,
    tooltipEnabled  = true,
    tooltipTarget   = true,   -- "Drop rate from target: X%"
    tooltipBest     = true,   -- "Best known: X% (N sources)"
    tooltipThreshold = 0,     -- only show if pct >= this value
    position        = { point = "CENTER", x = 0, y = 0 },
}

SAL.db = {}

-- --------------------------------------------------------
-- Static TBC raid boss NPC ID → name table
-- --------------------------------------------------------
local BOSS_NAMES = {
    -- Karazhan
    [15550] = "Attumen the Huntsman",
    [15687] = "Moroes",
    [16457] = "Maiden of Virtue",
    [16524] = "Shade of Aran",
    [15688] = "Terestian Illhoof",
    [15689] = "Netherspite",
    [15690] = "Prince Malchezaar",
    [15691] = "The Curator",
    [17225] = "Nightbane",
    [17229] = "Midnight",
    -- Gruul's Lair
    [18831] = "High King Maulgar",
    [19044] = "Gruul the Dragonkiller",
    -- Magtheridon's Lair
    [17257] = "Magtheridon",
    -- Serpentshrine Cavern
    [21212] = "Lady Vashj",
    [21213] = "Morogrim Tidewalker",
    [21214] = "Karathress",
    [21215] = "Leotheras the Blind",
    [21216] = "Hydross the Unstable",
    [21217] = "Fathom-Lord Karathress",
    [21754] = "The Lurker Below",
    -- Tempest Keep
    [19514] = "Al'ar",
    [19516] = "Void Reaver",
    [18805] = "High Astromancer Solarian",
    [19622] = "Kael'thas Sunstrider",
    -- Mount Hyjal
    [17767] = "Rage Winterchill",
    [17808] = "Anetheron",
    [17888] = "Kaz'rogal",
    [17842] = "Azgalor",
    [17968] = "Archimonde",
    -- Black Temple
    [22887] = "High Warlord Naj'entus",
    [22898] = "Supremus",
    [22841] = "Shade of Akama",
    [22871] = "Teron Gorefiend",
    [22948] = "Gurtogg Bloodboil",
    [22856] = "Reliquary of Souls",
    [23426] = "Mother Shahraz",
    [22949] = "Illidari Council",
    [22917] = "Illidan Stormrage",
    -- Sunwell Plateau
    [25166] = "Kalecgos",
    [24882] = "Brutallus",
    [25038] = "Felmyst",
    [25166] = "Kalecgos (Dragon Aspect)",
    [25315] = "Kil'jaeden",
    [25741] = "M'uru",
    [24892] = "Eredar Twins",
    -- Zul'Aman
    [23576] = "Nalorakk",
    [23577] = "Akil'zon",
    [23578] = "Jan'alai",
    [23579] = "Halazzi",
    [24239] = "Hex Lord Malacrass",
    [23863] = "Zul'jin",
    -- Heroic Dungeons — final bosses
    [17881] = "Murmur",              -- Shadow Labs
    [18731] = "Warlord Kalithresh",  -- Steamvault
    [17941] = "Warchief Kargath",    -- Shattered Halls
    [19220] = "Pathaleon the Calculator", -- Mechanar
    [20913] = "Harbinger Skyriss",   -- Arcatraz
    [18732] = "Hydromancer Thespia", -- Coilfang Pump
    [17798] = "Ambassador Hellmaw",  -- Shadow Lab
    [18373] = "Wrath-Scryer Soccothrates", -- Arcatraz
    [18096] = "Blackheart the Inciter",    -- Shadow Labyrinth
    [18708] = "Nexus-Prince Shaffar",      -- Mana-Tombs
    [18371] = "Warden Mellichar",          -- Arcatraz
    [19735] = "Gatewatcher Iron-Hand",     -- Mechanar
    [18814] = "Yor",                       -- Mana-Tombs (rare)
    [16808] = "Nexus-Prince Shimraz",      -- Mana-Tombs
    [17377] = "Exarch Maladaar",           -- Auchenai Crypts
    [18676] = "Talon King Ikiss",          -- Sethekk Halls
    [18678] = "Darkweaver Syth",           -- Sethekk Halls
    [18373] = "Wrath-Scryer Soccothrates", -- Arcatraz
    [18283] = "Pandemonius",               -- Mana-Tombs
    [18469] = "Omor the Unscarred",        -- Ramparts
    [17306] = "Watchkeeper Gargolmar",     -- Ramparts
    [17536] = "Omor the Unscarred",        -- Ramparts  
    [17537] = "Vazruden the Herald",       -- Ramparts
    [17881] = "Murmur",                    -- Shadow Labyrinth
    [18412] = "Keli'dan the Breaker",      -- Blood Furnace
    [17941] = "Kargath Bladefist",         -- Shattered Halls
}

-- --------------------------------------------------------
-- Runtime state
-- --------------------------------------------------------
SAL.drops      = {}   -- reverse index: [itemID] = {{npcID=n, pct=p}, ...}
SAL.npcCache   = {}   -- runtime NPC name cache: [npcID] = name
SAL.targetNPC  = nil  -- current target NPC ID (number or nil)
SAL.atlasReady = false

-- --------------------------------------------------------
-- Resolve NPC name from ID
-- --------------------------------------------------------
local function GetNPCName(npcID)
    return SAL.npcCache[npcID] or BOSS_NAMES[npcID] or ("NPC #" .. npcID)
end

-- --------------------------------------------------------
-- Build/update the reverse drop index from a npcID table
-- --------------------------------------------------------
local function IndexDropTable(data)
    for npcID, items in pairs(data) do
        for itemID, pct in pairs(items) do
            if not SAL.drops[itemID] then
                SAL.drops[itemID] = {}
            end
            -- Avoid duplicates
            local found = false
            for _, entry in ipairs(SAL.drops[itemID]) do
                if entry.npcID == npcID then
                    entry.pct = pct
                    found = true
                    break
                end
            end
            if not found then
                table.insert(SAL.drops[itemID], { npcID = npcID, pct = pct })
            end
            -- Sort descending by pct after each write operation would be slow;
            -- we do a lazy sort on first read instead. See GetDropsForItem.
        end
    end
end

-- Sort drop list for an itemID (called lazily)
local sortedCache = {}  -- [itemID] = true if already sorted
local function GetDropsForItem(itemID)
    local list = SAL.drops[itemID]
    if not list then return nil end
    if not sortedCache[itemID] then
        table.sort(list, function(a, b) return a.pct > b.pct end)
        sortedCache[itemID] = true
    end
    return list
end

-- --------------------------------------------------------
-- Hook AtlasLoot.Data.Droprate.AddData to capture data
-- --------------------------------------------------------
local function HookAtlasLoot()
    if not _G.AtlasLoot or not _G.AtlasLoot.Data or not _G.AtlasLoot.Data.Droprate then
        return false
    end
    local orig = _G.AtlasLoot.Data.Droprate.AddData
    _G.AtlasLoot.Data.Droprate.AddData = function(self, data)
        if data and type(data) == "table" then
            IndexDropTable(data)
        end
        return orig(self, data)
    end
    SAL.atlasReady = true
    return true
end

-- --------------------------------------------------------
-- Tooltip integration
-- --------------------------------------------------------
local function AddDropLinesToTooltip(tooltip)
    if not SAL.db.tooltipEnabled then return end
    local _, link = tooltip:GetItem()
    if not link then return end
    local itemID = tonumber(link:match("item:(%d+)"))
    if not itemID then return end

    local list = GetDropsForItem(itemID)
    if not list or #list == 0 then return end

    local threshold = SAL.db.tooltipThreshold or 0

    -- Line 1: current target drop rate (if applicable)
    if SAL.db.tooltipTarget and SAL.targetNPC then
        for _, entry in ipairs(list) do
            if entry.npcID == SAL.targetNPC then
                if entry.pct >= threshold then
                    tooltip:AddLine(string.format(
                        "|cff00ff88Drop from target:|r |cffffd700%.2f%%|r",
                        entry.pct))
                end
                break
            end
        end
    end

    -- Line 2: best overall drop rate + source count
    if SAL.db.tooltipBest then
        local best = list[1]
        if best and best.pct >= threshold then
            if #list == 1 then
                tooltip:AddLine(string.format(
                    "|cff88bbffDrop rate:|r |cffffd700%.2f%%|r  |cff888888(%s)|r",
                    best.pct, GetNPCName(best.npcID)))
            else
                tooltip:AddLine(string.format(
                    "|cff88bbffBest drop:|r |cffffd700%.2f%%|r  |cff888888(%s, +%d more)|r",
                    best.pct, GetNPCName(best.npcID), #list - 1))
            end
            tooltip:Show()
        end
    end
end

-- Hook all relevant tooltips
local function HookTooltips()
    GameTooltip:HookScript("OnTooltipSetItem", function(self)
        AddDropLinesToTooltip(self)
    end)
    ItemRefTooltip:HookScript("OnTooltipSetItem", function(self)
        AddDropLinesToTooltip(self)
    end)
    if ShoppingTooltip1 then
        ShoppingTooltip1:HookScript("OnTooltipSetItem", function(self)
            AddDropLinesToTooltip(self)
        end)
    end
    if ShoppingTooltip2 then
        ShoppingTooltip2:HookScript("OnTooltipSetItem", function(self)
            AddDropLinesToTooltip(self)
        end)
    end
end

-- --------------------------------------------------------
-- NPC target tracking
-- --------------------------------------------------------
local function UpdateTarget()
    local guid = UnitGUID("target")
    SAL.targetNPC = nil
    if guid then
        -- Creature GUID format: Creature-0-realmID-mapID-zoneID-npcID-spawnUID
        local npcID = tonumber(guid:match("Creature%-%d+%-%d+%-%d+%-%d+%-(%d+)%-"))
        if npcID then
            SAL.targetNPC = npcID
            -- Cache the name
            local name = UnitName("target")
            if name and name ~= UNKNOWN then
                SAL.npcCache[npcID] = name
            end
        end
    end
end

-- --------------------------------------------------------
-- Slash commands & integration
-- --------------------------------------------------------
local function SAL_Slash(msg)
    msg = (msg or ""):lower():trim()
    if msg == "tooltip" or msg == "tip" then
        SAL.db.tooltipEnabled = not SAL.db.tooltipEnabled
        DEFAULT_CHAT_FRAME:AddMessage(
            "|cff88bbff[SlyAtlasLoot]|r Tooltip " ..
            (SAL.db.tooltipEnabled and "|cff44ff44enabled|r" or "|cffaaaaaa disabled|r"))
    elseif msg == "target" then
        SAL.db.tooltipTarget = not SAL.db.tooltipTarget
        DEFAULT_CHAT_FRAME:AddMessage(
            "|cff88bbff[SlyAtlasLoot]|r Target drop rate display " ..
            (SAL.db.tooltipTarget and "|cff44ff44on|r" or "|cffaaaaaa off|r"))
    elseif msg:match("^threshold") then
        local val = tonumber(msg:match("threshold%s+(%S+)"))
        if val then
            SAL.db.tooltipThreshold = math.max(0, math.min(100, val))
            DEFAULT_CHAT_FRAME:AddMessage(
                string.format("|cff88bbff[SlyAtlasLoot]|r Threshold set to %.1f%%",
                    SAL.db.tooltipThreshold))
        end
    elseif msg == "atlas" or msg == "al" then
        if _G.AtlasLoot and _G.AtlasLoot.GUI then
            _G.AtlasLoot.GUI:Toggle()
        end
    elseif msg == "stats" or msg == "info" then
        local count = 0
        for _ in pairs(SAL.drops) do count = count + 1 end
        DEFAULT_CHAT_FRAME:AddMessage(string.format(
            "|cff88bbff[SlyAtlasLoot]|r Indexed |cffffd700%d|r items with drop data.  AtlasLoot ready: %s",
            count, SAL.atlasReady and "|cff44ff44yes|r" or "|cffff4444no|r"))
    else
        SAL_TogglePanel()
    end
end

-- --------------------------------------------------------
-- Event frame & lifecycle
-- --------------------------------------------------------
local frame = CreateFrame("Frame", "SlyAtlasLootFrame", UIParent)
frame:RegisterEvent("ADDON_LOADED")
frame:RegisterEvent("PLAYER_LOGOUT")
frame:RegisterEvent("PLAYER_TARGET_CHANGED")
frame:RegisterEvent("PLAYER_ENTERING_WORLD")

frame:SetScript("OnEvent", function(self, event, ...)
    if event == "ADDON_LOADED" then
        local name = ...
        if name == "SlyAtlasLoot" then
            -- Init saved variables
            SlyAtlasLootDB = SlyAtlasLootDB or {}
            for k, v in pairs(DB_DEFAULTS) do
                if SlyAtlasLootDB[k] == nil then
                    SlyAtlasLootDB[k] = v
                end
            end
            SAL.db = SlyAtlasLootDB

            -- Try to hook AtlasLoot if already loaded
            HookAtlasLoot()

            -- Hook tooltips
            HookTooltips()

            -- Register slash
            SLASH_SLYATLAS1 = "/slyatlas"
            SLASH_SLYATLAS2 = "/slyatlasloot"
            SlashCmdList["SLYATLAS"] = SAL_Slash

            -- Register with SlySuite if present
            if SlySuite_Register then
                SlySuite_Register("SlyAtlasLoot", SAL.version, function()
                    -- init UI is called by SlySuite after DB ready
                    SAL_BuildPanel()
                end, {
                    description = "AtlasLoot drop rates on tooltips + item search",
                    slash       = "/slyatlas",
                    icon        = "Interface\\Icons\\INV_Misc_Map_01",
                })
            end
        end

        -- Hook AtlasLoot when its droprate module loads (may load after us)
        if name == "AtlasLootClassic" or name == "AtlasLootClassic_DungeonsAndRaids" then
            HookAtlasLoot()
        end
    elseif event == "PLAYER_TARGET_CHANGED" then
        UpdateTarget()
    elseif event == "PLAYER_ENTERING_WORLD" then
        -- Try hook again in case modules loaded late
        if not SAL.atlasReady then HookAtlasLoot() end
        UpdateTarget()
    elseif event == "PLAYER_LOGOUT" then
        if SAL.db then
            local pt, _, _, x, y = (SlyAtlasLootPanel or frame):GetPoint()
            SAL.db.position = { point = pt or "CENTER", x = x or 0, y = y or 0 }
        end
    end
end)

-- --------------------------------------------------------
-- Public helpers used by UI
-- --------------------------------------------------------

-- Search items by name fragment or exact item link/ID
-- Returns sorted list of { itemID, itemName, itemLink, drops[] }
function SAL_SearchItems(query)
    local results = {}
    query = query and query:lower() or ""

    -- Accept item link pasted directly
    local linkID = tonumber(query:match("item:(%d+)"))
    if linkID then
        -- direct lookup
        local drops = GetDropsForItem(linkID)
        if drops then
            local name, link = GetItemInfo(linkID)
            table.insert(results, { itemID = linkID, name = name or ("Item #"..linkID),
                link = link or ("item:"..linkID), drops = drops })
        end
        return results
    end

    if #query < 2 then return results end

    for itemID, _ in pairs(SAL.drops) do
        local drops = GetDropsForItem(itemID)
        if drops and #drops > 0 and drops[1].pct >= (SAL.db.tooltipThreshold or 0) then
            local name, link = GetItemInfo(itemID)
            if name and name:lower():find(query, 1, true) then
                table.insert(results, {
                    itemID = itemID,
                    name   = name,
                    link   = link or ("item:" .. itemID),
                    drops  = drops,
                })
            end
        end
    end

    -- Sort by best drop rate descending
    table.sort(results, function(a, b)
        return (a.drops[1] and a.drops[1].pct or 0) > (b.drops[1] and b.drops[1].pct or 0)
    end)

    return results
end

-- Get NPC display name (public, used by UI)
function SAL_GetNPCName(npcID) return GetNPCName(npcID) end

-- Get total number of indexed items
function SAL_GetIndexCount()
    local n = 0; for _ in pairs(SAL.drops) do n = n + 1 end; return n
end
