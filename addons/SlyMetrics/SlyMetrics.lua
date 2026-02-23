-- ============================================================
-- SlyMetrics.lua  —  Damage meter + Threat meter core
-- Tracks combat log for damage/healing, polls threat API.
-- /slymetrics to toggle. /slymetrics reset to clear data.
-- ============================================================

local ADDON_NAME    = "SlyMetrics"
local ADDON_VERSION = "1.0.0"

SlyMetrics = SlyMetrics or {}
local SM = SlyMetrics

SM.activePanel = "dps"     -- "dps" | "hps" | "threat"
SM.inCombat    = false

-- -------------------------------------------------------
-- Segment data model
-- Each segment: { startTime, endTime, damage={}, healing={}, classes={} }
-- classes[name] = classToken (e.g. "WARRIOR")
-- -------------------------------------------------------
SM.segments  = {}    -- [1] = most recent finished
SM.current   = nil   -- active segment during combat
SM.MAX_SEGS  = 10

local function NewSegment()
    return {
        startTime = GetTime(),
        endTime   = nil,
        damage    = {},
        healing   = {},
        classes   = {},
    }
end

-- -------------------------------------------------------
-- Saved-variables defaults
-- -------------------------------------------------------
local DB_DEFAULTS = {
    position = { point = "RIGHT", x = -60, y = 100 },
    locked   = false,
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
-- Class lookup — cache UnitClass results by name
-- -------------------------------------------------------
local classCache = {}
local function GetClassToken(name)
    if classCache[name] then return classCache[name] end
    -- Scan party / raid
    local units = { "player" }
    if IsInRaid and IsInRaid() then
        for i = 1, GetNumGroupMembers() do
            table.insert(units, "raid" .. i)
        end
    elseif IsInGroup and IsInGroup() then
        for i = 1, GetNumGroupMembers() do
            table.insert(units, "party" .. i)
        end
    end
    for _, u in ipairs(units) do
        local n = UnitName(u)
        if n then
            local _, cls = UnitClass(u)
            if cls then classCache[n] = cls end
        end
    end
    return classCache[name]
end

-- -------------------------------------------------------
-- Combat log parsing
-- -------------------------------------------------------
-- COMBATLOG_OBJECT_REACTION_FRIENDLY = 0x10
-- COMBATLOG_OBJECT_AFFILIATION_MINE  = 0x01
-- COMBATLOG_OBJECT_AFFILIATION_PARTY = 0x02
-- COMBATLOG_OBJECT_AFFILIATION_RAID  = 0x04
-- COMBATLOG_OBJECT_TYPE_PLAYER       = 0x400
-- COMBATLOG_OBJECT_TYPE_PET          = 0x1000

local FRIENDLY_REACTION   = 0x00000010
local AFFIL_MINE_PARTY    = 0x00000007   -- mine | party | raid
local TYPE_PLAYER_OR_PET  = 0x00001400

local function IsFriendlyUnit(flags)
    return (bit.band(flags, FRIENDLY_REACTION) ~= 0)
       and (bit.band(flags, AFFIL_MINE_PARTY)  ~= 0)
end

local function ParseCLEU()
    local t, sub,
          _, srcGUID, srcName, srcFlags, _,
          _, _, _, _,
          a1, a2, a3, a4, a5
            = CombatLogGetCurrentEventInfo()

    if not sub or not srcName then return end
    if not IsFriendlyUnit(srcFlags or 0) then return end

    local seg = SM.current
    if not seg then return end

    -- Cache class
    if not seg.classes[srcName] then
        seg.classes[srcName] = GetClassToken(srcName) or "UNKNOWN"
    end

    if sub == "SWING_DAMAGE" then
        -- a1=amount, a2=overkill, ...
        local dmg = tonumber(a1) or 0
        seg.damage[srcName] = (seg.damage[srcName] or 0) + dmg

    elseif sub == "SPELL_DAMAGE"
        or sub == "SPELL_PERIODIC_DAMAGE"
        or sub == "RANGE_DAMAGE" then
        -- a1=spellId, a2=spellName, a3=school, a4=amount, ...
        local dmg = tonumber(a4) or 0
        seg.damage[srcName] = (seg.damage[srcName] or 0) + dmg

    elseif sub == "SPELL_HEAL"
        or sub == "SPELL_PERIODIC_HEAL" then
        -- a1=spellId, a2=spellName, a3=school, a4=amount, a5=overhealing
        local heal     = tonumber(a4) or 0
        local overheal = tonumber(a5) or 0
        local effective = math.max(0, heal - overheal)
        seg.healing[srcName] = (seg.healing[srcName] or 0) + effective
    end
end

-- -------------------------------------------------------
-- Threat polling: 0.3s tick during combat
-- -------------------------------------------------------
SM.threatData = {}    -- [unitToken] = { name, pct, value, isTanking, class }

local THREAT_TICK   = 0.3
local threatTimer   = 0

local function PollThreat(elapsed)
    threatTimer = threatTimer + elapsed
    if threatTimer < THREAT_TICK then return end
    threatTimer = 0

    if not UnitExists("target") then
        SM.threatData = {}
        return
    end

    local rows = {}
    local units = { "player" }
    local inRaid = IsInRaid and IsInRaid()
    local inGroup = IsInGroup and IsInGroup()
    if inRaid then
        for i = 1, GetNumGroupMembers() do
            table.insert(units, "raid" .. i)
        end
    elseif inGroup then
        for i = 1, GetNumGroupMembers() do
            table.insert(units, "party" .. i)
        end
    end

    for _, u in ipairs(units) do
        if UnitExists(u) then
            local isTanking, status, pct, rawPct, value =
                UnitDetailedThreatSituation(u, "target")
            if value then
                -- TBC Anniversary (Timewalk): scale factor of 100
                value = math.floor(value / 100)
                local name = UnitName(u) or u
                local _, cls = UnitClass(u)
                table.insert(rows, {
                    name      = name,
                    pct       = pct or 0,
                    rawPct    = rawPct or 0,
                    value     = value,
                    isTanking = isTanking,
                    status    = status or 0,
                    class     = cls or "UNKNOWN",
                })
            end
        end
    end

    table.sort(rows, function(a, b) return a.value > b.value end)
    SM.threatData = rows
    if SM.activePanel == "threat" then SM_RefreshThreat() end
end

-- -------------------------------------------------------
-- Public: sorted rows for display
-- -------------------------------------------------------
function SM.GetDamageRows()
    local seg = SM.current or SM.segments[1]
    if not seg then return {}, 0, 0 end

    local elapsed = (seg.endTime or GetTime()) - seg.startTime
    elapsed = math.max(1, elapsed)

    local rows, total = {}, 0
    for name, dmg in pairs(seg.damage) do
        total = total + dmg
        table.insert(rows, {
            name  = name,
            total = dmg,
            dps   = dmg / elapsed,
            class = seg.classes[name] or "UNKNOWN",
        })
    end
    table.sort(rows, function(a, b) return a.total > b.total end)
    return rows, total, elapsed
end

function SM.GetHealRows()
    local seg = SM.current or SM.segments[1]
    if not seg then return {}, 0, 0 end

    local elapsed = (seg.endTime or GetTime()) - seg.startTime
    elapsed = math.max(1, elapsed)

    local rows, total = {}, 0
    for name, h in pairs(seg.healing) do
        total = total + h
        table.insert(rows, {
            name  = name,
            total = h,
            hps   = h / elapsed,
            class = seg.classes[name] or "UNKNOWN",
        })
    end
    table.sort(rows, function(a, b) return a.total > b.total end)
    return rows, total, elapsed
end

function SM.Reset()
    SM.segments = {}
    SM.current  = SM.inCombat and NewSegment() or nil
    SM.threatData = {}
    SM_Refresh()
end

-- -------------------------------------------------------
-- OnUpdate dispatcher
-- -------------------------------------------------------
local tickFrame = CreateFrame("Frame")
tickFrame:SetScript("OnUpdate", function(self, elapsed)
    if SM.inCombat then
        PollThreat(elapsed)
        if SM.activePanel == "dps" or SM.activePanel == "hps" then
            -- light refresh for live meters (every 0.5s)
            self._meter = (self._meter or 0) + elapsed
            if self._meter >= 0.5 then
                self._meter = 0
                SM_Refresh()
            end
        end
    end
end)

-- -------------------------------------------------------
-- Events
-- -------------------------------------------------------
local ef = CreateFrame("Frame")
ef:RegisterEvent("ADDON_LOADED")
ef:RegisterEvent("PLAYER_REGEN_DISABLED")
ef:RegisterEvent("PLAYER_REGEN_ENABLED")
ef:RegisterEvent("COMBAT_LOG_EVENT_UNFILTERED")
ef:RegisterEvent("PARTY_MEMBERS_CHANGED")
ef:RegisterEvent("RAID_ROSTER_UPDATE")

ef:SetScript("OnEvent", function(self, event, arg1)
    if event == "ADDON_LOADED" and arg1 == ADDON_NAME then
        SlyMetricsDB = SlyMetricsDB or {}
        ApplyDefaults(SlyMetricsDB, DB_DEFAULTS)
        SM.db = SlyMetricsDB

        SM_BuildUI()

        if SlySuite_Register then
            SlySuite_Register(ADDON_NAME, ADDON_VERSION, function() end, {
                description = "Damage meter + threat meter in one window.",
                slash       = "/slymetrics",
                icon        = "Interface\\Icons\\Ability_Warrior_Charge",
            })
        end

    elseif event == "PLAYER_REGEN_DISABLED" then
        SM.inCombat = true
        SM.current  = NewSegment()
        classCache  = {}    -- re-scan on new combat
        SM_SetStatusText("Combat…")

    elseif event == "PLAYER_REGEN_ENABLED" then
        SM.inCombat = false
        if SM.current then
            SM.current.endTime = GetTime()
            table.insert(SM.segments, 1, SM.current)
            if #SM.segments > SM.MAX_SEGS then
                table.remove(SM.segments)
            end
            SM.current = nil
        end
        SM_Refresh()
        local rows, total, elapsed = SM.GetDamageRows()
        SM_SetStatusText(string.format("Done — %.0fs  %s dmg",
            elapsed, SM.FormatLarge(total)))

    elseif event == "COMBAT_LOG_EVENT_UNFILTERED" then
        if SM.inCombat then ParseCLEU() end

    elseif event == "PARTY_MEMBERS_CHANGED"
        or event == "RAID_ROSTER_UPDATE" then
        classCache = {}
    end
end)

-- -------------------------------------------------------
-- Utility
-- -------------------------------------------------------
function SM.FormatLarge(n)
    if n >= 1000000 then
        return string.format("%.1fM", n / 1000000)
    elseif n >= 1000 then
        return string.format("%.1fk", n / 1000)
    else
        return tostring(math.floor(n))
    end
end

-- -------------------------------------------------------
-- Slash
-- -------------------------------------------------------
SLASH_SLYMETRICS1 = "/slymetrics"
SLASH_SLYMETRICS2 = "/sm"
SlashCmdList["SLYMETRICS"] = function(msg)
    msg = strtrim(msg or ""):lower()
    if msg == "reset" then
        SM.Reset()
        print("|cff00ccff[SlyMetrics]|r Data cleared.")
    elseif msg == "dps" then
        SM.activePanel = "dps" ; SM_Refresh()
    elseif msg == "hps" then
        SM.activePanel = "hps" ; SM_Refresh()
    elseif msg == "threat" then
        SM.activePanel = "threat" ; SM_Refresh()
    else
        if SlyMetricsFrame then
            if SlyMetricsFrame:IsShown() then
                SlyMetricsFrame:Hide()
            else
                SlyMetricsFrame:Show()
            end
        end
    end
end
