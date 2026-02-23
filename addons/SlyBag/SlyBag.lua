-- ============================================================
-- SlyBag.lua  —  Unified bag window
-- All bags merged into one searchable grid.
-- Replaces Baganator. /slybag to toggle.
-- ============================================================

local ADDON_NAME    = "SlyBag"
local ADDON_VERSION = "1.0.0"

SlyBag = SlyBag or {}

local DB_DEFAULTS = {
    position = { point = "CENTER", x = 0, y = 0 },
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
-- Events
-- -------------------------------------------------------
local ef = CreateFrame("Frame")
ef:RegisterEvent("ADDON_LOADED")
ef:RegisterEvent("BAG_UPDATE")
ef:RegisterEvent("ITEM_LOCK_CHANGED")
ef:RegisterEvent("PLAYER_MONEY")

ef:SetScript("OnEvent", function(self, event, arg1)
    if event == "ADDON_LOADED" then
        if arg1 == ADDON_NAME then
            SlyBagDB = SlyBagDB or {}
            ApplyDefaults(SlyBagDB, DB_DEFAULTS)
            SlyBag.db = SlyBagDB

            SlyBag_BuildUI()

            -- Register with SlySuite if available
            if SlySuite_Register then
                SlySuite_Register(ADDON_NAME, ADDON_VERSION, function() end, {
                    description = "Unified bag window — all bags in one view.",
                    slash       = "/slybag",
                    icon        = "Interface\\Buttons\\Button-Backpack-Up",
                })
            end
        end
    else
        -- BAG_UPDATE, ITEM_LOCK_CHANGED, PLAYER_MONEY
        if SlyBagFrame and SlyBagFrame:IsShown() then
            SlyBag_Refresh()
        end
    end
end)

-- -------------------------------------------------------
-- Slash commands
-- -------------------------------------------------------
SLASH_SLYBAG1 = "/slybag"
SlashCmdList["SLYBAG"] = function()
    if SlyBagFrame then
        if SlyBagFrame:IsShown() then
            SlyBagFrame:Hide()
        else
            SlyBag_Refresh()
            SlyBagFrame:Show()
        end
    end
end
