-- SlyMetrics.lua  (TBC Anniversary / Interface 20505)
-- Clean standalone damage + healing + threat meter.
-- Parses COMBAT_LOG_EVENT_UNFILTERED directly; no external deps.

local ADDON_NAME    = "SlySuite_Metrics"
local ADDON_VERSION = "1.2.0"

-- Public namespace
SM = {}
SM.panel    = "dps"
SM.inCombat = false
SM.db       = {}

-- -- data --------------------------------------------------------------------
local actors  = {}        -- [guid] = { name, cls, dmg, heal }
local totDmg  = 0
local totHeal = 0
local elapsed = 0
local startT  = 0

local function Reset()
    actors  = {}
    totDmg  = 0
    totHeal = 0
    elapsed = 0
    startT  = 0
end
SM.Reset = Reset

local function Actor(guid, name)
    if not actors[guid] then
        actors[guid] = { guid=guid, name=name or "?", cls=nil, dmg=0, heal=0 }
    end
    if name and name ~= "" then actors[guid].name = name end
    return actors[guid]
end

local function GetRows(key)
    local rows = {}
    for _, a in pairs(actors) do
        rows[#rows+1] = a
    end
    table.sort(rows, function(a, b) return (a[key] or 0) > (b[key] or 0) end)
    local tot = (key == "dmg") and totDmg or totHeal
    return rows, tot, elapsed
end

SM.GetDPSRows = function() return GetRows("dmg")  end
SM.GetHPSRows = function() return GetRows("heal") end

function SM.Fmt(n)
    n = tonumber(n) or 0
    if n >= 1e6 then return string.format("%.1fM", n/1e6) end
    if n >= 1e3 then return string.format("%.1fk", n/1e3) end
    return tostring(math.floor(n))
end

-- -- combat log --------------------------------------------------------------
-- TBC combat log positions (from varargs):
--  1:timestamp  2:subevent  3:hideCaster
--  4:srcGUID    5:srcName   6:srcFlags  7:srcRaidFlags
--  8:dstGUID    9:dstName  10:dstFlags 11:dstRaidFlags
-- 12+: suffix parameters depending on subevent

local AFFIL_MINE    = 0x00000001
local AFFIL_PARTY   = 0x00000002
local AFFIL_RAID    = 0x00000004
local CTRL_PLAYER   = 0x00000100
local AFFIL_MASK    = AFFIL_MINE + AFFIL_PARTY + AFFIL_RAID

local function IsGroupSource(flags)
    if not flags then return false end
    return bit.band(flags, AFFIL_MASK) > 0
       and bit.band(flags, CTRL_PLAYER) > 0
end

local clFrame = CreateFrame("Frame")
clFrame:RegisterEvent("COMBAT_LOG_EVENT_UNFILTERED")
clFrame:RegisterEvent("PLAYER_REGEN_DISABLED")
clFrame:RegisterEvent("PLAYER_REGEN_ENABLED")
clFrame:SetScript("OnEvent", function(self, event, ...)
    if event == "PLAYER_REGEN_DISABLED" then
        SM.inCombat = true
        Reset()
        startT = GetTime()
        return
    elseif event == "PLAYER_REGEN_ENABLED" then
        SM.inCombat  = false
        elapsed      = GetTime() - startT
        return
    end

    -- COMBAT_LOG_EVENT_UNFILTERED
    -- Capture varargs into a table immediately — Lua 5.1 forbids '...' inside
    -- any nested function or closure, so we must do this at the top level here.
    local a       = { ... }
    local subev   = a[2]
    local srcGUID = a[4]
    local srcName = a[5]
    local srcFlags= a[6]

    if not srcGUID or srcGUID == "" then return end
    if not IsGroupSource(srcFlags) then return end

    if subev == "SWING_DAMAGE" then
        -- suffix: amount overkill school resisted blocked absorbed critical glancing crushing
        local amt = tonumber(a[12]) or 0
        local abs = tonumber(a[17]) or 0
        local act = Actor(srcGUID, srcName)
        act.dmg = act.dmg + amt + abs
        totDmg  = totDmg  + amt + abs

    elseif subev == "SPELL_DAMAGE"
        or subev == "SPELL_PERIODIC_DAMAGE"
        or subev == "RANGE_DAMAGE"
        or subev == "DAMAGE_SHIELD" then
        -- suffix: spellId spellName spellSchool amount overkill school resisted blocked absorbed critical
        local amt = tonumber(a[15]) or 0
        local abs = tonumber(a[20]) or 0
        local act = Actor(srcGUID, srcName)
        act.dmg = act.dmg + amt + abs
        totDmg  = totDmg  + amt + abs

    elseif subev == "SPELL_HEAL"
        or subev == "SPELL_PERIODIC_HEAL" then
        -- suffix: spellId spellName spellSchool amount overhealing absorbed critical
        local amt = tonumber(a[15]) or 0
        local act = Actor(srcGUID, srcName)
        act.heal = act.heal + amt
        totHeal  = totHeal  + amt
    end
end)

-- -- threat ticker ------------------------------------------------------------
SM.threat = {}
local thrClock = 0
local thrFrame = CreateFrame("Frame")
thrFrame:SetScript("OnUpdate", function(_, dt)
    thrClock = thrClock + dt
    if thrClock < 0.5 then return end
    thrClock = 0

    local rows = {}
    local function tryUnit(u)
        if not UnitExists(u) then return end
        local isTanking, _, threatPct, _, threatVal =
            UnitDetailedThreatSituation(u, "target")
        if threatVal and threatVal > 0 then
            local _, cls = UnitClass(u)
            rows[#rows+1] = {
                name   = UnitName(u) or u,
                cls    = cls,
                val    = threatVal,
                pct    = threatPct or 0,
                isTank = isTanking and true or false,
            }
        end
    end

    tryUnit("player")
    for i = 1, 4  do tryUnit("party"..i) end
    for i = 1, 40 do tryUnit("raid"..i)  end
    table.sort(rows, function(a, b) return a.val > b.val end)
    SM.threat = rows
    if SM_RefreshThreat then SM_RefreshThreat() end
end)

-- -- DPS ticker ---------------------------------------------------------------
local dClock = 0
local dFrame = CreateFrame("Frame")
dFrame:SetScript("OnUpdate", function(_, dt)
    if not SM.inCombat then return end
    dClock = dClock + dt
    if dClock < 0.5 then return end
    dClock = 0
    if SM_Refresh then SM_Refresh() end
end)

-- -- Init ---------------------------------------------------------------------
local function Init()
    SlyMetricsDB = SlyMetricsDB or {}
    SM.db        = SlyMetricsDB
    if SM_BuildUI then
        SM_BuildUI()
    end
end

-- -- Boot ---------------------------------------------------------------------
local bootFrame = CreateFrame("Frame")
bootFrame:RegisterEvent("ADDON_LOADED")
bootFrame:RegisterEvent("PLAYER_ENTERING_WORLD")
bootFrame:SetScript("OnEvent", function(self, event, arg1)
    if event == "ADDON_LOADED" then
        if arg1 ~= ADDON_NAME then return end
        self:UnregisterEvent("ADDON_LOADED")
        if SlySuiteDataFrame and SlySuiteDataFrame.Register then
            SlySuiteDataFrame.Register(ADDON_NAME, ADDON_VERSION, Init, {
                description = "Damage, healing and threat meter.",
                slash       = "/slymetrics",
                icon        = "Interface\\Icons\\Ability_Warrior_Charge",
            })
        else
            Init()
        end
    elseif event == "PLAYER_ENTERING_WORLD" then
        self:UnregisterEvent("PLAYER_ENTERING_WORLD")
        -- Safety net: runs Init if SlySuite somehow didn't trigger it.
        if not SlyMetricsFrame then Init() end
    end
end)

-- -- Slash --------------------------------------------------------------------
SLASH_SLYMETRICS1 = "/slymetrics"
SlashCmdList["SLYMETRICS"] = function(msg)
    msg = string.lower(string.gsub(msg or "", "^%s*(.-)%s*$", "%1"))

    -- Build window if it doesn't exist yet.
    if not SlyMetricsFrame then
        if SM_BuildUI then
            SM_BuildUI()
        else
            print("|cffff4444[SlyMetrics]|r UI not ready — wait for world to load.")
            return
        end
    end

    if msg == "reset" then
        Reset()
        if SM_Refresh then SM_Refresh() end
    elseif msg == "dps" or msg == "hps" then
        SM.panel = msg
        if SM_Refresh then SM_Refresh() end
    elseif msg == "pos" then
        if SM.db then SM.db.mx = nil ; SM.db.my = nil end
        SlyMetricsFrame:ClearAllPoints()
        SlyMetricsFrame:SetPoint("RIGHT", UIParent, "RIGHT", -60, 100)
        SlyMetricsFrame:Show()
        print("|cff00ccff[SlyMetrics]|r Window repositioned.")
    else
        if SlyMetricsFrame:IsShown() then
            SlyMetricsFrame:Hide()
        else
            SlyMetricsFrame:Show()
        end
    end
end
