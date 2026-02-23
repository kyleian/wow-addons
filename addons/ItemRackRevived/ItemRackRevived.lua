-- ============================================================
-- ItemRack Revived
-- Interface: 20504 (WoW TBC Anniversary)
-- A draggable gear set manager as a character sheet replacement.
-- ToS: Player-initiated only. No automation. No external calls.
-- ============================================================

local ADDON_NAME    = "ItemRackRevived"
local ADDON_VERSION = "1.0.0"

-- Namespace table — all globals prefixed IRR to avoid collisions
IRR = IRR or {}
IRR.version = ADDON_VERSION

-- Equipment slot definitions (id, GetInventorySlotInfo name, display label)
-- Arranged in left/right pairs matching character sheet layout
IRR.SLOT_PAIRS = {
    { { id=1,  slot="HeadSlot",          label="Head"      },
      { id=2,  slot="NeckSlot",          label="Neck"      } },
    { { id=3,  slot="ShoulderSlot",      label="Shoulder"  },
      { id=15, slot="BackSlot",          label="Back"      } },
    { { id=5,  slot="ChestSlot",         label="Chest"     },
      { id=4,  slot="ShirtSlot",         label="Shirt"     } },
    { { id=9,  slot="WristSlot",         label="Wrist"     },
      { id=19, slot="TabardSlot",        label="Tabard"    } },
    { { id=10, slot="HandsSlot",         label="Hands"     },
      { id=6,  slot="WaistSlot",         label="Waist"     } },
    { { id=7,  slot="LegsSlot",          label="Legs"      },
      { id=8,  slot="FeetSlot",          label="Feet"      } },
    { { id=11, slot="Finger0Slot",       label="Ring 1"    },
      { id=12, slot="Finger1Slot",       label="Ring 2"    } },
    { { id=13, slot="Trinket0Slot",      label="Trinket 1" },
      { id=14, slot="Trinket1Slot",      label="Trinket 2" } },
    { { id=16, slot="MainHandSlot",      label="Main Hand" },
      { id=17, slot="SecondaryHandSlot", label="Off Hand"  } },
    { { id=18, slot="RangedSlot",        label="Ranged"    },
      nil },
}

-- Flat list for iteration
IRR.SLOTS = {}
for _, pair in ipairs(IRR.SLOT_PAIRS) do
    if pair[1] then table.insert(IRR.SLOTS, pair[1]) end
    if pair[2] then table.insert(IRR.SLOTS, pair[2]) end
end

-- Item quality border colors (r, g, b)
IRR.QUALITY_COLORS = {
    [0] = {0.62, 0.62, 0.62},   -- Poor (grey)
    [1] = {1.00, 1.00, 1.00},   -- Common (white)
    [2] = {0.12, 1.00, 0.00},   -- Uncommon (green)
    [3] = {0.00, 0.44, 0.87},   -- Rare (blue)
    [4] = {0.64, 0.21, 0.93},   -- Epic (purple)
    [5] = {1.00, 0.50, 0.00},   -- Legendary (orange)
}

-- -------------------------------------------------------
-- Default SavedVariables structure
-- -------------------------------------------------------
local DB_DEFAULTS = {
    sets      = {},                             -- { [setName] = { [slotId] = itemId, ... } }
    specLinks = {},                             -- { [setName] = 1 or 2 }  dual-spec link
    position  = { point="CENTER", x=0, y=0 },
    options  = {
        showTooltips  = true,
        showQualityBorder = true,
        scale = 1.0,
    },
}

-- Recursively apply defaults without overwriting existing values
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
-- Event handling
-- -------------------------------------------------------
local eventFrame = CreateFrame("Frame")
eventFrame:RegisterEvent("ADDON_LOADED")
eventFrame:RegisterEvent("PLAYER_LOGOUT")
eventFrame:RegisterEvent("UNIT_INVENTORY_CHANGED")
eventFrame:RegisterEvent("PLAYER_ENTERING_WORLD")

eventFrame:SetScript("OnEvent", function(self, event, ...)
    if event == "ADDON_LOADED" then
        local name = ...
        if name == ADDON_NAME then
            -- Initialize saved variables
            ItemRackRevivedDB = ItemRackRevivedDB or {}
            ApplyDefaults(ItemRackRevivedDB, DB_DEFAULTS)
            IRR.db = ItemRackRevivedDB
            IRR_Init()
        end

    elseif event == "PLAYER_ENTERING_WORLD" then
        -- Refresh slots after loading screen
        if IRR.db and IRRFrame and IRRFrame:IsShown() then
            IRR_UpdateSlots()
        end

    elseif event == "UNIT_INVENTORY_CHANGED" then
        local unit = ...
        if unit == "player" and IRRFrame and IRRFrame:IsShown() then
            IRR_UpdateSlots()
        end

    elseif event == "PLAYER_LOGOUT" then
        IRR_OnLogout()
    end
end)

-- -------------------------------------------------------
-- Init
-- -------------------------------------------------------
function IRR_Init()
    IRR_BuildUI()
    print("|cff00ccff[ItemRack Revived]|r v" .. ADDON_VERSION
        .. " loaded.  |cffffcc00/itemrack|r to open.")
end

function IRR_OnLogout()
    if IRRFrame then
        local point, _, _, x, y = IRRFrame:GetPoint()
        IRR.db.position = { point = point or "CENTER", x = x or 0, y = y or 0 }
    end
end

-- -------------------------------------------------------
-- Slash commands
-- -------------------------------------------------------
SLASH_ITEMRACKREVIVED1 = "/itemrack"
SLASH_ITEMRACKREVIVED2 = "/irr"
SlashCmdList["ITEMRACKREVIVED"] = function(msg)
    msg = strtrim(msg):lower()

    if msg == "" or msg == "show" or msg == "toggle" then
        IRR_ToggleUI()

    elseif msg == "hide" then
        if IRRFrame then IRRFrame:Hide() end

    elseif msg == "reset" then
        IRR.db.position = { point="CENTER", x=0, y=0 }
        if IRRFrame then
            IRRFrame:ClearAllPoints()
            IRRFrame:SetPoint("CENTER")
        end
        print("|cff00ccff[ItemRack Revived]|r Frame position reset.")

    elseif msg == "help" then
        print("|cff00ccff[ItemRack Revived]|r Commands:")
        print("  |cffffcc00/itemrack|r           — toggle the gear panel")
        print("  |cffffcc00/itemrack reset|r      — reset frame to center")
        print("  |cffffcc00/itemrack help|r        — this text")
        print("  Tip: Right-click a gear set in the panel to delete it.")
    else
        print("|cff00ccff[ItemRack Revived]|r Unknown command. Type |cffffcc00/itemrack help|r.")
    end
end
