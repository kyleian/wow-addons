-- ============================================================
-- SlyBag.lua  —  Bagnon-style unified bag window
-- Single frame shows all bag slots in one scrollable grid.
-- Hooks OpenAllBags / CloseAllBags so B key works.
-- /slybag  toggle  |  /slybag sort  |  /slybag reset
-- ============================================================

local ADDON_NAME = "SlySuite_Bag"
local ADDON_VERSION = "1.1.4"

SlyBag = SlyBag or {}
SlyBag.newItems = {}   -- { ["bag:slot"] = {bag,slot} } items gained this session
SlyBag._prevInv = {}   -- [bagId][slot] = itemId string, for change detection

-- -------------------------------------------------------
-- New-item tracking
-- -------------------------------------------------------
local function _SBGetLink(bag, slot)
    if C_Container and C_Container.GetContainerItemLink then
        return C_Container.GetContainerItemLink(bag, slot)
    end
    return GetContainerItemLink(bag, slot)
end
local function _SBNumSlots(bag)
    if C_Container and C_Container.GetContainerNumSlots then
        return C_Container.GetContainerNumSlots(bag) or 0
    end
    return GetContainerNumSlots(bag) or 0
end

local function SnapshotInventory()
    for bag = 0, 4 do
        SlyBag._prevInv[bag] = {}
        for slot = 1, _SBNumSlots(bag) do
            local link = _SBGetLink(bag, slot)
            SlyBag._prevInv[bag][slot] = link and link:match("|Hitem:(%d+):") or nil
        end
    end
end

local function TrackNewItems(bagId)
    -- TBC Classic fires BAG_UPDATE with no argument; scan all bags in that case.
    local bags = (bagId ~= nil) and { bagId } or { 0, 1, 2, 3, 4 }
    for _, bid in ipairs(bags) do
        local prev = SlyBag._prevInv[bid] or {}
        local curr = {}
        for slot = 1, _SBNumSlots(bid) do
            local link = _SBGetLink(bid, slot)
            local id = link and link:match("|Hitem:(%d+):") or nil
            curr[slot] = id
            if id and id ~= prev[slot] then
                SlyBag.newItems[bid.."|"..slot] = { bag=bid, slot=slot }
            end
        end
        SlyBag._prevInv[bid] = curr
    end
end

local DB_DEFAULTS = {
    position      = { point = "CENTER", x = 0, y = 0 },
    sortMode      = "BAG",     -- "BAG" | "QUALITY" | "NAME"
    cols          = 10,
    showBagBreaks = true,
    scale         = 1.0,
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
-- Suppress all default container frames
-- -------------------------------------------------------
local function HookBlizzardBags()
    -- Hook each ContainerFrame's OnShow to redirect to SlyBag.
    -- Using HookScript fires AFTER the secure call exits — no taint.
    -- Never hooksecurefunc("OpenAllBags") — that is called from secure
    -- bag-bar buttons and taints loot confirmation / right-click looting.
    for i = 1, NUM_CONTAINER_FRAMES or 5 do
        local f = _G["ContainerFrame" .. i]
        if f then
            f:HookScript("OnShow", function(self)
                self:Hide()   -- suppress the Blizzard frame
                if SlyBagFrame then
                    -- Because all ContainerFrames are always hidden, AreAllBagsOpen()
                    -- always returns false, so B always fires OpenAllBags rather than
                    -- CloseAllBags. We toggle manually here to give proper B-key behaviour.
                    if SlyBagFrame:IsShown() then
                        SlyBagFrame:Hide()
                    else
                        SlyBag_Refresh()
                        SlyBagFrame:Show()
                    end
                end
            end)
            f:Hide()          -- hide any already-visible frame at load time
        end
    end
end

-- -------------------------------------------------------
-- Events
-- -------------------------------------------------------
local ef = CreateFrame("Frame")
ef:RegisterEvent("ADDON_LOADED")
ef:RegisterEvent("BAG_UPDATE")
ef:RegisterEvent("ITEM_LOCK_CHANGED")
ef:RegisterEvent("PLAYER_MONEY")

ef:SetScript("OnEvent", function(self, event, arg1)
    if event == "ADDON_LOADED" then
        if arg1 ~= ADDON_NAME then return end
        SlyBagDB = SlyBagDB or {}
        ApplyDefaults(SlyBagDB, DB_DEFAULTS)
        SlyBag.db = SlyBagDB

        SlyBag_BuildUI()
        HookBlizzardBags()
        SnapshotInventory()  -- seed before tracking; nothing marked new on load

        if SlySuiteDataFrame and SlySuiteDataFrame.Register then
            SlySuiteDataFrame.Register(ADDON_NAME, ADDON_VERSION, function() end, {
                description = "Bagnon-style bag window \226\128\148 all bags in one grid.",
                slash       = "/slybag",
                icon        = "Interface\\Buttons\\Button-Backpack-Up",
            })
        end
    elseif event == "BAG_UPDATE" then
        TrackNewItems(arg1)
        if SlyBagFrame and SlyBagFrame:IsShown() then SlyBag_Refresh() end
    else
        if SlyBagFrame and SlyBagFrame:IsShown() then SlyBag_Refresh() end
    end
end)

-- -------------------------------------------------------
-- Slash
-- -------------------------------------------------------
SLASH_SLYBAG1 = "/slybag"
SLASH_SLYBAG2 = "/bag"
SlashCmdList["SLYBAG"] = function(msg)
    msg = strtrim(msg or ""):lower()
    if msg == "sort" then
        local modes = { BAG = "QUALITY", QUALITY = "NAME", NAME = "BAG" }
        local labels = { BAG = "Bag order", QUALITY = "Quality", NAME = "Name" }
        SlyBag.db.sortMode = modes[SlyBag.db.sortMode] or "BAG"
        print("|cff00ccff[SlyBag]|r Sort: " .. labels[SlyBag.db.sortMode])
        if SlyBagFrame and SlyBagFrame:IsShown() then SlyBag_Refresh() end
    elseif msg == "reset" then
        SlyBag.db.position = { point = "CENTER", x = 0, y = 0 }
        if SlyBagFrame then
            SlyBagFrame:ClearAllPoints()
            SlyBagFrame:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
        end
        print("|cff00ccff[SlyBag]|r Position reset.")
    elseif msg == "break" or msg == "breaks" then
        SlyBag.db.showBagBreaks = not SlyBag.db.showBagBreaks
        print("|cff00ccff[SlyBag]|r Bag breaks: " .. (SlyBag.db.showBagBreaks and "ON" or "OFF"))
        if SlyBagFrame and SlyBagFrame:IsShown() then SlyBag_Refresh() end
    else
        if SlyBagFrame then
            if SlyBagFrame:IsShown() then SlyBagFrame:Hide()
            else SlyBag_Refresh(); SlyBagFrame:Show() end
        end
    end
end
