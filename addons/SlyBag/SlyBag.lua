-- ============================================================
-- SlyBag.lua  —  Bagnon-style unified bag window
-- Single frame shows all bag slots in one scrollable grid.
-- Hooks OpenAllBags / CloseAllBags so B key works.
-- /slybag  toggle  |  /slybag sort  |  /slybag reset
-- ============================================================

local ADDON_NAME    = "SlyBag"
local ADDON_VERSION = "1.1.4"

SlyBag = SlyBag or {}

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
local function HideBlizzardBags()
    -- Only hide visually; do NOT UnregisterAllEvents or hook OnShow.
    -- ContainerFrame events handle mouse-state cleanup during loot
    -- interactions — stripping them breaks right-click looting and
    -- corrupts camera right-click-drag (mouse pitch).
    for i = 1, NUM_CONTAINER_FRAMES or 5 do
        local f = _G["ContainerFrame" .. i]
        if f then f:Hide() end
    end
end

local function SlyBag_OpenHook()
    if SlyBagFrame then
        SlyBag_Refresh()
        SlyBagFrame:Show()
    end
end

local function SlyBag_CloseHook()
    if SlyBagFrame and SlyBagFrame:IsShown() then
        SlyBagFrame:Hide()
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
        HideBlizzardBags()

        hooksecurefunc("OpenAllBags",  SlyBag_OpenHook)
        hooksecurefunc("CloseAllBags", SlyBag_CloseHook)
        -- Do NOT hook ToggleBackpack — it is called from secure action buttons
        -- (the bag bar). A non-secure hook taints it, which propagates to loot
        -- confirmation dialogs and breaks corpse interaction.
        -- OpenAllBags / CloseAllBags already cover the B key in TBC.

        if SlySuite_Register then
            SlySuite_Register(ADDON_NAME, ADDON_VERSION, function() end, {
                description = "Bagnon-style bag window — all bags in one grid.",
                slash       = "/slybag",
                icon        = "Interface\\Buttons\\Button-Backpack-Up",
            })
        end
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
