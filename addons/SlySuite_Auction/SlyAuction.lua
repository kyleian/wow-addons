-- ================================================================
-- SlyAuction.lua  —  AH scan engine, data recording, market stats
--
-- Architecture:
--   SA_ScanAll()  → builds _scanQueue from SLYAUCTION_ITEMS
--   QueryAuctionItems() fires for head of queue
--   AUCTION_ITEM_LIST_UPDATE → CollectCurrentPage() → AdvanceScan()
--   AdvanceScan():  if more pages → next page query
--                   else         → RecordScan → next item
--
-- /slyauction   or   /sa   to toggle UI
-- /slyauction scan    — start full scan (must be at AH)
-- /slyauction stop    — abort current scan
-- /slyauction reset   — wipe all price history
-- ================================================================

local ADDON_NAME    = "SlySuite_Auction"
local ADDON_VERSION = "1.3.1"

SlyAuction          = SlyAuction or {}
SlyAuction.version  = ADDON_VERSION
SlyAuction.status   = "idle"       -- "idle" | "scanning" | "error"
SlyAuction.statusText = "Idle"

-- ----------------------------------------------------------------
-- SavedVariables schema / defaults
-- ----------------------------------------------------------------
local DB_DEFAULTS = {
    priceHistory = {},   -- [itemName] = { id, scans, stats, listings }
    settings = {
        snipeThreshold = 0.85,  -- buy when perUnit < avg7d * threshold
        listMarkup     = 0.98,  -- suggest sell at floor * markup (undercut)
        maxHistoryDays = 30,
        maxScansStored = 40,
    },
    lastScanTime = nil,
}

local function _ApplyDefaults(dest, src)
    for k, v in pairs(src) do
        if dest[k] == nil then
            dest[k] = type(v) == "table" and {} or v
        end
        if type(v) == "table" and type(dest[k]) == "table" then
            _ApplyDefaults(dest[k], v)
        end
    end
end

-- ----------------------------------------------------------------
-- Scan engine state (module-private)
-- ----------------------------------------------------------------
local _ahOpen      = false
local _scanActive  = false
local _scanQueue   = {}   -- ordered list of item names pending scan
local _currentItem = nil  -- { name, page, totalPages, listings={} }
local _scanStart   = nil
local _nScanned    = 0

-- ----------------------------------------------------------------
-- Copper formatting helpers (also used by UI)
-- ----------------------------------------------------------------
function SA_FormatCopper(c)
    if not c or c <= 0 then return "--" end
    local g  = math.floor(c / 10000)
    local s  = math.floor((c % 10000) / 100)
    local co = c % 100
    if g > 0 then
        return string.format("|cffffd700%dg|r |cffc0c0c0%ds|r |cffeda55f%dc|r", g, s, co)
    elseif s > 0 then
        return string.format("|cffc0c0c0%ds|r |cffeda55f%dc|r", s, co)
    end
    return string.format("|cffeda55f%dc|r", co)
end

function SA_FormatCopperShort(c)
    if not c or c <= 0 then return "--" end
    local g = c / 10000
    if g >= 1    then return string.format("%.1fg", g) end
    local sv = c / 100
    if sv >= 1   then return string.format("%.1fs", sv) end
    return c .. "c"
end

