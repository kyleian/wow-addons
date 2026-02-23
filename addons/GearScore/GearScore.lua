-- ============================================================
-- GearScore
-- Interface: 20504 (WoW TBC Anniversary)
-- Calculates a numeric gear score based on item level and quality.
-- Displays score on item tooltips and a movable character frame summary.
-- ToS: Read-only inspection. No automation. No external calls.
-- ============================================================

local ADDON_NAME    = "GearScore"
local ADDON_VERSION = "1.0.0"

GS = GS or {}
GS.version = ADDON_VERSION

-- -------------------------------------------------------
-- Gear score formula
-- Weights item level by slot type (TBC-tuned multipliers)
-- from the popular original GearScore methodology.
-- -------------------------------------------------------

-- Slot multipliers (slot id -> weight)
local SLOT_WEIGHT = {
    [1]  = 1.00,   -- Head
    [2]  = 0.56,   -- Neck
    [3]  = 0.75,   -- Shoulder
    [4]  = 0.00,   -- Shirt (cosmetic, ignored)
    [5]  = 1.00,   -- Chest
    [6]  = 0.75,   -- Waist
    [7]  = 1.00,   -- Legs
    [8]  = 0.75,   -- Feet
    [9]  = 0.56,   -- Wrist
    [10] = 0.75,   -- Hands
    [11] = 0.56,   -- Ring 1
    [12] = 0.56,   -- Ring 2
    [13] = 0.56,   -- Trinket 1
    [14] = 0.56,   -- Trinket 2
    [15] = 0.56,   -- Back
    [16] = 1.00,   -- Main Hand
    [17] = 1.00,   -- Off Hand
    [18] = 0.56,   -- Ranged
    [19] = 0.00,   -- Tabard (cosmetic, ignored)
}

-- Quality modifiers (quality index -> multiplier over base)
local QUALITY_MOD = {
    [0] = 0.005,   -- Poor
    [1] = 0.010,   -- Common
    [2] = 0.030,   -- Uncommon
    [3] = 0.060,   -- Rare
    [4] = 0.100,   -- Epic
    [5] = 0.130,   -- Legendary
}

-- Score a single item link (0 if no link)
function GS_ScoreItem(itemLink)
    if not itemLink then return 0 end
    local _, _, quality, itemLevel = GetItemInfo(itemLink)
    if not quality or not itemLevel then return 0 end
    local qMod = QUALITY_MOD[quality] or 0
    return math.floor(itemLevel * qMod * 11.25 + 0.5)
end

-- Score a single inventory slot
function GS_ScoreSlot(slotId)
    local link = GetInventoryItemLink("player", slotId)
    local score = GS_ScoreItem(link)
    local weight = SLOT_WEIGHT[slotId] or 0
    return math.floor(score * weight + 0.5)
end

-- Total GearScore for the player
function GS_GetTotalScore()
    local total = 0
    for slotId = 1, 19 do
        total = total + GS_ScoreSlot(slotId)
    end
    return total
end

-- -------------------------------------------------------
-- Tooltip hook — adds GearScore line to item tooltips
-- -------------------------------------------------------
GameTooltip:HookScript("OnTooltipSetItem", function(self)
    local _, link = self:GetItem()
    if not link then return end
    local score = GS_ScoreItem(link)
    if score and score > 0 then
        self:AddLine("|cffffcc00GearScore:|r " .. score, 1, 1, 1)
        self:Show()
    end
end)

