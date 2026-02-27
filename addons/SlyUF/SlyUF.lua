-- ============================================================
-- SlyUF.lua  —  Sly Unit Frames core
-- Player / Target / Target-of-Target / Party
-- Replaces ZPerl.  /slyuf to toggle enable.
-- ============================================================

local ADDON_NAME    = "SlyUF"
local ADDON_VERSION = "1.0.0"

SlyUF = SlyUF or {}
SlyUF.frames = {}   -- registered unit frames for bulk update

-- -------------------------------------------------------
-- Saved variables defaults
-- -------------------------------------------------------
local DB_DEFAULTS = {
    enabled   = true,
    positions = {},   -- [frameName] = {point, x, y}
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
-- Color tables
-- -------------------------------------------------------
SlyUF.POWER_COLORS = {
    [0] = { r=0.00, g=0.00, b=1.00 },   -- Mana
    [1] = { r=0.78, g=0.25, b=0.25 },   -- Rage
    [2] = { r=1.00, g=0.50, b=0.00 },   -- Focus
    [3] = { r=1.00, g=0.82, b=0.00 },   -- Energy
    [4] = { r=0.00, g=1.00, b=0.84 },   -- Happiness (pet)
}

SlyUF.REACT_COLORS = {
    [1] = { r=1.0, g=0.0,  b=0.0  },   -- Hated
    [2] = { r=1.0, g=0.0,  b=0.0  },   -- Hostile
    [3] = { r=1.0, g=0.25, b=0.0  },   -- Unfriendly
    [4] = { r=1.0, g=1.0,  b=0.0  },   -- Neutral
    [5] = { r=1.0, g=1.0,  b=0.0  },   -- Neutral
    [6] = { r=0.0, g=1.0,  b=0.0  },   -- Friendly
    [7] = { r=0.0, g=1.0,  b=0.0  },   -- Honored
    [8] = { r=0.0, g=1.0,  b=0.0  },   -- Exalted
}

-- -------------------------------------------------------
-- Blizzard frame suppression
-- -------------------------------------------------------
local function HideBlizzardFrames()
    -- NEVER call UnregisterAllEvents on Blizzard unit frames.
    -- PlayerFrame / TargetFrame / PartyMemberFrames drive critical
    -- game subsystems (loot eligibility, threat, vehicle, aura tracking).
    -- Stripping events causes crashes and broken loot interactions.
    -- Simply hide them and suppress re-show.
    if PlayerFrame then
        PlayerFrame:Hide()
        PlayerFrame:HookScript("OnShow", function(s) s:Hide() end)
    end
    if TargetFrame then
        TargetFrame:Hide()
        TargetFrame:HookScript("OnShow", function(s) s:Hide() end)
    end
    if ComboFrame then ComboFrame:Hide() end
    for i = 1, 4 do
        local pf = _G["PartyMemberFrame" .. i]
        if pf then
            pf:Hide()
            pf:HookScript("OnShow", function(s) s:Hide() end)
        end
        local pet = _G["PartyMemberFrame" .. i .. "PetFrame"]
        if pet then pet:Hide() end
    end
    if PartyMemberBackground then PartyMemberBackground:Hide() end
end

local function ShowBlizzardFrames()
    if PlayerFrame then
        PlayerFrame:Show()
        PlayerFrame:RegisterEvent("UNIT_HEALTH")
        PlayerFrame:RegisterEvent("UNIT_MANA")
        PlayerFrame:RegisterEvent("PLAYER_ENTERING_WORLD")
    end
    if TargetFrame then
        TargetFrame:Show()
        TargetFrame:RegisterEvent("PLAYER_TARGET_CHANGED")
    end
    for i = 1, 4 do
        local pf = _G["PartyMemberFrame" .. i]
        if pf then pf:Show() end
    end
end

-- -------------------------------------------------------
-- Data helpers
-- -------------------------------------------------------
function SlyUF.GetHP(unit)
    local hp  = UnitHealth(unit)    or 0
    local max = UnitHealthMax(unit) or 1
    return hp, max
end

function SlyUF.GetPower(unit)
    local pt  = UnitPowerType and UnitPowerType(unit) or 0
    local pw  = UnitMana and UnitMana(unit)    or
                (UnitPower and UnitPower(unit, pt) or 0)
    local max = UnitManaMax and UnitManaMax(unit) or
                (UnitPowerMax and UnitPowerMax(unit, pt) or 0)
    return pw, max, pt
end

function SlyUF.GetHPColor(unit)
    -- Class-colored for players, reaction-colored for NPCs
    if UnitIsPlayer(unit) then
        local _, cls = UnitClass(unit)
        if cls and RAID_CLASS_COLORS and RAID_CLASS_COLORS[cls] then
            local c = RAID_CLASS_COLORS[cls]
            return c.r, c.g, c.b
        end
        return 0.0, 0.8, 0.0
    end
    -- NPC: use reaction
    local react = UnitReaction(unit, "player") or 5
    local c = SlyUF.REACT_COLORS[react] or SlyUF.REACT_COLORS[5]
    return c.r, c.g, c.b
end

-- -------------------------------------------------------
-- Enable / disable toggle
-- -------------------------------------------------------
function SlyUF.Enable()
    SlyUF.db.enabled = true
    HideBlizzardFrames()
    if SlyUF.frames.player then SlyUF.frames.player:Show() end
    if SlyUF.frames.target then SlyUF.frames.target:Show() end
    if SlyUF.frames.tot    then SlyUF.frames.tot:Show() end
    for i = 1, 4 do
        local pf = SlyUF.frames["party" .. i]
        if pf then pf:Show() end
    end
    SlyUF.UpdateAll()
end

function SlyUF.Disable()
    SlyUF.db.enabled = false
    -- Hide our frames
    if SlyUF.frames.player then SlyUF.frames.player:Hide() end
    if SlyUF.frames.target then SlyUF.frames.target:Hide() end
    if SlyUF.frames.tot    then SlyUF.frames.tot:Hide() end
    for i = 1, 4 do
        local pf = SlyUF.frames["party" .. i]
        if pf then pf:Hide() end
    end
    ShowBlizzardFrames()
    print("|cff00ccff[SlyUF]|r Disabled — default frames restored. /reload to fully unload.")
end

-- -------------------------------------------------------
-- Events
-- -------------------------------------------------------
local UPDATE_EVENTS = {
    "UNIT_HEALTH", "UNIT_MAXHEALTH",
    "UNIT_MANA",   "UNIT_MAXMANA",
    "UNIT_ENERGY", "UNIT_RAGE",
    "UNIT_DISPLAYPOWER",
    "UNIT_NAME_UPDATE",
    "UNIT_LEVEL",
    "UNIT_PORTRAIT_UPDATE",
    "UNIT_AURA",
}

local ef = CreateFrame("Frame")
ef:RegisterEvent("ADDON_LOADED")

ef:SetScript("OnEvent", function(self, event, arg1)
    if event == "ADDON_LOADED" and arg1 == ADDON_NAME then
        SlyUFDB = SlyUFDB or {}
        ApplyDefaults(SlyUFDB, DB_DEFAULTS)
        SlyUF.db = SlyUFDB

        -- Build UI first
        SlyUF_BuildAll()

        -- Wire update events
        self:RegisterEvent("PLAYER_ENTERING_WORLD")
        self:RegisterEvent("PLAYER_TARGET_CHANGED")
        self:RegisterEvent("PARTY_MEMBERS_CHANGED")
        self:RegisterEvent("PLAYER_FLAGS_CHANGED")
        for _, ev in ipairs(UPDATE_EVENTS) do
            self:RegisterEvent(ev)
        end
        self:SetScript("OnEvent", SlyUF.OnEvent)

        -- Register with SlySuite
        if SlySuite_Register then
            SlySuite_Register(ADDON_NAME, ADDON_VERSION,
                function()
                    if SlyUF.db.enabled then SlyUF.Enable() end
                end, {
                description = "Unit frames — player, target, ToT, party. Replaces ZPerl.",
                slash       = "/slyuf",
                icon        = "Interface\\Icons\\Spell_Nature_NaturesBlessing",
            })
        else
            -- No suite — init directly
            if SlyUF.db.enabled then SlyUF.Enable() end
        end
    end
end)

function SlyUF.OnEvent(self, event, arg1)
    if event == "PLAYER_TARGET_CHANGED" then
        SlyUF.UpdateTarget()
        SlyUF.UpdateToT()
    elseif event == "PARTY_MEMBERS_CHANGED" then
        SlyUF.UpdateParty()
    elseif event == "PLAYER_ENTERING_WORLD" then
        SlyUF.UpdateAll()
        if SlyUF.db.enabled then HideBlizzardFrames() end
    else
        -- Unit-based events
        if arg1 == "player" then
            SlyUF.UpdatePlayer()
        elseif arg1 == "target" then
            SlyUF.UpdateTarget()
            SlyUF.UpdateToT()
        elseif arg1 and arg1:sub(1, 5) == "party" then
            local idx = tonumber(arg1:sub(6))
            if idx then SlyUF.UpdatePartyMember(idx) end
        end
    end
end

-- -------------------------------------------------------
-- Slash commands
-- -------------------------------------------------------
SLASH_SLYUF1 = "/slyuf"
SlashCmdList["SLYUF"] = function(msg)
    msg = strtrim(msg or ""):lower()
    if msg == "enable" then
        SlyUF.Enable()
        print("|cff00ccff[SlyUF]|r Enabled.")
    elseif msg == "disable" then
        SlyUF.Disable()
    elseif msg == "reset" then
        SlyUF.db.positions = {}
        SlyUF_PositionAll()
        print("|cff00ccff[SlyUF]|r Positions reset.")
    else
        if SlyUF.db.enabled then
            SlyUF.Disable()
        else
            SlyUF.Enable()
            print("|cff00ccff[SlyUF]|r Enabled.")
        end
    end
end