-- ================================================================
-- Statistics
-- ================================================================
local function _ComputeStats(entry)
    local scans = entry.scans
    if not scans or #scans == 0 then entry.stats = {}; return end

    local now        = time()
    local sum7, n7   = 0, 0
    local sum14, n14 = 0, 0

    for i = 1, #scans do
        local scan = scans[i]
        local age  = now - scan.t
        if age <= 7  * 86400 then sum7  = sum7  + scan.min; n7  = n7  + 1 end
        if age <= 14 * 86400 then sum14 = sum14 + scan.min; n14 = n14 + 1 end
    end

    local stats  = entry.stats or {}
    stats.avg7d  = n7  > 0 and math.floor(sum7  / n7)  or nil
    stats.avg14d = n14 > 0 and math.floor(sum14 / n14) or nil

    -- Trend: compare older half vs newer half of the last 10 scans.
    -- Negative = price falling (good to buy), positive = rising (good to sell).
    local window = math.min(10, #scans)
    if window >= 4 then
        local half = math.floor(window / 2)
        local s1, s2 = 0, 0
        for i = #scans - window + 1, #scans - half do s1 = s1 + scans[i].min end
        for i = #scans - half + 1,   #scans            do s2 = s2 + scans[i].min end
        stats.trend = (s2 / half - s1 / half) / math.max(s1 / half, 1)
    else
        stats.trend = 0
    end

    local last          = scans[#scans]
    stats.lastMin       = last.min
    stats.lastMedian    = last.median
    stats.lastAvg       = last.avg
    stats.lastCount     = last.count   -- number of distinct listings
    stats.lastQty       = last.qty     -- total units across listings
    stats.lastScan      = last.t

    -- Opportunity score: how far below the 7d avg the floor currently is.
    -- Positive  → floor is cheap relative to history → buy signal.
    -- Negative  → floor is expensive                 → sell / hold signal.
    if stats.avg7d and stats.lastMin and stats.avg7d > 0 then
        stats.opp = (stats.avg7d - stats.lastMin) / stats.avg7d
    else
        stats.opp = 0
    end

    entry.stats = stats
end

-- ================================================================
-- Record a completed scan page-set for one item
-- ================================================================
local function _RecordScan(itemName, listings)
    if not SlyAuctionDB then return end
    if #listings == 0 then return end

    -- Sort cheapest per-unit first
    table.sort(listings, function(a, b) return a.perUnit < b.perUnit end)

    local minP     = listings[1].perUnit
    local total, totalQty = 0, 0
    for _, l in ipairs(listings) do
        total    = total    + l.perUnit * l.qty
        totalQty = totalQty + l.qty
    end
    local avgP    = math.floor(total / math.max(totalQty, 1))
    local midIdx  = math.ceil(#listings / 2)
    local medianP = listings[midIdx].perUnit

    local snap = {
        t      = time(),
        min    = minP,
        median = medianP,
        avg    = avgP,
        count  = #listings,
        qty    = totalQty,
    }

    local entry = SlyAuctionDB.priceHistory[itemName]
    if not entry then
        local def = SLYAUCTION_ITEM_BY_NAME and SLYAUCTION_ITEM_BY_NAME[itemName]
        entry = { id = (def and def.id or 0), scans = {}, stats = {}, listings = {} }
        SlyAuctionDB.priceHistory[itemName] = entry
    end

    -- Persist last 30 cheapest listings for the buy panel
    local cheapList = {}
    for i = 1, math.min(30, #listings) do
        cheapList[i] = listings[i]
    end
    entry.listings = cheapList

    -- Auto-update the item ID from a live listing (corrects seeded guesses)
    for _, l in ipairs(listings) do
        if l.itemId and l.itemId > 0 then
            entry.id = l.itemId
            -- Also patch the static definition so SA_CountInBags is accurate
            local def = SLYAUCTION_ITEM_BY_NAME and SLYAUCTION_ITEM_BY_NAME[itemName]
            if def then def.id = l.itemId end
            break
        end
    end

    table.insert(entry.scans, snap)

    -- Prune by age
    local cfg     = SlyAuctionDB.settings
    local cutoff  = time() - cfg.maxHistoryDays * 86400
    while #entry.scans > 0 and entry.scans[1].t < cutoff do
        table.remove(entry.scans, 1)
    end
    -- Prune by count cap
    while #entry.scans > cfg.maxScansStored do
        table.remove(entry.scans, 1)
    end

    _ComputeStats(entry)
end

-- ================================================================
-- Scan engine — page collection and queue advancement
-- ================================================================
local function _CollectCurrentPage()
    if not _currentItem then return end

    local numBatch, totalAuctions = GetNumAuctionItems("list")
    _currentItem.totalAuctions = totalAuctions or 0

    local pagesNeeded = math.max(1, math.ceil((_currentItem.totalAuctions) / 50))
    _currentItem.totalPages = pagesNeeded

    for i = 1, numBatch do
        local name, _, count, _, _, _, _, _, _, buyoutPrice, _, _, _, _, _, _, itemId =
            GetAuctionItemInfo("list", i)
        -- Only collect exact name matches to avoid partial-name pollution
        if name == _currentItem.name
        and buyoutPrice and buyoutPrice > 0
        and count       and count       > 0
        then
            table.insert(_currentItem.listings, {
                perUnit = math.floor(buyoutPrice / count),
                qty     = count,
                buyout  = buyoutPrice,
                auctIdx = i,
                itemId  = itemId or 0,
            })
        end
    end
end

local function _SetStatus(st, txt)
    SlyAuction.status     = st
    SlyAuction.statusText = txt
    if SA_UI_OnStatusUpdate then SA_UI_OnStatusUpdate() end
end

local function _AdvanceScan()
    if not _scanActive then return end

    -- AH was closed mid-scan
    if not _ahOpen then
        _SetStatus("error", "AH closed - scan stopped")
        _scanActive = false
        return
    end

    -- Throttle guard
    if not CanSendAuctionQuery() then
        C_Timer.After(0.4, _AdvanceScan)
        return
    end

    -- More pages for the current item?
    if _currentItem and (_currentItem.page < _currentItem.totalPages - 1) then
        _currentItem.page = _currentItem.page + 1
        _SetStatus("scanning", string.format("Scanning %s  (page %d / %d)...",
            _currentItem.name, _currentItem.page + 1, _currentItem.totalPages))
        QueryAuctionItems(_currentItem.name, nil, nil, nil, nil, nil,
            _currentItem.page, nil, nil)
        return
    end

    -- Finalise the current item
    if _currentItem then
        _RecordScan(_currentItem.name, _currentItem.listings)
        _nScanned = _nScanned + 1
        -- Let buy-automation run while AH results are still fresh
        if SA_TryExecuteBuys then SA_TryExecuteBuys(_currentItem.name) end
        if SA_UI_OnItemScanned then SA_UI_OnItemScanned(_currentItem.name) end
        _currentItem = nil
    end

    -- Grab the next item from the queue
    if #_scanQueue > 0 then
        local nextName = table.remove(_scanQueue, 1)
        _currentItem   = { name=nextName, page=0, totalPages=1, listings={} }
        local total    = SLYAUCTION_ITEMS and #SLYAUCTION_ITEMS or 1
        _SetStatus("scanning", string.format("Scanning %s  (%d / %d)...",
            nextName, _nScanned + 1, total))
        QueryAuctionItems(nextName, nil, nil, nil, nil, nil, 0, nil, nil)
    else
        -- All done
        if SlyAuctionDB then SlyAuctionDB.lastScanTime = time() end
        local elapsed = _scanStart and (time() - _scanStart) or 0
        _scanActive   = false
        _nScanned     = 0
        _SetStatus("idle", string.format("Scan complete - %d items  (%.0fs)",
            _nScanned == 0 and #SLYAUCTION_ITEMS or _nScanned, elapsed))
        if SA_UI_OnScanComplete then SA_UI_OnScanComplete() end
    end
end

-- ================================================================
-- Public scan API
-- ================================================================
function SA_ScanAll()
    if not _ahOpen then
        print("|cffffcc00[SlyAuction]|r You must be at an Auction House to scan.")
        return
    end
    if _scanActive then
        print("|cffffcc00[SlyAuction]|r Scan already in progress. /sa stop to cancel.")
        return
    end

    _scanQueue   = {}
    for _, item in ipairs(SLYAUCTION_ITEMS) do
        table.insert(_scanQueue, item.name)
    end
    _scanActive  = true
    _nScanned    = 0
    _scanStart   = time()
    _currentItem = nil
    _SetStatus("scanning", "Starting scan...")
    _AdvanceScan()
end

function SA_ScanItem(name)
    if not _ahOpen then
        print("|cffffcc00[SlyAuction]|r You must be at an Auction House.")
        return
    end
    if _scanActive then
        -- Insert at front so it runs next
        table.insert(_scanQueue, 1, name)
        return
    end
    _scanQueue   = {}
    _scanActive  = true
    _nScanned    = 0
    _scanStart   = time()
    _currentItem = { name=name, page=0, totalPages=1, listings={} }
    _SetStatus("scanning", "Scanning " .. name .. "...")
    QueryAuctionItems(name, nil, nil, nil, nil, nil, 0, nil, nil)
end

function SA_StopScan()
    _scanActive  = false
    _scanQueue   = {}
    _currentItem = nil
    _SetStatus("idle", "Scan stopped")
end

-- ================================================================
-- Data query helpers
-- ================================================================
function SA_GetStats(name)
    if not SlyAuctionDB then return nil end
    return SlyAuctionDB.priceHistory[name]
end

function SA_GetSettings()
    return (SlyAuctionDB and SlyAuctionDB.settings) or DB_DEFAULTS.settings
end

-- Count how many of a given itemId are in the player's bags
function SA_CountInBags(itemId)
    if not itemId or itemId == 0 then return 0 end
    local total = 0
    for bag = 0, 4 do
        local numSlots
        if C_Container then
            numSlots = C_Container.GetContainerNumSlots(bag) or 0
        else
            numSlots = GetContainerNumSlots(bag) or 0
        end
        for slot = 1, numSlots do
            if C_Container then
                local info = C_Container.GetContainerItemInfo(bag, slot)
                if info and info.itemID == itemId then
                    total = total + (info.stackCount or 1)
                end
            else
                local id = GetContainerItemID(bag, slot)
                if id == itemId then
                    local _, count = GetContainerItemInfo(bag, slot)
                    total = total + (count or 1)
                end
            end
        end
    end
    return total
end

-- Suggested per-unit sell price: undercut current floor by 1c,
-- but never below (7d avg * listMarkup) to avoid underselling.
function SA_SuggestSellPrice(name)
    local entry = SA_GetStats(name)
    if not entry or not entry.stats then return nil end
    local cfg   = SA_GetSettings()
    local floor = entry.stats.lastMin
    if not floor or floor <= 0 then return nil end
    local undercut = floor - 1
    local floor7d  = entry.stats.avg7d
    local minPrice = floor7d and math.floor(floor7d * cfg.listMarkup) or 0
    return math.max(undercut, minPrice)
end

-- ================================================================
-- Pending buy-automation state
-- ================================================================
SlyAuction._buyPending = nil   -- { name, maxQty, thresh }

-- Called by _AdvanceScan right after a single-item scan finishes,
-- while the AH "list" results are still valid for PlaceAuctionBid.
function SA_TryExecuteBuys(name)
    local p = SlyAuction._buyPending
    if not p or p.name ~= name then return end
    SlyAuction._buyPending = nil

    local numBatch = GetNumAuctionItems("list")
    local bought   = 0

    for i = 1, numBatch do
        if bought >= p.maxQty then break end
        local aName, _, count, _, _, _, _, _, _, buyoutPrice =
            GetAuctionItemInfo("list", i)
        if aName == name
        and buyoutPrice and buyoutPrice > 0
        and count       and count       > 0
        then
            local perUnit = buyoutPrice / count
            if perUnit <= p.thresh then
                local ok = pcall(PlaceAuctionBid, "list", i, buyoutPrice)
                if ok then
                    bought = bought + count
                    print(string.format("|cff44ff44[SlyAuction]|r Bought x%d %s @ %s/unit",
                        count, name, SA_FormatCopperShort(perUnit)))
                end
            end
        end
    end

    if bought == 0 then
        print("|cffaaaaaa[SlyAuction]|r No listings found below snipe threshold.")
    elseif bought > 0 then
        -- Re-scan to update our price data after buying
        C_Timer.After(1.5, function() SA_ScanItem(name) end)
    end
end

-- Queue a snipe-buy for up to maxQty units below the snipe threshold.
function SA_BuyBelow(name, maxQty)
    if not _ahOpen then
        print("|cffffcc00[SlyAuction]|r Open the Auction House first.")
        return
    end
    local entry = SA_GetStats(name)
    local cfg   = SA_GetSettings()
    local avg   = entry and entry.stats and entry.stats.avg7d
    if not avg then
        print("|cffffcc00[SlyAuction]|r No price history for " .. name .. " - scan first.")
        return
    end
    local thresh = avg * cfg.snipeThreshold
    SlyAuction._buyPending = { name=name, maxQty=maxQty, thresh=thresh }
    print(string.format("|cffffcc00[SlyAuction]|r Scanning %s - will buy up to %d units below %s...",
        name, maxQty, SA_FormatCopperShort(thresh)))
    SA_ScanItem(name)
end

-- ================================================================
-- Event frame
-- ================================================================
local _evtFrame = CreateFrame("Frame")
_evtFrame:RegisterEvent("ADDON_LOADED")
_evtFrame:RegisterEvent("AUCTION_HOUSE_SHOW")
_evtFrame:RegisterEvent("AUCTION_HOUSE_CLOSED")
_evtFrame:RegisterEvent("AUCTION_ITEM_LIST_UPDATE")

_evtFrame:SetScript("OnEvent", function(self, event, arg1)
    if event == "ADDON_LOADED" and arg1 == ADDON_NAME then
        if SlyAuctionDB == nil then SlyAuctionDB = {} end
        _ApplyDefaults(SlyAuctionDB, DB_DEFAULTS)
        -- Recompute persisted stats in case the formula changed
        for _, entry in pairs(SlyAuctionDB.priceHistory) do
            _ComputeStats(entry)
        end
        -- Register with SlySuite if present; otherwise init directly
        if SlySuite_Register then
            SlySuite_Register(ADDON_NAME, ADDON_VERSION, function()
                if SA_BuildUI then SA_BuildUI() end
            end, {
                description = "AH scanner: tracks trade good prices, flags buy/sell opportunities.",
                slash       = "/slyauction",
            })
        else
            C_Timer.After(0, function()
                if SA_BuildUI then SA_BuildUI() end
            end)
        end

    elseif event == "AUCTION_HOUSE_SHOW" then
        _ahOpen = true
        if SA_UI_OnAHOpen then SA_UI_OnAHOpen() end

    elseif event == "AUCTION_HOUSE_CLOSED" then
        _ahOpen = false
        if _scanActive then SA_StopScan() end
        if SA_UI_OnAHClose then SA_UI_OnAHClose() end

    elseif event == "AUCTION_ITEM_LIST_UPDATE" then
        if _scanActive and _currentItem then
            _CollectCurrentPage()
            -- Small delay so any pending page results settle
            C_Timer.After(0.15, _AdvanceScan)
        end
    end
end)

-- ================================================================
-- Slash commands
-- ================================================================
SLASH_SLYAUCTION1 = "/slyauction"
SLASH_SLYAUCTION2 = "/sa"
SlashCmdList["SLYAUCTION"] = function(msg)
    local cmd = (msg or ""):match("^(%S*)"):lower()
    if     cmd == "scan"  then SA_ScanAll()
    elseif cmd == "stop"  then SA_StopScan()
    elseif cmd == "reset" then
        SlyAuctionDB.priceHistory = {}
        SlyAuctionDB.lastScanTime = nil
        print("|cffffcc00[SlyAuction]|r Price history cleared.")
    else
        if SA_ToggleUI then SA_ToggleUI() end
    end
end