-- -------------------------------------------------------
-- Default saved variables
-- -------------------------------------------------------
local DB_DEFAULTS = {
    enabled  = true,
    position = { point="CENTER", x=150, y=0 },
    options  = {
        showOnTooltip   = true,
        showOnCharFrame = true,
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

-- -------------------------------------------------------
-- Character frame summary badge
-- -------------------------------------------------------
local gsLabel = nil

local function CreateGSBadge()
    if gsLabel then return end
    local badge = CreateFrame("Frame", "GSBadgeFrame", UIParent)
    badge:SetSize(120, 24)
    badge:SetFrameStrata("HIGH")
    badge:SetMovable(true)
    badge:EnableMouse(true)
    badge:RegisterForDrag("LeftButton")
    badge:SetScript("OnDragStart", badge.StartMoving)
    badge:SetScript("OnDragStop", function(self)
        self:StopMovingOrSizing()
        local pt, _, _, x, y = self:GetPoint()
        GS.db.position = { point = pt, x = x, y = y }
    end)

    local pos = GS.db.position
    badge:ClearAllPoints()
    badge:SetPoint(pos.point or "CENTER", UIParent, pos.point or "CENTER",
        pos.x or 150, pos.y or 0)

    local bg = badge:CreateTexture(nil, "BACKGROUND")
    bg:SetAllPoints(badge)
    bg:SetColorTexture(0, 0, 0, 0.7)

    local lbl = badge:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    lbl:SetFont(lbl:GetFont(), 12, "OUTLINE")
    lbl:SetAllPoints(badge)
    lbl:SetJustifyH("CENTER")
    lbl:SetText("GS: ---")
    lbl:SetTextColor(1, 0.82, 0)
    gsLabel = lbl

    badge:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_TOPRIGHT")
        GameTooltip:ClearLines()
        GameTooltip:AddLine("|cff00ccffGearScore|r", 1, 1, 1)
        for slotId = 1, 19 do
            if SLOT_WEIGHT[slotId] and SLOT_WEIGHT[slotId] > 0 then
                local link = GetInventoryItemLink("player", slotId)
                if link then
                    local name = GetItemInfo(link)
                    local score = GS_ScoreSlot(slotId)
                    if name and score > 0 then
                        GameTooltip:AddDoubleLine(name, score,
                            0.9, 0.9, 0.9, 1, 0.82, 0)
                    end
                end
            end
        end
        GameTooltip:AddLine(" ")
        GameTooltip:AddDoubleLine("Total GearScore", GS_GetTotalScore(),
            0.9, 0.9, 0.9, 1, 0.82, 0)
        GameTooltip:Show()
    end)
    badge:SetScript("OnLeave", function() GameTooltip:Hide() end)

    GSBadgeFrame = badge
end

local function GS_UpdateBadge()
    if gsLabel then
        gsLabel:SetText("GS: " .. GS_GetTotalScore())
    end
end

-- -------------------------------------------------------
-- Events
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
            GearScoreDB = GearScoreDB or {}
            ApplyDefaults(GearScoreDB, DB_DEFAULTS)
            GS.db = GearScoreDB
            CreateGSBadge()
            GS_UpdateBadge()
            print("|cff00ccff[GearScore]|r v" .. ADDON_VERSION
                .. " loaded.  |cffffcc00/gs|r for help.")
        end

    elseif event == "PLAYER_ENTERING_WORLD" then
        GS_UpdateBadge()

    elseif event == "UNIT_INVENTORY_CHANGED" then
        local unit = ...
        if unit == "player" then GS_UpdateBadge() end

    elseif event == "PLAYER_LOGOUT" then
        if GSBadgeFrame then
            local point, _, _, x, y = GSBadgeFrame:GetPoint()
            GS.db.position = { point=point or "CENTER", x=x or 150, y=y or 0 }
        end
    end
end)

-- -------------------------------------------------------
-- Slash commands
-- -------------------------------------------------------
SLASH_GEARSCORE1 = "/gs"
SLASH_GEARSCORE2 = "/gearscore"
SlashCmdList["GEARSCORE"] = function(msg)
    msg = strtrim(msg):lower()
    if msg == "" or msg == "score" then
        print("|cff00ccff[GearScore]|r Your total gear score: |cffffcc00"
            .. GS_GetTotalScore() .. "|r")
    elseif msg == "toggle" then
        if GSBadgeFrame then
            if GSBadgeFrame:IsShown() then GSBadgeFrame:Hide()
            else GSBadgeFrame:Show() end
        end
    elseif msg == "help" then
        print("|cff00ccff[GearScore]|r Commands:")
        print("  |cffffcc00/gs|r          -- show total score")
        print("  |cffffcc00/gs toggle|r   -- show/hide the badge frame")
        print("  Hover over the badge for a per-slot breakdown.")
    end
end
